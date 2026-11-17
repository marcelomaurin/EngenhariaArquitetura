unit criadorcenas_main;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  ComCtrls, Dialogs, Menus,
  ea_geometria, ea_visual3d, ea_config_ui, ea_workflow,
  cena_projeto;

type
  TCenaMainForm = class(TForm)
  private
    FCena: TCenaProject;
    FViewport: TEAViewport3D;
    FRenderBox: TPaintBox;
    FRenderPixels: array of LongWord;
    FRenderW, FRenderH: Integer;
    FPages: TPageControl;
    FCamList, FLightList: TListBox;
    FHourEdit, FNorthEdit: TEdit;
    FAtmCombo: TComboBox;
    FStatusLabel: TLabel;
    procedure BuildMenus;
    procedure BuildUI;
    procedure RefreshLists;
    procedure PaintRenderBox(Sender: TObject);
    procedure ImportMaqueteClick(Sender: TObject);
    procedure ImportLightsClick(Sender: TObject);
    procedure SaveSceneClick(Sender: TObject);
    procedure OpenSceneClick(Sender: TObject);
    procedure RenderPreviewClick(Sender: TObject);
    procedure ExportPNGClick(Sender: TObject);
    procedure ExportSequenceClick(Sender: TObject);
    procedure DayPresetClick(Sender: TObject);
    procedure NightPresetClick(Sender: TObject);
    procedure AddCamFromViewClick(Sender: TObject);
    procedure SetupClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  CenaMainForm: TCenaMainForm;

implementation

constructor TCenaMainForm.Create(AOwner: TComponent);
var
  TaskPkg: string;
begin
  inherited CreateNew(AOwner, 1);
  FCena := TCenaProject.Create;
  FRenderW := 320;
  FRenderH := 200;
  Caption := 'Criador de Cenas Realistas — EngenhariaArquitetura';
  Width := 1220;
  Height := 760;
  Position := poScreenCenter;
  Font.Name := {$IFDEF WINDOWS}'Segoe UI'{$ELSE}'Sans'{$ENDIF};
  Font.Size := 10;
  Color := RGBToColor(244, 246, 250);

  BuildMenus;
  BuildUI;
  FCena.LoadDemoScene;
  FViewport.Mesh.Assign(FCena.SceneMesh);
  FViewport.FitToMesh;
  RefreshLists;

  TaskPkg := WFArg('--task-pkg');
  if (TaskPkg <> '') and FileExists(TaskPkg) then
    FStatusLabel.Caption := 'Tarefa recebida do Planejador: ' + ExtractFileName(TaskPkg);
end;

destructor TCenaMainForm.Destroy;
begin
  FCena.Free;
  inherited Destroy;
end;

procedure TCenaMainForm.BuildMenus;
var
  M: TMainMenu;
  TopMenu: TMenuItem;
  procedure Add(P: TMenuItem; const Cap: string; Ev: TNotifyEvent);
  var It: TMenuItem;
  begin It := TMenuItem.Create(M); It.Caption := Cap; It.OnClick := Ev; P.Add(It); end;
begin
  M := TMainMenu.Create(Self); Menu := M;
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Arquivo'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Importar Maquete 3D (.maquete.pkg.json)...', @ImportMaqueteClick);
  Add(TopMenu, 'Importar Iluminação do Elétrica 3D...', @ImportLightsClick);
  Add(TopMenu, '-', nil);
  Add(TopMenu, 'Abrir Cena (.cena.json)...', @OpenSceneClick);
  Add(TopMenu, 'Salvar Cena...', @SaveSceneClick);
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Renderizar'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Prévia Raytracer', @RenderPreviewClick);
  Add(TopMenu, 'Exportar Imagem PNG...', @ExportPNGClick);
  Add(TopMenu, 'Exportar Sequência de Quadros (Vídeo)...', @ExportSequenceClick);
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Setup'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Configurações compartilhadas...', @SetupClick);
end;

procedure TCenaMainForm.BuildUI;
var
  Header, Footer, LeftP, RightP, Bar: TPanel;
  L: TLabel;
  B: TButton;
  TabView, TabRender: TTabSheet;
