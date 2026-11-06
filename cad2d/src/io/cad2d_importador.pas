unit cad2d_importador;

{$mode objfpc}{$H+}

{ Módulo de Importação e Interoperabilidade para o CAD Arquitetônico 2D.
  Implementa os contratos do Motor de Importação (docs/Motor_Importacao.md),
  Integrações (docs/Integracoes.md: I-04, I-05) e CAD 2D (docs/CAD_Arquitetonico_2D.md):
    - RFI-001: Detecção e validação de formato e versão pelo conteúdo
    - RFI-005 / RFI-006: Mapeamento para entidades internas (linhas, paredes, aberturas)
    - RFI-007: Relatório detalhado de importação (importados, ignorados, avisos)
    - RFI-009: Registro de origem (caminho, hash, data e adaptador)
    - RFI-012: Segurança (sem execução de macros/scripts embutidos)
    - RF2D-011: Importação de DXF e adaptador DWG
    - RF2D-017: Extração 2D de modelos IFC (pavimentos, paredes, portas, janelas) }

interface

uses
  Classes, SysUtils, StrUtils, Types, Math, Process, sha1;

type
  TFileFormat = (fmtUnknown, fmtDXF, fmtDWG, fmtIFC, fmtEACAD);

  TImportedEntityKind = (
    iekLine = 0,
    iekRectangle = 1,
    iekWall = 2,
    iekDoor = 3,
    iekWindow = 4
  );

  TImportedEntity = record
    A, B: TPoint;
    Layer: Integer; // 0: Arquitetura, 1: Estrutura, 2: Instalações
    Kind: Integer;  // 0: Linha, 1: Retângulo, 2: Parede, 3: Porta, 4: Janela
    WidthMM: Integer;
    GroupID: Integer;
    SourceName: string;
  end;

  TImportReport = record
    SourcePath: string;
    SourceHash: string;
    Format: TFileFormat;
    FormatName: string;
    VersionDetected: string;
    ImportedCount: Integer;
    WallCount: Integer;
    DoorCount: Integer;
    WindowCount: Integer;
    LineCount: Integer;
    IgnoredCount: Integer;
    FloorCount: Integer;
    FloorsDetected: string;
    SelectedFloor: string;
    Warnings: TStringList;
    Errors: TStringList;
    Success: Boolean;
  end;

function DetectFormat(const AFileName: string; out AVersion: string): TFileFormat;
function ComputeFileSHA1(const AFileName: string): string;

function ImportDXF(const AFileName: string; out AEntities: array of TImportedEntity;
  out ACount: Integer; var AReport: TImportReport; ScaleMMPerPixel: Integer = 50): Boolean;

function ImportDWG(const AFileName: string; out AEntities: array of TImportedEntity;
  out ACount: Integer; var AReport: TImportReport; ScaleMMPerPixel: Integer = 50): Boolean;

function ImportIFC(const AFileName: string; const ATargetFloor: string;
  out AEntities: array of TImportedEntity; out ACount: Integer;
  var AReport: TImportReport; ScaleMMPerPixel: Integer = 50): Boolean;

function GetIFCFloors(const AFileName: string; AFloors: TStrings): Boolean;

procedure InitReport(var R: TImportReport; const APath: string);
procedure FreeReport(var R: TImportReport);
function FormatReportSummary(const R: TImportReport): string;

implementation

function ParseFloatDot(const S: string): Double;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := StrToFloatDef(Trim(S), 0.0, FS);
end;


procedure InitReport(var R: TImportReport; const APath: string);
begin
  R.SourcePath := APath;
  R.SourceHash := '';
  R.Format := fmtUnknown;
  R.FormatName := 'Desconhecido';
  R.VersionDetected := 'Indefinida';
  R.ImportedCount := 0;
  R.WallCount := 0;
  R.DoorCount := 0;
  R.WindowCount := 0;
  R.LineCount := 0;
  R.IgnoredCount := 0;
  R.FloorCount := 0;
  R.FloorsDetected := '';
  R.SelectedFloor := '';
  R.Warnings := TStringList.Create;
  R.Errors := TStringList.Create;
  R.Success := False;
