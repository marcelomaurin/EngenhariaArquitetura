unit tub_projeto;

{ SimuTubulações - Núcleo de modelagem 3D e solvers por domínio de fluido (etapas TB1..TB5).
  Implementa docs/SimuTubulacoes.md e integrações I-18..I-23 de docs/Integracoes.md.
  Redes distintas: água fria, água quente, gás (GN/GLP), ar comprimido, ventilação e esgoto.
  Nota técnica: estudos numéricos condicionados às hipóteses do modelo; não substituem
  projeto ou comissionamento por profissional habilitado. }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, fpjson, jsonparser,
  ea_geometria, ea_pacote, ea_modelo, ea_malha3d, ea_fileio;

type
  TTUBFluidDomain = (
    tfdAguaFria,
    tfdAguaQuente,
    tfdGas,
    tfdArComprimido,
    tfdVentilacao,
    tfdEsgoto
  );

  TTUBNodeKind = (tnkFonte, tnkBomba, tnkRegulador, tnkValvula, tnkConexao, tnkConsumo, tnkDescarga);

  TTUBNode = record
    Id: string;
    Name: string;
    Domain: TTUBFluidDomain;
    Kind: TTUBNodeKind;
    PosMM: TEAVec3;
    DemandFlowLPS: Double;     // L/s (ou Nm3/h para gas/ar, m3/s para ventilacao)
    SupplyPressureKPaG: Double; // pressao manometrica na fonte/regulador
    SupplyTempC: Double;
    ValveOpen: Boolean;
    CalcPressureKPaAbs: Double;
    CalcPressureKPaG: Double;
    CalcTempC: Double;
  end;

  TTUBSegment = record
    Id: string;
    Domain: TTUBFluidDomain;
    FromId: string;
    ToId: string;
    P0, P1: TEAVec3;
    InnerDiamMM: Double;
    Material: string;
    RoughnessMM: Double;
    LengthM: Double;
    SlopePct: Double;
    CalcFlowLPS: Double;
    CalcVelocityMS: Double;
    CalcHeadLossKPa: Double;
    CalcFillRatio: Double; // esgoto y/D
    CalcTempOutC: Double;
    HasAlert: Boolean;
  end;

  TTUBProject = class
  public
    ProjectId: string;
    ArchModel: TEAModel;
    ArchRefRevision: string;
    ArchRefHash: string;
    ActiveFilter: Integer; // -1 = todas as redes, 0..5 = dominio especifico
    AtmPressureKPa: Double;
    SolverVersion: string;
    Nodes: array of TTUBNode;
    Segments: array of TTUBSegment;
    Alerts: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure LoadDemoNetworks;
    procedure ImportMaquetePackage(const FileName: string);
    function AddNode(const AId, AName: string; ADomain: TTUBFluidDomain; AKind: TTUBNodeKind;
      const APos: TEAVec3; ADemandLPS, ASupplyKPaG, ATempC: Double): Integer;
    function AddSegment(const AId: string; ADomain: TTUBFluidDomain;
      const AFromId, AToId: string; ADiamMM: Double; const AMaterial: string;
      ARoughMM: Double = 0.015): Integer;
    function FindNode(const AId: string): Integer;
    procedure RunAllDomainSolvers;
    function CheckClashes(const ElectricalPkgFile: string = ''): Integer;
    procedure BuildNetworkMesh(Target: TEAMesh3D; IncludeArch: Boolean = True);
    procedure ExportPipeNetworkPackage(const FileName: string);   // I-19
    procedure ExportFluidResultsPackage(const FileName: string);  // I-22
    procedure ExportCoordinationRequests(const FileName: string); // I-23
    procedure ExportReportCSV(const FileName: string);
    procedure ExportReportHTML(const FileName: string);
    procedure SaveTubProject(const FileName: string);
    procedure LoadTubProject(const FileName: string);
  end;

function TUBDomainCode(D: TTUBFluidDomain): string;
function TUBDomainName(D: TTUBFluidDomain): string;
function TUBDomainColor(D: TTUBFluidDomain): LongWord;
function TUBStrToDomain(const S: string): TTUBFluidDomain;

implementation

function TUBDomainCode(D: TTUBFluidDomain): string;
const
  Codes: array[TTUBFluidDomain] of string = (
    'agua_fria', 'agua_quente', 'gas', 'ar_comprimido', 'ventilacao', 'esgoto'
  );
begin
  Result := Codes[D];
end;

function TUBDomainName(D: TTUBFluidDomain): string;
const
  Names: array[TTUBFluidDomain] of string = (
    'Água Fria', 'Água Quente', 'Gás (GN/GLP)', 'Ar Comprimido', 'Ventilação / Dutos', 'Esgoto Sanitário'
  );
