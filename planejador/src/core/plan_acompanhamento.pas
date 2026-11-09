unit plan_acompanhamento;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses SysUtils, Classes, DateUtils, Math, plan_tipos, plan_recursos, plan_sprints, plan_documento, plan_cronograma;
type
 TPLCustoSemana=record
  Inicio,Fim: TDateTime; Previsto,Computado,Desvio,DeltaPrevisto,DeltaComputado: Int64;
  TemAnterior,TemApuracao: Boolean;
 end;
 TPLCustosSemanais=array of TPLCustoSemana;
 TPLTaskIndices=array of Integer;
function PLSegundaFeira(D: TDateTime): TDateTime;
function PLAtualizarSprint(Doc: TPLProjeto; Crono: TPLCronograma; S: TPLSprint): Boolean;
procedure PLAtualizarSprints(Doc: TPLProjeto; Crono: TPLCronograma);
function PLTarefaUsaRecurso(Doc: TPLProjeto; T: TPLTarefa; const ResourceID: string): Boolean;
function PLTarefasTOdo(Doc: TPLProjeto; S: TPLSprint; const ResourceID: string): TPLTaskIndices;
procedure PLAlterarStatus(Doc: TPLProjeto; T: TPLTarefa; Status: TPLSituacao);
function PLCustosPorSemana(Doc: TPLProjeto; Ate: TDateTime=0): TPLCustosSemanais;
function PLGraficoCustosSVG(const Semanas: TPLCustosSemanais): string;
procedure PLExportarCustosCSV(Doc: TPLProjeto; const Semanas: TPLCustosSemanais; const FileName: string);
procedure PLExportarCustosHTML(Doc: TPLProjeto; const Semanas: TPLCustosSemanais; const FileName: string);
implementation
uses ea_money, ea_fileio;
function PLSegundaFeira(D: TDateTime): TDateTime;
begin D:=Trunc(D); Result:=D-((DayOfWeek(D)+5) mod 7); end;
function PLAtualizarSprint(Doc: TPLProjeto; Crono: TPLCronograma; S: TPLSprint): Boolean;
var I,N,J: Integer; Inicio,Fim: TDateTime; DoPeriodo,Pendente,TemApontamento: Boolean;
begin
 Result:=False; if not Crono.Valido then Exit; S.Validar;
 for I:=High(S.Items) downto 0 do if Doc.IndiceDe(S.Items[I].TaskID)<0 then begin S.Remover(S.Items[I].TaskID); Result:=True; end;
 for I:=0 to Doc.Count-1 do begin
  Inicio:=Crono.Resultado[I].Start; Fim:=Crono.Resultado[I].Finish;
  DoPeriodo:=(Inicio<S.Fim+1) and ((Inicio>=S.Inicio) or (Fim>S.Inicio));
  Pendente:=(Fim<=S.Inicio) and (Inicio<S.Inicio) and (Doc[I].Situacao<>plsConcluida);
  TemApontamento:=False;
  for J:=0 to High(Doc.Apontamentos) do if SameText(Doc.Apontamentos[J].TaskID,Doc[I].ID) and (Doc.Apontamentos[J].Data>=S.Inicio) and (Doc.Apontamentos[J].Data<S.Fim+1) then begin TemApontamento:=True; Break; end;
  if DoPeriodo or Pendente or TemApontamento then if S.Incluir(Doc[I].ID,Pendente) then Result:=True;
 end;
 if Result then Doc.MarcarModificado;
end;
procedure PLAtualizarSprints(Doc: TPLProjeto; Crono: TPLCronograma);
var I: Integer;
begin for I:=0 to Doc.Sprints.Count-1 do PLAtualizarSprint(Doc,Crono,Doc.Sprints[I]); end;
function PLTarefaUsaRecurso(Doc: TPLProjeto; T: TPLTarefa; const ResourceID: string): Boolean;
var I,K: Integer; R: TPLRecurso;
begin
 Result:=True; if ResourceID='' then Exit; Result:=False;
 for I:=0 to High(T.Alocacoes) do if SameText(T.Alocacoes[I].RecursoID,ResourceID) then Exit(True);
 K:=Doc.RecursoIndice(ResourceID); if K<0 then Exit; R:=Doc.Recursos[K];
 if R.Tipo<>prtPessoa then Exit;
 if (R.UsuarioID<>'') and (R.UsuarioID=T.ExecutorID) then Exit(True);
 Result:=(T.Responsavel<>'') and SameText(R.ID,'EXEC:login:'+LowerCase(T.Responsavel));
end;
function PLTarefasTOdo(Doc: TPLProjeto; S: TPLSprint; const ResourceID: string): TPLTaskIndices;
var I,N,J: Integer; Matches: Boolean;
begin
 Result:=nil;
 for I:=0 to Doc.Count-1 do if (S=nil) or S.Contem(Doc[I].ID) then begin
  Matches:=PLTarefaUsaRecurso(Doc,Doc[I],ResourceID);
  if not Matches then for J:=0 to High(Doc.Apontamentos) do if SameText(Doc.Apontamentos[J].TaskID,Doc[I].ID) and SameText(Doc.Apontamentos[J].RecursoID,ResourceID) and ((S=nil) or ((Doc.Apontamentos[J].Data>=S.Inicio) and (Doc.Apontamentos[J].Data<S.Fim+1))) then begin Matches:=True; Break; end;
  if Matches then begin N:=Length(Result); SetLength(Result,N+1); Result[N]:=I; end;
 end;
