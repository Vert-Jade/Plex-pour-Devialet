$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
python -X utf8 tools/devialet.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$players = @(Get-Content -LiteralPath '.local/players.json' -Raw | ConvertFrom-Json)
if ($players.Count -ne 1) { throw 'Un seul Player doit être détecté pour le lancement automatique.' }
python -X utf8 -u tools/devialet.py --launch $players[0]
