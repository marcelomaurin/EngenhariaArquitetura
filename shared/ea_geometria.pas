unit ea_geometria;

{ Núcleo Comum - Geometria 2D e 3D em dupla precisão (milímetros).
  Implementa etapas N1 e N4 de docs/Nucleo_Comum.md:
  vetores, tolerâncias, interseções, deslocamento paralelo, áreas e
  fechamento de polígonos, caixas delimitadoras e detecção de colisões 3D. }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  SysUtils, Math;

const
  EA_EPS_MM = 1e-4;
  EA_EPS_ANG = 1e-6;

type
  TEAVec2 = record
    X, Y: Double;
  end;

  TEAVec3 = record
    X, Y, Z: Double;
  end;

  TEAVec2Array = array of TEAVec2;
  TEAVec3Array = array of TEAVec3;

  TEABox3D = record
    Min, Max: TEAVec3;
    Valid: Boolean;
  end;

  TEASegment2D = record
    Id: string;
    A, B: TEAVec2;
  end;
  TEASegment2DArray = array of TEASegment2D;

  TEARoomLoop = record
    Vertices: TEAVec2Array;
    AreaMM2: Double;
    PerimeterMM: Double;
    Centroid: TEAVec2;
  end;
  TEARoomLoopArray = array of TEARoomLoop;

function EAV2(AX, AY: Double): TEAVec2;
function EAV3(AX, AY, AZ: Double): TEAVec3;
function EAV2Add(const A, B: TEAVec2): TEAVec2;
function EAV2Sub(const A, B: TEAVec2): TEAVec2;
function EAV2Scale(const A: TEAVec2; S: Double): TEAVec2;
function EAV2Dot(const A, B: TEAVec2): Double;
function EAV2Cross(const A, B: TEAVec2): Double;
function EAV2Len(const A: TEAVec2): Double;
function EAV2Dist(const A, B: TEAVec2): Double;
function EAV2Norm(const A: TEAVec2): TEAVec2;
function EAV2Perp(const A: TEAVec2): TEAVec2;
function EAV2Equal(const A, B: TEAVec2; Eps: Double = EA_EPS_MM): Boolean;

function EAV3Add(const A, B: TEAVec3): TEAVec3;
function EAV3Sub(const A, B: TEAVec3): TEAVec3;
function EAV3Scale(const A: TEAVec3; S: Double): TEAVec3;
function EAV3Dot(const A, B: TEAVec3): Double;
function EAV3Cross(const A, B: TEAVec3): TEAVec3;
function EAV3Len(const A: TEAVec3): Double;
function EAV3Dist(const A, B: TEAVec3): Double;
function EAV3Norm(const A: TEAVec3): TEAVec3;

function EAEmptyBox3D: TEABox3D;
function EAMakeBox3D(const AMin, AMax: TEAVec3): TEABox3D;
procedure EAExpandBox3D(var Box: TEABox3D; const P: TEAVec3);
procedure EAMergeBox3D(var Box: TEABox3D; const Other: TEABox3D);
function EABoxCenter(const Box: TEABox3D): TEAVec3;
function EABoxSize(const Box: TEABox3D): TEAVec3;
function EABoxIntersects(const A, B: TEABox3D; ClearanceMM: Double = 0.0): Boolean;
function EABoxIntersection(const A, B: TEABox3D): TEABox3D;
function EASegmentBox3D(const A, B: TEAVec3; RadiusMM: Double = 0.0): TEABox3D;
function EASegmentDistance3D(const A1, B1, A2, B2: TEAVec3; out P1, P2: TEAVec3): Double;

function EAIntersectSegments2D(const A1, B1, A2, B2: TEAVec2;
  out Hit: TEAVec2; Eps: Double = EA_EPS_MM): Boolean;
function EAPointToSegmentDist2D(const P, A, B: TEAVec2;
  out Proj: TEAVec2; out T: Double): Double;
