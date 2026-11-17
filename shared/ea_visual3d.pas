unit ea_visual3d;

{ Núcleo Comum - Visualização 3D interativa (ea_visual3d).
  Implementa etapa N5 de docs/Nucleo_Comum.md:
  navegação orbital, pan, zoom, câmera perspectiva/ortográfica, vistas padrão,
  iluminação de prévia e seleção de objetos por clique sobre a malha 3D. }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Types, Math, Controls, Graphics, ExtCtrls,
  ea_geometria, ea_malha3d;

type
  TEAViewPreset = (evpIso, evpTop, evpFront, evpSide);

  TEASelectTagEvent = procedure(Sender: TObject; const TagId: string) of object;

  TEAViewport3D = class(TPaintBox)
  private
    FMesh: TEAMesh3D;
    FTarget: TEAVec3;
    FYawDeg: Double;
    FPitchDeg: Double;
    FDistanceMM: Double;
    FOrtho: Boolean;
    FWireframe: Boolean;
    FShowGrid: Boolean;
    FSelectedTag: string;
    FDragging: Boolean;
    FPanning: Boolean;
    FLastMouse: TPoint;
    FOnSelectTag: TEASelectTagEvent;
    procedure PaintScene(Sender: TObject);
    procedure HandleMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure HandleMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure HandleMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure HandleWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    function ProjectPoint(const P: TEAVec3; out SX, SY, Depth: Double): Boolean;
    function PickTagAt(X, Y: Integer): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure FitToMesh;
    procedure SetPreset(Preset: TEAViewPreset);
    procedure SetCamera(const ATarget: TEAVec3; AYawDeg, APitchDeg, ADistMM: Double);
    property Mesh: TEAMesh3D read FMesh;
    property Target: TEAVec3 read FTarget write FTarget;
    property YawDeg: Double read FYawDeg write FYawDeg;
    property PitchDeg: Double read FPitchDeg write FPitchDeg;
    property DistanceMM: Double read FDistanceMM write FDistanceMM;
    property Ortho: Boolean read FOrtho write FOrtho;
    property Wireframe: Boolean read FWireframe write FWireframe;
    property ShowGrid: Boolean read FShowGrid write FShowGrid;
    property SelectedTag: string read FSelectedTag write FSelectedTag;
    property OnSelectTag: TEASelectTagEvent read FOnSelectTag write FOnSelectTag;
  end;

implementation

type
  TRenderTri = record
    P: array[0..2] of TPoint;
    Depth: Double;
    ShadeColor: TColor;
    TagId: string;
  end;

function RGBToTColorShade(RGB: LongWord; Factor: Double; Selected: Boolean): TColor;
var
  R, G, B: Integer;
begin
  R := EnsureRange(Round(((RGB shr 16) and $FF) * Factor), 0, 255);
  G := EnsureRange(Round(((RGB shr 8) and $FF) * Factor), 0, 255);
  B := EnsureRange(Round((RGB and $FF) * Factor), 0, 255);
  if Selected then
  begin
    R := Min(255, R + 45);
    G := Min(255, G + 65);
    B := Min(255, B + 110);
  end;
  Result := RGBToColor(R, G, B);
end;

constructor TEAViewport3D.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMesh := TEAMesh3D.Create;
  FTarget := EAV3(2000, 1500, 1000);
  FYawDeg := 40.0;
  FPitchDeg := 28.0;
  FDistanceMM := 9000.0;
  FOrtho := False;
  FWireframe := False;
  FShowGrid := True;
  FSelectedTag := '';
  OnPaint := @PaintScene;
  OnMouseDown := @HandleMouseDown;
  OnMouseMove := @HandleMouseMove;
  OnMouseUp := @HandleMouseUp;
  OnMouseWheel := @HandleWheel;
end;

destructor TEAViewport3D.Destroy;
begin
  FMesh.Free;
  inherited Destroy;
end;

procedure TEAViewport3D.FitToMesh;
var
  B: TEABox3D;
  Sz: TEAVec3;
  Diag: Double;
