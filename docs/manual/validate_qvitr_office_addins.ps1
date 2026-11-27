param(
    # Folder that contains xlQAddin.vsto and the PowerPoint folder of the installed product.
    [Parameter(Mandatory = $true)][string] $InstalledRoot,
    [switch] $SkipLaunch
)

# Installed smoke test for the Office integrations:
# 1. the Excel and PowerPoint add-ins are registered for the current user, load at startup and point to the
#    installed folder (not to a development build);
# 2. Excel and PowerPoint start invisibly and report the Qvitris add-in as connected.
# Office is closed again afterwards. Requires Excel and PowerPoint to be closed before the test.

$ErrorActionPreference = 'Stop'
$installed = [IO.Path]::GetFullPath($InstalledRoot).TrimEnd('\')
$failures = New-Object System.Collections.Generic.List[string]
$checks = @(
    @{ Application = 'Excel'; Key = 'xlQAddin'; Manifest = (Join-Path $installed 'xlQAddin.vsto'); ProgId = 'Excel.Application'; Process = 'EXCEL' },
    @{ Application = 'PowerPoint'; Key = 'QReportsPowerPointAddIn'; Manifest = (Join-Path $installed 'PowerPoint\QReportsPowerPointAddIn.vsto'); ProgId = 'PowerPoint.Application'; Process = 'POWERPNT' }
)

foreach ($check in $checks) {
    $name = $check.Application
    if (-not (Test-Path -LiteralPath $check.Manifest -PathType Leaf)) { $failures.Add("${name}: installed manifest is missing: $($check.Manifest)"); continue }
    $registryPath = "HKCU:\Software\Microsoft\Office\$name\Addins\$($check.Key)"
    if (-not (Test-Path -LiteralPath $registryPath)) { $failures.Add("${name}: add-in is not registered for the current user ($registryPath)"); continue }
    $registration = Get-ItemProperty -LiteralPath $registryPath
    if ([int]$registration.LoadBehavior -ne 3) { $failures.Add("${name}: LoadBehavior is $($registration.LoadBehavior), expected 3 (load at startup)") }
    $manifestPath = ([string]$registration.Manifest).Split('|')[0]
    if ($manifestPath -match '^file:') { $manifestPath = ([Uri]$manifestPath).LocalPath }
    if (-not $manifestPath -or [IO.Path]::GetFullPath($manifestPath) -ne [IO.Path]::GetFullPath($check.Manifest)) {
        $failures.Add("${name}: registration points to '$manifestPath' instead of the installed '$($check.Manifest)'")
    } else {
        Write-Host "Registration passed: $name -> $manifestPath"
    }

    if ($SkipLaunch) { continue }
    if (Get-Process -Name $check.Process -ErrorAction SilentlyContinue) { $failures.Add("${name}: close $name before running the launch check"); continue }
    $app = $null
    try {
        $app = New-Object -ComObject $check.ProgId
        $addin = $null
        for ($attempt = 0; $attempt -lt 40 -and -not $addin; $attempt++) {
            Start-Sleep -Milliseconds 500
            $addin = @($app.COMAddIns) | Where-Object { $_.ProgId -eq $check.Key } | Select-Object -First 1
        }
        if (-not $addin) { $failures.Add("${name}: the Qvitris add-in is not listed in COM add-ins") }
        elseif (-not $addin.Connect) { $failures.Add("${name}: the Qvitris add-in is listed but not connected (load failed)") }
        else { Write-Host "Launch passed: $name loaded '$($addin.Description)'" }
    } catch {
        $failures.Add("${name}: could not start for the add-in check: $($_.Exception.Message)")
    } finally {
        if ($app) { try { $app.Quit() } catch {} ; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($app) }
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        Start-Sleep -Seconds 2
        Get-Process -Name $check.Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -eq 0 } | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count) { $failures | ForEach-Object { Write-Host "FAILED: $_" }; throw "Office add-in validation failed ($($failures.Count) problem(s))." }
Write-Host 'Office add-in validation passed.'
