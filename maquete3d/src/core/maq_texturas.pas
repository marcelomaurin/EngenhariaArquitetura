unit maq_texturas;

{ Maquete 3D - Módulo interno: Gerador de Texturas / Skins (etapas T1..T4).
  Implementa docs/Gerador_Texturas.md:
  texturas procedurais offline com semente reproduzível, escala física em mm,
  padrões contínuos (madeira, pedra, mármore, concreto, tijolo, azulejo,
  pintura, metal, tecido), mapas PBR (cor, normal, rugosidade, metalicidade),
  exportação PNG e pacote autocontido de skin (.skin.json). }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, fpjson, jsonparser,
  FPImage, FPWritePNG,
  ea_pacote, ea_fileio;

type
  TMAQTexPattern = (
    mtpMadeira, mtpPedra, mtpMarmore, mtpConcreto,
    mtpTijolo, mtpAzulejo, mtpPintura, mtpMetal, mtpTecido
  );

  TMAQSkin = record
    Id: string;
    Name: string;
    Category: string;
    Pattern: TMAQTexPattern;
    Seed: LongWord;
    BaseColorRGB: LongWord;
    AccentColorRGB: LongWord;
    ScaleXMM: Double;
    ScaleYMM: Double;
    Roughness: Double;
    Metallic: Double;
    Opacity: Double;
    Seamless: Boolean;
    Version: string;
    SourceImage: string;
  end;

  TMAQPixelBuffer = array of LongWord; // $RRGGBB

  TMAQSkinLibrary = class
  public
    Items: array of TMAQSkin;
    constructor Create;
    procedure InitDefaults;
    function AddOrUpdate(const S: TMAQSkin): Integer;
    function FindIndex(const AId: string): Integer;
    function GetById(const AId: string; out S: TMAQSkin): Boolean;
    function ToJSON: TJSONArray;
    procedure FromJSON(Arr: TJSONArray);
  end;

function MAQPatternToStr(P: TMAQTexPattern): string;
function MAQStrToPattern(const S: string): TMAQTexPattern;
function MAQGenerateProceduralMaps(const Skin: TMAQSkin; Res: Integer;
  out ColorBuf, NormalBuf, RoughBuf: TMAQPixelBuffer): Boolean;
procedure MAQSaveBufferPNG(const Buf: TMAQPixelBuffer; Res: Integer; const FileName: string);
procedure MAQExportSkinPackage(const Skin: TMAQSkin; Res: Integer; const FileName: string);
function MAQImportSkinPackage(const FileName: string): TMAQSkin;

implementation

function MAQPatternToStr(P: TMAQTexPattern): string;
const
  Names: array[TMAQTexPattern] of string = (
    'madeira', 'pedra', 'marmore', 'concreto',
    'tijolo', 'azulejo', 'pintura', 'metal', 'tecido'
  );
begin
  Result := Names[P];
end;

function MAQStrToPattern(const S: string): TMAQTexPattern;
var
  P: TMAQTexPattern;
  L: string;
begin
  L := LowerCase(Trim(S));
  for P := Low(P) to High(P) do
    if MAQPatternToStr(P) = L then Exit(P);
  Result := mtpPintura;
end;

function Hash2D(IX, IY: Integer; Seed: LongWord): Double;
var
  H: LongWord;
begin
  H := LongWord(IX) * 374761393 + LongWord(IY) * 668265263 + Seed * 1442695041;
  H := (H xor (H shr 13)) * 1274126177;
  H := H xor (H shr 16);
  Result := (H and $FFFF) / 65535.0;
end;

function TileNoise(U, V: Double; Period: Integer; Seed: LongWord): Double;
var
  X, Y, X0, Y0, X1, Y1: Integer;
  FX, FY, N00, N10, N01, N11, NX0, NX1: Double;