begin
  Header := TPanel.Create(Self); Header.Parent := Self; Header.Align := alTop; Header.Height := 48;
  Header.BevelOuter := bvNone; Header.Color := RGBToColor(15, 23, 42);
  L := TLabel.Create(Self); L.Parent := Header; L.SetBounds(16, 12, 520, 26);
  L.Caption := 'CRIADOR DE CENAS REALISTAS  |  Câmeras, Iluminação e Render';
  L.Font.Color := clWhite; L.Font.Style := [fsBold];

  Footer := TPanel.Create(Self); Footer.Parent := Self; Footer.Align := alBottom; Footer.Height := 30;
  Footer.BevelOuter := bvNone; Footer.Color := RGBToColor(226, 232, 240);
  FStatusLabel := TLabel.Create(Self); FStatusLabel.Parent := Footer; FStatusLabel.Align := alClient;
  FStatusLabel.BorderSpacing.Left := 12; FStatusLabel.BorderSpacing.Top := 6;
  FStatusLabel.Caption := 'Cena pronta.';

  LeftP := TPanel.Create(Self); LeftP.Parent := Self; LeftP.Align := alLeft; LeftP.Width := 240;
  LeftP.BevelOuter := bvNone; LeftP.Color := clWhite;
  L := TLabel.Create(Self); L.Parent := LeftP; L.Align := alTop; L.Height := 24; L.Caption := ' Câmeras'; L.Font.Style := [fsBold];
  FCamList := TListBox.Create(Self); FCamList.Parent := LeftP; FCamList.Align := alTop; FCamList.Height := 160;
  B := TButton.Create(Self); B.Parent := LeftP; B.Align := alTop; B.Height := 30;
  B.Caption := 'Salvar câmera da vista atual'; B.OnClick := @AddCamFromViewClick;
  L := TLabel.Create(Self); L.Parent := LeftP; L.Align := alTop; L.Height := 24; L.Caption := ' Luzes Artificiais'; L.Font.Style := [fsBold];
  FLightList := TListBox.Create(Self); FLightList.Parent := LeftP; FLightList.Align := alClient;

  RightP := TPanel.Create(Self); RightP.Parent := Self; RightP.Align := alRight; RightP.Width := 250;
  RightP.BevelOuter := bvNone; RightP.Color := clWhite;
  L := TLabel.Create(Self); L.Parent := RightP; L.SetBounds(12, 12, 220, 22); L.Caption := 'Hora do Sol (0..24 h):';
  FHourEdit := TEdit.Create(Self); FHourEdit.Parent := RightP; FHourEdit.SetBounds(12, 36, 100, 28); FHourEdit.Text := '14.5';
  L := TLabel.Create(Self); L.Parent := RightP; L.SetBounds(12, 74, 220, 22); L.Caption := 'Orientação Norte (graus):';
  FNorthEdit := TEdit.Create(Self); FNorthEdit.Parent := RightP; FNorthEdit.SetBounds(12, 98, 100, 28); FNorthEdit.Text := '0';
  L := TLabel.Create(Self); L.Parent := RightP; L.SetBounds(12, 136, 220, 22); L.Caption := 'Atmosfera:';
  FAtmCombo := TComboBox.Create(Self); FAtmCombo.Parent := RightP; FAtmCombo.SetBounds(12, 160, 220, 28);
  FAtmCombo.Style := csDropDownList;
  FAtmCombo.Items.Add('Céu Limpo'); FAtmCombo.Items.Add('Neblina'); FAtmCombo.Items.Add('Chuva');
  FAtmCombo.ItemIndex := 0;
  B := TButton.Create(Self); B.Parent := RightP; B.SetBounds(12, 206, 104, 30); B.Caption := 'Cena Diurna'; B.OnClick := @DayPresetClick;
  B := TButton.Create(Self); B.Parent := RightP; B.SetBounds(124, 206, 108, 30); B.Caption := 'Cena Noturna'; B.OnClick := @NightPresetClick;
  B := TButton.Create(Self); B.Parent := RightP; B.SetBounds(12, 250, 220, 34); B.Caption := 'Renderizar Prévia'; B.OnClick := @RenderPreviewClick;
  B := TButton.Create(Self); B.Parent := RightP; B.SetBounds(12, 294, 220, 34); B.Caption := 'Exportar Imagem PNG...'; B.OnClick := @ExportPNGClick;

  FPages := TPageControl.Create(Self); FPages.Parent := Self; FPages.Align := alClient;
  TabView := TTabSheet.Create(FPages); TabView.PageControl := FPages; TabView.Caption := 'Navegação Interativa 3D';
  Bar := TPanel.Create(TabView); Bar.Parent := TabView; Bar.Align := alTop; Bar.Height := 38; Bar.BevelOuter := bvNone;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(8, 4, 140, 30); B.Caption := 'Importar Maquete'; B.OnClick := @ImportMaqueteClick;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(154, 4, 140, 30); B.Caption := 'Exportar Sequência'; B.OnClick := @ExportSequenceClick;
  FViewport := TEAViewport3D.Create(TabView); FViewport.Parent := TabView; FViewport.Align := alClient;

  TabRender := TTabSheet.Create(FPages); TabRender.PageControl := FPages; TabRender.Caption := 'Render Final (Raytracer)';
  FRenderBox := TPaintBox.Create(TabRender); FRenderBox.Parent := TabRender; FRenderBox.Align := alClient;
  FRenderBox.OnPaint := @PaintRenderBox;
