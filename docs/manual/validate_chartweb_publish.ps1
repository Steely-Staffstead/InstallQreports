param(
    [Parameter(Mandatory = $true)][string]$PublishRoot,
    [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
function Get-FileSha256([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return [System.BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}
$applicationFiles = Join-Path $PublishRoot 'Application Files'
$latest = Get-ChildItem -LiteralPath $applicationFiles -Directory -Filter 'xlQAddin_*' |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $latest) { throw "No ClickOnce application folder in $applicationFiles" }

$manifestPath = Join-Path $latest.FullName 'xlQAddin.dll.manifest'
[xml]$manifest = Get-Content -LiteralPath $manifestPath
$declared = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($file in $manifest.SelectNodes('//*[local-name()="file"]')) {
    [void]$declared.Add($file.GetAttribute('name'))
}

$payload = Join-Path $latest.FullName 'CanvasWeb'
$web = Join-Path $payload 'chartweb-web'
$required = @('ChartWeb.exe', 'ChartWeb.dll', 'ChartWeb.deps.json', 'ChartWeb.runtimeconfig.json')
$required += @('app.js', 'index.html', 'styles.css', 'chartweb-theme.css',
    'shared-settings.js', 'palette-model.js', 'chart-renderer.js', 'measure-evaluator.js') |
    ForEach-Object { "chartweb-web\$_" }

foreach ($relative in $required) {
    $manifestName = "CanvasWeb\$relative"
    if (-not $declared.Contains($manifestName)) { throw "Missing from ClickOnce manifest: $manifestName" }
    $plainPath = Join-Path $payload $relative
    $deployedPath = "$plainPath.deploy"
    if (-not (Test-Path -LiteralPath $plainPath) -and -not (Test-Path -LiteralPath $deployedPath)) {
        throw "Missing from ClickOnce payload: $manifestName"
    }
}

$indexPath = Join-Path $web 'index.html.deploy'
if (-not (Test-Path -LiteralPath $indexPath)) { $indexPath = Join-Path $web 'index.html' }
$index = Get-Content -LiteralPath $indexPath -Raw
$references = [regex]::Matches($index, '(?:src|href)="([^"?#]+\.(?:js|css))') |
    ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
foreach ($reference in $references) {
    $manifestName = "CanvasWeb\chartweb-web\$reference"
    if (-not $declared.Contains($manifestName)) { throw "ChartWeb index refers to an unlisted file: $reference" }
    $asset = Join-Path $web $reference
    if (-not (Test-Path -LiteralPath $asset) -and -not (Test-Path -LiteralPath "$asset.deploy")) {
        throw "ChartWeb index refers to a missing file: $reference"
    }
}

if ($SourceRoot) {
    $sourceMap = @{
        'ChartWeb.exe' = 'ChartWeb\bin\Release\net8.0-windows\ChartWeb.exe'
        'chartweb-web\app.js' = 'ChartWeb\web\app.js'
        'chartweb-web\index.html' = 'ChartWeb\web\index.html'
        'chartweb-web\styles.css' = 'ChartWeb\web\styles.css'
        'chartweb-web\chartweb-theme.css' = 'ChartWeb\web\chartweb-theme.css'
        'chartweb-web\shared-settings.js' = 'CanvasWeb\web\shared-settings.js'
        'chartweb-web\palette-model.js' = 'CanvasWeb\web\palette-model.js'
        'chartweb-web\chart-renderer.js' = 'CanvasWeb\web\chart-renderer.js'
        'chartweb-web\measure-evaluator.js' = 'CanvasWeb\web\measure-evaluator.js'
    }
    foreach ($relative in $sourceMap.Keys) {
        $source = Join-Path $SourceRoot $sourceMap[$relative]
        $published = Join-Path $payload $relative
        if (-not (Test-Path -LiteralPath $published)) { $published += '.deploy' }
        if (-not (Test-Path -LiteralPath $source)) { throw "Missing build source: $source" }
        $expected = Get-FileSha256 $source
        $actual = Get-FileSha256 $published
        if ($actual -ne $expected) { throw "Stale ChartWeb payload: $relative differs from $source" }
    }
}

Write-Host "ChartWeb ClickOnce assets and manifest verified: $($latest.Name)"
