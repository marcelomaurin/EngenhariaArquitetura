unit plan_p234;

{ Planejador - Etapas P2, P3 e P4:
  - P2: Contrato .task.json / .return.json (I-01/I-02), bloqueio por predecessoras (PL-008),
        rastreabilidade por SHA-256 e detecção de insumos desatualizados (PL-009)
  - P3: Linha de base (Baseline) e Curva S física/financeira acumulada (PL-016, PL-017)
  - P4: Vínculo de objetos e texturas/skins por objeto ou face (I-03, PL-020..PL-022) }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, DateUtils, Math, fpjson, jsonparser,
  ea_pacote, ea_fileio, ea_links, ea_money,
  plan_tipos, plan_documento, plan_cronograma, plan_recursos;

type
  TPLCurvaSPonto = record
    Data: TDateTime;
    PlanejadoPct: Double;
    RealizadoPct: Double;
    BaselinePct: Double;
    PlanejadoCentavos: Int64;
    RealizadoCentavos: Int64;
    BaselineCentavos: Int64;
  end;
  TPLCurvaSPontos = array of TPLCurvaSPonto;

function PLCalcularStatusExecucao(Doc: TPLProjeto; T: TPLTarefa): string;
function PLCalcularHashEntradas(Doc: TPLProjeto; T: TPLTarefa; const BaseFile: string): string;
function PLAplicativoExecutavel(App: TPLAplicativo): string;
function PLLocalizarExecutavel(App: TPLAplicativo; const AppDir: string): string;
procedure PLGerarPacoteTarefa(Doc: TPLProjeto; Crono: TPLCronograma; T: TPLTarefa;
  const BaseFile, OutFile: string);
procedure PLProcessarRetornoTarefa(Doc: TPLProjeto; T: TPLTarefa; const ReturnFile: string);

procedure PLCongelarBaseline(Doc: TPLProjeto; Crono: TPLCronograma);
function PLBuscarBaseline(Doc: TPLProjeto; const TaskId: string; out Item: TPLBaselineItem): Boolean;
function PLCalcularCurvaS(Doc: TPLProjeto; Crono: TPLCronograma): TPLCurvaSPontos;
procedure PLExportarCurvaSCSV(const Pontos: TPLCurvaSPontos; const FileName: string);

procedure PLVincularObjetoTextura(Doc: TPLProjeto; T: TPLTarefa;
  const ObjetoId, TexturaId, Destino, FaceId, Versao: string);
procedure PLExportarPacoteObjetoTextura(T: TPLTarefa; const OutFile: string);

implementation

function PLCalcularStatusExecucao(Doc: TPLProjeto; T: TPLTarefa): string;
var
  I, PredIdx: Integer;
  Pred: TPLTarefa;
begin
  if T = nil then Exit('bloqueada');
  if T.ExecStatus = 'desatualizada' then Exit('desatualizada');
  if T.Situacao = plsConcluida then Exit('concluida');
  for I := 0 to High(T.Predecessoras) do
  begin
    PredIdx := Doc.IndiceDe(T.Predecessoras[I].Id);
    if PredIdx >= 0 then
    begin
      Pred := Doc[PredIdx];
      if Pred.Situacao <> plsConcluida then
        Exit('bloqueada');
    end;
  end;
  if T.ExecStatus = 'em_execucao' then Exit('em_execucao');
  if T.ExecStatus = 'em_revisao' then Exit('em_revisao');
  if T.ExecStatus = 'falhou' then Exit('falhou');
  Result := 'pronta';
end;

function PLCalcularHashEntradas(Doc: TPLProjeto; T: TPLTarefa; const BaseFile: string): string;
var
  I, K: Integer;
  R: TPLRecurso;
  Acc, Resolved: string;
begin
  Acc := '';
  for I := 0 to High(T.Alocacoes) do
  begin
    if T.Alocacoes[I].Direcao <> prdEntrada then Continue;
    K := Doc.RecursoIndice(T.Alocacoes[I].RecursoID);
    if K < 0 then Continue;
    R := Doc.Recursos[K];
    if R.Tipo <> prtArquivo then Continue;
    try
      Resolved := EAResolveLink(R.Link, BaseFile);
    except
      Resolved := R.Link;
    end;
    if FileExists(Resolved) then
      Acc := Acc + R.ID + '=' + EASHA256File(Resolved) + ';'
    else
      Acc := Acc + R.ID + '=missing;'
  end;
  Result := EASHA256String(Acc);
