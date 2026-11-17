unit maquete3d_main;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Types, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  ComCtrls, Dialogs, Menus, CheckLst,
  ea_geometria, ea_pacote, ea_modelo, ea_ancoras, ea_malha3d, ea_visual3d,
  ea_config, ea_config_ui, ea_workflow,
  maq_texturas, maq_objetos, maq_projeto;

type
  TMaqMainForm = class(TForm)
  private
    FProj: TMAQProject;
    FCurrentFile: string;
    FViewport: TEAViewport3D;
    FObjViewport: TEAViewport3D;
    FTexPreview: TPaintBox;
    FTexBuf: TMAQPixelBuffer;
    FTexRes: Integer;
    FPages: TPageControl;
    FFloorList: TCheckListBox;
    FInstList: TListBox;
    FObjLibList: TListBox;
    FSkinLibList: TListBox;
    FAlertsMemo: TMemo;
    FStatusLabel: TLabel;
    FPatCombo: TComboBox;
    FSeedSpin, FScaleXEdit, FScaleYEdit, FObjXEdit, FObjYEdit, FObjZEdit: TEdit;
    procedure BuildUI;
    procedure BuildMenus;
    procedure RefreshLists;
    procedure Rebuild3D;
    procedure PaintTexPreview(Sender: TObject);
    procedure FloorCheckClick(Sender: TObject);
    procedure ObjSelectClick(Sender: TObject);
    procedure SkinSelectClick(Sender: TObject);
    procedure ViewPresetClick(Sender: TObject);
    procedure ToggleOrthoClick(Sender: TObject);
    procedure ToggleWireClick(Sender: TObject);
    procedure FitClick(Sender: TObject);
    procedure LoadDemoClick(Sender: TObject);
    procedure OpenMaqueteClick(Sender: TObject);
    procedure SaveMaqueteClick(Sender: TObject);
    procedure ImportPlanClick(Sender: TObject);
    procedure ExportMaquetePkgClick(Sender: TObject);
    procedure ExportGLBClick(Sender: TObject);
    procedure ImportSolidClick(Sender: TObject);
    procedure InsertInstanceClick(Sender: TObject);
    procedure ApplySkinToSelectedClick(Sender: TObject);
    procedure GenerateTexClick(Sender: TObject);
    procedure ExportSkinPkgClick(Sender: TObject);
    procedure LoadOverlayClick(Sender: TObject);
    procedure CheckClashesClick(Sender: TObject);
    procedure SetupClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MaqMainForm: TMaqMainForm;

implementation

constructor TMaqMainForm.Create(AOwner: TComponent);
var
  TaskPkg: string;
begin
  inherited CreateNew(AOwner, 1);
  FProj := TMAQProject.Create;
  FTexRes := 128;
  Caption := 'Maquete 3D — EngenhariaArquitetura';
  Width := 1240;
  Height := 780;
  Constraints.MinWidth := 900;
  Constraints.MinHeight := 620;
  Position := poScreenCenter;
  Font.Name := {$IFDEF WINDOWS}'Segoe UI'{$ELSE}'Sans'{$ENDIF};
  Font.Size := 10;
  Color := RGBToColor(244, 246, 250);

  BuildMenus;
  BuildUI;
  FProj.LoadDemoTwoFloors;
  RefreshLists;
  Rebuild3D;
  FViewport.FitToMesh;

  TaskPkg := WFArg('--task-pkg');
  if (TaskPkg <> '') and FileExists(TaskPkg) then
    FStatusLabel.Caption := 'Tarefa recebida do Planejador: ' + ExtractFileName(TaskPkg);
end;

destructor TMaqMainForm.Destroy;
begin
  FProj.Free;
  inherited Destroy;
end;

procedure TMaqMainForm.BuildMenus;
var
  M: TMainMenu;
  TopMenu: TMenuItem;
  procedure Add(Parent: TMenuItem; const Cap: string; Ev: TNotifyEvent; ATag: Integer = 0);
  var
    It: TMenuItem;
  begin
    It := TMenuItem.Create(M);
    It.Caption := Cap;
    It.OnClick := Ev;
    It.Tag := ATag;
    Parent.Add(It);
  end;
