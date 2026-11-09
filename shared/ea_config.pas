unit ea_config;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, fpjson;
function EAConfigFile: string;
function EAReadConfig(const FileName: string=''): TJSONObject;
function EAConfigGet(const Key: string): string;
procedure EAUpdateConfig(Changes: TJSONObject; const FileName: string='');
procedure EAConfigSet(const Key,Value: string);
procedure EARememberProject(const App,FileName: string);
function EALastProject(const App: string): string;
function EAValidCloudURL(const Value: string): Boolean;
implementation
uses jsonparser, ea_fileio;
function EAConfigFile: string;
var Base: string;
begin
  Result:=GetEnvironmentVariable('EA_CONFIG_FILE');
  if Result<>'' then Exit(ExpandFileName(Result));
  Base:=GetEnvironmentVariable('LOCALAPPDATA');
  if Base='' then Base:=GetAppConfigDir(False);
  Result:=IncludeTrailingPathDelimiter(Base)+'EngenhariaArquitetura'+DirectorySeparator+'config.json';
end;
function ConfigPath(const Name: string): string;
begin if Name='' then Result:=EAConfigFile else Result:=ExpandFileName(Name); end;
function AcquireConfigLock(const Path: string): TFileStream;
var Attempt: Integer;
begin
  if not ForceDirectories(ExtractFileDir(Path)) then raise Exception.Create('Não foi possível criar a pasta de configuração');
  Result:=nil;
  for Attempt:=1 to 200 do begin
    try
      if FileExists(Path+'.lock') then Result:=TFileStream.Create(Path+'.lock',fmOpenReadWrite or fmShareExclusive)
      else Result:=TFileStream.Create(Path+'.lock',fmCreate or fmShareExclusive);
      Break;
    except on E: EFOpenError do begin if Attempt=200 then raise; Sleep(25); end;
           on E: EFCreateError do begin if Attempt=200 then raise; Sleep(25); end; end;
  end;
end;
function ReadRawConfig(const FileName: string): TJSONObject;
var Stream: TFileStream; Data: TJSONData; Path: string;
begin
  Path:=ConfigPath(FileName);
  if not FileExists(Path) then begin Result:=TJSONObject.Create; Result.Add('schema_version','1.0'); Exit; end;
  Stream:=TFileStream.Create(Path,fmOpenRead or fmShareDenyNone);
  try
    if Stream.Size>1024*1024 then raise Exception.Create('Arquivo de configuração excede 1 MB');
    Data:=GetJSON(Stream,True);
  finally Stream.Free; end;
  if not (Data is TJSONObject) then begin Data.Free; raise Exception.Create('Configuração inválida: esperado objeto JSON'); end;
  Result:=TJSONObject(Data);
  if Result.Get('schema_version','1.0')<>'1.0' then begin Result.Free; raise Exception.Create('Versão de configuração não suportada'); end;
end;
function EAReadConfig(const FileName: string): TJSONObject;
var Lock: TFileStream; Path: string;
begin
  Path:=ConfigPath(FileName); Lock:=AcquireConfigLock(Path);
  try Result:=ReadRawConfig(Path); finally Lock.Free; end;
end;
function EAConfigGet(const Key: string): string;
var O: TJSONObject;
begin O:=EAReadConfig; try Result:=O.Get(Key,''); finally O.Free; end; end;
function EAValidCloudURL(const Value: string): Boolean;
var S,Host: string; N,I: Integer;
begin
  Result:=False; S:=Trim(Value); if S='' then Exit(True);
  if Pos('https://',LowerCase(S))=1 then Delete(S,1,8)
  else if Pos('http://',LowerCase(S))=1 then Delete(S,1,7) else Exit;
  Host:=S; N:=Pos('/',Host); if N>0 then Host:=Copy(Host,1,N-1);
  if (Host='') or (Pos('@',Host)>0) or (Pos('?',Host)>0) or (Pos('#',Host)>0) then Exit;
  for I:=1 to Length(Value) do if (Ord(Value[I])<=32) or (Value[I]='\') then Exit;
  Result:=True;
end;
procedure EAUpdateConfig(Changes: TJSONObject; const FileName: string);
var Path,Key,Value: string; Lock: TFileStream; O: TJSONObject; I: Integer;
begin
  if Changes.Count=0 then Exit;
  for I:=0 to Changes.Count-1 do begin
    Key:=Changes.Names[I];
    if (Key<>'last_project') and (Key<>'last_planner_project') and (Key<>'last_cad2d_project') and
       (Key<>'cloud_server_url') and (Key<>'last_login') then raise Exception.Create('Campo de configuração desconhecido: '+Key);
    if Changes.Items[I].JSONType<>jtString then raise Exception.Create('Configuração deve conter texto');
    Value:=Trim(Changes.Strings[Key]);
    if Length(Value)>8192 then raise Exception.Create('Valor de configuração muito longo');
    if (Key='cloud_server_url') and not EAValidCloudURL(Value) then
      raise Exception.Create('Informe uma URL http:// ou https:// válida, sem usuário e senha, ou deixe vazia.');
  end;
  Path:=ConfigPath(FileName); if not ForceDirectories(ExtractFileDir(Path)) then raise Exception.Create('Não foi possível criar a pasta de configuração');
  Lock:=AcquireConfigLock(Path);
  try
    O:=ReadRawConfig(Path);
    try
      for I:=0 to Changes.Count-1 do begin
        Key:=Changes.Names[I]; Value:=Trim(Changes.Strings[Key]); O.Delete(Key); O.Add(Key,Value);
      end;
      EAAtomicWriteText(Path,O.FormatJSON);
    finally O.Free; end;
  finally Lock.Free; end;
end;
procedure EAConfigSet(const Key,Value: string);
var O: TJSONObject;
begin O:=TJSONObject.Create; try O.Add(Key,Value); EAUpdateConfig(O); finally O.Free; end; end;
procedure EARememberProject(const App,FileName: string);
var O: TJSONObject; Path: string;
begin
  if (App<>'planner') and (App<>'cad2d') then raise Exception.Create('Aplicativo desconhecido');
  Path:=ExpandFileName(FileName); O:=TJSONObject.Create;
  try O.Add('last_project',Path); O.Add('last_'+App+'_project',Path); EAUpdateConfig(O); finally O.Free; end;
end;
function EALastProject(const App: string): string;
var O: TJSONObject;
begin
  O:=EAReadConfig;
  try
    if App='' then Result:=O.Get('last_project','') else Result:=O.Get('last_'+App+'_project','');
    if Result='' then begin
      Result:=O.Get('last_project','');
      if ((App='planner') and not SameText(ExtractFileExt(Result),'.json')) or
         ((App='cad2d') and not SameText(ExtractFileExt(Result),'.eacad')) then Result:='';
    end;
  finally O.Free; end;
end;
end.
