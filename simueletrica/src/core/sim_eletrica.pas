unit sim_eletrica;

{ SimuEletrica - Núcleo de simulação elétrica, faltas, proteções, RLC e mapa térmico (etapas S1..S4).
  Implementa docs/SimuEletrica.md e integrações I-16, I-17 de docs/Integracoes.md.
  Nota técnica: resultados são estimativas condicionadas às hipóteses do solver;
  não substituem laudo técnico ou ensaio físico. }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, fpjson, jsonparser,
  ea_geometria, ea_pacote, ea_malha3d, ea_fileio, ea_undo;

type
  TSIMScenarioKind = (sskNormal, sskMaxLoad, sskShortCircuit, sskHotAmbient);

  TSIMCircuit = record
    Id: string;
    Name: string;
    Phase: string;
    VoltageV: Double;
    BreakerA: Double;
    WireMM2: Double;
  end;

  TSIMNode = record
    Id: string;
    Name: string;
    Kind: string;
    CircuitId: string;
    PowerW: Double;
    PowerFactor: Double;
    VoltageV: Double;
    PosMM: TEAVec3;
  end;

  TSIMBranchResult = record
    Id: string;
    CircuitId: string;
    FromId: string;
    ToId: string;
    WireMM2: Double;
    LengthM: Double;
    P0, P1: TEAVec3;
    CurrentA: Double;
    FaultCurrentA: Double;
    DropV: Double;
    DropPct: Double;
    LossesW: Double;
    LossesWPerM: Double;
    ConductorTempC: Double;
    TempLimitC: Double;
    Overlimit: Boolean;
    TripTimeSec: Double;
  end;

  TSIMEvent = record
    TimeSec: Double;
    Kind: string;
    TargetId: string;
    Detail: string;
  end;

  TSIMProject = class
  public
    ProjectId: string;
    ElectricalRefPath: string;
    ElectricalRefHash: string;
    ScenarioName: string;
    ScenarioKind: TSIMScenarioKind;
    AmbientTempC: Double;
    LoadFactor: Double;
    FaultTargetId: string;
    FaultImpedanceOhm: Double;
    TimeInstSec: Double;
    SolverVersion: string;
    Circuits: array of TSIMCircuit;
    Nodes: array of TSIMNode;
    Branches: array of TSIMBranchResult;
    Events: array of TSIMEvent;
    Warnings: TStringList;
    UndoHistory: TEASnapshotUndo;
    constructor Create;
    destructor Destroy; override;
    function SnapshotToJSON: string;
    procedure RestoreFromSnapshotJSON(const JsonText: string);
    procedure BeginUndoStep(const Desc: string);
    function Undo: Boolean;
    function Redo: Boolean;
    procedure Clear;
    procedure LoadDemoModel;
    procedure ImportElectricalModel(const FileName: string);
    procedure RunSimulation;
    procedure BuildThermalMesh(Target: TEAMesh3D);
    procedure ExportResultsPackage(const FileName: string);
    procedure ExportReportCSV(const FileName: string);
    procedure ExportReportHTML(const FileName: string);
  end;

function SIMTempToRGB(TempC, MinC, MaxC: Double): LongWord;

implementation

function SIMTempToRGB(TempC, MinC, MaxC: Double): LongWord;
var
  T: Double;
  R, G, B: Integer;
begin
  if MaxC <= MinC then MaxC := MinC + 1.0;
  T := EnsureRange((TempC - MinC) / (MaxC - MinC), 0.0, 1.0);
  if T < 0.5 then
  begin
    { Azul -> Amarelo }
    R := Round(59 + (250 - 59) * (T * 2.0));
    G := Round(130 + (204 - 130) * (T * 2.0));
    B := Round(246 + (21 - 246) * (T * 2.0));
  end
  else
  begin
    { Amarelo -> Vermelho critico }
    R := Round(250 + (239 - 250) * ((T - 0.5) * 2.0));
    G := Round(204 + (68 - 204) * ((T - 0.5) * 2.0));
    B := Round(21 + (68 - 21) * ((T - 0.5) * 2.0));
  end;
  Result := (LongWord(EnsureRange(R, 0, 255)) shl 16) or
            (LongWord(EnsureRange(G, 0, 255)) shl 8) or
            LongWord(EnsureRange(B, 0, 255));
end;

constructor TSIMProject.Create;
begin
  inherited Create;
  Warnings := TStringList.Create;
  UndoHistory := TEASnapshotUndo.Create(@SnapshotToJSON, @RestoreFromSnapshotJSON);
  Clear;
