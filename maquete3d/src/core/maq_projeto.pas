unit maq_projeto;

{ Maquete 3D - Núcleo do projeto tridimensional (etapas M1..M5).
  Implementa docs/Maquete_3D.md e integrações I-03, I-06, I-08, I-11, I-12,
  I-13, I-14, I-18, I-19, I-22, I-23 de docs/Integracoes.md. }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, fpjson, jsonparser,
  ea_geometria, ea_pacote, ea_modelo, ea_ancoras, ea_malha3d, ea_fileio,
  cad_document, cad2d_importador, cad_interop,
  maq_texturas, maq_objetos;

type
  TMAQExternalSegment = record
    Id: string;
    Discipline: string; // 'electrical' ou 'plumbing'
    P0, P1: TEAVec3;
    RadiusMM: Double;
    ColorRGB: LongWord;
  end;

  TMAQCoordRequest = record
    Id: string;
    Discipline: string;
    Description: string;
    CenterMM: TEAVec3;
    SizeMM: TEAVec3;
    Status: string; // 'pendente', 'aprovada', 'recusada'
  end;

  TMAQProject = class
  public
    Model: TEAModel;
    Skins: TMAQSkinLibrary;
    Objects: TMAQObjectLibrary;
    Instances: array of TMAQObjectInstance;
    HiddenFloors: TStringList;
    ExternalSegments: array of TMAQExternalSegment;
    CoordRequests: array of TMAQCoordRequest;
    Alerts: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure LoadDemoTwoFloors;
    procedure ImportArchitecture2D(const FileName, TargetFloorId, TargetFloorName: string;
      ElevationMM: Double; ReviewDiff: Boolean; out DiffSummary: string);
    procedure ImportCADOrBIMFloor(const FileName, FloorId, FloorName: string;
      ElevationMM: Double);
    function InsertObjectInstance(const AssetId, FloorId, HostId: string;
      HostKind: TEAAnchorHostKind; const OffsetMM: TEAVec3; YawDeg: Double = 0.0;
      const SkinOverrideId: string = ''): Integer;
    function ReconcileAnchors: Integer;
    procedure ApplyObjectTextureLinkPackage(const FileName: string);
    procedure ImportDisciplineOverlay(const FileName: string);
    function DetectDisciplineClashes: Integer;
    procedure SetFloorVisible(const FloorId: string; Visible: Boolean);
    function IsFloorVisible(const FloorId: string): Boolean;
    procedure BuildCompositeMesh(Target: TEAMesh3D; IncludeExternal: Boolean = True);
    procedure SaveMaqueteFile(const FileName: string);
    procedure LoadMaqueteFile(const FileName: string);
    procedure ExportMaquetePackage(const FileName: string);
  end;

implementation

constructor TMAQProject.Create;
begin
  inherited Create;
  Model := TEAModel.Create;
  Skins := TMAQSkinLibrary.Create;
  Objects := TMAQObjectLibrary.Create;
  HiddenFloors := TStringList.Create;
  Alerts := TStringList.Create;
  Clear;
end;

destructor TMAQProject.Destroy;
begin
  Alerts.Free;
  HiddenFloors.Free;
  Objects.Free;
  Skins.Free;
  Model.Free;
  inherited Destroy;
end;

procedure TMAQProject.Clear;
begin
  Model.Clear;
  Skins.InitDefaults;
  Objects.InitDefaults(Skins);
  SetLength(Instances, 0);
  SetLength(ExternalSegments, 0);
  SetLength(CoordRequests, 0);
  HiddenFloors.Clear;
  Alerts.Clear;
end;

procedure TMAQProject.LoadDemoTwoFloors;
var
  Poly: TEAVec2Array;
