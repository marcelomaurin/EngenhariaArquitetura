program test_cad2d_import;

{$mode objfpc}{$H+}

{ Testes do Motor de Importação do CAD 2D (DWG, DXF, IFC)
  Conforme requisitos RFI-001, RFI-005, RFI-006, RFI-007, RFI-009, RF2D-011, RF2D-017.
  Uso: test_cad2d_import (código de saída 0 = todos os testes passaram) }

uses
  Classes, SysUtils, cad2d_importador;

var
  Falhas, Total: Integer;

procedure Confere(Cond: Boolean; const Msg: string);
begin
  Inc(Total);
  if Cond then
    WriteLn('  ok    ', Msg)
  else
  begin
    Inc(Falhas);
    WriteLn('  FALHA ', Msg);
  end;
end;

procedure TesteDeteccaoDWG;
var
  TestPath, Ver: string;
  Fmt: TFileFormat;
  FS: TFileStream;
  Magic: array[0..5] of Char;
begin
  WriteLn('[1/4] Testando deteccao de formatos DWG por magic bytes (RFI-001)...');

  // Simula arquivo DWG versão AutoCAD 2018 (AC1032)
  TestPath := GetTempFileName('', 'test_dwg_') + '.dwg';
  FS := TFileStream.Create(TestPath, fmCreate);
  try
    Magic := 'AC1032';
    FS.Write(Magic[0], 6);
  finally
    FS.Free;
  end;

  Fmt := DetectFormat(TestPath, Ver);
  Confere(Fmt = fmtDWG, 'Formato identificado como DWG');
  Confere(Pos('AC1032', Ver) > 0, 'Versao detectada corretamente como AC1032: ' + Ver);
  DeleteFile(TestPath);

  // Simula arquivo DWG versão AutoCAD 2004 (AC1018)
  TestPath := GetTempFileName('', 'test_dwg_') + '.dwg';
  FS := TFileStream.Create(TestPath, fmCreate);
  try
    Magic := 'AC1018';
    FS.Write(Magic[0], 6);
  finally
    FS.Free;
  end;

  Fmt := DetectFormat(TestPath, Ver);
  Confere(Fmt = fmtDWG, 'Formato identificado como DWG');
  Confere(Pos('AC1018', Ver) > 0, 'Versao detectada corretamente como AC1018: ' + Ver);
  DeleteFile(TestPath);
end;

procedure TesteImportacaoDXF;
var
  TestPath, Ver: string;
  Fmt: TFileFormat;
  Lines: TStringList;
  Buffer: array[0..255] of TImportedEntity;
  Count: Integer;
  Report: TImportReport;
  Ok: Boolean;
begin
  WriteLn('[2/4] Testando importacao e classificacao DXF (RFI-005, RFI-006, RF2D-011)...');

  TestPath := GetTempFileName('', 'test_') + '.dxf';
  Lines := TStringList.Create;
  try
    // Monta DXF mínimo com seções e entidades de parede e porta
    Lines.Add('0'); Lines.Add('SECTION');
    Lines.Add('2'); Lines.Add('ENTITIES');
    // Linha de parede
    Lines.Add('0'); Lines.Add('LINE');
    Lines.Add('8'); Lines.Add('ARQ_PAREDES');
    Lines.Add('10'); Lines.Add('0.0');
    Lines.Add('20'); Lines.Add('0.0');
    Lines.Add('11'); Lines.Add('5000.0');
    Lines.Add('21'); Lines.Add('0.0');
    // Linha de porta
    Lines.Add('0'); Lines.Add('LINE');
    Lines.Add('8'); Lines.Add('ARQ_PORTAS');
    Lines.Add('10'); Lines.Add('1000.0');
    Lines.Add('20'); Lines.Add('0.0');
    Lines.Add('11'); Lines.Add('1900.0');
    Lines.Add('21'); Lines.Add('0.0');
    // Fim da seção
    Lines.Add('0'); Lines.Add('ENDSEC');
    Lines.Add('0'); Lines.Add('EOF');
    Lines.SaveToFile(TestPath);

    Fmt := DetectFormat(TestPath, Ver);
    Confere(Fmt = fmtDXF, 'Formato identificado como DXF');

    InitReport(Report, TestPath);
    try
      Ok := ImportDXF(TestPath, Buffer, Count, Report, 50);
      Confere(Ok, 'Importacao DXF executada com sucesso');
      Confere(Count = 2, Format('Numero de entidades importadas (obtido %d, esperado 2)', [Count]));
      Confere(Report.WallCount = 1, 'Parede identificada na camada ARQ_PAREDES');
      Confere(Report.DoorCount = 1, 'Porta identificada na camada ARQ_PORTAS');
      Confere(Report.SourceHash <> '', 'Hash SHA-1 gerado para rastreabilidade (RFI-009)');
    finally
      FreeReport(Report);
    end;
  finally
    Lines.Free;
    DeleteFile(TestPath);
  end;
end;

procedure TesteImportacaoIFC;
var
  TestPath, Ver: string;
  Fmt: TFileFormat;
  Lines: TStringList;
  Floors: TStringList;
  Buffer: array[0..255] of TImportedEntity;
  Count: Integer;
  Report: TImportReport;
  Ok: Boolean;
