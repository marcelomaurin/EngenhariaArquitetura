unit ea_launcher_main;
{$mode objfpc}{$H+}
{$codepage utf8}
interface
uses Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Buttons,
     Dialogs, Process;
type
  TEALauncherForm = class(TForm)
  private
    FNavigation, FHeader, FContent, FFooter: TPanel;
    FTitle, FSubtitle, FStatus: TLabel;
    FSection: Integer;
    procedure BuildInterface;
    procedure Navigate(Sender: TObject);
    procedure ShowSection(AIndex: Integer);
    procedure RefreshCatalog(Sender: TObject);
    procedure OpenApp(Sender: TObject);
    function ExecutableFor(AIndex: Integer): string;
    procedure AddAppCard(AParent: TWinControl; AIndex, ATop: Integer);
    procedure SetStatus(const S: string);
  public
    constructor Create(AOwner: TComponent); override;
  end;
var EALauncherForm: TEALauncherForm;
implementation
const
  APP_COUNT = 7;
  APP_NAMES: array[0..APP_COUNT-1] of string = (
    'Planejador', 'CAD Arquitetônico 2D', 'Maquete 3D',
    'Criador de Cenas', 'Elétrica 3D', 'SimuEletrica', 'SimuTubulações');
  APP_DESCRIPTIONS: array[0..APP_COUNT-1] of string = (
    'Cronograma, tarefas, dependências e planejamento da obra',
    'Plantas baixas, cotas, camadas e desenho técnico',
    'Edificação tridimensional, objetos e materiais',
    'Câmeras, iluminação, animações e renderização',
    'Instalações elétricas, quadros e encaminhamento',
    'Simulação de circuitos, proteção e cargas',
    'Redes de água, gás, ar e esgoto com simulação');
  APP_EXECUTABLES: array[0..APP_COUNT-1] of string = (
    'planejador', 'cad2d', 'maquete3d', 'criadorcenas',
    'eletrica3d', 'simueletrica', 'simutubulacoes');
  APP_PATHS: array[0..APP_COUNT-1] of string = (
    'planejador/src/app', 'cad2d/src/app', 'maquete3d/src/app',
    'criadorcenas/src/app', 'eletrica3d/src/app',
    'simueletrica/src/app', 'simutubulacoes/src/app');
function ColorRGB(R,G,B: Byte): TColor;
begin Result := RGBToColor(R,G,B); end;
constructor TEALauncherForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner, 1);
  Caption := 'EngenhariaArquitetura — Aplicativos';
  Width := 1150; Height := 760;
  Constraints.MinWidth := 840; Constraints.MinHeight := 580;
  Position := poScreenCenter;
  Font.Name := {$IFDEF WINDOWS}'Segoe UI'{$ELSE}'Sans'{$ENDIF};
  Font.Size := 10; Color := ColorRGB(244,246,250);
  BuildInterface;
  ShowSection(0);
end;
procedure TEALauncherForm.SetStatus(const S: string);
begin FStatus.Caption := S; end;
function TEALauncherForm.ExecutableFor(AIndex: Integer): string;
var Name, Base, Root: string; D: Integer;
begin
  Result := '';
  if (AIndex < 0) or (AIndex >= APP_COUNT) then Exit;
  Name := APP_EXECUTABLES[AIndex];
  {$IFDEF WINDOWS} Name := Name + '.exe'; {$ENDIF}
  Base := ExtractFilePath(ExpandFileName(ParamStr(0)));
  // Instalacao: executaveis lado a lado; desenvolvimento: caminhos de build.
  if FileExists(Base + Name) then Exit(Base + Name);
  Root := ExcludeTrailingPathDelimiter(Base);
  for D := 0 to 4 do begin
    if FileExists(IncludeTrailingPathDelimiter(Root) + APP_PATHS[AIndex] +
       DirectorySeparator + Name) then
      Exit(IncludeTrailingPathDelimiter(Root) + APP_PATHS[AIndex] +
           DirectorySeparator + Name);
    {$IFDEF WINDOWS}
    if FileExists(IncludeTrailingPathDelimiter(Root) + APP_PATHS[AIndex] +
       DirectorySeparator + Name) then
      Exit(IncludeTrailingPathDelimiter(Root) + APP_PATHS[AIndex] +
           DirectorySeparator + Name);
    {$ENDIF}
    if ExtractFileDir(Root) = Root then Break;
    Root := ExtractFileDir(Root);
  end;