end;

destructor TSIMProject.Destroy;
begin
  UndoHistory.Free;
  Warnings.Free;
  inherited Destroy;
end;

procedure TSIMProject.Clear;
begin
  ProjectId := 'sim-001';
  ElectricalRefPath := '';
  ElectricalRefHash := '';
  ScenarioName := 'Operação Normal';
  ScenarioKind := sskNormal;
  AmbientTempC := 30.0;
  LoadFactor := 1.0;
  FaultTargetId := '';
  FaultImpedanceOhm := 0.25;
  TimeInstSec := 1800.0;
  SolverVersion := 'SimuEletrica-Solver-1.0 (IEC60287-est/Regime-CC)';
  SetLength(Circuits, 0);
  SetLength(Nodes, 0);
  SetLength(Branches, 0);
  SetLength(Events, 0);
  Warnings.Clear;
end;

procedure TSIMProject.LoadDemoModel;
  procedure AddN(const Id, Nm, Knd, CId: string; W, V: Double; const P: TEAVec3);
  var N: Integer;
  begin
    N := Length(Nodes); SetLength(Nodes, N + 1);
    Nodes[N].Id := Id; Nodes[N].Name := Nm; Nodes[N].Kind := Knd;
    Nodes[N].CircuitId := CId; Nodes[N].PowerW := W; Nodes[N].PowerFactor := 0.92;
    Nodes[N].VoltageV := V; Nodes[N].PosMM := P;
  end;
  procedure AddB(const Id, CId, F, T: string; WMM2, LM: Double; const P0, P1: TEAVec3);
  var N: Integer;
  begin
    N := Length(Branches); SetLength(Branches, N + 1);
    Branches[N] := Default(TSIMBranchResult);
    Branches[N].Id := Id; Branches[N].CircuitId := CId; Branches[N].FromId := F; Branches[N].ToId := T;
    Branches[N].WireMM2 := WMM2; Branches[N].LengthM := LM; Branches[N].P0 := P0; Branches[N].P1 := P1;
  end;
begin
  Clear;
  SetLength(Circuits, 2);
  Circuits[0].Id := 'C1'; Circuits[0].Name := 'Iluminação'; Circuits[0].Phase := 'F1';
  Circuits[0].VoltageV := 127.0; Circuits[0].BreakerA := 10.0; Circuits[0].WireMM2 := 1.5;
  Circuits[1].Id := 'C2'; Circuits[1].Name := 'Tomadas'; Circuits[1].Phase := 'F2';
  Circuits[1].VoltageV := 127.0; Circuits[1].BreakerA := 20.0; Circuits[1].WireMM2 := 2.5;

  AddN('QDC-01', 'Quadro Geral', 'panel', '', 0, 127, EAV3(0, 800, 1600));
  AddN('LUM-01', 'Luminária Central', 'luminaire', 'C1', 120, 127, EAV3(2500, 2000, 2750));
  AddN('TOM-01', 'Tomada Bancada', 'socket', 'C2', 1200, 127, EAV3(3000, 80, 300));
  AddN('TOM-02', 'Tomada Equipamento', 'socket', 'C2', 1800, 127, EAV3(4920, 2000, 300));

  AddB('ED-01', 'C1', 'QDC-01', 'LUM-01', 1.5, 4.2, EAV3(0, 800, 1600), EAV3(2500, 2000, 2750));
  AddB('ED-02', 'C2', 'QDC-01', 'TOM-01', 2.5, 4.8, EAV3(0, 800, 1600), EAV3(3000, 80, 300));
  AddB('ED-03', 'C2', 'TOM-01', 'TOM-02', 2.5, 3.6, EAV3(3000, 80, 300), EAV3(4920, 2000, 300));
  RunSimulation;
end;

procedure TSIMProject.ImportElectricalModel(const FileName: string);
var
  Pkg: TEAPackageManifest;
  Arr: TJSONArray;
  O, P0, P1: TJSONObject;
  I: Integer;
