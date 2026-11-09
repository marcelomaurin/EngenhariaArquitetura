unit plan_recursos_ui;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, Grids, fpjson,
 plan_documento, plan_tipos, plan_recursos, plan_cronograma, airesourceview;
type
 TPLRecursosPanel=class(TPanel)
 private
  FDoc: TPLProjeto; FCrono: TPLCronograma; FUsers: TJSONArray;
  FGrid: TStringGrid; FView: TAIResourceView;
  procedure AddClick(Sender: TObject); procedure EditClick(Sender: TObject);
  procedure DeleteClick(Sender: TObject); procedure ImportUsers(Sender: TObject);
  procedure BarClick(Sender: TObject; Index: Integer);
 public
  OnChanged,OnSelectTask: TNotifyEvent;
  SelectedTask: Integer;
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  procedure Setup(Doc: TPLProjeto; Crono: TPLCronograma; Users: TJSONArray);
 end;
function PLEditResource(Owner: TForm; Doc: TPLProjeto; R: TPLRecurso; Users: TJSONArray): Boolean;
function PLEditTaskResources(Owner: TForm; Doc: TPLProjeto; T: TPLTarefa; Users: TJSONArray; const BaseFile: string): Boolean;
function PLEditTaskCosts(Owner: TForm; Doc: TPLProjeto; T: TPLTarefa): Boolean;
implementation
uses Math, DateUtils, Dialogs, ComCtrls, EditBtn, Spin, CheckLst, Graphics,
 aiworkcalendar, airesourceload, ea_money, ea_links_ui;
function LabelAt(P: TWinControl; const S: string; X,Y,W: Integer): TLabel;
begin Result:=TLabel.Create(P); Result.Parent:=P; Result.SetBounds(X,Y,W,23); Result.Caption:=S; end;
function EditAt(P: TWinControl; const S: string; X,Y,W: Integer): TEdit;
begin Result:=TEdit.Create(P); Result.Parent:=P; Result.SetBounds(X,Y,W,28); Result.Text:=S; end;
function ButtonAt(P: TWinControl; const S: string; X,Y,W: Integer; Action: TNotifyEvent): TButton;
begin Result:=TButton.Create(P); Result.Parent:=P; Result.SetBounds(X,Y,W,32); Result.Caption:=S; Result.OnClick:=Action; end;
function FormFor(Owner: TForm; const S: string; W,H: Integer): TForm;
begin Result:=TForm.CreateNew(Owner); Result.Caption:=S; Result.SetBounds(0,0,W,H); Result.Position:=poScreenCenter; Result.BorderStyle:=bsDialog; Result.Font.Name:='Segoe UI'; Result.Font.Size:=10; Result.Color:=RGBToColor(244,246,250); end;
function ParseMinute(const Text: string): Integer;
var H,M: Integer; S: string;
begin S:=Trim(Text); if (Length(S)<>5) or (S[3]<>':') or not TryStrToInt(Copy(S,1,2),H) or not TryStrToInt(Copy(S,4,2),M) or (H<0) or (H>24) or (M<0) or (M>59) or ((H=24) and (M<>0)) then raise Exception.Create('Horário inválido: use HH:MM'); Result:=H*60+M; end;
function MinuteText(M: Integer): string;
begin Result:=Format('%.2d:%.2d',[M div 60,M mod 60]); end;
function PLEditResource(Owner: TForm; Doc: TPLProjeto; R: TPLRecurso; Users: TJSONArray): Boolean;
var F: TForm; Pages: TPageControl; General,Availability: TTabSheet; Name,Link,Price: TEdit; Notes,Absences: TMemo;
 Kind,User: TComboBox; Capacity: TFloatSpinEdit; ProjectCalendar: TCheckBox; Days: TCheckListBox; FromDate,UntilDate: TDateEdit;
 StartTime,BreakStart,BreakEnd,EndTime: TEdit; B: TButton; Draft,Backup: TPLRecurso; I,J,K,P,A,C,D,E: Integer;
 Intervals: TAIWorkIntervals; Line: string;