begin
  if Period < 2 then Period := 2;
  X := Floor(U * Period);
  Y := Floor(V * Period);
  FX := U * Period - X;
  FY := V * Period - Y;
  FX := FX * FX * (3.0 - 2.0 * FX);
  FY := FY * FY * (3.0 - 2.0 * FY);
  X0 := ((X mod Period) + Period) mod Period;
  Y0 := ((Y mod Period) + Period) mod Period;
  X1 := (X0 + 1) mod Period;
  Y1 := (Y0 + 1) mod Period;
  N00 := Hash2D(X0, Y0, Seed);
  N10 := Hash2D(X1, Y0, Seed);
  N01 := Hash2D(X0, Y1, Seed);
  N11 := Hash2D(X1, Y1, Seed);
  NX0 := N00 + (N10 - N00) * FX;
  NX1 := N01 + (N11 - N01) * FX;
  Result := NX0 + (NX1 - NX0) * FY;
end;

function LerpRGB(C1, C2: LongWord; T: Double): LongWord;
var
  R1, G1, B1, R2, G2, B2, R, G, B: Integer;
begin
  T := EnsureRange(T, 0.0, 1.0);
  R1 := (C1 shr 16) and $FF; G1 := (C1 shr 8) and $FF; B1 := C1 and $FF;
  R2 := (C2 shr 16) and $FF; G2 := (C2 shr 8) and $FF; B2 := C2 and $FF;
  R := EnsureRange(Round(R1 + (R2 - R1) * T), 0, 255);
  G := EnsureRange(Round(G1 + (G2 - G1) * T), 0, 255);
  B := EnsureRange(Round(B1 + (B2 - B1) * T), 0, 255);
  Result := (LongWord(R) shl 16) or (LongWord(G) shl 8) or LongWord(B);
end;

function MAQGenerateProceduralMaps(const Skin: TMAQSkin; Res: Integer;
  out ColorBuf, NormalBuf, RoughBuf: TMAQPixelBuffer): Boolean;
var
  X, Y, Idx, RowTile, Grout: Integer;
  U, V, N1, N2, H, Rough, TX, TY, DX, DY, NZ: Double;
  HMap: array of Double;
  NR, NG, NB, RV: Byte;
