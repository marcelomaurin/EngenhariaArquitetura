unit cad_interop;

{ CAD 2D - Interoperabilidade arquitetônica:
  - Exportação semântica para Maquete 3D (ea_modelo / ea_pacote I-06)
  - Reconhecimento automático de ambientes fechados e áreas (RF2D-009)
  - Exportação PDF vetorial em escala verificável (1:20, 1:50, 1:75, 1:100, 1:200) (RF2D-015)
  - Conversão de entidades do cad2d_importador (DXF/DWG/IFC) para TCADLines }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Types, Math,
  ea_geometria, ea_modelo, ea_pacote, ea_fileio,
  cad_document, cad2d_importador;

function CADConvertImportedEntities(const Entities: array of TImportedEntity;
  Count, ScaleMMPerPixel: Integer): TCADLines;

function CADBuildModelFromLines(const Lines: TCADLines; const Labels: TCADLabels;
  const ProjectName: string): TEAModel;

procedure CADExportModelPackage(const Lines: TCADLines; const Labels: TCADLabels;
  const FileName, ProjectName: string);

function CADDetectRoomsAndLabels(const Lines: TCADLines; var Labels: TCADLabels): Integer;

procedure CADExportScaledPDF(const Lines: TCADLines; const Labels: TCADLabels;
  const FileName, Title: string; ScaleDenom: Integer);

implementation

function CADConvertImportedEntities(const Entities: array of TImportedEntity;
  Count, ScaleMMPerPixel: Integer): TCADLines;
var
  I: Integer;
begin
  Result := nil;
  if Count <= 0 then Exit;
  SetLength(Result, Count);
  for I := 0 to Count - 1 do
  begin
    Result[I].A := Point(Entities[I].A.X * ScaleMMPerPixel, Entities[I].A.Y * ScaleMMPerPixel);
    Result[I].B := Point(Entities[I].B.X * ScaleMMPerPixel, Entities[I].B.Y * ScaleMMPerPixel);
    Result[I].Layer := EnsureRange(Entities[I].Layer, 0, 7);
    Result[I].Kind := EnsureRange(Entities[I].Kind, 0, 9);
    Result[I].WidthMM := Max(0, Entities[I].WidthMM);
    case Result[I].Kind of
      2: begin Result[I].HeightMM := 2800; Result[I].SillMM := 0; if Result[I].WidthMM = 0 then Result[I].WidthMM := 150; end;
      3: begin Result[I].HeightMM := 2100; Result[I].SillMM := 0; if Result[I].WidthMM = 0 then Result[I].WidthMM := 900; end;
      4: begin Result[I].HeightMM := 1200; Result[I].SillMM := 900; if Result[I].WidthMM = 0 then Result[I].WidthMM := 1200; end;
    else
      Result[I].HeightMM := 0;
      Result[I].SillMM := 0;
    end;
    Result[I].GroupID := Max(1, Entities[I].GroupID);
    Result[I].CatalogID := '';
  end;
end;

function CADBuildModelFromLines(const Lines: TCADLines; const Labels: TCADLabels;
  const ProjectName: string): TEAModel;
var
  I, J, BestWall: Integer;
  WallSegs: array of record
    WallId: string;
    A, B: TEAVec2;
    Len: Double;
  end;
  WCount, OCount: Integer;
  Mid, Proj: TEAVec2;
  Dist, BestDist, T, WLen: Double;
  Kind: TEAOpeningKind;
  OpenW, OpenH, OpenSill: Double;