begin
  WriteLn('[3/4] Testando analise e extracao 2D de modelo BIM IFC (RF2D-017)...');

  TestPath := GetTempFileName('', 'test_') + '.ifc';
  Lines := TStringList.Create;
  Floors := TStringList.Create;
  try
    // Monta arquivo IFC STEP sintético conforme ISO-10303-21
    Lines.Add('ISO-10303-21;');
    Lines.Add('HEADER;');
    Lines.Add('FILE_DESCRIPTION((''Exemplo IFC para CAD 2D''),''2;1'');');
    Lines.Add('FILE_SCHEMA((''IFC4''));');
    Lines.Add('ENDSEC;');
    Lines.Add('DATA;');
    Lines.Add('#1=IFCPROJECT(''1XG8$m$r15awpmmyurt$,'',#2,''Projeto Residencial'',$,$,$,$,(#20),#7);');
    Lines.Add('#10=IFCBUILDING(''2N7f$m$r15awpmmyurt$,'',#2,''Edificio'',$,$,#11,$,$,.ELEMENT.,$,$,$);');
    Lines.Add('#20=IFCBUILDINGSTOREY(''3A7f$m$r15awpmmyurt$,'',#2,''Térreo'',$,$,#21,$,$,.ELEMENT.,0.0);');
    Lines.Add('#21=IFCBUILDINGSTOREY(''4B7f$m$r15awpmmyurt$,'',#2,''Superior'',$,$,#22,$,$,.ELEMENT.,3000.0);');
    Lines.Add('#30=IFCWALLSTANDARDCASE(''5C7f$m$r15awpmmyurt$,'',#2,''Parede Fachada'',$,$,#31,#32,$);');
    Lines.Add('#40=IFCDOOR(''6D7f$m$r15awpmmyurt$,'',#2,''Porta Entrada'',$,$,#41,#42,$,900.0,2100.0);');
    Lines.Add('#50=IFCWINDOW(''7E7f$m$r15awpmmyurt$,'',#2,''Janela Sala'',$,$,#51,#52,$,1200.0,1200.0);');
    Lines.Add('ENDSEC;');
    Lines.Add('END-ISO-10303-21;');
    Lines.SaveToFile(TestPath);

    Fmt := DetectFormat(TestPath, Ver);
    Confere(Fmt = fmtIFC, 'Formato identificado como IFC');
    Confere(Pos('IFC4', Ver) > 0, 'Schema detectado como IFC4: ' + Ver);

    GetIFCFloors(TestPath, Floors);
    Confere(Floors.Count = 2, Format('Detectou %d pavimentos (esperado 2)', [Floors.Count]));
    if Floors.Count >= 2 then
    begin
      Confere(Floors[0] = 'Térreo', 'Primeiro pavimento identificado: ' + Floors[0]);
      Confere(Floors[1] = 'Superior', 'Segundo pavimento identificado: ' + Floors[1]);
    end;

    InitReport(Report, TestPath);
    try
      Ok := ImportIFC(TestPath, 'Térreo', Buffer, Count, Report, 50);
      Confere(Ok, 'Extracao 2D do IFC realizada com sucesso');
      Confere(Report.WallCount >= 1, 'Parede extraida do modelo BIM IFC');
      Confere(Report.DoorCount >= 1, 'Porta extraida do modelo BIM IFC');
      Confere(Report.WindowCount >= 1, 'Janela extraida do modelo BIM IFC');
    finally
      FreeReport(Report);
    end;

  finally
    Floors.Free;
    Lines.Free;
    DeleteFile(TestPath);
  end;
end;

procedure TesteRelatorioESeguranca;
var
  R: TImportReport;
  Summary: string;
begin
  WriteLn('[4/4] Testando relatorio de integridade e perdas (RFI-007, RFI-009)...');

  InitReport(R, 'planta_exemplo.dwg');
  try
    R.Format := fmtDWG;
    R.FormatName := 'AutoCAD DWG';
    R.VersionDetected := 'AutoCAD 2018 (AC1032)';
    R.SourceHash := 'e5b7a123f890';
    R.ImportedCount := 45;
    R.WallCount := 20;
    R.DoorCount := 5;
    R.WindowCount := 8;
    R.IgnoredCount := 12;
    R.Warnings.Add('12 blocos de anotações não compatíveis foram ignorados.');

    Summary := FormatReportSummary(R);
    Confere(Pos('AutoCAD 2018', Summary) > 0, 'Relatorio contem versao identificada');
    Confere(Pos('Paredes: 20', Summary) > 0, 'Relatorio contabiliza paredes');
    Confere(Pos('Entidades ignoradas', Summary) > 0, 'Relatorio aponta entidades ignoradas (RFI-007)');
  finally
    FreeReport(R);
  end;
end;

begin
  Total := 0;
  Falhas := 0;
  WriteLn('=== Testes do Motor de Importacao CAD 2D (DWG / DXF / IFC) ===');
  TesteDeteccaoDWG;
  TesteImportacaoDXF;
  TesteImportacaoIFC;
  TesteRelatorioESeguranca;
  WriteLn(Format('Total de verificacoes: %d | Falhas: %d', [Total, Falhas]));
  if Falhas > 0 then Halt(1);
end.