begin
 Result:=False; F:=FormFor(Owner,'Cadastro de recurso',740,620); Draft:=TPLRecurso.Create; Backup:=TPLRecurso.Create;
 try
  Draft.Assign(R); Backup.Assign(R); Pages:=TPageControl.Create(F); Pages.Parent:=F; Pages.SetBounds(12,12,704,540);
  General:=TTabSheet.Create(Pages); General.PageControl:=Pages; General.Caption:='Cadastro e preço';
  Availability:=TTabSheet.Create(Pages); Availability.PageControl:=Pages; Availability.Caption:='Disponibilidade e ausências';
  LabelAt(General,'Nome do recurso',16,18,640); Name:=EditAt(General,R.Nome,16,44,640);
  LabelAt(General,'Tipo',16,86,260); Kind:=TComboBox.Create(F); Kind.Parent:=General; Kind.SetBounds(16,112,270,28); Kind.Style:=csDropDownList;
  for I:=0 to Ord(High(TPLRecursoTipo)) do Kind.Items.Add(PL_RECURSO_TIPOS[TPLRecursoTipo(I)]); Kind.ItemIndex:=Ord(R.Tipo);
  LabelAt(General,'Capacidade (%) — trabalho/equipe/equipamento',306,86,350); Capacity:=TFloatSpinEdit.Create(F); Capacity.Parent:=General; Capacity.SetBounds(306,112,350,28); Capacity.MinValue:=0.01; Capacity.MaxValue:=1000000; Capacity.DecimalPlaces:=2; Capacity.Value:=R.Capacidade*100;
  LabelAt(General,'Usuário vinculado (opcional, somente para pessoa)',16,154,640); User:=TComboBox.Create(F); User.Parent:=General; User.SetBounds(16,180,640,28); User.Style:=csDropDownList; User.Items.Add('Sem vínculo de login'); User.ItemIndex:=0;
  if Users<>nil then for I:=0 to Users.Count-1 do begin User.Items.Add(Users.Objects[I].Get('name','')+' ('+Users.Objects[I].Get('login','')+')'); if Users.Objects[I].Get('id','')=R.UsuarioID then User.ItemIndex:=I+1; end;
  LabelAt(General,'Preço por unidade (material) ou por hora (trabalho)',16,222,640); Price:=EditAt(General,EAMoneyText(R.PrecoCentavos),16,248,260);
  LabelAt(General,'Arquivo / URL (apenas para recurso de arquivo)',16,290,640); Link:=EditAt(General,R.Link,16,316,640);
  LabelAt(General,'Notas',16,358,640); Notes:=TMemo.Create(F); Notes.Parent:=General; Notes.SetBounds(16,384,640,90); Notes.Text:=R.Notas;
  ProjectCalendar:=TCheckBox.Create(F); ProjectCalendar.Parent:=Availability; ProjectCalendar.SetBounds(16,16,640,28); ProjectCalendar.Caption:='Usar calendário do projeto'; ProjectCalendar.Checked:=R.CalendarioProjeto;
  LabelAt(Availability,'Se desmarcado, usar os dias e horários abaixo:',16,52,640);
  Days:=TCheckListBox.Create(F); Days.Parent:=Availability; Days.SetBounds(16,80,176,166);
  Days.Items.Add('Domingo'); Days.Items.Add('Segunda'); Days.Items.Add('Terça'); Days.Items.Add('Quarta'); Days.Items.Add('Quinta'); Days.Items.Add('Sexta'); Days.Items.Add('Sábado');
  for I:=1 to 7 do Days.Checked[I-1]:=Length(R.Calendario.WeekDay(I))>0;
  Intervals:=R.Calendario.WeekDay(2); A:=480; C:=720; D:=780; E:=1020;
  if Length(Intervals)>0 then begin A:=Intervals[0].StartMin; E:=Intervals[High(Intervals)].EndMin; if Length(Intervals)>1 then begin C:=Intervals[0].EndMin; D:=Intervals[1].StartMin; end else begin C:=E; D:=E; end; end;
  LabelAt(Availability,'Início / pausa / retorno / fim (HH:MM)',216,80,440);
  StartTime:=EditAt(Availability,MinuteText(A),216,110,90); BreakStart:=EditAt(Availability,MinuteText(C),320,110,90); BreakEnd:=EditAt(Availability,MinuteText(D),424,110,90); EndTime:=EditAt(Availability,MinuteText(E),528,110,90);
  LabelAt(Availability,'Disponível de (vazio = sem limite)',216,162,440); FromDate:=TDateEdit.Create(F); FromDate.Parent:=Availability; FromDate.SetBounds(216,190,180,28); FromDate.DateOrder:=doDMY; if R.DisponivelDe>0 then FromDate.Date:=R.DisponivelDe;
  LabelAt(Availability,'Disponível até (inclusive)',426,162,240); UntilDate:=TDateEdit.Create(F); UntilDate.Parent:=Availability; UntilDate.SetBounds(426,190,180,28); UntilDate.DateOrder:=doDMY; if R.DisponivelAte>0 then UntilDate.Date:=R.DisponivelAte;
  LabelAt(Availability,'Férias / afastamentos: uma data ou intervalo ISO por linha',16,270,640);
  LabelAt(Availability,'Ex.: 2026-11-10..2026-11-15 (datas inclusivas)',16,296,640);
  Absences:=TMemo.Create(F); Absences.Parent:=Availability; Absences.SetBounds(16,326,640,150); Absences.ScrollBars:=ssAutoVertical;
  for I:=0 to High(R.Ausencias) do Absences.Lines.Add(PLDataISO(R.Ausencias[I].De)+'..'+PLDataISO(R.Ausencias[I].Ate));
  B:=ButtonAt(F,'Salvar recurso',438,568,134,nil); B.ModalResult:=mrOK; B.Default:=True; B:=ButtonAt(F,'Cancelar',582,568,134,nil); B.ModalResult:=mrCancel; B.Cancel:=True;
  while F.ShowModal=mrOK do begin
   try
    Draft.Nome:=Trim(Name.Text); Draft.Tipo:=TPLRecursoTipo(Kind.ItemIndex); Draft.Capacidade:=Capacity.Value/100; Draft.Link:=Trim(Link.Text); Draft.Notas:=Notes.Text; Draft.PrecoCentavos:=EAMoneyParse(Price.Text);
    Draft.UsuarioID:=''; if (Draft.Tipo=prtPessoa) and (User.ItemIndex>0) then Draft.UsuarioID:=Users.Objects[User.ItemIndex-1].Get('id','');
    if (Draft.Tipo=prtPessoa) and (User.ItemIndex=0) and (R.UsuarioID<>'') then begin
      for I:=0 to Doc.Count-1 do if Doc[I].ExecutorID=R.UsuarioID then raise Exception.Create('Recurso é executor; mantenha o usuário vinculado ou altere primeiro as tarefas');
    end;
    Draft.CalendarioProjeto:=ProjectCalendar.Checked;
    if not Draft.CalendarioProjeto then begin
      A:=ParseMinute(StartTime.Text); C:=ParseMinute(BreakStart.Text); D:=ParseMinute(BreakEnd.Text); E:=ParseMinute(EndTime.Text);
      if (A>=E) or (C<A) or (D<C) or (E<D) then raise Exception.Create('Jornada inválida');
      Draft.Calendario.Clear;
      for I:=1 to 7 do if Days.Checked[I-1] then begin
       if C=D then Draft.Calendario.SetWeekDay(I,[A,E])
       else if (A<C) and (D<E) then Draft.Calendario.SetWeekDay(I,[A,C,D,E]) else Draft.Calendario.SetWeekDay(I,[A,E]);
      end;
    end;
    Draft.DisponivelDe:=0; Draft.DisponivelAte:=0;
    if Trim(FromDate.Text)<>'' then Draft.DisponivelDe:=FromDate.Date;
    if Trim(UntilDate.Text)<>'' then Draft.DisponivelAte:=UntilDate.Date;
    SetLength(Draft.Ausencias,0);
    for I:=0 to Absences.Lines.Count-1 do begin
      Line:=Trim(Absences.Lines[I]); if Line='' then Continue; P:=Pos('..',Line); J:=Length(Draft.Ausencias); SetLength(Draft.Ausencias,J+1);
      if P=0 then begin Draft.Ausencias[J].De:=PLDataLer(Line); Draft.Ausencias[J].Ate:=Draft.Ausencias[J].De; end
      else begin Draft.Ausencias[J].De:=PLDataLer(Copy(Line,1,P-1)); Draft.Ausencias[J].Ate:=PLDataLer(Copy(Line,P+2,Length(Line))); end;
    end;
    Draft.Validar;
    for I:=0 to Doc.Recursos.Count-1 do if (Doc.Recursos[I]<>R) and (Draft.UsuarioID<>'') and (Doc.Recursos[I].UsuarioID=Draft.UsuarioID) then raise Exception.Create('Usuário já vinculado a outro recurso');
    for I:=0 to High(Doc.Apontamentos) do if SameText(Doc.Apontamentos[I].RecursoID,R.ID) and (Draft.UsuarioID<>R.UsuarioID) then raise Exception.Create('Pessoa possui horas apontadas; mantenha o usuário vinculado ou cadastre outro recurso');
    R.Assign(Draft);
    try Doc.ValidarRecursos; except R.Assign(Backup); raise; end;
    Result:=True; Break;
   except on Ex: Exception do ShowMessage(Ex.Message); end;
  end;
 finally Draft.Free; Backup.Free; F.Free; end;