begin
  M := TMainMenu.Create(Self);
  Menu := M;

  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Arquivo'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Carregar demonstração 2 pavimentos', @LoadDemoClick);
  Add(TopMenu, '&Abrir maquete (.maquete.json)...', @OpenMaqueteClick);
  Add(TopMenu, '&Salvar maquete...', @SaveMaqueteClick);
  Add(TopMenu, '-', nil);
  Add(TopMenu, '&Importar planta 2D / DXF / DWG / IFC...', @ImportPlanClick);
  Add(TopMenu, '&Exportar pacote Maquete (I-11/I-12/I-18)...', @ExportMaquetePkgClick);
  Add(TopMenu, 'Exportar &GLB (glTF 2.0)...', @ExportGLBClick);

  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Exibir'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Isométrica', @ViewPresetClick, 0);
  Add(TopMenu, 'Superior (Planta)', @ViewPresetClick, 1);
  Add(TopMenu, 'Frontal', @ViewPresetClick, 2);
  Add(TopMenu, 'Lateral', @ViewPresetClick, 3);
  Add(TopMenu, '-', nil);
  Add(TopMenu, 'Alternar Perspectiva / Ortográfica', @ToggleOrthoClick);
  Add(TopMenu, 'Alternar Aramado (Wireframe)', @ToggleWireClick);
  Add(TopMenu, 'Enquadrar modelo', @FitClick);

  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Objetos 3D'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Importar sólido STL / 3MF / OBJ / GLB...', @ImportSolidClick);
  Add(TopMenu, 'Inserir objeto selecionado na maquete', @InsertInstanceClick);

  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Texturas (Skins)'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Gerar prévia procedural', @GenerateTexClick);
  Add(TopMenu, 'Aplicar skin ao objeto selecionado', @ApplySkinToSelectedClick);
  Add(TopMenu, 'Exportar pacote de skin + PNGs...', @ExportSkinPkgClick);

  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Coordenação'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Carregar disciplina externa (Elétrica / Tubulações)...', @LoadOverlayClick);
  Add(TopMenu, 'Detectar interferências 3D', @CheckClashesClick);

  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Setup'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Configurações compartilhadas...', @SetupClick);
end;

procedure TMaqMainForm.BuildUI;
var
  Header, Footer, LeftP, RightP, Bar, EdTop, TexCtrl: TPanel;
  L: TLabel;
  B: TButton;
  TabMaq, TabObj, TabTex: TTabSheet;
  P: TMAQTexPattern;