end;
procedure PLAlterarStatus(Doc: TPLProjeto; T: TPLTarefa; Status: TPLSituacao);
begin
 if (T=nil) or (Doc.IndiceDe(T.ID)<0) or (Doc[Doc.IndiceDe(T.ID)]<>T) then raise Exception.Create('Tarefa fora do projeto');
 T.Situacao:=Status;
 case Status of
  plsConcluida: T.Progresso:=100;
  plsAFazer: T.Progresso:=0;
  plsEmAndamento: if (T.Progresso=0) or (T.Progresso=100) then T.Progresso:=10;
 end;
 Doc.MarcarModificado;
end;
function PLCustosPorSemana(Doc: TPLProjeto; Ate: TDateTime): TPLCustosSemanais;
var StartWeek,EndWeek,D: TDateTime; I,J,N: Integer; Previsto,Computado: Int64; HasEntry: Boolean;
begin
 Result:=nil; Doc.ValidarAcompanhamento; N:=Length(Doc.HistoricoCustos); if N=0 then Exit;
 if Ate<=0 then Ate:=Date; StartWeek:=PLSegundaFeira(Doc.HistoricoCustos[0].Data); EndWeek:=PLSegundaFeira(Max(Ate,Doc.HistoricoCustos[N-1].Data));
 if EndWeek-StartWeek>36525 then raise Exception.Create('Relatório limitado a cem anos');
 SetLength(Result,Trunc((EndWeek-StartWeek)/7)+1); J:=0; Previsto:=0; Computado:=0;
 for I:=0 to High(Result) do begin
  D:=StartWeek+I*7; HasEntry:=False;
  while (J<N) and (Doc.HistoricoCustos[J].Data<D+7) do begin Previsto:=Doc.HistoricoCustos[J].Previsto; Computado:=Doc.HistoricoCustos[J].Computado; HasEntry:=True; Inc(J); end;
  Result[I].Inicio:=D; Result[I].Fim:=D+6; Result[I].Previsto:=Previsto; Result[I].Computado:=Computado; Result[I].Desvio:=Computado-Previsto;
  Result[I].TemApuracao:=HasEntry; Result[I].TemAnterior:=I>0;
  if I>0 then begin Result[I].DeltaPrevisto:=Previsto-Result[I-1].Previsto; Result[I].DeltaComputado:=Computado-Result[I-1].Computado; end;
 end;
end;
function Esc(const S: string): string;
begin Result:=StringReplace(S,'&','&amp;',[rfReplaceAll]); Result:=StringReplace(Result,'<','&lt;',[rfReplaceAll]); Result:=StringReplace(Result,'>','&gt;',[rfReplaceAll]); Result:=StringReplace(Result,'"','&quot;',[rfReplaceAll]); end;
function PLGraficoCustosSVG(const Semanas: TPLCustosSemanais): string;
var I,X,Y,Step: Integer; Maximo: Int64; Prev,Comp,Labels: string;
begin
 Maximo:=1; for I:=0 to High(Semanas) do Maximo:=Max(Maximo,Max(Semanas[I].Previsto,Semanas[I].Computado)); Prev:=''; Comp:=''; Labels:=''; Step:=Max(1,Length(Semanas) div 7);
 for I:=0 to High(Semanas) do begin
  X:=80; if Length(Semanas)>1 then X:=80+Round(840*I/(Length(Semanas)-1));
  Y:=250-Round(200*Semanas[I].Previsto/Maximo); Prev:=Prev+IntToStr(X)+','+IntToStr(Y)+' ';
  Y:=250-Round(200*Semanas[I].Computado/Maximo); Comp:=Comp+IntToStr(X)+','+IntToStr(Y)+' ';
  if (I mod Step=0) or (I=High(Semanas)) then Labels:=Labels+'<text x="'+IntToStr(X)+'" y="276" text-anchor="middle">'+FormatDateTime('dd/mm/yy',Semanas[I].Inicio)+'</text>';
 end;
 Result:='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 980 300" role="img" aria-label="Evolução semanal dos custos previsto e computado"><rect width="980" height="300" fill="#f8fafc"/><g font-family="sans-serif" font-size="12" fill="#334155"><text x="20" y="22">R$ — previsto em azul; computado em laranja</text><path d="M80 42V250H940" fill="none" stroke="#94a3b8"/><text x="82" y="40">'+Esc(EAMoneyText(Maximo))+'</text><polyline points="'+Prev+'" fill="none" stroke="#1e40af" stroke-width="3"/><polyline points="'+Comp+'" fill="none" stroke="#ea580c" stroke-width="3"/>'+Labels+'</g></svg>';