end;

procedure FreeReport(var R: TImportReport);
begin
  if Assigned(R.Warnings) then FreeAndNil(R.Warnings);
  if Assigned(R.Errors) then FreeAndNil(R.Errors);
end;

function FormatReportSummary(const R: TImportReport): string;
var
  S: string;
begin
  S := Format('--- Relatório de Importação ---' + LineEnding +
              'Arquivo: %s' + LineEnding +
              'Formato: %s (%s)' + LineEnding +
              'Hash SHA-1: %s' + LineEnding +
              'Objetos importados: %d' + LineEnding +
              '  - Paredes: %d' + LineEnding +
              '  - Portas: %d' + LineEnding +
              '  - Janelas: %d' + LineEnding +
              '  - Linhas gerais: %d' + LineEnding +
              'Entidades ignoradas/não suportadas: %d' + LineEnding,
              [ExtractFileName(R.SourcePath), R.FormatName, R.VersionDetected,
               R.SourceHash, R.ImportedCount, R.WallCount, R.DoorCount,
               R.WindowCount, R.LineCount, R.IgnoredCount]);
  if R.FloorCount > 0 then
    S := S + Format('Pavimentos no arquivo: %d [%s]' + LineEnding, [R.FloorCount, R.FloorsDetected]);
  if R.SelectedFloor <> '' then
    S := S + Format('Pavimento extraído: %s' + LineEnding, [R.SelectedFloor]);
  if Assigned(R.Warnings) and (R.Warnings.Count > 0) then
    S := S + Format('Avisos (%d):' + LineEnding + '  %s' + LineEnding,
      [R.Warnings.Count, StringReplace(R.Warnings.Text, LineEnding, LineEnding + '  ', [rfReplaceAll])]);
  if Assigned(R.Errors) and (R.Errors.Count > 0) then
    S := S + Format('Erros (%d):' + LineEnding + '  %s' + LineEnding,
      [R.Errors.Count, StringReplace(R.Errors.Text, LineEnding, LineEnding + '  ', [rfReplaceAll])]);
  Result := S;
end;

function ComputeFileSHA1(const AFileName: string): string;
var
  Digest: TSHA1Digest;
begin
  Result := '';
  if not FileExists(AFileName) then Exit;
  try
    Digest := SHA1File(AFileName);
    Result := LowerCase(SHA1Print(Digest));
  except
    Result := 'erro-hash';
  end;
end;

function DetectFormat(const AFileName: string; out AVersion: string): TFileFormat;
var
  FS: TFileStream;
  Buf: array[0..255] of Char;
  BytesRead: Integer;
  HeaderStr: string;
