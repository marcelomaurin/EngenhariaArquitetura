unit cad_dxf;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Types, Math, cad_document;
procedure CADImportDXF(const FileName: string; Doc: TCADDocument; out Report: string);
implementation
function LayerIndex(const Name: string; out Known: Boolean): Integer;
const Names: array[0..7] of string=('ARQ_PAREDES','ARQ_ESQUADRIAS','MOBILIARIO','ARQ_COTAS','ARQ_TEXTOS','ARQ_PROJECOES','ARQ_ESTRUTURA','ARQ_PISOS');
var I: Integer; N: string;
begin
  N:=StringReplace(StringReplace(UpperCase(Name),'Á','A',[rfReplaceAll]),'Í','I',[rfReplaceAll]);
  Known:=True; for I:=0 to 7 do if N=Names[I] then Exit(I);
  Result:=0; Known:=(N='') or (N='0');
end;
procedure CADImportDXF(const FileName: string; Doc: TCADDocument; out Report: string);
var L: TStringList; Stream: TFileStream; Temp: TCADDocument; Entity: TCADLine;
  I,J,Code,Units,N,Ignored,Unknown,Rounded: Integer; Section,Kind,Layer: string;
  Scale,X1,Y1,X2,Y2,Z1,Z2,NX,NY,NZ,V: Double; FS: TFormatSettings;
  HasX1,HasY1,HasX2,HasY2,Known,Found: Boolean;
  function Number(const Text: string): Double;
  begin if not TryStrToFloat(Trim(Text),Result,FS) or IsNan(Result) or IsInfinite(Result) then raise EConvertError.Create('Número inválido no DXF'); end;
  function Coord(Value: Double): Integer;
  begin
    V:=Value*Scale;
    if Abs(V)>10000000 then raise EConvertError.Create('Coordenada DXF fora do limite de 10 km');
    Result:=Round(V); if Abs(V-Result)>0.000001 then Inc(Rounded);
  end;
begin
  L:=TStringList.Create; Temp:=TCADDocument.Create;
  try
    Stream:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
    try if Stream.Size>64*1024*1024 then raise EConvertError.Create('DXF maior que 64 MB'); L.LoadFromStream(Stream); finally Stream.Free; end;
    if (L.Count mod 2)<>0 then raise EConvertError.Create('DXF incompleto: pares de código/valor inválidos');
    FS:=DefaultFormatSettings; FS.DecimalSeparator:='.'; FS.ThousandSeparator:=#0;
    Units:=0; I:=0;
    while I<L.Count do begin
      if not TryStrToInt(Trim(L[I]),Code) then raise EConvertError.Create('Código de grupo DXF inválido');
      if (Code=9) and (Trim(L[I+1])='$INSUNITS') then begin
        if (I+3>=L.Count) or not TryStrToInt(Trim(L[I+3]),Units) then raise EConvertError.Create('Unidade DXF inválida');
      end;
      Inc(I,2);
    end;
    case Units of 0,4: Scale:=1; 1: Scale:=25.4; 2: Scale:=304.8; 5: Scale:=10; 6: Scale:=1000;
    else raise EConvertError.Create('Unidade DXF não suportada. Converta o arquivo para milímetros.'); end;
    Section:=''; Found:=False; I:=0; Ignored:=0; Unknown:=0; Rounded:=0;
    while I<L.Count do begin
      Code:=StrToInt(Trim(L[I])); Kind:=UpperCase(Trim(L[I+1]));
      if (Code=0) and (Kind='SECTION') then begin
        if (I+3>=L.Count) or (Trim(L[I+2])<>'2') then raise EConvertError.Create('Seção DXF inválida');
        Section:=UpperCase(Trim(L[I+3])); if Section='ENTITIES' then Found:=True;
        Inc(I,4); Continue;
      end;
      if (Code=0) and (Kind='ENDSEC') then begin Section:=''; Inc(I,2); Continue; end;
      if (Section<>'ENTITIES') or (Code<>0) then begin Inc(I,2); Continue; end;
      J:=I+2; while (J<L.Count) and (StrToInt(Trim(L[J]))<>0) do Inc(J,2);
      if Kind<>'LINE' then begin Inc(Ignored); I:=J; Continue; end;
      HasX1:=False; HasY1:=False; HasX2:=False; HasY2:=False;
      X1:=0; Y1:=0; X2:=0; Y2:=0; Z1:=0; Z2:=0; NX:=0; NY:=0; NZ:=1; Layer:='0';
      Inc(I,2);
      while I<J do begin
        Code:=StrToInt(Trim(L[I]));
        case Code of
          8: Layer:=Trim(L[I+1]);
          10: begin X1:=Number(L[I+1]); HasX1:=True; end;
          20: begin Y1:=Number(L[I+1]); HasY1:=True; end;
          11: begin X2:=Number(L[I+1]); HasX2:=True; end;
          21: begin Y2:=Number(L[I+1]); HasY2:=True; end;
          30: Z1:=Number(L[I+1]); 31: Z2:=Number(L[I+1]);
          210: NX:=Number(L[I+1]); 220: NY:=Number(L[I+1]); 230: NZ:=Number(L[I+1]);
        end;
        Inc(I,2);
      end;
      if not (HasX1 and HasY1 and HasX2 and HasY2) then raise EConvertError.Create('Linha DXF sem coordenadas completas');
      if (Abs(Z1)>0.000001) or (Abs(Z2)>0.000001) or (Abs(NX)>0.000001) or (Abs(NY)>0.000001) or (Abs(NZ-1)>0.000001) then begin Inc(Ignored); Continue; end;
      FillChar(Entity,SizeOf(Entity),0); Entity.A:=Point(Coord(X1),Coord(-Y1)); Entity.B:=Point(Coord(X2),Coord(-Y2));
      Entity.Layer:=LayerIndex(Layer,Known); if not Known then Inc(Unknown);
      N:=Length(Temp.Lines); if N>=200000 then raise EConvertError.Create('Limite de entidades DXF excedido');
      Entity.GroupID:=N+1; SetLength(Temp.Lines,N+1); Temp.Lines[N]:=Entity;
    end;
    if not Found then raise EConvertError.Create('DXF sem seção ENTITIES');
    if Length(Temp.Lines)=0 then raise EConvertError.Create('Nenhuma entidade LINE 2D compatível encontrada');
    Report:=Format('%d linhas 2D; %d entidades ignoradas; %d linhas com camada mapeada para ARQ_PAREDES; %d coordenadas arredondadas a 1 mm.',[Length(Temp.Lines),Ignored,Unknown,Rounded]);
    if Units=0 then Report:=Report+LineEnding+'Sem unidade declarada: serão usados milímetros.';
    Doc.Lines:=Temp.Lines; Doc.GridMM:=Temp.GridMM; Doc.Visible:=Temp.Visible; Doc.Locked:=Temp.Locked;
  finally Temp.Free; L.Free; end;
end;
end.
