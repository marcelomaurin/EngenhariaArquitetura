program test_planejador_core;

{ Testes do modelo do Planejador (etapa P1): tarefas, dependencias,
  recusa de ciclo, caminho critico e ida e volta em JSON.
  Uso: test_planejador_core   (codigo de saida 0 = todos passaram) }

{$mode objfpc}{$H+}{$codepage utf8}

uses
  Classes, SysUtils, DateUtils, fpjson, aiprojectduration, aitaskgraph, plan_tipos, plan_documento,
  plan_cronograma, plan_json, plan_exemplos, plan_executor;

var
  Falhas, Total: Integer;

procedure Confere(Cond: Boolean; const Msg: string);
begin
  Inc(Total);
  if Cond then
    WriteLn('  ok    ', Msg)
  else
  begin
    Inc(Falhas);
    WriteLn('  FALHA ', Msg);
  end;
end;

procedure ConfereTexto(const Obtido, Esperado, Msg: string);
begin
  Confere(Obtido = Esperado, Format('%s (obtido "%s", esperado "%s")', [Msg, Obtido, Esperado]));
end;

function DH(D: TDateTime): string;
begin
  Result := FormatDateTime('yyyy"-"mm"-"dd hh":"nn', D);
end;

{ projeto de referencia, calendario seg-sex 08-12 e 13-17, sem feriados:
  A 5d; B 3d (A); C 2d (A); D 1d (B; C) -- inicio seg 09/11/2026 }
function Referencia: TPLProjeto;
var A, B, C, D: TPLTarefa; Err: string;
begin
  Result := TPLProjeto.Create;
  Result.Novo('Referência', EncodeDate(2026, 11, 9));
  Result.Calendario.Clear;
  Result.Calendario.SetStandard;
  A := Result.NovaTarefa('Levantamento');
  B := Result.NovaTarefa('Planta do térreo');
  C := Result.NovaTarefa('Planta do superior');
  D := Result.NovaTarefa('Maquete');
  Result.DefinirDuracao(A, '5d', Err);
  Result.DefinirDuracao(B, '3d', Err);
  Result.DefinirDuracao(C, '2d', Err);
  Result.DefinirDuracao(D, '1d', Err);
  B.Aplicativo := plaCAD2D;
  C.Aplicativo := plaCAD2D;
  D.Aplicativo := plaMaquete3D;
  Result.DefinirPredecessoras(B, 'T-0001', Err);
  Result.DefinirPredecessoras(C, 'T-0001', Err);
  Result.DefinirPredecessoras(D, 'T-0002; T-0003', Err);
end;

procedure TesteIdsEDuracoes;
var P: TPLProjeto; T: TPLTarefa; Err: string;
begin
  WriteLn('IDs e durações');
  P := TPLProjeto.Create;
  try
    T := P.NovaTarefa('Primeira');
    ConfereTexto(T.Id, 'T-0001', 'primeiro ID');
    ConfereTexto(P.NovaTarefa('Segunda').Id, 'T-0002', 'segundo ID');
    Confere(P.DefinirDuracao(T, '2sem', Err), 'aceita "2sem"');
    Confere(T.Duracao.Minutes = 2 * PL_MINUTOS_POR_SEMANA, 'duas semanas = 4800 min');
    Confere(P.DefinirDuracao(T, '0d', Err) and T.Marco, 'duração zero vira marco');
    Confere(not P.DefinirDuracao(T, 'abc', Err), 'recusa duração inválida');
    P.ExcluirTarefa(0);
    ConfereTexto(P.NovaTarefa('Terceira').Id, 'T-0003', 'ID não é reutilizado após exclusão');
  finally
    P.Free;
  end;
end;

