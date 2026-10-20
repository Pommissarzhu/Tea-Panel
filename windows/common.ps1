Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$TeaRoot = Split-Path $PSScriptRoot -Parent
$TeaBuildRoot = Join-Path $TeaRoot 'build/windows'

if ($env:TEA_PANEL_DOTNET) {
    $TeaDotNet = $env:TEA_PANEL_DOTNET
} elseif (Test-Path -LiteralPath (Join-Path $TeaRoot 'build/tools/dotnet/dotnet.exe')) {
    $TeaDotNet = Join-Path $TeaRoot 'build/tools/dotnet/dotnet.exe'
} else {
    $TeaDotNet = (Get-Command dotnet -ErrorAction Stop).Source
}

$env:DOTNET_ROOT = Split-Path $TeaDotNet -Parent
$env:DOTNET_CLI_HOME = Join-Path $TeaBuildRoot 'dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_ADD_GLOBAL_TOOLS_TO_PATH = 'false'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
$env:DOTNET_NOLOGO = 'true'
$env:DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE = 'true'
$env:NUGET_PACKAGES = Join-Path $TeaBuildRoot 'nuget-packages'
New-Item -ItemType Directory -Force -Path $TeaBuildRoot | Out-Null

function Invoke-TeaDotNet {
    param([string[]] $Arguments)
    & $TeaDotNet @Arguments
    if ($LASTEXITCODE -ne 0) { throw "dotnet failed with exit code $LASTEXITCODE" }
}

function Get-TeaVersion {
    [xml] $project = Get-Content -LiteralPath (Join-Path $TeaRoot 'windows/TeaPanel/TeaPanel.csproj') -Raw -Encoding UTF8
    $version = [string] $project.Project.PropertyGroup[0].Version
    if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'App version must use major.minor.patch' }
    return $version
}
