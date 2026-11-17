unit maq_objetos;

{ Maquete 3D - Módulo interno: Editor de Objetos 3D e Biblioteca (etapas O1..O5).
  Implementa docs/Editor_Objetos_3D.md:
  primitivas, importação STL/3MF/OBJ/GLB (recusa .mcad/.msuite),
  UV/normais, skins por objeto ou face, instâncias ancoradas (ea_ancoras)
  e exportação GLB e pacote objeto_3d. }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, fpjson, jsonparser,
  ea_geometria, ea_pacote, ea_modelo, ea_ancoras, ea_malha3d, ea_fileio,
  maq_texturas;

type
  TMAQObjectAsset = class
  public
    AssetId: string;
    Version: string;
    Name: string;
    Category: string;
    SourceFile: string;
    SourceHash: string;
    License: string;
    Mesh: TEAMesh3D;
    DefaultSkinId: string;
    FaceSkins: array of record
      FaceGroup: Integer;
      SkinId: string;
    end;
    constructor Create;
    destructor Destroy; override;
    procedure AssignSkinToObject(const SkinId: string; Lib: TMAQSkinLibrary);
    procedure AssignSkinToFace(FaceGroup: Integer; const SkinId: string; Lib: TMAQSkinLibrary);
    function ToJSON: TJSONObject;
    procedure FromJSON(O: TJSONObject);
  end;

  TMAQObjectInstance = record
    InstanceId: string;
    AssetId: string;
    AssetVersion: string;
    Anchor: TEAAnchor;
    ScaleXYZ: TEAVec3;
    OverrideSkinId: string;
    Visible: Boolean;
  end;

  TMAQObjectLibrary = class
  public
    Assets: array of TMAQObjectAsset;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure InitDefaults(Skins: TMAQSkinLibrary);
    function AddAsset(A: TMAQObjectAsset): Integer;
    function FindAsset(const AssetId: string): Integer;
    function ImportExternalSolid(const FileName, AssetId, AssetName: string;
      UnitScaleMM: Double = 1.0): TMAQObjectAsset;
    procedure ExportAssetGLB(const AssetId, FileName: string; out Limitations: string);
  end;

implementation

constructor TMAQObjectAsset.Create;
begin
  inherited Create;
  AssetId := '';
  Version := '1.0';
  Name := 'Objeto 3D';
  Category := 'Personalizado';
  SourceFile := '';
  SourceHash := '';
  License := 'Projeto próprio';
  Mesh := TEAMesh3D.Create;
  DefaultSkinId := '';
  SetLength(FaceSkins, 0);
end;

destructor TMAQObjectAsset.Destroy;
begin
  Mesh.Free;
  inherited Destroy;
end;

procedure TMAQObjectAsset.AssignSkinToObject(const SkinId: string; Lib: TMAQSkinLibrary);
var
  S: TMAQSkin;
  MatIdx, I: Integer;
begin
  DefaultSkinId := SkinId;
  if (Lib <> nil) and Lib.GetById(SkinId, S) then
  begin
    MatIdx := Mesh.AddMaterial(S.Id, S.Name, S.BaseColorRGB, S.Roughness, S.Metallic, S.Opacity);
    for I := 0 to High(Mesh.Triangles) do
    begin
      Mesh.Triangles[I].ColorRGB := S.BaseColorRGB;
      Mesh.Triangles[I].MaterialIndex := MatIdx;
    end;
  end;
end;

procedure TMAQObjectAsset.AssignSkinToFace(FaceGroup: Integer; const SkinId: string; Lib: TMAQSkinLibrary);
var
  S: TMAQSkin;
  MatIdx, I: Integer;
  Found: Boolean;
begin
  Found := False;
  for I := 0 to High(FaceSkins) do
    if FaceSkins[I].FaceGroup = FaceGroup then
    begin
      FaceSkins[I].SkinId := SkinId;
      Found := True;
      Break;
    end;
  if not Found then
  begin
    I := Length(FaceSkins);
    SetLength(FaceSkins, I + 1);
    FaceSkins[I].FaceGroup := FaceGroup;
    FaceSkins[I].SkinId := SkinId;
  end;
  if (Lib <> nil) and Lib.GetById(SkinId, S) then
  begin
    MatIdx := Mesh.AddMaterial(S.Id, S.Name, S.BaseColorRGB, S.Roughness, S.Metallic, S.Opacity);
    for I := 0 to High(Mesh.Triangles) do
      if Mesh.Triangles[I].FaceGroup = FaceGroup then
      begin
        Mesh.Triangles[I].ColorRGB := S.BaseColorRGB;
        Mesh.Triangles[I].MaterialIndex := MatIdx;
      end;
  end;
