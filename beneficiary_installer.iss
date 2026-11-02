#ifndef MyAppVersion
  #define MyAppVersion "1.1.0"
#endif
[Setup]
AppId={{BBEC3A1C-A387-426A-9899-FA07280EAC39}
AppName=Amazon Affiliate ERP - Beneficiary
AppVersion={#MyAppVersion}
AppPublisher=ShamiNet
DefaultDirName={localappdata}\Programs\Amazon Affiliate ERP Beneficiary
DefaultGroupName=Amazon Affiliate ERP Beneficiary
OutputDir=installer_output
OutputBaseFilename=AmazonAffiliateERP_Beneficiary_Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
WizardStyle=modern
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\amazon_affiliate_erp.exe
[Files]
Source: "build\distributions\beneficiary\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\بوابة المستفيدين"; Filename: "{app}\amazon_affiliate_erp.exe"
Name: "{autodesktop}\بوابة المستفيدين"; Filename: "{app}\amazon_affiliate_erp.exe"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "إنشاء اختصار لبوابة المستفيدين"; Flags: unchecked
[Run]
Filename: "{app}\amazon_affiliate_erp.exe"; Description: "فتح بوابة المستفيدين"; Flags: nowait postinstall skipifsilent
