unit ele_projeto;

{ Elétrica 3D - Núcleo do projeto elétrico tridimensional (etapas E1..E5).
  Implementa docs/Eletrica_3D.md e integrações I-12..I-16, I-20 de docs/Integracoes.md. }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, fpjson, jsonparser, aicostmodel,
  ea_geometria, ea_pacote, ea_modelo, ea_ancoras, ea_malha3d, ea_fileio, ea_undo;

type
  TELEPointKind = (epkQuadro, epkTomada, epkInterruptor, epkLuminaria, epkCaixa);

  TELEPoint = record
    Id: string;
    Name: string;
    Kind: TELEPointKind;
    Anchor: TEAAnchor;
    CircuitId: string;
    CommandTargetId: string; // interruptor -> luminaria
    PowerW: Double;
    PowerFactor: Double;
    VoltageV: Double;
  end;

  TELEConduit = record
    Id: string;
    CircuitId: string;
    FromId: string;
    ToId: string;
    P0, P1: TEAVec3;
    DiameterMM: Double;
    WireSectionMM2: Double;
    ConductorCount: Integer;
    Material: string;
    MarginPct: Double;
    LengthMM: Double;
  end;

  TELECircuit = record
    Id: string;
    Name: string;
    BoardId: string;
    Phase: string;
    VoltageV: Double;
    BreakerA: Double;
    WireSectionMM2: Double;
    TotalLoadW: Double;
    CurrentA: Double;
  end;

  TELEProject = class
  public
    ProjectId: string;
    ArchModel: TEAModel;
    ArchRefRevision: string;
    ArchRefHash: string;
    Points: array of TELEPoint;
    Conduits: array of TELEConduit;
    Circuits: array of TELECircuit;
    Alerts: TStringList;
    UndoHistory: TEASnapshotUndo;
    SimOverlays: array of record
      SegmentId: string;
      TempC: Double;
      CurrentA: Double;
      Overlimit: Boolean;
    end;
    constructor Create;
    destructor Destroy; override;
    function SnapshotToJSON: string;
    procedure RestoreFromSnapshotJSON(const JsonText: string);
    procedure BeginUndoStep(const Desc: string);
    function Undo: Boolean;
    function Redo: Boolean;
    function EstimateMaterialCostBRL: Double;
    procedure Clear;
    procedure LoadDemoProject;
    procedure ImportMaquetePackage(const FileName: string; Reconcile: Boolean);
    function AddCircuit(const AId, AName, ABoardId, APhase: string;
      AVoltageV, ABreakerA, AWireMM2: Double): Integer;
    function AddPoint(const AId, AName: string; AKind: TELEPointKind;
      const AFloorId, AHostId: string; AHostKind: TEAAnchorHostKind;
      const AOffsetMM: TEAVec3; const ACircuitId: string; APowerW: Double;
      AVoltageV: Double = 127.0): Integer;
    function AddConduit(const AId, ACircuitId, AFromId, AToId: string;
      ADiameterMM, AWireMM2: Double; ACondCount: Integer; AMarginPct: Double = 10.0): Integer;
    function FindPoint(const AId: string): Integer;
    function FindCircuit(const AId: string): Integer;
    procedure RecalculateEngineering;
    function CheckPlumbingClashes(const PlumbingPkgFile: string): Integer;
    procedure BuildMesh(Target: TEAMesh3D; IncludeArch: Boolean = True);
    procedure ExportElectricalLayer(const FileName: string);      // I-13 / I-20
    procedure ExportLightingState(const FileName: string);        // I-15
    procedure ExportSimulationModel(const FileName: string);      // I-16
    procedure ExportCoordinationRequests(const FileName: string); // I-14
    procedure ExportQuantitiesCSV(const FileName: string);
    procedure ImportSimulationResults(const FileName: string);    // I-17
    procedure SaveElectricalFile(const FileName: string);
    procedure LoadElectricalFile(const FileName: string);
  end;

function ELEPointKindToStr(K: TELEPointKind): string;
function ELEStrToPointKind(const S: string): TELEPointKind;