procedure EAOffsetSegment2D(const A, B: TEAVec2; OffsetMM: Double;
  out OA, OB: TEAVec2);

function EAPolygonSignedAreaMM2(const Poly: TEAVec2Array): Double;
function EAPolygonAreaMM2(const Poly: TEAVec2Array): Double;
function EAPolygonPerimeterMM(const Poly: TEAVec2Array): Double;
function EAPolygonCentroid(const Poly: TEAVec2Array): TEAVec2;
function EAPointInPolygon2D(const P: TEAVec2; const Poly: TEAVec2Array): Boolean;
function EADetectClosedRooms(const Walls: TEASegment2DArray;
  SnapTolMM: Double = 25.0): TEARoomLoopArray;

implementation

function EAV2(AX, AY: Double): TEAVec2;
begin
  Result.X := AX;
  Result.Y := AY;
end;

function EAV3(AX, AY, AZ: Double): TEAVec3;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Z := AZ;
end;

function EAV2Add(const A, B: TEAVec2): TEAVec2;
begin
  Result.X := A.X + B.X;
  Result.Y := A.Y + B.Y;
end;

function EAV2Sub(const A, B: TEAVec2): TEAVec2;
begin
  Result.X := A.X - B.X;
  Result.Y := A.Y - B.Y;
end;

function EAV2Scale(const A: TEAVec2; S: Double): TEAVec2;
begin
  Result.X := A.X * S;
  Result.Y := A.Y * S;
end;

function EAV2Dot(const A, B: TEAVec2): Double;
begin
  Result := A.X * B.X + A.Y * B.Y;
end;

function EAV2Cross(const A, B: TEAVec2): Double;
begin
  Result := A.X * B.Y - A.Y * B.X;
end;

function EAV2Len(const A: TEAVec2): Double;
begin
  Result := Hypot(A.X, A.Y);
end;

function EAV2Dist(const A, B: TEAVec2): Double;
begin
  Result := Hypot(B.X - A.X, B.Y - A.Y);
end;

function EAV2Norm(const A: TEAVec2): TEAVec2;
var
  L: Double;
begin
  L := EAV2Len(A);
  if L <= EA_EPS_MM then Exit(EAV2(0, 0));
  Result.X := A.X / L;
  Result.Y := A.Y / L;
end;

function EAV2Perp(const A: TEAVec2): TEAVec2;
begin
  Result.X := -A.Y;
  Result.Y := A.X;
end;

function EAV2Equal(const A, B: TEAVec2; Eps: Double): Boolean;
begin
  Result := (Abs(A.X - B.X) <= Eps) and (Abs(A.Y - B.Y) <= Eps);
end;

function EAV3Add(const A, B: TEAVec3): TEAVec3;
begin
  Result.X := A.X + B.X;
  Result.Y := A.Y + B.Y;
  Result.Z := A.Z + B.Z;
end;

function EAV3Sub(const A, B: TEAVec3): TEAVec3;
begin
  Result.X := A.X - B.X;
  Result.Y := A.Y - B.Y;
  Result.Z := A.Z - B.Z;
end;

function EAV3Scale(const A: TEAVec3; S: Double): TEAVec3;
begin
  Result.X := A.X * S;
  Result.Y := A.Y * S;
  Result.Z := A.Z * S;
end;

function EAV3Dot(const A, B: TEAVec3): Double;
begin
  Result := A.X * B.X + A.Y * B.Y + A.Z * B.Z;
end;

function EAV3Cross(const A, B: TEAVec3): TEAVec3;
begin
  Result.X := A.Y * B.Z - A.Z * B.Y;
  Result.Y := A.Z * B.X - A.X * B.Z;
  Result.Z := A.X * B.Y - A.Y * B.X;
end;

function EAV3Len(const A: TEAVec3): Double;
begin
  Result := Sqrt(A.X * A.X + A.Y * A.Y + A.Z * A.Z);
end;