begin
  Res := EnsureRange(Res, 16, 1024);
  SetLength(ColorBuf, Res * Res);
  SetLength(NormalBuf, Res * Res);
  SetLength(RoughBuf, Res * Res);
  SetLength(HMap, Res * Res);

  for Y := 0 to Res - 1 do
  begin
    V := Y / Res;
    for X := 0 to Res - 1 do
    begin
      U := X / Res;
      Idx := Y * Res + X;
      N1 := TileNoise(U, V, 8, Skin.Seed);
      N2 := TileNoise(U, V, 24, Skin.Seed + 71);
      H := 0.5;
      Rough := Skin.Roughness;
      case Skin.Pattern of
        mtpMadeira:
          begin
            H := 0.5 + 0.5 * Sin((U * 14.0 + N1 * 2.2) * 2.0 * Pi);
            H := 0.7 * H + 0.3 * N2;
            ColorBuf[Idx] := LerpRGB(Skin.BaseColorRGB, Skin.AccentColorRGB, H);
            Rough := EnsureRange(Skin.Roughness + (0.5 - H) * 0.2, 0.1, 1.0);
          end;
        mtpMarmore:
          begin
            H := Abs(Sin((U * 3.0 + V * 2.0 + N1 * 3.5 + N2 * 0.8) * Pi));
            H := Power(H, 0.35);
            ColorBuf[Idx] := LerpRGB(Skin.AccentColorRGB, Skin.BaseColorRGB, H);
            Rough := EnsureRange(Skin.Roughness + (1.0 - H) * 0.15, 0.05, 1.0);
          end;
        mtpTijolo:
          begin
            RowTile := Floor(V * 4.0);
            TX := Frac(U * 2.0 + (RowTile mod 2) * 0.5);
            TY := Frac(V * 4.0);
            if (TX < 0.06) or (TY < 0.10) then
            begin
              H := 0.15;
              ColorBuf[Idx] := Skin.AccentColorRGB;
              Rough := 0.92;
            end
            else
            begin
              H := 0.65 + 0.35 * N2;
              ColorBuf[Idx] := LerpRGB(Skin.BaseColorRGB, $FFFFFF, N2 * 0.15);
            end;
          end;
        mtpAzulejo:
          begin
            TX := Frac(U * 2.0);
            TY := Frac(V * 2.0);
            Grout := Ord((TX < 0.03) or (TY < 0.03));
            if Grout = 1 then
            begin
              H := 0.1;
              ColorBuf[Idx] := Skin.AccentColorRGB;
              Rough := 0.85;
            end
            else
            begin
              H := 0.90 + 0.05 * N1;
              ColorBuf[Idx] := LerpRGB(Skin.BaseColorRGB, $FFFFFF, N1 * 0.08);
              Rough := EnsureRange(Skin.Roughness, 0.05, 0.45);
            end;
          end;
        mtpPedra, mtpConcreto:
          begin
            H := 0.65 * N1 + 0.35 * N2;
            ColorBuf[Idx] := LerpRGB(Skin.BaseColorRGB, Skin.AccentColorRGB, H);
            Rough := EnsureRange(Skin.Roughness + (H - 0.5) * 0.25, 0.2, 1.0);
          end;
        mtpMetal:
          begin
            H := 0.5 + 0.5 * TileNoise(U, V * 0.25, 16, Skin.Seed);
            ColorBuf[Idx] := LerpRGB(Skin.BaseColorRGB, Skin.AccentColorRGB, H * 0.3);
            Rough := EnsureRange(Skin.Roughness + (H - 0.5) * 0.1, 0.05, 0.7);
          end;
        mtpTecido:
          begin
            H := 0.5 + 0.25 * Sin(U * 32.0 * Pi) + 0.25 * Sin(V * 32.0 * Pi);
            ColorBuf[Idx] := LerpRGB(Skin.BaseColorRGB, Skin.AccentColorRGB, H * 0.5);
            Rough := EnsureRange(Max(0.7, Skin.Roughness), 0.5, 1.0);
          end;
      else
        begin
          H := 0.5 + 0.08 * (N2 - 0.5);
          ColorBuf[Idx] := LerpRGB(Skin.BaseColorRGB, Skin.AccentColorRGB, 0.1 * N2);
        end;
      end;
      HMap[Idx] := H;
      RV := EnsureRange(Round(Rough * 255.0), 0, 255);
      RoughBuf[Idx] := (LongWord(RV) shl 16) or (LongWord(RV) shl 8) or LongWord(RV);
    end;
  end;

  { Normal map estimado a partir das diferencas finitas continuas do mapa de altura }
  for Y := 0 to Res - 1 do
    for X := 0 to Res - 1 do
    begin
      DX := (HMap[Y * Res + ((X + 1) mod Res)] - HMap[Y * Res + ((X + Res - 1) mod Res)]) * 2.0;
      DY := (HMap[((Y + 1) mod Res) * Res + X] - HMap[((Y + Res - 1) mod Res) * Res + X]) * 2.0;
      NZ := Sqrt(Max(0.01, 1.0 - Min(0.95, DX * DX + DY * DY)));
      NR := EnsureRange(Round((-DX * 0.5 + 0.5) * 255.0), 0, 255);
      NG := EnsureRange(Round((-DY * 0.5 + 0.5) * 255.0), 0, 255);
      NB := EnsureRange(Round((NZ * 0.5 + 0.5) * 255.0), 0, 255);
      NormalBuf[Y * Res + X] := (LongWord(NR) shl 16) or (LongWord(NG) shl 8) or LongWord(NB);
    end;
  Result := True;
end;

procedure MAQSaveBufferPNG(const Buf: TMAQPixelBuffer; Res: Integer; const FileName: string);
var
  Img: TFPMemoryImage;
  Writer: TFPWriterPNG;
  X, Y: Integer;
  C: LongWord;
  FP: TFPColor;
begin
  Img := TFPMemoryImage.Create(Res, Res);
  Writer := TFPWriterPNG.Create;
  try
    Writer.UseAlpha := False;
    for Y := 0 to Res - 1 do
      for X := 0 to Res - 1 do
      begin
        C := Buf[Y * Res + X];
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

