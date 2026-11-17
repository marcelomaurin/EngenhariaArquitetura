unit ea_pacote;

{ Núcleo Comum - Pacotes de intercâmbio versionados com manifesto JSON e SHA-256.
  Implementa etapa N2 e G1 de docs/Nucleo_Comum.md e docs/Integracoes.md (seção 4.1). }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, DateUtils, fpjson, jsonparser, ea_fileio;

const
  EA_PACKAGE_SCHEMA_MAJOR = '1';
  EA_PACKAGE_SCHEMA_VERSION = '1.0';

  EA_PKG_TAREFA = 'tarefa';
  EA_PKG_RETORNO_TAREFA = 'retorno_tarefa';
  EA_PKG_ARQUITETURA_2D = 'arquitetura_2d';
  EA_PKG_MAQUETE = 'maquete';
  EA_PKG_CENA_VISUAL = 'cena_visual';
  EA_PKG_OBJETO_3D = 'objeto_3d';
  EA_PKG_TEXTURA = 'textura';
  EA_PKG_CAMADA_ELETRICA = 'camada_eletrica';
  EA_PKG_SOLICITACAO_COORD = 'solicitacao_coordenacao';
  EA_PKG_ESTADO_ILUMINACAO = 'estado_iluminacao';
  EA_PKG_MODELO_ELETRICO = 'modelo_eletrico';
  EA_PKG_CENARIO_SIMULACAO = 'cenario_simulacao';
  EA_PKG_RESULTADO_SIMULACAO = 'resultado_simulacao';
  EA_PKG_REDE_TUBULACOES = 'rede_tubulacoes';
  EA_PKG_CENARIO_FLUIDOS = 'cenario_fluidos';
  EA_PKG_RESULTADO_FLUIDOS = 'resultado_fluidos';
  EA_PKG_COORDENACAO_DISC = 'coordenacao_disciplinas';

type
  EEAPackageError = class(Exception);

  TEASourceRef = record
    PackageId: string;
    Revision: string;
    Hash: string;
  end;

  TEAPackageFileRef = record
    Path: string;
    Hash: string;
  end;

  TEAPackageManifest = class
  public
    SchemaVersion: string;
    PackageType: string;
    PackageId: string;
    Revision: string;
    CreatedByApp: string;
    CreatedByVersion: string;
    CreatedAt: string;
    Units: string;
    UpAxis: string;
    Handedness: string;
    SourceRefs: array of TEASourceRef;
    Files: array of TEAPackageFileRef;
    Payload: TJSONObject; // opcional: payload embutido no mesmo JSON
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure AddSourceRef(const APackageId, ARevision, AHash: string);
    procedure AddFileRef(const APath, AHash: string);
    function ToJSON: TJSONObject;
    procedure FromJSON(O: TJSONObject);
    procedure SaveToFile(const FileName: string);
    procedure LoadFromFile(const FileName: string);
  end;

function EASHA256String(const S: RawByteString): string;
function EASHA256File(const FileName: string): string;
procedure EACheckSupportedExternalFile(const FileName: string);
function EAIsSupportedPackageType(const PackageType: string): Boolean;
function EANowISO8601: string;

implementation

const
  K256: array[0..63] of LongWord = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2
  );

type
  TSHA256Ctx = record
    State: array[0..7] of LongWord;
    BitLen: QWord;
    Buf: array[0..63] of Byte;
    BufLen: Integer;
  end;

function ROR32(X: LongWord; N: Byte): LongWord; inline;
begin
  Result := (X shr N) or (X shl (32 - N));
end;

procedure SHA256Init(out Ctx: TSHA256Ctx);
begin
  Ctx.State[0] := $6a09e667;
  Ctx.State[1] := $bb67ae85;
  Ctx.State[2] := $3c6ef372;
  Ctx.State[3] := $a54ff53a;
  Ctx.State[4] := $510e527f;
  Ctx.State[5] := $9b05688c;
  Ctx.State[6] := $1f83d9ab;
  Ctx.State[7] := $5be0cd19;
  Ctx.BitLen := 0;
  Ctx.BufLen := 0;
end;

procedure SHA256Transform(var Ctx: TSHA256Ctx; const Block: array of Byte);
var
  W: array[0..63] of LongWord;
  I: Integer;
  A, B, C, D, E, F, G, H, S0, S1, Ch, Maj, T1, T2: LongWord;