function EAV3Dist(const A, B: TEAVec3): Double;
begin
  Result := EAV3Len(EAV3Sub(B, A));
end;

function EAV3Norm(const A: TEAVec3): TEAVec3;
var
  L: Double;
begin
  L := EAV3Len(A);
  if L <= EA_EPS_MM then Exit(EAV3(0, 0, 0));
  Result.X := A.X / L;
  Result.Y := A.Y / L;
  Result.Z := A.Z / L;
end;

function EAEmptyBox3D: TEABox3D;
begin
  Result.Min := EAV3(0, 0, 0);
  Result.Max := EAV3(0, 0, 0);
  Result.Valid := False;
end;

function EAMakeBox3D(const AMin, AMax: TEAVec3): TEABox3D;
begin
  Result.Min.X := Min(AMin.X, AMax.X);
  Result.Min.Y := Min(AMin.Y, AMax.Y);
  Result.Min.Z := Min(AMin.Z, AMax.Z);
  Result.Max.X := Max(AMin.X, AMax.X);
  Result.Max.Y := Max(AMin.Y, AMax.Y);
  Result.Max.Z := Max(AMin.Z, AMax.Z);
  Result.Valid := True;
end;

procedure EAExpandBox3D(var Box: TEABox3D; const P: TEAVec3);
begin
  if not Box.Valid then
  begin
    Box.Min := P;
    Box.Max := P;
    Box.Valid := True;
    Exit;
  end;
  if P.X < Box.Min.X then Box.Min.X := P.X;
  if P.Y < Box.Min.Y then Box.Min.Y := P.Y;
  if P.Z < Box.Min.Z then Box.Min.Z := P.Z;
  if P.X > Box.Max.X then Box.Max.X := P.X;
  if P.Y > Box.Max.Y then Box.Max.Y := P.Y;
  if P.Z > Box.Max.Z then Box.Max.Z := P.Z;
end;

procedure EAMergeBox3D(var Box: TEABox3D; const Other: TEABox3D);
begin
  if not Other.Valid then Exit;
  EAExpandBox3D(Box, Other.Min);
  EAExpandBox3D(Box, Other.Max);
end;

function EABoxCenter(const Box: TEABox3D): TEAVec3;
begin
  if not Box.Valid then Exit(EAV3(0, 0, 0));
  Result := EAV3Scale(EAV3Add(Box.Min, Box.Max), 0.5);
end;

function EABoxSize(const Box: TEABox3D): TEAVec3;
begin
  if not Box.Valid then Exit(EAV3(0, 0, 0));
  Result := EAV3Sub(Box.Max, Box.Min);
end;

function EABoxIntersects(const A, B: TEABox3D; ClearanceMM: Double): Boolean;
begin
  if (not A.Valid) or (not B.Valid) then Exit(False);
  Result :=
    (A.Min.X <= B.Max.X + ClearanceMM) and (A.Max.X >= B.Min.X - ClearanceMM) and
    (A.Min.Y <= B.Max.Y + ClearanceMM) and (A.Max.Y >= B.Min.Y - ClearanceMM) and
    (A.Min.Z <= B.Max.Z + ClearanceMM) and (A.Max.Z >= B.Min.Z - ClearanceMM);
end;

function EABoxIntersection(const A, B: TEABox3D): TEABox3D;
begin
  if not EABoxIntersects(A, B, 0.0) then Exit(EAEmptyBox3D);
  Result.Min := EAV3(Max(A.Min.X, B.Min.X), Max(A.Min.Y, B.Min.Y), Max(A.Min.Z, B.Min.Z));
  Result.Max := EAV3(Min(A.Max.X, B.Max.X), Min(A.Max.Y, B.Max.Y), Min(A.Max.Z, B.Max.Z));
  Result.Valid := True;
end;

