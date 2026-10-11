[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectPath,
    [switch]$RevisionOnly
)

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = Join-Path $PSScriptRoot '..\xlQAddin\xlQAddin.vbproj'
}

$resolvedProject = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path
$content = [System.IO.File]::ReadAllText($resolvedProject)
$matches = [regex]::Matches($content, '<ApplicationVersion>(\d+)\.(\d+)\.(\d+)\.(\d+)</ApplicationVersion>')

if ($matches.Count -ne 1) {
    throw "Expected exactly one four-part ApplicationVersion in '$resolvedProject'; found $($matches.Count)."
}

$current = $matches[0]
$year = [int]$current.Groups[1].Value
$month = [int]$current.Groups[2].Value
$day = [int]$current.Groups[3].Value
$revision = [int]$current.Groups[4].Value

if ($RevisionOnly) {
    $newVersion = '{0}.{1:D2}.{2:D2}.{3}' -f $year, $month, $day, ($revision + 1)
}
else {
    $today = Get-Date
    $currentDate = (Get-Date -Year $year -Month $month -Day $day).Date
    $todayDate = $today.Date

    if ($todayDate -lt $currentDate) {
        throw "Today's date is earlier than the current version date. Use -RevisionOnly to keep the version increasing."
    }

    $nextRevision = if ($todayDate -eq $currentDate) { $revision + 1 } else { 0 }
    $newVersion = '{0}.{1:D2}.{2:D2}.{3}' -f $today.Year, $today.Month, $today.Day, $nextRevision
}

$oldVersion = '{0}.{1:D2}.{2:D2}.{3}' -f $year, $month, $day, $revision
$replacement = "<ApplicationVersion>$newVersion</ApplicationVersion>"
$updatedContent = $content.Remove($current.Index, $current.Length).Insert($current.Index, $replacement)
$updates = @(
    [pscustomobject]@{
        Path = $resolvedProject
        Content = $updatedContent
    }
)

$assemblyInfoPaths = @(
    (Join-Path $PSScriptRoot '..\xlQAddin\My Project\AssemblyInfo.vb'),
    (Join-Path $PSScriptRoot '..\xlquerycode\My Project\AssemblyInfo.vb')
)

foreach ($assemblyInfoPath in $assemblyInfoPaths) {
    $resolvedAssemblyInfo = (Resolve-Path -LiteralPath $assemblyInfoPath -ErrorAction Stop).Path
    $assemblyContent = [System.IO.File]::ReadAllText($resolvedAssemblyInfo)
    $fileVersionPattern = '<Assembly:\s*AssemblyFileVersion\("\d+\.\d+\.\d+\.\d+"\)>'

    if ([regex]::Matches($assemblyContent, $fileVersionPattern).Count -ne 1) {
        throw "Expected exactly one four-part AssemblyFileVersion in '$resolvedAssemblyInfo'."
    }

    $assemblyContent = [regex]::Replace(
        $assemblyContent,
        $fileVersionPattern,
        "<Assembly: AssemblyFileVersion(`"$newVersion`")>"
    )
    $updates += [pscustomobject]@{
        Path = $resolvedAssemblyInfo
        Content = $assemblyContent
    }
}

$canvasProjectPath = Join-Path $PSScriptRoot '..\CanvasWeb\CanvasWeb.csproj'
$resolvedCanvasProject = (Resolve-Path -LiteralPath $canvasProjectPath -ErrorAction Stop).Path
$canvasProjectContent = [System.IO.File]::ReadAllText($resolvedCanvasProject)
$canvasFileVersionPattern = '<FileVersion>\d+\.\d+\.\d+\.\d+</FileVersion>'

if ([regex]::Matches($canvasProjectContent, $canvasFileVersionPattern).Count -ne 1) {
    throw "Expected exactly one four-part FileVersion in '$resolvedCanvasProject'."
}

$canvasProjectContent = [regex]::Replace(
    $canvasProjectContent,
    $canvasFileVersionPattern,
    "<FileVersion>$newVersion</FileVersion>"
)
$updates += [pscustomobject]@{
    Path = $resolvedCanvasProject
    Content = $canvasProjectContent
}

if ($PSCmdlet.ShouldProcess('ClickOnce project, QRep assemblies, and Qanvas file version', "Change version from $oldVersion to $newVersion")) {
    foreach ($update in $updates) {
        $originalBytes = [System.IO.File]::ReadAllBytes($update.Path)
        $hasUtf8Bom = $originalBytes.Length -ge 3 -and
            $originalBytes[0] -eq 0xEF -and
            $originalBytes[1] -eq 0xBB -and
            $originalBytes[2] -eq 0xBF
        $encoding = New-Object System.Text.UTF8Encoding($hasUtf8Bom)
        [System.IO.File]::WriteAllText($update.Path, $update.Content, $encoding)
    }
    Write-Host "QRep version: $oldVersion -> $newVersion"
}
