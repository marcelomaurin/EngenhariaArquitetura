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
    GroupID: Integer;
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
    FSelected: Integer;
    FZoom: Double;
    FPanX, FPanY: Integer;
    procedure PanDrawing(Sender: TObject);
    FNextGroup: Integer;
    FUndo: array of TCADLine;
    procedure RedoDrawing(Sender: TObject);
    procedure ZoomDrawing(Sender: TObject);
    procedure SelectObjectAt(const P: TPoint);
    procedure DeleteSelected(Sender: TObject);
    procedure TransformSelected(Sender: TObject);
    procedure SelectionChanged(Sender: TObject);
    procedure AddSegment(const A, B: TPoint);
    procedure AddCircle(const Center, Edge: TPoint);
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
  FSelected := -1;
  FZoom := 1.0;
  FPanX := 0; FPanY := 0;
  FNextGroup := 1;
  FMillimetersPerPixel := 50; // grade de 20 pixels equivale a 1 metro
  TopBar := TPanel.Create(Self); TopBar.Parent := Self; TopBar.Align := alTop;
  TopBar.Height := 48; TopBar.BevelOuter := bvNone;
  AddButton('Exportar DXF', @ExportDXF);
  AddButton('Desfazer', @UndoLine);
  AddButton('Refazer', @RedoDrawing);
  AddButton('Novo desenho', @NewDrawing);
  AddButton('Salvar projeto', @SaveDrawing);
  AddButton('Abrir projeto', @OpenDrawing);
  AddButton('Editar último', @EditLastObject);
  AddButton('Excluir seleção', @DeleteSelected);
  AddButton('Mover seleção', @TransformSelected);
  B.Tag := 0;
  AddButton('Copiar seleção', @TransformSelected);
  B.Tag := 1;
  AddButton('Zoom +', @ZoomDrawing); B.Tag := 1;
  AddButton('Zoom -', @ZoomDrawing); B.Tag := -1;
  AddButton('Pan esquerda', @PanDrawing); B.Tag := 1;
  AddButton('Pan direita', @PanDrawing); B.Tag := 2;
  AddButton('Pan cima', @PanDrawing); B.Tag := 3;
  AddButton('Pan baixo', @PanDrawing); B.Tag := 4;
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
  FToolSelect.Items.Add('Selecionar');
  FToolSelect.Items.Add('Círculo');
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
  Result.X := Round((P.X-FPanX) / (FGrid * FZoom)) * FGrid;
  Result.Y := Round((P.Y-FPanY) / (FGrid * FZoom)) * FGrid;
end;
procedure TCADMainForm.PanDrawing(Sender: TObject);
begin
  case TButton(Sender).Tag of
    1: Dec(FPanX,40);
    2: Inc(FPanX,40);
    3: Dec(FPanY,40);
    4: Inc(FPanY,40);
  end;
  FCanvas.Invalidate;
  RefreshStatus('Vista deslocada');
end;
procedure TCADMainForm.ZoomDrawing(Sender: TObject);
begin
  if TButton(Sender).Tag > 0 then FZoom := Min(4.0, FZoom * 1.25)
  else FZoom := Max(0.5, FZoom / 1.25);
  FCanvas.Invalidate;
  RefreshStatus('Zoom ajustado para ' + IntToStr(Round(FZoom*100)) + '%');
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
  FLines[N].GroupID := FNextGroup;
  FLines[N].Kind := FToolSelect.ItemIndex;
  case FLines[N].Kind of
    2: FLines[N].WidthMM := 150;
    3: FLines[N].WidthMM := 900;
    4: FLines[N].WidthMM := 1200;
  else FLines[N].WidthMM := 0;
  end;
  if FLines[N].Kind = 2 then FLines[N].Layer := 0;
