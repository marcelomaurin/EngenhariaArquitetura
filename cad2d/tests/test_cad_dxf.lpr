program test_cad_dxf;
{$mode objfpc}{$H+}
uses Classes, SysUtils, Types, cad_document, cad_dxf;
var D: TCADDocument; L: TStringList; G: TGUID; FileName,Report: string; Checks: Integer; Failed: Boolean;
procedure Check(OK: Boolean; const Msg: string);
begin Inc(Checks); if not OK then raise Exception.Create(Msg); end;
procedure MakeDXF(const UnitCode,Entities: string);
begin L.Text:='0'+LineEnding+'SECTION'+LineEnding+'2'+LineEnding+'HEADER'+LineEnding+'9'+LineEnding+'$INSUNITS'+LineEnding+'70'+LineEnding+UnitCode+LineEnding+'0'+LineEnding+'ENDSEC'+LineEnding+'0'+LineEnding+'SECTION'+LineEnding+'2'+LineEnding+'ENTITIES'+LineEnding+Entities+LineEnding+'0'+LineEnding+'ENDSEC'+LineEnding+'0'+LineEnding+'EOF'; L.SaveToFile(FileName); end;
function LineText(const Layer: string): string;
begin Result:='0'+LineEnding+'LINE'+LineEnding+'8'+LineEnding+Layer+LineEnding+'10'+LineEnding+'1.25'+LineEnding+'20'+LineEnding+'-2.5'+LineEnding+'11'+LineEnding+'3.75'+LineEnding+'21'+LineEnding+'4.5'; end;
begin
  CreateGUID(G); FileName:=IncludeTrailingPathDelimiter(GetTempDir)+'ea-dxf-'+GUIDToString(G)+'.dxf';
  D:=TCADDocument.Create; L:=TStringList.Create;
  try
    MakeDXF('5',LineText('ARQ_ESQUADRIAS')); CADImportDXF(FileName,D,Report);
    Check(Length(D.Lines)=1,'linha importada'); Check(D.Lines[0].A=Point(12,25),'cm convertidos para mm e eixo Y');
    Check(D.Lines[0].B=Point(38,-45),'arredondamento de meio mm'); Check(D.Lines[0].Layer=1,'camada conhecida preservada');
    Check(Pos('arredondadas',Report)>0,'relatorio de arredondamento');
    MakeDXF('6',LineText('CAMADA_EXTERNA')); CADImportDXF(FileName,D,Report);
    Check(D.Lines[0].A=Point(1250,2500),'metros convertidos'); Check(D.Lines[0].Layer=0,'camada externa mapeada');
    Check(Pos('1 linhas com camada',Report)>0,'mapeamento informado');
    MakeDXF('4',LineText('ARQ_PAREDES')+LineEnding+'0'+LineEnding+'CIRCLE'+LineEnding+'10'+LineEnding+'1'+LineEnding+'20'+LineEnding+'1'+LineEnding+'40'+LineEnding+'5');
    CADImportDXF(FileName,D,Report); Check(Length(D.Lines)=1,'curva nao fingida como linha'); Check(Pos('1 entidades ignoradas',Report)>0,'entidade nao suportada informada');
    MakeDXF('4',LineText('0')+LineEnding+'30'+LineEnding+'10');
    Failed:=False; try CADImportDXF(FileName,D,Report); except on E: Exception do Failed:=True; end; Check(Failed,'linha 3D nao convertida silenciosamente');
    Check(Length(D.Lines)=1,'falha preserva documento');
    MakeDXF('7',LineText('0')); Failed:=False; try CADImportDXF(FileName,D,Report); except on E: Exception do Failed:=True; end; Check(Failed,'unidade nao suportada recusada');
    MakeDXF('0',LineText('0')); CADImportDXF(FileName,D,Report); Check(Pos('Sem unidade declarada',Report)>0,'unidade ausente informada');
    L.Text:='0'+LineEnding+'LINE'+LineEnding+'10'; L.SaveToFile(FileName);
    Failed:=False; try CADImportDXF(FileName,D,Report); except on E: Exception do Failed:=True; end; Check(Failed,'DXF truncado recusado');
    WriteLn(Checks,' verificacoes DXF 2D, 0 falhas');
  except on E: Exception do begin WriteLn('FALHA: ',E.Message); Halt(1); end; end;
  L.Free; D.Free; DeleteFile(FileName);
end.