function SkinToJSON(const S: TMAQSkin): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('id', S.Id);
  Result.Add('name', S.Name);
  Result.Add('category', S.Category);
  Result.Add('pattern', MAQPatternToStr(S.Pattern));
  Result.Add('seed', Int64(S.Seed));
  Result.Add('base_color_hex', IntToHex(S.BaseColorRGB and $FFFFFF, 6));
  Result.Add('accent_color_hex', IntToHex(S.AccentColorRGB and $FFFFFF, 6));
  Result.Add('scale_x_mm', S.ScaleXMM);
  Result.Add('scale_y_mm', S.ScaleYMM);
  Result.Add('roughness', S.Roughness);
  Result.Add('metallic', S.Metallic);
  Result.Add('opacity', S.Opacity);
  Result.Add('seamless', S.Seamless);
  Result.Add('version', S.Version);
  Result.Add('source_image', S.SourceImage);
end;

function SkinFromJSON(O: TJSONObject): TMAQSkin;
begin
  Result := Default(TMAQSkin);
  if O = nil then Exit;
  Result.Id := O.Get('id', 'skin-1');
  Result.Name := O.Get('name', 'Skin');
  Result.Category := O.Get('category', 'Geral');
  Result.Pattern := MAQStrToPattern(O.Get('pattern', 'pintura'));
  Result.Seed := LongWord(O.Get('seed', Int64(1)));
  Result.BaseColorRGB := StrToDWordDef('$' + O.Get('base_color_hex', 'CCCCCC'), $CCCCCC);
  Result.AccentColorRGB := StrToDWordDef('$' + O.Get('accent_color_hex', '888888'), $888888);
  Result.ScaleXMM := O.Get('scale_x_mm', 1000.0);
  Result.ScaleYMM := O.Get('scale_y_mm', 1000.0);
  Result.Roughness := O.Get('roughness', 0.7);
  Result.Metallic := O.Get('metallic', 0.0);
  Result.Opacity := O.Get('opacity', 1.0);
  Result.Seamless := O.Get('seamless', True);
  Result.Version := O.Get('version', '1.0');
  Result.SourceImage := O.Get('source_image', '');
end;

procedure MAQExportSkinPackage(const Skin: TMAQSkin; Res: Integer; const FileName: string);
var
  Dir, BaseName, ColorPng, NormalPng, RoughPng: string;
  ColB, NorB, RghB: TMAQPixelBuffer;
  Pkg: TEAPackageManifest;
begin
  Dir := ExtractFilePath(ExpandFileName(FileName));
  BaseName := ChangeFileExt(ExtractFileName(FileName), '');
  ColorPng := Dir + BaseName + '_basecolor.png';
  NormalPng := Dir + BaseName + '_normal.png';
  RoughPng := Dir + BaseName + '_roughness.png';
  MAQGenerateProceduralMaps(Skin, Res, ColB, NorB, RghB);
  MAQSaveBufferPNG(ColB, Res, ColorPng);
  MAQSaveBufferPNG(NorB, Res, NormalPng);
  MAQSaveBufferPNG(RghB, Res, RoughPng);

  Pkg := TEAPackageManifest.Create;
  try
    Pkg.PackageType := EA_PKG_TEXTURA;
    Pkg.PackageId := Skin.Id;
    Pkg.Revision := Skin.Version;
    Pkg.CreatedByApp := 'Maquete3D-GeradorTexturas';
    Pkg.AddFileRef(ExtractFileName(ColorPng), EASHA256File(ColorPng));
    Pkg.AddFileRef(ExtractFileName(NormalPng), EASHA256File(NormalPng));
    Pkg.AddFileRef(ExtractFileName(RoughPng), EASHA256File(RoughPng));
    Pkg.Payload := SkinToJSON(Skin);
    Pkg.SaveToFile(FileName);
  finally
    Pkg.Free;
  end;
end;

function MAQImportSkinPackage(const FileName: string): TMAQSkin;
var
  Pkg: TEAPackageManifest;
