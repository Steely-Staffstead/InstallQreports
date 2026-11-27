param(
    [Parameter(Mandatory = $true)][string] $InstalledRoot,
    [Parameter(Mandatory = $true)][string] $SourceRoot,
    [Parameter(Mandatory = $true)][string] $SampleQanvas,
    [string] $ProofPath,
    [int] $LaunchTimeoutSeconds = 25,
    [switch] $SkipLaunch,
    [switch] $SkipBrowserSmoke
)

$ErrorActionPreference = 'Stop'
function Get-RelativePath([string] $Base, [string] $Target) {
    $baseUri = [Uri](([IO.Path]::GetFullPath($Base).TrimEnd('\') + '\'))
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri([Uri][IO.Path]::GetFullPath($Target)).ToString()).Replace('/', '\')
}
$installed = [IO.Path]::GetFullPath($InstalledRoot)
$source = [IO.Path]::GetFullPath($SourceRoot)
$sample = [IO.Path]::GetFullPath($SampleQanvas)
$manifestPath = Join-Path $installed 'qvitr-release-assets.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Release manifest is missing: $manifestPath" }
if (-not (Test-Path -LiteralPath $sample -PathType Leaf)) { throw "Sample Qanvas is missing: $sample" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or -not $manifest.releaseVersion) { throw 'Unsupported or incomplete release asset manifest.' }

$declared = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $manifest.files) {
    $relative = [string]$entry.path
    if ([IO.Path]::IsPathRooted($relative) -or $relative.Contains('..')) { throw "Unsafe manifest path: $relative" }
    [void]$declared.Add($relative.Replace('\', '/'))
    $file = Join-Path $installed $relative
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Installed asset is missing: $relative" }
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $entry.sha256 -or (Get-Item -LiteralPath $file).Length -ne $entry.bytes) {
        throw "Installed asset does not match its release manifest: $relative"
    }
}

$actualAssets = Get-ChildItem -LiteralPath (Join-Path $installed 'web'), (Join-Path $installed 'chartweb-web') -Recurse -File |
    ForEach-Object { (Get-RelativePath $installed $_.FullName).Replace('\', '/') }
foreach ($relative in $actualAssets) {
    if (-not $declared.Contains($relative)) { throw "Installed payload has an undeclared web asset: $relative" }
}

foreach ($mapping in @(@('CanvasWeb\web', 'web'), @('ChartWeb\web', 'chartweb-web'))) {
    $sourceWeb = Join-Path $source $mapping[0]
    $installedWeb = Join-Path $installed $mapping[1]
    foreach ($sourceFile in Get-ChildItem -LiteralPath $sourceWeb -Recurse -File) {
        $relative = Get-RelativePath $sourceWeb $sourceFile.FullName
        $deployedFile = Join-Path $installedWeb $relative
        if (-not (Test-Path -LiteralPath $deployedFile -PathType Leaf)) { throw "Source web asset was not deployed: $($mapping[1])/$relative" }
        if ((Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $deployedFile -Algorithm SHA256).Hash) {
            throw "Stale deployed web asset: $($mapping[1])/$relative"
        }
    }
}

$exe = Join-Path $installed 'QanvasWeb.exe'
$actualVersion = (Get-Item -LiteralPath $exe).VersionInfo.FileVersion
if ($manifest.executableVersion -and $actualVersion -ne $manifest.executableVersion) {
    throw "Executable version mismatch. Manifest: $($manifest.executableVersion); installed: $actualVersion"
}

if (-not $SkipLaunch) {
    $profileRoot = Join-Path ([IO.Path]::GetTempPath()) ("qvitr-release-proof-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $profileRoot | Out-Null
    $oldWebView = $env:WEBVIEW2_USER_DATA_FOLDER
    try {
        $env:WEBVIEW2_USER_DATA_FOLDER = $profileRoot
        foreach ($probe in @(
            @{ Name = 'Settings'; Arguments = @('--settings'); Title = 'settings' },
            @{ Name = 'Query'; Arguments = @('--query-workspace'); Title = 'Query Workspace' },
            @{ Name = 'Measures'; Arguments = @('--measure-workspace'); Title = 'Measures' },
            @{ Name = 'API'; Arguments = @('--api-workspace'); Title = 'API Workspace' },
            @{ Name = 'Sample Qanvas'; Arguments = @($sample); Title = 'Qanvas' }
        )) {
            $process = Start-Process -FilePath $exe -ArgumentList $probe.Arguments -WorkingDirectory $installed -PassThru -WindowStyle Hidden
            try {
                $deadline = [DateTime]::UtcNow.AddSeconds($LaunchTimeoutSeconds)
                do {
                    Start-Sleep -Milliseconds 250
                    $process.Refresh()
                    if ($process.HasExited) { throw "$($probe.Name) exited before its window was ready (exit code $($process.ExitCode))." }
                } until (($process.MainWindowHandle -ne 0 -and $process.MainWindowTitle -match $probe.Title) -or [DateTime]::UtcNow -ge $deadline)
                if ($process.MainWindowHandle -eq 0 -or $process.MainWindowTitle -notmatch $probe.Title) {
                    throw "$($probe.Name) did not open the expected window within $LaunchTimeoutSeconds seconds. Last title: '$($process.MainWindowTitle)'"
                }
                Write-Host "Launch passed: $($probe.Name) [$($process.MainWindowTitle)]"
            } finally {
                if (-not $process.HasExited) {
                    & taskkill.exe /PID $process.Id /T /F | Out-Null
                    $process.WaitForExit(5000) | Out-Null
                }
            }
        }
    } finally {
        $env:WEBVIEW2_USER_DATA_FOLDER = $oldWebView
        if (Test-Path -LiteralPath $profileRoot) {
            $profileRemoved = $false
            for ($attempt = 1; $attempt -le 10 -and -not $profileRemoved; $attempt++) {
                try {
                    Remove-Item -LiteralPath $profileRoot -Recurse -Force -ErrorAction Stop
                    $profileRemoved = $true
                } catch {
                    if ($attempt -lt 10) { Start-Sleep -Milliseconds 500 }
                }
            }
            if (-not $profileRemoved) {
                Write-Warning "Could not remove the temporary WebView2 profile '$profileRoot' because a WebView2 process still has a file open. Validation results are unaffected."
            }
        }
    }
}

if (-not $SkipBrowserSmoke) {
    $smoke = Join-Path $source 'CanvasWeb\tests\tools\installed-release-proof.cjs'
    & node $smoke --installed-root $installed --sample $sample
    if ($LASTEXITCODE -ne 0) { throw "Installed UI release proof failed with exit code $LASTEXITCODE." }
}

if ($ProofPath) {
    $proof = [ordered]@{
        schemaVersion = 1
        status = 'passed'
        releaseVersion = $manifest.releaseVersion
        executableVersion = $actualVersion
        verifiedUtc = [DateTime]::UtcNow.ToString('o')
        installedRoot = $installed
        sampleQanvas = $sample
        assetCount = @($manifest.files).Count
        checks = [ordered]@{
            manifestHashes = $true
            sourceWebParity = $true
            cleanProfileLaunch = -not $SkipLaunch
            settings = -not $SkipLaunch
            presentationSettings = -not $SkipBrowserSmoke
            queryWorkspace = (-not $SkipLaunch) -and (-not $SkipBrowserSmoke)
            measuresWorkspace = (-not $SkipLaunch) -and (-not $SkipBrowserSmoke)
            apiWorkspace = (-not $SkipLaunch) -and (-not $SkipBrowserSmoke)
            sampleOpenAndRefresh = -not $SkipBrowserSmoke
            creatorAndViewerModes = -not $SkipBrowserSmoke
        }
    }
    $proofDirectory = Split-Path -Parent ([IO.Path]::GetFullPath($ProofPath))
    if ($proofDirectory) { New-Item -ItemType Directory -Path $proofDirectory -Force | Out-Null }
    $proof | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ProofPath -Encoding utf8
    Write-Host "Release proof written: $ProofPath"
}

Write-Host "Qvitr installed release proof passed for version $($manifest.releaseVersion)."

