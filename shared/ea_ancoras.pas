unit ea_ancoras;

{ Núcleo Comum - Âncoras persistentes (ea_ancoras).
  Implementa etapa N6 de docs/Nucleo_Comum.md e regras I-10 / I-12 / I-18 de
  docs/Integracoes.md: reposiciona objetos/pontos ancorados quando uma parede
  se move e sinaliza âncoras órfãs se o hospedeiro for removido. }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, fpjson, ea_geometria, ea_modelo;

type
  TEAAnchorHostKind = (ahkFloor, ahkWall, ahkCeiling, ahkRoom);
  TEAAnchorStatus = (easValid, easUpdated, easOrphaned);

  TEAAnchor = record
    AnchorId: string;
    TargetId: string;
    FloorId: string;
    HostId: string;
    HostKind: TEAAnchorHostKind;
    OffsetMM: TEAVec3; // para parede: X = distância ao longo, Y = afastamento normal, Z = altura do piso
    WorldPosMM: TEAVec3;
    YawDeg: Double;
    Status: TEAAnchorStatus;
    Note: string;
  end;

  TEAAnchorArray = array of TEAAnchor;

function EAHostKindToStr(K: TEAAnchorHostKind): string;
function EAStrToHostKind(const S: string): TEAAnchorHostKind;
function EAAnchorStatusToStr(S: TEAAnchorStatus): string;
function EAResolveAnchor(var Anchor: TEAAnchor; Model: TEAModel): Boolean;
function EAResolveAnchors(var Anchors: TEAAnchorArray; Model: TEAModel): Integer;
function EAAnchorToJSON(const A: TEAAnchor): TJSONObject;
function EAAnchorFromJSON(O: TJSONObject): TEAAnchor;

implementation

uses
  Math;

function EAHostKindToStr(K: TEAAnchorHostKind): string;
begin
  case K of
    ahkFloor: Result := 'floor';
    ahkWall: Result := 'wall';
    ahkCeiling: Result := 'ceiling';
  else
    Result := 'room';
  end;
end;

function EAStrToHostKind(const S: string): TEAAnchorHostKind;
var
  L: string;
begin
  L := LowerCase(Trim(S));
  if L = 'wall' then Result := ahkWall
  else if L = 'ceiling' then Result := ahkCeiling
  else if L = 'room' then Result := ahkRoom
  else Result := ahkFloor;
end;

function EAAnchorStatusToStr(S: TEAAnchorStatus): string;
begin
  case S of
    easValid: Result := 'valid';
    easUpdated: Result := 'updated';
  else
    Result := 'orphaned';
  end;
end;

function EAResolveAnchor(var Anchor: TEAAnchor; Model: TEAModel): Boolean;
var
  FIdx, WIdx: Integer;
  FloorZ: Double;
  Dir, Nor, P2: TEAVec2;
  PrevPos: TEAVec3;
