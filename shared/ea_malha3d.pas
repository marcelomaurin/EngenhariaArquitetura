unit ea_malha3d;

{ Núcleo Comum - Malhas 3D, primitivas, extrusão arquitetônica e interoperabilidade
  STL (ASCII/binário), 3MF, OBJ e GLB/glTF 2.0.
  Implementa etapa N4, I4 e RF3D-045..055 de docs/Nucleo_Comum.md,
  docs/Motor_Importacao.md e docs/Editor_Objetos_3D.md. Independente da LCL. }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, fpjson, jsonparser, zipper, DOM, XMLRead,
  aigltfloader, aiavatartypes,
  ea_geometria, ea_modelo, ea_pacote, ea_fileio;

type
  TEAVertex3D = record
    Pos: TEAVec3;
    Normal: TEAVec3;
    U, V: Double;
  end;

  TEATriangle3D = record
    A, B, C: TEAVertex3D;
    Normal: TEAVec3;
    ColorRGB: LongWord; // $RRGGBB
    MaterialIndex: Integer;
    FaceGroup: Integer;
    TagId: string;
  end;

  TEAMeshMaterial = record
    Id: string;
    Name: string;
    ColorRGB: LongWord;
    Roughness: Double;
    Metallic: Double;
    Opacity: Double;
  end;

  TEAMesh3D = class
  public
    Name: string;
    Triangles: array of TEATriangle3D;
    Materials: array of TEAMeshMaterial;
    constructor Create;
    procedure Clear;
    procedure Assign(Source: TEAMesh3D);
    function AddMaterial(const AId, AName: string; AColorRGB: LongWord;
      ARoughness: Double = 0.7; AMetallic: Double = 0.0; AOpacity: Double = 1.0): Integer;
    procedure AddTri(const P0, P1, P2: TEAVec3; AColorRGB: LongWord;
      AMatIdx: Integer = 0; AFaceGroup: Integer = 0; const ATagId: string = '');
    procedure AddQuad(const P0, P1, P2, P3: TEAVec3; AColorRGB: LongWord;
      AMatIdx: Integer = 0; AFaceGroup: Integer = 0; const ATagId: string = '');
    procedure AddBox(const Center, SizeMM: TEAVec3; AColorRGB: LongWord;
      AMatIdx: Integer = 0; const ATagId: string = '');
    procedure AddCylinder(const BaseCenter: TEAVec3; RadiusMM, HeightMM: Double;
      Segments: Integer; AColorRGB: LongWord; AMatIdx: Integer = 0; const ATagId: string = '');
    procedure AddSphere(const Center: TEAVec3; RadiusMM: Double;
      Slices, Stacks: Integer; AColorRGB: LongWord; AMatIdx: Integer = 0; const ATagId: string = '');
    procedure AddCone(const BaseCenter: TEAVec3; RadiusMM, HeightMM: Double;
      Segments: Integer; AColorRGB: LongWord; AMatIdx: Integer = 0; const ATagId: string = '');
    procedure AddPipeSegment(const P0, P1: TEAVec3; RadiusMM: Double;
      Segments: Integer; AColorRGB: LongWord; AMatIdx: Integer = 0; const ATagId: string = '');
    procedure Transform(const OffsetMM: TEAVec3; Scale: TEAVec3; YawDeg: Double);
    procedure CenterPivotAtBottom;
    procedure GenerateBoxUVs(ScaleMM: Double = 1000.0);
    procedure RepairNormals;
    function Bounds: TEABox3D;
    function TriangleCount: Integer;
    procedure AppendMesh(Other: TEAMesh3D; const OffsetMM: TEAVec3;
      Scale: TEAVec3; YawDeg: Double; OverrideColor: Boolean = False; NewColorRGB: LongWord = $FFFFFF;
      const OverrideTag: string = '');
  end;

procedure EABuildModelMesh(Model: TEAModel; Target: TEAMesh3D;
  const OnlyFloorId: string = ''; WallColor: LongWord = $D9DEE6;
  SlabColor: LongWord = $94A3B8; DoorColor: LongWord = $92400E; WindowColor: LongWord = $38BDF8);

procedure EAExportSTLBinary(Mesh: TEAMesh3D; const FileName: string);
procedure EAExportSTLASCII(Mesh: TEAMesh3D; const FileName: string);
procedure EAImportSTL(const FileName: string; Mesh: TEAMesh3D; UnitScaleMM: Double = 1.0);

procedure EAExportOBJ(Mesh: TEAMesh3D; const FileName: string);
procedure EAImportOBJ(const FileName: string; Mesh: TEAMesh3D; UnitScaleMM: Double = 1.0);

procedure EAImport3MF(const FileName: string; Mesh: TEAMesh3D);

procedure EAExportGLB(Mesh: TEAMesh3D; const FileName: string; out Limitations: string);
procedure EAImportGLB(const FileName: string; Mesh: TEAMesh3D);
procedure EAImportGLTF(const FileName: string; Mesh: TEAMesh3D);

function EAParseHexColorRGB(const Hex: string; Fallback: LongWord = $CCCCCC): LongWord;

implementation

function EAParseHexColorRGB(const Hex: string; Fallback: LongWord): LongWord;
var
  S: string;
  V: LongWord;
begin
  S := Trim(Hex);
  if (Length(S) > 0) and (S[1] = '#') then Delete(S, 1, 1);
  if (Length(S) = 6) and TryStrToDWord('$' + S, V) then
    Result := V and $FFFFFF
  else
    Result := Fallback;
end;

function ComputeTriNormal(const P0, P1, P2: TEAVec3): TEAVec3;
begin
  Result := EAV3Norm(EAV3Cross(EAV3Sub(P1, P0), EAV3Sub(P2, P0)));
end;

constructor TEAMesh3D.Create;
begin
  inherited Create;
  Clear;
end;

procedure TEAMesh3D.Clear;
begin
  Name := 'Objeto3D';
  SetLength(Triangles, 0);
  SetLength(Materials, 0);
end;

procedure TEAMesh3D.Assign(Source: TEAMesh3D);
begin
  if Source = nil then Exit;
  Name := Source.Name;
  Triangles := Copy(Source.Triangles);
  Materials := Copy(Source.Materials);
end;

function TEAMesh3D.AddMaterial(const AId, AName: string; AColorRGB: LongWord;
  ARoughness, AMetallic, AOpacity: Double): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Materials) do
    if Materials[I].Id = AId then Exit(I);
  Result := Length(Materials);
  SetLength(Materials, Result + 1);
  Materials[Result].Id := AId;
  Materials[Result].Name := AName;
  Materials[Result].ColorRGB := AColorRGB and $FFFFFF;
  Materials[Result].Roughness := EnsureRange(ARoughness, 0.0, 1.0);
  Materials[Result].Metallic := EnsureRange(AMetallic, 0.0, 1.0);
  Materials[Result].Opacity := EnsureRange(AOpacity, 0.05, 1.0);
end;

procedure TEAMesh3D.AddTri(const P0, P1, P2: TEAVec3; AColorRGB: LongWord;
  AMatIdx, AFaceGroup: Integer; const ATagId: string);
var
  N: Integer;
  Nor: TEAVec3;
begin
  Nor := ComputeTriNormal(P0, P1, P2);
  N := Length(Triangles);
  SetLength(Triangles, N + 1);
  Triangles[N].A.Pos := P0; Triangles[N].A.Normal := Nor; Triangles[N].A.U := 0; Triangles[N].A.V := 0;
  Triangles[N].B.Pos := P1; Triangles[N].B.Normal := Nor; Triangles[N].B.U := 1; Triangles[N].B.V := 0;
  Triangles[N].C.Pos := P2; Triangles[N].C.Normal := Nor; Triangles[N].C.U := 1; Triangles[N].C.V := 1;
  Triangles[N].Normal := Nor;
  Triangles[N].ColorRGB := AColorRGB and $FFFFFF;
  Triangles[N].MaterialIndex := AMatIdx;
  Triangles[N].FaceGroup := AFaceGroup;
  Triangles[N].TagId := ATagId;
end;

procedure TEAMesh3D.AddQuad(const P0, P1, P2, P3: TEAVec3; AColorRGB: LongWord;
  AMatIdx, AFaceGroup: Integer; const ATagId: string);
var
  N: Integer;
begin
  AddTri(P0, P1, P2, AColorRGB, AMatIdx, AFaceGroup, ATagId);
  N := High(Triangles);
  Triangles[N].A.U := 0; Triangles[N].A.V := 0;
  Triangles[N].B.U := 1; Triangles[N].B.V := 0;
  Triangles[N].C.U := 1; Triangles[N].C.V := 1;
  AddTri(P0, P2, P3, AColorRGB, AMatIdx, AFaceGroup, ATagId);
  N := High(Triangles);
  Triangles[N].A.U := 0; Triangles[N].A.V := 0;
  Triangles[N].B.U := 1; Triangles[N].B.V := 1;
  Triangles[N].C.U := 0; Triangles[N].C.V := 1;
end;

procedure TEAMesh3D.AddBox(const Center, SizeMM: TEAVec3; AColorRGB: LongWord;
  AMatIdx: Integer; const ATagId: string);
