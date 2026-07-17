param(
  [switch]$Yes
)

if (-not $Yes) {
  throw "Use -Yes to remove lab containers and volumes."
}

$RootDir = Split-Path -Parent $PSScriptRoot
docker compose -f (Join-Path $RootDir "docker-compose.yml") down -v --remove-orphans