end;

function TMAQObjectAsset.ToJSON: TJSONObject;
var
  B: TEABox3D;
  BoundsObj, FObj: TJSONObject;
  FArr: TJSONArray;
  I: Integer;
begin
  B := Mesh.Bounds;
  Result := TJSONObject.Create;
  Result.Add('asset_id', AssetId);
  Result.Add('version', Version);
  Result.Add('name', Name);
  Result.Add('category', Category);
  Result.Add('units', 'mm');
  Result.Add('source_file', SourceFile);
  Result.Add('source_hash', SourceHash);
  Result.Add('license', License);
  Result.Add('default_skin_id', DefaultSkinId);
  Result.Add('triangle_count', Mesh.TriangleCount);
  BoundsObj := TJSONObject.Create;
  BoundsObj.Add('min_x', B.Min.X); BoundsObj.Add('min_y', B.Min.Y); BoundsObj.Add('min_z', B.Min.Z);
  BoundsObj.Add('max_x', B.Max.X); BoundsObj.Add('max_y', B.Max.Y); BoundsObj.Add('max_z', B.Max.Z);
  Result.Add('bounds_mm', BoundsObj);
  FArr := TJSONArray.Create;
  for I := 0 to High(FaceSkins) do
  begin
    FObj := TJSONObject.Create;
    FObj.Add('face_group', FaceSkins[I].FaceGroup);
    FObj.Add('skin_id', FaceSkins[I].SkinId);
    FArr.Add(FObj);
  end;
  Result.Add('face_skins', FArr);
end;

procedure TMAQObjectAsset.FromJSON(O: TJSONObject);
var
  FArr: TJSONArray;
  I: Integer;
begin
  if O = nil then Exit;
  AssetId := O.Get('asset_id', '');
  Version := O.Get('version', '1.0');
  Name := O.Get('name', 'Objeto 3D');
  Category := O.Get('category', 'Personalizado');
  SourceFile := O.Get('source_file', '');
  SourceHash := O.Get('source_hash', '');
  License := O.Get('license', '');
  DefaultSkinId := O.Get('default_skin_id', '');
  FArr := O.Get('face_skins', TJSONArray(nil));
  if FArr <> nil then
  begin
    SetLength(FaceSkins, FArr.Count);
    for I := 0 to FArr.Count - 1 do
    begin
      FaceSkins[I].FaceGroup := FArr.Objects[I].Get('face_group', 0);
      FaceSkins[I].SkinId := FArr.Objects[I].Get('skin_id', '');
    end;
  end;
end;

constructor TMAQObjectLibrary.Create;
begin
  inherited Create;
  SetLength(Assets, 0);
end;

destructor TMAQObjectLibrary.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TMAQObjectLibrary.Clear;
var
  I: Integer;
begin
  for I := 0 to High(Assets) do Assets[I].Free;
  SetLength(Assets, 0);
end;

procedure TMAQObjectLibrary.InitDefaults(Skins: TMAQSkinLibrary);
var
  A: TMAQObjectAsset;