begin
  for I := 0 to 15 do
    W[I] := (LongWord(Block[I * 4]) shl 24) or
            (LongWord(Block[I * 4 + 1]) shl 16) or
            (LongWord(Block[I * 4 + 2]) shl 8) or
            LongWord(Block[I * 4 + 3]);
  for I := 16 to 63 do
  begin
    S0 := ROR32(W[I - 15], 7) xor ROR32(W[I - 15], 18) xor (W[I - 15] shr 3);
    S1 := ROR32(W[I - 2], 17) xor ROR32(W[I - 2], 19) xor (W[I - 2] shr 10);
    W[I] := W[I - 16] + S0 + W[I - 7] + S1;
  end;
  A := Ctx.State[0]; B := Ctx.State[1]; C := Ctx.State[2]; D := Ctx.State[3];
  E := Ctx.State[4]; F := Ctx.State[5]; G := Ctx.State[6]; H := Ctx.State[7];
  for I := 0 to 63 do
  begin
    S1 := ROR32(E, 6) xor ROR32(E, 11) xor ROR32(E, 25);
    Ch := (E and F) xor ((not E) and G);
    T1 := H + S1 + Ch + K256[I] + W[I];
    S0 := ROR32(A, 2) xor ROR32(A, 13) xor ROR32(A, 22);
    Maj := (A and B) xor (A and C) xor (B and C);
    T2 := S0 + Maj;
    H := G; G := F; F := E; E := D + T1;
    D := C; C := B; B := A; A := T1 + T2;
  end;
  Inc(Ctx.State[0], A); Inc(Ctx.State[1], B); Inc(Ctx.State[2], C); Inc(Ctx.State[3], D);
  Inc(Ctx.State[4], E); Inc(Ctx.State[5], F); Inc(Ctx.State[6], G); Inc(Ctx.State[7], H);
end;

procedure SHA256Update(var Ctx: TSHA256Ctx; const Data; Len: SizeInt);
var
  P: PByte;
  I: SizeInt;
begin
  P := @Data;
  for I := 0 to Len - 1 do
  begin
    Ctx.Buf[Ctx.BufLen] := P[I];
    Inc(Ctx.BufLen);
    if Ctx.BufLen = 64 then
    begin
      SHA256Transform(Ctx, Ctx.Buf);
      Inc(Ctx.BitLen, 512);
      Ctx.BufLen := 0;
    end;
  end;
end;

function SHA256FinalHex(var Ctx: TSHA256Ctx): string;
var
  I: Integer;
  TotalBits: QWord;
begin
  TotalBits := Ctx.BitLen + QWord(Ctx.BufLen) * 8;
  Ctx.Buf[Ctx.BufLen] := $80;
  Inc(Ctx.BufLen);
  if Ctx.BufLen > 56 then
  begin
    while Ctx.BufLen < 64 do
    begin
      Ctx.Buf[Ctx.BufLen] := 0;
      Inc(Ctx.BufLen);
    end;
    SHA256Transform(Ctx, Ctx.Buf);
    Ctx.BufLen := 0;
  end;
  while Ctx.BufLen < 56 do
  begin
    Ctx.Buf[Ctx.BufLen] := 0;
    Inc(Ctx.BufLen);
  end;
  for I := 0 to 7 do
    Ctx.Buf[56 + I] := Byte((TotalBits shr ((7 - I) * 8)) and $FF);
  SHA256Transform(Ctx, Ctx.Buf);
  Result := '';
  for I := 0 to 7 do
    Result := Result + LowerCase(IntToHex(Ctx.State[I], 8));
end;

function EASHA256String(const S: RawByteString): string;
var
  Ctx: TSHA256Ctx;
begin
  SHA256Init(Ctx);
  if Length(S) > 0 then
    SHA256Update(Ctx, S[1], Length(S));
  Result := 'sha256-' + SHA256FinalHex(Ctx);
end;

function EASHA256File(const FileName: string): string;
var
  Ctx: TSHA256Ctx;
  Stream: TFileStream;
  Buf: array[0..8191] of Byte;
  N: LongInt;
begin
  if not FileExists(FileName) then
    raise EEAPackageError.CreateFmt('Arquivo não encontrado para hash: %s', [FileName]);
  SHA256Init(Ctx);
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    repeat
      N := Stream.Read(Buf, SizeOf(Buf));
      if N > 0 then SHA256Update(Ctx, Buf, N);
    until N = 0;
  finally
    Stream.Free;
  end;
  Result := 'sha256-' + SHA256FinalHex(Ctx);
end;

procedure EACheckSupportedExternalFile(const FileName: string);
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  if (Ext = '.mcad') or (Ext = '.msuite') then
    raise EEAPackageError.Create(
      'Arquivos nativos do MultiCAD/MultiSuite (.mcad/.msuite) não são compatíveis. ' +
      'Exporte o sólido no aplicativo de origem como STL ou 3MF e importe esse arquivo.');
  if (Ext = '.gcode') or (Ext = '.nc') then
    raise EEAPackageError.Create(
      'Código de máquina (.gcode/.nc) não é um modelo sólido válido. Exporte STL ou 3MF.');