begin
  Result := TEAModel.Create;
  Result.ProjectId := 'cad2d-' + FormatDateTime('yyyymmddhhnnss', Now);
  if Trim(ProjectName) <> '' then Result.ProjectName := ProjectName
  else Result.ProjectName := 'Planta CAD 2D';
  Result.AddFloor('terreo', 'Térreo', 0.0, 2800.0, 150.0);

  WCount := 0;
  for I := 0 to High(Lines) do
  begin
    if Lines[I].Kind <> 2 then Continue;
    Inc(WCount);
    SetLength(WallSegs, WCount);
    WallSegs[WCount - 1].WallId := Format('wall-%d', [WCount]);
    { No CAD 2D o eixo Y de tela aponta para baixo; no modelo 3D Z-up Y aponta para cima }
    WallSegs[WCount - 1].A := EAV2(Lines[I].A.X, -Lines[I].A.Y);
    WallSegs[WCount - 1].B := EAV2(Lines[I].B.X, -Lines[I].B.Y);
    WallSegs[WCount - 1].Len := EAV2Dist(WallSegs[WCount - 1].A, WallSegs[WCount - 1].B);
    Result.AddWall(WallSegs[WCount - 1].WallId, 'terreo',
      WallSegs[WCount - 1].A, WallSegs[WCount - 1].B,
      Max(50.0, Lines[I].WidthMM), Max(500.0, Lines[I].HeightMM), 'ARQ_PAREDES');
  end;

  { Vincular portas (3) e janelas (4, 9) a parede hospedeira mais proxima }
  OCount := 0;
  for I := 0 to High(Lines) do
  begin
    if not (Lines[I].Kind in [3, 4, 9]) then Continue;
    if Length(WallSegs) = 0 then Continue;
    Mid := EAV2((Lines[I].A.X + Lines[I].B.X) * 0.5, -(Lines[I].A.Y + Lines[I].B.Y) * 0.5);
    BestWall := -1;
    BestDist := 1e12;
    for J := 0 to High(WallSegs) do
    begin
      Dist := EAPointToSegmentDist2D(Mid, WallSegs[J].A, WallSegs[J].B, Proj, T);
      if Dist < BestDist then
      begin
        BestDist := Dist;
        BestWall := J;
      end;
    end;
    if (BestWall >= 0) and (BestDist <= 400.0) then
    begin
      Inc(OCount);
      if Lines[I].Kind = 3 then
      begin
        Kind := eokDoor;
        OpenH := Max(1800.0, Lines[I].HeightMM);
        OpenSill := 0.0;
      end
      else
      begin
        Kind := eokWindow;
        OpenH := Max(400.0, Lines[I].HeightMM);
        OpenSill := Max(0.0, Lines[I].SillMM);
      end;
      OpenW := Max(300.0, Hypot(Lines[I].B.X - Lines[I].A.X, Lines[I].B.Y - Lines[I].A.Y));
      EAPointToSegmentDist2D(Mid, WallSegs[BestWall].A, WallSegs[BestWall].B, Proj, T);
      WLen := WallSegs[BestWall].Len;
      Result.AddOpening(Format('open-%d', [OCount]), WallSegs[BestWall].WallId, 'terreo',
        Kind, EnsureRange(T * WLen - OpenW * 0.5, 0.0, Max(0.0, WLen - OpenW)),
        OpenW, OpenH, OpenSill);
    end;
  end;

  Result.AutoGenerateSlabsAndRooms;
  { Aplicar nomes de rotulos de ambiente se existirem dentro do poligono }
  for I := 0 to High(Result.Rooms) do
    for J := 0 to High(Labels) do
      if EAPointInPolygon2D(EAV2(Labels[J].X, -Labels[J].Y), Result.Rooms[I].Polygon) then
      begin
        Result.Rooms[I].Name := Labels[J].Text;
        Break;
      end;
end;

procedure CADExportModelPackage(const Lines: TCADLines; const Labels: TCADLabels;
  const FileName, ProjectName: string);
var
  M: TEAModel;
begin
  M := CADBuildModelFromLines(Lines, Labels, ProjectName);
  try
    M.SaveToPackageFile(FileName, 'CAD2D');
  finally
    M.Free;
  end;
end;

function CADDetectRoomsAndLabels(const Lines: TCADLines; var Labels: TCADLabels): Integer;
var
  Segs: TEASegment2DArray;
  Rooms: TEARoomLoopArray;
  I, N, BaseLen: Integer;
