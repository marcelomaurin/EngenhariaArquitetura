unit simutubulacoes_main;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  ComCtrls, Grids, Dialogs, Menus,
  ea_visual3d, ea_config_ui, ea_workflow, tub_projeto;

type
  TTubMainForm = class(TForm)
  private
    FTub: TTUBProject;
    FViewport: TEAViewport3D;
    FGrid, FNodeGrid: TStringGrid;
    FDomainList: TListBox;
    FAlertsMemo: TMemo;
    FStatusLabel: TLabel;
    procedure BuildMenus;
    procedure BuildUI;
    procedure RefreshUI;
    procedure DomainFilterClick(Sender: TObject);
    procedure ImportMaqueteClick(Sender: TObject);
    procedure OpenTubClick(Sender: TObject);
    procedure SaveTubClick(Sender: TObject);
    procedure RunSolversClick(Sender: TObject);
    procedure CheckClashesClick(Sender: TObject);
    procedure ExportNetworkClick(Sender: TObject);
    procedure ExportResultsClick(Sender: TObject);
    procedure ExportCSVClick(Sender: TObject);
    procedure ExportHTMLClick(Sender: TObject);
    procedure SetupClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  TubMainForm: TTubMainForm;

implementation

constructor TTubMainForm.Create(AOwner: TComponent);
var TaskPkg: string;
begin
  inherited CreateNew(AOwner, 1);
  FTub := TTUBProject.Create;
  Caption := 'SimuTubulações — EngenhariaArquitetura';
  Width := 1240; Height := 760; Position := poScreenCenter;
  Font.Name := {$IFDEF WINDOWS}'Segoe UI'{$ELSE}'Sans'{$ENDIF};
  Font.Size := 10; Color := RGBToColor(244, 246, 250);
  BuildMenus;
  BuildUI;
  FTub.LoadDemoNetworks;
  RefreshUI;
  FViewport.FitToMesh;

  TaskPkg := WFArg('--task-pkg');
  if (TaskPkg <> '') and FileExists(TaskPkg) then
    FStatusLabel.Caption := 'Tarefa recebida do Planejador: ' + ExtractFileName(TaskPkg);
end;

destructor TTubMainForm.Destroy;
begin
  FTub.Free;
  inherited Destroy;
end;

procedure TTubMainForm.BuildMenus;
var M: TMainMenu; TopMenu: TMenuItem;
  procedure Add(P: TMenuItem; const Cap: string; Ev: TNotifyEvent);
  var It: TMenuItem;
  begin It := TMenuItem.Create(M); It.Caption := Cap; It.OnClick := Ev; P.Add(It); end;
begin
  M := TMainMenu.Create(Self); Menu := M;
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Arquivo'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Importar Maquete 3D (somente leitura)...', @ImportMaqueteClick);
  Add(TopMenu, 'Abrir Projeto (.stubproj.json)...', @OpenTubClick);
  Add(TopMenu, 'Salvar Projeto...', @SaveTubClick);
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Simulação'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Executar Solvers (Água, Gás, Ar, Dutos, Esgoto)', @RunSolversClick);
  Add(TopMenu, 'Verificar Interferências (I-20)...', @CheckClashesClick);
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Exportar'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Publicar Rede de Tubulações (I-19)...', @ExportNetworkClick);
  Add(TopMenu, 'Exportar Resultados de Fluidos (I-22)...', @ExportResultsClick);
  Add(TopMenu, 'Exportar CSV...', @ExportCSVClick);
  Add(TopMenu, 'Exportar HTML...', @ExportHTMLClick);
  TopMenu := TMenuItem.Create(M); TopMenu.Caption := '&Setup'; M.Items.Add(TopMenu);
  Add(TopMenu, 'Configurações compartilhadas...', @SetupClick);
end;

procedure TTubMainForm.BuildUI;
var
  Header, Footer, LeftP, RightP, Bar: TPanel;
  L: TLabel;
  B: TButton;
  Pages: TPageControl;
  Tab3D, TabSegs, TabNodes: TTabSheet;
  D: TTUBFluidDomain;