begin
  Clear;
  Model.ProjectId := 'maquete-demo-01';
  Model.ProjectName := 'Edificação Demonstrativa 2 Pavimentos';
  Model.AddFloor('terreo', 'Térreo', 0, 2800, 150);
  Model.AddFloor('piso1', 'Pavimento Superior', 3000, 2800, 150);

  Model.AddWall('w1', 'terreo', EAV2(0, 0), EAV2(6000, 0), 150, 2800);
  Model.AddWall('w2', 'terreo', EAV2(6000, 0), EAV2(6000, 4500), 150, 2800);
  Model.AddWall('w3', 'terreo', EAV2(6000, 4500), EAV2(0, 4500), 150, 2800);
  Model.AddWall('w4', 'terreo', EAV2(0, 4500), EAV2(0, 0), 150, 2800);
  Model.AddOpening('d1', 'w1', 'terreo', eokDoor, 1200, 900, 2100, 0);
  Model.AddOpening('j1', 'w2', 'terreo', eokWindow, 1400, 1500, 1200, 900);

  Model.AddWall('w5', 'piso1', EAV2(0, 0), EAV2(6000, 0), 150, 2800);
  Model.AddWall('w6', 'piso1', EAV2(6000, 0), EAV2(6000, 4500), 150, 2800);
  Model.AddWall('w7', 'piso1', EAV2(6000, 4500), EAV2(0, 4500), 150, 2800);
  Model.AddWall('w8', 'piso1', EAV2(0, 4500), EAV2(0, 0), 150, 2800);
  Model.AddOpening('j2', 'w5', 'piso1', eokWindow, 2200, 1500, 1200, 900);

  Model.AddStair('esc1', 'terreo', 'piso1', EAV2(800, 3600), EAV2(3800, 3600), 1100, 14);
  SetLength(Poly, 4);
  Poly[0] := EAV2(0, 0); Poly[1] := EAV2(6000, 0); Poly[2] := EAV2(6000, 4500); Poly[3] := EAV2(0, 4500);
  Model.AddSlab('laje-terreo', 'terreo', Poly, 150);
  Model.AddSlab('laje-piso1', 'piso1', Poly, 150);
  Model.AddRoom('amb-terreo', 'terreo', 'Recepção', Poly);
  Model.AddRoom('amb-piso1', 'piso1', 'Consultório Superior', Poly);

  InsertObjectInstance('mesa_1200x700', 'terreo', 'terreo', ahkFloor, EAV3(3000, 2200, 0), 0, 'madeira_carvalho');
  InsertObjectInstance('mesa_1200x700', 'piso1', 'piso1', ahkFloor, EAV3(3000, 2200, 0), 90, 'marmore_carrara');
end;

procedure TMAQProject.ImportArchitecture2D(const FileName, TargetFloorId, TargetFloorName: string;
  ElevationMM: Double; ReviewDiff: Boolean; out DiffSummary: string);
var
  Incoming, OldCopy: TEAModel;
  Diffs: TEAModelDiffArray;
  I, Orphans: Integer;
  HasPrevWalls: Boolean;
