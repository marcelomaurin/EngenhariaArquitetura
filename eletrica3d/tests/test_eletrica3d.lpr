program test_eletrica3d;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  Classes, SysUtils,
  ea_geometria, ea_pacote, ea_modelo, ea_ancoras,
  maq_projeto, ele_projeto;

var
  Maq: TMAQProject;
  Ele, Ele2: TELEProject;
  TmpMaq, TmpEle, TmpLayer, TmpLuz, TmpSim, TmpCoord, TmpCSV: string;
  G: TGUID;
  Checks: Integer = 0;

procedure Check(OK: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not OK then raise Exception.Create('FALHA: ' + Msg);
end;

begin
  CreateGUID(G);
  TmpMaq := GetTempDir(False) + 'ea-ele-maq-' + GUIDToString(G) + '.maquete.pkg.json';
  TmpEle := GetTempDir(False) + 'ea-ele-' + GUIDToString(G) + '.ele.json';
  TmpLayer := GetTempDir(False) + 'ea-ele-layer-' + GUIDToString(G) + '.json';
  TmpLuz := GetTempDir(False) + 'ea-ele-luz-' + GUIDToString(G) + '.json';
  TmpSim := GetTempDir(False) + 'ea-ele-sim-' + GUIDToString(G) + '.json';
  TmpCoord := GetTempDir(False) + 'ea-ele-coord-' + GUIDToString(G) + '.json';
  TmpCSV := GetTempDir(False) + 'ea-ele-' + GUIDToString(G) + '.csv';

  Maq := TMAQProject.Create;
  Ele := TELEProject.Create;
  Ele2 := TELEProject.Create;
  try
    Maq.LoadDemoTwoFloors;
    Maq.ExportMaquetePackage(TmpMaq);

    Ele.LoadDemoProject;
    Ele.ImportMaquetePackage(TmpMaq, True);
    Check(Length(Ele.ArchModel.Floors) = 2, 'maquete com 2 pavimentos importada somente leitura');
    Check(Length(Ele.Circuits) = 2, '2 circuitos definidos');
    Check(Length(Ele.Conduits) = 4, '4 eletrodutos definidos');

    Ele.ExportElectricalLayer(TmpLayer);
    Ele.ExportLightingState(TmpLuz);
    Ele.ExportSimulationModel(TmpSim);
    Ele.ExportCoordinationRequests(TmpCoord);
    Ele.ExportQuantitiesCSV(TmpCSV);
    Check(FileExists(TmpLayer) and FileExists(TmpLuz) and FileExists(TmpSim) and FileExists(TmpCoord) and FileExists(TmpCSV),
      'todos os contratos I-13..I-16 e CSV exportados');

    { Maquete 3D carrega camada eletrica exportada sem erro }
    Maq.ImportDisciplineOverlay(TmpLayer);
    Check(Length(Maq.ExternalSegments) = 4, 'Maquete 3D exibe camada eletrica sobreposta');

    Ele.SaveElectricalFile(TmpEle);
    Ele2.LoadElectricalFile(TmpEle);
    Check((Length(Ele2.Circuits) = 2) and (Length(Ele2.Points) = 5), 'roundtrip projeto eletrico');

    WriteLn(Checks, ' verificacoes do Eletrica 3D, 0 falhas');
  finally
    Ele2.Free;
    Ele.Free;
    Maq.Free;
    if FileExists(TmpMaq) then DeleteFile(TmpMaq);
    if FileExists(ChangeFileExt(TmpMaq, '.glb')) then DeleteFile(ChangeFileExt(TmpMaq, '.glb'));
    if FileExists(TmpEle) then DeleteFile(TmpEle);
    if FileExists(TmpLayer) then DeleteFile(TmpLayer);
    if FileExists(TmpLuz) then DeleteFile(TmpLuz);
    if FileExists(TmpSim) then DeleteFile(TmpSim);
    if FileExists(TmpCoord) then DeleteFile(TmpCoord);
    if FileExists(TmpCSV) then DeleteFile(TmpCSV);
  end;
end.
