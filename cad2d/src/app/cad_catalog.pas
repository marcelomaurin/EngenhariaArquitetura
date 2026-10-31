unit cad_catalog;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Types, Math, fpjson, jsonparser, cad_document;
type
  TCADCatalog = class
  private
    FData: TJSONObject;
  public
    constructor Create(const FileName: string);
    destructor Destroy; override;
    function Items: TJSONArray;
    function Item(const ID: string): TJSONObject;
    function BuildLines(const ID: string; const Origin: TPoint; WidthMM,DepthMM,GroupID: Integer): TCADLines;
  end;
function CADCatalogFile: string;
implementation
function CADCatalogFile: string;
var Base: string;
begin
  Base:=ExtractFilePath(ParamStr(0));
  Result:=Base+'bibliotecas'+DirectorySeparator+'catalogo_2d.json';
  if FileExists(Result) then Exit;
  Result:=ExpandFileName(Base+'..'+DirectorySeparator+'libraries'+DirectorySeparator+'catalogo_2d.json');
  if FileExists(Result) then Exit;
  Result:=ExpandFileName('libraries'+DirectorySeparator+'catalogo_2d.json');
  if not FileExists(Result) then raise Exception.Create('Biblioteca 2D não encontrada. Reinstale o pacote de bibliotecas.');
end;
constructor TCADCatalog.Create(const FileName: string);
var L: TStringList; Data: TJSONData; I,J: Integer; O: TJSONObject;
begin
  inherited Create; L:=TStringList.Create;
  try
    L.LoadFromFile(FileName); Data:=GetJSON(L.Text);
    if not (Data is TJSONObject) then begin Data.Free; raise Exception.Create('Biblioteca inválida'); end;
    FData:=TJSONObject(Data);
    if FData.Get('units','')<>'mm' then raise Exception.Create('Biblioteca precisa usar milímetros');
    if FData.Get('schema_version',0)<>1 then raise Exception.Create('Versão de biblioteca não suportada');
    if (Items.Count=0) or (Items.Count>10000) then raise Exception.Create('Quantidade de itens inválida');
    for I:=0 to Items.Count-1 do begin
      O:=Items.Objects[I];
      if (O.Get('id','')='') or (O.Get('name','')='') or (O.Get('category','')='') or
        (O.Get('width_mm',0)<10) or (O.Get('depth_mm',0)<10) or (O.Get('width_mm',0)>1000000) or (O.Get('depth_mm',0)>1000000) or (O.Arrays['shapes'].Count=0) then raise Exception.Create('Item de biblioteca incompleto');
      for J:=0 to I-1 do if Items.Objects[J].Get('id','')=O.Get('id','') then raise Exception.Create('ID de biblioteca duplicado');
    end;
  finally L.Free; end;
end;
destructor TCADCatalog.Destroy;
begin FData.Free; inherited Destroy; end;
function TCADCatalog.Items: TJSONArray;
begin Result:=FData.Arrays['items']; end;
function TCADCatalog.Item(const ID: string): TJSONObject;
var I: Integer;
begin
  for I:=0 to Items.Count-1 do if Items.Objects[I].Get('id','')=ID then Exit(Items.Objects[I]);
  raise Exception.Create('Item de biblioteca não encontrado: '+ID);
end;
function TCADCatalog.BuildLines(const ID: string; const Origin: TPoint; WidthMM,DepthMM,GroupID: Integer): TCADLines;
var O: TJSONObject; Shapes: TJSONArray; Shape: TJSONArray; I,K,N: Integer;
  X1,Y1,X2,Y2,CX,CY,RX,RY,A: Double; P,Q: TPoint;
  function PointAt(X,Y: Double): TPoint;
  var PX,PY: Int64;
  begin
    PX:=Int64(Origin.X)+Round(X*WidthMM/1000); PY:=Int64(Origin.Y)+Round(Y*DepthMM/1000);
    if (Abs(PX)>10000000) or (Abs(PY)>10000000) then raise Exception.Create('Bloco fora do limite do desenho');
    Result:=Point(PX,PY);
  end;
  procedure Segment(const FromP,ToP: TPoint);
  begin
    N:=Length(Result); SetLength(Result,N+1);
    Result[N].A:=FromP; Result[N].B:=ToP; Result[N].Layer:=2;
    Result[N].Kind:=0; Result[N].WidthMM:=0; Result[N].GroupID:=GroupID;
    Result[N].CatalogID:=ID;
  end;
begin
  Result:=nil;
  if (WidthMM<10) or (DepthMM<10) or (WidthMM>1000000) or (DepthMM>1000000) or (GroupID<1) then raise Exception.Create('Dimensões de bloco inválidas');
  O:=Item(ID); Shapes:=O.Arrays['shapes'];
  for I:=0 to Shapes.Count-1 do begin
    Shape:=Shapes.Arrays[I]; if Shape.Count<>5 then raise Exception.Create('Geometria de biblioteca inválida');
    X1:=Shape.Floats[1]; Y1:=Shape.Floats[2]; X2:=Shape.Floats[3]; Y2:=Shape.Floats[4];
    if (IsNan(X1) or IsNan(Y1) or IsNan(X2) or IsNan(Y2)) or
      (Abs(X1)>10000) or (Abs(Y1)>10000) or (Abs(X2)>10000) or (Abs(Y2)>10000) then raise Exception.Create('Coordenada de biblioteca inválida');
    case Shape.Strings[0] of
      'line': Segment(PointAt(X1,Y1),PointAt(X2,Y2));
      'rect': begin Segment(PointAt(X1,Y1),PointAt(X2,Y1)); Segment(PointAt(X2,Y1),PointAt(X2,Y2)); Segment(PointAt(X2,Y2),PointAt(X1,Y2)); Segment(PointAt(X1,Y2),PointAt(X1,Y1)); end;
      'ellipse': begin
        CX:=(X1+X2)/2; CY:=(Y1+Y2)/2; RX:=Abs(X2-X1)/2; RY:=Abs(Y2-Y1)/2;
        P:=PointAt(CX+RX,CY);
        for K:=1 to 32 do begin A:=2*Pi*K/32; Q:=PointAt(CX+RX*Cos(A),CY+RY*Sin(A)); Segment(P,Q); P:=Q; end;
      end;
    else raise Exception.Create('Primitiva de biblioteca não suportada'); end;
  end;
end;
end.
