unit plan_principal;

{ Planejador - janela principal (etapa P1).
  Tabela de tarefas e Grafico de Gantt com o componente TAIGanttView da
  suite CHATGPT; caminho critico pelo TAICPMScheduler. A janela e montada
  em codigo, no mesmo estilo das demais aplicacoes da plataforma. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, DateUtils, StrUtils, Forms, Controls, Graphics, StdCtrls,
  ExtCtrls, Menus, Dialogs, Buttons, Spin, EditBtn, LCLType,
  aicpmscheduler, aitaskgraph, aiganttview,
  plan_tipos, plan_documento, plan_cronograma, plan_json, plan_exemplos, plan_estilo;

type
  TPLJanelaPrincipal = class(TForm)
  private
    FDoc: TPLProjeto;
    FCrono: TPLCronograma;
    FArquivo: string;
    FAtualizando: Boolean;
    { componentes }
    FCabecalho: TPLCabecalho;
    FGantt: TAIGanttView;
    FStatus, FAviso: TLabel;
    FResumo: TLabel;
    FProjNome: TEdit;
    FProjObjetivo: TMemo;
    FProjInicio: TDateEdit;
    FTarId: TLabel;
    FTarNome, FTarDuracao, FTarPred, FTarResp: TEdit;
    FTarApp, FTarSituacao: TComboBox;
    FTarProgresso: TSpinEdit;
    FTarNotas: TMemo;
    FTarDatas: TLabel;
    FPainelTarefa: TPanel;
    FAbrir: TOpenDialog;
    FSalvar: TSaveDialog;
    procedure MontarMenu;
    procedure MontarBarra;
    procedure MontarPainelProjeto(P: TPanel);
    procedure MontarPainelTarefa(P: TPanel);
    procedure MontarGantt(P: TPanel);
    procedure MontarRodape;
    function Selecionada: TPLTarefa;
    procedure Recalcular(const AManterId: string = '');
    procedure RecalcularAssincrono(Data: PtrInt);
    procedure MostrarTarefa;
    procedure MostrarProjeto;
    procedure AtualizarTitulo;
    procedure Mensagem(const ATexto: string; AErro: Boolean = False);
    function ConfirmarDescartar: Boolean;
    procedure AbrirArquivo(const AArquivo: string);
    function SalvarEm(const AArquivo: string): Boolean;
    { eventos }
    procedure AoNovo(Sender: TObject);
    procedure AoAbrir(Sender: TObject);
    procedure AoAbrirExemplo(Sender: TObject);
    procedure AoSalvar(Sender: TObject);
    procedure AoSalvarComo(Sender: TObject);
    procedure AoSair(Sender: TObject);
    procedure AoNovaTarefa(Sender: TObject);
    procedure AoNovoMarco(Sender: TObject);
    procedure AoExcluir(Sender: TObject);
    procedure AoSubir(Sender: TObject);
    procedure AoDescer(Sender: TObject);
    procedure AoAmpliar(Sender: TObject);
    procedure AoReduzir(Sender: TObject);
    procedure AoAjustar(Sender: TObject);
    procedure AoSobre(Sender: TObject);
    procedure AoSelecionarLinha(Sender: TObject; ARow: Integer);
    procedure AoEditarCelula(Sender: TObject; ARow, ACol: Integer; var AText: string;
      var Accept: Boolean);
    function AoDiaUtil(Sender: TObject; ADay: TDateTime): Boolean;
    procedure AoAlterarProjeto(Sender: TObject);
    procedure AoAplicarTarefa(Sender: TObject);
    procedure AoTecla(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure AoFecharConsulta(Sender: TObject; var CanClose: Boolean);
    procedure AoMostrar(Sender: TObject);
    procedure AjustarAssincrono(Data: PtrInt);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  JanelaPrincipal: TPLJanelaPrincipal;

implementation

const
  COL_ID = 0; COL_NOME = 1; COL_DURACAO = 2; COL_INICIO = 3; COL_TERMINO = 4;
  COL_PRED = 5; COL_APP = 6; COL_FOLGA = 7;
  TITULO = 'Planejador';

function FmtData(D: TDateTime): string;
begin
  if D <= 0 then Result := '' else Result := FormatDateTime('dd"/"mm"/"yyyy', D);
end;

function FmtFolga(Minutos: Int64): string;
begin
  if Minutos = 0 then Exit('0');
  Result := FormatFloat('0.#', Minutos / PL_MINUTOS_POR_DIA) + 'd';
end;

{ ---------------- construcao ---------------- }

constructor TPLJanelaPrincipal.Create(AOwner: TComponent);
var Esq, Dir, Centro: TPanel;
begin
  inherited CreateNew(AOwner, 1);
  FDoc := TPLProjeto.Create;
  FCrono := TPLCronograma.Create;
  Caption := TITULO;
  Width := 1280; Height := 800;
  Constraints.MinWidth := 1000; Constraints.MinHeight := 600;
  Position := poScreenCenter;
  Font.Name := PL_FONTE; Font.Size := 10;
  Color := clPLSuperficie;
  KeyPreview := True;
  OnKeyDown := @AoTecla;
  OnCloseQuery := @AoFecharConsulta;
  OnShow := @AoMostrar;
  ShowHint := True;

  FAbrir := TOpenDialog.Create(Self);
  FAbrir.Filter := 'Projeto do Planejador (*.plan.json)|*.plan.json|Todos os arquivos (*.*)|*.*';
  FAbrir.Title := 'Abrir projeto';
  FSalvar := TSaveDialog.Create(Self);
  FSalvar.Filter := FAbrir.Filter;
  FSalvar.DefaultExt := 'plan.json';
  FSalvar.Title := 'Salvar projeto';
  FSalvar.Options := FSalvar.Options + [ofOverwritePrompt];

  MontarMenu;
  FCabecalho := TPLCabecalho.Create(Self);
  FCabecalho.Parent := Self;
  FCabecalho.Configurar('Planejador', 'Engenharia e Arquitetura  •  tarefas, dependências e cronograma');
  MontarBarra;
  MontarRodape;
  Esq := PLPainel(Self, Self, alLeft, 230, clPLCartao);
  Esq.BorderSpacing.Right := 1;
  MontarPainelProjeto(Esq);
  Dir := PLPainel(Self, Self, alRight, 280, clPLCartao);
  Dir.BorderSpacing.Left := 1;
  MontarPainelTarefa(Dir);
  Centro := PLPainel(Self, Self, alClient, 0, clPLSuperficie);
  MontarGantt(Centro);

  if (ParamCount >= 1) and FileExists(ParamStr(1)) then
    AbrirArquivo(ParamStr(1))
  else
  begin
    FDoc.Novo('Novo projeto', Date);
    MostrarProjeto;
    Recalcular;
  end;
end;

destructor TPLJanelaPrincipal.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  FCrono.Free;
  FDoc.Free;
  inherited Destroy;
end;

procedure TPLJanelaPrincipal.MontarMenu;
var M: TMainMenu; Item: TMenuItem;

  function Add(Pai: TMenuItem; const ATexto: string; AClique: TNotifyEvent;
    AAtalho: TShortCut = 0): TMenuItem;
  begin
    Result := TMenuItem.Create(M);
    Result.Caption := ATexto;
    Result.OnClick := AClique;
    Result.ShortCut := AAtalho;
    Pai.Add(Result);
  end;

begin
  M := TMainMenu.Create(Self);
  Menu := M;
  Item := TMenuItem.Create(M); Item.Caption := '&Arquivo'; M.Items.Add(Item);
  Add(Item, '&Novo projeto', @AoNovo, ShortCut(VK_N, [ssCtrl]));
  Add(Item, '&Abrir...', @AoAbrir, ShortCut(VK_O, [ssCtrl]));
  Add(Item, 'Abrir &exemplo (residência)', @AoAbrirExemplo);
  Add(Item, '-', nil);
  Add(Item, '&Salvar', @AoSalvar, ShortCut(VK_S, [ssCtrl]));
  Add(Item, 'Salvar &como...', @AoSalvarComo, ShortCut(VK_S, [ssCtrl, ssShift]));
  Add(Item, '-', nil);
  Add(Item, 'Sai&r', @AoSair);
  Item := TMenuItem.Create(M); Item.Caption := '&Tarefa'; M.Items.Add(Item);
  Add(Item, '&Nova tarefa', @AoNovaTarefa, ShortCut(VK_INSERT, []));
  Add(Item, 'Novo &marco', @AoNovoMarco, ShortCut(VK_INSERT, [ssShift]));
  Add(Item, '&Excluir tarefa', @AoExcluir, ShortCut(VK_DELETE, [ssCtrl]));
  Add(Item, '-', nil);
  Add(Item, '&Subir', @AoSubir, ShortCut(VK_UP, [ssAlt]));
  Add(Item, '&Descer', @AoDescer, ShortCut(VK_DOWN, [ssAlt]));
  Item := TMenuItem.Create(M); Item.Caption := '&Exibir'; M.Items.Add(Item);
  Add(Item, '&Ampliar escala', @AoAmpliar, ShortCut(VK_ADD, [ssCtrl]));
  Add(Item, '&Reduzir escala', @AoReduzir, ShortCut(VK_SUBTRACT, [ssCtrl]));
  Add(Item, 'A&justar ao projeto', @AoAjustar, ShortCut(VK_0, [ssCtrl]));
  Item := TMenuItem.Create(M); Item.Caption := 'A&juda'; M.Items.Add(Item);
  Add(Item, '&Sobre o Planejador', @AoSobre);
end;

procedure TPLJanelaPrincipal.MontarBarra;
var B: TPanel;
begin
  B := PLPainel(Self, Self, alTop, 42, clPLCartao);
  B.Top := FCabecalho.Top + FCabecalho.Height;
  B.BorderSpacing.Bottom := 1;
  { alLeft empilha da esquerda para a direita na ordem de criacao inversa;
    criamos do ultimo para o primeiro }
  PLBotao(B, 'Ajustar', 'Ajustar a escala ao projeto (Ctrl+0)', @AoAjustar);
  PLBotao(B, 'Reduzir', 'Reduzir a escala de tempo', @AoReduzir);
  PLBotao(B, 'Ampliar', 'Ampliar a escala de tempo', @AoAmpliar);
  PLSeparador(B);
  PLBotao(B, 'Descer', 'Descer a tarefa (Alt+Seta para baixo)', @AoDescer);
  PLBotao(B, 'Subir', 'Subir a tarefa (Alt+Seta para cima)', @AoSubir);
  PLBotao(B, 'Excluir', 'Excluir a tarefa selecionada (Ctrl+Del)', @AoExcluir);
  PLBotao(B, 'Novo marco', 'Inserir marco (Shift+Insert)', @AoNovoMarco);
  PLBotao(B, 'Nova tarefa', 'Inserir tarefa após a selecionada (Insert)', @AoNovaTarefa);
  PLSeparador(B);
  PLBotao(B, 'Salvar', 'Salvar o projeto (Ctrl+S)', @AoSalvar);
  PLBotao(B, 'Abrir', 'Abrir um projeto (Ctrl+O)', @AoAbrir);
  PLBotao(B, 'Novo', 'Novo projeto (Ctrl+N)', @AoNovo);
end;

procedure TPLJanelaPrincipal.MontarPainelProjeto(P: TPanel);
var Y: Integer;

  procedure Ajusta(C: TControl);
  begin
    C.Parent := P; C.Align := alTop; C.Top := Y; Inc(Y);
    C.BorderSpacing.Left := 12; C.BorderSpacing.Right := 12;
  end;

begin
  Y := 0;
  PLRotulo(P, 'PROJETO', True).Top := Y; Inc(Y);
  PLRotulo(P, 'Nome').Top := Y; Inc(Y);
  FProjNome := TEdit.Create(Self);
  Ajusta(FProjNome);
  FProjNome.OnChange := @AoAlterarProjeto;
  PLRotulo(P, 'Início').Top := Y; Inc(Y);
  FProjInicio := TDateEdit.Create(Self);
  Ajusta(FProjInicio);
  FProjInicio.DateOrder := doDMY;
  FProjInicio.OnChange := @AoAlterarProjeto;
  PLRotulo(P, 'Objetivo').Top := Y; Inc(Y);
  FProjObjetivo := TMemo.Create(Self);
  Ajusta(FProjObjetivo);
  FProjObjetivo.Height := 110;
  FProjObjetivo.ScrollBars := ssAutoVertical;
  FProjObjetivo.OnChange := @AoAlterarProjeto;
  PLRotulo(P, 'RESUMO', True).Top := Y; Inc(Y);
  FResumo := PLRotulo(P, '');
  FResumo.Top := Y; Inc(Y);
  FResumo.WordWrap := True;
  FResumo.Font.Color := clPLTexto;
  FResumo.AutoSize := True;
end;

procedure TPLJanelaPrincipal.MontarPainelTarefa(P: TPanel);
var A: TPLAplicativo; S: TPLSituacao; Y: Integer; Bt: TButton;

  function Campo(const ARotulo: string): TEdit;
  begin
    PLRotulo(P, ARotulo).Top := Y; Inc(Y);
    Result := TEdit.Create(Self);
    Result.Parent := P; Result.Align := alTop; Result.Top := Y; Inc(Y);
    Result.BorderSpacing.Left := 12; Result.BorderSpacing.Right := 12;
    Result.OnEditingDone := @AoAplicarTarefa;
  end;

  function Lista(const ARotulo: string): TComboBox;
  begin
    PLRotulo(P, ARotulo).Top := Y; Inc(Y);
    Result := TComboBox.Create(Self);
    Result.Parent := P; Result.Align := alTop; Result.Top := Y; Inc(Y);
    Result.Style := csDropDownList;
    Result.BorderSpacing.Left := 12; Result.BorderSpacing.Right := 12;
    Result.OnChange := @AoAplicarTarefa;
  end;

begin
  FPainelTarefa := P;
  Y := 0;
  PLRotulo(P, 'TAREFA', True).Top := Y; Inc(Y);
  FTarId := PLRotulo(P, '—'); FTarId.Top := Y; Inc(Y);
  FTarId.Font.Color := clPLPrimaria; FTarId.Font.Style := [fsBold];
  FTarNome := Campo('Nome');
  FTarDuracao := Campo('Duração (ex.: 5d, 2sem, 4h; 0d = marco)');
  FTarPred := Campo('Predecessoras (ex.: T-0001; T-0002II+1d)');
  FTarApp := Lista('Aplicativo responsável');
  for A := Low(A) to High(A) do FTarApp.Items.Add(PL_APLICATIVO_NOME[A]);
  FTarResp := Campo('Responsável');
  FTarSituacao := Lista('Situação');
  for S := Low(S) to High(S) do FTarSituacao.Items.Add(PL_SITUACAO_NOME[S]);
  PLRotulo(P, 'Progresso (%)').Top := Y; Inc(Y);
  FTarProgresso := TSpinEdit.Create(Self);
  FTarProgresso.Parent := P; FTarProgresso.Align := alTop; FTarProgresso.Top := Y; Inc(Y);
  FTarProgresso.MinValue := 0; FTarProgresso.MaxValue := 100; FTarProgresso.Increment := 10;
  FTarProgresso.BorderSpacing.Left := 12; FTarProgresso.BorderSpacing.Right := 12;
  FTarProgresso.OnEditingDone := @AoAplicarTarefa;
  PLRotulo(P, 'Notas').Top := Y; Inc(Y);
  FTarNotas := TMemo.Create(Self);
  FTarNotas.Parent := P; FTarNotas.Align := alTop; FTarNotas.Top := Y; Inc(Y);
  FTarNotas.Height := 80; FTarNotas.ScrollBars := ssAutoVertical;
  FTarNotas.BorderSpacing.Left := 12; FTarNotas.BorderSpacing.Right := 12;
  FTarNotas.OnEditingDone := @AoAplicarTarefa;
  FTarDatas := PLRotulo(P, ''); FTarDatas.Top := Y; Inc(Y);
  FTarDatas.WordWrap := True; FTarDatas.AutoSize := True;
  Bt := TButton.Create(Self);
  Bt.Parent := P; Bt.Align := alTop; Bt.Top := Y; Inc(Y);
  Bt.Caption := 'Aplicar alterações';
  Bt.BorderSpacing.Left := 12; Bt.BorderSpacing.Right := 12; Bt.BorderSpacing.Top := 10;
  Bt.OnClick := @AoAplicarTarefa;
end;

procedure TPLJanelaPrincipal.MontarGantt(P: TPanel);
begin
  FGantt := TAIGanttView.Create(Self);
  FGantt.Parent := P;
  FGantt.Align := alClient;
  FGantt.BorderSpacing.Around := 8;
  FGantt.Font.Name := PL_FONTE;
  FGantt.Font.Size := 9;
  FGantt.TableWidth := 600;
  FGantt.RowHeight := 26;
  FGantt.ColorBackground := clPLCartao;
  FGantt.ColorText := clPLTexto;
  FGantt.ColorMuted := clPLSuave;
  FGantt.ColorGrid := clPLBorda;
  FGantt.ColorHeader := clPLSuperficie;
  FGantt.ColorHeaderText := clPLTexto;
  FGantt.ColorBar := clPLPrimaria;
  FGantt.ColorCritical := clPLPerigo;
  FGantt.ColorMilestone := clPLMarinho;
  FGantt.ColorProgress := RGBToColor(30, 58, 138);
  FGantt.ColorSelection := RGBToColor(219, 234, 254);
  FGantt.ColorNonWork := RGBToColor(248, 250, 252);
  FGantt.ColorLink := clPLSuave;
  FGantt.ColorStatusLine := clPLSucesso;
  FGantt.StatusDate := Date;
  FGantt.AddColumn('ID', 66);
  FGantt.AddColumn('Nome da tarefa', 190, True);
  FGantt.AddColumn('Duração', 62, True, taRightJustify);
  FGantt.AddColumn('Início', 78);
  FGantt.AddColumn('Término', 78);
  FGantt.AddColumn('Predecessoras', 100, True);
  FGantt.AddColumn('Aplicativo', 110);
  FGantt.AddColumn('Folga', 48, False, taRightJustify);
  FGantt.OnSelectRow := @AoSelecionarLinha;
  FGantt.OnCellEdited := @AoEditarCelula;
  FGantt.OnIsWorkingDay := @AoDiaUtil;
end;

procedure TPLJanelaPrincipal.MontarRodape;
var R: TPanel;
begin
  R := PLPainel(Self, Self, alBottom, 30, clPLCartao);
  FStatus := TLabel.Create(Self);
  FStatus.Parent := R; FStatus.Align := alLeft;
  FStatus.BorderSpacing.Left := 14; FStatus.Layout := tlCenter;
  FStatus.Font.Color := clPLTexto;
  FAviso := TLabel.Create(Self);
  FAviso.Parent := R; FAviso.Align := alClient;
  FAviso.BorderSpacing.Left := 24; FAviso.Layout := tlCenter;
  FAviso.Font.Color := clPLSuave;
end;

{ ---------------- estado e exibicao ---------------- }

function TPLJanelaPrincipal.Selecionada: TPLTarefa;
var R: Integer;
begin
  R := FGantt.Selected;
  if (R >= 0) and (R < FDoc.Count) then Result := FDoc[R] else Result := nil;
end;

procedure TPLJanelaPrincipal.Mensagem(const ATexto: string; AErro: Boolean);
begin
  FAviso.Caption := ATexto;
  if AErro then FAviso.Font.Color := clPLPerigo else FAviso.Font.Color := clPLSuave;
end;

procedure TPLJanelaPrincipal.AtualizarTitulo;
var N: string;
begin
  if FArquivo = '' then N := 'sem título' else N := ExtractFileName(FArquivo);
  if FDoc.Modificado then N := N + ' *';
  Caption := Format('%s — %s', [TITULO, N]);
end;

procedure TPLJanelaPrincipal.Recalcular(const AManterId: string);
var
  I, J, K, Sel: Integer;
  T: TPLTarefa;
  Row: TAIGanttRow;
  Res: TAICPMResult;
  Lk: TAITaskLink;
  Id: string;
begin
  Id := AManterId;
  if (Id = '') and (Selecionada <> nil) then Id := Selecionada.Id;
  FCrono.Calcular(FDoc);
  FGantt.BeginUpdate;
  try
    FGantt.Clear;
    for I := 0 to FDoc.Count - 1 do
    begin
      T := FDoc[I];
      if FCrono.Valido then Res := FCrono.Resultado[I]
      else FillChar(Res, SizeOf(Res), 0);
      if T.Marco then
        Row := AIGanttRow(T.Id, 0, Res.Start, Res.Start, agbMilestone)
      else
        Row := AIGanttRow(T.Id, 0, Res.Start, Res.Finish, agbTask);
      SetLength(Row.Cells, 8);
      Row.Cells[COL_ID] := T.Id;
      Row.Cells[COL_NOME] := T.Nome;
      Row.Cells[COL_DURACAO] := FDoc.TextoDuracao(T);
      Row.Cells[COL_INICIO] := FmtData(Res.Start);
      Row.Cells[COL_TERMINO] := FmtData(Res.Finish);
      Row.Cells[COL_PRED] := FDoc.TextoPredecessoras(T);
      if T.Aplicativo = plaNenhum then Row.Cells[COL_APP] := ''
      else Row.Cells[COL_APP] := PL_APLICATIVO_NOME[T.Aplicativo];
      if FCrono.Valido then Row.Cells[COL_FOLGA] := FmtFolga(Res.TotalSlack);
      Row.Critical := FCrono.Valido and Res.Critical;
      Row.Progress := T.Progresso;
      Row.Tag := I;
      FGantt.AddRow(Row);
    end;
    if FCrono.Valido then
      for K := 0 to FCrono.Grafo.LinkCount - 1 do
      begin
        Lk := FCrono.Grafo.Links[K];
        I := Lk.FromNode; J := Lk.ToNode;
        FGantt.AddLink(I, J, Ord(Lk.LinkType),
          FCrono.Resultado[I].Critical and FCrono.Resultado[J].Critical);
      end;
  finally
    FGantt.EndUpdate;
  end;
  if FGantt.Origin <= 0 then
  begin
    FGantt.FitToRows;
    if Visible then Application.QueueAsyncCall(@AjustarAssincrono, 0);
  end;
  Sel := FDoc.IndiceDe(Id);
  if (Sel < 0) and (FDoc.Count > 0) then Sel := 0;
  if Sel >= 0 then FGantt.Selected := Sel;
  { rodape e resumo }
  if not FCrono.Valido then
  begin
    FStatus.Caption := 'Cronograma não calculado';
    Mensagem(FCrono.Erro, True);
    FResumo.Caption := '';
  end
  else
  begin
    FStatus.Caption := Format('%d tarefas  •  término %s  •  %d no caminho crítico',
      [FDoc.Count, FmtData(FCrono.Termino), FCrono.Criticas]);
    if FCrono.Avisos.Count > 0 then Mensagem(FCrono.Avisos[0], True)
    else if FAviso.Font.Color <> clPLPerigo then Mensagem('');
    FResumo.Caption := Format('Tarefas: %d'#10'Início: %s'#10'Término: %s'#10 +
      'Duração: %d dias úteis'#10'Caminho crítico: %d tarefas',
      [FDoc.Count, FmtData(FCrono.Inicio), FmtData(FCrono.Termino),
       Round(FDoc.Calendario.WorkingMinutesBetween(FCrono.Inicio, FCrono.Termino) / PL_MINUTOS_POR_DIA),
       FCrono.Criticas]);
  end;
  MostrarTarefa;
  AtualizarTitulo;
end;

procedure TPLJanelaPrincipal.RecalcularAssincrono(Data: PtrInt);
begin
  Recalcular;
end;

procedure TPLJanelaPrincipal.MostrarProjeto;
begin
  FAtualizando := True;
  try
    FProjNome.Text := FDoc.Nome;
    FProjObjetivo.Text := FDoc.Objetivo;
    FProjInicio.Date := FDoc.Inicio;
  finally
    FAtualizando := False;
  end;
end;

procedure TPLJanelaPrincipal.MostrarTarefa;
var T: TPLTarefa; R: TAICPMResult; I: Integer; C: TControl;
begin
  T := Selecionada;
  FAtualizando := True;
  try
    for I := 0 to FPainelTarefa.ControlCount - 1 do
    begin
      C := FPainelTarefa.Controls[I];
      if not (C is TLabel) then C.Enabled := T <> nil;
    end;
    if T = nil then
    begin
      FTarId.Caption := 'Nenhuma tarefa selecionada';
      FTarNome.Text := ''; FTarDuracao.Text := ''; FTarPred.Text := '';
      FTarResp.Text := ''; FTarNotas.Text := ''; FTarApp.ItemIndex := -1;
      FTarSituacao.ItemIndex := -1; FTarProgresso.Value := 0; FTarDatas.Caption := '';
      Exit;
    end;
    if T.Marco then FTarId.Caption := T.Id + '  •  marco' else FTarId.Caption := T.Id;
    FTarNome.Text := T.Nome;
    FTarDuracao.Text := FDoc.TextoDuracao(T);
    FTarPred.Text := FDoc.TextoPredecessoras(T);
    FTarApp.ItemIndex := Ord(T.Aplicativo);
    FTarResp.Text := T.Responsavel;
    FTarSituacao.ItemIndex := Ord(T.Situacao);
    FTarProgresso.Value := T.Progresso;
    FTarNotas.Text := T.Notas;
    if FCrono.Valido then
    begin
      R := FCrono.Resultado[FDoc.IndiceDe(T.Id)];
      FTarDatas.Caption := Format('Início: %s'#10'Término: %s'#10'Folga total: %s%s',
        [FormatDateTime('dd"/"mm"/"yyyy hh":"nn', R.Start), FormatDateTime('dd"/"mm"/"yyyy hh":"nn', R.Finish),
         FmtFolga(R.TotalSlack), IfThen(R.Critical, #10'No caminho crítico', '')]);
    end
    else
      FTarDatas.Caption := '';
  finally
    FAtualizando := False;
  end;
end;

{ ---------------- arquivos ---------------- }

function TPLJanelaPrincipal.ConfirmarDescartar: Boolean;
begin
  Result := True;
  if not FDoc.Modificado then Exit;
  case MessageDlg('Planejador', 'O projeto tem alterações não salvas. Deseja salvá-las?',
    mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes: Result := SalvarEm(FArquivo);
    mrNo: Result := True;
  else
    Result := False;
  end;
end;

procedure TPLJanelaPrincipal.AbrirArquivo(const AArquivo: string);
begin
  try
    PLCarregarProjeto(FDoc, AArquivo);
    FArquivo := AArquivo;
    Mensagem('Projeto aberto: ' + ExtractFileName(AArquivo));
  except
    on E: Exception do
    begin
      FDoc.Novo('Novo projeto', Date);
      FArquivo := '';
      Mensagem('Não foi possível abrir o arquivo: ' + E.Message, True);
    end;
  end;
  MostrarProjeto;
  FGantt.Origin := 0;
  Recalcular;
end;

function TPLJanelaPrincipal.SalvarEm(const AArquivo: string): Boolean;
var A: string;
begin
  Result := False;
  A := AArquivo;
  if A = '' then
  begin
    FSalvar.FileName := FDoc.Nome + PL_EXTENSAO;
    if not FSalvar.Execute then Exit;
    A := FSalvar.FileName;
    if not AnsiEndsText(PL_EXTENSAO, A) then A := ChangeFileExt(A, '') + PL_EXTENSAO;
  end;
  try
    PLSalvarProjeto(FDoc, A);
    FArquivo := A;
    Mensagem('Projeto salvo: ' + ExtractFileName(A));
    Result := True;
  except
    on E: Exception do Mensagem('Erro ao salvar: ' + E.Message, True);
  end;
  AtualizarTitulo;
end;

{ ---------------- eventos ---------------- }

procedure TPLJanelaPrincipal.AoNovo(Sender: TObject);
begin
  if not ConfirmarDescartar then Exit;
  FDoc.Novo('Novo projeto', Date);
  FArquivo := '';
  MostrarProjeto;
  FGantt.Origin := 0;
  Recalcular;
  Mensagem('Novo projeto criado. Use Insert para incluir tarefas.');
end;

procedure TPLJanelaPrincipal.AoAbrir(Sender: TObject);
begin
  if not ConfirmarDescartar then Exit;
  if FAbrir.Execute then AbrirArquivo(FAbrir.FileName);
end;

procedure TPLJanelaPrincipal.AoAbrirExemplo(Sender: TObject);
begin
  if not ConfirmarDescartar then Exit;
  PLCarregarExemploResidencia(FDoc, IncDay(Date, 1));
  FArquivo := '';
  MostrarProjeto;
  FGantt.Origin := 0;
  Recalcular;
  Mensagem('Exemplo carregado: residência de dois pavimentos.');
end;

procedure TPLJanelaPrincipal.AoSalvar(Sender: TObject);
begin
  SalvarEm(FArquivo);
end;

procedure TPLJanelaPrincipal.AoSalvarComo(Sender: TObject);
begin
  SalvarEm('');
end;

procedure TPLJanelaPrincipal.AoSair(Sender: TObject);
begin
  Close;
end;

procedure TPLJanelaPrincipal.AoNovaTarefa(Sender: TObject);
var T: TPLTarefa; Pos: Integer;
begin
  Pos := FGantt.Selected + 1;
  if Pos <= 0 then Pos := FDoc.Count;
  T := FDoc.NovaTarefa('Nova tarefa', False, Pos);
  Recalcular(T.Id);
  FGantt.EditCell(FDoc.IndiceDe(T.Id), COL_NOME);
end;

procedure TPLJanelaPrincipal.AoNovoMarco(Sender: TObject);
var T: TPLTarefa; Pos: Integer;
begin
  Pos := FGantt.Selected + 1;
  if Pos <= 0 then Pos := FDoc.Count;
  T := FDoc.NovaTarefa('Novo marco', True, Pos);
  Recalcular(T.Id);
  FGantt.EditCell(FDoc.IndiceDe(T.Id), COL_NOME);
end;

procedure TPLJanelaPrincipal.AoExcluir(Sender: TObject);
var T: TPLTarefa; I: Integer; Id: string;
begin
  T := Selecionada;
  if T = nil then Exit;
  if MessageDlg('Planejador', Format('Excluir a tarefa %s — %s? Os vínculos com ela também serão removidos.',
    [T.Id, T.Nome]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  I := FGantt.Selected;
  Id := '';
  if I + 1 < FDoc.Count then Id := FDoc[I + 1].Id
  else if I > 0 then Id := FDoc[I - 1].Id;
  FDoc.ExcluirTarefa(I);
  Recalcular(Id);
end;

procedure TPLJanelaPrincipal.AoSubir(Sender: TObject);
var T: TPLTarefa;
begin
  T := Selecionada;
  if T = nil then Exit;
  FDoc.Mover(FGantt.Selected, -1);
  Recalcular(T.Id);
end;

procedure TPLJanelaPrincipal.AoDescer(Sender: TObject);
var T: TPLTarefa;
begin
  T := Selecionada;
  if T = nil then Exit;
  FDoc.Mover(FGantt.Selected, 1);
  Recalcular(T.Id);
end;

procedure TPLJanelaPrincipal.AoAmpliar(Sender: TObject);
begin
  FGantt.ZoomBy(1.25);
end;

procedure TPLJanelaPrincipal.AoReduzir(Sender: TObject);
begin
  FGantt.ZoomBy(0.8);
end;

procedure TPLJanelaPrincipal.AoAjustar(Sender: TObject);
begin
  FGantt.FitToRows;
end;

procedure TPLJanelaPrincipal.AoSobre(Sender: TObject);
begin
  MessageDlg('Sobre o Planejador',
    'Planejador ' + PL_VERSAO_APLICATIVO + #10 +
    'Plataforma EngenhariaArquitetura — primeira etapa da linha de produção.'#10#10 +
    'Gráfico de Gantt e caminho crítico com os componentes da suíte CHATGPT ' +
    '(AIProject e AIProjectCore).', mtInformation, [mbOK], 0);
end;

procedure TPLJanelaPrincipal.AoSelecionarLinha(Sender: TObject; ARow: Integer);
begin
  MostrarTarefa;
end;

procedure TPLJanelaPrincipal.AoEditarCelula(Sender: TObject; ARow, ACol: Integer;
  var AText: string; var Accept: Boolean);
var T: TPLTarefa; Err: string;
begin
  if (ARow < 0) or (ARow >= FDoc.Count) then begin Accept := False; Exit; end;
  T := FDoc[ARow];
  Err := '';
  case ACol of
    COL_NOME:
      begin
        if Trim(AText) = '' then Err := 'o nome da tarefa não pode ficar vazio'
        else begin T.Nome := Trim(AText); FDoc.MarcarModificado; end;
      end;
    COL_DURACAO:
      if not FDoc.DefinirDuracao(T, AText, Err) then Err := 'duração inválida: ' + Err;
    COL_PRED:
      if not FDoc.DefinirPredecessoras(T, AText, Err) then Err := 'predecessoras: ' + Err;
  end;
  Accept := Err = '';
  if Accept then Mensagem('') else Mensagem(T.Id + ' — ' + Err, True);
  { o Gantt grava o texto da celula depois deste evento: recalcula em seguida }
  Application.QueueAsyncCall(@RecalcularAssincrono, 0);
end;

function TPLJanelaPrincipal.AoDiaUtil(Sender: TObject; ADay: TDateTime): Boolean;
begin
  Result := FDoc.Calendario.IsWorkingDay(ADay);
end;

procedure TPLJanelaPrincipal.AoAlterarProjeto(Sender: TObject);
begin
  if FAtualizando then Exit;
  FDoc.Nome := FProjNome.Text;
  FDoc.Objetivo := FProjObjetivo.Text;
  if (Sender = FProjInicio) and (FProjInicio.Date > 0) and (Trunc(FProjInicio.Date) <> FDoc.Inicio) then
  begin
    FDoc.Inicio := Trunc(FProjInicio.Date);
    FDoc.MarcarModificado;
    FGantt.Origin := 0;
    Recalcular;
    Exit;
  end;
  FDoc.MarcarModificado;
  AtualizarTitulo;
end;

procedure TPLJanelaPrincipal.AoAplicarTarefa(Sender: TObject);
var T: TPLTarefa; Err: string;
begin
  if FAtualizando then Exit;
  T := Selecionada;
  if T = nil then Exit;
  Err := '';
  if (Sender = FTarNome) or (Sender is TButton) then
    if Trim(FTarNome.Text) <> '' then T.Nome := Trim(FTarNome.Text);
  if ((Sender = FTarDuracao) or (Sender is TButton)) and (FTarDuracao.Text <> FDoc.TextoDuracao(T)) then
    if not FDoc.DefinirDuracao(T, FTarDuracao.Text, Err) then Err := 'duração inválida: ' + Err;
  if (Err = '') and ((Sender = FTarPred) or (Sender is TButton)) and
    (FTarPred.Text <> FDoc.TextoPredecessoras(T)) then
    if not FDoc.DefinirPredecessoras(T, FTarPred.Text, Err) then Err := 'predecessoras: ' + Err;
  if FTarApp.ItemIndex >= 0 then T.Aplicativo := TPLAplicativo(FTarApp.ItemIndex);
  if FTarSituacao.ItemIndex >= 0 then T.Situacao := TPLSituacao(FTarSituacao.ItemIndex);
  T.Responsavel := FTarResp.Text;
  T.Notas := FTarNotas.Text;
  T.Progresso := FTarProgresso.Value;
  if (T.Situacao = plsConcluida) and (T.Progresso < 100) then T.Progresso := 100;
  FDoc.MarcarModificado;
  if Err <> '' then Mensagem(T.Id + ' — ' + Err, True) else Mensagem('');
  Recalcular(T.Id);
end;

procedure TPLJanelaPrincipal.AoTecla(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if FGantt.Editing then Exit;
  if (ActiveControl = FGantt) and (Key = VK_F2) and (Selecionada <> nil) then
  begin
    FGantt.EditCell(FGantt.Selected, COL_NOME);
    Key := 0;
  end;
end;

procedure TPLJanelaPrincipal.AoMostrar(Sender: TObject);
begin
  { a escala de tempo depende da largura final do grafico }
  Application.QueueAsyncCall(@AjustarAssincrono, 0);
end;

procedure TPLJanelaPrincipal.AjustarAssincrono(Data: PtrInt);
begin
  FGantt.FitToRows;
end;

procedure TPLJanelaPrincipal.AoFecharConsulta(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := ConfirmarDescartar;
end;

end.
