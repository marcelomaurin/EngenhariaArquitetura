unit plan_tipos;

{ Planejador - tipos basicos: tarefa, aplicativo responsavel e situacao.
  Parte da plataforma EngenhariaArquitetura (docs/Planejador.md). }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, aiprojectduration, aitaskgraph;

type
  { aplicativo da plataforma que executa a tarefa (RFP-004) }
  TPLAplicativo = (plaNenhum, plaCAD2D, plaMaquete3D, plaCriadorCenas,
    plaEletrica3D, plaSimuEletrica, plaSimuTubulacoes);

  TPLSituacao = (plsAFazer, plsEmAndamento, plsConcluida);

  TPLTarefa = class
  public
    Id: string;
    Nome: string;
    Responsavel: string;
    Notas: string;
    Duracao: TAIDuration;
    Marco: Boolean;
    Aplicativo: TPLAplicativo;
    Situacao: TPLSituacao;
    Progresso: Integer;               // 0..100
    Predecessoras: TAIPredecessorItems;
    constructor Create(const AId, ANome: string);
    procedure Assign(Source: TPLTarefa);
  end;

const
  { nomes exibidos na tela }
  PL_APLICATIVO_NOME: array[TPLAplicativo] of string = (
    'Nenhum', 'CAD Arquitetônico 2D', 'Maquete 3D', 'Criador de Cenas',
    'Elétrica 3D', 'SimuEletrica', 'SimuTubulações');
  { codigos usados no contrato de tarefa (docs/Integracoes.md) }
  PL_APLICATIVO_CODIGO: array[TPLAplicativo] of string = (
    '', 'CAD2D', 'Maquete3D', 'CriadorCenas', 'Eletrica3D', 'SimuEletrica',
    'SimuTubulacoes');

  PL_SITUACAO_NOME: array[TPLSituacao] of string = (
    'A fazer', 'Em andamento', 'Concluída');
  PL_SITUACAO_CODIGO: array[TPLSituacao] of string = (
    'a_fazer', 'em_andamento', 'concluida');

  PL_MINUTOS_POR_DIA = AI_DEFAULT_MINUTES_PER_DAY;    // 8 h
  PL_MINUTOS_POR_SEMANA = AI_DEFAULT_MINUTES_PER_WEEK; // 40 h

function PLAplicativoDeCodigo(const S: string): TPLAplicativo;
function PLSituacaoDeCodigo(const S: string): TPLSituacao;

implementation

function PLAplicativoDeCodigo(const S: string): TPLAplicativo;
var A: TPLAplicativo;
begin
  for A := Low(A) to High(A) do
    if SameText(Trim(S), PL_APLICATIVO_CODIGO[A]) then Exit(A);
  Result := plaNenhum;
end;

function PLSituacaoDeCodigo(const S: string): TPLSituacao;
var A: TPLSituacao;
begin
  for A := Low(A) to High(A) do
    if SameText(Trim(S), PL_SITUACAO_CODIGO[A]) then Exit(A);
  Result := plsAFazer;
end;

constructor TPLTarefa.Create(const AId, ANome: string);
begin
  inherited Create;
  Id := AId;
  Nome := ANome;
  Duracao := AIMakeDuration(PL_MINUTOS_POR_DIA, aduDay);
  Aplicativo := plaNenhum;
  Situacao := plsAFazer;
  Progresso := 0;
  Predecessoras := nil;
end;

procedure TPLTarefa.Assign(Source: TPLTarefa);
begin
  Id := Source.Id;
  Nome := Source.Nome;
  Responsavel := Source.Responsavel;
  Notas := Source.Notas;
  Duracao := Source.Duracao;
  Marco := Source.Marco;
  Aplicativo := Source.Aplicativo;
  Situacao := Source.Situacao;
  Progresso := Source.Progresso;
  Predecessoras := Copy(Source.Predecessoras);
end;

end.