end;

function PLAplicativoExecutavel(App: TPLAplicativo): string;
begin
  case App of
    plaCAD2D: Result := 'cad2d';
    plaMaquete3D: Result := 'maquete3d';
    plaCriadorCenas: Result := 'criadorcenas';
    plaEletrica3D: Result := 'eletrica3d';
    plaSimuEletrica: Result := 'simueletrica';
    plaSimuTubulacoes: Result := 'simutubulacoes';
  else
    Result := '';
  end;
  {$IFDEF WINDOWS}
  if Result <> '' then Result := Result + '.exe';
  {$ENDIF}
end;

function PLLocalizarExecutavel(App: TPLAplicativo; const AppDir: string): string;
var
  ExeName, Base: string;
begin
  ExeName := PLAplicativoExecutavel(App);
  if ExeName = '' then Exit('');
  Base := IncludeTrailingPathDelimiter(AppDir);
  if FileExists(Base + ExeName) then Exit(Base + ExeName);
  if FileExists(ExpandFileName(Base + '..' + DirectorySeparator + 'bin' + DirectorySeparator + ExeName)) then
    Exit(ExpandFileName(Base + '..' + DirectorySeparator + 'bin' + DirectorySeparator + ExeName));
  Result := '';
end;

procedure PLGerarPacoteTarefa(Doc: TPLProjeto; Crono: TPLCronograma; T: TPLTarefa;
  const BaseFile, OutFile: string);
var
  Pkg: TEAPackageManifest;
  Payload, Params, InObj, TexObj: TJSONObject;
  Deps, Entradas, TexArr: TJSONArray;
  I, K, TIdx: Integer;
  R: TPLRecurso;
  Resolved, HashVal: string;
  Status: string;
begin
  if (Doc = nil) or (T = nil) then raise Exception.Create('Tarefa inválida');
  Status := PLCalcularStatusExecucao(Doc, T);
  if Status = 'bloqueada' then
    raise Exception.CreateFmt('Tarefa %s bloqueada: conclua as predecessoras antes de despachar.', [T.Id]);

  Pkg := TEAPackageManifest.Create;
  Payload := TJSONObject.Create;
  try
    Pkg.PackageType := EA_PKG_TAREFA;
    Pkg.PackageId := 'task-' + T.Id;
    Pkg.Revision := 'rev-' + FormatDateTime('yyyymmddhhnnss', Now);
    Pkg.CreatedByApp := 'Planejador';

    Payload.Add('task_id', T.Id);
    Payload.Add('nome', T.Nome);
    Payload.Add('aplicativo', PL_APLICATIVO_CODIGO[T.Aplicativo]);
    Payload.Add('situacao', PL_SITUACAO_CODIGO[T.Situacao]);
    Payload.Add('exec_status', Status);

    TIdx := Doc.IndiceDe(T.Id);
    if (Crono <> nil) and Crono.Valido and (TIdx >= 0) and (TIdx < Doc.Count) then
      Payload.Add('prazo', FormatDateTime('yyyy"-"mm"-"dd', Crono.Resultado[TIdx].Finish));

    Deps := TJSONArray.Create;
    for I := 0 to High(T.Predecessoras) do Deps.Add(T.Predecessoras[I].Id);
    Payload.Add('depende_de', Deps);

    Entradas := TJSONArray.Create;
    for I := 0 to High(T.Alocacoes) do
    begin
      if T.Alocacoes[I].Direcao <> prdEntrada then Continue;
      K := Doc.RecursoIndice(T.Alocacoes[I].RecursoID);
      if (K < 0) or (Doc.Recursos[K].Tipo <> prtArquivo) then Continue;
      R := Doc.Recursos[K];
      try Resolved := EAResolveLink(R.Link, BaseFile); except Resolved := R.Link; end;
      if FileExists(Resolved) then HashVal := EASHA256File(Resolved) else HashVal := '';
      InObj := TJSONObject.Create;
      InObj.Add('nome', R.Nome);
      InObj.Add('arquivo', Resolved);
      InObj.Add('hash', HashVal);
      Entradas.Add(InObj);
    end;
    Payload.Add('entradas', Entradas);

    Params := TJSONObject.Create;
    Params.Add('projeto', Doc.Nome);
    Params.Add('responsavel', T.Responsavel);
    Payload.Add('parametros', Params);

    if T.ObjetoId <> '' then Payload.Add('objeto', T.ObjetoId);
    if Length(T.Texturas) > 0 then
    begin
      TexArr := TJSONArray.Create;
      for I := 0 to High(T.Texturas) do
      begin
        TexObj := TJSONObject.Create;
        TexObj.Add('textura_id', T.Texturas[I].TexturaId);
        TexObj.Add('destino', T.Texturas[I].Destino);
        TexObj.Add('face_id', T.Texturas[I].FaceId);
        TexObj.Add('versao', T.Texturas[I].Versao);
        TexArr.Add(TexObj);
      end;
      Payload.Add('texturas', TexArr);
    end;

    T.EntradasHash := PLCalcularHashEntradas(Doc, T, BaseFile);
    T.ExecStatus := 'em_execucao';
    Pkg.Payload := Payload;
    Payload := nil;
    Pkg.SaveToFile(OutFile);
    Doc.MarcarModificado;
  finally
    Payload.Free;
    Pkg.Free;
  end;
