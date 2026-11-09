program test_relatorios_sprint_ui;
{$mode objfpc}{$H+}{$codepage utf8}
uses Windows,Interfaces,Forms,Classes,SysUtils,Controls,StdCtrls,ExtCtrls,Grids,ComCtrls,
 plan_documento,plan_cronograma,plan_tipos,plan_recursos,plan_sprints,plan_acompanhamento,plan_relatorios_sprint_ui;
var P: TPLProjeto; C: TPLCronograma; A,B: TPLTarefa; Ana,Bruno: TPLRecurso; S: TPLSprint; F: TForm; Filter: TComboBox; Pending,Users,Hours,AllTasks: TStringGrid;
 I,Checks,Failures: Integer; Day: TDateTime; ID: string;
procedure Check(Value: Boolean; const Text: string);
begin Inc(Checks); if not Value then begin Inc(Failures); WriteLn('FALHA ',Text); end; end;
function Person(const Name,UID: string): TPLRecurso;
begin Result:=P.NovoRecurso; Result.Nome:=Name; Result.Tipo:=prtPessoa; Result.UsuarioID:=UID; P.AdicionarRecurso(Result); end;
function FindButton(Root: TWinControl; const CaptionText: string): TButton;
var I: Integer;
begin Result:=nil; for I:=0 to Root.ControlCount-1 do begin
 if (Root.Controls[I] is TButton) and (TButton(Root.Controls[I]).Caption=CaptionText) then Exit(TButton(Root.Controls[I]));
 if Root.Controls[I] is TWinControl then begin Result:=FindButton(TWinControl(Root.Controls[I]),CaptionText); if Result<>nil then Exit; end;
end; end;
procedure CheckFlow(Root: TWinControl);
var I: Integer;
begin
 if Root is TFlowPanel then for I:=0 to Root.ControlCount-1 do Check((Root.Controls[I].Left+Root.Controls[I].Width<=Root.ClientWidth) and (Root.Controls[I].Top+Root.Controls[I].Height<=Root.ClientHeight),'ação do relatório cabe na barra');
 for I:=0 to Root.ControlCount-1 do if Root.Controls[I] is TWinControl then CheckFlow(TWinControl(Root.Controls[I]));
end;
begin
 RequireDerivedFormResource:=False; Application.Initialize; Checks:=0; P:=TPLProjeto.Create; C:=TPLCronograma.Create; F:=nil;
 try
  Day:=EncodeDate(2026,11,9); P.Novo('Teste de relatório',Day); P.Calendario.Clear; P.Calendario.SetStandard;
  Ana:=Person('Ana','ana'); Bruno:=Person('Bruno','bruno');
  A:=P.NovaTarefa('Pendente'); A.ExecutorID:='ana'; A.ExecutorNome:='Ana'; A.Progresso:=50;
  B:=P.NovaTarefa('Concluída'); B.ExecutorID:='bruno'; B.ExecutorNome:='Bruno'; PLAlterarStatus(P,B,plsConcluida);
  C.Calcular(P); S:=P.NovaSprint('Sprint teste',Day,Day+6); PLAtualizarSprint(P,C,S);
  ID:=P.SalvarApontamento('',A.ID,Ana.ID,Day,60,'Primeira atividade'); P.SalvarApontamento('',B.ID,Bruno.ID,Day+1,120,'Segunda atividade');
  F:=PLCriarRelatorioSprint(nil,P,C,S,''); F.Width:=780; F.Show; Application.ProcessMessages; Filter:=nil; Pending:=nil; Users:=nil; Hours:=nil; AllTasks:=nil;
  for I:=0 to F.ComponentCount-1 do begin
   if F.Components[I] is TComboBox then Filter:=TComboBox(F.Components[I]);
   if F.Components[I] is TStringGrid then begin
    if TStringGrid(F.Components[I]).Cells[0,0]='Data' then Hours:=TStringGrid(F.Components[I]);
    if TStringGrid(F.Components[I]).Cells[0,0]='Usuário' then Users:=TStringGrid(F.Components[I]);
    if (TStringGrid(F.Components[I]).Cells[0,0]='ID') and (TStringGrid(F.Components[I]).ColCount=10) then Pending:=TStringGrid(F.Components[I]);
    if (TStringGrid(F.Components[I]).Cells[0,0]='ID') and (TStringGrid(F.Components[I]).ColCount=9) then AllTasks:=TStringGrid(F.Components[I]);
   end;
  end;
  Check(Pending<>nil,'aba de pendências disponível'); Check(Users<>nil,'aba de carga por usuário disponível'); Check(Hours<>nil,'aba de horas disponível'); Check(AllTasks<>nil,'escopo completo disponível'); Check(Filter<>nil,'filtro por usuário/recurso disponível');
  Check((Pending.RowCount=2) and (Pending.Cells[1,1]='Pendente'),'somente a tarefa pendente é listada'); Check(Users.RowCount=3,'usuários recebem linhas próprias'); Check(Hours.RowCount=3,'apontamentos recebem linhas próprias'); Check(AllTasks.RowCount=3,'escopo inclui concluídas');
  Filter.ItemIndex:=1; Filter.OnChange(Filter); Check((Users.RowCount=2) and (Users.Cells[0,1]='Ana'),'filtro não mantém dados do outro usuário'); Check(Hours.RowCount=2,'horas seguem filtro de usuário'); Check(Pending.Cells[1,1]='Pendente','pendências seguem filtro');
  Filter.ItemIndex:=2; Filter.OnChange(Filter); Check(Pending.Cells[0,1]='','filtro com apenas concluída não mantém pendência anterior'); Check((Users.RowCount=2) and (Users.Cells[0,1]='Bruno'),'trocar usuário atualiza a carga'); Check(AllTasks.Cells[1,1]='Concluída','concluída continua identificável');
  P.SalvarApontamento(ID,A.ID,Ana.ID,Day,120,'Corrigido'); Filter.ItemIndex:=1; Filter.OnChange(Filter); Check(Hours.Cells[4,1]='2,00','edição atualiza horas sem duplicar a linha');
  Check(FindButton(F,'Relatório HTML')<>nil,'exportação HTML disponível'); Check(FindButton(F,'Pendências CSV')<>nil,'exportação de pendências disponível'); Check(FindButton(F,'Carga por usuário CSV')<>nil,'exportação de carga disponível'); Check(FindButton(F,'Horas apontadas CSV')<>nil,'exportação de horas disponível');
  Check(Assigned(FindButton(F,'Apontar horas').OnClick),'apontar horas conectado'); Check(Assigned(FindButton(F,'Editar apontamento').OnClick),'editar apontamento conectado'); Check(Assigned(FindButton(F,'Remover apontamento').OnClick),'remoção explícita conectada'); CheckFlow(F);
  WriteLn(Checks,' verificacoes da interface de relatorios de sprint, ',Failures,' falhas');
 finally F.Free; C.Free; P.Free; end;
 if Failures>0 then Halt(1);
end.
