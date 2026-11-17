program simutubulacoes;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, simutubulacoes_main;

{$R *.res}

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.Title := 'SimuTubulações';
  Application.CreateForm(TTubMainForm, TubMainForm);
  Application.Run;
end.
