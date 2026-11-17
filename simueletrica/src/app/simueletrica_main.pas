unit simueletrica_main;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  ComCtrls, Grids, Dialogs, Menus,
  ea_visual3d, ea_config_ui, ea_workflow, sim_eletrica;

type
  TSimEleMainForm = class(TForm)
  private
    FSim: TSIMProject;
    FViewport: TEAViewport3D;
    FLegendBox: TPaintBox;
    FGrid: TStringGrid;
    FEventsList: TListBox;
    FAlertsMemo: TMemo;
    FScenarioCombo: TComboBox;
    FAmbientEdit, FLoadEdit, FTimeEdit: TEdit;
    FStatusLabel: TLabel;
    procedure BuildMenus;
    procedure BuildUI;
    procedure RefreshUI;
    procedure PaintLegend(Sender: TObject);
    procedure ImportModelClick(Sender: TObject);
    procedure RunSimClick(Sender: TObject);
    procedure ExportResClick(Sender: TObject);
    procedure ExportCSVClick(Sender: TObject);
    procedure ExportHTMLClick(Sender: TObject);
    procedure SetupClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  SimEleMainForm: TSimEleMainForm;

implementation

constructor TSimEleMainForm.Create(AOwner: TComponent);
var TaskPkg: string;
begin
  inherited CreateNew(AOwner, 1);
  FSim := TSIMProject.Create;
  Caption := 'SimuEletrica — Simulador Elétrico e Mapa Térmico 3D';
  Width := 1220; Height := 760; Position := poScreenCenter;
  Font.Name := {$IFDEF WINDOWS}'Segoe UI'{$ELSE}'Sans'{$ENDIF};
  Font.Size := 10; Color := RGBToColor(244, 246, 250);
  BuildMenus;
  BuildUI;
  FSim.LoadDemoModel;
  RefreshUI;
  FViewport.FitToMesh;

  TaskPkg := WFArg('--task-pkg');
  if (TaskPkg <> '') and FileExists(TaskPkg) then
    FStatusLabel.Caption := 'Tarefa recebida do Planejador: ' + ExtractFileName(TaskPkg);
end;

destructor TSimEleMainForm.Destroy;
begin
  FSim.Free;
  inherited Destroy;
end;

procedure TSimEleMainForm.BuildMenus;
var M: TMainMenu; TopMenu: TMenuItem;
  procedure Add(P: TMenuItem; const Cap: string; Ev: TNotifyEvent);
  var It: TMenuItem;
  begin It := TMenuItem.Create(M); It.Caption := Cap; It.OnClick := Ev; P.Add(It); end;
begin
  M := TMainMenu.Create(Self); Menu := M;
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Arquivo'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Importar Modelo do Elétrica 3D (I-16)...', @ImportModelClick);
  Add(TopMenu, 'Exportar Resultados para Elétrica 3D / Maquete (I-17)...', @ExportResClick);
  Add(TopMenu, 'Exportar Relatório CSV...', @ExportCSVClick);
  Add(TopMenu, 'Exportar Relatório HTML...', @ExportHTMLClick);
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Simulação'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Executar Solver Elétrico e Térmico', @RunSimClick);
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Setup'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Configurações compartilhadas...', @SetupClick);
end;

procedure TSimEleMainForm.BuildUI;
var
  Header, Footer, LeftP, RightP, Bar: TPanel;
  L: TLabel;
  B: TButton;
  Pages: TPageControl;
  Tab3D, TabTable: TTabSheet;