var
  HX, HY, HZ: Double;
  V: array[0..7] of TEAVec3;
begin
  HX := SizeMM.X * 0.5;
  HY := SizeMM.Y * 0.5;
  HZ := SizeMM.Z * 0.5;
  V[0] := EAV3(Center.X - HX, Center.Y - HY, Center.Z - HZ);
  V[1] := EAV3(Center.X + HX, Center.Y - HY, Center.Z - HZ);
  V[2] := EAV3(Center.X + HX, Center.Y + HY, Center.Z - HZ);
  V[3] := EAV3(Center.X - HX, Center.Y + HY, Center.Z - HZ);
  V[4] := EAV3(Center.X - HX, Center.Y - HY, Center.Z + HZ);
  V[5] := EAV3(Center.X + HX, Center.Y - HY, Center.Z + HZ);
  V[6] := EAV3(Center.X + HX, Center.Y + HY, Center.Z + HZ);
  V[7] := EAV3(Center.X - HX, Center.Y + HY, Center.Z + HZ);

  AddQuad(V[3], V[2], V[1], V[0], AColorRGB, AMatIdx, 0, ATagId); // base Z-
  AddQuad(V[4], V[5], V[6], V[7], AColorRGB, AMatIdx, 1, ATagId); // topo Z+
  AddQuad(V[0], V[1], V[5], V[4], AColorRGB, AMatIdx, 2, ATagId); // frente Y-
  AddQuad(V[1], V[2], V[6], V[5], AColorRGB, AMatIdx, 3, ATagId); // direita X+
  AddQuad(V[2], V[3], V[7], V[6], AColorRGB, AMatIdx, 4, ATagId); // trás Y+
  AddQuad(V[3], V[0], V[4], V[7], AColorRGB, AMatIdx, 5, ATagId); // esquerda X-
end;

procedure TEAMesh3D.AddCylinder(const BaseCenter: TEAVec3; RadiusMM, HeightMM: Double;
  Segments: Integer; AColorRGB: LongWord; AMatIdx: Integer; const ATagId: string);
var
  I: Integer;
  A0, A1: Double;
  B0, B1, T0, T1, BC, TC: TEAVec3;
begin
  Segments := Max(6, Segments);
  BC := BaseCenter;
  TC := EAV3(BaseCenter.X, BaseCenter.Y, BaseCenter.Z + HeightMM);
  for I := 0 to Segments - 1 do
  begin
    A0 := (2.0 * Pi * I) / Segments;
    A1 := (2.0 * Pi * (I + 1)) / Segments;
    B0 := EAV3(BC.X + RadiusMM * Cos(A0), BC.Y + RadiusMM * Sin(A0), BC.Z);
    B1 := EAV3(BC.X + RadiusMM * Cos(A1), BC.Y + RadiusMM * Sin(A1), BC.Z);
    T0 := EAV3(TC.X + RadiusMM * Cos(A0), TC.Y + RadiusMM * Sin(A0), TC.Z);
    T1 := EAV3(TC.X + RadiusMM * Cos(A1), TC.Y + RadiusMM * Sin(A1), TC.Z);
    AddQuad(B0, B1, T1, T0, AColorRGB, AMatIdx, 0, ATagId);
    AddTri(BC, B1, B0, AColorRGB, AMatIdx, 1, ATagId);
    AddTri(TC, T0, T1, AColorRGB, AMatIdx, 2, ATagId);
  end;
end;

procedure TEAMesh3D.AddSphere(const Center: TEAVec3; RadiusMM: Double;
  Slices, Stacks: Integer; AColorRGB: LongWord; AMatIdx: Integer; const ATagId: string);
var
  I, J: Integer;
  Phi0, Phi1, Theta0, Theta1: Double;
  P00, P10, P11, P01: TEAVec3;
  function SPoint(Phi, Theta: Double): TEAVec3;
  begin
    Result := EAV3(
      Center.X + RadiusMM * Sin(Phi) * Cos(Theta),
      Center.Y + RadiusMM * Sin(Phi) * Sin(Theta),
      Center.Z + RadiusMM * Cos(Phi));
  end;
begin
  Slices := Max(6, Slices);
  Stacks := Max(4, Stacks);
  for I := 0 to Stacks - 1 do
  begin
    Phi0 := Pi * I / Stacks;
    Phi1 := Pi * (I + 1) / Stacks;
    for J := 0 to Slices - 1 do
    begin
      Theta0 := 2.0 * Pi * J / Slices;
      Theta1 := 2.0 * Pi * (J + 1) / Slices;
      P00 := SPoint(Phi0, Theta0);
      P10 := SPoint(Phi1, Theta0);
      P11 := SPoint(Phi1, Theta1);
      P01 := SPoint(Phi0, Theta1);
      if I > 0 then AddTri(P00, P10, P01, AColorRGB, AMatIdx, 0, ATagId);
      if I < Stacks - 1 then AddTri(P10, P11, P01, AColorRGB, AMatIdx, 0, ATagId);
    end;
  end;
end;

procedure TEAMesh3D.AddCone(const BaseCenter: TEAVec3; RadiusMM, HeightMM: Double;
  Segments: Integer; AColorRGB: LongWord; AMatIdx: Integer; const ATagId: string);
var
  I: Integer;
  A0, A1: Double;
  B0, B1, Apex: TEAVec3;
begin
  Segments := Max(6, Segments);
  Apex := EAV3(BaseCenter.X, BaseCenter.Y, BaseCenter.Z + HeightMM);
  for I := 0 to Segments - 1 do
  begin
    A0 := (2.0 * Pi * I) / Segments;
    A1 := (2.0 * Pi * (I + 1)) / Segments;
    B0 := EAV3(BaseCenter.X + RadiusMM * Cos(A0), BaseCenter.Y + RadiusMM * Sin(A0), BaseCenter.Z);
    B1 := EAV3(BaseCenter.X + RadiusMM * Cos(A1), BaseCenter.Y + RadiusMM * Sin(A1), BaseCenter.Z);
    AddTri(B0, B1, Apex, AColorRGB, AMatIdx, 0, ATagId);
    AddTri(BaseCenter, B1, B0, AColorRGB, AMatIdx, 1, ATagId);
  end;
end;

procedure TEAMesh3D.AddPipeSegment(const P0, P1: TEAVec3; RadiusMM: Double;
  Segments: Integer; AColorRGB: LongWord; AMatIdx: Integer; const ATagId: string);
var
  Dir, Up, Side, UAxis, VAxis, A0, A1, B0, B1: TEAVec3;
  I: Integer;
  Ang0, Ang1: Double;
begin
  Dir := EAV3Sub(P1, P0);
  if EAV3Len(Dir) <= EA_EPS_MM then Exit;
  Dir := EAV3Norm(Dir);
  if Abs(Dir.Z) < 0.9 then Up := EAV3(0, 0, 1) else Up := EAV3(1, 0, 0);
  Side := EAV3Norm(EAV3Cross(Dir, Up));
  UAxis := Side;
  VAxis := EAV3Norm(EAV3Cross(Dir, UAxis));
  Segments := Max(6, Segments);
  for I := 0 to Segments - 1 do
  begin
    Ang0 := 2.0 * Pi * I / Segments;
    Ang1 := 2.0 * Pi * (I + 1) / Segments;
    A0 := EAV3Add(P0, EAV3Add(EAV3Scale(UAxis, RadiusMM * Cos(Ang0)), EAV3Scale(VAxis, RadiusMM * Sin(Ang0))));
    A1 := EAV3Add(P0, EAV3Add(EAV3Scale(UAxis, RadiusMM * Cos(Ang1)), EAV3Scale(VAxis, RadiusMM * Sin(Ang1))));
    B0 := EAV3Add(P1, EAV3Add(EAV3Scale(UAxis, RadiusMM * Cos(Ang0)), EAV3Scale(VAxis, RadiusMM * Sin(Ang0))));
    B1 := EAV3Add(P1, EAV3Add(EAV3Scale(UAxis, RadiusMM * Cos(Ang1)), EAV3Scale(VAxis, RadiusMM * Sin(Ang1))));
    AddQuad(A0, A1, B1, B0, AColorRGB, AMatIdx, 0, ATagId);
  end;
end;

procedure TEAMesh3D.Transform(const OffsetMM: TEAVec3; Scale: TEAVec3; YawDeg: Double);
var
  I: Integer;
  Rad, C, S: Double;
  function Xf(const P: TEAVec3): TEAVec3;
  var
    SX, SY, SZ: Double;
  begin
    SX := P.X * Scale.X;
    SY := P.Y * Scale.Y;
    SZ := P.Z * Scale.Z;
    Result.X := OffsetMM.X + SX * C - SY * S;
    Result.Y := OffsetMM.Y + SX * S + SY * C;
    Result.Z := OffsetMM.Z + SZ;
  end;