function EASegmentBox3D(const A, B: TEAVec3; RadiusMM: Double): TEABox3D;
begin
  Result := EAMakeBox3D(A, B);
  Result.Min.X := Result.Min.X - RadiusMM;
  Result.Min.Y := Result.Min.Y - RadiusMM;
  Result.Min.Z := Result.Min.Z - RadiusMM;
  Result.Max.X := Result.Max.X + RadiusMM;
  Result.Max.Y := Result.Max.Y + RadiusMM;
  Result.Max.Z := Result.Max.Z + RadiusMM;
end;

function EASegmentDistance3D(const A1, B1, A2, B2: TEAVec3;
  out P1, P2: TEAVec3): Double;
var
  D1, D2, R: TEAVec3;
  A, E, F, C, B, Denom, S, T, SN, SD, TN, TD: Double;
begin
  D1 := EAV3Sub(B1, A1);
  D2 := EAV3Sub(B2, A2);
  R := EAV3Sub(A1, A2);
  A := EAV3Dot(D1, D1);
  E := EAV3Dot(D2, D2);
  F := EAV3Dot(D2, R);
  if (A <= EA_EPS_MM) and (E <= EA_EPS_MM) then
  begin
    P1 := A1; P2 := A2;
    Exit(EAV3Dist(P1, P2));
  end;
  if A <= EA_EPS_MM then
  begin
    S := 0.0;
    T := EnsureRange(F / E, 0.0, 1.0);
  end
  else
  begin
    C := EAV3Dot(D1, R);
    if E <= EA_EPS_MM then
    begin
      T := 0.0;
      S := EnsureRange(-C / A, 0.0, 1.0);
    end
    else
    begin
      B := EAV3Dot(D1, D2);
      Denom := A * E - B * B;
      SD := Denom; TD := Denom;
      if Abs(Denom) > 1e-12 then
        SN := EnsureRange(B * F - C * E, 0.0, Denom)
      else
        SN := 0.0;
      if Abs(Denom) <= 1e-12 then
      begin
        S := 0.0; SD := 1.0; TN := F; TD := E;
      end
      else
      begin
        TN := B * SN + F * SD;
        TD := E * SD;
      end;
      if TN < 0.0 then
      begin
        TN := 0.0;
        SN := -C;
        SD := A;
      end
      else if TN > TD then
      begin
        TN := TD;
        SN := -C + B;
        SD := A;
      end;
      if Abs(SD) > 1e-12 then S := EnsureRange(SN / SD, 0.0, 1.0) else S := 0.0;
      if Abs(TD) > 1e-12 then T := EnsureRange(TN / TD, 0.0, 1.0) else T := 0.0;
    end;
  end;
  P1 := EAV3Add(A1, EAV3Scale(D1, S));
  P2 := EAV3Add(A2, EAV3Scale(D2, T));
  Result := EAV3Dist(P1, P2);
end;

function EAIntersectSegments2D(const A1, B1, A2, B2: TEAVec2;
  out Hit: TEAVec2; Eps: Double): Boolean;
var
  R, S, Diff: TEAVec2;
  Den, T, U: Double;
begin
  Result := False;
  Hit := EAV2(0, 0);
  R := EAV2Sub(B1, A1);
  S := EAV2Sub(B2, A2);
  Den := EAV2Cross(R, S);
  if Abs(Den) <= 1e-9 then Exit;
  Diff := EAV2Sub(A2, A1);
  T := EAV2Cross(Diff, S) / Den;
  U := EAV2Cross(Diff, R) / Den;
  if (T >= -Eps) and (T <= 1.0 + Eps) and (U >= -Eps) and (U <= 1.0 + Eps) then
  begin
    Hit := EAV2Add(A1, EAV2Scale(R, EnsureRange(T, 0.0, 1.0)));
    Result := True;
  end;
end;

function EAPointToSegmentDist2D(const P, A, B: TEAVec2;
  out Proj: TEAVec2; out T: Double): Double;
var
  AB: TEAVec2;
  L2: Double;
