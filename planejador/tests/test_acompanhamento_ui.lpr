program test_acompanhamento_ui;
{$mode objfpc}{$H+}{$codepage utf8}
uses Windows,Interfaces,Forms,Classes,SysUtils,Controls,StdCtrls,Buttons,ExtCtrls,Grids,
 plan_principal,plan_acompanhamento_ui,plan_acompanhamento,plan_documento,plan_tipos,plan_recursos,plan_sprints,plan_cronograma;
var P: TPLProjeto; C: TPLCronograma; A,B: TPLTarefa; R: TPLRecurso; S: TPLSprint;
 Host: TForm; Main: TPLJanelaPrincipal; Todo: TPLSprintPanel; Report: TPLCustosPanel;
 SprintBox,ResourceBox: TComboBox; Boards: array[0..2] of TListBox; Grid: TStringGrid;
 Control: TControl; I,J,Checks,Failures: Integer; G: TGUID; Config: string; Step6,Step7: TSpeedButton; Found: Boolean;
procedure Check(Value: Boolean; const S: string);
begin Inc(Checks); if not Value then begin Inc(Failures); WriteLn('FALHA ',Checks,' ',S); end else WriteLn('ok ',Checks,' ',S); Flush(Output); end;
function FindCaption(Root: TWinControl; const CaptionText: string): TControl;
var I: Integer;
begin
 Result:=nil;
 for I:=0 to Root.ControlCount-1 do begin
  if (Root.Controls[I] is TButton) and (TButton(Root.Controls[I]).Caption=CaptionText) then Exit(Root.Controls[I]);
  if Root.Controls[I] is TWinControl then begin Result:=FindCaption(TWinControl(Root.Controls[I]),CaptionText); if Result<>nil then Exit; end;
 end;
end;
procedure CheckFlow(Root: TWinControl);
var I: Integer;
begin
 if Root is TFlowPanel then begin
  Check(Root.ClientWidth>0,'barra tem largura útil');
  for I:=0 to Root.ControlCount-1 do begin Check((Root.Controls[I].Left+Root.Controls[I].Width<=Root.ClientWidth) and (Root.Controls[I].Top+Root.Controls[I].Height<=Root.ClientHeight),'controle da barra cabe na janela sem cortes'); end;
 end;
 for I:=0 to Root.ControlCount-1 do if Root.Controls[I] is TWinControl then CheckFlow(TWinControl(Root.Controls[I]));
