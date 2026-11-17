unit cena_projeto;

{ Criador de Cenas Realistas - Núcleo e Renderizador Software Raytracer (etapas C1..C5).
  Implementa docs/Criador_Cenas.md e integrações I-11, I-15, I-21 de docs/Integracoes.md. }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, fpjson, jsonparser,
  FPImage, FPWritePNG,
  ea_geometria, ea_pacote, ea_modelo, ea_malha3d, ea_fileio;

type
  TCenaAtmosphere = (caClear, caFog, caRain);

  TCenaCamera = record
    Id: string;
    Name: string;
    EyeMM: TEAVec3;
    TargetMM: TEAVec3;
    FOVDeg: Double;
  end;

  TCenaLight = record
    Id: string;
    Name: string;
    PosMM: TEAVec3;
    ColorRGB: LongWord;
    PowerWatts: Double;
    Enabled: Boolean;
  end;

  TCenaKeyframe = record
    TimeSec: Double;
    EyeMM: TEAVec3;
    TargetMM: TEAVec3;
    DoorAngleDeg: Double;
    HourOfDay: Double;
  end;

  TCenaProject = class
  public
    ProjectId: string;
    MaqueteRefPath: string;
    MaqueteRevision: string;
    MaqueteHash: string;
    SceneMesh: TEAMesh3D;
    Cameras: array of TCenaCamera;
    Lights: array of TCenaLight;
    Keyframes: array of TCenaKeyframe;
    HourOfDay: Double;     // 0..24
    NorthDeg: Double;
    Atmosphere: TCenaAtmosphere;
    WindStrength: Double;  // 0..1
    WaterEnabled: Boolean;
    WaterLevelMM: Double;
    HasPeople: Boolean;
    HasVegetation: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure LoadDemoScene;
    procedure ImportMaquetePackage(const FileName: string; Reconcile: Boolean);
    procedure ImportLightingPackage(const FileName: string);
    procedure AddCamera(const AId, AName: string; const AEye, ATarget: TEAVec3; AFOV: Double = 55.0);
    procedure AddLight(const AId, AName: string; const APos: TEAVec3; AColor: LongWord; APower: Double);
    procedure AddKeyframe(ATimeSec: Double; const AEye, ATarget: TEAVec3; ADoorDeg, AHour: Double);
    procedure EvaluateAtTime(ATimeSec: Double; out Eye, Target: TEAVec3; out DoorDeg, Hour: Double);
    function RenderImageToBuffer(Width, Height: Integer; const Eye, Target: TEAVec3;
      FOVDeg, TimeHour: Double; Shadows: Boolean; out Pixels: array of LongWord): Boolean;
    procedure RenderToPNG(const FileName: string; Width, Height, CamIdx: Integer; Shadows: Boolean = True);
    function RenderSequencePNG(const OutDir: string; Width, Height, FrameCount: Integer;
      DurationSec: Double): Integer;
    procedure SaveSceneFile(const FileName: string);
    procedure LoadSceneFile(const FileName: string);
  end;

implementation

constructor TCenaProject.Create;
begin
  inherited Create;
  SceneMesh := TEAMesh3D.Create;
  Clear;
end;

destructor TCenaProject.Destroy;
begin
  SceneMesh.Free;
  inherited Destroy;
end;

procedure TCenaProject.Clear;
begin
  ProjectId := 'cena-001';
  MaqueteRefPath := '';
  MaqueteRevision := '';
  MaqueteHash := '';
  SceneMesh.Clear;
  SetLength(Cameras, 0);
  SetLength(Lights, 0);
  SetLength(Keyframes, 0);
  HourOfDay := 14.5;
  NorthDeg := 0.0;
  Atmosphere := caClear;
  WindStrength := 0.25;
  WaterEnabled := True;
  WaterLevelMM := 50.0;
  HasPeople := True;
  HasVegetation := True;
end;

procedure TCenaProject.LoadDemoScene;
var
  M: TEAModel;
  Poly: TEAVec2Array;
