unit ea_modelo;

{ Núcleo Comum - Modelo Arquitetônico Interno Canônico (ea_modelo).
  Implementa etapa N2 de docs/Nucleo_Comum.md e intercâmbio I-06 / I-12 / I-18
  de docs/Integracoes.md. Independente da UI (RNF-002). Unidades: mm, Double. }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, fpjson, jsonparser, ea_geometria, ea_pacote, ea_fileio;

type
  TEAOpeningKind = (eokDoor, eokWindow, eokOpening);

  TEAFloor = record
    Id: string;
    Name: string;
    ElevationMM: Double;
    WallHeightMM: Double;
    SlabThicknessMM: Double;
    OffsetXMM: Double;
    OffsetYMM: Double;
  end;

  TEAWall = record
    Id: string;
    FloorId: string;
    StartMM: TEAVec2;
    EndMM: TEAVec2;
    ThicknessMM: Double;
    HeightMM: Double;
    MaterialId: string;
    Layer: string;
    SourceFormat: string;
    SourceExternalId: string;
  end;

  TEAOpening = record
    Id: string;
    WallId: string;
    FloorId: string;
    Kind: TEAOpeningKind;
    OffsetAlongMM: Double; // distância a partir do StartMM da parede
    WidthMM: Double;
    HeightMM: Double;
    SillMM: Double;
    SwingDeg: Double;
    MaterialId: string;
  end;

  TEASlab = record
    Id: string;
    FloorId: string;
    Polygon: TEAVec2Array;
    ThicknessMM: Double;
    ElevationOffsetMM: Double;
    MaterialId: string;
  end;

  TEARoom = record
    Id: string;
    FloorId: string;
    Name: string;
    Polygon: TEAVec2Array;
    AreaM2: Double;
    PerimeterM: Double;
    CentroidMM: TEAVec2;
  end;

  TEAStair = record
    Id: string;
    FromFloorId: string;
    ToFloorId: string;
    StartMM: TEAVec2;
    EndMM: TEAVec2;
    WidthMM: Double;
    StepCount: Integer;
  end;

  TEAMaterialRef = record
    Id: string;
    Name: string;
    ColorHex: string;
    Roughness: Double;
    Metallic: Double;
    TextureId: string;
    ScaleXMM: Double;
    ScaleYMM: Double;
  end;

  TEAModelDiffKind = (mdkAdded, mdkModified, mdkRemoved);

  TEAModelDiffItem = record
    EntityKind: string; // 'floor', 'wall', 'opening'
    EntityId: string;
    DiffKind: TEAModelDiffKind;
    Description: string;
  end;
  TEAModelDiffArray = array of TEAModelDiffItem;

  TEAModel = class
  public
    SchemaVersion: string;
    ProjectId: string;
    ProjectName: string;
    Revision: string;
    Units: string;
    SourceFile: string;
    SourceHash: string;
    Floors: array of TEAFloor;
    Walls: array of TEAWall;
    Openings: array of TEAOpening;
    Slabs: array of TEASlab;
    Rooms: array of TEARoom;
    Stairs: array of TEAStair;
    Materials: array of TEAMaterialRef;
    constructor Create;
    procedure Clear;
    procedure Assign(Source: TEAModel);
    function AddFloor(const AId, AName: string; AElevationMM, AWallHeightMM, ASlabMM: Double): Integer;
    function AddWall(const AId, AFloorId: string; const AStart, AEnd: TEAVec2;
      AThicknessMM: Double = 150; AHeightMM: Double = 2800; const ALayer: string = 'ARQ_PAREDES'): Integer;
    function AddOpening(const AId, AWallId, AFloorId: string; AKind: TEAOpeningKind;
      AOffsetAlongMM, AWidthMM, AHeightMM, ASillMM: Double): Integer;
    function AddSlab(const AId, AFloorId: string; const APoly: TEAVec2Array; AThicknessMM: Double = 150): Integer;
    function AddRoom(const AId, AFloorId, AName: string; const APoly: TEAVec2Array): Integer;
    function AddStair(const AId, AFromFloorId, AToFloorId: string; const AStart, AEnd: TEAVec2;
      AWidthMM: Double; AStepCount: Integer): Integer;
    function FindFloor(const AId: string): Integer;
    function FindWall(const AId: string): Integer;
    function FindOpening(const AId: string): Integer;
    function FindMaterial(const AId: string): Integer;
    procedure EnsureDefaultFloor;
    procedure AutoGenerateSlabsAndRooms;
    function ComputeBounds3D: TEABox3D;
    function ToJSON: TJSONObject;
    procedure FromJSON(O: TJSONObject);
    procedure SaveToPackageFile(const FileName, CreatedByApp: string);
    procedure LoadFromPackageFile(const FileName: string);
  end;

