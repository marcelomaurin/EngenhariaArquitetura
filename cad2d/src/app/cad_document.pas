unit cad_document;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Types, Math, fpjson, jsonparser, ea_fileio;
type
  TCADLine = record
    A,B: TPoint;
    CatalogID: string;
    Layer,Kind,WidthMM,HeightMM,SillMM,GroupID: Integer;
  end;
  TCADLines = array of TCADLine;
  TCADLabel = record Text: string; X,Y: Integer; end;
  TCADLabels = array of TCADLabel;
  TCADLayers = array[0..7] of Boolean;
  TCADDocument = class
  public
    Lines: TCADLines;
    Labels: TCADLabels;
    GridMM: Integer;
    Visible,Locked: TCADLayers;
    constructor Create;
    procedure Load(const FileName: string);
    procedure LoadText(const Content: string);
    procedure Save(const FileName: string);
    function Text: string;
  end;
implementation
const MAX_COORD=10000000; MAX_ENTITIES=200000;
constructor TCADDocument.Create;
var I: Integer;
begin inherited Create; GridMM:=1000; for I:=0 to 7 do begin Visible[I]:=True; Locked[I]:=False; end; end;
function Coordinate(const S: string; Scale: Integer): Integer;
var V: Int64;
begin
  if not TryStrToInt64(S,V) then raise EConvertError.Create('Coordenada inválida');
  if (V < -MAX_COORD div Scale) or (V > MAX_COORD div Scale) then raise EConvertError.Create('Coordenada fora do limite de 10 km');
  Result:=V*Scale;
end;
procedure Validate(const L: TCADLine);
var I: Integer;
begin
  if Length(L.CatalogID)>128 then raise EConvertError.Create('Identificador de biblioteca inválido');
  for I:=1 to Length(L.CatalogID) do if not (L.CatalogID[I] in ['a'..'z','0'..'9','_','-']) then raise EConvertError.Create('Identificador de biblioteca inválido');
  if (L.Layer<0) or (L.Layer>7) or (L.Kind<0) or (L.Kind>9) or
    (L.GroupID<1) or (L.GroupID>100000000) or
    (Abs(Int64(L.A.X))>MAX_COORD) or (Abs(Int64(L.A.Y))>MAX_COORD) or
    (Abs(Int64(L.B.X))>MAX_COORD) or (Abs(Int64(L.B.Y))>MAX_COORD) or
    (L.WidthMM<0) or (L.WidthMM>1000000) or (L.HeightMM<0) or (L.HeightMM>1000000) or
    (L.SillMM<0) or (L.SillMM>1000000) then raise EConvertError.Create('Objeto ou dimensão inválida');
end;
procedure TCADDocument.Load(const FileName: string);
var Stream: TFileStream; L: TStringList;
begin
  L:=TStringList.Create;
  try
    Stream:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
    try if Stream.Size>64*1024*1024 then raise EConvertError.Create('Arquivo maior que o limite de 64 MB'); L.LoadFromStream(Stream); finally Stream.Free; end;
    LoadText(L.Text);
  finally L.Free; end;
end;
procedure TCADDocument.LoadText(const Content: string);
var L,F: TStringList; V: TCADDocument; I,J,Version,Scale,Start,N: Integer;
  MetaData: TJSONData; Meta: TJSONObject; A: TJSONArray; LabelObject: TJSONObject;