begin
  Rad := DegToRad(YawDeg);
  C := Cos(Rad);
  S := Sin(Rad);
  for I := 0 to High(Triangles) do
  begin
    Triangles[I].A.Pos := Xf(Triangles[I].A.Pos);
    Triangles[I].B.Pos := Xf(Triangles[I].B.Pos);
    Triangles[I].C.Pos := Xf(Triangles[I].C.Pos);
    Triangles[I].Normal := ComputeTriNormal(Triangles[I].A.Pos, Triangles[I].B.Pos, Triangles[I].C.Pos);
    Triangles[I].A.Normal := Triangles[I].Normal;
    Triangles[I].B.Normal := Triangles[I].Normal;
    Triangles[I].C.Normal := Triangles[I].Normal;
  end;
end;

procedure TEAMesh3D.CenterPivotAtBottom;
var
  B: TEABox3D;
  Ctr: TEAVec3;
begin
  B := Bounds;
  if not B.Valid then Exit;
  Ctr := EABoxCenter(B);
  Transform(EAV3(-Ctr.X, -Ctr.Y, -B.Min.Z), EAV3(1, 1, 1), 0.0);
end;

procedure TEAMesh3D.GenerateBoxUVs(ScaleMM: Double);
var
  I: Integer;
  Nor: TEAVec3;
  procedure ProjectVertex(var V: TEAVertex3D);
  begin
    if (Abs(Nor.Z) >= Abs(Nor.X)) and (Abs(Nor.Z) >= Abs(Nor.Y)) then
    begin
      V.U := V.Pos.X / ScaleMM;
      V.V := V.Pos.Y / ScaleMM;
    end
    else if Abs(Nor.X) >= Abs(Nor.Y) then
    begin
      V.U := V.Pos.Y / ScaleMM;
      V.V := V.Pos.Z / ScaleMM;
    end
    else
    begin
      V.U := V.Pos.X / ScaleMM;
      V.V := V.Pos.Z / ScaleMM;
    end;
  end;
begin
  if ScaleMM <= 1.0 then ScaleMM := 1000.0;
  for I := 0 to High(Triangles) do
  begin
    Nor := Triangles[I].Normal;
    ProjectVertex(Triangles[I].A);
    ProjectVertex(Triangles[I].B);
    ProjectVertex(Triangles[I].C);
  end;
end;

procedure TEAMesh3D.RepairNormals;
var
  I: Integer;
  Nor: TEAVec3;
begin
  for I := 0 to High(Triangles) do
  begin
    Nor := ComputeTriNormal(Triangles[I].A.Pos, Triangles[I].B.Pos, Triangles[I].C.Pos);
    Triangles[I].Normal := Nor;
    Triangles[I].A.Normal := Nor;
    Triangles[I].B.Normal := Nor;
    Triangles[I].C.Normal := Nor;
  end;
end;

function TEAMesh3D.Bounds: TEABox3D;
var
  I: Integer;
begin
  Result := EAEmptyBox3D;
  for I := 0 to High(Triangles) do
  begin
    EAExpandBox3D(Result, Triangles[I].A.Pos);
    EAExpandBox3D(Result, Triangles[I].B.Pos);
    EAExpandBox3D(Result, Triangles[I].C.Pos);
  end;
end;

function TEAMesh3D.TriangleCount: Integer;
begin
  Result := Length(Triangles);
end;

procedure TEAMesh3D.AppendMesh(Other: TEAMesh3D; const OffsetMM: TEAVec3;
  Scale: TEAVec3; YawDeg: Double; OverrideColor: Boolean; NewColorRGB: LongWord; const OverrideTag: string);
var
  I, BaseLen: Integer;
  Rad, C, S: Double;
  function Xf(const P: TEAVec3): TEAVec3;
  var
    SX, SY, SZ: Double;
  begin
    SX := P.X * Scale.X;
    SY := P.Y * Scale.Y;
    SZ := P.Z * Scale.Z;
    Result.X := OffsetMM.X + SX * C - SY * S;
    Result.Y := OffsetMM.Y + SX * S + SY * C;
    Result.Z := OffsetMM.Z + SZ;
  end;
begin
  if (Other = nil) or (Length(Other.Triangles) = 0) then Exit;
  Rad := DegToRad(YawDeg);
  C := Cos(Rad);
  S := Sin(Rad);
  BaseLen := Length(Triangles);
  SetLength(Triangles, BaseLen + Length(Other.Triangles));
  for I := 0 to High(Other.Triangles) do
  begin
    Triangles[BaseLen + I] := Other.Triangles[I];
    Triangles[BaseLen + I].A.Pos := Xf(Other.Triangles[I].A.Pos);
    Triangles[BaseLen + I].B.Pos := Xf(Other.Triangles[I].B.Pos);
    Triangles[BaseLen + I].C.Pos := Xf(Other.Triangles[I].C.Pos);
    Triangles[BaseLen + I].Normal := ComputeTriNormal(
      Triangles[BaseLen + I].A.Pos, Triangles[BaseLen + I].B.Pos, Triangles[BaseLen + I].C.Pos);
    Triangles[BaseLen + I].A.Normal := Triangles[BaseLen + I].Normal;
    Triangles[BaseLen + I].B.Normal := Triangles[BaseLen + I].Normal;
    Triangles[BaseLen + I].C.Normal := Triangles[BaseLen + I].Normal;
    if OverrideColor then Triangles[BaseLen + I].ColorRGB := NewColorRGB and $FFFFFF;
    if OverrideTag <> '' then Triangles[BaseLen + I].TagId := OverrideTag;
  end;
end;

procedure AddWallSpanBox(Target: TEAMesh3D; const Start2, Dir2, Nor2: TEAVec2;
  S0, S1, HalfThick, Z0, Z1: Double; ColorRGB: LongWord; MatIdx: Integer; const TagId: string);
var
  P0, P1, B0, B1, B2, B3, T0, T1, T2, T3: TEAVec3;
  A2, E2: TEAVec2;
begin
  if (S1 - S0 <= 1.0) or (Z1 - Z0 <= 1.0) then Exit;
  A2 := EAV2Add(Start2, EAV2Scale(Dir2, S0));
  E2 := EAV2Add(Start2, EAV2Scale(Dir2, S1));
  P0 := EAV3(A2.X, A2.Y, Z0);
  P1 := EAV3(E2.X, E2.Y, Z0);
  B0 := EAV3(P0.X - Nor2.X * HalfThick, P0.Y - Nor2.Y * HalfThick, Z0);
  B1 := EAV3(P1.X - Nor2.X * HalfThick, P1.Y - Nor2.Y * HalfThick, Z0);
  B2 := EAV3(P1.X + Nor2.X * HalfThick, P1.Y + Nor2.Y * HalfThick, Z0);
  B3 := EAV3(P0.X + Nor2.X * HalfThick, P0.Y + Nor2.Y * HalfThick, Z0);
  T0 := EAV3(B0.X, B0.Y, Z1);
  T1 := EAV3(B1.X, B1.Y, Z1);
  T2 := EAV3(B2.X, B2.Y, Z1);
  T3 := EAV3(B3.X, B3.Y, Z1);
  Target.AddQuad(B3, B2, B1, B0, ColorRGB, MatIdx, 0, TagId);
  Target.AddQuad(T0, T1, T2, T3, ColorRGB, MatIdx, 1, TagId);
  Target.AddQuad(B0, B1, T1, T0, ColorRGB, MatIdx, 2, TagId);
  Target.AddQuad(B1, B2, T2, T1, ColorRGB, MatIdx, 3, TagId);
  Target.AddQuad(B2, B3, T3, T2, ColorRGB, MatIdx, 4, TagId);
  Target.AddQuad(B3, B0, T0, T3, ColorRGB, MatIdx, 5, TagId);
end;

procedure EABuildModelMesh(Model: TEAModel; Target: TEAMesh3D;
  const OnlyFloorId: string; WallColor, SlabColor, DoorColor, WindowColor: LongWord);
type
  TOpenInterval = record
    Idx: Integer;
    S0, S1: Double;
  end;
var
  I, J, K, FIdx, MatWall, MatSlab, MatDoor, MatWin: Integer;
  W: TEAWall;
  Len, HalfT, ZFloor, ZTop, CurS: Double;
  Dir, Nor: TEAVec2;
  Intervals: array of TOpenInterval;
  Tmp: TOpenInterval;
  FloorOffX, FloorOffY, ZSlab0, ZSlab1: Double;
  S0, S1: TEAVec2;
  StepI: Integer;
  StepStart, StepEnd: TEAVec2;
  StepZ0, StepZ1, StepLen: Double;
  Box: TEABox3D;