begin
  Result := False;
  if Model = nil then Exit;
  PrevPos := Anchor.WorldPosMM;
  FIdx := Model.FindFloor(Anchor.FloorId);
  if FIdx < 0 then
  begin
    Anchor.Status := easOrphaned;
    Anchor.Note := 'Pavimento hospedeiro removido: ' + Anchor.FloorId;
    Exit(False);
  end;
  FloorZ := Model.Floors[FIdx].ElevationMM;

  case Anchor.HostKind of
    ahkFloor:
      begin
        Anchor.WorldPosMM := EAV3(
          Model.Floors[FIdx].OffsetXMM + Anchor.OffsetMM.X,
          Model.Floors[FIdx].OffsetYMM + Anchor.OffsetMM.Y,
          FloorZ + Anchor.OffsetMM.Z);
        Result := True;
      end;
    ahkCeiling:
      begin
        Anchor.WorldPosMM := EAV3(
          Model.Floors[FIdx].OffsetXMM + Anchor.OffsetMM.X,
          Model.Floors[FIdx].OffsetYMM + Anchor.OffsetMM.Y,
          FloorZ + Model.Floors[FIdx].WallHeightMM - Anchor.OffsetMM.Z);
        Result := True;
      end;
    ahkWall:
      begin
        WIdx := Model.FindWall(Anchor.HostId);
        if WIdx < 0 then
        begin
          Anchor.Status := easOrphaned;
          Anchor.Note := 'Parede hospedeira removida: ' + Anchor.HostId;
          Exit(False);
        end;
        Dir := EAV2Norm(EAV2Sub(Model.Walls[WIdx].EndMM, Model.Walls[WIdx].StartMM));
        Nor := EAV2Perp(Dir);
        P2 := EAV2Add(
          EAV2Add(Model.Walls[WIdx].StartMM, EAV2Scale(Dir, Anchor.OffsetMM.X)),
          EAV2Scale(Nor, Anchor.OffsetMM.Y));
        Anchor.WorldPosMM := EAV3(P2.X, P2.Y, FloorZ + Anchor.OffsetMM.Z);
        Anchor.YawDeg := RadToDeg(ArcTan2(Dir.Y, Dir.X));
        Result := True;
      end;
    ahkRoom:
      begin
        Anchor.WorldPosMM := EAV3(Anchor.OffsetMM.X, Anchor.OffsetMM.Y, FloorZ + Anchor.OffsetMM.Z);
        Result := True;
      end;
  end;

  if EAV3Dist(PrevPos, Anchor.WorldPosMM) > 0.1 then
    Anchor.Status := easUpdated
  else
    Anchor.Status := easValid;
  Anchor.Note := '';
end;

function EAResolveAnchors(var Anchors: TEAAnchorArray; Model: TEAModel): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(Anchors) do
    if not EAResolveAnchor(Anchors[I], Model) then
      Inc(Result);
end;

function EAAnchorToJSON(const A: TEAAnchor): TJSONObject;
var
  Arr: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.Add('anchor_id', A.AnchorId);
  Result.Add('target_id', A.TargetId);
  Result.Add('floor_id', A.FloorId);
  Result.Add('host_id', A.HostId);
  Result.Add('host_kind', EAHostKindToStr(A.HostKind));
  Arr := TJSONArray.Create;
  Arr.Add(A.OffsetMM.X); Arr.Add(A.OffsetMM.Y); Arr.Add(A.OffsetMM.Z);
  Result.Add('offset_mm', Arr);
  Arr := TJSONArray.Create;
  Arr.Add(A.WorldPosMM.X); Arr.Add(A.WorldPosMM.Y); Arr.Add(A.WorldPosMM.Z);
  Result.Add('world_pos_mm', Arr);
  Result.Add('yaw_deg', A.YawDeg);
  Result.Add('status', EAAnchorStatusToStr(A.Status));
  Result.Add('note', A.Note);
end;

function EAAnchorFromJSON(O: TJSONObject): TEAAnchor;
var
  Arr: TJSONArray;
  St: string;
begin
  Result := Default(TEAAnchor);
  if O = nil then Exit;
  Result.AnchorId := O.Get('anchor_id', '');
  Result.TargetId := O.Get('target_id', '');
  Result.FloorId := O.Get('floor_id', 'terreo');
  Result.HostId := O.Get('host_id', '');
  Result.HostKind := EAStrToHostKind(O.Get('host_kind', 'floor'));
  Arr := O.Get('offset_mm', TJSONArray(nil));
  if (Arr <> nil) and (Arr.Count >= 3) then
    Result.OffsetMM := EAV3(Arr.Floats[0], Arr.Floats[1], Arr.Floats[2]);
  Arr := O.Get('world_pos_mm', TJSONArray(nil));
  if (Arr <> nil) and (Arr.Count >= 3) then
    Result.WorldPosMM := EAV3(Arr.Floats[0], Arr.Floats[1], Arr.Floats[2]);
  Result.YawDeg := O.Get('yaw_deg', 0.0);
  St := O.Get('status', 'valid');
  if St = 'orphaned' then Result.Status := easOrphaned
  else if St = 'updated' then Result.Status := easUpdated
  else Result.Status := easValid;
  Result.Note := O.Get('note', '');
end;

end.
