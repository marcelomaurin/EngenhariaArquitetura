unit ea_workflow;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, DateUtils, fpjson, jsonparser;
const
  WF_ROLES: array[0..3] of string = ('Administrador','Usuário','Usuário restrito (my task only)','Visualizador');
  WF_ROLE_CODES: array[0..3] of string = ('admin','user','restricted','viewer');
type
  EWorkflow = class(Exception);
  TWorkflow = class
  private
    FPath: string;
    FData: TJSONObject;
    FLock: TFileStream;
    procedure Open;
    procedure Finish(Changed: Boolean);
    function Actor(const Token: string): TJSONObject;
    function Find(A: TJSONArray; const ID: string): TJSONObject;
    function AddSession(U: TJSONObject): string;
    function Visible(U,T: TJSONObject): Boolean;
    procedure RequireManager(U: TJSONObject);
  public
    constructor Create(const APath: string = '');
    destructor Destroy; override;
    function Empty: Boolean;
    function Bootstrap(const Login, Name, Password: string): string;
    function Login(const ALogin, Password: string): string;
    procedure Logout(const Token: string);
    function User(const Token: string): TJSONObject;
    function Users(const Token: string): TJSONArray;
    function SaveUser(const Token, ID, ALogin, Name, Password, Role: string; Active: Boolean): string;
    function Tasks(const Token: string): TJSONArray;
    function Task(const Token, ID: string): TJSONObject;
    function SaveTask(const Token, ID, Title, Details, Assignee, Artifact, Source, SourceID: string): string;
    procedure Reply(const Token, ID, Text, State: string; Progress: Integer; const Artifact: string; Returned: Boolean);
    property Path: string read FPath;
  end;
function WFDefaultPath: string;
function WFArg(const Name: string): string;
procedure WFSet(O: TJSONObject; const Key, Value: string); overload;
procedure WFSet(O: TJSONObject; const Key: string; Value: Int64); overload;
procedure WFSet(O: TJSONObject; const Key: string; Value: Boolean); overload;
function WFManager(U: TJSONObject): Boolean;
implementation
{$IFDEF WINDOWS}uses Windows;{$ENDIF}
{$IFDEF WINDOWS}
function BCryptOpenAlgorithmProvider(out H: Pointer; Alg, Provider: PWideChar; Flags: LongWord): LongInt; stdcall; external 'bcrypt.dll';
function BCryptCloseAlgorithmProvider(H: Pointer; Flags: LongWord): LongInt; stdcall; external 'bcrypt.dll';
function BCryptGenRandom(H: Pointer; Buffer: Pointer; Size, Flags: LongWord): LongInt; stdcall; external 'bcrypt.dll';
function BCryptDeriveKeyPBKDF2(H: Pointer; Password: Pointer; PasswordSize: LongWord; Salt: Pointer; SaltSize: LongWord; Iterations: QWord; Output: Pointer; OutputSize, Flags: LongWord): LongInt; stdcall; external 'bcrypt.dll';
{$ENDIF}
function Hex(const S: RawByteString): string;
var I: Integer;
begin Result := ''; for I:=1 to Length(S) do Result += LowerCase(IntToHex(Ord(S[I]),2)); end;
function RandomKey: string;
var B: RawByteString;
begin
  SetLength(B,32);
  {$IFDEF WINDOWS}
  if BCryptGenRandom(nil,@B[1],Length(B),2)<>0 then raise EWorkflow.Create('Falha no gerador de segurança do Windows');
  {$ELSE}raise EWorkflow.Create('Autenticação deste pacote requer Windows');{$ENDIF}
  Result:=Hex(B);
end;
function PasswordHash(const Password, Salt: string): string;
var B,P,S: RawByteString; H: Pointer;
begin
  P:=UTF8Encode(UnicodeString(Password)); S:=Salt; SetLength(B,32); H:=nil;
  {$IFDEF WINDOWS}
  if BCryptOpenAlgorithmProvider(H,'SHA256',nil,8)<>0 then raise EWorkflow.Create('Falha no provedor criptográfico');
  try
    if BCryptDeriveKeyPBKDF2(H,Pointer(P),Length(P),Pointer(S),Length(S),600000,@B[1],32,0)<>0 then
      raise EWorkflow.Create('Falha ao proteger a senha');
  finally BCryptCloseAlgorithmProvider(H,0); end;
  {$ELSE}raise EWorkflow.Create('Autenticação deste pacote requer Windows');{$ENDIF}
  Result:=Hex(B);
