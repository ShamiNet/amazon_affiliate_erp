@echo off
cd /d "%~dp0"
title Amazon Affiliate ERP - Instant Windows App Launcher
echo Launching Amazon Affiliate ERP Windows Desktop Application...
where msedge >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    start "" msedge --app="file:///%~dp0Amazon_ERP_Windows_Desktop.html" --window-size=1440,900
    exit /b 0
)
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
    start "" "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" --app="file:///%~dp0Amazon_ERP_Windows_Desktop.html" --window-size=1440,900
    exit /b 0
)
if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" (
    start "" "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" --app="file:///%~dp0Amazon_ERP_Windows_Desktop.html" --window-size=1440,900
    exit /b 0
)
start "" "%~dp0Amazon_ERP_Windows_Desktop.html"