end;

procedure TCenaMainForm.RefreshLists;
var I: Integer;
begin
  FCamList.Items.Clear;
  for I := 0 to High(FCena.Cameras) do FCamList.Items.Add(FCena.Cameras[I].Name);
  FLightList.Items.Clear;
  for I := 0 to High(FCena.Lights) do FLightList.Items.Add(Format('%s (%.0f W)', [FCena.Lights[I].Name, FCena.Lights[I].PowerWatts]));
  FHourEdit.Text := FloatToStr(FCena.HourOfDay);
  FNorthEdit.Text := FloatToStr(FCena.NorthDeg);
end;

procedure TCenaMainForm.PaintRenderBox(Sender: TObject);
var
  X, Y, SX, SY, CellW, CellH: Integer;
  C: LongWord;
begin
  FRenderBox.Canvas.Brush.Color := RGBToColor(15, 23, 42);
  FRenderBox.Canvas.FillRect(0, 0, FRenderBox.Width, FRenderBox.Height);
  if Length(FRenderPixels) < FRenderW * FRenderH then
  begin
    FRenderBox.Canvas.Font.Color := clWhite;
    FRenderBox.Canvas.TextOut(24, 24, 'Clique em "Renderizar Prévia" para gerar a imagem fotorrealista.');
    Exit;
  end;
  CellW := Max(1, (FRenderBox.Width - 20) div FRenderW);
  CellH := Max(1, (FRenderBox.Height - 20) div FRenderH);
  for Y := 0 to FRenderH - 1 do
    for X := 0 to FRenderW - 1 do
    begin
      C := FRenderPixels[Y * FRenderW + X];
      FRenderBox.Canvas.Brush.Color := RGBToColor((C shr 16) and $FF, (C shr 8) and $FF, C and $FF);
      SX := 10 + X * CellW;
      SY := 10 + Y * CellH;
      FRenderBox.Canvas.FillRect(SX, SY, SX + CellW, SY + CellH);
    end;
end;

procedure TCenaMainForm.RenderPreviewClick(Sender: TObject);
var
  Eye, Target: TEAVec3;
  FOV: Double;
  Idx: Integer;
begin
  FCena.HourOfDay := StrToFloatDef(FHourEdit.Text, 14.5);
  FCena.NorthDeg := StrToFloatDef(FNorthEdit.Text, 0.0);
  FCena.Atmosphere := TCenaAtmosphere(Max(0, FAtmCombo.ItemIndex));
  Idx := FCamList.ItemIndex;
  if (Idx >= 0) and (Idx < Length(FCena.Cameras)) then
  begin
    Eye := FCena.Cameras[Idx].EyeMM;
    Target := FCena.Cameras[Idx].TargetMM;
    FOV := FCena.Cameras[Idx].FOVDeg;
  end
  else
  begin
    Eye := EAV3(8500, -5500, 2600);
    Target := FViewport.Target;
    FOV := 55.0;
  end;
  SetLength(FRenderPixels, FRenderW * FRenderH);
  FCena.RenderImageToBuffer(FRenderW, FRenderH, Eye, Target, FOV, FCena.HourOfDay, True, FRenderPixels);
  FPages.ActivePageIndex := 1;
  FRenderBox.Invalidate;
  FStatusLabel.Caption := Format('Prévia renderizada (%dx%d, %.1fh).', [FRenderW, FRenderH, FCena.HourOfDay]);
