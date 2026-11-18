; Per-user Windows x64 packaging source. Not a qualified release artifact.
; Compile only after native PDFium, notices, signing and OS acceptance gates pass.
#ifndef PaperNativeQualified
  #error Native dependency and release qualification is required before packaging.
#endif
#ifndef PaperVersion
  #error Supply PaperVersion from the tested release candidate.
#endif
#ifndef PaperBuildDir
  #error Supply the absolute path to the qualified Flutter Windows x64 Release bundle.
#endif

#if !FileExists(PaperBuildDir + "\cave_paper.exe") || !FileExists(PaperBuildDir + "\flutter_windows.dll") || !FileExists(PaperBuildDir + "\data\app.so") || !FileExists(PaperBuildDir + "\data\icudtl.dat")
  #error PaperBuildDir must contain the complete qualified Flutter Release bundle.
#endif

[Setup]
AppId=technology.cave.paper
AppName=Cave Paper
AppVersion={#PaperVersion}
AppPublisher=Cave
DefaultDirName={localappdata}\Programs\Cave Paper
DisableDirPage=yes
DefaultGroupName=Cave Paper
PrivilegesRequired=lowest
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
ChangesAssociations=yes
UninstallDisplayIcon={app}\cave_paper.exe
OutputDir=..\..\build\installers
OutputBaseFilename=Cave-Paper-{#PaperVersion}-windows-x64
Compression=lzma2
SolidCompression=yes

[Files]
Source: "{#PaperBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\runner\resources\pdf_document.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Cave Paper"; Filename: "{app}\cave_paper.exe"

; These are candidate registrations, NOT a default assignment.
; Only app-owned values are removed; shared keys and unrelated values survive.
; Do not add uninsdeletekey, a .pdf default value, or a UserChoice write.
[Registry]
Root: HKCU; Subkey: "Software\Classes\Cave.Paper.PDF"; ValueType: string; ValueName: ""; ValueData: "Cave Paper PDF document"; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: "Software\Classes\Cave.Paper.PDF\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\pdf_document.ico"",0"; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: "Software\Classes\Cave.Paper.PDF\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\cave_paper.exe"" ""%1"""; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: "Software\Classes\.pdf\OpenWithProgids"; ValueType: string; ValueName: "Cave.Paper.PDF"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Cave\Paper\Capabilities"; ValueType: string; ValueName: "ApplicationName"; ValueData: "Cave Paper"; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: "Software\Cave\Paper\Capabilities"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "Offline PDF reader"; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: "Software\Cave\Paper\Capabilities\FileAssociations"; ValueType: string; ValueName: ".pdf"; ValueData: "Cave.Paper.PDF"; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: "Software\RegisteredApplications"; ValueType: string; ValueName: "Cave Paper"; ValueData: "Software\Cave\Paper\Capabilities"; Flags: uninsdeletevalue

; No Run section, default-setting command, recursive uninstall delete, or
; application-data removal. One stable AppId upgrades the existing installation.
