; Instalador Windows x64 da plataforma EngenhariaArquitetura.
; Gerado por build_release_wine.sh (Linux) ou build_release.bat (Windows),
; que criam dist\version.iss, dist\app e dist\installer-images.
#ifndef MyAppName
  #define MyAppName "EngenhariaArquitetura"
#endif
#include "..\..\dist\version.iss"
#ifndef SetupSeq
  #define SetupSeq "001"
#endif
#ifndef MyAppPublisher
  #define MyAppPublisher "Maurinsoft"
#endif
#ifndef OutputExeName
  #define OutputExeName "setup_engenhariaarquitetura_" + SetupSeq
#endif

[Setup]
AppId={{6F2C1E4B-8B7A-4C1D-9E3F-2A5D7B9C0E11}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
VersionInfoVersion={#MyBinaryVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://maurinsoft.com.br
DefaultDirName={autopf}\EngenhariaArquitetura
DefaultGroupName=EngenhariaArquitetura
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename={#OutputExeName}
SetupIconFile=..\..\planejador\src\app\planejador.ico
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
WizardStyle=modern
WizardImageFile=..\..\dist\installer-images\welcome.bmp
WizardSmallImageFile=..\..\dist\installer-images\small.bmp
WizardSizePercent=120
UninstallDisplayIcon={app}\engenhariaarquitetura.exe
CloseApplications=yes

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Types]
Name: "full"; Description: "Instalação completa (aplicativos, exemplos e documentação)"
Name: "compact"; Description: "Instalação básica (somente os aplicativos)"
Name: "custom"; Description: "Instalação personalizada (escolher os itens)"; Flags: iscustom

[Components]
Name: "apps"; Description: "Aplicativos da plataforma"; Types: full compact custom; Flags: fixed
Name: "apps\planejador"; Description: "Planejador - tarefas, dependências, caminho crítico e Gantt"; Types: full compact custom; Flags: fixed
Name: "extra"; Description: "Recursos complementares"; Types: full custom
Name: "extra\exemplos"; Description: "Projetos de exemplo"; Types: full custom
Name: "extra\docs"; Description: "Documentação da plataforma"; Types: full custom

[Dirs]
Name: "{userdocs}\EngenhariaArquitetura Projetos"

[Files]
Source: "..\..\dist\app\engenhariaarquitetura.exe"; DestDir: "{app}"; Components: apps; Flags: ignoreversion
Source: "..\..\dist\app\planejador.exe"; DestDir: "{app}"; Components: apps\planejador; Flags: ignoreversion
Source: "..\..\dist\app\exemplos\*"; DestDir: "{app}\exemplos"; Components: extra\exemplos; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\dist\app\exemplos\*"; DestDir: "{userdocs}\EngenhariaArquitetura Projetos\Exemplos"; Components: extra\exemplos; Flags: ignoreversion onlyifdoesntexist recursesubdirs createallsubdirs
Source: "..\..\dist\app\documentation\*"; DestDir: "{app}\documentation"; Components: extra\docs; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\dist\app\licencas\*"; DestDir: "{app}\licencas"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\dist\app\build-manifest.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\dist\installer-images\slide*.bmp"; Flags: dontcopy

[Tasks]
Name: "desktopicon_launcher"; Description: "Criar atalho da Central de Aplicativos na área de trabalho"; GroupDescription: "Atalhos da área de trabalho:"; Components: apps; Flags: unchecked
Name: "desktopicon_planejador"; Description: "Criar atalho do Planejador na área de trabalho"; GroupDescription: "Atalhos da área de trabalho:"; Components: apps\planejador; Flags: unchecked

[Icons]
Name: "{autoprograms}\EngenhariaArquitetura\Central de Aplicativos"; Filename: "{app}\engenhariaarquitetura.exe"; Components: apps
Name: "{autoprograms}\EngenhariaArquitetura\Planejador"; Filename: "{app}\planejador.exe"; Components: apps\planejador
Name: "{autoprograms}\EngenhariaArquitetura\Planejador - exemplo da residência"; Filename: "{app}\planejador.exe"; Parameters: """{app}\exemplos\residencia.plan.json"""; Components: apps\planejador and extra\exemplos
Name: "{autoprograms}\EngenhariaArquitetura\Documentação"; Filename: "{app}\documentation"; Components: extra\docs
Name: "{autodesktop}\EngenhariaArquitetura"; Filename: "{app}\engenhariaarquitetura.exe"; Tasks: desktopicon_launcher; Components: apps
Name: "{autodesktop}\Planejador"; Filename: "{app}\planejador.exe"; Tasks: desktopicon_planejador; Components: apps\planejador

[Run]
Filename: "{app}\planejador.exe"; Parameters: """{app}\exemplos\residencia.plan.json"""; Description: "Abrir o Planejador com o exemplo da residência"; Flags: nowait postinstall skipifsilent; Components: apps\planejador and extra\exemplos

[Code]
var
  ProjectImage: TBitmapImage;
  ProjectCaption: TNewStaticText;

procedure InitializeWizard;
var
  ImageTop: Integer;
begin
  ExtractTemporaryFile('slide0.bmp');
  ImageTop := WizardForm.ProgressGauge.Top + WizardForm.ProgressGauge.Height + ScaleY(18);
  ProjectImage := TBitmapImage.Create(WizardForm);
  ProjectImage.Parent := WizardForm.InstallingPage;
  ProjectImage.SetBounds(0, ImageTop, WizardForm.InstallingPage.ClientWidth,
    WizardForm.InstallingPage.ClientHeight - ImageTop - ScaleY(24));
  ProjectImage.Stretch := True;
  ProjectImage.Bitmap.LoadFromFile(ExpandConstant('{tmp}\slide0.bmp'));
  ProjectCaption := TNewStaticText.Create(WizardForm);
  ProjectCaption.Parent := WizardForm.InstallingPage;
  ProjectCaption.SetBounds(0, ProjectImage.Top + ProjectImage.Height + ScaleY(4),
    WizardForm.InstallingPage.ClientWidth, ScaleY(20));
  ProjectCaption.Caption := 'Planejador - tarefas, dependências, caminho crítico e Gráfico de Gantt';
end;
