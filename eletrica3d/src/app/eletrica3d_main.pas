unit eletrica3d_main;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  ComCtrls, Grids, Dialogs, Menus,
  ea_geometria, ea_ancoras, ea_visual3d, ea_config_ui, ea_workflow,
  ele_projeto;

type
  TELEMainForm = class(TForm)
  private
    FEle: TELEProject;
    FViewport: TEAViewport3D;
    FUnifilarBox: TPaintBox;
    FQuantGrid: TStringGrid;
    FCircuitList, FPointList: TListBox;
    FAlertsMemo: TMemo;
    FStatusLabel: TLabel;
    procedure BuildMenus;
    procedure BuildUI;
    procedure RefreshUI;
    procedure PaintUnifilar(Sender: TObject);
    procedure ImportMaqueteClick(Sender: TObject);
    procedure SaveEleClick(Sender: TObject);
    procedure OpenEleClick(Sender: TObject);
    procedure ExportLayerClick(Sender: TObject);
    procedure ExportSimModelClick(Sender: TObject);
    procedure ExportLightingClick(Sender: TObject);
    procedure ExportBOMClick(Sender: TObject);
    procedure AddSocketClick(Sender: TObject);
    procedure ClashPlumbingClick(Sender: TObject);
    procedure SetupClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  EleMainForm: TELEMainForm;

implementation

constructor TELEMainForm.Create(AOwner: TComponent);
var
  TaskPkg: string;
begin
  inherited CreateNew(AOwner, 1);
  FEle := TELEProject.Create;
  Caption := 'Elétrica 3D — EngenhariaArquitetura';
  Width := 1220;
  Height := 760;
  Position := poScreenCenter;
  Font.Name := {$IFDEF WINDOWS}'Segoe UI'{$ELSE}'Sans'{$ENDIF};
  Font.Size := 10;
  Color := RGBToColor(244, 246, 250);

  BuildMenus;
  BuildUI;
  FEle.LoadDemoProject;
  RefreshUI;
  FViewport.FitToMesh;

  TaskPkg := WFArg('--task-pkg');
  if (TaskPkg <> '') and FileExists(TaskPkg) then
    FStatusLabel.Caption := 'Tarefa recebida do Planejador: ' + ExtractFileName(TaskPkg);
end;

destructor TELEMainForm.Destroy;
begin
  FEle.Free;
  inherited Destroy;
end;

procedure TELEMainForm.BuildMenus;
var M: TMainMenu; TopMenu: TMenuItem;
  procedure Add(P: TMenuItem; const Cap: string; Ev: TNotifyEvent);
  var It: TMenuItem;
  begin It := TMenuItem.Create(M); It.Caption := Cap; It.OnClick := Ev; P.Add(It); end;
begin
  M := TMainMenu.Create(Self); Menu := M;
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Arquivo'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Importar Maquete 3D (somente leitura)...', @ImportMaqueteClick);
  Add(TopMenu, 'Abrir Projeto Elétrico (.ele.json)...', @OpenEleClick);
  Add(TopMenu, 'Salvar Projeto Elétrico...', @SaveEleClick);
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Inserir'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Inserir Tomada 127V no Circuito C2', @AddSocketClick);
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Exportar'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Publicar Camada Elétrica (I-13 / Maquete 3D)...', @ExportLayerClick);
  Add(TopMenu, 'Exportar Modelo para SimuEletrica (I-16)...', @ExportSimModelClick);
  Add(TopMenu, 'Exportar Iluminação para Criador de Cenas (I-15)...', @ExportLightingClick);
  Add(TopMenu, 'Exportar Quantitativos (CSV)...', @ExportBOMClick);
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Coordenação'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Verificar Interferências com Tubulações (I-20)...', @ClashPlumbingClick);
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Setup'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Configurações compartilhadas...', @SetupClick);
end;

procedure TELEMainForm.BuildUI;
var
  Header, Footer, LeftP, RightP, Bar: TPanel;
  L: TLabel;
  B: TButton;
  Pages: TPageControl;
  Tab3D, TabUni, TabBOM: TTabSheet;
