unit plan_cronograma;

{ Planejador - calculo do cronograma pelo caminho critico, usando o
  agendador TAICPMScheduler da suite CHATGPT. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, aitaskgraph, aicpmscheduler, plan_tipos, plan_documento, plan_recursos, airesourceload, aiworkcalendar;

type
  TPLCronograma = class
  private
    FGrafo: TAITaskGraph;
    FAgenda: TAICPMScheduler;
    FValido: Boolean;
    FErro: string;
    FAvisos: TStringList;
    FCriticas: Integer;
    FCarga: TAIResourceLoad;
    FCalendarios: array of TAIWorkCalendar;
    procedure LimparCarga;
    procedure CalcularCarga(Doc: TPLProjeto);
  private
    FConflitos: array of Boolean;
    function GetConflito(I: Integer): Boolean;
    function GetResultado(I: Integer): TAICPMResult;
    function GetTermino: TDateTime;
    function GetInicio: TDateTime;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Calcular(Doc: TPLProjeto);
    property Conflito[I: Integer]: Boolean read GetConflito;
    property Valido: Boolean read FValido;
    property Erro: string read FErro;
    property Avisos: TStringList read FAvisos;
    property Criticas: Integer read FCriticas;
    property Inicio: TDateTime read GetInicio;
    property Termino: TDateTime read GetTermino;
    property Resultado[I: Integer]: TAICPMResult read GetResultado;
    property Grafo: TAITaskGraph read FGrafo;
    property Carga: TAIResourceLoad read FCarga;
  end;

implementation

procedure TPLCronograma.LimparCarga;
var I: Integer;
begin
 FCarga.Clear; for I:=0 to High(FCalendarios) do FCalendarios[I].Free; SetLength(FCalendarios,0);
end;
procedure TPLCronograma.CalcularCarga(Doc: TPLProjeto);
var I,J,K,ExecutorIndex: Integer; R: TPLRecurso; Kind: TAIResourceKind; ExplicitExecutor: Boolean; A: TAICPMResult;
  procedure Add(TaskIndex,ResourceIndex: Integer; Units: Double);
  var Res: TPLRecurso; Schedule: TAICPMResult;
  begin
   Res:=Doc.Recursos[ResourceIndex]; Schedule:=FAgenda.Results[TaskIndex];
   FCarga.AddAssignment(TaskIndex,ResourceIndex,Units,Schedule.Start,Schedule.Finish);
   if not Res.Disponivel(Doc.Calendario,FCalendarios[ResourceIndex],Schedule.Start,Schedule.Finish,Doc[TaskIndex].Duracao.Elapsed) then begin
    FConflitos[TaskIndex]:=True;
    FAvisos.Add('Indisponibilidade: '+Doc[TaskIndex].Id+' — '+Res.Nome+' (jornada, período ou ausência)');
   end;
  end;
begin
 for I:=0 to Doc.Count-1 do Doc.RecursoExecutor(Doc[I]);
 Doc.ValidarRecursos; SetLength(FCalendarios,Doc.Recursos.Count);
 for I:=0 to Doc.Recursos.Count-1 do begin
  R:=Doc.Recursos[I]; Kind:=arkWork;
  if R.Tipo=prtMaterial then Kind:=arkMaterial else if R.Tipo=prtArquivo then Kind:=arkCost;
  if R.Tipo in [prtPessoa,prtEquipe,prtEquipamento] then FCalendarios[I]:=R.MontarCalendario(Doc.Calendario) else FCalendarios[I]:=nil;
  FCarga.AddResource(AINewResource(R.ID,R.Nome,R.Capacidade,Kind,FCalendarios[I]));
 end;
 for I:=0 to Doc.Count-1 do begin
  ExecutorIndex:=Doc.RecursoExecutor(Doc[I]); ExplicitExecutor:=False;
  for J:=0 to High(Doc[I].Alocacoes) do begin
   K:=Doc.RecursoIndice(Doc[I].Alocacoes[J].RecursoID); if K=ExecutorIndex then ExplicitExecutor:=True;
   Add(I,K,Doc[I].Alocacoes[J].Unidades);
  end;
  if (ExecutorIndex>=0) and not ExplicitExecutor then Add(I,ExecutorIndex,1);
 end;
 FCarga.Compute;
 for I:=0 to FCarga.OverloadCount-1 do FAvisos.Add('Sobrecarga de recurso: '+FCarga.OverloadMessage(I));
 for I:=0 to Doc.Count-1 do FConflitos[I]:=FConflitos[I] or FCarga.TaskOverloaded(I);
end;

constructor TPLCronograma.Create;
begin
  inherited Create;
  FGrafo := TAITaskGraph.Create;
  FCarga:=TAIResourceLoad.Create;
  FAgenda := TAICPMScheduler.Create;
  FAvisos := TStringList.Create;
end;

destructor TPLCronograma.Destroy;
begin
  LimparCarga; FCarga.Free;
  FAvisos.Free;
  FAgenda.Free;
  FGrafo.Free;
  inherited Destroy;
end;

procedure TPLCronograma.Calcular(Doc: TPLProjeto);
var
  I: Integer;
  T: TAICPMTask;
  E: string;
begin
  FValido := False;
  FErro := '';
  FAvisos.Clear;
  SetLength(FConflitos,Doc.Count);
  for I:=0 to Doc.Count-1 do FConflitos[I]:=False;
  FCriticas := 0;
  FAgenda.Clear;
  LimparCarga;
  Doc.MontarGrafo(FGrafo, E);
  if E <> '' then
  begin
    FErro := E;
    Exit;
  end;
  for I := 0 to Doc.Count - 1 do
  begin
    T := AINewCPMTask(Doc[I].Id, Doc[I].Duracao.Minutes);
    T.Elapsed := Doc[I].Duracao.Elapsed;
    if Doc[I].InicioSolicitado>0 then begin
      T.Constraint:=actSNET; T.ConstraintDate:=Doc[I].InicioSolicitado;
    end;
    FAgenda.AddTask(T);
  end;
  FAgenda.ProjectCalendar := Doc.Calendario;
  FAgenda.Graph := FGrafo;
  FAgenda.ProjectStart := Doc.Inicio;
  try
    FAgenda.Run;
  except
    on Ex: Exception do
    begin
      FErro := Ex.Message;
      Exit;
    end;
  end;
  for I := 0 to FAgenda.WarningCount - 1 do
    FAvisos.Add(FAgenda.Warnings[I].Message);
  for I := 0 to Doc.Count - 1 do
    if FAgenda.Results[I].Critical then Inc(FCriticas);
  try CalcularCarga(Doc); except on Ex: Exception do begin FErro:=Ex.Message; Exit; end; end;
  FValido := True;
end;

function TPLCronograma.GetConflito(I: Integer): Boolean;
begin Result:=(I>=0) and (I<Length(FConflitos)) and FConflitos[I]; end;

function TPLCronograma.GetResultado(I: Integer): TAICPMResult;
begin
  Result := FAgenda.Results[I];
end;

function TPLCronograma.GetTermino: TDateTime;
begin
  Result := FAgenda.ProjectFinish;
end;

function TPLCronograma.GetInicio: TDateTime;
begin
  Result := FAgenda.ProjectStart;
end;

end.