begin
  Header := TPanel.Create(Self); Header.Parent := Self; Header.Align := alTop; Header.Height := 48;
  Header.BevelOuter := bvNone; Header.Color := RGBToColor(15, 23, 42);
  L := TLabel.Create(Self); L.Parent := Header; L.SetBounds(16, 12, 620, 26);
  L.Caption := 'SIMUTUBULAÇÕES 3D  |  Água Fria/Quente, Gás, Ar, Ventilação e Esgoto';
  L.Font.Color := clWhite; L.Font.Style := [fsBold];

  Footer := TPanel.Create(Self); Footer.Parent := Self; Footer.Align := alBottom; Footer.Height := 30;
  Footer.BevelOuter := bvNone; Footer.Color := RGBToColor(226, 232, 240);
  FStatusLabel := TLabel.Create(Self); FStatusLabel.Parent := Footer; FStatusLabel.Align := alClient;
  FStatusLabel.BorderSpacing.Left := 12; FStatusLabel.BorderSpacing.Top := 6;

  LeftP := TPanel.Create(Self); LeftP.Parent := Self; LeftP.Align := alLeft; LeftP.Width := 230;
  LeftP.BevelOuter := bvNone; LeftP.Color := clWhite;
  L := TLabel.Create(Self); L.Parent := LeftP; L.Align := alTop; L.Height := 26; L.Caption := ' Redes Independentes (ST-003)'; L.Font.Style := [fsBold];
  FDomainList := TListBox.Create(Self); FDomainList.Parent := LeftP; FDomainList.Align := alTop; FDomainList.Height := 220;
  FDomainList.Items.Add('Todas as redes (6 domínios)');
  for D := Low(D) to High(D) do FDomainList.Items.Add(TUBDomainName(D));
  FDomainList.ItemIndex := 0;
  FDomainList.OnClick := @DomainFilterClick;

  RightP := TPanel.Create(Self); RightP.Parent := Self; RightP.Align := alRight; RightP.Width := 260;
  RightP.BevelOuter := bvNone; RightP.Color := clWhite;
  L := TLabel.Create(Self); L.Parent := RightP; L.Align := alTop; L.Height := 26; L.Caption := ' Alertas & Interferências'; L.Font.Style := [fsBold];
  FAlertsMemo := TMemo.Create(Self); FAlertsMemo.Parent := RightP; FAlertsMemo.Align := alClient; FAlertsMemo.ReadOnly := True;

  Pages := TPageControl.Create(Self); Pages.Parent := Self; Pages.Align := alClient;
  Tab3D := TTabSheet.Create(Pages); Tab3D.PageControl := Pages; Tab3D.Caption := 'Redes 3D';
  Bar := TPanel.Create(Tab3D); Bar.Parent := Tab3D; Bar.Align := alTop; Bar.Height := 38; Bar.BevelOuter := bvNone;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(8, 4, 150, 30); B.Caption := 'Importar Maquete'; B.OnClick := @ImportMaqueteClick;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(164, 4, 150, 30); B.Caption := 'Executar Solvers'; B.OnClick := @RunSolversClick;
  B := TButton.Create(Bar); B.Parent := Bar; B.SetBounds(320, 4, 150, 30); B.Caption := 'Checar Colisões'; B.OnClick := @CheckClashesClick;
  FViewport := TEAViewport3D.Create(Tab3D); FViewport.Parent := Tab3D; FViewport.Align := alClient;

  TabSegs := TTabSheet.Create(Pages); TabSegs.PageControl := Pages; TabSegs.Caption := 'Trechos e Resultados';
  FGrid := TStringGrid.Create(TabSegs); FGrid.Parent := TabSegs; FGrid.Align := alClient;
  FGrid.ColCount := 8; FGrid.FixedRows := 1;
  FGrid.Cells[0, 0] := 'Trecho'; FGrid.Cells[1, 0] := 'Rede';
  FGrid.Cells[2, 0] := 'DN (mm)'; FGrid.Cells[3, 0] := 'Decliv (%)';
  FGrid.Cells[4, 0] := 'Vazão (L/s)'; FGrid.Cells[5, 0] := 'Vel (m/s)';
  FGrid.Cells[6, 0] := 'Perda (kPa)'; FGrid.Cells[7, 0] := 'Temp (°C)';

  TabNodes := TTabSheet.Create(Pages); TabNodes.PageControl := Pages; TabNodes.Caption := 'Nós (Pressão Absoluta / Manométrica)';
  FNodeGrid := TStringGrid.Create(TabNodes); FNodeGrid.Parent := TabNodes; FNodeGrid.Align := alClient;
  FNodeGrid.ColCount := 5; FNodeGrid.FixedRows := 1;
  FNodeGrid.Cells[0, 0] := 'Nó'; FNodeGrid.Cells[1, 0] := 'Rede';
  FNodeGrid.Cells[2, 0] := 'P Manométrica (kPa g)'; FNodeGrid.Cells[3, 0] := 'P Absoluta (kPa a)';
  FNodeGrid.Cells[4, 0] := 'Temp (°C)';
end;

