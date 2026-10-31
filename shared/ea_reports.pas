unit ea_reports;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, fpjson, ea_workflow, ea_fileio;
procedure WFExportTasksCSV(Store: TWorkflow; const Token,FileName: string);
implementation
function QuoteField(const S: string): string;
var Safe: string; I: Integer;
begin
  Safe:=S; I:=1; while (I<=Length(Safe)) and (Safe[I] in [' ',#9,#13,#10]) do Inc(I);
  if (I<=Length(Safe)) and (Safe[I] in ['=','+','-','@']) then Safe:=''''+Safe;
  Result:='"'+StringReplace(Safe,'"','""',[rfReplaceAll])+'"';
end;
procedure WFExportTasksCSV(Store: TWorkflow; const Token,FileName: string);
var A: TJSONArray; T: TJSONObject; L: TStringList; I: Integer;
begin
  A:=Store.Tasks(Token); L:=TStringList.Create;
  try
    L.Add('Tarefa;Responsável;Situação;Progresso;Detalhes;Arquivo;Atualização');
    for I:=0 to A.Count-1 do begin
      T:=A.Objects[I];
      L.Add(QuoteField(T.Get('title',''))+';'+QuoteField(T.Get('assignee_name',''))+';'+QuoteField(T.Get('state',''))+';'+
        IntToStr(T.Get('progress',0))+';'+QuoteField(T.Get('details',''))+';'+QuoteField(T.Get('artifact',''))+';'+QuoteField(T.Get('updated_at','')));
    end;
    EAAtomicWriteText(FileName,#$EF#$BB#$BF+L.Text);
  finally L.Free; A.Free; end;
end;
end.