begin
  if (Model = nil) or (Target = nil) then Exit;
  Target.Clear;
  MatWall := Target.AddMaterial('mat_parede_padrao', 'Alvenaria', WallColor, 0.85, 0.0, 1.0);
  MatSlab := Target.AddMaterial('mat_piso_padrao', 'Laje/Piso', SlabColor, 0.80, 0.0, 1.0);
  MatDoor := Target.AddMaterial('mat_porta', 'Porta Madeira', DoorColor, 0.55, 0.0, 1.0);
  MatWin := Target.AddMaterial('mat_janela', 'Vidro/Caixilho', WindowColor, 0.15, 0.1, 0.55);

  { Lajes }
  for I := 0 to High(Model.Slabs) do
  begin
    if (OnlyFloorId <> '') and (Model.Slabs[I].FloorId <> OnlyFloorId) then Continue;
    FIdx := Model.FindFloor(Model.Slabs[I].FloorId);
    if FIdx >= 0 then ZFloor := Model.Floors[FIdx].ElevationMM else ZFloor := 0.0;
    ZSlab1 := ZFloor + Model.Slabs[I].ElevationOffsetMM;
    ZSlab0 := ZSlab1 - Model.Slabs[I].ThicknessMM;
    if Length(Model.Slabs[I].Polygon) >= 3 then
    begin
      Box := EAEmptyBox3D;
      for J := 0 to High(Model.Slabs[I].Polygon) do
        EAExpandBox3D(Box, EAV3(Model.Slabs[I].Polygon[J].X, Model.Slabs[I].Polygon[J].Y, ZSlab0));
      Target.AddBox(
        EAV3((Box.Min.X + Box.Max.X) * 0.5, (Box.Min.Y + Box.Max.Y) * 0.5, (ZSlab0 + ZSlab1) * 0.5),
        EAV3(Box.Max.X - Box.Min.X, Box.Max.Y - Box.Min.Y, Model.Slabs[I].ThicknessMM),
        SlabColor, MatSlab, Model.Slabs[I].Id);
    end;
  end;

  { Paredes com recortes de portas e janelas }
  for I := 0 to High(Model.Walls) do
  begin
    W := Model.Walls[I];
    if (OnlyFloorId <> '') and (W.FloorId <> OnlyFloorId) then Continue;
    FIdx := Model.FindFloor(W.FloorId);
    if FIdx >= 0 then
    begin
      ZFloor := Model.Floors[FIdx].ElevationMM;
      FloorOffX := Model.Floors[FIdx].OffsetXMM;
      FloorOffY := Model.Floors[FIdx].OffsetYMM;
    end
    else
    begin
      ZFloor := 0.0; FloorOffX := 0.0; FloorOffY := 0.0;
    end;
    S0 := EAV2(W.StartMM.X + FloorOffX, W.StartMM.Y + FloorOffY);
    S1 := EAV2(W.EndMM.X + FloorOffX, W.EndMM.Y + FloorOffY);
    Len := EAV2Dist(S0, S1);
    if Len <= 1.0 then Continue;
    Dir := EAV2Scale(EAV2Sub(S1, S0), 1.0 / Len);
    Nor := EAV2Perp(Dir);
    HalfT := Max(10.0, W.ThicknessMM * 0.5);
    ZTop := ZFloor + W.HeightMM;

    SetLength(Intervals, 0);
    for J := 0 to High(Model.Openings) do
    begin
      if Model.Openings[J].WallId <> W.Id then Continue;
      K := Length(Intervals);
      SetLength(Intervals, K + 1);
      Intervals[K].Idx := J;
      Intervals[K].S0 := EnsureRange(Model.Openings[J].OffsetAlongMM, 0.0, Len);
      Intervals[K].S1 := EnsureRange(Model.Openings[J].OffsetAlongMM + Model.Openings[J].WidthMM, 0.0, Len);
    end;
    for J := 0 to High(Intervals) - 1 do
      for K := J + 1 to High(Intervals) do
        if Intervals[K].S0 < Intervals[J].S0 then
        begin
          Tmp := Intervals[J]; Intervals[J] := Intervals[K]; Intervals[K] := Tmp;
        end;

    CurS := 0.0;
    for J := 0 to High(Intervals) do
    begin
      if Intervals[J].S0 > CurS + 1.0 then
        AddWallSpanBox(Target, S0, Dir, Nor, CurS, Intervals[J].S0, HalfT, ZFloor, ZTop, WallColor, MatWall, W.Id);
      K := Intervals[J].Idx;
      { Peitoril abaixo da abertura }
      if Model.Openings[K].SillMM > 1.0 then
        AddWallSpanBox(Target, S0, Dir, Nor, Intervals[J].S0, Intervals[J].S1, HalfT,
          ZFloor, Min(ZTop, ZFloor + Model.Openings[K].SillMM), WallColor, MatWall, W.Id);
      { Verga acima da abertura }
      if ZFloor + Model.Openings[K].SillMM + Model.Openings[K].HeightMM < ZTop - 1.0 then
        AddWallSpanBox(Target, S0, Dir, Nor, Intervals[J].S0, Intervals[J].S1, HalfT,
          ZFloor + Model.Openings[K].SillMM + Model.Openings[K].HeightMM, ZTop, WallColor, MatWall, W.Id);
      { Folha visual da porta ou vidro da janela }
      if Model.Openings[K].Kind = eokDoor then
        AddWallSpanBox(Target, S0, Dir, Nor, Intervals[J].S0, Intervals[J].S0 + 45.0,
          Model.Openings[K].WidthMM * 0.5, ZFloor + Model.Openings[K].SillMM,
          Min(ZTop, ZFloor + Model.Openings[K].SillMM + Model.Openings[K].HeightMM),
          DoorColor, MatDoor, Model.Openings[K].Id)
      else if Model.Openings[K].Kind = eokWindow then
        AddWallSpanBox(Target, S0, Dir, Nor, Intervals[J].S0, Intervals[J].S1,
          20.0, ZFloor + Model.Openings[K].SillMM,
          Min(ZTop, ZFloor + Model.Openings[K].SillMM + Model.Openings[K].HeightMM),
          WindowColor, MatWin, Model.Openings[K].Id);
      CurS := Max(CurS, Intervals[J].S1);
    end;
    if CurS < Len - 1.0 then
      AddWallSpanBox(Target, S0, Dir, Nor, CurS, Len, HalfT, ZFloor, ZTop, WallColor, MatWall, W.Id);
  end;

  { Escadas }
  for I := 0 to High(Model.Stairs) do
  begin
    if (OnlyFloorId <> '') and (Model.Stairs[I].FromFloorId <> OnlyFloorId) then Continue;
    FIdx := Model.FindFloor(Model.Stairs[I].FromFloorId);
    if FIdx >= 0 then ZFloor := Model.Floors[FIdx].ElevationMM else ZFloor := 0.0;
    J := Model.FindFloor(Model.Stairs[I].ToFloorId);
    if J >= 0 then ZTop := Model.Floors[J].ElevationMM else ZTop := ZFloor + 3000.0;
    StepLen := EAV2Dist(Model.Stairs[I].StartMM, Model.Stairs[I].EndMM);
    if StepLen <= 10.0 then Continue;
    Dir := EAV2Scale(EAV2Sub(Model.Stairs[I].EndMM, Model.Stairs[I].StartMM), 1.0 / StepLen);
    Nor := EAV2Perp(Dir);
    for StepI := 0 to Model.Stairs[I].StepCount - 1 do
    begin
      StepStart := EAV2Add(Model.Stairs[I].StartMM, EAV2Scale(Dir, StepLen * StepI / Model.Stairs[I].StepCount));
      StepEnd := EAV2Add(Model.Stairs[I].StartMM, EAV2Scale(Dir, StepLen * (StepI + 1) / Model.Stairs[I].StepCount));
      StepZ0 := ZFloor + (ZTop - ZFloor) * StepI / Model.Stairs[I].StepCount;
      StepZ1 := ZFloor + (ZTop - ZFloor) * (StepI + 1) / Model.Stairs[I].StepCount;
      AddWallSpanBox(Target, StepStart, Dir, Nor, 0, EAV2Dist(StepStart, StepEnd),
        Model.Stairs[I].WidthMM * 0.5, StepZ0, StepZ1, SlabColor, MatSlab, Model.Stairs[I].Id);
    end;
  end;
  Target.GenerateBoxUVs(1000.0);
end;

procedure EAExportSTLBinary(Mesh: TEAMesh3D; const FileName: string);
var
  MS: TMemoryStream;
  Header: array[0..79] of Byte;
  Count, Attr: LongWord;
  I: Integer;
  F: Single;
  procedure WriteVec3(const V: TEAVec3);
  begin
    F := V.X; MS.WriteBuffer(F, 4);
    F := V.Y; MS.WriteBuffer(F, 4);
    F := V.Z; MS.WriteBuffer(F, 4);
  end;
var
  Attr16: Word;
begin
  MS := TMemoryStream.Create;
  try
    FillChar(Header, SizeOf(Header), 0);
    Move('EngenhariaArquitetura STL Binary', Header[0], 33);
    MS.WriteBuffer(Header, 80);
    Count := Length(Mesh.Triangles);
    MS.WriteBuffer(Count, 4);
    Attr16 := 0;
    for I := 0 to High(Mesh.Triangles) do
    begin
      WriteVec3(Mesh.Triangles[I].Normal);
      WriteVec3(Mesh.Triangles[I].A.Pos);
      WriteVec3(Mesh.Triangles[I].B.Pos);
      WriteVec3(Mesh.Triangles[I].C.Pos);
      Attr := Attr16;
      MS.WriteBuffer(Attr, 2);
    end;
    MS.SaveToFile(FileName);
  finally
    MS.Free;
  end;
end;

