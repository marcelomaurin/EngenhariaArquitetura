unit ea_links_ui;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Forms, fpjson;
function EAEditFiles(Owner: TForm; Files: TJSONArray; const BaseFile: string; ReadOnly: Boolean=False): Boolean;
procedure EAOpenLink(const Link,BaseFile: string);
implementation
uses Classes, SysUtils, Controls, StdCtrls, Dialogs, Graphics, LCLIntf, ea_links;
type
 TFileForm=class(TForm)
 private
  Data: TJSONArray; List: TListBox; TitleEdit,LinkEdit: TEdit; Direction: TComboBox; CanEdit: Boolean; Base: string;
  procedure RefreshList;
  procedure Selection(Sender: TObject);
  procedure AddClick(Sender: TObject);
  procedure UpdateClick(Sender: TObject);
  procedure RemoveClick(Sender: TObject);
  procedure BrowseClick(Sender: TObject);
  procedure OpenClick(Sender: TObject);
  function ItemFromFields: TJSONObject;
 public constructor Create(AOwner: TComponent); override;
 end;
procedure EAOpenLink(const Link,BaseFile: string);
var Target,Extension: string;
begin
 Target:=EAResolveLink(Link,BaseFile);
 if (Pos('http://',LowerCase(Target))=1) or (Pos('https://',LowerCase(Target))=1) then begin
  if not OpenURL(Target) then raise Exception.Create('Não foi possível abrir o navegador'); Exit;
 end;
 if not FileExists(Target) then raise Exception.Create('Arquivo não encontrado. Uma saída prevista pode ser vinculada antes de existir: '+Target);
 Extension:=LowerCase(ExtractFileExt(Target));
 if (Extension='.exe') or (Extension='.com') or (Extension='.bat') or (Extension='.cmd') or (Extension='.ps1') or (Extension='.vbs') or (Extension='.js') or (Extension='.hta') or (Extension='.lnk') or (Extension='.url') or (Extension='.msi') or (Extension='.scr') or (Extension='.reg') then raise Exception.Create('Este vínculo é executável. Abra-o manualmente fora do gerenciador de arquivos da tarefa.');
 if not OpenDocument(Target) then raise Exception.Create('Nenhum aplicativo conseguiu abrir esse arquivo');
end;
constructor TFileForm.Create(AOwner: TComponent);
var L: TLabel; B: TButton;
 procedure LabelAt(const S: string; X,Y: Integer);
 begin L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(X,Y,420,24); L.Caption:=S; end;
 procedure ButtonAt(const S: string; X,Y,W: Integer; Action: TNotifyEvent);
 begin B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(X,Y,W,32); B.Caption:=S; B.OnClick:=Action; end;
begin
 inherited CreateNew(AOwner); Caption:='Arquivos da tarefa — entradas e saídas opcionais'; SetBounds(0,0,800,550); Position:=poScreenCenter; BorderStyle:=bsDialog; Font.Name:='Segoe UI'; Font.Size:=10; Color:=RGBToColor(244,246,250);
 List:=TListBox.Create(Self); List.Parent:=Self; List.SetBounds(18,18,754,210); List.OnClick:=@Selection;
 LabelAt('Nome / descrição',18,242); TitleEdit:=TEdit.Create(Self); TitleEdit.Parent:=Self; TitleEdit.SetBounds(18,268,490,28);
 LabelAt('Tipo de vínculo',526,242); Direction:=TComboBox.Create(Self); Direction.Parent:=Self; Direction.SetBounds(526,268,246,28); Direction.Style:=csDropDownList; Direction.Items.Add('Entrada (input)'); Direction.Items.Add('Saída (output)'); Direction.ItemIndex:=0;
 LabelAt('Caminho local, relativo ou URL HTTP/HTTPS',18,309); LinkEdit:=TEdit.Create(Self); LinkEdit.Parent:=Self; LinkEdit.SetBounds(18,335,640,28);
 ButtonAt('Procurar...',670,334,102,@BrowseClick); ButtonAt('Adicionar',18,386,116,@AddClick); ButtonAt('Atualizar',144,386,116,@UpdateClick); ButtonAt('Remover',270,386,116,@RemoveClick); ButtonAt('Abrir vínculo',396,386,126,@OpenClick);
 LabelAt('Vínculos não copiam nem enviam os arquivos. Saídas podem ainda não existir.',18,437);
 ButtonAt('Confirmar',540,475,110,nil); B.ModalResult:=mrOK; B.Default:=True;
 ButtonAt('Cancelar',662,475,110,nil); B.ModalResult:=mrCancel; B.Cancel:=True;