begin
  B := FMesh.Bounds;
  if not B.Valid then
  begin
    FTarget := EAV3(0, 0, 0);
    FDistanceMM := 8000.0;
    Invalidate;
    Exit;
  end;
  FTarget := EABoxCenter(B);
  Sz := EABoxSize(B);
  Diag := Sqrt(Sz.X * Sz.X + Sz.Y * Sz.Y + Sz.Z * Sz.Z);
  FDistanceMM := Max(1500.0, Diag * 1.45);
  Invalidate;
end;

procedure TEAViewport3D.SetPreset(Preset: TEAViewPreset);
begin
  case Preset of
    evpIso: begin FYawDeg := 40.0; FPitchDeg := 28.0; end;
    evpTop: begin FYawDeg := 0.0; FPitchDeg := 89.0; end;
    evpFront: begin FYawDeg := 0.0; FPitchDeg := 0.0; end;
    evpSide: begin FYawDeg := 90.0; FPitchDeg := 0.0; end;
  end;
  Invalidate;
end;

procedure TEAViewport3D.SetCamera(const ATarget: TEAVec3; AYawDeg, APitchDeg, ADistMM: Double);
begin
  FTarget := ATarget;
  FYawDeg := AYawDeg;
  FPitchDeg := EnsureRange(APitchDeg, -89.0, 89.0);
  FDistanceMM := Max(200.0, ADistMM);
  Invalidate;
end;

function TEAViewport3D.ProjectPoint(const P: TEAVec3; out SX, SY, Depth: Double): Boolean;
var
  Yaw, Pitch, CY, SYaw, CP, SP: Double;
  D, CamX, CamY, CamZ, FOVScale, W, H: Double;
begin
  Yaw := DegToRad(FYawDeg);
  Pitch := DegToRad(FPitchDeg);
  CY := Cos(Yaw); SYaw := Sin(Yaw);
  CP := Cos(Pitch); SP := Sin(Pitch);

  D := 0;
  { Deslocamento relativo ao alvo }
  CamX := (P.X - FTarget.X) * CY + (P.Y - FTarget.Y) * SYaw;
  CamY := -(P.X - FTarget.X) * SYaw + (P.Y - FTarget.Y) * CY;
  CamZ := (P.Z - FTarget.Z);

  { Rotacao de pitch: eixo visual aponta ao longo de +CamY }
  Depth := CamY * CP + CamZ * SP + FDistanceMM;
  CamZ := -CamY * SP + CamZ * CP;

  W := Max(1, Width);
  H := Max(1, Height);
  if FOrtho then
  begin
    FOVScale := Min(W, H) / Max(500.0, FDistanceMM * 0.95);
    SX := W * 0.5 + CamX * FOVScale;
    SY := H * 0.5 - CamZ * FOVScale;
    Exit(True);
  end;

  if Depth <= 50.0 then Exit(False);
  FOVScale := Min(W, H) * 1.15;
  SX := W * 0.5 + (CamX / Depth) * FOVScale;
  SY := H * 0.5 - (CamZ / Depth) * FOVScale;
  Result := True;
end;

procedure SortRenderTris(var Tris: array of TRenderTri; L, R: Integer);
var
  I, J: Integer;
  Pivot: Double;
  Tmp: TRenderTri;
begin
  I := L; J := R;
  Pivot := Tris[(L + R) div 2].Depth;
  repeat
    while Tris[I].Depth > Pivot do Inc(I);
    while Tris[J].Depth < Pivot do Dec(J);
    if I <= J then
    begin
      Tmp := Tris[I]; Tris[I] := Tris[J]; Tris[J] := Tmp;
      Inc(I); Dec(J);
    end;
  until I > J;
  if L < J then SortRenderTris(Tris, L, J);
  if I < R then SortRenderTris(Tris, I, R);
end;

procedure TEAViewport3D.PaintScene(Sender: TObject);
var
  C: TCanvas;
  I, N, K: Integer;
  LightDir: TEAVec3;
  Dot, Shade, SX0, SY0, D0, SX1, SY1, D1, SX2, SY2, D2: Double;
  Tris: array of TRenderTri;
  GridStep, GMax, GX, GY: Double;
  P0, P1: TEAVec3;
  IsSel: Boolean;
