program test_criadorcenas;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  Classes, SysUtils,
  ea_geometria, ea_pacote, ea_modelo,
  maq_projeto, cena_projeto;

var
  Maq: TMAQProject;
  Cena, Cena2: TCenaProject;
  TmpPkg, TmpDay, TmpNight, TmpSeqDir, TmpScene: string;
  G: TGUID;
  Frames: Integer;
  Checks: Integer = 0;

procedure Check(OK: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not OK then raise Exception.Create('FALHA: ' + Msg);
end;

begin
  CreateGUID(G);
  TmpPkg := GetTempDir(False) + 'ea-cena-' + GUIDToString(G) + '.maquete.pkg.json';
  TmpDay := GetTempDir(False) + 'ea-cena-day-' + GUIDToString(G) + '.png';
  TmpNight := GetTempDir(False) + 'ea-cena-night-' + GUIDToString(G) + '.png';
  TmpScene := GetTempDir(False) + 'ea-cena-' + GUIDToString(G) + '.cena.json';
  TmpSeqDir := GetTempDir(False) + 'ea-cena-seq-' + GUIDToString(G);

  Maq := TMAQProject.Create;
  Cena := TCenaProject.Create;
  Cena2 := TCenaProject.Create;
  try
    Maq.LoadDemoTwoFloors;
    Maq.ExportMaquetePackage(TmpPkg);

    Cena.ImportMaquetePackage(TmpPkg, False);
    Check(Cena.SceneMesh.TriangleCount > 0, 'importa maquete com geometria');
    Cena.AddCamera('cam-1', 'Principal', EAV3(8500, -5500, 2600), EAV3(3000, 2200, 1400), 55.0);
    Cena.AddLight('l1', 'Luz Central', EAV3(3000, 2200, 2600), $FFF7ED, 150.0);
    Cena.AddKeyframe(0.0, EAV3(8500, -5500, 2600), EAV3(3000, 2200, 1400), 0, 13.0);
    Cena.AddKeyframe(1.0, EAV3(7000, -4500, 2200), EAV3(3000, 2200, 1400), 90, 21.0);

    { Render diurno e noturno }
    Cena.HourOfDay := 13.0;
    Cena.RenderToPNG(TmpDay, 120, 80, 0, True);
    Check(FileExists(TmpDay), 'PNG diurno gerado');
    Cena.HourOfDay := 22.0;
    Cena.RenderToPNG(TmpNight, 120, 80, 0, True);
    Check(FileExists(TmpNight), 'PNG noturno gerado');

    { Sequencia de quadros }
    Frames := Cena.RenderSequencePNG(TmpSeqDir, 80, 60, 3, 1.0);
    Check(Frames = 3, 'sequencia de 3 quadros exportada');
    Check(FileExists(TmpSeqDir + DirectorySeparator + 'frame_0003.png'), 'ultimo quadro gerado');

    { Salvar/reabrir cena e reconciliar maquete sem perder cameras }
    Cena.SaveSceneFile(TmpScene);
    Cena2.LoadSceneFile(TmpScene);
    Check(Length(Cena2.Cameras) = 2, 'cameras preservadas');
    Cena2.ImportMaquetePackage(TmpPkg, True);
    Check(Length(Cena2.Cameras) = 2, 'reconciliacao de maquete preserva cameras');

    WriteLn(Checks, ' verificacoes do Criador de Cenas, 0 falhas');
  finally
    Cena2.Free;
    Cena.Free;
    Maq.Free;
    if FileExists(TmpPkg) then DeleteFile(TmpPkg);
    if FileExists(ChangeFileExt(TmpPkg, '.glb')) then DeleteFile(ChangeFileExt(TmpPkg, '.glb'));
    if FileExists(TmpDay) then DeleteFile(TmpDay);
    if FileExists(TmpNight) then DeleteFile(TmpNight);
    if FileExists(TmpScene) then DeleteFile(TmpScene);
    if FileExists(TmpSeqDir + DirectorySeparator + 'frame_0001.png') then DeleteFile(TmpSeqDir + DirectorySeparator + 'frame_0001.png');
    if FileExists(TmpSeqDir + DirectorySeparator + 'frame_0002.png') then DeleteFile(TmpSeqDir + DirectorySeparator + 'frame_0002.png');
    if FileExists(TmpSeqDir + DirectorySeparator + 'frame_0003.png') then DeleteFile(TmpSeqDir + DirectorySeparator + 'frame_0003.png');
    if DirectoryExists(TmpSeqDir) then RemoveDir(TmpSeqDir);
  end;
end.
