unit ea_workflow_ui;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Grids, Spin,
  Dialogs, Graphics, fpjson, ea_workflow;
type
  TWorkflowPanel = class(TPanel)
  private
    FStore: TWorkflow;
    FToken: string;
    FIDs: TStringList;
    FGrid: TStringGrid;
    FInfo, FHistory, FReply: TMemo;
    FState: TComboBox;
    FProgress: TSpinEdit;
    FAccount, FSummary: TLabel;
    FNew,FEdit,FUsers,FRespond: TButton;
    procedure RefreshClick(Sender: TObject);
    procedure ExportClick(Sender: TObject);
    procedure Selection(Sender: TObject; ACol,ARow: Integer);
    procedure NewClick(Sender: TObject);
    procedure EditClick(Sender: TObject);
    procedure UsersClick(Sender: TObject);
    procedure ReplyClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure LoginClick(Sender: TObject);
    procedure EditTask(const ID: string);
  public
    OnOpenCAD, OnReturnTask, OnIdentityChanged: TNotifyEvent;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Setup(Store: TWorkflow; const Token: string);
    procedure Refresh;
    procedure SelectTask(const ID: string);
    function SelectedID: string;
    function ReplyText: string;
    function ReplyState: string;
    function ReplyProgress: Integer;
    property Token: string read FToken;
  end;
function WFLoginDialog(Store: TWorkflow; var Token: string): Boolean;
procedure WFLaunch(const Executable: string; const Args: array of string);
implementation
uses Process, ea_reports;
const STATES: array[0..3] of string = ('pendente','em_andamento','devolvida','concluida');
function RoleName(const Code: string): string;
var I: Integer;
begin Result:=Code; for I:=0 to 3 do if Code=WF_ROLE_CODES[I] then Exit(WF_ROLES[I]); end;
function StateName(const Code: string): string;
begin
  case Code of
    'pendente': Result:='Pendente'; 'em_andamento': Result:='Em andamento';
    'devolvida': Result:='Devolvida / em revisão'; 'concluida': Result:='Concluída';
  else Result:=Code; end;
end;
function MakeForm(const Caption: string; W,H: Integer): TForm;
begin
  Result:=TForm.CreateNew(nil); Result.Caption:=Caption; Result.SetBounds(0,0,W,H);
  Result.Position:=poScreenCenter; Result.Font.Name:='Segoe UI'; Result.Font.Size:=10;
  Result.Color:=RGBToColor(244,246,250); Result.BorderStyle:=bsDialog;
end;
function LabelAt(P: TWinControl; const Text: string; X,Y,W: Integer): TLabel;
begin
  Result:=TLabel.Create(P); Result.Parent:=P; Result.SetBounds(X,Y,W,24);
  Result.AutoSize:=False; Result.Caption:=Text;
end;
function EditAt(P: TWinControl; const Text: string; X,Y,W: Integer): TEdit;
begin Result:=TEdit.Create(P); Result.Parent:=P; Result.SetBounds(X,Y,W,28); Result.Text:=Text; end;
function ButtonAt(P: TWinControl; const Text: string; X,Y,W: Integer; Click: TNotifyEvent): TButton;
begin Result:=TButton.Create(P); Result.Parent:=P; Result.SetBounds(X,Y,W,32); Result.Caption:=Text; Result.OnClick:=Click; end;
procedure WFLaunch(const Executable: string; const Args: array of string);
var P: TProcess; S: string;
begin
  if not FileExists(Executable) then raise EWorkflow.Create('Aplicativo não encontrado: '+ExtractFileName(Executable));
  P:=TProcess.Create(nil);
  try P.Executable:=Executable; for S in Args do P.Parameters.Add(S); P.Execute; finally P.Free; end;
