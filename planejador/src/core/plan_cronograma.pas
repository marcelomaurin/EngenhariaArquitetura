unit plan_cronograma;

{ Planejador - calculo do cronograma pelo caminho critico, usando o
  agendador TAICPMScheduler da suite CHATGPT. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, aitaskgraph, aicpmscheduler, plan_tipos, plan_documento;

type
  TPLCronograma = class
  private
    FGrafo: TAITaskGraph;
    FAgenda: TAICPMScheduler;
    FValido: Boolean;
    FErro: string;
    FAvisos: TStringList;
    FCriticas: Integer;
    function GetResultado(I: Integer): TAICPMResult;
    function GetTermino: TDateTime;
    function GetInicio: TDateTime;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Calcular(Doc: TPLProjeto);
    property Valido: Boolean read FValido;
    property Erro: string read FErro;
    property Avisos: TStringList read FAvisos;
    property Criticas: Integer read FCriticas;
    property Inicio: TDateTime read GetInicio;
    property Termino: TDateTime read GetTermino;
    property Resultado[I: Integer]: TAICPMResult read GetResultado;
    property Grafo: TAITaskGraph read FGrafo;
  end;

implementation

constructor TPLCronograma.Create;
begin
  inherited Create;
  FGrafo := TAITaskGraph.Create;
  FAgenda := TAICPMScheduler.Create;
  FAvisos := TStringList.Create;
end;

destructor TPLCronograma.Destroy;
begin
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
  FCriticas := 0;
  FAgenda.Clear;
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
  FValido := True;
end;

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