begin
  Clear;
  { Mesa padrão 1200 x 700 x 750 mm (critério de aceite do Editor) }
  A := TMAQObjectAsset.Create;
  A.AssetId := 'mesa_1200x700';
  A.Name := 'Mesa Escritório 1200×700×750';
  A.Category := 'Móveis';
  A.Mesh.Name := A.AssetId;
  A.Mesh.AddBox(EAV3(0, 0, 730), EAV3(1200, 700, 40), $A47148, 0, A.AssetId);
  A.Mesh.AddBox(EAV3(-550, -300, 355), EAV3(50, 50, 710), $475569, 0, A.AssetId);
  A.Mesh.AddBox(EAV3(550, -300, 355), EAV3(50, 50, 710), $475569, 0, A.AssetId);
  A.Mesh.AddBox(EAV3(-550, 300, 355), EAV3(50, 50, 710), $475569, 0, A.AssetId);
  A.Mesh.AddBox(EAV3(550, 300, 355), EAV3(50, 50, 710), $475569, 0, A.AssetId);
  A.Mesh.GenerateBoxUVs(1000);
  if Skins <> nil then A.AssignSkinToObject('madeira_carvalho', Skins);
  AddAsset(A);

  { Bancada de recepção / hospitalar 1600 x 700 x 850 mm }
  A := TMAQObjectAsset.Create;
  A.AssetId := 'bancada_1600x700';
  A.Name := 'Bancada Recepção 1600×700×850';
  A.Category := 'Móveis';
  A.Mesh.Name := A.AssetId;
  A.Mesh.AddBox(EAV3(0, 0, 405), EAV3(1560, 660, 810), $F1F5F9, 0, A.AssetId);
  A.Mesh.AddBox(EAV3(0, 0, 830), EAV3(1600, 700, 40), $94A3B8, 0, A.AssetId);
  A.Mesh.GenerateBoxUVs(1000);
  AddAsset(A);

  { Leito hospitalar 2000 x 900 x 600 mm }
  A := TMAQObjectAsset.Create;
  A.AssetId := 'leito_hospitalar';
  A.Name := 'Leito Hospitalar 2000×900×600';
  A.Category := 'Equipamentos Hospitalares';
  A.Mesh.Name := A.AssetId;
  A.Mesh.AddBox(EAV3(0, 0, 400), EAV3(2000, 900, 200), $E0F2FE, 0, A.AssetId);
  A.Mesh.AddBox(EAV3(-950, 0, 550), EAV3(60, 900, 500), $64748B, 0, A.AssetId);
  A.Mesh.GenerateBoxUVs(1000);
  AddAsset(A);

  { Luminária teto 600 x 600 mm }
  A := TMAQObjectAsset.Create;
  A.AssetId := 'luminaria_led_600';
  A.Name := 'Painel LED Embutir 600×600';
  A.Category := 'Iluminação';
  A.Mesh.Name := A.AssetId;
  A.Mesh.AddBox(EAV3(0, 0, 20), EAV3(600, 600, 40), $FEF9C3, 0, A.AssetId);
  A.Mesh.GenerateBoxUVs(600);
  AddAsset(A);
end;

function TMAQObjectLibrary.AddAsset(A: TMAQObjectAsset): Integer;
var
  Idx: Integer;
begin
  Idx := FindAsset(A.AssetId);
  if Idx >= 0 then
  begin
    Assets[Idx].Free;
    Assets[Idx] := A;
    Exit(Idx);
  end;
  Result := Length(Assets);
  SetLength(Assets, Result + 1);
  Assets[Result] := A;
end;

function TMAQObjectLibrary.FindAsset(const AssetId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Assets) do
    if Assets[I].AssetId = AssetId then Exit(I);
  Result := -1;
end;

function TMAQObjectLibrary.ImportExternalSolid(const FileName, AssetId, AssetName: string;
  UnitScaleMM: Double): TMAQObjectAsset;
var
  Ext: string;
begin
  EACheckSupportedExternalFile(FileName);
  Ext := LowerCase(ExtractFileExt(FileName));
  Result := TMAQObjectAsset.Create;
  try
    Result.AssetId := AssetId;
    if Result.AssetId = '' then Result.AssetId := ChangeFileExt(ExtractFileName(FileName), '');
    Result.Name := AssetName;
    if Result.Name = '' then Result.Name := Result.AssetId;
    Result.SourceFile := ExpandFileName(FileName);
    Result.SourceHash := EASHA256File(FileName);

    if Ext = '.stl' then
      EAImportSTL(FileName, Result.Mesh, UnitScaleMM)
    else if Ext = '.3mf' then
      EAImport3MF(FileName, Result.Mesh)
    else if Ext = '.obj' then
      EAImportOBJ(FileName, Result.Mesh, UnitScaleMM)
    else if Ext = '.glb' then
      EAImportGLB(FileName, Result.Mesh)
    else
      raise EEAPackageError.Create('Formato de sólido não suportado: ' + Ext + ' (use STL, 3MF, OBJ ou GLB)');

    Result.Mesh.RepairNormals;
    Result.Mesh.GenerateBoxUVs(1000.0);
    AddAsset(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TMAQObjectLibrary.ExportAssetGLB(const AssetId, FileName: string; out Limitations: string);
var
  Idx: Integer;
begin
  Idx := FindAsset(AssetId);
  if Idx < 0 then raise EEAPackageError.Create('Objeto não encontrado na biblioteca: ' + AssetId);
  EAExportGLB(Assets[Idx].Mesh, FileName, Limitations);
end;

end.