implementation

function ELEPointKindToStr(K: TELEPointKind): string;
begin
  case K of
    epkQuadro: Result := 'panel';
    epkTomada: Result := 'socket';
    epkInterruptor: Result := 'switch';
    epkLuminaria: Result := 'luminaire';
  else
    Result := 'junction_box';
  end;
end;

function ELEStrToPointKind(const S: string): TELEPointKind;
var L: string;
begin
  L := LowerCase(Trim(S));
  if L = 'panel' then Result := epkQuadro
  else if L = 'socket' then Result := epkTomada
  else if L = 'switch' then Result := epkInterruptor
  else if L = 'luminaire' then Result := epkLuminaria
  else Result := epkCaixa;
end;

constructor TELEProject.Create;
begin
  inherited Create;
  ArchModel := TEAModel.Create;
  Alerts := TStringList.Create;
  UndoHistory := TEASnapshotUndo.Create(@SnapshotToJSON, @RestoreFromSnapshotJSON);
  Clear;
end;

destructor TELEProject.Destroy;
begin
  UndoHistory.Free;
  Alerts.Free;
  ArchModel.Free;
  inherited Destroy;
end;

procedure TELEProject.Clear;
begin
  ProjectId := 'eletrica-001';
  ArchModel.Clear;
  ArchRefRevision := 'rev-001';
  ArchRefHash := '';
  SetLength(Points, 0);
  SetLength(Conduits, 0);
  SetLength(Circuits, 0);
  SetLength(SimOverlays, 0);
  Alerts.Clear;
end;

procedure TELEProject.LoadDemoProject;
var
  Poly: TEAVec2Array;
begin
  Clear;
  ArchModel.ProjectId := 'hosp-demo';
  ArchModel.AddFloor('terreo', 'Térreo', 0, 2800, 150);
  ArchModel.AddWall('w1', 'terreo', EAV2(0, 0), EAV2(5000, 0), 150, 2800);
  ArchModel.AddWall('w2', 'terreo', EAV2(5000, 0), EAV2(5000, 4000), 150, 2800);
  ArchModel.AddWall('w3', 'terreo', EAV2(5000, 4000), EAV2(0, 4000), 150, 2800);
  ArchModel.AddWall('w4', 'terreo', EAV2(0, 4000), EAV2(0, 0), 150, 2800);
  ArchModel.AddOpening('d1', 'w1', 'terreo', eokDoor, 1200, 900, 2100, 0);
  SetLength(Poly, 4);
  Poly[0] := EAV2(0, 0); Poly[1] := EAV2(5000, 0); Poly[2] := EAV2(5000, 4000); Poly[3] := EAV2(0, 4000);
  ArchModel.AddSlab('laje-terreo', 'terreo', Poly, 150);

  AddCircuit('C1', 'Iluminação Recepção', 'QDC-01', 'F1', 127.0, 10.0, 1.5);
  AddCircuit('C2', 'Tomadas TUG/TUE', 'QDC-01', 'F2', 127.0, 20.0, 2.5);

  AddPoint('QDC-01', 'Quadro Geral', epkQuadro, 'terreo', 'w4', ahkWall, EAV3(800, 80, 1600), '', 0);
  AddPoint('LUM-01', 'Painel LED 1', epkLuminaria, 'terreo', 'terreo', ahkCeiling, EAV3(2500, 2000, 50), 'C1', 100);
  AddPoint('INT-01', 'Interruptor Entrada', epkInterruptor, 'terreo', 'w1', ahkWall, EAV3(900, 80, 1100), 'C1', 0);
  Points[High(Points)].CommandTargetId := 'LUM-01';
  AddPoint('TOM-01', 'Tomada Parede Sul', epkTomada, 'terreo', 'w1', ahkWall, EAV3(3000, 80, 300), 'C2', 600);
  AddPoint('TOM-02', 'Tomada Parede Leste', epkTomada, 'terreo', 'w2', ahkWall, EAV3(2000, 80, 300), 'C2', 1200);

  AddConduit('ED-01', 'C1', 'QDC-01', 'LUM-01', 25.0, 1.5, 3, 10.0);
  AddConduit('ED-02', 'C1', 'LUM-01', 'INT-01', 20.0, 1.5, 2, 10.0);
  AddConduit('ED-03', 'C2', 'QDC-01', 'TOM-01', 25.0, 2.5, 3, 10.0);
  AddConduit('ED-04', 'C2', 'TOM-01', 'TOM-02', 25.0, 2.5, 3, 10.0);
  RecalculateEngineering;
