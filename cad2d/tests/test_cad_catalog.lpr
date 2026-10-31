program test_cad_catalog;
{$mode objfpc}{$H+}{$codepage utf8}
uses Classes, SysUtils, Types, Math, fpjson, cad_catalog, cad_document, cad_health_examples;
var C: TCADCatalog; D,Q: TCADDocument; Lines: TCADLines; I,J,Checks: Integer;
  FileName: string; G: TGUID; HasMaca,HasVacina,HasLab: Boolean; R: TRect;
procedure Check(OK: Boolean; const Msg: string);
begin Inc(Checks); if not OK then raise Exception.Create(Msg); end;
begin
  DefaultSystemCodePage:=CP_UTF8; SetMultiByteConversionCodePage(CP_UTF8);
  C:=TCADCatalog.Create(CADCatalogFile); Q:=TCADDocument.Create;
  CreateGUID(G); FileName:=IncludeTrailingPathDelimiter(GetTempDir)+'saude-catalog-'+GUIDToString(G)+'.eacad';
  try
    Check(C.Items.Count=48,'48 itens de biblioteca');
    for I:=0 to C.Items.Count-1 do begin
      Lines:=C.BuildLines(C.Items.Objects[I].Get('id',''),Point(100,200),C.Items.Objects[I].Get('width_mm',0),C.Items.Objects[I].Get('depth_mm',0),I+1);
      Check(Length(Lines)>0,'geometria do item '+IntToStr(I));
      for J:=0 to High(Lines) do if (Lines[J].CatalogID<>C.Items.Objects[I].Get('id','')) or (Lines[J].GroupID<>I+1) then raise Exception.Create('Identidade de bloco perdida');
    end;
    Check(C.Item('geral_mesa').Get('category','')='Uso geral','uso geral preservado');
    Check(C.Item('lab_microscopio').Get('dimension_status','')='initial_editable_envelope','dimensao inicial identificada');
    Lines:=C.BuildLines('consult_maca',Point(100,200),700,1900,9);
    R:=Rect(MaxInt,MaxInt,-MaxInt,-MaxInt);
    for I:=0 to High(Lines) do begin R.Left:=Min(R.Left,Min(Lines[I].A.X,Lines[I].B.X)); R.Top:=Min(R.Top,Min(Lines[I].A.Y,Lines[I].B.Y)); R.Right:=Max(R.Right,Max(Lines[I].A.X,Lines[I].B.X)); R.Bottom:=Max(R.Bottom,Max(Lines[I].A.Y,Lines[I].B.Y)); end;
    Check((R.Right-R.Left=700) and (R.Bottom-R.Top=1900),'envelope em milimetros');
    D:=CADHealthcareExample(C,False);
    try
      Check(Length(D.Labels)>=7,'ambientes da UBS identificados'); HasMaca:=False; HasVacina:=False; HasLab:=False;
      for I:=0 to High(D.Lines) do begin HasMaca:=HasMaca or (D.Lines[I].CatalogID='consult_maca'); HasVacina:=HasVacina or (D.Lines[I].CatalogID='vacina_camara'); HasLab:=HasLab or (D.Lines[I].CatalogID='lab_microscopio'); end;
      Check(HasMaca and HasVacina and HasLab,'UBS com consultorio vacina e coleta');
      D.Save(FileName); Q.Load(FileName);
      Check(Length(Q.Lines)=Length(D.Lines),'blocos preservados ao reabrir');
      Check(Length(Q.Labels)=Length(D.Labels),'anotacoes preservadas');
      Check(Q.Labels[0].Text=D.Labels[0].Text,'texto das anotacoes preservado');
      HasMaca:=False; for I:=0 to High(Q.Lines) do HasMaca:=HasMaca or (Q.Lines[I].CatalogID='consult_maca');
      Check(HasMaca,'ID do catalogo persistido');
    finally D.Free; end;
    D:=CADHealthcareExample(C,True);
    try HasMaca:=False; for I:=0 to High(D.Lines) do HasMaca:=HasMaca or (D.Lines[I].CatalogID='internacao_cama'); Check(HasMaca,'ala hospitalar com camas'); finally D.Free; end;
    WriteLn(Checks,' verificacoes de biblioteca e exemplos de saude, 0 falhas');
  except on E: Exception do begin WriteLn('FALHA: ',E.Message); Halt(1); end; end;
  Q.Free; C.Free; DeleteFile(FileName);
end.