begin
  Clear;
  M := TEAModel.Create;
  try
    M.AddFloor('terreo', 'Térreo', 0, 2800, 150);
    M.AddWall('w1', 'terreo', EAV2(0, 0), EAV2(5000, 0), 150, 2800);
    M.AddWall('w2', 'terreo', EAV2(5000, 0), EAV2(5000, 4000), 150, 2800);
    M.AddWall('w3', 'terreo', EAV2(5000, 4000), EAV2(0, 4000), 150, 2800);
    M.AddWall('w4', 'terreo', EAV2(0, 4000), EAV2(0, 0), 150, 2800);
    M.AddOpening('d1', 'w1', 'terreo', eokDoor, 1200, 900, 2100, 0);
    M.AddOpening('j1', 'w2', 'terreo', eokWindow, 1200, 1400, 1200, 900);
    SetLength(Poly, 4);
    Poly[0] := EAV2(0, 0); Poly[1] := EAV2(5000, 0); Poly[2] := EAV2(5000, 4000); Poly[3] := EAV2(0, 4000);
    M.AddSlab('laje-terreo', 'terreo', Poly, 150);
    EABuildModelMesh(M, SceneMesh);
    { Elemento de vegetacao / arvore estilizada e pessoa }
    SceneMesh.AddCylinder(EAV3(-1200, 1200, 0), 120, 1800, 8, $78350F, 0, 'arvore_tronco');
    SceneMesh.AddSphere(EAV3(-1200, 1200, 2200), 750, 10, 6, $16A34A, 0, 'arvore_copa');
    SceneMesh.AddCylinder(EAV3(2500, -1400, 0), 160, 1650, 8, $2563EB, 0, 'pessoa_01');
  finally
    M.Free;
  end;

  AddCamera('cam-ext', 'Fachada Diurna/Noturna', EAV3(8500, -5500, 2600), EAV3(2500, 1500, 1200), 52.0);
  AddCamera('cam-int', 'Vista Interna', EAV3(800, 800, 1650), EAV3(3800, 2800, 1200), 65.0);
  AddLight('luz-01', 'Luminária Central', EAV3(2500, 2000, 2600), $FFF7ED, 120.0);
  AddKeyframe(0.0, EAV3(8500, -5500, 2600), EAV3(2500, 1500, 1200), 0.0, 14.5);
  AddKeyframe(2.0, EAV3(3500, -4200, 2000), EAV3(2500, 1500, 1200), 75.0, 20.5);
end;

procedure TCenaProject.ImportMaquetePackage(const FileName: string; Reconcile: Boolean);
var
  Pkg: TEAPackageManifest;
  M: TEAModel;
  SavedCams: array of TCenaCamera;
  SavedLights: array of TCenaLight;
  SavedKeys: array of TCenaKeyframe;
begin
  EACheckSupportedExternalFile(FileName);
  Pkg := TEAPackageManifest.Create;
  M := TEAModel.Create;
  try
    Pkg.LoadFromFile(FileName);
    if Pkg.PackageType <> EA_PKG_MAQUETE then
      raise EEAPackageError.Create('Esperado pacote do tipo maquete');
    if Reconcile then
    begin
      SavedCams := Copy(Cameras);
      SavedLights := Copy(Lights);
      SavedKeys := Copy(Keyframes);
    end;
    MaqueteRefPath := ExpandFileName(FileName);
    MaqueteRevision := Pkg.Revision;
    MaqueteHash := EASHA256File(FileName);
    if (Pkg.Payload <> nil) and (Pkg.Payload.Find('model') <> nil) then
    begin
      M.FromJSON(Pkg.Payload.Objects['model']);
      EABuildModelMesh(M, SceneMesh);
    end;
    if Reconcile and (Length(SavedCams) > 0) then
    begin
      Cameras := SavedCams;
      Lights := SavedLights;
      Keyframes := SavedKeys;
    end
    else if Length(Cameras) = 0 then
      AddCamera('cam-1', 'Câmera Principal', EAV3(7000, -5000, 2500), EAV3(2000, 1500, 1200), 55.0);
  finally
    M.Free;
    Pkg.Free;
  end;
