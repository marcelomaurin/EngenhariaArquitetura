program gerar_exemplos_saude;
{$mode objfpc}{$H+}{$codepage utf8}
uses SysUtils, DateUtils, cad_catalog, cad_health_examples, cad_document,
  plan_documento, plan_exemplos, plan_json;
var C: TCADCatalog; D: TCADDocument; P: TPLProjeto; Root: string;
begin
  DefaultSystemCodePage:=CP_UTF8; SetMultiByteConversionCodePage(CP_UTF8);
  Root:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  C:=TCADCatalog.Create(Root+'libraries/catalogo_2d.json'); P:=TPLProjeto.Create;
  try
    ForceDirectories(Root+'cad2d/examples');
    D:=CADHealthcareExample(C,False); try D.Save(Root+'cad2d/examples/ubs_estudo.eacad'); finally D.Free; end;
    D:=CADHealthcareExample(C,True); try D.Save(Root+'cad2d/examples/ala_hospitalar_estudo.eacad'); finally D.Free; end;
    PLCarregarExemploSaude(P,EncodeDate(2026,11,3),False); PLSalvarProjeto(P,Root+'planejador/examples/ubs.plan.json');
    PLCarregarExemploSaude(P,EncodeDate(2026,11,3),True); PLSalvarProjeto(P,Root+'planejador/examples/ala_hospitalar.plan.json');
    WriteLn('Exemplos de UBS e ala assistencial gerados');
  finally P.Free; C.Free; end;
end.
