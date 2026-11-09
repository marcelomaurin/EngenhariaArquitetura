unit plan_relatorios_sprint_ui;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes,SysUtils,Forms,plan_documento,plan_cronograma,plan_sprints;
function PLEditarHoras(Owner: TForm; Doc: TPLProjeto; const TaskID: string; DataInicial: TDateTime; const ApontamentoID: string=''): Boolean;
function PLCriarRelatorioSprint(Owner: TForm; Doc: TPLProjeto; Crono: TPLCronograma; Sprint: TPLSprint; const ResourceID: string): TForm;
procedure PLMostrarRelatorioSprint(Owner: TForm; Doc: TPLProjeto; Crono: TPLCronograma; Sprint: TPLSprint; const ResourceID: string; OnChanged: TNotifyEvent);
implementation
uses Math,Controls,StdCtrls,ExtCtrls,ComCtrls,Grids,Dialogs,Graphics,EditBtn,Spin,
 plan_tipos,plan_recursos,plan_apontamentos,plan_acompanhamento,plan_relatorios_sprint;
function LabelAt(P: TWinControl; const S: string; X,Y,W: Integer): TLabel;
begin Result:=TLabel.Create(P); Result.Parent:=P; Result.SetBounds(X,Y,W,24); Result.Caption:=S; end;
function ButtonAt(P: TWinControl; const S: string; W: Integer; Event: TNotifyEvent): TButton;
begin Result:=TButton.Create(P); Result.Parent:=P; Result.SetBounds(0,0,W,32); Result.BorderSpacing.Around:=4; Result.Caption:=S; Result.OnClick:=Event; end;
function PLEditarHoras(Owner: TForm; Doc: TPLProjeto; const TaskID: string; DataInicial: TDateTime; const ApontamentoID: string): Boolean;
var F: TForm; Tasks,People: TComboBox; TaskKeys,PeopleKeys: TStringList; WorkDate: TDateEdit; Hours: TFloatSpinEdit; Notes: TMemo; B: TButton; I,K: Integer; Entry: TPLApontamento; DefaultResource: string;
begin
 Result:=False; F:=TForm.CreateNew(Owner); TaskKeys:=TStringList.Create; PeopleKeys:=TStringList.Create;
 try
  Entry.ID:=''; Entry.TaskID:=TaskID; Entry.Data:=DataInicial; Entry.Minutos:=60; Entry.Notas:=''; Entry.RecursoID:='';
  if ApontamentoID<>'' then begin K:=Doc.ApontamentoIndice(ApontamentoID); if K<0 then raise Exception.Create('Apontamento não encontrado'); Entry:=Doc.Apontamentos[K]; end;
  F.Caption:='Apontar horas por usuário e tarefa'; F.SetBounds(0,0,700,440); F.Position:=poScreenCenter; F.BorderStyle:=bsDialog; F.Font.Name:='Segoe UI'; F.Font.Size:=10; F.Color:=RGBToColor(244,246,250);
  LabelAt(F,'Tarefa',18,16,650); Tasks:=TComboBox.Create(F); Tasks.Parent:=F; Tasks.SetBounds(18,42,650,28); Tasks.Style:=csDropDownList;
  for I:=0 to Doc.Count-1 do begin Tasks.Items.Add(Doc[I].ID+' — '+Doc[I].Nome); TaskKeys.Add(Doc[I].ID); end; Tasks.ItemIndex:=TaskKeys.IndexOf(Entry.TaskID); if (Tasks.ItemIndex<0) and (Tasks.Items.Count>0) then Tasks.ItemIndex:=0;
  LabelAt(F,'Pessoa / usuário que executou o trabalho',18,86,650); People:=TComboBox.Create(F); People.Parent:=F; People.SetBounds(18,112,650,28); People.Style:=csDropDownList;
  DefaultResource:=Entry.RecursoID; K:=Doc.IndiceDe(Entry.TaskID);
  for I:=0 to Doc.Recursos.Count-1 do if Doc.Recursos[I].Tipo=prtPessoa then begin
   People.Items.Add(Doc.Recursos[I].Nome); PeopleKeys.Add(Doc.Recursos[I].ID);
   if (DefaultResource='') and (K>=0) and (Doc[K].ExecutorID<>'') and (Doc[K].ExecutorID=Doc.Recursos[I].UsuarioID) then DefaultResource:=Doc.Recursos[I].ID;
  end;
  People.ItemIndex:=PeopleKeys.IndexOf(DefaultResource); if (People.ItemIndex<0) and (People.Items.Count>0) then People.ItemIndex:=0;
  LabelAt(F,'Data do trabalho',18,156,310); WorkDate:=TDateEdit.Create(F); WorkDate.Parent:=F; WorkDate.SetBounds(18,182,310,28); WorkDate.DateOrder:=doDMY; WorkDate.Date:=Entry.Data;
  LabelAt(F,'Horas realizadas (arredondadas ao minuto)',350,156,318); Hours:=TFloatSpinEdit.Create(F); Hours.Parent:=F; Hours.SetBounds(350,182,318,28); Hours.MinValue:=1/60; Hours.MaxValue:=24; Hours.DecimalPlaces:=4; Hours.Increment:=0.25; Hours.Value:=Entry.Minutos/60;
  LabelAt(F,'Observação / atividade realizada (opcional)',18,226,650); Notes:=TMemo.Create(F); Notes.Parent:=F; Notes.SetBounds(18,252,650,80); Notes.Text:=Entry.Notas;
  LabelAt(F,'Horas são registradas por data; não concluem a tarefa nem lançam custo automaticamente.',18,342,650);
  B:=ButtonAt(F,'Salvar horas',120,nil); B.SetBounds(410,374,120,32); B.ModalResult:=mrOK; B.Default:=True; B:=ButtonAt(F,'Cancelar',128,nil); B.SetBounds(540,374,128,32); B.ModalResult:=mrCancel; B.Cancel:=True;
  while F.ShowModal=mrOK do begin
   try
    if Tasks.ItemIndex<0 then raise Exception.Create('Cadastre e selecione uma tarefa');
    if People.ItemIndex<0 then raise Exception.Create('Cadastre/importa uma pessoa na etapa Recursos para apontar horas');
    Doc.SalvarApontamento(Entry.ID,TaskKeys[Tasks.ItemIndex],PeopleKeys[People.ItemIndex],WorkDate.Date,Round(Hours.Value*60),Notes.Text); Result:=True; Break;
   except on E: Exception do ShowMessage(E.Message); end;
  end;
 finally PeopleKeys.Free; TaskKeys.Free; F.Free; end;
