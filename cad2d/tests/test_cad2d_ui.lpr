program test_cad2d_ui;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, Controls, StdCtrls, ExtCtrls,
  ComCtrls, Graphics, cad2d_main, cad2d_controls;
var F: TCADMainForm; I: Integer; C: TComponent; Canvas: TPaintBox;
  WideCanvas: Integer; Palette: TScrollBox; Panel: TScrollBox; GroupHeader: TButton;
  Ribbon: TPageControl; Tool: TComboBox; Props: TLabel; Preview: TPortableNetworkGraphic; Bitmap: TBitmap;
procedure Check(Value: Boolean; const Msg: string);
begin
  if not Value then raise Exception.Create(Msg);
  WriteLn('PASS: ',Msg);
end;
begin
  try
    Application.Initialize;
    WriteLn('Creating form'); Flush(Output);
    Application.CreateForm(TCADMainForm,F);
    Check(Application.MainForm=F,'application main form registered');
    try
      F.Show; Application.ProcessMessages;
      Ribbon := TPageControl(F.FindComponent('CommandRibbon'));
      Canvas := TPaintBox(F.FindComponent('DrawingCanvas'));
      Tool := TComboBox(F.FindComponent('ActiveTool'));
      Props := TLabel(F.FindComponent('SelectionProperties'));
      Check(Ribbon.PageCount=6,'six command tabs');
      Palette := TScrollBox(F.FindComponent('PartsLibrary'));
      Panel := TScrollBox(F.FindComponent('PropertiesPanel'));
      Check(not Panel.Visible,'properties hidden initially');
      WideCanvas := Canvas.Width;
      TButton(F.FindComponent('ToggleProperties')).Click; Application.ProcessMessages;
      Check(Panel.Visible and (Canvas.Width<WideCanvas),'properties open on demand');
      TButton(F.FindComponent('ToggleProperties')).Click; Application.ProcessMessages;
      Check((not Panel.Visible) and (Canvas.Width=WideCanvas),'closing restores drawing width');
      Check(Palette.Width=132,'compact single column library');
      GroupHeader := TButton(F.FindComponent('LibraryGroup0'));
      GroupHeader.Click;
      Check(GroupHeader.Parent.Height=32,'forms group collapses');
      GroupHeader.Click;
      Check(GroupHeader.Parent.Height>32,'forms group expands');
      GroupHeader := TButton(F.FindComponent('LibraryGroup1'));
      Check(GroupHeader.Parent.Height=32,'parts initially collapsed');
      GroupHeader.Click; Application.ProcessMessages;
      Check((GroupHeader.Parent.Height>32) and
        (Palette.VertScrollBar.Range>Palette.ClientHeight),'expanded groups scroll vertically');
      GroupHeader.Click;
      Check((Canvas.Width>350) and (Canvas.Height>200),'usable drawing canvas');
      Canvas.OnMouseDown(Canvas,mbLeft,[],100,100);
      Canvas.OnMouseDown(Canvas,mbLeft,[],180,100);
      Tool.ItemIndex := 5; Tool.OnChange(Tool);
      Canvas.OnMouseDown(Canvas,mbLeft,[],140,100);
      Check(Pos(FormatFloat('0.00',4.0),Props.Caption)>0,'4000 mm line selected with properties');
      for I:=0 to F.ComponentCount-1 do begin
        C:=F.Components[I];
        if (C is TCADCommandButton) and (TCADCommandButton(C).Caption='Desfazer') then TCADCommandButton(C).Click;
      end;
      Check(Pos('Nenhum',Props.Caption)>0,'undo clears selection');
      for I:=0 to F.ComponentCount-1 do begin
        C:=F.Components[I];
        if (C is TCADCommandButton) and (TCADCommandButton(C).Caption='Refazer') then TCADCommandButton(C).Click;
      end;
      Canvas.OnMouseDown(Canvas,mbLeft,[],140,100);
      Check(Pos(FormatFloat('0.00',4.0),Props.Caption)>0,'redo restores geometry');
      if ParamCount>0 then begin
        Ribbon.ActivePageIndex:=0; Application.ProcessMessages;
        Bitmap:=F.GetFormImage; Preview:=TPortableNetworkGraphic.Create;
        try Preview.Assign(Bitmap); Preview.SaveToFile(ParamStr(1));
        finally Preview.Free; Bitmap.Free; end;
        TButton(F.FindComponent('LibraryGroup0')).Click;
        TButton(F.FindComponent('LibraryGroup1')).Click;
        for I:=0 to F.ComponentCount-1 do begin
          C:=F.Components[I];
          if (C is TCADCommandButton) and (TCADCommandButton(C).Caption='Porta') then TCADCommandButton(C).Click;
        end;
        Check(Tool.ItemIndex=3,'parts button activates door tool');
        Application.ProcessMessages;
        Bitmap:=F.GetFormImage; Preview:=TPortableNetworkGraphic.Create;
        try Preview.Assign(Bitmap); Preview.SaveToFile(ChangeFileExt(ParamStr(1),'-pecas.png'));
        finally Preview.Free; Bitmap.Free; end;
      end;
      F.Width:=960; F.Height:=640; Application.ProcessMessages;
      Check((Canvas.Width>350) and (Canvas.Height>200),'minimum window canvas');
      for I:=0 to Ribbon.PageCount-1 do begin
        Ribbon.ActivePageIndex:=I; Application.ProcessMessages;
      end;
      WriteLn('PASS: all tabs opened');
      Application.Terminate;
    finally F.Free; end;
  except on E:Exception do begin WriteLn(E.ClassName,': ',E.Message); Halt(1); end; end;
end.