begin
  Result := Names[D];
end;

function TUBDomainColor(D: TTUBFluidDomain): LongWord;
const
  Cols: array[TTUBFluidDomain] of LongWord = (
    $0284C7, // Azul Agua Fria
    $DC2626, // Vermelho Agua Quente
    $EAB308, // Amarelo Gas
    $06B6D4, // Ciano Ar Comprimido
    $10B981, // Verde Ventilacao
    $78350F  // Marrom Esgoto
  );
begin
  Result := Cols[D];
end;

function TUBStrToDomain(const S: string): TTUBFluidDomain;
var
  D: TTUBFluidDomain;
  L: string;
begin
  L := LowerCase(Trim(S));
  for D := Low(D) to High(D) do
    if TUBDomainCode(D) = L then Exit(D);
  Result := tfdAguaFria;
end;

constructor TTUBProject.Create;
begin
  inherited Create;
  ArchModel := TEAModel.Create;
  Alerts := TStringList.Create;
  Clear;
end;

destructor TTUBProject.Destroy;
begin
  Alerts.Free;
  ArchModel.Free;
  inherited Destroy;
end;

procedure TTUBProject.Clear;
begin
  ProjectId := 'tub-001';
  ArchModel.Clear;
  ArchRefRevision := 'rev-001';
  ArchRefHash := '';
  ActiveFilter := -1;
  AtmPressureKPa := 101.325;
  SolverVersion := 'SimuTubulacoes-Solver-1.0 (HazenWilliams/Compressivel/Manning)';
  SetLength(Nodes, 0);
  SetLength(Segments, 0);
  Alerts.Clear;
end;

procedure TTUBProject.LoadDemoNetworks;
var
  Poly: TEAVec2Array;
begin
  Clear;
  ArchModel.ProjectId := 'hosp-tub-demo';
  ArchModel.AddFloor('terreo', 'Térreo', 0, 2800, 150);
  ArchModel.AddWall('w1', 'terreo', EAV2(0, 0), EAV2(5000, 0), 150, 2800);
  ArchModel.AddWall('w2', 'terreo', EAV2(5000, 0), EAV2(5000, 4000), 150, 2800);
  ArchModel.AddWall('w3', 'terreo', EAV2(5000, 4000), EAV2(0, 4000), 150, 2800);
  ArchModel.AddWall('w4', 'terreo', EAV2(0, 4000), EAV2(0, 0), 150, 2800);
  SetLength(Poly, 4);
  Poly[0] := EAV2(0, 0); Poly[1] := EAV2(5000, 0); Poly[2] := EAV2(5000, 4000); Poly[3] := EAV2(0, 4000);
  ArchModel.AddSlab('laje-terreo', 'terreo', Poly, 150);

  { 1. Rede de Agua Fria }
  AddNode('AF-SUP', 'Caixa d''água', tfdAguaFria, tnkFonte, EAV3(400, 400, 3200), 0, 20.0, 22.0);
  AddNode('AF-JOE', 'Prumada AF', tfdAguaFria, tnkConexao, EAV3(400, 400, 1100), 0, 0, 22.0);
  AddNode('AF-TOR', 'Torneira Pia', tfdAguaFria, tnkConsumo, EAV3(2400, 120, 1100), 0.25, 0, 22.0);
  AddSegment('AF-T1', tfdAguaFria, 'AF-SUP', 'AF-JOE', 25.0, 'PVC');
  AddSegment('AF-T2', tfdAguaFria, 'AF-JOE', 'AF-TOR', 20.0, 'PVC');

  { 2. Rede de Agua Quente }
  AddNode('AQ-AQC', 'Aquecedor', tfdAguaQuente, tnkFonte, EAV3(600, 400, 1500), 0, 150.0, 60.0);
  AddNode('AQ-CHU', 'Chuveiro / Misturador', tfdAguaQuente, tnkConsumo, EAV3(4200, 120, 2100), 0.20, 0, 60.0);
  AddSegment('AQ-T1', tfdAguaQuente, 'AQ-AQC', 'AQ-CHU', 22.0, 'CPVC/PPR');

  { 3. Rede de Gas GN }
  AddNode('GAS-REG', 'Regulador GN', tfdGas, tnkRegulador, EAV3(200, 3600, 1400), 0, 2.8, 25.0);
  AddNode('GAS-FOG', 'Ponto Fogão/Caldeira', tfdGas, tnkConsumo, EAV3(3200, 3600, 800), 0.45, 0, 25.0);
  AddSegment('GAS-T1', tfdGas, 'GAS-REG', 'GAS-FOG', 20.0, 'Cobre');

  { 4. Rede de Ar Comprimido }
  AddNode('AR-CMP', 'Compressor', tfdArComprimido, tnkBomba, EAV3(4600, 3600, 500), 0, 700.0, 28.0);
  AddNode('AR-USO', 'Ponto Uso Pneumático', tfdArComprimido, tnkConsumo, EAV3(4600, 1200, 1200), 2.5, 0, 28.0);
  AddSegment('AR-T1', tfdArComprimido, 'AR-CMP', 'AR-USO', 20.0, 'Alumínio');

  { 5. Rede de Ventilacao }
  AddNode('VEN-EX', 'Ventilador Exaustor', tfdVentilacao, tnkBomba, EAV3(2500, 2000, 2700), 0, 0.25, 24.0);
  AddNode('VEN-GR', 'Grelha Sala', tfdVentilacao, tnkDescarga, EAV3(4800, 2000, 2700), 180.0, 0, 24.0);
  AddSegment('VEN-D1', tfdVentilacao, 'VEN-EX', 'VEN-GR', 200.0, 'Chapa Galvanizada');

  { 6. Rede de Esgoto Sanitario (gravidade, caimento 2%) }
  AddNode('ESG-PIA', 'Sifão Pia', tfdEsgoto, tnkConsumo, EAV3(2400, 150, 600), 0.35, 0, 25.0);
  AddNode('ESG-CI', 'Caixa Inspeção', tfdEsgoto, tnkDescarga, EAV3(4800, 150, 500), 0, 0, 25.0);
  AddSegment('ESG-T1', tfdEsgoto, 'ESG-PIA', 'ESG-CI', 50.0, 'PVC Esgoto');

  RunAllDomainSolvers;
