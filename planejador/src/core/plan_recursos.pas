unit plan_recursos;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Math, DateUtils, fpjson, aiworkcalendar, ea_links;
type
  TPLRecursoTipo=(prtPessoa,prtEquipe,prtEquipamento,prtMaterial,prtArquivo);
  TPLDirecao=(prdUso,prdEntrada,prdSaida);
  TPLAlocacao=record
    RecursoID: string; Unidades: Double; Direcao: TPLDirecao;
    CustoUnitarioCentavos: Int64; Contabilizado: Boolean;
  end;
  TPLCustoItem=record Nome: string; Quantidade: Double; ValorUnitarioCentavos: Int64; Contabilizado: Boolean; end;
  TPLCustos=array of TPLCustoItem;
  TPLAlocacoes=array of TPLAlocacao;
  TPLAusencia=record De,Ate: TDateTime; end;
  TPLAusencias=array of TPLAusencia;
  TPLRecurso=class
  public
    ID,Nome,UsuarioID,Link,Notas: string;
    Tipo: TPLRecursoTipo;
    Capacidade: Double;
    PrecoCentavos: Int64;
    CalendarioProjeto: Boolean;
    Calendario: TAIWorkCalendar;
    DisponivelDe,DisponivelAte: TDateTime;
    Ausencias: TPLAusencias;
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPLRecurso);
    procedure Validar;
    function MontarCalendario(Project: TAIWorkCalendar): TAIWorkCalendar;
    function Disponivel(Project,Effective: TAIWorkCalendar; A,B: TDateTime; Elapsed: Boolean): Boolean;
    function ParaJSON: TJSONObject;
    procedure DeJSON(O: TJSONObject);
  end;
const
  PL_RECURSO_TIPOS: array[TPLRecursoTipo] of string=('Pessoa','Equipe','Equipamento','Material','Arquivo / link');
  PL_RECURSO_CODIGOS: array[TPLRecursoTipo] of string=('person','team','equipment','material','file');
  PL_DIRECOES: array[TPLDirecao] of string=('Uso','Entrada (input)','Saída (output)');
  PL_DIRECAO_CODIGOS: array[TPLDirecao] of string=('use','input','output');
function PLDataISO(D: TDateTime): string;
function PLDataLer(const S: string): TDateTime;
implementation
function PLDataISO(D: TDateTime): string;
begin if D=0 then Result:='' else Result:=FormatDateTime('yyyy-mm-dd',D); end;
function PLDataLer(const S: string): TDateTime;
var Y,M,D: Integer;
begin
  Result:=0; if S='' then Exit;
  if (Length(S)<>10) or not TryStrToInt(Copy(S,1,4),Y) or not TryStrToInt(Copy(S,6,2),M) or not TryStrToInt(Copy(S,9,2),D) then raise Exception.Create('Data inválida: '+S);
  if not TryEncodeDate(Y,M,D,Result) then raise Exception.Create('Data inválida: '+S);
  if (Result<=0) or (PLDataISO(Result)<>S) then raise Exception.Create('Data inválida: '+S);
end;
constructor TPLRecurso.Create;
begin inherited Create; Tipo:=prtPessoa; Capacidade:=1; CalendarioProjeto:=True; Calendario:=TAIWorkCalendar.Create; Calendario.SetStandard; end;
destructor TPLRecurso.Destroy;
begin Calendario.Free; inherited Destroy; end;
procedure TPLRecurso.Assign(Source: TPLRecurso);
begin
 ID:=Source.ID; Nome:=Source.Nome; UsuarioID:=Source.UsuarioID; Link:=Source.Link; Notas:=Source.Notas; Tipo:=Source.Tipo;
 PrecoCentavos:=Source.PrecoCentavos;
 Capacidade:=Source.Capacidade; CalendarioProjeto:=Source.CalendarioProjeto; Calendario.Assign(Source.Calendario);
 DisponivelDe:=Source.DisponivelDe; DisponivelAte:=Source.DisponivelAte; Ausencias:=Copy(Source.Ausencias);
end;
procedure TPLRecurso.Validar;
var I: Integer;
begin
 if (PrecoCentavos<0) or (PrecoCentavos>1000000000000) then raise Exception.Create('Preço do recurso inválido');
 if (Trim(ID)='') or (Trim(Nome)='') then raise Exception.Create('Recurso precisa de identificação e nome');
 if IsNan(Capacidade) or IsInfinite(Capacidade) or (Capacidade<=0) or (Capacidade>10000) then raise Exception.Create('Capacidade deve ser positiva e finita');
 if (DisponivelDe<0) or (DisponivelAte<0) or ((DisponivelDe>0) and (DisponivelAte>0) and (DisponivelDe>DisponivelAte)) then raise Exception.Create('Período de disponibilidade inválido');
 if (Tipo=prtArquivo) and not EAValidLink(Link) then raise Exception.Create('Informe um caminho ou link HTTP/HTTPS válido');
 if Length(Ausencias)>1000 then raise Exception.Create('Muitos períodos de ausência');
 for I:=0 to High(Ausencias) do
  if (Ausencias[I].De<=0) or (Ausencias[I].Ate<Ausencias[I].De) or (Ausencias[I].Ate-Ausencias[I].De>3660) then raise Exception.Create('Ausência inválida (máximo de dez anos por período)');