end;

procedure TCenaProject.ImportLightingPackage(const FileName: string);
var
  Pkg: TEAPackageManifest;
  Arr: TJSONArray;
  Item, PosObj: TJSONObject;
  I: Integer;
begin
  Pkg := TEAPackageManifest.Create;
  try
    Pkg.LoadFromFile(FileName);
    if Pkg.PackageType <> EA_PKG_ESTADO_ILUMINACAO then
      raise EEAPackageError.Create('Pacote não é estado_iluminacao');
    if Pkg.Payload = nil then Exit;
    Arr := Pkg.Payload.Get('luminaires', TJSONArray(nil));
    if Arr = nil then Exit;
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Objects[I];
      PosObj := Item.Get('pos_mm', TJSONObject(nil));
      if PosObj = nil then Continue;
      AddLight(Item.Get('id', Format('lum-%d', [I + 1])),
        Item.Get('name', 'Luminária'),
        EAV3(PosObj.Get('x', 0.0), PosObj.Get('y', 0.0), PosObj.Get('z', 2600.0)),
        $FFF7ED, Item.Get('power_w', 40.0));
      Lights[High(Lights)].Enabled := Item.Get('on', True);
    end;
  finally
    Pkg.Free;
  end;
end;

procedure TCenaProject.AddCamera(const AId, AName: string; const AEye, ATarget: TEAVec3; AFOV: Double);
var
  N: Integer;
begin
  N := Length(Cameras);
  SetLength(Cameras, N + 1);
  Cameras[N].Id := AId;
  Cameras[N].Name := AName;
  Cameras[N].EyeMM := AEye;
  Cameras[N].TargetMM := ATarget;
  Cameras[N].FOVDeg := EnsureRange(AFOV, 15.0, 110.0);
end;

procedure TCenaProject.AddLight(const AId, AName: string; const APos: TEAVec3; AColor: LongWord; APower: Double);
var
  N: Integer;
begin
  N := Length(Lights);
  SetLength(Lights, N + 1);
  Lights[N].Id := AId;
  Lights[N].Name := AName;
  Lights[N].PosMM := APos;
  Lights[N].ColorRGB := AColor;
  Lights[N].PowerWatts := APower;
  Lights[N].Enabled := True;
end;

procedure TCenaProject.AddKeyframe(ATimeSec: Double; const AEye, ATarget: TEAVec3; ADoorDeg, AHour: Double);
var
  N: Integer;
begin
  N := Length(Keyframes);
  SetLength(Keyframes, N + 1);
  Keyframes[N].TimeSec := ATimeSec;
  Keyframes[N].EyeMM := AEye;
  Keyframes[N].TargetMM := ATarget;
  Keyframes[N].DoorAngleDeg := ADoorDeg;
  Keyframes[N].HourOfDay := AHour;
end;

procedure TCenaProject.EvaluateAtTime(ATimeSec: Double; out Eye, Target: TEAVec3; out DoorDeg, Hour: Double);
var
  I: Integer;
  T: Double;
