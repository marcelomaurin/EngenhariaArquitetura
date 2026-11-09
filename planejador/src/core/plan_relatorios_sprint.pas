unit plan_relatorios_sprint;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes,SysUtils,Math,DateUtils,plan_tipos,plan_recursos,plan_sprints,plan_documento,plan_cronograma,plan_acompanhamento,plan_apontamentos;
type
 TPLSprintTarefaRel=record
  ID,Nome,Executor: string; Situacao: TPLSituacao; Progresso: Integer; Inicio,Fim: TDateTime;
  PendenteAnterior,Atrasada,Conflito: Boolean; PrevistoMin,RestanteMin,ApontadoMin: Int64;
 end;
 TPLSprintUsuarioRel=record
  RecursoID,UsuarioID,Nome: string;
  Tarefas,Pendentes,Concluidas,Atrasadas: Integer;
  PrevistoPeriodoMin,ConcluidoEstimadoMin,RestanteEstimadoMin,ApontadoMin,CapacidadeMin: Int64;
 end;
 TPLSprintHoraRel=record
  ID,TaskID,Tarefa,RecursoID,Usuario,Notas: string; Data: TDateTime; Minutos: Integer;
 end;
 TPLRelatorioSprint=class
 public
  Projeto,SprintID,SprintNome,Filtro: string; Inicio,Fim,Referencia: TDateTime;
  Tarefas: array of TPLSprintTarefaRel; Usuarios: array of TPLSprintUsuarioRel; Horas: array of TPLSprintHoraRel;
  Total,Pendentes,Concluidas,Atrasadas: Integer; ApontadoMin,RestanteMin: Int64;
 end;
