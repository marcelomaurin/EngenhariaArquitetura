unit plan_documento;

{ Planejador - documento do projeto: tarefas, dependencias e calendario.
  As dependencias sao validadas pelo grafo da suite CHATGPT (TAITaskGraph),
  que recusa auto-vinculo, vinculo repetido e ciclo (RFP-003). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, Math, ea_links, ea_money, fgl, aiprojectduration, aitaskgraph,
  aiworkcalendar, plan_tipos, plan_recursos, plan_sprints, plan_apontamentos, fpjson;

type
  TPLListaTarefas = specialize TFPGObjectList<TPLTarefa>;

  TPLListaRecursos = specialize TFPGObjectList<TPLRecurso>;

  TPLListaSprints = specialize TFPGObjectList<TPLSprint>;

  TPLProjeto = class
  private
    FTarefas: TPLListaTarefas;
    FRecursos: TPLListaRecursos;
    FSprints: TPLListaSprints;
    FCalendario: TAIWorkCalendar;
    FProximo: Integer;
    FModificado: Boolean;
    function GetCount: Integer;
    function GetTarefa(I: Integer): TPLTarefa;
    function NovoId: string;
  public
    Nome: string;
    Objetivo: string;
    OrcamentoFixado: Boolean;
    OrcamentoCentavos: Int64;
    HistoricoCustos: TPLHistoricoCustos;
    Apontamentos: TPLApontamentos;
    Inicio: TDateTime;
    constructor Create;
    destructor Destroy; override;
    procedure Limpar;
    { troca todos os dados sem alocacoes; usado para carregar JSON com seguranca }
    procedure TrocarCom(Outro: TPLProjeto);
    { validacao integral antes de aplicar a edicao pelo painel }
    function AplicarEdicaoTarefa(T: TPLTarefa;
      const ANome, ADuracao, APredecessoras, AResponsavel, ANotas: string;
      AAplicativo: TPLAplicativo; ASituacao: TPLSituacao; AProgresso: Integer;
      out Err: string): Boolean;
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
    function RecursoIndice(const ID: string): Integer;
    function AdicionarRecurso(R: TPLRecurso): Integer;
    function NovoRecurso: TPLRecurso;
    procedure ExcluirRecurso(I: Integer);
    procedure ValidarRecursos;
    function CustoTarefa(T: TPLTarefa; SomenteContabilizado: Boolean=True): Int64;
    function CustoProjeto(SomenteContabilizado: Boolean=True): Int64;
    function CustoPrevistoProjeto: Int64;
    function CustoComputadoProjeto: Int64;
    function RegistrarCustos(Data: TDateTime): Boolean;
    function NovaSprint(const ANome: string; AInicio,AFim: TDateTime): TPLSprint;
    procedure AdicionarSprint(S: TPLSprint);
    procedure ValidarAcompanhamento;
    procedure ValidarApontamentos;
    function ApontamentoIndice(const AID: string): Integer;
    function SalvarApontamento(const AID,TaskID,ResourceID: string; AData: TDateTime; Minutos: Integer; const Notas: string): string;
    procedure ExcluirApontamento(const AID: string);
    property Sprints: TPLListaSprints read FSprints;
    procedure ValidarAlocacoes(const Itens: TPLAlocacoes);
    procedure DefinirAlocacoes(T: TPLTarefa; const Itens: TPLAlocacoes);
    function RecursoExecutor(T: TPLTarefa): Integer;
    function ArquivosTarefa(T: TPLTarefa; const BaseFile: string): TJSONArray;
    procedure ImportarArquivos(T: TPLTarefa; Files: TJSONArray);
    procedure DefinirArquivos(T: TPLTarefa; Files: TJSONArray);
    property Recursos: TPLListaRecursos read FRecursos;
    procedure ProximoIdMinimo(N: Integer);
    property Count: Integer read GetCount;
    property Tarefas[I: Integer]: TPLTarefa read GetTarefa; default;
    property Calendario: TAIWorkCalendar read FCalendario;
    property Modificado: Boolean read FModificado write FModificado;
  end;

implementation

function TPLProjeto.CustoPrevistoProjeto: Int64;
begin if OrcamentoFixado then Result:=OrcamentoCentavos else Result:=CustoProjeto(False); end;
function TPLProjeto.CustoComputadoProjeto: Int64;
begin Result:=CustoProjeto(True); end;
function TPLProjeto.RegistrarCustos(Data: TDateTime): Boolean;
var I,N: Integer; Entry: TPLCustoRegistro;
begin
 Data:=Trunc(Data); if Data<=0 then raise Exception.Create('Data de apuração inválida');
 Entry.Data:=Data; Entry.Previsto:=CustoPrevistoProjeto; Entry.Computado:=CustoComputadoProjeto;
 for I:=0 to High(HistoricoCustos) do if HistoricoCustos[I].Data=Data then begin
  Result:=(HistoricoCustos[I].Previsto<>Entry.Previsto) or (HistoricoCustos[I].Computado<>Entry.Computado);
  if Result then begin HistoricoCustos[I]:=Entry; MarcarModificado; end; Exit;
 end;
 if Length(HistoricoCustos)>=50000 then raise Exception.Create('Limite de apurações atingido');
 N:=Length(HistoricoCustos); SetLength(HistoricoCustos,N+1); I:=N;
 while (I>0) and (HistoricoCustos[I-1].Data>Data) do begin HistoricoCustos[I]:=HistoricoCustos[I-1]; Dec(I); end;
 HistoricoCustos[I]:=Entry; MarcarModificado; Result:=True;
end;
function TPLProjeto.NovaSprint(const ANome: string; AInicio,AFim: TDateTime): TPLSprint;
var G: TGUID;
begin
 Result:=TPLSprint.Create; CreateGUID(G); Result.ID:='SP-'+GUIDToString(G); Result.Nome:=Trim(ANome); Result.Inicio:=Trunc(AInicio); Result.Fim:=Trunc(AFim);
 try AdicionarSprint(Result); except Result.Free; raise; end;
end;
procedure TPLProjeto.AdicionarSprint(S: TPLSprint);
var I: Integer;
begin
 S.Validar; if FSprints.Count>=5000 then raise Exception.Create('Muitas sprints');
 for I:=0 to FSprints.Count-1 do begin
  if SameText(FSprints[I].ID,S.ID) then raise Exception.Create('Sprint repetida');
  if (FSprints[I].Inicio=S.Inicio) and (FSprints[I].Fim=S.Fim) then raise Exception.Create('Já existe uma sprint neste período');
 end;
 FSprints.Add(S); MarcarModificado;
end;
function TPLProjeto.ApontamentoIndice(const AID: string): Integer;
var I: Integer;
begin Result:=-1; for I:=0 to High(Apontamentos) do if SameText(Apontamentos[I].ID,AID) then Exit(I); end;
procedure TPLProjeto.ValidarApontamentos;
var IDs,Days: TStringList; I,K,J,Minutes: Integer; Key: string;
begin
 if Length(Apontamentos)>100000 then raise Exception.Create('Muitos apontamentos no projeto');
 IDs:=TStringList.Create; Days:=TStringList.Create;
 try
  IDs.Sorted:=True; IDs.CaseSensitive:=False; Days.Sorted:=True; Days.CaseSensitive:=False;
  for I:=0 to High(Apontamentos) do begin
   PLValidarApontamento(Apontamentos[I]);
   if IDs.IndexOf(Apontamentos[I].ID)>=0 then raise Exception.Create('Apontamento com identificação repetida'); IDs.Add(Apontamentos[I].ID);
   if IndiceDe(Apontamentos[I].TaskID)<0 then raise Exception.Create('Apontamento referencia tarefa inexistente');
   K:=RecursoIndice(Apontamentos[I].RecursoID); if (K<0) then raise Exception.Create('Usuário/recurso do apontamento não encontrado');
   if FRecursos[K].Tipo<>prtPessoa then raise Exception.Create('Horas por usuário devem ser vinculadas a uma pessoa');
   Key:=FRecursos[K].ID+#9+PLDataISO(Apontamentos[I].Data); J:=Days.IndexOf(Key);
   Minutes:=Apontamentos[I].Minutos;
   if J>=0 then begin Inc(Minutes,PtrInt(Days.Objects[J])); Days.Objects[J]:=TObject(PtrInt(Minutes)); end else Days.AddObject(Key,TObject(PtrInt(Minutes)));
   if Minutes>1440 then raise Exception.Create('A soma diária de horas de um usuário não pode ultrapassar 24 horas');
  end;
 finally IDs.Free; Days.Free; end;
end;
function TPLProjeto.SalvarApontamento(const AID,TaskID,ResourceID: string; AData: TDateTime; Minutos: Integer; const Notas: string): string;
var Entry,Backup: TPLApontamento; I,N: Integer; G: TGUID; IsNew: Boolean;
begin
 I:=ApontamentoIndice(AID); IsNew:=AID=''; if not IsNew and (I<0) then raise Exception.Create('Apontamento não encontrado');
 Entry.ID:=AID; if IsNew then begin CreateGUID(G); Entry.ID:='AP-'+GUIDToString(G); end;
 Entry.TaskID:=TaskID; Entry.RecursoID:=ResourceID; Entry.Data:=Trunc(AData); Entry.Minutos:=Minutos; Entry.Notas:=Notas; PLValidarApontamento(Entry);
 N:=Length(Apontamentos); if IsNew then begin I:=N; SetLength(Apontamentos,N+1); end else Backup:=Apontamentos[I];
 Apontamentos[I]:=Entry;
 try ValidarApontamentos; except if IsNew then SetLength(Apontamentos,N) else Apontamentos[I]:=Backup; raise; end;
 Result:=Entry.ID; MarcarModificado;
end;
procedure TPLProjeto.ExcluirApontamento(const AID: string);
var I,J: Integer;
begin I:=ApontamentoIndice(AID); if I<0 then raise Exception.Create('Apontamento não encontrado'); for J:=I to High(Apontamentos)-1 do Apontamentos[J]:=Apontamentos[J+1]; SetLength(Apontamentos,Length(Apontamentos)-1); MarcarModificado; end;

procedure TPLProjeto.ValidarAcompanhamento;
var I,J,K: Integer;
begin
 ValidarApontamentos;
 if (OrcamentoCentavos<0) or (OrcamentoCentavos>9000000000000000) then raise Exception.Create('Orçamento previsto inválido');
 if Length(HistoricoCustos)>50000 then raise Exception.Create('Muitas apurações de custos');
 for I:=0 to High(HistoricoCustos) do begin
  if (HistoricoCustos[I].Data<=0) or (HistoricoCustos[I].Data<>Trunc(HistoricoCustos[I].Data)) or (HistoricoCustos[I].Previsto<0) or (HistoricoCustos[I].Computado<0) or (HistoricoCustos[I].Previsto>9000000000000000) or (HistoricoCustos[I].Computado>9000000000000000) then raise Exception.Create('Apuração de custos inválida');
  if (I>0) and (HistoricoCustos[I-1].Data>=HistoricoCustos[I].Data) then raise Exception.Create('Datas de apuração devem ser únicas e crescentes');
 end;
 if FSprints.Count>5000 then raise Exception.Create('Muitas sprints');
 for I:=0 to FSprints.Count-1 do begin
  FSprints[I].Validar;
  for J:=0 to I-1 do if SameText(FSprints[I].ID,FSprints[J].ID) or ((FSprints[I].Inicio=FSprints[J].Inicio) and (FSprints[I].Fim=FSprints[J].Fim)) then raise Exception.Create('Sprint repetida');
  for K:=0 to High(FSprints[I].Items) do if IndiceDe(FSprints[I].Items[K].TaskID)<0 then raise Exception.Create('Sprint referencia tarefa inexistente');
 end;
end;

function TPLProjeto.CustoTarefa(T: TPLTarefa; SomenteContabilizado: Boolean): Int64;
var I,K: Integer; Q: Double; Value: Int64;
  procedure Add(Cost: Int64);
  begin if Result>9000000000000000-Cost then raise Exception.Create('Custo total excede limite'); Result:=Result+Cost; end;
begin
 Result:=0;
 for I:=0 to High(T.Custos) do begin
  if Trim(T.Custos[I].Nome)='' then raise Exception.Create('Informe a descrição do custo');
  if (T.Custos[I].Quantidade<=0) or (T.Custos[I].ValorUnitarioCentavos<0) or (T.Custos[I].ValorUnitarioCentavos>1000000000000) then raise Exception.Create('Custo direto inválido');
  Value:=EALineCost(T.Custos[I].Quantidade,T.Custos[I].ValorUnitarioCentavos);
  if not SomenteContabilizado or T.Custos[I].Contabilizado then Add(Value);
 end;
 for I:=0 to High(T.Alocacoes) do begin
  K:=RecursoIndice(T.Alocacoes[I].RecursoID); if K<0 then raise Exception.Create('Recurso de custo não encontrado');
  if FRecursos[K].Tipo=prtArquivo then Continue;
  Q:=T.Alocacoes[I].Unidades;
  if FRecursos[K].Tipo<>prtMaterial then Q:=Q*T.Duracao.Minutes/60;
  Value:=EALineCost(Q,T.Alocacoes[I].CustoUnitarioCentavos);
  if not SomenteContabilizado or T.Alocacoes[I].Contabilizado then Add(Value);
 end;
end;
function TPLProjeto.CustoProjeto(SomenteContabilizado: Boolean): Int64;
var I: Integer; V: Int64;
begin
 Result:=0; for I:=0 to Count-1 do begin V:=CustoTarefa(Tarefas[I],SomenteContabilizado); if Result>9000000000000000-V then raise Exception.Create('Custo do projeto excede limite'); Result:=Result+V; end;
end;

function TPLProjeto.RecursoIndice(const ID: string): Integer;
var I: Integer;
begin Result:=-1; for I:=0 to FRecursos.Count-1 do if SameText(FRecursos[I].ID,ID) then Exit(I); end;
function TPLProjeto.AdicionarRecurso(R: TPLRecurso): Integer;
var I: Integer;
begin
 R.Validar;
 if RecursoIndice(R.ID)>=0 then raise Exception.Create('ID de recurso repetido: '+R.ID);
 for I:=0 to FRecursos.Count-1 do if (R.Tipo=prtPessoa) and (R.UsuarioID<>'') and (FRecursos[I].UsuarioID=R.UsuarioID) then raise Exception.Create('Usuário já cadastrado como recurso');
 Result:=FRecursos.Add(R); MarcarModificado;
end;
function TPLProjeto.NovoRecurso: TPLRecurso;
var G: TGUID;
begin Result:=TPLRecurso.Create; CreateGUID(G); Result.ID:='R-'+GUIDToString(G); end;
procedure TPLProjeto.ExcluirRecurso(I: Integer);
var T,J: Integer;
begin
 if (I<0) or (I>=FRecursos.Count) then raise Exception.Create('Selecione um recurso');
 for T:=0 to High(Apontamentos) do if SameText(Apontamentos[T].RecursoID,FRecursos[I].ID) then raise Exception.Create('Pessoa possui horas apontadas e não pode ser excluída');
 for T:=0 to Count-1 do begin
  if (FRecursos[I].Tipo=prtPessoa) and (((FRecursos[I].UsuarioID<>'') and (Tarefas[T].ExecutorID=FRecursos[I].UsuarioID)) or ((Tarefas[T].Responsavel<>'') and (FRecursos[I].ID='EXEC:login:'+LowerCase(Tarefas[T].Responsavel)))) then raise Exception.Create('Recurso é executor de uma tarefa; altere primeiro o executor');
  for J:=0 to High(Tarefas[T].Alocacoes) do if SameText(Tarefas[T].Alocacoes[J].RecursoID,FRecursos[I].ID) then raise Exception.Create('Recurso alocado; remova primeiro os vínculos das tarefas');
 end;
 FRecursos.Delete(I); MarcarModificado;
end;
procedure TPLProjeto.ValidarAlocacoes(const Itens: TPLAlocacoes);
var I,J,K: Integer; R: TPLRecurso;
begin
 if Length(Itens)>5000 then raise Exception.Create('Muitas alocações em uma tarefa');
 for I:=0 to High(Itens) do begin
  K:=RecursoIndice(Itens[I].RecursoID); if K<0 then raise Exception.Create('Recurso alocado não encontrado: '+Itens[I].RecursoID); R:=FRecursos[K];
  if IsNan(Itens[I].Unidades) or IsInfinite(Itens[I].Unidades) or (Itens[I].Unidades<=0) or (Itens[I].Unidades>1000000000) then raise Exception.Create('Alocação deve ter unidades positivas e finitas');
  if (R.Tipo=prtArquivo) and (Itens[I].Direcao=prdUso) then raise Exception.Create('Arquivo deve ser entrada ou saída');
  if (R.Tipo=prtMaterial) and (Itens[I].Direcao<>prdEntrada) then raise Exception.Create('Consumível deve ser recurso de entrada');
  if not (R.Tipo in [prtArquivo,prtMaterial]) and (Itens[I].Direcao<>prdUso) then raise Exception.Create('Recurso de trabalho deve ser de uso');
  if (Itens[I].CustoUnitarioCentavos<0) or (Itens[I].CustoUnitarioCentavos>1000000000000) then raise Exception.Create('Preço de alocação inválido');
  for J:=0 to I-1 do if SameText(Itens[J].RecursoID,Itens[I].RecursoID) and (Itens[J].Direcao=Itens[I].Direcao) then raise Exception.Create('Alocação repetida');
 end;
end;
procedure TPLProjeto.ValidarRecursos;
var I,J: Integer;
begin
 ValidarApontamentos;
 if FRecursos.Count>10000 then raise Exception.Create('Muitos recursos');
 for I:=0 to FRecursos.Count-1 do begin
  FRecursos[I].Validar;
  for J:=0 to I-1 do begin
   if SameText(FRecursos[I].ID,FRecursos[J].ID) then raise Exception.Create('Recurso repetido');
   if (FRecursos[I].UsuarioID<>'') and (FRecursos[I].UsuarioID=FRecursos[J].UsuarioID) then raise Exception.Create('Usuário vinculado a dois recursos');
  end;
 end;
 for I:=0 to Count-1 do begin ValidarAlocacoes(Tarefas[I].Alocacoes); CustoTarefa(Tarefas[I],False); end;
end;
procedure TPLProjeto.DefinirAlocacoes(T: TPLTarefa; const Itens: TPLAlocacoes);
begin
 if (T=nil) or (IndiceDe(T.ID)<0) or (Tarefas[IndiceDe(T.ID)]<>T) then raise Exception.Create('Tarefa fora do projeto');
 ValidarAlocacoes(Itens); T.Alocacoes:=Copy(Itens); MarcarModificado;
end;
function TPLProjeto.RecursoExecutor(T: TPLTarefa): Integer;
var I: Integer; Key: string; R: TPLRecurso;
begin
 Result:=-1; if (T.ExecutorID='') and (Trim(T.Responsavel)='') then Exit;
 Key:=T.ExecutorID; if Key='' then Key:='login:'+LowerCase(T.Responsavel);
 for I:=0 to FRecursos.Count-1 do if (FRecursos[I].Tipo=prtPessoa) and
  (((T.ExecutorID<>'') and (FRecursos[I].UsuarioID=T.ExecutorID)) or (FRecursos[I].ID='EXEC:'+Key)) then Exit(I);
 R:=NovoRecurso; R.ID:='EXEC:'+Key; R.UsuarioID:=T.ExecutorID; R.Nome:=T.ExecutorNome;
 if R.Nome='' then R.Nome:=T.Responsavel;
 try Result:=AdicionarRecurso(R); except R.Free; raise; end;
end;
function TPLProjeto.ArquivosTarefa(T: TPLTarefa; const BaseFile: string): TJSONArray;
var I,J: Integer; R: TPLRecurso; O: TJSONObject;
begin
 Result:=TJSONArray.Create;
 try
  for I:=0 to High(T.Alocacoes) do begin J:=RecursoIndice(T.Alocacoes[I].RecursoID); if J<0 then Continue; R:=FRecursos[J]; if R.Tipo<>prtArquivo then Continue;
   O:=TJSONObject.Create; O.Add('name',R.Nome); O.Add('direction',PL_DIRECAO_CODIGOS[T.Alocacoes[I].Direcao]); if BaseFile='' then O.Add('link',R.Link) else O.Add('link',EAResolveLink(R.Link,BaseFile)); Result.Add(O);
  end;
 except Result.Free; raise; end;
end;
procedure TPLProjeto.DefinirArquivos(T: TPLTarefa; Files: TJSONArray);
var Backup,NonFiles: TPLAlocacoes; I,K,N: Integer;
begin
 EAValidateFiles(Files); Backup:=Copy(T.Alocacoes);
 for I:=0 to High(Backup) do begin K:=RecursoIndice(Backup[I].RecursoID); if (K>=0) and (FRecursos[K].Tipo=prtArquivo) then Continue; N:=Length(NonFiles); SetLength(NonFiles,N+1); NonFiles[N]:=Backup[I]; end;
 try DefinirAlocacoes(T,NonFiles); ImportarArquivos(T,Files); except T.Alocacoes:=Backup; raise; end;
end;
procedure TPLProjeto.ImportarArquivos(T: TPLTarefa; Files: TJSONArray);
var I,J,N,K: Integer; R: TPLRecurso; A: TPLAlocacoes; Direction: TPLDirecao; Found: Boolean;
begin
 EAValidateFiles(Files); A:=Copy(T.Alocacoes);
 for I:=0 to Files.Count-1 do begin
  Direction:=prdEntrada; if Files.Objects[I].Get('direction','')='output' then Direction:=prdSaida;
  J:=-1;
  for K:=0 to FRecursos.Count-1 do if (FRecursos[K].Tipo=prtArquivo) and (FRecursos[K].Link=Files.Objects[I].Get('link','')) then begin J:=K; Break; end;
  if J<0 then begin
   R:=NovoRecurso; R.Tipo:=prtArquivo; R.Nome:=Files.Objects[I].Get('name',''); R.Link:=Files.Objects[I].Get('link','');
   try J:=AdicionarRecurso(R); except R.Free; raise; end;
  end;
  FRecursos[J].Nome:=Files.Objects[I].Get('name','');
  Found:=False; for N:=0 to High(A) do if (A[N].RecursoID=FRecursos[J].ID) and (A[N].Direcao=Direction) then Found:=True;
  if not Found then begin N:=Length(A); SetLength(A,N+1); A[N].RecursoID:=FRecursos[J].ID; A[N].Unidades:=1; A[N].Direcao:=Direction; end;
 end;
 DefinirAlocacoes(T,A);
end;

constructor TPLProjeto.Create;
begin
  inherited Create;
  FTarefas := TPLListaTarefas.Create(True);
  FRecursos := TPLListaRecursos.Create(True);
  FSprints:=TPLListaSprints.Create(True);
  FCalendario := TAIWorkCalendar.Create('Padrão');
  Novo('Novo projeto', Date);
end;

destructor TPLProjeto.Destroy;
begin
  FTarefas.Free;
  FRecursos.Free;
  FSprints.Free;
  FCalendario.Free;
  inherited Destroy;
end;

procedure TPLProjeto.TrocarCom(Outro: TPLProjeto);
var
  L: TPLListaTarefas;
  ResourcesList: TPLListaRecursos;
  Logs: TPLApontamentos;
  SprintList: TPLListaSprints; History: TPLHistoricoCustos; Budget: Int64; FixedBudget: Boolean;
  C: TAIWorkCalendar;
  N: Integer;
  B: Boolean;
  S: string;
  D: TDateTime;
begin
  if Outro = nil then raise Exception.Create('projeto de destino ausente');
  if Outro = Self then Exit;
  L := FTarefas; FTarefas := Outro.FTarefas; Outro.FTarefas := L;
  ResourcesList:=FRecursos; FRecursos:=Outro.FRecursos; Outro.FRecursos:=ResourcesList;
  SprintList:=FSprints; FSprints:=Outro.FSprints; Outro.FSprints:=SprintList;
  Logs:=Apontamentos; Apontamentos:=Outro.Apontamentos; Outro.Apontamentos:=Logs;
  History:=HistoricoCustos; HistoricoCustos:=Outro.HistoricoCustos; Outro.HistoricoCustos:=History;
  Budget:=OrcamentoCentavos; OrcamentoCentavos:=Outro.OrcamentoCentavos; Outro.OrcamentoCentavos:=Budget;
  FixedBudget:=OrcamentoFixado; OrcamentoFixado:=Outro.OrcamentoFixado; Outro.OrcamentoFixado:=FixedBudget;
  C := FCalendario; FCalendario := Outro.FCalendario; Outro.FCalendario := C;
  N := FProximo; FProximo := Outro.FProximo; Outro.FProximo := N;
  B := FModificado; FModificado := Outro.FModificado; Outro.FModificado := B;
  S := Nome; Nome := Outro.Nome; Outro.Nome := S;
  S := Objetivo; Objetivo := Outro.Objetivo; Outro.Objetivo := S;
  D := Inicio; Inicio := Outro.Inicio; Outro.Inicio := D;
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
  FRecursos.Clear;
  FSprints.Clear; SetLength(Apontamentos,0); SetLength(HistoricoCustos,0); OrcamentoFixado:=False; OrcamentoCentavos:=0;
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
  for K:=0 to High(Apontamentos) do if SameText(Apontamentos[K].TaskID,Id) then raise Exception.Create('Tarefa possui horas apontadas. Corrija/remova os apontamentos antes de excluí-la.');
  FTarefas.Delete(I);
  for K:=0 to FSprints.Count-1 do FSprints[K].Remover(Id);
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

function TPLProjeto.AplicarEdicaoTarefa(T: TPLTarefa;
  const ANome, ADuracao, APredecessoras, AResponsavel, ANotas: string;
  AAplicativo: TPLAplicativo; ASituacao: TPLSituacao; AProgresso: Integer;
  out Err: string): Boolean;
var
  D: TAIDuration;
  Itens: TAIPredecessorItems;
begin
  Result := False;
  Err := '';
  if (T = nil) or (IndiceDe(T.Id) < 0) or (FTarefas[IndiceDe(T.Id)] <> T) then
  begin
    Err := 'tarefa nao pertence ao projeto';
    Exit;
  end;
  if Trim(ANome) = '' then
  begin
    Err := 'o nome da tarefa nao pode ficar vazio';
    Exit;
  end;
  if not AITryParseDuration(ADuracao, PL_MINUTOS_POR_DIA, PL_MINUTOS_POR_SEMANA, D, Err) then
  begin
    Err := 'duracao invalida: ' + Err;
    Exit;
  end;
  if D.Minutes < 0 then
  begin
    Err := 'duracao negativa';
    Exit;
  end;
  if (AProgresso < 0) or (AProgresso > 100) then
  begin
    Err := 'progresso deve estar entre 0 e 100';
    Exit;
  end;
  if not AITryParsePredecessors(APredecessoras, PL_MINUTOS_POR_DIA,
    PL_MINUTOS_POR_SEMANA, @IdExiste, Itens, Err) then
  begin
    Err := 'predecessoras: ' + Err;
    Exit;
  end;
  { DefinirItens valida ciclo/duplicidade antes de escrever. Nada foi
    alterado ate este ponto; falhas de validacao deixam a tarefa intacta. }
  if not DefinirItens(T, Itens, Err) then
  begin
    Err := 'predecessoras: ' + Err;
    Exit;
  end;
  T.Nome := Trim(ANome);
  T.Duracao := D;
  T.Marco := D.Minutes = 0;
  T.Aplicativo := AAplicativo;
  T.Situacao := ASituacao;
  T.Responsavel := AResponsavel;
  T.Notas := ANotas;
  if ASituacao = plsConcluida then T.Progresso := 100
  else T.Progresso := AProgresso;
  MarcarModificado;
  Result := True;
end;

procedure TPLProjeto.MarcarModificado;
begin
  FModificado := True;
end;

end.