end;
procedure TCADMainForm.AddCircle(const Center, Edge: TPoint);
var Radius, Angle, NextAngle: Double; I: Integer; A, B: TPoint;
begin
  Radius := Hypot(Edge.X-Center.X, Edge.Y-Center.Y);
  if Radius < 1 then Exit;
  for I := 0 to 47 do begin
    Angle := I * 2 * Pi / 48;
    NextAngle := (I+1) * 2 * Pi / 48;
    A := Point(Center.X+Round(Radius*Cos(Angle)),
               Center.Y+Round(Radius*Sin(Angle)));
    B := Point(Center.X+Round(Radius*Cos(NextAngle)),
               Center.Y+Round(Radius*Sin(NextAngle)));
    if (A.X<>B.X) or (A.Y<>B.Y) then begin
      AddSegment(A,B);
      FLines[High(FLines)].Kind := 0;
    end;
  end;
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
  for X := 0 to Round(FCanvas.Width / (FGrid * FZoom)) do begin
    FCanvas.Canvas.MoveTo(Round(X*FGrid*FZoom)+FPanX,0);
    FCanvas.Canvas.LineTo(Round(X*FGrid*FZoom)+FPanX,FCanvas.Height);
  end;
  for Y := 0 to Round(FCanvas.Height / (FGrid * FZoom)) do begin
    FCanvas.Canvas.MoveTo(0,Round(Y*FGrid*FZoom)+FPanY);
    FCanvas.Canvas.LineTo(FCanvas.Width,Round(Y*FGrid*FZoom)+FPanY);
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
    if I = FSelected then begin
      FCanvas.Canvas.Pen.Color := clFuchsia;
      FCanvas.Canvas.Pen.Width := Max(3, FCanvas.Canvas.Pen.Width);
    end;
    FCanvas.Canvas.MoveTo(Round(FLines[I].A.X*FZoom)+FPanX, Round(FLines[I].A.Y*FZoom)+FPanY);
    FCanvas.Canvas.LineTo(Round(FLines[I].B.X*FZoom)+FPanX, Round(FLines[I].B.Y*FZoom)+FPanY);
  end;
  FCanvas.Canvas.Pen.Width := 1;
  if FHasStart then begin
    FCanvas.Canvas.Brush.Color := clRed;
    FCanvas.Canvas.Ellipse(Round(FStart.X*FZoom)+FPanX-4,Round(FStart.Y*FZoom)+FPanY-4,
      Round(FStart.X*FZoom)+FPanX+4,Round(FStart.Y*FZoom)+FPanY+4);
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
  if FToolSelect.ItemIndex = 5 then begin
    SelectObjectAt(Point(Round((X-FPanX)/FZoom),Round((Y-FPanY)/FZoom))); Exit;
  end;
  if not FHasStart then begin
    FStart := P; FHasStart := True;
    RefreshStatus('Selecione o segundo ponto');
  end else begin
    if (ssShift in Shift) and (FToolSelect.ItemIndex in [0,2,3,4]) then begin
      if Abs(P.X-FStart.X) >= Abs(P.Y-FStart.Y) then P.Y := FStart.Y
      else P.X := FStart.X;
    end;
    if FToolSelect.ItemIndex = 6 then AddCircle(FStart,P)
    else if FToolSelect.ItemIndex = 1 then begin
      AddSegment(FStart, Point(P.X,FStart.Y));
      AddSegment(Point(P.X,FStart.Y), P);
      AddSegment(P, Point(FStart.X,P.Y));
      AddSegment(Point(FStart.X,P.Y),FStart);
    end else AddSegment(FStart,P);
    Inc(FNextGroup);
    SetLength(FUndo,0);
    FHasStart := False;
    RefreshStatus('Desenho criado');
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
  SetLength(FLines,0); SetLength(FUndo,0);
  FNextGroup := 1; FHasStart := False; FSelected := -1; FPath := '';
  FCanvas.Invalidate; RefreshStatus('Novo desenho');
