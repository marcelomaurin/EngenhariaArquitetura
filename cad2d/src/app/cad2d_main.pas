unit cad2d_main;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, Menus,
  Graphics, Types, Math, Dialogs;
type
  TCADLine = record
    A, B: TPoint;
    Layer: Integer;
    Kind: Integer; // 0 linha, 1 retangulo, 2 parede, 3 porta, 4 janela
    WidthMM: Integer;
  end;
  TCADMainForm = class(TForm)
  private
    FCanvas: TPaintBox;
    FStatus: TLabel;
    FLayerSelect, FToolSelect: TComboBox;
    FLines: array of TCADLine;
    FHasStart: Boolean;
    FStart: TPoint;
    FGrid: Integer;
    FMillimetersPerPixel: Integer;
    FPath: string;
    procedure SelectionChanged(Sender: TObject);
    procedure AddSegment(const A, B: TPoint);
    procedure PaintDrawing(Sender: TObject);
    procedure CanvasClick(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure MouseMoveDrawing(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure NewDrawing(Sender: TObject);
    procedure ExportDXF(Sender: TObject);
    procedure SaveDrawing(Sender: TObject);
    procedure OpenDrawing(Sender: TObject);
    procedure UndoLine(Sender: TObject);
    procedure EditLastObject(Sender: TObject);
    function Snap(P: TPoint): TPoint;
    procedure RefreshStatus(const S: string);
  public
    constructor Create(AOwner: TComponent); override;
  end;
var CADMainForm: TCADMainForm;
implementation
constructor TCADMainForm.Create(AOwner: TComponent);
var TopBar, Footer: TPanel; B: TButton;
  procedure AddButton(const Caption: string; Action: TNotifyEvent);
  begin
    B := TButton.Create(Self); B.Parent := TopBar; B.Align := alLeft;
    B.Width := 125; B.Caption := Caption; B.OnClick := Action;
  end;
begin
  inherited CreateNew(AOwner, 1);
  Caption := 'CAD Arquitetônico 2D — desenho inicial';
  Width := 1100; Height := 730; Position := poScreenCenter;
  Constraints.MinWidth := 700; Constraints.MinHeight := 480;
  Color := RGBToColor(244,246,250); Font.Size := 10;
  FGrid := 20;
  FMillimetersPerPixel := 50; // grade de 20 pixels equivale a 1 metro
  TopBar := TPanel.Create(Self); TopBar.Parent := Self; TopBar.Align := alTop;
  TopBar.Height := 48; TopBar.BevelOuter := bvNone;
  AddButton('Exportar DXF', @ExportDXF);
  AddButton('Desfazer linha', @UndoLine);
  AddButton('Novo desenho', @NewDrawing);
  AddButton('Salvar projeto', @SaveDrawing);
  AddButton('Abrir projeto', @OpenDrawing);
  AddButton('Editar último', @EditLastObject);
  FLayerSelect := TComboBox.Create(Self); FLayerSelect.Parent := TopBar;
  FLayerSelect.Align := alRight; FLayerSelect.Width := 150;
  FLayerSelect.Style := csDropDownList;
  FLayerSelect.Items.Add('Arquitetura');
  FLayerSelect.Items.Add('Estrutura');
  FLayerSelect.Items.Add('Instalações');
  FLayerSelect.ItemIndex := 0; FLayerSelect.OnChange := @SelectionChanged;
  FToolSelect := TComboBox.Create(Self); FToolSelect.Parent := TopBar;
  FToolSelect.Align := alRight; FToolSelect.Width := 135;
  FToolSelect.Style := csDropDownList;
  FToolSelect.Items.Add('Linha'); FToolSelect.Items.Add('Retângulo');
  FToolSelect.Items.Add('Parede'); FToolSelect.Items.Add('Porta');
  FToolSelect.Items.Add('Janela');
  FToolSelect.ItemIndex := 0; FToolSelect.OnChange := @SelectionChanged;
  Footer := TPanel.Create(Self); Footer.Parent := Self; Footer.Align := alBottom;
  Footer.Height := 32; Footer.BevelOuter := bvNone; Footer.Color := clWhite;
  FStatus := TLabel.Create(Self); FStatus.Parent := Footer; FStatus.Align := alClient;
  FStatus.BorderSpacing.Left := 12; FStatus.BorderSpacing.Top := 7;
  FCanvas := TPaintBox.Create(Self); FCanvas.Parent := Self;
  FCanvas.Align := alClient;
  FCanvas.OnPaint := @PaintDrawing; FCanvas.OnMouseDown := @CanvasClick;
  FCanvas.OnMouseMove := @MouseMoveDrawing;
  RefreshStatus('Clique para começar uma linha. Botão direito cancela.');
end;
function TCADMainForm.Snap(P: TPoint): TPoint;
begin
  Result.X := Round(P.X / FGrid) * FGrid;
  Result.Y := Round(P.Y / FGrid) * FGrid;
end;
procedure TCADMainForm.SelectionChanged(Sender: TObject);
begin
  FHasStart := False;
  FCanvas.Invalidate;
  RefreshStatus('Ferramenta ou camada alterada');
end;
procedure TCADMainForm.AddSegment(const A, B: TPoint);
var N: Integer;
begin
  if (A.X = B.X) and (A.Y = B.Y) then Exit;
  N := Length(FLines); SetLength(FLines, N+1);
  FLines[N].A := A; FLines[N].B := B;
  FLines[N].Layer := FLayerSelect.ItemIndex;
  FLines[N].Kind := FToolSelect.ItemIndex;
  case FLines[N].Kind of
    2: FLines[N].WidthMM := 150;
    3: FLines[N].WidthMM := 900;
    4: FLines[N].WidthMM := 1200;
  else FLines[N].WidthMM := 0;
  end;
  if FLines[N].Kind = 2 then FLines[N].Layer := 0;
end;
procedure TCADMainForm.RefreshStatus(const S: string);
begin
  FStatus.Caption := Format('%s   |   %d segmentos   |   grade %d mm   |   camada: %s',
    [S, Length(FLines), FGrid * FMillimetersPerPixel, FLayerSelect.Text]);
end;
procedure TCADMainForm.PaintDrawing(Sender: TObject);
var X, Y, I: Integer; R: TRect;
begin
  R := FCanvas.ClientRect;
  FCanvas.Canvas.Brush.Color := clWhite;
  FCanvas.Canvas.FillRect(R);
  FCanvas.Canvas.Pen.Color := RGBToColor(232,236,244);
  FCanvas.Canvas.Pen.Width := 1;
  for X := 0 to FCanvas.Width div FGrid do begin
    FCanvas.Canvas.MoveTo(X*FGrid,0); FCanvas.Canvas.LineTo(X*FGrid,FCanvas.Height);
  end;
  for Y := 0 to FCanvas.Height div FGrid do begin
    FCanvas.Canvas.MoveTo(0,Y*FGrid); FCanvas.Canvas.LineTo(FCanvas.Width,Y*FGrid);
  end;
  FCanvas.Canvas.Pen.Color := RGBToColor(28,70,150);
  FCanvas.Canvas.Pen.Width := 2;
  for I := 0 to High(FLines) do begin
    case FLines[I].Layer of
      1: FCanvas.Canvas.Pen.Color := RGBToColor(180,80,40);
      2: FCanvas.Canvas.Pen.Color := RGBToColor(25,120,90);
    else FCanvas.Canvas.Pen.Color := RGBToColor(28,70,150);
    end;
    case FLines[I].Kind of
      2: FCanvas.Canvas.Pen.Width := Max(1, Round(FLines[I].WidthMM / FMillimetersPerPixel));
      3: begin FCanvas.Canvas.Pen.Width := 3; FCanvas.Canvas.Pen.Color := clRed; end;
      4: begin FCanvas.Canvas.Pen.Width := 3; FCanvas.Canvas.Pen.Color := clAqua; end;
    else FCanvas.Canvas.Pen.Width := 2;
    end;
    FCanvas.Canvas.MoveTo(FLines[I].A.X, FLines[I].A.Y);
    FCanvas.Canvas.LineTo(FLines[I].B.X, FLines[I].B.Y);
  end;
  FCanvas.Canvas.Pen.Width := 1;
  if FHasStart then begin
    FCanvas.Canvas.Brush.Color := clRed;
    FCanvas.Canvas.Ellipse(FStart.X-4,FStart.Y-4,FStart.X+4,FStart.Y+4);
  end;
end;
procedure TCADMainForm.CanvasClick(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var P: TPoint;
begin
  if Button = mbRight then begin
    FHasStart := False; FCanvas.Invalidate; RefreshStatus('Linha cancelada'); Exit;
  end;
  if Button <> mbLeft then Exit;
  P := Snap(Point(X,Y));
  if not FHasStart then begin
    FStart := P; FHasStart := True;
    RefreshStatus('Selecione o segundo ponto');
  end else begin
    if FToolSelect.ItemIndex = 1 then begin
      AddSegment(FStart, Point(P.X,FStart.Y));
      AddSegment(Point(P.X,FStart.Y), P);
      AddSegment(P, Point(FStart.X,P.Y));
      AddSegment(Point(FStart.X,P.Y),FStart);
    end else AddSegment(FStart,P);
    FHasStart := False;
    RefreshStatus('Linha criada');
  end;
  FCanvas.Invalidate;
end;
procedure TCADMainForm.MouseMoveDrawing(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var P: TPoint;
begin
  if not FHasStart then Exit;
  P := Snap(Point(X,Y));
  RefreshStatus(Format('Início (%d,%d) — próximo (%d,%d)',
    [FStart.X,FStart.Y,P.X,P.Y]));
end;
procedure TCADMainForm.NewDrawing(Sender: TObject);
begin
  if (Length(FLines) > 0) and
    (MessageDlg('Novo desenho','Descartar o desenho atual?',
     mtConfirmation,[mbYes,mbNo],0) <> mrYes) then Exit;
  SetLength(FLines,0); FHasStart := False; FPath := '';
  FCanvas.Invalidate; RefreshStatus('Novo desenho');
end;
procedure TCADMainForm.UndoLine(Sender: TObject);
begin
  if Length(FLines) = 0 then Exit;
  SetLength(FLines,Length(FLines)-1);
  FCanvas.Invalidate; RefreshStatus('Última linha desfeita');
end;
procedure TCADMainForm.EditLastObject(Sender: TObject);
var V: string; MM, N: Integer;
begin
  N := High(FLines);
  if N < 0 then Exit;
  if FLines[N].Kind < 2 then begin
    ShowMessage('A última entidade não é parede, porta ou janela.'); Exit;
  end;
  V := IntToStr(FLines[N].WidthMM);
  if not InputQuery('Propriedade dimensional',
     'Espessura ou largura nominal (mm):', V) then Exit;
  if (not TryStrToInt(V, MM)) or (MM < 50) or (MM > 10000) then begin
    ShowMessage('Informe de 50 a 10000 mm.'); Exit;
  end;
  FLines[N].WidthMM := MM;
  FCanvas.Invalidate;
  RefreshStatus('Dimensão atualizada');
end;
procedure TCADMainForm.ExportDXF(Sender: TObject);
var D: TSaveDialog; L: TStringList; I: Integer;
  function DXFCoord(V: Integer): string;
  begin Result := IntToStr(V * FMillimetersPerPixel); end;
  function LayerName(Index: Integer): string;
  begin
    case Index of
      1: Result := 'ESTRUTURA';
      2: Result := 'INSTALACOES';
    else Result := 'ARQUITETURA';
    end;
  end;
begin
  D := TSaveDialog.Create(Self);
  L := TStringList.Create;
  try
    D.Filter := 'AutoCAD DXF R12 (*.dxf)|*.dxf'; D.DefaultExt := 'dxf';
    D.FileName := 'planta.dxf'; D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    L.Add('0');L.Add('SECTION');L.Add('2');L.Add('HEADER');
    L.Add('9');L.Add('$INSUNITS');L.Add('70');L.Add('4');
    L.Add('0');L.Add('ENDSEC');
    L.Add('0');L.Add('SECTION');L.Add('2');L.Add('ENTITIES');
    for I := 0 to High(FLines) do begin
      L.Add('0'); L.Add('LINE');L.Add('8');L.Add(LayerName(FLines[I].Layer));
      L.Add('10');L.Add(DXFCoord(FLines[I].A.X));
      L.Add('20');L.Add(DXFCoord(-FLines[I].A.Y));
      L.Add('30');L.Add('0');
      L.Add('11');L.Add(DXFCoord(FLines[I].B.X));
      L.Add('21');L.Add(DXFCoord(-FLines[I].B.Y));
      L.Add('31');L.Add('0');
    end;
    L.Add('0');L.Add('ENDSEC');L.Add('0');L.Add('EOF');
    L.SaveToFile(D.FileName);
    RefreshStatus('DXF exportado: '+ExtractFileName(D.FileName));
  finally
    L.Free; D.Free;
  end;
end;
procedure TCADMainForm.SaveDrawing(Sender: TObject);
var D: TSaveDialog; L: TStringList; I: Integer;
begin
  D := TSaveDialog.Create(Self);
  L := TStringList.Create;
  try
    D.Filter := 'Projeto CAD 2D (*.eacad)|*.eacad';
    D.DefaultExt := 'eacad'; D.Options := D.Options + [ofOverwritePrompt];
    if FPath <> '' then D.FileName := FPath else D.FileName := 'planta.eacad';
    if not D.Execute then Exit;
    L.Add('EACAD2');
    L.Add(IntToStr(FMillimetersPerPixel));
    for I := 0 to High(FLines) do
      L.Add(Format('%d;%d;%d;%d;%d;%d;%d', [FLines[I].A.X,FLines[I].A.Y,
        FLines[I].B.X,FLines[I].B.Y,FLines[I].Layer,FLines[I].Kind,
        FLines[I].WidthMM]));
    L.SaveToFile(D.FileName);
    FPath := D.FileName; RefreshStatus('Projeto salvo: '+ExtractFileName(FPath));
  finally L.Free; D.Free; end;
end;
procedure TCADMainForm.OpenDrawing(Sender: TObject);
var D: TOpenDialog; L, Fields: TStringList; I, N: Integer; Temp: array of TCADLine;
  Scale: Integer; Legacy: Boolean;
begin
  D := TOpenDialog.Create(Self);
  L := TStringList.Create; Fields := TStringList.Create;
  try
    D.Filter := 'Projeto CAD 2D (*.eacad)|*.eacad';
    if not D.Execute then Exit;
    L.LoadFromFile(D.FileName);
    if (L.Count < 2) or ((L[0] <> 'EACAD1') and (L[0] <> 'EACAD2')) then
      raise Exception.Create('Formato de projeto não reconhecido');
    Legacy := L[0] = 'EACAD1';
    Scale := StrToInt(L[1]);
    if (Scale < 1) or (Scale > 100000) then
      raise Exception.Create('Escala inválida');
    SetLength(Temp,L.Count-2);
    Fields.StrictDelimiter := True; Fields.Delimiter := ';';
    for I := 2 to L.Count-1 do begin
      Fields.DelimitedText := L[I];
      if (Legacy and (Fields.Count <> 6)) or
        ((not Legacy) and (Fields.Count <> 7)) then
        raise Exception.CreateFmt('Linha %d inválida',[I+1]);
      N := I-2;
      Temp[N].A.X := StrToInt(Fields[0]); Temp[N].A.Y := StrToInt(Fields[1]);
      Temp[N].B.X := StrToInt(Fields[2]); Temp[N].B.Y := StrToInt(Fields[3]);
      Temp[N].Layer := StrToInt(Fields[4]); Temp[N].Kind := StrToInt(Fields[5]);
      if Legacy then begin
        case Temp[N].Kind of
          2: Temp[N].WidthMM := 150;
          3: Temp[N].WidthMM := 900;
          4: Temp[N].WidthMM := 1200;
        else Temp[N].WidthMM := 0;
        end;
      end else Temp[N].WidthMM := StrToInt(Fields[6]);
      if (Temp[N].Layer < 0) or (Temp[N].Layer > 2) or
         (Temp[N].Kind < 0) or (Temp[N].Kind > 4) then
        raise Exception.CreateFmt('Objeto inválido na linha %d',[I+1]);
    end;
    FLines := Temp; FMillimetersPerPixel := Scale;
    FHasStart := False; FPath := D.FileName;
    FCanvas.Invalidate; RefreshStatus('Projeto aberto: '+ExtractFileName(FPath));
  except on E: Exception do
    MessageDlg('Erro ao abrir projeto', E.Message, mtError, [mbOK], 0);
  end;
  Fields.Free; L.Free; D.Free;
end;

end.