end;
procedure TEALauncherForm.BuildInterface;
var I: Integer; B: TSpeedButton; L: TLabel;
begin
  FHeader := TPanel.Create(Self); FHeader.Parent := Self; FHeader.Align := alTop;
  FHeader.Height := 84; FHeader.BevelOuter := bvNone; FHeader.Color := ColorRGB(25,45,89);
  FTitle := TLabel.Create(Self); FTitle.Parent := FHeader;
  FTitle.SetBounds(22,12,700,31); FTitle.Caption := 'EngenhariaArquitetura';
  FTitle.Font.Size := 18; FTitle.Font.Style := [fsBold]; FTitle.Font.Color := clWhite;
  FSubtitle := TLabel.Create(Self); FSubtitle.Parent := FHeader;
  FSubtitle.SetBounds(23,49,750,23);
  FSubtitle.Caption := 'Central de aplicativos para engenharia e arquitetura';
  FSubtitle.Font.Color := ColorRGB(206,223,248);
  FFooter := TPanel.Create(Self); FFooter.Parent := Self; FFooter.Align := alBottom;
  FFooter.Height := 45; FFooter.BevelOuter := bvNone; FFooter.Color := clWhite;
  FStatus := TLabel.Create(Self); FStatus.Parent := FFooter;
  FStatus.Align := alClient; FStatus.BorderSpacing.Left := 18;
  FStatus.BorderSpacing.Top := 12; FStatus.Font.Color := ColorRGB(74,85,104);
  FNavigation := TPanel.Create(Self); FNavigation.Parent := Self;
  FNavigation.Align := alLeft; FNavigation.Width := 224;
  FNavigation.BevelOuter := bvNone; FNavigation.Color := clWhite;
  L := TLabel.Create(Self); L.Parent := FNavigation;
  L.SetBounds(16,16,190,24); L.Caption := 'NAVEGAÇÃO';
  L.Font.Style := [fsBold]; L.Font.Color := ColorRGB(74,85,104);
  for I := 0 to 3 do begin
    B := TSpeedButton.Create(Self); B.Parent := FNavigation;
    B.SetBounds(12,48+I*48,196,38); B.Tag := I; B.Flat := True;
    case I of
      0: B.Caption := 'Início';
      1: B.Caption := 'Desenho e modelagem';
      2: B.Caption := 'Instalações e simulação';
      3: B.Caption := 'Todos os aplicativos';
    end;
    B.OnClick := @Navigate;
  end;
  B := TSpeedButton.Create(Self); B.Parent := FNavigation;
  B.SetBounds(12,267,196,38); B.Caption := 'Atualizar disponibilidade';
  B.Hint := 'Verificar novamente os executáveis instalados'; B.ShowHint := True;
  B.OnClick := @RefreshCatalog;
  FContent := TPanel.Create(Self); FContent.Parent := Self;
  FContent.Align := alClient; FContent.BevelOuter := bvNone;
  FContent.Color := ColorRGB(244,246,250);