end;

type
 TAssignmentForm=class(TForm)
 private
  Doc: TPLProjeto; Task: TPLTarefa; Users: TJSONArray; Base: string;
  Data: TPLAlocacoes; Files: TJSONArray;
  List: TListBox; Resource: TComboBox; Units: TFloatSpinEdit; Price: TEdit; Accounted: TCheckBox;
  procedure RefreshList; procedure LoadResources;
  procedure Selection(Sender: TObject); procedure ResourceChanged(Sender: TObject);
  procedure AddClick(Sender: TObject); procedure UpdateClick(Sender: TObject); procedure RemoveClick(Sender: TObject);
  procedure FilesClick(Sender: TObject); procedure NewResource(Sender: TObject);
  function Fields: TPLAlocacao;
 public constructor Create(AOwner: TComponent); override;
 end;
constructor TAssignmentForm.Create(AOwner: TComponent);
var B: TButton;
begin
 inherited CreateNew(AOwner); Caption:='Recursos, consumíveis e arquivos da tarefa'; SetBounds(0,0,800,550); Position:=poScreenCenter; BorderStyle:=bsDialog; Font.Name:='Segoe UI'; Font.Size:=10;
 List:=TListBox.Create(Self); List.Parent:=Self; List.SetBounds(16,16,750,210); List.OnClick:=@Selection;
 LabelAt(Self,'Recurso de trabalho ou consumível',16,240,750); Resource:=TComboBox.Create(Self); Resource.Parent:=Self; Resource.SetBounds(16,266,750,28); Resource.Style:=csDropDownList; Resource.OnChange:=@ResourceChanged;
 LabelAt(Self,'Dedicação (%) ou quantidade de consumível',16,306,400); Units:=TFloatSpinEdit.Create(Self); Units.Parent:=Self; Units.SetBounds(16,332,240,28); Units.MinValue:=0.001; Units.MaxValue:=1000000000; Units.DecimalPlaces:=3; Units.Value:=100;
 LabelAt(Self,'Preço unitário / hora (R$)',280,306,300); Price:=EditAt(Self,'0,00',280,332,230);
 Accounted:=TCheckBox.Create(Self); Accounted.Parent:=Self; Accounted.SetBounds(530,332,236,28); Accounted.Caption:='Contabilizar custo'; Accounted.Checked:=True;
 ButtonAt(Self,'Adicionar',16,380,112,@AddClick); ButtonAt(Self,'Atualizar',138,380,112,@UpdateClick); ButtonAt(Self,'Remover',260,380,112,@RemoveClick); ButtonAt(Self,'Novo recurso...',382,380,144,@NewResource); ButtonAt(Self,'Arquivos de entrada/saída...',536,380,230,@FilesClick);
 LabelAt(Self,'Consumíveis são sempre entradas. Arquivos são opcionais e não geram custo por vínculo.',16,430,750);
 B:=ButtonAt(Self,'Confirmar',530,475,112,nil); B.ModalResult:=mrOK; B.Default:=True; B:=ButtonAt(Self,'Cancelar',654,475,112,nil); B.ModalResult:=mrCancel; B.Cancel:=True;
