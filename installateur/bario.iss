; =====================================================================
; BARIO · Programme d'installation Windows (Inno Setup)
; Fabrique automatiquement par GitHub (.github/workflows/livraison.yml).
; =====================================================================
#define Version GetEnv("BARIO_VERSION")
#if Version == ""
  #define Version "1.0.0"
#endif

[Setup]
AppId={{A987E102-0861-4427-9BE6-75E1CBFFC05C}
AppName=Bario
AppVersion={#Version}
AppVerName=Bario {#Version}
AppPublisher=Bario
DefaultDirName={localappdata}\Programs\Bario
DefaultGroupName=Bario
DisableProgramGroupPage=yes
; Installation pour l'utilisateur : pas besoin d'etre administrateur
PrivilegesRequired=lowest
OutputDir=..\livraison
OutputBaseFilename=Bario-Installation
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\bario.exe
UninstallDisplayName=Bario
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Ferme le logiciel s'il est ouvert pendant une mise a jour
CloseApplications=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "bureau"; Description: "Creer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Bario"; Filename: "{app}\bario.exe"
Name: "{autodesktop}\Bario"; Filename: "{app}\bario.exe"; Tasks: bureau

[Run]
Filename: "{app}\bario.exe"; Description: "Ouvrir Bario maintenant"; Flags: nowait postinstall skipifsilent