end;
procedure TCADMainForm.UndoLine(Sender: TObject);
var G, N: Integer;
begin
  if Length(FLines) = 0 then Exit;
  G := FLines[High(FLines)].GroupID;
  repeat
    N := Length(FUndo); SetLength(FUndo,N+1);
    FUndo[N] := FLines[High(FLines)];
    SetLength(FLines,Length(FLines)-1);
  until (Length(FLines) = 0) or (FLines[High(FLines)].GroupID <> G);
  FSelected := -1;
  FCanvas.Invalidate; RefreshStatus('Operação desfeita');
end;
procedure TCADMainForm.RedoDrawing(Sender: TObject);
var G, N: Integer;
begin
  if Length(FUndo) = 0 then Exit;
  G := FUndo[High(FUndo)].GroupID;
  repeat
    N := Length(FLines); SetLength(FLines,N+1);
    FLines[N] := FUndo[High(FUndo)];
    SetLength(FUndo,Length(FUndo)-1);
  until (Length(FUndo)=0) or (FUndo[High(FUndo)].GroupID <> G);
  FCanvas.Invalidate; RefreshStatus('Operação refeita');
end;
procedure TCADMainForm.SelectObjectAt(const P: TPoint);
var I: Integer; DX, DY, T, Dist, Best: Double; Nearest: Integer;
begin
  Best := 100.0; Nearest := -1;
  for I := 0 to High(FLines) do begin
    DX := FLines[I].B.X - FLines[I].A.X;
    DY := FLines[I].B.Y - FLines[I].A.Y;
    if DX*DX + DY*DY <= 0 then Continue;
    T := ((P.X-FLines[I].A.X)*DX+(P.Y-FLines[I].A.Y)*DY)/(DX*DX+DY*DY);
    T := Max(0.0,Min(1.0,T));
    Dist := Sqrt(Sqr(P.X-FLines[I].A.X-T*DX)+Sqr(P.Y-FLines[I].A.Y-T*DY));
    if (Dist <= 12/FZoom) and (Dist < Best) then begin Best := Dist; Nearest := I; end;
  end;
  FSelected := Nearest; FCanvas.Invalidate;
  if FSelected >= 0 then RefreshStatus('Objeto selecionado')
  else RefreshStatus('Nenhum objeto próximo');
end;
procedure TCADMainForm.DeleteSelected(Sender: TObject);
var I: Integer;
begin
  if FSelected < 0 then begin ShowMessage('Selecione um objeto antes de excluir.'); Exit; end;
  for I := FSelected to High(FLines)-1 do FLines[I] := FLines[I+1];
  SetLength(FLines,Length(FLines)-1);
  FSelected := -1; FCanvas.Invalidate;
  RefreshStatus('Objeto excluído');
end;
procedure TCADMainForm.TransformSelected(Sender: TObject);
var SX, SY: string; DX, DY, Id, N: Integer; IsCopy: Boolean;
begin
  if (FSelected < 0) or (FSelected >= Length(FLines)) then begin
    ShowMessage('Primeiro selecione um objeto.'); Exit;
  end;
  IsCopy := TButton(Sender).Tag = 1;
  SX := '1000'; SY := '0';
  if not InputQuery('Deslocamento em milímetros',
    'Deslocamento horizontal (mm):', SX) then Exit;
  if not InputQuery('Deslocamento em milímetros',
    'Deslocamento vertical (mm):', SY) then Exit;
  if (not TryStrToInt(SX, DX)) or (not TryStrToInt(SY, DY)) then begin
    ShowMessage('Informe coordenadas inteiras em milímetros.'); Exit;
  end;
  if (Abs(Int64(DX)) > 10000000) or (Abs(Int64(DY)) > 10000000) then begin
    ShowMessage('Deslocamento fora do limite.'); Exit;
  end;
  Id := FSelected;
  if IsCopy then begin
    N := Length(FLines);
    SetLength(FLines, N+1);
    FLines[N] := FLines[Id];
    Id := N;
    FSelected := N;
  end;
  Inc(FLines[Id].A.X, Round(DX / FMillimetersPerPixel));
  Inc(FLines[Id].B.X, Round(DX / FMillimetersPerPixel));
  Dec(FLines[Id].A.Y, Round(DY / FMillimetersPerPixel));
  Dec(FLines[Id].B.Y, Round(DY / FMillimetersPerPixel));
  FCanvas.Invalidate;
  if IsCopy then RefreshStatus('Objeto copiado')
  else RefreshStatus('Objeto movido');