end;

procedure TELEProject.ImportMaquetePackage(const FileName: string; Reconcile: Boolean);
var
  Pkg: TEAPackageManifest;
  NewM: TEAModel;
  I, Orphans: Integer;
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
    if Reconcile then
    begin
      Orphans := 0;
      for I := 0 to High(Points) do
        if not EAResolveAnchor(Points[I].Anchor, ArchModel) then
          Inc(Orphans);
      if Orphans > 0 then
        Alerts.Add(Format('Revisão da maquete impactou %d ponto(s) elétrico(s). Confirme antes de reposicionar.', [Orphans]));
      RecalculateEngineering;
    end;
  finally
    NewM.Free;
    Pkg.Free;
  end;
end;

function TELEProject.AddCircuit(const AId, AName, ABoardId, APhase: string;
  AVoltageV, ABreakerA, AWireMM2: Double): Integer;
begin
  Result := FindCircuit(AId);
  if Result < 0 then
  begin
    Result := Length(Circuits);
    SetLength(Circuits, Result + 1);
  end;
  Circuits[Result].Id := AId;
  Circuits[Result].Name := AName;
  Circuits[Result].BoardId := ABoardId;
  Circuits[Result].Phase := APhase;
  Circuits[Result].VoltageV := AVoltageV;
  Circuits[Result].BreakerA := ABreakerA;
  Circuits[Result].WireSectionMM2 := AWireMM2;
  Circuits[Result].TotalLoadW := 0;
  Circuits[Result].CurrentA := 0;
end;

function TELEProject.AddPoint(const AId, AName: string; AKind: TELEPointKind;
  const AFloorId, AHostId: string; AHostKind: TEAAnchorHostKind;
  const AOffsetMM: TEAVec3; const ACircuitId: string; APowerW, AVoltageV: Double): Integer;
begin
  Result := Length(Points);
  SetLength(Points, Result + 1);
  Points[Result].Id := AId;
  Points[Result].Name := AName;
  Points[Result].Kind := AKind;
  Points[Result].Anchor.AnchorId := 'anc-' + AId;
  Points[Result].Anchor.TargetId := AId;
  Points[Result].Anchor.FloorId := AFloorId;
  Points[Result].Anchor.HostId := AHostId;
  Points[Result].Anchor.HostKind := AHostKind;
  Points[Result].Anchor.OffsetMM := AOffsetMM;
  Points[Result].CircuitId := ACircuitId;
  Points[Result].PowerW := APowerW;
  Points[Result].PowerFactor := 0.92;
  Points[Result].VoltageV := AVoltageV;
  EAResolveAnchor(Points[Result].Anchor, ArchModel);
end;

function TELEProject.AddConduit(const AId, ACircuitId, AFromId, AToId: string;
  ADiameterMM, AWireMM2: Double; ACondCount: Integer; AMarginPct: Double): Integer;
var
  I0, I1: Integer;
begin
  I0 := FindPoint(AFromId);
  I1 := FindPoint(AToId);
  Result := Length(Conduits);
  SetLength(Conduits, Result + 1);
  Conduits[Result].Id := AId;
  Conduits[Result].CircuitId := ACircuitId;
  Conduits[Result].FromId := AFromId;
  Conduits[Result].ToId := AToId;
  if I0 >= 0 then Conduits[Result].P0 := Points[I0].Anchor.WorldPosMM;
  if I1 >= 0 then Conduits[Result].P1 := Points[I1].Anchor.WorldPosMM;
  Conduits[Result].DiameterMM := ADiameterMM;
  Conduits[Result].WireSectionMM2 := AWireMM2;
  Conduits[Result].ConductorCount := Max(2, ACondCount);
  Conduits[Result].Material := 'PVC';
  Conduits[Result].MarginPct := AMarginPct;
  Conduits[Result].LengthMM := EAV3Dist(Conduits[Result].P0, Conduits[Result].P1) * (1.0 + AMarginPct / 100.0);