end;
procedure TAssignmentForm.LoadResources;
var I: Integer;
begin Resource.Clear; for I:=0 to Doc.Recursos.Count-1 do Resource.Items.Add(PL_RECURSO_TIPOS[Doc.Recursos[I].Tipo]+' | '+Doc.Recursos[I].Nome); end;
procedure TAssignmentForm.RefreshList;
var I,K: Integer; S: string;
begin List.Clear; for I:=0 to High(Data) do begin K:=Doc.RecursoIndice(Data[I].RecursoID); S:=Doc.Recursos[K].Nome;
 if Doc.Recursos[K].Tipo=prtMaterial then S:='ENTRADA consumível | '+S+' | qtd. '+FloatToStr(Data[I].Unidades) else S:=S+' | '+FloatToStr(Data[I].Unidades*100)+'%';
 S:=S+' | '+EAMoneyText(Data[I].CustoUnitarioCentavos); if Data[I].Contabilizado then S:=S+' | contabilizado' else S:=S+' | pendente'; List.Items.Add(S); end; end;
procedure TAssignmentForm.ResourceChanged(Sender: TObject);
var R: TPLRecurso;
begin if Resource.ItemIndex<0 then Exit; R:=Doc.Recursos[Resource.ItemIndex]; Price.Text:=EAMoneyText(R.PrecoCentavos); if R.Tipo=prtMaterial then Units.Value:=1 else Units.Value:=100; end;
procedure TAssignmentForm.Selection(Sender: TObject);
var I,K: Integer;
begin I:=List.ItemIndex; if I<0 then Exit; K:=Doc.RecursoIndice(Data[I].RecursoID); Resource.ItemIndex:=K;
 if Doc.Recursos[K].Tipo=prtMaterial then Units.Value:=Data[I].Unidades else Units.Value:=Data[I].Unidades*100;
 Price.Text:=EAMoneyText(Data[I].CustoUnitarioCentavos); Accounted.Checked:=Data[I].Contabilizado; end;