begin
  Header := TPanel.Create(Self); Header.Parent := Self; Header.Align := alTop; Header.Height := 48;
  Header.BevelOuter := bvNone; Header.Color := RGBToColor(15, 23, 42);
  L := TLabel.Create(Self); L.Parent := Header; L.SetBounds(16, 12, 520, 26);
  L.Caption := 'ELÉTRICA 3D  |  Circuitos, Eletrodutos e Coordenação';
  L.Font.Color := clWhite; L.Font.Style := [fsBold];

  Footer := TPanel.Create(Self); Footer.Parent := Self; Footer.Align := alBottom; Footer.Height := 30;
  Footer.BevelOuter := bvNone; Footer.Color := RGBToColor(226, 232, 240);
  FStatusLabel := TLabel.Create(Self); FStatusLabel.Parent := Footer; FStatusLabel.Align := alClient;
  FStatusLabel.BorderSpacing.Left := 12; FStatusLabel.BorderSpacing.Top := 6;

  LeftP := TPanel.Create(Self); LeftP.Parent := Self; LeftP.Align := alLeft; LeftP.Width := 250;
  LeftP.BevelOuter := bvNone; LeftP.Color := clWhite;
  L := TLabel.Create(Self); L.Parent := LeftP; L.Align := alTop; L.Height := 24; L.Caption := ' Circuitos'; L.Font.Style := [fsBold];
  FCircuitList := TListBox.Create(Self); FCircuitList.Parent := LeftP; FCircuitList.Align := alTop; FCircuitList.Height := 160;
  L := TLabel.Create(Self); L.Parent := LeftP; L.Align := alTop; L.Height := 24; L.Caption := ' Pontos & Quadros'; L.Font.Style := [fsBold];
  FPointList := TListBox.Create(Self); FPointList.Parent := LeftP; FPointList.Align := alClient;

  RightP := TPanel.Create(Self); RightP.Parent := Self; RightP.Align := alRight; RightP.Width := 260;
  RightP.BevelOuter := bvNone; RightP.Color := clWhite;
  L := TLabel.Create(Self); L.Parent := RightP; L.Align := alTop; L.Height := 24; L.Caption := ' Verificações & Alertas (NBR 5410)'; L.Font.Style := [fsBold];
  FAlertsMemo := TMemo.Create(Self); FAlertsMemo.Parent := RightP; FAlertsMemo.Align := alClient; FAlertsMemo.ReadOnly := True;

  Pages := TPageControl.Create(Self); Pages.Parent := Self; Pages.Align := alClient;
  Tab3D := TTabSheet.Create(Pages); Tab3D.PageControl := Pages; Tab3D.Caption := 'Instalação 3D';
  Bar := TPanel.Create(Tab3D); Bar.Parent := Tab3D; Bar.Align := alTop; Bar.Height := 38; Bar.BevelOuter := bvNone;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(8, 4, 150, 30); B.Caption := 'Importar Maquete'; B.OnClick := @ImportMaqueteClick;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(164, 4, 140, 30); B.Caption := 'Nova Tomada'; B.OnClick := @AddSocketClick;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(310, 4, 170, 30); B.Caption := 'Exportar SimuEletrica'; B.OnClick := @ExportSimModelClick;
  FViewport := TEAViewport3D.Create(Tab3D); FViewport.Parent := Tab3D; FViewport.Align := alClient;

  TabUni := TTabSheet.Create(Pages); TabUni.PageControl := Pages; TabUni.Caption := 'Diagrama Unifilar';
  FUnifilarBox := TPaintBox.Create(TabUni); FUnifilarBox.Parent := TabUni; FUnifilarBox.Align := alClient;
  FUnifilarBox.OnPaint := @PaintUnifilar;

  TabBOM := TTabSheet.Create(Pages); TabBOM.PageControl := Pages; TabBOM.Caption := 'Quantitativos';
  FQuantGrid := TStringGrid.Create(TabBOM); FQuantGrid.Parent := TabBOM; FQuantGrid.Align := alClient;
  FQuantGrid.ColCount := 5; FQuantGrid.FixedRows := 1;
  FQuantGrid.Cells[0, 0] := 'ID'; FQuantGrid.Cells[1, 0] := 'Circuito';
  FQuantGrid.Cells[2, 0] := 'Trecho'; FQuantGrid.Cells[3, 0] := 'Comprimento (m)';
  FQuantGrid.Cells[4, 0] := 'Condutores / Bitola';
