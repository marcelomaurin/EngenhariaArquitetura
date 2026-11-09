unit plan_executor;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses SysUtils, fpjson, plan_tipos;
function PLRotuloExecutor(U: TJSONObject): string;
function PLResolverExecutor(T: TPLTarefa; Users: TJSONArray): Boolean;
implementation
function PLRotuloExecutor(U: TJSONObject): string;
begin Result:=U.Get('name','')+' ('+U.Get('login','')+')'; end;
function PLResolverExecutor(T: TPLTarefa; Users: TJSONArray): Boolean;
var I,Pick,Admin: Integer; U: TJSONObject; Old: string;
begin
  Result:=False; Pick:=-1; Admin:=-1;
  for I:=0 to Users.Count-1 do begin
    U:=Users.Objects[I];
    if (Admin<0) and U.Get('active',False) and (U.Get('role','')='admin') then Admin:=I;
    if ((T.ExecutorID<>'') and (T.ExecutorID=U.Get('id',''))) or
       ((T.ExecutorID='') and (Trim(T.Responsavel)<>'') and
       (SameText(T.Responsavel,U.Get('login','')) or (T.Responsavel=PLRotuloExecutor(U)))) then Pick:=I;
  end;
  if (Pick<0) and (Trim(T.Responsavel)='') and (T.ExecutorID='') then Pick:=Admin;
  if Pick<0 then Exit;
  U:=Users.Objects[Pick];
  Old:=T.ExecutorID+#1+T.ExecutorNome+#1+T.Responsavel;
  T.ExecutorID:=U.Get('id',''); T.ExecutorNome:=U.Get('name',''); T.Responsavel:=U.Get('login','');
  Result:=Old<>(T.ExecutorID+#1+T.ExecutorNome+#1+T.Responsavel);
end;
end.