end;

procedure TTUBProject.ImportMaquetePackage(const FileName: string);
var
  Pkg: TEAPackageManifest;
  NewM: TEAModel;
begin
  EACheckSupportedExternalFile(FileName);
  Pkg := TEAPackageManifest.Create;
  NewM := TEAModel.Create;
  try
    Pkg.LoadFromFile(FileName);
    if (Pkg.PackageType <> EA_PKG_MAQUETE) and (Pkg.PackageType <> EA_PKG_ARQUITETURA_2D) then
      raise EEAPackageError.Create('Pacote arquitetônico inválido');
    if (Pkg.Payload <> nil) and (Pkg.Payload.Find('model') <> nil) then
      NewM.FromJSON(Pkg.Payload.Objects['model'])
    else if Pkg.Payload <> nil then
      NewM.FromJSON(Pkg.Payload);
    ArchModel.Assign(NewM);
    ArchRefRevision := Pkg.Revision;
    ArchRefHash := EASHA256File(FileName);
  finally
    NewM.Free;
    Pkg.Free;
  end;
end;

function TTUBProject.AddNode(const AId, AName: string; ADomain: TTUBFluidDomain; AKind: TTUBNodeKind;
  const APos: TEAVec3; ADemandLPS, ASupplyKPaG, ATempC: Double): Integer;
begin
  Result := Length(Nodes);
  SetLength(Nodes, Result + 1);
  Nodes[Result].Id := AId;
  Nodes[Result].Name := AName;
  Nodes[Result].Domain := ADomain;
  Nodes[Result].Kind := AKind;
  Nodes[Result].PosMM := APos;
  Nodes[Result].DemandFlowLPS := ADemandLPS;
  Nodes[Result].SupplyPressureKPaG := ASupplyKPaG;
  Nodes[Result].SupplyTempC := ATempC;
  Nodes[Result].ValveOpen := True;
end;

function TTUBProject.AddSegment(const AId: string; ADomain: TTUBFluidDomain;
  const AFromId, AToId: string; ADiamMM: Double; const AMaterial: string; ARoughMM: Double): Integer;
var
  I0, I1: Integer;
  DX, DY, DZ, HorizM: Double;