begin
  DiffSummary := '';
  EACheckSupportedExternalFile(FileName);
  Incoming := TEAModel.Create;
  OldCopy := TEAModel.Create;
  try
    Incoming.LoadFromPackageFile(FileName);
    OldCopy.Assign(Model);
    HasPrevWalls := Length(Model.Walls) > 0;

    if TargetFloorId <> '' then
    begin
      if Model.FindFloor(TargetFloorId) < 0 then
        Model.AddFloor(TargetFloorId, TargetFloorName, ElevationMM, 2800, 150);
      { Substitui paredes/aberturas apenas do pavimento alvo, preservando outros pavimentos }
      for I := High(Model.Walls) downto 0 do
        if Model.Walls[I].FloorId = TargetFloorId then
        begin
          if I < High(Model.Walls) then Model.Walls[I] := Model.Walls[High(Model.Walls)];
          SetLength(Model.Walls, High(Model.Walls));
        end;
      for I := High(Model.Openings) downto 0 do
        if Model.Openings[I].FloorId = TargetFloorId then
        begin
          if I < High(Model.Openings) then Model.Openings[I] := Model.Openings[High(Model.Openings)];
          SetLength(Model.Openings, High(Model.Openings));
        end;
      for I := 0 to High(Incoming.Walls) do
        Model.AddWall(TargetFloorId + '_' + Incoming.Walls[I].Id, TargetFloorId,
          Incoming.Walls[I].StartMM, Incoming.Walls[I].EndMM,
          Incoming.Walls[I].ThicknessMM, Incoming.Walls[I].HeightMM, Incoming.Walls[I].Layer);
      for I := 0 to High(Incoming.Openings) do
        Model.AddOpening(TargetFloorId + '_' + Incoming.Openings[I].Id,
          TargetFloorId + '_' + Incoming.Openings[I].WallId, TargetFloorId,
          Incoming.Openings[I].Kind, Incoming.Openings[I].OffsetAlongMM,
          Incoming.Openings[I].WidthMM, Incoming.Openings[I].HeightMM, Incoming.Openings[I].SillMM);
    end
    else
      Model.Assign(Incoming);

    Model.AutoGenerateSlabsAndRooms;
    if HasPrevWalls and ReviewDiff then
    begin
      Diffs := EACompareModels(OldCopy, Model);
      DiffSummary := Format('%d alteração(ões) detectada(s) na revisão.', [Length(Diffs)]);
      for I := 0 to Min(High(Diffs), 9) do
        DiffSummary := DiffSummary + LineEnding + ' - ' + Diffs[I].Description;
    end
    else
      DiffSummary := Format('Importado pavimento com %d paredes e %d aberturas.', [Length(Model.Walls), Length(Model.Openings)]);

    Orphans := ReconcileAnchors;
    if Orphans > 0 then
      Alerts.Add(Format('%d instância(s) com âncora órfã após atualização da planta.', [Orphans]));
  finally
    OldCopy.Free;
    Incoming.Free;
  end;
end;

procedure TMAQProject.ImportCADOrBIMFloor(const FileName, FloorId, FloorName: string;
  ElevationMM: Double);
var
  CadDoc: TCADDocument;
  Fmt: TFileFormat;
  Ver, DiffSum: string;
  Entities: array[0..8191] of TImportedEntity;
  Count: Integer;
  Report: TImportReport;
  Lines: TCADLines;
  Labels: TCADLabels;
  TempPkg: string;
  G: TGUID;
  TempM: TEAModel;
begin
  EACheckSupportedExternalFile(FileName);
  Fmt := DetectFormat(FileName, Ver);
  Lines := nil;
  SetLength(Labels, 0);
  if Fmt = fmtEACAD then
  begin
    CadDoc := TCADDocument.Create;
    try
      CadDoc.Load(FileName);
      Lines := CadDoc.Lines;
      Labels := CadDoc.Labels;
    finally
      CadDoc.Free;
    end;
  end
  else
  begin
    InitReport(Report, FileName);
    try
      case Fmt of
        fmtDXF: if not ImportDXF(FileName, Entities, Count, Report, 1) then raise EEAPackageError.Create('Falha DXF');
        fmtDWG: if not ImportDWG(FileName, Entities, Count, Report, 1) then raise EEAPackageError.Create('Falha DWG: ' + Report.Errors.Text);
        fmtIFC: if not ImportIFC(FileName, '', Entities, Count, Report, 1) then raise EEAPackageError.Create('Falha IFC');
      else
        raise EEAPackageError.Create('Formato não suportado para importação de planta: ' + ExtractFileExt(FileName));
      end;
      Lines := CADConvertImportedEntities(Entities, Count, 1);
    finally
      FreeReport(Report);
    end;
  end;

  CreateGUID(G);
  TempPkg := GetTempDir(False) + 'maq-imp-' + GUIDToString(G) + '.ea2d.json';
  TempM := CADBuildModelFromLines(Lines, Labels, FloorName);
  try
    TempM.SaveToPackageFile(TempPkg, 'Maquete3D');
    ImportArchitecture2D(TempPkg, FloorId, FloorName, ElevationMM, True, DiffSum);
  finally
    TempM.Free;
    if FileExists(TempPkg) then DeleteFile(TempPkg);
  end;