end;
procedure TCADMainForm.EditLastObject(Sender: TObject);
var V: string; MM, N: Integer;
begin
  N := FSelected;
  if N < 0 then N := High(FLines);
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
    L.Add('EACAD3');
    L.Add(IntToStr(FMillimetersPerPixel));
    for I := 0 to High(FLines) do
      L.Add(Format('%d;%d;%d;%d;%d;%d;%d;%d', [FLines[I].A.X,FLines[I].A.Y,
        FLines[I].B.X,FLines[I].B.Y,FLines[I].Layer,FLines[I].Kind,
        FLines[I].WidthMM,FLines[I].GroupID]));
    L.SaveToFile(D.FileName);
    FPath := D.FileName; RefreshStatus('Projeto salvo: '+ExtractFileName(FPath));
  finally L.Free; D.Free; end;
end;
procedure TCADMainForm.OpenDrawing(Sender: TObject);
var D: TOpenDialog; L, Fields: TStringList; I, N: Integer; Temp: array of TCADLine;
  Scale, MaxGroup: Integer; Legacy, Grouped: Boolean;
begin
  D := TOpenDialog.Create(Self);
  L := TStringList.Create; Fields := TStringList.Create;
  try
    D.Filter := 'Projeto CAD 2D (*.eacad)|*.eacad';
    if not D.Execute then Exit;
    L.LoadFromFile(D.FileName);
    if (L.Count < 2) or ((L[0] <> 'EACAD1') and (L[0] <> 'EACAD2') and (L[0] <> 'EACAD3')) then
      raise Exception.Create('Formato de projeto não reconhecido');
    Legacy := L[0] = 'EACAD1';
    Grouped := L[0] = 'EACAD3';
    MaxGroup := 0;
    Scale := StrToInt(L[1]);
    if (Scale < 1) or (Scale > 100000) then
      raise Exception.Create('Escala inválida');
    SetLength(Temp,L.Count-2);
    Fields.StrictDelimiter := True; Fields.Delimiter := ';';
    for I := 2 to L.Count-1 do begin
      Fields.DelimitedText := L[I];
      if (Legacy and (Fields.Count <> 6)) or
         ((not Legacy) and (not Grouped) and (Fields.Count <> 7)) or
         (Grouped and (Fields.Count <> 8)) then
        raise Exception.CreateFmt('Linha %d inválida',[I+1]);
      N := I-2;
      if Grouped then Temp[N].GroupID := StrToInt(Fields[7])
      else Temp[N].GroupID := N + 1;
      if (Temp[N].GroupID < 1) or (Temp[N].GroupID > 100000000) then
        raise Exception.CreateFmt('Grupo inválido na linha %d',[I+1]);
      MaxGroup := Max(MaxGroup,Temp[N].GroupID);
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
    FLines := Temp; SetLength(FUndo,0); FNextGroup := MaxGroup+1;
    FSelected := -1; FMillimetersPerPixel := Scale;
    FHasStart := False; FPath := D.FileName;
    FCanvas.Invalidate; RefreshStatus('Projeto aberto: '+ExtractFileName(FPath));
  except on E: Exception do
    MessageDlg('Erro ao abrir projeto', E.Message, mtError, [mbOK], 0);
  end;
  Fields.Free; L.Free; D.Free;
end;

end.
