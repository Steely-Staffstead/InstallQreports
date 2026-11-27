[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{4}\.\d{1,2}\.\d{1,2}\.\d+$')]
    [string] $ApplicationVersion,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $InstallerVersion
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Read-VersionedFile {
    param([Parameter(Mandatory = $true)][string] $Path)

    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $bytes = [System.IO.File]::ReadAllBytes($resolved)
    $hasUtf8Bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    [pscustomobject]@{
        Path = $resolved
        Content = [System.IO.File]::ReadAllText($resolved)
        Encoding = [System.Text.UTF8Encoding]::new($hasUtf8Bom)
    }
}

function Replace-SingleMatch {
    param(
        [Parameter(Mandatory = $true)][string] $Content,
        [Parameter(Mandatory = $true)][string] $Pattern,
        [Parameter(Mandatory = $true)][string] $Replacement,
        [Parameter(Mandatory = $true)][string] $Description
    )

    $matches = [regex]::Matches($Content, $Pattern)
    if ($matches.Count -ne 1) {
        throw "Expected exactly one $Description; found $($matches.Count)."
    }
    return [regex]::Replace($Content, $Pattern, $Replacement, 1)
}

function ConvertTo-Version {
    param([Parameter(Mandatory = $true)][string] $Value)
    return [Version]::Parse($Value)
}

$sourceFiles = @(
    @{ Path = Join-Path $repositoryRoot 'CanvasWeb\CanvasWeb.csproj'; Pattern = '<FileVersion>(?<version>\d+\.\d+\.\d+\.\d+)</FileVersion>'; Replacement = "<FileVersion>$ApplicationVersion</FileVersion>" },
    @{ Path = Join-Path $repositoryRoot 'CanvasWeb.LegacyBridge\CanvasWeb.LegacyBridge.vbproj'; Pattern = '<FileVersion>(?<version>\d+\.\d+\.\d+\.\d+)</FileVersion>'; Replacement = "<FileVersion>$ApplicationVersion</FileVersion>" },
    @{ Path = Join-Path $repositoryRoot 'xlQAddin\My Project\AssemblyInfo.vb'; Pattern = '<Assembly:\s*AssemblyFileVersion\("(?<version>\d+\.\d+\.\d+\.\d+)"\)>'; Replacement = "<Assembly: AssemblyFileVersion(`"$ApplicationVersion`")>" },
    @{ Path = Join-Path $repositoryRoot 'xlquerycode\My Project\AssemblyInfo.vb'; Pattern = '<Assembly:\s*AssemblyFileVersion\("(?<version>\d+\.\d+\.\d+\.\d+)"\)>'; Replacement = "<Assembly: AssemblyFileVersion(`"$ApplicationVersion`")>" }
)

$updates = @()
$currentApplicationVersions = @()
foreach ($definition in $sourceFiles) {
    $file = Read-VersionedFile $definition.Path
    $matches = [regex]::Matches($file.Content, $definition.Pattern)
    if ($matches.Count -ne 1) {
        throw "Expected exactly one application file version in '$($file.Path)'; found $($matches.Count)."
    }
    $currentApplicationVersions += $matches[0].Groups['version'].Value
    $updated = [regex]::Replace($file.Content, $definition.Pattern, $definition.Replacement, 1)
    $updates += [pscustomobject]@{ File = $file; Content = $updated }
}

$distinctApplicationVersions = @($currentApplicationVersions | Sort-Object -Unique)
if ($distinctApplicationVersions.Count -ne 1) {
    throw "Application versions are not synchronized: $($distinctApplicationVersions -join ', ')."
}
$currentApplicationVersion = $distinctApplicationVersions[0]
if ((ConvertTo-Version $ApplicationVersion) -le (ConvertTo-Version $currentApplicationVersion)) {
    throw "ApplicationVersion must be newer than $currentApplicationVersion."
}

$developmentFile = Read-VersionedFile (Join-Path $repositoryRoot 'xlquerycode\development_info.md')
$legacyMarker = '## CLICKONCE INSTALLATION ' + [char]0x2014 + ' LEGACY / NOT USED'
$legacyIndex = $developmentFile.Content.IndexOf($legacyMarker, [StringComparison]::Ordinal)
if ($legacyIndex -lt 0) {
    throw "Could not find the ClickOnce legacy marker in '$($developmentFile.Path)'."
}
$activeDocumentation = $developmentFile.Content.Substring(0, $legacyIndex)
$legacyDocumentation = $developmentFile.Content.Substring($legacyIndex)

$installerMatch = [regex]::Match($activeDocumentation, '- Windows Installer version: `(?<version>\d+\.\d+\.\d+)`')
if (-not $installerMatch.Success) {
    throw 'Could not find the current Windows Installer version in development_info.md.'
}
$currentInstallerVersion = $installerMatch.Groups['version'].Value
if ((ConvertTo-Version $InstallerVersion) -le (ConvertTo-Version $currentInstallerVersion)) {
    throw "InstallerVersion must be newer than $currentInstallerVersion."
}

$nextInstaller = ConvertTo-Version $InstallerVersion
$nextInstallerVersion = '{0}.{1}.{2}' -f $nextInstaller.Major, $nextInstaller.Minor, ($nextInstaller.Build + 1)
$reviewedDate = [DateTime]::Now.ToString('d MMMM yyyy', [Globalization.CultureInfo]::InvariantCulture)

$activeDocumentation = Replace-SingleMatch $activeDocumentation '(?m)^## Current Qvitris package \u2014 reviewed .+$' ("## Current Qvitris package " + [char]0x2014 + " reviewed $reviewedDate") 'reviewed date heading'
$activeDocumentation = $activeDocumentation.Replace($currentApplicationVersion, $ApplicationVersion)
$activeDocumentation = $activeDocumentation.Replace($currentInstallerVersion, $InstallerVersion)
$activeDocumentation = Replace-SingleMatch $activeDocumentation '(?m)^- Previous local installer version: `\d+\.\d+\.\d+`\r?$' "- Previous local installer version: ``$currentInstallerVersion``" 'previous installer version line'
$activeDocumentation = Replace-SingleMatch $activeDocumentation 'The local `v\d+\.\d+\.\d+` release manifest contains application version\r?\n`\d+\.\d+\.\d+\.\d+`, so the prepared' "The local ``v$currentInstallerVersion`` release manifest contains application version`r`n``$currentApplicationVersion``, so the prepared" 'previous release comparison'
$activeDocumentation = Replace-SingleMatch $activeDocumentation '(?:For example, after|After) publishing `\d+\.\d+\.\d+`, use `\d+\.\d+\.\d+`\.' "After publishing ``$InstallerVersion``, use ``$nextInstallerVersion``." 'next installer example'

$updates += [pscustomobject]@{
    File = $developmentFile
    Content = $activeDocumentation + $legacyDocumentation
}

$summary = "Application $currentApplicationVersion -> $ApplicationVersion; installer $currentInstallerVersion -> $InstallerVersion"
if ($PSCmdlet.ShouldProcess('Qvitris source versions and development_info.md', $summary)) {
    foreach ($update in $updates) {
        [System.IO.File]::WriteAllText($update.File.Path, $update.Content, $update.File.Encoding)
    }
    Write-Host "Updated $summary"
    Write-Host 'Next build command:'
    Write-Host ".\xlQRep.Setup\build-enterprise.ps1 -Version $InstallerVersion"
}
else {
    Write-Host "Preview: $summary"
}
