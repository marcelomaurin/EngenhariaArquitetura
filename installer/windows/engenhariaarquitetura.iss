; Inno Setup Script - Engenharia e Arquitetura
; Gerador do instalador oficial para Windows 64-bit

#define MyAppName "EngenhariaArquitetura"
#define MyAppPublisher "Maurinsoft"
#define MyAppURL "https://github.com/marcelomaurin/EngenhariaArquitetura"
#define MyAppExeName "engenhariaarquitetura.exe"
#pragma include __INCLUDE__ + ";" + ReadReg(HKEY_LOCAL_MACHINE, "Software\Classes\InnoSetupScriptFile\Shell\Open\Command", "", "")

#include "..\..\dist\version.iss"

#ifndef MySetupSeq
  #ifdef SetupSeq
    #define MySetupSeq SetupSeq
  #else
    #define MySetupSeq "010"
  #endif
#endif

[Setup]
AppId={{5E3F8A1C-4B9D-4E2F-8A3B-1C5E7F9A2B4D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE
OutputBaseFilename=setup_engenhariaarquitetura_{#MySetupSeq}
OutputDir=..\..\dist
SetupIconFile=..\..\launcher\src\app\engenhariaarquitetura.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
ChangesAssociations=no
WizardImageFile=..\..\dist\installer-images\wizard-large.bmp
WizardSmallImageFile=..\..\dist\installer-images\wizard-small.bmp

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Types]
Name: "full"; Description: "Instalação completa"
Name: "compact"; Description: "Instalação compacta (apenas aplicativos)"
Name: "custom"; Description: "Instalação personalizada"; Flags: iscustom

[Components]
Name: "apps"; Description: "Aplicativos da plataforma"; Types: full compact custom; Flags: fixed
Name: "apps\planejador"; Description: "Planejador - tarefas, dependências, caminho crítico e Gantt"; Types: full compact custom; Flags: fixed
Name: "apps\cad2d"; Description: "CAD Arquitetônico 2D - plantas baixas, paredes, esquadrias e cotas"; Types: full compact custom; Flags: fixed
Name: "extra"; Description: "Recursos complementares"; Types: full custom
Name: "extra\exemplos"; Description: "Projetos de exemplo"; Types: full custom
Name: "extra\docs"; Description: "Documentação da plataforma"; Types: full custom

[Dirs]
Name: "{userdocs}\EngenhariaArquitetura Projetos"; Flags: uninsneveruninstall
Name: "{userdocs}\EngenhariaArquitetura Projetos\Exemplos"; Flags: uninsneveruninstall
Name: "{userdocs}\EngenhariaArquitetura Projetos\samples\files"; Flags: uninsneveruninstall

[Files]
Source: "..\..\dist\app\engenhariaarquitetura.exe"; DestDir: "{app}"; Components: apps; Flags: ignoreversion
Source: "..\..\dist\app\cad2d.exe"; DestDir: "{app}"; Components: apps\cad2d; Flags: ignoreversion
Source: "..\..\dist\app\planejador.exe"; DestDir: "{app}"; Components: apps\planejador; Flags: ignoreversion
Source: "..\..\dist\app\bibliotecas\*"; DestDir: "{app}\bibliotecas"; Components: apps; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\dist\app\updater\windows\update.ps1"; DestDir: "{app}\updater\windows"; Components: apps; Flags: ignoreversion
Source: "..\..\dist\app\exemplos\*"; DestDir: "{app}\exemplos"; Components: extra\exemplos; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\dist\app\exemplos\*"; DestDir: "{userdocs}\EngenhariaArquitetura Projetos\Exemplos"; Components: extra\exemplos; Flags: ignoreversion onlyifdoesntexist recursesubdirs createallsubdirs
Source: "..\..\dist\app\samples\*"; DestDir: "{app}\samples"; Components: apps\cad2d; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\dist\app\samples\files\*"; DestDir: "{userdocs}\EngenhariaArquitetura Projetos\samples\files"; Components: apps\cad2d; Flags: ignoreversion onlyifdoesntexist recursesubdirs createallsubdirs
Source: "..\..\dist\app\documentation\*"; DestDir: "{app}\documentation"; Components: extra\docs; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\dist\app\licencas\*"; DestDir: "{app}\licencas"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\dist\app\qa-tests.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\dist\app\build-manifest.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\dist\installer-images\slide*.bmp"; Flags: dontcopy

[Tasks]
Name: "desktopicon_launcher"; Description: "Criar atalho da Central de Aplicativos na área de trabalho"; GroupDescription: "Atalhos da área de trabalho:"; Components: apps
Name: "desktopicon_planejador"; Description: "Criar atalho do Planejador na área de trabalho"; GroupDescription: "Atalhos da área de trabalho:"; Components: apps\planejador; Flags: unchecked
Name: "desktopicon_cad2d"; Description: "Criar atalho do CAD Arquitetônico 2D na área de trabalho"; GroupDescription: "Atalhos da área de trabalho:"; Components: apps\cad2d; Flags: unchecked

[Icons]
Name: "{autoprograms}\EngenhariaArquitetura\Central de Aplicativos"; Filename: "{app}\engenhariaarquitetura.exe"; Components: apps
Name: "{autoprograms}\EngenhariaArquitetura\Planejador"; Filename: "{app}\planejador.exe"; Components: apps\planejador
Name: "{autoprograms}\EngenhariaArquitetura\Planejador - exemplo UBS"; Filename: "{app}\planejador.exe"; Parameters: """{app}\exemplos\ubs.plan.json"""; Components: apps\planejador and extra\exemplos
Name: "{autoprograms}\EngenhariaArquitetura\Planejador - exemplo ala hospitalar"; Filename: "{app}\planejador.exe"; Parameters: """{app}\exemplos\ala_hospitalar.plan.json"""; Components: apps\planejador and extra\exemplos
Name: "{autoprograms}\EngenhariaArquitetura\Planejador - exemplo da residência"; Filename: "{app}\planejador.exe"; Parameters: """{app}\exemplos\residencia.plan.json"""; Components: apps\planejador and extra\exemplos
Name: "{autoprograms}\EngenhariaArquitetura\CAD Arquitetônico 2D"; Filename: "{app}\cad2d.exe"; Components: apps\cad2d
Name: "{autoprograms}\EngenhariaArquitetura\Documentação"; Filename: "{app}\documentation"; Components: extra\docs
Name: "{autoprograms}\EngenhariaArquitetura\Samples - modelos de hospital"; Filename: "{app}\samples\files"; Components: apps\cad2d
Name: "{autodesktop}\EngenhariaArquitetura"; Filename: "{app}\engenhariaarquitetura.exe"; Tasks: desktopicon_launcher; Components: apps
Name: "{autodesktop}\Planejador"; Filename: "{app}\planejador.exe"; Tasks: desktopicon_planejador; Components: apps\planejador
Name: "{autodesktop}\CAD Arquitetônico 2D"; Filename: "{app}\cad2d.exe"; Tasks: desktopicon_cad2d; Components: apps\cad2d

[Run]
Filename: "{app}\engenhariaarquitetura.exe"; Description: "Abrir a Central de Aplicativos EngenhariaArquitetura"; Flags: nowait postinstall skipifsilent; Components: apps

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
  ProjectCaption.Caption := 'EngenhariaArquitetura - Planejador e CAD Arquitetônico 2D';
end;
