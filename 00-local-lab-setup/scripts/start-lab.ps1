$RootDir = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $RootDir ".env"))) {
  throw ".env not found. Copy .env.example to .env first."
}
docker compose -f (Join-Path $RootDir "docker-compose.yml") up -d --build
Start-Sleep -Seconds 10
& (Join-Path $PSScriptRoot "verify-lab.ps1")