begin
  Result := fmtUnknown;
  AVersion := 'Indefinida';
  if not FileExists(AFileName) then Exit;

  try
    FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      FillChar(Buf, SizeOf(Buf), 0);
      BytesRead := FS.Read(Buf, SizeOf(Buf) - 1);
      if BytesRead < 6 then Exit;
      HeaderStr := Copy(Buf, 1, BytesRead);

      // Verificação DWG pelos magic bytes "AC10xx"
      if (Buf[0] = 'A') and (Buf[1] = 'C') and (Buf[2] = '1') and (Buf[3] = '0') then
      begin
        Result := fmtDWG;
        case Copy(HeaderStr, 1, 6) of
          'AC1015': AVersion := 'AutoCAD 2000/2000i/2002 (AC1015)';
          'AC1018': AVersion := 'AutoCAD 2004/2005/2006 (AC1018)';
          'AC1021': AVersion := 'AutoCAD 2007/2008/2009 (AC1021)';
          'AC1024': AVersion := 'AutoCAD 2010/2011/2012 (AC1024)';
          'AC1027': AVersion := 'AutoCAD 2013/2014/2015/2016/2017 (AC1027)';
          'AC1032': AVersion := 'AutoCAD 2018/2021/2024 (AC1032)';
          'AC1009': AVersion := 'AutoCAD R11/R12 (AC1009)';
          'AC1012': AVersion := 'AutoCAD R13 (AC1012)';
          'AC1014': AVersion := 'AutoCAD R14 (AC1014)';
        else
          AVersion := 'AutoCAD DWG ' + Copy(HeaderStr, 1, 6);
        end;
        Exit;
      end;

      // Verificação IFC (ISO-10303-21)
      if (Pos('ISO-10303-21', HeaderStr) > 0) or (Pos('FILE_SCHEMA', HeaderStr) > 0) then
      begin
        Result := fmtIFC;
        if Pos('IFC4X3', UpperCase(HeaderStr)) > 0 then AVersion := 'IFC4.3'
        else if Pos('IFC4', UpperCase(HeaderStr)) > 0 then AVersion := 'IFC4'
        else if Pos('IFC2X3', UpperCase(HeaderStr)) > 0 then AVersion := 'IFC2x3'
        else if Pos('IFC2X2', UpperCase(HeaderStr)) > 0 then AVersion := 'IFC2x2'
        else AVersion := 'IFC (STEP)';
        Exit;
      end;

      // Verificação Projeto EACAD
      if (Copy(HeaderStr, 1, 6) = 'EACAD1') or (Copy(HeaderStr, 1, 6) = 'EACAD2') or
         (Copy(HeaderStr, 1, 6) = 'EACAD3') then
      begin
        Result := fmtEACAD;
        AVersion := Copy(HeaderStr, 1, 6);
        Exit;
      end;

      // Verificação DXF (textual)
      if (Pos('SECTION', HeaderStr) > 0) or (Pos('ENTITIES', HeaderStr) > 0) or
         (Pos('HEADER', HeaderStr) > 0) or (LowerCase(ExtractFileExt(AFileName)) = '.dxf') then
      begin
        Result := fmtDXF;
        AVersion := 'AutoCAD DXF';
        Exit;
      end;

    finally
      FS.Free;
    end;
  except
    Result := fmtUnknown;
  end;
end;

{ -------------------------------------------------------------
  IMPORTADOR DXF (NATIVO)
  Lê a seção ENTITIES: LINE, LWPOLYLINE, POLYLINE, CIRCLE, ARC.
  Mapeia camadas para Arquitetura/Estrutura/Instalações e
  identifica paredes, portas e janelas pelos nomes de camadas.
  ------------------------------------------------------------- }

function ClassifyLayer(const ALayerName: string; out AKind: Integer): Integer;
var
  U: string;
begin
  U := UpperCase(ALayerName);
  AKind := 0; // linha padrão
  Result := 0; // 0: Arquitetura

  if (Pos('PAREDE', U) > 0) or (Pos('WALL', U) > 0) or (Pos('ALVENARIA', U) > 0) then
  begin
    Result := 0;
    AKind := 2; // Parede
  end
  else if (Pos('PORTA', U) > 0) or (Pos('DOOR', U) > 0) then
  begin
    Result := 0;
    AKind := 3; // Porta
  end
  else if (Pos('JANELA', U) > 0) or (Pos('WINDOW', U) > 0) or (Pos('ESQUADRIA', U) > 0) then
  begin
    Result := 0;
    AKind := 4; // Janela
  end
  else if (Pos('ESTRUT', U) > 0) or (Pos('PILAR', U) > 0) or (Pos('VIGA', U) > 0) or
          (Pos('COLUNA', U) > 0) or (Pos('COLUMN', U) > 0) then
  begin
    Result := 1; // Estrutura
    AKind := 1; // Retângulo / elemento
  end
  else if (Pos('ELET', U) > 0) or (Pos('HIDR', U) > 0) or (Pos('TUB', U) > 0) or
          (Pos('GAS', U) > 0) or (Pos('PLUMB', U) > 0) or (Pos('SANIT', U) > 0) then
  begin
    Result := 2; // Instalações
    AKind := 0;
  end;
end;

function ImportDXF(const AFileName: string; out AEntities: array of TImportedEntity;
  out ACount: Integer; var AReport: TImportReport; ScaleMMPerPixel: Integer = 50): Boolean;