end;
function TPLRecurso.MontarCalendario(Project: TAIWorkCalendar): TAIWorkCalendar;
var I,D: Integer;
begin
 Result:=TAIWorkCalendar.Create;
 if CalendarioProjeto then Result.Assign(Project) else Result.Assign(Calendario);
 for I:=0 to High(Ausencias) do
  for D:=Trunc(Ausencias[I].De) to Trunc(Ausencias[I].Ate) do Result.AddHoliday(D,'Indisponível');
end;
function TPLRecurso.Disponivel(Project,Effective: TAIWorkCalendar; A,B: TDateTime; Elapsed: Boolean): Boolean;
var Day,J,K: Integer; Segments: TAIWorkIntervals; E: TAICalendarException; S,F,Low,HighDate: TDateTime; Expected: Int64;
begin
 Result:=True; if (B<=A) or (Tipo in [prtMaterial,prtArquivo]) then Exit;
 Low:=A; HighDate:=B;
 if (DisponivelDe>0) and (A<DisponivelDe) then begin
   if Elapsed or (Project.WorkingMinutesBetween(A,Min(B,DisponivelDe))>0) then Exit(False);
 end;
 if (DisponivelAte>0) and (B>DisponivelAte+1) then begin
   if Elapsed or (Project.WorkingMinutesBetween(Max(A,DisponivelAte+1),B)>0) then Exit(False);
 end;
 for Day:=Trunc(Low) to Trunc(HighDate) do begin
  if Elapsed then begin SetLength(Segments,1); Segments[0].StartMin:=0; Segments[0].EndMin:=1440; end
  else begin
   Segments:=Project.WeekDay(DayOfWeek(Day));
   for K:=0 to Project.ExceptionCount-1 do begin E:=Project.ExceptionAt(K); if E.Day=Day then begin Segments:=E.Intervals; Break; end; end;
  end;
  for J:=0 to High(Segments) do begin
    S:=Max(A,Day+Segments[J].StartMin/1440); F:=Min(B,Day+Segments[J].EndMin/1440);
    if F<=S then Continue;
    Expected:=Round((F-S)*1440);
    if Effective.WorkingMinutesBetween(S,F)<Expected then Exit(False);
  end;
 end;
end;
function TPLRecurso.ParaJSON: TJSONObject;
var Arr: TJSONArray; O: TJSONObject; I: Integer;
begin
 Result:=TJSONObject.Create; Result.Add('id',ID); Result.Add('name',Nome); Result.Add('kind',PL_RECURSO_CODIGOS[Tipo]);
 Result.Add('user_id',UsuarioID); Result.Add('link',Link); Result.Add('notes',Notas); Result.Add('capacity',Capacidade);
 Result.Add('unit_cost_cents',PrecoCentavos);
 Result.Add('project_calendar',CalendarioProjeto); Result.Add('calendar',Calendario.ToJSON);
 Result.Add('available_from',PLDataISO(DisponivelDe)); Result.Add('available_until',PLDataISO(DisponivelAte));
 Arr:=TJSONArray.Create; for I:=0 to High(Ausencias) do begin O:=TJSONObject.Create; O.Add('from',PLDataISO(Ausencias[I].De)); O.Add('until',PLDataISO(Ausencias[I].Ate)); Arr.Add(O); end;
 Result.Add('absences',Arr);
end;
procedure TPLRecurso.DeJSON(O: TJSONObject);
var I: Integer; K: TPLRecursoTipo; Found: Boolean; Arr: TJSONArray;
begin
 ID:=O.Get('id',''); Nome:=O.Get('name',''); Found:=False;
 for K:=Low(K) to High(K) do if O.Get('kind','')=PL_RECURSO_CODIGOS[K] then begin Tipo:=K; Found:=True; end;
 if not Found then raise Exception.Create('Tipo de recurso desconhecido');
 PrecoCentavos:=O.Get('unit_cost_cents',Int64(0));
 UsuarioID:=O.Get('user_id',''); Link:=O.Get('link',''); Notas:=O.Get('notes',''); Capacidade:=O.Get('capacity',1.0);
 CalendarioProjeto:=O.Get('project_calendar',True); if O.Find('calendar')<>nil then Calendario.FromJSON(O.Objects['calendar']);
 DisponivelDe:=PLDataLer(O.Get('available_from','')); DisponivelAte:=PLDataLer(O.Get('available_until',''));
 Arr:=O.Get('absences',TJSONArray(nil)); SetLength(Ausencias,0);
 if Arr<>nil then begin
  if Arr.Count>1000 then raise Exception.Create('Muitas ausências'); SetLength(Ausencias,Arr.Count);
  for I:=0 to Arr.Count-1 do begin Ausencias[I].De:=PLDataLer(Arr.Objects[I].Get('from','')); Ausencias[I].Ate:=PLDataLer(Arr.Objects[I].Get('until','')); end;
 end;
 Validar;
end;
end.
