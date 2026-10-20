. (Join-Path $PSScriptRoot 'common.ps1')
$version = Get-TeaVersion
$stage = Join-Path $TeaBuildRoot ('package-stage-' + [guid]::NewGuid().ToString('N'))
$distribution = Join-Path $TeaRoot 'dist'
$executableName = "Tea-Panel-$version-Windows-x64.exe"
$executable = Join-Path $distribution $executableName
try {
    Invoke-TeaDotNet -Arguments @('publish', (Join-Path $PSScriptRoot 'TeaPanel/TeaPanel.csproj'), '-c', 'Release', '-r', 'win-x64', '--self-contained', 'true', '-p:PublishSingleFile=true', '-p:TeaPanelTesting=false', '-o', $stage)
    $published = @(Get-ChildItem -LiteralPath $stage -Force)
    if ($published.Count -ne 1 -or $published[0].Name -ne 'TeaPanel.exe') { throw 'Expected exactly one standalone TeaPanel.exe in publish output' }
    New-Item -ItemType Directory -Force -Path $distribution | Out-Null
    Copy-Item -LiteralPath $published[0].FullName -Destination $executable -Force
    $hash = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText(($executable + '.sha256'), ($hash + '  ' + $executableName + "`n"), (New-Object Text.UTF8Encoding($false)))
    Write-Output $executable
    Write-Output ($executable + '.sha256')
} finally {
    $resolvedStage = [IO.Path]::GetFullPath($stage)
    $allowedRoot = [IO.Path]::GetFullPath($TeaBuildRoot).TrimEnd('\') + '\'
    if (-not $resolvedStage.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Package stage escaped build directory' }
    if (Test-Path -LiteralPath $resolvedStage) { Remove-Item -LiteralPath $resolvedStage -Recurse -Force }
}