begin
  Header := TPanel.Create(Self); Header.Parent := Self; Header.Align := alTop; Header.Height := 48;
  Header.BevelOuter := bvNone; Header.Color := RGBToColor(15, 23, 42);
  L := TLabel.Create(Self); L.Parent := Header; L.SetBounds(16, 12, 560, 26);
  L.Caption := 'SIMUELETRICA  |  Regime Permanente, Faltas e Mapa Térmico 3D';
  L.Font.Color := clWhite; L.Font.Style := [fsBold];

  Footer := TPanel.Create(Self); Footer.Parent := Self; Footer.Align := alBottom; Footer.Height := 30;
  Footer.BevelOuter := bvNone; Footer.Color := RGBToColor(226, 232, 240);
  FStatusLabel := TLabel.Create(Self); FStatusLabel.Parent := Footer; FStatusLabel.Align := alClient;
  FStatusLabel.BorderSpacing.Left := 12; FStatusLabel.BorderSpacing.Top := 6;

  LeftP := TPanel.Create(Self); LeftP.Parent := Self; LeftP.Align := alLeft; LeftP.Width := 250;
  LeftP.BevelOuter := bvNone; LeftP.Color := clWhite;
  L := TLabel.Create(Self); L.Parent := LeftP; L.SetBounds(12, 10, 220, 22); L.Caption := 'Cenário de Análise:';
  FScenarioCombo := TComboBox.Create(Self); FScenarioCombo.Parent := LeftP; FScenarioCombo.SetBounds(12, 34, 226, 28);
  FScenarioCombo.Style := csDropDownList;
  FScenarioCombo.Items.Add('Operação Normal');
  FScenarioCombo.Items.Add('Carga Máxima (1,35x)');
  FScenarioCombo.Items.Add('Curto-Circuito (Falta)');
  FScenarioCombo.Items.Add('Ambiente Quente (40 °C)');
  FScenarioCombo.ItemIndex := 0;

  L := TLabel.Create(Self); L.Parent := LeftP; L.SetBounds(12, 72, 220, 22); L.Caption := 'Temp. Ambiente (°C):';
  FAmbientEdit := TEdit.Create(Self); FAmbientEdit.Parent := LeftP; FAmbientEdit.SetBounds(12, 96, 100, 28); FAmbientEdit.Text := '30';
  L := TLabel.Create(Self); L.Parent := LeftP; L.SetBounds(12, 134, 220, 22); L.Caption := 'Fator de Carga:';
  FLoadEdit := TEdit.Create(Self); FLoadEdit.Parent := LeftP; FLoadEdit.SetBounds(12, 158, 100, 28); FLoadEdit.Text := '1.0';
  L := TLabel.Create(Self); L.Parent := LeftP; L.SetBounds(12, 196, 220, 22); L.Caption := 'Instante Térmico (s):';
  FTimeEdit := TEdit.Create(Self); FTimeEdit.Parent := LeftP; FTimeEdit.SetBounds(12, 220, 100, 28); FTimeEdit.Text := '1800';
  B := TButton.Create(Self); B.Parent := LeftP; B.SetBounds(12, 262, 226, 34); B.Caption := 'Executar Simulação'; B.OnClick := @RunSimClick;

  L := TLabel.Create(Self); L.Parent := LeftP; L.SetBounds(12, 310, 220, 22); L.Caption := 'Eventos Temporais / Proteção:';
  FEventsList := TListBox.Create(Self); FEventsList.Parent := LeftP; FEventsList.SetBounds(12, 336, 226, 280);

  RightP := TPanel.Create(Self); RightP.Parent := Self; RightP.Align := alRight; RightP.Width := 250;
  RightP.BevelOuter := bvNone; RightP.Color := clWhite;
  L := TLabel.Create(Self); L.Parent := RightP; L.Align := alTop; L.Height := 24; L.Caption := ' Escala Térmica (°C — Condutor)'; L.Font.Style := [fsBold];
  FLegendBox := TPaintBox.Create(Self); FLegendBox.Parent := RightP; FLegendBox.Align := alTop; FLegendBox.Height := 90;
  FLegendBox.OnPaint := @PaintLegend;
  L := TLabel.Create(Self); L.Parent := RightP; L.Align := alTop; L.Height := 24; L.Caption := ' Alertas & Limites'; L.Font.Style := [fsBold];
  FAlertsMemo := TMemo.Create(Self); FAlertsMemo.Parent := RightP; FAlertsMemo.Align := alClient; FAlertsMemo.ReadOnly := True;

  Pages := TPageControl.Create(Self); Pages.Parent := Self; Pages.Align := alClient;
  Tab3D := TTabSheet.Create(Pages); Tab3D.PageControl := Pages; Tab3D.Caption := 'Mapa Térmico 3D';
  Bar := TPanel.Create(Tab3D); Bar.Parent := Tab3D; Bar.Align := alTop; Bar.Height := 38; Bar.BevelOuter := bvNone;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(8, 4, 150, 30); B.Caption := 'Importar Elétrica (I-16)'; B.OnClick := @ImportModelClick;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(164, 4, 150, 30); B.Caption := 'Exportar Resultados'; B.OnClick := @ExportResClick;
  FViewport := TEAViewport3D.Create(Tab3D); FViewport.Parent := Tab3D; FViewport.Align := alClient;

  TabTable := TTabSheet.Create(Pages); TabTable.PageControl := Pages; TabTable.Caption := 'Resultados por Trecho';
  FGrid := TStringGrid.Create(TabTable); FGrid.Parent := TabTable; FGrid.Align := alClient;
  FGrid.ColCount := 8; FGrid.FixedRows := 1;
  FGrid.Cells[0, 0] := 'Trecho'; FGrid.Cells[1, 0] := 'Circuito';
  FGrid.Cells[2, 0] := 'I (A)'; FGrid.Cells[3, 0] := 'ΔV (%)';
  FGrid.Cells[4, 0] := 'Perdas (W)'; FGrid.Cells[5, 0] := 'Icc (A)';
  FGrid.Cells[6, 0] := 'Temp (°C)'; FGrid.Cells[7, 0] := 'Limite (70°C)';
end;

