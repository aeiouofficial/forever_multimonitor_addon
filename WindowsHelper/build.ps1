$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path $root ".tmp"
New-Item -ItemType Directory -Force $temp | Out-Null
$env:TEMP = $temp
$env:TMP = $temp
$env:DOTNET_CLI_HOME = Join-Path $temp "dotnet-home"
$env:NUGET_PACKAGES = Join-Path $temp "nuget"
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
$env:LIB = ""
dotnet build (Join-Path $PSScriptRoot "ForeverMultiMonitor.WindowsHelper.csproj") --configuration Release --verbosity minimal -p:RestoreIgnoreFailedSources=true
if ($LASTEXITCODE -ne 0) { throw "Windows helper build failed with exit code $LASTEXITCODE" }
Write-Host "Built: $(Join-Path $PSScriptRoot 'bin\Release\net10.0-windows\ForeverMultiMonitor.WindowsHelper.exe')"