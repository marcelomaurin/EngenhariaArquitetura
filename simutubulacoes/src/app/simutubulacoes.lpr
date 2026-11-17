program simutubulacoes;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, simutubulacoes_main;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TTubMainForm, TubMainForm);
  Application.Run;
end.