procedure TesteDependencias;
var P: TPLProjeto; Err: string;
begin
  WriteLn('Dependências');
  P := Referencia;
  try
    ConfereTexto(P.TextoPredecessoras(P[3]), 'T-0002; T-0003', 'texto das predecessoras');
    Confere(not P.DefinirPredecessoras(P[0], 'T-0004', Err), 'recusa ciclo A <- D');
    Confere(Length(P[0].Predecessoras) = 0, 'ciclo recusado não altera a tarefa');
    Confere(not P.DefinirPredecessoras(P[0], 'T-0001', Err), 'recusa auto-vínculo');
    Confere(not P.DefinirPredecessoras(P[0], 'T-0099', Err), 'recusa tarefa inexistente');
    Confere(P.DefinirPredecessoras(P[3], 't-0002II+1d', Err), 'aceita tipo II com latência');
    ConfereTexto(P.TextoPredecessoras(P[3]), 'T-0002II+1d', 'normaliza a grafia do ID');
    P.DefinirPredecessoras(P[3], 'T-0002; T-0003', Err);
    P.ExcluirTarefa(1);
    ConfereTexto(P.TextoPredecessoras(P[2]), 'T-0003', 'exclusão remove o vínculo');
  finally
    P.Free;
  end;
end;

procedure TesteVinculos;
var P: TPLProjeto; Err: string; S: TStringArray;
begin
  WriteLn('Vínculos individuais (painel, Ctrl+F2 e diagrama de rede)');
  P := TPLProjeto.Create;
  try
    P.NovaTarefa('A'); P.NovaTarefa('B'); P.NovaTarefa('C');
    Confere(P.VincularProxima(0, Err), 'Ctrl+F2 liga A -> B');
    ConfereTexto(P.TextoPredecessoras(P[1]), 'T-0001', 'B depende de A');
    Confere(P.AdicionarVinculo('T-0002', 'T-0003', atlSS, AIMakeLag(PL_MINUTOS_POR_DIA), Err),
      'vínculo II com latência B -> C');
    ConfereTexto(P.TextoPredecessoras(P[2]), 'T-0002II+1d', 'texto do vínculo II');
    Confere(not P.AdicionarVinculo('T-0003', 'T-0001', atlFS, AINoLag, Err), 'recusa ciclo C -> A');
    Confere(Pos('ciclo', Err) > 0, 'mensagem menciona o ciclo');
    Confere(not P.AdicionarVinculo('T-0001', 'T-0002', atlFS, AINoLag, Err), 'recusa vínculo repetido');
    Confere(not P.AdicionarVinculo('T-0001', 'T-0001', atlFS, AINoLag, Err), 'recusa auto-vínculo');
    Confere(not P.VincularProxima(2, Err), 'última tarefa não tem próxima');
    S := P.Sucessoras('T-0002');
    Confere((Length(S) = 1) and (S[0] = 'T-0003'), 'sucessoras de B');
    Confere(P.RemoverVinculo('T-0002', 'T-0003'), 'remove B -> C');
    ConfereTexto(P.TextoPredecessoras(P[2]), '', 'C ficou sem predecessoras');
    P.VincularProxima(1, Err);
    Confere(P.Desvincular(1) = 2, 'desvincular B remove entrada e saída');
    Confere((Length(P[1].Predecessoras) = 0) and (Length(P[2].Predecessoras) = 0), 'B isolada');
  finally
    P.Free;
  end;
end;