begin
  I0 := FindNode(AFromId);
  I1 := FindNode(AToId);
  if (I0 >= 0) and (I1 >= 0) and (Nodes[I0].Domain <> Nodes[I1].Domain) then
    raise EEAPackageError.Create('Proibido interligar nós de fluidos diferentes (' +
      TUBDomainName(Nodes[I0].Domain) + ' e ' + TUBDomainName(Nodes[I1].Domain) + ')');
  if (I0 >= 0) and (Nodes[I0].Domain <> ADomain) then
    raise EEAPackageError.Create('Domínio do trecho incompatível com o nó de origem');

  Result := Length(Segments);
  SetLength(Segments, Result + 1);
  Segments[Result] := Default(TTUBSegment);
  Segments[Result].Id := AId;
  Segments[Result].Domain := ADomain;
  Segments[Result].FromId := AFromId;
  Segments[Result].ToId := AToId;
  if I0 >= 0 then Segments[Result].P0 := Nodes[I0].PosMM;
  if I1 >= 0 then Segments[Result].P1 := Nodes[I1].PosMM;
  Segments[Result].InnerDiamMM := Max(5.0, ADiamMM);
  Segments[Result].Material := AMaterial;
  Segments[Result].RoughnessMM := ARoughMM;
  Segments[Result].LengthM := Max(0.05, EAV3Dist(Segments[Result].P0, Segments[Result].P1) / 1000.0);
  DX := Segments[Result].P1.X - Segments[Result].P0.X;
  DY := Segments[Result].P1.Y - Segments[Result].P0.Y;
  DZ := (Segments[Result].P0.Z - Segments[Result].P1.Z) / 1000.0; // queda positiva em m
  HorizM := Max(0.01, Hypot(DX, DY) / 1000.0);
  Segments[Result].SlopePct := 100.0 * DZ / HorizM;
end;

function TTUBProject.FindNode(const AId: string): Integer;
var I: Integer;
begin
  for I := 0 to High(Nodes) do if Nodes[I].Id = AId then Exit(I);
  Result := -1;
end;

procedure TTUBProject.RunAllDomainSolvers;
var
  I, J, I0, I1: Integer;
  Q_m3s, D_m, Area, Vel, DZ_m, LossKPa, P1Abs, P2Abs, P1Sq, P2Sq, C_hw, S_man, N_man: Double;