end;

function TELEProject.FindPoint(const AId: string): Integer;
var I: Integer;
begin
  for I := 0 to High(Points) do if Points[I].Id = AId then Exit(I);
  Result := -1;
end;

function TELEProject.FindCircuit(const AId: string): Integer;
var I: Integer;
begin
  for I := 0 to High(Circuits) do if Circuits[I].Id = AId then Exit(I);
  Result := -1;
end;

procedure TELEProject.RecalculateEngineering;
var
  I, J, I0, I1: Integer;
  AreaCond, AreaTube, FillPct: Double;
begin
  Alerts.Clear;
  for I := 0 to High(Circuits) do
  begin
    Circuits[I].TotalLoadW := 0;
    for J := 0 to High(Points) do
      if Points[J].CircuitId = Circuits[I].Id then
        Circuits[I].TotalLoadW := Circuits[I].TotalLoadW + Points[J].PowerW;
    if Circuits[I].VoltageV > 0 then
      Circuits[I].CurrentA := Circuits[I].TotalLoadW / (Circuits[I].VoltageV * 0.92)
    else
      Circuits[I].CurrentA := 0;
    if Circuits[I].CurrentA > Circuits[I].BreakerA then
      Alerts.Add(Format('NBR 5410 (assistivo): Circuito %s com corrente %.1f A excede disjuntor %.0f A.',
        [Circuits[I].Id, Circuits[I].CurrentA, Circuits[I].BreakerA]));
  end;

  for I := 0 to High(Points) do
  begin
    if Points[I].Anchor.Status = easOrphaned then
      Alerts.Add(Format('Ponto órfão %s: %s', [Points[I].Id, Points[I].Anchor.Note]));
  end;

  for I := 0 to High(Conduits) do
  begin
    I0 := FindPoint(Conduits[I].FromId);
    I1 := FindPoint(Conduits[I].ToId);
    if (I0 >= 0) and (I1 >= 0) then
    begin
      Conduits[I].P0 := Points[I0].Anchor.WorldPosMM;
      Conduits[I].P1 := Points[I1].Anchor.WorldPosMM;
      Conduits[I].LengthMM := EAV3Dist(Conduits[I].P0, Conduits[I].P1) * (1.0 + Conduits[I].MarginPct / 100.0);
    end
    else
      Alerts.Add(Format('Roteamento interrompido no eletroduto %s.', [Conduits[I].Id]));

    AreaCond := Conduits[I].ConductorCount * Conduits[I].WireSectionMM2 * 2.5; // considerando isolacao
    AreaTube := Pi * Sqr(Conduits[I].DiameterMM * 0.5);
    if AreaTube > 0 then FillPct := 100.0 * AreaCond / AreaTube else FillPct := 100.0;
    if FillPct > 40.0 then
      Alerts.Add(Format('NBR 5410 (assistivo): Ocupação de %s em %.1f%% (>40%%).', [Conduits[I].Id, FillPct]));
  end;
end;

function TELEProject.CheckPlumbingClashes(const PlumbingPkgFile: string): Integer;
var
  Pkg: TEAPackageManifest;
  Arr: TJSONArray;
  Item, P0Obj, P1Obj: TJSONObject;
  I, J: Integer;
  TP0, TP1, C1, C2: TEAVec3;
  TRad, D: Double;
