[Setup]
AppName=Field Operation Desktop
AppVersion=1.0.0
DefaultDirName={autopf}\FieldOperationDesktop
DefaultGroupName=Field Operation Desktop
OutputDir=installer
OutputBaseFilename=FieldOperationDesktopSetup
SetupIconFile=icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "dist\FieldOperationDesktop.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Field Operation Desktop"; Filename: "{app}\FieldOperationDesktop.exe"
Name: "{autodesktop}\Field Operation Desktop"; Filename: "{app}\FieldOperationDesktop.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\FieldOperationDesktop.exe"; Description: "Run Field Operation Desktop"; Flags: nowait postinstall skipifsilent
