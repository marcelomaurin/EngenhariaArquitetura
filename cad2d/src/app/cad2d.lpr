program cad2d;
{$mode objfpc}{$H+}
uses Interfaces, Forms, cad2d_main;
begin
 Application.Initialize;
 Application.Title := 'CAD Arquitetônico 2D';
 Application.CreateForm(TCADMainForm, CADMainForm);
 Application.Run;
end.