begin
  Segs := nil;
  N := 0;
  for I := 0 to High(Lines) do
  begin
    if Lines[I].Kind <> 2 then Continue;
    SetLength(Segs, N + 1);
    Segs[N].Id := Format('w-%d', [N + 1]);
    Segs[N].A := EAV2(Lines[I].A.X, -Lines[I].A.Y);
    Segs[N].B := EAV2(Lines[I].B.X, -Lines[I].B.Y);
    Inc(N);
  end;
  Rooms := EADetectClosedRooms(Segs, 40.0);
  Result := Length(Rooms);
  if Result = 0 then Exit;
  BaseLen := Length(Labels);
  SetLength(Labels, BaseLen + Result);
  for I := 0 to Result - 1 do
  begin
    Labels[BaseLen + I].Text := Format('Ambiente %d (%.2f m2)', [I + 1, Rooms[I].AreaMM2 / 1000000.0]);
    Labels[BaseLen + I].X := Round(Rooms[I].Centroid.X);
    Labels[BaseLen + I].Y := Round(-Rooms[I].Centroid.Y);
  end;
end;

procedure CADExportScaledPDF(const Lines: TCADLines; const Labels: TCADLabels;
  const FileName, Title: string; ScaleDenom: Integer);
const
  { Pagina A3 paisagem em pontos (1 pt = 1/72 pol = 25.4/72 mm) }
  PAGE_W_MM = 420.0;
  PAGE_H_MM = 297.0;
  MM_TO_PT = 72.0 / 25.4;
