program test_cad_interop;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  Classes, SysUtils, Types, ea_modelo, ea_pacote, cad_document, cad_interop;

var
  Lines: TCADLines;
  Labels: TCADLabels;
  RoomsFound: Integer;
  Model: TEAModel;
  TmpPkg, TmpPDF: string;
  G: TGUID;
  SL: TStringList;
  Checks: Integer = 0;

procedure Check(OK: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not OK then raise Exception.Create('FALHA: ' + Msg);
end;

begin
  CreateGUID(G);
  TmpPkg := GetTempDir(False) + 'ea-cad-pkg-' + GUIDToString(G) + '.ea2d.json';
  TmpPDF := GetTempDir(False) + 'ea-cad-pdf-' + GUIDToString(G) + '.pdf';
  try
    SetLength(Lines, 6);
    { Sala 4000 x 3000 mm }
    Lines[0].A := Point(0, 0); Lines[0].B := Point(4000, 0); Lines[0].Kind := 2; Lines[0].WidthMM := 150; Lines[0].HeightMM := 2800; Lines[0].GroupID := 1;
    Lines[1].A := Point(4000, 0); Lines[1].B := Point(4000, 3000); Lines[1].Kind := 2; Lines[1].WidthMM := 150; Lines[1].HeightMM := 2800; Lines[1].GroupID := 2;
    Lines[2].A := Point(4000, 3000); Lines[2].B := Point(0, 3000); Lines[2].Kind := 2; Lines[2].WidthMM := 150; Lines[2].HeightMM := 2800; Lines[2].GroupID := 3;
    Lines[3].A := Point(0, 3000); Lines[3].B := Point(0, 0); Lines[3].Kind := 2; Lines[3].WidthMM := 150; Lines[3].HeightMM := 2800; Lines[3].GroupID := 4;
    { Porta na parede 0 e janela na parede 1 }
    Lines[4].A := Point(1000, 0); Lines[4].B := Point(1900, 0); Lines[4].Kind := 3; Lines[4].WidthMM := 900; Lines[4].HeightMM := 2100; Lines[4].GroupID := 5;
    Lines[5].A := Point(4000, 900); Lines[5].B := Point(4000, 2100); Lines[5].Kind := 4; Lines[5].WidthMM := 1200; Lines[5].HeightMM := 1200; Lines[5].SillMM := 900; Lines[5].GroupID := 6;

    SetLength(Labels, 0);
    RoomsFound := CADDetectRoomsAndLabels(Lines, Labels);
    Check(RoomsFound = 1, 'detecta 1 ambiente fechado');
    Check(Pos('12.00 m2', StringReplace(Labels[0].Text, ',', '.', [rfReplaceAll])) > 0, 'rotulo com area 12.00 m2');

    CADExportModelPackage(Lines, Labels, TmpPkg, 'Sala Teste');
    Check(FileExists(TmpPkg), 'pacote ea2d.json gravado');
    Model := TEAModel.Create;
    try
      Model.LoadFromPackageFile(TmpPkg);
      Check(Length(Model.Walls) = 4, '4 paredes exportadas');
      Check(Length(Model.Openings) = 2, 'porta e janela vinculadas as paredes');
      Check(Length(Model.Rooms) = 1, '1 ambiente exportado');
    finally
      Model.Free;
    end;

    CADExportScaledPDF(Lines, Labels, TmpPDF, 'Sala 4x3m', 50);
    Check(FileExists(TmpPDF), 'PDF em escala gravado');
    SL := TStringList.Create;
    try
      SL.LoadFromFile(TmpPDF);
      Check(Pos('%PDF-1.4', SL.Text) = 1, 'cabecalho PDF 1.4 valido');
      Check(Pos('Escala 1:50', SL.Text) > 0, 'escala 1:50 registrada no carimbo');
      Check(Pos('%%EOF', SL.Text) > 0, 'marcador EOF do PDF');
    finally
      SL.Free;
    end;

    WriteLn(Checks, ' verificacoes de interoperabilidade CAD 2D, 0 falhas');
  except
    on E: Exception do
    begin
      WriteLn(E.Message);
      Halt(1);
    end;
  end;
  if FileExists(TmpPkg) then DeleteFile(TmpPkg);
  if FileExists(TmpPDF) then DeleteFile(TmpPDF);
end.