begin
  C := Canvas;
  C.Brush.Color := RGBToColor(15, 23, 42);
  C.FillRect(0, 0, Width, Height);

  { Grade no plano Z = 0 }
  if FShowGrid then
  begin
    C.Pen.Color := RGBToColor(30, 41, 59);
    C.Pen.Width := 1;
    GridStep := 1000.0;
    GMax := 10000.0;
    GX := -GMax;
    while GX <= GMax do
    begin
      P0 := EAV3(GX, -GMax, 0);
      P1 := EAV3(GX, GMax, 0);
      if ProjectPoint(P0, SX0, SY0, D0) and ProjectPoint(P1, SX1, SY1, D1) then
        C.Line(Round(SX0), Round(SY0), Round(SX1), Round(SY1));
      P0 := EAV3(-GMax, GX, 0);
      P1 := EAV3(GMax, GX, 0);
      if ProjectPoint(P0, SX0, SY0, D0) and ProjectPoint(P1, SX1, SY1, D1) then
        C.Line(Round(SX0), Round(SY0), Round(SX1), Round(SY1));
      GX := GX + GridStep;
    end;
    { Eixos RGB na origem }
    if ProjectPoint(EAV3(0, 0, 0), SX0, SY0, D0) then
    begin
      if ProjectPoint(EAV3(1500, 0, 0), SX1, SY1, D1) then begin C.Pen.Color := clRed; C.Line(Round(SX0), Round(SY0), Round(SX1), Round(SY1)); end;
      if ProjectPoint(EAV3(0, 1500, 0), SX1, SY1, D1) then begin C.Pen.Color := clLime; C.Line(Round(SX0), Round(SY0), Round(SX1), Round(SY1)); end;
      if ProjectPoint(EAV3(0, 0, 1500), SX1, SY1, D1) then begin C.Pen.Color := clSkyBlue; C.Line(Round(SX0), Round(SY0), Round(SX1), Round(SY1)); end;
    end;
  end;

  LightDir := EAV3Norm(EAV3(0.45, -0.55, 0.70));
  SetLength(Tris, FMesh.TriangleCount);
  N := 0;
  for I := 0 to High(FMesh.Triangles) do
  begin
    if not ProjectPoint(FMesh.Triangles[I].A.Pos, SX0, SY0, D0) then Continue;
    if not ProjectPoint(FMesh.Triangles[I].B.Pos, SX1, SY1, D1) then Continue;
    if not ProjectPoint(FMesh.Triangles[I].C.Pos, SX2, SY2, D2) then Continue;

    Dot := Abs(EAV3Dot(FMesh.Triangles[I].Normal, LightDir));
    Shade := 0.42 + 0.58 * Dot;
    IsSel := (FSelectedTag <> '') and (FMesh.Triangles[I].TagId = FSelectedTag);

    Tris[N].P[0] := Point(Round(SX0), Round(SY0));
    Tris[N].P[1] := Point(Round(SX1), Round(SY1));
    Tris[N].P[2] := Point(Round(SX2), Round(SY2));
    Tris[N].Depth := (D0 + D1 + D2) / 3.0;
    Tris[N].ShadeColor := RGBToTColorShade(FMesh.Triangles[I].ColorRGB, Shade, IsSel);
    Tris[N].TagId := FMesh.Triangles[I].TagId;
    Inc(N);
  end;

  if N > 1 then SortRenderTris(Tris, 0, N - 1);

  for I := 0 to N - 1 do
  begin
    if FWireframe then
    begin
      C.Brush.Style := bsClear;
      C.Pen.Color := Tris[I].ShadeColor;
      C.Polygon(Tris[I].P);
      C.Brush.Style := bsSolid;
    end
    else
    begin
      C.Brush.Color := Tris[I].ShadeColor;
      C.Pen.Color := RGBToTColorShade(ColorToRGB(Tris[I].ShadeColor), 0.75, False);
      C.Polygon(Tris[I].P);
    end;
  end;

  C.Brush.Style := bsClear;
  C.Font.Color := RGBToColor(203, 213, 225);
  C.TextOut(10, 10, Format('3D | Triângulos: %d | Yaw: %.0f° Pitch: %.0f° Dist: %.2f m | %s',
    [FMesh.TriangleCount, FYawDeg, FPitchDeg, FDistanceMM / 1000.0,
     BoolToStr(FOrtho, 'Ortográfica', 'Perspectiva')]));
  C.Brush.Style := bsSolid;