end;
function EqualSecret(const A,B: string): Boolean;
var I,D: Integer;
begin D:=Length(A) xor Length(B); for I:=1 to Length(A) do if I<=Length(B) then D:=D or (Ord(A[I]) xor Ord(B[I])); Result:=D=0; end;
function Stamp: string;
begin Result:=FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"',LocalTimeToUniversal(Now)); end;
function Seconds: Int64;
begin Result:=DateTimeToUnix(LocalTimeToUniversal(Now)); end;
procedure WFSet(O: TJSONObject; const Key, Value: string);
begin O.Delete(Key); O.Add(Key,Value); end;
procedure WFSet(O: TJSONObject; const Key: string; Value: Int64);
begin O.Delete(Key); O.Add(Key,Value); end;
procedure WFSet(O: TJSONObject; const Key: string; Value: Boolean);
begin O.Delete(Key); O.Add(Key,Value); end;
function WFArg(const Name: string): string;
var I: Integer;
begin Result:=''; for I:=1 to ParamCount-1 do if ParamStr(I)=Name then Exit(ParamStr(I+1)); end;
function WFDefaultPath: string;
var Base: string;
begin
  Base:=SysUtils.GetEnvironmentVariable('LOCALAPPDATA');
  if Base='' then Base:=GetAppConfigDir(False);
  Result:=IncludeTrailingPathDelimiter(Base)+'EngenhariaArquitetura'+DirectorySeparator+'workspace.json';
end;
function WFManager(U: TJSONObject): Boolean;
begin Result:=(U<>nil) and ((U.Get('role','')='admin') or (U.Get('role','')='user')); end;
constructor TWorkflow.Create(const APath: string);
begin inherited Create; FPath:=APath; if FPath='' then FPath:=WFDefaultPath; FPath:=ExpandFileName(FPath); end;
destructor TWorkflow.Destroy;
begin FData.Free; FLock.Free; inherited Destroy; end;
procedure TWorkflow.Open;
var D: TJSONData; L: TStringList;
begin
  if Assigned(FLock) then raise EWorkflow.Create('Transação já aberta');
  ForceDirectories(ExtractFilePath(FPath));
  try FLock:=TFileStream.Create(FPath+'.lock',fmCreate or fmShareExclusive);
  except raise EWorkflow.Create('Espaço de trabalho em uso. Tente novamente.'); end;
  try
    if FileExists(FPath) then begin
      L:=TStringList.Create;
      try L.LoadFromFile(FPath); D:=GetJSON(L.Text); finally L.Free; end;
      if not (D is TJSONObject) then begin D.Free; raise EWorkflow.Create('Espaço de trabalho inválido'); end;
      FData:=TJSONObject(D);
      if FData.Get('schema',0)<>1 then raise EWorkflow.Create('Versão de espaço de trabalho incompatível');
    end else begin
      FData:=TJSONObject.Create; FData.Add('schema',1);
      FData.Add('users',TJSONArray.Create); FData.Add('tasks',TJSONArray.Create); FData.Add('sessions',TJSONArray.Create);
    end;
  except FreeAndNil(FData); FreeAndNil(FLock); raise; end;
end;
procedure TWorkflow.Finish(Changed: Boolean);
var L: TStringList; Tmp: string;
begin
  try
    if Changed then begin
      Tmp:=FPath+'.tmp'; L:=TStringList.Create;
      try L.Text:=FData.FormatJSON; L.SaveToFile(Tmp); finally L.Free; end;
      {$IFDEF WINDOWS}
      if not MoveFileExW(PWideChar(UTF8Decode(Tmp)),PWideChar(UTF8Decode(FPath)),MOVEFILE_REPLACE_EXISTING or $00000008) then
        raise EWorkflow.Create('Não foi possível gravar o espaço de trabalho');
      {$ELSE}if not RenameFile(Tmp,FPath) then raise EWorkflow.Create('Falha ao gravar espaço de trabalho');{$ENDIF}
    end;
  finally FreeAndNil(FData); FreeAndNil(FLock); end;
