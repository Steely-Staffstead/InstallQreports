param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $Version,
    [Parameter(Mandatory = $true)]
    [string] $ArtifactDirectory,
    [switch] $Draft,
    [switch] $ValidateOnly
)

$ErrorActionPreference = 'Stop'
$resolved = [IO.Path]::GetFullPath($ArtifactDirectory)
$setup = Join-Path $resolved 'Qvitr-enterprise-setup.exe'
$msi = Join-Path $resolved 'Qvitr-enterprise.msi'
$hashes = Join-Path $resolved 'SHA256SUMS.txt'
$notes = Join-Path $resolved 'RELEASE_NOTES.md'
$publicCertificate = Join-Path $resolved 'Qvitr-Internal-Code-Signing.cer'
$trustScript = Join-Path $resolved 'trust-qvitr-internal-certificate.ps1'
$updateManifest = Join-Path $resolved 'qvitr-update.json'

foreach ($file in @($setup, $msi, $hashes, $notes, $publicCertificate, $trustScript, $updateManifest)) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing release file: $file" }
}
$manifest = Get-Content -LiteralPath $updateManifest -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or [string]::IsNullOrWhiteSpace($manifest.applicationVersion) -or
    $manifest.installerVersion -ne $Version -or [string]::IsNullOrWhiteSpace($manifest.downloadUrl) -or
    $manifest.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
    throw 'qvitr-update.json is incomplete or does not match the release version.'
}
$actualSetupHash = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash
if ($actualSetupHash -ne $manifest.sha256) {
    throw 'qvitr-update.json does not contain the SHA-256 hash of Qvitr-enterprise-setup.exe.'
}
$expectedCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($publicCertificate)
foreach ($file in @($setup, $msi)) {
    $signature = Get-AuthenticodeSignature -LiteralPath $file
    if ($signature.Status -ne 'Valid') {
        throw "Refusing to upload an unsigned or invalid package: $file ($($signature.Status))"
    }
    if ($signature.SignerCertificate.Thumbprint -ne $expectedCertificate.Thumbprint) {
        throw "Refusing to upload a package signed by an unexpected certificate: $file"
    }
}

foreach ($line in Get-Content -LiteralPath $hashes) {
    if ($line -notmatch '^([0-9a-fA-F]{64})\s{2}([^\\/]+)$') {
        throw "Invalid SHA256SUMS entry: $line"
    }
    $expectedHash = $Matches[1]
    $fileName = $Matches[2]
    $hashedFile = Join-Path $resolved $fileName
    if (-not (Test-Path -LiteralPath $hashedFile -PathType Leaf)) {
        throw "SHA256SUMS references a missing file: $fileName"
    }
    $actualHash = (Get-FileHash -LiteralPath $hashedFile -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        throw "SHA256 mismatch for $fileName. Prepare the release again before uploading."
    }
}

if ($ValidateOnly) {
    Write-Host "Enterprise release v$Version is valid and ready to upload from: $resolved"
    return
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is not installed. Install it, then run gh auth login.'
}

$repository = 'Steely-Staffstead/InstallQreports'
$tag = "v$Version"
$assets = @($setup, $msi, $hashes, $publicCertificate, $trustScript, $updateManifest)

$previousErrorActionPreference = $ErrorActionPreference
try {
    # A missing release is the expected result on the first publish. GitHub CLI
    # writes that result to stderr, which would otherwise become terminating
    # because this script uses ErrorActionPreference = Stop.
    $ErrorActionPreference = 'SilentlyContinue'
    & gh release view $tag --repo $repository *> $null
    $releaseViewExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
$releaseExists = $releaseViewExitCode -eq 0
if ($releaseExists) {
    & gh release upload $tag @assets --repo $repository --clobber
    if ($LASTEXITCODE -ne 0) { throw "GitHub release asset update failed with exit code $LASTEXITCODE." }
    & gh release edit $tag --repo $repository --title "Qvitr Enterprise $Version" --notes-file $notes
    if ($LASTEXITCODE -ne 0) { throw "GitHub release-note update failed with exit code $LASTEXITCODE." }
    Write-Host "Updated installer assets on existing GitHub release $tag."
    return
}

$arguments = @('release', 'create', $tag) + $assets + @(
    '--repo', $repository,
    '--title', "Qvitr Enterprise $Version",
    '--notes-file', $notes
)
if ($Draft) { $arguments += '--draft' }

& gh @arguments
if ($LASTEXITCODE -ne 0) { throw "GitHub release upload failed with exit code $LASTEXITCODE." }
