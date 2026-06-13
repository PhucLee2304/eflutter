param(
  [ValidateSet("all", "android", "web")]
  [string]$Target = "all",
  [string]$AndroidPackage = "com.example.eflutter",
  [string]$WebOrigin = "http://localhost:7357"
)

$ErrorActionPreference = "Continue"

function Clear-AndroidStorage {
  $adb = Get-Command adb -ErrorAction SilentlyContinue
  if (-not $adb) {
    Write-Host "adb not found; skipped Android storage cleanup."
    return
  }

  $devices = (& adb devices) | Select-String "device$"
  if (-not $devices) {
    Write-Host "No Android device connected; skipped Android storage cleanup."
    return
  }

  & adb shell pm clear $AndroidPackage | Out-Host
}

function Invoke-ChromeRuntime {
  param(
    [string]$WebSocketDebuggerUrl,
    [string]$Expression
  )

  Add-Type -AssemblyName System.Net.WebSockets
  $socket = [System.Net.WebSockets.ClientWebSocket]::new()
  $uri = [Uri]$WebSocketDebuggerUrl
  $socket.ConnectAsync($uri, [Threading.CancellationToken]::None).Wait(2000) | Out-Null

  if ($socket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
    return $false
  }

  $payload = @{
    id = 1
    method = "Runtime.evaluate"
    params = @{
      expression = $Expression
      awaitPromise = $true
    }
  } | ConvertTo-Json -Depth 8 -Compress

  $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
  $segment = [ArraySegment[byte]]::new($bytes)
  $socket.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait(2000) | Out-Null
  $socket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "done", [Threading.CancellationToken]::None).Wait(2000) | Out-Null
  return $true
}

function Clear-WebStorage {
  $expression = @"
(() => {
  const keys = [
    'accessToken',
    'refreshToken',
    'flutter.accessToken',
    'flutter.refreshToken',
  ];
  for (const key of keys) {
    localStorage.removeItem(key);
    sessionStorage.removeItem(key);
  }
  return true;
})()
"@

  foreach ($port in 9222..9227) {
    try {
      $targets = Invoke-RestMethod -Uri "http://127.0.0.1:$port/json/list" -TimeoutSec 1
    } catch {
      continue
    }

    foreach ($target in $targets) {
      if ($target.url -like "$WebOrigin*") {
        $ok = Invoke-ChromeRuntime -WebSocketDebuggerUrl $target.webSocketDebuggerUrl -Expression $expression
        if ($ok) {
          Write-Host "Cleared Web token storage for $($target.url)."
          return
        }
      }
    }
  }

  Write-Host "No debuggable Chrome tab found for $WebOrigin; skipped Web storage cleanup."
}

if ($Target -eq "all" -or $Target -eq "android") {
  Clear-AndroidStorage
}

if ($Target -eq "all" -or $Target -eq "web") {
  Clear-WebStorage
}