end;

function TMAQProject.InsertObjectInstance(const AssetId, FloorId, HostId: string;
  HostKind: TEAAnchorHostKind; const OffsetMM: TEAVec3; YawDeg: Double;
  const SkinOverrideId: string): Integer;
var
  Idx: Integer;
begin
  Idx := Objects.FindAsset(AssetId);
  if Idx < 0 then
    raise EEAPackageError.Create('Objeto não encontrado na biblioteca: ' + AssetId);
  Result := Length(Instances);
  SetLength(Instances, Result + 1);
  Instances[Result].InstanceId := Format('inst-%d', [Result + 1]);
  Instances[Result].AssetId := AssetId;
  Instances[Result].AssetVersion := Objects.Assets[Idx].Version;
  Instances[Result].Anchor.AnchorId := Format('anc-%d', [Result + 1]);
  Instances[Result].Anchor.TargetId := Instances[Result].InstanceId;
  Instances[Result].Anchor.FloorId := FloorId;
  Instances[Result].Anchor.HostId := HostId;
  Instances[Result].Anchor.HostKind := HostKind;
  Instances[Result].Anchor.OffsetMM := OffsetMM;
  Instances[Result].Anchor.YawDeg := YawDeg;
  Instances[Result].ScaleXYZ := EAV3(1, 1, 1);
  Instances[Result].OverrideSkinId := SkinOverrideId;
  Instances[Result].Visible := True;
  EAResolveAnchor(Instances[Result].Anchor, Model);
end;

function TMAQProject.ReconcileAnchors: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(Instances) do
    if not EAResolveAnchor(Instances[I].Anchor, Model) then
      Inc(Result);
end;

procedure TMAQProject.ApplyObjectTextureLinkPackage(const FileName: string);
var
  Pkg: TEAPackageManifest;
  ObjId, TexId, Dest: string;
  FaceGrp, I, AIdx: Integer;
  Arr: TJSONArray;
  Item: TJSONObject;
begin
  Pkg := TEAPackageManifest.Create;
  try
    Pkg.LoadFromFile(FileName);
    if (Pkg.PackageType <> EA_PKG_TEXTURA) or (Pkg.Payload = nil) then
      raise EEAPackageError.Create('Pacote não contém vínculo objeto-textura');
    ObjId := Pkg.Payload.Get('object_id', '');
    Arr := Pkg.Payload.Get('texturas', TJSONArray(nil));
    if Arr = nil then Exit;
    for I := 0 to High(Instances) do
    begin
      if (Instances[I].InstanceId = ObjId) or (Instances[I].AssetId = ObjId) then
      begin
        AIdx := Objects.FindAsset(Instances[I].AssetId);
        for FaceGrp := 0 to Arr.Count - 1 do
        begin
          Item := Arr.Objects[FaceGrp];
          TexId := Item.Get('textura_id', '');
          Dest := Item.Get('destino', 'objeto');
          if Dest = 'objeto' then
          begin
            Instances[I].OverrideSkinId := TexId;
            if AIdx >= 0 then Objects.Assets[AIdx].AssignSkinToObject(TexId, Skins);
          end
          else if AIdx >= 0 then
            Objects.Assets[AIdx].AssignSkinToFace(StrToIntDef(Item.Get('face_id', '0'), 0), TexId, Skins);
        end;
      end;
    end;
  finally
    Pkg.Free;
  end;
end;

procedure TMAQProject.ImportDisciplineOverlay(const FileName: string);
var
  Pkg: TEAPackageManifest;
  Arr: TJSONArray;
  Item, P0, P1: TJSONObject;
  I, N: Integer;
  Disc: string;
  Col: LongWord;