procedure TTubMainForm.RefreshUI;
var I: Integer;
begin
  FTub.BuildNetworkMesh(FViewport.Mesh, True);
  FViewport.Invalidate;
  FGrid.RowCount := Max(2, Length(FTub.Segments) + 1);
  for I := 0 to High(FTub.Segments) do
  begin
    FGrid.Cells[0, I + 1] := FTub.Segments[I].Id;
    FGrid.Cells[1, I + 1] := TUBDomainName(FTub.Segments[I].Domain);
    FGrid.Cells[2, I + 1] := FormatFloat('0', FTub.Segments[I].InnerDiamMM);
    FGrid.Cells[3, I + 1] := FormatFloat('0.00', FTub.Segments[I].SlopePct);
    FGrid.Cells[4, I + 1] := FormatFloat('0.00', FTub.Segments[I].CalcFlowLPS);
    FGrid.Cells[5, I + 1] := FormatFloat('0.00', FTub.Segments[I].CalcVelocityMS);
    FGrid.Cells[6, I + 1] := FormatFloat('0.000', FTub.Segments[I].CalcHeadLossKPa);
    FGrid.Cells[7, I + 1] := FormatFloat('0.1', FTub.Segments[I].CalcTempOutC);
  end;
  FNodeGrid.RowCount := Max(2, Length(FTub.Nodes) + 1);
  for I := 0 to High(FTub.Nodes) do
  begin
    FNodeGrid.Cells[0, I + 1] := FTub.Nodes[I].Id;
    FNodeGrid.Cells[1, I + 1] := TUBDomainName(FTub.Nodes[I].Domain);
    FNodeGrid.Cells[2, I + 1] := FormatFloat('0.00', FTub.Nodes[I].CalcPressureKPaG);
    FNodeGrid.Cells[3, I + 1] := FormatFloat('0.00', FTub.Nodes[I].CalcPressureKPaAbs);
    FNodeGrid.Cells[4, I + 1] := FormatFloat('0.1', FTub.Nodes[I].CalcTempC);
  end;
  FAlertsMemo.Lines.Assign(FTub.Alerts);
  if FAlertsMemo.Lines.Count = 0 then
    FAlertsMemo.Lines.Add('Redes consistentes nos 6 domínios. Estudos condicionados às hipóteses do solver.');
  FStatusLabel.Caption := FTub.SolverVersion + Format(' | Nós: %d | Trechos: %d', [Length(FTub.Nodes), Length(FTub.Segments)]);
end;

procedure TTubMainForm.DomainFilterClick(Sender: TObject);
begin
  FTub.ActiveFilter := FDomainList.ItemIndex - 1;
  RefreshUI;
end;

procedure TTubMainForm.RunSolversClick(Sender: TObject);
begin
  FTub.RunAllDomainSolvers;
  RefreshUI;
end;

procedure TTubMainForm.CheckClashesClick(Sender: TObject);
var D: TOpenDialog; N: Integer; EleFile: string;
begin
  EleFile := '';
  D := TOpenDialog.Create(Self);
  try
    D.Title := 'Opcional: selecione camada elétrica (I-20) ou cancele para checar apenas redes de fluidos';
    D.Filter := 'Camada Elétrica (*.json)|*.json';
    if D.Execute then EleFile := D.FileName;
  finally D.Free; end;
  N := FTub.CheckClashes(EleFile);
  RefreshUI;
  ShowMessage(Format('%d interferência(s) detectada(s).', [N]));
end;

procedure TTubMainForm.ImportMaqueteClick(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Pacote Maquete (*.json)|*.json';
    if not D.Execute then Exit;
    FTub.ImportMaquetePackage(D.FileName);
    RefreshUI; FViewport.FitToMesh;
  except on E: Exception do MessageDlg('SimuTubulações', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TTubMainForm.OpenTubClick(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'SimuTubulações (*.stubproj.json)|*.stubproj.json';
    if not D.Execute then Exit;
    FTub.LoadTubProject(D.FileName);
    RefreshUI; FViewport.FitToMesh;
  except on E: Exception do MessageDlg('SimuTubulações', E.Message, mtError, [mbOK], 0);
  end;
  D.Free;
end;

procedure TTubMainForm.SaveTubClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'SimuTubulações (*.stubproj.json)|*.stubproj.json'; D.FileName := 'redes.stubproj.json';
    if D.Execute then FTub.SaveTubProject(D.FileName);
  finally D.Free; end;
end;

procedure TTubMainForm.ExportNetworkClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Pacote Rede (*.stubpkg.json)|*.stubpkg.json'; D.FileName := 'rede_tubulacoes.json';
    if D.Execute then FTub.ExportPipeNetworkPackage(D.FileName);
  finally D.Free; end;
end;

procedure TTubMainForm.ExportResultsClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Resultados Fluidos (*.json)|*.json'; D.FileName := 'resultado_fluidos.json';
    if D.Execute then FTub.ExportFluidResultsPackage(D.FileName);
  finally D.Free; end;
end;

procedure TTubMainForm.ExportCSVClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'CSV (*.csv)|*.csv'; D.FileName := 'relatorio_tubulacoes.csv';
    if D.Execute then FTub.ExportReportCSV(D.FileName);
  finally D.Free; end;
end;

procedure TTubMainForm.ExportHTMLClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'HTML (*.html)|*.html'; D.FileName := 'relatorio_tubulacoes.html';
    if D.Execute then FTub.ExportReportHTML(D.FileName);
  finally D.Free; end;
end;

procedure TTubMainForm.SetupClick(Sender: TObject);
begin
  EAShowSetup(Self);
end;

end.