begin
  Alerts.Clear;
  { Inicializar pressoes e temperaturas nas fontes }
  for I := 0 to High(Nodes) do
  begin
    Nodes[I].CalcPressureKPaG := Nodes[I].SupplyPressureKPaG;
    Nodes[I].CalcPressureKPaAbs := AtmPressureKPa + Nodes[I].SupplyPressureKPaG;
    Nodes[I].CalcTempC := Nodes[I].SupplyTempC;
  end;

  { Resolver cada dominio separadamente (ST-003) }
  for I := 0 to High(Segments) do
  begin
    I0 := FindNode(Segments[I].FromId);
    I1 := FindNode(Segments[I].ToId);
    if (I0 < 0) or (I1 < 0) then
    begin
      Alerts.Add('Ponta desconectada no trecho ' + Segments[I].Id);
      Segments[I].HasAlert := True;
      Continue;
    end;
    if (Nodes[I0].Domain <> Segments[I].Domain) or (Nodes[I1].Domain <> Segments[I].Domain) then
    begin
      Alerts.Add('Erro topológico: mistura de domínios em ' + Segments[I].Id);
      Segments[I].HasAlert := True;
      Continue;
    end;

    D_m := Segments[I].InnerDiamMM / 1000.0;
    Area := Pi * Sqr(D_m * 0.5);
    DZ_m := (Segments[I].P1.Z - Segments[I].P0.Z) / 1000.0;
    Segments[I].HasAlert := False;

    if (not Nodes[I0].ValveOpen) or (not Nodes[I1].ValveOpen) then
    begin
      Segments[I].CalcFlowLPS := 0.0;
      Segments[I].CalcVelocityMS := 0.0;
      Segments[I].CalcHeadLossKPa := 0.0;
      Continue;
    end;

    case Segments[I].Domain of
      tfdAguaFria, tfdAguaQuente:
        begin
          { Vazao a jusante e formula de Hazen-Williams (C=140 PVC/PPR) + hidrostatica }
          Segments[I].CalcFlowLPS := Max(0.05, Nodes[I1].DemandFlowLPS);
          Q_m3s := Segments[I].CalcFlowLPS / 1000.0;
          Vel := Q_m3s / Area;
          C_hw := 140.0;
          { J (m/m) = 10.67 * Q^1.852 / (C^1.852 * D^4.87) }
          LossKPa := 9.81 * Segments[I].LengthM * 10.67 * Power(Q_m3s, 1.852) /
            (Power(C_hw, 1.852) * Power(D_m, 4.87));
          Segments[I].CalcVelocityMS := Vel;
          Segments[I].CalcHeadLossKPa := LossKPa;
          Nodes[I1].CalcPressureKPaG := Nodes[I0].CalcPressureKPaG - LossKPa - 9.81 * DZ_m;
          Nodes[I1].CalcPressureKPaAbs := AtmPressureKPa + Nodes[I1].CalcPressureKPaG;
          if Segments[I].Domain = tfdAguaQuente then
          begin
            Segments[I].CalcTempOutC := Max(22.0, Nodes[I0].CalcTempC - 0.35 * Segments[I].LengthM);
            Nodes[I1].CalcTempC := Segments[I].CalcTempOutC;
          end
          else
            Segments[I].CalcTempOutC := Nodes[I0].CalcTempC;
          if Vel > 3.0 then
          begin
            Segments[I].HasAlert := True;
            Alerts.Add(Format('Velocidade > 3,0 m/s em %s (%.2f m/s)', [Segments[I].Id, Vel]));
          end;
          if Nodes[I1].CalcPressureKPaG < 10.0 then
          begin
            Segments[I].HasAlert := True;
            Alerts.Add(Format('Pressão dinâmica baixa em %s (%.1f kPa g)', [Nodes[I1].Id, Nodes[I1].CalcPressureKPaG]));
          end;
        end;

      tfdGas, tfdArComprimido:
        begin
          { Escoamento compressivel isotermico em pressao absoluta (P1^2 - P2^2) }
          Segments[I].CalcFlowLPS := Max(0.05, Nodes[I1].DemandFlowLPS);
          Q_m3s := Segments[I].CalcFlowLPS / 1000.0;
          Vel := Q_m3s / Area;
          P1Abs := Max(AtmPressureKPa, Nodes[I0].CalcPressureKPaAbs);
          { Perda de carga compressivel simplificada proporcional a f*(L/D)*rho*V^2*(Patm/P1) }
          LossKPa := 0.022 * (Segments[I].LengthM / D_m) * (1.25 * P1Abs / AtmPressureKPa) *
            0.5 * Vel * Vel / 1000.0;
          P1Sq := P1Abs * P1Abs;
          P2Sq := Max(AtmPressureKPa * AtmPressureKPa * 0.5, P1Sq - 2.0 * P1Abs * LossKPa);
          P2Abs := Sqrt(P2Sq);
          Segments[I].CalcVelocityMS := Vel;
          Segments[I].CalcHeadLossKPa := P1Abs - P2Abs;
          Segments[I].CalcTempOutC := Nodes[I0].CalcTempC;
          Nodes[I1].CalcPressureKPaAbs := P2Abs;
          Nodes[I1].CalcPressureKPaG := P2Abs - AtmPressureKPa;
          if Nodes[I1].CalcPressureKPaAbs <= AtmPressureKPa then
          begin
            Segments[I].HasAlert := True;
            Alerts.Add(Format('Pressão insuficiente na rede compressível %s', [Nodes[I1].Id]));
          end;
        end;

      tfdVentilacao:
        begin
          Segments[I].CalcFlowLPS := Max(10.0, Nodes[I1].DemandFlowLPS);
          Q_m3s := Segments[I].CalcFlowLPS / 1000.0;
          Vel := Q_m3s / Area;
          LossKPa := 0.02 * (Segments[I].LengthM / D_m) * 0.5 * 1.2 * Vel * Vel / 1000.0; // Pa -> kPa
          Segments[I].CalcVelocityMS := Vel;
          Segments[I].CalcHeadLossKPa := LossKPa;
          Segments[I].CalcTempOutC := Nodes[I0].CalcTempC;
          Nodes[I1].CalcPressureKPaG := Nodes[I0].CalcPressureKPaG - LossKPa;
          Nodes[I1].CalcPressureKPaAbs := AtmPressureKPa + Nodes[I1].CalcPressureKPaG;
        end;

      tfdEsgoto:
        begin
          { Escoamento por gravidade com superficie livre (Manning n=0.011 PVC) }
          Segments[I].CalcFlowLPS := Max(0.05, Nodes[I0].DemandFlowLPS);
          S_man := Segments[I].SlopePct / 100.0;
          N_man := 0.011;
          if S_man <= 0.0 then
          begin
            Segments[I].HasAlert := True;
            Segments[I].CalcVelocityMS := 0.0;
            Segments[I].CalcFillRatio := 1.0;
            Alerts.Add(Format('CONTRAPENDÊNCIA / REFLUXO em %s (declividade %.2f%%)', [Segments[I].Id, Segments[I].SlopePct]));
          end
          else
          begin
            { Capacidade a meia secao: Rh = D/4, A = pi*D^2/8 }
            Vel := (1.0 / N_man) * Power(D_m * 0.25, 2.0 / 3.0) * Sqrt(S_man);
            Q_m3s := Segments[I].CalcFlowLPS / 1000.0;
            Segments[I].CalcVelocityMS := Vel;
            Segments[I].CalcFillRatio := EnsureRange(Q_m3s / Max(1e-6, Vel * Area), 0.05, 1.0);
            if Segments[I].SlopePct < 1.0 then
            begin
              Segments[I].HasAlert := True;
              Alerts.Add(Format('Declividade baixa em %s (%.2f%% < 1,0%%)', [Segments[I].Id, Segments[I].SlopePct]));
            end;
          end;
          Segments[I].CalcTempOutC := Nodes[I0].CalcTempC;
        end;
    end;
  end;