procedure TesteCaminhoCritico;
var P: TPLProjeto; C: TPLCronograma; Err: string;
begin
  WriteLn('Caminho crítico');
  P := Referencia;
  C := TPLCronograma.Create;
  try
    C.Calcular(P);
    Confere(C.Valido, 'cronograma válido');
    ConfereTexto(DH(C.Resultado[0].Start), '2026-11-09 08:00', 'início de A');
    ConfereTexto(DH(C.Resultado[0].Finish), '2026-11-13 17:00', 'término de A');
    ConfereTexto(DH(C.Resultado[1].Start), '2026-11-16 08:00', 'início de B');
    ConfereTexto(DH(C.Resultado[1].Finish), '2026-11-18 17:00', 'término de B');
    ConfereTexto(DH(C.Resultado[2].Finish), '2026-11-17 17:00', 'término de C');
    ConfereTexto(DH(C.Resultado[3].Start), '2026-11-19 08:00', 'início de D');
    ConfereTexto(DH(C.Termino), '2026-11-19 17:00', 'término do projeto');
    Confere(C.Resultado[0].Critical and C.Resultado[1].Critical and C.Resultado[3].Critical,
      'A, B e D são críticas');
    Confere(not C.Resultado[2].Critical, 'C não é crítica');
    Confere(C.Resultado[2].TotalSlack = PL_MINUTOS_POR_DIA, 'folga de C = 1 dia');
    Confere(C.Criticas = 3, 'três tarefas críticas');
    { latencia de 2 dias depois de B empurra D }
    P.DefinirPredecessoras(P[3], 'T-0002TI+2d; T-0003', Err);
    C.Calcular(P);
    ConfereTexto(DH(C.Termino), '2026-11-23 17:00', 'latência de 2 dias empurra o término');
  finally
    C.Free;
    P.Free;
  end;
end;

procedure TesteJSON;
var P, Q: TPLProjeto; C1, C2: TPLCronograma; Arq: string; I: Integer; Igual: Boolean;
begin
  WriteLn('Gravação em JSON');
  Arq := GetTempDir + 'teste_planejador' + PL_EXTENSAO;
  P := Referencia;
  Q := TPLProjeto.Create;
  C1 := TPLCronograma.Create;
  C2 := TPLCronograma.Create;
  try
    P.Objetivo := 'Residência unifamiliar';
    P[1].Responsavel := 'Marcelo';
    P[1].Situacao := plsEmAndamento;
    P[1].Progresso := 40;
    PLSalvarProjeto(P, Arq);
    Confere(not P.Modificado, 'salvar limpa o indicador de modificação');
    PLCarregarProjeto(Q, Arq);
    Confere(Q.Count = 4, 'quatro tarefas lidas');
    ConfereTexto(Q.Objetivo, 'Residência unifamiliar', 'objetivo preservado');
    ConfereTexto(Q[1].Nome, 'Planta do térreo', 'nome com acento preservado');
    Confere(Q[1].Aplicativo = plaCAD2D, 'aplicativo preservado');
    Confere((Q[1].Situacao = plsEmAndamento) and (Q[1].Progresso = 40), 'situação e progresso');
    ConfereTexto(Q.TextoPredecessoras(Q[3]), 'T-0002; T-0003', 'vínculos preservados');
    Confere(Q.Calendario.IsWorkingDay(EncodeDate(2026, 11, 9)), 'calendário preservado');
    C1.Calcular(P);
    C2.Calcular(Q);
    Igual := C2.Valido and (C1.Termino = C2.Termino);
    for I := 0 to P.Count - 1 do
      Igual := Igual and (C1.Resultado[I].Start = C2.Resultado[I].Start);
    Confere(Igual, 'cronograma idêntico após reabrir');
    ConfereTexto(Q.NovaTarefa('Nova').Id, 'T-0005', 'numeração continua após reabrir');
  finally
    C2.Free;
    C1.Free;
    Q.Free;
    P.Free;
    DeleteFile(Arq);
  end;
end;

procedure TesteIntegridadeArquivo;
var P,Q: TPLProjeto; O: TJSONObject; L: TStringList; Hold: TFileStream;
  FileName,Original: string; G: TGUID; Failed: Boolean; CaseNo: Integer;