function EAOpeningKindToStr(K: TEAOpeningKind): string;
function EAStrToOpeningKind(const S: string): TEAOpeningKind;
function EACompareModels(OldModel, NewModel: TEAModel): TEAModelDiffArray;

implementation

function EAOpeningKindToStr(K: TEAOpeningKind): string;
begin
  case K of
    eokDoor: Result := 'door';
    eokWindow: Result := 'window';
  else
    Result := 'opening';
  end;
end;

function EAStrToOpeningKind(const S: string): TEAOpeningKind;
var
  L: string;
begin
  L := LowerCase(Trim(S));
  if L = 'door' then Result := eokDoor
  else if L = 'window' then Result := eokWindow
  else Result := eokOpening;
end;

function JSONVec2(const V: TEAVec2): TJSONArray;
begin
  Result := TJSONArray.Create;
  Result.Add(V.X);
  Result.Add(V.Y);
end;

function ReadVec2(A: TJSONArray): TEAVec2;
begin
  Result := EAV2(0, 0);
  if (A <> nil) and (A.Count >= 2) then
  begin
    Result.X := A.Floats[0];
    Result.Y := A.Floats[1];
  end;
end;

function JSONPoly(const Poly: TEAVec2Array): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to High(Poly) do
    Result.Add(JSONVec2(Poly[I]));
end;

function ReadPoly(A: TJSONArray): TEAVec2Array;
var
  I: Integer;
begin
  Result := nil;
  if A = nil then Exit;
  SetLength(Result, A.Count);
  for I := 0 to A.Count - 1 do
    Result[I] := ReadVec2(A.Arrays[I]);
end;

constructor TEAModel.Create;
begin
  inherited Create;
  Clear;
end;

procedure TEAModel.Clear;
begin
  SchemaVersion := '1.0';
  ProjectId := 'projeto-001';
  ProjectName := 'Projeto EngenhariaArquitetura';
  Revision := 'rev-001';
  Units := 'mm';
  SourceFile := '';
  SourceHash := '';
  SetLength(Floors, 0);
  SetLength(Walls, 0);
  SetLength(Openings, 0);
  SetLength(Slabs, 0);
  SetLength(Rooms, 0);
  SetLength(Stairs, 0);
  SetLength(Materials, 0);
end;

procedure TEAModel.Assign(Source: TEAModel);
var
  I: Integer;
begin
  if Source = nil then Exit;
  SchemaVersion := Source.SchemaVersion;
  ProjectId := Source.ProjectId;
  ProjectName := Source.ProjectName;
  Revision := Source.Revision;
  Units := Source.Units;
  SourceFile := Source.SourceFile;
  SourceHash := Source.SourceHash;
  Floors := Copy(Source.Floors);
  Walls := Copy(Source.Walls);
  Openings := Copy(Source.Openings);
  SetLength(Slabs, Length(Source.Slabs));
  for I := 0 to High(Source.Slabs) do
  begin
    Slabs[I] := Source.Slabs[I];
    Slabs[I].Polygon := Copy(Source.Slabs[I].Polygon);
  end;
  SetLength(Rooms, Length(Source.Rooms));
  for I := 0 to High(Source.Rooms) do
  begin
    Rooms[I] := Source.Rooms[I];
    Rooms[I].Polygon := Copy(Source.Rooms[I].Polygon);
  end;
  Stairs := Copy(Source.Stairs);
  Materials := Copy(Source.Materials);
end;

function TEAModel.AddFloor(const AId, AName: string; AElevationMM, AWallHeightMM, ASlabMM: Double): Integer;
begin
  Result := Length(Floors);
  SetLength(Floors, Result + 1);
  Floors[Result].Id := AId;
  Floors[Result].Name := AName;
  Floors[Result].ElevationMM := AElevationMM;
  Floors[Result].WallHeightMM := AWallHeightMM;
  Floors[Result].SlabThicknessMM := ASlabMM;
  Floors[Result].OffsetXMM := 0.0;
  Floors[Result].OffsetYMM := 0.0;