begin
  Pkg := TEAPackageManifest.Create;
  try
    Pkg.LoadFromFile(FileName);
    if Pkg.Payload = nil then Exit;
    if (Pkg.PackageType <> EA_PKG_CAMADA_ELETRICA) and (Pkg.PackageType <> EA_PKG_REDE_TUBULACOES) then
      raise EEAPackageError.Create('Disciplina incompatível: esperado camada_eletrica ou rede_tubulacoes');
    if Pkg.PackageType = EA_PKG_CAMADA_ELETRICA then
    begin
      Disc := 'electrical'; Col := $FACC15;
    end
    else
    begin
      Disc := 'plumbing'; Col := $06B6D4;
    end;
    Arr := Pkg.Payload.Get('segments', TJSONArray(nil));
    if Arr = nil then Arr := Pkg.Payload.Get('routes', TJSONArray(nil));
    if Arr = nil then Exit;
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Objects[I];
      P0 := Item.Get('p0_mm', TJSONObject(nil));
      P1 := Item.Get('p1_mm', TJSONObject(nil));
      if (P0 = nil) or (P1 = nil) then Continue;
      N := Length(ExternalSegments);
      SetLength(ExternalSegments, N + 1);
      ExternalSegments[N].Id := Item.Get('id', Format('%s-%d', [Disc, I + 1]));
      ExternalSegments[N].Discipline := Disc;
      ExternalSegments[N].P0 := EAV3(P0.Get('x', 0.0), P0.Get('y', 0.0), P0.Get('z', 0.0));
      ExternalSegments[N].P1 := EAV3(P1.Get('x', 0.0), P1.Get('y', 0.0), P1.Get('z', 0.0));
      ExternalSegments[N].RadiusMM := Max(10.0, Item.Get('diameter_mm', 25.0) * 0.5);
      ExternalSegments[N].ColorRGB := Col;
    end;
  finally
    Pkg.Free;
  end;
end;

function TMAQProject.DetectDisciplineClashes: Integer;
var
  I, J, K: Integer;
  P1, P2: TEAVec3;
  D: Double;
begin
  Result := 0;
  SetLength(CoordRequests, 0);
  for I := 0 to High(ExternalSegments) do
    for J := I + 1 to High(ExternalSegments) do
    begin
      if ExternalSegments[I].Discipline = ExternalSegments[J].Discipline then Continue;
      D := EASegmentDistance3D(ExternalSegments[I].P0, ExternalSegments[I].P1,
        ExternalSegments[J].P0, ExternalSegments[J].P1, P1, P2);
      if D < (ExternalSegments[I].RadiusMM + ExternalSegments[J].RadiusMM + 10.0) then
      begin
        K := Length(CoordRequests);
        SetLength(CoordRequests, K + 1);
        CoordRequests[K].Id := Format('clash-%d', [K + 1]);
        CoordRequests[K].Discipline := 'eletrica x tubulacoes';
        CoordRequests[K].Description := Format('Interferência entre %s e %s (distância %.1f mm)',
          [ExternalSegments[I].Id, ExternalSegments[J].Id, D]);
        CoordRequests[K].CenterMM := EAV3Scale(EAV3Add(P1, P2), 0.5);
        CoordRequests[K].SizeMM := EAV3(100, 100, 100);
        CoordRequests[K].Status := 'pendente';
        Inc(Result);
      end;
    end;
end;

procedure TMAQProject.SetFloorVisible(const FloorId: string; Visible: Boolean);
var
  Idx: Integer;
begin
  Idx := HiddenFloors.IndexOf(FloorId);
  if Visible and (Idx >= 0) then HiddenFloors.Delete(Idx)
  else if (not Visible) and (Idx < 0) then HiddenFloors.Add(FloorId);
end;