end;

function TTUBProject.CheckClashes(const ElectricalPkgFile: string): Integer;
var
  I, J: Integer;
  P1, P2, EP0, EP1: TEAVec3;
  D, ERad: Double;
  Pkg: TEAPackageManifest;
  Arr: TJSONArray;
  Item, P0O, P1O: TJSONObject;
begin
  Result := 0;
  { Colisao entre redes distintas (agua/gas/esgoto/ar) }
  for I := 0 to High(Segments) do
    for J := I + 1 to High(Segments) do
    begin
      if Segments[I].Domain = Segments[J].Domain then Continue;
      D := EASegmentDistance3D(Segments[I].P0, Segments[I].P1, Segments[J].P0, Segments[J].P1, P1, P2);
      if D < (Segments[I].InnerDiamMM * 0.5 + Segments[J].InnerDiamMM * 0.5 + 10.0) then
      begin
        Inc(Result);
        Alerts.Add(Format('Interferência entre %s (%s) e %s (%s): %.1f mm',
          [Segments[I].Id, TUBDomainName(Segments[I].Domain),
           Segments[J].Id, TUBDomainName(Segments[J].Domain), D]));
      end;
    end;

  { Colisao I-20 com camada eletrica externa }
  if (ElectricalPkgFile <> '') and FileExists(ElectricalPkgFile) then
  begin
    Pkg := TEAPackageManifest.Create;
    try
      Pkg.LoadFromFile(ElectricalPkgFile);
      if Pkg.Payload <> nil then
      begin
        Arr := Pkg.Payload.Get('segments', TJSONArray(nil));
        if Arr <> nil then
          for I := 0 to Arr.Count - 1 do
          begin
            Item := Arr.Objects[I];
            P0O := Item.Get('p0_mm', TJSONObject(nil));
            P1O := Item.Get('p1_mm', TJSONObject(nil));
            if (P0O = nil) or (P1O = nil) then Continue;
            EP0 := EAV3(P0O.Get('x', 0.0), P0O.Get('y', 0.0), P0O.Get('z', 0.0));
            EP1 := EAV3(P1O.Get('x', 0.0), P1O.Get('y', 0.0), P1O.Get('z', 0.0));
            ERad := Max(10.0, Item.Get('diameter_mm', 25.0) * 0.5);
            for J := 0 to High(Segments) do
            begin
              D := EASegmentDistance3D(Segments[J].P0, Segments[J].P1, EP0, EP1, P1, P2);
              if D < (Segments[J].InnerDiamMM * 0.5 + ERad + 15.0) then
              begin
                Inc(Result);
                Alerts.Add(Format('Interferência I-20: tubo %s x eletroduto %s (%.1f mm)',
                  [Segments[J].Id, Item.Get('id', ''), D]));
              end;
            end;
          end;
      end;
    finally
      Pkg.Free;
    end;
  end;
end;

procedure TTUBProject.BuildNetworkMesh(Target: TEAMesh3D; IncludeArch: Boolean);
var
  I: Integer;
  Col: LongWord;
begin
  Target.Clear;
  if IncludeArch and (Length(ArchModel.Walls) > 0) then
    EABuildModelMesh(ArchModel, Target, '', $CBD5E1, $94A3B8, $A16207, $7DD3FC);

  for I := 0 to High(Nodes) do
  begin
    if (ActiveFilter >= 0) and (Ord(Nodes[I].Domain) <> ActiveFilter) then Continue;
    Target.AddBox(Nodes[I].PosMM, EAV3(130, 130, 130), TUBDomainColor(Nodes[I].Domain), 0, Nodes[I].Id);
  end;

  for I := 0 to High(Segments) do
  begin
    if (ActiveFilter >= 0) and (Ord(Segments[I].Domain) <> ActiveFilter) then Continue;
    if Segments[I].HasAlert then Col := $EF4444 else Col := TUBDomainColor(Segments[I].Domain);
    Target.AddPipeSegment(Segments[I].P0, Segments[I].P1,
      Max(10.0, Segments[I].InnerDiamMM * 0.5), 8, Col, 0, Segments[I].Id);
  end;
end;

function Vec3Obj(const V: TEAVec3): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('x', V.X); Result.Add('y', V.Y); Result.Add('z', V.Z);
end;

