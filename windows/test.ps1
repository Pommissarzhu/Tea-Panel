param([switch] $Desktop)
. (Join-Path $PSScriptRoot 'common.ps1')
$env:TEA_PANEL_TEST_ROOT = Join-Path $TeaBuildRoot 'test-data'
Invoke-TeaDotNet -Arguments @('run', '--project', (Join-Path $PSScriptRoot 'Tests/TeaCoreTests.csproj'), '-c', 'Release')
if ($Desktop) {
    $output = Join-Path $TeaBuildRoot 'desktop-tests'
    $report = Join-Path $TeaBuildRoot 'verification'
    Invoke-TeaDotNet -Arguments @('build', (Join-Path $PSScriptRoot 'TeaPanel/TeaPanel.csproj'), '-c', 'Release', '-p:TeaPanelTesting=true', '-o', $output)
    $process = Start-Process -FilePath (Join-Path $output 'TeaPanel.exe') -ArgumentList @('--verify-ui', ('"' + $report + '"')) -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw "Desktop checks failed. See $report/desktop-checks.json" }
    Get-Content -LiteralPath (Join-Path $report 'desktop-checks.json')
}