end;
type
 TSprintReportForm=class(TForm)
 private
  FDoc: TPLProjeto; FCrono: TPLCronograma; FSprint: TPLSprint; FReport: TPLRelatorioSprint;
  FKeys,FHourKeys: TStringList; FFilter: TComboBox; FDate: TDateEdit; FSummary: TLabel;
  FPending,FUsers,FHours,FAll: TStringGrid; FLoading: Boolean;
  procedure Reload;
  procedure FilterChanged(Sender: TObject);
  procedure ExportHTML(Sender: TObject); procedure ExportPending(Sender: TObject); procedure ExportUsers(Sender: TObject); procedure ExportHours(Sender: TObject);
  procedure NewHours(Sender: TObject); procedure EditHours(Sender: TObject); procedure DeleteHours(Sender: TObject);
  procedure DataChanged;
  function SelectPath(const FileName,Filter,Extension: string): string;
 public
  OnDataChanged: TNotifyEvent;
  constructor Create(AOwner: TComponent); override; destructor Destroy; override;
  procedure Setup(Doc: TPLProjeto; Crono: TPLCronograma; Sprint: TPLSprint; const ResourceID: string);
 end;
constructor TSprintReportForm.Create(AOwner: TComponent);
var Filters,Actions,Bottom: TFlowPanel; Tabs: TPageControl; HintLabel: TLabel; B: TButton;
 function AddGrid(const CaptionText: string; const Columns: array of string): TStringGrid;
 var Tab: TTabSheet; I: Integer;
 begin
  Tab:=TTabSheet.Create(Tabs); Tab.PageControl:=Tabs; Tab.Caption:=CaptionText; Result:=TStringGrid.Create(Self); Result.Parent:=Tab; Result.Align:=alClient; Result.FixedCols:=0; Result.FixedRows:=1; Result.RowCount:=2; Result.ColCount:=Length(Columns); Result.Options:=[goColSizing,goRowSelect,goVertLine,goHorzLine]; Result.DefaultRowHeight:=28;
  for I:=0 to High(Columns) do begin Result.Cells[I,0]:=Columns[I]; Result.ColWidths[I]:=140; end;
 end;
