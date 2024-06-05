[Setup]
AppName=PhotosServer
AppVersion=1.0
DefaultDirName={pf}\PhotosServer
DefaultGroupName=PhotosServer
OutputDir=.
OutputBaseFilename=PhotosServerInstaller
Compression=lzma
SolidCompression=yes

[Files]
Source: "home-services-app.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\PhotosServer"; Filename: "{app}\photos-server.exe"
Name: "{group}\Uninstall PhotosServer"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\photos-server.exe"; Description: "Start Photos Server"; Flags: nowait postinstall skipifsilent
