param(
    [Parameter(Mandatory = $true)][string] $PayloadRoot,
    [Parameter(Mandatory = $true)][string] $Version
)

$ErrorActionPreference = 'Stop'
function Get-RelativePath([string] $Base, [string] $Target) {
    $baseUri = [Uri](([IO.Path]::GetFullPath($Base).TrimEnd('\') + '\'))
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri([Uri][IO.Path]::GetFullPath($Target)).ToString()).Replace('/', '\')
}
$payload = [IO.Path]::GetFullPath($PayloadRoot)
$canvasRoot = Join-Path $payload 'CanvasWeb'
if (-not (Test-Path -LiteralPath $canvasRoot -PathType Container)) {
    throw "CanvasWeb payload was not found: $canvasRoot"
}

$manifestPath = Join-Path $canvasRoot 'qvitr-release-assets.json'
$files = Get-ChildItem -LiteralPath $canvasRoot -Recurse -File | Where-Object {
    $_.FullName -ne $manifestPath -and (
        $_.FullName.StartsWith((Join-Path $canvasRoot 'web') + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $_.FullName.StartsWith((Join-Path $canvasRoot 'chartweb-web') + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $_.Name -in @('QanvasWeb.exe', 'QanvasWeb.dll', 'QanvasWeb.deps.json', 'QanvasWeb.runtimeconfig.json', 'ChartWeb.exe', 'ChartWeb.dll', 'ChartWeb.deps.json', 'ChartWeb.runtimeconfig.json')
    )
} | Sort-Object FullName

if (-not $files -or -not ($files.Name -contains 'QanvasWeb.exe')) {
    throw 'The payload is incomplete; QanvasWeb.exe and its web assets must exist before creating the release manifest.'
}

$entries = foreach ($file in $files) {
    [ordered]@{
        path = (Get-RelativePath $canvasRoot $file.FullName).Replace('\', '/')
        bytes = $file.Length
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$exe = Get-Item -LiteralPath (Join-Path $canvasRoot 'QanvasWeb.exe')
$manifest = [ordered]@{
    schemaVersion = 1
    releaseVersion = $Version
    executableVersion = $exe.VersionInfo.FileVersion
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    files = @($entries)
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Host "Release asset manifest created: $manifestPath ($($entries.Count) files)"

