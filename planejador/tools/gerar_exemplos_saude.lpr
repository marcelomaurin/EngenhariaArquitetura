program gerar_exemplos_saude;
{$mode objfpc}{$H+}{$codepage utf8}
uses SysUtils, DateUtils, cad_catalog, cad_health_examples, cad_document,
  plan_documento, plan_exemplos, plan_json, plan_cronograma, plan_acompanhamento, plan_tipos, plan_recursos, plan_sprints, plan_relatorios_sprint;
var C: TCADCatalog; D: TCADDocument; P: TPLProjeto; Root: string; Schedule: TPLCronograma; Task: TPLTarefa; Weeks: TPLCustosSemanais; Ana,Bruno: TPLRecurso; Sprint: TPLSprint; ReportData: TPLRelatorioSprint; A,B,Done: TPLTarefa;
begin
  DefaultSystemCodePage:=CP_UTF8; SetMultiByteConversionCodePage(CP_UTF8);
  Root:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  C:=TCADCatalog.Create(Root+'libraries/catalogo_2d.json'); P:=TPLProjeto.Create; Schedule:=TPLCronograma.Create;
  try
    ForceDirectories(Root+'cad2d/examples');
    D:=CADHealthcareExample(C,False); try D.Save(Root+'cad2d/examples/ubs_estudo.eacad'); finally D.Free; end;
    D:=CADHealthcareExample(C,True); try D.Save(Root+'cad2d/examples/ala_hospitalar_estudo.eacad'); finally D.Free; end;
    PLCarregarExemploSaude(P,EncodeDate(2026,11,3),False); Schedule.Calcular(P); PLAtualizarSprints(P,Schedule); PLSalvarProjeto(P,Root+'planejador/examples/ubs.plan.json');
    PLCarregarExemploSaude(P,EncodeDate(2026,11,3),True); Schedule.Calcular(P); PLAtualizarSprints(P,Schedule); PLSalvarProjeto(P,Root+'planejador/examples/ala_hospitalar.plan.json');
    P.Novo('Exemplo fictício — evolução semanal de custos (sem dados reais)',EncodeDate(2026,10,5)); Task:=P.NovaTarefa('Composição ilustrativa');
    SetLength(Task.Custos,2); Task.Custos[0].Nome:='Serviço fictício'; Task.Custos[0].Quantidade:=1; Task.Custos[0].ValorUnitarioCentavos:=10000; Task.Custos[0].Contabilizado:=False;
    Task.Custos[1].Nome:='Consumível fictício'; Task.Custos[1].Quantidade:=1; Task.Custos[1].ValorUnitarioCentavos:=2000; Task.Custos[1].Contabilizado:=True;
    P.OrcamentoFixado:=True; P.OrcamentoCentavos:=10000; P.RegistrarCustos(EncodeDate(2026,10,5));
    Task.Custos[0].Contabilizado:=True; P.RegistrarCustos(EncodeDate(2026,10,12));
    Task.Custos[1].Contabilizado:=False; P.OrcamentoCentavos:=15000; P.RegistrarCustos(EncodeDate(2026,10,26));
    Weeks:=PLCustosPorSemana(P,EncodeDate(2026,10,31));
    PLExportarCustosHTML(P,Weeks,Root+'planejador/examples/relatorio_custos_exemplo.html');
    PLExportarCustosCSV(P,Weeks,Root+'planejador/examples/relatorio_custos_exemplo.csv');
    P.Novo('Exemplo fictício — relatório de sprint (sem dados reais)',EncodeDate(2026,9,28)); P.Calendario.Clear; P.Calendario.SetStandard;
    Ana:=P.NovoRecurso; Ana.Nome:='Ana — exemplo fictício'; Ana.UsuarioID:='demo-ana'; Ana.Tipo:=prtPessoa; P.AdicionarRecurso(Ana);
    Bruno:=P.NovoRecurso; Bruno.Nome:='Bruno — exemplo fictício'; Bruno.UsuarioID:='demo-bruno'; Bruno.Tipo:=prtPessoa; P.AdicionarRecurso(Bruno);
    A:=P.NovaTarefa('Levantamento pendente de período anterior'); A.InicioSolicitado:=EncodeDate(2026,9,28); A.ExecutorID:=Ana.UsuarioID; A.ExecutorNome:=Ana.Nome; A.Progresso:=25;
    B:=P.NovaTarefa('Desenho do período'); B.InicioSolicitado:=EncodeDate(2026,10,5); B.ExecutorID:=Bruno.UsuarioID; B.ExecutorNome:=Bruno.Nome; B.Progresso:=50; B.Situacao:=plsEmAndamento;
    Done:=P.NovaTarefa('Revisão concluída'); Done.InicioSolicitado:=EncodeDate(2026,10,6); Done.ExecutorID:=Ana.UsuarioID; Done.ExecutorNome:=Ana.Nome; PLAlterarStatus(P,Done,plsConcluida);
    Schedule.Calcular(P); Sprint:=P.NovaSprint('Sprint demonstrativa — dados fictícios',EncodeDate(2026,10,5),EncodeDate(2026,10,18)); PLAtualizarSprint(P,Schedule,Sprint);
    P.SalvarApontamento('',A.ID,Ana.ID,EncodeDate(2026,10,5),240,'Atividade demonstrativa');
    P.SalvarApontamento('',B.ID,Bruno.ID,EncodeDate(2026,10,6),360,'Desenho demonstrativo');
    P.SalvarApontamento('',Done.ID,Ana.ID,EncodeDate(2026,10,7),480,'Revisão demonstrativa');
    ReportData:=PLGerarRelatorioSprint(P,Schedule,Sprint,'',EncodeDate(2026,10,12));
    try
      PLRelatorioSprintHTML(ReportData,Root+'planejador/examples/relatorio_sprint_exemplo.html');
      PLRelatorioSprintPendenciasCSV(ReportData,Root+'planejador/examples/sprint_pendencias_exemplo.csv');
      PLRelatorioSprintUsuariosCSV(ReportData,Root+'planejador/examples/sprint_usuarios_exemplo.csv');
      PLRelatorioSprintHorasCSV(ReportData,Root+'planejador/examples/sprint_horas_exemplo.csv');
    finally ReportData.Free; end;
    WriteLn('Exemplos de UBS, ala assistencial, sprints, custos e carga de usuários gerados');
  finally Schedule.Free; P.Free; C.Free; end;
end.