end;

procedure TELEMainForm.RefreshUI;
var
  I: Integer;
begin
  FEle.RecalculateEngineering;
  FEle.BuildMesh(FViewport.Mesh, True);
  FViewport.Invalidate;
  FCircuitList.Items.Clear;
  for I := 0 to High(FEle.Circuits) do
    FCircuitList.Items.Add(Format('%s | %.0fW (%.1fA / Disj %.0fA)', [
      FEle.Circuits[I].Id, FEle.Circuits[I].TotalLoadW,
      FEle.Circuits[I].CurrentA, FEle.Circuits[I].BreakerA]));
  FPointList.Items.Clear;
  for I := 0 to High(FEle.Points) do
    FPointList.Items.Add(Format('%s [%s] %s', [
      FEle.Points[I].Id, ELEPointKindToStr(FEle.Points[I].Kind), FEle.Points[I].CircuitId]));

  FQuantGrid.RowCount := Max(2, Length(FEle.Conduits) + 1);
  for I := 0 to High(FEle.Conduits) do
  begin
    FQuantGrid.Cells[0, I + 1] := FEle.Conduits[I].Id;
    FQuantGrid.Cells[1, I + 1] := FEle.Conduits[I].CircuitId;
    FQuantGrid.Cells[2, I + 1] := FEle.Conduits[I].FromId + ' -> ' + FEle.Conduits[I].ToId;
    FQuantGrid.Cells[3, I + 1] := FormatFloat('0.00', FEle.Conduits[I].LengthMM / 1000.0);
    FQuantGrid.Cells[4, I + 1] := Format('%dx %.1f mm2', [FEle.Conduits[I].ConductorCount, FEle.Conduits[I].WireSectionMM2]);
  end;

  FAlertsMemo.Lines.Assign(FEle.Alerts);
  if FAlertsMemo.Lines.Count = 0 then
    FAlertsMemo.Lines.Add('Sem pendências técnicas detectadas. Verificações são assistivas; não substituem responsável técnico.');
  FUnifilarBox.Invalidate;
  FStatusLabel.Caption := Format('Circuitos: %d | Pontos: %d | Eletrodutos: %d | Avisos: %d',
    [Length(FEle.Circuits), Length(FEle.Points), Length(FEle.Conduits), FEle.Alerts.Count]);
end;

procedure TELEMainForm.PaintUnifilar(Sender: TObject);
var
  C: TCanvas;
  I, Y: Integer;
begin
  C := FUnifilarBox.Canvas;
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, FUnifilarBox.Width, FUnifilarBox.Height);
  C.Font.Color := RGBToColor(15, 23, 42);
  C.Font.Style := [fsBold];
  C.TextOut(24, 20, 'DIAGRAMA UNIFILAR ESQUEMÁTICO');
  C.Font.Style := [];
  C.Pen.Color := RGBToColor(30, 64, 145);
  C.Pen.Width := 2;
  C.Rectangle(40, 70, 180, 140);
  C.TextOut(62, 96, 'QDC-01');
  C.Line(180, 105, 240, 105);
  for I := 0 to High(FEle.Circuits) do
  begin
    Y := 80 + I * 90;
    C.Line(240, 105, 240, Y);
    C.Line(240, Y, 380, Y);
    C.TextOut(255, Y - 22, Format('%s (%s) — Disj %.0fA | %.1f mm2', [
      FEle.Circuits[I].Id, FEle.Circuits[I].Phase, FEle.Circuits[I].BreakerA, FEle.Circuits[I].WireSectionMM2]));
    C.Rectangle(380, Y - 18, 620, Y + 18);
    C.TextOut(392, Y - 8, Format('%s: %.0f W (%.1f A)', [
      FEle.Circuits[I].Name, FEle.Circuits[I].TotalLoadW, FEle.Circuits[I].CurrentA]));
  end;
