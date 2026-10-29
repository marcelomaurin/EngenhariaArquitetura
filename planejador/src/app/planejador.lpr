program planejador;

{ Planejador - primeira etapa da linha de producao da plataforma
  EngenhariaArquitetura. Uso: planejador [arquivo.plan.json] }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, Forms, plan_principal;

{$R *.res}

begin
  RequireDerivedFormResource := False;
  Application.Title := 'Planejador';
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TPLJanelaPrincipal, JanelaPrincipal);
  Application.Run;
end.