function TAssignmentForm.Fields: TPLAlocacao;
var R: TPLRecurso;
begin
 if Resource.ItemIndex<0 then raise Exception.Create('Escolha um recurso'); R:=Doc.Recursos[Resource.ItemIndex];
 if R.Tipo=prtArquivo then raise Exception.Create('Use o botão Arquivos de entrada/saída para vincular arquivos');
 Result.RecursoID:=R.ID; Result.Unidades:=Units.Value; Result.Direcao:=prdUso;
 if R.Tipo=prtMaterial then Result.Direcao:=prdEntrada else Result.Unidades:=Result.Unidades/100;
 Result.CustoUnitarioCentavos:=EAMoneyParse(Price.Text); Result.Contabilizado:=Accounted.Checked;
end;
procedure TAssignmentForm.AddClick(Sender: TObject);
var NewData: TPLAlocacoes; N: Integer;
begin try NewData:=Copy(Data); N:=Length(NewData); SetLength(NewData,N+1); NewData[N]:=Fields; Doc.ValidarAlocacoes(NewData); Data:=NewData; RefreshList; except on E: Exception do ShowMessage(E.Message); end; end;
procedure TAssignmentForm.UpdateClick(Sender: TObject);
var NewData: TPLAlocacoes;
begin if List.ItemIndex<0 then Exit; try NewData:=Copy(Data); NewData[List.ItemIndex]:=Fields; Doc.ValidarAlocacoes(NewData); Data:=NewData; RefreshList; except on E: Exception do ShowMessage(E.Message); end; end;
procedure TAssignmentForm.RemoveClick(Sender: TObject);
var I,J: Integer;
begin I:=List.ItemIndex; if I<0 then Exit; for J:=I to High(Data)-1 do Data[J]:=Data[J+1]; SetLength(Data,Length(Data)-1); RefreshList; end;
procedure TAssignmentForm.FilesClick(Sender: TObject);
begin EAEditFiles(Self,Files,Base); end;
procedure TAssignmentForm.NewResource(Sender: TObject);
var R: TPLRecurso;
begin R:=Doc.NovoRecurso; if PLEditResource(Self,Doc,R,Users) then begin try Doc.AdicionarRecurso(R); except R.Free; raise; end; LoadResources; end else R.Free; end;
function PLEditTaskResources(Owner: TForm; Doc: TPLProjeto; T: TPLTarefa; Users: TJSONArray; const BaseFile: string): Boolean;
var F: TAssignmentForm; I,K,N: Integer; Backup: TPLAlocacoes;
begin
 Result:=False; F:=TAssignmentForm.Create(Owner);
 try
  F.Doc:=Doc; F.Task:=T; F.Users:=Users; F.Base:=BaseFile; F.Files:=Doc.ArquivosTarefa(T,'');
  for I:=0 to High(T.Alocacoes) do begin K:=Doc.RecursoIndice(T.Alocacoes[I].RecursoID); if Doc.Recursos[K].Tipo=prtArquivo then Continue; N:=Length(F.Data); SetLength(F.Data,N+1); F.Data[N]:=T.Alocacoes[I]; end;
  F.LoadResources; F.RefreshList;
  while F.ShowModal=mrOK do begin
   Backup:=Copy(T.Alocacoes);
   try
    Doc.DefinirAlocacoes(T,F.Data); Doc.ImportarArquivos(T,F.Files); Doc.ValidarRecursos; Result:=True; Break;
   except on E: Exception do begin T.Alocacoes:=Backup; ShowMessage(E.Message); end; end;
  end;
 finally F.Files.Free; F.Free; end;