begin
  if Length(Keyframes) = 0 then
  begin
    if Length(Cameras) > 0 then begin Eye := Cameras[0].EyeMM; Target := Cameras[0].TargetMM; end
    else begin Eye := EAV3(6000, -5000, 2400); Target := EAV3(2000, 1500, 1000); end;
    DoorDeg := 0;
    Hour := HourOfDay;
    Exit;
  end;
  if (Length(Keyframes) = 1) or (ATimeSec <= Keyframes[0].TimeSec) then
  begin
    Eye := Keyframes[0].EyeMM; Target := Keyframes[0].TargetMM;
    DoorDeg := Keyframes[0].DoorAngleDeg; Hour := Keyframes[0].HourOfDay;
    Exit;
  end;
  for I := 0 to High(Keyframes) - 1 do
    if (ATimeSec >= Keyframes[I].TimeSec) and (ATimeSec <= Keyframes[I + 1].TimeSec) then
    begin
      if Keyframes[I + 1].TimeSec > Keyframes[I].TimeSec then
        T := (ATimeSec - Keyframes[I].TimeSec) / (Keyframes[I + 1].TimeSec - Keyframes[I].TimeSec)
      else T := 0.0;
      Eye := EAV3Add(EAV3Scale(Keyframes[I].EyeMM, 1.0 - T), EAV3Scale(Keyframes[I + 1].EyeMM, T));
      Target := EAV3Add(EAV3Scale(Keyframes[I].TargetMM, 1.0 - T), EAV3Scale(Keyframes[I + 1].TargetMM, T));
      DoorDeg := Keyframes[I].DoorAngleDeg + (Keyframes[I + 1].DoorAngleDeg - Keyframes[I].DoorAngleDeg) * T;
      Hour := Keyframes[I].HourOfDay + (Keyframes[I + 1].HourOfDay - Keyframes[I].HourOfDay) * T;
      Exit;
    end;
  I := High(Keyframes);
  Eye := Keyframes[I].EyeMM; Target := Keyframes[I].TargetMM;
  DoorDeg := Keyframes[I].DoorAngleDeg; Hour := Keyframes[I].HourOfDay;
end;

function RayTriangle(const Orig, Dir, V0, V1, V2: TEAVec3; out TOut: Double): Boolean;
var
  E1, E2, H, S, Q: TEAVec3;
  A, F, U, V, T: Double;
begin
  Result := False;
  E1 := EAV3Sub(V1, V0);
  E2 := EAV3Sub(V2, V0);
  H := EAV3Cross(Dir, E2);
  A := EAV3Dot(E1, H);
  if Abs(A) < 1e-6 then Exit;
  F := 1.0 / A;
  S := EAV3Sub(Orig, V0);
  U := F * EAV3Dot(S, H);
  if (U < 0.0) or (U > 1.0) then Exit;
  Q := EAV3Cross(S, E1);
  V := F * EAV3Dot(Dir, Q);
  if (V < 0.0) or (U + V > 1.0) then Exit;
  T := F * EAV3Dot(E2, Q);
  if T > 1.0 then
  begin
    TOut := T;
    Result := True;
  end;
end;

function RayBoxHit(const Orig, Dir: TEAVec3; const Box: TEABox3D): Boolean;
var
  TMin, TMax, T1, T2, Inv: Double;
  procedure AxisTest(O, D, BMin, BMax: Double);
  begin
    if Abs(D) < 1e-9 then
    begin
      if (O < BMin) or (O > BMax) then TMin := 1e30;
      Exit;
    end;
    Inv := 1.0 / D;
    T1 := (BMin - O) * Inv;
    T2 := (BMax - O) * Inv;
    if T1 > T2 then begin Inv := T1; T1 := T2; T2 := Inv; end;
    if T1 > TMin then TMin := T1;
    if T2 < TMax then TMax := T2;
  end;
begin
  if not Box.Valid then Exit(False);
  TMin := 0.0; TMax := 1e12;
  AxisTest(Orig.X, Dir.X, Box.Min.X, Box.Max.X);
  AxisTest(Orig.Y, Dir.Y, Box.Min.Y, Box.Max.Y);
  AxisTest(Orig.Z, Dir.Z, Box.Min.Z, Box.Max.Z);
  Result := (TMax >= TMin) and (TMax > 0.0);
end;

function TCenaProject.RenderImageToBuffer(Width, Height: Integer; const Eye, Target: TEAVec3;
  FOVDeg, TimeHour: Double; Shadows: Boolean; out Pixels: array of LongWord): Boolean;