end;
procedure TFileForm.RefreshList;
var I: Integer; O: TJSONObject;
begin List.Clear; for I:=0 to Data.Count-1 do begin O:=Data.Objects[I]; if O.Get('direction','')='input' then List.Items.Add('ENTRADA | '+O.Get('name','')+' | '+O.Get('link','')) else List.Items.Add('SAÍDA | '+O.Get('name','')+' | '+O.Get('link','')); end; end;
procedure TFileForm.Selection(Sender: TObject);
var O: TJSONObject;
begin if List.ItemIndex<0 then Exit; O:=Data.Objects[List.ItemIndex]; TitleEdit.Text:=O.Get('name',''); LinkEdit.Text:=O.Get('link',''); if O.Get('direction','')='input' then Direction.ItemIndex:=0 else Direction.ItemIndex:=1; end;
function TFileForm.ItemFromFields: TJSONObject;
var A: TJSONArray;
begin
 Result:=TJSONObject.Create; Result.Add('name',Trim(TitleEdit.Text)); Result.Add('link',Trim(LinkEdit.Text));
 if Direction.ItemIndex=0 then Result.Add('direction','input') else Result.Add('direction','output');
 A:=TJSONArray.Create;
 try
  try A.Add(Result.Clone); EAValidateFiles(A); except Result.Free; raise; end;
 finally A.Free; end;
end;
procedure TFileForm.AddClick(Sender: TObject);
begin if not CanEdit then Exit; try Data.Add(ItemFromFields); RefreshList; except on E: Exception do ShowMessage(E.Message); end; end;
procedure TFileForm.UpdateClick(Sender: TObject);
var O: TJSONObject; I: Integer;
begin if not CanEdit or (List.ItemIndex<0) then Exit; try I:=List.ItemIndex; O:=ItemFromFields; Data.Delete(I); Data.Insert(I,O); RefreshList; List.ItemIndex:=I; except on E: Exception do ShowMessage(E.Message); end; end;
procedure TFileForm.RemoveClick(Sender: TObject);
begin if not CanEdit or (List.ItemIndex<0) then Exit; Data.Delete(List.ItemIndex); RefreshList; end;
procedure TFileForm.BrowseClick(Sender: TObject);
var D: TOpenDialog;
begin
 if not CanEdit then Exit; D:=TOpenDialog.Create(Self);
 try D.Options:=D.Options-[ofFileMustExist]; D.Title:='Selecionar entrada ou caminho de saída previsto'; if D.Execute then begin LinkEdit.Text:=D.FileName; if Trim(TitleEdit.Text)='' then TitleEdit.Text:=ExtractFileName(D.FileName); end;
 finally D.Free; end;
end;
procedure TFileForm.OpenClick(Sender: TObject);
begin try if List.ItemIndex>=0 then EAOpenLink(Data.Objects[List.ItemIndex].Get('link',''),Base); except on E: Exception do ShowMessage(E.Message); end; end;
function EAEditFiles(Owner: TForm; Files: TJSONArray; const BaseFile: string; ReadOnly: Boolean): Boolean;
var F: TFileForm; I: Integer;
begin
 Result:=False; F:=TFileForm.Create(Owner);
 try
  F.Data:=TJSONArray(Files.Clone); F.CanEdit:=not ReadOnly; F.Base:=BaseFile; F.RefreshList;
  for I:=0 to F.ComponentCount-1 do if F.Components[I] is TButton then
    if (TButton(F.Components[I]).Caption='Adicionar') or (TButton(F.Components[I]).Caption='Atualizar') or (TButton(F.Components[I]).Caption='Remover') or (TButton(F.Components[I]).Caption='Procurar...') then TButton(F.Components[I]).Enabled:=not ReadOnly;
  F.TitleEdit.ReadOnly:=ReadOnly; F.LinkEdit.ReadOnly:=ReadOnly; F.Direction.Enabled:=not ReadOnly;
  if F.ShowModal<>mrOK then Exit;
  if ReadOnly then Exit;
  EAValidateFiles(F.Data); Files.Clear; for I:=0 to F.Data.Count-1 do Files.Add(F.Data.Items[I].Clone); Result:=True;
 finally F.Data.Free; F.Free; end;
end;
end.