function TMAQProject.IsFloorVisible(const FloorId: string): Boolean;
begin
  Result := HiddenFloors.IndexOf(FloorId) < 0;
end;

procedure TMAQProject.BuildCompositeMesh(Target: TEAMesh3D; IncludeExternal: Boolean);
var
  I, AIdx, FIdx: Integer;
  TempModel: TEAModel;
  S: TMAQSkin;
  OverrideCol: Boolean;
  Col: LongWord;
begin
  Target.Clear;
  TempModel := TEAModel.Create;
  try
    TempModel.Assign(Model);
    { Filtra pavimentos ocultos }
    for I := High(TempModel.Walls) downto 0 do
      if not IsFloorVisible(TempModel.Walls[I].FloorId) then
      begin
        if I < High(TempModel.Walls) then TempModel.Walls[I] := TempModel.Walls[High(TempModel.Walls)];
        SetLength(TempModel.Walls, High(TempModel.Walls));
      end;
    for I := High(TempModel.Slabs) downto 0 do
      if not IsFloorVisible(TempModel.Slabs[I].FloorId) then
      begin
        if I < High(TempModel.Slabs) then TempModel.Slabs[I] := TempModel.Slabs[High(TempModel.Slabs)];
        SetLength(TempModel.Slabs, High(TempModel.Slabs));
      end;
    EABuildModelMesh(TempModel, Target);
  finally
    TempModel.Free;
  end;

  { Instancias de objetos 3D }
  for I := 0 to High(Instances) do
  begin
    if not Instances[I].Visible then Continue;
    if not IsFloorVisible(Instances[I].Anchor.FloorId) then Continue;
    AIdx := Objects.FindAsset(Instances[I].AssetId);
    if AIdx < 0 then Continue;
    OverrideCol := False;
    Col := $FFFFFF;
    if (Instances[I].OverrideSkinId <> '') and Skins.GetById(Instances[I].OverrideSkinId, S) then
    begin
      OverrideCol := True;
      Col := S.BaseColorRGB;
    end;
    Target.AppendMesh(Objects.Assets[AIdx].Mesh, Instances[I].Anchor.WorldPosMM,
      Instances[I].ScaleXYZ, Instances[I].Anchor.YawDeg, OverrideCol, Col, Instances[I].InstanceId);
  end;

  { Disciplinas externas vinculadas (Elétrica / Tubulações) }
  if IncludeExternal then
    for I := 0 to High(ExternalSegments) do
      Target.AddPipeSegment(ExternalSegments[I].P0, ExternalSegments[I].P1,
        ExternalSegments[I].RadiusMM, 8, ExternalSegments[I].ColorRGB, 0, ExternalSegments[I].Id);
end;

procedure TMAQProject.SaveMaqueteFile(const FileName: string);
var
  Root, InstObj: TJSONObject;
  InstArr, AssetsArr: TJSONArray;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('schema_version', '1.0');
    Root.Add('package_type', EA_PKG_MAQUETE);
    Root.Add('model', Model.ToJSON);
    Root.Add('skins', Skins.ToJSON);
    AssetsArr := TJSONArray.Create;
    for I := 0 to High(Objects.Assets) do AssetsArr.Add(Objects.Assets[I].ToJSON);
    Root.Add('assets', AssetsArr);
    InstArr := TJSONArray.Create;
    for I := 0 to High(Instances) do
    begin
      InstObj := TJSONObject.Create;
      InstObj.Add('instance_id', Instances[I].InstanceId);
      InstObj.Add('asset_id', Instances[I].AssetId);
      InstObj.Add('asset_version', Instances[I].AssetVersion);
      InstObj.Add('anchor', EAAnchorToJSON(Instances[I].Anchor));
      InstObj.Add('override_skin_id', Instances[I].OverrideSkinId);
      InstObj.Add('visible', Instances[I].Visible);
      InstArr.Add(InstObj);
    end;
    Root.Add('instances', InstArr);
    EAAtomicWriteText(FileName, Root.FormatJSON);
  finally
    Root.Free;
  end;