end;

procedure PLProcessarRetornoTarefa(Doc: TPLProjeto; T: TPLTarefa; const ReturnFile: string);
var
  Pkg: TEAPackageManifest;
  Ret: TJSONObject;
  Saidas: TJSONArray;
  SObj: TJSONObject;
  I, J: Integer;
  OutPath, ExpectedHash, ActualHash, Sit: string;
  Reg: TPLRetornoRegistro;
  Succs: TStringArray;
begin
  if (Doc = nil) or (T = nil) then raise Exception.Create('Tarefa inválida');
  Pkg := TEAPackageManifest.Create;
  try
    Pkg.LoadFromFile(ReturnFile);
    if Pkg.PackageType <> EA_PKG_RETORNO_TAREFA then
      raise Exception.Create('Pacote não é do tipo retorno_tarefa');
    Ret := Pkg.Payload;
    if Ret = nil then raise Exception.Create('Retorno sem conteúdo');
    if Ret.Get('task_id', '') <> T.Id then
      raise Exception.CreateFmt('Retorno pertence à tarefa %s, esperado %s', [Ret.Get('task_id', ''), T.Id]);

    Saidas := Ret.Get('saidas', TJSONArray(nil));
    OutPath := '';
    ActualHash := '';
    if (Saidas <> nil) and (Saidas.Count > 0) then
    begin
      for I := 0 to Saidas.Count - 1 do
      begin
        SObj := Saidas.Objects[I];
        OutPath := SObj.Get('arquivo', '');
        ExpectedHash := SObj.Get('hash', '');
        if OutPath = '' then raise Exception.Create('Saída de retorno sem caminho de arquivo');
        if not FileExists(OutPath) then
          raise Exception.Create('Arquivo de saída do retorno não encontrado: ' + OutPath);
        ActualHash := EASHA256File(OutPath);
        if (ExpectedHash <> '') and (ActualHash <> ExpectedHash) then
          raise Exception.Create('Falha de integridade SHA-256 na saída do retorno: ' + OutPath);
      end;
    end;

    Sit := Ret.Get('situacao', 'em_revisao');
    Reg.DataHora := EANowISO8601;
    Reg.Situacao := Sit;
    Reg.SaidaArquivo := OutPath;
    Reg.SaidaHash := ActualHash;
    Reg.Mensagem := Ret.Get('mensagem', '');
    J := Length(T.HistoricoRetorno);
    SetLength(T.HistoricoRetorno, J + 1);
    T.HistoricoRetorno[J] := Reg;

    if Sit = 'concluida' then
    begin
      if OutPath = '' then
        raise Exception.Create('Conclusão exige ao menos um arquivo de saída válido');
      T.Situacao := plsConcluida;
      T.Progresso := 100;
      T.ExecStatus := 'concluida';
      { Se alguma sucessora já havia sido executada, sinaliza desatualizada (PL-009) }
      Succs := Doc.Sucessoras(T.Id);
      for I := 0 to High(Succs) do
      begin
        J := Doc.IndiceDe(Succs[I]);
        if (J >= 0) and (Doc[J].Situacao <> plsAFazer) then
          Doc[J].ExecStatus := 'desatualizada';
      end;
    end
    else if Sit = 'falhou' then
      T.ExecStatus := 'falhou'
    else
      T.ExecStatus := 'em_revisao';

    Doc.MarcarModificado;
  finally
    Pkg.Free;
  end;
end;

procedure PLCongelarBaseline(Doc: TPLProjeto; Crono: TPLCronograma);
var
  I: Integer;
