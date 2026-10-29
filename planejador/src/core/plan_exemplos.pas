unit plan_exemplos;

{ Planejador - projeto de exemplo: residencia de dois pavimentos,
  com tarefas executadas pelos aplicativos da plataforma. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, plan_tipos, plan_documento;

procedure PLCarregarExemploResidencia(Doc: TPLProjeto; AInicio: TDateTime);

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

end.
