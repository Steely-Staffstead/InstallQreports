@echo off
setlocal

if "%~1"=="" goto :usage
set "VERSION=%~1"
set "MODE=%~2"
set "REPO=%~dp0.."
set "RELEASE_DIR=%REPO%\xlQRep.Setup\artifacts\release\v%VERSION%"
rem Keep Windows PowerShell from loading incompatible PowerShell 7 modules
rem inherited from a developer shell.
set "PSModulePath=%ProgramFiles%\WindowsPowerShell\Modules;%SystemRoot%\system32\WindowsPowerShell\v1.0\Modules"

if /I not "%MODE%"=="" if /I not "%MODE%"=="--validate-only" goto :usage

pushd "%REPO%"
if errorlevel 1 goto :fail

rem Refresh the staged folder and refuse a version that does not match the build.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File ".\xlQRep.Setup\prepare-github-release.ps1" -Version "%VERSION%"
if errorlevel 1 goto :fail_popd

if /I "%MODE%"=="--validate-only" (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File ".\xlQRep.Setup\github-distribution\upload-enterprise-release.ps1" -Version "%VERSION%" -ArtifactDirectory "%RELEASE_DIR%" -ValidateOnly
) else (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File ".\xlQRep.Setup\github-distribution\upload-enterprise-release.ps1" -Version "%VERSION%" -ArtifactDirectory "%RELEASE_DIR%"
)
if errorlevel 1 goto :fail_popd

popd
exit /b 0

:usage
echo Usage: %~nx0 VERSION [--validate-only]
echo Example: %~nx0 12.0.2 --validate-only
echo Example: %~nx0 12.0.2
exit /b 2

:fail_popd
popd
:fail
echo Enterprise installer publish failed.
exit /b 1
