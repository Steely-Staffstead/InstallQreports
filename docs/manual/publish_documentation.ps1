[CmdletBinding()]
param(
    [string]$InstallRepository = "C:\temp\qrep\InstallQreportsRepo",
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
$solutionRoot = Split-Path -Parent $PSScriptRoot
$configFile = Join-Path $solutionRoot "mkdocs.yml"
$targetDocs = Join-Path $InstallRepository "docs"
$targetManual = Join-Path $targetDocs "manual"
$landingPage = Join-Path $PSScriptRoot "site-root\index.html"
$localPython = Join-Path $solutionRoot ".venv-docs\Scripts\python.exe"

if (-not (Test-Path -LiteralPath $localPython)) {
    throw "Documentation environment not found. Run '.\documentation\setup_documentation.ps1' first."
}

if (-not (Test-Path -LiteralPath (Join-Path $InstallRepository ".git"))) {
    throw "InstallQreports repository not found at '$InstallRepository'. Run the installer publish script once so it is cloned."
}

Push-Location $InstallRepository
try {
    git pull --rebase origin main
    if ($LASTEXITCODE -ne 0) { throw "Could not update the InstallQreports repository." }
}
finally {
    Pop-Location
}

New-Item -ItemType Directory -Force -Path $targetDocs | Out-Null

& $localPython -m mkdocs build --clean --config-file $configFile --site-dir $targetManual
if ($LASTEXITCODE -ne 0) {
    throw "MkDocs build failed. Run 'py -m pip install -r requirements-docs.txt' from the solution folder."
}

Copy-Item -LiteralPath $landingPage -Destination (Join-Path $targetDocs "index.html") -Force
New-Item -ItemType File -Force -Path (Join-Path $targetDocs ".nojekyll") | Out-Null

Push-Location $InstallRepository
try {
    git add -- "docs/manual" "docs/index.html" "docs/.nojekyll"
    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "No documentation changes to publish."
        return
    }

    git commit -m "update QReports documentation"
    if ($LASTEXITCODE -ne 0) { throw "Could not commit documentation changes." }

    if (-not $NoPush) {
        git push origin main
        if ($LASTEXITCODE -ne 0) { throw "Could not push documentation changes." }
    }
}
finally {
    Pop-Location
}

Write-Host "Documentation published successfully."