end;
function TWorkflow.Find(A: TJSONArray; const ID: string): TJSONObject;
var I: Integer;
begin Result:=nil; for I:=0 to A.Count-1 do if A.Objects[I].Get('id','')=ID then Exit(A.Objects[I]); end;
function TWorkflow.Actor(const Token: string): TJSONObject;
var S: TJSONObject;
begin
  S:=Find(FData.Arrays['sessions'],Token);
  if (S=nil) or (S.Get('expires',Int64(0))<=Seconds) then raise EWorkflow.Create('Sessão expirada. Entre novamente.');
  Result:=Find(FData.Arrays['users'],S.Get('user_id',''));
  if (Result=nil) or not Result.Get('active',False) then raise EWorkflow.Create('Usuário desativado');
end;
function TWorkflow.AddSession(U: TJSONObject): string;
var S: TJSONObject; A: TJSONArray; I: Integer;
begin
  A:=FData.Arrays['sessions']; for I:=A.Count-1 downto 0 do if A.Objects[I].Get('expires',Int64(0))<=Seconds then A.Delete(I);
  Result:=RandomKey; S:=TJSONObject.Create;
  S.Add('id',Result); S.Add('user_id',U.Get('id','')); S.Add('expires',Seconds+8*3600); A.Add(S);
end;
function TWorkflow.Visible(U,T: TJSONObject): Boolean;
begin Result:=(U.Get('role','')<>'restricted') or (T.Get('assignee','')=U.Get('id','')); end;
procedure TWorkflow.RequireManager(U: TJSONObject);
begin if not WFManager(U) then raise EWorkflow.Create('Acesso permitido somente a Administrador e Usuário'); end;
function TWorkflow.Empty: Boolean;
begin Open; try Result:=FData.Arrays['users'].Count=0; finally Finish(False); end; end;
function TWorkflow.Bootstrap(const Login,Name,Password: string): string;
var U: TJSONObject; OK: Boolean;
begin
  Open; OK:=False;
  try
    if FData.Arrays['users'].Count<>0 then raise EWorkflow.Create('O administrador inicial já foi criado');
    if (Trim(Login)='') or (Trim(Name)='') or (Length(Password)<8) then raise EWorkflow.Create('Informe nome, login e uma senha de pelo menos 8 caracteres');
    U:=TJSONObject.Create; U.Add('id',RandomKey); U.Add('login',LowerCase(Trim(Login))); U.Add('name',Trim(Name));
    U.Add('role','admin'); U.Add('active',True); U.Add('password_kdf','pbkdf2-sha256'); U.Add('password_iterations',600000); U.Add('salt',RandomKey); U.Add('password_hash',PasswordHash(Password,U.Get('salt','')));
    FData.Arrays['users'].Add(U); Result:=AddSession(U); OK:=True;
  finally Finish(OK); end;
end;
function TWorkflow.Login(const ALogin,Password: string): string;
var I: Integer; U: TJSONObject; OK, Locked: Boolean;
begin
  Open; OK:=False;
  try
    for I:=0 to FData.Arrays['users'].Count-1 do begin
      U:=FData.Arrays['users'].Objects[I];
      if SameText(U.Get('login',''),Trim(ALogin)) then begin
        Locked:=U.Get('locked_until',Int64(0))>Seconds;
        if Locked or not U.Get('active',False) then raise EWorkflow.Create('Login inválido ou temporariamente bloqueado');
        if not EqualSecret(U.Get('password_hash',''),PasswordHash(Password,U.Get('salt',''))) then begin
          WFSet(U,'failures',U.Get('failures',Int64(0))+1);
          if U.Get('failures',0)>=5 then begin WFSet(U,'locked_until',Seconds+60); WFSet(U,'failures',Int64(0)); end;
          OK:=True; raise EWorkflow.Create('Login ou senha inválidos');
        end;
        WFSet(U,'failures',Int64(0)); Result:=AddSession(U); OK:=True; Exit;
      end;
    end;
    raise EWorkflow.Create('Login ou senha inválidos');
  finally Finish(OK); end;
