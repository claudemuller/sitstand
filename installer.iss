[Setup]
AppName=SitStand
AppVersion=1.0
DefaultDirName={pf}\SitStand
DefaultGroupName=SitStand
OutputDir=Output
OutputBaseFilename=sitstand-setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\SitStand"; Filename: "{app}\sitstand.exe"
