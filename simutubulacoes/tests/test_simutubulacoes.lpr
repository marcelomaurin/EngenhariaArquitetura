program test_simutubulacoes;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  Classes, SysUtils,
  ea_geometria, ea_pacote,
  maq_projeto, ele_projeto, tub_projeto;

var
  Maq: TMAQProject;
  Ele: TELEProject;
  Tub, Tub2: TTUBProject;
  TmpMaq, TmpEleLayer, TmpTubProj, TmpNet, TmpRes, TmpCSV, TmpHTML: string;
  G: TGUID;
  MixedBlocked: Boolean;
  Clashes: Integer;
  Checks: Integer = 0;

procedure Check(OK: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not OK then raise Exception.Create('FALHA: ' + Msg);
end;

begin
  CreateGUID(G);
  TmpMaq := GetTempDir(False) + 'ea-tub-m-' + GUIDToString(G) + '.maquete.pkg.json';
  TmpEleLayer := GetTempDir(False) + 'ea-tub-el-' + GUIDToString(G) + '.json';
  TmpTubProj := GetTempDir(False) + 'ea-tub-' + GUIDToString(G) + '.stubproj.json';
  TmpNet := GetTempDir(False) + 'ea-tub-net-' + GUIDToString(G) + '.json';
  TmpRes := GetTempDir(False) + 'ea-tub-res-' + GUIDToString(G) + '.json';
  TmpCSV := GetTempDir(False) + 'ea-tub-' + GUIDToString(G) + '.csv';
  TmpHTML := GetTempDir(False) + 'ea-tub-' + GUIDToString(G) + '.html';

  Maq := TMAQProject.Create;
  Ele := TELEProject.Create;
  Tub := TTUBProject.Create;
  Tub2 := TTUBProject.Create;
  try
    Maq.LoadDemoTwoFloors;
    Maq.ExportMaquetePackage(TmpMaq);
    Ele.LoadDemoProject;
    Ele.ExportElectricalLayer(TmpEleLayer);

    Tub.LoadDemoNetworks;
    Tub.ImportMaquetePackage(TmpMaq);
    Check(Length(Tub.Segments) = 7, '7 trechos de redes independentes carregados');
    Check(Tub.Nodes[Tub.FindNode('AF-TOR')].CalcPressureKPaG > 10.0, 'agua fria com pressao positiva');
    Check(Tub.Segments[2].CalcTempOutC < 60.0, 'agua quente calcula perda termica');
    Check(Tub.Nodes[Tub.FindNode('GAS-FOG')].CalcPressureKPaAbs > Tub.AtmPressureKPa, 'gas compressivel com pressao abs/manometrica');
    Check(Tub.Segments[6].CalcVelocityMS > 0.3, 'esgoto por gravidade Manning calculado');

    { Recusar mistura de fluidos diferentes (ST-003) }
    MixedBlocked := False;
    try
      Tub.AddSegment('BAD-1', tfdGas, 'AF-JOE', 'GAS-FOG', 20, 'Cobre');
    except
      on E: EEAPackageError do MixedBlocked := True;
    end;
    Check(MixedBlocked, 'proibe ligar agua e gas no mesmo grafo');

    { Detectar contrapendencia no esgoto }
    Tub.AddNode('ESG-B1', 'Ralo Baixo', tfdEsgoto, tnkConsumo, EAV3(1000, 500, 400), 0.2, 0, 25);
    Tub.AddNode('ESG-B2', 'Caixa Alta', tfdEsgoto, tnkDescarga, EAV3(2000, 500, 550), 0, 0, 25);
    Tub.AddSegment('ESG-BAD', tfdEsgoto, 'ESG-B1', 'ESG-B2', 50, 'PVC');
    Tub.RunAllDomainSolvers;
    Check(Pos('REFLUXO', Tub.Alerts.Text) > 0, 'detecta contrapendencia/refluxo no esgoto');

    { Coordenacao I-20 com Eletrica 3D (cruzamento forcado) }
    Tub.AddNode('CRUZ-1', 'Nó Cruz 1', tfdAguaFria, tnkConexao, EAV3(0, 800, 1600), 0, 0, 22);
    Tub.AddNode('CRUZ-2', 'Nó Cruz 2', tfdAguaFria, tnkConsumo, EAV3(2500, 2000, 2750), 0.1, 0, 22);
    Tub.AddSegment('AF-CRUZ', tfdAguaFria, 'CRUZ-1', 'CRUZ-2', 32, 'PVC');
    Clashes := Tub.CheckClashes(TmpEleLayer);
    Check(Clashes > 0, 'detecta interferencia I-20 com eletroduto');

    Tub.ExportPipeNetworkPackage(TmpNet);
    Tub.ExportFluidResultsPackage(TmpRes);
    Tub.ExportReportCSV(TmpCSV);
    Tub.ExportReportHTML(TmpHTML);
    Check(FileExists(TmpNet) and FileExists(TmpRes) and FileExists(TmpCSV) and FileExists(TmpHTML),
      'pacotes I-19/I-22 e relatorios exportados');

    Tub.SaveTubProject(TmpTubProj);
    Tub2.LoadTubProject(TmpTubProj);
    Check(Length(Tub2.Segments) = Length(Tub.Segments), 'roundtrip projeto SimuTubulacoes');
    Tub2.BeginUndoStep('No extra');
    Tub2.AddNode('AF-EX', 'Ponto Extra', tfdAguaFria, tnkConsumo, EAV3(1500, 500, 800), 0.1, 0, 22);
    Check(Tub2.Undo and (Tub2.FindNode('AF-EX') < 0), 'SimuTubulacoes desfaz via TAIUndoHistory');
    Check(Tub2.Redo and (Tub2.FindNode('AF-EX') >= 0), 'SimuTubulacoes refaz via TAIUndoHistory');

    WriteLn(Checks, ' verificacoes do SimuTubulacoes, 0 falhas');
  finally
    Tub2.Free;
    Tub.Free;
    Ele.Free;
    Maq.Free;
    if FileExists(TmpMaq) then DeleteFile(TmpMaq);
    if FileExists(ChangeFileExt(TmpMaq, '.glb')) then DeleteFile(ChangeFileExt(TmpMaq, '.glb'));
    if FileExists(TmpEleLayer) then DeleteFile(TmpEleLayer);
    if FileExists(TmpTubProj) then DeleteFile(TmpTubProj);
    if FileExists(TmpNet) then DeleteFile(TmpNet);
    if FileExists(TmpRes) then DeleteFile(TmpRes);
    if FileExists(TmpCSV) then DeleteFile(TmpCSV);
    if FileExists(TmpHTML) then DeleteFile(TmpHTML);
  end;
end.
