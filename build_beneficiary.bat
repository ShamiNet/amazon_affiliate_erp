@echo off
setlocal EnableExtensions DisableDelayedExpansion
pushd "%~dp0" || exit /b 1
set "NO_PAUSE=0"
if /i "%~1"=="--no-pause" set "NO_PAUSE=1"
set "FLUTTER_CMD="
for /f "delims=" %%F in ('where flutter.bat 2^>nul') do if not defined FLUTTER_CMD set "FLUTTER_CMD=%%F"
if not defined FLUTTER_CMD if exist "C:\src\flutter\bin\flutter.bat" set "FLUTTER_CMD=C:\src\flutter\bin\flutter.bat"
set "ISCC="
for %%D in ("%ProgramFiles%\Inno Setup 6" "%ProgramFiles(x86)%\Inno Setup 6" "%LOCALAPPDATA%\Programs\Inno Setup 6") do if exist "%%~D\ISCC.exe" set "ISCC=%%~D\ISCC.exe"
if not defined FLUTTER_CMD (echo ERROR: Flutter not found.& goto failed)
if not defined ISCC (echo ERROR: Inno Setup 6 not found.& goto failed)
if not exist "installer_output" mkdir "installer_output"
set "LOG=%CD%\installer_output\build_beneficiary.log"
set "CI=true"
set "FLUTTER_SUPPRESS_ANALYTICS=true"
>"%LOG%" echo Beneficiary build started: %DATE% %TIME%
for /f "tokens=2" %%V in ('findstr /b "version:" pubspec.yaml') do for /f "tokens=1 delims=+" %%N in ("%%V") do set "APP_VERSION=%%N"
echo Building independent beneficiary application...
call "%FLUTTER_CMD%" pub get >>"%LOG%" 2>&1
if errorlevel 1 goto failed
call "%FLUTTER_CMD%" build windows --release --no-pub --target=lib/beneficiary_main.dart >>"%LOG%" 2>&1
if errorlevel 1 goto failed
if not exist "build\windows\x64\runner\Release\data\app.so" goto failed
robocopy "build\windows\x64\runner\Release" "build\distributions\beneficiary" /E /R:2 /W:1 /XD backend /XF *.pdb >>"%LOG%" 2>&1
if errorlevel 8 goto failed
"%ISCC%" "/DMyAppVersion=%APP_VERSION%" "%CD%\beneficiary_installer.iss" >>"%LOG%" 2>&1
if errorlevel 1 goto failed
if not exist "installer_output\AmazonAffiliateERP_Beneficiary_Setup.exe" goto failed
echo SUCCESS: "%CD%\installer_output\AmazonAffiliateERP_Beneficiary_Setup.exe"
echo Run build_installer.bat afterwards to restore the manager Release build.
set "RESULT=0"
goto finish
:failed
echo BUILD FAILED. See "%LOG%"
set "RESULT=1"
:finish
popd
if "%NO_PAUSE%"=="0" pause
exit /b %RESULT%
