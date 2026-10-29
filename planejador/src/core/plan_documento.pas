unit plan_documento;

{ Planejador - documento do projeto: tarefas, dependencias e calendario.
  As dependencias sao validadas pelo grafo da suite CHATGPT (TAITaskGraph),
  que recusa auto-vinculo, vinculo repetido e ciclo (RFP-003). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, fgl, aiprojectduration, aitaskgraph,
  aiworkcalendar, plan_tipos;

type
  TPLListaTarefas = specialize TFPGObjectList<TPLTarefa>;

  TPLProjeto = class
  private
    FTarefas: TPLListaTarefas;
    FCalendario: TAIWorkCalendar;
    FProximo: Integer;
    FModificado: Boolean;
    function GetCount: Integer;
    function GetTarefa(I: Integer): TPLTarefa;
    function NovoId: string;
  public
    Nome: string;
    Objetivo: string;
    Inicio: TDateTime;
    constructor Create;
    destructor Destroy; override;
    procedure Limpar;
    procedure Novo(const ANome: string; AInicio: TDateTime);
    function IdExiste(const AId: string): Boolean;
    function IndiceDe(const AId: string): Integer;
    function NovaTarefa(const ANome: string; AMarco: Boolean = False;
      APosicao: Integer = -1): TPLTarefa;
    { usado na leitura do arquivo: mantem o ID gravado }
    function AdicionarTarefa(T: TPLTarefa): Integer;
    procedure ExcluirTarefa(I: Integer);
    function Mover(I, Delta: Integer): Integer;
    { texto da coluna Predecessoras: "T-0001; T-0002II+1d" }
    function DefinirPredecessoras(T: TPLTarefa; const ATexto: string;
      out Err: string): Boolean;
    function TextoPredecessoras(T: TPLTarefa): string;
    { substitui as predecessoras de T, validando IDs, repeticao e ciclo }
    function DefinirItens(T: TPLTarefa; const AItens: TAIPredecessorItems;
      out Err: string): Boolean;
    { vinculos individuais, como no Microsoft Project e no MultiProject }
    function AdicionarVinculo(const ADe, APara: string; ATipo: TAITaskLinkType;
      const ALatencia: TAITaskLag; out Err: string): Boolean;
    function RemoverVinculo(const ADe, APara: string): Boolean;
    { liga a tarefa I a seguinte da lista (Ctrl+F2) }
    function VincularProxima(I: Integer; out Err: string): Boolean;
    { remove todas as predecessoras e sucessoras da tarefa (Ctrl+Shift+F2) }
    function Desvincular(I: Integer): Integer;
    { sucessoras diretas de uma tarefa }
    function Sucessoras(const AId: string): TStringArray;
    function DefinirDuracao(T: TPLTarefa; const ATexto: string; out Err: string): Boolean;
    function TextoDuracao(T: TPLTarefa): string;
    { monta o grafo na ordem das tarefas; Err vazio = consistente }
    procedure MontarGrafo(G: TAITaskGraph; out Err: string);
    procedure MarcarModificado;
    procedure ProximoIdMinimo(N: Integer);
    property Count: Integer read GetCount;
    property Tarefas[I: Integer]: TPLTarefa read GetTarefa; default;
    property Calendario: TAIWorkCalendar read FCalendario;
    property Modificado: Boolean read FModificado write FModificado;
  end;

implementation

constructor TPLProjeto.Create;
begin
  inherited Create;
  FTarefas := TPLListaTarefas.Create(True);
  FCalendario := TAIWorkCalendar.Create('Padrão');
  Novo('Novo projeto', Date);
end;

destructor TPLProjeto.Destroy;
begin
  FTarefas.Free;
  FCalendario.Free;
  inherited Destroy;
end;

function TPLProjeto.GetCount: Integer;
begin
  Result := FTarefas.Count;
end;

function TPLProjeto.GetTarefa(I: Integer): TPLTarefa;
begin
  Result := FTarefas[I];
end;

procedure TPLProjeto.Limpar;
begin
  FTarefas.Clear;
  FProximo := 1;
  FModificado := False;
end;

procedure TPLProjeto.Novo(const ANome: string; AInicio: TDateTime);
var Ano: Integer;
begin
  Limpar;
  Nome := ANome;
  Objetivo := '';
  Inicio := Trunc(AInicio);
  Ano := YearOf(Inicio);
  FCalendario.Clear;
  FCalendario.Name := 'Padrão';
  FCalendario.SetStandard;
  FCalendario.AddBrazilianHolidays(Ano - 1, Ano + 5, False);
  FModificado := False;
end;

function TPLProjeto.NovoId: string;
begin
  repeat
    Result := Format('T-%.4d', [FProximo]);
    Inc(FProximo);
  until not IdExiste(Result);
end;

procedure TPLProjeto.ProximoIdMinimo(N: Integer);
begin
  if N > FProximo then FProximo := N;
end;

function TPLProjeto.IdExiste(const AId: string): Boolean;
begin
  Result := IndiceDe(AId) >= 0;
end;

function TPLProjeto.IndiceDe(const AId: string): Integer;
var I: Integer;
begin
  for I := 0 to FTarefas.Count - 1 do
    if SameText(FTarefas[I].Id, AId) then Exit(I);
  Result := -1;
end;

function TPLProjeto.NovaTarefa(const ANome: string; AMarco: Boolean;
  APosicao: Integer): TPLTarefa;
begin
  Result := TPLTarefa.Create(NovoId, ANome);
  Result.Marco := AMarco;
  if AMarco then Result.Duracao := AIMakeDuration(0, aduDay);
  if (APosicao < 0) or (APosicao > FTarefas.Count) then
    FTarefas.Add(Result)
  else
    FTarefas.Insert(APosicao, Result);
  MarcarModificado;
end;

function TPLProjeto.AdicionarTarefa(T: TPLTarefa): Integer;
var N: Integer;
begin
  if IdExiste(T.Id) then
    raise Exception.CreateFmt('tarefa repetida: %s', [T.Id]);
  Result := FTarefas.Add(T);
  if TryStrToInt(Copy(T.Id, 3, MaxInt), N) then ProximoIdMinimo(N + 1);
end;

procedure TPLProjeto.ExcluirTarefa(I: Integer);
var
  Id: string;
  K, J, L: Integer;
  T: TPLTarefa;
begin
  Id := FTarefas[I].Id;
  FTarefas.Delete(I);
  { remove os vinculos que apontavam para a tarefa excluida }
  for K := 0 to FTarefas.Count - 1 do
  begin
    T := FTarefas[K];
    L := 0;
    for J := 0 to High(T.Predecessoras) do
      if not SameText(T.Predecessoras[J].Id, Id) then
      begin
        T.Predecessoras[L] := T.Predecessoras[J];
        Inc(L);
      end;
    SetLength(T.Predecessoras, L);
  end;
  MarcarModificado;
end;

function TPLProjeto.Mover(I, Delta: Integer): Integer;
var J: Integer;
begin
  J := I + Delta;
  if (I < 0) or (I >= FTarefas.Count) or (J < 0) or (J >= FTarefas.Count) then Exit(I);
  FTarefas.Move(I, J);
  MarcarModificado;
  Result := J;
end;

procedure TPLProjeto.MontarGrafo(G: TAITaskGraph; out Err: string);
var I, J: Integer; T: TPLTarefa; E: string;
begin
  Err := '';
  G.Clear;
  for I := 0 to FTarefas.Count - 1 do G.AddNode(FTarefas[I].Id);
  for I := 0 to FTarefas.Count - 1 do
  begin
    T := FTarefas[I];
    for J := 0 to High(T.Predecessoras) do
      if G.AddLink(T.Predecessoras[J].Id, T.Id, T.Predecessoras[J].LinkType,
        T.Predecessoras[J].Lag, E) < 0 then
        if Err = '' then Err := Format('%s: %s', [T.Id, E]);
  end;
end;

function TPLProjeto.DefinirPredecessoras(T: TPLTarefa; const ATexto: string;
  out Err: string): Boolean;
var Itens: TAIPredecessorItems;
begin
  Result := False;
  if not AITryParsePredecessors(ATexto, PL_MINUTOS_POR_DIA, PL_MINUTOS_POR_SEMANA,
    @IdExiste, Itens, Err) then Exit;
  Result := DefinirItens(T, Itens, Err);
end;

function TPLProjeto.DefinirItens(T: TPLTarefa; const AItens: TAIPredecessorItems;
  out Err: string): Boolean;
var
  Itens: TAIPredecessorItems;
  G: TAITaskGraph;
  I, J: Integer;
  O: TPLTarefa;
  E: string;
begin
  Result := False;
  Err := '';
  Itens := Copy(AItens);
  for I := 0 to High(Itens) do
  begin
    if not IdExiste(Itens[I].Id) then
    begin
      Err := Format('tarefa inexistente: %s', [Itens[I].Id]);
      Exit;
    end;
    { grava o ID com a grafia cadastrada }
    Itens[I].Id := FTarefas[IndiceDe(Itens[I].Id)].Id;
  end;
  { valida contra os demais vinculos do projeto }
  G := TAITaskGraph.Create;
  try
    for I := 0 to FTarefas.Count - 1 do G.AddNode(FTarefas[I].Id);
    for I := 0 to FTarefas.Count - 1 do
    begin
      O := FTarefas[I];
      if O = T then Continue;
      for J := 0 to High(O.Predecessoras) do
        G.AddLink(O.Predecessoras[J].Id, O.Id, O.Predecessoras[J].LinkType,
          O.Predecessoras[J].Lag, E);
    end;
    for I := 0 to High(Itens) do
      if G.AddLink(Itens[I].Id, T.Id, Itens[I].LinkType, Itens[I].Lag, E) < 0 then
      begin
        Err := E;
        Exit;
      end;
  finally
    G.Free;
  end;
  T.Predecessoras := Itens;
  MarcarModificado;
  Result := True;
end;

function TPLProjeto.AdicionarVinculo(const ADe, APara: string; ATipo: TAITaskLinkType;
  const ALatencia: TAITaskLag; out Err: string): Boolean;
var
  I: Integer;
  T: TPLTarefa;
  Itens: TAIPredecessorItems;
begin
  Result := False;
  I := IndiceDe(APara);
  if I < 0 then begin Err := Format('tarefa inexistente: %s', [APara]); Exit; end;
  if not IdExiste(ADe) then begin Err := Format('tarefa inexistente: %s', [ADe]); Exit; end;
  T := FTarefas[I];
  Itens := Copy(T.Predecessoras);
  SetLength(Itens, Length(Itens) + 1);
  Itens[High(Itens)].Id := ADe;
  Itens[High(Itens)].LinkType := ATipo;
  Itens[High(Itens)].Lag := ALatencia;
  Result := DefinirItens(T, Itens, Err);
end;

function TPLProjeto.RemoverVinculo(const ADe, APara: string): Boolean;
var I, J, L: Integer; T: TPLTarefa;
begin
  Result := False;
  I := IndiceDe(APara);
  if I < 0 then Exit;
  T := FTarefas[I];
  L := 0;
  for J := 0 to High(T.Predecessoras) do
    if SameText(T.Predecessoras[J].Id, ADe) then Result := True
    else
    begin
      T.Predecessoras[L] := T.Predecessoras[J];
      Inc(L);
    end;
  SetLength(T.Predecessoras, L);
  if Result then MarcarModificado;
end;

function TPLProjeto.VincularProxima(I: Integer; out Err: string): Boolean;
begin
  Result := False;
  if (I < 0) or (I >= FTarefas.Count) then begin Err := 'selecione uma tarefa'; Exit; end;
  if I + 1 >= FTarefas.Count then begin Err := 'não há tarefa abaixo para vincular'; Exit; end;
  Result := AdicionarVinculo(FTarefas[I].Id, FTarefas[I + 1].Id, atlFS, AINoLag, Err);
end;

function TPLProjeto.Desvincular(I: Integer): Integer;
var Id: string; K: Integer;
begin
  Result := 0;
  if (I < 0) or (I >= FTarefas.Count) then Exit;
  Id := FTarefas[I].Id;
  Inc(Result, Length(FTarefas[I].Predecessoras));
  SetLength(FTarefas[I].Predecessoras, 0);
  for K := 0 to FTarefas.Count - 1 do
    if RemoverVinculo(Id, FTarefas[K].Id) then Inc(Result);
  if Result > 0 then MarcarModificado;
end;

function TPLProjeto.Sucessoras(const AId: string): TStringArray;
var K, J: Integer;
begin
  Result := nil;
  for K := 0 to FTarefas.Count - 1 do
    for J := 0 to High(FTarefas[K].Predecessoras) do
      if SameText(FTarefas[K].Predecessoras[J].Id, AId) then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := FTarefas[K].Id;
      end;
end;

function TPLProjeto.TextoPredecessoras(T: TPLTarefa): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to High(T.Predecessoras) do
  begin
    if Result <> '' then Result := Result + '; ';
    Result := Result + AIFormatPredecessor(T.Predecessoras[I], PL_MINUTOS_POR_DIA,
      PL_MINUTOS_POR_SEMANA);
  end;
end;

function TPLProjeto.DefinirDuracao(T: TPLTarefa; const ATexto: string; out Err: string): Boolean;
var D: TAIDuration;
begin
  Result := AITryParseDuration(ATexto, PL_MINUTOS_POR_DIA, PL_MINUTOS_POR_SEMANA, D, Err);
  if not Result then Exit;
  if D.Minutes < 0 then
  begin
    Err := 'duração negativa';
    Exit(False);
  end;
  T.Duracao := D;
  T.Marco := D.Minutes = 0;
  MarcarModificado;
end;

function TPLProjeto.TextoDuracao(T: TPLTarefa): string;
begin
  Result := AIFormatDuration(T.Duracao, PL_MINUTOS_POR_DIA, PL_MINUTOS_POR_SEMANA);
end;

procedure TPLProjeto.MarcarModificado;
begin
  FModificado := True;
end;

end.
