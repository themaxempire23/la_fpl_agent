$ErrorActionPreference = 'Continue'
# Docker writes normal progress messages to stderr; check its exit codes explicitly.
Set-Location $PSScriptRoot -ErrorAction Stop
if (-not (Test-Path -LiteralPath '.env')) {
    Copy-Item -LiteralPath '.env.example' -Destination '.env' -ErrorAction Stop
}
docker compose --progress plain up -d --wait postgres n8n ollama search
if ($LASTEXITCODE -ne 0) { throw 'Docker services failed to start. Check Docker Desktop and docker compose logs.' }
docker compose run --rm ollama-init
if ($LASTEXITCODE -ne 0) { throw 'Model download failed; rerun start.ps1 to retry.' }
docker compose exec -T n8n n8n import:credentials --input=/workflows/n8n-credentials.json
if ($LASTEXITCODE -ne 0) { throw 'Credential import failed. Complete n8n owner setup at http://localhost:5678 and retry.' }
docker compose exec -T n8n n8n import:workflow --input=/workflows/fpl-n8n-workflow.json
if ($LASTEXITCODE -ne 0) { throw 'Workflow import failed. Complete n8n owner setup at http://localhost:5678 and retry.' }
Write-Host 'Open http://localhost:5678. Set FPL_TEAM_ID in .env, execute the workflow, then publish it to enable the schedule and webhooks.'