begin
  EACheckSupportedExternalFile(FileName);
  Pkg := TEAPackageManifest.Create;
  try
    Pkg.LoadFromFile(FileName);
    if Pkg.PackageType <> EA_PKG_MODELO_ELETRICO then
      raise EEAPackageError.Create('Pacote inválido: esperado modelo_eletrico');
    if Pkg.Payload = nil then raise EEAPackageError.Create('Modelo elétrico sem payload');
    Clear;
    ElectricalRefPath := ExpandFileName(FileName);
    ElectricalRefHash := EASHA256File(FileName);

    Arr := Pkg.Payload.Get('circuits', TJSONArray(nil));
    if Arr <> nil then
    begin
      SetLength(Circuits, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        Circuits[I].Id := O.Get('id', '');
        Circuits[I].Name := O.Get('name', '');
        Circuits[I].Phase := O.Get('phase', 'F1');
        Circuits[I].VoltageV := O.Get('voltage_v', 127.0);
        Circuits[I].BreakerA := O.Get('breaker_a', 16.0);
        Circuits[I].WireMM2 := O.Get('wire_mm2', 2.5);
      end;
    end;

    Arr := Pkg.Payload.Get('nodes', TJSONArray(nil));
    if Arr <> nil then
    begin
      SetLength(Nodes, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        Nodes[I].Id := O.Get('id', '');
        Nodes[I].Name := O.Get('name', '');
        Nodes[I].Kind := O.Get('kind', 'socket');
        Nodes[I].CircuitId := O.Get('circuit_id', '');
        Nodes[I].PowerW := O.Get('power_w', 0.0);
        Nodes[I].PowerFactor := O.Get('power_factor', 0.92);
        Nodes[I].VoltageV := O.Get('voltage_v', 127.0);
        P0 := O.Get('pos_mm', TJSONObject(nil));
        if P0 <> nil then Nodes[I].PosMM := EAV3(P0.Get('x', 0.0), P0.Get('y', 0.0), P0.Get('z', 0.0));
      end;
    end;

    Arr := Pkg.Payload.Get('branches', TJSONArray(nil));
    if Arr <> nil then
    begin
      SetLength(Branches, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        Branches[I] := Default(TSIMBranchResult);
        Branches[I].Id := O.Get('id', '');
        Branches[I].CircuitId := O.Get('circuit_id', '');
        Branches[I].FromId := O.Get('from_id', '');
        Branches[I].ToId := O.Get('to_id', '');
        Branches[I].WireMM2 := Max(0.5, O.Get('wire_mm2', 2.5));
        Branches[I].LengthM := Max(0.1, O.Get('length_m', 1.0));
        P0 := O.Get('p0_mm', TJSONObject(nil));
        P1 := O.Get('p1_mm', TJSONObject(nil));
        if P0 <> nil then Branches[I].P0 := EAV3(P0.Get('x', 0.0), P0.Get('y', 0.0), P0.Get('z', 0.0));
        if P1 <> nil then Branches[I].P1 := EAV3(P1.Get('x', 0.0), P1.Get('y', 0.0), P1.Get('z', 0.0));
      end;
    end;
    RunSimulation;
  finally
    Pkg.Free;
  end;
end;

procedure TSIMProject.RunSimulation;
  procedure AddEvt(T: Double; const K, Target, Det: string);
  var N: Integer;
  begin
    N := Length(Events); SetLength(Events, N + 1);
    Events[N].TimeSec := T; Events[N].Kind := K; Events[N].TargetId := Target; Events[N].Detail := Det;
  end;
var
  I, J, CIdx: Integer;
  Volt, Breaker, RhoCu, RLoop, TotalP, Curr, TempRise, RTh, TauSec, TransFactor: Double;
begin
  Warnings.Clear;
  SetLength(Events, 0);
  RhoCu := 0.01724; // Ohm*mm2/m a 20C
  TauSec := 420.0;
  TransFactor := 1.0 - Exp(-Max(1.0, TimeInstSec) / TauSec);

  for I := 0 to High(Branches) do
  begin
    Volt := 127.0; Breaker := 20.0;
    for CIdx := 0 to High(Circuits) do
      if Circuits[CIdx].Id = Branches[I].CircuitId then
      begin
        Volt := Max(12.0, Circuits[CIdx].VoltageV);
        Breaker := Max(1.0, Circuits[CIdx].BreakerA);
        Break;
      end;

    { Soma cargas do circuito a jusante / associadas }
    TotalP := 0.0;
    for J := 0 to High(Nodes) do
      if Nodes[J].CircuitId = Branches[I].CircuitId then
        TotalP := TotalP + Nodes[J].PowerW;
    TotalP := TotalP * LoadFactor;

    Curr := TotalP / (Volt * 0.92);
    { Trecho ida+volta (fator 2) com correcao termica aproximada }
    RLoop := 2.0 * RhoCu * Branches[I].LengthM / Max(0.5, Branches[I].WireMM2);
    RLoop := RLoop * (1.0 + 0.00393 * (AmbientTempC - 20.0));

    Branches[I].CurrentA := Curr;
    Branches[I].DropV := Curr * RLoop;
    Branches[I].DropPct := 100.0 * Branches[I].DropV / Volt;
    Branches[I].LossesW := Curr * Curr * RLoop;
    Branches[I].LossesWPerM := Branches[I].LossesW / Max(0.1, Branches[I].LengthM);

    { Curto-circuito no trecho ou circuito alvo }
    if (ScenarioKind = sskShortCircuit) and
       ((FaultTargetId = '') or (FaultTargetId = Branches[I].Id) or (FaultTargetId = Branches[I].ToId)) then
    begin
      Branches[I].FaultCurrentA := Volt / Max(0.05, RLoop + FaultImpedanceOhm);
      Branches[I].TripTimeSec := Max(0.02, 0.14 * Breaker / Max(1.0, Branches[I].FaultCurrentA - Breaker));
      AddEvt(0.0, 'falta', Branches[I].Id, Format('Curto-circuito fase-neutro: Icc = %.1f A', [Branches[I].FaultCurrentA]));
      AddEvt(Branches[I].TripTimeSec, 'disparo', Branches[I].CircuitId,
        Format('Disjuntor %s (%.0f A) atuou em %.3f s', [Branches[I].CircuitId, Breaker, Branches[I].TripTimeSec]));
    end
    else
    begin
      Branches[I].FaultCurrentA := Volt / Max(0.05, RLoop + 0.5);
      Branches[I].TripTimeSec := 0.0;
    end;

    { Modelo termico IEC 60287 simplificado: T = Tamb + (I^2 R / L) * Rth_termica * fator_transiente }
    RTh := 1.45 / Power(Max(0.5, Branches[I].WireMM2), 0.35);
    TempRise := Branches[I].LossesWPerM * RTh * TransFactor;
    Branches[I].ConductorTempC := AmbientTempC + TempRise;
    Branches[I].TempLimitC := 70.0; // PVC 70 C
    Branches[I].Overlimit := (Branches[I].ConductorTempC > Branches[I].TempLimitC) or (Branches[I].CurrentA > Breaker);

    if Branches[I].Overlimit then
      Warnings.Add(Format('LIMITE EXCEDIDO em %s (%s): I=%.1f A, T=%.1f °C (limite %.0f °C)',
        [Branches[I].Id, Branches[I].CircuitId, Branches[I].CurrentA, Branches[I].ConductorTempC, Branches[I].TempLimitC]));
    if Branches[I].DropPct > 4.0 then
      Warnings.Add(Format('Queda de tensão > 4%% em %s: %.2f%%', [Branches[I].Id, Branches[I].DropPct]));
  end;
end;

procedure TSIMProject.BuildThermalMesh(Target: TEAMesh3D);
var
  I: Integer;
  Col: LongWord;
begin
  Target.Clear;
  for I := 0 to High(Nodes) do
    Target.AddBox(Nodes[I].PosMM, EAV3(160, 120, 160), $64748B, 0, Nodes[I].Id);
  for I := 0 to High(Branches) do
  begin
    Col := SIMTempToRGB(Branches[I].ConductorTempC, AmbientTempC, 75.0);
    Target.AddPipeSegment(Branches[I].P0, Branches[I].P1, 22.0, 8, Col, 0, Branches[I].Id);
  end;
end;

procedure TSIMProject.ExportResultsPackage(const FileName: string);
var
  Pkg: TEAPackageManifest;
  Payload, O: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Pkg := TEAPackageManifest.Create;
  Payload := TJSONObject.Create;
  try
    Pkg.PackageType := EA_PKG_RESULTADO_SIMULACAO;
    Pkg.PackageId := ProjectId + '-res';
    Pkg.CreatedByApp := 'SimuEletrica';
    if ElectricalRefHash <> '' then Pkg.AddSourceRef('modelo_eletrico', '1.0', ElectricalRefHash);
    Payload.Add('scenario_name', ScenarioName);
    Payload.Add('solver_version', SolverVersion);
    Payload.Add('ambient_temp_c', AmbientTempC);
    Payload.Add('note', 'Estimativa de engenharia condicionada às hipóteses do modelo; não substitui ensaio ou laudo técnico.');

    Arr := TJSONArray.Create;
    for I := 0 to High(Branches) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Branches[I].Id);
      O.Add('circuit_id', Branches[I].CircuitId);
      O.Add('current_a', Branches[I].CurrentA);
      O.Add('drop_v', Branches[I].DropV);
      O.Add('drop_pct', Branches[I].DropPct);
      O.Add('losses_w', Branches[I].LossesW);
      O.Add('temp_c', Branches[I].ConductorTempC);
      O.Add('temp_limit_c', Branches[I].TempLimitC);
      O.Add('overlimit', Branches[I].Overlimit);
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

procedure TSIMProject.ExportReportCSV(const FileName: string);
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('Trecho;Circuito;Bitola_mm2;Comprimento_m;Corrente_A;Queda_V;Queda_Pct;Perdas_W;Temp_C;Limite_C;Excedido');
    for I := 0 to High(Branches) do
      SL.Add(Format('%s;%s;%.1f;%.2f;%.2f;%.2f;%.2f;%.2f;%.1f;%.0f;%s', [
        Branches[I].Id, Branches[I].CircuitId, Branches[I].WireMM2, Branches[I].LengthM,
        Branches[I].CurrentA, Branches[I].DropV, Branches[I].DropPct, Branches[I].LossesW,
        Branches[I].ConductorTempC, Branches[I].TempLimitC, BoolToStr(Branches[I].Overlimit, 'SIM', 'NAO')]));
    EAAtomicWriteText(FileName, #$EF#$BB#$BF + SL.Text);
  finally
    SL.Free;
  end;
end;

procedure TSIMProject.ExportReportHTML(const FileName: string);
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>SimuEletrica — Relatório</title>');
    SL.Add('<style>body{font-family:Segoe UI,sans-serif;margin:24px;}table{border-collapse:collapse;width:100%;}th,td{border:1px solid #cbd5e1;padding:6px;text-align:left;}</style></head><body>');
    SL.Add('<h1>SimuEletrica — ' + ScenarioName + '</h1><p>' + SolverVersion + '</p>');
    SL.Add('<table><tr><th>Trecho</th><th>Circuito</th><th>I (A)</th><th>ΔV (%)</th><th>Perdas (W)</th><th>Temp (°C)</th></tr>');
    for I := 0 to High(Branches) do
      SL.Add(Format('<tr><td>%s</td><td>%s</td><td>%.2f</td><td>%.2f%%</td><td>%.2f</td><td>%.1f °C</td></tr>', [
        Branches[I].Id, Branches[I].CircuitId, Branches[I].CurrentA, Branches[I].DropPct,
        Branches[I].LossesW, Branches[I].ConductorTempC]));
    SL.Add('</table></body></html>');
    EAAtomicWriteText(FileName, SL.Text);
  finally
    SL.Free;
  end;
end;

function TSIMProject.SnapshotToJSON: string;
var
  Root, O: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('project_id', ProjectId);
    Root.Add('ref_path', ElectricalRefPath);
    Root.Add('ref_hash', ElectricalRefHash);
    Root.Add('scenario_name', ScenarioName);
    Root.Add('scenario_kind', Ord(ScenarioKind));
    Root.Add('ambient_c', AmbientTempC);
    Root.Add('load_factor', LoadFactor);
    Root.Add('fault_target', FaultTargetId);
    Root.Add('fault_z', FaultImpedanceOhm);
    Root.Add('time_s', TimeInstSec);
    Arr := TJSONArray.Create;
    for I := 0 to High(Circuits) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Circuits[I].Id); O.Add('name', Circuits[I].Name); O.Add('phase', Circuits[I].Phase);
      O.Add('v', Circuits[I].VoltageV); O.Add('brk', Circuits[I].BreakerA); O.Add('wire', Circuits[I].WireMM2);
      Arr.Add(O);
    end;
    Root.Add('circuits', Arr);
    Arr := TJSONArray.Create;
    for I := 0 to High(Nodes) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Nodes[I].Id); O.Add('name', Nodes[I].Name); O.Add('kind', Nodes[I].Kind);
      O.Add('cid', Nodes[I].CircuitId); O.Add('w', Nodes[I].PowerW); O.Add('v', Nodes[I].VoltageV);
      O.Add('x', Nodes[I].PosMM.X); O.Add('y', Nodes[I].PosMM.Y); O.Add('z', Nodes[I].PosMM.Z);
      Arr.Add(O);
    end;
    Root.Add('nodes', Arr);
    Arr := TJSONArray.Create;
    for I := 0 to High(Branches) do
    begin
      O := TJSONObject.Create;
      O.Add('id', Branches[I].Id); O.Add('cid', Branches[I].CircuitId);
      O.Add('from', Branches[I].FromId); O.Add('to', Branches[I].ToId);
      O.Add('wire', Branches[I].WireMM2); O.Add('len_m', Branches[I].LengthM);
      O.Add('x0', Branches[I].P0.X); O.Add('y0', Branches[I].P0.Y); O.Add('z0', Branches[I].P0.Z);
      O.Add('x1', Branches[I].P1.X); O.Add('y1', Branches[I].P1.Y); O.Add('z1', Branches[I].P1.Z);
      Arr.Add(O);
    end;
    Root.Add('branches', Arr);
    Result := Root.FormatJSON;
  finally
    Root.Free;
  end;
end;

procedure TSIMProject.RestoreFromSnapshotJSON(const JsonText: string);
var
  Data: TJSONData;
  Root, O: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Data := GetJSON(JsonText);
  try
    if not (Data is TJSONObject) then Exit;
    Root := TJSONObject(Data);
    Clear;
    ProjectId := Root.Get('project_id', 'sim-001');
    ElectricalRefPath := Root.Get('ref_path', '');
    ElectricalRefHash := Root.Get('ref_hash', '');
    ScenarioName := Root.Get('scenario_name', 'Operação Normal');
    ScenarioKind := TSIMScenarioKind(EnsureRange(Root.Get('scenario_kind', 0), 0, 3));
    AmbientTempC := Root.Get('ambient_c', 30.0);
    LoadFactor := Root.Get('load_factor', 1.0);
    FaultTargetId := Root.Get('fault_target', '');
    FaultImpedanceOhm := Root.Get('fault_z', 0.25);
    TimeInstSec := Root.Get('time_s', 1800.0);
    Arr := Root.Get('circuits', TJSONArray(nil));
    if Arr <> nil then
    begin
      SetLength(Circuits, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        Circuits[I].Id := O.Get('id', ''); Circuits[I].Name := O.Get('name', '');
        Circuits[I].Phase := O.Get('phase', 'F1'); Circuits[I].VoltageV := O.Get('v', 127.0);
        Circuits[I].BreakerA := O.Get('brk', 16.0); Circuits[I].WireMM2 := O.Get('wire', 2.5);
      end;
    end;
    Arr := Root.Get('nodes', TJSONArray(nil));
    if Arr <> nil then
    begin
      SetLength(Nodes, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        Nodes[I].Id := O.Get('id', ''); Nodes[I].Name := O.Get('name', '');
        Nodes[I].Kind := O.Get('kind', 'socket'); Nodes[I].CircuitId := O.Get('cid', '');
        Nodes[I].PowerW := O.Get('w', 0.0); Nodes[I].PowerFactor := 0.92;
        Nodes[I].VoltageV := O.Get('v', 127.0);
        Nodes[I].PosMM := EAV3(O.Get('x', 0.0), O.Get('y', 0.0), O.Get('z', 0.0));
      end;
    end;
    Arr := Root.Get('branches', TJSONArray(nil));
    if Arr <> nil then
    begin
      SetLength(Branches, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        Branches[I].Id := O.Get('id', ''); Branches[I].CircuitId := O.Get('cid', '');
        Branches[I].FromId := O.Get('from', ''); Branches[I].ToId := O.Get('to', '');
        Branches[I].WireMM2 := O.Get('wire', 2.5); Branches[I].LengthM := O.Get('len_m', 1.0);
        Branches[I].P0 := EAV3(O.Get('x0', 0.0), O.Get('y0', 0.0), O.Get('z0', 0.0));
        Branches[I].P1 := EAV3(O.Get('x1', 0.0), O.Get('y1', 0.0), O.Get('z1', 0.0));
      end;
    end;
    RunSimulation;
  finally
    Data.Free;
  end;
end;

procedure TSIMProject.BeginUndoStep(const Desc: string);
begin
  UndoHistory.RecordBefore(Desc);
end;

function TSIMProject.Undo: Boolean;
begin
  Result := UndoHistory.Undo;
end;

function TSIMProject.Redo: Boolean;
begin
  Result := UndoHistory.Redo;
end;

end.
