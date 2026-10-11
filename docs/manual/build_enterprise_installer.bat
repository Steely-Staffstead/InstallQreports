@echo off
setlocal

if "%~1"=="" goto :usage
set "VERSION=%~1"
set "REPO=%~dp0.."
rem Keep Windows PowerShell from loading incompatible PowerShell 7 modules
rem inherited from a developer shell.
set "PSModulePath=%ProgramFiles%\WindowsPowerShell\Modules;%SystemRoot%\system32\WindowsPowerShell\v1.0\Modules"

echo ====================================
echo Build Qvitr Enterprise %VERSION%
echo ====================================

pushd "%REPO%"
if errorlevel 1 goto :fail

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File ".\xlQRep.Setup\build-enterprise.ps1" -Version "%VERSION%"
if errorlevel 1 goto :fail_popd

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File ".\xlQRep.Setup\prepare-github-release.ps1" -Version "%VERSION%"
if errorlevel 1 goto :fail_popd

popd
echo.
echo Installer built, signed, and staged in:
echo %REPO%\xlQRep.Setup\artifacts\release\v%VERSION%
exit /b 0

:usage
echo Usage: %~nx0 VERSION
echo Example: %~nx0 12.0.2
exit /b 2

:fail_popd
popd
:fail
echo Enterprise installer build failed.
exit /b 1
