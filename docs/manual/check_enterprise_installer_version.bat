@echo off
setlocal

rem Keep Windows PowerShell from loading incompatible PowerShell 7 modules
rem inherited from a developer shell.
set "PSModulePath=%ProgramFiles%\WindowsPowerShell\Modules;%SystemRoot%\system32\WindowsPowerShell\v1.0\Modules"
set "SCRIPT=%~dp0check_enterprise_installer_version.ps1"

if "%~1"=="" (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
) else (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Version "%~1"
)

exit /b %ERRORLEVEL%