begin
  Header := TPanel.Create(Self); Header.Parent := Self; Header.Align := alTop; Header.Height := 48;
  Header.BevelOuter := bvNone; Header.Color := RGBToColor(15, 23, 42);
  L := TLabel.Create(Self); L.Parent := Header; L.SetBounds(16, 12, 520, 26);
  L.Caption := 'MAQUETE 3D  |  Editor de Objetos 3D & Gerador de Texturas';
  L.Font.Color := clWhite; L.Font.Style := [fsBold];

  Footer := TPanel.Create(Self); Footer.Parent := Self; Footer.Align := alBottom; Footer.Height := 30;
  Footer.BevelOuter := bvNone; Footer.Color := RGBToColor(226, 232, 240);
  FStatusLabel := TLabel.Create(Self); FStatusLabel.Parent := Footer; FStatusLabel.Align := alClient;
  FStatusLabel.BorderSpacing.Left := 12; FStatusLabel.BorderSpacing.Top := 6;
  FStatusLabel.Caption := 'Pronto. Unidades: mm (Z-up)';

  LeftP := TPanel.Create(Self); LeftP.Parent := Self; LeftP.Align := alLeft; LeftP.Width := 250;
  LeftP.BevelOuter := bvNone; LeftP.Color := clWhite;

  L := TLabel.Create(Self); L.Parent := LeftP; L.Align := alTop; L.Height := 24;
  L.Caption := ' Pavimentos'; L.Font.Style := [fsBold];
  FFloorList := TCheckListBox.Create(Self); FFloorList.Parent := LeftP; FFloorList.Align := alTop;
  FFloorList.Height := 120; FFloorList.OnClickCheck := @FloorCheckClick;

  L := TLabel.Create(Self); L.Parent := LeftP; L.Align := alTop; L.Height := 24;
  L.Caption := ' Instâncias na Maquete'; L.Font.Style := [fsBold];
  FInstList := TListBox.Create(Self); FInstList.Parent := LeftP; FInstList.Align := alTop;
  FInstList.Height := 160;

  L := TLabel.Create(Self); L.Parent := LeftP; L.Align := alTop; L.Height := 24;
  L.Caption := ' Biblioteca de Objetos 3D'; L.Font.Style := [fsBold];
  FObjLibList := TListBox.Create(Self); FObjLibList.Parent := LeftP; FObjLibList.Align := alClient;
  FObjLibList.OnClick := @ObjSelectClick;

  RightP := TPanel.Create(Self); RightP.Parent := Self; RightP.Align := alRight; RightP.Width := 260;
  RightP.BevelOuter := bvNone; RightP.Color := clWhite;

  L := TLabel.Create(Self); L.Parent := RightP; L.Align := alTop; L.Height := 24;
  L.Caption := ' Biblioteca de Skins (PBR)'; L.Font.Style := [fsBold];
  FSkinLibList := TListBox.Create(Self); FSkinLibList.Parent := RightP; FSkinLibList.Align := alTop;
  FSkinLibList.Height := 220; FSkinLibList.OnClick := @SkinSelectClick;

  B := TButton.Create(Self); B.Parent := RightP; B.Align := alTop; B.Height := 32;
  B.Caption := 'Aplicar skin ao selecionado'; B.OnClick := @ApplySkinToSelectedClick;

  L := TLabel.Create(Self); L.Parent := RightP; L.Align := alTop; L.Height := 24;
  L.Caption := ' Avisos & Interferências'; L.Font.Style := [fsBold];
  FAlertsMemo := TMemo.Create(Self); FAlertsMemo.Parent := RightP; FAlertsMemo.Align := alClient;
  FAlertsMemo.ReadOnly := True;

  FPages := TPageControl.Create(Self); FPages.Parent := Self; FPages.Align := alClient;

  { Aba 1: Maquete 3D }
  TabMaq := TTabSheet.Create(FPages); TabMaq.PageControl := FPages; TabMaq.Caption := 'Maquete 3D';
  Bar := TPanel.Create(TabMaq); Bar.Parent := TabMaq; Bar.Align := alTop; Bar.Height := 38; Bar.BevelOuter := bvNone;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(6, 4, 84, 30); B.Caption := 'Isométrica'; B.Tag := 0; B.OnClick := @ViewPresetClick;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(96, 4, 72, 30); B.Caption := 'Topo'; B.Tag := 1; B.OnClick := @ViewPresetClick;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(174, 4, 76, 30); B.Caption := 'Frontal'; B.Tag := 2; B.OnClick := @ViewPresetClick;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(256, 4, 88, 30); B.Caption := 'Enquadrar'; B.OnClick := @FitClick;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(350, 4, 118, 30); B.Caption := 'Importar Planta'; B.OnClick := @ImportPlanClick;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(474, 4, 118, 30); B.Caption := 'Exportar GLB'; B.OnClick := @ExportGLBClick;
  FViewport := TEAViewport3D.Create(TabMaq); FViewport.Parent := TabMaq; FViewport.Align := alClient;

  { Aba 2: Editor de Objetos 3D }
  TabObj := TTabSheet.Create(FPages); TabObj.PageControl := FPages; TabObj.Caption := 'Editor de Objetos 3D';
  EdTop := TPanel.Create(TabObj); EdTop.Parent := TabObj; EdTop.Align := alTop; EdTop.Height := 44; EdTop.BevelOuter := bvNone;
  B := TButton.Create(EdTop); B.Parent := EdTop; B.SetBounds(8, 6, 170, 30); B.Caption := 'Importar STL / 3MF / OBJ'; B.OnClick := @ImportSolidClick;
  L := TLabel.Create(EdTop); L.Parent := EdTop; L.SetBounds(190, 12, 54, 22); L.Caption := 'X (mm):';
  FObjXEdit := TEdit.Create(EdTop); FObjXEdit.Parent := EdTop; FObjXEdit.SetBounds(244, 8, 64, 26); FObjXEdit.Text := '1500';
  L := TLabel.Create(EdTop); L.Parent := EdTop; L.SetBounds(316, 12, 54, 22); L.Caption := 'Y (mm):';
  FObjYEdit := TEdit.Create(EdTop); FObjYEdit.Parent := EdTop; FObjYEdit.SetBounds(370, 8, 64, 26); FObjYEdit.Text := '1500';
  L := TLabel.Create(EdTop); L.Parent := EdTop; L.SetBounds(442, 12, 54, 22); L.Caption := 'Z (mm):';
  FObjZEdit := TEdit.Create(EdTop); FObjZEdit.Parent := EdTop; FObjZEdit.SetBounds(496, 8, 56, 26); FObjZEdit.Text := '0';
  B := TButton.Create(EdTop); B.Parent := EdTop; B.SetBounds(560, 6, 140, 30); B.Caption := 'Inserir na Maquete'; B.OnClick := @InsertInstanceClick;
  FObjViewport := TEAViewport3D.Create(TabObj); FObjViewport.Parent := TabObj; FObjViewport.Align := alClient;

  { Aba 3: Gerador de Texturas }
  TabTex := TTabSheet.Create(FPages); TabTex.PageControl := FPages; TabTex.Caption := 'Gerador de Texturas (Skins)';
  TexCtrl := TPanel.Create(TabTex); TexCtrl.Parent := TabTex; TexCtrl.Align := alTop; TexCtrl.Height := 50; TexCtrl.BevelOuter := bvNone;
  L := TLabel.Create(TexCtrl); L.Parent := TexCtrl; L.SetBounds(8, 14, 54, 22); L.Caption := 'Padrão:';
  FPatCombo := TComboBox.Create(TexCtrl); FPatCombo.Parent := TexCtrl; FPatCombo.SetBounds(64, 10, 115, 28); FPatCombo.Style := csDropDownList;
  for P := Low(P) to High(P) do FPatCombo.Items.Add(MAQPatternToStr(P));
  FPatCombo.ItemIndex := 0;
  L := TLabel.Create(TexCtrl); L.Parent := TexCtrl; L.SetBounds(186, 14, 60, 22); L.Caption := 'Semente:';
  FSeedSpin := TEdit.Create(TexCtrl); FSeedSpin.Parent := TexCtrl; FSeedSpin.SetBounds(248, 10, 56, 28); FSeedSpin.Text := '101';
  L := TLabel.Create(TexCtrl); L.Parent := TexCtrl; L.SetBounds(312, 14, 80, 22); L.Caption := 'Escala (mm):';
  FScaleXEdit := TEdit.Create(TexCtrl); FScaleXEdit.Parent := TexCtrl; FScaleXEdit.SetBounds(394, 10, 56, 28); FScaleXEdit.Text := '600';
  FScaleYEdit := TEdit.Create(TexCtrl); FScaleYEdit.Parent := TexCtrl; FScaleYEdit.SetBounds(454, 10, 56, 28); FScaleYEdit.Text := '600';
  B := TButton.Create(TexCtrl); B.Parent := TexCtrl; B.SetBounds(518, 9, 95, 30); B.Caption := 'Gerar Mapa'; B.OnClick := @GenerateTexClick;
  B := TButton.Create(TexCtrl); B.Parent := TexCtrl; B.SetBounds(618, 9, 105, 30); B.Caption := 'Exportar Skin'; B.OnClick := @ExportSkinPkgClick;
  FTexPreview := TPaintBox.Create(TabTex); FTexPreview.Parent := TabTex; FTexPreview.Align := alClient;
  FTexPreview.OnPaint := @PaintTexPreview;
