program test_maquete3d;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  Classes, SysUtils, Types,
  ea_geometria, ea_pacote, ea_modelo, ea_ancoras, ea_malha3d,
  cad_document, cad_interop,
  maq_texturas, maq_objetos, maq_projeto;

var
  Proj: TMAQProject;
  Mesh: TEAMesh3D;
  Col1, Nor1, Rgh1, Col2, Nor2, Rgh2: TMAQPixelBuffer;
  Skin1, Skin2: TMAQSkin;
  Lines: TCADLines;
  Labels: TCADLabels;
  TmpEA2D, TmpSTL, TmpGLB, TmpSkin, TmpMaq, TmpPkg, DiffSum, Lim: string;
  G: TGUID;
  Checks: Integer = 0;

procedure Check(OK: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not OK then raise Exception.Create('FALHA: ' + Msg);
end;

begin
  CreateGUID(G);
  TmpEA2D := GetTempDir(False) + 'ea-maq-' + GUIDToString(G) + '.ea2d.json';
  TmpSTL := GetTempDir(False) + 'ea-maq-' + GUIDToString(G) + '.stl';
  TmpGLB := GetTempDir(False) + 'ea-maq-' + GUIDToString(G) + '.glb';
  TmpSkin := GetTempDir(False) + 'ea-maq-' + GUIDToString(G) + '.skin.json';
  TmpMaq := GetTempDir(False) + 'ea-maq-' + GUIDToString(G) + '.maquete.json';
  TmpPkg := GetTempDir(False) + 'ea-maq-' + GUIDToString(G) + '.maquete.pkg.json';

  Proj := TMAQProject.Create;
  Mesh := TEAMesh3D.Create;
  try
    { 1. Texturas procedurais offline com semente reproduzivel + pacote skin + PNG }
    Check(Proj.Skins.GetById('azulejo_300x600', Skin1), 'skin azulejo na biblioteca');
    Check(MAQGenerateProceduralMaps(Skin1, 64, Col1, Nor1, Rgh1), 'gera mapas PBR');
    Check(MAQGenerateProceduralMaps(Skin1, 64, Col2, Nor2, Rgh2), 'semente reproduzivel');
    Check(Col1[100] = Col2[100], 'mesma semente gera mesmo pixel');
    MAQExportSkinPackage(Skin1, 64, TmpSkin);
    Check(FileExists(TmpSkin), 'pacote de skin exportado');
    Check(FileExists(ChangeFileExt(TmpSkin, '') + '_basecolor.png'), 'PNG basecolor exportado');
    Skin2 := MAQImportSkinPackage(TmpSkin);
    Check((Skin2.Id = Skin1.Id) and (Abs(Skin2.ScaleXMM - 600.0) < 0.1), 'reimporta skin com escala 600 mm');

    { 2. Importa planta 2D de sala 4x3m com porta e janela e reconstroi 3D }
    SetLength(Lines, 5);
    Lines[0].A := Point(0, 0); Lines[0].B := Point(4000, 0); Lines[0].Kind := 2; Lines[0].WidthMM := 150; Lines[0].HeightMM := 2800; Lines[0].GroupID := 1;
    Lines[1].A := Point(4000, 0); Lines[1].B := Point(4000, 3000); Lines[1].Kind := 2; Lines[1].WidthMM := 150; Lines[1].HeightMM := 2800; Lines[1].GroupID := 2;
    Lines[2].A := Point(4000, 3000); Lines[2].B := Point(0, 3000); Lines[2].Kind := 2; Lines[2].WidthMM := 150; Lines[2].HeightMM := 2800; Lines[2].GroupID := 3;
    Lines[3].A := Point(0, 3000); Lines[3].B := Point(0, 0); Lines[3].Kind := 2; Lines[3].WidthMM := 150; Lines[3].HeightMM := 2800; Lines[3].GroupID := 4;
    Lines[4].A := Point(1000, 0); Lines[4].B := Point(1900, 0); Lines[4].Kind := 3; Lines[4].WidthMM := 900; Lines[4].HeightMM := 2100; Lines[4].GroupID := 5;
    SetLength(Labels, 0);
    CADExportModelPackage(Lines, Labels, TmpEA2D, 'Sala 4x3');

    Proj.Clear;
    Proj.ImportArchitecture2D(TmpEA2D, 'terreo', 'Térreo', 0, False, DiffSum);
    Proj.ImportArchitecture2D(TmpEA2D, 'piso1', 'Superior', 3000, False, DiffSum);
    Check(Length(Proj.Model.Floors) = 2, 'dois pavimentos alinhados');
    Check(Length(Proj.Model.Walls) = 8, 'oito paredes nos dois pavimentos');

    { 3. Inserir ancora na parede terreo_wall-1 e depois mover parede na revisao }
    Proj.InsertObjectInstance('mesa_1200x700', 'terreo', 'terreo_wall-1', ahkWall, EAV3(1500, 500, 0), 0, 'madeira_carvalho');
    Check(Length(Proj.Instances) = 1, 'instancia inserida');

    { 4. Importar STL externo, aplicar skin e exportar GLB }
    Mesh.Clear;
    Mesh.AddBox(EAV3(0, 0, 250), EAV3(500, 500, 500), $CCCCCC, 0, 'cubo');
    EAExportSTLBinary(Mesh, TmpSTL);
    Proj.Objects.ImportExternalSolid(TmpSTL, 'cubo_stl', 'Cubo Externo');
    Proj.Objects.Assets[Proj.Objects.FindAsset('cubo_stl')].AssignSkinToObject('madeira_carvalho', Proj.Skins);
    Proj.Objects.ExportAssetGLB('cubo_stl', TmpGLB, Lim);
    Check(FileExists(TmpGLB), 'GLB exportado de STL com skin');

    { 5. Salvar/reabrir maquete e exportar pacote maquete }
    Proj.SaveMaqueteFile(TmpMaq);
    Proj.LoadMaqueteFile(TmpMaq);
    Check(Length(Proj.Instances) = 1, 'instancia preservada ao reabrir maquete');
    Proj.ExportMaquetePackage(TmpPkg);
    Check(FileExists(TmpPkg) and FileExists(ChangeFileExt(TmpPkg, '.glb')), 'pacote maquete + GLB exportados');

    WriteLn(Checks, ' verificacoes da Maquete 3D, Objetos e Texturas, 0 falhas');
  finally
    Mesh.Free;
    Proj.Free;
    if FileExists(TmpEA2D) then DeleteFile(TmpEA2D);
    if FileExists(TmpSTL) then DeleteFile(TmpSTL);
    if FileExists(TmpGLB) then DeleteFile(TmpGLB);
    if FileExists(TmpSkin) then DeleteFile(TmpSkin);
    if FileExists(ChangeFileExt(TmpSkin, '') + '_basecolor.png') then DeleteFile(ChangeFileExt(TmpSkin, '') + '_basecolor.png');
    if FileExists(ChangeFileExt(TmpSkin, '') + '_normal.png') then DeleteFile(ChangeFileExt(TmpSkin, '') + '_normal.png');
    if FileExists(ChangeFileExt(TmpSkin, '') + '_roughness.png') then DeleteFile(ChangeFileExt(TmpSkin, '') + '_roughness.png');
    if FileExists(TmpMaq) then DeleteFile(TmpMaq);
    if FileExists(TmpPkg) then DeleteFile(TmpPkg);
    if FileExists(ChangeFileExt(TmpPkg, '.glb')) then DeleteFile(ChangeFileExt(TmpPkg, '.glb'));
  end;
end.
