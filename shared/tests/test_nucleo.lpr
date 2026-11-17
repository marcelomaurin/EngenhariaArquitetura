program test_nucleo;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  Classes, SysUtils, Math, fpjson, zipper,
  ea_geometria, ea_pacote, ea_modelo, ea_ancoras, ea_malha3d;

var
  Checks: Integer = 0;

procedure Check(OK: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not OK then
    raise Exception.Create('FALHA: ' + Msg);
end;

procedure TestGeometria;
var
  Hit, Proj: TEAVec2;
  T: Double;
  Poly: TEAVec2Array;
  Segs: TEASegment2DArray;
  Rooms: TEARoomLoopArray;
  B1, B2: TEABox3D;
  P1, P2: TEAVec3;
begin
  Check(EAIntersectSegments2D(EAV2(0, 0), EAV2(4000, 0), EAV2(2000, -1000), EAV2(2000, 1000), Hit), 'intersecao 2D');
  Check(EAV2Equal(Hit, EAV2(2000, 0)), 'ponto de intersecao exato');
  Check(Abs(EAPointToSegmentDist2D(EAV2(1500, 500), EAV2(0, 0), EAV2(3000, 0), Proj, T) - 500.0) < 1e-4, 'distancia ponto-segmento');
  SetLength(Poly, 4);
  Poly[0] := EAV2(0, 0); Poly[1] := EAV2(4000, 0); Poly[2] := EAV2(4000, 3000); Poly[3] := EAV2(0, 3000);
  Check(Abs(EAPolygonAreaMM2(Poly) - 12000000.0) < 1.0, 'area sala 4x3m = 12 m2');
  Check(Abs(EAPolygonPerimeterMM(Poly) - 14000.0) < 1.0, 'perimetro sala 4x3m = 14 m');
  Check(EAPointInPolygon2D(EAV2(2000, 1500), Poly), 'ponto dentro do poligono');
  Check(not EAPointInPolygon2D(EAV2(4500, 1500), Poly), 'ponto fora do poligono');

  SetLength(Segs, 4);
  Segs[0].Id := 'w1'; Segs[0].A := EAV2(0, 0); Segs[0].B := EAV2(4000, 0);
  Segs[1].Id := 'w2'; Segs[1].A := EAV2(4000, 0); Segs[1].B := EAV2(4000, 3000);
  Segs[2].Id := 'w3'; Segs[2].A := EAV2(4000, 3000); Segs[2].B := EAV2(0, 3000);
  Segs[3].Id := 'w4'; Segs[3].A := EAV2(0, 3000); Segs[3].B := EAV2(0, 0);
  Rooms := EADetectClosedRooms(Segs, 25.0);
  Check(Length(Rooms) = 1, 'deteccao automatica de ambiente fechado');
  Check(Abs(Rooms[0].AreaMM2 - 12000000.0) < 10.0, 'area detectada 12 m2');

  B1 := EAMakeBox3D(EAV3(0, 0, 0), EAV3(1000, 1000, 1000));
  B2 := EAMakeBox3D(EAV3(500, 500, 500), EAV3(1500, 1500, 1500));
  Check(EABoxIntersects(B1, B2), 'colisao AABB 3D');
  Check(Abs(EASegmentDistance3D(EAV3(0, 0, 0), EAV3(1000, 0, 0), EAV3(500, -500, 200), EAV3(500, 500, 200), P1, P2) - 200.0) < 1e-4, 'distancia 3D entre segmentos');
end;

procedure TestPacote;
var
  H: string;
  Pkg, Pkg2: TEAPackageManifest;
  Tmp: string;
  G: TGUID;
  Rejected: Boolean;
begin
  H := EASHA256String('abc');
  Check(H = 'sha256-ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'vetor SHA-256 oficial');
  CreateGUID(G);
  Tmp := GetTempDir(False) + 'ea-pkg-' + GUIDToString(G) + '.json';
  Pkg := TEAPackageManifest.Create;
  Pkg2 := TEAPackageManifest.Create;
  try
    Pkg.PackageType := EA_PKG_ARQUITETURA_2D;
    Pkg.PackageId := 'pkg-test-1';
    Pkg.Revision := 'rev-002';
    Pkg.CreatedByApp := 'CAD2D';
    Pkg.AddSourceRef('pkg-src', 'rev-001', H);
    Pkg.AddFileRef('modelo.json', H);
    Pkg.SaveToFile(Tmp);
    Pkg2.LoadFromFile(Tmp);
    Check(Pkg2.PackageId = 'pkg-test-1', 'package_id preservado');
    Check(Pkg2.Revision = 'rev-002', 'revision preservada');
    Check((Length(Pkg2.SourceRefs) = 1) and (Pkg2.SourceRefs[0].Hash = H), 'source_refs preservados');
    Check(Pkg2.UpAxis = 'Z', 'eixo Z-up preservado');

    Rejected := False;
    try
      EACheckSupportedExternalFile('peca.mcad');
    except
      on E: EEAPackageError do Rejected := True;
    end;
    Check(Rejected, 'rejeita .mcad com orientacao');

    Rejected := False;
    try
      EACheckSupportedExternalFile('suite.msuite');
    except
      on E: EEAPackageError do Rejected := True;
    end;
    Check(Rejected, 'rejeita .msuite com orientacao');
  finally
    Pkg.Free;
    Pkg2.Free;
    if FileExists(Tmp) then DeleteFile(Tmp);
  end;
end;

procedure TestModeloEAncoras;
var
  M1, M2: TEAModel;
  Diffs: TEAModelDiffArray;
  Ancs: TEAAnchorArray;
  Orphans: Integer;
  Tmp: string;
  G: TGUID;
begin
  CreateGUID(G);
  Tmp := GetTempDir(False) + 'ea-model-' + GUIDToString(G) + '.ea2d.json';
  M1 := TEAModel.Create;
  M2 := TEAModel.Create;
  try
    M1.ProjectId := 'hosp-01';
    M1.AddFloor('terreo', 'Térreo', 0, 2800, 150);
    M1.AddFloor('piso1', 'Superior', 3000, 2800, 150);
    M1.AddWall('w1', 'terreo', EAV2(0, 0), EAV2(4000, 0), 150, 2800);
    M1.AddWall('w2', 'terreo', EAV2(4000, 0), EAV2(4000, 3000), 150, 2800);
    M1.AddWall('w3', 'terreo', EAV2(4000, 3000), EAV2(0, 3000), 150, 2800);
    M1.AddWall('w4', 'terreo', EAV2(0, 3000), EAV2(0, 0), 150, 2800);
    M1.AddOpening('door1', 'w1', 'terreo', eokDoor, 1200, 900, 2100, 0);
    M1.AddOpening('win1', 'w2', 'terreo', eokWindow, 900, 1200, 1200, 900);
    M1.AutoGenerateSlabsAndRooms;
    Check(Length(M1.Rooms) = 1, 'modelo gera ambiente fechado');
    Check(Abs(M1.Rooms[0].AreaM2 - 12.0) < 0.01, 'area do ambiente 12 m2');

    M1.SaveToPackageFile(Tmp, 'CAD2D');
    M2.LoadFromPackageFile(Tmp);
    Check((Length(M2.Floors) = 2) and (Length(M2.Walls) = 4) and (Length(M2.Openings) = 2), 'roundtrip modelo dois pavimentos');

    { Testa ancora presa a parede w1 }
    SetLength(Ancs, 2);
    Ancs[0].AnchorId := 'a1'; Ancs[0].TargetId := 'tomada-1'; Ancs[0].FloorId := 'terreo';
    Ancs[0].HostId := 'w1'; Ancs[0].HostKind := ahkWall; Ancs[0].OffsetMM := EAV3(1000, 75, 300);
    Ancs[1].AnchorId := 'a2'; Ancs[1].TargetId := 'mesa-1'; Ancs[1].FloorId := 'terreo';
    Ancs[1].HostId := 'w2'; Ancs[1].HostKind := ahkWall; Ancs[1].OffsetMM := EAV3(500, 0, 0);
    Orphans := EAResolveAnchors(Ancs, M2);
    Check(Orphans = 0, 'nenhuma ancora orfa inicial');
    Check(Abs(Ancs[0].WorldPosMM.X - 1000.0) < 0.1, 'posicao X ancora w1');

    { Move parede w1 em Y+500 e remove w2 }
    M2.Walls[0].StartMM.Y := 500;
    M2.Walls[0].EndMM.Y := 500;
    M2.Walls[1] := M2.Walls[3];
    SetLength(M2.Walls, 3);
    Orphans := EAResolveAnchors(Ancs, M2);
    Check(Orphans = 1, 'ancora da parede removida marcada como orfa');
    Check(Ancs[1].Status = easOrphaned, 'status easOrphaned');
    Check(Ancs[0].Status = easUpdated, 'ancora da parede movida atualizada');
    Check(Abs(Ancs[0].WorldPosMM.Y - 575.0) < 0.1, 'ancora acompanha parede deslocada');

    Diffs := EACompareModels(M1, M2);
    Check(Length(Diffs) >= 2, 'comparacao de revisoes detecta alteracao e remocao');
  finally
    M1.Free;
    M2.Free;
    if FileExists(Tmp) then DeleteFile(Tmp);
  end;
end;

procedure TestMalha3D;
var
  M: TEAModel;
  Mesh, Mesh2: TEAMesh3D;
  Lim, TmpSTL, TmpOBJ, TmpGLB, Tmp3MF, TmpXml: string;
  G: TGUID;
  Zip: TZipper;
  SL: TStringList;
begin
  CreateGUID(G);
  TmpSTL := GetTempDir(False) + 'ea-m-' + GUIDToString(G) + '.stl';
  TmpOBJ := GetTempDir(False) + 'ea-m-' + GUIDToString(G) + '.obj';
  TmpGLB := GetTempDir(False) + 'ea-m-' + GUIDToString(G) + '.glb';
  Tmp3MF := GetTempDir(False) + 'ea-m-' + GUIDToString(G) + '.3mf';
  TmpXml := GetTempDir(False) + 'ea-m-' + GUIDToString(G) + '.model';

  M := TEAModel.Create;
  Mesh := TEAMesh3D.Create;
  Mesh2 := TEAMesh3D.Create;
  try
    M.AddFloor('terreo', 'Térreo', 0, 2800, 150);
    M.AddWall('w1', 'terreo', EAV2(0, 0), EAV2(4000, 0), 150, 2800);
    M.AddOpening('d1', 'w1', 'terreo', eokDoor, 1000, 900, 2100, 0);
    EABuildModelMesh(M, Mesh);
    Check(Mesh.TriangleCount > 12, 'extrusao 3D da parede com vao de porta');
    Check(Abs(Mesh.Bounds.Max.X - 4000.0) < 1.0, 'dimensao X 4000 mm preservada');

    Mesh.Clear;
    Mesh.AddBox(EAV3(0, 0, 375), EAV3(1200, 700, 750), $8B5A2B, 0, 'mesa');
    Check(Mesh.TriangleCount = 12, 'caixa 12 triangulos');
    EAExportSTLBinary(Mesh, TmpSTL);
    EAImportSTL(TmpSTL, Mesh2);
    Check(Mesh2.TriangleCount = 12, 'roundtrip STL binario');
    Check(Abs((Mesh2.Bounds.Max.X - Mesh2.Bounds.Min.X) - 1200.0) < 0.1, 'STL preserva 1200 mm');

    EAExportOBJ(Mesh, TmpOBJ);
    EAImportOBJ(TmpOBJ, Mesh2);
    Check(Mesh2.TriangleCount = 12, 'roundtrip OBJ');

    EAExportGLB(Mesh, TmpGLB, Lim);
    Check(FileExists(TmpGLB) and (Lim <> ''), 'GLB exportado');
    EAImportGLB(TmpGLB, Mesh2);
    Check(Mesh2.TriangleCount = 12, 'roundtrip GLB');
    Check(Abs((Mesh2.Bounds.Max.X - Mesh2.Bounds.Min.X) - 1200.0) < 0.5, 'GLB preserva 1200 mm');

    { Testa 3MF real empacotado em ZIP }
    SL := TStringList.Create;
    Zip := TZipper.Create;
    try
      SL.Text :=
        '<?xml version="1.0" encoding="UTF-8"?>' + LineEnding +
        '<model unit="millimeter" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">' + LineEnding +
        '  <resources><object id="1" type="model"><mesh>' + LineEnding +
        '    <vertices>' + LineEnding +
        '      <vertex x="0" y="0" z="0"/><vertex x="500" y="0" z="0"/><vertex x="500" y="500" z="0"/><vertex x="0" y="0" z="500"/>' + LineEnding +
        '    </vertices>' + LineEnding +
        '    <triangles><triangle v1="0" v2="1" v3="2"/><triangle v1="0" v2="1" v3="3"/></triangles>' + LineEnding +
        '  </mesh></object></resources>' + LineEnding +
        '</model>';
      SL.SaveToFile(TmpXml);
      Zip.FileName := Tmp3MF;
      Zip.Entries.AddFileEntry(TmpXml, '3D/3dmodel.model');
      Zip.ZipAllFiles;
    finally
      Zip.Free;
      SL.Free;
    end;
    EAImport3MF(Tmp3MF, Mesh2);
    Check(Mesh2.TriangleCount = 2, 'importacao 3MF real');
    Check(Abs(Mesh2.Bounds.Max.Z - 500.0) < 0.1, '3MF preserva unidade mm');
  finally
    Mesh2.Free;
    Mesh.Free;
    M.Free;
    if FileExists(TmpSTL) then DeleteFile(TmpSTL);
    if FileExists(TmpOBJ) then DeleteFile(TmpOBJ);
    if FileExists(TmpGLB) then DeleteFile(TmpGLB);
    if FileExists(Tmp3MF) then DeleteFile(Tmp3MF);
    if FileExists(TmpXml) then DeleteFile(TmpXml);
  end;
end;

begin
  try
    TestGeometria;
    TestPacote;
    TestModeloEAncoras;
    TestMalha3D;
    WriteLn(Checks, ' verificacoes do Nucleo Comum, 0 falhas');
  except
    on E: Exception do
    begin
      WriteLn(E.Message);
      Halt(1);
    end;
  end;
end.
