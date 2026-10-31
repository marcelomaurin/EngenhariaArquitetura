unit plan_exemplos;

{ Planejador - projeto de exemplo: residencia de dois pavimentos,
  com tarefas executadas pelos aplicativos da plataforma. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, plan_tipos, plan_documento;

procedure PLCarregarExemploResidencia(Doc: TPLProjeto; AInicio: TDateTime);

procedure PLCarregarExemploSaude(Doc: TPLProjeto; AInicio: TDateTime; Hospital: Boolean);

implementation

procedure PLCarregarExemploResidencia(Doc: TPLProjeto; AInicio: TDateTime);

  procedure T(const ANome, ADuracao, APred: string; AApp: TPLAplicativo; AMarco: Boolean = False);
  var Tar: TPLTarefa; Err: string;
  begin
    Tar := Doc.NovaTarefa(ANome, AMarco);
    if not AMarco then Doc.DefinirDuracao(Tar, ADuracao, Err);
    Tar.Aplicativo := AApp;
    if APred <> '' then
      if not Doc.DefinirPredecessoras(Tar, APred, Err) then
        raise Exception.CreateFmt('exemplo inválido em %s: %s', [Tar.Id, Err]);
  end;

begin
  Doc.Novo('Residência unifamiliar — exemplo', AInicio);
  Doc.Objetivo := 'Projeto completo de uma residência de dois pavimentos: plantas, ' +
    'maquete, instalações elétricas e hidrossanitárias e imagens para o cliente.';
  T('Levantamento e programa de necessidades', '5d', '', plaNenhum);           // T-0001
  T('Estudo preliminar', '5d', 'T-0001', plaCAD2D);                           // T-0002
  T('Planta do térreo', '5d', 'T-0002', plaCAD2D);                            // T-0003
  T('Planta do pavimento superior', '4d', 'T-0002', plaCAD2D);                // T-0004
  T('Aprovação do estudo pelo cliente', '', 'T-0003; T-0004', plaNenhum, True); // T-0005
  T('Maquete da edificação', '4d', 'T-0005', plaMaquete3D);                   // T-0006
  T('Projeto elétrico', '6d', 'T-0006', plaEletrica3D);                       // T-0007
  T('Projeto hidrossanitário', '6d', 'T-0006', plaSimuTubulacoes);            // T-0008
  T('Simulação elétrica e proteções', '2d', 'T-0007', plaSimuEletrica);       // T-0009
  T('Imagens realistas para o cliente', '3d', 'T-0006', plaCriadorCenas);     // T-0010
  T('Entrega do projeto', '', 'T-0008; T-0009; T-0010', plaNenhum, True);     // T-0011
  Doc.Modificado := False;
end;


procedure PLCarregarExemploSaude(Doc: TPLProjeto; AInicio: TDateTime; Hospital: Boolean);
  procedure Task(const Name,Duration,Pred,Notes: string; App: TPLAplicativo; Milestone: Boolean=False);
  var T: TPLTarefa; Err: string;
  begin
    T:=Doc.NovaTarefa(Name,Milestone); T.Notas:=Notes; T.Aplicativo:=App;
    if not Milestone then if not Doc.DefinirDuracao(T,Duration,Err) then raise Exception.Create(Err);
    if Pred<>'' then if not Doc.DefinirPredecessoras(T,Pred,Err) then raise Exception.Create(Err);
  end;
begin
  if Hospital then Doc.Novo('Ala assistencial hospitalar — exemplo de planejamento',AInicio)
  else Doc.Novo('UBS — exemplo de planejamento',AInicio);
  Doc.Objetivo:='Estudo de projeto para estabelecimento de saúde. Confirmar programa assistencial, equipamentos, fluxos, acessibilidade e requisitos técnicos com a equipe responsável. Cronograma ilustrativo; não é projeto referencial oficial.';
  Task('Levantamento do terreno e da edificação','3d','','Registrar implantação, restrições locais e condições existentes.',plaNenhum);
  Task('Programa assistencial e de necessidades','4d','T-0001','Definir atividades, público atendido, ambientes e capacidade com a gestão de saúde.',plaNenhum);
  Task('Inventário de mobiliário e equipamentos','3d','T-0002','Consultar SOMASUS, equipamentos efetivos e fichas dos fabricantes; confirmar dimensões e infraestrutura.',plaNenhum);
  Task('Estudo de zoneamento e fluxos','4d','T-0002','Representar fluxos assistenciais e de apoio para revisão da equipe técnica.',plaCAD2D);
  Task('Planta 2D de ambientes e circulações','5d','T-0004','Desenvolver o desenho em milímetros; identificar ambientes e acessos.',plaCAD2D);
  Task('Layout 2D de mobiliário e equipamentos','4d','T-0003; T-0005','Usar a biblioteca de saúde como base editável; ajustar envelopes e áreas operacionais ao projeto.',plaCAD2D);
  Task('Revisão de acessibilidade e uso dos ambientes','3d','T-0006','Análise técnica das rotas, sanitários, atendimento e circulação; não é verificação automática do software.',plaCAD2D);
  Task('Planejamento das instalações e infraestrutura','4d','T-0006','Levantar necessidades de elétrica, hidráulica, climatização e outros sistemas compatíveis com o programa assistencial.',plaNenhum);
  Task('Compatibilização de arquitetura e disciplinas','3d','T-0007; T-0008','Registrar interferências e pendências para a equipe de projeto.',plaCAD2D);
  Task('Quantitativos e estimativa de custos','3d','T-0009','Consolidar levantamento e bases orçamentárias aplicáveis ao empreendimento; conferência profissional.',plaNenhum);
  Task('Revisão técnica e exigências locais','3d','T-0009','Conferir referências sanitárias, acessibilidade e exigências pertinentes ao serviço, local e data.',plaNenhum);
  Task('Consolidação do projeto e documentação','3d','T-0010; T-0011','Consolidar desenhos, memoriais, inventário de equipamentos, respostas e pendências.',plaCAD2D);
  Task('Revisão com a gestão e equipe assistencial','2d','T-0012','Validar requisitos do empreendimento e registrar decisões do contratante.',plaNenhum);
  Task('Entrega e registro de pendências','','T-0013','Registrar arquivos entregues e pendências que impedem a próxima etapa.',plaNenhum,True);
  Doc.Modificado:=False;
end;
end.
