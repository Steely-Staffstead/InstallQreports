@echo off
setlocal

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0increment_clickonce_version.ps1" %*
exit /b %errorlevel%