end;

function TEAModel.AddWall(const AId, AFloorId: string; const AStart, AEnd: TEAVec2;
  AThicknessMM, AHeightMM: Double; const ALayer: string): Integer;
begin
  Result := Length(Walls);
  SetLength(Walls, Result + 1);
  Walls[Result].Id := AId;
  Walls[Result].FloorId := AFloorId;
  Walls[Result].StartMM := AStart;
  Walls[Result].EndMM := AEnd;
  Walls[Result].ThicknessMM := AThicknessMM;
  Walls[Result].HeightMM := AHeightMM;
  Walls[Result].MaterialId := 'mat_parede_padrao';
  Walls[Result].Layer := ALayer;
  Walls[Result].SourceFormat := '';
  Walls[Result].SourceExternalId := '';
end;

function TEAModel.AddOpening(const AId, AWallId, AFloorId: string; AKind: TEAOpeningKind;
  AOffsetAlongMM, AWidthMM, AHeightMM, ASillMM: Double): Integer;
begin
  Result := Length(Openings);
  SetLength(Openings, Result + 1);
  Openings[Result].Id := AId;
  Openings[Result].WallId := AWallId;
  Openings[Result].FloorId := AFloorId;
  Openings[Result].Kind := AKind;
  Openings[Result].OffsetAlongMM := AOffsetAlongMM;
  Openings[Result].WidthMM := AWidthMM;
  Openings[Result].HeightMM := AHeightMM;
  Openings[Result].SillMM := ASillMM;
  Openings[Result].SwingDeg := 90.0;
  Openings[Result].MaterialId := '';
end;

function TEAModel.AddSlab(const AId, AFloorId: string; const APoly: TEAVec2Array; AThicknessMM: Double): Integer;
begin
  Result := Length(Slabs);
  SetLength(Slabs, Result + 1);
  Slabs[Result].Id := AId;
  Slabs[Result].FloorId := AFloorId;
  Slabs[Result].Polygon := Copy(APoly);
  Slabs[Result].ThicknessMM := AThicknessMM;
  Slabs[Result].ElevationOffsetMM := 0.0;
  Slabs[Result].MaterialId := 'mat_piso_padrao';
end;

function TEAModel.AddRoom(const AId, AFloorId, AName: string; const APoly: TEAVec2Array): Integer;
begin
  Result := Length(Rooms);
  SetLength(Rooms, Result + 1);
  Rooms[Result].Id := AId;
  Rooms[Result].FloorId := AFloorId;
  Rooms[Result].Name := AName;
  Rooms[Result].Polygon := Copy(APoly);
  Rooms[Result].AreaM2 := EAPolygonAreaMM2(APoly) / 1000000.0;
  Rooms[Result].PerimeterM := EAPolygonPerimeterMM(APoly) / 1000.0;
  Rooms[Result].CentroidMM := EAPolygonCentroid(APoly);
end;

function TEAModel.AddStair(const AId, AFromFloorId, AToFloorId: string; const AStart, AEnd: TEAVec2;
  AWidthMM: Double; AStepCount: Integer): Integer;
begin
  Result := Length(Stairs);
  SetLength(Stairs, Result + 1);
  Stairs[Result].Id := AId;
  Stairs[Result].FromFloorId := AFromFloorId;
  Stairs[Result].ToFloorId := AToFloorId;
  Stairs[Result].StartMM := AStart;
  Stairs[Result].EndMM := AEnd;
  Stairs[Result].WidthMM := AWidthMM;
  Stairs[Result].StepCount := Max(2, AStepCount);
end;

function TEAModel.FindFloor(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Floors) do
    if Floors[I].Id = AId then Exit(I);
  Result := -1;
end;

function TEAModel.FindWall(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Walls) do
    if Walls[I].Id = AId then Exit(I);
  Result := -1;
end;

function TEAModel.FindOpening(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Openings) do
    if Openings[I].Id = AId then Exit(I);
  Result := -1;
end;

function TEAModel.FindMaterial(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Materials) do
    if Materials[I].Id = AId then Exit(I);
  Result := -1;
end;

procedure TEAModel.EnsureDefaultFloor;
begin
  if Length(Floors) = 0 then
    AddFloor('terreo', 'Térreo', 0.0, 2800.0, 150.0);
end;