begin
  Result := 0;
  Pkg := TEAPackageManifest.Create;
  try
    Pkg.LoadFromFile(PlumbingPkgFile);
    if Pkg.Payload = nil then Exit;
    Arr := Pkg.Payload.Get('segments', TJSONArray(nil));
    if Arr = nil then Exit;
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Objects[I];
      P0Obj := Item.Get('p0_mm', TJSONObject(nil));
      P1Obj := Item.Get('p1_mm', TJSONObject(nil));
      if (P0Obj = nil) or (P1Obj = nil) then Continue;
      TP0 := EAV3(P0Obj.Get('x', 0.0), P0Obj.Get('y', 0.0), P0Obj.Get('z', 0.0));
      TP1 := EAV3(P1Obj.Get('x', 0.0), P1Obj.Get('y', 0.0), P1Obj.Get('z', 0.0));
      TRad := Max(10.0, Item.Get('diameter_mm', 25.0) * 0.5);
      for J := 0 to High(Conduits) do
      begin
        D := EASegmentDistance3D(Conduits[J].P0, Conduits[J].P1, TP0, TP1, C1, C2);
        if D < (Conduits[J].DiameterMM * 0.5 + TRad + 15.0) then
        begin
          Inc(Result);
          Alerts.Add(Format('Interferência I-20: eletroduto %s x tubo %s (%.1f mm)',
            [Conduits[J].Id, Item.Get('id', ''), D]));
        end;
      end;
    end;
  finally
    Pkg.Free;
  end;
end;

procedure TELEProject.BuildMesh(Target: TEAMesh3D; IncludeArch: Boolean);
var
  I: Integer;
  Col: LongWord;
begin
  Target.Clear;
  if IncludeArch and (Length(ArchModel.Walls) > 0) then
    EABuildModelMesh(ArchModel, Target, '', $CBD5E1, $94A3B8, $A16207, $7DD3FC);

  for I := 0 to High(Points) do
  begin
    case Points[I].Kind of
      epkQuadro: Col := $EF4444;
      epkLuminaria: Col := $FACC15;
      epkInterruptor: Col := $38BDF8;
      epkTomada: Col := $22C55E;
    else
      Col := $A855F7;
    end;
    Target.AddBox(Points[I].Anchor.WorldPosMM, EAV3(160, 120, 160), Col, 0, Points[I].Id);
  end;

  for I := 0 to High(Conduits) do
    Target.AddPipeSegment(Conduits[I].P0, Conduits[I].P1,
      Max(10.0, Conduits[I].DiameterMM * 0.5), 8, $F59E0B, 0, Conduits[I].Id);
end;

function VecObj(const V: TEAVec3): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('x', V.X); Result.Add('y', V.Y); Result.Add('z', V.Z);
end;

procedure TELEProject.ExportElectricalLayer(const FileName: string);
var
  Pkg: TEAPackageManifest;
  Payload, O: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Pkg := TEAPackageManifest.Create;
  Payload := TJSONObject.Create;
  try
    Pkg.PackageType := EA_PKG_CAMADA_ELETRICA;
    Pkg.PackageId := ProjectId;
    Pkg.CreatedByApp := 'Eletrica3D';
    Payload.Add('discipline', 'electrical');
    Payload.Add('project_id', ProjectId);
    Arr := TJSONArray.Create;
    for I := 0 to High(Points) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Points[I].Id);
      O.Add('type', ELEPointKindToStr(Points[I].Kind));
      O.Add('circuit_id', Points[I].CircuitId);
      O.Add('anchor', EAAnchorToJSON(Points[I].Anchor));
      Arr.Add(O);
    end;
    Payload.Add('objects', Arr);
    Arr := TJSONArray.Create;
    for I := 0 to High(Conduits) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Conduits[I].Id);
      O.Add('circuit_id', Conduits[I].CircuitId);
      O.Add('diameter_mm', Conduits[I].DiameterMM);
      O.Add('p0_mm', VecObj(Conduits[I].P0));
      O.Add('p1_mm', VecObj(Conduits[I].P1));
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

