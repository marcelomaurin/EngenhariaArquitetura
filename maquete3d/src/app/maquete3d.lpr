program maquete3d;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, maquete3d_main;

{$R *.res}

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.Title := 'Maquete 3D';
  Application.CreateForm(TMaqMainForm, MaqMainForm);
  Application.Run;
end.
