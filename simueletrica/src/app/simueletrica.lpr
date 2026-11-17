program simueletrica;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, simueletrica_main;

{$R *.res}

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.Title := 'SimuEletrica';
  Application.CreateForm(TSimEleMainForm, SimEleMainForm);
  Application.Run;
end.