end;

function EAIsSupportedPackageType(const PackageType: string): Boolean;
const
  Types: array[0..16] of string = (
    EA_PKG_TAREFA, EA_PKG_RETORNO_TAREFA, EA_PKG_ARQUITETURA_2D, EA_PKG_MAQUETE,
    EA_PKG_CENA_VISUAL, EA_PKG_OBJETO_3D, EA_PKG_TEXTURA, EA_PKG_CAMADA_ELETRICA,
    EA_PKG_SOLICITACAO_COORD, EA_PKG_ESTADO_ILUMINACAO, EA_PKG_MODELO_ELETRICO,
    EA_PKG_CENARIO_SIMULACAO, EA_PKG_RESULTADO_SIMULACAO, EA_PKG_REDE_TUBULACOES,
    EA_PKG_CENARIO_FLUIDOS, EA_PKG_RESULTADO_FLUIDOS, EA_PKG_COORDENACAO_DISC
  );
var
  I: Integer;
begin
  for I := 0 to High(Types) do
    if PackageType = Types[I] then Exit(True);
  Result := False;
end;

function EANowISO8601: string;
begin
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"Z"', LocalTimeToUniversal(Now));
end;

constructor TEAPackageManifest.Create;
begin
  inherited Create;
  Clear;
end;

destructor TEAPackageManifest.Destroy;
begin
  FreeAndNil(Payload);
  inherited Destroy;
end;

procedure TEAPackageManifest.Clear;
begin
  SchemaVersion := EA_PACKAGE_SCHEMA_VERSION;
  PackageType := '';
  PackageId := '';
  Revision := 'rev-001';
  CreatedByApp := '';
  CreatedByVersion := '0.10.0';
  CreatedAt := EANowISO8601;
  Units := 'mm';
  UpAxis := 'Z';
  Handedness := 'right';
  SetLength(SourceRefs, 0);
  SetLength(Files, 0);
  FreeAndNil(Payload);
end;

procedure TEAPackageManifest.AddSourceRef(const APackageId, ARevision, AHash: string);
var
  N: Integer;
begin
  N := Length(SourceRefs);
  SetLength(SourceRefs, N + 1);
  SourceRefs[N].PackageId := APackageId;
  SourceRefs[N].Revision := ARevision;
  SourceRefs[N].Hash := AHash;
end;

procedure TEAPackageManifest.AddFileRef(const APath, AHash: string);
var
  N: Integer;
begin
  N := Length(Files);
  SetLength(Files, N + 1);
  Files[N].Path := APath;
  Files[N].Hash := AHash;
end;

function TEAPackageManifest.ToJSON: TJSONObject;
var
  CB, Ax, RefObj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  if not EAIsSupportedPackageType(PackageType) then
    raise EEAPackageError.CreateFmt('Tipo de pacote inválido: %s', [PackageType]);
  if Trim(PackageId) = '' then
    raise EEAPackageError.Create('package_id obrigatório no manifesto');
  if Trim(Units) = '' then Units := 'mm';
  if CreatedAt = '' then CreatedAt := EANowISO8601;

  Result := TJSONObject.Create;
  Result.Add('schema_version', SchemaVersion);
  Result.Add('package_type', PackageType);
  Result.Add('package_id', PackageId);
  Result.Add('revision', Revision);

  CB := TJSONObject.Create;
  CB.Add('application', CreatedByApp);
  CB.Add('version', CreatedByVersion);
  Result.Add('created_by', CB);

  Result.Add('created_at', CreatedAt);
  Result.Add('units', Units);

  Ax := TJSONObject.Create;
  Ax.Add('up', UpAxis);
  Ax.Add('handedness', Handedness);
  Result.Add('axes', Ax);

  Arr := TJSONArray.Create;
  for I := 0 to High(SourceRefs) do
  begin
    RefObj := TJSONObject.Create;
    RefObj.Add('package_id', SourceRefs[I].PackageId);
    RefObj.Add('revision', SourceRefs[I].Revision);
    RefObj.Add('hash', SourceRefs[I].Hash);
    Arr.Add(RefObj);
  end;
  Result.Add('source_refs', Arr);

  Arr := TJSONArray.Create;
  for I := 0 to High(Files) do
  begin
    RefObj := TJSONObject.Create;
    RefObj.Add('path', Files[I].Path);
    RefObj.Add('hash', Files[I].Hash);
    Arr.Add(RefObj);
  end;
  Result.Add('files', Arr);

  if Payload <> nil then
    Result.Add('payload', TJSONObject(Payload.Clone));
end;

