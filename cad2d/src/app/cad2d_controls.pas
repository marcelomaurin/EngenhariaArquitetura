unit cad2d_controls;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Controls, Graphics, Types, Math, LCLType;
type
  TCADCommandButton = class(TCustomControl)
  private
    FHover, FActive: Boolean;
    FToolIndex: Integer;
    procedure SetActive(Value: Boolean);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Click; override;
    property Active: Boolean read FActive write SetActive;
    property ToolIndex: Integer read FToolIndex write FToolIndex;
    property Caption;
    property OnClick;
  end;
implementation
constructor TCADCommandButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FToolIndex := -1; TabStop := True; Cursor := crHandPoint;
  ControlStyle := ControlStyle + [csClickEvents,csCaptureMouse,csDoubleClicks];
  Font.Name := 'Segoe UI'; Font.Size := 9; DoubleBuffered := True;
  AccessibleRole := larButton;
end;
procedure TCADCommandButton.Click;
begin inherited Click; end;
procedure TCADCommandButton.SetActive(Value: Boolean);
begin
  if FActive=Value then Exit;
  FActive:=Value; Invalidate;
end;
procedure TCADCommandButton.MouseEnter;
begin inherited MouseEnter; FHover:=True; Invalidate; end;
procedure TCADCommandButton.MouseLeave;
begin inherited MouseLeave; FHover:=False; Invalidate; end;
procedure TCADCommandButton.DoEnter;
begin inherited DoEnter; Invalidate; end;
procedure TCADCommandButton.DoExit;
begin inherited DoExit; Invalidate; end;
procedure TCADCommandButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key,Shift);
  if Key in [VK_SPACE,VK_RETURN] then begin Click; Key:=0; end;
end;
procedure TCADCommandButton.Paint;
var X,Y,I: Integer; S: string; R: TRect; Style: TTextStyle;
  procedure Line(X1,Y1,X2,Y2: Integer);
  begin Canvas.Line(X+X1,Y+Y1,X+X2,Y+Y2); end;
  procedure Box(X1,Y1,X2,Y2: Integer);
  begin Canvas.Rectangle(X+X1,Y+Y1,X+X2,Y+Y2); end;
  procedure Circle(X1,Y1,X2,Y2: Integer);
  begin Canvas.Ellipse(X+X1,Y+Y1,X+X2,Y+Y2); end;
  procedure Arrow;
  begin Line(4,12,24,12); Line(18,6,24,12); Line(18,18,24,12); end;