var
  ForwardDir, RightDir, UpDir, RayDir, SunDir, HitPt, Nor, LDir: TEAVec3;
  SunElev, SunAzim, SunInt, AmbInt, Aspect, HalfH, HalfW: Double;
  PX, PY, I, BestTri, LIdx: Integer;
  NX, NY, TVal, BestT, Diff, Atten, RAcc, GAcc, BAcc, FogF: Double;
  InShadow: Boolean;
  BaseCol, SkyCol, FogCol: LongWord;
  Box: TEABox3D;
  SunColor: array[0..2] of Double;
  function MixCol(C1, C2: LongWord; F: Double): LongWord;
  var R, G, B: Integer;
  begin
    F := EnsureRange(F, 0.0, 1.0);
    R := EnsureRange(Round(((C1 shr 16) and $FF) * (1 - F) + ((C2 shr 16) and $FF) * F), 0, 255);
    G := EnsureRange(Round(((C1 shr 8) and $FF) * (1 - F) + ((C2 shr 8) and $FF) * F), 0, 255);
    B := EnsureRange(Round((C1 and $FF) * (1 - F) + (C2 and $FF) * F), 0, 255);
    Result := (LongWord(R) shl 16) or (LongWord(G) shl 8) or LongWord(B);
  end;
begin
  Result := False;
  if (Width < 8) or (Height < 8) or (Length(Pixels) < Width * Height) then Exit;
  Box := SceneMesh.Bounds;

  { Direcao solar conforme horario (6h..18h dia; noite luar suave + luzes artificiais) }
  SunElev := Sin(EnsureRange((TimeHour - 6.0) / 12.0, 0.0, 1.0) * Pi);
  if (TimeHour < 6.0) or (TimeHour > 18.5) then
  begin
    SunInt := 0.08;
    AmbInt := 0.14;
    SkyCol := $0F172A;
    SunColor[0] := 0.65; SunColor[1] := 0.75; SunColor[2] := 1.0;
    SunElev := 0.55;
  end
  else
  begin
    SunInt := 0.45 + 0.55 * SunElev;
    AmbInt := 0.30;
    SkyCol := MixCol($FDBA74, $7DD3FC, EnsureRange(SunElev * 1.4, 0.0, 1.0));
    SunColor[0] := 1.0; SunColor[1] := 0.96; SunColor[2] := 0.88;
  end;
  SunAzim := DegToRad(NorthDeg + (TimeHour - 6.0) * 15.0);
  SunDir := EAV3Norm(EAV3(Cos(SunAzim), Sin(SunAzim), Max(0.25, SunElev)));
  FogCol := $CBD5E1;

  ForwardDir := EAV3Norm(EAV3Sub(Target, Eye));
  RightDir := EAV3Norm(EAV3Cross(ForwardDir, EAV3(0, 0, 1)));
  if EAV3Len(RightDir) < 0.01 then RightDir := EAV3(1, 0, 0);
  UpDir := EAV3Norm(EAV3Cross(RightDir, ForwardDir));

  Aspect := Width / Height;
  HalfH := Tan(DegToRad(FOVDeg) * 0.5);
  HalfW := HalfH * Aspect;

  for PY := 0 to Height - 1 do
  begin
    NY := 1.0 - 2.0 * (PY + 0.5) / Height;
    for PX := 0 to Width - 1 do
    begin
      NX := 2.0 * (PX + 0.5) / Width - 1.0;
      RayDir := EAV3Norm(EAV3Add(ForwardDir,
        EAV3Add(EAV3Scale(RightDir, NX * HalfW), EAV3Scale(UpDir, NY * HalfH))));

      BestT := 1e12;
      BestTri := -1;
      if RayBoxHit(Eye, RayDir, Box) then
      begin
        for I := 0 to High(SceneMesh.Triangles) do
          if RayTriangle(Eye, RayDir, SceneMesh.Triangles[I].A.Pos,
            SceneMesh.Triangles[I].B.Pos, SceneMesh.Triangles[I].C.Pos, TVal) then
            if TVal < BestT then
            begin
              BestT := TVal;
              BestTri := I;
            end;
      end;

      { Plano do solo / agua Z = 0 se o raio cruzar para baixo }
      if (BestTri < 0) and (RayDir.Z < -0.001) then
      begin
        TVal := (0.0 - Eye.Z) / RayDir.Z;
        if (TVal > 1.0) and (TVal < BestT) then
        begin
          BestT := TVal;
          HitPt := EAV3Add(Eye, EAV3Scale(RayDir, BestT));
          if WaterEnabled and (Abs(HitPt.X) < 3500) and (HitPt.Y < -500) and (HitPt.Y > -3500) then
            BaseCol := MixCol($0284C7, SkyCol, 0.35 + 0.1 * Sin(HitPt.X * 0.01))
          else if ((Floor(HitPt.X / 1000) + Floor(HitPt.Y / 1000)) and 1) = 0 then
            BaseCol := $64748B
          else
            BaseCol := $475569;
          RAcc := ((BaseCol shr 16) and $FF) * (AmbInt + SunInt * 0.5);
          GAcc := ((BaseCol shr 8) and $FF) * (AmbInt + SunInt * 0.5);
          BAcc := (BaseCol and $FF) * (AmbInt + SunInt * 0.5);
          Pixels[PY * Width + PX] :=
            (LongWord(EnsureRange(Round(RAcc), 0, 255)) shl 16) or
            (LongWord(EnsureRange(Round(GAcc), 0, 255)) shl 8) or
            LongWord(EnsureRange(Round(BAcc), 0, 255));
          Continue;
        end;
      end;

      if BestTri < 0 then
      begin
        Pixels[PY * Width + PX] := MixCol(SkyCol, $FFFFFF, EnsureRange((1.0 - RayDir.Z) * 0.35, 0.0, 0.45));
        Continue;
      end;

      HitPt := EAV3Add(Eye, EAV3Scale(RayDir, BestT));
      Nor := SceneMesh.Triangles[BestTri].Normal;
      if EAV3Dot(Nor, RayDir) > 0 then Nor := EAV3Scale(Nor, -1.0);
      BaseCol := SceneMesh.Triangles[BestTri].ColorRGB;

      InShadow := False;
      if Shadows then
      begin
        for I := 0 to High(SceneMesh.Triangles) do
        begin
          if I = BestTri then Continue;
          if RayTriangle(EAV3Add(HitPt, EAV3Scale(Nor, 2.0)), SunDir,
            SceneMesh.Triangles[I].A.Pos, SceneMesh.Triangles[I].B.Pos, SceneMesh.Triangles[I].C.Pos, TVal) then
          begin
            InShadow := True;
            Break;
          end;
        end;
      end;

      Diff := Max(0.0, EAV3Dot(Nor, SunDir));
      if InShadow then Diff := 0.0;
      RAcc := ((BaseCol shr 16) and $FF) * (AmbInt + SunInt * Diff * SunColor[0]);
      GAcc := ((BaseCol shr 8) and $FF) * (AmbInt + SunInt * Diff * SunColor[1]);
      BAcc := (BaseCol and $FF) * (AmbInt + SunInt * Diff * SunColor[2]);

      { Contribuicao das luzes artificiais (especialmente visiveis a noite) }
      for LIdx := 0 to High(Lights) do
      begin
        if not Lights[LIdx].Enabled then Continue;
        LDir := EAV3Sub(Lights[LIdx].PosMM, HitPt);
        TVal := Max(200.0, EAV3Len(LDir));
        LDir := EAV3Scale(LDir, 1.0 / TVal);
        Atten := (Lights[LIdx].PowerWatts / 60.0) / (1.0 + (TVal / 3500.0) * (TVal / 3500.0));
        Diff := Max(0.0, EAV3Dot(Nor, LDir)) * Atten;
        RAcc := RAcc + ((BaseCol shr 16) and $FF) * Diff * (((Lights[LIdx].ColorRGB shr 16) and $FF) / 255.0);
        GAcc := GAcc + ((BaseCol shr 8) and $FF) * Diff * (((Lights[LIdx].ColorRGB shr 8) and $FF) / 255.0);
        BAcc := BAcc + (BaseCol and $FF) * Diff * ((Lights[LIdx].ColorRGB and $FF) / 255.0);
      end;

      if Atmosphere <> caClear then
      begin
        FogF := EnsureRange(BestT / 25000.0, 0.0, 0.65);
        RAcc := RAcc * (1.0 - FogF) + ((FogCol shr 16) and $FF) * FogF;
        GAcc := GAcc * (1.0 - FogF) + ((FogCol shr 8) and $FF) * FogF;
        BAcc := BAcc * (1.0 - FogF) + (FogCol and $FF) * FogF;
      end;

      Pixels[PY * Width + PX] :=
        (LongWord(EnsureRange(Round(RAcc), 0, 255)) shl 16) or
        (LongWord(EnsureRange(Round(GAcc), 0, 255)) shl 8) or
        LongWord(EnsureRange(Round(BAcc), 0, 255));
    end;
  end;
  Result := True;