var
  MinX, MinY, MaxX, MaxY, ModelW, ModelH, ScaleFactor, OffXMM, OffYMM: Double;
  I: Integer;
  Stream: TStringList;
  FS: TFormatSettings;
  Content, OutStr: RawByteString;
  Offsets: array of Integer;
  XRefPos: Integer;
  function FmtPt(V: Double): string;
  begin
    Result := Format('%.2f', [V], FS);
  end;
  function PDFEsc(const S: string): string;
  var
    K: Integer;
    Ch: Char;
  begin
    Result := '';
    for K := 1 to Length(S) do
    begin
      Ch := S[K];
      if (Ch = '(') or (Ch = ')') or (Ch = '\') then Result := Result + '\' + Ch
      else if Ord(Ch) < 128 then Result := Result + Ch
      else Result := Result + '?';
    end;
  end;
  function MapXPt(XMM: Double): Double;
  begin
    Result := (OffXMM + (XMM - MinX) * ScaleFactor) * MM_TO_PT;
  end;
  function MapYPt(YMM: Double): Double;
  begin
    { CAD Y positivo aponta para baixo; PDF Y positivo aponta para cima }
    Result := (OffYMM + (MaxY - YMM) * ScaleFactor) * MM_TO_PT;
  end;
  procedure AddObj(const Body: string);
  var
    N: Integer;
  begin
    N := Length(Offsets);
    SetLength(Offsets, N + 1);
    Offsets[N] := Length(OutStr);
    OutStr := OutStr + IntToStr(N + 1) + ' 0 obj' + #10 + Body + #10 + 'endobj' + #10;
  end;
var
  PageW, PageH: Double;
  LineW: Double;
begin
  if ScaleDenom < 1 then ScaleDenom := 50;
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

  MinX := 0; MinY := 0; MaxX := 4000; MaxY := 3000;
  if Length(Lines) > 0 then
  begin
    MinX := Lines[0].A.X; MaxX := MinX;
    MinY := Lines[0].A.Y; MaxY := MinY;
    for I := 0 to High(Lines) do
    begin
      MinX := Min(MinX, Min(Lines[I].A.X, Lines[I].B.X));
      MinY := Min(MinY, Min(Lines[I].A.Y, Lines[I].B.Y));
      MaxX := Max(MaxX, Max(Lines[I].A.X, Lines[I].B.X));
      MaxY := Max(MaxY, Max(Lines[I].A.Y, Lines[I].B.Y));
    end;
  end;
  ScaleFactor := 1.0 / ScaleDenom;
  ModelW := (MaxX - MinX) * ScaleFactor;
  ModelH := (MaxY - MinY) * ScaleFactor;
  OffXMM := Max(15.0, (PAGE_W_MM - 20.0 - ModelW) * 0.5);
  OffYMM := Max(28.0, (PAGE_H_MM - 20.0 - ModelH) * 0.5);

  PageW := PAGE_W_MM * MM_TO_PT;
  PageH := PAGE_H_MM * MM_TO_PT;

  Stream := TStringList.Create;
  try
    { Margem e carimbo ABNT }
    Stream.Add('0.15 0.15 0.15 RG 0.8 w');
    Stream.Add(Format('%s %s %s %s re S', [FmtPt(10 * MM_TO_PT), FmtPt(10 * MM_TO_PT),
      FmtPt((PAGE_W_MM - 20) * MM_TO_PT), FmtPt((PAGE_H_MM - 20) * MM_TO_PT)]));
    Stream.Add(Format('%s %s %s %s re S', [FmtPt((PAGE_W_MM - 125) * MM_TO_PT), FmtPt(10 * MM_TO_PT),
      FmtPt(115 * MM_TO_PT), FmtPt(22 * MM_TO_PT)]));
    Stream.Add(Format('BT /F1 10 Tf %s %s Td (%s) Tj ET', [
      FmtPt((PAGE_W_MM - 121) * MM_TO_PT), FmtPt(24 * MM_TO_PT), PDFEsc(Title)]));
    Stream.Add(Format('BT /F1 8 Tf %s %s Td (Escala 1:%d | Unidade: mm | ABNT NBR 6492) Tj ET', [
      FmtPt((PAGE_W_MM - 121) * MM_TO_PT), FmtPt(14 * MM_TO_PT), ScaleDenom]));

    { Entidades em escala fisica exata }
    for I := 0 to High(Lines) do
    begin
      case Lines[I].Kind of
        2: begin Stream.Add('0.10 0.25 0.55 RG'); LineW := Max(1.2, Lines[I].WidthMM * ScaleFactor * MM_TO_PT * 0.35); end;
        3: begin Stream.Add('0.65 0.35 0.05 RG'); LineW := 0.9; end;
        4, 9: begin Stream.Add('0.05 0.50 0.70 RG'); LineW := 0.9; end;
      else
        Stream.Add('0.20 0.20 0.25 RG'); LineW := 0.6;
      end;
      Stream.Add(Format('%s w %s %s m %s %s l S', [
        FmtPt(LineW),
        FmtPt(MapXPt(Lines[I].A.X)), FmtPt(MapYPt(Lines[I].A.Y)),
        FmtPt(MapXPt(Lines[I].B.X)), FmtPt(MapYPt(Lines[I].B.Y))]));
    end;

    for I := 0 to High(Labels) do
      Stream.Add(Format('BT /F1 8 Tf 0.1 0.1 0.1 rg %s %s Td (%s) Tj ET', [
        FmtPt(MapXPt(Labels[I].X)), FmtPt(MapYPt(Labels[I].Y)), PDFEsc(Labels[I].Text)]));

    Content := Stream.Text;
    OutStr := '%PDF-1.4' + #10;
    SetLength(Offsets, 0);
    AddObj('<< /Type /Catalog /Pages 2 0 R >>');
    AddObj('<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    AddObj(Format('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %s %s] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
      [FmtPt(PageW), FmtPt(PageH)]));
    AddObj('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
    AddObj('<< /Length ' + IntToStr(Length(Content)) + ' >>' + #10 + 'stream' + #10 + Content + 'endstream');

    XRefPos := Length(OutStr);
    OutStr := OutStr + 'xref' + #10 + '0 ' + IntToStr(Length(Offsets) + 1) + #10;
    OutStr := OutStr + '0000000000 65535 f ' + #10;
    for I := 0 to High(Offsets) do
      OutStr := OutStr + Format('%.10d 00000 n ', [Offsets[I]]) + #10;
    OutStr := OutStr + 'trailer' + #10 + '<< /Size ' + IntToStr(Length(Offsets) + 1) + ' /Root 1 0 R >>' + #10;
    OutStr := OutStr + 'startxref' + #10 + IntToStr(XRefPos) + #10 + '%%EOF' + #10;
    EAAtomicWriteText(FileName, OutStr);
  finally
    Stream.Free;
  end;
end;

end.