procedure TELEProject.ExportLightingState(const FileName: string);
var
  Pkg: TEAPackageManifest;
  Payload, O: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Pkg := TEAPackageManifest.Create;
  Payload := TJSONObject.Create;
  try
    Pkg.PackageType := EA_PKG_ESTADO_ILUMINACAO;
    Pkg.PackageId := ProjectId + '-luz';
    Pkg.CreatedByApp := 'Eletrica3D';
    Arr := TJSONArray.Create;
    for I := 0 to High(Points) do
    begin
      if Points[I].Kind <> epkLuminaria then Continue;
      O := TJSONObject.Create;
      O.Add('id', Points[I].Id);
      O.Add('name', Points[I].Name);
      O.Add('pos_mm', VecObj(Points[I].Anchor.WorldPosMM));
      O.Add('power_w', Points[I].PowerW);
      O.Add('on', True);
      Arr.Add(O);
    end;
    Payload.Add('luminaires', Arr);
    Pkg.Payload := Payload;
    Payload := nil;
    Pkg.SaveToFile(FileName);
  finally
    Payload.Free;
    Pkg.Free;
  end;
end;

procedure TELEProject.ExportSimulationModel(const FileName: string);
var
  Pkg: TEAPackageManifest;
  Payload, O: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  RecalculateEngineering;
  Pkg := TEAPackageManifest.Create;
  Payload := TJSONObject.Create;
  try
    Pkg.PackageType := EA_PKG_MODELO_ELETRICO;
    Pkg.PackageId := ProjectId + '-sim';
    Pkg.CreatedByApp := 'Eletrica3D';
    Payload.Add('project_id', ProjectId);
    Arr := TJSONArray.Create;
    for I := 0 to High(Circuits) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Circuits[I].Id);
      O.Add('name', Circuits[I].Name);
      O.Add('board_id', Circuits[I].BoardId);
      O.Add('phase', Circuits[I].Phase);
      O.Add('voltage_v', Circuits[I].VoltageV);
      O.Add('breaker_a', Circuits[I].BreakerA);
      O.Add('wire_mm2', Circuits[I].WireSectionMM2);
      Arr.Add(O);
    end;
    Payload.Add('circuits', Arr);

    Arr := TJSONArray.Create;
    for I := 0 to High(Points) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Points[I].Id);
      O.Add('name', Points[I].Name);
      O.Add('kind', ELEPointKindToStr(Points[I].Kind));
      O.Add('circuit_id', Points[I].CircuitId);
      O.Add('power_w', Points[I].PowerW);
      O.Add('power_factor', Points[I].PowerFactor);
      O.Add('voltage_v', Points[I].VoltageV);
      O.Add('pos_mm', VecObj(Points[I].Anchor.WorldPosMM));
      Arr.Add(O);
    end;
    Payload.Add('nodes', Arr);

    Arr := TJSONArray.Create;
    for I := 0 to High(Conduits) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Conduits[I].Id);
      O.Add('circuit_id', Conduits[I].CircuitId);
      O.Add('from_id', Conduits[I].FromId);
      O.Add('to_id', Conduits[I].ToId);
      O.Add('wire_mm2', Conduits[I].WireSectionMM2);
      O.Add('length_m', Conduits[I].LengthMM / 1000.0);
      O.Add('p0_mm', VecObj(Conduits[I].P0));
      O.Add('p1_mm', VecObj(Conduits[I].P1));
      Arr.Add(O);
    end;
    Payload.Add('branches', Arr);
    Pkg.Payload := Payload;
    Payload := nil;
    Pkg.SaveToFile(FileName);
  finally
    Payload.Free;
    Pkg.Free;
  end;
end;

procedure TELEProject.ExportCoordinationRequests(const FileName: string);
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
    Pkg.CreatedByApp := 'Eletrica3D';
    Arr := TJSONArray.Create;
    for I := 0 to High(Points) do
      if Points[I].Kind = epkQuadro then
      begin
        O := TJSONObject.Create;
        O.Add('id', 'rasgo-' + Points[I].Id);
        O.Add('description', 'Nicho para quadro elétrico ' + Points[I].Id);
        O.Add('pos_mm', VecObj(Points[I].Anchor.WorldPosMM));
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

