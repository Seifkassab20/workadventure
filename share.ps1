# ==============================================================================
# WorkAdventure Free Public Share Helper (Cloudflare Tunnel)
# ==============================================================================
param (
    [switch]$Stop
)

if ($Stop) {
    Write-Host "Stopping Cloudflare Tunnel..." -ForegroundColor Yellow
    Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-Host "Reverting WorkAdventure to localhost..." -ForegroundColor Cyan
    (Get-Content .env) -replace '^DOMAIN=.*', 'DOMAIN=localhost' -replace '^PROTOCOL=.*', 'PROTOCOL=http' | Set-Content .env
    docker compose -f docker-compose.standalone.yaml -f docker-compose.local.yaml up -d play back map-storage
    Write-Host "Done! WorkAdventure is back on http://localhost" -ForegroundColor Green
    exit 0
}

# Download cloudflared if not present
if (-not (Test-Path "cloudflared.exe")) {
    Write-Host "Downloading cloudflared executable (one-time download)..." -ForegroundColor Cyan
    $url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
    Invoke-WebRequest -Uri $url -OutFile "cloudflared.exe" -UseBasicParsing
}

Write-Host "`nStarting Cloudflare Tunnel to create your free public link..." -ForegroundColor Cyan

# Start cloudflared in background and capture the generated URL
$logFile = "$env:TEMP\cf_tunnel_wa.log"
if (Test-Path $logFile) { Remove-Item $logFile -Force }

$proc = Start-Process -FilePath ".\cloudflared.exe" -ArgumentList "tunnel", "--url", "http://localhost:80" -RedirectStandardError $logFile -PassThru -NoNewWindow

$tunnelUrl = $null
$domain = $null
$timeout = 45
$elapsed = 0

Write-Host "Waiting for Cloudflare to assign a public HTTPS address..." -NoNewline

while ($elapsed -lt $timeout) {
    Start-Sleep -Seconds 1
    $elapsed++
    Write-Host "." -NoNewline

    if (Test-Path $logFile) {
        try {
            $stream = [System.IO.File]::Open($logFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $reader = New-Object System.IO.StreamReader($stream)
            $content = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()

            if ($content -match '(https://[a-zA-Z0-9-]+\.trycloudflare\.com)') {
                $tunnelUrl = $matches[1]
                $domain = $tunnelUrl.Replace('https://', '').Trim('/')
                break
            }
        } catch {
            # File might be momentarily locked, will retry on next tick
        }
    }

    if ($proc.HasExited) {
        Write-Host "`ncloudflared process exited unexpectedly." -ForegroundColor Red
        break
    }
}

Write-Host ""

if (-not $tunnelUrl) {
    Write-Host "`nFailed to obtain Cloudflare tunnel URL within $timeout seconds." -ForegroundColor Red
    if (Test-Path $logFile) {
        Write-Host "--- Cloudflare Log ---" -ForegroundColor Yellow
        Get-Content $logFile -Tail 20
    }
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
    exit 1
}

Write-Host "==> Assigned Public URL: $tunnelUrl" -ForegroundColor Green
Write-Host "==> Updating WorkAdventure configuration with public domain..." -ForegroundColor Cyan

# Update .env with the public domain and PROTOCOL=https
$envContent = Get-Content .env -Raw
if ($envContent -match 'DOMAIN=') {
    $envContent = $envContent -replace 'DOMAIN=[^\r\n]*', "DOMAIN=$domain"
} else {
    $envContent += "`nDOMAIN=$domain"
}
if ($envContent -match 'PROTOCOL=') {
    $envContent = $envContent -replace 'PROTOCOL=[^\r\n]*', "PROTOCOL=https"
} else {
    $envContent += "`nPROTOCOL=https"
}
Set-Content -Path .env -Value $envContent -NoNewline

# Restart play and back to pick up the new public domain
Write-Host "==> Syncing WorkAdventure Pusher and Game Engine..." -ForegroundColor Cyan
docker compose -f docker-compose.standalone.yaml -f docker-compose.local.yaml up -d play back map-storage > $null 2>&1

Write-Host @"

================================================================================
   SUCCESS! YOUR WORKADVENTURE VIRTUAL OFFICE IS NOW PUBLIC AND LIVE!
================================================================================

   Public Shareable Link:
   $tunnelUrl

   Anyone in the world can open this link in their browser and join!
   WebRTC camera, microphone, and proximity bubbles will work automatically.

   To STOP sharing and return to localhost:
   .\share.ps1 -Stop

================================================================================
"@ -ForegroundColor Green

Write-Host "Keeping tunnel active. Press Ctrl+C in this terminal to close the public link." -ForegroundColor Yellow

# Wait on cloudflared process
try {
    Wait-Process -Id $proc.Id
} finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $logFile) { Remove-Item $logFile -Force -ErrorAction SilentlyContinue }
}
