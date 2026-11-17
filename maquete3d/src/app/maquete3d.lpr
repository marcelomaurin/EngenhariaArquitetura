program maquete3d;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, maquete3d_main;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMaqMainForm, MaqMainForm);
  Application.Run;
end.