function TELEProject.EstimateMaterialCostBRL: Double;
var
  I: Integer;
  PointUnitCost, ConduitUnitCostPerM: Double;
begin
  Result := 0.0;
  for I := 0 to High(Points) do
  begin
    case Points[I].Kind of
      epkQuadro: PointUnitCost := 480.0;
      epkLuminaria: PointUnitCost := 135.0;
      epkInterruptor: PointUnitCost := 38.0;
      epkTomada: PointUnitCost := 42.0;
    else
      PointUnitCost := 25.0;
    end;
    Result := Result + AIMaterialCost(1.0, PointUnitCost);
  end;
  for I := 0 to High(Conduits) do
  begin
    ConduitUnitCostPerM := 14.0 + Conduits[I].ConductorCount * (3.5 + Conduits[I].WireSectionMM2 * 2.2);
    Result := Result + AIMaterialCost(Conduits[I].LengthMM / 1000.0, ConduitUnitCostPerM);
  end;
end;

procedure TELEProject.ExportQuantitiesCSV(const FileName: string);
var
  SL: TStringList;
  I: Integer;
  TotalBRL: Double;
begin
  SL := TStringList.Create;
  try
    SL.Add('Categoria;ID;Descricao;Circuito;Quantidade_ou_Comprimento_m;Secao_mm2_ou_Potencia_W');
    for I := 0 to High(Points) do
      SL.Add(Format('Ponto;%s;%s;%s;1;%.0f W', [Points[I].Id, Points[I].Name, Points[I].CircuitId, Points[I].PowerW]));
    for I := 0 to High(Conduits) do
      SL.Add(Format('Eletroduto;%s;%s->%s;%s;%.2f m;%.1f mm2 (%d cond)', [
        Conduits[I].Id, Conduits[I].FromId, Conduits[I].ToId, Conduits[I].CircuitId,
        Conduits[I].LengthMM / 1000.0, Conduits[I].WireSectionMM2, Conduits[I].ConductorCount]));
    TotalBRL := EstimateMaterialCostBRL;
    SL.Add(Format('Resumo;COST-MAT;Custo estimado materiais (AICostModel);-;1;%s', [AIFormatMoney(TotalBRL, 'R$')]));
    EAAtomicWriteText(FileName, #$EF#$BB#$BF + SL.Text);
  finally
    SL.Free;
  end;
end;

procedure TELEProject.ImportSimulationResults(const FileName: string);
var
  Pkg: TEAPackageManifest;
  Arr: TJSONArray;
  Item: TJSONObject;
  I: Integer;
begin
  Pkg := TEAPackageManifest.Create;
  try
    Pkg.LoadFromFile(FileName);
    if Pkg.PackageType <> EA_PKG_RESULTADO_SIMULACAO then
      raise EEAPackageError.Create('Esperado pacote resultado_simulacao');
    if Pkg.Payload = nil then Exit;
    Arr := Pkg.Payload.Get('branches', TJSONArray(nil));
    if Arr = nil then Exit;
    SetLength(SimOverlays, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Objects[I];
      SimOverlays[I].SegmentId := Item.Get('id', '');
      SimOverlays[I].TempC := Item.Get('temp_c', 25.0);
      SimOverlays[I].CurrentA := Item.Get('current_a', 0.0);
      SimOverlays[I].Overlimit := Item.Get('overlimit', False);
    end;
  finally
    Pkg.Free;
  end;
end;

function TELEProject.SnapshotToJSON: string;
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
    for I := 0 to High(Circuits) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Circuits[I].Id); O.Add('name', Circuits[I].Name); O.Add('board_id', Circuits[I].BoardId);
      O.Add('phase', Circuits[I].Phase); O.Add('voltage_v', Circuits[I].VoltageV);
      O.Add('breaker_a', Circuits[I].BreakerA); O.Add('wire_mm2', Circuits[I].WireSectionMM2);
      Arr.Add(O);
    end;
    Root.Add('circuits', Arr);
    Arr := TJSONArray.Create;
    for I := 0 to High(Points) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Points[I].Id); O.Add('name', Points[I].Name); O.Add('kind', ELEPointKindToStr(Points[I].Kind));
      O.Add('anchor', EAAnchorToJSON(Points[I].Anchor)); O.Add('circuit_id', Points[I].CircuitId);
      O.Add('power_w', Points[I].PowerW); O.Add('voltage_v', Points[I].VoltageV);
      Arr.Add(O);
    end;
    Root.Add('points', Arr);
    Arr := TJSONArray.Create;
    for I := 0 to High(Conduits) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Conduits[I].Id); O.Add('circuit_id', Conduits[I].CircuitId);
      O.Add('from_id', Conduits[I].FromId); O.Add('to_id', Conduits[I].ToId);
      O.Add('diameter_mm', Conduits[I].DiameterMM); O.Add('wire_mm2', Conduits[I].WireSectionMM2);
      O.Add('conductor_count', Conduits[I].ConductorCount); O.Add('margin_pct', Conduits[I].MarginPct);
      Arr.Add(O);
    end;
    Root.Add('conduits', Arr);
    Result := Root.FormatJSON;
  finally
    Root.Free;
  end;