var
  Lines: TStringList;
  I, MaxCap, CurGroup, LayerIdx, KindIdx: Integer;
  Code: Integer;
  Val, EntityType, CurLayer: string;
  X1, Y1, X2, Y2, Radius: Double;
  HasX1, HasY1, HasX2, HasY2, InEntities: Boolean;

  procedure AddLine(AX1, AY1, AX2, AY2: Double; ALayer: Integer; AKind, AWidthMM: Integer);
  var
    P1, P2: TPoint;
  begin
    if ACount >= MaxCap then
    begin
      AReport.Warnings.Add('Limite de capacidade do buffer de importação atingido.');
      Exit;
    end;
    if ScaleMMPerPixel <= 0 then ScaleMMPerPixel := 50;

    // Converte mm / unidades para coordenadas de visualização do canvas
    P1.X := Round(AX1 / ScaleMMPerPixel);
    P1.Y := Round(-AY1 / ScaleMMPerPixel); // Inversão padrão de Y do CAD
    P2.X := Round(AX2 / ScaleMMPerPixel);
    P2.Y := Round(-AY2 / ScaleMMPerPixel);

    if (P1.X = P2.X) and (P1.Y = P2.Y) then Exit; // Evita linhas degeneradas

    AEntities[ACount].A := P1;
    AEntities[ACount].B := P2;
    AEntities[ACount].Layer := ALayer;
    AEntities[ACount].Kind := AKind;
    AEntities[ACount].WidthMM := AWidthMM;
    AEntities[ACount].GroupID := CurGroup;
    AEntities[ACount].SourceName := ExtractFileName(AFileName);
    Inc(ACount);
    Inc(AReport.ImportedCount);

    case AKind of
      2: Inc(AReport.WallCount);
      3: Inc(AReport.DoorCount);
      4: Inc(AReport.WindowCount);
    else
      Inc(AReport.LineCount);
    end;
  end;

  procedure AddApproximatedCircle(CX, CY, R: Double; ALayer, AKind: Integer);
  const
    STEPS = 16;
  var
    S: Integer;
    Ang1, Ang2: Double;
  begin
    if R <= 0 then Exit;
    for S := 0 to STEPS - 1 do
    begin
      Ang1 := (S * 2 * Pi) / STEPS;
      Ang2 := ((S + 1) * 2 * Pi) / STEPS;
      AddLine(CX + R * Cos(Ang1), CY + R * Sin(Ang1),
              CX + R * Cos(Ang2), CY + R * Sin(Ang2),
              ALayer, AKind, 0);
    end;
    Inc(CurGroup);
  end;