begin
 inherited CreateNew(AOwner); Caption:='Relatório da sprint'; SetBounds(0,0,1120,740); Constraints.MinWidth:=780; Constraints.MinHeight:=580; Position:=poScreenCenter; Font.Name:='Segoe UI'; Font.Size:=10; Color:=RGBToColor(244,246,250);
 FKeys:=TStringList.Create; FHourKeys:=TStringList.Create;
 Filters:=TFlowPanel.Create(Self); Filters.Parent:=Self; Filters.Align:=alTop; Filters.Top:=0; Filters.AutoWrap:=True; Filters.AutoSize:=True; Filters.BevelOuter:=bvNone;
 FFilter:=TComboBox.Create(Self); FFilter.Parent:=Filters; FFilter.SetBounds(0,0,360,28); FFilter.BorderSpacing.Around:=4; FFilter.Style:=csDropDownList; FFilter.OnChange:=@FilterChanged;
 FDate:=TDateEdit.Create(Self); FDate.Parent:=Filters; FDate.SetBounds(0,0,140,28); FDate.BorderSpacing.Around:=4; FDate.DateOrder:=doDMY; FDate.Date:=Date; FDate.OnEditingDone:=@FilterChanged; FDate.Hint:='Data de referência para atraso; situações são as atuais'; FDate.ShowHint:=True;
 Actions:=TFlowPanel.Create(Self); Actions.Parent:=Self; Actions.Align:=alTop; Actions.Top:=1000; Actions.AutoWrap:=True; Actions.AutoSize:=True; Actions.BevelOuter:=bvNone;
 ButtonAt(Actions,'Relatório HTML',142,@ExportHTML); ButtonAt(Actions,'Pendências CSV',144,@ExportPending); ButtonAt(Actions,'Carga por usuário CSV',178,@ExportUsers); ButtonAt(Actions,'Horas apontadas CSV',176,@ExportHours);
 FSummary:=TLabel.Create(Self); FSummary.Parent:=Self; FSummary.Align:=alTop; FSummary.Top:=2000; FSummary.Height:=74; FSummary.AutoSize:=False; FSummary.WordWrap:=True; FSummary.Font.Style:=[fsBold]; FSummary.Font.Color:=RGBToColor(30,64,145);
 Bottom:=TFlowPanel.Create(Self); Bottom.Parent:=Self; Bottom.Align:=alBottom; Bottom.AutoSize:=True; Bottom.AutoWrap:=True; Bottom.BevelOuter:=bvNone;
 ButtonAt(Bottom,'Apontar horas',140,@NewHours); ButtonAt(Bottom,'Editar apontamento',168,@EditHours); ButtonAt(Bottom,'Remover apontamento',182,@DeleteHours); B:=ButtonAt(Bottom,'Fechar',112,nil); B.ModalResult:=mrClose; B.Cancel:=True;
 HintLabel:=TLabel.Create(Self); HintLabel.Parent:=Self; HintLabel.Align:=alBottom; HintLabel.AutoSize:=False; HintLabel.Height:=52; HintLabel.WordWrap:=True; HintLabel.Caption:='Horas apontadas são registros de trabalho por data dentro da sprint. Carga concluída/restante é estimativa do escopo pelo progresso. Equipes não são divididas automaticamente entre pessoas. Salve o projeto para preservar os apontamentos.';
 Tabs:=TPageControl.Create(Self); Tabs.Parent:=Self; Tabs.Align:=alClient;
 FPending:=AddGrid('Pendências',['ID','Tarefa','Executor','Situação','%','Prazo','Atrasada','Origem anterior','Restante estimado h','Apontadas h']); FPending.ColWidths[1]:=270;
 FUsers:=AddGrid('Carga por usuário',['Usuário','Tarefas','Pendentes','Concluídas','Atrasadas','Prevista período h','Concluída estimada h','Restante estimado h','Apontadas na sprint h','Capacidade h']); FUsers.ColWidths[0]:=230;
 FHours:=AddGrid('Horas apontadas',['Data','Usuário','ID tarefa','Tarefa','Horas','Observação']); FHours.ColWidths[1]:=220; FHours.ColWidths[3]:=260; FHours.ColWidths[5]:=300;
 FAll:=AddGrid('Escopo completo',['ID','Tarefa','Executor','Situação','%','Prazo','Origem anterior','Restante estimado h','Apontadas h']); FAll.ColWidths[1]:=270;