begin
  AB := EAV2Sub(B, A);
  L2 := EAV2Dot(AB, AB);
  if L2 <= 1e-12 then
  begin
    T := 0.0;
    Proj := A;
    Exit(EAV2Dist(P, A));
  end;
  T := EnsureRange(EAV2Dot(EAV2Sub(P, A), AB) / L2, 0.0, 1.0);
  Proj := EAV2Add(A, EAV2Scale(AB, T));
  Result := EAV2Dist(P, Proj);
end;

procedure EAOffsetSegment2D(const A, B: TEAVec2; OffsetMM: Double;
  out OA, OB: TEAVec2);
var
  N: TEAVec2;
begin
  N := EAV2Perp(EAV2Norm(EAV2Sub(B, A)));
  OA := EAV2Add(A, EAV2Scale(N, OffsetMM));
  OB := EAV2Add(B, EAV2Scale(N, OffsetMM));
end;

function EAPolygonSignedAreaMM2(const Poly: TEAVec2Array): Double;
var
  I, J: Integer;
begin
  Result := 0.0;
  if Length(Poly) < 3 then Exit;
  for I := 0 to High(Poly) do
  begin
    J := (I + 1) mod Length(Poly);
    Result := Result + (Poly[I].X * Poly[J].Y - Poly[J].X * Poly[I].Y);
  end;
  Result := 0.5 * Result;
end;

function EAPolygonAreaMM2(const Poly: TEAVec2Array): Double;
begin
  Result := Abs(EAPolygonSignedAreaMM2(Poly));
end;

function EAPolygonPerimeterMM(const Poly: TEAVec2Array): Double;
var
  I, J: Integer;
begin
  Result := 0.0;
  if Length(Poly) < 2 then Exit;
  for I := 0 to High(Poly) do
  begin
    J := (I + 1) mod Length(Poly);
    Result := Result + EAV2Dist(Poly[I], Poly[J]);
  end;
end;

function EAPolygonCentroid(const Poly: TEAVec2Array): TEAVec2;
var
  I, J: Integer;
  A, Cross: Double;
begin
  Result := EAV2(0, 0);
  if Length(Poly) = 0 then Exit;
  A := EAPolygonSignedAreaMM2(Poly);
  if Abs(A) <= EA_EPS_MM then
  begin
    for I := 0 to High(Poly) do Result := EAV2Add(Result, Poly[I]);
    Exit(EAV2Scale(Result, 1.0 / Length(Poly)));
  end;
  for I := 0 to High(Poly) do
  begin
    J := (I + 1) mod Length(Poly);
    Cross := Poly[I].X * Poly[J].Y - Poly[J].X * Poly[I].Y;
    Result.X := Result.X + (Poly[I].X + Poly[J].X) * Cross;
    Result.Y := Result.Y + (Poly[I].Y + Poly[J].Y) * Cross;
  end;
  Result.X := Result.X / (6.0 * A);
  Result.Y := Result.Y / (6.0 * A);
end;

function EAPointInPolygon2D(const P: TEAVec2; const Poly: TEAVec2Array): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  if Length(Poly) < 3 then Exit;
  J := High(Poly);
  for I := 0 to High(Poly) do
  begin
    if ((Poly[I].Y > P.Y) <> (Poly[J].Y > P.Y)) and
       (P.X < (Poly[J].X - Poly[I].X) * (P.Y - Poly[I].Y) / (Poly[J].Y - Poly[I].Y) + Poly[I].X) then
      Result := not Result;
    J := I;
  end;
end;

function EADetectClosedRooms(const Walls: TEASegment2DArray;
  SnapTolMM: Double): TEARoomLoopArray;
type
  TEdge = record
    U, V: Integer;
    Ang: Double;
    Used: Boolean;
  end;