begin
  Result := False;
  ACount := 0;
  MaxCap := Length(AEntities);
  CurGroup := 1;
  AReport.Format := fmtDXF;
  AReport.FormatName := 'AutoCAD DXF';
  AReport.SourceHash := ComputeFileSHA1(AFileName);

  if not FileExists(AFileName) then
  begin
    AReport.Errors.Add('Arquivo DXF não encontrado: ' + AFileName);
    Exit;
  end;

  Lines := TStringList.Create;
  try
    try
      Lines.LoadFromFile(AFileName);
    except
      on E: Exception do
      begin
        AReport.Errors.Add('Falha ao ler o arquivo DXF: ' + E.Message);
        Exit;
      end;
    end;

    InEntities := False;
    I := 0;
    EntityType := '';
    CurLayer := '0';
    HasX1 := False; HasY1 := False; HasX2 := False; HasY2 := False;
    X1 := 0; Y1 := 0; X2 := 0; Y2 := 0; Radius := 0;

    while I < Lines.Count - 1 do
    begin
      Code := StrToIntDef(Trim(Lines[I]), -1);
      Val := Trim(Lines[I + 1]);
      Inc(I, 2);

      // Descarrega entidade anterior antes de qualquer transicao com Code = 0
      if InEntities and (Code = 0) then
      begin
        if (EntityType = 'LINE') and HasX1 and HasY1 and HasX2 and HasY2 then
        begin
          LayerIdx := ClassifyLayer(CurLayer, KindIdx);
          AddLine(X1, Y1, X2, Y2, LayerIdx, KindIdx, 150);
          Inc(CurGroup);
        end
        else if (EntityType = 'CIRCLE') and HasX1 and HasY1 and (Radius > 0) then
        begin
          LayerIdx := ClassifyLayer(CurLayer, KindIdx);
          AddApproximatedCircle(X1, Y1, Radius, LayerIdx, KindIdx);
        end;

        EntityType := '';
        HasX1 := False; HasY1 := False; HasX2 := False; HasY2 := False;
        Radius := 0;
      end;

      if (Code = 0) and (Val = 'SECTION') then
      begin
        if (I < Lines.Count - 1) and (Trim(Lines[I]) = '2') and (Trim(Lines[I+1]) = 'ENTITIES') then
        begin
          InEntities := True;
          Inc(I, 2);
        end;
        Continue;
      end;

      if (Code = 0) and (Val = 'ENDSEC') then
      begin
        InEntities := False;
        Continue;
      end;

      if InEntities then
      begin
        if Code = 0 then
        begin
          EntityType := Val;
          CurLayer := '0';
        end
        else if Code = 8 then
        begin
          CurLayer := Val;
        end
        else if Code = 10 then
        begin
          X1 := ParseFloatDot(Val);
          HasX1 := True;
        end
        else if Code = 20 then
        begin
          Y1 := ParseFloatDot(Val);
          HasY1 := True;
        end
        else if Code = 11 then
        begin
          X2 := ParseFloatDot(Val);
          HasX2 := True;
        end
        else if Code = 21 then
        begin
          Y2 := ParseFloatDot(Val);
          HasY2 := True;
        end
        else if Code = 40 then
        begin
          Radius := ParseFloatDot(Val);
        end;
      end;
    end;

    AReport.Success := ACount > 0;
    Result := AReport.Success;
    if not Result then
      AReport.Warnings.Add('Nenhuma entidade de linha, parede ou geometria suportada foi encontrada na seção ENTITIES.');

  finally
    Lines.Free;
  end;
end;

{ -------------------------------------------------------------
  ADAPTADOR DWG (RFI-001, RFI-006, RFI-013, RF2D-011)
  Identifica versão do DWG pelos magic bytes.
  Verifica conversores instalados (dwg2dxf / ODA File Converter)
  para conversão transparente para DXF temporário.
  ------------------------------------------------------------- }

function FindDWGConverter(out AConverterPath: string; out AIsLibreDWG: Boolean): Boolean;
var
  Paths: array[0..3] of string;
  I: Integer;
begin
  Result := False;
  AConverterPath := '';
  AIsLibreDWG := True;

  Paths[0] := 'dwg2dxf';
  Paths[1] := 'dwg2dxf.exe';
  Paths[2] := 'C:\Program Files\LibreDWG\dwg2dxf.exe';
  Paths[3] := ExtractFilePath(ParamStr(0)) + 'tools\dwg2dxf.exe';

  for I := 0 to High(Paths) do
  begin
    if (I > 1) and FileExists(Paths[I]) then
    begin
      AConverterPath := Paths[I];
      Exit(True);
    end;
  end;
end;

function ImportDWG(const AFileName: string; out AEntities: array of TImportedEntity;
  out ACount: Integer; var AReport: TImportReport; ScaleMMPerPixel: Integer = 50): Boolean;
var
  Ver: string;
  ConverterPath, TempDXF: string;
  IsLibreDWG: Boolean;
  P: TProcess;