end;
procedure TWorkflow.Logout(const Token: string);
var I: Integer;
begin Open; try for I:=FData.Arrays['sessions'].Count-1 downto 0 do if FData.Arrays['sessions'].Objects[I].Get('id','')=Token then FData.Arrays['sessions'].Delete(I); finally Finish(True); end; end;
function TWorkflow.User(const Token: string): TJSONObject;
begin Open; try Result:=TJSONObject(Actor(Token).Clone); Result.Delete('salt'); Result.Delete('password_hash'); finally Finish(False); end; end;
function TWorkflow.Users(const Token: string): TJSONArray;
var U,V,C: TJSONObject; I: Integer;
begin
  Open; Result:=TJSONArray.Create;
  try
    U:=Actor(Token); RequireManager(U);
    for I:=0 to FData.Arrays['users'].Count-1 do begin
      V:=FData.Arrays['users'].Objects[I]; C:=TJSONObject(V.Clone); C.Delete('password_hash'); C.Delete('salt'); Result.Add(C);
    end;
  except Result.Free; Finish(False); raise; end;
  Finish(False);
end;
function TWorkflow.SaveUser(const Token,ID,ALogin,Name,Password,Role: string; Active: Boolean): string;
var U,V,A: TJSONObject; I,N: Integer; OK, ValidRole: Boolean;
begin
  Open; OK:=False;
  try
    U:=Actor(Token); if U.Get('role','')<>'admin' then raise EWorkflow.Create('Somente o Administrador pode gerenciar usuários');
    ValidRole:=False; for I:=0 to 3 do ValidRole:=ValidRole or (Role=WF_ROLE_CODES[I]);
    if not ValidRole then raise EWorkflow.Create('Tipo de acesso inválido');
    if (Trim(ALogin)='') or (Trim(Name)='') then raise EWorkflow.Create('Nome e login obrigatórios');
    for I:=0 to FData.Arrays['users'].Count-1 do begin
      A:=FData.Arrays['users'].Objects[I];
      if SameText(A.Get('login',''),Trim(ALogin)) and (A.Get('id','')<>ID) then raise EWorkflow.Create('Login já cadastrado');
    end;
    V:=Find(FData.Arrays['users'],ID);
    if (V=nil) and (ID<>'') then raise EWorkflow.Create('Usuário não encontrado');
    if ((V=nil) or (Password<>'')) and (Length(Password)<8) then raise EWorkflow.Create('A senha deve conter pelo menos 8 caracteres');
    if (V<>nil) and (V.Get('role','')='admin') and ((Role<>'admin') or not Active) then begin
      N:=0; for I:=0 to FData.Arrays['users'].Count-1 do begin A:=FData.Arrays['users'].Objects[I]; if (A.Get('role','')='admin') and A.Get('active',False) then Inc(N); end;
      if N<=1 then raise EWorkflow.Create('Mantenha ao menos um Administrador ativo');
    end;
    if V=nil then begin V:=TJSONObject.Create; V.Add('id',RandomKey); FData.Arrays['users'].Add(V); end;
    WFSet(V,'login',LowerCase(Trim(ALogin))); WFSet(V,'name',Trim(Name)); WFSet(V,'role',Role); WFSet(V,'active',Active);
    if Password<>'' then begin
      WFSet(V,'password_kdf','pbkdf2-sha256'); WFSet(V,'password_iterations',Int64(600000));
      WFSet(V,'salt',RandomKey); WFSet(V,'password_hash',PasswordHash(Password,V.Get('salt','')));
      for I:=FData.Arrays['sessions'].Count-1 downto 0 do if FData.Arrays['sessions'].Objects[I].Get('user_id','')=V.Get('id','') then FData.Arrays['sessions'].Delete(I);
    end;
    Result:=V.Get('id',''); OK:=True;
  finally Finish(OK); end;
end;
function TWorkflow.Tasks(const Token: string): TJSONArray;
var U,T: TJSONObject; I: Integer;
begin
  Open; Result:=TJSONArray.Create;
  try
    U:=Actor(Token);
    for I:=0 to FData.Arrays['tasks'].Count-1 do begin T:=FData.Arrays['tasks'].Objects[I]; if Visible(U,T) then Result.Add(T.Clone); end;
  except Result.Free; Finish(False); raise; end;
  Finish(False);