end;

procedure TCenaMainForm.ExportPNGClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'PNG (*.png)|*.png'; D.DefaultExt := 'png'; D.FileName := 'render_cena.png';
    if not D.Execute then Exit;
    FCena.HourOfDay := StrToFloatDef(FHourEdit.Text, 14.5);
    FCena.RenderToPNG(D.FileName, 640, 400, Max(0, FCamList.ItemIndex), True);
    ShowMessage('Imagem exportada: ' + D.FileName);
  finally D.Free; end;
end;

procedure TCenaMainForm.ExportSequenceClick(Sender: TObject);
var D: TSelectDirectoryDialog; N: Integer;
begin
  D := TSelectDirectoryDialog.Create(Self);
  try
    if not D.Execute then Exit;
    N := FCena.RenderSequencePNG(D.FileName, 320, 200, 8, 2.0);
    ShowMessage(Format('%d quadros PNG exportados em %s', [N, D.FileName]));
  finally D.Free; end;
end;

procedure TCenaMainForm.DayPresetClick(Sender: TObject);
begin
  FHourEdit.Text := '13.5';
  RenderPreviewClick(nil);
end;

procedure TCenaMainForm.NightPresetClick(Sender: TObject);
begin
  FHourEdit.Text := '21.5';
  RenderPreviewClick(nil);
end;

procedure TCenaMainForm.AddCamFromViewClick(Sender: TObject);
var
  Yaw, Pitch: Double;
  Eye: TEAVec3;
begin
  Yaw := DegToRad(FViewport.YawDeg);
  Pitch := DegToRad(FViewport.PitchDeg);
  Eye := EAV3(
    FViewport.Target.X + FViewport.DistanceMM * Cos(Pitch) * Sin(Yaw),
    FViewport.Target.Y - FViewport.DistanceMM * Cos(Pitch) * Cos(Yaw),
    FViewport.Target.Z + FViewport.DistanceMM * Sin(Pitch));
  FCena.AddCamera(Format('cam-%d', [Length(FCena.Cameras) + 1]),
    Format('Câmera %d', [Length(FCena.Cameras) + 1]), Eye, FViewport.Target, 55.0);
  RefreshLists;
end;

procedure TCenaMainForm.ImportMaqueteClick(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Pacote Maquete (*.maquete.pkg.json;*.json)|*.json';
    if not D.Execute then Exit;
    FCena.ImportMaquetePackage(D.FileName, True);
    FViewport.Mesh.Assign(FCena.SceneMesh);
    FViewport.FitToMesh;
    RefreshLists;
  except on E: Exception do MessageDlg('Criador de Cenas', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TCenaMainForm.ImportLightsClick(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Estado de Iluminação (*.json)|*.json';
    if not D.Execute then Exit;
    FCena.ImportLightingPackage(D.FileName);
    RefreshLists;
  except on E: Exception do MessageDlg('Iluminação', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TCenaMainForm.SaveSceneClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Cena (*.cena.json)|*.cena.json'; D.DefaultExt := 'cena.json'; D.FileName := 'projeto.cena.json';
    if not D.Execute then Exit;
    FCena.HourOfDay := StrToFloatDef(FHourEdit.Text, 14.5);
    FCena.SaveSceneFile(D.FileName);
    FStatusLabel.Caption := 'Cena salva: ' + ExtractFileName(D.FileName);
  finally D.Free; end;
end;

procedure TCenaMainForm.OpenSceneClick(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Cena (*.cena.json)|*.cena.json';
    if not D.Execute then Exit;
    FCena.LoadSceneFile(D.FileName);
    FViewport.Mesh.Assign(FCena.SceneMesh);
    FViewport.FitToMesh;
    RefreshLists;
  except on E: Exception do MessageDlg('Cena', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TCenaMainForm.SetupClick(Sender: TObject);
begin
  EAShowSetup(Self);
end;

end.
