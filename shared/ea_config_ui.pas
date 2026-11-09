unit ea_config_ui;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Forms;
procedure EAShowSetup(Owner: TForm);
implementation
uses Classes, SysUtils, Controls, StdCtrls, Dialogs, Graphics, fpjson, ea_config;
procedure EAShowSetup(Owner: TForm);
var F: TForm; Project,URL,Login: TEdit; L: TLabel; B: TButton; Original,Changes: TJSONObject;
  function Field(const Caption,Value: string; Y: Integer): TEdit;
  var LabelControl: TLabel;
  begin
    LabelControl:=TLabel.Create(F); LabelControl.Parent:=F; LabelControl.SetBounds(20,Y,660,22); LabelControl.Caption:=Caption;
    Result:=TEdit.Create(F); Result.Parent:=F; Result.SetBounds(20,Y+25,660,28); Result.Text:=Value;
  end;
begin
  try Original:=EAReadConfig; except on E: Exception do begin ShowMessage('Não foi possível ler o Setup: '+E.Message); Exit; end; end;
  F:=TForm.CreateNew(Owner);
  try
    F.Caption:='Setup — configurações compartilhadas'; F.SetBounds(0,0,710,400);
    F.Position:=poScreenCenter; F.BorderStyle:=bsDialog; F.Font.Name:='Segoe UI'; F.Font.Size:=10;
    F.Color:=RGBToColor(244,246,250);
    Project:=Field('Último projeto aberto',Original.Get('last_project',''),18); Project.ReadOnly:=True;
    URL:=Field('URL do servidor de nuvem',Original.Get('cloud_server_url',''),88);
    URL.TextHint:='https://servidor.exemplo';
    Login:=Field('Último login digitado (preenchimento da identificação)',Original.Get('last_login',''),158);
    L:=TLabel.Create(F); L.Parent:=F; L.SetBounds(20,232,660,46); L.AutoSize:=False; L.WordWrap:=True;
    L.Caption:='A URL fica disponível aos aplicativos. A sincronização em nuvem ainda não está implementada. A senha não é salva no Setup.';
    L:=TLabel.Create(F); L.Parent:=F; L.SetBounds(20,282,660,38); L.AutoSize:=False; L.WordWrap:=True;
    L.Caption:='Arquivo comum: '+EAConfigFile;
    B:=TButton.Create(F); B.Parent:=F; B.SetBounds(458,334,106,32); B.Caption:='Salvar'; B.ModalResult:=mrOK; B.Default:=True;
    B:=TButton.Create(F); B.Parent:=F; B.SetBounds(574,334,106,32); B.Caption:='Cancelar'; B.ModalResult:=mrCancel; B.Cancel:=True;
    while F.ShowModal=mrOK do begin
      Changes:=TJSONObject.Create;
      try
        if Trim(URL.Text)<>Original.Get('cloud_server_url','') then Changes.Add('cloud_server_url',Trim(URL.Text));
        if Trim(Login.Text)<>Original.Get('last_login','') then Changes.Add('last_login',Trim(Login.Text));
        try EAUpdateConfig(Changes); Break; except on E: Exception do ShowMessage(E.Message); end;
      finally Changes.Free; end;
    end;
  finally F.Free; Original.Free; end;
end;
end.
