program test_simueletrica;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  Classes, SysUtils,
  ele_projeto, sim_eletrica;

var
  Ele: TELEProject;
  Sim: TSIMProject;
  TmpModel, TmpRes, TmpCSV, TmpHTML: string;
  G: TGUID;
  Checks: Integer = 0;

procedure Check(OK: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not OK then raise Exception.Create('FALHA: ' + Msg);
end;

begin
  CreateGUID(G);
  TmpModel := GetTempDir(False) + 'ea-sim-m-' + GUIDToString(G) + '.json';
  TmpRes := GetTempDir(False) + 'ea-sim-r-' + GUIDToString(G) + '.json';
  TmpCSV := GetTempDir(False) + 'ea-sim-' + GUIDToString(G) + '.csv';
  TmpHTML := GetTempDir(False) + 'ea-sim-' + GUIDToString(G) + '.html';

  Ele := TELEProject.Create;
  Sim := TSIMProject.Create;
  try
    Ele.LoadDemoProject;
    Ele.ExportSimulationModel(TmpModel);

    Sim.ImportElectricalModel(TmpModel);
    Check(Length(Sim.Branches) = 4, '4 trechos importados de modelo_eletrico');
    Check(Sim.Branches[2].CurrentA > 0.0, 'corrente em regime permanente calculada');
    Check(Sim.Branches[2].ConductorTempC > Sim.AmbientTempC, 'aquecimento Joule calculado');

    { Injetar curto-circuito e verificar disparo e eventos }
    Sim.BeginUndoStep('Curto-circuito ED-03');
    Sim.ScenarioKind := sskShortCircuit;
    Sim.FaultTargetId := 'ED-03';
    Sim.RunSimulation;
    Check(Sim.Branches[2].FaultCurrentA > 50.0, 'corrente de curto-circuito calculada');
    Check(Length(Sim.Events) >= 2, 'eventos temporais de falta e disparo registrados');
    Check(Sim.Undo and (Sim.ScenarioKind = sskNormal), 'SimuEletrica desfaz cenario via TAIUndoHistory');
    Check(Sim.Redo and (Sim.ScenarioKind = sskShortCircuit), 'SimuEletrica refaz cenario via TAIUndoHistory');

    Sim.ExportResultsPackage(TmpRes);
    Sim.ExportReportCSV(TmpCSV);
    Sim.ExportReportHTML(TmpHTML);
    Check(FileExists(TmpRes) and FileExists(TmpCSV) and FileExists(TmpHTML), 'resultados I-17 e relatorios exportados');

    { Eletrica 3D reimporta resultado sem alterar projeto eletrico }
    Ele.ImportSimulationResults(TmpRes);
    Check(Length(Ele.SimOverlays) = 4, 'Eletrica 3D exibe camada de resultados I-17');

    WriteLn(Checks, ' verificacoes do SimuEletrica, 0 falhas');
  finally
    Sim.Free;
    Ele.Free;
    if FileExists(TmpModel) then DeleteFile(TmpModel);
    if FileExists(TmpRes) then DeleteFile(TmpRes);
    if FileExists(TmpCSV) then DeleteFile(TmpCSV);
    if FileExists(TmpHTML) then DeleteFile(TmpHTML);
  end;
end.
