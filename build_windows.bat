@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
title Amazon Affiliate ERP - Flutter Windows Builder
echo ============================================================================
echo   Amazon Affiliate ERP - Flutter Windows Build and Launch Tool
echo ============================================================================
echo.

REM Check common Flutter installation paths if not in PATH
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    if exist "C:\src\flutter\bin\flutter.bat" set "PATH=%PATH%;C:\src\flutter\bin"
    if exist "C:\flutter\bin\flutter.bat" set "PATH=%PATH%;C:\flutter\bin"
    if exist "%USERPROFILE%\flutter\bin\flutter.bat" set "PATH=%PATH%;%USERPROFILE%\flutter\bin"
    if exist "%LOCALAPPDATA%\flutter\bin\flutter.bat" set "PATH=%PATH%;%LOCALAPPDATA%\flutter\bin"
)

where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [!] Flutter SDK was not found in your Windows PATH.
    echo [i] Launching the Instant Standalone Windows Desktop App instead...
    echo.
    call "%~dp0Run_App_Immediately.bat"
    exit /b 0
)

echo [1/4] Backing up application source code (lib/main.dart)...
copy /y "lib\main.dart" "lib\main.dart.bak" >nul
copy /y "pubspec.yaml" "pubspec.yaml.bak" >nul

echo [2/4] Generating complete Flutter Windows C++ runner files...
call flutter config --enable-windows-desktop >nul 2>nul
call flutter create --platforms=windows --project-name amazon_affiliate_erp .

echo [3/4] Restoring application source code and fetching packages...
copy /y "lib\main.dart.bak" "lib\main.dart" >nul
copy /y "pubspec.yaml.bak" "pubspec.yaml" >nul
del /q "lib\main.dart.bak" >nul 2>nul
del /q "pubspec.yaml.bak" >nul 2>nul
call flutter pub get

echo [4/4] Building Windows Release Executable (.exe)...
call flutter build windows --release

if exist "build\windows\x64\runner\Release\amazon_affiliate_erp.exe" (
    echo.
    echo [SUCCESS] Build completed successfully!
    echo Executable location: build\windows\x64\runner\Release\amazon_affiliate_erp.exe
    echo Launching application now...
    start "" "build\windows\x64\runner\Release\amazon_affiliate_erp.exe"
    pause
    exit /b 0
) else (
    echo.
    echo [!] Visual Studio C++ Build Tools may not be installed for native .exe compilation.
    echo [i] Launching the Instant Windows Desktop App window now...
    call "%~dp0Run_App_Immediately.bat"
    pause
    exit /b 0
)