procedure EAExportSTLASCII(Mesh: TEAMesh3D; const FileName: string);
var
  SL: TStringList;
  FS: TFormatSettings;
  I: Integer;
  function FmtV(const V: TEAVec3): string;
  begin
    Result := Format('%.6f %.6f %.6f', [V.X, V.Y, V.Z], FS);
  end;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  SL := TStringList.Create;
  try
    SL.Add('solid ' + Mesh.Name);
    for I := 0 to High(Mesh.Triangles) do
    begin
      SL.Add('  facet normal ' + FmtV(Mesh.Triangles[I].Normal));
      SL.Add('    outer loop');
      SL.Add('      vertex ' + FmtV(Mesh.Triangles[I].A.Pos));
      SL.Add('      vertex ' + FmtV(Mesh.Triangles[I].B.Pos));
      SL.Add('      vertex ' + FmtV(Mesh.Triangles[I].C.Pos));
      SL.Add('    endloop');
      SL.Add('  endfacet');
    end;
    SL.Add('endsolid ' + Mesh.Name);
    EAAtomicWriteText(FileName, SL.Text);
  finally
    SL.Free;
  end;
end;

procedure EAImportSTL(const FileName: string; Mesh: TEAMesh3D; UnitScaleMM: Double);
var
  Stream: TFileStream;
  Header: array[0..79] of Byte;
  TriCount: LongWord;
  ExpectedSize: Int64;
  IsBinary: Boolean;
  I: Integer;
  FN, V0, V1, V2: array[0..2] of Single;
  Attr: Word;
  SL: TStringList;
  Line, Tok: string;
  Verts: array[0..2] of TEAVec3;
  VIdx: Integer;
  FS: TFormatSettings;
  Parts: TStringList;
begin
  EACheckSupportedExternalFile(FileName);
  if not FileExists(FileName) then
    raise EEAPackageError.CreateFmt('STL não encontrado: %s', [FileName]);
  Mesh.Clear;
  Mesh.Name := ChangeFileExt(ExtractFileName(FileName), '');
  Mesh.AddMaterial('mat_stl', 'STL Padrão', $CBD5E1, 0.7, 0.0, 1.0);
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    if Stream.Size < 15 then raise EEAPackageError.Create('Arquivo STL inválido ou vazio');
    IsBinary := False;
    if Stream.Size >= 84 then
    begin
      Stream.ReadBuffer(Header, 80);
      Stream.ReadBuffer(TriCount, 4);
      ExpectedSize := 84 + Int64(TriCount) * 50;
      if ExpectedSize = Stream.Size then IsBinary := True;
    end;

    if IsBinary then
    begin
      if TriCount > 2000000 then raise EEAPackageError.Create('STL excede o limite de 2 milhões de triângulos');
      for I := 0 to Integer(TriCount) - 1 do
      begin
        Stream.ReadBuffer(FN, 12);
        Stream.ReadBuffer(V0, 12);
        Stream.ReadBuffer(V1, 12);
        Stream.ReadBuffer(V2, 12);
        Stream.ReadBuffer(Attr, 2);
        Mesh.AddTri(
          EAV3(V0[0] * UnitScaleMM, V0[1] * UnitScaleMM, V0[2] * UnitScaleMM),
          EAV3(V1[0] * UnitScaleMM, V1[1] * UnitScaleMM, V1[2] * UnitScaleMM),
          EAV3(V2[0] * UnitScaleMM, V2[1] * UnitScaleMM, V2[2] * UnitScaleMM),
          $CBD5E1, 0, 0, Mesh.Name);
      end;
      Exit;
    end;
  finally
    Stream.Free;
  end;

  { Fallback ASCII STL }
  SL := TStringList.Create;
  Parts := TStringList.Create;
  try
    SL.LoadFromFile(FileName);
    Parts.Delimiter := ' ';
    VIdx := 0;
    for I := 0 to SL.Count - 1 do
    begin
      Line := Trim(SL[I]);
      if Line = '' then Continue;
      if Pos('vertex', LowerCase(Line)) = 1 then
      begin
        Parts.DelimitedText := Line;
        if Parts.Count >= 4 then
        begin
          Verts[VIdx] := EAV3(
            StrToFloatDef(Parts[1], 0.0, FS) * UnitScaleMM,
            StrToFloatDef(Parts[2], 0.0, FS) * UnitScaleMM,
            StrToFloatDef(Parts[3], 0.0, FS) * UnitScaleMM);
          Inc(VIdx);
          if VIdx = 3 then
          begin
            Mesh.AddTri(Verts[0], Verts[1], Verts[2], $CBD5E1, 0, 0, Mesh.Name);
            VIdx := 0;
          end;
        end;
      end;
    end;
  finally
    Parts.Free;
    SL.Free;
  end;
  if Mesh.TriangleCount = 0 then
    raise EEAPackageError.Create('Nenhum triângulo válido encontrado no arquivo STL');
end;

procedure EAExportOBJ(Mesh: TEAMesh3D; const FileName: string);
var
  SL: TStringList;
  FS: TFormatSettings;
  I, BaseIdx: Integer;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  SL := TStringList.Create;
  try
    SL.Add('# EngenhariaArquitetura OBJ (units: mm)');
    SL.Add('o ' + Mesh.Name);
    for I := 0 to High(Mesh.Triangles) do
    begin
      with Mesh.Triangles[I] do
      begin
        SL.Add(Format('v %.4f %.4f %.4f', [A.Pos.X, A.Pos.Y, A.Pos.Z], FS));
        SL.Add(Format('v %.4f %.4f %.4f', [B.Pos.X, B.Pos.Y, B.Pos.Z], FS));
        SL.Add(Format('v %.4f %.4f %.4f', [C.Pos.X, C.Pos.Y, C.Pos.Z], FS));
        SL.Add(Format('vt %.4f %.4f', [A.U, A.V], FS));
        SL.Add(Format('vt %.4f %.4f', [B.U, B.V], FS));
        SL.Add(Format('vt %.4f %.4f', [C.U, C.V], FS));
      end;
    end;
    for I := 0 to High(Mesh.Triangles) do
    begin
      BaseIdx := I * 3 + 1;
      SL.Add(Format('f %d/%d %d/%d %d/%d', [BaseIdx, BaseIdx, BaseIdx + 1, BaseIdx + 1, BaseIdx + 2, BaseIdx + 2]));
    end;
    EAAtomicWriteText(FileName, SL.Text);
  finally
    SL.Free;
  end;
end;

procedure EAImportOBJ(const FileName: string; Mesh: TEAMesh3D; UnitScaleMM: Double);
var
  SL, Parts: TStringList;
  Verts: array of TEAVec3;
  I, J, K, VIdx: Integer;
  Line, Tok: string;
  FS: TFormatSettings;
  FaceIdx: array of Integer;
  function ParseVertIdx(const S: string): Integer;
  var
    P: Integer;
    NumStr: string;
  begin
    P := Pos('/', S);
    if P > 0 then NumStr := Copy(S, 1, P - 1) else NumStr := S;
    Result := StrToIntDef(NumStr, 0);
    if Result < 0 then Result := Length(Verts) + Result + 1;
  end;
begin
  EACheckSupportedExternalFile(FileName);
  if not FileExists(FileName) then
    raise EEAPackageError.CreateFmt('OBJ não encontrado: %s', [FileName]);
  Mesh.Clear;
  Mesh.Name := ChangeFileExt(ExtractFileName(FileName), '');
  Mesh.AddMaterial('mat_obj', 'OBJ Padrão', $CBD5E1, 0.7, 0.0, 1.0);
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  SL := TStringList.Create;
  Parts := TStringList.Create;
  try
    SL.LoadFromFile(FileName);
    Parts.Delimiter := ' ';
    for I := 0 to SL.Count - 1 do
    begin
      Line := Trim(SL[I]);
      if (Line = '') or (Line[1] = '#') then Continue;
      Parts.DelimitedText := Line;
      if Parts.Count = 0 then Continue;
      Tok := LowerCase(Parts[0]);
      if (Tok = 'v') and (Parts.Count >= 4) then
      begin
        VIdx := Length(Verts);
        SetLength(Verts, VIdx + 1);
        Verts[VIdx] := EAV3(
          StrToFloatDef(Parts[1], 0.0, FS) * UnitScaleMM,
          StrToFloatDef(Parts[2], 0.0, FS) * UnitScaleMM,
          StrToFloatDef(Parts[3], 0.0, FS) * UnitScaleMM);
      end
      else if (Tok = 'f') and (Parts.Count >= 4) then
      begin
        SetLength(FaceIdx, 0);
        for J := 1 to Parts.Count - 1 do
        begin
          if Trim(Parts[J]) = '' then Continue;
          K := ParseVertIdx(Parts[J]) - 1;
          if (K >= 0) and (K < Length(Verts)) then
          begin
            VIdx := Length(FaceIdx);
            SetLength(FaceIdx, VIdx + 1);
            FaceIdx[VIdx] := K;
          end;
        end;
        for J := 1 to Length(FaceIdx) - 2 do
          Mesh.AddTri(Verts[FaceIdx[0]], Verts[FaceIdx[J]], Verts[FaceIdx[J + 1]], $CBD5E1, 0, 0, Mesh.Name);
      end;
    end;
  finally
    Parts.Free;
    SL.Free;
  end;
  if Mesh.TriangleCount = 0 then
    raise EEAPackageError.Create('Nenhum polígono válido encontrado no arquivo OBJ');