end;
function TWorkflow.Task(const Token,ID: string): TJSONObject;
var U,T: TJSONObject;
begin
  Open;
  try
    U:=Actor(Token); T:=Find(FData.Arrays['tasks'],ID);
    if (T=nil) or not Visible(U,T) then raise EWorkflow.Create('Tarefa indisponível para este usuário');
    Result:=TJSONObject(T.Clone);
  finally Finish(False); end;
end;
function TWorkflow.SaveTask(const Token,ID,Title,Details,Assignee,Artifact,Source,SourceID: string): string;
var U,T,A: TJSONObject; OK: Boolean;
begin
  Open; OK:=False;
  try
    U:=Actor(Token); RequireManager(U);
    if Trim(Title)='' then raise EWorkflow.Create('Informe o nome da tarefa');
    A:=Find(FData.Arrays['users'],Assignee);
    if (A=nil) or not A.Get('active',False) or (A.Get('role','')='viewer') then raise EWorkflow.Create('Selecione um responsável ativo com acesso de execução');
    T:=Find(FData.Arrays['tasks'],ID);
    if (T=nil) and (ID<>'') then raise EWorkflow.Create('Tarefa não encontrada');
    if T=nil then begin
      T:=TJSONObject.Create; T.Add('id',RandomKey); T.Add('state','pendente'); T.Add('progress',0);
      T.Add('history',TJSONArray.Create); T.Add('created_at',Stamp); FData.Arrays['tasks'].Add(T);
    end;
    WFSet(T,'title',Trim(Title)); WFSet(T,'details',Details); WFSet(T,'assignee',Assignee);
    WFSet(T,'assignee_name',A.Get('name','')); WFSet(T,'artifact',Artifact);
    WFSet(T,'source',Source); WFSet(T,'source_id',SourceID); WFSet(T,'updated_at',Stamp);
    Result:=T.Get('id',''); OK:=True;
  finally Finish(OK); end;
end;
procedure TWorkflow.Reply(const Token,ID,Text,State: string; Progress: Integer; const Artifact: string; Returned: Boolean);
var U,T,E: TJSONObject; OK: Boolean;
begin
  Open; OK:=False;
  try
    U:=Actor(Token); T:=Find(FData.Arrays['tasks'],ID);
    if (T=nil) or not Visible(U,T) then raise EWorkflow.Create('Tarefa indisponível para este usuário');
    if (U.Get('role','')='viewer') or ((not WFManager(U)) and (T.Get('assignee','')<>U.Get('id',''))) then raise EWorkflow.Create('Sem permissão para responder a esta tarefa');
    if not ((State='pendente') or (State='em_andamento') or (State='concluida') or (State='devolvida')) then raise EWorkflow.Create('Situação inválida');
    if (Progress<0) or (Progress>100) then raise EWorkflow.Create('Progresso fora de 0 a 100');
    if Trim(Text)='' then raise EWorkflow.Create('Descreva o que foi feito e o que falta');
    if (Artifact<>'') and (T.Get('artifact','')<>'') and not SameFileName(ExpandFileName(Artifact),ExpandFileName(T.Get('artifact',''))) then
      raise EWorkflow.Create('A tarefa está associada a outro arquivo. Ajuste a associação no Planejador.');
    if Returned and ((Artifact='') or not FileExists(Artifact)) then raise EWorkflow.Create('Salve o arquivo antes de devolver a tarefa');
    if (T.Get('artifact','')='') and (Artifact<>'') then WFSet(T,'artifact',ExpandFileName(Artifact));
    if Returned then WFSet(T,'state','devolvida') else WFSet(T,'state',State);
    if State='concluida' then Progress:=100;
    WFSet(T,'progress',Int64(Progress)); WFSet(T,'updated_at',Stamp);
    E:=TJSONObject.Create; E.Add('at',Stamp); E.Add('user_id',U.Get('id','')); E.Add('user_name',U.Get('name',''));
    E.Add('text',Text); E.Add('state',T.Get('state','')); E.Add('progress',Progress); E.Add('returned',Returned); E.Add('artifact',T.Get('artifact',''));
    T.Arrays['history'].Add(E); OK:=True;
  finally Finish(OK); end;
end;
end.