begin
  L:=TStringList.Create; F:=TStringList.Create; V:=TCADDocument.Create;
  try
    if Length(Content)>64*1024*1024 then raise EConvertError.Create('Arquivo maior que o limite de 64 MB');
    L.Text:=Content;
    if (L.Count<2) or (Copy(L[0],1,5)<>'EACAD') or not TryStrToInt(Copy(L[0],6,MaxInt),Version) or (Version<1) or (Version>5) then
      raise EConvertError.Create('Formato de projeto não reconhecido');
    if not TryStrToInt(L[1],Scale) or (Scale<1) or (Scale>100000) then raise EConvertError.Create('Escala inválida');
    Start:=2;
    if Version>=4 then begin
      if (L.Count<3) or (Copy(L[2],1,5)<>'META ') then raise EConvertError.Create('Configurações do projeto ausentes');
      MetaData:=GetJSON(Copy(L[2],6,MaxInt));
      try
        if not (MetaData is TJSONObject) then raise EConvertError.Create('Configurações inválidas');
        Meta:=TJSONObject(MetaData);
        if Meta.Get('units','')<>'mm' then raise EConvertError.Create('Unidades incompatíveis');
        V.GridMM:=Meta.Get('grid_mm',1000);
        if (V.GridMM<1) or (V.GridMM>1000000) then raise EConvertError.Create('Grade inválida');
        A:=Meta.Arrays['visible']; if A.Count<>8 then raise EConvertError.Create('Camadas inválidas');
        for J:=0 to 7 do begin if A.Types[J]<>jtBoolean then raise EConvertError.Create('Visibilidade inválida'); V.Visible[J]:=A.Booleans[J]; end;
        A:=Meta.Arrays['locked']; if A.Count<>8 then raise EConvertError.Create('Bloqueios inválidos');
        for J:=0 to 7 do begin if A.Types[J]<>jtBoolean then raise EConvertError.Create('Bloqueio inválido'); V.Locked[J]:=A.Booleans[J]; end;
        if Meta.Find('labels')<>nil then begin
          A:=Meta.Arrays['labels']; if A.Count>5000 then raise EConvertError.Create('Limite de anotações excedido');
          SetLength(V.Labels,A.Count);
          for J:=0 to A.Count-1 do begin
            LabelObject:=A.Objects[J]; V.Labels[J].Text:=LabelObject.Get('text','');
            V.Labels[J].X:=LabelObject.Get('x',0); V.Labels[J].Y:=LabelObject.Get('y',0);
            if (Length(V.Labels[J].Text)>200) or (Abs(Int64(V.Labels[J].X))>MAX_COORD) or (Abs(Int64(V.Labels[J].Y))>MAX_COORD) then raise EConvertError.Create('Anotação inválida');
          end;
        end;
      finally MetaData.Free; end;
      Start:=3;
    end;
    if L.Count-Start>MAX_ENTITIES then raise EConvertError.Create('Limite de entidades excedido');
    SetLength(V.Lines,L.Count-Start); F.Delimiter:=';'; F.StrictDelimiter:=True;
    for I:=Start to L.Count-1 do begin
      F.DelimitedText:=L[I]; N:=I-Start;
      if ((Version=1) and (F.Count<>6)) or ((Version=2) and (F.Count<>7)) or
         ((Version=3) and (F.Count<>8)) or ((Version=4) and (F.Count<>10)) or ((Version=5) and (F.Count<>11)) then raise EConvertError.CreateFmt('Linha %d inválida',[I+1]);
      V.Lines[N].A:=Point(Coordinate(F[0],Scale),Coordinate(F[1],Scale));
      V.Lines[N].B:=Point(Coordinate(F[2],Scale),Coordinate(F[3],Scale));
      V.Lines[N].Layer:=StrToInt(F[4]); V.Lines[N].Kind:=StrToInt(F[5]);
      if Version>=2 then V.Lines[N].WidthMM:=StrToInt(F[6]) else
        case V.Lines[N].Kind of 2: V.Lines[N].WidthMM:=150; 3: V.Lines[N].WidthMM:=900; 4: V.Lines[N].WidthMM:=1200; else V.Lines[N].WidthMM:=0; end;
      if Version>=3 then V.Lines[N].GroupID:=StrToInt(F[7]) else V.Lines[N].GroupID:=N+1;
      if Version>=4 then begin V.Lines[N].HeightMM:=StrToInt(F[8]); V.Lines[N].SillMM:=StrToInt(F[9]); end
      else begin
        case V.Lines[N].Kind of 2: V.Lines[N].HeightMM:=2800; 3: V.Lines[N].HeightMM:=2100; 9: V.Lines[N].HeightMM:=600; else V.Lines[N].HeightMM:=1200; end;
        if V.Lines[N].Kind=9 then V.Lines[N].SillMM:=1600 else if V.Lines[N].Kind=3 then V.Lines[N].SillMM:=0 else V.Lines[N].SillMM:=900;
      end;
      if Version=5 then V.Lines[N].CatalogID:=F[10] else V.Lines[N].CatalogID:='';
      Validate(V.Lines[N]);
    end;
    Lines:=V.Lines; Labels:=V.Labels; GridMM:=V.GridMM; Visible:=V.Visible; Locked:=V.Locked;
  finally V.Free; F.Free; L.Free; end;
end;
function TCADDocument.Text: string;
var L: TStringList; Meta,LabelObject: TJSONObject; A,B,LabelArray: TJSONArray; I: Integer;
begin
  if (Length(Lines)>MAX_ENTITIES) or (GridMM<1) or (GridMM>1000000) then raise EConvertError.Create('Documento inválido');
  L:=TStringList.Create; Meta:=TJSONObject.Create;
  try
    Meta.Add('units','mm'); Meta.Add('grid_mm',GridMM); A:=TJSONArray.Create; B:=TJSONArray.Create;
    for I:=0 to 7 do begin A.Add(Visible[I]); B.Add(Locked[I]); end;
    Meta.Add('visible',A); Meta.Add('locked',B);
    LabelArray:=TJSONArray.Create; Meta.Add('labels',LabelArray);
    if Length(Labels)>5000 then raise EConvertError.Create('Limite de anotações excedido');
    for I:=0 to High(Labels) do begin
      if (Length(Labels[I].Text)>200) or (Abs(Int64(Labels[I].X))>MAX_COORD) or (Abs(Int64(Labels[I].Y))>MAX_COORD) then raise EConvertError.Create('Anotação inválida');
      LabelObject:=TJSONObject.Create; LabelObject.Add('text',Labels[I].Text); LabelObject.Add('x',Labels[I].X); LabelObject.Add('y',Labels[I].Y); LabelArray.Add(LabelObject);
    end;
    L.Add('EACAD5'); L.Add('1'); L.Add('META '+Meta.AsJSON);
    for I:=0 to High(Lines) do begin
      Validate(Lines[I]);
      with Lines[I] do L.Add(Format('%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%s',[A.X,A.Y,B.X,B.Y,Layer,Kind,WidthMM,GroupID,HeightMM,SillMM,CatalogID]));
    end;
    Result:=L.Text;
  finally Meta.Free; L.Free; end;
end;
procedure TCADDocument.Save(const FileName: string);
begin EAAtomicWriteText(FileName,Text); end;
end.