end;

procedure TMAQProject.LoadMaqueteFile(const FileName: string);
var
  SL: TStringList;
  Data: TJSONData;
  Root, InstObj: TJSONObject;
  InstArr: TJSONArray;
  I: Integer;
begin
  EACheckSupportedExternalFile(FileName);
  SL := TStringList.Create;
  try
    SL.LoadFromFile(FileName);
    Data := GetJSON(SL.Text);
  finally
    SL.Free;
  end;
  try
    if not (Data is TJSONObject) then raise EEAPackageError.Create('Arquivo de maquete inválido');
    Root := TJSONObject(Data);
    Clear;
    if (Root.Find('model') <> nil) and (Root.Find('model') is TJSONObject) then
      Model.FromJSON(Root.Objects['model']);
    if (Root.Find('skins') <> nil) and (Root.Find('skins') is TJSONArray) then
      Skins.FromJSON(Root.Arrays['skins']);
    InstArr := Root.Get('instances', TJSONArray(nil));
    if InstArr <> nil then
    begin
      SetLength(Instances, InstArr.Count);
      for I := 0 to InstArr.Count - 1 do
      begin
        InstObj := InstArr.Objects[I];
        Instances[I].InstanceId := InstObj.Get('instance_id', '');
        Instances[I].AssetId := InstObj.Get('asset_id', '');
        Instances[I].AssetVersion := InstObj.Get('asset_version', '1.0');
        Instances[I].Anchor := EAAnchorFromJSON(InstObj.Objects['anchor']);
        Instances[I].ScaleXYZ := EAV3(1, 1, 1);
        Instances[I].OverrideSkinId := InstObj.Get('override_skin_id', '');
        Instances[I].Visible := InstObj.Get('visible', True);
      end;
    end;
    ReconcileAnchors;
  finally
    Data.Free;
  end;
end;

procedure TMAQProject.ExportMaquetePackage(const FileName: string);
var
  Pkg: TEAPackageManifest;
  Payload, InstObj: TJSONObject;
  InstArr: TJSONArray;
  GlbFile, Lim: string;
  Mesh: TEAMesh3D;
  I: Integer;
begin
  GlbFile := ChangeFileExt(FileName, '.glb');
  Mesh := TEAMesh3D.Create;
  try
    BuildCompositeMesh(Mesh, False);
    if Mesh.TriangleCount > 0 then
      EAExportGLB(Mesh, GlbFile, Lim);
  finally
    Mesh.Free;
  end;

  Pkg := TEAPackageManifest.Create;
  Payload := TJSONObject.Create;
  try
    Pkg.PackageType := EA_PKG_MAQUETE;
    Pkg.PackageId := Model.ProjectId;
    Pkg.Revision := Model.Revision;
    Pkg.CreatedByApp := 'Maquete3D';
    if FileExists(GlbFile) then
      Pkg.AddFileRef(ExtractFileName(GlbFile), EASHA256File(GlbFile));

    Payload.Add('model', Model.ToJSON);
    Payload.Add('skins', Skins.ToJSON);
    InstArr := TJSONArray.Create;
    for I := 0 to High(Instances) do
    begin
      InstObj := TJSONObject.Create;
      InstObj.Add('instance_id', Instances[I].InstanceId);
      InstObj.Add('asset_id', Instances[I].AssetId);
      InstObj.Add('anchor', EAAnchorToJSON(Instances[I].Anchor));
      InstObj.Add('override_skin_id', Instances[I].OverrideSkinId);
      InstArr.Add(InstObj);
    end;
    Payload.Add('instances', InstArr);
    Pkg.Payload := Payload;
    Payload := nil;
    Pkg.SaveToFile(FileName);
  finally
    Payload.Free;
    Pkg.Free;
  end;
end;

end.