end;
procedure TEALauncherForm.Navigate(Sender: TObject);
begin ShowSection(TSpeedButton(Sender).Tag); end;
procedure TEALauncherForm.RefreshCatalog(Sender: TObject);
begin ShowSection(FSection); end;
procedure TEALauncherForm.AddAppCard(AParent: TWinControl; AIndex, ATop: Integer);
var P: TPanel; Title, Desc, Status: TLabel; B: TButton; Exe: string;
begin
  P := TPanel.Create(Self); P.Parent := AParent; P.Align := alTop;
  P.Height := 104; P.BorderSpacing.Left := 18; P.BorderSpacing.Right := 18;
  P.BorderSpacing.Bottom := 10; P.BevelOuter := bvNone; P.Color := clWhite;
  Title := TLabel.Create(Self); Title.Parent := P;
  Title.SetBounds(18,13,480,27); Title.Caption := APP_NAMES[AIndex];
  Title.Font.Size := 12; Title.Font.Style := [fsBold];
  Title.Font.Color := ColorRGB(25,45,89);
  Desc := TLabel.Create(Self); Desc.Parent := P;
  Desc.SetBounds(18,44,480,22); Desc.Caption := APP_DESCRIPTIONS[AIndex];
  Desc.Font.Color := ColorRGB(95,108,125);
  Exe := ExecutableFor(AIndex);
  Status := TLabel.Create(Self); Status.Parent := P;
  Status.SetBounds(18,74,430,20);
  if Exe <> '' then begin
    Status.Caption := 'Disponível — executável encontrado';
    Status.Font.Color := ColorRGB(22,131,71);
  end else begin
    Status.Caption := 'Ainda não instalado / não compilado';
    Status.Font.Color := ColorRGB(162,100,31);
  end;
  B := TButton.Create(Self); B.Parent := P; B.Anchors := [akTop,akRight];
  B.SetBounds(P.Width-139,30,120,36); B.Caption := 'Abrir';
  B.Tag := AIndex; B.Enabled := Exe <> ''; B.OnClick := @OpenApp;
  P.OnResize := nil;
  // A largura inicial do cartão é atualizada por alinhamento; botão ficará à direita.
  B.AnchorSideRight.Control := P; B.AnchorSideRight.Side := asrRight;
  B.BorderSpacing.Right := 18;
end;
procedure TEALauncherForm.ShowSection(AIndex: Integer);
var Scroll: TScrollBox; I, N: Integer; ShowIt: Boolean; Head: TLabel;
begin
  FSection := AIndex;
  while FContent.ControlCount > 0 do FContent.Controls[0].Free;
  Scroll := TScrollBox.Create(Self); Scroll.Parent := FContent;
  Scroll.Align := alClient; Scroll.BorderStyle := bsNone;
  Scroll.Color := ColorRGB(244,246,250);
  Scroll.VertScrollBar.Tracking := True;
  Head := TLabel.Create(Self); Head.Parent := Scroll;
  Head.Align := alTop; Head.Height := 58;
  Head.BorderSpacing.Left := 20; Head.BorderSpacing.Top := 12;
  Head.Font.Size := 15; Head.Font.Style := [fsBold];
  case AIndex of
    0: Head.Caption := 'Aplicativos da plataforma';
    1: Head.Caption := 'Desenho e modelagem';
    2: Head.Caption := 'Instalações e simulações';
  else Head.Caption := 'Catálogo completo';
  end;
  N := 0;
  for I := APP_COUNT - 1 downto 0 do begin
    ShowIt := (AIndex in [0,3]) or
      ((AIndex=1) and (I in [1,2,3])) or
      ((AIndex=2) and (I in [4,5,6]));
    if ShowIt then begin AddAppCard(Scroll, I, N*114); Inc(N); end;
  end;
  SetStatus(IntToStr(N) + ' aplicativos listados. Somente executáveis encontrados podem ser abertos.');
end;
procedure TEALauncherForm.OpenApp(Sender: TObject);
var Id: Integer; Path: string; P: TProcess;
begin
  Id := TButton(Sender).Tag;
  Path := ExecutableFor(Id);
  if Path = '' then begin
    MessageDlg('Aplicativo indisponível', 'O executável não foi encontrado.',
      mtWarning, [mbOK], 0); Exit;
  end;
  P := TProcess.Create(nil);
  try
    try
      P.Executable := Path;
      P.CurrentDirectory := ExtractFilePath(Path);
      P.Options := [];
      P.Execute;
      SetStatus('Aberto: ' + APP_NAMES[Id]);
    except on E: Exception do
      MessageDlg('Erro ao abrir', E.Message, mtError, [mbOK], 0);
    end;
  finally P.Free; end;
end;
end.
