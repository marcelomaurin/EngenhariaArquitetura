program planejador;

{ Planejador - primeira etapa da linha de producao da plataforma
  EngenhariaArquitetura. Uso: planejador [arquivo.plan.json] }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, Forms, SysUtils, Dialogs, plan_principal, plan_pg_bootstrap;

{$R *.res}

var DBStatus: string;
begin
  RequireDerivedFormResource := False;
  Application.Title := 'Planejador';
  Application.Scaled := True;
  Application.Initialize;
  { PostgreSQL e opcional; falhas nao apagam arquivos locais nem o projeto aberto. }
  try
    PLBootstrapPostgres(DBStatus);
  except
    on E: Exception do
      MessageDlg('PostgreSQL - inicializacao',
        E.Message + LineEnding + 'O modo local continua disponivel.',
        mtWarning, [mbOK], 0);
  end;
  Application.CreateForm(TPLJanelaPrincipal, JanelaPrincipal);
  Application.Run;
end.
