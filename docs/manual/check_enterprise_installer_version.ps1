param(
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $Version
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$setupRoot = Join-Path $repositoryRoot 'xlQRep.Setup'
$artifactRoot = Join-Path $setupRoot 'artifacts'
$buildVersionFile = Join-Path $artifactRoot 'BUILD_VERSION.txt'

if (-not $Version) {
    if (-not (Test-Path -LiteralPath $buildVersionFile -PathType Leaf)) {
        throw "No current installer version was found. Build one with .\documentation\build_enterprise_installer.bat VERSION"
    }
    $Version = (Get-Content -LiteralPath $buildVersionFile -Raw).Trim()
}

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Invalid installer version: $Version"
}

$releaseRoot = Join-Path $artifactRoot (Join-Path 'release' "v$Version")
$setup = Join-Path $releaseRoot 'Qvitr-enterprise-setup.exe'
$msi = Join-Path $releaseRoot 'Qvitr-enterprise.msi'
$validator = Join-Path $setupRoot 'github-distribution\upload-enterprise-release.ps1'

foreach ($file in @($setup, $msi, $validator)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Missing installer file: $file"
    }
}

function ConvertTo-ThreePartVersion([string] $Value) {
    $parsed = [Version] $Value
    return '{0}.{1}.{2}' -f $parsed.Major, $parsed.Minor, [Math]::Max(0, $parsed.Build)
}

$setupInfo = (Get-Item -LiteralPath $setup).VersionInfo
$setupVersion = ConvertTo-ThreePartVersion $setupInfo.FileVersion

$windowsInstaller = New-Object -ComObject WindowsInstaller.Installer
$database = $null
$view = $null
$record = $null
try {
    $database = $windowsInstaller.OpenDatabase($msi, 0)
    $view = $database.OpenView("SELECT ``Value`` FROM ``Property`` WHERE ``Property``='ProductVersion'")
    $view.Execute()
    $record = $view.Fetch()
    if (-not $record) { throw 'The MSI does not contain a ProductVersion property.' }
    $msiVersion = ConvertTo-ThreePartVersion $record.StringData(1)
}
finally {
    if ($view) { $view.Close() }
    foreach ($comObject in @($record, $view, $database, $windowsInstaller)) {
        if ($comObject) { [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($comObject) }
    }
}

if ($setupVersion -ne $Version) {
    throw "Setup EXE version is $setupVersion, but the expected version is $Version."
}
if ($msiVersion -ne $Version) {
    throw "MSI ProductVersion is $msiVersion, but the expected version is $Version."
}

& $validator -Version $Version -ArtifactDirectory $releaseRoot -ValidateOnly
if (-not $?) {
    throw 'Installer validation failed.'
}

Write-Host ''
Write-Host 'Qvitr Enterprise installer'
Write-Host "Version:           $Version"
Write-Host "Setup file version: $setupVersion"
Write-Host "MSI ProductVersion: $msiVersion"
Write-Host "Release folder:     $releaseRoot"
Write-Host 'Status:             READY FOR UPLOAD'
