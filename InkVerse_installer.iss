; Inno Setup Script for InkVerse
; Packages the PyInstaller folder dist\InkVerse (built from InkVerse.spec).
; The version comes from app/__init__.py; CI passes it as /DMyAppVersion=x.y.z.

#ifndef MyAppVersion
  #define MyAppVersion "0.2.0"
#endif

[Setup]
AppName=InkVerse
AppVersion={#MyAppVersion}
AppPublisher=b1mango
DefaultDirName={autopf}\InkVerse
DefaultGroupName=InkVerse
DisableProgramGroupPage=no
OutputDir=release
OutputBaseFilename=InkVerse-{#MyAppVersion}-Setup
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

; Compile command example (PowerShell, from the repository root after `pyinstaller InkVerse.spec`):
; & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion=0.2.0 InkVerse_installer.iss
