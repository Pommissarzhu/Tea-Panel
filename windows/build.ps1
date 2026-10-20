param([switch] $Run)
. (Join-Path $PSScriptRoot 'common.ps1')
$output = Join-Path $TeaBuildRoot 'app'
Invoke-TeaDotNet -Arguments @('build', (Join-Path $PSScriptRoot 'TeaPanel/TeaPanel.csproj'), '-c', 'Release', '-o', $output)
Write-Output (Join-Path $output 'TeaPanel.exe')
if ($Run) { Start-Process -FilePath (Join-Path $output 'TeaPanel.exe') -WorkingDirectory $TeaRoot }