begin
  if (Doc = nil) or (Crono = nil) or (not Crono.Valido) then
    raise Exception.Create('Calcule um cronograma válido antes de congelar a linha de base');
  SetLength(Doc.Baseline, Doc.Count);
  for I := 0 to Doc.Count - 1 do
  begin
    Doc.Baseline[I].TaskId := Doc[I].Id;
    Doc.Baseline[I].Inicio := Crono.Resultado[I].Start;
    Doc.Baseline[I].Termino := Crono.Resultado[I].Finish;
    Doc.Baseline[I].CustoCentavos := Doc.CustoTarefa(Doc[I], False);
  end;
  Doc.MarcarModificado;
end;

function PLBuscarBaseline(Doc: TPLProjeto; const TaskId: string; out Item: TPLBaselineItem): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Doc = nil then Exit;
  for I := 0 to High(Doc.Baseline) do
    if Doc.Baseline[I].TaskId = TaskId then
    begin
      Item := Doc.Baseline[I];
      Exit(True);
    end;
end;

function PLCalcularCurvaS(Doc: TPLProjeto; Crono: TPLCronograma): TPLCurvaSPontos;
var
  D0, D1, CurD: TDateTime;
  I, K, N: Integer;
  TotalDur, PlanDur, RealDur, BaseDur, TaskDur: Double;
  TotalCusto, TotalBaseCusto, TaskCusto, PlanCusto, RealCusto, BaseCusto: Int64;
  S, F: TDateTime;
  Frac: Double;
  BItem: TPLBaselineItem;
begin
  Result := nil;
  if (Doc = nil) or (Crono = nil) or (not Crono.Valido) or (Doc.Count = 0) then Exit;
  D0 := Crono.Inicio;
  D1 := Crono.Termino;
  for I := 0 to High(Doc.Baseline) do
  begin
    if Doc.Baseline[I].Inicio > 0 then D0 := Min(D0, Doc.Baseline[I].Inicio);
    if Doc.Baseline[I].Termino > 0 then D1 := Max(D1, Doc.Baseline[I].Termino);
  end;
  if D1 < D0 then D1 := D0;
  N := Max(2, Ceil((D1 - D0) / 7.0) + 1);
  if N > 520 then N := 520;
  SetLength(Result, N);

  TotalDur := 0.0; TotalCusto := 0; TotalBaseCusto := 0;
  for I := 0 to Doc.Count - 1 do
  begin
    TaskDur := Max(1.0, Doc[I].Duracao.Minutes / PL_MINUTOS_POR_DIA);
    TotalDur := TotalDur + TaskDur;
    TotalCusto := TotalCusto + Doc.CustoTarefa(Doc[I], False);
    if PLBuscarBaseline(Doc, Doc[I].Id, BItem) then
      TotalBaseCusto := TotalBaseCusto + BItem.CustoCentavos;
  end;
  if TotalDur <= 0 then TotalDur := 1.0;

  for K := 0 to N - 1 do
  begin
    CurD := Min(D1, D0 + K * 7.0);
    if K = N - 1 then CurD := D1;
    PlanDur := 0; RealDur := 0; BaseDur := 0;
    PlanCusto := 0; RealCusto := 0; BaseCusto := 0;
    for I := 0 to Doc.Count - 1 do
    begin
      TaskDur := Max(1.0, Doc[I].Duracao.Minutes / PL_MINUTOS_POR_DIA);
      TaskCusto := Doc.CustoTarefa(Doc[I], False);
      S := Crono.Resultado[I].Start;
      F := Crono.Resultado[I].Finish;
      if F <= S then
        Frac := Ord(CurD >= F)
      else
        Frac := EnsureRange((CurD - S) / (F - S), 0.0, 1.0);
      PlanDur := PlanDur + TaskDur * Frac;
      PlanCusto := PlanCusto + Round(TaskCusto * Frac);

      RealDur := RealDur + TaskDur * (Doc[I].Progresso / 100.0) * Frac;
      RealCusto := RealCusto + Round(Doc.CustoTarefa(Doc[I], True) * Frac);

      if PLBuscarBaseline(Doc, Doc[I].Id, BItem) then
      begin
        if BItem.Termino <= BItem.Inicio then Frac := Ord(CurD >= BItem.Termino)
        else Frac := EnsureRange((CurD - BItem.Inicio) / (BItem.Termino - BItem.Inicio), 0.0, 1.0);
        BaseDur := BaseDur + TaskDur * Frac;
        BaseCusto := BaseCusto + Round(BItem.CustoCentavos * Frac);
      end;
    end;
    Result[K].Data := CurD;
    Result[K].PlanejadoPct := EnsureRange(100.0 * PlanDur / TotalDur, 0.0, 100.0);
    Result[K].RealizadoPct := EnsureRange(100.0 * RealDur / TotalDur, 0.0, 100.0);
    Result[K].BaselinePct := EnsureRange(100.0 * BaseDur / TotalDur, 0.0, 100.0);
    Result[K].PlanejadoCentavos := PlanCusto;
    Result[K].RealizadoCentavos := RealCusto;
    Result[K].BaselineCentavos := BaseCusto;
  end;
