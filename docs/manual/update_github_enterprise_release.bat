@echo off
setlocal EnableExtensions

if "%~1"=="" goto :usage
set "UPDATE_SCRIPT=%~dp0update_github_enterprise_release.ps1"
set "VERSION=%~1"
shift
set "PS_SWITCHES="

:parse
if "%~1"=="" goto :run
if /I "%~1"=="--validate-only" (
    set "PS_SWITCHES=%PS_SWITCHES% -ValidateOnly"
    shift
    goto :parse
)
if /I "%~1"=="--skip-build" (
    set "PS_SWITCHES=%PS_SWITCHES% -SkipBuild"
    shift
    goto :parse
)
if /I "%~1"=="--draft" (
    set "PS_SWITCHES=%PS_SWITCHES% -Draft"
    shift
    goto :parse
)
goto :usage

:run
rem Keep Windows PowerShell from loading incompatible PowerShell 7 modules
rem inherited from a developer shell.
set "PSModulePath=%ProgramFiles%\WindowsPowerShell\Modules;%SystemRoot%\system32\WindowsPowerShell\v1.0\Modules"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%UPDATE_SCRIPT%" -Version "%VERSION%" %PS_SWITCHES%
exit /b %ERRORLEVEL%

:usage
echo Usage: %~nx0 VERSION [--validate-only] [--skip-build] [--draft]
echo.
echo Build, sign, stage, validate, and upload:
echo   %~nx0 12.0.2
echo.
echo Build and validate without uploading:
echo   %~nx0 12.0.2 --validate-only
echo.
echo Reuse already-built artifacts and upload them:
echo   %~nx0 12.0.2 --skip-build
exit /b 2