procedure TSimEleMainForm.PaintLegend(Sender: TObject);
var I: Integer; C: LongWord; T: Double;
begin
  FLegendBox.Canvas.Brush.Color := clWhite;
  FLegendBox.Canvas.FillRect(0, 0, FLegendBox.Width, FLegendBox.Height);
  for I := 0 to 199 do
  begin
    T := FSim.AmbientTempC + (75.0 - FSim.AmbientTempC) * (I / 199.0);
    C := SIMTempToRGB(T, FSim.AmbientTempC, 75.0);
    FLegendBox.Canvas.Pen.Color := RGBToColor((C shr 16) and $FF, (C shr 8) and $FF, C and $FF);
    FLegendBox.Canvas.Line(16 + I, 16, 16 + I, 40);
  end;
  FLegendBox.Canvas.Font.Color := clBlack;
  FLegendBox.Canvas.TextOut(16, 46, Format('%.0f °C (Frio)', [FSim.AmbientTempC]));
  FLegendBox.Canvas.TextOut(145, 46, '75 °C (Crítico)');
end;

procedure TSimEleMainForm.RefreshUI;
var I: Integer;
begin
  FSim.BuildThermalMesh(FViewport.Mesh);
  FViewport.Invalidate;
  FLegendBox.Invalidate;
  FGrid.RowCount := Max(2, Length(FSim.Branches) + 1);
  for I := 0 to High(FSim.Branches) do
  begin
    FGrid.Cells[0, I + 1] := FSim.Branches[I].Id;
    FGrid.Cells[1, I + 1] := FSim.Branches[I].CircuitId;
    FGrid.Cells[2, I + 1] := FormatFloat('0.00', FSim.Branches[I].CurrentA);
    FGrid.Cells[3, I + 1] := FormatFloat('0.00', FSim.Branches[I].DropPct) + '%';
    FGrid.Cells[4, I + 1] := FormatFloat('0.00', FSim.Branches[I].LossesW);
    FGrid.Cells[5, I + 1] := FormatFloat('0.0', FSim.Branches[I].FaultCurrentA);
    FGrid.Cells[6, I + 1] := FormatFloat('0.1', FSim.Branches[I].ConductorTempC) + ' °C';
    FGrid.Cells[7, I + 1] := BoolToStr(FSim.Branches[I].Overlimit, 'EXCEDIDO', 'OK');
  end;
  FEventsList.Items.Clear;
  for I := 0 to High(FSim.Events) do
    FEventsList.Items.Add(Format('t=%.3fs | %s | %s', [FSim.Events[I].TimeSec, FSim.Events[I].Kind, FSim.Events[I].Detail]));
  FAlertsMemo.Lines.Assign(FSim.Warnings);
  if FAlertsMemo.Lines.Count = 0 then
    FAlertsMemo.Lines.Add('Todos os trechos dentro dos limites térmicos e de queda de tensão.');
  FStatusLabel.Caption := FSim.SolverVersion + ' | Cenário: ' + FSim.ScenarioName;
end;

procedure TSimEleMainForm.RunSimClick(Sender: TObject);
begin
  FSim.ScenarioKind := TSIMScenarioKind(Max(0, FScenarioCombo.ItemIndex));
  FSim.ScenarioName := FScenarioCombo.Text;
  FSim.AmbientTempC := StrToFloatDef(FAmbientEdit.Text, 30.0);
  FSim.LoadFactor := StrToFloatDef(FLoadEdit.Text, 1.0);
  if FSim.ScenarioKind = sskMaxLoad then FSim.LoadFactor := 1.35;
  if FSim.ScenarioKind = sskHotAmbient then FSim.AmbientTempC := 40.0;
  FSim.TimeInstSec := StrToFloatDef(FTimeEdit.Text, 1800.0);
  FSim.RunSimulation;
  RefreshUI;
end;

procedure TSimEleMainForm.ImportModelClick(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Modelo Elétrico (*.json)|*.json';
    if not D.Execute then Exit;
    FSim.ImportElectricalModel(D.FileName);
    RefreshUI; FViewport.FitToMesh;
  except on E: Exception do MessageDlg('SimuEletrica', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TSimEleMainForm.ExportResClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Resultados SimuEletrica (*.json)|*.json'; D.FileName := 'resultado_simulacao.json';
    if D.Execute then FSim.ExportResultsPackage(D.FileName);
  finally D.Free; end;
end;

procedure TSimEleMainForm.ExportCSVClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'CSV (*.csv)|*.csv'; D.FileName := 'relatorio_simueletrica.csv';
    if D.Execute then FSim.ExportReportCSV(D.FileName);
  finally D.Free; end;
end;

procedure TSimEleMainForm.ExportHTMLClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'HTML (*.html)|*.html'; D.FileName := 'relatorio_simueletrica.html';
    if D.Execute then FSim.ExportReportHTML(D.FileName);
  finally D.Free; end;
end;

procedure TSimEleMainForm.SetupClick(Sender: TObject);
begin
  EAShowSetup(Self);
end;

end.
