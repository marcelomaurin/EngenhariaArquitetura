program criadorcenas;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, criadorcenas_main;

{$R *.res}

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.Title := 'Criador de Cenas';
  Application.CreateForm(TCenaMainForm, CenaMainForm);
  Application.Run;
end.
