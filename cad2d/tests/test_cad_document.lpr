program test_cad_document;
{$mode objfpc}{$H+}{$codepage utf8}
uses Classes, SysUtils, Types, cad_document, ea_fileio;
var D,Q: TCADDocument; FileName,BadName,Before: string; L: TStringList; G: TGUID;
  Hold: TFileStream; Checks,Version: Integer; Failed: Boolean;
procedure Check(OK: Boolean; const Msg: string);
begin Inc(Checks); if not OK then raise Exception.Create(Msg); end;
begin
  CreateGUID(G); FileName:=IncludeTrailingPathDelimiter(GetTempDir)+'cad-roundtrip-'+GUIDToString(G)+'.eacad'; BadName:=FileName+'.invalid';
  D:=TCADDocument.Create; Q:=TCADDocument.Create; L:=TStringList.Create;
  try
    SetLength(D.Lines,1); D.Lines[0].A:=Point(-3073,125); D.Lines[0].B:=Point(1417,3099);
    D.Lines[0].Layer:=1; D.Lines[0].Kind:=9; D.Lines[0].WidthMM:=181;
    D.Lines[0].HeightMM:=713; D.Lines[0].SillMM:=1637; D.Lines[0].GroupID:=42;
    D.GridMM:=25; D.Visible[3]:=False; D.Locked[5]:=True;
    D.Save(FileName); Q.Load(FileName);
    Check(Length(Q.Lines)=1,'entidades preservadas');
    Check(Q.Lines[0].A=Point(-3073,125),'coordenada exata em 1 mm');
    Check(Q.Lines[0].B=D.Lines[0].B,'segunda coordenada preservada');
    Check(Q.Lines[0].WidthMM=181,'largura preservada');
    Check(Q.Lines[0].HeightMM=713,'altura preservada');
    Check(Q.Lines[0].SillMM=1637,'peitoril preservado');
    Check(Q.Lines[0].GroupID=42,'grupo preservado');
    Check((Q.Lines[0].Layer=1) and (Q.Lines[0].Kind=9),'camada e tipo preservados');
    Check(Q.GridMM=25,'grade persistida'); Check(not Q.Visible[3],'visibilidade persistida'); Check(Q.Locked[5],'bloqueio persistido');
    L.LoadFromFile(FileName); Check(L[0]='EACAD5','novo formato'); Check(L[1]='1','unidade mm');
    Before:=L.Text;
    Hold:=TFileStream.Create(FileName,fmOpenRead or fmShareExclusive);
    try Failed:=False; try D.Save(FileName); except on E: Exception do Failed:=True; end; Check(Failed,'falha de escrita detectada');
    finally Hold.Free; end;
    L.LoadFromFile(FileName); Check(L.Text=Before,'original preservado apos falha');
    L.Text:='EACAD4'+LineEnding+'1'+LineEnding+'META {}'; L.SaveToFile(BadName);
    Failed:=False; try Q.Load(BadName); except on E: Exception do Failed:=True; end;
    Check(Failed,'arquivo invalido recusado'); Check(Q.Lines[0].HeightMM=713,'falha de leitura preserva documento'); Check(Q.GridMM=25,'falha preserva configuracoes');
    for Version:=1 to 3 do begin
      L.Clear; L.Add('EACAD'+IntToStr(Version)); L.Add('50');
      case Version of 1: L.Add('3;2;7;9;1;4'); 2: L.Add('3;2;7;9;1;4;175'); 3: L.Add('3;2;7;9;1;4;175;19'); end;
      L.SaveToFile(BadName); Q.Load(BadName);
      Check(Q.Lines[0].A=Point(150,100),'conversao de unidades antiga');
      Check(Q.Lines[0].B=Point(350,450),'medidas antigas mantidas');
      Check((Q.Lines[0].HeightMM=1200) and (Q.Lines[0].SillMM=900),'valores legados explicitos');
      Q.Save(BadName); Q.Load(BadName); Check(Q.Lines[0].B=Point(350,450),'migracao idempotente');
    end;
    L.Text:='EACAD3'+LineEnding+'50'+LineEnding+'2147483647;0;1;1;0;0;0;1'; L.SaveToFile(BadName);
    Failed:=False; try Q.Load(BadName); except on E: Exception do Failed:=True; end; Check(Failed,'overflow de migracao recusado');
    D.Lines[0].HeightMM:=-1; Failed:=False; try D.Save(FileName); except on E: Exception do Failed:=True; end; Check(Failed,'dimensao negativa recusada');
    L.LoadFromFile(FileName); Check(L.Text=Before,'validacao antes de substituir arquivo');
    WriteLn(Checks,' verificacoes de persistencia CAD e gravacao segura, 0 falhas');
  except on E: Exception do begin WriteLn('FALHA: ',E.Message); Halt(1); end; end;
  L.Free; Q.Free; D.Free; DeleteFile(FileName); DeleteFile(BadName);
end.