end;

procedure TMaqMainForm.RefreshLists;
var
  I: Integer;
begin
  FFloorList.Items.Clear;
  for I := 0 to High(FProj.Model.Floors) do
  begin
    FFloorList.Items.Add(Format('%s (%.2f m)', [FProj.Model.Floors[I].Name, FProj.Model.Floors[I].ElevationMM / 1000.0]));
    FFloorList.Checked[I] := FProj.IsFloorVisible(FProj.Model.Floors[I].Id);
  end;

  FInstList.Items.Clear;
  for I := 0 to High(FProj.Instances) do
    FInstList.Items.Add(Format('%s [%s] (%s)', [FProj.Instances[I].InstanceId,
      FProj.Instances[I].AssetId, EAAnchorStatusToStr(FProj.Instances[I].Anchor.Status)]));

  FObjLibList.Items.Clear;
  for I := 0 to High(FProj.Objects.Assets) do
    FObjLibList.Items.Add(FProj.Objects.Assets[I].Name);
  if (FObjLibList.Items.Count > 0) and (FObjLibList.ItemIndex < 0) then
  begin
    FObjLibList.ItemIndex := 0;
    ObjSelectClick(nil);
  end;

  FSkinLibList.Items.Clear;
  for I := 0 to High(FProj.Skins.Items) do
    FSkinLibList.Items.Add(FProj.Skins.Items[I].Name);
  if (FSkinLibList.Items.Count > 0) and (FSkinLibList.ItemIndex < 0) then
  begin
    FSkinLibList.ItemIndex := 0;
    SkinSelectClick(nil);
  end;

  FAlertsMemo.Lines.Assign(FProj.Alerts);
  for I := 0 to High(FProj.CoordRequests) do
    FAlertsMemo.Lines.Add(FProj.CoordRequests[I].Description);