function PLGerarRelatorioSprint(Doc: TPLProjeto; Crono: TPLCronograma; S: TPLSprint; const ResourceID: string=''; Referencia: TDateTime=0): TPLRelatorioSprint;
function PLHorasTexto(Minutos: Int64): string;
procedure PLRelatorioSprintHTML(Rel: TPLRelatorioSprint; const FileName: string);
procedure PLRelatorioSprintPendenciasCSV(Rel: TPLRelatorioSprint; const FileName: string);
procedure PLRelatorioSprintUsuariosCSV(Rel: TPLRelatorioSprint; const FileName: string);
procedure PLRelatorioSprintHorasCSV(Rel: TPLRelatorioSprint; const FileName: string);
implementation
uses aiworkcalendar,airesourceload,ea_fileio;
function Minutes(Value: Extended): Int64;
begin if IsNan(Value) or IsInfinite(Value) or (Value<0) or (Value>1000000000000) then raise Exception.Create('Carga de trabalho fora do limite'); Result:=Round(Value); end;
function PLHorasTexto(Minutos: Int64): string;
var F: TFormatSettings;
begin F:=DefaultFormatSettings; F.DecimalSeparator:=','; Result:=FormatFloat('0.00',Minutos/60.0,F); end;
function PLGerarRelatorioSprint(Doc: TPLProjeto; Crono: TPLCronograma; S: TPLSprint; const ResourceID: string; Referencia: TDateTime): TPLRelatorioSprint;
var Rel: TPLRelatorioSprint; Tasks: TPLTaskIndices; UserTasks: TStringList; I,J,K,N,U,Row,FilterIndex: Integer; A: TAIAssignment; T: TPLTarefa; R: TPLRecurso; Entry: TPLApontamento;
 Included: array of Boolean; TaskRow: array of Integer; HasPerson: Boolean; Full,Remain,PeriodWork: Int64; LowDate,HighDate: TDateTime; PersonFilter: Boolean;
  function UserRow(ResourceIndex: Integer): Integer;
  var Key: string; L: Integer; Cal: TAIWorkCalendar; Start,Finish: TDateTime;
  begin
   Key:=''; if ResourceIndex>=0 then Key:=Doc.Recursos[ResourceIndex].ID;
   for L:=0 to High(Rel.Usuarios) do if SameText(Rel.Usuarios[L].RecursoID,Key) then Exit(L);
   L:=Length(Rel.Usuarios); SetLength(Rel.Usuarios,L+1); Rel.Usuarios[L].RecursoID:=Key;
   if ResourceIndex<0 then Rel.Usuarios[L].Nome:='Sem usuário atribuído'
   else begin
    Rel.Usuarios[L].Nome:=Doc.Recursos[ResourceIndex].Nome; Rel.Usuarios[L].UsuarioID:=Doc.Recursos[ResourceIndex].UsuarioID;
    Start:=S.Inicio; Finish:=S.Fim+1; R:=Doc.Recursos[ResourceIndex];
    if R.DisponivelDe>0 then Start:=Max(Start,R.DisponivelDe); if R.DisponivelAte>0 then Finish:=Min(Finish,R.DisponivelAte+1);
    Cal:=R.MontarCalendario(Doc.Calendario);
    try if Finish>Start then Rel.Usuarios[L].CapacidadeMin:=Minutes(Cal.WorkingMinutesBetween(Start,Finish)*R.Capacidade); finally Cal.Free; end;
   end;
   Exit(L);
  end;
  procedure CountUserTask(UserIndex,TaskIndex: Integer);
  var Key: string;
  begin
   Key:=IntToStr(UserIndex)+'|'+Doc[TaskIndex].ID; if UserTasks.IndexOf(Key)>=0 then Exit; UserTasks.Add(Key);
   Inc(Rel.Usuarios[UserIndex].Tarefas);
   if Doc[TaskIndex].Situacao=plsConcluida then Inc(Rel.Usuarios[UserIndex].Concluidas) else begin
    Inc(Rel.Usuarios[UserIndex].Pendentes); if Rel.Tarefas[TaskRow[TaskIndex]].Atrasada then Inc(Rel.Usuarios[UserIndex].Atrasadas);
   end;
  end;
  procedure AddDemand(UserIndex,TaskIndex: Integer; Units: Double);
  var Planned,Remaining,Period: Int64; Start,Finish: TDateTime;
  begin
   Planned:=Minutes(Doc[TaskIndex].Duracao.Minutes*Units); Remaining:=0;
   if Doc[TaskIndex].Situacao<>plsConcluida then Remaining:=Minutes(Planned*(100-Doc[TaskIndex].Progresso)/100.0);
   Start:=Max(Crono.Resultado[TaskIndex].Start,S.Inicio); Finish:=Min(Crono.Resultado[TaskIndex].Finish,S.Fim+1); Period:=0;
   if Finish>Start then begin
    if Doc[TaskIndex].Duracao.Elapsed then Period:=Minutes((Finish-Start)*1440*Units)
    else Period:=Minutes(Doc.Calendario.WorkingMinutesBetween(Start,Finish)*Units);
   end else if Crono.Resultado[TaskIndex].Finish<=S.Inicio then Period:=Remaining;
   Inc(Rel.Usuarios[UserIndex].PrevistoPeriodoMin,Period); Inc(Rel.Usuarios[UserIndex].RestanteEstimadoMin,Remaining); Inc(Rel.Usuarios[UserIndex].ConcluidoEstimadoMin,Planned-Remaining);
   Inc(Rel.Tarefas[TaskRow[TaskIndex]].PrevistoMin,Period); Inc(Rel.Tarefas[TaskRow[TaskIndex]].RestanteMin,Remaining); CountUserTask(UserIndex,TaskIndex);
  end;