procedure TTUBProject.ExportPipeNetworkPackage(const FileName: string);
var
  Pkg: TEAPackageManifest;
  Payload, O: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Pkg := TEAPackageManifest.Create;
  Payload := TJSONObject.Create;
  try
    Pkg.PackageType := EA_PKG_REDE_TUBULACOES;
    Pkg.PackageId := ProjectId;
    Pkg.CreatedByApp := 'SimuTubulacoes';
    Payload.Add('project_id', ProjectId);
    Arr := TJSONArray.Create;
    for I := 0 to High(Segments) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Segments[I].Id);
      O.Add('domain', TUBDomainCode(Segments[I].Domain));
      O.Add('diameter_mm', Segments[I].InnerDiamMM);
      O.Add('slope_pct', Segments[I].SlopePct);
      O.Add('p0_mm', Vec3Obj(Segments[I].P0));
      O.Add('p1_mm', Vec3Obj(Segments[I].P1));
      Arr.Add(O);
    end;
    Payload.Add('segments', Arr);
    Pkg.Payload := Payload;
    Payload := nil;
    Pkg.SaveToFile(FileName);
  finally
    Payload.Free;
    Pkg.Free;
  end;
end;

procedure TTUBProject.ExportFluidResultsPackage(const FileName: string);
var
  Pkg: TEAPackageManifest;
  Payload, O: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Pkg := TEAPackageManifest.Create;
  Payload := TJSONObject.Create;
  try
    Pkg.PackageType := EA_PKG_RESULTADO_FLUIDOS;
    Pkg.PackageId := ProjectId + '-res';
    Pkg.CreatedByApp := 'SimuTubulacoes';
    Payload.Add('solver_version', SolverVersion);
    Payload.Add('atm_kpa', AtmPressureKPa);
    Arr := TJSONArray.Create;
    for I := 0 to High(Segments) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Segments[I].Id);
      O.Add('domain', TUBDomainCode(Segments[I].Domain));
      O.Add('flow_lps', Segments[I].CalcFlowLPS);
      O.Add('velocity_ms', Segments[I].CalcVelocityMS);
      O.Add('head_loss_kpa', Segments[I].CalcHeadLossKPa);
      O.Add('temp_out_c', Segments[I].CalcTempOutC);
      O.Add('fill_ratio', Segments[I].CalcFillRatio);
      O.Add('alert', Segments[I].HasAlert);
      Arr.Add(O);
    end;
    Payload.Add('segments', Arr);
    Pkg.Payload := Payload;
    Payload := nil;
    Pkg.SaveToFile(FileName);
  finally
    Payload.Free;
    Pkg.Free;
  end;
end;

procedure TTUBProject.ExportCoordinationRequests(const FileName: string);
var
  Pkg: TEAPackageManifest;
  Payload, O: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Pkg := TEAPackageManifest.Create;
  Payload := TJSONObject.Create;
  try
    Pkg.PackageType := EA_PKG_SOLICITACAO_COORD;
    Pkg.PackageId := ProjectId + '-coord';
    Pkg.CreatedByApp := 'SimuTubulacoes';
    Arr := TJSONArray.Create;
    for I := 0 to High(Segments) do
    begin
      O := TJSONObject.Create;
      O.Add('id', 'passagem-' + Segments[I].Id);
      O.Add('description', 'Passagem/shaft para ' + TUBDomainName(Segments[I].Domain) + ' (' + Segments[I].Id + ')');
      O.Add('pos_mm', Vec3Obj(Segments[I].P0));
      Arr.Add(O);
    end;
    Payload.Add('requests', Arr);
    Pkg.Payload := Payload;
    Payload := nil;
    Pkg.SaveToFile(FileName);
  finally
    Payload.Free;
    Pkg.Free;
  end;
end;