var
  Verts: TEAVec2Array;
  Edges: array of TEdge;
  Adj: array of array of Integer;

  function FindOrAddVertex(const P: TEAVec2): Integer;
  var
    I: Integer;
  begin
    for I := 0 to High(Verts) do
      if EAV2Dist(Verts[I], P) <= SnapTolMM then Exit(I);
    Result := Length(Verts);
    SetLength(Verts, Result + 1);
    Verts[Result] := P;
  end;

  procedure AddHalfEdge(U, V: Integer);
  var
    Idx, K: Integer;
    D: TEAVec2;
  begin
    if U = V then Exit;
    Idx := Length(Edges);
    SetLength(Edges, Idx + 1);
    Edges[Idx].U := U;
    Edges[Idx].V := V;
    D := EAV2Sub(Verts[V], Verts[U]);
    Edges[Idx].Ang := ArcTan2(D.Y, D.X);
    Edges[Idx].Used := False;
    if Length(Adj) < Length(Verts) then SetLength(Adj, Length(Verts));
    K := Length(Adj[U]);
    SetLength(Adj[U], K + 1);
    Adj[U][K] := Idx;
  end;

  function NextCCWEdge(InEdgeIdx: Integer): Integer;
  var
    U, V, I, EIdx, BestIdx: Integer;
    BackAng, Diff, BestDiff: Double;
  begin
    U := Edges[InEdgeIdx].U;
    V := Edges[InEdgeIdx].V;
    BackAng := ArcTan2(Verts[U].Y - Verts[V].Y, Verts[U].X - Verts[V].X);
    BestIdx := -1;
    BestDiff := 1e9;
    for I := 0 to High(Adj[V]) do
    begin
      EIdx := Adj[V][I];
      if Edges[EIdx].V = U then Continue;
      Diff := Edges[EIdx].Ang - BackAng;
      while Diff <= 0 do Diff := Diff + 2 * Pi;
      while Diff > 2 * Pi do Diff := Diff - 2 * Pi;
      if Diff < BestDiff then
      begin
        BestDiff := Diff;
        BestIdx := EIdx;
      end;
    end;
    Result := BestIdx;
  end;

var
  I, J, U, V, Cur, Nxt, Steps, RIdx: Integer;
  Poly: TEAVec2Array;
  SignedA: Double;
begin
  Result := nil;
  Verts := nil;
  Edges := nil;
  Adj := nil;
  if Length(Walls) < 3 then Exit;
  for I := 0 to High(Walls) do
  begin
    U := FindOrAddVertex(Walls[I].A);
    V := FindOrAddVertex(Walls[I].B);
    AddHalfEdge(U, V);
    AddHalfEdge(V, U);
  end;
  if Length(Adj) < Length(Verts) then SetLength(Adj, Length(Verts));

  for I := 0 to High(Edges) do
  begin
    if Edges[I].Used then Continue;
    SetLength(Poly, 0);
    Cur := I;
    Steps := 0;
    while (Cur >= 0) and (not Edges[Cur].Used) and (Steps <= Length(Edges)) do
    begin
      Edges[Cur].Used := True;
      J := Length(Poly);
      SetLength(Poly, J + 1);
      Poly[J] := Verts[Edges[Cur].U];
      Nxt := NextCCWEdge(Cur);
      Inc(Steps);
      if Nxt = I then Break;
      Cur := Nxt;
    end;
    if (Cur >= 0) and (NextCCWEdge(Cur) = I) and (Length(Poly) >= 3) then
    begin
      SignedA := EAPolygonSignedAreaMM2(Poly);
      { Face interna tem orientacao positiva (CCW) ou menor loop fechado }
      if SignedA > 1000.0 then
      begin
        RIdx := Length(Result);
        SetLength(Result, RIdx + 1);
        Result[RIdx].Vertices := Poly;
        Result[RIdx].AreaMM2 := SignedA;
        Result[RIdx].PerimeterMM := EAPolygonPerimeterMM(Poly);
        Result[RIdx].Centroid := EAPolygonCentroid(Poly);
      end;
    end;
  end;
end;

end.
