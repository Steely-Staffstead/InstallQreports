@echo off
setlocal

set "SOURCE=C:\temp\qrep\publish"
set "REPO=C:\temp\qrep\InstallQreportsRepo"
set "TARGET=%REPO%\docs"
set "REMOTE=https://github.com/Steely-Staffstead/InstallQreports.git"

echo ====================================
echo Sync publish to InstallQreports/docs
echo ====================================

if not exist "%SOURCE%" (
    echo ERROR: Source folder not found:
    echo %SOURCE%
    pause
    exit /b 1
)

if not exist "%REPO%\.git" (
    echo Cloning repo...
    git clone "%REMOTE%" "%REPO%"
    if errorlevel 1 goto :fail
)

cd /d "%REPO%"
if errorlevel 1 goto :fail

echo Pulling latest changes...
git pull --rebase origin main
if errorlevel 1 goto :fail

if not exist "%TARGET%" mkdir "%TARGET%"

echo Cleaning docs contents...
for /d %%D in ("%TARGET%\*") do rmdir /s /q "%%~fD"
del /q "%TARGET%\*" 2>nul

echo Copying publish files to docs...
robocopy "%SOURCE%" "%TARGET%" /E /XD ".git" /R:2 /W:2
set RC=%ERRORLEVEL%
if %RC% GEQ 8 (
    echo Robocopy failed with code %RC%
    goto :fail
)

echo Staging changes...
git add -A
if errorlevel 1 goto :fail

git diff --cached --quiet
if %ERRORLEVEL%==0 (
    echo No changes to commit.
    goto :done
)

echo Committing...
git commit -m "update published installer"
if errorlevel 1 goto :fail

echo Pushing...
git push origin main
if errorlevel 1 goto :fail

:done
echo Done.
pause
exit /b 0

:fail
echo Script failed.
pause
exit /b 1