end;
destructor TSprintReportForm.Destroy;
begin FReport.Free; FKeys.Free; FHourKeys.Free; inherited Destroy; end;
procedure TSprintReportForm.Setup(Doc: TPLProjeto; Crono: TPLCronograma; Sprint: TPLSprint; const ResourceID: string);
var I: Integer;
begin
 FDoc:=Doc; FCrono:=Crono; FSprint:=Sprint; FLoading:=True;
 try FFilter.Clear; FKeys.Clear; FFilter.Items.Add('Todos os usuários / recursos'); FKeys.Add('');
  for I:=0 to Doc.Recursos.Count-1 do begin FFilter.Items.Add(PL_RECURSO_TIPOS[Doc.Recursos[I].Tipo]+' | '+Doc.Recursos[I].Nome); FKeys.Add(Doc.Recursos[I].ID); end;
  FFilter.ItemIndex:=Max(0,FKeys.IndexOf(ResourceID));
 finally FLoading:=False; end; Reload;
end;
procedure TSprintReportForm.Reload;
var ReportData: TPLRelatorioSprint; I,J,Row: Integer; FilterKey: string; T: TPLSprintTarefaRel; U: TPLSprintUsuarioRel; H: TPLSprintHoraRel;
 procedure ClearGrid(Grid: TStringGrid; Rows: Integer);
 var C,R: Integer;
 begin Grid.RowCount:=Max(2,Rows+1); for R:=1 to Grid.RowCount-1 do for C:=0 to Grid.ColCount-1 do Grid.Cells[C,R]:=''; end;