end;

function PointInTri2D(PX, PY: Double; const P0, P1, P2: TPoint): Boolean;
var
  D1, D2, D3: Double;
  HasNeg, HasPos: Boolean;
  function Sign(AX, AY, BX, BY, CX, CY: Double): Double;
  begin
    Result := (AX - CX) * (BY - CY) - (BX - CX) * (AY - CY);
  end;
begin
  D1 := Sign(PX, PY, P0.X, P0.Y, P1.X, P1.Y);
  D2 := Sign(PX, PY, P1.X, P1.Y, P2.X, P2.Y);
  D3 := Sign(PX, PY, P2.X, P2.Y, P0.X, P0.Y);
  HasNeg := (D1 < 0) or (D2 < 0) or (D3 < 0);
  HasPos := (D1 > 0) or (D2 > 0) or (D3 > 0);
  Result := not (HasNeg and HasPos);
end;

function TEAViewport3D.PickTagAt(X, Y: Integer): string;
var
  I: Integer;
  SX0, SY0, D0, SX1, SY1, D1, SX2, SY2, D2, AvgD, BestD: Double;
begin
  Result := '';
  BestD := 1e12;
  for I := 0 to High(FMesh.Triangles) do
  begin
    if not ProjectPoint(FMesh.Triangles[I].A.Pos, SX0, SY0, D0) then Continue;
    if not ProjectPoint(FMesh.Triangles[I].B.Pos, SX1, SY1, D1) then Continue;
    if not ProjectPoint(FMesh.Triangles[I].C.Pos, SX2, SY2, D2) then Continue;
    AvgD := (D0 + D1 + D2) / 3.0;
    if AvgD >= BestD then Continue;
    if PointInTri2D(X, Y, Point(Round(SX0), Round(SY0)), Point(Round(SX1), Round(SY1)), Point(Round(SX2), Round(SY2))) then
    begin
      BestD := AvgD;
      Result := FMesh.Triangles[I].TagId;
    end;
  end;
end;

procedure TEAViewport3D.HandleMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FLastMouse := Point(X, Y);
  if Button = mbLeft then
  begin
    FDragging := True;
    FPanning := ssShift in Shift;
    if not (ssCtrl in Shift) and not (ssShift in Shift) then
    begin
      FSelectedTag := PickTagAt(X, Y);
      if Assigned(FOnSelectTag) then FOnSelectTag(Self, FSelectedTag);
      Invalidate;
    end;
  end
  else if (Button = mbMiddle) or (Button = mbRight) then
  begin
    FDragging := True;
    FPanning := True;
  end;
end;

procedure TEAViewport3D.HandleMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  DX, DY: Integer;
  YawRad, ScalePan: Double;
begin
  if not FDragging then Exit;
  DX := X - FLastMouse.X;
  DY := Y - FLastMouse.Y;
  FLastMouse := Point(X, Y);
  if FPanning then
  begin
    YawRad := DegToRad(FYawDeg);
    ScalePan := Max(1.0, FDistanceMM * 0.0015);
    FTarget.X := FTarget.X - DX * Cos(YawRad) * ScalePan;
    FTarget.Y := FTarget.Y - DX * Sin(YawRad) * ScalePan;
    FTarget.Z := FTarget.Z + DY * ScalePan;
  end
  else
  begin
    FYawDeg := FYawDeg + DX * 0.5;
    FPitchDeg := EnsureRange(FPitchDeg + DY * 0.5, -89.0, 89.0);
  end;
  Invalidate;
end;

procedure TEAViewport3D.HandleMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FDragging := False;
  FPanning := False;
end;

procedure TEAViewport3D.HandleWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if WheelDelta > 0 then FDistanceMM := Max(300.0, FDistanceMM * 0.88)
  else FDistanceMM := Min(200000.0, FDistanceMM * 1.14);
  Handled := True;
  Invalidate;
end;

end.