end;

procedure TELEMainForm.ImportMaqueteClick(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Pacote Maquete (*.json)|*.json';
    if not D.Execute then Exit;
    FEle.ImportMaquetePackage(D.FileName, True);
    RefreshUI; FViewport.FitToMesh;
  except on E: Exception do MessageDlg('Elétrica 3D', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TELEMainForm.SaveEleClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Projeto Elétrico (*.ele.json)|*.ele.json'; D.DefaultExt := 'ele.json'; D.FileName := 'projeto.ele.json';
    if not D.Execute then Exit;
    FEle.SaveElectricalFile(D.FileName);
  finally D.Free; end;
end;

procedure TELEMainForm.OpenEleClick(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Projeto Elétrico (*.ele.json)|*.ele.json';
    if not D.Execute then Exit;
    FEle.LoadElectricalFile(D.FileName);
    RefreshUI; FViewport.FitToMesh;
  except on E: Exception do MessageDlg('Elétrica 3D', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TELEMainForm.ExportLayerClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Camada Elétrica (*.ele.layer.json)|*.ele.layer.json'; D.FileName := 'camada_eletrica.json';
    if D.Execute then FEle.ExportElectricalLayer(D.FileName);
  finally D.Free; end;
end;

procedure TELEMainForm.ExportSimModelClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Modelo SimuEletrica (*.simele.json)|*.simele.json'; D.FileName := 'modelo_eletrico.json';
    if D.Execute then FEle.ExportSimulationModel(D.FileName);
  finally D.Free; end;
end;

procedure TELEMainForm.ExportLightingClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Estado Iluminação (*.luz.json)|*.luz.json'; D.FileName := 'estado_iluminacao.json';
    if D.Execute then FEle.ExportLightingState(D.FileName);
  finally D.Free; end;
end;

procedure TELEMainForm.ExportBOMClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'CSV (*.csv)|*.csv'; D.FileName := 'quantitativos_eletrica.csv';
    if D.Execute then FEle.ExportQuantitiesCSV(D.FileName);
  finally D.Free; end;
end;

procedure TELEMainForm.AddSocketClick(Sender: TObject);
var
  NewId, LastId: string;
  WId, FlId: string;
begin
  if Length(FEle.ArchModel.Walls) > 0 then
  begin
    WId := FEle.ArchModel.Walls[0].Id;
    FlId := FEle.ArchModel.Walls[0].FloorId;
  end
  else
  begin
    WId := ''; FlId := 'terreo';
  end;
  NewId := Format('TOM-%d', [Length(FEle.Points) + 1]);
  if Length(FEle.Points) > 0 then LastId := FEle.Points[High(FEle.Points)].Id else LastId := '';
  FEle.AddPoint(NewId, 'Tomada ' + NewId, epkTomada, FlId, WId, ahkWall, EAV3(1500, 80, 300), 'C2', 600);
  if LastId <> '' then
    FEle.AddConduit(Format('ED-%d', [Length(FEle.Conduits) + 1]), 'C2', LastId, NewId, 25.0, 2.5, 3);
  RefreshUI;
end;

procedure TELEMainForm.ClashPlumbingClick(Sender: TObject);
var D: TOpenDialog; N: Integer;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Rede Tubulações (*.json)|*.json';
    if not D.Execute then Exit;
    N := FEle.CheckPlumbingClashes(D.FileName);
    RefreshUI;
    ShowMessage(Format('%d interferência(s) detectada(s) com a disciplina de tubulações.', [N]));
  except on E: Exception do MessageDlg('Coordenação', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TELEMainForm.SetupClick(Sender: TObject);
begin
  EAShowSetup(Self);
end;

end.
