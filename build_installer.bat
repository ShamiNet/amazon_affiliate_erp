@echo off
setlocal EnableExtensions DisableDelayedExpansion
pushd "%~dp0" || exit /b 1
set "NO_PAUSE=0"
set "CLEAN_BUILD=0"
:arguments
if "%~1"=="" goto configure
if /i "%~1"=="--no-pause" (set "NO_PAUSE=1") else if /i "%~1"=="--clean" (set "CLEAN_BUILD=1") else (echo Unknown option: %~1& popd& exit /b 2)
shift
goto arguments

:configure
set "OUTPUT=%CD%\installer_output"
set "RELEASE=%CD%\build\windows\x64\runner\Release"
if not exist "%OUTPUT%" mkdir "%OUTPUT%"
if not exist "%OUTPUT%" goto failed
set "LOG=%OUTPUT%\build_installer.log"
>"%LOG%" echo Build started: %DATE% %TIME%
set "CI=true"
set "FLUTTER_SUPPRESS_ANALYTICS=true"
set "FLUTTER_CMD="
if defined FLUTTER_ROOT if exist "%FLUTTER_ROOT%\bin\flutter.bat" set "FLUTTER_CMD=%FLUTTER_ROOT%\bin\flutter.bat"
if not defined FLUTTER_CMD for /f "delims=" %%F in ('where flutter.bat 2^>nul') do if not defined FLUTTER_CMD set "FLUTTER_CMD=%%F"
if not defined FLUTTER_CMD if exist "C:\src\flutter\bin\flutter.bat" set "FLUTTER_CMD=C:\src\flutter\bin\flutter.bat"
if not defined FLUTTER_CMD (echo ERROR: Flutter not found. Set FLUTTER_ROOT or add Flutter to PATH.& goto failed)
if defined ISCC if not exist "%ISCC%" set "ISCC="
if not defined ISCC for /f "delims=" %%F in ('where ISCC.exe 2^>nul') do if not defined ISCC set "ISCC=%%F"
if not defined ISCC for %%D in ("%ProgramFiles%\Inno Setup 6" "%ProgramFiles(x86)%\Inno Setup 6" "%LOCALAPPDATA%\Programs\Inno Setup 6" "%LOCALAPPDATA%\Inno Setup 6" "%CD%\tools\Inno Setup 6") do if exist "%%~D\ISCC.exe" set "ISCC=%%~D\ISCC.exe"
if not defined ISCC (echo ERROR: Inno Setup 6 not found. Install it or set ISCC to the full path of ISCC.exe.& goto failed)
for %%F in ("pubspec.yaml" "installer.iss" "windows\CMakeLists.txt" "backend\report_extractor.py" "backend\run_report_extractor.ps1" "backend\setup_paddle_ocr.ps1" "backend\requirements-paddle.txt" "backend\ocr_runtime\tesseract.exe" "backend\ocr_runtime\tessdata\ara.traineddata" "backend\ocr_runtime\tessdata\eng.traineddata") do if not exist "%%~F" (echo ERROR: Missing required file: %%~F& goto failed)
set "APP_VERSION="
for /f "tokens=2" %%V in ('findstr /b "version:" pubspec.yaml') do for /f "tokens=1 delims=+" %%N in ("%%V") do set "APP_VERSION=%%N"
if not defined APP_VERSION (echo ERROR: Missing version in pubspec.yaml.& goto failed)
if "%CLEAN_BUILD%"=="1" (
    echo Cleaning previous Flutter build...
    call "%FLUTTER_CMD%" clean >>"%LOG%" 2>&1
    if errorlevel 1 goto failed
)
echo [1/6] Resolving dependencies...
call "%FLUTTER_CMD%" pub get >>"%LOG%" 2>&1
if errorlevel 1 goto failed
echo [2/6] Checking source code...
call "%FLUTTER_CMD%" analyze --no-pub --no-fatal-infos >>"%LOG%" 2>&1
if errorlevel 1 goto failed
echo [3/6] Running tests...
call "%FLUTTER_CMD%" test --no-pub >>"%LOG%" 2>&1
if errorlevel 1 goto failed
echo [4/6] Building Windows release...
call "%FLUTTER_CMD%" build windows --release --no-pub >>"%LOG%" 2>&1
if errorlevel 1 goto failed
for %%F in ("amazon_affiliate_erp.exe" "flutter_windows.dll" "data\icudtl.dat" "data\app.so" "data\flutter_assets\AssetManifest.bin") do if not exist "%RELEASE%\%%~F" (echo ERROR: Incomplete release: %%~F& goto failed)
echo [5/6] Adding local OCR backend to the application folder...
if not exist "%RELEASE%\backend" mkdir "%RELEASE%\backend"
for %%F in (report_extractor.py run_report_extractor.ps1 setup_paddle_ocr.ps1 requirements-paddle.txt) do (
    copy /y "backend\%%F" "%RELEASE%\backend\%%F" >>"%LOG%" 2>&1
    if errorlevel 1 goto failed
)
robocopy "backend\ocr_runtime" "%RELEASE%\backend\ocr_runtime" /E /R:2 /W:1 /XF *.log *.tmp >>"%LOG%" 2>&1
if errorlevel 8 goto failed
echo [6/6] Creating installer...
"%ISCC%" "/DMyAppVersion=%APP_VERSION%" "/O%OUTPUT%" "/FAmazonAffiliateERP_Setup" "%CD%\installer.iss" >>"%LOG%" 2>&1
if errorlevel 1 goto failed
if not exist "%OUTPUT%\AmazonAffiliateERP_Setup.exe" (echo ERROR: Installer output is missing.& goto failed)
echo.
echo SUCCESS: Version %APP_VERSION%
echo Application: "%RELEASE%\amazon_affiliate_erp.exe"
echo Keep the entire Release folder together when copying the application.
echo Installer: "%OUTPUT%\AmazonAffiliateERP_Setup.exe"
echo Log: "%LOG%"
set "RESULT=0"
goto finish

:failed
echo.
echo BUILD FAILED. No successful build is being reported.
if defined LOG echo See the error details in: "%LOG%"
set "RESULT=1"
:finish
popd
if "%NO_PAUSE%"=="0" pause
exit /b %RESULT%