end;

procedure TELEProject.RestoreFromSnapshotJSON(const JsonText: string);
var
  Data: TJSONData;
  Root, O: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Data := GetJSON(JsonText);
  try
    if not (Data is TJSONObject) then raise EEAPackageError.Create('Projeto elétrico inválido');
    Root := TJSONObject(Data);
    Clear;
    ProjectId := Root.Get('project_id', 'eletrica-001');
    if (Root.Find('arch_model') <> nil) and (Root.Find('arch_model') is TJSONObject) then
      ArchModel.FromJSON(Root.Objects['arch_model']);
    Arr := Root.Get('circuits', TJSONArray(nil));
    if Arr <> nil then
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        AddCircuit(O.Get('id', ''), O.Get('name', ''), O.Get('board_id', ''),
          O.Get('phase', 'F1'), O.Get('voltage_v', 127.0), O.Get('breaker_a', 16.0), O.Get('wire_mm2', 2.5));
      end;
    Arr := Root.Get('points', TJSONArray(nil));
    if Arr <> nil then
    begin
      SetLength(Points, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        Points[I].Id := O.Get('id', '');
        Points[I].Name := O.Get('name', '');
        Points[I].Kind := ELEStrToPointKind(O.Get('kind', 'socket'));
        Points[I].Anchor := EAAnchorFromJSON(O.Objects['anchor']);
        Points[I].CircuitId := O.Get('circuit_id', '');
        Points[I].PowerW := O.Get('power_w', 0.0);
        Points[I].PowerFactor := 0.92;
        Points[I].VoltageV := O.Get('voltage_v', 127.0);
      end;
    end;
    Arr := Root.Get('conduits', TJSONArray(nil));
    if Arr <> nil then
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        AddConduit(O.Get('id', ''), O.Get('circuit_id', ''), O.Get('from_id', ''),
          O.Get('to_id', ''), O.Get('diameter_mm', 25.0), O.Get('wire_mm2', 2.5),
          O.Get('conductor_count', 3), O.Get('margin_pct', 10.0));
      end;
    RecalculateEngineering;
  finally
    Data.Free;
  end;
end;

procedure TELEProject.BeginUndoStep(const Desc: string);
begin
  UndoHistory.RecordBefore(Desc);
end;

function TELEProject.Undo: Boolean;
begin
  Result := UndoHistory.Undo;
end;

function TELEProject.Redo: Boolean;
begin
  Result := UndoHistory.Redo;
end;

procedure TELEProject.SaveElectricalFile(const FileName: string);
begin
  EAAtomicWriteText(FileName, SnapshotToJSON);
end;

procedure TELEProject.LoadElectricalFile(const FileName: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.LoadFromFile(FileName);
    RestoreFromSnapshotJSON(SL.Text);
    UndoHistory.Clear;
  finally
    SL.Free;
  end;
end;

end.
