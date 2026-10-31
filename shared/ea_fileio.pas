unit ea_fileio;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils;
procedure EAAtomicWriteText(const FileName, Content: string);
implementation
{$IFDEF WINDOWS}uses Windows;{$ENDIF}
procedure EAAtomicWriteText(const FileName, Content: string);
var Destination, TempName: string; G: TGUID; Stream: TFileStream;
begin
  Destination:=ExpandFileName(FileName);
  if not DirectoryExists(ExtractFilePath(Destination)) then raise EFCreateError.Create('A pasta de destino não existe');
  CreateGUID(G); TempName:=Destination+'.'+GUIDToString(G)+'.tmp';
  try
    Stream:=TFileStream.Create(TempName,fmCreate or fmShareExclusive);
    try
      if Content<>'' then Stream.WriteBuffer(Content[1],Length(Content));
      {$IFDEF WINDOWS}
      if not Windows.FlushFileBuffers(Stream.Handle) then raise EWriteError.Create('Falha ao confirmar a gravação no disco');
      {$ENDIF}
    finally Stream.Free; end;
    {$IFDEF WINDOWS}
    if not Windows.MoveFileExW(PWideChar(UTF8Decode(TempName)),PWideChar(UTF8Decode(Destination)),MOVEFILE_REPLACE_EXISTING or $00000008) then
      raise EWriteError.Create('Não foi possível substituir o arquivo. O original foi preservado.');
    {$ELSE}
    if not RenameFile(TempName,Destination) then raise EWriteError.Create('Não foi possível substituir o arquivo. O original foi preservado.');
    {$ENDIF}
  finally if FileExists(TempName) then SysUtils.DeleteFile(TempName); end;
end;
end.
