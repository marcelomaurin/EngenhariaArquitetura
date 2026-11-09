unit plan_apontamentos;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses SysUtils,fpjson,plan_recursos;
type
 TPLApontamento=record ID,TaskID,RecursoID,Notas: string; Data: TDateTime; Minutos: Integer; end;
 TPLApontamentos=array of TPLApontamento;
procedure PLValidarApontamento(const A: TPLApontamento);
function PLApontamentoJSON(const A: TPLApontamento): TJSONObject;
function PLApontamentoLer(O: TJSONObject): TPLApontamento;
implementation
procedure PLValidarApontamento(const A: TPLApontamento);
begin
 if (Trim(A.ID)='') or (A.TaskID='') or (A.RecursoID='') then raise Exception.Create('Apontamento precisa de identificação, tarefa e usuário/recurso');
 if (A.Data<=0) or (A.Data<>Trunc(A.Data)) then raise Exception.Create('Informe a data do trabalho');
 if PLDataLer(PLDataISO(A.Data))<>A.Data then raise Exception.Create('Data do apontamento inválida');
 if (A.Minutos<1) or (A.Minutos>1440) then raise Exception.Create('Informe entre 1 minuto e 24 horas por apontamento diário');
 if Length(A.Notas)>10000 then raise Exception.Create('Observação do apontamento muito longa');
end;
function PLApontamentoJSON(const A: TPLApontamento): TJSONObject;
begin
 PLValidarApontamento(A); Result:=TJSONObject.Create; Result.Add('id',A.ID); Result.Add('task_id',A.TaskID); Result.Add('resource_id',A.RecursoID); Result.Add('date',PLDataISO(A.Data)); Result.Add('minutes',A.Minutos); Result.Add('notes',A.Notas);
end;
function PLApontamentoLer(O: TJSONObject): TPLApontamento;
begin
 Result.ID:=O.Get('id',''); Result.TaskID:=O.Get('task_id',''); Result.RecursoID:=O.Get('resource_id',''); Result.Data:=PLDataLer(O.Get('date','')); Result.Minutos:=O.Get('minutes',0); Result.Notas:=O.Get('notes',''); PLValidarApontamento(Result);
end;
end.