begin
  Canvas.Brush.Style:=bsSolid;
  if FActive then Canvas.Brush.Color:=RGBToColor(40,83,127)
  else if FHover or Focused then Canvas.Brush.Color:=RGBToColor(69,84,103)
  else Canvas.Brush.Color:=RGBToColor(47,57,71);
  Canvas.Pen.Color:=Canvas.Brush.Color;
  if FActive or Focused then Canvas.Pen.Color:=RGBToColor(96,165,250);
  Canvas.RoundRect(1,1,Width-1,Height-1,6,6);
  Canvas.Brush.Style:=bsClear; Canvas.Pen.Width:=2;
  Canvas.Pen.Color:=RGBToColor(147,197,253);
  X:=(Width-28) div 2; Y:=8; S:=Caption;
  if S='Texto' then begin Canvas.Font.Size:=22; Canvas.Font.Color:=clWhite; Canvas.TextOut(X+4,Y-5,'A'); end
  else if S='Polilinha' then begin Line(2,24,9,5); Line(9,5,18,22); Line(18,22,26,4); end
  else if S='Arco' then begin Canvas.Arc(X+2,Y+2,X+26,Y+26,X+26,Y+14,X+2,Y+14); end
  else if S='Elipse' then Canvas.Ellipse(X+1,Y+7,X+27,Y+21)
  else if S='Polígono' then Canvas.Polygon([Point(X+7,Y+3),Point(X+21,Y+3),Point(X+27,Y+14),Point(X+21,Y+25),Point(X+7,Y+25),Point(X+1,Y+14)])
  else if S='Hachura' then begin Box(2,2,26,26); for I:=1 to 5 do Line(2,2+I*4,2+I*4,2); end
  else if S='Vão' then begin Line(2,2,2,26); Line(26,2,26,26); Line(2,14,26,14); end
  else if S='Vaso sanitário' then begin Box(4,2,24,10); Circle(6,10,22,27); end
  else if S='Lavatório' then begin Box(2,3,26,25); Circle(6,7,22,21); end
  else if S='Escala' then begin Box(2,15,13,26); Box(2,2,26,26); Line(13,15,26,2); end
  else if S='Array' then begin for I:=0 to 3 do Box((I mod 2)*15,(I div 2)*15,11+(I mod 2)*15,11+(I div 2)*15); end
  else if S='Stretch' then begin Box(2,6,17,24); Arrow; end
  else if (S='Agrupar') or (S='Desagrupar') then begin Box(2,2,26,26); Circle(6,6,15,15); Box(15,15,22,22); end
  else if S='Escada' then begin Box(2,2,26,26); for I:=1 to 5 do Line(2,I*4,26,I*4); end
  else if S='Pilar' then begin Box(3,3,25,25); Line(3,3,25,25); Line(25,3,3,25); end
  else if (S='Cama') or (S='Sofá') or (S='Mesa') then begin Box(2,3,26,25); Box(6,7,22,13); end
  else if S='Linha' then begin Line(3,25,25,3); Box(1,23,5,27); Box(23,1,27,5); end
  else if S='Retângulo' then Box(2,5,26,23)
  else if S='Círculo' then begin Circle(2,2,26,26); Line(14,14,24,8); end
  else if S='Parede' then begin
    Canvas.Pen.Color:=RGBToColor(226,232,240);
    Box(2,3,26,25); Line(2,10,26,10); Line(2,18,26,18);
    Line(10,3,10,10); Line(19,10,19,18); Line(10,18,10,25);
  end
  else if S='Porta' then begin Line(3,25,3,3); Line(3,25,25,25); Canvas.MoveTo(X+3,Y+3); for I:=1 to 16 do Canvas.LineTo(X+3+Round(22*Sin(I*Pi/32)),Y+25-Round(22*Cos(I*Pi/32))); end
  else if S='Janela' then begin Box(2,6,26,23); Line(2,11,26,11); Line(2,18,26,18); Line(14,6,14,23); end
  else if S='Selecionar' then begin Canvas.Polygon([Point(X+5,Y+2),Point(X+6,Y+26),Point(X+13,Y+19),Point(X+24,Y+18),Point(X+5,Y+2)]); end
  else if S='Novo' then begin Box(5,2,23,27); Line(9,9,19,9); Line(14,14,14,23); Line(9,18,19,18); end
  else if S='Abrir' then begin Canvas.Pen.Color:=RGBToColor(251,191,36); Canvas.Polyline([Point(X+2,Y+23),Point(X+2,Y+5),Point(X+11,Y+5),Point(X+15,Y+9),Point(X+26,Y+9),Point(X+23,Y+23),Point(X+2,Y+23)]); Line(3,13,24,13); end
  else if S='Salvar' then begin Box(3,2,25,26); Box(8,2,20,11); Box(8,17,20,26); end
  else if S='Excluir' then begin Canvas.Pen.Color:=RGBToColor(248,113,113); Box(6,7,22,26); Line(3,7,25,7); Line(10,3,18,3); Line(11,11,11,22); Line(17,11,17,22); end
  else if S='Copiar' then begin Box(2,2,19,19); Box(9,9,26,26); end
  else if S='Mover' then begin Arrow; Line(14,2,14,27); Line(9,7,14,2); Line(19,7,14,2); Line(9,22,14,27); Line(19,22,14,27); Line(4,12,9,7); Line(4,12,9,17); end
  else if (S='Girar') or (S='Desfazer') or (S='Refazer') then begin Canvas.Arc(X+3,Y+3,X+26,Y+26,X+25,Y+14,X+6,Y+4); if S='Refazer' then begin Line(20,2,26,8); Line(26,8,26,1); end else begin Line(3,2,3,10); Line(3,10,11,10); end; end
  else if Pos('Espelhar',S)=1 then begin Line(14,1,14,27); Canvas.Polygon([Point(X+3,Y+22),Point(X+10,Y+6),Point(X+10,Y+22)]); Canvas.Polygon([Point(X+18,Y+22),Point(X+18,Y+6),Point(X+25,Y+22)]); end
  else if S='Offset' then begin Line(3,22,20,5); Line(8,27,25,10); end
  else if (S='Aparar') or (S='Estender') then begin Line(21,2,21,27); Line(2,20,26,6); if S='Aparar' then begin Canvas.Pen.Color:=RGBToColor(248,113,113); Circle(1,2,9,10); Circle(1,11,9,19); end else Arrow; end
  else if (S='Chanfro') or (S='Arredondar') then begin Line(3,26,3,14); Line(14,3,26,3); if S='Chanfro' then Line(3,14,14,3) else Canvas.Arc(X+3,Y+3,X+25,Y+25,X+14,Y+3,X+3,Y+14); end
  else if Pos('Zoom',S)=1 then begin Circle(2,2,21,21); Line(19,19,27,27); Line(6,11,17,11); if Pos('+',S)>0 then Line(11,6,11,17); end
  else if S='Enquadrar tudo' then begin Box(5,5,23,23); Line(1,9,1,1); Line(1,1,9,1); Line(19,27,27,27); Line(27,27,27,19); end
  else if (S='Esquerda') or (S='Direita') or (S='Cima') or (S='Baixo') then begin
    if S='Direita' then Arrow
    else if S='Esquerda' then begin Line(4,14,25,14); Line(4,14,11,7); Line(4,14,11,21); end
    else if S='Cima' then begin Line(14,3,14,26); Line(14,3,7,10); Line(14,3,21,10); end
    else begin Line(14,3,14,26); Line(14,26,7,19); Line(14,26,21,19); end;
  end
  else if (S='DWG / DXF') or (S='IFC') or (S='DXF') or (S='SVG') then begin Box(4,2,23,26); Arrow; end
  else begin
    Canvas.Pen.Color:=RGBToColor(251,191,36);
    Line(2,5,2,25); Line(26,5,26,25); Line(2,14,26,14);
    Line(2,14,7,10); Line(26,14,21,18);
    for I:=0 to 3 do Line(7+I*4,21,7+I*4,25);
  end;
  Canvas.Pen.Width:=1; Canvas.Font.Assign(Font); Canvas.Font.Color:=RGBToColor(226,232,240);
  R:=Rect(3,43,Width-3,Height-3);
  Style := Canvas.TextStyle; Style.Alignment := taCenter; Style.Layout := tlTop;
  Style.Wordbreak := True; Style.SingleLine := False;
  Canvas.TextRect(R,3,43,S,Style);
  Canvas.Brush.Style:=bsSolid;
end;
end.
