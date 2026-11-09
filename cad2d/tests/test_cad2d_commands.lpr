program test_cad2d_commands;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Graphics,
  Types, ComCtrls, ValEdit, cad2d_main, cad2d_controls;
var F:TCADMainForm; PB:TPaintBox; Tool:TComboBox; Grid:TValueListEditor;
  L:TStringList; Base,FileName:string; I,Checks:Integer; Failed:Boolean; Preview:TPortableNetworkGraphic; Bitmap:TBitmap;
procedure Check(V:Boolean; const Msg:string);
begin if not V then raise Exception.Create(Msg); Inc(Checks); WriteLn('PASS: ',Msg); end;
procedure Save;
begin F.SaveProject(FileName); L.LoadFromFile(FileName); end;
procedure Click(X,Y:Integer; Add:Boolean=False);
begin if Add then PB.OnMouseDown(PB,mbLeft,[ssCtrl],X,Y) else PB.OnMouseDown(PB,mbLeft,[],X,Y); end;
procedure Choose(N:Integer);
begin Tool.ItemIndex:=N; Tool.OnChange(Tool); end;
procedure Button(const Caption:string);
var J:Integer;
begin for J:=0 to F.ComponentCount-1 do if (F.Components[J] is TCADCommandButton) and
  (TCADCommandButton(F.Components[J]).Caption=Caption) then begin TCADCommandButton(F.Components[J]).Click; Exit; end;
  raise Exception.Create('Missing button '+Caption);
end;
function GroupAt(Row:Integer):Integer;
var Fields:TStringList;
begin Fields:=TStringList.Create; try Fields.Delimiter:=';'; Fields.StrictDelimiter:=True; Fields.DelimitedText:=L[Row]; Result:=StrToInt(Fields[7]); finally Fields.Free; end; end;
procedure Fixture;
begin
  L.Clear; L.Add('EACAD4'); L.Add('50');
  L.Add('100;100;180;100;0;0;0;1;0;0;');
  L.Add('180;100;180;160;0;0;0;1;0;0;');
  L.SaveToFile(FileName); F.LoadProject(FileName); Choose(5); Click(140,100);