end;

procedure TMaqMainForm.Rebuild3D;
begin
  FProj.BuildCompositeMesh(FViewport.Mesh, True);
  FViewport.Invalidate;
  FStatusLabel.Caption := Format('Pavimentos: %d | Paredes: %d | Instâncias: %d | Triângulos: %d',
    [Length(FProj.Model.Floors), Length(FProj.Model.Walls), Length(FProj.Instances), FViewport.Mesh.TriangleCount]);
end;

procedure TMaqMainForm.FloorCheckClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to High(FProj.Model.Floors) do
    if I < FFloorList.Items.Count then
      FProj.SetFloorVisible(FProj.Model.Floors[I].Id, FFloorList.Checked[I]);
  Rebuild3D;
end;

procedure TMaqMainForm.ObjSelectClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FObjLibList.ItemIndex;
  if (Idx < 0) or (Idx >= Length(FProj.Objects.Assets)) then Exit;
  FObjViewport.Mesh.Assign(FProj.Objects.Assets[Idx].Mesh);
  FObjViewport.FitToMesh;
end;

procedure TMaqMainForm.SkinSelectClick(Sender: TObject);
var
  Idx: Integer;
  S: TMAQSkin;
  N, R: TMAQPixelBuffer;
begin
  Idx := FSkinLibList.ItemIndex;
  if (Idx < 0) or (Idx >= Length(FProj.Skins.Items)) then Exit;
  S := FProj.Skins.Items[Idx];
  FPatCombo.ItemIndex := Ord(S.Pattern);
  FSeedSpin.Text := IntToStr(S.Seed);
  FScaleXEdit.Text := IntToStr(Round(S.ScaleXMM));
  FScaleYEdit.Text := IntToStr(Round(S.ScaleYMM));
  MAQGenerateProceduralMaps(S, FTexRes, FTexBuf, N, R);
  FTexPreview.Invalidate;
end;

procedure TMaqMainForm.PaintTexPreview(Sender: TObject);
var
  X, Y, Size, Cell: Integer;
  C: LongWord;
begin
  FTexPreview.Canvas.Brush.Color := RGBToColor(30, 41, 59);
  FTexPreview.Canvas.FillRect(0, 0, FTexPreview.Width, FTexPreview.Height);
  if Length(FTexBuf) < FTexRes * FTexRes then Exit;
  Size := Min(FTexPreview.Width - 40, FTexPreview.Height - 40);
  if Size < 64 then Size := 64;
  Cell := Max(1, Size div FTexRes);
  for Y := 0 to FTexRes - 1 do
    for X := 0 to FTexRes - 1 do
    begin
      C := FTexBuf[Y * FTexRes + X];
      FTexPreview.Canvas.Brush.Color := RGBToColor((C shr 16) and $FF, (C shr 8) and $FF, C and $FF);
      FTexPreview.Canvas.FillRect(20 + X * Cell, 20 + Y * Cell, 20 + (X + 1) * Cell, 20 + (Y + 1) * Cell);
    end;
end;

procedure TMaqMainForm.ViewPresetClick(Sender: TObject);
begin
  FViewport.SetPreset(TEAViewPreset(TControl(Sender).Tag));
end;

procedure TMaqMainForm.ToggleOrthoClick(Sender: TObject);
begin
  FViewport.Ortho := not FViewport.Ortho;
  FViewport.Invalidate;
end;

procedure TMaqMainForm.ToggleWireClick(Sender: TObject);
begin
  FViewport.Wireframe := not FViewport.Wireframe;
  FViewport.Invalidate;
end;

procedure TMaqMainForm.FitClick(Sender: TObject);
begin
  FViewport.FitToMesh;
end;