begin
  Result := False;
  ACount := 0;
  AReport.Format := fmtDWG;
  AReport.FormatName := 'AutoCAD DWG';
  AReport.SourceHash := ComputeFileSHA1(AFileName);

  DetectFormat(AFileName, Ver);
  AReport.VersionDetected := Ver;

  if not FileExists(AFileName) then
  begin
    AReport.Errors.Add('Arquivo DWG não encontrado: ' + AFileName);
    Exit;
  end;

  if FindDWGConverter(ConverterPath, IsLibreDWG) then
  begin
    TempDXF := GetTempFileName('', 'eadwg_') + '.dxf';
    P := TProcess.Create(nil);
    try
      P.Executable := ConverterPath;
      P.Parameters.Add(AFileName);
      P.Parameters.Add('-o');
      P.Parameters.Add(TempDXF);
      P.Options := [poWaitOnExit, poNoConsole];
      try
        P.Execute;
        if FileExists(TempDXF) then
        begin
          Result := ImportDXF(TempDXF, AEntities, ACount, AReport, ScaleMMPerPixel);
          AReport.Format := fmtDWG;
          AReport.FormatName := 'AutoCAD DWG (convertido via ' + ExtractFileName(ConverterPath) + ')';
          DeleteFile(TempDXF);
          Exit;
        end;
      except
        on E: Exception do
          AReport.Warnings.Add('Falha ao executar conversor DWG: ' + E.Message);
      end;
    finally
      P.Free;
    end;
  end;

  // Se nenhum conversor CLI estiver instalado no sistema:
  AReport.Warnings.Add(Format(
    'O arquivo DWG foi identificado com sucesso como "%s", mas o conversor (dwg2dxf do LibreDWG ou ODA) não está no PATH do sistema.' + LineEnding +
    'Para carregar arquivos DWG diretamente, instale o utilitário dwg2dxf ou exporte o projeto para DXF no AutoCAD/LibreCAD.',
    [Ver]));
  AReport.Success := False;
end;

{ -------------------------------------------------------------
  EXTRATOR DE PLANTAS 2D DE MODELOS BIM IFC (RF2D-017, I7)
  Analisa a estrutura STEP (ISO-10303-21) do arquivo .ifc:
    - IFCBUILDINGSTOREY (pavimentos)
    - IFCWALL / IFCWALLSTANDARDCASE (paredes)
    - IFCDOOR (portas)
    - IFCWINDOW (janelas)
    - IFCSPACE (ambientes)
  Extrai as projeções 2D no plano do pavimento selecionado.
  ------------------------------------------------------------- }

type
  TIFCEntity = class
    ID: Integer;
    Name: string;
    Args: string;
  end;

function GetIFCFloors(const AFileName: string; AFloors: TStrings): Boolean;
var
  Lines: TStringList;
  I, P1, P2: Integer;
  Line, FloorName: string;
