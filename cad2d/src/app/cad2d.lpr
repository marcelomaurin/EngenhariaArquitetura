program cad2d;
{$mode objfpc}{$H+}
uses Interfaces, Forms, cad2d_main
  {$IFDEF WINDOWS}, Windows{$ENDIF};
{$R *.res}
begin
 Application.Initialize;
 Application.Title := 'CAD Arquitetônico 2D';
 Application.CreateForm(TCADMainForm, CADMainForm);
 CADMainForm.Show;
 {$IFDEF WINDOWS}Windows.ShowWindow(CADMainForm.Handle, SW_SHOWNORMAL);{$ENDIF}
 Application.Run;
end.