procedure TMaqMainForm.LoadDemoClick(Sender: TObject);
begin
  FProj.LoadDemoTwoFloors;
  RefreshLists;
  Rebuild3D;
  FViewport.FitToMesh;
end;

procedure TMaqMainForm.OpenMaqueteClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Maquete 3D (*.maquete.json)|*.maquete.json|Todos (*.*)|*.*';
    if not D.Execute then Exit;
    FProj.LoadMaqueteFile(D.FileName);
    FCurrentFile := D.FileName;
    RefreshLists; Rebuild3D; FViewport.FitToMesh;
  except on E: Exception do MessageDlg('Maquete 3D', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TMaqMainForm.SaveMaqueteClick(Sender: TObject);
var
  D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Maquete 3D (*.maquete.json)|*.maquete.json';
    D.DefaultExt := 'maquete.json';
    D.FileName := 'edificacao.maquete.json';
    if not D.Execute then Exit;
    FProj.SaveMaqueteFile(D.FileName);
    FCurrentFile := D.FileName;
    FStatusLabel.Caption := 'Maquete salva: ' + ExtractFileName(D.FileName);
  except on E: Exception do MessageDlg('Maquete 3D', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TMaqMainForm.ImportPlanClick(Sender: TObject);
var
  D: TOpenDialog;
  FloorId, ElevStr, DiffSum: string;
  ElevMM: Double;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Plantas CAD / BIM (*.ea2d.json;*.eacad;*.dxf;*.dwg;*.ifc)|*.ea2d.json;*.eacad;*.dxf;*.dwg;*.ifc|Todos (*.*)|*.*';
    if not D.Execute then Exit;
    FloorId := 'terreo';
    ElevStr := '0';
    if not InputQuery('Pavimento', 'ID do pavimento (ex.: terreo, piso1):', FloorId) then Exit;
    if not InputQuery('Cota de Nível', 'Elevação do pavimento (mm):', ElevStr) then Exit;
    ElevMM := StrToFloatDef(ElevStr, 0.0);
    if LowerCase(ExtractFileExt(D.FileName)) = '.json' then
      FProj.ImportArchitecture2D(D.FileName, FloorId, FloorId, ElevMM, True, DiffSum)
    else
      FProj.ImportCADOrBIMFloor(D.FileName, FloorId, FloorId, ElevMM);
    RefreshLists; Rebuild3D; FViewport.FitToMesh;
    if DiffSum <> '' then ShowMessage(DiffSum);
  except on E: Exception do MessageDlg('Importação', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TMaqMainForm.ExportMaquetePkgClick(Sender: TObject);
var
  D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Pacote Maquete 3D (*.maquete.pkg.json)|*.maquete.pkg.json';
    D.DefaultExt := 'maquete.pkg.json';
    D.FileName := 'maquete_publicada.maquete.pkg.json';
    if not D.Execute then Exit;
    FProj.ExportMaquetePackage(D.FileName);
    ShowMessage('Pacote de Maquete exportado com GLB e hashes SHA-256.');
  except on E: Exception do MessageDlg('Exportação', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TMaqMainForm.ExportGLBClick(Sender: TObject);
var
  D: TSaveDialog;
  Lim: string;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'glTF Binary (*.glb)|*.glb|Wavefront OBJ (*.obj)|*.obj';
    D.FileName := 'maquete.glb';
    if not D.Execute then Exit;
    if LowerCase(ExtractFileExt(D.FileName)) = '.obj' then
      EAExportOBJ(FViewport.Mesh, D.FileName)
    else
    begin
      EAExportGLB(FViewport.Mesh, D.FileName, Lim);
      ShowMessage(Lim);
    end;
  except on E: Exception do MessageDlg('Exportação 3D', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TMaqMainForm.ImportSolidClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Sólidos 3D (*.stl;*.3mf;*.obj;*.glb)|*.stl;*.3mf;*.obj;*.glb|Todos (*.*)|*.*';
    if not D.Execute then Exit;
    FProj.Objects.ImportExternalSolid(D.FileName, '', '');
    RefreshLists;
    FObjLibList.ItemIndex := FObjLibList.Items.Count - 1;
    ObjSelectClick(nil);
    FPages.ActivePageIndex := 1;
  except on E: Exception do MessageDlg('Importar Sólido', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TMaqMainForm.InsertInstanceClick(Sender: TObject);
var
  Idx: Integer;
  FloorId: string;
begin
  Idx := FObjLibList.ItemIndex;
  if (Idx < 0) or (Idx >= Length(FProj.Objects.Assets)) then Exit;
  if Length(FProj.Model.Floors) > 0 then FloorId := FProj.Model.Floors[0].Id else FloorId := 'terreo';
  if (FFloorList.ItemIndex >= 0) and (FFloorList.ItemIndex < Length(FProj.Model.Floors)) then
    FloorId := FProj.Model.Floors[FFloorList.ItemIndex].Id;
  FProj.InsertObjectInstance(FProj.Objects.Assets[Idx].AssetId, FloorId, FloorId, ahkFloor,
    EAV3(StrToFloatDef(FObjXEdit.Text, 1500), StrToFloatDef(FObjYEdit.Text, 1500), StrToFloatDef(FObjZEdit.Text, 0)));
  RefreshLists; Rebuild3D;
end;

procedure TMaqMainForm.ApplySkinToSelectedClick(Sender: TObject);
var
  SIdx, IIdx: Integer;
begin
  SIdx := FSkinLibList.ItemIndex;
  IIdx := FInstList.ItemIndex;
  if (SIdx < 0) or (SIdx >= Length(FProj.Skins.Items)) then Exit;
  if (IIdx >= 0) and (IIdx < Length(FProj.Instances)) then
  begin
    FProj.Instances[IIdx].OverrideSkinId := FProj.Skins.Items[SIdx].Id;
    Rebuild3D;
  end
  else if (FObjLibList.ItemIndex >= 0) and (FObjLibList.ItemIndex < Length(FProj.Objects.Assets)) then
  begin
    FProj.Objects.Assets[FObjLibList.ItemIndex].AssignSkinToObject(FProj.Skins.Items[SIdx].Id, FProj.Skins);
    ObjSelectClick(nil);
    Rebuild3D;
  end;
end;

procedure TMaqMainForm.GenerateTexClick(Sender: TObject);
var
  S: TMAQSkin;
  N, R: TMAQPixelBuffer;
begin
  if (FSkinLibList.ItemIndex >= 0) and (FSkinLibList.ItemIndex < Length(FProj.Skins.Items)) then
    S := FProj.Skins.Items[FSkinLibList.ItemIndex]
  else
    S := FProj.Skins.Items[0];
  S.Pattern := TMAQTexPattern(Max(0, FPatCombo.ItemIndex));
  S.Seed := LongWord(StrToIntDef(FSeedSpin.Text, 101));
  S.ScaleXMM := StrToFloatDef(FScaleXEdit.Text, 600);
  S.ScaleYMM := StrToFloatDef(FScaleYEdit.Text, 600);
  if FSkinLibList.ItemIndex >= 0 then FProj.Skins.Items[FSkinLibList.ItemIndex] := S;
  MAQGenerateProceduralMaps(S, FTexRes, FTexBuf, N, R);
  FTexPreview.Invalidate;
end;

procedure TMaqMainForm.ExportSkinPkgClick(Sender: TObject);
var
  D: TSaveDialog;
  Idx: Integer;
begin
  Idx := Max(0, FSkinLibList.ItemIndex);
  if Idx >= Length(FProj.Skins.Items) then Exit;
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Pacote de Skin (*.skin.json)|*.skin.json';
    D.DefaultExt := 'skin.json';
    D.FileName := FProj.Skins.Items[Idx].Id + '.skin.json';
    if not D.Execute then Exit;
    MAQExportSkinPackage(FProj.Skins.Items[Idx], 256, D.FileName);
    ShowMessage('Skin e mapas PNG exportados com sucesso.');
  except on E: Exception do MessageDlg('Skin', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TMaqMainForm.LoadOverlayClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Disciplinas (*.json)|*.json';
    if not D.Execute then Exit;
    FProj.ImportDisciplineOverlay(D.FileName);
    Rebuild3D;
    RefreshLists;
  except on E: Exception do MessageDlg('Coordenação', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TMaqMainForm.CheckClashesClick(Sender: TObject);
var
  N: Integer;
begin
  N := FProj.DetectDisciplineClashes;
  RefreshLists;
  ShowMessage(Format('%d interferência(s) geométrica(s) encontrada(s) entre disciplinas.', [N]));
end;

procedure TMaqMainForm.SetupClick(Sender: TObject);
begin
  EAShowSetup(Self);
end;

end.