end;

type
 TCostForm=class(TForm)
 private
  Data: TPLCustos; List: TListBox; CostName,Price: TEdit; Qty: TFloatSpinEdit; Accounted: TCheckBox;
  procedure RefreshList; procedure SelectItem(Sender: TObject); procedure AddClick(Sender: TObject); procedure UpdateClick(Sender: TObject); procedure RemoveClick(Sender: TObject);
  function Fields: TPLCustoItem;
 public constructor Create(AOwner: TComponent); override;
 end;
constructor TCostForm.Create(AOwner: TComponent);
var B: TButton;
begin
 inherited CreateNew(AOwner); Caption:='Composição de custos da tarefa'; SetBounds(0,0,780,570); Position:=poScreenCenter; BorderStyle:=bsDialog; Font.Name:='Segoe UI'; Font.Size:=10;
 List:=TListBox.Create(Self); List.Parent:=Self; List.SetBounds(16,16,730,200); List.OnClick:=@SelectItem;
 LabelAt(Self,'Descrição do custo direto (componente)',16,232,730); CostName:=EditAt(Self,'',16,258,730);
 LabelAt(Self,'Quantidade',16,300,210); Qty:=TFloatSpinEdit.Create(Self); Qty.Parent:=Self; Qty.SetBounds(16,326,210,28); Qty.MinValue:=0.001; Qty.MaxValue:=1000000000; Qty.DecimalPlaces:=3; Qty.Value:=1;
 LabelAt(Self,'Valor unitário (R$)',248,300,210); Price:=EditAt(Self,'0,00',248,326,210);
 Accounted:=TCheckBox.Create(Self); Accounted.Parent:=Self; Accounted.SetBounds(482,326,264,28); Accounted.Caption:='Contabilizar este componente'; Accounted.Checked:=True;
 ButtonAt(Self,'Adicionar',16,376,112,@AddClick); ButtonAt(Self,'Atualizar',138,376,112,@UpdateClick); ButtonAt(Self,'Remover',260,376,112,@RemoveClick);
 LabelAt(Self,'Consumíveis e recursos/hora são incluídos pela alocação em Recursos da tarefa.',16,424,730);
 LabelAt(Self,'Saída = custos diretos + consumíveis + recursos/hora contabilizados; sem duplicar totais.',16,452,730);
 B:=ButtonAt(Self,'Confirmar',510,496,112,nil); B.ModalResult:=mrOK; B.Default:=True; B:=ButtonAt(Self,'Cancelar',634,496,112,nil); B.ModalResult:=mrCancel; B.Cancel:=True;
end;
procedure TCostForm.RefreshList;
var I: Integer; S: string;
begin List.Clear; for I:=0 to High(Data) do begin S:=Data[I].Nome+' | '+FloatToStr(Data[I].Quantidade)+' × '+EAMoneyText(Data[I].ValorUnitarioCentavos)+' = '+EAMoneyText(EALineCost(Data[I].Quantidade,Data[I].ValorUnitarioCentavos)); if Data[I].Contabilizado then S:=S+' | contabilizado' else S:=S+' | pendente'; List.Items.Add(S); end; end;
procedure TCostForm.SelectItem(Sender: TObject);
var I: Integer;
begin I:=List.ItemIndex; if I<0 then Exit; CostName.Text:=Data[I].Nome; Qty.Value:=Data[I].Quantidade; Price.Text:=EAMoneyText(Data[I].ValorUnitarioCentavos); Accounted.Checked:=Data[I].Contabilizado; end;
function TCostForm.Fields: TPLCustoItem;
begin Result.Nome:=Trim(CostName.Text); if Result.Nome='' then raise Exception.Create('Informe a descrição'); Result.Quantidade:=Qty.Value; Result.ValorUnitarioCentavos:=EAMoneyParse(Price.Text); Result.Contabilizado:=Accounted.Checked; EALineCost(Result.Quantidade,Result.ValorUnitarioCentavos); end;
procedure TCostForm.AddClick(Sender: TObject);
var Item: TPLCustoItem; N: Integer;
begin try Item:=Fields; N:=Length(Data); SetLength(Data,N+1); Data[N]:=Item; RefreshList; except on E: Exception do ShowMessage(E.Message); end; end;
procedure TCostForm.UpdateClick(Sender: TObject);
begin if List.ItemIndex<0 then Exit; try Data[List.ItemIndex]:=Fields; RefreshList; except on E: Exception do ShowMessage(E.Message); end; end;
procedure TCostForm.RemoveClick(Sender: TObject);
var I,J: Integer;
begin I:=List.ItemIndex; if I<0 then Exit; for J:=I to High(Data)-1 do Data[J]:=Data[J+1]; SetLength(Data,Length(Data)-1); RefreshList; end;
function PLEditTaskCosts(Owner: TForm; Doc: TPLProjeto; T: TPLTarefa): Boolean;
var F: TCostForm; Backup: TPLCustos;
begin
 Result:=False; F:=TCostForm.Create(Owner);
 try F.Data:=Copy(T.Custos); F.RefreshList;
  while F.ShowModal=mrOK do begin Backup:=Copy(T.Custos); try T.Custos:=Copy(F.Data); Doc.CustoTarefa(T,False); Doc.MarcarModificado; Result:=True; Break; except on E: Exception do begin T.Custos:=Backup; ShowMessage(E.Message); end; end; end;
 finally F.Free; end;