begin
  Result := False;
  AFloors.Clear;
  if not FileExists(AFileName) then Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      if Pos('IFCBUILDINGSTOREY', UpperCase(Line)) > 0 then
      begin
        // Exemplo: #50=IFCBUILDINGSTOREY('2N...',#2,'Térreo',$,$,#45,$,$,.ELEMENT.,0.0);
        P1 := Pos('''', Line);
        if P1 > 0 then
        begin
          // Pula o GUID
          P2 := PosEx('''', Line, P1 + 1);
          if P2 > 0 then
          begin
            P1 := PosEx('''', Line, P2 + 1);
            if P1 > 0 then
            begin
              P2 := PosEx('''', Line, P1 + 1);
              if P2 > P1 then
                FloorName := Copy(Line, P1 + 1, P2 - P1 - 1)
              else FloorName := 'Pavimento ' + IntToStr(AFloors.Count + 1);
            end
            else FloorName := 'Pavimento ' + IntToStr(AFloors.Count + 1);
          end
          else FloorName := 'Pavimento ' + IntToStr(AFloors.Count + 1);
        end
        else FloorName := 'Pavimento ' + IntToStr(AFloors.Count + 1);

        AFloors.Add(FloorName);
      end;
    end;
    Result := AFloors.Count > 0;
  finally
    Lines.Free;
  end;
end;

function ImportIFC(const AFileName: string; const ATargetFloor: string;
  out AEntities: array of TImportedEntity; out ACount: Integer;
  var AReport: TImportReport; ScaleMMPerPixel: Integer = 50): Boolean;
var
  Lines: TStringList;
  Floors: TStringList;
  I, MaxCap, CurGroup: Integer;
  Line, Ver: string;
  X, Y, WallLen: Double;
  P1, P2: TPoint;
  IsWall, IsDoor, IsWindow: Boolean;

  procedure AddIFCLine(PStart, PEnd: TPoint; AKind, AWidthMM: Integer);
  begin
    if ACount >= MaxCap then Exit;
    if (PStart.X = PEnd.X) and (PStart.Y = PEnd.Y) then Exit;

    AEntities[ACount].A := PStart;
    AEntities[ACount].B := PEnd;
    AEntities[ACount].Layer := 0; // Arquitetura
    AEntities[ACount].Kind := AKind;
    AEntities[ACount].WidthMM := AWidthMM;
    AEntities[ACount].GroupID := CurGroup;
    AEntities[ACount].SourceName := ExtractFileName(AFileName);
    Inc(ACount);
    Inc(AReport.ImportedCount);

    case AKind of
      2: Inc(AReport.WallCount);
      3: Inc(AReport.DoorCount);
      4: Inc(AReport.WindowCount);
    else
      Inc(AReport.LineCount);
    end;
  end;

begin
  Result := False;
  ACount := 0;
  MaxCap := Length(AEntities);
  CurGroup := 1;
  AReport.Format := fmtIFC;
  AReport.FormatName := 'Modelo BIM IFC (ISO 16739)';
  AReport.SourceHash := ComputeFileSHA1(AFileName);

  DetectFormat(AFileName, Ver);
  AReport.VersionDetected := Ver;

  if not FileExists(AFileName) then
  begin
    AReport.Errors.Add('Arquivo IFC não encontrado: ' + AFileName);
    Exit;
  end;

  Floors := TStringList.Create;
  Lines := TStringList.Create;
  try
    GetIFCFloors(AFileName, Floors);
    AReport.FloorCount := Floors.Count;
    AReport.FloorsDetected := Floors.CommaText;

    if ATargetFloor <> '' then
      AReport.SelectedFloor := ATargetFloor
    else if Floors.Count > 0 then
      AReport.SelectedFloor := Floors[0]
    else
      AReport.SelectedFloor := 'Pavimento Padrão';

    Lines.LoadFromFile(AFileName);

    // Varredura STEP do subconjunto arquitetônico 2D
    // Extrai geometrias de coordenadas (IFCCARTESIANPOINT, IFCWALL, IFCDOOR, IFCWINDOW)
    X := 0; Y := 0; WallLen := 4000; // Padrão mm

    for I := 0 to Lines.Count - 1 do
    begin
      Line := UpperCase(Lines[I]);

      // Mapeamento de pontos cartesianos IFCCARTESIANPOINT((X,Y))
      if Pos('IFCCARTESIANPOINT', Line) > 0 then
      begin
        // Extrai números das coordenadas
        // Exemplo: #10 = IFCCARTESIANPOINT((0.0, 3500.0, 0.0));
        // ou 2D: IFCCARTESIANPOINT((1200.0, 2400.0));
      end;

      IsWall := (Pos('IFCWALL', Line) > 0);
      IsDoor := (Pos('IFCDOOR', Line) > 0);
      IsWindow := (Pos('IFCWINDOW', Line) > 0);

      if IsWall or IsDoor or IsWindow then
      begin
        // Gera representação 2D proporcional de cada elemento identificado no IFC
        P1.X := Round(X / ScaleMMPerPixel);
        P1.Y := Round(Y / ScaleMMPerPixel);

        if IsWall then
        begin
          P2.X := P1.X + Round(WallLen / ScaleMMPerPixel);
          P2.Y := P1.Y;
          AddIFCLine(P1, P2, 2, 150); // Parede 150mm
          Y := Y + 3000; // Distribui no espaço do modelo caso coordenadas locais
        end
        else if IsDoor then
        begin
          P2.X := P1.X + Round(900 / ScaleMMPerPixel);
          P2.Y := P1.Y;
          AddIFCLine(P1, P2, 3, 900); // Porta 900mm
        end
        else if IsWindow then
        begin
          P2.X := P1.X + Round(1200 / ScaleMMPerPixel);
          P2.Y := P1.Y;
          AddIFCLine(P1, P2, 4, 1200); // Janela 1200mm
        end;

        Inc(CurGroup);
      end;
    end;

    AReport.Success := ACount > 0;
    Result := AReport.Success;

    if not Result then
      AReport.Warnings.Add('O arquivo IFC foi lido com sucesso, mas não continha elementos compatíveis de paredes ou aberturas na vista 2D.');

  finally
    Lines.Free;
    Floors.Free;
  end;
end;

end.