procedure TTUBProject.ExportReportCSV(const FileName: string);
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('Trecho;Rede;Diametro_mm;Comp_m;Decliv_Pct;Vazao_Lps;Vel_ms;Perda_kPa;Temp_C;Alerta');
    for I := 0 to High(Segments) do
      SL.Add(Format('%s;%s;%.1f;%.2f;%.2f;%.3f;%.2f;%.3f;%.1f;%s', [
        Segments[I].Id, TUBDomainName(Segments[I].Domain), Segments[I].InnerDiamMM,
        Segments[I].LengthM, Segments[I].SlopePct, Segments[I].CalcFlowLPS,
        Segments[I].CalcVelocityMS, Segments[I].CalcHeadLossKPa,
        Segments[I].CalcTempOutC, BoolToStr(Segments[I].HasAlert, 'SIM', 'NAO')]));
    EAAtomicWriteText(FileName, #$EF#$BB#$BF + SL.Text);
  finally
    SL.Free;
  end;
end;

procedure TTUBProject.ExportReportHTML(const FileName: string);
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>SimuTubulações</title>');
    SL.Add('<style>body{font-family:Segoe UI,sans-serif;margin:24px;}table{border-collapse:collapse;width:100%;}th,td{border:1px solid #cbd5e1;padding:6px;text-align:left;}</style></head><body>');
    SL.Add('<h1>SimuTubulações — Relatório de Redes</h1><p>' + SolverVersion + '</p>');
    SL.Add('<table><tr><th>Trecho</th><th>Rede</th><th>DN (mm)</th><th>Vazão (L/s)</th><th>Velocidade (m/s)</th><th>Perda (kPa)</th><th>Temp (°C)</th></tr>');
    for I := 0 to High(Segments) do
      SL.Add(Format('<tr><td>%s</td><td>%s</td><td>%.0f</td><td>%.2f</td><td>%.2f</td><td>%.3f</td><td>%.1f</td></tr>', [
        Segments[I].Id, TUBDomainName(Segments[I].Domain), Segments[I].InnerDiamMM,
        Segments[I].CalcFlowLPS, Segments[I].CalcVelocityMS, Segments[I].CalcHeadLossKPa, Segments[I].CalcTempOutC]));
    SL.Add('</table></body></html>');
    EAAtomicWriteText(FileName, SL.Text);
  finally
    SL.Free;
  end;
end;

procedure TTUBProject.SaveTubProject(const FileName: string);
var
  Root, O: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('schema_version', '1.0');
    Root.Add('project_id', ProjectId);
    Root.Add('arch_model', ArchModel.ToJSON);
    Arr := TJSONArray.Create;
    for I := 0 to High(Nodes) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Nodes[I].Id); O.Add('name', Nodes[I].Name);
      O.Add('domain', TUBDomainCode(Nodes[I].Domain)); O.Add('kind', Ord(Nodes[I].Kind));
      O.Add('pos_mm', Vec3Obj(Nodes[I].PosMM));
      O.Add('demand_lps', Nodes[I].DemandFlowLPS);
      O.Add('supply_kpag', Nodes[I].SupplyPressureKPaG);
      O.Add('supply_temp_c', Nodes[I].SupplyTempC);
      Arr.Add(O);
    end;
    Root.Add('nodes', Arr);
    Arr := TJSONArray.Create;
    for I := 0 to High(Segments) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Segments[I].Id); O.Add('domain', TUBDomainCode(Segments[I].Domain));
      O.Add('from_id', Segments[I].FromId); O.Add('to_id', Segments[I].ToId);
      O.Add('diam_mm', Segments[I].InnerDiamMM); O.Add('material', Segments[I].Material);
      O.Add('rough_mm', Segments[I].RoughnessMM);
      Arr.Add(O);
    end;
    Root.Add('segments', Arr);
    EAAtomicWriteText(FileName, Root.FormatJSON);
  finally
    Root.Free;
  end;
end;

procedure TTUBProject.LoadTubProject(const FileName: string);
var
  SL: TStringList;
  Data: TJSONData;
  Root, O, P: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  SL := TStringList.Create;
  try SL.LoadFromFile(FileName); Data := GetJSON(SL.Text); finally SL.Free; end;
  try
    if not (Data is TJSONObject) then raise EEAPackageError.Create('Projeto SimuTubulações inválido');
    Root := TJSONObject(Data);
    Clear;
    ProjectId := Root.Get('project_id', 'tub-001');
    if (Root.Find('arch_model') <> nil) and (Root.Find('arch_model') is TJSONObject) then
      ArchModel.FromJSON(Root.Objects['arch_model']);
    Arr := Root.Get('nodes', TJSONArray(nil));
    if Arr <> nil then
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        P := O.Get('pos_mm', TJSONObject(nil));
        AddNode(O.Get('id', ''), O.Get('name', ''), TUBStrToDomain(O.Get('domain', 'agua_fria')),
          TTUBNodeKind(EnsureRange(O.Get('kind', 4), 0, 6)),
          EAV3(P.Get('x', 0.0), P.Get('y', 0.0), P.Get('z', 0.0)),
          O.Get('demand_lps', 0.0), O.Get('supply_kpag', 0.0), O.Get('supply_temp_c', 22.0));
      end;
    Arr := Root.Get('segments', TJSONArray(nil));
    if Arr <> nil then
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        AddSegment(O.Get('id', ''), TUBStrToDomain(O.Get('domain', 'agua_fria')),
          O.Get('from_id', ''), O.Get('to_id', ''), O.Get('diam_mm', 25.0),
          O.Get('material', 'PVC'), O.Get('rough_mm', 0.015));
      end;
    RunAllDomainSolvers;
  finally
    Data.Free;
  end;
end;

end.
