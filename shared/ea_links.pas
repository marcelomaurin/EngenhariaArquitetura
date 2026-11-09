unit ea_links;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses SysUtils, fpjson;
function EAValidLink(const Value: string): Boolean;
function EAResolveLink(const Value,BaseFile: string): string;
procedure EAValidateFiles(Files: TJSONArray);
implementation
uses ea_config;
function EAValidLink(const Value: string): Boolean;
var S: string; I: Integer;
begin
  S:=Trim(Value); Result:=False;
  if (S='') or (Length(S)>8192) then Exit;
  for I:=1 to Length(S) do if Ord(S[I])<32 then Exit;
  if (Pos('http://',LowerCase(S))=1) or (Pos('https://',LowerCase(S))=1) then Exit(EAValidCloudURL(S));
  { Links locais, UNC e relativos são permitidos, sem esquemas executáveis. }
  I:=Pos(':',S); if (I>0) and not ((I=2) and (UpCase(S[1]) in ['A'..'Z']) and (Length(S)>2) and (S[3] in ['\','/'])) then Exit;
  Result:=True;
end;
function EAResolveLink(const Value,BaseFile: string): string;
begin
  Result:=Trim(Value);
  if not EAValidLink(Result) then raise Exception.Create('Link inválido: use caminho de arquivo ou URL HTTP/HTTPS');
  if (Pos('http://',LowerCase(Result))=1) or (Pos('https://',LowerCase(Result))=1) then Exit;
  if not ((Copy(Result,1,2)='\\') or ((Length(Result)>2) and (Result[2]=':')) or (Copy(Result,1,1)='/')) then begin
    if BaseFile='' then raise Exception.Create('Salve o projeto antes de abrir um caminho relativo');
    Result:=ExpandFileName(ExtractFilePath(ExpandFileName(BaseFile))+Result);
  end;
end;
procedure EAValidateFiles(Files: TJSONArray);
var I: Integer; O: TJSONObject;
begin
  if Files.Count>5000 then raise Exception.Create('Limite de vínculos de arquivos excedido');
  for I:=0 to Files.Count-1 do begin
    if not (Files.Items[I] is TJSONObject) then raise Exception.Create('Vínculo de arquivo inválido');
    O:=Files.Objects[I];
    if (O.Get('direction','')<>'input') and (O.Get('direction','')<>'output') then raise Exception.Create('Indique entrada ou saída para o arquivo');
    if Trim(O.Get('name',''))='' then raise Exception.Create('Informe o nome do arquivo/recurso');
    if not EAValidLink(O.Get('link','')) then raise Exception.Create('Caminho ou link de arquivo inválido');
  end;
end;
end.
