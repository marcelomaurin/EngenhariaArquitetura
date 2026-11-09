program test_config;
{$mode objfpc}{$H+}{$codepage utf8}
uses Classes, SysUtils, Process, fpjson, ea_config, ea_fileio;
var Path,Root,Original: string; G: TGUID; O,Changes: TJSONObject; L: TStringList;
    Failed: Boolean; Count,I: Integer; Hold: TFileStream; P,Q: TProcess;
procedure Check(Value: Boolean; const MessageText: string);
begin Inc(Count); if not Value then raise Exception.Create(MessageText); end;
procedure SetValue(const Key,Value: string);
var C: TJSONObject;
begin C:=TJSONObject.Create; try C.Add(Key,Value); EAUpdateConfig(C,Path); finally C.Free; end; end;
procedure Child;
var J: Integer; C: TJSONObject; Value: string;
begin
  for J:=1 to 30 do begin
    if ParamStr(3)='last_login' then Value:='login'+IntToStr(J) else Value:='https://nuvem.exemplo/api/'+IntToStr(J);
    C:=TJSONObject.Create;
    try C.Add(ParamStr(3),Value); EAUpdateConfig(C,ParamStr(2)); finally C.Free; end;
  end;
end;
procedure LaunchChild(Proc: TProcess; const Key: string);
begin Proc.Executable:=ExpandFileName(ParamStr(0)); Proc.Parameters.Add('--write'); Proc.Parameters.Add(Path); Proc.Parameters.Add(Key); Proc.Execute; end;
begin
  DefaultSystemCodePage:=CP_UTF8; SetMultiByteConversionCodePage(CP_UTF8);
  if (ParamCount=3) and (ParamStr(1)='--write') then begin Child; Halt(0); end;
  Count:=0; CreateGUID(G); Root:=GetTempDir(False)+'ea-config-'+GUIDToString(G); Path:=Root+DirectorySeparator+'config.json';
  L:=TStringList.Create;
  try
    O:=EAReadConfig(Path); try Check(O.Get('schema_version','')='1.0','configuração ausente recebe padrão'); Check(O.Get('last_login','')='','login inicial vazio'); finally O.Free; end;
    Check(EAValidCloudURL(''),'nuvem opcional'); Check(EAValidCloudURL('https://nuvem.exemplo/api'),'URL HTTPS aceita');
    Check(EAValidCloudURL('http://localhost:8080'),'servidor de desenvolvimento aceito');
    Check(not EAValidCloudURL('ftp://servidor'),'protocolo inválido recusado');
    Check(not EAValidCloudURL('https://'),'servidor ausente recusado');
    Check(not EAValidCloudURL('https://usuario:senha@servidor'),'credenciais na URL recusadas');
    Check(not EAValidCloudURL('https://ser vidor'),'espaços na URL recusados');
    SetValue('last_login','médico'); SetValue('cloud_server_url','https://nuvem.exemplo/api');
    O:=EAReadConfig(Path);
    try
      Check(O.Get('last_login','')='médico','login com acento preservado');
      Check(O.Get('cloud_server_url','')='https://nuvem.exemplo/api','escrita de campo preserva os demais');
      Check(O.Find('password')=nil,'nenhuma senha gravada');
      O.Add('future_option','preservar'); EAAtomicWriteText(Path,O.FormatJSON);
    finally O.Free; end;
    SetValue('last_login','outro'); O:=EAReadConfig(Path);
    try Check(O.Get('future_option','')='preservar','preferências desconhecidas preservadas'); finally O.Free; end;
    L.LoadFromFile(Path); Original:=L.Text;
    Failed:=False; try SetValue('cloud_server_url','invalida'); except on E: Exception do Failed:=True; end;
    Check(Failed,'URL inválida falha antes de gravar'); L.LoadFromFile(Path); Check(L.Text=Original,'configuração preservada em erro de validação');
    Failed:=False; try SetValue('password','nunca-gravar'); except on E: Exception do Failed:=True; end;
    Check(Failed,'API não permite guardar senha');
    Changes:=TJSONObject.Create;
    try Changes.Add('last_project','C:\Projetos\UBS.plan.json'); Changes.Add('last_planner_project','C:\Projetos\UBS.plan.json'); EAUpdateConfig(Changes,Path); finally Changes.Free; end;
    SetValue('last_cad2d_project','C:\Projetos\planta.eacad'); SetValue('last_project','C:\Projetos\planta.eacad');
    O:=EAReadConfig(Path);
    try Check(O.Get('last_planner_project','')='C:\Projetos\UBS.plan.json','histórico do Planejador preservado pelo CAD'); Check(O.Get('last_cad2d_project','')='C:\Projetos\planta.eacad','histórico CAD separado'); finally O.Free; end;
    P:=TProcess.Create(nil); Q:=TProcess.Create(nil);
    try
      LaunchChild(P,'last_login'); LaunchChild(Q,'cloud_server_url');
      for I:=1 to 1500 do begin if not P.Running and not Q.Running then Break; Sleep(10); end;
      if P.Running then P.Terminate(1); if Q.Running then Q.Terminate(1);
      P.WaitOnExit; Q.WaitOnExit;
      Check((P.ExitStatus=0) and (Q.ExitStatus=0),'dois aplicativos escrevem simultaneamente');
    finally P.Free; Q.Free; end;
    O:=EAReadConfig(Path);
    try Check(O.Get('last_login','')='login30','último login concorrente mantido'); Check(O.Get('cloud_server_url','')='https://nuvem.exemplo/api/30','URL concorrente mantida'); Check(O.Get('last_planner_project','')='C:\Projetos\UBS.plan.json','escrita concorrente não apaga projeto'); finally O.Free; end;
    L.LoadFromFile(Path); Original:=L.Text;
    Hold:=TFileStream.Create(Path,fmOpenRead or fmShareExclusive);
    try Failed:=False; try SetValue('last_login','falha'); except on E: Exception do Failed:=True; end; Check(Failed,'falha de acesso reportada'); finally Hold.Free; end;
    L.LoadFromFile(Path); Check(L.Text=Original,'falha de acesso preserva conteúdo');
    EAAtomicWriteText(Path,'{ invalido'); Failed:=False;
    try SetValue('last_login','nao-sobrescrever'); except on E: Exception do Failed:=True; end;
    Check(Failed,'JSON inválido reportado'); L.LoadFromFile(Path); Check(Pos('invalido',L.Text)>0,'JSON inválido não é sobrescrito');
    WriteLn(Count,' verificacoes de configuracao compartilhada, 0 falhas');
  finally L.Free; DeleteFile(Path); DeleteFile(Path+'.lock'); RemoveDir(Root); end;
end.