begin
  Pkg := TEAPackageManifest.Create;
  try
    Pkg.LoadFromFile(FileName);
    if Pkg.PackageType <> EA_PKG_TEXTURA then
      raise EEAPackageError.Create('Pacote não é uma skin/textura válida');
    Result := SkinFromJSON(Pkg.Payload);
  finally
    Pkg.Free;
  end;
end;

constructor TMAQSkinLibrary.Create;
begin
  inherited Create;
  InitDefaults;
end;

procedure TMAQSkinLibrary.InitDefaults;
  procedure AddPreset(const AId, AName, ACat: string; APat: TMAQTexPattern; ASeed: LongWord;
    C1, C2: LongWord; SX, SY, Rgh, Met: Double);
  var
    S: TMAQSkin;
  begin
    S.Id := AId; S.Name := AName; S.Category := ACat; S.Pattern := APat; S.Seed := ASeed;
    S.BaseColorRGB := C1; S.AccentColorRGB := C2;
    S.ScaleXMM := SX; S.ScaleYMM := SY;
    S.Roughness := Rgh; S.Metallic := Met; S.Opacity := 1.0;
    S.Seamless := True; S.Version := '1.0'; S.SourceImage := '';
    AddOrUpdate(S);
  end;
begin
  SetLength(Items, 0);
  AddPreset('madeira_carvalho', 'Madeira Carvalho', 'Madeiras', mtpMadeira, 101, $A47148, $6F4518, 1200, 1200, 0.55, 0.0);
  AddPreset('mdf_branco', 'MDF Branco', 'Pinturas', mtpPintura, 102, $F1F5F9, $E2E8F0, 1000, 1000, 0.45, 0.0);
  AddPreset('granito_cinza', 'Granito Cinza', 'Pedras', mtpPedra, 103, $94A3B8, $475569, 800, 800, 0.35, 0.0);
  AddPreset('marmore_carrara', 'Mármore Carrara', 'Pedras', mtpMarmore, 104, $F8FAFC, $94A3B8, 1200, 1200, 0.20, 0.0);
  AddPreset('azulejo_300x600', 'Azulejo Hospitalar 300×600', 'Revestimentos', mtpAzulejo, 105, $E0F2FE, $94A3B8, 600, 600, 0.25, 0.0);
  AddPreset('tijolo_aparente', 'Tijolo Aparente', 'Alvenaria', mtpTijolo, 106, $B45309, $CBD5E1, 1000, 500, 0.85, 0.0);
  AddPreset('concreto_aparente', 'Concreto Aparente', 'Estrutura', mtpConcreto, 107, $94A3B8, $64748B, 1500, 1500, 0.80, 0.0);
  AddPreset('metal_escovado', 'Aço Inox Escovado', 'Metais', mtpMetal, 108, $CBD5E1, $64748B, 500, 500, 0.28, 0.9);
end;

function TMAQSkinLibrary.AddOrUpdate(const S: TMAQSkin): Integer;
begin
  Result := FindIndex(S.Id);
  if Result < 0 then
  begin
    Result := Length(Items);
    SetLength(Items, Result + 1);
  end;
  Items[Result] := S;
end;

function TMAQSkinLibrary.FindIndex(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Items) do
    if Items[I].Id = AId then Exit(I);
  Result := -1;
end;

function TMAQSkinLibrary.GetById(const AId: string; out S: TMAQSkin): Boolean;
var
  Idx: Integer;
begin
  Idx := FindIndex(AId);
  Result := Idx >= 0;
  if Result then S := Items[Idx];
end;

function TMAQSkinLibrary.ToJSON: TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to High(Items) do
    Result.Add(SkinToJSON(Items[I]));
end;

procedure TMAQSkinLibrary.FromJSON(Arr: TJSONArray);
var
  I: Integer;
begin
  if Arr = nil then Exit;
  for I := 0 to Arr.Count - 1 do
    AddOrUpdate(SkinFromJSON(Arr.Objects[I]));
end;

end.