end;

procedure SavePixelsPNG(const Pixels: array of LongWord; Width, Height: Integer; const FileName: string);
var
  Img: TFPMemoryImage;
  Writer: TFPWriterPNG;
  X, Y: Integer;
  C: LongWord;
  FP: TFPColor;
begin
  Img := TFPMemoryImage.Create(Width, Height);
  Writer := TFPWriterPNG.Create;
  try
    Writer.UseAlpha := False;
    for Y := 0 to Height - 1 do
      for X := 0 to Width - 1 do
      begin
        C := Pixels[Y * Width + X];
        FP.Red := ((C shr 16) and $FF) * 257;
        FP.Green := ((C shr 8) and $FF) * 257;
        FP.Blue := (C and $FF) * 257;
        FP.Alpha := $FFFF;
        Img.Colors[X, Y] := FP;
      end;
    Img.SaveToFile(FileName, Writer);
  finally
    Writer.Free;
    Img.Free;
  end;
end;

procedure TCenaProject.RenderToPNG(const FileName: string; Width, Height, CamIdx: Integer; Shadows: Boolean);
var
  Pixels: array of LongWord;
  Eye, Target: TEAVec3;
  FOV: Double;
begin
  if (CamIdx >= 0) and (CamIdx < Length(Cameras)) then
  begin
    Eye := Cameras[CamIdx].EyeMM;
    Target := Cameras[CamIdx].TargetMM;
    FOV := Cameras[CamIdx].FOVDeg;
  end
  else
  begin
    Eye := EAV3(8000, -5000, 2500);
    Target := EAV3(2500, 1500, 1200);
    FOV := 55.0;
  end;
  SetLength(Pixels, Width * Height);
  RenderImageToBuffer(Width, Height, Eye, Target, FOV, HourOfDay, Shadows, Pixels);
  SavePixelsPNG(Pixels, Width, Height, FileName);