end;
function WFLoginDialog(Store: TWorkflow; var Token: string): Boolean;
var F: TForm; L,N,P: TEdit; B: TButton; First: Boolean; NewToken: string;
begin
  Result:=False; First:=Store.Empty; F:=MakeForm('Identificação — EngenhariaArquitetura',460,320);
  try
    if First then LabelAt(F,'Crie o primeiro Administrador',24,16,410)
    else LabelAt(F,'Entre para acessar suas tarefas',24,16,410);
    LabelAt(F,'Login',24,52,410); L:=EditAt(F,'',24,76,410);
    LabelAt(F,'Senha (mínimo de 8 caracteres para nova conta)',24,112,410);
    P:=EditAt(F,'',24,136,410); P.PasswordChar:='*';
    N:=nil;
    if First then begin LabelAt(F,'Nome do Administrador',24,174,410); N:=EditAt(F,'',24,198,410); end;
    B:=ButtonAt(F,'Entrar',220,252,100,nil); B.ModalResult:=mrOK; B.Default:=True;
    B:=ButtonAt(F,'Cancelar',330,252,104,nil); B.ModalResult:=mrCancel; B.Cancel:=True;
    while F.ShowModal=mrOK do begin
      try
        if First then NewToken:=Store.Bootstrap(L.Text,N.Text,P.Text) else NewToken:=Store.Login(L.Text,P.Text);
        Token:=NewToken; Exit(True);
      except on E: Exception do ShowMessage(E.Message); end;
    end;
  finally F.Free; end;
