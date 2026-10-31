unit cad_health_examples;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Types, cad_document, cad_catalog;
function CADHealthcareExample(Catalog: TCADCatalog; Hospital: Boolean): TCADDocument;
implementation
function CADHealthcareExample(Catalog: TCADCatalog; Hospital: Boolean): TCADDocument;
var D: TCADDocument; Group: Integer; I,X,Step: Integer;
  procedure Segment(X1,Y1,X2,Y2,Kind: Integer);
  var N: Integer;
  begin
    N:=Length(D.Lines); SetLength(D.Lines,N+1);
    D.Lines[N].A:=Point(X1,Y1); D.Lines[N].B:=Point(X2,Y2);
    D.Lines[N].Kind:=Kind; D.Lines[N].Layer:=0; D.Lines[N].GroupID:=Group; Inc(Group);
    if Kind=2 then begin D.Lines[N].WidthMM:=150; D.Lines[N].HeightMM:=2800; end;
    if Kind=3 then begin D.Lines[N].Layer:=1; D.Lines[N].WidthMM:=1000; D.Lines[N].HeightMM:=2100; end;
    if Kind=4 then begin D.Lines[N].Layer:=1; D.Lines[N].WidthMM:=150; D.Lines[N].HeightMM:=1200; D.Lines[N].SillMM:=900; end;
  end;
  procedure LabelAt(const Text: string; AX,AY: Integer);
  var N: Integer;
  begin N:=Length(D.Labels); SetLength(D.Labels,N+1); D.Labels[N].Text:=Text; D.Labels[N].X:=AX; D.Labels[N].Y:=AY; end;
  procedure Place(const ID: string; AX,AY: Integer);
  var Lines: TCADLines; N,J: Integer;
  begin
    Lines:=Catalog.BuildLines(ID,Point(AX,AY),Catalog.Item(ID).Get('width_mm',1000),Catalog.Item(ID).Get('depth_mm',1000),Group); Inc(Group);
    N:=Length(D.Lines); SetLength(D.Lines,N+Length(Lines)); for J:=0 to High(Lines) do D.Lines[N+J]:=Lines[J];
  end;
begin
  D:=TCADDocument.Create; Group:=1;
  try
    Segment(0,0,24000,0,2); Segment(0,0,0,16000,2); Segment(24000,0,24000,16000,2);
    Segment(0,16000,2000,16000,2); Segment(4000,16000,24000,16000,2);
    for I:=0 to 2 do begin
      X:=I*8000;
      Segment(X,6000,X+1000,6000,2); Segment(X+2000,6000,X+8000,6000,2); Segment(X+1000,6000,X+2000,6000,3);
      Segment(X+1000,0,X+3500,0,4);
      if I>0 then Segment(X,0,X,6000,2);
    end;
    if Hospital then Step:=8000 else Step:=6000;
    for I:=0 to 24000 div Step-1 do begin
      X:=I*Step;
      Segment(X,9000,X+1000,9000,2); Segment(X+2000,9000,X+Step,9000,2); Segment(X+1000,9000,X+2000,9000,3);
      if I>0 then Segment(X,9000,X,16000,2);
    end;
    LabelAt('Circulação — estudo esquemático',1000,7800);
    if not Hospital then begin
      LabelAt('UBS — estudo esquemático, não referencial oficial',0,-1000);
      LabelAt('Consultório',1000,5500); LabelAt('Vacinação',9000,5500); LabelAt('Coleta / laboratório',17000,5500);
      LabelAt('Recepção',1000,15000); LabelAt('Espera',7000,15000); LabelAt('Apoio / DML',13000,15000); LabelAt('Sanitários — estudo',19000,15000);
      Place('consult_maca',1000,1000); Place('consult_mesa',3500,1000); Place('consult_cadeira_prof',3500,2200); Place('consult_cadeira_paciente',5200,1900); Place('consult_lavatorio',1000,4200); Place('consult_balanca',6500,1000);
      Place('vacina_camara',9000,700); Place('vacina_mesa',10500,700); Place('consult_cadeira_paciente',9000,2600);
      Place('lab_poltrona_coleta',17000,1000); Place('lab_bancada',19500,700); Place('lab_microscopio',19800,800); Place('lab_centrifuga',21500,800);
      Place('recepcao_balcao',1000,11000); Place('recepcao_longarina',7000,11000); Place('recepcao_longarina',7000,13000); Place('acesso_cadeira_rodas',10000,11000);
      Place('esterilizacao_bancada',13000,11000); Place('esterilizacao_autoclave',13200,11100); Place('apoio_dml',16500,13000);
      Place('sanitario_vaso',19000,11000); Place('consult_lavatorio',21500,11000);
    end else begin
      LabelAt('Ala assistencial — estudo esquemático hospitalar',0,-1000);
      LabelAt('Atendimento / urgência',1000,5500); LabelAt('Observação',9000,5500); LabelAt('Internação',17000,5500);
      LabelAt('Coleta / laboratório',1000,15000); LabelAt('Esterilização — estudo',9000,15000); LabelAt('Apoio assistencial',17000,15000);
      Place('urgencia_maca',1000,1000); Place('urgencia_carro',3000,1000); Place('urgencia_desfibrilador',3100,1100); Place('consult_lavatorio',6000,1000);
      Place('internacao_cama',9000,1000); Place('internacao_cama',12500,1000); Place('internacao_monitor',10500,1000);
      Place('internacao_cama',17000,1000); Place('internacao_mesa_cabeceira',18500,1000); Place('internacao_poltrona',19500,1000);
      Place('lab_bancada',1000,10500); Place('lab_microscopio',1200,10600); Place('lab_centrifuga',2500,10600); Place('lab_poltrona_coleta',5000,11000);
      Place('esterilizacao_bancada',9000,10500); Place('esterilizacao_autoclave',9200,10600); Place('apoio_expurgo',12000,10500);
      Place('apoio_carro_roupa',17000,11000); Place('consult_armario',19000,10500); Place('acesso_cadeira_rodas',21000,11000);
    end;
    Result:=D;
  except D.Free; raise; end;
end;
end.