end;
begin
 RequireDerivedFormResource:=False; Application.Initialize; Checks:=0; CreateGUID(G); Config:=GetTempDir(False)+'ea-acomp-ui-'+GUIDToString(G)+'.json'; Windows.SetEnvironmentVariableW('EA_CONFIG_FILE',PWideChar(UTF8Decode(Config)));
 P:=TPLProjeto.Create; C:=TPLCronograma.Create; Host:=TForm.CreateNew(nil); Main:=nil;
 try
  P.Novo('Quadro e custos',EncodeDate(2026,11,9)); P.Calendario.Clear; P.Calendario.SetStandard;
  A:=P.NovaTarefa('Planejamento'); A.ExecutorID:='u1'; A.ExecutorNome:='Usuário de teste'; B:=P.NovaTarefa('Desenho'); PLAlterarStatus(P,B,plsEmAndamento);
  SetLength(A.Custos,1); A.Custos[0].Nome:='Serviço'; A.Custos[0].Quantidade:=1; A.Custos[0].ValorUnitarioCentavos:=10000; A.Custos[0].Contabilizado:=False;
  P.OrcamentoFixado:=True; P.OrcamentoCentavos:=9000; P.RegistrarCustos(EncodeDate(2026,10,5)); A.Custos[0].Contabilizado:=True; P.RegistrarCustos(EncodeDate(2026,10,12));
  C.Calcular(P); S:=P.NovaSprint('Sprint da semana',P.Inicio,P.Inicio+6); PLAtualizarSprint(P,C,S);
  R:=P.NovoRecurso; R.Nome:='Sem alocação'; R.Tipo:=prtEquipamento; P.AdicionarRecurso(R); C.Calcular(P);
  Host.SetBounds(0,0,800,720); Todo:=TPLSprintPanel.Create(Host); Todo.Parent:=Host; Todo.SetBounds(0,0,430,600); Todo.Setup(P,C); Host.Caption:='Teste de interface — dados temporários'; Host.Show; Host.HandleNeeded; Todo.HandleNeeded; Application.ProcessMessages;
  SprintBox:=nil; ResourceBox:=nil;
  for I:=0 to Todo.ComponentCount-1 do begin
   if Todo.Components[I] is TComboBox then begin
    if TComboBox(Todo.Components[I]).Items[0]='Todas as tarefas' then SprintBox:=TComboBox(Todo.Components[I]);
    if TComboBox(Todo.Components[I]).Items[0]='Todos os usuários / recursos' then ResourceBox:=TComboBox(Todo.Components[I]);
   end;
   if Todo.Components[I] is TListBox then Boards[TListBox(Todo.Components[I]).Tag]:=TListBox(Todo.Components[I]);
  end;
  Check(SprintBox<>nil,'seletor de sprint disponível'); Check(ResourceBox<>nil,'filtro por usuário/recurso disponível');
  Check((Boards[0]<>nil) and (Boards[1]<>nil) and (Boards[2]<>nil),'três colunas TO-DO criadas');
  Check((Boards[0].Items.Count=1) and (Boards[1].Items.Count=1) and (Boards[2].Items.Count=0),'tarefas separadas por situação');
  SprintBox.ItemIndex:=1; SprintBox.OnChange(SprintBox); Check(Boards[0].Items.Count=1,'seleção da sprint mantém tarefas do agrupamento');
  ResourceBox.ItemIndex:=ResourceBox.Items.IndexOf('Equipamento | Sem alocação'); ResourceBox.OnChange(ResourceBox);
  Check((Boards[0].Items.Count+Boards[1].Items.Count+Boards[2].Items.Count)=0,'recurso sem tarefa produz quadro vazio');
  ResourceBox.ItemIndex:=0; ResourceBox.OnChange(ResourceBox); Boards[0].ItemIndex:=0; Boards[0].OnClick(Boards[0]);
  Control:=FindCaption(Todo,'Concluída'); Check(Control<>nil,'ação concluir acessível'); TButton(Control).Click;
  Check((A.Situacao=plsConcluida) and (A.Progresso=100),'conclusão pelo quadro altera tarefa e progresso');
  Check((Boards[0].Items.Count=0) and (Boards[2].Items.Count=1),'cartão muda para concluídas'); Check(S.Contem(A.ID),'conclusão mantém cartão na sprint');
  Check(FindCaption(Todo,'Relatório da sprint')<>nil,'relatório associado à sprint acessível');
  Check(FindCaption(Todo,'Apontar horas')<>nil,'horas por tarefa acessíveis no TO-DO');
  CheckFlow(Todo);
  Todo.Visible:=False; Report:=TPLCustosPanel.Create(Host); Report.Parent:=Host; Report.SetBounds(0,0,430,600); Report.Setup(P); Report.HandleNeeded; Application.ProcessMessages;
  Grid:=nil; for I:=0 to Report.ComponentCount-1 do if Report.Components[I] is TStringGrid then Grid:=TStringGrid(Report.Components[I]);
  Check(Grid<>nil,'relatório semanal tem tabela'); Check((Grid.ColCount=9) and (Grid.RowCount>=3),'relatório apresenta comparação e semanas');
  Check(FindCaption(Report,'Registrar apuração')<>nil,'apuração com data disponível'); Check(FindCaption(Report,'Orçamento previsto')<>nil,'orçamento previsto ajustável');
  Check(FindCaption(Report,'Exportar CSV')<>nil,'CSV disponível'); Check(FindCaption(Report,'Relatório HTML')<>nil,'relatório HTML disponível'); CheckFlow(Report);
  Main:=TPLJanelaPrincipal.Create(nil); Step6:=nil; Step7:=nil;
  for I:=0 to Main.ComponentCount-1 do if Main.Components[I] is TSpeedButton then begin
   if Pos('6  TO-DO',TSpeedButton(Main.Components[I]).Caption)>0 then Step6:=TSpeedButton(Main.Components[I]);
   if Pos('7  Custos',TSpeedButton(Main.Components[I]).Caption)>0 then Step7:=TSpeedButton(Main.Components[I]);
  end;
  Check((Step6<>nil) and Step6.Enabled,'etapa TO-DO/sprints habilitada'); Check((Step7<>nil) and Step7.Enabled,'etapa de custos/relatórios habilitada');
  Step6.Click; Found:=False; for I:=0 to Main.ComponentCount-1 do if Main.Components[I] is TPLSprintPanel then Found:=TPLSprintPanel(Main.Components[I]).Visible; Check(Found,'menu abre quadro TO-DO');
  Step7.Click; Found:=False; for I:=0 to Main.ComponentCount-1 do if Main.Components[I] is TPLCustosPanel then Found:=TPLCustosPanel(Main.Components[I]).Visible; Check(Found,'menu abre relatório de custos');
  WriteLn(Checks,' verificacoes da interface TO-DO, sprints e custos semanais, ',Failures,' falhas');
 finally Main.Free; Host.Free; C.Free; P.Free; DeleteFile(Config); DeleteFile(Config+'.lock'); end;
 if Failures>0 then Halt(1);
end.