end;

function TCenaProject.RenderSequencePNG(const OutDir: string; Width, Height, FrameCount: Integer;
  DurationSec: Double): Integer;
var
  I: Integer;
  T, DoorDeg, Hour: Double;
  Eye, Target: TEAVec3;
  Pixels: array of LongWord;
begin
  ForceDirectories(OutDir);
  SetLength(Pixels, Width * Height);
  Result := 0;
  for I := 0 to FrameCount - 1 do
  begin
    if FrameCount > 1 then T := DurationSec * I / (FrameCount - 1) else T := 0.0;
    EvaluateAtTime(T, Eye, Target, DoorDeg, Hour);
    RenderImageToBuffer(Width, Height, Eye, Target, 55.0, Hour, True, Pixels);
    SavePixelsPNG(Pixels, Width, Height, IncludeTrailingPathDelimiter(OutDir) + Format('frame_%.4d.png', [I + 1]));
    Inc(Result);
  end;
end;

procedure TCenaProject.SaveSceneFile(const FileName: string);
var
  Root, C, L: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('schema_version', '1.0');
    Root.Add('package_type', EA_PKG_CENA_VISUAL);
    Root.Add('project_id', ProjectId);
    Root.Add('maquete_ref_path', MaqueteRefPath);
    Root.Add('maquete_revision', MaqueteRevision);
    Root.Add('maquete_hash', MaqueteHash);
    Root.Add('hour_of_day', HourOfDay);
    Root.Add('north_deg', NorthDeg);
    Root.Add('atmosphere', Ord(Atmosphere));
    Root.Add('wind_strength', WindStrength);
    Root.Add('water_enabled', WaterEnabled);

    Arr := TJSONArray.Create;
    for I := 0 to High(Cameras) do
    begin
      C := TJSONObject.Create;
      C.Add('id', Cameras[I].Id); C.Add('name', Cameras[I].Name);
      C.Add('ex', Cameras[I].EyeMM.X); C.Add('ey', Cameras[I].EyeMM.Y); C.Add('ez', Cameras[I].EyeMM.Z);
      C.Add('tx', Cameras[I].TargetMM.X); C.Add('ty', Cameras[I].TargetMM.Y); C.Add('tz', Cameras[I].TargetMM.Z);
      C.Add('fov', Cameras[I].FOVDeg);
      Arr.Add(C);
    end;
    Root.Add('cameras', Arr);

    Arr := TJSONArray.Create;
    for I := 0 to High(Lights) do
    begin
      L := TJSONObject.Create;
      L.Add('id', Lights[I].Id); L.Add('name', Lights[I].Name);
      L.Add('x', Lights[I].PosMM.X); L.Add('y', Lights[I].PosMM.Y); L.Add('z', Lights[I].PosMM.Z);
      L.Add('power', Lights[I].PowerWatts); L.Add('enabled', Lights[I].Enabled);
      Arr.Add(L);
    end;
    Root.Add('lights', Arr);

    EAAtomicWriteText(FileName, Root.FormatJSON);
  finally
    Root.Free;
  end;
