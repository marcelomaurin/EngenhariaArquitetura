unit ea_money;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses SysUtils, Math;
function EAMoneyParse(const Text: string; MaximumCents: Int64=1000000000000): Int64;
function EAMoneyText(Cents: Int64): string;
function EALineCost(Quantity: Double; UnitCents: Int64): Int64;
implementation
function EAMoneyParse(const Text: string; MaximumCents: Int64): Int64;
var S,Whole,Fraction: string; P,I: Integer; V: Int64;
begin
 S:=Trim(StringReplace(Text,'R$','',[])); if S='' then Exit(0);
 if Pos(',',S)>0 then begin S:=StringReplace(S,'.','',[rfReplaceAll]); S:=StringReplace(S,',','.',[]); end;
 P:=Pos('.',S); if P=0 then begin Whole:=S; Fraction:=''; end else begin Whole:=Copy(S,1,P-1); Fraction:=Copy(S,P+1,Length(S)); end;
 if (Whole='') or (Length(Fraction)>2) then raise Exception.Create('Valor monetário inválido; use até duas casas decimais');
 for I:=1 to Length(Whole) do if not (Whole[I] in ['0'..'9']) then raise Exception.Create('Valor monetário deve ser positivo');
 for I:=1 to Length(Fraction) do if not (Fraction[I] in ['0'..'9']) then raise Exception.Create('Valor monetário inválido');
 while Length(Fraction)<2 do Fraction:=Fraction+'0';
 if not TryStrToInt64(Whole,V) or (V>MaximumCents div 100) then raise Exception.Create('Valor monetário fora do limite');
 Result:=V*100+StrToInt(Fraction); if Result>MaximumCents then raise Exception.Create('Valor monetário fora do limite');
end;
function EAMoneyText(Cents: Int64): string;
var F: TFormatSettings;
begin F:=DefaultFormatSettings; F.DecimalSeparator:=','; F.ThousandSeparator:='.'; Result:=FormatCurr('"R$ "#,##0.00',Currency(Cents)/100,F); end;
function EALineCost(Quantity: Double; UnitCents: Int64): Int64;
var V: Extended;
begin
 if IsNan(Quantity) or IsInfinite(Quantity) or (Quantity<0) or (UnitCents<0) then raise Exception.Create('Quantidade ou preço inválido');
 V:=Quantity*UnitCents; if V>9000000000000000 then raise Exception.Create('Custo excede o limite');
 Result:=Trunc(V+0.5+0.000000001);
end;
end.