procedure TEAModel.AutoGenerateSlabsAndRooms;
var
  FIdx, I, WCount: Integer;
  Segs: TEASegment2DArray;
  Loops: TEARoomLoopArray;
  MinX, MinY, MaxX, MaxY: Double;
  HasPts: Boolean;
  BoxPoly: TEAVec2Array;
begin
  EnsureDefaultFloor;
  SetLength(Slabs, 0);
  SetLength(Rooms, 0);
  for FIdx := 0 to High(Floors) do
  begin
    Segs := nil;
    WCount := 0;
    HasPts := False;
    MinX := 1e12; MinY := 1e12; MaxX := -1e12; MaxY := -1e12;
    for I := 0 to High(Walls) do
    begin
      if Walls[I].FloorId <> Floors[FIdx].Id then Continue;
      SetLength(Segs, WCount + 1);
      Segs[WCount].Id := Walls[I].Id;
      Segs[WCount].A := Walls[I].StartMM;
      Segs[WCount].B := Walls[I].EndMM;
      Inc(WCount);
      MinX := Min(MinX, Min(Walls[I].StartMM.X, Walls[I].EndMM.X));
      MinY := Min(MinY, Min(Walls[I].StartMM.Y, Walls[I].EndMM.Y));
      MaxX := Max(MaxX, Max(Walls[I].StartMM.X, Walls[I].EndMM.X));
      MaxY := Max(MaxY, Max(Walls[I].StartMM.Y, Walls[I].EndMM.Y));
      HasPts := True;
    end;
    if not HasPts then Continue;
    Loops := EADetectClosedRooms(Segs, 40.0);
    for I := 0 to High(Loops) do
      AddRoom(Format('amb-%s-%d', [Floors[FIdx].Id, I + 1]), Floors[FIdx].Id,
        Format('Ambiente %d', [I + 1]), Loops[I].Vertices);

    SetLength(BoxPoly, 4);
    BoxPoly[0] := EAV2(MinX - 200, MinY - 200);
    BoxPoly[1] := EAV2(MaxX + 200, MinY - 200);
    BoxPoly[2] := EAV2(MaxX + 200, MaxY + 200);
    BoxPoly[3] := EAV2(MinX - 200, MaxY + 200);
    AddSlab('laje-' + Floors[FIdx].Id, Floors[FIdx].Id, BoxPoly, Floors[FIdx].SlabThicknessMM);
  end;
end;

function TEAModel.ComputeBounds3D: TEABox3D;
var
  I, FIdx: Integer;
  Z0, Z1: Double;
begin
  Result := EAEmptyBox3D;
  for I := 0 to High(Walls) do
  begin
    FIdx := FindFloor(Walls[I].FloorId);
    if FIdx >= 0 then Z0 := Floors[FIdx].ElevationMM else Z0 := 0.0;
    Z1 := Z0 + Walls[I].HeightMM;
    EAExpandBox3D(Result, EAV3(Walls[I].StartMM.X, Walls[I].StartMM.Y, Z0));
    EAExpandBox3D(Result, EAV3(Walls[I].EndMM.X, Walls[I].EndMM.Y, Z1));
  end;
end;

