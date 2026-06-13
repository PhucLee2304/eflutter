$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent $PSScriptRoot
$envDir = Join-Path $workspace ".env"
$localEnvPath = Join-Path $envDir "local.json"
$devLaunchPath = Join-Path $envDir "dev_launch.json"

New-Item -ItemType Directory -Force $envDir | Out-Null

$defines = [ordered]@{}
if (Test-Path $localEnvPath) {
  $localDefines = Get-Content $localEnvPath -Raw | ConvertFrom-Json
  foreach ($property in $localDefines.PSObject.Properties) {
    $defines[$property.Name] = $property.Value
  }
}

$defines["DEV_AUTH_STORAGE_SESSION"] = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()

$defines | ConvertTo-Json -Depth 10 | Set-Content -Path $devLaunchPath -Encoding UTF8
Write-Host "Generated .env/dev_launch.json"