end;
type
  TUsersForm=class(TForm)
  public
    Store: TWorkflow; Token: string; UsersData: TJSONArray;
    List: TListBox; UserLogin,UserName,Password: TEdit; Role: TComboBox; ActiveBox: TCheckBox;
    procedure Selected(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure Reload;
    constructor Build(AStore: TWorkflow; const AToken: string);
    destructor Destroy; override;
  end;
constructor TUsersForm.Build(AStore: TWorkflow; const AToken: string);
var I: Integer; B: TButton;
begin
  inherited CreateNew(nil); Store:=AStore; Token:=AToken;
  Caption:='Usuários e tipos de acesso'; Width:=720; Height:=430; Position:=poScreenCenter;
  Font.Name:='Segoe UI'; Font.Size:=10; BorderStyle:=bsDialog;
  List:=TListBox.Create(Self); List.Parent:=Self; List.SetBounds(16,16,240,350); List.OnClick:=@Selected;
  LabelAt(Self,'Login',278,16,410); UserLogin:=EditAt(Self,'',278,42,400);
  LabelAt(Self,'Nome',278,80,400); UserName:=EditAt(Self,'',278,106,400);
  LabelAt(Self,'Nova senha (vazia mantém a senha atual)',278,144,400);
  Password:=EditAt(Self,'',278,170,400); Password.PasswordChar:='*';
  LabelAt(Self,'Tipo de acesso',278,208,400);
  Role:=TComboBox.Create(Self); Role.Parent:=Self; Role.SetBounds(278,234,400,28); Role.Style:=csDropDownList;
  for I:=0 to 3 do Role.Items.Add(WF_ROLES[I]); Role.ItemIndex:=1;
  ActiveBox:=TCheckBox.Create(Self); ActiveBox.Parent:=Self; ActiveBox.SetBounds(278,276,300,24); ActiveBox.Caption:='Usuário ativo'; ActiveBox.Checked:=True;
  ButtonAt(Self,'Salvar usuário',278,326,180,@SaveClick);
  B:=ButtonAt(Self,'Fechar',488,326,190,nil); B.ModalResult:=mrCancel;
  Reload;
end;
destructor TUsersForm.Destroy;
begin UsersData.Free; inherited Destroy; end;
procedure TUsersForm.Reload;
var I: Integer;
begin
  FreeAndNil(UsersData); UsersData:=Store.Users(Token); List.Items.Clear; List.Items.Add('+ Novo usuário');
  for I:=0 to UsersData.Count-1 do List.Items.Add(UsersData.Objects[I].Get('name','')+' ('+UsersData.Objects[I].Get('login','')+')');
  List.ItemIndex:=0; Selected(nil);
end;
procedure TUsersForm.Selected(Sender: TObject);
var U: TJSONObject; I: Integer;
begin
  Password.Clear;
  if List.ItemIndex<=0 then begin UserLogin.Clear; UserName.Clear; Role.ItemIndex:=1; ActiveBox.Checked:=True; Exit; end;
  U:=UsersData.Objects[List.ItemIndex-1]; UserLogin.Text:=U.Get('login',''); UserName.Text:=U.Get('name',''); ActiveBox.Checked:=U.Get('active',True);
  for I:=0 to 3 do if U.Get('role','')=WF_ROLE_CODES[I] then Role.ItemIndex:=I;
end;
procedure TUsersForm.SaveClick(Sender: TObject);
var ID: string;
begin
  try
    ID:=''; if List.ItemIndex>0 then ID:=UsersData.Objects[List.ItemIndex-1].Get('id','');
    Store.SaveUser(Token,ID,UserLogin.Text,UserName.Text,Password.Text,WF_ROLE_CODES[Role.ItemIndex],ActiveBox.Checked);
    Reload; ShowMessage('Usuário salvo');
  except on E: Exception do ShowMessage(E.Message); end;
end;
constructor TWorkflowPanel.Create(AOwner: TComponent);
var TopBar,Right: TPanel; B: TButton; I: Integer;
begin
  inherited Create(AOwner); BevelOuter:=bvNone; Color:=RGBToColor(244,246,250); FIDs:=TStringList.Create;
  TopBar:=TPanel.Create(Self); TopBar.Parent:=Self; TopBar.Align:=alTop; TopBar.Height:=108; TopBar.BevelOuter:=bvNone;
  TopBar.Color:=RGBToColor(30,64,145);
  FAccount:=LabelAt(TopBar,'Gestão de tarefas',16,8,950); FAccount.Font.Color:=clWhite;
  FNew:=ButtonAt(TopBar,'Nova tarefa',16,40,108,@NewClick); FEdit:=ButtonAt(TopBar,'Editar / atribuir',132,40,125,@EditClick);
  ButtonAt(TopBar,'Abrir no CAD 2D',265,40,130,@OpenClick);
  FUsers:=ButtonAt(TopBar,'Usuários',403,40,100,@UsersClick); ButtonAt(TopBar,'Atualizar',511,40,100,@RefreshClick);
  ButtonAt(TopBar,'Trocar usuário',619,40,125,@LoginClick);
  ButtonAt(TopBar,'Exportar CSV',752,40,116,@ExportClick);
  FSummary:=LabelAt(TopBar,'',16,80,950); FSummary.Font.Color:=clWhite;
  Right:=TPanel.Create(Self); Right.Parent:=Self; Right.Align:=alRight; Right.Width:=360; Right.BevelOuter:=bvNone;
  FInfo:=TMemo.Create(Self); FInfo.Parent:=Right; FInfo.Align:=alTop; FInfo.Height:=140; FInfo.ReadOnly:=True; FInfo.ScrollBars:=ssAutoVertical;
  FHistory:=TMemo.Create(Self); FHistory.Parent:=Right; FHistory.Align:=alClient; FHistory.ReadOnly:=True; FHistory.ScrollBars:=ssAutoVertical;
  FReply:=TMemo.Create(Self); FReply.Parent:=Right; FReply.Align:=alBottom; FReply.Height:=80; FReply.TextHint:='O que foi feito? O que falta?';
  B:=ButtonAt(Right,'Registrar resposta',0,0,150,@ReplyClick); B.Align:=alBottom; FRespond:=B;
  FProgress:=TSpinEdit.Create(Self); FProgress.Parent:=Right; FProgress.Align:=alBottom; FProgress.MinValue:=0; FProgress.MaxValue:=100; FProgress.Hint:='Progresso (%)'; FProgress.ShowHint:=True;
  FState:=TComboBox.Create(Self); FState.Parent:=Right; FState.Align:=alBottom; FState.Style:=csDropDownList;
  FState.Items.Add('Pendente'); FState.Items.Add('Em andamento'); FState.Items.Add('Devolvida / em revisão'); FState.Items.Add('Concluída'); FState.ItemIndex:=0;
  FGrid:=TStringGrid.Create(Self); FGrid.Parent:=Self; FGrid.Align:=alClient;
  FGrid.ColCount:=4; FGrid.FixedCols:=0; FGrid.RowCount:=2; FGrid.FixedRows:=1;
  FGrid.Options:=[goRowSelect,goColSizing,goVertLine,goHorzLine]; FGrid.OnSelection:=@Selection;
  FGrid.Cells[0,0]:='Tarefa'; FGrid.Cells[1,0]:='Responsável'; FGrid.Cells[2,0]:='Situação'; FGrid.Cells[3,0]:='%';
  FGrid.ColWidths[0]:=300; FGrid.ColWidths[1]:=180; FGrid.ColWidths[2]:=150; FGrid.ColWidths[3]:=50;
end;
destructor TWorkflowPanel.Destroy;
begin FIDs.Free; inherited Destroy; end;
procedure TWorkflowPanel.Setup(Store: TWorkflow; const Token: string);
begin FStore:=Store; FToken:=Token; Refresh; end;
procedure TWorkflowPanel.Refresh;
var A: TJSONArray; U,T: TJSONObject; I,Done,Pending,Returned: Integer; Prev: string;
begin
  if FStore=nil then Exit;
  Prev:=SelectedID; U:=FStore.User(FToken);
  try
    FAccount.Caption:='Gestão — '+U.Get('name','')+' | '+RoleName(U.Get('role',''));
    FNew.Enabled:=WFManager(U); FEdit.Enabled:=FNew.Enabled; FUsers.Enabled:=U.Get('role','')='admin';
    FRespond.Enabled:=U.Get('role','')<>'viewer'; FReply.ReadOnly:=not FRespond.Enabled;
  finally U.Free; end;
  A:=FStore.Tasks(FToken);
  try
    FIDs.Clear; FGrid.RowCount:=A.Count+1; if FGrid.RowCount<2 then FGrid.RowCount:=2;
    FGrid.Rows[1].Clear; Done:=0; Pending:=0; Returned:=0;
    for I:=0 to A.Count-1 do begin
      T:=A.Objects[I]; FIDs.Add(T.Get('id','')); FGrid.Cells[0,I+1]:=T.Get('title','');
      FGrid.Cells[1,I+1]:=T.Get('assignee_name',''); FGrid.Cells[2,I+1]:=StateName(T.Get('state','')); FGrid.Cells[3,I+1]:=IntToStr(T.Get('progress',0));
      if T.Get('state','')='concluida' then Inc(Done) else Inc(Pending);
      if T.Get('state','')='devolvida' then Inc(Returned);
    end;
    FSummary.Caption:=Format('%d tarefas | %d concluídas | %d pendentes | %d devolvidas para revisão',[A.Count,Done,Pending,Returned]);
  finally A.Free; end;
  SelectTask(Prev);
end;
function TWorkflowPanel.SelectedID: string;
begin Result:=''; if (FGrid.Row>0) and (FGrid.Row<=FIDs.Count) then Result:=FIDs[FGrid.Row-1]; end;
procedure TWorkflowPanel.SelectTask(const ID: string);
var I: Integer;
begin I:=FIDs.IndexOf(ID); if I<0 then I:=0; FGrid.Row:=I+1; Selection(nil,0,FGrid.Row); end;
procedure TWorkflowPanel.Selection(Sender: TObject; ACol,ARow: Integer);
var T,E: TJSONObject; I: Integer; ID: string;
begin
  FInfo.Clear; FHistory.Clear; FReply.Clear;
  if (ARow<1) or (ARow>FIDs.Count) then Exit; ID:=FIDs[ARow-1];
  try
    T:=FStore.Task(FToken,ID);
    try
      FInfo.Lines.Add(T.Get('title','')); FInfo.Lines.Add('Responsável: '+T.Get('assignee_name',''));
      FInfo.Lines.Add('Arquivo: '+T.Get('artifact','')); FInfo.Lines.Add('Origem: '+T.Get('source','')); FInfo.Lines.Add(''); FInfo.Lines.Add(T.Get('details',''));
      FProgress.Value:=T.Get('progress',0); FState.ItemIndex:=0;
      for I:=0 to 3 do if T.Get('state','')=STATES[I] then FState.ItemIndex:=I;
      for I:=0 to T.Arrays['history'].Count-1 do begin E:=T.Arrays['history'].Objects[I]; FHistory.Lines.Add(E.Get('at','')+' — '+E.Get('user_name','')+' ['+StateName(E.Get('state',''))+']'); FHistory.Lines.Add(E.Get('text','')); FHistory.Lines.Add(''); end;
    finally T.Free; end;
  except on E: Exception do FInfo.Text:=E.Message; end;
end;
procedure TWorkflowPanel.EditTask(const ID: string);
var F: TForm; TaskName,FileName: TEdit; Details: TMemo; Assignee: TComboBox; A: TJSONArray; IDs: TStringList; T: TJSONObject; I: Integer; B: TButton;
begin
  F:=MakeForm('Tarefa — arquivo e responsabilidade',640,480); A:=nil; IDs:=TStringList.Create; T:=nil;
  try
    A:=FStore.Users(FToken); if ID<>'' then T:=FStore.Task(FToken,ID);
    LabelAt(F,'Nome da tarefa',20,16,600); TaskName:=EditAt(F,'',20,42,600);
    LabelAt(F,'Responsável',20,80,600); Assignee:=TComboBox.Create(F); Assignee.Parent:=F; Assignee.SetBounds(20,106,600,28); Assignee.Style:=csDropDownList;
    for I:=0 to A.Count-1 do if A.Objects[I].Get('active',False) and (A.Objects[I].Get('role','')<>'viewer') then begin Assignee.Items.Add(A.Objects[I].Get('name','')+' ('+A.Objects[I].Get('login','')+')'); IDs.Add(A.Objects[I].Get('id','')); end;
    if IDs.Count>0 then Assignee.ItemIndex:=0;
    LabelAt(F,'Arquivo CAD associado (pode ser associado ao devolver)',20,144,600); FileName:=EditAt(F,'',20,170,600);
    LabelAt(F,'Detalhes, entregas e pendências',20,208,600); Details:=TMemo.Create(F); Details.Parent:=F; Details.SetBounds(20,234,600,150); Details.ScrollBars:=ssAutoVertical;
    if T<>nil then begin TaskName.Text:=T.Get('title',''); FileName.Text:=T.Get('artifact',''); Details.Text:=T.Get('details',''); Assignee.ItemIndex:=IDs.IndexOf(T.Get('assignee','')); end;
    B:=ButtonAt(F,'Salvar tarefa',360,408,125,nil); B.ModalResult:=mrOK;
    B:=ButtonAt(F,'Cancelar',495,408,125,nil); B.ModalResult:=mrCancel;
    while F.ShowModal=mrOK do begin
      try
        if Assignee.ItemIndex<0 then raise EWorkflow.Create('Selecione um responsável');
        if T=nil then FStore.SaveTask(FToken,ID,TaskName.Text,Details.Text,IDs[Assignee.ItemIndex],FileName.Text,'','')
        else FStore.SaveTask(FToken,ID,TaskName.Text,Details.Text,IDs[Assignee.ItemIndex],FileName.Text,T.Get('source',''),T.Get('source_id',''));
        Break;
      except on E: Exception do ShowMessage(E.Message); end;
    end;
  finally T.Free; A.Free; IDs.Free; F.Free; end;
  Refresh;
end;
procedure TWorkflowPanel.NewClick(Sender: TObject);
begin try EditTask(''); except on E: Exception do ShowMessage(E.Message); end; end;
procedure TWorkflowPanel.EditClick(Sender: TObject);
begin if SelectedID<>'' then try EditTask(SelectedID); except on E: Exception do ShowMessage(E.Message); end; end;
procedure TWorkflowPanel.RefreshClick(Sender: TObject);
begin try Refresh; except on E: Exception do ShowMessage(E.Message); end; end;
procedure TWorkflowPanel.UsersClick(Sender: TObject);
var F: TUsersForm;
begin try F:=TUsersForm.Build(FStore,FToken); try F.ShowModal; finally F.Free; end; Refresh; except on E: Exception do ShowMessage(E.Message); end; end;
procedure TWorkflowPanel.ReplyClick(Sender: TObject);
begin
  try FStore.Reply(FToken,SelectedID,FReply.Text,ReplyState,FProgress.Value,'',False); Refresh;
  except on E: Exception do ShowMessage(E.Message); end;
end;
procedure TWorkflowPanel.OpenClick(Sender: TObject);
begin if (SelectedID<>'') and Assigned(OnOpenCAD) then OnOpenCAD(Self); end;
procedure TWorkflowPanel.LoginClick(Sender: TObject);
var NewToken: string;
begin
  NewToken:='';
  if WFLoginDialog(FStore,NewToken) then begin
    FStore.Logout(FToken); FToken:=NewToken;
    if Assigned(OnIdentityChanged) then OnIdentityChanged(Self);
    Refresh;
  end;
end;
function TWorkflowPanel.ReplyText: string;
begin Result:=FReply.Text; end;
function TWorkflowPanel.ReplyState: string;
begin Result:=STATES[FState.ItemIndex]; end;
function TWorkflowPanel.ReplyProgress: Integer;
begin Result:=FProgress.Value; end;

procedure TWorkflowPanel.ExportClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Relatório de tarefas (*.csv)|*.csv'; D.DefaultExt := 'csv';
    D.FileName := 'tarefas.csv'; D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    try WFExportTasksCSV(FStore,FToken,D.FileName); ShowMessage('Relatório exportado com as tarefas permitidas ao seu perfil.');
    except on E: Exception do ShowMessage(E.Message); end;
  finally D.Free; end;
end;
end.
