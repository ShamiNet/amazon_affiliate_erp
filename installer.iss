[Setup]
AppId={{7B1E3F52-4C0A-4E8B-9D55-3A2C6E1F8A10}
AppName=Amazon Affiliate ERP
AppVersion=1.0.2
AppPublisher=ShamiNet
DefaultDirName={autopf}\Amazon Affiliate ERP
DefaultGroupName=Amazon Affiliate ERP
OutputDir=installer_output
OutputBaseFilename=AmazonAffiliateERP_Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
WizardStyle=modern
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\amazon_affiliate_erp.exe

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "backend\report_extractor.py"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "backend\run_report_extractor.ps1"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "windows\runner\resources\app_icon.ico"; DestDir: "{app}"; DestName: "app_icon.ico"; Flags: ignoreversion

[Icons]
Name: "{group}\Amazon Affiliate ERP"; Filename: "{app}\amazon_affiliate_erp.exe"; IconFilename: "{app}\app_icon.ico"
Name: "{autodesktop}\Amazon Affiliate ERP"; Filename: "{app}\amazon_affiliate_erp.exe"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "إنشاء اختصار على سطح المكتب"; Flags: unchecked

[Run]
Filename: "{app}\amazon_affiliate_erp.exe"; Description: "تشغيل التطبيق"; Flags: nowait postinstall skipifsilent