begin
 if S=nil then raise Exception.Create('Selecione uma sprint para gerar o relatório');
 if not Crono.Valido then raise Exception.Create('Corrija o cronograma antes de gerar o relatório');
 Doc.ValidarAcompanhamento; Doc.ValidarRecursos; S.Validar;
 if Referencia<=0 then Referencia:=Date;
 Result:=TPLRelatorioSprint.Create; Rel:=Result; UserTasks:=TStringList.Create;
 try
  try
  UserTasks.Sorted:=True; Rel.Projeto:=Doc.Nome; Rel.SprintID:=S.ID; Rel.SprintNome:=S.Nome; Rel.Inicio:=S.Inicio; Rel.Fim:=S.Fim; Rel.Referencia:=Trunc(Referencia);
  FilterIndex:=Doc.RecursoIndice(ResourceID); PersonFilter:=(FilterIndex>=0) and (Doc.Recursos[FilterIndex].Tipo=prtPessoa);
  Rel.Filtro:='Todos os usuários / recursos'; if ResourceID<>'' then begin if FilterIndex<0 then raise Exception.Create('Filtro de recurso não encontrado'); Rel.Filtro:=Doc.Recursos[FilterIndex].Nome; end;
  Tasks:=PLTarefasTOdo(Doc,S,ResourceID); SetLength(Included,Doc.Count); SetLength(TaskRow,Doc.Count);
  SetLength(Rel.Tarefas,Length(Tasks)); Rel.Total:=Length(Tasks);
  for I:=0 to High(Tasks) do begin
   K:=Tasks[I]; T:=Doc[K]; Included[K]:=True; TaskRow[K]:=I;
   Rel.Tarefas[I].ID:=T.ID; Rel.Tarefas[I].Nome:=T.Nome; Rel.Tarefas[I].Executor:=T.ExecutorNome; if Rel.Tarefas[I].Executor='' then Rel.Tarefas[I].Executor:=T.Responsavel;
   Rel.Tarefas[I].Situacao:=T.Situacao; Rel.Tarefas[I].Progresso:=T.Progresso; Rel.Tarefas[I].Inicio:=Crono.Resultado[K].Start; Rel.Tarefas[I].Fim:=Crono.Resultado[K].Finish; Rel.Tarefas[I].Conflito:=Crono.Conflito[K];
   Rel.Tarefas[I].Atrasada:=(T.Situacao<>plsConcluida) and (Crono.Resultado[K].Finish<Trunc(Referencia));
   for J:=0 to High(S.Items) do if SameText(S.Items[J].TaskID,T.ID) then Rel.Tarefas[I].PendenteAnterior:=S.Items[J].PendenteAnterior;
   if T.Situacao=plsConcluida then Inc(Rel.Concluidas) else Inc(Rel.Pendentes); if Rel.Tarefas[I].Atrasada then Inc(Rel.Atrasadas);
  end;
  for I:=0 to High(Tasks) do begin
   K:=Tasks[I]; HasPerson:=False;
   for J:=0 to Crono.Carga.AssignmentCount-1 do begin
    A:=Crono.Carga.Assignments[J]; if A.Task<>K then Continue; if Doc.Recursos[A.Resource].Tipo<>prtPessoa then Continue;
    if PersonFilter and not SameText(Doc.Recursos[A.Resource].ID,ResourceID) then Continue;
    U:=UserRow(A.Resource); AddDemand(U,K,A.Units); HasPerson:=True;
   end;
   if not HasPerson and not PersonFilter then begin U:=UserRow(-1); AddDemand(U,K,1); end;
  end;
  for I:=0 to High(Doc.Apontamentos) do begin
   Entry:=Doc.Apontamentos[I]; K:=Doc.IndiceDe(Entry.TaskID);
   if (K<0) or not Included[K] or (Entry.Data<S.Inicio) or (Entry.Data>=S.Fim+1) then Continue;
   if PersonFilter and not SameText(Entry.RecursoID,ResourceID) then Continue;
   J:=Doc.RecursoIndice(Entry.RecursoID); U:=UserRow(J); CountUserTask(U,K);
   Inc(Rel.Usuarios[U].ApontadoMin,Entry.Minutos); Inc(Rel.Tarefas[TaskRow[K]].ApontadoMin,Entry.Minutos); Inc(Rel.ApontadoMin,Entry.Minutos);
   N:=Length(Rel.Horas); SetLength(Rel.Horas,N+1); Rel.Horas[N].ID:=Entry.ID; Rel.Horas[N].TaskID:=Entry.TaskID; Rel.Horas[N].Tarefa:=Doc[K].Nome; Rel.Horas[N].RecursoID:=Entry.RecursoID; Rel.Horas[N].Usuario:=Doc.Recursos[J].Nome; Rel.Horas[N].Data:=Entry.Data; Rel.Horas[N].Minutos:=Entry.Minutos; Rel.Horas[N].Notas:=Entry.Notas;
  end;
  for I:=0 to High(Rel.Tarefas) do Inc(Rel.RestanteMin,Rel.Tarefas[I].RestanteMin);
 except Rel.Free; raise; end;
 finally UserTasks.Free; end;