procedure TEAPackageManifest.FromJSON(O: TJSONObject);
var
  Ver, PType, PId: string;
  CB, Ax, Item: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  DotPos: Integer;
  Major: string;
begin
  if O = nil then raise EEAPackageError.Create('Manifesto JSON ausente');
  Ver := O.Get('schema_version', '');
  if Ver = '' then raise EEAPackageError.Create('Manifesto sem schema_version');
  DotPos := Pos('.', Ver);
  if DotPos > 0 then Major := Copy(Ver, 1, DotPos - 1) else Major := Ver;
  if Major <> EA_PACKAGE_SCHEMA_MAJOR then
    raise EEAPackageError.CreateFmt('Versão de esquema de pacote não suportada: %s', [Ver]);

  PType := O.Get('package_type', '');
  if not EAIsSupportedPackageType(PType) then
    raise EEAPackageError.CreateFmt('package_type desconhecido ou incompatível: %s', [PType]);

  PId := O.Get('package_id', '');
  if Trim(PId) = '' then
    raise EEAPackageError.Create('Manifesto sem package_id');

  Clear;
  SchemaVersion := Ver;
  PackageType := PType;
  PackageId := PId;
  Revision := O.Get('revision', 'rev-001');
  CreatedAt := O.Get('created_at', '');
  Units := O.Get('units', 'mm');
  if Units <> 'mm' then
    raise EEAPackageError.CreateFmt('Unidade não suportada no pacote (%s). Esperado: mm', [Units]);

  if (O.Find('created_by') <> nil) and (O.Find('created_by') is TJSONObject) then
  begin
    CB := O.Objects['created_by'];
    CreatedByApp := CB.Get('application', '');
    CreatedByVersion := CB.Get('version', '');
  end;
  if (O.Find('axes') <> nil) and (O.Find('axes') is TJSONObject) then
  begin
    Ax := O.Objects['axes'];
    UpAxis := Ax.Get('up', 'Z');
    Handedness := Ax.Get('handedness', 'right');
  end;
  if (O.Find('source_refs') <> nil) and (O.Find('source_refs') is TJSONArray) then
  begin
    Arr := O.Arrays['source_refs'];
    SetLength(SourceRefs, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Objects[I];
      SourceRefs[I].PackageId := Item.Get('package_id', '');
      SourceRefs[I].Revision := Item.Get('revision', '');
      SourceRefs[I].Hash := Item.Get('hash', '');
    end;
  end;
  if (O.Find('files') <> nil) and (O.Find('files') is TJSONArray) then
  begin
    Arr := O.Arrays['files'];
    SetLength(Files, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Objects[I];
      Files[I].Path := Item.Get('path', '');
      Files[I].Hash := Item.Get('hash', '');
    end;
  end;
  if (O.Find('payload') <> nil) and (O.Find('payload') is TJSONObject) then
    Payload := TJSONObject(O.Objects['payload'].Clone);
end;

procedure TEAPackageManifest.SaveToFile(const FileName: string);
var
  O: TJSONObject;
begin
  O := ToJSON;
  try
    EAAtomicWriteText(FileName, O.FormatJSON);
  finally
    O.Free;
  end;
end;

procedure TEAPackageManifest.LoadFromFile(const FileName: string);
var
  SL: TStringList;
  Data: TJSONData;
  Temp: TEAPackageManifest;
begin
  EACheckSupportedExternalFile(FileName);
  if not FileExists(FileName) then
    raise EEAPackageError.CreateFmt('Arquivo de pacote não encontrado: %s', [FileName]);
  SL := TStringList.Create;
  try
    SL.LoadFromFile(FileName);
    Data := GetJSON(SL.Text);
  finally
    SL.Free;
  end;
  try
    if not (Data is TJSONObject) then
      raise EEAPackageError.Create('Pacote JSON inválido');
    Temp := TEAPackageManifest.Create;
    try
      Temp.FromJSON(TJSONObject(Data));
      Clear;
      SchemaVersion := Temp.SchemaVersion;
      PackageType := Temp.PackageType;
      PackageId := Temp.PackageId;
      Revision := Temp.Revision;
      CreatedByApp := Temp.CreatedByApp;
      CreatedByVersion := Temp.CreatedByVersion;
      CreatedAt := Temp.CreatedAt;
      Units := Temp.Units;
      UpAxis := Temp.UpAxis;
      Handedness := Temp.Handedness;
      SourceRefs := Copy(Temp.SourceRefs);
      Files := Copy(Temp.Files);
      if Temp.Payload <> nil then
        Payload := TJSONObject(Temp.Payload.Clone);
    finally
      Temp.Free;
    end;
  finally
    Data.Free;
  end;
end;

end.
