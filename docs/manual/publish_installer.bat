@echo off
setlocal

set "SOURCE=C:\temp\qrep\publish"
set "REPO=C:\temp\qrep\InstallQreportsRepo"
set "TARGET=%REPO%\docs"
set "REMOTE=https://github.com/Steely-Staffstead/InstallQreports.git"

echo ====================================
echo Sync QReports installer to GitHub
echo ====================================

if not exist "%SOURCE%" (
    echo ERROR: Publish folder not found: %SOURCE%
    pause
    exit /b 1
)

if not exist "%REPO%\.git" (
    echo Cloning repository...
    git clone "%REMOTE%" "%REPO%"
    if errorlevel 1 goto :fail
)

cd /d "%REPO%"
if errorlevel 1 goto :fail

echo Pulling latest changes...
git pull --rebase origin main
if errorlevel 1 goto :fail

if not exist "%TARGET%" mkdir "%TARGET%"

echo Removing the previous ClickOnce payload...
if exist "%TARGET%\Application Files" rmdir /s /q "%TARGET%\Application Files"
if exist "%TARGET%\script" rmdir /s /q "%TARGET%\script"
del /q "%TARGET%\setup.exe" 2>nul
del /q "%TARGET%\xlQAddin.vsto" 2>nul

echo Copying the new ClickOnce payload...
robocopy "%SOURCE%" "%TARGET%" /E /R:2 /W:2 /XD "%SOURCE%\script" /XF "index.html" "qreports.cer"
set RC=%ERRORLEVEL%
if %RC% GEQ 8 goto :fail

rem Stage only installer artifacts. docs\manual and the landing page are
rem maintained by documentation\publish_documentation.ps1.
git add -A -- "docs/Application Files" "docs/setup.exe" "docs/xlQAddin.vsto" "docs/script"
if errorlevel 1 goto :fail

git diff --cached --quiet
if %ERRORLEVEL%==0 (
    echo No installer changes to commit.
    goto :done
)

git commit -m "update published installer"
if errorlevel 1 goto :fail

git push origin main
if errorlevel 1 goto :fail

:done
echo Installer published. Documentation was preserved.
pause
exit /b 0

:fail
echo Installer publish failed.
pause
exit /b 1