end;

constructor TPLRecursosPanel.Create(AOwner: TComponent);
var Bar: TPanel;
begin
 inherited Create(AOwner); BevelOuter:=bvNone;
 Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alTop; Bar.Height:=48; Bar.BevelOuter:=bvNone; Bar.Color:=RGBToColor(244,246,250);
 ButtonAt(Bar,'Novo recurso',12,8,132,@AddClick); ButtonAt(Bar,'Editar',154,8,100,@EditClick); ButtonAt(Bar,'Excluir',264,8,100,@DeleteClick); ButtonAt(Bar,'Importar usuários',374,8,156,@ImportUsers);
 LabelAt(Bar,'Duplo clique na barra abre a tarefa.',544,13,340);
 FGrid:=TStringGrid.Create(Self); FGrid.Parent:=Self; FGrid.Align:=alTop; FGrid.Height:=190; FGrid.ColCount:=5; FGrid.FixedCols:=0; FGrid.FixedRows:=1; FGrid.RowCount:=2; FGrid.Options:=FGrid.Options+[goRowSelect];
 FGrid.Cells[0,0]:='Recurso'; FGrid.Cells[1,0]:='Tipo'; FGrid.Cells[2,0]:='Capacidade'; FGrid.Cells[3,0]:='Preço un./hora'; FGrid.Cells[4,0]:='Situação'; FGrid.ColWidths[0]:=240; FGrid.ColWidths[1]:=160; FGrid.ColWidths[2]:=120; FGrid.ColWidths[3]:=140; FGrid.ColWidths[4]:=180; FGrid.OnDblClick:=@EditClick;
 FView:=TAIResourceView.Create(Self); FView.Parent:=Self; FView.Align:=alClient; FView.ColorBar:=RGBToColor(30,64,145); FView.OnBarDblClick:=@BarClick; FView.StatusDate:=Date;
