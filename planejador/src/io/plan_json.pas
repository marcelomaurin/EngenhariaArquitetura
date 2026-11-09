unit plan_json;

{ Planejador - gravacao e leitura do projeto em JSON versionado.
  Estrutura segue o contrato de tarefa de docs/Planejador.md e o
  manifesto comum de docs/Integracoes.md (schema_version, package_type). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, fpjson, jsonparser, aiprojectduration,
  aitaskgraph, plan_tipos, plan_documento, plan_recursos, plan_sprints, plan_apontamentos, ea_fileio;

const
  PL_SCHEMA_VERSION = '1.3';
  PL_PACKAGE_TYPE = 'projeto_planejador';
  PL_VERSAO_APLICATIVO = '0.9.0';
  PL_EXTENSAO = '.plan.json';

function PLProjetoParaJSON(Doc: TPLProjeto): TJSONObject;
procedure PLProjetoDeJSON(Doc: TPLProjeto; O: TJSONObject);
procedure PLSalvarProjeto(Doc: TPLProjeto; const AArquivo: string);
procedure PLCarregarProjeto(Doc: TPLProjeto; const AArquivo: string);

implementation

function DataISO(D: TDateTime): string;
begin
  Result := FormatDateTime('yyyy"-"mm"-"dd', D);
end;

function DataDeISO(const S: string; Padrao: TDateTime): TDateTime;
var A, M, D: Integer;
begin
  Result := Padrao;
  if Length(S) < 10 then Exit;
  if TryStrToInt(Copy(S, 1, 4), A) and TryStrToInt(Copy(S, 6, 2), M)
    and TryStrToInt(Copy(S, 9, 2), D) then
    if not TryEncodeDate(A, M, D, Result) then Result := Padrao;
end;

function PLProjetoParaJSON(Doc: TPLProjeto): TJSONObject;
var
  P, T, C, L: TJSONObject;
  Arr, Deps, ResourcesJSON,AllocationsJSON,CostsJSON,SprintsJSON,HistoryJSON,LogsJSON: TJSONArray;
  I, J: Integer;
  Tar: TPLTarefa;
begin
  Doc.ValidarRecursos; Doc.ValidarAcompanhamento;
  Result := TJSONObject.Create;
  Result.Add('schema_version', PL_SCHEMA_VERSION);
  Result.Add('package_type', PL_PACKAGE_TYPE);
  C := TJSONObject.Create;
  C.Add('application', 'Planejador');
  C.Add('version', PL_VERSAO_APLICATIVO);
  Result.Add('created_by', C);
  Result.Add('units', 'mm');

  P := TJSONObject.Create;
  P.Add('nome', Doc.Nome);
  P.Add('objetivo', Doc.Objetivo);
  P.Add('inicio', DataISO(Doc.Inicio));
  P.Add('orcamento_fixado',Doc.OrcamentoFixado); P.Add('orcamento_centavos',Doc.OrcamentoCentavos);
  P.Add('calendario', Doc.Calendario.ToJSON);
  Result.Add('projeto', P);

  ResourcesJSON:=TJSONArray.Create;
  for I:=0 to Doc.Recursos.Count-1 do ResourcesJSON.Add(Doc.Recursos[I].ParaJSON);
  Result.Add('recursos',ResourcesJSON);
  LogsJSON:=TJSONArray.Create; for I:=0 to High(Doc.Apontamentos) do LogsJSON.Add(PLApontamentoJSON(Doc.Apontamentos[I])); Result.Add('apontamentos',LogsJSON);
  SprintsJSON:=TJSONArray.Create; for I:=0 to Doc.Sprints.Count-1 do SprintsJSON.Add(Doc.Sprints[I].ParaJSON); Result.Add('sprints',SprintsJSON);
  HistoryJSON:=TJSONArray.Create; for I:=0 to High(Doc.HistoricoCustos) do begin
    L:=TJSONObject.Create; L.Add('date',PLDataISO(Doc.HistoricoCustos[I].Data)); L.Add('planned_cents',Doc.HistoricoCustos[I].Previsto); L.Add('computed_cents',Doc.HistoricoCustos[I].Computado); HistoryJSON.Add(L);
  end; Result.Add('historico_custos',HistoryJSON);
  Result.Add('custo_previsto_centavos',Doc.CustoPrevistoProjeto); Result.Add('custo_computado_centavos',Doc.CustoComputadoProjeto);
  Arr := TJSONArray.Create;
  for I := 0 to Doc.Count - 1 do
  begin
    Tar := Doc[I];
    T := TJSONObject.Create;
    T.Add('task_id', Tar.Id);
    T.Add('nome', Tar.Nome);
    T.Add('aplicativo', PL_APLICATIVO_CODIGO[Tar.Aplicativo]);
    T.Add('duracao_min', Tar.Duracao.Minutes);
    T.Add('duracao_unidade', AIDurationUnitName(Tar.Duracao.DisplayUnit));
    T.Add('duracao_corrida', Tar.Duracao.Elapsed);
    T.Add('marco', Tar.Marco);
    T.Add('situacao', PL_SITUACAO_CODIGO[Tar.Situacao]);
    T.Add('progresso', Tar.Progresso);
    T.Add('responsavel', Tar.Responsavel);
    T.Add('executor_id',Tar.ExecutorID); T.Add('executor_nome',Tar.ExecutorNome);
    if Tar.InicioSolicitado>0 then T.Add('inicio_solicitado',DataISO(Tar.InicioSolicitado));
    T.Add('notas', Tar.Notas);
    AllocationsJSON:=TJSONArray.Create;
    for J:=0 to High(Tar.Alocacoes) do begin
      L:=TJSONObject.Create; L.Add('resource_id',Tar.Alocacoes[J].RecursoID); L.Add('units',Tar.Alocacoes[J].Unidades);
      L.Add('unit_cost_cents',Tar.Alocacoes[J].CustoUnitarioCentavos); L.Add('accounted',Tar.Alocacoes[J].Contabilizado);
      L.Add('direction',PL_DIRECAO_CODIGOS[Tar.Alocacoes[J].Direcao]); AllocationsJSON.Add(L);
    end;
    T.Add('alocacoes',AllocationsJSON);
    CostsJSON:=TJSONArray.Create;
    for J:=0 to High(Tar.Custos) do begin
      L:=TJSONObject.Create; L.Add('name',Tar.Custos[J].Nome); L.Add('quantity',Tar.Custos[J].Quantidade);
      L.Add('unit_cost_cents',Tar.Custos[J].ValorUnitarioCentavos); L.Add('accounted',Tar.Custos[J].Contabilizado); CostsJSON.Add(L);
    end;
    T.Add('custos',CostsJSON); T.Add('custo_saida_centavos',Doc.CustoTarefa(Tar));
    Deps := TJSONArray.Create;
    for J := 0 to High(Tar.Predecessoras) do
    begin
      L := TJSONObject.Create;
      L.Add('task_id', Tar.Predecessoras[J].Id);
      L.Add('tipo', AILinkTypeCode(Tar.Predecessoras[J].LinkType));
      L.Add('latencia', AIFormatLag(Tar.Predecessoras[J].Lag, PL_MINUTOS_POR_DIA,
        PL_MINUTOS_POR_SEMANA));
      Deps.Add(L);
    end;
    T.Add('depende_de', Deps);
    Arr.Add(T);
  end;
  Result.Add('tarefas', Arr); Result.Add('custo_saida_centavos',Doc.CustoProjeto);
end;

procedure PLProjetoDeJSON(Doc: TPLProjeto; O: TJSONObject);
var
  P, T, L: TJSONObject;
  Arr, Deps, ResourcesJSON,AllocationsJSON,CostsJSON,SprintsJSON,HistoryJSON,LogsJSON: TJSONArray;
  I, J: Integer;
  Tar: TPLTarefa;
  U: TAIDurationUnit;
  Item: TAIPredecessorItem;
  Err, Versao: string;
  Graph: TAITaskGraph;
  Sprint: TPLSprint;
  Resource: TPLRecurso; Direction: TPLDirecao; FoundDirection: Boolean;
begin
  Versao := O.Get('schema_version', '');
  if Versao = '' then
    raise Exception.Create('arquivo sem schema_version: não é um projeto do Planejador');
  if Copy(Versao, 1, 2) <> '1.' then
    raise Exception.CreateFmt('versão de esquema não suportada: %s', [Versao]);
  if O.Get('package_type', '') <> PL_PACKAGE_TYPE then
    raise Exception.Create('o arquivo não é um projeto do Planejador');

  P := O.Objects['projeto'];
  Doc.Novo(P.Get('nome', 'Projeto'), DataDeISO(P.Get('inicio', ''), Date));
  Doc.Objetivo := P.Get('objetivo', '');
  Doc.OrcamentoFixado:=P.Get('orcamento_fixado',False); Doc.OrcamentoCentavos:=P.Get('orcamento_centavos',Int64(0));
  if (P.Find('calendario') <> nil) and (P.Find('calendario') is TJSONObject) then
    Doc.Calendario.FromJSON(P.Objects['calendario']);

  ResourcesJSON:=O.Get('recursos',TJSONArray(nil));
  if ResourcesJSON<>nil then begin
    if ResourcesJSON.Count>10000 then raise Exception.Create('Muitos recursos');
    for I:=0 to ResourcesJSON.Count-1 do begin
      Resource:=TPLRecurso.Create;
      try Resource.DeJSON(ResourcesJSON.Objects[I]); Doc.AdicionarRecurso(Resource); except Resource.Free; raise; end;
    end;
  end;
  Arr := O.Arrays['tarefas'];
  { primeiro todas as tarefas, depois os vinculos (as predecessoras podem vir depois) }
  for I := 0 to Arr.Count - 1 do
  begin
    T := Arr.Objects[I];
    Tar := TPLTarefa.Create(T.Get('task_id', ''), T.Get('nome', ''));
    if Tar.Id = '' then
    begin
      Tar.Free;
      raise Exception.CreateFmt('tarefa %d sem task_id', [I + 1]);
    end;
    if not AITryDurationUnitFromName(T.Get('duracao_unidade', 'd'), U) then U := aduDay;
    Tar.Duracao := AIMakeDuration(T.Get('duracao_min', Int64(PL_MINUTOS_POR_DIA)), U,
      T.Get('duracao_corrida', False));
    Tar.Marco := T.Get('marco', False);
    Tar.Aplicativo := PLAplicativoDeCodigo(T.Get('aplicativo', ''));
    Tar.Situacao := PLSituacaoDeCodigo(T.Get('situacao', ''));
    Tar.Progresso := T.Get('progresso', 0);
    Tar.Responsavel := T.Get('responsavel', '');
    Tar.ExecutorID:=T.Get('executor_id',''); Tar.ExecutorNome:=T.Get('executor_nome','');
    Tar.InicioSolicitado:=DataDeISO(T.Get('inicio_solicitado',''),0);
    if (T.Get('inicio_solicitado','')<>'') and
       ((Tar.InicioSolicitado<=0) or (DataISO(Tar.InicioSolicitado)<>T.Get('inicio_solicitado',''))) then begin
      Tar.Free; raise Exception.Create('Data de início da tarefa inválida');
    end;
    Tar.Notas := T.Get('notas', '');
    try
      Doc.AdicionarTarefa(Tar);
    except
      Tar.Free;
      raise;
    end;
    AllocationsJSON:=T.Get('alocacoes',TJSONArray(nil));
    if AllocationsJSON<>nil then begin
      if AllocationsJSON.Count>5000 then raise Exception.Create('Muitas alocações');
      SetLength(Tar.Alocacoes,AllocationsJSON.Count);
      for J:=0 to AllocationsJSON.Count-1 do begin
        L:=AllocationsJSON.Objects[J]; Tar.Alocacoes[J].RecursoID:=L.Get('resource_id','');
        Tar.Alocacoes[J].CustoUnitarioCentavos:=L.Get('unit_cost_cents',Int64(0));
        Tar.Alocacoes[J].Contabilizado:=L.Get('accounted',False);
        Tar.Alocacoes[J].Unidades:=L.Get('units',1.0); FoundDirection:=False;
        for Direction:=Low(Direction) to High(Direction) do if L.Get('direction','use')=PL_DIRECAO_CODIGOS[Direction] then begin Tar.Alocacoes[J].Direcao:=Direction; FoundDirection:=True; end;
        if not FoundDirection then raise Exception.Create('Direção de recurso inválida');
      end;
    end;
    CostsJSON:=T.Get('custos',TJSONArray(nil));
    if CostsJSON<>nil then begin
      if CostsJSON.Count>5000 then raise Exception.Create('Muitos itens de custo');
      SetLength(Tar.Custos,CostsJSON.Count);
      for J:=0 to CostsJSON.Count-1 do begin L:=CostsJSON.Objects[J];
        Tar.Custos[J].Nome:=L.Get('name',''); Tar.Custos[J].Quantidade:=L.Get('quantity',1.0);
        Tar.Custos[J].ValorUnitarioCentavos:=L.Get('unit_cost_cents',Int64(0)); Tar.Custos[J].Contabilizado:=L.Get('accounted',False);
      end;
    end;
    if Tar.Duracao.Minutes < 0 then raise Exception.Create('Duração negativa no arquivo');
    if (Tar.Progresso < 0) or (Tar.Progresso > 100) then raise Exception.Create('Progresso fora de 0 a 100 no arquivo');
    if not SameText(T.Get('situacao',PL_SITUACAO_CODIGO[Tar.Situacao]),PL_SITUACAO_CODIGO[Tar.Situacao]) then
      raise Exception.Create('Situação desconhecida no arquivo');
    if (Tar.Situacao = plsConcluida) and (Tar.Progresso <> 100) then raise Exception.Create('Tarefa concluída deve ter progresso de 100%');
  end;
  for I := 0 to Arr.Count - 1 do
  begin
    T := Arr.Objects[I];
    Tar := Doc[I];
    Deps := T.Get('depende_de', TJSONArray(nil));
    if Deps = nil then Continue;
    for J := 0 to Deps.Count - 1 do
    begin
      if Deps.Types[J] = jtString then
      begin
        { forma simplificada do contrato: lista de IDs }
        Item.Id := Deps.Strings[J];
        Item.LinkType := atlFS;
        Item.Lag := AINoLag;
      end
      else
      begin
        L := Deps.Objects[J];
        Item.Id := L.Get('task_id', '');
        if not AITryLinkTypeFromCode(L.Get('tipo', 'TI'), Item.LinkType) then
          Item.LinkType := atlFS;
        Item.Lag := AINoLag;
        if L.Get('latencia', '') <> '' then
          if not AITryParseLag(L.Get('latencia', ''), PL_MINUTOS_POR_DIA,
            PL_MINUTOS_POR_SEMANA, Item.Lag, Err) then
            raise Exception.CreateFmt('%s: latência inválida (%s)', [Tar.Id, Err]);
      end;
      if not Doc.IdExiste(Item.Id) then
        raise Exception.CreateFmt('%s depende de tarefa inexistente: %s', [Tar.Id, Item.Id]);
      SetLength(Tar.Predecessoras, Length(Tar.Predecessoras) + 1);
      Tar.Predecessoras[High(Tar.Predecessoras)] := Item;
    end;
  end;
  Graph := TAITaskGraph.Create;
  try
    Doc.MontarGrafo(Graph,Err);
    if Err <> '' then raise Exception.Create('Dependências inválidas no arquivo: '+Err);
  finally Graph.Free; end;
  SprintsJSON:=O.Get('sprints',TJSONArray(nil));
  if SprintsJSON<>nil then begin
    if SprintsJSON.Count>5000 then raise Exception.Create('Muitas sprints');
    for I:=0 to SprintsJSON.Count-1 do begin Sprint:=TPLSprint.Create; try Sprint.DeJSON(SprintsJSON.Objects[I]); Doc.AdicionarSprint(Sprint); except Sprint.Free; raise; end; end;
  end;
  HistoryJSON:=O.Get('historico_custos',TJSONArray(nil));
  if HistoryJSON<>nil then begin
    if HistoryJSON.Count>50000 then raise Exception.Create('Muitas apurações'); SetLength(Doc.HistoricoCustos,HistoryJSON.Count);
    for I:=0 to HistoryJSON.Count-1 do begin Doc.HistoricoCustos[I].Data:=PLDataLer(HistoryJSON.Objects[I].Get('date',''));
      Doc.HistoricoCustos[I].Previsto:=HistoryJSON.Objects[I].Get('planned_cents',Int64(0)); Doc.HistoricoCustos[I].Computado:=HistoryJSON.Objects[I].Get('computed_cents',Int64(0)); end;
  end;
  LogsJSON:=O.Get('apontamentos',TJSONArray(nil));
  if LogsJSON<>nil then begin if LogsJSON.Count>100000 then raise Exception.Create('Muitos apontamentos'); SetLength(Doc.Apontamentos,LogsJSON.Count); for I:=0 to LogsJSON.Count-1 do Doc.Apontamentos[I]:=PLApontamentoLer(LogsJSON.Objects[I]); end;
  Doc.ValidarRecursos; Doc.ValidarAcompanhamento;
  Doc.Modificado := False;
end;

procedure PLSalvarProjeto(Doc: TPLProjeto; const AArquivo: string);
var
  O: TJSONObject;
  S: TStringList;
begin
  O := PLProjetoParaJSON(Doc);
  S := TStringList.Create;
  try
    S.Text := O.FormatJSON;
    EAAtomicWriteText(AArquivo,S.Text);
    Doc.Modificado := False;
  finally
    S.Free;
    O.Free;
  end;
end;

procedure PLCarregarProjeto(Doc: TPLProjeto; const AArquivo: string);
var
  S: TStringList;
  D: TJSONData;
  Temp: TPLProjeto;
begin
  S := TStringList.Create;
  try
    S.LoadFromFile(AArquivo);
    D := GetJSON(S.Text);
  finally
    S.Free;
  end;
  try
    if not (D is TJSONObject) then
      raise Exception.Create('arquivo JSON inválido');
    { A leitura nunca modifica o documento ativo antes da validacao integral. }
    Temp := TPLProjeto.Create;
    try
      PLProjetoDeJSON(Temp, TJSONObject(D));
      Doc.TrocarCom(Temp);
      Doc.Modificado := False;
    finally
      Temp.Free;
    end;
  finally
    D.Free;
  end;
end;

end.
