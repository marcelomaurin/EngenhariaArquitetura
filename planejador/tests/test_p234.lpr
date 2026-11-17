program test_p234;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  Classes, SysUtils, DateUtils, fpjson,
  ea_pacote, ea_fileio,
  plan_tipos, plan_documento, plan_cronograma, plan_json, plan_p234;

var
  Doc, Doc2: TPLProjeto;
  Crono: TPLCronograma;
  T1, T2, T3: TPLTarefa;
  Err, TmpTask, TmpRet, TmpOut, TmpPlan, TmpTex: string;
  G: TGUID;
  Pkg: TEAPackageManifest;
  RetObj, SObj: TJSONObject;
  Arr: TJSONArray;
  Blocked: Boolean;
  Curva: TPLCurvaSPontos;
  BItem: TPLBaselineItem;
  Checks: Integer = 0;

procedure Check(OK: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not OK then raise Exception.Create('FALHA: ' + Msg);
end;

begin
  CreateGUID(G);
  TmpTask := GetTempDir(False) + 'ea-p2-' + GUIDToString(G) + '.task.json';
  TmpRet := GetTempDir(False) + 'ea-p2-' + GUIDToString(G) + '.return.json';
  TmpOut := GetTempDir(False) + 'ea-p2-' + GUIDToString(G) + '.ea2d.json';
  TmpPlan := GetTempDir(False) + 'ea-p2-' + GUIDToString(G) + '.plan.json';
  TmpTex := GetTempDir(False) + 'ea-p4-' + GUIDToString(G) + '.tex.json';

  Doc := TPLProjeto.Create;
  Doc2 := TPLProjeto.Create;
  Crono := TPLCronograma.Create;
  try
    Doc.Novo('Obra Teste P234', EncodeDate(2026, 11, 2));
    T1 := Doc.NovaTarefa('Planta do Térreo'); T1.Aplicativo := plaCAD2D;
    T2 := Doc.NovaTarefa('Maquete 3D'); T2.Aplicativo := plaMaquete3D;
    T3 := Doc.NovaTarefa('Acabamento Bancada'); T3.Aplicativo := plaMaquete3D;
    Check(Doc.DefinirPredecessoras(T2, T1.Id, Err), 'vinculo T1->T2');
    Crono.Calcular(Doc);
    Check(Crono.Valido, 'cronograma valido');

    { P2: T2 bloqueada enquanto T1 nao concluiu }
    Check(PLCalcularStatusExecucao(Doc, T1) = 'pronta', 'T1 pronta');
    Check(PLCalcularStatusExecucao(Doc, T2) = 'bloqueada', 'T2 bloqueada por T1');
    Blocked := False;
    try
      PLGerarPacoteTarefa(Doc, Crono, T2, '', TmpTask);
    except
      on E: Exception do Blocked := True;
    end;
    Check(Blocked, 'recusa despacho de tarefa bloqueada');

    { Despachar T1 e processar retorno valido com SHA-256 }
    PLGerarPacoteTarefa(Doc, Crono, T1, '', TmpTask);
    Check(FileExists(TmpTask), 'pacote .task.json gerado');
    Check(T1.ExecStatus = 'em_execucao', 'T1 em execucao');

    EAAtomicWriteText(TmpOut, '{"modelo":"ok"}');
    Pkg := TEAPackageManifest.Create;
    RetObj := TJSONObject.Create;
    try
      Pkg.PackageType := EA_PKG_RETORNO_TAREFA;
      Pkg.PackageId := 'ret-' + T1.Id;
      Pkg.CreatedByApp := 'CAD2D';
      RetObj.Add('task_id', T1.Id);
      RetObj.Add('situacao', 'concluida');
      RetObj.Add('mensagem', 'Planta finalizada');
      Arr := TJSONArray.Create;
      SObj := TJSONObject.Create;
      SObj.Add('arquivo', TmpOut);
      SObj.Add('hash', EASHA256File(TmpOut));
      Arr.Add(SObj);
      RetObj.Add('saidas', Arr);
      Pkg.Payload := RetObj;
      RetObj := nil;
      Pkg.SaveToFile(TmpRet);
    finally
      RetObj.Free;
      Pkg.Free;
    end;

    PLProcessarRetornoTarefa(Doc, T1, TmpRet);
    Check(T1.Situacao = plsConcluida, 'T1 concluida apos retorno valido');
    Check(PLCalcularStatusExecucao(Doc, T2) = 'pronta', 'T2 liberada apos conclusao de T1');

    { Rejeita retorno com hash corrompido }
    EAAtomicWriteText(TmpOut, '{"modelo":"adulterado"}');
    Blocked := False;
    try
      PLProcessarRetornoTarefa(Doc, T1, TmpRet);
    except
      on E: Exception do Blocked := True;
    end;
    Check(Blocked, 'rejeita retorno com SHA-256 divergente');

    { P3: Linha de Base e Curva S }
    PLCongelarBaseline(Doc, Crono);
    Check(PLBuscarBaseline(Doc, T1.Id, BItem), 'baseline gravada para T1');
    Curva := PLCalcularCurvaS(Doc, Crono);
    Check(Length(Curva) >= 2, 'Curva S calculada');
    Check(Curva[High(Curva)].PlanejadoPct >= 99.9, 'Curva S planejada chega a 100%');

    { P4: Vinculo de objeto e textura por objeto e face }
    PLVincularObjetoTextura(Doc, T3, 'bancada_01', 'granito_cinza', 'face', 'tampo', '1.0');
    PLVincularObjetoTextura(Doc, T3, 'bancada_01', 'mdf_branco', 'objeto', '', '1.0');
    Check(Length(T3.Texturas) = 2, 'duas texturas vinculadas a T3');
    PLExportarPacoteObjetoTextura(T3, TmpTex);
    Check(FileExists(TmpTex), 'pacote objeto-textura I-03 exportado');

    { Roundtrip JSON schema 1.4 }
    PLSalvarProjeto(Doc, TmpPlan);
    PLCarregarProjeto(Doc2, TmpPlan);
    Check(Length(Doc2.Baseline) = 3, 'baseline preservada no roundtrip JSON');
    Check(Doc2[2].ObjetoId = 'bancada_01', 'objeto_id preservado no roundtrip JSON');
    Check(Length(Doc2[2].Texturas) = 2, 'texturas P4 preservadas no roundtrip JSON');

    WriteLn(Checks, ' verificacoes P2/P3/P4 do Planejador, 0 falhas');
  finally
    Crono.Free;
    Doc2.Free;
    Doc.Free;
    if FileExists(TmpTask) then DeleteFile(TmpTask);
    if FileExists(TmpRet) then DeleteFile(TmpRet);
    if FileExists(TmpOut) then DeleteFile(TmpOut);
    if FileExists(TmpPlan) then DeleteFile(TmpPlan);
    if FileExists(TmpTex) then DeleteFile(TmpTex);
  end;
end.
