program gerar_exemplo;

{ Gera examples/residencia.plan.json a partir de plan_exemplos.
  Uso: gerar_exemplo <arquivo-de-saida> [aaaa-mm-dd] }

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils, plan_documento, plan_exemplos, plan_json;

var
  Doc: TPLProjeto;
  Inicio: TDateTime;
begin
  DefaultSystemCodePage := CP_UTF8;
  SetMultiByteConversionCodePage(CP_UTF8);
  if ParamCount < 1 then
  begin
    WriteLn('uso: gerar_exemplo <arquivo-de-saida> [aaaa-mm-dd]');
    Halt(2);
  end;
  Inicio := EncodeDate(2026, 11, 3);
  if ParamCount >= 2 then Inicio := ScanDateTime('yyyy-mm-dd', ParamStr(2));
  Doc := TPLProjeto.Create;
  try
    PLCarregarExemploResidencia(Doc, Inicio);
    PLSalvarProjeto(Doc, ParamStr(1));
    WriteLn('gerado: ', ParamStr(1));
  finally
    Doc.Free;
  end;
end.
