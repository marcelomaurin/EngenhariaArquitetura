program test_recursos_ui;
{$mode objfpc}{$H+}{$codepage utf8}
uses Windows, Interfaces, Forms, Classes, SysUtils, Controls, StdCtrls, Buttons, ExtCtrls, Menus, Grids, fpjson,
 plan_principal, plan_recursos_ui, plan_documento, plan_tipos, plan_recursos, plan_cronograma, airesourceview;
var P: TPLProjeto; C: TPLCronograma; A,B: TPLTarefa; R: TPLRecurso; Alloc: TPLAlocacoes;
 Host: TForm; Main: TPLJanelaPrincipal; Panel: TPLRecursosPanel; View: TAIResourceView; Grid: TStringGrid;
 Step: TSpeedButton; ResourceButton,CostButton: TButton; I,Checks: Integer; G: TGUID; Config: string; Found: Boolean;
procedure Check(Value: Boolean; const S: string);
begin Inc(Checks); if not Value then raise Exception.Create(S); end;
begin
 RequireDerivedFormResource:=False; Application.Initialize; Checks:=0; CreateGUID(G); Config:=GetTempDir(False)+'ea-resource-ui-'+GUIDToString(G)+'.json'; Windows.SetEnvironmentVariableW('EA_CONFIG_FILE',PWideChar(UTF8Decode(Config)));
 P:=TPLProjeto.Create; C:=TPLCronograma.Create; Application.CreateForm(TForm,Host); Main:=nil;
 try
  P.Novo('Carga de equipe',EncodeDate(2026,11,9)); P.Calendario.Clear; P.Calendario.SetStandard;
  A:=P.NovaTarefa('Projeto UBS'); B:=P.NovaTarefa('Projeto hospitalar'); R:=P.NovoRecurso; R.Nome:='Equipe de arquitetura'; R.Tipo:=prtEquipe; P.AdicionarRecurso(R);
  SetLength(Alloc,1); Alloc[0].RecursoID:=R.ID; Alloc[0].Unidades:=0.75; Alloc[0].Direcao:=prdUso;
  P.DefinirAlocacoes(A,Alloc); P.DefinirAlocacoes(B,Alloc); C.Calcular(P);
  Panel:=TPLRecursosPanel.Create(Host); Panel.Parent:=Host; Panel.Align:=alClient; Host.SetBounds(0,0,1100,700); Panel.Setup(P,C,nil);
  View:=nil; Grid:=nil;
  for I:=0 to Panel.ComponentCount-1 do begin if Panel.Components[I] is TAIResourceView then View:=TAIResourceView(Panel.Components[I]); if Panel.Components[I] is TStringGrid then Grid:=TStringGrid(Panel.Components[I]); end;
  Check(View<>nil,'visão de carga CHATGPT integrada'); Check(Grid<>nil,'cadastro de recursos disponível');
  Check(View.RowCount=1,'uma linha por recurso'); Check(View.BarCount=2,'uma barra por alocação'); Check(View.OverloadBandCount>0,'faixa de sobrecarga visível'); Check(View.Row(0).Overallocated,'nome do recurso sinaliza sobrecarga'); Check(Assigned(View.OnBarDblClick),'barra permite navegar para tarefa');
  Check(Grid.Cells[4,1]='SOBRECARGA','tabela sinaliza recurso sobrecarregado');
  if Pos('recursos_preview',LowerCase(ExtractFileName(ParamStr(0))))>0 then begin
    Host.Caption:='Prévia de Recursos — dados de teste'; Host.Position:=poScreenCenter; Host.Show;
    while Host.Visible do begin Application.ProcessMessages; Sleep(10); end;
    Exit;
  end;
  B.InicioSolicitado:=P.Inicio+1; C.Calcular(P); Panel.Setup(P,C,nil); Check(View.OverloadBandCount=0,'alterar data remove sinalização de sobrecarga');
  Main:=TPLJanelaPrincipal.Create(nil); Step:=nil; ResourceButton:=nil; CostButton:=nil;
  for I:=0 to Main.ComponentCount-1 do begin
   if (Main.Components[I] is TSpeedButton) and (Pos('4  Recursos',TSpeedButton(Main.Components[I]).Caption)>0) then Step:=TSpeedButton(Main.Components[I]);
   if (Main.Components[I] is TButton) and (TButton(Main.Components[I]).Caption='Recursos / arquivos de entrada e saída') then ResourceButton:=TButton(Main.Components[I]);
   if (Main.Components[I] is TButton) and (TButton(Main.Components[I]).Caption='Compor custos da tarefa') then CostButton:=TButton(Main.Components[I]);
  end;
  Check(Step<>nil,'etapa Recursos localizada'); Check(Step.Enabled,'etapa Recursos habilitada'); Step.Click; Found:=False;
  for I:=0 to Main.ComponentCount-1 do if Main.Components[I] is TPLRecursosPanel then Found:=TPLRecursosPanel(Main.Components[I]).Visible;
  Check(Found,'etapa Recursos abre painel próprio'); Check(ResourceButton<>nil,'recursos e arquivos acessíveis nos detalhes da tarefa'); Check(CostButton<>nil,'custos acessíveis nos detalhes da tarefa');
  Check(Assigned(ResourceButton.OnClick) and Assigned(CostButton.OnClick),'ações da tarefa conectadas');
  WriteLn(Checks,' verificacoes da interface de recursos e custos, 0 falhas');
 finally Main.Free; Host.Free; C.Free; P.Free; DeleteFile(Config); DeleteFile(Config+'.lock'); end;
end.