end;

type
  T3MFHandler = class
  public
    TempDir: string;
    ModelPath: string;
    procedure OnCreateStream(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
    procedure OnDoneStream(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
  end;

procedure T3MFHandler.OnCreateStream(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
begin
  if LowerCase(ExtractFileExt(AItem.ArchiveFileName)) = '.model' then
    AStream := TMemoryStream.Create
  else
    AStream := TMemoryStream.Create;
end;

procedure T3MFHandler.OnDoneStream(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
var
  OutPath: string;
begin
  if LowerCase(ExtractFileExt(AItem.ArchiveFileName)) = '.model' then
  begin
    OutPath := IncludeTrailingPathDelimiter(TempDir) + 'model.xml';
    TMemoryStream(AStream).SaveToFile(OutPath);
    ModelPath := OutPath;
  end;
  AStream.Free;
  AStream := nil;
end;

procedure EAImport3MF(const FileName: string; Mesh: TEAMesh3D);
var
  Unzip: TUnZipper;
  Handler: T3MFHandler;
  G: TGUID;
  Doc: TXMLDocument;
  Root, Node, MeshNode, VertsNode, TrisNode, Child: TDOMNode;
  UnitStr: string;
  ScaleMM: Double;
  Verts: array of TEAVec3;
  VIdx, I0, I1, I2: Integer;
  FS: TFormatSettings;
  Attr: TDOMNode;
begin
  EACheckSupportedExternalFile(FileName);
  if not FileExists(FileName) then
    raise EEAPackageError.CreateFmt('Arquivo 3MF não encontrado: %s', [FileName]);
  Mesh.Clear;
  Mesh.Name := ChangeFileExt(ExtractFileName(FileName), '');
  Mesh.AddMaterial('mat_3mf', '3MF Padrão', $CBD5E1, 0.7, 0.0, 1.0);
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

  CreateGUID(G);
  Handler := T3MFHandler.Create;
  Handler.TempDir := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'ea-3mf-' + GUIDToString(G);
  ForceDirectories(Handler.TempDir);
  Unzip := TUnZipper.Create;
  try
    Unzip.FileName := FileName;
    Unzip.OnCreateStream := @Handler.OnCreateStream;
    Unzip.OnDoneStream := @Handler.OnDoneStream;
    Unzip.UnZipAllFiles;
    if (Handler.ModelPath = '') or (not FileExists(Handler.ModelPath)) then
      raise EEAPackageError.Create('Arquivo 3MF não contém 3D/3dmodel.model');

    ReadXMLFile(Doc, Handler.ModelPath);
    try
      Root := Doc.DocumentElement;
      ScaleMM := 1.0;
      Attr := Root.Attributes.GetNamedItem('unit');
      if Attr <> nil then
      begin
        UnitStr := LowerCase(UTF8Encode(Attr.NodeValue));
        if UnitStr = 'meter' then ScaleMM := 1000.0
        else if UnitStr = 'centimeter' then ScaleMM := 10.0
        else if UnitStr = 'inch' then ScaleMM := 25.4
        else if UnitStr = 'foot' then ScaleMM := 304.8;
      end;

      Node := Root.FirstChild;
      while Node <> nil do
      begin
        if LowerCase(UTF8Encode(Node.NodeName)) = 'resources' then
        begin
          Child := Node.FirstChild;
          while Child <> nil do
          begin
            if LowerCase(UTF8Encode(Child.NodeName)) = 'object' then
            begin
              MeshNode := Child.FirstChild;
              while MeshNode <> nil do
              begin
                if LowerCase(UTF8Encode(MeshNode.NodeName)) = 'mesh' then
                begin
                  SetLength(Verts, 0);
                  VertsNode := MeshNode.FirstChild;
                  while VertsNode <> nil do
                  begin
                    if LowerCase(UTF8Encode(VertsNode.NodeName)) = 'vertices' then
                    begin
                      TrisNode := VertsNode.FirstChild;
                      while TrisNode <> nil do
                      begin
                        if LowerCase(UTF8Encode(TrisNode.NodeName)) = 'vertex' then
                        begin
                          VIdx := Length(Verts);
                          SetLength(Verts, VIdx + 1);
                          Verts[VIdx] := EAV3(
                            StrToFloatDef(UTF8Encode(TDOMElement(TrisNode).GetAttribute('x')), 0.0, FS) * ScaleMM,
                            StrToFloatDef(UTF8Encode(TDOMElement(TrisNode).GetAttribute('y')), 0.0, FS) * ScaleMM,
                            StrToFloatDef(UTF8Encode(TDOMElement(TrisNode).GetAttribute('z')), 0.0, FS) * ScaleMM);
                        end;
                        TrisNode := TrisNode.NextSibling;
                      end;
                    end
                    else if LowerCase(UTF8Encode(VertsNode.NodeName)) = 'triangles' then
                    begin
                      TrisNode := VertsNode.FirstChild;
                      while TrisNode <> nil do
                      begin
                        if LowerCase(UTF8Encode(TrisNode.NodeName)) = 'triangle' then
                        begin
                          I0 := StrToIntDef(UTF8Encode(TDOMElement(TrisNode).GetAttribute('v1')), -1);
                          I1 := StrToIntDef(UTF8Encode(TDOMElement(TrisNode).GetAttribute('v2')), -1);
                          I2 := StrToIntDef(UTF8Encode(TDOMElement(TrisNode).GetAttribute('v3')), -1);
                          if (I0 >= 0) and (I1 >= 0) and (I2 >= 0) and
                             (I0 < Length(Verts)) and (I1 < Length(Verts)) and (I2 < Length(Verts)) then
                            Mesh.AddTri(Verts[I0], Verts[I1], Verts[I2], $CBD5E1, 0, 0, Mesh.Name);
                        end;
                        TrisNode := TrisNode.NextSibling;
                      end;
                    end;
                    VertsNode := VertsNode.NextSibling;
                  end;
                end;
                MeshNode := MeshNode.NextSibling;
              end;
            end;
            Child := Child.NextSibling;
          end;
        end;
        Node := Node.NextSibling;
      end;
    finally
      Doc.Free;
    end;
  finally
    Unzip.Free;
    if (Handler.ModelPath <> '') and FileExists(Handler.ModelPath) then DeleteFile(Handler.ModelPath);
    if DirectoryExists(Handler.TempDir) then RemoveDir(Handler.TempDir);
    Handler.Free;
  end;
  if Mesh.TriangleCount = 0 then
    raise EEAPackageError.Create('Nenhum triângulo encontrado no arquivo 3MF');
end;

procedure EAExportGLB(Mesh: TEAMesh3D; const FileName: string; out Limitations: string);
var
  BinStream, OutStream: TMemoryStream;
  I, VCount, MatIdx: Integer;
  PosByteLen, NorByteLen, UVByteLen, TotalBinLen, JsonLen, JsonPad, BinPad, TotalLen: LongWord;
  B: TEABox3D;
  F: Single;
  Root, Asset, SceneObj, NodeObj, MeshObj, PrimObj, MatObj, PbrObj: TJSONObject;
  Arr, ScenesArr, NodesArr, MeshesArr, PrimsArr, BuffersArr, ViewsArr, AccArr, MatsArr, ColArr, MinArr, MaxArr: TJSONArray;
  JsonStr: RawByteString;
  PadByte: Byte;
  Magic, Version, ChunkType: LongWord;
  RCol, GCol, BCol: Double;
  procedure WriteF3(const V: TEAVec3);
  begin
    { glTF usa metros e Y-up; convertemos de mm Z-up (X, Z, -Y)/1000 }
    F := V.X / 1000.0; BinStream.WriteBuffer(F, 4);
    F := V.Z / 1000.0; BinStream.WriteBuffer(F, 4);
    F := -V.Y / 1000.0; BinStream.WriteBuffer(F, 4);
  end;
  procedure WriteF2(U, V: Double);
  begin
    F := U; BinStream.WriteBuffer(F, 4);
    F := V; BinStream.WriteBuffer(F, 4);
  end;
begin
  Limitations := '';
  if Mesh.TriangleCount = 0 then
    raise EEAPackageError.Create('Malha vazia não pode ser exportada para GLB');
  if Length(Mesh.Materials) = 0 then
    Mesh.AddMaterial('mat_default', 'Material Padrão', $CCCCCC, 0.7, 0.0, 1.0);

  BinStream := TMemoryStream.Create;
  try
    VCount := Mesh.TriangleCount * 3;
    for I := 0 to High(Mesh.Triangles) do
    begin
      WriteF3(Mesh.Triangles[I].A.Pos);
      WriteF3(Mesh.Triangles[I].B.Pos);
      WriteF3(Mesh.Triangles[I].C.Pos);
    end;
    PosByteLen := LongWord(VCount) * 12;

    for I := 0 to High(Mesh.Triangles) do
    begin
      WriteF3(Mesh.Triangles[I].A.Normal);
      WriteF3(Mesh.Triangles[I].B.Normal);
      WriteF3(Mesh.Triangles[I].C.Normal);
    end;
    NorByteLen := LongWord(VCount) * 12;

    for I := 0 to High(Mesh.Triangles) do
    begin
      WriteF2(Mesh.Triangles[I].A.U, Mesh.Triangles[I].A.V);
      WriteF2(Mesh.Triangles[I].B.U, Mesh.Triangles[I].B.V);
      WriteF2(Mesh.Triangles[I].C.U, Mesh.Triangles[I].C.V);
    end;
    UVByteLen := LongWord(VCount) * 8;

    TotalBinLen := PosByteLen + NorByteLen + UVByteLen;
    BinPad := (4 - (TotalBinLen mod 4)) mod 4;
    PadByte := 0;
    for I := 1 to BinPad do BinStream.WriteBuffer(PadByte, 1);

    B := Mesh.Bounds;
    Root := TJSONObject.Create;
    try
      Asset := TJSONObject.Create;
      Asset.Add('version', '2.0');
      Asset.Add('generator', 'EngenhariaArquitetura GLB Exporter 1.0');
      Root.Add('asset', Asset);
      Root.Add('scene', 0);

      ScenesArr := TJSONArray.Create;
      SceneObj := TJSONObject.Create;
      Arr := TJSONArray.Create; Arr.Add(0);
      SceneObj.Add('nodes', Arr);
      ScenesArr.Add(SceneObj);
      Root.Add('scenes', ScenesArr);

      NodesArr := TJSONArray.Create;
      NodeObj := TJSONObject.Create;
      NodeObj.Add('name', Mesh.Name);
      NodeObj.Add('mesh', 0);
      NodesArr.Add(NodeObj);
      Root.Add('nodes', NodesArr);

      MatsArr := TJSONArray.Create;
      for I := 0 to High(Mesh.Materials) do
      begin
        MatObj := TJSONObject.Create;
        MatObj.Add('name', Mesh.Materials[I].Name);
        PbrObj := TJSONObject.Create;
        ColArr := TJSONArray.Create;
        RCol := ((Mesh.Materials[I].ColorRGB shr 16) and $FF) / 255.0;
        GCol := ((Mesh.Materials[I].ColorRGB shr 8) and $FF) / 255.0;
        BCol := (Mesh.Materials[I].ColorRGB and $FF) / 255.0;
        ColArr.Add(RCol); ColArr.Add(GCol); ColArr.Add(BCol); ColArr.Add(Mesh.Materials[I].Opacity);
        PbrObj.Add('baseColorFactor', ColArr);
        PbrObj.Add('metallicFactor', Mesh.Materials[I].Metallic);
        PbrObj.Add('roughnessFactor', Mesh.Materials[I].Roughness);
        MatObj.Add('pbrMetallicRoughness', PbrObj);
        MatsArr.Add(MatObj);
      end;
      Root.Add('materials', MatsArr);

      MatIdx := EnsureRange(Mesh.Triangles[0].MaterialIndex, 0, High(Mesh.Materials));
      MeshesArr := TJSONArray.Create;
      MeshObj := TJSONObject.Create;
      MeshObj.Add('name', Mesh.Name);
      PrimsArr := TJSONArray.Create;
      PrimObj := TJSONObject.Create;
      NodeObj := TJSONObject.Create;
      NodeObj.Add('POSITION', 0);
      NodeObj.Add('NORMAL', 1);
      NodeObj.Add('TEXCOORD_0', 2);
      PrimObj.Add('attributes', NodeObj);
      PrimObj.Add('material', MatIdx);
      PrimsArr.Add(PrimObj);
      MeshObj.Add('primitives', PrimsArr);
      MeshesArr.Add(MeshObj);
      Root.Add('meshes', MeshesArr);

      BuffersArr := TJSONArray.Create;
      NodeObj := TJSONObject.Create;
      NodeObj.Add('byteLength', Int64(TotalBinLen));
      BuffersArr.Add(NodeObj);
      Root.Add('buffers', BuffersArr);

      ViewsArr := TJSONArray.Create;
      NodeObj := TJSONObject.Create; NodeObj.Add('buffer', 0); NodeObj.Add('byteOffset', 0); NodeObj.Add('byteLength', Int64(PosByteLen)); ViewsArr.Add(NodeObj);
      NodeObj := TJSONObject.Create; NodeObj.Add('buffer', 0); NodeObj.Add('byteOffset', Int64(PosByteLen)); NodeObj.Add('byteLength', Int64(NorByteLen)); ViewsArr.Add(NodeObj);
      NodeObj := TJSONObject.Create; NodeObj.Add('buffer', 0); NodeObj.Add('byteOffset', Int64(PosByteLen + NorByteLen)); NodeObj.Add('byteLength', Int64(UVByteLen)); ViewsArr.Add(NodeObj);
      Root.Add('bufferViews', ViewsArr);

      AccArr := TJSONArray.Create;
      NodeObj := TJSONObject.Create;
      NodeObj.Add('bufferView', 0); NodeObj.Add('componentType', 5126); NodeObj.Add('count', VCount); NodeObj.Add('type', 'VEC3');
      MinArr := TJSONArray.Create; MinArr.Add(B.Min.X / 1000.0); MinArr.Add(B.Min.Z / 1000.0); MinArr.Add(-B.Max.Y / 1000.0);
      MaxArr := TJSONArray.Create; MaxArr.Add(B.Max.X / 1000.0); MaxArr.Add(B.Max.Z / 1000.0); MaxArr.Add(-B.Min.Y / 1000.0);
      NodeObj.Add('min', MinArr); NodeObj.Add('max', MaxArr);
      AccArr.Add(NodeObj);

      NodeObj := TJSONObject.Create;
      NodeObj.Add('bufferView', 1); NodeObj.Add('componentType', 5126); NodeObj.Add('count', VCount); NodeObj.Add('type', 'VEC3');
      AccArr.Add(NodeObj);

      NodeObj := TJSONObject.Create;
      NodeObj.Add('bufferView', 2); NodeObj.Add('componentType', 5126); NodeObj.Add('count', VCount); NodeObj.Add('type', 'VEC2');
      AccArr.Add(NodeObj);
      Root.Add('accessors', AccArr);

      JsonStr := Root.AsJSON;
    finally
      Root.Free;
    end;

    JsonLen := Length(JsonStr);
    JsonPad := (4 - (JsonLen mod 4)) mod 4;
    TotalLen := 12 + 8 + JsonLen + JsonPad + 8 + TotalBinLen + BinPad;

    OutStream := TMemoryStream.Create;
    try
      Magic := $46546C67; // 'glTF'
      Version := 2;
      OutStream.WriteBuffer(Magic, 4);
      OutStream.WriteBuffer(Version, 4);
      OutStream.WriteBuffer(TotalLen, 4);

      ChunkType := $4E4F534A; // 'JSON'
      Version := JsonLen + JsonPad;
      OutStream.WriteBuffer(Version, 4);
      OutStream.WriteBuffer(ChunkType, 4);
      if JsonLen > 0 then OutStream.WriteBuffer(JsonStr[1], JsonLen);
      PadByte := Ord(' ');
      for I := 1 to JsonPad do OutStream.WriteBuffer(PadByte, 1);

      ChunkType := $004E4942; // 'BIN'
      Version := TotalBinLen + BinPad;
      OutStream.WriteBuffer(Version, 4);
      OutStream.WriteBuffer(ChunkType, 4);
      BinStream.Position := 0;
      OutStream.CopyFrom(BinStream, BinStream.Size);
      OutStream.SaveToFile(FileName);
    finally
      OutStream.Free;
    end;
    Limitations := 'Exportado em glTF 2.0 (GLB) com geometria em metros (Y-up) e materiais PBR metálico/rugosidade.';
  finally
    BinStream.Free;
  end;
end;

procedure EAImportGLTF(const FileName: string; Mesh: TEAMesh3D);
var
  Loader: TGLTFLoader;
  Verts: TAIAvatarVertexArray;
  Faces: TGLTFFaceArray;
  Mats: TAIAvatarMaterialArray;
  Texs: TAIAvatarTextureArray;
  Skins: TAIAvatarSkinArray;
  Nodes: TGLTFNodeArray;
  I, MatIdx: Integer;
  ColRGB: LongWord;
  R, G, B: Byte;
  P0, P1, P2: TEAVec3;
  function ToZUpMM(const V: TVector3D): TEAVec3;
  begin
    Result := EAV3(V.X * 1000.0, -V.Z * 1000.0, V.Y * 1000.0);
  end;
begin
  EACheckSupportedExternalFile(FileName);
  if not FileExists(FileName) then
    raise EEAPackageError.CreateFmt('glTF/GLB não encontrado: %s', [FileName]);
  Mesh.Clear;
  Mesh.Name := ChangeFileExt(ExtractFileName(FileName), '');
  Loader := TGLTFLoader.Create;
  try
    if not Loader.LoadFromFile(FileName, Verts, Faces, Mats, Texs, Skins, Nodes) then
      raise EEAPackageError.Create('Falha no TGLTFLoader (CHATGPT): ' + Loader.LastError);
    for I := 0 to High(Mats) do
    begin
      R := Round(EnsureRange(Mats[I].BaseColorFactor.X, 0.0, 1.0) * 255);
      G := Round(EnsureRange(Mats[I].BaseColorFactor.Y, 0.0, 1.0) * 255);
      B := Round(EnsureRange(Mats[I].BaseColorFactor.Z, 0.0, 1.0) * 255);
      ColRGB := (LongWord(R) shl 16) or (LongWord(G) shl 8) or LongWord(B);
      Mesh.AddMaterial(Format('gltf_mat_%d', [I]), Mats[I].Name, ColRGB,
        Mats[I].RoughnessFactor, Mats[I].MetallicFactor,
        EnsureRange(Mats[I].BaseColorFactor.W, 0.05, 1.0));
    end;
    if Length(Mesh.Materials) = 0 then
      Mesh.AddMaterial('gltf_mat_0', 'glTF Padrão', $CBD5E1, 0.7, 0.0, 1.0);
    for I := 0 to High(Faces) do
    begin
      MatIdx := EnsureRange(Faces[I].MaterialIndex, 0, High(Mesh.Materials));
      ColRGB := Mesh.Materials[MatIdx].ColorRGB;
      P0 := ToZUpMM(Faces[I].V1);
      P1 := ToZUpMM(Faces[I].V2);
      P2 := ToZUpMM(Faces[I].V3);
      Mesh.AddTri(P0, P1, P2, ColRGB, MatIdx, 0, Mesh.Name);
    end;
  finally
    Loader.Free;
  end;
end;

procedure EAImportGLB(const FileName: string; Mesh: TEAMesh3D);
var
  MS: TMemoryStream;
  Magic, Version, TotalLen, ChunkLen, ChunkType, BinOffset: LongWord;
  JsonStr: RawByteString;
  Data: TJSONData;
  Root, Prim, Attrs, Acc, BV, MatObj, PbrObj: TJSONObject;
  MeshesArr, PrimsArr, AccArr, BVArr, MatsArr, ColArr: TJSONArray;
  PosAccIdx, IndAccIdx, MatIdx, BVIdx, ByteOff, Count, CompType, I, TriN: Integer;
  Verts: array of TEAVec3;
  Indices: array of Integer;
  F3: array[0..2] of Single;
  U16: Word;
  U32: LongWord;
  ColRGB: LongWord;
  R, G, B: Byte;
begin
  EACheckSupportedExternalFile(FileName);
  if SameText(ExtractFileExt(FileName), '.gltf') then
  begin
    EAImportGLTF(FileName, Mesh);
    Exit;
  end;
  if not FileExists(FileName) then
    raise EEAPackageError.CreateFmt('GLB não encontrado: %s', [FileName]);
  Mesh.Clear;
  Mesh.Name := ChangeFileExt(ExtractFileName(FileName), '');
  MS := TMemoryStream.Create;
  try
    MS.LoadFromFile(FileName);
    if MS.Size < 28 then raise EEAPackageError.Create('GLB inválido');
    MS.ReadBuffer(Magic, 4);
    MS.ReadBuffer(Version, 4);
    MS.ReadBuffer(TotalLen, 4);
    if (Magic <> $46546C67) or (Version <> 2) then
      raise EEAPackageError.Create('Assinatura glTF 2.0 inválida');

    MS.ReadBuffer(ChunkLen, 4);
    MS.ReadBuffer(ChunkType, 4);
    if ChunkType <> $4E4F534A then raise EEAPackageError.Create('Primeiro chunk do GLB deve ser JSON');
    SetLength(JsonStr, ChunkLen);
    if ChunkLen > 0 then MS.ReadBuffer(JsonStr[1], ChunkLen);

    BinOffset := 0;
    if MS.Position + 8 <= MS.Size then
    begin
      MS.ReadBuffer(ChunkLen, 4);
      MS.ReadBuffer(ChunkType, 4);
      if ChunkType = $004E4942 then BinOffset := MS.Position;
    end;
    if BinOffset = 0 then raise EEAPackageError.Create('GLB sem buffer binário BIN');

    Data := GetJSON(JsonStr);
    try
      if not (Data is TJSONObject) then raise EEAPackageError.Create('JSON glTF inválido');
      Root := TJSONObject(Data);
      MatsArr := Root.Get('materials', TJSONArray(nil));
      if MatsArr <> nil then
      begin
        for I := 0 to MatsArr.Count - 1 do
        begin
          MatObj := MatsArr.Objects[I];
          ColRGB := $CBD5E1;
          if (MatObj.Find('pbrMetallicRoughness') <> nil) and (MatObj.Find('pbrMetallicRoughness') is TJSONObject) then
          begin
            PbrObj := MatObj.Objects['pbrMetallicRoughness'];
            ColArr := PbrObj.Get('baseColorFactor', TJSONArray(nil));
            if (ColArr <> nil) and (ColArr.Count >= 3) then
            begin
              R := Round(EnsureRange(ColArr.Floats[0], 0.0, 1.0) * 255);
              G := Round(EnsureRange(ColArr.Floats[1], 0.0, 1.0) * 255);
              B := Round(EnsureRange(ColArr.Floats[2], 0.0, 1.0) * 255);
              ColRGB := (LongWord(R) shl 16) or (LongWord(G) shl 8) or LongWord(B);
            end;
            Mesh.AddMaterial(Format('mat_%d', [I]), MatObj.Get('name', 'Material'),
              ColRGB, PbrObj.Get('roughnessFactor', 0.7), PbrObj.Get('metallicFactor', 0.0), 1.0);
          end;
        end;
      end;
      if Length(Mesh.Materials) = 0 then
        Mesh.AddMaterial('mat_0', 'GLB Padrão', $CBD5E1, 0.7, 0.0, 1.0);

      MeshesArr := Root.Get('meshes', TJSONArray(nil));
      AccArr := Root.Get('accessors', TJSONArray(nil));
      BVArr := Root.Get('bufferViews', TJSONArray(nil));
      if (MeshesArr = nil) or (MeshesArr.Count = 0) or (AccArr = nil) or (BVArr = nil) then
        raise EEAPackageError.Create('GLB sem malha acessível');

      PrimsArr := MeshesArr.Objects[0].Get('primitives', TJSONArray(nil));
      if (PrimsArr = nil) or (PrimsArr.Count = 0) then Exit;
      Prim := PrimsArr.Objects[0];
      MatIdx := EnsureRange(Prim.Get('material', 0), 0, High(Mesh.Materials));
      ColRGB := Mesh.Materials[MatIdx].ColorRGB;
      Attrs := Prim.Objects['attributes'];
      PosAccIdx := Attrs.Get('POSITION', -1);
      if PosAccIdx < 0 then Exit;

      Acc := AccArr.Objects[PosAccIdx];
      BVIdx := Acc.Get('bufferView', 0);
      Count := Acc.Get('count', 0);
      BV := BVArr.Objects[BVIdx];
      ByteOff := BV.Get('byteOffset', 0) + Acc.Get('byteOffset', 0);
      MS.Position := Int64(BinOffset) + Int64(ByteOff);
      SetLength(Verts, Count);
      for I := 0 to Count - 1 do
      begin
        MS.ReadBuffer(F3, 12);
        { Converter de glTF m (Y-up) para mm Z-up }
        Verts[I] := EAV3(F3[0] * 1000.0, -F3[2] * 1000.0, F3[1] * 1000.0);
      end;

      IndAccIdx := Prim.Get('indices', -1);
      if IndAccIdx >= 0 then
      begin
        Acc := AccArr.Objects[IndAccIdx];
        BVIdx := Acc.Get('bufferView', 0);
        Count := Acc.Get('count', 0);
        CompType := Acc.Get('componentType', 5123);
        BV := BVArr.Objects[BVIdx];
        ByteOff := BV.Get('byteOffset', 0) + Acc.Get('byteOffset', 0);
        MS.Position := Int64(BinOffset) + Int64(ByteOff);
        SetLength(Indices, Count);
        for I := 0 to Count - 1 do
        begin
          if CompType = 5125 then begin MS.ReadBuffer(U32, 4); Indices[I] := U32; end
          else begin MS.ReadBuffer(U16, 2); Indices[I] := U16; end;
        end;
        TriN := Count div 3;
        for I := 0 to TriN - 1 do
          Mesh.AddTri(Verts[Indices[I * 3]], Verts[Indices[I * 3 + 1]], Verts[Indices[I * 3 + 2]],
            ColRGB, MatIdx, 0, Mesh.Name);
      end
      else
      begin
        TriN := Length(Verts) div 3;
        for I := 0 to TriN - 1 do
          Mesh.AddTri(Verts[I * 3], Verts[I * 3 + 1], Verts[I * 3 + 2],
            ColRGB, MatIdx, 0, Mesh.Name);
      end;
    finally
      Data.Free;
    end;
  finally
    MS.Free;
  end;
end;

end.
