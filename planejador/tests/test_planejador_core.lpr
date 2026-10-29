program test_planejador_core;

{ Testes do modelo do Planejador (etapa P1): tarefas, dependencias,
  recusa de ciclo, caminho critico e ida e volta em JSON.
  Uso: test_planejador_core   (codigo de saida 0 = todos passaram) }

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils, aiprojectduration, plan_tipos, plan_documento,
  plan_cronograma, plan_json;

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

begin
  { como nos aplicativos LCL (LazUTF8): textos em UTF-8 }
  DefaultSystemCodePage := CP_UTF8;
  SetMultiByteConversionCodePage(CP_UTF8);
  Falhas := 0;
  Total := 0;
  TesteIdsEDuracoes;
  TesteDependencias;
  TesteCaminhoCritico;
  TesteJSON;
  WriteLn;
  WriteLn(Format('%d verificações, %d falhas', [Total, Falhas]));
  if Falhas > 0 then Halt(1);
end.
