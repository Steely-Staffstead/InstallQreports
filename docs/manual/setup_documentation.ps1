$ErrorActionPreference = "Stop"
$solutionRoot = Split-Path -Parent $PSScriptRoot
$environmentPath = Join-Path $solutionRoot ".venv-docs"
$python = Join-Path $environmentPath "Scripts\python.exe"
$requirements = Join-Path $solutionRoot "requirements-docs.txt"

if (-not (Test-Path -LiteralPath $python)) {
    py -m venv $environmentPath
    if ($LASTEXITCODE -ne 0) { throw "Could not create the documentation environment." }
}

& $python -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { throw "Could not update pip." }

& $python -m pip install -r $requirements
if ($LASTEXITCODE -ne 0) { throw "Could not install the documentation dependencies." }

Write-Host "Documentation environment is ready."
Write-Host "Preview with: .\.venv-docs\Scripts\python.exe -m mkdocs serve"

