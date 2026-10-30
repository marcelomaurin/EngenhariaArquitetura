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
    FShowDimensions: Boolean;
    FNextGroup: Integer;
    FUndo: array of TCADLine;
    FHistoryUndo, FHistoryRedo: TStringList;
    procedure RecordChange;
    function Snapshot: string;
    procedure RestoreSnapshot(const Value: string);
    procedure PanDrawing(Sender: TObject);
    procedure RedoDrawing(Sender: TObject);
    procedure UndoHistory(Sender: TObject);
    procedure RedoHistory(Sender: TObject);
    procedure ZoomDrawing(Sender: TObject);
    procedure SelectObjectAt(const P: TPoint);
    procedure DeleteSelected(Sender: TObject);
    procedure TransformSelected(Sender: TObject);
    procedure RotateSelected(Sender: TObject);
    procedure MirrorSelected(Sender: TObject);
    procedure OffsetSelected(Sender: TObject);
    procedure ExtendSelected(Sender: TObject);
    procedure TrimSelected(Sender: TObject);
    procedure ChamferSelected(Sender: TObject);
    procedure FilletSelected(Sender: TObject);
    procedure SelectionChanged(Sender: TObject);
    procedure AddSegment(const A, B: TPoint);
    procedure AddCircle(const Center, Edge: TPoint);
    procedure PaintDrawing(Sender: TObject);
    procedure CanvasClick(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure MouseMoveDrawing(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure NewDrawing(Sender: TObject);
    procedure ExportDXF(Sender: TObject);
    procedure ExportSVG(Sender: TObject);
    procedure MeasureSelected(Sender: TObject);
    procedure ToggleDimensions(Sender: TObject);
    procedure SaveDrawing(Sender: TObject);
    procedure OpenDrawing(Sender: TObject);
    procedure UndoLine(Sender: TObject);
    procedure EditLastObject(Sender: TObject);
    function Snap(P: TPoint): TPoint;
    procedure RefreshStatus(const S: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
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
  FShowDimensions := False;
  FNextGroup := 1;
  FHistoryUndo := TStringList.Create;
  FHistoryRedo := TStringList.Create;
  FMillimetersPerPixel := 50; // grade de 20 pixels equivale a 1 metro
  TopBar := TPanel.Create(Self); TopBar.Parent := Self; TopBar.Align := alTop;
  TopBar.Height := 48; TopBar.BevelOuter := bvNone;
  AddButton('Exportar DXF', @ExportDXF);
  AddButton('Exportar SVG', @ExportSVG);
  AddButton('Medir seleção', @MeasureSelected);
  AddButton('Exibir cotas', @ToggleDimensions);
  AddButton('Desfazer', @UndoHistory);
  AddButton('Refazer', @RedoHistory);
  AddButton('Novo desenho', @NewDrawing);
  AddButton('Salvar projeto', @SaveDrawing);
  AddButton('Abrir projeto', @OpenDrawing);
  AddButton('Editar último', @EditLastObject);
  AddButton('Excluir seleção', @DeleteSelected);
  AddButton('Mover seleção', @TransformSelected);
  B.Tag := 0;
  AddButton('Copiar seleção', @TransformSelected);
  B.Tag := 1;
  AddButton('Girar seleção', @RotateSelected);
  AddButton('Espelhar X', @MirrorSelected); B.Tag := 0;
  AddButton('Espelhar Y', @MirrorSelected); B.Tag := 1;
  AddButton('Offset seleção', @OffsetSelected);
  AddButton('Estender até linha', @ExtendSelected);
  AddButton('Aparar (Trim)', @TrimSelected);
  AddButton('Chanfro', @ChamferSelected);
  AddButton('Arredondar canto', @FilletSelected);
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
destructor TCADMainForm.Destroy;
begin
  FHistoryRedo.Free;
  FHistoryUndo.Free;
  inherited Destroy;
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
function TCADMainForm.Snapshot: string;
var I: Integer;
begin
  Result := IntToStr(FNextGroup) + '|' + IntToStr(Length(FLines));
  for I := 0 to High(FLines) do
    Result := Result + '|' + Format('%d,%d,%d,%d,%d,%d,%d,%d',
      [FLines[I].A.X,FLines[I].A.Y,FLines[I].B.X,FLines[I].B.Y,
       FLines[I].Layer,FLines[I].Kind,FLines[I].WidthMM,FLines[I].GroupID]);
end;
procedure TCADMainForm.RestoreSnapshot(const Value: string);
var Parts, Fields: TStringList; I, N: Integer;
begin
  Parts := TStringList.Create; Fields := TStringList.Create;
  try
    Parts.Delimiter := '|'; Parts.StrictDelimiter := True;
    Parts.DelimitedText := Value;
    if Parts.Count < 2 then Exit;
    N := StrToInt(Parts[1]);
    if (N < 0) or (N > 200000) or (Parts.Count <> N+2) then Exit;
    SetLength(FLines,N);
    Fields.Delimiter := ','; Fields.StrictDelimiter := True;
    for I := 0 to N-1 do begin
      Fields.DelimitedText := Parts[I+2];
      if Fields.Count <> 8 then Exit;
      FLines[I].A.X := StrToInt(Fields[0]);
      FLines[I].A.Y := StrToInt(Fields[1]);
      FLines[I].B.X := StrToInt(Fields[2]);
      FLines[I].B.Y := StrToInt(Fields[3]);
      FLines[I].Layer := StrToInt(Fields[4]);
      FLines[I].Kind := StrToInt(Fields[5]);
      FLines[I].WidthMM := StrToInt(Fields[6]);
      FLines[I].GroupID := StrToInt(Fields[7]);
    end;
    FNextGroup := StrToInt(Parts[0]);
    FSelected := -1; FCanvas.Invalidate;
  finally Fields.Free; Parts.Free; end;
end;
procedure TCADMainForm.RecordChange;
begin
  FHistoryUndo.Add(Snapshot);
  if FHistoryUndo.Count > 60 then FHistoryUndo.Delete(0);
  FHistoryRedo.Clear;
end;
procedure TCADMainForm.UndoHistory(Sender: TObject);
var N: Integer; V: string;
begin
  N := FHistoryUndo.Count;
  if N = 0 then Exit;
  FHistoryRedo.Add(Snapshot);
  V := FHistoryUndo[N-1]; FHistoryUndo.Delete(N-1);
  RestoreSnapshot(V); RefreshStatus('Alteração desfeita');
end;
procedure TCADMainForm.RedoHistory(Sender: TObject);
var N: Integer; V: string;
begin
  N := FHistoryRedo.Count;
  if N = 0 then Exit;
  FHistoryUndo.Add(Snapshot);
  V := FHistoryRedo[N-1]; FHistoryRedo.Delete(N-1);
  RestoreSnapshot(V); RefreshStatus('Alteração refeita');
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
  if FLines[N].Kind = 1 then FLines[N].Kind := 0;
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
var X, Y, I, MX, MY: Integer; R: TRect; MM: Double;
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
    if FShowDimensions then begin
      MM := Hypot(FLines[I].B.X-FLines[I].A.X,
        FLines[I].B.Y-FLines[I].A.Y)*FMillimetersPerPixel;
      MX := Round((FLines[I].A.X+FLines[I].B.X)*FZoom/2)+FPanX;
      MY := Round((FLines[I].A.Y+FLines[I].B.Y)*FZoom/2)+FPanY;
      FCanvas.Canvas.Font.Color := clBlack;
      FCanvas.Canvas.Brush.Style := bsClear;
      FCanvas.Canvas.TextOut(MX+5,MY-14,FormatFloat('0.00',MM/1000)+' m');
      FCanvas.Canvas.Brush.Style := bsSolid;
    end;
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
    RecordChange;
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
  RecordChange;
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
  RecordChange;
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
  RecordChange;
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
procedure TCADMainForm.RotateSelected(Sender: TObject);
var AngleText: string; Degrees, Radians, CX, CY: Double;
  A, B: TPoint;
  function RotatePoint(const P: TPoint): TPoint;
  var RX, RY: Double;
  begin
    RX := P.X-CX; RY := P.Y-CY;
    Result.X := Round(CX+RX*Cos(Radians)-RY*Sin(Radians));
    Result.Y := Round(CY+RX*Sin(Radians)+RY*Cos(Radians));
  end;
begin
  if (FSelected < 0) or (FSelected >= Length(FLines)) then begin
    ShowMessage('Selecione um objeto antes de girar.'); Exit;
  end;
  AngleText := '90';
  if not InputQuery('Girar objeto', 'Ângulo em graus (sentido horário na tela):',AngleText) then Exit;
  if not TryStrToFloat(AngleText,Degrees) then begin
    ShowMessage('Ângulo inválido.'); Exit;
  end;
  if (IsNan(Degrees)) or (IsInfinite(Degrees)) or (Abs(Degrees)>36000) then begin
    ShowMessage('Ângulo fora do limite.'); Exit;
  end;
  Radians := DegToRad(Degrees);
  A := FLines[FSelected].A; B := FLines[FSelected].B;
  CX := (A.X+B.X)/2; CY := (A.Y+B.Y)/2;
  RecordChange;
  FLines[FSelected].A := RotatePoint(A);
  FLines[FSelected].B := RotatePoint(B);
  FCanvas.Invalidate; RefreshStatus('Objeto girado');
end;
procedure TCADMainForm.MirrorSelected(Sender: TObject);
var CX, CY: Double; Id: Integer;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione um objeto antes de espelhar.'); Exit;
  end;
  CX := (FLines[Id].A.X+FLines[Id].B.X)/2;
  CY := (FLines[Id].A.Y+FLines[Id].B.Y)/2;
  RecordChange;
  if TButton(Sender).Tag=0 then begin
    FLines[Id].A.Y := Round(2*CY-FLines[Id].A.Y);
    FLines[Id].B.Y := Round(2*CY-FLines[Id].B.Y);
  end else begin
    FLines[Id].A.X := Round(2*CX-FLines[Id].A.X);
    FLines[Id].B.X := Round(2*CX-FLines[Id].B.X);
  end;
  FCanvas.Invalidate; RefreshStatus('Objeto espelhado');
end;
procedure TCADMainForm.OffsetSelected(Sender: TObject);
var N, Id: Integer; DistanceText: string; MM, DX, DY, Len, ShiftX, ShiftY: Double;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione uma linha antes de aplicar offset.'); Exit;
  end;
  DistanceText := '200';
  if not InputQuery('Offset paralelo',
     'Distância assinada em milímetros:', DistanceText) then Exit;
  if not TryStrToFloat(DistanceText,MM) then begin
    ShowMessage('Distância inválida.'); Exit;
  end;
  if IsNan(MM) or IsInfinite(MM) or (Abs(MM)>1000000) then begin
    ShowMessage('Distância fora do limite.'); Exit;
  end;
  DX := FLines[Id].B.X-FLines[Id].A.X;
  DY := FLines[Id].B.Y-FLines[Id].A.Y;
  Len := Hypot(DX,DY);
  if Len < 1 then Exit;
  ShiftX := -DY*MM/(Len*FMillimetersPerPixel);
  ShiftY := DX*MM/(Len*FMillimetersPerPixel);
  RecordChange;
  N := Length(FLines);
  SetLength(FLines,N+1);
  FLines[N] := FLines[Id];
  FLines[N].A.X := Round(FLines[N].A.X+ShiftX);
  FLines[N].A.Y := Round(FLines[N].A.Y+ShiftY);
  FLines[N].B.X := Round(FLines[N].B.X+ShiftX);
  FLines[N].B.Y := Round(FLines[N].B.Y+ShiftY);
  FLines[N].GroupID := FNextGroup;
  Inc(FNextGroup);
  FSelected := N;
  FCanvas.Invalidate;
  RefreshStatus('Offset paralelo criado');
end;
procedure TCADMainForm.ExtendSelected(Sender: TObject);
var TargetText: string; Id, Other: Integer;
  AX, AY, BX, BY, CX, CY, DX, DY, Den, T, U, PX, PY: Double;
  A, B: TPoint;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione o segmento que deseja estender.'); Exit;
  end;
  TargetText := IntToStr(Id+1);
  if not InputQuery('Estender até linha', 'Número do segmento de limite (1 a '+
    IntToStr(Length(FLines))+'):', TargetText) then Exit;
  if (not TryStrToInt(TargetText,Other)) or (Other<1) or
    (Other>Length(FLines)) or (Other=Id+1) then begin
    ShowMessage('Segmento de limite inválido.'); Exit;
  end;
  Dec(Other);
  A := FLines[Id].A; B := FLines[Id].B;
  AX := A.X; AY := A.Y; BX := B.X; BY := B.Y;
  CX := FLines[Other].A.X; CY := FLines[Other].A.Y;
  DX := FLines[Other].B.X; DY := FLines[Other].B.Y;
  Den := (BX-AX)*(DY-CY)-(BY-AY)*(DX-CX);
  if Abs(Den)<0.000001 then begin
    ShowMessage('Linhas paralelas ou coincidentes.'); Exit;
  end;
  T := ((CX-AX)*(DY-CY)-(CY-AY)*(DX-CX))/Den;
  U := ((CX-AX)*(BY-AY)-(CY-AY)*(BX-AX))/Den;
  if (U<0) or (U>1) then begin
    ShowMessage('A interseção está fora do segmento de limite.'); Exit;
  end;
  if (T>=0) and (T<=1) then begin
    ShowMessage('A interseção já está no segmento selecionado.'); Exit;
  end;
  if (Abs(T)>10000) then begin
    ShowMessage('Prolongamento excede o limite.'); Exit;
  end;
  PX := AX+T*(BX-AX); PY := AY+T*(BY-AY);
  RecordChange;
  if T<0 then FLines[Id].A := Point(Round(PX),Round(PY))
  else FLines[Id].B := Point(Round(PX),Round(PY));
  FCanvas.Invalidate;
  RefreshStatus('Segmento estendido até a interseção');
end;
procedure TCADMainForm.TrimSelected(Sender: TObject);
var TargetText, EndText: string; Id, Other: Integer;
  AX, AY, BX, BY, CX, CY, DX, DY, Den, T, U: Double;
  CutPoint: TPoint;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione o segmento que deseja aparar.'); Exit;
  end;
  TargetText := '';
  if not InputQuery('Aparar segmento',
     'Número do segmento de limite (1 a '+IntToStr(Length(FLines))+'):',TargetText) then Exit;
  if (not TryStrToInt(TargetText,Other)) or (Other < 1) or
     (Other > Length(FLines)) or (Other = Id+1) then begin
    ShowMessage('Segmento de limite inválido.'); Exit;
  end;
  Dec(Other);
  AX := FLines[Id].A.X; AY := FLines[Id].A.Y;
  BX := FLines[Id].B.X; BY := FLines[Id].B.Y;
  CX := FLines[Other].A.X; CY := FLines[Other].A.Y;
  DX := FLines[Other].B.X; DY := FLines[Other].B.Y;
  Den := (BX-AX)*(DY-CY)-(BY-AY)*(DX-CX);
  if Abs(Den) < 0.000001 then begin
    ShowMessage('Linhas paralelas ou coincidentes.'); Exit;
  end;
  T := ((CX-AX)*(DY-CY)-(CY-AY)*(DX-CX))/Den;
  U := ((CX-AX)*(BY-AY)-(CY-AY)*(BX-AX))/Den;
  if (T<=0) or (T>=1) or (U<0) or (U>1) then begin
    ShowMessage('Não há interseção interna para aparar.'); Exit;
  end;
  EndText := 'B';
  if not InputQuery('Escolher extremidade', 'Remover lado A ou B?',EndText) then Exit;
  EndText := UpperCase(Trim(EndText));
  if (EndText <> 'A') and (EndText <> 'B') then begin
    ShowMessage('Escolha A ou B.'); Exit;
  end;
  CutPoint := Point(Round(AX+T*(BX-AX)),Round(AY+T*(BY-AY)));
  RecordChange;
  if EndText='A' then FLines[Id].A := CutPoint
  else FLines[Id].B := CutPoint;
  FCanvas.Invalidate;
  RefreshStatus('Segmento aparado');
end;
procedure TCADMainForm.ChamferSelected(Sender: TObject);
var OtherText, DistanceText: string; Id, Other, N: Integer;
    AX, AY, BX, BY, CX, CY, DX, DY, Den, T, U,
    PX, PY, Len1, Len2, Offset1, Offset2: Double;
    P1, P2: TPoint; ChangeA1, ChangeA2: Boolean;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione a primeira linha para criar o chanfro.'); Exit;
  end;
  OtherText := '';
  if not InputQuery('Chanfro', 'Número da segunda linha:', OtherText) then Exit;
  if (not TryStrToInt(OtherText,Other)) or (Other < 1) or
    (Other > Length(FLines)) or (Other = Id+1) then begin
    ShowMessage('Segunda linha inválida.'); Exit;
  end;
  Dec(Other);
  DistanceText := '200';
  if not InputQuery('Chanfro', 'Distância em milímetros:', DistanceText) then Exit;
  if not TryStrToFloat(DistanceText,Offset1) then begin
    ShowMessage('Distância inválida.'); Exit;
  end;
  if IsNan(Offset1) or IsInfinite(Offset1) or
    (Offset1 <= 0) or (Offset1 > 1000000) then begin
    ShowMessage('Distância fora do limite.'); Exit;
  end;
  AX := FLines[Id].A.X; AY := FLines[Id].A.Y;
  BX := FLines[Id].B.X; BY := FLines[Id].B.Y;
  CX := FLines[Other].A.X; CY := FLines[Other].A.Y;
  DX := FLines[Other].B.X; DY := FLines[Other].B.Y;
  Den := (BX-AX)*(DY-CY)-(BY-AY)*(DX-CX);
  if Abs(Den) < 0.000001 then begin
    ShowMessage('As linhas são paralelas ou coincidentes.'); Exit;
  end;
  T := ((CX-AX)*(DY-CY)-(CY-AY)*(DX-CX))/Den;
  U := ((CX-AX)*(BY-AY)-(CY-AY)*(BX-AX))/Den;
  PX := AX+T*(BX-AX); PY := AY+T*(BY-AY);
  Len1 := Hypot(BX-AX,BY-AY);
  Len2 := Hypot(DX-CX,DY-CY);
  if (Len1 < 1) or (Len2 < 1) then Exit;
  Offset2 := Offset1 / FMillimetersPerPixel;
  ChangeA1 := T < 0.5;
  ChangeA2 := U < 0.5;
  if ChangeA1 then begin
    if (Hypot(AX-PX,AY-PY) < Offset2) then begin
      ShowMessage('Primeira linha curta para este chanfro.'); Exit;
    end;
    P1 := Point(Round(PX+(AX-PX)/Hypot(AX-PX,AY-PY)*Offset2),
                Round(PY+(AY-PY)/Hypot(AX-PX,AY-PY)*Offset2));
  end else begin
    if Hypot(BX-PX,BY-PY) < Offset2 then begin
      ShowMessage('Primeira linha curta para este chanfro.'); Exit;
    end;
    P1 := Point(Round(PX+(BX-PX)/Hypot(BX-PX,BY-PY)*Offset2),
                Round(PY+(BY-PY)/Hypot(BX-PX,BY-PY)*Offset2));
  end;
  if ChangeA2 then begin
    if Hypot(CX-PX,CY-PY) < Offset2 then begin
      ShowMessage('Segunda linha curta para este chanfro.'); Exit;
    end;
    P2 := Point(Round(PX+(CX-PX)/Hypot(CX-PX,CY-PY)*Offset2),
                Round(PY+(CY-PY)/Hypot(CX-PX,CY-PY)*Offset2));
  end else begin
    if Hypot(DX-PX,DY-PY) < Offset2 then begin
      ShowMessage('Segunda linha curta para este chanfro.'); Exit;
    end;
    P2 := Point(Round(PX+(DX-PX)/Hypot(DX-PX,DY-PY)*Offset2),
                Round(PY+(DY-PY)/Hypot(DX-PX,DY-PY)*Offset2));
  end;
  if (P1.X=P2.X) and (P1.Y=P2.Y) then begin
    ShowMessage('Chanfro abaixo da resolução do desenho.'); Exit;
  end;
  RecordChange;
  if ChangeA1 then FLines[Id].A := P1 else FLines[Id].B := P1;
  if ChangeA2 then FLines[Other].A := P2 else FLines[Other].B := P2;
  N := Length(FLines); SetLength(FLines,N+1);
  FLines[N].A := P1; FLines[N].B := P2;
  FLines[N].Layer := FLines[Id].Layer;
  FLines[N].Kind := 0; FLines[N].WidthMM := 0;
  FLines[N].GroupID := FNextGroup; Inc(FNextGroup);
  FSelected := N;
  FCanvas.Invalidate;
  RefreshStatus('Chanfro criado');
end;
procedure TCADMainForm.FilletSelected(Sender: TObject);
var Id, Other, N, J, Steps: Integer; TextId, TextRadius: string;
    AX, AY, BX, BY, CX, CY, DX, DY, Den, T, U, IX, IY,
    V1X, V1Y, V2X, V2Y, L1, L2, DotValue, Angle, Radius,
    Tangent, Q1X, Q1Y, Q2X, Q2Y, BisX, BisY, BisLen,
    CenterX, CenterY, CenterDist, StartAngle, EndAngle,
    Sweep, PrevX, PrevY, X, Y: Double;
    P1, P2, PrevPoint, NextPoint: TPoint;
    NearA1, NearA2: Boolean;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione a primeira linha.'); Exit;
  end;
  TextId := '';
  if not InputQuery('Arredondar canto','Número da segunda linha:',TextId) then Exit;
  if (not TryStrToInt(TextId,Other)) or (Other<1) or
     (Other>Length(FLines)) or (Other=Id+1) then begin
    ShowMessage('Segunda linha inválida.'); Exit;
  end;
  Dec(Other);
  TextRadius := '200';
  if not InputQuery('Arredondar canto','Raio em milímetros:',TextRadius) then Exit;
  if not TryStrToFloat(TextRadius,Radius) then begin
    ShowMessage('Raio inválido.'); Exit;
  end;
  if IsNan(Radius) or IsInfinite(Radius) or
     (Radius <= 0) or (Radius > 1000000) then begin
    ShowMessage('Raio fora do limite.'); Exit;
  end;
  Radius := Radius / FMillimetersPerPixel;
  AX := FLines[Id].A.X; AY := FLines[Id].A.Y;
  BX := FLines[Id].B.X; BY := FLines[Id].B.Y;
  CX := FLines[Other].A.X; CY := FLines[Other].A.Y;
  DX := FLines[Other].B.X; DY := FLines[Other].B.Y;
  Den := (BX-AX)*(DY-CY)-(BY-AY)*(DX-CX);
  if Abs(Den)<0.000001 then begin
    ShowMessage('Linhas paralelas ou coincidentes.'); Exit;
  end;
  T := ((CX-AX)*(DY-CY)-(CY-AY)*(DX-CX))/Den;
  U := ((CX-AX)*(BY-AY)-(CY-AY)*(BX-AX))/Den;
  IX := AX+T*(BX-AX); IY := AY+T*(BY-AY);
  NearA1 := Hypot(IX-AX,IY-AY) <= Hypot(IX-BX,IY-BY);
  NearA2 := Hypot(IX-CX,IY-CY) <= Hypot(IX-DX,IY-DY);
  if NearA1 then begin V1X:=AX-IX; V1Y:=AY-IY; end
  else begin V1X:=BX-IX; V1Y:=BY-IY; end;
  if NearA2 then begin V2X:=CX-IX; V2Y:=CY-IY; end
  else begin V2X:=DX-IX; V2Y:=DY-IY; end;
  L1 := Hypot(V1X,V1Y); L2 := Hypot(V2X,V2Y);
  if (L1<1) or (L2<1) then Exit;
  V1X:=V1X/L1; V1Y:=V1Y/L1;
  V2X:=V2X/L2; V2Y:=V2Y/L2;
  DotValue := Max(-1.0,Min(1.0,V1X*V2X+V1Y*V2Y));
  Angle := ArcCos(DotValue);
  if (Angle < 0.05) or (Angle > Pi-0.05) then begin
    ShowMessage('Ângulo inadequado para arredondamento.'); Exit;
  end;
  Tangent := Radius/Tan(Angle/2);
  if (Tangent >= L1) or (Tangent >= L2) then begin
    ShowMessage('Raio grande demais para os segmentos.'); Exit;
  end;
  Q1X:=IX+Tangent*V1X; Q1Y:=IY+Tangent*V1Y;
  Q2X:=IX+Tangent*V2X; Q2Y:=IY+Tangent*V2Y;
  BisX:=V1X+V2X; BisY:=V1Y+V2Y;
  BisLen:=Hypot(BisX,BisY);
  CenterDist:=Radius/Sin(Angle/2);
  CenterX:=IX+CenterDist*BisX/BisLen;
  CenterY:=IY+CenterDist*BisY/BisLen;
  P1:=Point(Round(Q1X),Round(Q1Y));
  P2:=Point(Round(Q2X),Round(Q2Y));
  if (P1.X=P2.X) and (P1.Y=P2.Y) then begin
    ShowMessage('Raio abaixo da resolução atual.'); Exit;
  end;
  StartAngle:=ArcTan2(Q1Y-CenterY,Q1X-CenterX);
  EndAngle:=ArcTan2(Q2Y-CenterY,Q2X-CenterX);
  Sweep:=EndAngle-StartAngle;
  while Sweep>Pi do Sweep:=Sweep-2*Pi;
  while Sweep< -Pi do Sweep:=Sweep+2*Pi;
  Steps:=Max(4,Min(64,Ceil(Abs(Sweep)*Radius/3)));
  RecordChange;
  if NearA1 then FLines[Id].A:=P1 else FLines[Id].B:=P1;
  if NearA2 then FLines[Other].A:=P2 else FLines[Other].B:=P2;
  PrevPoint:=P1;
  for J:=1 to Steps do begin
    X:=CenterX+Radius*Cos(StartAngle+Sweep*J/Steps);
    Y:=CenterY+Radius*Sin(StartAngle+Sweep*J/Steps);
    NextPoint:=Point(Round(X),Round(Y));
    if J=Steps then NextPoint:=P2;
    if (PrevPoint.X<>NextPoint.X) or (PrevPoint.Y<>NextPoint.Y) then begin
      N:=Length(FLines); SetLength(FLines,N+1);
      FLines[N].A:=PrevPoint; FLines[N].B:=NextPoint;
      FLines[N].Layer:=FLines[Id].Layer; FLines[N].Kind:=0;
      FLines[N].WidthMM:=0; FLines[N].GroupID:=FNextGroup;
    end;
    PrevPoint:=NextPoint;
  end;
  Inc(FNextGroup);
  FSelected:=-1; FCanvas.Invalidate;
  RefreshStatus('Canto arredondado');
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
  RecordChange;
  FLines[N].WidthMM := MM;
  FCanvas.Invalidate;
  RefreshStatus('Dimensão atualizada');
end;
procedure TCADMainForm.ToggleDimensions(Sender: TObject);
begin
  FShowDimensions := not FShowDimensions;
  FCanvas.Invalidate;
  if FShowDimensions then RefreshStatus('Cotas visíveis em metros')
  else RefreshStatus('Cotas ocultas');
end;
procedure TCADMainForm.MeasureSelected(Sender: TObject);
var A, B: TPoint; MM: Double; V: string;
begin
  if (FSelected < 0) or (FSelected >= Length(FLines)) then begin
    ShowMessage('Selecione um segmento antes de medir.'); Exit;
  end;
  A := FLines[FSelected].A; B := FLines[FSelected].B;
  MM := Hypot(B.X-A.X,B.Y-A.Y)*FMillimetersPerPixel;
  V := FormatFloat('0.00',MM/1000);
  ShowMessage('Comprimento: ' + V + ' m (' +
    IntToStr(Round(MM)) + ' mm)');
end;
procedure TCADMainForm.ExportSVG(Sender: TObject);
var D: TSaveDialog; L: TStringList; I, MinX, MaxX, MinY, MaxY: Integer;
  function Num(V: Integer): string;
  begin Result := IntToStr(V*FMillimetersPerPixel); end;
  function Stroke(K: Integer): string;
  begin
    case K of
      2: Result := '#304c83';
      3: Result := '#c44331';
      4: Result := '#158f91';
    else Result := '#204878';
    end;
  end;
begin
  D := TSaveDialog.Create(Self); L := TStringList.Create;
  try
    D.Filter := 'Scalable Vector Graphics (*.svg)|*.svg';
    D.DefaultExt := 'svg'; D.FileName := 'planta.svg';
    D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    MinX := 0; MinY := 0; MaxX := 1000; MaxY := 1000;
    if Length(FLines)>0 then begin
      MinX := FLines[0].A.X; MaxX := MinX;
      MinY := FLines[0].A.Y; MaxY := MinY;
      for I := 0 to High(FLines) do begin
        MinX := Min(MinX,Min(FLines[I].A.X,FLines[I].B.X));
        MinY := Min(MinY,Min(FLines[I].A.Y,FLines[I].B.Y));
        MaxX := Max(MaxX,Max(FLines[I].A.X,FLines[I].B.X));
        MaxY := Max(MaxY,Max(FLines[I].A.Y,FLines[I].B.Y));
      end;
    end;
    L.Add('<?xml version="1.0" encoding="UTF-8"?>');
    L.Add('<svg xmlns="http://www.w3.org/2000/svg" viewBox="' +
      Num(MinX-10) + ' ' + Num(MinY-10) + ' ' +
      Num(Max(20,MaxX-MinX+20)) + ' ' + Num(Max(20,MaxY-MinY+20)) + '">');
    for I := 0 to High(FLines) do
      L.Add('<line x1="' + Num(FLines[I].A.X) + '" y1="' +
        Num(FLines[I].A.Y) + '" x2="' + Num(FLines[I].B.X) +
        '" y2="' + Num(FLines[I].B.Y) + '" stroke="' +
        Stroke(FLines[I].Kind) + '" stroke-width="' +
        IntToStr(Max(10,FLines[I].WidthMM)) + '"/>');
    L.Add('</svg>');
    L.SaveToFile(D.FileName);
    RefreshStatus('SVG exportado: ' + ExtractFileName(D.FileName));
  finally L.Free; D.Free; end;
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
    FHistoryUndo.Clear; FHistoryRedo.Clear;
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
