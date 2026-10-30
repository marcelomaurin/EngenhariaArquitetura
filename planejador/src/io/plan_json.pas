unit plan_json;

{ Planejador - gravacao e leitura do projeto em JSON versionado.
  Estrutura segue o contrato de tarefa de docs/Planejador.md e o
  manifesto comum de docs/Integracoes.md (schema_version, package_type). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, fpjson, jsonparser, aiprojectduration,
  aitaskgraph, plan_tipos, plan_documento;

const
  PL_SCHEMA_VERSION = '1.0';
  PL_PACKAGE_TYPE = 'projeto_planejador';
  PL_VERSAO_APLICATIVO = '0.2.0';
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
  Arr, Deps: TJSONArray;
  I, J: Integer;
  Tar: TPLTarefa;
begin
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
  P.Add('calendario', Doc.Calendario.ToJSON);
  Result.Add('projeto', P);

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
    T.Add('notas', Tar.Notas);
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
  Result.Add('tarefas', Arr);
end;

procedure PLProjetoDeJSON(Doc: TPLProjeto; O: TJSONObject);
var
  P, T, L: TJSONObject;
  Arr, Deps: TJSONArray;
  I, J: Integer;
  Tar: TPLTarefa;
  U: TAIDurationUnit;
  Item: TAIPredecessorItem;
  Err, Versao: string;
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
  if (P.Find('calendario') <> nil) and (P.Find('calendario') is TJSONObject) then
    Doc.Calendario.FromJSON(P.Objects['calendario']);

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
    Tar.Notas := T.Get('notas', '');
    try
      Doc.AdicionarTarefa(Tar);
    except
      Tar.Free;
      raise;
    end;
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
    S.SaveToFile(AArquivo);
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
