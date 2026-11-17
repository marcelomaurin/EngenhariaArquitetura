program eletrica3d;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, eletrica3d_main;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TELEMainForm, EleMainForm);
  Application.Run;
end.