begin
  CreateGUID(G); FileName:=IncludeTrailingPathDelimiter(GetTempDir)+'plan-validation-'+GUIDToString(G)+'.plan.json';
  P:=Referencia; Q:=TPLProjeto.Create; L:=TStringList.Create;
  try
    PLSalvarProjeto(P,FileName); L.LoadFromFile(FileName); Original:=L.Text;
    P.Nome:='Alteração não gravada'; P.Modificado:=True;
    Hold:=TFileStream.Create(FileName,fmOpenRead or fmShareExclusive);
    try Failed:=False; try PLSalvarProjeto(P,FileName); except on E: Exception do Failed:=True; end;
      Confere(Failed,'falha de escrita reportada');
      Confere(P.Modificado,'falha preserva indicador modificado');
    finally Hold.Free; end;
    L.LoadFromFile(FileName); ConfereTexto(L.Text,Original,'falha preserva arquivo original');
    Q.Novo('Documento preservado',Date); Q.NovaTarefa('Tarefa preservada');
    for CaseNo:=1 to 6 do begin
      O:=PLProjetoParaJSON(P);
      try
        case CaseNo of
          1: begin O.Arrays['tarefas'].Objects[0].Delete('progresso'); O.Arrays['tarefas'].Objects[0].Add('progresso',101); end;
          2: begin O.Arrays['tarefas'].Objects[0].Delete('duracao_min'); O.Arrays['tarefas'].Objects[0].Add('duracao_min',-1); end;
          3: O.Arrays['tarefas'].Objects[0].Arrays['depende_de'].Add(P[3].Id);
          4: O.Arrays['tarefas'].Objects[0].Arrays['depende_de'].Add(P[0].Id);
          5: O.Arrays['tarefas'].Objects[3].Arrays['depende_de'].Add(O.Arrays['tarefas'].Objects[3].Arrays['depende_de'].Items[0].Clone);
          6: begin O.Arrays['tarefas'].Objects[0].Delete('situacao'); O.Arrays['tarefas'].Objects[0].Add('situacao','desconhecida'); end;
        end;
        L.Text:=O.AsJSON; L.SaveToFile(FileName);
        Failed:=False; try PLCarregarProjeto(Q,FileName); except on E: Exception do Failed:=True; end;
        Confere(Failed,'arquivo inválido recusado - caso '+IntToStr(CaseNo));
        Confere((Q.Count=1) and (Q.Nome='Documento preservado'),'documento preservado na falha - caso '+IntToStr(CaseNo));
      finally O.Free; end;
    end;
  finally L.Free; Q.Free; P.Free; DeleteFile(FileName); end;
end;

procedure TesteExemplosSaude;
var P: TPLProjeto; C: TPLCronograma;
begin
  P:=TPLProjeto.Create; C:=TPLCronograma.Create;
  try
    PLCarregarExemploSaude(P,Date,False);
    Confere(P.Count=14,'planejamento UBS com 14 tarefas');
    Confere(Pos('UBS',P.Nome)>0,'exemplo UBS identificado');
    C.Calcular(P); Confere(C.Valido,'cronograma de UBS valido');
    PLCarregarExemploSaude(P,Date,True);
    Confere(Pos('hospitalar',P.Nome)>0,'exemplo hospitalar identificado');
    C.Calcular(P); Confere(C.Valido,'cronograma hospitalar valido');
    PLCarregarExemploResidencia(P,Date);
    Confere(P.Count=11,'exemplo residencial preservado para uso geral');
  finally C.Free; P.Free; end;
end;

procedure TesteDatasEExecutores;
var P,Q: TPLProjeto; C: TPLCronograma; A,B: TPLTarefa;
    Users: TJSONArray; U,O: TJSONObject; D,Boundary: TDateTime; DummyErr: string;