end;
function CSV(const S: string): string;
begin Result:='"'+StringReplace(S,'"','""',[rfReplaceAll])+'"'; end;
function PercentText(Current,Previous: Int64): string;
begin if Previous=0 then Result:='—' else Result:=FormatFloat('0.00',(Current-Previous)*100.0/Previous)+'%'; end;
procedure PLExportarCustosCSV(Doc: TPLProjeto; const Semanas: TPLCustosSemanais; const FileName: string);
var L: TStringList; I: Integer; DeltaP,DeltaC,Pct,Note: string;
begin
 L:=TStringList.Create;
 try
  L.Add('Semana início;Semana fim;Custo previsto;Custo computado;Desvio computado-previsto;Variação semanal previsto;Variação semanal computado;Variação computado %;Observação');
  for I:=0 to High(Semanas) do begin
   DeltaP:=''; DeltaC:=''; Pct:=''; Note:='';
   if Semanas[I].TemAnterior then begin DeltaP:=EAMoneyText(Semanas[I].DeltaPrevisto); DeltaC:=EAMoneyText(Semanas[I].DeltaComputado); Pct:=PercentText(Semanas[I].Computado,Semanas[I-1].Computado); end else Note:='Base inicial';
   if not Semanas[I].TemApuracao then Note:='Sem nova apuração; valores mantidos';
   L.Add(CSV(PLDataISO(Semanas[I].Inicio))+';'+CSV(PLDataISO(Semanas[I].Fim))+';'+CSV(EAMoneyText(Semanas[I].Previsto))+';'+CSV(EAMoneyText(Semanas[I].Computado))+';'+CSV(EAMoneyText(Semanas[I].Desvio))+';'+CSV(DeltaP)+';'+CSV(DeltaC)+';'+CSV(Pct)+';'+CSV(Note));
  end;
  EAAtomicWriteText(FileName,#$EF#$BB#$BF+L.Text);
 finally L.Free; end;
end;
procedure PLExportarCustosHTML(Doc: TPLProjeto; const Semanas: TPLCustosSemanais; const FileName: string);
var L: TStringList; I: Integer; Pct,DeltaP,DeltaC,Note: string;
begin
 L:=TStringList.Create;
 try
  L.Add('<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Relatório semanal de custos</title><style>body{font:15px Arial;margin:32px;color:#0f172a}h1{color:#1e40af}table{border-collapse:collapse;width:100%}th,td{padding:8px;border-bottom:1px solid #cbd5e1;text-align:right}th:first-child,td:first-child{text-align:left}th{background:#e2e8f0}.over{color:#b91c1c}svg{max-height:340px;width:100%}@media print{body{margin:10px;font-size:10px}}</style><h1>'+Esc(Doc.Nome)+'</h1><h2>Relatório semanal — previsto e computado</h2>');
  L.Add('<p>Previsto atual: '+Esc(EAMoneyText(Doc.CustoPrevistoProjeto))+' | Computado atual: '+Esc(EAMoneyText(Doc.CustoComputadoProjeto))+'</p>');
  L.Add('<p>Apurações históricas por semana (segunda a domingo). Primeira semana é a base inicial; valores sem nova apuração são mantidos. Os registros não são uma distribuição estimada de desembolsos nem comprovantes de pagamento.</p>');
  L.Add(PLGraficoCustosSVG(Semanas)); L.Add('<table><thead><tr><th>Semana</th><th>Previsto</th><th>Computado</th><th>Desvio</th><th>Δ previsto</th><th>Δ computado</th><th>Δ computado %</th><th>Observação</th></tr></thead><tbody>');
  for I:=0 to High(Semanas) do begin
   DeltaP:='—'; DeltaC:='—'; Pct:='—'; Note:='Base inicial';
   if Semanas[I].TemAnterior then begin DeltaP:=EAMoneyText(Semanas[I].DeltaPrevisto); DeltaC:=EAMoneyText(Semanas[I].DeltaComputado); Pct:=PercentText(Semanas[I].Computado,Semanas[I-1].Computado); Note:=''; end;
   if not Semanas[I].TemApuracao then Note:='Sem nova apuração';
   if Semanas[I].Desvio>0 then L.Add('<tr class="over">') else L.Add('<tr>');
   L.Add('<td>'+FormatDateTime('dd/mm/yyyy',Semanas[I].Inicio)+' a '+FormatDateTime('dd/mm/yyyy',Semanas[I].Fim)+'</td><td>'+Esc(EAMoneyText(Semanas[I].Previsto))+'</td><td>'+Esc(EAMoneyText(Semanas[I].Computado))+'</td><td>'+Esc(EAMoneyText(Semanas[I].Desvio))+'</td><td>'+Esc(DeltaP)+'</td><td>'+Esc(DeltaC)+'</td><td>'+Esc(Pct)+'</td><td>'+Esc(Note)+'</td></tr>');
  end;
  L.Add('</tbody></table></html>'); EAAtomicWriteText(FileName,L.Text);
 finally L.Free; end;
end;
end.
