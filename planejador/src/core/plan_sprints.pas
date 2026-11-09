unit plan_sprints;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses SysUtils, fpjson, plan_recursos;
type
 TPLSprintItem=record TaskID: string; PendenteAnterior: Boolean; end;
 TPLSprintItems=array of TPLSprintItem;
 TPLSprint=class
 public
  ID,Nome: string; Inicio,Fim: TDateTime; Items: TPLSprintItems;
  procedure Validar;
  function Contem(const TaskID: string): Boolean;
  function Incluir(const TaskID: string; PendenteAnterior: Boolean): Boolean;
  procedure Remover(const TaskID: string);
  function ParaJSON: TJSONObject;
  procedure DeJSON(O: TJSONObject);
 end;
 TPLCustoRegistro=record Data: TDateTime; Previsto,Computado: Int64; end;
 TPLHistoricoCustos=array of TPLCustoRegistro;
implementation
procedure TPLSprint.Validar;
var I,J: Integer;
begin
 if (Trim(ID)='') or (Trim(Nome)='') then raise Exception.Create('Sprint precisa de identificação e nome');
 if (Inicio<=0) or (Fim<Inicio) or (Inicio<>Trunc(Inicio)) or (Fim<>Trunc(Fim)) or (Fim-Inicio>3660) then raise Exception.Create('Período de sprint inválido (datas inclusivas, máximo de dez anos)');
 if Length(Items)>200000 then raise Exception.Create('Muitas tarefas na sprint');
 for I:=0 to High(Items) do begin
  if Items[I].TaskID='' then raise Exception.Create('Tarefa de sprint sem identificação');
  for J:=0 to I-1 do if SameText(Items[I].TaskID,Items[J].TaskID) then raise Exception.Create('Tarefa repetida na sprint');
 end;
end;
function TPLSprint.Contem(const TaskID: string): Boolean;
var I: Integer;
begin Result:=False; for I:=0 to High(Items) do if SameText(Items[I].TaskID,TaskID) then Exit(True); end;
function TPLSprint.Incluir(const TaskID: string; PendenteAnterior: Boolean): Boolean;
var N: Integer;
begin Result:=not Contem(TaskID); if not Result then Exit; N:=Length(Items); SetLength(Items,N+1); Items[N].TaskID:=TaskID; Items[N].PendenteAnterior:=PendenteAnterior; end;
procedure TPLSprint.Remover(const TaskID: string);
var I,J: Integer;
begin for I:=High(Items) downto 0 do if SameText(Items[I].TaskID,TaskID) then begin for J:=I to High(Items)-1 do Items[J]:=Items[J+1]; SetLength(Items,Length(Items)-1); end; end;
function TPLSprint.ParaJSON: TJSONObject;
var A: TJSONArray; O: TJSONObject; I: Integer;
begin
 Validar; Result:=TJSONObject.Create; Result.Add('id',ID); Result.Add('name',Nome); Result.Add('start',PLDataISO(Inicio)); Result.Add('end',PLDataISO(Fim)); A:=TJSONArray.Create;
 for I:=0 to High(Items) do begin O:=TJSONObject.Create; O.Add('task_id',Items[I].TaskID); O.Add('carryover',Items[I].PendenteAnterior); A.Add(O); end; Result.Add('tasks',A);
end;
procedure TPLSprint.DeJSON(O: TJSONObject);
var A: TJSONArray; I: Integer;
begin
 ID:=O.Get('id',''); Nome:=O.Get('name',''); Inicio:=PLDataLer(O.Get('start','')); Fim:=PLDataLer(O.Get('end',''));
 A:=O.Get('tasks',TJSONArray(nil)); SetLength(Items,0);
 if A<>nil then begin if A.Count>200000 then raise Exception.Create('Muitas tarefas na sprint'); SetLength(Items,A.Count); for I:=0 to A.Count-1 do begin Items[I].TaskID:=A.Objects[I].Get('task_id',''); Items[I].PendenteAnterior:=A.Objects[I].Get('carryover',False); end; end;
 Validar;
end;
end.