begin
  P:=TPLProjeto.Create; Q:=TPLProjeto.Create; C:=TPLCronograma.Create; Users:=TJSONArray.Create;
  try
    D:=EncodeDate(2026,11,9); P.Novo('Datas e executores',D);
    P.Calendario.Clear; P.Calendario.SetStandard;
    U:=TJSONObject.Create; U.Add('id','admin-id'); U.Add('login','admin'); U.Add('name','Administrador'); U.Add('role','admin'); U.Add('active',True); Users.Add(U);
    U:=TJSONObject.Create; U.Add('id','ana-id'); U.Add('login','ana'); U.Add('name',String('Ana Médica')); U.Add('role','user'); U.Add('active',True); Users.Add(U);
    A:=P.NovaTarefa('Primeira'); B:=P.NovaTarefa('Segunda');
    Confere(PLResolverExecutor(A,Users),'executor ausente recebe administrador');
    ConfereTexto(A.ExecutorID,'admin-id','administrador por identidade');
    ConfereTexto(A.ExecutorNome,'Administrador','nome do executor preenchido');
    Confere(not PLResolverExecutor(A,Users),'resolver executor é idempotente');
    PLResolverExecutor(B,Users); A.InicioSolicitado:=D; B.InicioSolicitado:=D;
    C.Calcular(P); Confere(C.Valido,'sobreposição aceita sem invalidar cronograma');
    Confere(C.Conflito[0] and C.Conflito[1],'mesmo executor sobreposto marca as duas tarefas');
    Confere(C.Avisos.Count>0,'conflito explica tarefas envolvidas');
    B.Responsavel:='ana'; B.ExecutorID:=''; PLResolverExecutor(B,Users);
    C.Calcular(P); Confere(not C.Conflito[0] and not C.Conflito[1],'executores diferentes sem conflito');
    ConfereTexto(B.ExecutorNome,'Ana Médica','usuário indicado mantém nome real');
    B.Responsavel:='admin'; B.ExecutorID:=''; PLResolverExecutor(B,Users);
    Boundary:=C.Resultado[0].Finish; B.InicioSolicitado:=Boundary;
    C.Calcular(P); Confere(not C.Conflito[0] and not C.Conflito[1],'início no término exato não conflita');
    B.InicioSolicitado:=D+3; C.Calcular(P);
    Confere(Trunc(C.Resultado[1].Start)=D+3,'data posterior indicada é respeitada');
    Confere(not C.Conflito[1],'data posterior ao término aceita sem conflito');
    Confere(P.DefinirPredecessoras(B,A.Id,DummyErr),'dependência com data própria aceita');
    B.InicioSolicitado:=D; C.Calcular(P);
    Confere(C.Resultado[1].Start>=C.Resultado[0].Finish,'dependências continuam respeitadas');
    Confere(not C.Conflito[1],'tarefas sequenciais do executor sem conflito');
    B.InicioSolicitado:=D+3;
    O:=PLProjetoParaJSON(P);
    try PLProjetoDeJSON(Q,O); finally O.Free; end;
    Confere(Q[1].InicioSolicitado=D+3,'data própria persiste em JSON');
    ConfereTexto(Q[1].ExecutorID,'admin-id','identidade do executor persiste');
    ConfereTexto(Q[1].ExecutorNome,'Administrador','nome do executor persiste');
    A.Assign(B); Confere(A.InicioSolicitado=B.InicioSolicitado,'cópia mantém data própria');
    ConfereTexto(A.ExecutorID,B.ExecutorID,'cópia mantém executor');
    A.Id:='T-0001'; A.Predecessoras:=nil;
    A.Responsavel:='historico'; A.ExecutorID:=''; A.ExecutorNome:='';
    PLResolverExecutor(A,Users); ConfereTexto(A.Responsavel,'historico','responsável legado desconhecido preservado');
    B.InicioSolicitado:=0; O:=PLProjetoParaJSON(P);
    try PLProjetoDeJSON(Q,O); finally O.Free; end;
    Confere(Q[1].InicioSolicitado=0,'início automático sem data preservado');
  finally Users.Free; C.Free; Q.Free; P.Free; end;
end;

begin
  { como nos aplicativos LCL (LazUTF8): textos em UTF-8 }
  DefaultSystemCodePage := CP_UTF8;
  SetMultiByteConversionCodePage(CP_UTF8);
  Falhas := 0;
  Total := 0;
  TesteIdsEDuracoes;
  TesteDependencias;
  TesteVinculos;
  TesteCaminhoCritico;
  TesteJSON;
  TesteIntegridadeArquivo;
  TesteExemplosSaude;
  TesteDatasEExecutores;
  WriteLn;
  WriteLn(Format('%d verificações, %d falhas', [Total, Falhas]));
  if Falhas > 0 then Halt(1);
end.