begin
 if (FDoc=nil) or FLoading then Exit; FilterKey:=''; if FFilter.ItemIndex>=0 then FilterKey:=FKeys[FFilter.ItemIndex];
 ReportData:=PLGerarRelatorioSprint(FDoc,FCrono,FSprint,FilterKey,FDate.Date); FReport.Free; FReport:=ReportData;
 Caption:='Relatório da sprint — '+FReport.SprintNome;
 FSummary.Caption:=FReport.SprintNome+' | '+PLDataISO(FReport.Inicio)+' a '+PLDataISO(FReport.Fim)+#10+IntToStr(FReport.Total)+' tarefas | '+IntToStr(FReport.Pendentes)+' pendentes | '+IntToStr(FReport.Concluidas)+' concluídas | '+IntToStr(FReport.Atrasadas)+' atrasadas | '+PLHorasTexto(FReport.ApontadoMin)+' h apontadas | '+PLHorasTexto(FReport.RestanteMin)+' h restantes estimadas';
 ClearGrid(FPending,FReport.Pendentes); ClearGrid(FAll,FReport.Total); Row:=1;
 for I:=0 to High(FReport.Tarefas) do begin
  T:=FReport.Tarefas[I]; FAll.Cells[0,I+1]:=T.ID; FAll.Cells[1,I+1]:=T.Nome; FAll.Cells[2,I+1]:=T.Executor; FAll.Cells[3,I+1]:=PL_SITUACAO_NOME[T.Situacao]; FAll.Cells[4,I+1]:=IntToStr(T.Progresso); FAll.Cells[5,I+1]:=PLDataISO(T.Fim); if T.PendenteAnterior then FAll.Cells[6,I+1]:='Sim'; FAll.Cells[7,I+1]:=PLHorasTexto(T.RestanteMin); FAll.Cells[8,I+1]:=PLHorasTexto(T.ApontadoMin);
  if T.Situacao=plsConcluida then Continue;
  FPending.Cells[0,Row]:=T.ID; FPending.Cells[1,Row]:=T.Nome; FPending.Cells[2,Row]:=T.Executor; FPending.Cells[3,Row]:=PL_SITUACAO_NOME[T.Situacao]; FPending.Cells[4,Row]:=IntToStr(T.Progresso); FPending.Cells[5,Row]:=PLDataISO(T.Fim);
  if T.Atrasada then FPending.Cells[6,Row]:='Sim'; if T.PendenteAnterior then FPending.Cells[7,Row]:='Sim'; FPending.Cells[8,Row]:=PLHorasTexto(T.RestanteMin); FPending.Cells[9,Row]:=PLHorasTexto(T.ApontadoMin); Inc(Row);
 end;
 ClearGrid(FUsers,Length(FReport.Usuarios));
 for I:=0 to High(FReport.Usuarios) do begin U:=FReport.Usuarios[I]; FUsers.Cells[0,I+1]:=U.Nome; FUsers.Cells[1,I+1]:=IntToStr(U.Tarefas); FUsers.Cells[2,I+1]:=IntToStr(U.Pendentes); FUsers.Cells[3,I+1]:=IntToStr(U.Concluidas); FUsers.Cells[4,I+1]:=IntToStr(U.Atrasadas); FUsers.Cells[5,I+1]:=PLHorasTexto(U.PrevistoPeriodoMin); FUsers.Cells[6,I+1]:=PLHorasTexto(U.ConcluidoEstimadoMin); FUsers.Cells[7,I+1]:=PLHorasTexto(U.RestanteEstimadoMin); FUsers.Cells[8,I+1]:=PLHorasTexto(U.ApontadoMin); if U.RecursoID<>'' then FUsers.Cells[9,I+1]:=PLHorasTexto(U.CapacidadeMin) else FUsers.Cells[9,I+1]:='—'; end;
 ClearGrid(FHours,Length(FReport.Horas)); FHourKeys.Clear;
 for I:=0 to High(FReport.Horas) do begin H:=FReport.Horas[I]; FHourKeys.Add(H.ID); FHours.Cells[0,I+1]:=PLDataISO(H.Data); FHours.Cells[1,I+1]:=H.Usuario; FHours.Cells[2,I+1]:=H.TaskID; FHours.Cells[3,I+1]:=H.Tarefa; FHours.Cells[4,I+1]:=PLHorasTexto(H.Minutos); FHours.Cells[5,I+1]:=H.Notas; end;
