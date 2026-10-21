param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $Version,
    [switch] $ValidateOnly,
    [switch] $SkipBuild,
    [switch] $Draft
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$setupRoot = Join-Path $repositoryRoot 'xlQRep.Setup'
$artifactRoot = Join-Path $setupRoot 'artifacts'
$releaseRoot = Join-Path $artifactRoot (Join-Path 'release' "v$Version")
$buildScript = Join-Path $setupRoot 'build-enterprise.ps1'
$prepareScript = Join-Path $setupRoot 'prepare-github-release.ps1'
$checkScript = Join-Path $PSScriptRoot 'check_enterprise_installer_version.ps1'
$uploadScript = Join-Path $setupRoot 'github-distribution\upload-enterprise-release.ps1'

foreach ($script in @($buildScript, $prepareScript, $checkScript, $uploadScript)) {
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
        throw "Required release script was not found: $script"
    }
}

if (-not $ValidateOnly) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'GitHub CLI (gh) is not installed. Install it and run gh auth login before publishing.'
    }
    & gh auth status --hostname github.com
    if ($LASTEXITCODE -ne 0) {
        throw 'GitHub CLI is not authenticated. Run gh auth login, then retry.'
    }
}

Write-Host '===================================='
Write-Host "Qvitr Enterprise GitHub release v$Version"
Write-Host '===================================='

Push-Location $repositoryRoot
try {
    if (-not $SkipBuild) {
        Write-Host ''
        Write-Host 'Step 1/3: Build and sign the enterprise installer'
        & $buildScript -Version $Version
        if (-not $?) { throw 'Enterprise installer build failed.' }
    }
    else {
        Write-Host ''
        Write-Host 'Step 1/3: Reuse the existing signed installer artifacts (-SkipBuild)'
    }

    Write-Host ''
    Write-Host 'Step 2/3: Stage and validate the release'
    & $prepareScript -Version $Version
    if (-not $?) { throw 'Enterprise release staging failed.' }
    & $checkScript -Version $Version
    if (-not $?) { throw 'Enterprise release validation failed.' }

    if ($ValidateOnly) {
        Write-Host ''
        Write-Host "Validation completed. Nothing was uploaded: $releaseRoot"
        return
    }

    Write-Host ''
    Write-Host 'Step 3/3: Upload installer and update manifest to GitHub Releases'
    $uploadArguments = @{
        Version = $Version
        ArtifactDirectory = $releaseRoot
    }
    if ($Draft) { $uploadArguments.Draft = $true }
    & $uploadScript @uploadArguments
    if (-not $?) { throw 'GitHub release upload failed.' }

    Write-Host ''
    Write-Host "GitHub release: https://github.com/Steely-Staffstead/InstallQreports/releases/tag/v$Version"
    Write-Host 'Manual update manifest: https://github.com/Steely-Staffstead/InstallQreports/releases/latest/download/qvitr-update.json'
}
finally {
    Pop-Location
}
