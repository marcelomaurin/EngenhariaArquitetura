unit plan_acompanhamento_ui;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes,SysUtils,Forms,Controls,StdCtrls,ExtCtrls,Grids,Graphics,Types,EditBtn,
 plan_documento,plan_cronograma,plan_tipos,plan_sprints,plan_acompanhamento;
type
 TPLSprintPanel=class(TPanel)
 private
  FDoc: TPLProjeto; FCrono: TPLCronograma; FLoading: Boolean;
  FSprint,FRecurso: TComboBox; FSprintKeys,FResourceKeys: TStringList;
  FColumns: array[0..2] of TPanel; FHeaders: array[0..2] of TLabel; FBoards: array[0..2] of TListBox;
  FIndices: array[0..2] of TPLTaskIndices; FContainers: TPanel; FPlot: TPaintBox;
  FSelectedID,FPendingSprint: string;
  procedure ResizeBoards(Sender: TObject); procedure RefreshBoard;
  procedure FilterChanged(Sender: TObject); procedure NewSprint(Sender: TObject); procedure EditSprint(Sender: TObject);
  procedure ReportSprint(Sender: TObject); procedure RecordTaskHours(Sender: TObject);
  procedure DeleteSprint(Sender: TObject); procedure UpdateSprint(Sender: TObject);
  procedure Selection(Sender: TObject); procedure OpenTask(Sender: TObject); procedure StatusClick(Sender: TObject);
  procedure DrawCard(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
  procedure PaintStats(Sender: TObject); procedure Changed;
  function CurrentSprint: TPLSprint;
 public
  OnChanged,OnOpenTask: TNotifyEvent;
  SelectedTask: Integer;
  constructor Create(AOwner: TComponent); override; destructor Destroy; override;
  procedure Setup(Doc: TPLProjeto; Crono: TPLCronograma);
 end;
 TPLCustosPanel=class(TPanel)
 private
  FDoc: TPLProjeto; FWeeks: TPLCustosSemanais; FChart: TPaintBox; FGrid: TStringGrid;
  FSummary,FHint: TLabel; FData: TDateEdit;
  procedure ResizeReport(Sender: TObject);
  procedure PaintChart(Sender: TObject); procedure RecordClick(Sender: TObject); procedure BudgetClick(Sender: TObject);
  procedure ExportCSV(Sender: TObject); procedure ExportHTML(Sender: TObject);
 public
  OnChanged: TNotifyEvent;
  constructor Create(AOwner: TComponent); override;
  procedure Setup(Doc: TPLProjeto);
 end;
implementation
uses Math,DateUtils,Dialogs,LCLType,ea_money,plan_recursos,plan_relatorios_sprint_ui;
function LabelAt(P: TWinControl; const S: string; X,Y,W: Integer): TLabel;
begin Result:=TLabel.Create(P); Result.Parent:=P; Result.SetBounds(X,Y,W,24); Result.Caption:=S; end;
function ButtonAt(P: TWinControl; const S: string; X,Y,W: Integer; Event: TNotifyEvent): TButton;
begin Result:=TButton.Create(P); Result.Parent:=P; Result.SetBounds(X,Y,W,30); Result.Caption:=S; Result.OnClick:=Event; end;
function EditSprintDialog(Owner: TForm; const OldName: string; Start,Finish: TDateTime; out NewName: string; out NewStart,NewEnd: TDateTime): Boolean;
var F: TForm; NameEdit: TEdit; First,Last: TDateEdit; B: TButton;
begin
 Result:=False; F:=TForm.CreateNew(Owner);
 try
  F.Caption:='Sprint — período e agrupamento automático'; F.SetBounds(0,0,560,286); F.Position:=poScreenCenter; F.BorderStyle:=bsDialog; F.Font.Name:='Segoe UI'; F.Font.Size:=10;
  LabelAt(F,'Nome da sprint',18,16,520); NameEdit:=TEdit.Create(F); NameEdit.Parent:=F; NameEdit.SetBounds(18,42,520,28); NameEdit.Text:=OldName;
  LabelAt(F,'Início',18,86,240); LabelAt(F,'Fim (inclusive)',290,86,240);
  First:=TDateEdit.Create(F); First.Parent:=F; First.SetBounds(18,112,240,28); First.DateOrder:=doDMY; First.Date:=Start;
  Last:=TDateEdit.Create(F); Last.Parent:=F; Last.SetBounds(290,112,248,28); Last.DateOrder:=doDMY; Last.Date:=Finish;
  with LabelAt(F,'Inclui tarefas do período e pendências anteriores. Não altera suas datas nem duplica tarefas.',18,158,520) do begin AutoSize:=False; Height:=42; WordWrap:=True; end;
  B:=ButtonAt(F,'Confirmar',300,218,112,nil); B.ModalResult:=mrOK; B.Default:=True; B:=ButtonAt(F,'Cancelar',426,218,112,nil); B.ModalResult:=mrCancel; B.Cancel:=True;
  while F.ShowModal=mrOK do begin
   try
    NewName:=Trim(NameEdit.Text); NewStart:=Trunc(First.Date); NewEnd:=Trunc(Last.Date);
    if (NewName='') or (NewStart<=0) or (NewEnd<NewStart) or (NewEnd-NewStart>3660) then raise Exception.Create('Informe nome e período válido');
    Result:=True; Break;
   except on E: Exception do ShowMessage(E.Message); end;
  end;
 finally F.Free; end;
end;
constructor TPLSprintPanel.Create(AOwner: TComponent);
var Filters,Actions: TFlowPanel; Field: TPanel; B: TButton; I: Integer;
begin
 inherited Create(AOwner); BevelOuter:=bvNone; FSprintKeys:=TStringList.Create; FResourceKeys:=TStringList.Create;
 Filters:=TFlowPanel.Create(Self); Filters.Parent:=Self; Filters.Align:=alTop; Filters.Top:=0; Filters.AutoWrap:=True; Filters.AutoSize:=True; Filters.BevelOuter:=bvNone; Filters.Color:=RGBToColor(244,246,250);
 Field:=TPanel.Create(Self); Field.Parent:=Filters; Field.SetBounds(0,0,344,64); Field.BevelOuter:=bvNone; Field.BorderSpacing.Around:=4;
 LabelAt(Field,'Sprint / período',4,2,330);
 FSprint:=TComboBox.Create(Self); FSprint.Parent:=Field; FSprint.SetBounds(4,28,330,28); FSprint.Style:=csDropDownList; FSprint.OnChange:=@FilterChanged;
 Field:=TPanel.Create(Self); Field.Parent:=Filters; Field.SetBounds(0,0,344,64); Field.BevelOuter:=bvNone; Field.BorderSpacing.Around:=4;
 LabelAt(Field,'Usuário / recurso',4,2,330);
 FRecurso:=TComboBox.Create(Self); FRecurso.Parent:=Field; FRecurso.SetBounds(4,28,330,28); FRecurso.Style:=csDropDownList; FRecurso.OnChange:=@FilterChanged;
 Actions:=TFlowPanel.Create(Self); Actions.Parent:=Self; Actions.Align:=alTop; Actions.Top:=1000; Actions.AutoWrap:=True; Actions.AutoSize:=True; Actions.BevelOuter:=bvNone;
 B:=ButtonAt(Actions,'Nova sprint',0,0,116,@NewSprint); B.BorderSpacing.Around:=4;
 B:=ButtonAt(Actions,'Editar período',0,0,120,@EditSprint); B.BorderSpacing.Around:=4;
 B:=ButtonAt(Actions,'Excluir sprint',0,0,120,@DeleteSprint); B.BorderSpacing.Around:=4;
 B:=ButtonAt(Actions,'Atualizar tarefas',0,0,144,@UpdateSprint); B.BorderSpacing.Around:=4;
 B:=ButtonAt(Actions,'Relatório da sprint',0,0,154,@ReportSprint); B.BorderSpacing.Around:=4;
 B:=ButtonAt(Actions,'Apontar horas',0,0,132,@RecordTaskHours); B.BorderSpacing.Around:=4;
 for I:=0 to 2 do begin B:=ButtonAt(Actions,PL_SITUACAO_NOME[TPLSituacao(I)],0,0,110,@StatusClick); B.Tag:=I; B.BorderSpacing.Around:=4; end;
 FPlot:=TPaintBox.Create(Self); FPlot.Parent:=Self; FPlot.Align:=alTop; FPlot.Top:=2000; FPlot.Height:=66; FPlot.OnPaint:=@PaintStats;
 FContainers:=TPanel.Create(Self); FContainers.Parent:=Self; FContainers.Align:=alClient; FContainers.BevelOuter:=bvNone; FContainers.OnResize:=@ResizeBoards;
 for I:=0 to 2 do begin
  FColumns[I]:=TPanel.Create(Self); FColumns[I].Parent:=FContainers; FColumns[I].BevelOuter:=bvNone; FColumns[I].Color:=RGBToColor(241,245,249);
  FHeaders[I]:=TLabel.Create(Self); FHeaders[I].Parent:=FColumns[I]; FHeaders[I].Align:=alTop; FHeaders[I].Height:=32; FHeaders[I].Font.Style:=[fsBold]; FHeaders[I].Font.Color:=RGBToColor(30,64,145);
  FBoards[I]:=TListBox.Create(Self); FBoards[I].Parent:=FColumns[I]; FBoards[I].Align:=alClient; FBoards[I].Style:=lbOwnerDrawFixed; FBoards[I].ItemHeight:=88; FBoards[I].Tag:=I; FBoards[I].OnClick:=@Selection; FBoards[I].OnDblClick:=@OpenTask; FBoards[I].OnDrawItem:=@DrawCard;
 end;
 ResizeBoards(nil);
end;
destructor TPLSprintPanel.Destroy;
begin FSprintKeys.Free; FResourceKeys.Free; inherited Destroy; end;
procedure TPLSprintPanel.ResizeBoards(Sender: TObject);
var I,W: Integer;
begin W:=FContainers.ClientWidth div 3; for I:=0 to 2 do if FColumns[I]<>nil then FColumns[I].SetBounds(I*W+4,4,Max(0,W-8),Max(0,FContainers.ClientHeight-8)); end;
function TPLSprintPanel.CurrentSprint: TPLSprint;
var I: Integer;
begin Result:=nil; if (FDoc=nil) or (FSprint.ItemIndex<1) then Exit; for I:=0 to FDoc.Sprints.Count-1 do if FDoc.Sprints[I].ID=FSprintKeys[FSprint.ItemIndex] then Exit(FDoc.Sprints[I]); end;
procedure TPLSprintPanel.Setup(Doc: TPLProjeto; Crono: TPLCronograma);
var OldSprint,OldResource: string; I: Integer;
begin
 OldSprint:=''; OldResource:=''; if FSprint.ItemIndex>=0 then OldSprint:=FSprintKeys[FSprint.ItemIndex]; if FRecurso.ItemIndex>=0 then OldResource:=FResourceKeys[FRecurso.ItemIndex];
 if FPendingSprint<>'' then begin OldSprint:=FPendingSprint; FPendingSprint:=''; end;
 FDoc:=Doc; FCrono:=Crono; FLoading:=True;
 try
  FSprint.Clear; FSprintKeys.Clear; FSprint.Items.Add('Todas as tarefas'); FSprintKeys.Add('');
  for I:=0 to Doc.Sprints.Count-1 do begin FSprint.Items.Add(Doc.Sprints[I].Nome+' | '+FormatDateTime('dd/mm',Doc.Sprints[I].Inicio)+' a '+FormatDateTime('dd/mm/yyyy',Doc.Sprints[I].Fim)); FSprintKeys.Add(Doc.Sprints[I].ID); end;
  FSprint.ItemIndex:=Max(0,FSprintKeys.IndexOf(OldSprint));
  FRecurso.Clear; FResourceKeys.Clear; FRecurso.Items.Add('Todos os usuários / recursos'); FResourceKeys.Add('');
  for I:=0 to Doc.Recursos.Count-1 do begin FRecurso.Items.Add(PL_RECURSO_TIPOS[Doc.Recursos[I].Tipo]+' | '+Doc.Recursos[I].Nome); FResourceKeys.Add(Doc.Recursos[I].ID); end;
  FRecurso.ItemIndex:=Max(0,FResourceKeys.IndexOf(OldResource));
 finally FLoading:=False; end;
 RefreshBoard;
end;
procedure TPLSprintPanel.RefreshBoard;
var Tasks: TPLTaskIndices; I,K,N,Column: Integer; ResourceKey: string;
begin
 if FDoc=nil then Exit; ResourceKey:=''; if FRecurso.ItemIndex>=0 then ResourceKey:=FResourceKeys[FRecurso.ItemIndex]; Tasks:=PLTarefasTOdo(FDoc,CurrentSprint,ResourceKey);
 for I:=0 to 2 do begin FBoards[I].Clear; SetLength(FIndices[I],0); end;
 for I:=0 to High(Tasks) do begin K:=Tasks[I]; Column:=Ord(FDoc[K].Situacao); N:=Length(FIndices[Column]); SetLength(FIndices[Column],N+1); FIndices[Column][N]:=K; FBoards[Column].Items.Add(FDoc[K].ID); if FDoc[K].ID=FSelectedID then FBoards[Column].ItemIndex:=N; end;
 for I:=0 to 2 do FHeaders[I].Caption:=PL_SITUACAO_NOME[TPLSituacao(I)]+' ('+IntToStr(Length(FIndices[I]))+')';
 FPlot.Invalidate;
end;
procedure TPLSprintPanel.FilterChanged(Sender: TObject);
begin if not FLoading then begin FSelectedID:=''; RefreshBoard; end; end;
procedure TPLSprintPanel.Changed;
begin if Assigned(OnChanged) then OnChanged(Self) else Setup(FDoc,FCrono); end;
procedure TPLSprintPanel.NewSprint(Sender: TObject);
var Start,Finish: TDateTime; NewName: string; S: TPLSprint;
begin
 if FDoc=nil then Exit; Start:=PLSegundaFeira(Date); if FDoc.Sprints.Count>0 then Start:=FDoc.Sprints[FDoc.Sprints.Count-1].Fim+1;
 if not EditSprintDialog(TForm(GetParentForm(Self)),'Sprint '+IntToStr(FDoc.Sprints.Count+1),Start,Start+13,NewName,Start,Finish) then Exit;
 try S:=FDoc.NovaSprint(NewName,Start,Finish); PLAtualizarSprint(FDoc,FCrono,S); FPendingSprint:=S.ID; Changed;
 except on E: Exception do ShowMessage(E.Message); end;
end;
procedure TPLSprintPanel.EditSprint(Sender: TObject);
var S: TPLSprint; Start,Finish: TDateTime; NewName: string; I: Integer;
begin
 S:=CurrentSprint; if S=nil then begin ShowMessage('Selecione uma sprint'); Exit; end;
 if not EditSprintDialog(TForm(GetParentForm(Self)),S.Nome,S.Inicio,S.Fim,NewName,Start,Finish) then Exit;
 try
  for I:=0 to FDoc.Sprints.Count-1 do if (FDoc.Sprints[I]<>S) and (FDoc.Sprints[I].Inicio=Start) and (FDoc.Sprints[I].Fim=Finish) then raise Exception.Create('Já existe uma sprint neste período');
  if (S.Inicio<>Start) or (S.Fim<>Finish) then SetLength(S.Items,0);
  S.Nome:=NewName; S.Inicio:=Start; S.Fim:=Finish; PLAtualizarSprint(FDoc,FCrono,S); FDoc.MarcarModificado; Changed;
 except on E: Exception do ShowMessage(E.Message); end;
end;
procedure TPLSprintPanel.ReportSprint(Sender: TObject);
var Key: string;
begin Key:=''; if FRecurso.ItemIndex>=0 then Key:=FResourceKeys[FRecurso.ItemIndex]; try PLMostrarRelatorioSprint(TForm(GetParentForm(Self)),FDoc,FCrono,CurrentSprint,Key,OnChanged); except on E: Exception do ShowMessage(E.Message); end; end;
procedure TPLSprintPanel.RecordTaskHours(Sender: TObject);
begin if FSelectedID='' then begin ShowMessage('Selecione um cartão para apontar horas'); Exit; end; if PLEditarHoras(TForm(GetParentForm(Self)),FDoc,FSelectedID,Date) then begin if not Assigned(OnChanged) then begin FCrono.Calcular(FDoc); PLAtualizarSprints(FDoc,FCrono); end; Changed; end; end;

procedure TPLSprintPanel.DeleteSprint(Sender: TObject);
var S: TPLSprint; I: Integer;
begin
 S:=CurrentSprint; if S=nil then Exit;
 if MessageDlg('Excluir sprint','Excluir somente o agrupamento? As tarefas serão preservadas.',mtConfirmation,[mbYes,mbNo],0)<>mrYes then Exit;
 for I:=0 to FDoc.Sprints.Count-1 do if FDoc.Sprints[I]=S then begin FDoc.Sprints.Delete(I); Break; end; FDoc.MarcarModificado; Changed;
end;
procedure TPLSprintPanel.UpdateSprint(Sender: TObject);
begin PLAtualizarSprints(FDoc,FCrono); Changed; end;
procedure TPLSprintPanel.Selection(Sender: TObject);
var B: TListBox; K: Integer;
begin B:=TListBox(Sender); if B.ItemIndex<0 then Exit; K:=FIndices[B.Tag][B.ItemIndex]; FSelectedID:=FDoc[K].ID; SelectedTask:=K; end;
procedure TPLSprintPanel.OpenTask(Sender: TObject);
begin Selection(Sender); if (FSelectedID<>'') and Assigned(OnOpenTask) then OnOpenTask(Self); end;
procedure TPLSprintPanel.StatusClick(Sender: TObject);
var I: Integer;
begin I:=FDoc.IndiceDe(FSelectedID); if I<0 then begin ShowMessage('Selecione um cartão da tarefa'); Exit; end; PLAlterarStatus(FDoc,FDoc[I],TPLSituacao(TControl(Sender).Tag)); Changed; end;
procedure TPLSprintPanel.DrawCard(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var B: TListBox; T: TPLTarefa; S: TPLSprint; I,K: Integer; Carry: Boolean; Dates,Executor: string; R: TRect;
begin
 B:=TListBox(Control); if (Index<0) or (Index>=Length(FIndices[B.Tag])) then Exit; K:=FIndices[B.Tag][Index]; T:=FDoc[K]; S:=CurrentSprint; Carry:=False;
 if S<>nil then for I:=0 to High(S.Items) do if S.Items[I].TaskID=T.ID then Carry:=S.Items[I].PendenteAnterior;
 with B.Canvas do begin
  Brush.Color:=clWhite; if T.Situacao=plsConcluida then Brush.Color:=RGBToColor(220,252,231) else if Carry then Brush.Color:=RGBToColor(254,242,242);
  if odSelected in State then Brush.Color:=RGBToColor(219,234,254); Brush.Style:=bsSolid; FillRect(ARect); Brush.Style:=bsClear; R:=ARect; InflateRect(R,-7,-5); Font.Style:=[fsBold]; Font.Color:=RGBToColor(30,64,145); TextRect(R,R.Left,R.Top,T.ID+' | '+T.Nome); Font.Style:=[]; Font.Color:=RGBToColor(51,65,85);
  Dates:=''; if FCrono.Valido then Dates:=FormatDateTime('dd/mm/yyyy',FCrono.Resultado[K].Start)+' a '+FormatDateTime('dd/mm/yyyy',FCrono.Resultado[K].Finish);
  Executor:=T.ExecutorNome; if Executor='' then Executor:=T.Responsavel;
  TextRect(R,R.Left,R.Top+23,Executor); TextRect(R,R.Left,R.Top+43,Dates);
  if Carry then begin Font.Color:=RGBToColor(185,28,28); if T.Situacao=plsConcluida then Font.Color:=RGBToColor(100,116,139); TextRect(R,R.Left,R.Top+63,'Origem: pendência anterior'); end; Brush.Style:=bsSolid;
 end;
end;
procedure TPLSprintPanel.PaintStats(Sender: TObject);
const StatusColors: array[0..2] of TColor=($00D19F3B,$000B9EF5,$0081B910);
var I,Total,X,W: Integer;
begin
 with FPlot.Canvas do begin Brush.Color:=RGBToColor(248,250,252); FillRect(FPlot.ClientRect); Font.Color:=RGBToColor(15,23,42); Font.Style:=[fsBold]; TextOut(12,6,'TO-DO — tarefas por situação, sprint e recurso'); Font.Style:=[];
  Total:=0; for I:=0 to 2 do Inc(Total,Length(FIndices[I])); X:=12;
  for I:=0 to 2 do begin W:=0; if Total>0 then W:=Round((FPlot.Width-24)*Length(FIndices[I])/Total); Brush.Color:=StatusColors[I]; FillRect(Rect(X,36,X+W,52)); Inc(X,W); end;
  TextOut(12,22,IntToStr(Total)+' tarefa(s). Selecione um cartão para mudar a situação; duplo clique abre os detalhes.');
 end;
end;
constructor TPLCustosPanel.Create(AOwner: TComponent);
var Toolbar: TFlowPanel; B: TButton;
begin
 inherited Create(AOwner); BevelOuter:=bvNone;
 Toolbar:=TFlowPanel.Create(Self); Toolbar.Parent:=Self; Toolbar.Align:=alTop; Toolbar.Top:=0; Toolbar.AutoSize:=True; Toolbar.AutoWrap:=True; Toolbar.BevelOuter:=bvNone;
 FData:=TDateEdit.Create(Self); FData.Parent:=Toolbar; FData.SetBounds(0,0,130,28); FData.BorderSpacing.Around:=4; FData.DateOrder:=doDMY; FData.Date:=Date; FData.Hint:='Data da apuração de custos'; FData.ShowHint:=True;
 B:=ButtonAt(Toolbar,'Registrar apuração',0,0,156,@RecordClick); B.BorderSpacing.Around:=4;
 B:=ButtonAt(Toolbar,'Orçamento previsto',0,0,164,@BudgetClick); B.BorderSpacing.Around:=4;
 B:=ButtonAt(Toolbar,'Exportar CSV',0,0,124,@ExportCSV); B.BorderSpacing.Around:=4;
 B:=ButtonAt(Toolbar,'Relatório HTML',0,0,140,@ExportHTML); B.BorderSpacing.Around:=4;
 FSummary:=TLabel.Create(Self); FSummary.Parent:=Self; FSummary.Align:=alTop; FSummary.Top:=1000; FSummary.Height:=42; FSummary.AutoSize:=False; FSummary.WordWrap:=True; FSummary.Font.Style:=[fsBold];
 FHint:=TLabel.Create(Self); FHint.Parent:=Self; FHint.Align:=alTop; FHint.Top:=2000; FHint.AutoSize:=False; FHint.Height:=42; FHint.WordWrap:=True; FHint.Caption:='Histórico semanal (segunda a domingo), preservado no projeto. Primeira semana = base inicial. Semanas sem nova apuração mantêm os últimos valores; não há reconstrução de custos anteriores ao primeiro registro.';
 FChart:=TPaintBox.Create(Self); FChart.Parent:=Self; FChart.Align:=alTop; FChart.Top:=3000; FChart.Height:=220; FChart.OnPaint:=@PaintChart;
 FGrid:=TStringGrid.Create(Self); FGrid.Parent:=Self; FGrid.Align:=alClient; FGrid.FixedCols:=0; FGrid.FixedRows:=1; FGrid.ColCount:=9; FGrid.RowCount:=2; FGrid.Options:=[goColSizing,goVertLine,goHorzLine,goRowSelect]; FGrid.DefaultRowHeight:=28;
 FGrid.Cells[0,0]:='Semana'; FGrid.Cells[1,0]:='Previsto'; FGrid.Cells[2,0]:='Computado'; FGrid.Cells[3,0]:='Desvio'; FGrid.Cells[4,0]:='Δ previsto'; FGrid.Cells[5,0]:='Δ computado'; FGrid.Cells[6,0]:='Δ computado %'; FGrid.Cells[7,0]:='Até'; FGrid.Cells[8,0]:='Observação';
 FGrid.ColWidths[0]:=108; FGrid.ColWidths[1]:=140; FGrid.ColWidths[2]:=140; FGrid.ColWidths[3]:=140; FGrid.ColWidths[4]:=140; FGrid.ColWidths[5]:=140; FGrid.ColWidths[6]:=124; FGrid.ColWidths[7]:=108; FGrid.ColWidths[8]:=270; OnResize:=@ResizeReport;
end;
procedure TPLCustosPanel.ResizeReport(Sender: TObject);
begin
 if FChart<>nil then FChart.Height:=Max(100,Min(220,ClientHeight div 3));
 if FSummary<>nil then if ClientWidth<700 then FSummary.Height:=64 else FSummary.Height:=42;
 if FHint<>nil then if ClientWidth<700 then FHint.Height:=64 else FHint.Height:=42;
end;
procedure TPLCustosPanel.Setup(Doc: TPLProjeto);
var I,J: Integer;
begin
 FDoc:=Doc; FWeeks:=PLCustosPorSemana(Doc); FGrid.RowCount:=Max(2,Length(FWeeks)+1); for J:=0 to 8 do FGrid.Cells[J,1]:='';
 FSummary.Caption:='Custo previsto: '+EAMoneyText(Doc.CustoPrevistoProjeto)+' | Custo computado: '+EAMoneyText(Doc.CustoComputadoProjeto)+' | Desvio: '+EAMoneyText(Doc.CustoComputadoProjeto-Doc.CustoPrevistoProjeto);
 if Doc.OrcamentoFixado then FSummary.Caption:=FSummary.Caption+' | Orçamento fixado' else FSummary.Caption:=FSummary.Caption+' | Previsão automática';
 FSummary.Font.Color:=RGBToColor(30,64,145); if Doc.CustoComputadoProjeto>Doc.CustoPrevistoProjeto then FSummary.Font.Color:=RGBToColor(185,28,28);
 for I:=0 to High(FWeeks) do begin
  FGrid.Cells[0,I+1]:=FormatDateTime('dd/mm/yyyy',FWeeks[I].Inicio); FGrid.Cells[7,I+1]:=FormatDateTime('dd/mm/yyyy',FWeeks[I].Fim); FGrid.Cells[1,I+1]:=EAMoneyText(FWeeks[I].Previsto); FGrid.Cells[2,I+1]:=EAMoneyText(FWeeks[I].Computado); FGrid.Cells[3,I+1]:=EAMoneyText(FWeeks[I].Desvio);
  FGrid.Cells[4,I+1]:='—'; FGrid.Cells[5,I+1]:='—'; FGrid.Cells[6,I+1]:='—'; FGrid.Cells[8,I+1]:='Base inicial';
  if FWeeks[I].TemAnterior then begin FGrid.Cells[4,I+1]:=EAMoneyText(FWeeks[I].DeltaPrevisto); FGrid.Cells[5,I+1]:=EAMoneyText(FWeeks[I].DeltaComputado); FGrid.Cells[8,I+1]:=''; if FWeeks[I-1].Computado<>0 then FGrid.Cells[6,I+1]:=FormatFloat('0.00',FWeeks[I].DeltaComputado*100.0/FWeeks[I-1].Computado)+'%'; end;
  if not FWeeks[I].TemApuracao then FGrid.Cells[8,I+1]:='Sem nova apuração; valores mantidos';
 end;
 FChart.Invalidate;
end;
procedure TPLCustosPanel.PaintChart(Sender: TObject);
var I,J,X,Y,PrevX,PrevY,W,H,Tick: Integer; MaxCost,Value: Int64;
begin
 W:=FChart.Width; H:=FChart.Height; if (W<160) or (H<80) then Exit;
 with FChart.Canvas do begin
  Brush.Color:=RGBToColor(248,250,252); FillRect(FChart.ClientRect); Font.Color:=RGBToColor(51,65,85); TextOut(12,5,'Evolução semanal — previsto (azul) e computado (laranja)');
  if Length(FWeeks)=0 then begin TextOut(12,48,'Registre a primeira apuração para iniciar o histórico.'); Exit; end;
  MaxCost:=1; for I:=0 to High(FWeeks) do MaxCost:=Max(MaxCost,Max(FWeeks[I].Previsto,FWeeks[I].Computado));
  Pen.Color:=RGBToColor(148,163,184); MoveTo(70,35); LineTo(70,H-35); LineTo(W-20,H-35); TextOut(72,22,EAMoneyText(MaxCost)); Tick:=Max(1,Length(FWeeks) div Max(1,W div 120));
  for J:=0 to 1 do begin
   PrevX:=0; PrevY:=0;
   Pen.Width:=3; if J=0 then Pen.Color:=RGBToColor(30,64,145) else Pen.Color:=RGBToColor(234,88,12);
   for I:=0 to High(FWeeks) do begin
    X:=70; if Length(FWeeks)>1 then X:=70+Round((W-100)*I/(Length(FWeeks)-1)); Value:=FWeeks[I].Previsto; if J=1 then Value:=FWeeks[I].Computado; Y:=H-35-Round((H-80)*Value/MaxCost);
    if I=0 then MoveTo(X,Y) else begin MoveTo(PrevX,PrevY); LineTo(X,Y); end;
    if Length(FWeeks)=1 then begin Brush.Color:=Pen.Color; Ellipse(X-3,Y-3,X+3,Y+3); end;
    PrevX:=X; PrevY:=Y;
    if (J=1) and ((I mod Tick=0) or (I=High(FWeeks))) then TextOut(Max(0,X-25),H-27,FormatDateTime('dd/mm/yy',FWeeks[I].Inicio));
   end;
  end; Pen.Width:=1;
 end;
end;
procedure TPLCustosPanel.RecordClick(Sender: TObject);
begin try FDoc.RegistrarCustos(FData.Date); if Assigned(OnChanged) then OnChanged(Self) else Setup(FDoc); except on E: Exception do ShowMessage(E.Message); end; end;
procedure TPLCustosPanel.BudgetClick(Sender: TObject);
var F: TForm; Fixed: TCheckBox; Value: TEdit; B: TButton;
begin
 F:=TForm.CreateNew(GetParentForm(Self));
 try
  F.Caption:='Custo previsto do projeto'; F.SetBounds(0,0,510,228); F.Position:=poScreenCenter; F.BorderStyle:=bsDialog;
  Fixed:=TCheckBox.Create(F); Fixed.Parent:=F; Fixed.SetBounds(18,18,470,28); Fixed.Caption:='Fixar orçamento previsto para comparar com o computado'; Fixed.Checked:=FDoc.OrcamentoFixado;
  LabelAt(F,'Valor previsto (R$)',18,60,460); Value:=TEdit.Create(F); Value.Parent:=F; Value.SetBounds(18,86,470,28); Value.Text:=EAMoneyText(FDoc.CustoPrevistoProjeto);
  LabelAt(F,'Desmarcado: previsão acompanha a composição das tarefas.',18,126,470);
  B:=ButtonAt(F,'Confirmar',252,164,112,nil); B.ModalResult:=mrOK; B.Default:=True; B:=ButtonAt(F,'Cancelar',378,164,112,nil); B.ModalResult:=mrCancel; B.Cancel:=True;
  while F.ShowModal=mrOK do begin
   try if Fixed.Checked then FDoc.OrcamentoCentavos:=EAMoneyParse(Value.Text,9000000000000000); FDoc.OrcamentoFixado:=Fixed.Checked; FDoc.MarcarModificado; if Assigned(OnChanged) then OnChanged(Self) else Setup(FDoc); Break;
   except on E: Exception do ShowMessage(E.Message); end;
  end;
 finally F.Free; end;
end;
procedure TPLCustosPanel.ExportCSV(Sender: TObject);
var D: TSaveDialog;
begin D:=TSaveDialog.Create(Self); try D.Filter:='CSV (*.csv)|*.csv'; D.DefaultExt:='csv'; D.FileName:='custos_semanais.csv'; D.Options:=D.Options+[ofOverwritePrompt]; if D.Execute then PLExportarCustosCSV(FDoc,FWeeks,D.FileName); finally D.Free; end; end;
procedure TPLCustosPanel.ExportHTML(Sender: TObject);
var D: TSaveDialog;
begin D:=TSaveDialog.Create(Self); try D.Filter:='Relatório HTML (*.html)|*.html'; D.DefaultExt:='html'; D.FileName:='relatorio_custos_semanais.html'; D.Options:=D.Options+[ofOverwritePrompt]; if D.Execute then PLExportarCustosHTML(FDoc,FWeeks,D.FileName); finally D.Free; end; end;
end.