end;
function Esc(const S: string): string;
begin Result:=StringReplace(S,'&','&amp;',[rfReplaceAll]); Result:=StringReplace(Result,'<','&lt;',[rfReplaceAll]); Result:=StringReplace(Result,'>','&gt;',[rfReplaceAll]); Result:=StringReplace(Result,'"','&quot;',[rfReplaceAll]); end;
function CSV(const S: string): string;
var Safe: string; I: Integer;
begin Safe:=S; I:=1; while (I<=Length(Safe)) and (Safe[I] in [' ',#9,#10,#13]) do Inc(I); if (I<=Length(Safe)) and (Safe[I] in ['=','+','-','@']) then Safe:=#39+Safe; Result:='"'+StringReplace(Safe,'"','""',[rfReplaceAll])+'"'; end;
function BoolText(Value: Boolean): string;
begin if Value then Result:='Sim' else Result:='Não'; end;
procedure PLRelatorioSprintPendenciasCSV(Rel: TPLRelatorioSprint; const FileName: string);
var L: TStringList; I: Integer; T: TPLSprintTarefaRel;
begin L:=TStringList.Create; try
 L.Add('Sprint;Sprint ID;Início sprint;Fim sprint;Filtro;Data referência atraso;Tarefa ID;Tarefa;Executor;Situação;Progresso;Início calculado;Término calculado;Atrasada;Origem anterior;Conflito;Carga prevista período h;Restante estimado h;Horas apontadas na sprint');
 for I:=0 to High(Rel.Tarefas) do begin T:=Rel.Tarefas[I]; if T.Situacao=plsConcluida then Continue;
  L.Add(CSV(Rel.SprintNome)+';'+CSV(Rel.SprintID)+';'+CSV(PLDataISO(Rel.Inicio))+';'+CSV(PLDataISO(Rel.Fim))+';'+CSV(Rel.Filtro)+';'+CSV(PLDataISO(Rel.Referencia))+';'+CSV(T.ID)+';'+CSV(T.Nome)+';'+CSV(T.Executor)+';'+CSV(PL_SITUACAO_NOME[T.Situacao])+';'+IntToStr(T.Progresso)+';'+CSV(PLDataISO(T.Inicio))+';'+CSV(PLDataISO(T.Fim))+';'+CSV(BoolText(T.Atrasada))+';'+CSV(BoolText(T.PendenteAnterior))+';'+CSV(BoolText(T.Conflito))+';'+CSV(PLHorasTexto(T.PrevistoMin))+';'+CSV(PLHorasTexto(T.RestanteMin))+';'+CSV(PLHorasTexto(T.ApontadoMin)));
 end; EAAtomicWriteText(FileName,#$EF#$BB#$BF+L.Text);
 finally L.Free; end; end;
procedure PLRelatorioSprintUsuariosCSV(Rel: TPLRelatorioSprint; const FileName: string);
var L: TStringList; I: Integer; U: TPLSprintUsuarioRel;
begin L:=TStringList.Create; try
 L.Add('Sprint;Sprint ID;Início sprint;Fim sprint;Filtro;Data referência atraso;Usuário recurso;Usuário ID;Nome;Tarefas;Pendentes;Concluídas;Atrasadas;Carga prevista período h;Concluída estimada escopo h;Restante estimado escopo h;Horas apontadas na sprint;Capacidade sprint h');
 for I:=0 to High(Rel.Usuarios) do begin U:=Rel.Usuarios[I]; L.Add(CSV(Rel.SprintNome)+';'+CSV(Rel.SprintID)+';'+CSV(PLDataISO(Rel.Inicio))+';'+CSV(PLDataISO(Rel.Fim))+';'+CSV(Rel.Filtro)+';'+CSV(PLDataISO(Rel.Referencia))+';'+CSV(U.RecursoID)+';'+CSV(U.UsuarioID)+';'+CSV(U.Nome)+';'+IntToStr(U.Tarefas)+';'+IntToStr(U.Pendentes)+';'+IntToStr(U.Concluidas)+';'+IntToStr(U.Atrasadas)+';'+CSV(PLHorasTexto(U.PrevistoPeriodoMin))+';'+CSV(PLHorasTexto(U.ConcluidoEstimadoMin))+';'+CSV(PLHorasTexto(U.RestanteEstimadoMin))+';'+CSV(PLHorasTexto(U.ApontadoMin))+';'+CSV(PLHorasTexto(U.CapacidadeMin))); end;
 EAAtomicWriteText(FileName,#$EF#$BB#$BF+L.Text); finally L.Free; end; end;
procedure PLRelatorioSprintHorasCSV(Rel: TPLRelatorioSprint; const FileName: string);
var L: TStringList; I: Integer; H: TPLSprintHoraRel;
begin L:=TStringList.Create; try L.Add('Sprint;Sprint ID;Início sprint;Fim sprint;Data;Apontamento ID;Tarefa ID;Tarefa;Usuário recurso;Usuário;Minutos;Horas;Observação');
 for I:=0 to High(Rel.Horas) do begin H:=Rel.Horas[I]; L.Add(CSV(Rel.SprintNome)+';'+CSV(Rel.SprintID)+';'+CSV(PLDataISO(Rel.Inicio))+';'+CSV(PLDataISO(Rel.Fim))+';'+CSV(PLDataISO(H.Data))+';'+CSV(H.ID)+';'+CSV(H.TaskID)+';'+CSV(H.Tarefa)+';'+CSV(H.RecursoID)+';'+CSV(H.Usuario)+';'+IntToStr(H.Minutos)+';'+CSV(PLHorasTexto(H.Minutos))+';'+CSV(H.Notas)); end;
 EAAtomicWriteText(FileName,#$EF#$BB#$BF+L.Text); finally L.Free; end; end;
function Graph(Rel: TPLRelatorioSprint): string;
var I,N,Y,W: Integer; Maximum: Int64; S: string;
begin
 N:=Min(30,Length(Rel.Usuarios)); Maximum:=1; for I:=0 to N-1 do Maximum:=Max(Maximum,Max(Rel.Usuarios[I].ApontadoMin,Rel.Usuarios[I].RestanteEstimadoMin));
 S:='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 980 '+IntToStr(Max(90,50+N*58))+'" role="img" aria-label="Carga por usuário"><defs><clipPath id="nomes"><rect x="0" y="0" width="295" height="2000"/></clipPath></defs><g font-family="sans-serif" font-size="13"><text x="12" y="20">Horas apontadas na sprint (verde) e restante estimado do escopo (laranja)</text>';
 for I:=0 to N-1 do begin Y:=42+I*58; S:=S+'<text clip-path="url(#nomes)" x="12" y="'+IntToStr(Y+12)+'">'+Esc(Rel.Usuarios[I].Nome)+'</text>';
  W:=Round(500.0*Rel.Usuarios[I].ApontadoMin/Maximum); S:=S+'<rect x="310" y="'+IntToStr(Y)+'" width="'+IntToStr(W)+'" height="15" fill="#15803d"/><text x="'+IntToStr(318+W)+'" y="'+IntToStr(Y+12)+'">'+PLHorasTexto(Rel.Usuarios[I].ApontadoMin)+' h</text>';
  W:=Round(500.0*Rel.Usuarios[I].RestanteEstimadoMin/Maximum); S:=S+'<rect x="310" y="'+IntToStr(Y+20)+'" width="'+IntToStr(W)+'" height="15" fill="#ea580c"/><text x="'+IntToStr(318+W)+'" y="'+IntToStr(Y+32)+'">'+PLHorasTexto(Rel.Usuarios[I].RestanteEstimadoMin)+' h</text>';
 end;
 Result:=S+'</g></svg>';
end;
procedure PLRelatorioSprintHTML(Rel: TPLRelatorioSprint; const FileName: string);
var L: TStringList; I: Integer; T: TPLSprintTarefaRel; U: TPLSprintUsuarioRel; H: TPLSprintHoraRel;
begin
 L:=TStringList.Create;
 try
  L.Add('<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Relatório da sprint</title><style>body{font:14px Arial;margin:28px;color:#0f172a}h1,h2{color:#1e40af}table{border-collapse:collapse;width:100%;margin-bottom:28px}th,td{border:1px solid #cbd5e1;padding:7px;text-align:left}th{background:#e2e8f0}.warn{color:#b91c1c}.numbers{font-weight:bold;padding:16px;background:#eff6ff}svg{width:100%}@media print{body{margin:8px;font-size:10px}thead{display:table-header-group}tr{break-inside:avoid}}</style>');
  L.Add('<h1>'+Esc(Rel.Projeto)+'</h1><h2>'+Esc(Rel.SprintNome)+'</h2><p>Identificação: '+Esc(Rel.SprintID)+' | Período: '+PLDataISO(Rel.Inicio)+' a '+PLDataISO(Rel.Fim)+' | Filtro: '+Esc(Rel.Filtro)+' | Referência de atraso: '+PLDataISO(Rel.Referencia)+'</p>');
  L.Add('<p class="numbers">'+IntToStr(Rel.Total)+' tarefas | '+IntToStr(Rel.Pendentes)+' pendentes | '+IntToStr(Rel.Concluidas)+' concluídas | '+IntToStr(Rel.Atrasadas)+' atrasadas | '+PLHorasTexto(Rel.ApontadoMin)+' h apontadas | '+PLHorasTexto(Rel.RestanteMin)+' h restantes estimadas</p>');
  L.Add('<p>Situação atual das tarefas. Horas realizadas são apenas apontamentos datados dentro da sprint. Conclusão e progresso não inventam horas. Carga concluída/restante é uma estimativa do escopo atribuído; não é medição de horas trabalhadas. Tarefas compartilhadas podem aparecer na contagem de mais de um usuário. Equipes agregadas não são distribuídas ficticiamente entre pessoas.</p>');
  L.Add(Graph(Rel)); if Length(Rel.Usuarios)>30 then L.Add('<p>Gráfico limitado aos 30 primeiros usuários; tabela completa abaixo.</p>');
  L.Add('<h2>Pendências</h2><table><thead><tr><th>ID / tarefa</th><th>Executor</th><th>Situação / %</th><th>Prazo</th><th>Origem / alertas</th><th>Restante estimado h</th><th>Apontadas h</th></tr></thead><tbody>');
  for I:=0 to High(Rel.Tarefas) do begin T:=Rel.Tarefas[I]; if T.Situacao=plsConcluida then Continue; L.Add('<tr><td>'+Esc(T.ID+' — '+T.Nome)+'</td><td>'+Esc(T.Executor)+'</td><td>'+Esc(PL_SITUACAO_NOME[T.Situacao])+' / '+IntToStr(T.Progresso)+'%</td><td>'+PLDataISO(T.Fim)+'</td><td>Origem anterior: '+BoolText(T.PendenteAnterior)+'; atrasada: '+BoolText(T.Atrasada)+'; conflito: '+BoolText(T.Conflito)+'</td><td>'+PLHorasTexto(T.RestanteMin)+'</td><td>'+PLHorasTexto(T.ApontadoMin)+'</td></tr>'); end;
  if Rel.Pendentes=0 then L.Add('<tr><td colspan="7">Nenhuma tarefa pendente neste filtro.</td></tr>'); L.Add('</tbody></table>');
  L.Add('<h2>Tarefas concluídas</h2><table><thead><tr><th>Tarefa</th><th>Executor</th><th>Prazo calculado</th><th>Horas apontadas na sprint</th></tr></thead><tbody>');
  for I:=0 to High(Rel.Tarefas) do begin T:=Rel.Tarefas[I]; if T.Situacao<>plsConcluida then Continue; L.Add('<tr><td>'+Esc(T.ID+' — '+T.Nome)+'</td><td>'+Esc(T.Executor)+'</td><td>'+PLDataISO(T.Fim)+'</td><td>'+PLHorasTexto(T.ApontadoMin)+'</td></tr>'); end;
  if Rel.Concluidas=0 then L.Add('<tr><td colspan="4">Nenhuma tarefa concluída neste filtro.</td></tr>'); L.Add('</tbody></table>');
  L.Add('<h2>Carga por usuário</h2><table><thead><tr><th>Usuário</th><th>Tarefas</th><th>Pendentes</th><th>Concluídas</th><th>Atrasadas</th><th>Prevista no período h</th><th>Concluída estimada escopo h</th><th>Restante estimado escopo h</th><th>Apontadas na sprint h</th><th>Capacidade h</th></tr></thead><tbody>');
  for I:=0 to High(Rel.Usuarios) do begin U:=Rel.Usuarios[I]; if (U.RecursoID<>'') and ((U.PrevistoPeriodoMin>U.CapacidadeMin) or (U.ApontadoMin>U.CapacidadeMin)) then L.Add('<tr class="warn">') else L.Add('<tr>');
   L.Add('<td>'+Esc(U.Nome)+'</td><td>'+IntToStr(U.Tarefas)+'</td><td>'+IntToStr(U.Pendentes)+'</td><td>'+IntToStr(U.Concluidas)+'</td><td>'+IntToStr(U.Atrasadas)+'</td><td>'+PLHorasTexto(U.PrevistoPeriodoMin)+'</td><td>'+PLHorasTexto(U.ConcluidoEstimadoMin)+'</td><td>'+PLHorasTexto(U.RestanteEstimadoMin)+'</td><td>'+PLHorasTexto(U.ApontadoMin)+'</td><td>'+PLHorasTexto(U.CapacidadeMin)+'</td></tr>');
  end; L.Add('</tbody></table><p>Prevista no período: interseção planejada com a sprint, acrescida do saldo de tarefas antigas pendentes. Restante/concluída estimados: duração e dedicação do escopo completo, ponderadas pelo progresso. Capacidade considera calendário, ausências, datas de disponibilidade e percentual do recurso.</p>');
  L.Add('<h2>Horas apontadas</h2><table><thead><tr><th>Data</th><th>Usuário</th><th>Tarefa</th><th>Horas</th><th>Observação</th></tr></thead><tbody>');
  for I:=0 to High(Rel.Horas) do begin H:=Rel.Horas[I]; L.Add('<tr><td>'+PLDataISO(H.Data)+'</td><td>'+Esc(H.Usuario)+'</td><td>'+Esc(H.TaskID+' — '+H.Tarefa)+'</td><td>'+PLHorasTexto(H.Minutos)+'</td><td>'+Esc(H.Notas)+'</td></tr>'); end;
  if Length(Rel.Horas)=0 then L.Add('<tr><td colspan="5">Sem apontamentos de horas neste período e filtro.</td></tr>');
  L.Add('</tbody></table><p>Relatório de acompanhamento local. Não representa folha de pagamento nem contabilização automática de custos. Períodos de sprint sobrepostos podem apresentar os mesmos apontamentos; os relatórios não devem ser somados como se fossem períodos independentes.</p></html>');
  EAAtomicWriteText(FileName,L.Text);
 finally L.Free; end;
end;
end.
