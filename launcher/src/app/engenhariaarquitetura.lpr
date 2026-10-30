program engenhariaarquitetura;
{$mode objfpc}{$H+}
{$codepage utf8}
uses Interfaces, Forms, ea_launcher_main;
begin
  Application.Initialize;
  Application.Title := 'EngenhariaArquitetura';
  Application.CreateForm(TEALauncherForm, EALauncherForm);
  Application.Run;
end.
