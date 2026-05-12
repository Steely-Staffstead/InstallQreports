@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM QReports Company Settings Installer
REM
REM Expected folder structure:
REM
REM   InstallCompanySettings.bat
REM   company\
REM       connections.json
REM       settings.json
REM       templates\
REM       api\
REM       ...
REM
REM This script copies everything inside .\company
REM to the user's QReports settings folder.
REM ============================================================

set "SCRIPT_DIR=%~dp0"
set "SOURCE_DIR=%SCRIPT_DIR%company"
set "TARGET_DIR=%LOCALAPPDATA%\QReports\settings"

echo.
echo QReports Company Settings Installer
echo ----------------------------------
echo Source:
echo   %SOURCE_DIR%
echo.
echo Target:
echo   %TARGET_DIR%
echo.

if not exist "%SOURCE_DIR%" (
    echo ERROR: Source folder not found:
    echo %SOURCE_DIR%
    echo.
    echo Make sure a folder named "company" exists next to this .bat file.
    pause
    exit /b 1
)

if not exist "%TARGET_DIR%" (
    echo Creating target folder...
    mkdir "%TARGET_DIR%"
    if errorlevel 1 (
        echo ERROR: Could not create target folder:
        echo %TARGET_DIR%
        pause
        exit /b 1
    )
)

echo Copying company settings...
echo.

robocopy "%SOURCE_DIR%" "%TARGET_DIR%" /E /R:2 /W:1

set "RC=%ERRORLEVEL%"

REM Robocopy exit codes 0-7 are normally success/warnings.
if %RC% GEQ 8 (
    echo.
    echo ERROR: Copy failed. Robocopy exit code: %RC%
    pause
    exit /b %RC%
)

echo.
echo Company settings installed successfully.
echo.
echo Files were copied to:
echo %TARGET_DIR%
echo.

pause
exit /b 0