end;
begin
  Checks:=0; Application.Initialize;
  Base:=GetTempDir(False)+'cad2d-command-test-'+IntToStr(GetProcessID)+PathDelim;
  ForceDirectories(Base); FileName:=Base+'drawing.eacad'; L:=TStringList.Create;
  try
    F:=TCADMainForm.Create(nil);
    try
      F.Show; Application.ProcessMessages;
      PB:=TPaintBox(F.FindComponent('DrawingCanvas')); Tool:=TComboBox(F.FindComponent('ActiveTool'));
      Grid:=TValueListEditor(F.FindComponent('PropertyEditor'));
      Fixture; F.EditSelection(0,1000,0); Save;
      Check(Pos('120;100;200;100',L[2])=1,'move transforms first member');
      Check(Pos('200;100;200;160',L[3])=1,'move transforms entire group');
      Button('Desfazer'); Save; Check(Pos('100;100;180;100',L[2])=1,'undo grouped move');
      Button('Refazer'); Save; Check(Pos('120;100;200;100',L[2])=1,'redo grouped move');
      Fixture; F.EditSelection(2,90,0); Save; Check(Pos('100;100;100;180',L[2])=1,'rotate around base point');
      Fixture; F.EditSelection(3,2,0); Save; Check(Pos('100;100;260;100',L[2])=1,'scale retains proportions');
      Fixture; F.EditSelection(5,0,0); Save; Check(Pos('180;100;180;40',L[3])=1,'mirror group across base axis');
      Fixture; F.EditSelection(1,1000,0); Save; Check(L.Count=6,'copy preserves original and duplicates group');
      Fixture; F.EditSelection(9,1000,2000,2,3); Save; Check(L.Count=14,'rectangular array creates six group instances');
      Fixture; F.EditSelection(8,0,0); Save; Check(GroupAt(2)<>GroupAt(3),'ungroup assigns distinct groups');
      Click(140,100); Click(180,140,True); F.EditSelection(7,0,0); Save;
      F.EditSelection(0,1000,0); Save; Check(Pos('200;100;200;160',L[3])=1,'Ctrl selection and regroup move both objects');
      Fixture; F.StretchWindow(Rect(170,90,190,170),1000,0); Save;
      Check(Pos('100;100;200;100',L[2])=1,'stretch keeps outside endpoint fixed');
      Check(Pos('200;100;200;160',L[3])=1,'stretch moves enclosed endpoints');
      Fixture; Choose(7); Click(200,200); Click(300,200); Click(300,300);
      PB.OnMouseDown(PB,mbRight,[],300,300); Save; Check(L.Count=6,'polyline creates connected segments');
      Choose(8); Click(400,300); Click(460,300); Click(400,360); Save; Check(L.Count>20,'center start end arc produces geometry');
      Choose(6); Click(500,200); Click(540,200); Save; Check(L.Count>60,'circle produces grouped geometry');
      Choose(10); Click(100,300); Click(180,300); Save;
      Check(Pos(';6;500;',L[L.Count-1])>0,'persistent aligned dimension created');
      F.LoadProject(FileName); Save; Check(Pos(';6;500;',L[L.Count-1])>0,'dimension survives reload');
      Fixture;
      Grid.Values['X final mm']:='10000'; Grid.Values['Cor RGB hex']:='FF0000'; Grid.Values['Traço mm (0 auto)']:='25';
      TButton(F.FindComponent('ApplyProperties')).Click; Save;
      Check(Pos('100;100;200;100',L[2])=1,'properties edit geometry');
      Check(Pos(';16711680;25;',L[2])>0,'color and stroke persisted');
      Button('Desfazer'); Save; Check(Pos(';0;0;',L[2])>0,'property edit undo');
      L.Clear; L.Add('EACAD4'); L.Add('50');
      L.Add('100;100;180;100;0;5;250;1;0;0;436F7A696E6861');
      L.Add('100;200;180;200;0;6;500;2;0;0;'); L.SaveToFile(FileName); F.LoadProject(FileName);
      Choose(5); Click(140,100); Grid.Values['Texto']:='Cozinha <A> & B';
      TButton(F.FindComponent('ApplyProperties')).Click;
      F.ExportProject(Base+'drawing.svg',True); L.LoadFromFile(Base+'drawing.svg');
      Check(Pos('Cozinha &lt;A&gt; &amp; B',L.Text)>0,'SVG escapes editable text');
      Check(Pos('4,00 m',L.Text)+Pos('4.00 m',L.Text)>0,'SVG includes measured dimension');
      F.ExportProject(Base+'drawing.dxf',False); L.LoadFromFile(Base+'drawing.dxf');
      Check(Pos('TEXT',L.Text)>0,'DXF exports text entities');
      Check(Pos('Cozinha <A> & B',L.Text)>0,'DXF preserves annotation');
      Save; F.LoadProject(FileName); Save; Check(Pos('436F7A696E6861',L[2])>0,'text roundtrip');
      for I:=1 to 3 do begin
        L.Clear; L.Add('EACAD'+IntToStr(I)); L.Add('50');
        case I of 1:L.Add('0;0;80;0;0;0'); 2:L.Add('0;0;80;0;0;0;0'); 3:L.Add('0;0;80;0;0;0;0;1'); end;
        L.SaveToFile(FileName); F.LoadProject(FileName); Save; Check(L[0]='EACAD4','legacy EACAD'+IntToStr(I)+' loads');
      end;
      L.Clear; L.Add('EACAD4'); L.Add('50'); L.Add('invalid'); L.SaveToFile(FileName); Failed:=False;
      try F.LoadProject(FileName); except Failed:=True; end;
      Check(Failed,'malformed project rejected'); Save; Check(L.Count=3,'failed load preserves previous geometry');
      Fixture;
      for I:=12 to 16 do begin Choose(I); Click(200,200); Click(300,300); end;
      Save; Check(L.Count>30,'stairs pillar bed sofa table create editable geometry');
      Fixture; for I:=18 to 23 do begin Choose(I); Click(200,200); Click(300,300); end; Save;
      Check(L.Count>100,'ellipse polygon hatch opening and sanitary symbols create geometry');
      WriteLn('TOTAL: ',Checks,' checks passed');
      if ParamCount=2 then begin
        F.LoadProject(ParamStr(1)); Choose(5); Click(180,280);
        TButton(F.FindComponent('ToggleProperties')).Click;
        TPageControl(F.FindComponent('CommandRibbon')).ActivePageIndex:=3;
        Application.ProcessMessages; Bitmap:=F.GetFormImage; Preview:=TPortableNetworkGraphic.Create;
        try Preview.Assign(Bitmap); Preview.SaveToFile(ParamStr(2)); finally Preview.Free; Bitmap.Free; end;
        F.ExportProject(ChangeFileExt(ParamStr(1),'.svg'),True);
        F.ExportProject(ChangeFileExt(ParamStr(1),'.dxf'),False);
      end;
      Application.Terminate;
    finally F.Free; end;
  except on E:Exception do begin WriteLn('FAIL: ',E.Message); Halt(1); end; end;
  L.Free;
end.