end;
procedure TSprintReportForm.FilterChanged(Sender: TObject);
begin if FLoading then Exit; try Reload; except on E: Exception do ShowMessage(E.Message); end; end;
function TSprintReportForm.SelectPath(const FileName,Filter,Extension: string): string;
var D: TSaveDialog;
begin Result:=''; D:=TSaveDialog.Create(Self); try D.FileName:=FileName; D.Filter:=Filter; D.DefaultExt:=Extension; D.Options:=D.Options+[ofOverwritePrompt]; if D.Execute then Result:=D.FileName; finally D.Free; end; end;
procedure TSprintReportForm.ExportHTML(Sender: TObject);
var Path: string;
begin try Path:=SelectPath('relatorio_sprint.html','HTML (*.html)|*.html','html'); if Path<>'' then PLRelatorioSprintHTML(FReport,Path); except on E: Exception do ShowMessage(E.Message); end; end;
procedure TSprintReportForm.ExportPending(Sender: TObject);
var Path: string;
begin try Path:=SelectPath('sprint_pendencias.csv','CSV (*.csv)|*.csv','csv'); if Path<>'' then PLRelatorioSprintPendenciasCSV(FReport,Path); except on E: Exception do ShowMessage(E.Message); end; end;
procedure TSprintReportForm.ExportUsers(Sender: TObject);
var Path: string;
begin try Path:=SelectPath('sprint_carga_usuarios.csv','CSV (*.csv)|*.csv','csv'); if Path<>'' then PLRelatorioSprintUsuariosCSV(FReport,Path); except on E: Exception do ShowMessage(E.Message); end; end;
procedure TSprintReportForm.ExportHours(Sender: TObject);
var Path: string;
begin try Path:=SelectPath('sprint_horas_apontadas.csv','CSV (*.csv)|*.csv','csv'); if Path<>'' then PLRelatorioSprintHorasCSV(FReport,Path); except on E: Exception do ShowMessage(E.Message); end; end;
procedure TSprintReportForm.DataChanged;
begin if Assigned(OnDataChanged) then OnDataChanged(Self) else begin FCrono.Calcular(FDoc); PLAtualizarSprints(FDoc,FCrono); end; Reload; end;
procedure TSprintReportForm.NewHours(Sender: TObject);
var TaskID: string;
begin
 TaskID:='';
 if (TTabSheet(FPending.Parent).PageControl.ActivePage=TTabSheet(FPending.Parent)) and (FPending.Row>0) and (FPending.Row<=FReport.Pendentes) then TaskID:=FPending.Cells[0,FPending.Row];
 if (TTabSheet(FAll.Parent).PageControl.ActivePage=TTabSheet(FAll.Parent)) and (FAll.Row>0) and (FAll.Row<=FReport.Total) then TaskID:=FAll.Cells[0,FAll.Row];
 if (TaskID='') and (Length(FReport.Tarefas)>0) then TaskID:=FReport.Tarefas[0].ID;
 if PLEditarHoras(Self,FDoc,TaskID,Date) then DataChanged;
end;
procedure TSprintReportForm.EditHours(Sender: TObject);
begin if TTabSheet(FHours.Parent).PageControl.ActivePage<>TTabSheet(FHours.Parent) then begin ShowMessage('Abra a aba Horas apontadas e selecione o registro a editar'); Exit; end; if (FHours.Row<1) or (FHours.Row>FHourKeys.Count) then begin ShowMessage('Selecione um apontamento na aba Horas apontadas'); Exit; end; if PLEditarHoras(Self,FDoc,'',Date,FHourKeys[FHours.Row-1]) then DataChanged; end;
procedure TSprintReportForm.DeleteHours(Sender: TObject);
begin
 if TTabSheet(FHours.Parent).PageControl.ActivePage<>TTabSheet(FHours.Parent) then begin ShowMessage('Abra a aba Horas apontadas e selecione o registro a remover'); Exit; end;
 if (FHours.Row<1) or (FHours.Row>FHourKeys.Count) then begin ShowMessage('Selecione um apontamento na aba Horas apontadas'); Exit; end;
 if MessageDlg('Remover apontamento','Remover este registro de horas? A tarefa será preservada.',mtConfirmation,[mbYes,mbNo],0)<>mrYes then Exit;
 FDoc.ExcluirApontamento(FHourKeys[FHours.Row-1]); DataChanged;
end;
function PLCriarRelatorioSprint(Owner: TForm; Doc: TPLProjeto; Crono: TPLCronograma; Sprint: TPLSprint; const ResourceID: string): TForm;
var F: TSprintReportForm;
begin
 if Sprint=nil then raise Exception.Create('Selecione uma sprint');
 F:=TSprintReportForm.Create(Owner); try F.Setup(Doc,Crono,Sprint,ResourceID); except F.Free; raise; end; Result:=F;
end;
procedure PLMostrarRelatorioSprint(Owner: TForm; Doc: TPLProjeto; Crono: TPLCronograma; Sprint: TPLSprint; const ResourceID: string; OnChanged: TNotifyEvent);
var F: TSprintReportForm;
begin
 if Sprint=nil then begin ShowMessage('Selecione uma sprint no quadro TO-DO'); Exit; end;
 F:=TSprintReportForm.Create(Owner); try F.OnDataChanged:=OnChanged; F.Setup(Doc,Crono,Sprint,ResourceID); F.ShowModal; finally F.Free; end;
end;
end.