end;

procedure TCenaProject.LoadSceneFile(const FileName: string);
var
  SL: TStringList;
  Data: TJSONData;
  Root, O: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.LoadFromFile(FileName);
    Data := GetJSON(SL.Text);
  finally
    SL.Free;
  end;
  try
    if not (Data is TJSONObject) then raise EEAPackageError.Create('Arquivo de cena inválido');
    Root := TJSONObject(Data);
    Clear;
    ProjectId := Root.Get('project_id', 'cena-001');
    MaqueteRefPath := Root.Get('maquete_ref_path', '');
    MaqueteRevision := Root.Get('maquete_revision', '');
    MaqueteHash := Root.Get('maquete_hash', '');
    HourOfDay := Root.Get('hour_of_day', 14.5);
    NorthDeg := Root.Get('north_deg', 0.0);
    Atmosphere := TCenaAtmosphere(EnsureRange(Root.Get('atmosphere', 0), 0, 2));
    WindStrength := Root.Get('wind_strength', 0.25);
    WaterEnabled := Root.Get('water_enabled', True);
    Arr := Root.Get('cameras', TJSONArray(nil));
    if Arr <> nil then
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        AddCamera(O.Get('id', ''), O.Get('name', ''),
          EAV3(O.Get('ex', 0.0), O.Get('ey', 0.0), O.Get('ez', 0.0)),
          EAV3(O.Get('tx', 0.0), O.Get('ty', 0.0), O.Get('tz', 0.0)),
          O.Get('fov', 55.0));
      end;
    Arr := Root.Get('lights', TJSONArray(nil));
    if Arr <> nil then
      for I := 0 to Arr.Count - 1 do
      begin
        O := Arr.Objects[I];
        AddLight(O.Get('id', ''), O.Get('name', ''),
          EAV3(O.Get('x', 0.0), O.Get('y', 0.0), O.Get('z', 2500.0)),
          $FFF7ED, O.Get('power', 60.0));
        Lights[High(Lights)].Enabled := O.Get('enabled', True);
      end;
    if (MaqueteRefPath <> '') and FileExists(MaqueteRefPath) then
      ImportMaquetePackage(MaqueteRefPath, True);
  finally
    Data.Free;
  end;
end;

end.