end;

procedure PLExportarCurvaSCSV(const Pontos: TPLCurvaSPontos; const FileName: string);
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('Data;Planejado_Pct;Realizado_Pct;Baseline_Pct;Planejado_BRL;Realizado_BRL;Baseline_BRL');
    for I := 0 to High(Pontos) do
      SL.Add(Format('%s;%.2f;%.2f;%.2f;%s;%s;%s', [
        FormatDateTime('yyyy-mm-dd', Pontos[I].Data),
        Pontos[I].PlanejadoPct, Pontos[I].RealizadoPct, Pontos[I].BaselinePct,
        EAMoneyText(Pontos[I].PlanejadoCentavos),
        EAMoneyText(Pontos[I].RealizadoCentavos),
        EAMoneyText(Pontos[I].BaselineCentavos)]));
    EAAtomicWriteText(FileName, #$EF#$BB#$BF + SL.Text);
  finally
    SL.Free;
  end;
end;

procedure PLVincularObjetoTextura(Doc: TPLProjeto; T: TPLTarefa;
  const ObjetoId, TexturaId, Destino, FaceId, Versao: string);
var
  N: Integer;
  Dest: string;
begin
  if (Doc = nil) or (T = nil) then raise Exception.Create('Tarefa inválida');
  if Trim(ObjetoId) = '' then raise Exception.Create('Informe o object_id do objeto na Maquete 3D');
  if Trim(TexturaId) = '' then raise Exception.Create('Informe o textura_id da biblioteca de texturas');
  Dest := LowerCase(Trim(Destino));
  if (Dest <> 'objeto') and (Dest <> 'face') then
    raise Exception.Create('Destino deve ser "objeto" ou "face"');
  if (Dest = 'face') and (Trim(FaceId) = '') then
    raise Exception.Create('Informe o face_id para vínculo em face específica');

  T.ObjetoId := Trim(ObjetoId);
  N := Length(T.Texturas);
  SetLength(T.Texturas, N + 1);
  T.Texturas[N].TexturaId := Trim(TexturaId);
  T.Texturas[N].Destino := Dest;
  T.Texturas[N].FaceId := Trim(FaceId);
  if Trim(Versao) <> '' then T.Texturas[N].Versao := Trim(Versao) else T.Texturas[N].Versao := '1.0';
  Doc.MarcarModificado;
end;

procedure PLExportarPacoteObjetoTextura(T: TPLTarefa; const OutFile: string);
var
  Pkg: TEAPackageManifest;
  Payload, TexObj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  if (T = nil) or (T.ObjetoId = '') then
    raise Exception.Create('Tarefa não possui objeto vinculado');
  Pkg := TEAPackageManifest.Create;
  Payload := TJSONObject.Create;
  try
    Pkg.PackageType := EA_PKG_TEXTURA;
    Pkg.PackageId := 'link-tex-' + T.Id;
    Pkg.CreatedByApp := 'Planejador';
    Payload.Add('task_id', T.Id);
    Payload.Add('object_id', T.ObjetoId);
    Arr := TJSONArray.Create;
    for I := 0 to High(T.Texturas) do
    begin
      TexObj := TJSONObject.Create;
      TexObj.Add('textura_id', T.Texturas[I].TexturaId);
      TexObj.Add('destino', T.Texturas[I].Destino);
      TexObj.Add('face_id', T.Texturas[I].FaceId);
      TexObj.Add('versao', T.Texturas[I].Versao);
      Arr.Add(TexObj);
    end;
    Payload.Add('texturas', Arr);
    Pkg.Payload := Payload;
    Payload := nil;
    Pkg.SaveToFile(OutFile);
  finally
    Payload.Free;
    Pkg.Free;
  end;
end;

end.