end;
destructor TPLRecursosPanel.Destroy;
begin FUsers.Free; inherited Destroy; end;
procedure TPLRecursosPanel.Setup(Doc: TPLProjeto; Crono: TPLCronograma; Users: TJSONArray);
var I,J,K: Integer; R: TPLRecurso; Row: TAIResourceRow; Bar: TAIResourceBar; A: TAIAssignment; O: TAIOverload; BarText: string;
begin
 FDoc:=Doc; FCrono:=Crono; FreeAndNil(FUsers); if Users<>nil then FUsers:=TJSONArray(Users.Clone);
 FGrid.RowCount:=Max(2,Doc.Recursos.Count+1); for J:=0 to 4 do FGrid.Cells[J,1]:='';
 FView.BeginUpdate;
 try
 FView.Clear;
 for I:=0 to Doc.Recursos.Count-1 do begin
  R:=Doc.Recursos[I]; FGrid.Cells[0,I+1]:=R.Nome; FGrid.Cells[1,I+1]:=PL_RECURSO_TIPOS[R.Tipo]; FGrid.Cells[2,I+1]:=FloatToStr(R.Capacidade*100)+'%'; FGrid.Cells[3,I+1]:=EAMoneyText(R.PrecoCentavos);
  Row:=AIResourceRow(R.ID,R.Nome,PL_RECURSO_TIPOS[R.Tipo]); Row.Subtitle:=FGrid.Cells[2,I+1]; Row.Tag:=I;
  if Crono.Valido then Row.Overallocated:=Crono.Carga.IsOverallocated(I);
  if Row.Overallocated then FGrid.Cells[4,I+1]:='SOBRECARGA' else FGrid.Cells[4,I+1]:='';
  if R.Tipo in [prtMaterial,prtArquivo] then begin FGrid.Cells[2,I+1]:='Não se aplica'; Row.Subtitle:=''; end;
  FView.AddRow(Row);
 end;
 if Crono.Valido then begin
  for I:=0 to Crono.Carga.AssignmentCount-1 do begin
   A:=Crono.Carga.Assignments[I]; BarText:=Doc[A.Task].Nome;
   if Doc.Recursos[A.Resource].Tipo=prtMaterial then BarText:=BarText+' | entrada '+FloatToStr(A.Units)
   else if Doc.Recursos[A.Resource].Tipo=prtArquivo then begin
    for J:=0 to High(Doc[A.Task].Alocacoes) do if Doc[A.Task].Alocacoes[J].RecursoID=Doc.Recursos[A.Resource].ID then BarText:=BarText+' | '+PL_DIRECOES[Doc[A.Task].Alocacoes[J].Direcao];
   end else BarText:=BarText+' | '+FloatToStr(A.Units*100)+'%';
   Bar:=AIResourceBar(IntToStr(I),A.Resource,A.Start,A.Finish,BarText); Bar.Tag:=A.Task; Bar.Overloaded:=Crono.Conflito[A.Task]; FView.AddBar(Bar);
   if Crono.Conflito[A.Task] and (FGrid.Cells[4,A.Resource+1]='') then FGrid.Cells[4,A.Resource+1]:='Ver avisos da tarefa';
  end;
  for I:=0 to Crono.Carga.OverloadCount-1 do begin O:=Crono.Carga.Overloads[I]; FView.AddOverload(O.Resource,O.Start,O.Finish); end;
 end;
 finally FView.EndUpdate; end;
 FView.FitToBars;
end;
procedure TPLRecursosPanel.AddClick(Sender: TObject);
var R: TPLRecurso;
begin
 R:=FDoc.NovoRecurso;
 try if not PLEditResource(TForm(GetParentForm(Self)),FDoc,R,FUsers) then begin R.Free; Exit; end; FDoc.AdicionarRecurso(R); except R.Free; raise; end;
 if Assigned(OnChanged) then OnChanged(Self);
end;
procedure TPLRecursosPanel.EditClick(Sender: TObject);
var I: Integer;
begin I:=FGrid.Row-1; if (I<0) or (I>=FDoc.Recursos.Count) then Exit; if PLEditResource(TForm(GetParentForm(Self)),FDoc,FDoc.Recursos[I],FUsers) then begin FDoc.MarcarModificado; if Assigned(OnChanged) then OnChanged(Self); end; end;
procedure TPLRecursosPanel.DeleteClick(Sender: TObject);
begin try FDoc.ExcluirRecurso(FGrid.Row-1); if Assigned(OnChanged) then OnChanged(Self); except on E: Exception do ShowMessage(E.Message); end; end;
procedure TPLRecursosPanel.ImportUsers(Sender: TObject);
var I: Integer; T: TPLTarefa;
begin
 if FUsers=nil then Exit; T:=TPLTarefa.Create('','');
 try for I:=0 to FUsers.Count-1 do if FUsers.Objects[I].Get('active',False) and (FUsers.Objects[I].Get('role','')<>'viewer') then begin T.ExecutorID:=FUsers.Objects[I].Get('id',''); T.ExecutorNome:=FUsers.Objects[I].Get('name',''); T.Responsavel:=FUsers.Objects[I].Get('login',''); FDoc.RecursoExecutor(T); end;
 finally T.Free; end; if Assigned(OnChanged) then OnChanged(Self);
end;
procedure TPLRecursosPanel.BarClick(Sender: TObject; Index: Integer);
begin if Index<0 then Exit; SelectedTask:=FView.Bar(Index).Tag; if Assigned(OnSelectTask) then OnSelectTask(Self); end;
end.