function TEAModel.ToJSON: TJSONObject;
var
  Arr: TJSONArray;
  Item, Src: TJSONObject;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.Add('schema_version', SchemaVersion);
  Result.Add('project_id', ProjectId);
  Result.Add('project_name', ProjectName);
  Result.Add('revision', Revision);
  Result.Add('units', Units);
  if SourceFile <> '' then
  begin
    Src := TJSONObject.Create;
    Src.Add('file', SourceFile);
    Src.Add('hash', SourceHash);
    Result.Add('source', Src);
  end;

  Arr := TJSONArray.Create;
  for I := 0 to High(Floors) do
  begin
    Item := TJSONObject.Create;
    Item.Add('id', Floors[I].Id);
    Item.Add('name', Floors[I].Name);
    Item.Add('elevation_mm', Floors[I].ElevationMM);
    Item.Add('wall_height_mm', Floors[I].WallHeightMM);
    Item.Add('slab_thickness_mm', Floors[I].SlabThicknessMM);
    Item.Add('offset_x_mm', Floors[I].OffsetXMM);
    Item.Add('offset_y_mm', Floors[I].OffsetYMM);
    Arr.Add(Item);
  end;
  Result.Add('floors', Arr);

  Arr := TJSONArray.Create;
  for I := 0 to High(Walls) do
  begin
    Item := TJSONObject.Create;
    Item.Add('id', Walls[I].Id);
    Item.Add('type', 'wall');
    Item.Add('floor_id', Walls[I].FloorId);
    Item.Add('start_mm', JSONVec2(Walls[I].StartMM));
    Item.Add('end_mm', JSONVec2(Walls[I].EndMM));
    Item.Add('thickness_mm', Walls[I].ThicknessMM);
    Item.Add('height_mm', Walls[I].HeightMM);
    Item.Add('material_id', Walls[I].MaterialId);
    Item.Add('layer', Walls[I].Layer);
    if Walls[I].SourceFormat <> '' then
    begin
      Src := TJSONObject.Create;
      Src.Add('format', Walls[I].SourceFormat);
      Src.Add('external_id', Walls[I].SourceExternalId);
      Item.Add('source', Src);
    end;
    Arr.Add(Item);
  end;
  Result.Add('walls', Arr);

  Arr := TJSONArray.Create;
  for I := 0 to High(Openings) do
  begin
    Item := TJSONObject.Create;
    Item.Add('id', Openings[I].Id);
    Item.Add('wall_id', Openings[I].WallId);
    Item.Add('floor_id', Openings[I].FloorId);
    Item.Add('kind', EAOpeningKindToStr(Openings[I].Kind));
    Item.Add('offset_along_mm', Openings[I].OffsetAlongMM);
    Item.Add('width_mm', Openings[I].WidthMM);
    Item.Add('height_mm', Openings[I].HeightMM);
    Item.Add('sill_mm', Openings[I].SillMM);
    Item.Add('swing_deg', Openings[I].SwingDeg);
    Item.Add('material_id', Openings[I].MaterialId);
    Arr.Add(Item);
  end;
  Result.Add('openings', Arr);

  Arr := TJSONArray.Create;
  for I := 0 to High(Slabs) do
  begin
    Item := TJSONObject.Create;
    Item.Add('id', Slabs[I].Id);
    Item.Add('floor_id', Slabs[I].FloorId);
    Item.Add('polygon', JSONPoly(Slabs[I].Polygon));
    Item.Add('thickness_mm', Slabs[I].ThicknessMM);
    Item.Add('elevation_offset_mm', Slabs[I].ElevationOffsetMM);
    Item.Add('material_id', Slabs[I].MaterialId);
    Arr.Add(Item);
  end;
  Result.Add('slabs', Arr);

  Arr := TJSONArray.Create;
  for I := 0 to High(Rooms) do
  begin
    Item := TJSONObject.Create;
    Item.Add('id', Rooms[I].Id);
    Item.Add('floor_id', Rooms[I].FloorId);
    Item.Add('name', Rooms[I].Name);
    Item.Add('polygon', JSONPoly(Rooms[I].Polygon));
    Item.Add('area_m2', Rooms[I].AreaM2);
    Item.Add('perimeter_m', Rooms[I].PerimeterM);
    Item.Add('centroid_mm', JSONVec2(Rooms[I].CentroidMM));
    Arr.Add(Item);
  end;
  Result.Add('rooms', Arr);

  Arr := TJSONArray.Create;
  for I := 0 to High(Stairs) do
  begin
    Item := TJSONObject.Create;
    Item.Add('id', Stairs[I].Id);
    Item.Add('from_floor_id', Stairs[I].FromFloorId);
    Item.Add('to_floor_id', Stairs[I].ToFloorId);
    Item.Add('start_mm', JSONVec2(Stairs[I].StartMM));
    Item.Add('end_mm', JSONVec2(Stairs[I].EndMM));
    Item.Add('width_mm', Stairs[I].WidthMM);
    Item.Add('step_count', Stairs[I].StepCount);
    Arr.Add(Item);
  end;
  Result.Add('stairs', Arr);

  Arr := TJSONArray.Create;
  for I := 0 to High(Materials) do
  begin
    Item := TJSONObject.Create;
    Item.Add('id', Materials[I].Id);
    Item.Add('name', Materials[I].Name);
    Item.Add('color_hex', Materials[I].ColorHex);
    Item.Add('roughness', Materials[I].Roughness);
    Item.Add('metallic', Materials[I].Metallic);
    Item.Add('texture_id', Materials[I].TextureId);
    Item.Add('scale_x_mm', Materials[I].ScaleXMM);
    Item.Add('scale_y_mm', Materials[I].ScaleYMM);
    Arr.Add(Item);
  end;
  Result.Add('materials', Arr);
