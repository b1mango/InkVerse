; Inno Setup Script for InkVerse
; Generated on 2026-02-09

[Setup]
AppName=InkVerse
AppVersion=0.1.0
DefaultDirName={pf}\InkVerse
DefaultGroupName=InkVerse
DisableProgramGroupPage=no
OutputDir=release
OutputBaseFilename=InkVerse_Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
SetupIconFile={#SourcePath}\assets\icons\app.ico
UninstallDisplayIcon={app}\app.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "其他选项:"; Flags: unchecked

[Files]
; Copy all build output from dist\InkVerse into install directory
Source: "{#SourcePath}\dist\InkVerse\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs
; Install the app icon for shortcuts
Source: "{#SourcePath}\assets\icons\app.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\InkVerse"; Filename: "{app}\InkVerse.exe"; WorkingDir: "{app}"; IconFilename: "{app}\app.ico"
Name: "{userdesktop}\InkVerse"; Filename: "{app}\InkVerse.exe"; Tasks: desktopicon; WorkingDir: "{app}"; IconFilename: "{app}\app.ico"

[Run]
Filename: "{app}\InkVerse.exe"; Description: "Launch InkVerse"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: files; Name: "{app}\*"

; Compile command example (PowerShell):
; & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DSourcePath="F:\\VSCode Projects\\InkVerse" "F:\\VSCode Projects\\InkVerse\\InkVerse_installer.iss"