end;

procedure TEAModel.FromJSON(O: TJSONObject);
var
  Arr: TJSONArray;
  Item, Src: TJSONObject;
  I: Integer;
  Temp: TEAModel;
begin
  if O = nil then raise EEAPackageError.Create('Modelo JSON nulo');
  if O.Get('units', 'mm') <> 'mm' then
    raise EEAPackageError.Create('Unidade do modelo diferente de mm');
  Temp := TEAModel.Create;
  try
    Temp.SchemaVersion := O.Get('schema_version', '1.0');
    Temp.ProjectId := O.Get('project_id', 'projeto-001');
    Temp.ProjectName := O.Get('project_name', 'Projeto');
    Temp.Revision := O.Get('revision', 'rev-001');
    Temp.Units := 'mm';
    if (O.Find('source') <> nil) and (O.Find('source') is TJSONObject) then
    begin
      Src := O.Objects['source'];
      Temp.SourceFile := Src.Get('file', '');
      Temp.SourceHash := Src.Get('hash', '');
    end;
    if (O.Find('floors') <> nil) and (O.Find('floors') is TJSONArray) then
    begin
      Arr := O.Arrays['floors'];
      SetLength(Temp.Floors, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Objects[I];
        Temp.Floors[I].Id := Item.Get('id', 'terreo');
        Temp.Floors[I].Name := Item.Get('name', 'Térreo');
        Temp.Floors[I].ElevationMM := Item.Get('elevation_mm', 0.0);
        Temp.Floors[I].WallHeightMM := Item.Get('wall_height_mm', 2800.0);
        Temp.Floors[I].SlabThicknessMM := Item.Get('slab_thickness_mm', 150.0);
        Temp.Floors[I].OffsetXMM := Item.Get('offset_x_mm', 0.0);
        Temp.Floors[I].OffsetYMM := Item.Get('offset_y_mm', 0.0);
      end;
    end;
    if (O.Find('walls') <> nil) and (O.Find('walls') is TJSONArray) then
    begin
      Arr := O.Arrays['walls'];
      SetLength(Temp.Walls, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Objects[I];
        Temp.Walls[I].Id := Item.Get('id', Format('wall-%d', [I + 1]));
        Temp.Walls[I].FloorId := Item.Get('floor_id', 'terreo');
        Temp.Walls[I].StartMM := ReadVec2(Item.Get('start_mm', TJSONArray(nil)));
        Temp.Walls[I].EndMM := ReadVec2(Item.Get('end_mm', TJSONArray(nil)));
        Temp.Walls[I].ThicknessMM := Item.Get('thickness_mm', 150.0);
        Temp.Walls[I].HeightMM := Item.Get('height_mm', 2800.0);
        Temp.Walls[I].MaterialId := Item.Get('material_id', 'mat_parede_padrao');
        Temp.Walls[I].Layer := Item.Get('layer', 'ARQ_PAREDES');
        if (Item.Find('source') <> nil) and (Item.Find('source') is TJSONObject) then
        begin
          Src := Item.Objects['source'];
          Temp.Walls[I].SourceFormat := Src.Get('format', '');
          Temp.Walls[I].SourceExternalId := Src.Get('external_id', '');
        end;
      end;
    end;
    if (O.Find('openings') <> nil) and (O.Find('openings') is TJSONArray) then
    begin
      Arr := O.Arrays['openings'];
      SetLength(Temp.Openings, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Objects[I];
        Temp.Openings[I].Id := Item.Get('id', Format('open-%d', [I + 1]));
        Temp.Openings[I].WallId := Item.Get('wall_id', '');
        Temp.Openings[I].FloorId := Item.Get('floor_id', 'terreo');
        Temp.Openings[I].Kind := EAStrToOpeningKind(Item.Get('kind', 'door'));
        Temp.Openings[I].OffsetAlongMM := Item.Get('offset_along_mm', 0.0);
        Temp.Openings[I].WidthMM := Item.Get('width_mm', 900.0);
        Temp.Openings[I].HeightMM := Item.Get('height_mm', 2100.0);
        Temp.Openings[I].SillMM := Item.Get('sill_mm', 0.0);
        Temp.Openings[I].SwingDeg := Item.Get('swing_deg', 90.0);
        Temp.Openings[I].MaterialId := Item.Get('material_id', '');
      end;
    end;
    if (O.Find('slabs') <> nil) and (O.Find('slabs') is TJSONArray) then
    begin
      Arr := O.Arrays['slabs'];
      SetLength(Temp.Slabs, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Objects[I];
        Temp.Slabs[I].Id := Item.Get('id', Format('slab-%d', [I + 1]));
        Temp.Slabs[I].FloorId := Item.Get('floor_id', 'terreo');
        Temp.Slabs[I].Polygon := ReadPoly(Item.Get('polygon', TJSONArray(nil)));
        Temp.Slabs[I].ThicknessMM := Item.Get('thickness_mm', 150.0);
        Temp.Slabs[I].ElevationOffsetMM := Item.Get('elevation_offset_mm', 0.0);
        Temp.Slabs[I].MaterialId := Item.Get('material_id', 'mat_piso_padrao');
      end;
    end;
    if (O.Find('rooms') <> nil) and (O.Find('rooms') is TJSONArray) then
    begin
      Arr := O.Arrays['rooms'];
      SetLength(Temp.Rooms, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Objects[I];
        Temp.Rooms[I].Id := Item.Get('id', Format('room-%d', [I + 1]));
        Temp.Rooms[I].FloorId := Item.Get('floor_id', 'terreo');
        Temp.Rooms[I].Name := Item.Get('name', 'Ambiente');
        Temp.Rooms[I].Polygon := ReadPoly(Item.Get('polygon', TJSONArray(nil)));
        Temp.Rooms[I].AreaM2 := Item.Get('area_m2', 0.0);
        Temp.Rooms[I].PerimeterM := Item.Get('perimeter_m', 0.0);
        Temp.Rooms[I].CentroidMM := ReadVec2(Item.Get('centroid_mm', TJSONArray(nil)));
      end;
    end;
    if (O.Find('stairs') <> nil) and (O.Find('stairs') is TJSONArray) then
    begin
      Arr := O.Arrays['stairs'];
      SetLength(Temp.Stairs, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Objects[I];
        Temp.Stairs[I].Id := Item.Get('id', Format('stair-%d', [I + 1]));
        Temp.Stairs[I].FromFloorId := Item.Get('from_floor_id', 'terreo');
        Temp.Stairs[I].ToFloorId := Item.Get('to_floor_id', '');
        Temp.Stairs[I].StartMM := ReadVec2(Item.Get('start_mm', TJSONArray(nil)));
        Temp.Stairs[I].EndMM := ReadVec2(Item.Get('end_mm', TJSONArray(nil)));
        Temp.Stairs[I].WidthMM := Item.Get('width_mm', 1200.0);
        Temp.Stairs[I].StepCount := Item.Get('step_count', 14);
      end;
    end;
    if (O.Find('materials') <> nil) and (O.Find('materials') is TJSONArray) then
    begin
      Arr := O.Arrays['materials'];
      SetLength(Temp.Materials, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Objects[I];
        Temp.Materials[I].Id := Item.Get('id', '');
        Temp.Materials[I].Name := Item.Get('name', '');
        Temp.Materials[I].ColorHex := Item.Get('color_hex', 'CCCCCC');
        Temp.Materials[I].Roughness := Item.Get('roughness', 0.7);
        Temp.Materials[I].Metallic := Item.Get('metallic', 0.0);
        Temp.Materials[I].TextureId := Item.Get('texture_id', '');
        Temp.Materials[I].ScaleXMM := Item.Get('scale_x_mm', 1000.0);
        Temp.Materials[I].ScaleYMM := Item.Get('scale_y_mm', 1000.0);
      end;
    end;
    Assign(Temp);
  finally
    Temp.Free;
  end;
end;

procedure TEAModel.SaveToPackageFile(const FileName, CreatedByApp: string);
var
  Pkg: TEAPackageManifest;
  MJson: TJSONObject;
begin
  Pkg := TEAPackageManifest.Create;
  MJson := ToJSON;
  try
    Pkg.PackageType := EA_PKG_ARQUITETURA_2D;
    Pkg.PackageId := ProjectId;
    Pkg.Revision := Revision;
    Pkg.CreatedByApp := CreatedByApp;
    Pkg.AddFileRef(ExtractFileName(FileName), EASHA256String(MJson.FormatJSON));
    Pkg.Payload := MJson;
    MJson := nil;
    Pkg.SaveToFile(FileName);
  finally
    MJson.Free;
    Pkg.Free;
  end;
end;

procedure TEAModel.LoadFromPackageFile(const FileName: string);
var
  Pkg: TEAPackageManifest;
  SL: TStringList;
  Data: TJSONData;
begin
  EACheckSupportedExternalFile(FileName);
  Pkg := TEAPackageManifest.Create;
  try
    try
      Pkg.LoadFromFile(FileName);
      if Pkg.Payload <> nil then
      begin
        FromJSON(Pkg.Payload);
        Exit;
      end;
    except
      on E: EEAPackageError do
      begin
        { Permite também ler um ea_modelo puro em JSON caso não tenha envelope de pacote }
        SL := TStringList.Create;
        try
          SL.LoadFromFile(FileName);
          Data := GetJSON(SL.Text);
          try
            if (Data is TJSONObject) and (TJSONObject(Data).Find('walls') <> nil) then
            begin
              FromJSON(TJSONObject(Data));
              Exit;
            end;
          finally
            Data.Free;
          end;
        finally
          SL.Free;
        end;
        raise;
      end;
    end;
    raise EEAPackageError.Create('Pacote não contém dados do modelo arquitetônico');
  finally
    Pkg.Free;
  end;
end;

function EACompareModels(OldModel, NewModel: TEAModel): TEAModelDiffArray;
  procedure AddDiff(const AKind, AId: string; DKind: TEAModelDiffKind; const ADesc: string);
  var
    N: Integer;
  begin
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N].EntityKind := AKind;
    Result[N].EntityId := AId;
    Result[N].DiffKind := DKind;
    Result[N].Description := ADesc;
  end;
var
  I, J: Integer;
begin
  Result := nil;
  if (OldModel = nil) or (NewModel = nil) then Exit;
  for I := 0 to High(NewModel.Walls) do
  begin
    J := OldModel.FindWall(NewModel.Walls[I].Id);
    if J < 0 then
      AddDiff('wall', NewModel.Walls[I].Id, mdkAdded, 'Parede adicionada: ' + NewModel.Walls[I].Id)
    else if (not EAV2Equal(OldModel.Walls[J].StartMM, NewModel.Walls[I].StartMM, 0.1)) or
            (not EAV2Equal(OldModel.Walls[J].EndMM, NewModel.Walls[I].EndMM, 0.1)) or
            (Abs(OldModel.Walls[J].ThicknessMM - NewModel.Walls[I].ThicknessMM) > 0.1) or
            (Abs(OldModel.Walls[J].HeightMM - NewModel.Walls[I].HeightMM) > 0.1) then
      AddDiff('wall', NewModel.Walls[I].Id, mdkModified, 'Parede alterada: ' + NewModel.Walls[I].Id);
  end;
  for I := 0 to High(OldModel.Walls) do
    if NewModel.FindWall(OldModel.Walls[I].Id) < 0 then
      AddDiff('wall', OldModel.Walls[I].Id, mdkRemoved, 'Parede removida: ' + OldModel.Walls[I].Id);

  for I := 0 to High(NewModel.Openings) do
  begin
    J := OldModel.FindOpening(NewModel.Openings[I].Id);
    if J < 0 then
      AddDiff('opening', NewModel.Openings[I].Id, mdkAdded, 'Abertura adicionada: ' + NewModel.Openings[I].Id)
    else if (OldModel.Openings[J].WallId <> NewModel.Openings[I].WallId) or
            (Abs(OldModel.Openings[J].OffsetAlongMM - NewModel.Openings[I].OffsetAlongMM) > 0.1) or
            (Abs(OldModel.Openings[J].WidthMM - NewModel.Openings[I].WidthMM) > 0.1) then
      AddDiff('opening', NewModel.Openings[I].Id, mdkModified, 'Abertura alterada: ' + NewModel.Openings[I].Id);
  end;
  for I := 0 to High(OldModel.Openings) do
    if NewModel.FindOpening(OldModel.Openings[I].Id) < 0 then
      AddDiff('opening', OldModel.Openings[I].Id, mdkRemoved, 'Abertura removida: ' + OldModel.Openings[I].Id);
end;

end.
