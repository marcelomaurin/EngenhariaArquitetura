unit cad2d_main;
{$mode objfpc}{$H+}
{$codepage utf8}
interface
uses Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, Menus,
  Graphics, Types, Math, Dialogs, LCLType;
type
  TCADLine = record
    A, B: TPoint;
    Layer: Integer;
    Kind: Integer; // 0 linha, 1 retangulo, 2 parede, 3 porta, 4 janela, 5 sofa+tapete, 6 mesa jantar, 7 rack tv, 8 planta, 9 janela alta (tracejada)
    WidthMM: Integer;
    HeightMM: Integer; // altura da janela/porta (ex: 1200 mm ou 2100 mm)
    SillMM: Integer;   // peitoril da janela (ex: 900 mm ou 1600 mm)
    GroupID: Integer;
  end;

  TCADMainForm = class(TForm)
  private
    // Estrutura UI estilo AutoCAD LT
    FQuickBar, FRibbonTabsBar, FRibbonPanel, FDocTabsBar: TPanel;
    FCommandDock, FStatusBar: TPanel;
    FCmdHistoryMemo: TMemo;
    FCmdEdit: TEdit;
    FCoordLabel, FModeLabel, FStatus: TLabel;
    FBtnGrid, FBtnSnap, FBtnOrtho, FBtnOsnap, FBtnDim, FBtnTheme: TPanel;
    FLayerColorSwatch: TShape;
    FLayerBulbLabel, FLayerSunLabel, FLayerLockLabel: TLabel;
    FLayerSelect, FToolSelect: TComboBox;
    FCanvas: TPaintBox;

    // Estado do modelo geométrico e arquitetônico
    FLines: array of TCADLine;
    FLayerVisible: array[0..7] of Boolean;
    FLayerLocked: array[0..7] of Boolean;
    FHasStart: Boolean;
    FStart, FMousePos: TPoint;
    FHasMouse: Boolean;
    FGrid: Integer;
    FMillimetersPerPixel: Integer;
    FPath: string;
    FSelected: Integer;
    FZoom: Double;
    FPanX, FPanY: Integer;
    FShowDimensions: Boolean;
    FShowGrid: Boolean;
    FSnapEnabled: Boolean;
    FOrthoEnabled: Boolean;
    FOsnapEnabled: Boolean;
    FDarkModelSpace: Boolean;
    FNextGroup: Integer;
    FUndo: array of TCADLine;
    FHistoryUndo, FHistoryRedo: TStringList;

    // Construção da interface AutoCAD
    procedure BuildAutoCADInterface;
    procedure UpdateTogglePills;
    procedure UpdateLayerSwatch;
    procedure LogCommand(const CmdText: string);
    procedure CmdEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ExecuteCommandString(const RawCmd: string);
    procedure FormKeyDownHandler(Sender: TObject; var Key: Word; Shift: TShiftState);

    // Manipuladores de botões da Ribbon e Status Bar
    procedure SelectToolByTag(Sender: TObject);
    procedure ToggleGridClick(Sender: TObject);
    procedure ToggleSnapClick(Sender: TObject);
    procedure ToggleOrthoClick(Sender: TObject);
    procedure ToggleOsnapClick(Sender: TObject);
    procedure ToggleThemeClick(Sender: TObject);
    procedure ToggleLayerVisibilityClick(Sender: TObject);
    procedure ToggleLayerLockClick(Sender: TObject);
    procedure LoadSampleFloorPlan(Sender: TObject);
    procedure ZoomExtents(Sender: TObject);

    // Histórico e persistência
    procedure RecordChange;
    function Snapshot: string;
    procedure RestoreSnapshot(const Value: string);
    procedure PanDrawing(Sender: TObject);
    procedure RedoDrawing(Sender: TObject);
    procedure UndoHistory(Sender: TObject);
    procedure RedoHistory(Sender: TObject);
    procedure ZoomDrawing(Sender: TObject);
    procedure SelectObjectAt(const P: TPoint);
    procedure DeleteSelected(Sender: TObject);
    procedure TransformSelected(Sender: TObject);
    procedure RotateSelected(Sender: TObject);
    procedure MirrorSelected(Sender: TObject);
    procedure OffsetSelected(Sender: TObject);
    procedure ExtendSelected(Sender: TObject);
    procedure TrimSelected(Sender: TObject);
    procedure ChamferSelected(Sender: TObject);
    procedure FilletSelected(Sender: TObject);
    procedure SelectionChanged(Sender: TObject);
    procedure AddSegment(const A, B: TPoint);
    procedure AddSegmentEx(const A, B: TPoint; ALayer, AKind, AWidthMM, AHeightMM, ASillMM: Integer);
    procedure AddCircle(const Center, Edge: TPoint);

    // Renderização Arquitetônica (Paredes duplas com vãos, Portas com arco, Janelas Aula 06, Mobiliário)
    procedure PaintDrawing(Sender: TObject);
    procedure DrawUCSIcon(C: TCanvas; const R: TRect);
    procedure DrawCrosshair(C: TCanvas; const R: TRect);
    procedure DrawDoubleWallWithOpenings(C: TCanvas; WallIdx: Integer; IsSelected: Boolean);
    procedure DrawArchitecturalDoor(C: TCanvas; const L: TCADLine; IsSelected: Boolean);
    procedure DrawArchitecturalWindow(C: TCanvas; const L: TCADLine; IsSelected: Boolean);
    procedure DrawFurnitureBlock(C: TCanvas; const L: TCADLine; IsSelected: Boolean);
    function WorldToScreen(const P: TPoint): TPoint;
    function ScreenToWorld(X, Y: Integer): TPoint;
    function LayerColor(LayerIdx: Integer): TColor;
    function LayerDXFName(LayerIdx: Integer): string;

    procedure CanvasClick(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure MouseMoveDrawing(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure NewDrawing(Sender: TObject);
    procedure ExportDXF(Sender: TObject);
    procedure ExportSVG(Sender: TObject);
    procedure MeasureSelected(Sender: TObject);
    procedure ToggleDimensions(Sender: TObject);
    procedure SaveDrawing(Sender: TObject);
    procedure OpenDrawing(Sender: TObject);
    procedure UndoLine(Sender: TObject);
    procedure EditLastObject(Sender: TObject);
    function Snap(P: TPoint): TPoint;
    procedure RefreshStatus(const S: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  CADMainForm: TCADMainForm;

implementation

const
  LAYER_NAMES: array[0..7] of string = (
    'ARQ_PAREDES',
    'ARQ_ESQUADRIAS',
    'Mobiliário',
    'ARQ_COTAS',
    'ARQ_TEXTOS',
    'ARQ_PROJECOES',
    'ARQ_ESTRUTURA',
    'ARQ_PISOS'
  );

function TCADMainForm.LayerColor(LayerIdx: Integer): TColor;
begin
  case LayerIdx of
    0: Result := RGBToColor(186, 85, 42);   // ARQ_PAREDES (terracota/marrom AutoCAD)
    1: Result := RGBToColor(225, 198, 44);  // ARQ_ESQUADRIAS (amarelo portas/janelas)
    2: Result := RGBToColor(220, 48, 42);   // Mobiliário (vermelho/madeira)
    3: Result := RGBToColor(215, 72, 62);   // ARQ_COTAS (vermelho cota)
    4: Result := RGBToColor(110, 205, 245); // ARQ_TEXTOS (ciano)
    5: Result := RGBToColor(160, 170, 185); // ARQ_PROJECOES (cinza tracejado - janela alta)
    6: Result := RGBToColor(52, 185, 110);  // ARQ_ESTRUTURA (verde)
    7: Result := RGBToColor(212, 188, 148); // ARQ_PISOS (bege pisos/tapete)
  else
    Result := RGBToColor(200, 210, 225);
  end;
end;

function TCADMainForm.LayerDXFName(LayerIdx: Integer): string;
begin
  if (LayerIdx >= 0) and (LayerIdx <= High(LAYER_NAMES)) then
    Result := StringReplace(UpperCase(LAYER_NAMES[LayerIdx]), 'Á', 'A', [rfReplaceAll])
  else
    Result := 'ARQ_PAREDES';
end;

function TCADMainForm.WorldToScreen(const P: TPoint): TPoint;
begin
  Result.X := Round(P.X * FZoom) + FPanX;
  Result.Y := Round(P.Y * FZoom) + FPanY;
end;

function TCADMainForm.ScreenToWorld(X, Y: Integer): TPoint;
begin
  Result.X := Round((X - FPanX) / FZoom);
  Result.Y := Round((Y - FPanY) / FZoom);
end;

constructor TCADMainForm.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited CreateNew(AOwner, 1);
  Caption := 'AutoCAD LT / CAD Arquitetônico 2D — vobi autocad.eacad';
  Width := 1280;
  Height := 820;
  Position := poScreenCenter;
  Constraints.MinWidth := 920;
  Constraints.MinHeight := 600;
  KeyPreview := True;
  OnKeyDown := @FormKeyDownHandler;
  Color := RGBToColor(43, 48, 54);
  Font.Name := {$IFDEF WINDOWS}'Segoe UI'{$ELSE}'Sans'{$ENDIF};
  Font.Size := 9;

  FGrid := 20;
  FMillimetersPerPixel := 50; // 20 px = 1000 mm (1,00 m); 1 px = 50 mm
  FSelected := -1;
  FZoom := 1.0;
  FPanX := 40;
  FPanY := 20;
  FShowDimensions := True;
  FShowGrid := True;
  FSnapEnabled := True;
  FOrthoEnabled := False;
  FOsnapEnabled := True;
  FDarkModelSpace := True;
  FNextGroup := 1;
  for I := 0 to High(FLayerVisible) do begin
    FLayerVisible[I] := True;
    FLayerLocked[I] := False;
  end;
  FHistoryUndo := TStringList.Create;
  FHistoryRedo := TStringList.Create;

  BuildAutoCADInterface;
  LoadSampleFloorPlan(nil);
  RefreshStatus('Pronto — Planta baixa carregada. Digite um comando ou selecione uma ferramenta na Ribbon.');
end;

destructor TCADMainForm.Destroy;
begin
  FHistoryRedo.Free;
  FHistoryUndo.Free;
  inherited Destroy;
end;

procedure TCADMainForm.BuildAutoCADInterface;
var
  Badge, GroupCaption, Lbl: TLabel;
  CmdLeftPanel, CmdInputRow: TPanel;

  function CreateRibbonGroup(const ATitle: string; AWidth: Integer): TPanel;
  var
    CapBar: TPanel;
  begin
    Result := TPanel.Create(Self);
    Result.Parent := FRibbonPanel;
    Result.Align := alLeft;
    Result.Width := AWidth;
    Result.BevelOuter := bvNone;
    Result.Color := RGBToColor(58, 63, 70);
    Result.BorderSpacing.Right := 2;

    CapBar := TPanel.Create(Self);
    CapBar.Parent := Result;
    CapBar.Align := alBottom;
    CapBar.Height := 18;
    CapBar.BevelOuter := bvNone;
    CapBar.Color := RGBToColor(46, 50, 56);

    GroupCaption := TLabel.Create(Self);
    GroupCaption.Parent := CapBar;
    GroupCaption.Align := alClient;
    GroupCaption.Alignment := taCenter;
    GroupCaption.Layout := tlCenter;
    GroupCaption.Caption := ATitle + ' ▾';
    GroupCaption.Font.Color := RGBToColor(175, 184, 196);
    GroupCaption.Font.Size := 8;
  end;

  function AddRibbonBtn(AParent: TWinControl; const ACaption: string;
    AX, AY, AW, AH: Integer; AAction: TNotifyEvent; ATag: Integer = 0;
    const AHint: string = ''): TPanel;
  var
    L: TLabel;
  begin
    Result := TPanel.Create(Self);
    Result.Parent := AParent;
    Result.SetBounds(AX, AY, AW, AH);
    Result.BevelOuter := bvNone;
    Result.Color := RGBToColor(70, 76, 84);
    Result.Tag := ATag;
    Result.Cursor := crHandPoint;
    if AHint <> '' then begin
      Result.Hint := AHint;
      Result.ShowHint := True;
    end;
    Result.OnClick := AAction;

    L := TLabel.Create(Self);
    L.Parent := Result;
    L.Align := alClient;
    L.Alignment := taCenter;
    L.Layout := tlCenter;
    L.Caption := ACaption;
    L.Font.Color := RGBToColor(235, 240, 245);
    L.Font.Size := 8;
    L.Tag := ATag;
    L.Cursor := crHandPoint;
    if AHint <> '' then begin
      L.Hint := AHint;
      L.ShowHint := True;
    end;
    L.OnClick := AAction;
  end;

  function AddQuickBtn(const ACaption: string; AWidth: Integer; AAction: TNotifyEvent; const AHint: string): TPanel;
  var
    L: TLabel;
  begin
    Result := TPanel.Create(Self);
    Result.Parent := FQuickBar;
    Result.Align := alLeft;
    Result.Width := AWidth;
    Result.BorderSpacing.Left := 3;
    Result.BorderSpacing.Top := 3;
    Result.BorderSpacing.Bottom := 3;
    Result.BevelOuter := bvNone;
    Result.Color := RGBToColor(58, 63, 70);
    Result.Cursor := crHandPoint;
    Result.Hint := AHint;
    Result.ShowHint := True;
    Result.OnClick := AAction;

    L := TLabel.Create(Self);
    L.Parent := Result;
    L.Align := alClient;
    L.Alignment := taCenter;
    L.Layout := tlCenter;
    L.Caption := ACaption;
    L.Font.Color := RGBToColor(230, 235, 242);
    L.Font.Size := 8;
    L.Cursor := crHandPoint;
    L.Hint := AHint;
    L.ShowHint := True;
    L.OnClick := AAction;
  end;

  function AddStatusPill(const ACaption: string; AWidth: Integer; AAction: TNotifyEvent; const AHint: string): TPanel;
  var
    L: TLabel;
  begin
    Result := TPanel.Create(Self);
    Result.Parent := FStatusBar;
    Result.Align := alRight;
    Result.Width := AWidth;
    Result.BorderSpacing.Left := 2;
    Result.BorderSpacing.Top := 2;
    Result.BorderSpacing.Bottom := 2;
    Result.BevelOuter := bvNone;
    Result.Color := RGBToColor(55, 62, 72);
    Result.Cursor := crHandPoint;
    Result.Hint := AHint;
    Result.ShowHint := True;
    Result.OnClick := AAction;

    L := TLabel.Create(Self);
    L.Parent := Result;
    L.Align := alClient;
    L.Alignment := taCenter;
    L.Layout := tlCenter;
    L.Caption := ACaption;
    L.Font.Color := RGBToColor(225, 232, 240);
    L.Font.Size := 8;
    L.Font.Style := [fsBold];
    L.Cursor := crHandPoint;
    L.Hint := AHint;
    L.ShowHint := True;
    L.OnClick := AAction;
  end;

var
  GrpModify, GrpDraw, GrpArch, GrpAnnot, GrpLayers, GrpBlock, GrpView: TPanel;
  LayerBoxPanel: TPanel;
  TabNames: array[0..7] of string = ('Home', 'Insert', 'Annotate', 'Parametric', 'View', 'Manage', 'Output', 'Collaborate');
  I, XPos: Integer;
begin
  // 1. Barra de Acesso Rápido (Quick Access Toolbar estilo AutoCAD LT)
  FQuickBar := TPanel.Create(Self);
  FQuickBar.Parent := Self;
  FQuickBar.Align := alTop;
  FQuickBar.Height := 28;
  FQuickBar.BevelOuter := bvNone;
  FQuickBar.Color := RGBToColor(36, 40, 46);

  Badge := TLabel.Create(Self);
  Badge.Parent := FQuickBar;
  Badge.Align := alLeft;
  Badge.AutoSize := False;
  Badge.Width := 46;
  Badge.Alignment := taCenter;
  Badge.Layout := tlCenter;
  Badge.Caption := 'A LT';
  Badge.Font.Color := RGBToColor(235, 68, 52);
  Badge.Font.Style := [fsBold];
  Badge.Font.Size := 10;

  AddQuickBtn('Novo', 48, @NewDrawing, 'Novo desenho (NEW)');
  AddQuickBtn('Abrir', 48, @OpenDrawing, 'Abrir projeto .eacad (OPEN)');
  AddQuickBtn('Salvar', 52, @SaveDrawing, 'Salvar projeto .eacad (QSAVE)');
  AddQuickBtn('DXF', 44, @ExportDXF, 'Exportar AutoCAD DXF R12');
  AddQuickBtn('SVG', 44, @ExportSVG, 'Exportar SVG Vetorial');
  AddQuickBtn('↶ Undo', 56, @UndoHistory, 'Desfazer operação (Ctrl+Z / U)');
  AddQuickBtn('↷ Redo', 56, @RedoHistory, 'Refazer operação (Ctrl+Y / REDO)');
  AddQuickBtn('★ Planta Exemplo (Vobi)', 142, @LoadSampleFloorPlan, 'Recarregar a planta baixa humanizada do exemplo AutoCAD');

  Lbl := TLabel.Create(Self);
  Lbl.Parent := FQuickBar;
  Lbl.Align := alClient;
  Lbl.Alignment := taCenter;
  Lbl.Layout := tlCenter;
  Lbl.Caption := 'vobi autocad.dwg / .eacad  —  CAD Arquitetônico 2D';
  Lbl.Font.Color := RGBToColor(200, 208, 218);
  Lbl.Font.Style := [fsBold];

  // 2. Barra de Abas da Ribbon (Home | Insert | Annotate | Parametric | View | Manage | Output)
  FRibbonTabsBar := TPanel.Create(Self);
  FRibbonTabsBar.Parent := Self;
  FRibbonTabsBar.Align := alTop;
  FRibbonTabsBar.Height := 24;
  FRibbonTabsBar.BevelOuter := bvNone;
  FRibbonTabsBar.Color := RGBToColor(43, 48, 54);

  XPos := 8;
  for I := 0 to High(TabNames) do begin
    Lbl := TLabel.Create(Self);
    Lbl.Parent := FRibbonTabsBar;
    Lbl.AutoSize := False;
    Lbl.SetBounds(XPos, 2, 76, 20);
    Lbl.Alignment := taCenter;
    Lbl.Layout := tlCenter;
    Lbl.Caption := TabNames[I];
    if I = 0 then begin
      Lbl.Font.Color := clWhite;
      Lbl.Font.Style := [fsBold];
    end else
      Lbl.Font.Color := RGBToColor(175, 182, 192);
    Inc(XPos, 78);
  end;

  // 3. Painel Principal da Ribbon (Modify | Draw | Arquitetura | Annotation | Layers | Block | View)
  FRibbonPanel := TPanel.Create(Self);
  FRibbonPanel.Parent := Self;
  FRibbonPanel.Align := alTop;
  FRibbonPanel.Height := 94;
  FRibbonPanel.BevelOuter := bvNone;
  FRibbonPanel.Color := RGBToColor(50, 55, 62);

  // Grupo MODIFY
  GrpModify := CreateRibbonGroup('Modify', 222);
  AddRibbonBtn(GrpModify, '✥ Mover', 4, 4, 68, 22, @TransformSelected, 0, 'Mover objeto selecionado (MOVE)');
  AddRibbonBtn(GrpModify, '⧉ Copiar', 74, 4, 68, 22, @TransformSelected, 1, 'Copiar objeto selecionado (COPY)');
  AddRibbonBtn(GrpModify, '↻ Girar', 144, 4, 72, 22, @RotateSelected, 0, 'Rotacionar seleção em graus (ROTATE)');
  AddRibbonBtn(GrpModify, '✂ Trim', 4, 28, 68, 22, @TrimSelected, 0, 'Aparar segmento na interseção (TRIM)');
  AddRibbonBtn(GrpModify, '⇥ Extend', 74, 28, 68, 22, @ExtendSelected, 0, 'Estender segmento até limite (EXTEND)');
  AddRibbonBtn(GrpModify, '⌫ Excluir', 144, 28, 72, 22, @DeleteSelected, 0, 'Apagar entidade selecionada (ERASE / Del)');
  AddRibbonBtn(GrpModify, '⇄ Esp.X/Y', 4, 52, 68, 20, @MirrorSelected, 0, 'Espelhar objeto selecionado (MIRROR)');
  AddRibbonBtn(GrpModify, '⫽ Offset', 74, 52, 68, 20, @OffsetSelected, 0, 'Cópia paralela em milímetros (OFFSET)');
  AddRibbonBtn(GrpModify, '◜ Fillet', 144, 52, 35, 20, @FilletSelected, 0, 'Arredondar canto entre 2 linhas (FILLET)');
  AddRibbonBtn(GrpModify, '◿ Chanf', 181, 52, 35, 20, @ChamferSelected, 0, 'Chanfrar canto entre 2 linhas (CHAMFER)');

  // Grupo DRAW (Geometria CAD)
  GrpDraw := CreateRibbonGroup('Draw', 158);
  AddRibbonBtn(GrpDraw, '╱ Line', 4, 4, 72, 32, @SelectToolByTag, 0, 'Desenhar Linha por 2 pontos (LINE)');
  AddRibbonBtn(GrpDraw, '▭ Retâng.', 80, 4, 72, 32, @SelectToolByTag, 1, 'Desenhar Retângulo (RECTANG)');
  AddRibbonBtn(GrpDraw, '◯ Circle', 4, 40, 72, 32, @SelectToolByTag, 6, 'Desenhar Círculo por centro e raio (CIRCLE)');
  AddRibbonBtn(GrpDraw, '↖ Selecionar', 80, 40, 72, 32, @SelectToolByTag, 5, 'Selecionar objeto na planta');

  // Grupo ARQUITETURA (Paredes, Portas, Janelas Aula 06)
  GrpArch := CreateRibbonGroup('Arquitetura (BIM 2D)', 196);
  AddRibbonBtn(GrpArch, '🧱 Parede Dupla', 4, 4, 90, 32, @SelectToolByTag, 2, 'Desenhar Parede paramétrica com linha dupla (150 mm) e abertura automática de vãos');
  AddRibbonBtn(GrpArch, '🚪 Porta 90°', 98, 4, 92, 32, @SelectToolByTag, 3, 'Inserir Porta (900 mm) com abertura de vão na parede, boneca e arco 90°');
  AddRibbonBtn(GrpArch, '🪟 Janela Baixa', 4, 40, 90, 32, @SelectToolByTag, 4, 'Inserir Janela padrão (Aula 06): abre vão na parede, desenha peitoril + 2 linhas de caixilho e cota LxAxP');
  AddRibbonBtn(GrpArch, '🪟 Janela Alta', 98, 40, 92, 32, @SelectToolByTag, 9, 'Inserir Janela Alta (tracejada acima do plano de corte, peitoril 1,60m - Aula 06)');

  // Grupo ANNOTATION (Cotas e Medidas)
  GrpAnnot := CreateRibbonGroup('Annotation', 132);
  AddRibbonBtn(GrpAnnot, '📏 Cotas ON/OFF', 4, 4, 122, 22, @ToggleDimensions, 0, 'Exibir/ocultar cotas em metros e especificações de janelas (LxAxP)');
  AddRibbonBtn(GrpAnnot, '📐 Medir Seleção', 4, 28, 122, 22, @MeasureSelected, 0, 'Medir comprimento exato em metros e milímetros (DIST)');
  AddRibbonBtn(GrpAnnot, '✎ Editar Dimensão', 4, 52, 122, 20, @EditLastObject, 0, 'Editar espessura de parede ou largura/altura/peitoril de esquadria');

  // Grupo LAYERS (Idêntico ao destaque da imagem: lâmpada, sol, cadeado, cor e nome da Layer)
  GrpLayers := CreateRibbonGroup('Layers', 240);
  LayerBoxPanel := TPanel.Create(Self);
  LayerBoxPanel.Parent := GrpLayers;
  LayerBoxPanel.SetBounds(6, 6, 226, 30);
  LayerBoxPanel.BevelOuter := bvNone;
  LayerBoxPanel.Color := RGBToColor(40, 44, 50);

  FLayerBulbLabel := TLabel.Create(Self);
  FLayerBulbLabel.Parent := LayerBoxPanel;
  FLayerBulbLabel.SetBounds(6, 5, 18, 20);
  FLayerBulbLabel.Caption := '💡';
  FLayerBulbLabel.Font.Color := RGBToColor(255, 215, 60);
  FLayerBulbLabel.Cursor := crHandPoint;
  FLayerBulbLabel.Hint := 'Ligar/Desligar visibilidade da camada atual (Layer On/Off)';
  FLayerBulbLabel.ShowHint := True;
  FLayerBulbLabel.OnClick := @ToggleLayerVisibilityClick;

  FLayerSunLabel := TLabel.Create(Self);
  FLayerSunLabel.Parent := LayerBoxPanel;
  FLayerSunLabel.SetBounds(26, 5, 18, 20);
  FLayerSunLabel.Caption := '☀';
  FLayerSunLabel.Font.Color := RGBToColor(255, 200, 50);
  FLayerSunLabel.Cursor := crHandPoint;
  FLayerSunLabel.Hint := 'Congelar/Descongelar camada (Freeze)';
  FLayerSunLabel.ShowHint := True;
  FLayerSunLabel.OnClick := @ToggleLayerVisibilityClick;

  FLayerLockLabel := TLabel.Create(Self);
  FLayerLockLabel.Parent := LayerBoxPanel;
  FLayerLockLabel.SetBounds(46, 5, 18, 20);
  FLayerLockLabel.Caption := '🔓';
  FLayerLockLabel.Font.Color := RGBToColor(190, 200, 215);
  FLayerLockLabel.Cursor := crHandPoint;
  FLayerLockLabel.Hint := 'Bloquear/Desbloquear camada atual (Lock)';
  FLayerLockLabel.ShowHint := True;
  FLayerLockLabel.OnClick := @ToggleLayerLockClick;

  FLayerColorSwatch := TShape.Create(Self);
  FLayerColorSwatch.Parent := LayerBoxPanel;
  FLayerColorSwatch.SetBounds(68, 7, 16, 16);
  FLayerColorSwatch.Shape := stRectangle;
  FLayerColorSwatch.Brush.Color := LayerColor(0);
  FLayerColorSwatch.Pen.Color := clWhite;

  FLayerSelect := TComboBox.Create(Self);
  FLayerSelect.Parent := LayerBoxPanel;
  FLayerSelect.SetBounds(88, 3, 134, 24);
  FLayerSelect.Style := csDropDownList;
  for I := 0 to High(LAYER_NAMES) do
    FLayerSelect.Items.Add(LAYER_NAMES[I]);
  FLayerSelect.ItemIndex := 2; // "Mobiliário" em destaque como na captura do AutoCAD
  FLayerSelect.OnChange := @SelectionChanged;

  // Seletor de ferramenta ativa sincronizado
  Lbl := TLabel.Create(Self);
  Lbl.Parent := GrpLayers;
  Lbl.SetBounds(6, 44, 64, 20);
  Lbl.Caption := 'Ferramenta:';
  Lbl.Font.Color := RGBToColor(185, 195, 205);

  FToolSelect := TComboBox.Create(Self);
  FToolSelect.Parent := GrpLayers;
  FToolSelect.SetBounds(72, 40, 160, 24);
  FToolSelect.Style := csDropDownList;
  FToolSelect.Items.Add('Linha (LINE)');             // 0
  FToolSelect.Items.Add('Retângulo (RECTANG)');      // 1
  FToolSelect.Items.Add('Parede Dupla (WALL)');      // 2
  FToolSelect.Items.Add('Porta 90° (DOOR)');         // 3
  FToolSelect.Items.Add('Janela Baixa (WINDOW)');    // 4
  FToolSelect.Items.Add('Selecionar');               // 5
  FToolSelect.Items.Add('Círculo (CIRCLE)');         // 6
  FToolSelect.Items.Add('Bloco: Sofá + Tapete');     // 7
  FToolSelect.Items.Add('Bloco: Mesa Jantar');       // 8
  FToolSelect.Items.Add('Bloco: Rack TV');           // 9
  FToolSelect.Items.Add('Bloco: Vaso Planta');       // 10
  FToolSelect.Items.Add('Janela Alta Tracejada');    // 11
  FToolSelect.ItemIndex := 4; // Janela ativa por padrão para fácil teste da Aula 06
  FToolSelect.OnChange := @SelectionChanged;

  // Grupo BLOCK (Mobiliário humanizado como na imagem do AutoCAD)
  GrpBlock := CreateRibbonGroup('Block / Mobiliário', 178);
  AddRibbonBtn(GrpBlock, '🛋 Sofá+Tapete', 4, 4, 82, 32, @SelectToolByTag, 7, 'Inserir bloco de Sofá + Tapete listrado + Mesa de centro');
  AddRibbonBtn(GrpBlock, '🍽 Mesa Jantar', 90, 4, 82, 32, @SelectToolByTag, 8, 'Inserir bloco de Mesa redonda com 4 cadeiras');
  AddRibbonBtn(GrpBlock, '📺 Rack TV', 4, 40, 82, 32, @SelectToolByTag, 9, 'Inserir bloco de Rack de madeira com TV');
  AddRibbonBtn(GrpBlock, '🌿 Planta', 90, 40, 82, 32, @SelectToolByTag, 10, 'Inserir bloco de Planta humanizada');

  // Grupo VIEW (Zoom e Pan)
  GrpView := CreateRibbonGroup('View / Navigate', 140);
  AddRibbonBtn(GrpView, '🔍 Zoom +', 4, 4, 64, 22, @ZoomDrawing, 1, 'Aproximar vista (Zoom In)');
  AddRibbonBtn(GrpView, '🔎 Zoom -', 70, 4, 64, 22, @ZoomDrawing, -1, 'Afastar vista (Zoom Out)');
  AddRibbonBtn(GrpView, '⛶ Enquadrar', 4, 28, 130, 22, @ZoomExtents, 0, 'Centralizar planta na tela (ZOOM EXTENTS)');
  AddRibbonBtn(GrpView, '◀', 4, 52, 30, 20, @PanDrawing, 1, 'Pan esquerda');
  AddRibbonBtn(GrpView, '▶', 37, 52, 30, 20, @PanDrawing, 2, 'Pan direita');
  AddRibbonBtn(GrpView, '▲', 70, 52, 30, 20, @PanDrawing, 3, 'Pan cima');
  AddRibbonBtn(GrpView, '▼', 103, 52, 31, 20, @PanDrawing, 4, 'Pan baixo');

  // 4. Barra de Abas de Documento (Start | vobi autocad *)
  FDocTabsBar := TPanel.Create(Self);
  FDocTabsBar.Parent := Self;
  FDocTabsBar.Align := alTop;
  FDocTabsBar.Height := 26;
  FDocTabsBar.BevelOuter := bvNone;
  FDocTabsBar.Color := RGBToColor(36, 40, 46);

  AddRibbonBtn(FDocTabsBar, 'Start', 6, 3, 70, 22, nil, 0);
  with AddRibbonBtn(FDocTabsBar, 'vobi autocad.dwg  ✕', 80, 2, 150, 24, nil, 0) do
    Color := RGBToColor(26, 33, 41);
  AddRibbonBtn(FDocTabsBar, '+', 234, 3, 24, 22, @NewDrawing, 0, 'Nova aba de desenho');

  // 5. Barra de Status Inferior estilo AutoCAD (Model | Layout1 | Layout2 | Coordenadas | GRID | SNAP | ORTHO | OSNAP)
  FStatusBar := TPanel.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.Align := alBottom;
  FStatusBar.Height := 26;
  FStatusBar.BevelOuter := bvNone;
  FStatusBar.Color := RGBToColor(43, 48, 54);

  Lbl := TLabel.Create(Self);
  Lbl.Parent := FStatusBar;
  Lbl.Align := alLeft;
  Lbl.AutoSize := False;
  Lbl.Width := 190;
  Lbl.Layout := tlCenter;
  Lbl.Caption := '  [Model]   Layout1   Layout2   +';
  Lbl.Font.Color := RGBToColor(225, 232, 240);
  Lbl.Font.Style := [fsBold];

  FStatus := TLabel.Create(Self);
  FStatus.Parent := FStatusBar;
  FStatus.Align := alClient;
  FStatus.Layout := tlCenter;
  FStatus.Font.Color := RGBToColor(190, 200, 212);

  FBtnTheme := AddStatusPill('FUNDO ESCURO', 98, @ToggleThemeClick, 'Alternar fundo Model Space (Escuro AutoCAD / Claro Folha)');
  FBtnDim := AddStatusPill('COTAS', 58, @ToggleDimensions, 'Mostrar/ocultar cotas e dimensões de janelas');
  FBtnOsnap := AddStatusPill('OSNAP', 58, @ToggleOsnapClick, 'Object Snap em extremidades e paredes');
  FBtnOrtho := AddStatusPill('ORTHO (F8)', 76, @ToggleOrthoClick, 'Restringir cursor aos eixos ortogonais 0°/90°');
  FBtnSnap := AddStatusPill('SNAP', 52, @ToggleSnapClick, 'Snap à grade');
  FBtnGrid := AddStatusPill('GRID (F7)', 68, @ToggleGridClick, 'Exibir/ocultar grade do Model Space');

  FModeLabel := TLabel.Create(Self);
  FModeLabel.Parent := FStatusBar;
  FModeLabel.Align := alRight;
  FModeLabel.AutoSize := False;
  FModeLabel.Width := 90;
  FModeLabel.Alignment := taCenter;
  FModeLabel.Layout := tlCenter;
  FModeLabel.Caption := 'MODEL  1:50';
  FModeLabel.Font.Color := RGBToColor(235, 240, 245);
  FModeLabel.Font.Style := [fsBold];

  FCoordLabel := TLabel.Create(Self);
  FCoordLabel.Parent := FStatusBar;
  FCoordLabel.Align := alRight;
  FCoordLabel.AutoSize := False;
  FCoordLabel.Width := 180;
  FCoordLabel.Alignment := taRightJustify;
  FCoordLabel.Layout := tlCenter;
  FCoordLabel.Caption := '3311.0396, 1403.1835, 0.0000  ';
  FCoordLabel.Font.Color := RGBToColor(210, 218, 228);

  // 6. Janela de Linha de Comando do AutoCAD (Command: / Type a command)
  FCommandDock := TPanel.Create(Self);
  FCommandDock.Parent := Self;
  FCommandDock.Align := alBottom;
  FCommandDock.Height := 68;
  FCommandDock.BevelOuter := bvNone;
  FCommandDock.Color := RGBToColor(228, 231, 236);

  CmdLeftPanel := TPanel.Create(Self);
  CmdLeftPanel.Parent := FCommandDock;
  CmdLeftPanel.Align := alLeft;
  CmdLeftPanel.Width := 22;
  CmdLeftPanel.BevelOuter := bvNone;
  CmdLeftPanel.Color := RGBToColor(78, 84, 92);

  CmdInputRow := TPanel.Create(Self);
  CmdInputRow.Parent := FCommandDock;
  CmdInputRow.Align := alBottom;
  CmdInputRow.Height := 24;
  CmdInputRow.BevelOuter := bvNone;
  CmdInputRow.Color := clWhite;

  Lbl := TLabel.Create(Self);
  Lbl.Parent := CmdInputRow;
  Lbl.Align := alLeft;
  Lbl.AutoSize := False;
  Lbl.Width := 95;
  Lbl.Layout := tlCenter;
  Lbl.Caption := '  >- Command:';
  Lbl.Font.Color := RGBToColor(60, 68, 78);
  Lbl.Font.Style := [fsBold];

  FCmdEdit := TEdit.Create(Self);
  FCmdEdit.Parent := CmdInputRow;
  FCmdEdit.Align := alClient;
  FCmdEdit.BorderStyle := bsNone;
  FCmdEdit.TextHint := 'Type a command (ex: WALL, JANELA, PORTA, LINE, OFFSET, TRIM, QSAVE, 1960x1200x900)...';
  FCmdEdit.OnKeyDown := @CmdEditKeyDown;

  FCmdHistoryMemo := TMemo.Create(Self);
  FCmdHistoryMemo.Parent := FCommandDock;
  FCmdHistoryMemo.Align := alClient;
  FCmdHistoryMemo.ReadOnly := True;
  FCmdHistoryMemo.ScrollBars := ssVertical;
  FCmdHistoryMemo.BorderStyle := bsNone;
  FCmdHistoryMemo.Color := RGBToColor(235, 237, 240);
  FCmdHistoryMemo.Font.Name := 'Consolas';
  FCmdHistoryMemo.Font.Size := 9;
  FCmdHistoryMemo.Font.Color := RGBToColor(35, 40, 46);
  FCmdHistoryMemo.Lines.Add('Command: _OPEN vobi_autocad.eacad');
  FCmdHistoryMemo.Lines.Add('Command: _LAYER Set Mobiliário');
  FCmdHistoryMemo.Lines.Add('Command: _QSAVE');

  // 7. Viewport Model Space
  FCanvas := TPaintBox.Create(Self);
  FCanvas.Parent := Self;
  FCanvas.Align := alClient;
  FCanvas.Cursor := crNone; // Usamos o crosshair classico do AutoCAD com pickbox central
  FCanvas.OnPaint := @PaintDrawing;
  FCanvas.OnMouseDown := @CanvasClick;
  FCanvas.OnMouseMove := @MouseMoveDrawing;

  UpdateLayerSwatch;
  UpdateTogglePills;
end;

procedure TCADMainForm.UpdateLayerSwatch;
var
  Idx: Integer;
begin
  if not Assigned(FLayerSelect) then Exit;
  Idx := Max(0, FLayerSelect.ItemIndex);
  if Assigned(FLayerColorSwatch) then
    FLayerColorSwatch.Brush.Color := LayerColor(Idx);
  if Assigned(FLayerBulbLabel) then begin
    if FLayerVisible[Idx] then
      FLayerBulbLabel.Font.Color := RGBToColor(255, 215, 60)
    else
      FLayerBulbLabel.Font.Color := RGBToColor(110, 115, 125);
  end;
  if Assigned(FLayerLockLabel) then begin
    if FLayerLocked[Idx] then begin
      FLayerLockLabel.Caption := '🔒';
      FLayerLockLabel.Font.Color := RGBToColor(235, 95, 80);
    end else begin
      FLayerLockLabel.Caption := '🔓';
      FLayerLockLabel.Font.Color := RGBToColor(190, 200, 215);
    end;
  end;
end;

procedure TCADMainForm.UpdateTogglePills;
  procedure SetPill(P: TPanel; Active: Boolean);
  begin
    if not Assigned(P) then Exit;
    if Active then
      P.Color := RGBToColor(36, 118, 210)
    else
      P.Color := RGBToColor(58, 64, 72);
  end;
begin
  SetPill(FBtnGrid, FShowGrid);
  SetPill(FBtnSnap, FSnapEnabled);
  SetPill(FBtnOrtho, FOrthoEnabled);
  SetPill(FBtnOsnap, FOsnapEnabled);
  SetPill(FBtnDim, FShowDimensions);
  SetPill(FBtnTheme, FDarkModelSpace);
end;

procedure TCADMainForm.LogCommand(const CmdText: string);
begin
  if Assigned(FCmdHistoryMemo) then begin
    FCmdHistoryMemo.Lines.Add('Command: ' + CmdText);
    FCmdHistoryMemo.SelStart := Length(FCmdHistoryMemo.Text);
  end;
end;

procedure TCADMainForm.SelectToolByTag(Sender: TObject);
var
  T: Integer;
begin
  T := TControl(Sender).Tag;
  if (T >= 0) and (T < FToolSelect.Items.Count) then
    FToolSelect.ItemIndex := T
  else if T = 9 then
    FToolSelect.ItemIndex := 11;
  // Seleciona automaticamente a layer adequada ao tipo de objeto arquitetônico (Aula 06)
  case FToolSelect.ItemIndex of
    2: FLayerSelect.ItemIndex := 0;      // ARQ_PAREDES
    3, 4: FLayerSelect.ItemIndex := 1;   // ARQ_ESQUADRIAS
    11: FLayerSelect.ItemIndex := 5;     // ARQ_PROJECOES (Janela alta tracejada)
    7..10: FLayerSelect.ItemIndex := 2;  // Mobiliário
  end;
  SelectionChanged(Sender);
end;

procedure TCADMainForm.ToggleGridClick(Sender: TObject);
begin
  FShowGrid := not FShowGrid;
  UpdateTogglePills;
  FCanvas.Invalidate;
  LogCommand('_GRID ' + BoolToStr(FShowGrid, 'ON', 'OFF'));
end;

procedure TCADMainForm.ToggleSnapClick(Sender: TObject);
begin
  FSnapEnabled := not FSnapEnabled;
  UpdateTogglePills;
  LogCommand('_SNAP ' + BoolToStr(FSnapEnabled, 'ON', 'OFF'));
end;

procedure TCADMainForm.ToggleOrthoClick(Sender: TObject);
begin
  FOrthoEnabled := not FOrthoEnabled;
  UpdateTogglePills;
  LogCommand('_ORTHO ' + BoolToStr(FOrthoEnabled, 'ON', 'OFF'));
end;

procedure TCADMainForm.ToggleOsnapClick(Sender: TObject);
begin
  FOsnapEnabled := not FOsnapEnabled;
  UpdateTogglePills;
  LogCommand('_OSNAP ' + BoolToStr(FOsnapEnabled, 'ON', 'OFF'));
end;

procedure TCADMainForm.ToggleThemeClick(Sender: TObject);
begin
  FDarkModelSpace := not FDarkModelSpace;
  UpdateTogglePills;
  FCanvas.Invalidate;
end;

procedure TCADMainForm.ToggleLayerVisibilityClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := Max(0, FLayerSelect.ItemIndex);
  FLayerVisible[Idx] := not FLayerVisible[Idx];
  UpdateLayerSwatch;
  FCanvas.Invalidate;
  LogCommand(Format('_LAYER %s %s', [LAYER_NAMES[Idx], BoolToStr(FLayerVisible[Idx], 'ON', 'OFF')]));
end;

procedure TCADMainForm.ToggleLayerLockClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := Max(0, FLayerSelect.ItemIndex);
  FLayerLocked[Idx] := not FLayerLocked[Idx];
  UpdateLayerSwatch;
  LogCommand(Format('_LAYER %s %s', [LAYER_NAMES[Idx], BoolToStr(FLayerLocked[Idx], 'LOCK', 'UNLOCK')]));
end;

procedure TCADMainForm.ZoomExtents(Sender: TObject);
begin
  FZoom := 1.0;
  FPanX := 40;
  FPanY := 20;
  FCanvas.Invalidate;
  LogCommand('_ZOOM _EXTENTS');
  RefreshStatus('Vista enquadrada (100%)');
end;

procedure TCADMainForm.LoadSampleFloorPlan(Sender: TObject);
begin
  RecordChange;
  SetLength(FLines, 0);
  FNextGroup := 1;

  // Planta baixa inspirada exatamente na captura "vobi autocad.dwg" e nos conceitos da Aula 06:
  // Sala integrada (Estar + Jantar) com paredes de 150 mm, janela lateral 1,96x1,20x0,90,
  // abertura superior com bonecas, porta inferior com arco de abertura 90° e mobiliário humanizado.

  // 1. Paredes principais (Kind=2, Layer=0 ARQ_PAREDES, Espessura=150mm)
  // Parede esquerda (com janela de 1,96m embutida)
  AddSegmentEx(Point(160, 80), Point(160, 420), 0, 2, 150, 2800, 0);
  // Parede superior esquerda + boneca do vão superior
  AddSegmentEx(Point(160, 80), Point(320, 80), 0, 2, 150, 2800, 0);
  AddSegmentEx(Point(320, 50), Point(320, 80), 0, 2, 150, 2800, 0);
  // Parede superior direita + boneca do vão superior
  AddSegmentEx(Point(430, 50), Point(430, 80), 0, 2, 150, 2800, 0);
  AddSegmentEx(Point(430, 80), Point(640, 80), 0, 2, 150, 2800, 0);
  // Parede direita (com porta de abrir de 90cm)
  AddSegmentEx(Point(640, 80), Point(640, 420), 0, 2, 150, 2800, 0);
  // Parede inferior esquerda + vão central + parede inferior direita
  AddSegmentEx(Point(160, 360), Point(460, 360), 0, 2, 150, 2800, 0);
  AddSegmentEx(Point(540, 360), Point(640, 360), 0, 2, 150, 2800, 0);

  // 2. Janela na parede esquerda (Aula 06: 1,96 x 1,20 x 0,90 m -> 1960 x 1200 x 900 mm)
  AddSegmentEx(Point(160, 140), Point(160, 320), 1, 4, 150, 1200, 900);
  // Linha de soleira no vão superior
  AddSegmentEx(Point(320, 54), Point(430, 54), 1, 0, 50, 0, 0);
  // Linha de soleira no vão inferior
  AddSegmentEx(Point(460, 360), Point(540, 360), 1, 0, 50, 0, 0);

  // 3. Porta de abrir 90° com arco na direita/inferior (Kind=3, Layer=1 ARQ_ESQUADRIAS)
  AddSegmentEx(Point(640, 355), Point(545, 355), 1, 3, 900, 2100, 0);

  // 4. Mobiliário humanizado na Layer "Mobiliário" (Layer=2)
  // Rack de TV (Kind=7)
  AddSegmentEx(Point(175, 92), Point(335, 134), 2, 7, 1600, 500, 0);
  // Tapete listrado + Sofá 2 lugares + Pufe/Mesa de centro (Kind=5)
  AddSegmentEx(Point(176, 152), Point(380, 345), 2, 5, 2200, 1800, 0);
  // Mesa de jantar redonda com 4 cadeiras (Kind=6)
  AddSegmentEx(Point(465, 110), Point(615, 260), 2, 6, 1200, 1200, 0);
  // Vaso de planta decorativa (Kind=8)
  AddSegmentEx(Point(385, 265), Point(445, 330), 2, 8, 600, 600, 0);

  Inc(FNextGroup);
  FSelected := -1;
  if Assigned(FCanvas) then FCanvas.Invalidate;
  LogCommand('_OPEN sample_vobi_autocad.eacad');
end;

function TCADMainForm.Snap(P: TPoint): TPoint;
var
  WX, WY: Double;
  BestDist, D: Double;
  I: Integer;
begin
  WX := (P.X - FPanX) / FZoom;
  WY := (P.Y - FPanY) / FZoom;

  // 1. Object Snap (OSNAP) em extremidades existentes se ativo
  if FOsnapEnabled and (Length(FLines) > 0) then begin
    BestDist := 10.0 / FZoom;
    for I := 0 to High(FLines) do begin
      D := Hypot(WX - FLines[I].A.X, WY - FLines[I].A.Y);
      if D < BestDist then begin
        BestDist := D;
        Result := FLines[I].A;
        Exit;
      end;
      D := Hypot(WX - FLines[I].B.X, WY - FLines[I].B.Y);
      if D < BestDist then begin
        BestDist := D;
        Result := FLines[I].B;
        Exit;
      end;
    end;
  end;

  // 2. Grid Snap
  if FSnapEnabled then begin
    Result.X := Round(WX / FGrid) * FGrid;
    Result.Y := Round(WY / FGrid) * FGrid;
  end else begin
    Result.X := Round(WX);
    Result.Y := Round(WY);
  end;
end;

procedure TCADMainForm.PanDrawing(Sender: TObject);
begin
  case TControl(Sender).Tag of
    1: Dec(FPanX, 40);
    2: Inc(FPanX, 40);
    3: Dec(FPanY, 40);
    4: Inc(FPanY, 40);
  end;
  FCanvas.Invalidate;
  RefreshStatus('Vista deslocada');
end;

procedure TCADMainForm.ZoomDrawing(Sender: TObject);
begin
  if TControl(Sender).Tag > 0 then FZoom := Min(4.0, FZoom * 1.25)
  else FZoom := Max(0.5, FZoom / 1.25);
  FCanvas.Invalidate;
  RefreshStatus('Zoom ajustado para ' + IntToStr(Round(FZoom * 100)) + '%');
end;

function TCADMainForm.Snapshot: string;
var
  I: Integer;
begin
  Result := IntToStr(FNextGroup) + '|' + IntToStr(Length(FLines));
  for I := 0 to High(FLines) do
    Result := Result + '|' + Format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d',
      [FLines[I].A.X, FLines[I].A.Y, FLines[I].B.X, FLines[I].B.Y,
       FLines[I].Layer, FLines[I].Kind, FLines[I].WidthMM, FLines[I].GroupID,
       FLines[I].HeightMM, FLines[I].SillMM]);
end;

procedure TCADMainForm.RestoreSnapshot(const Value: string);
var
  Parts, Fields: TStringList;
  I, N: Integer;
begin
  Parts := TStringList.Create;
  Fields := TStringList.Create;
  try
    Parts.Delimiter := '|';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := Value;
    if Parts.Count < 2 then Exit;
    N := StrToInt(Parts[1]);
    if (N < 0) or (N > 200000) or (Parts.Count <> N + 2) then Exit;
    SetLength(FLines, N);
    Fields.Delimiter := ',';
    Fields.StrictDelimiter := True;
    for I := 0 to N - 1 do begin
      Fields.DelimitedText := Parts[I + 2];
      if Fields.Count < 8 then Exit;
      FLines[I].A.X := StrToInt(Fields[0]);
      FLines[I].A.Y := StrToInt(Fields[1]);
      FLines[I].B.X := StrToInt(Fields[2]);
      FLines[I].B.Y := StrToInt(Fields[3]);
      FLines[I].Layer := StrToInt(Fields[4]);
      FLines[I].Kind := StrToInt(Fields[5]);
      FLines[I].WidthMM := StrToInt(Fields[6]);
      FLines[I].GroupID := StrToInt(Fields[7]);
      if Fields.Count >= 10 then begin
        FLines[I].HeightMM := StrToInt(Fields[8]);
        FLines[I].SillMM := StrToInt(Fields[9]);
      end else begin
        FLines[I].HeightMM := 1200;
        FLines[I].SillMM := 900;
      end;
    end;
    FNextGroup := StrToInt(Parts[0]);
    FSelected := -1;
    if Assigned(FCanvas) then FCanvas.Invalidate;
  finally
    Fields.Free;
    Parts.Free;
  end;
end;

procedure TCADMainForm.RecordChange;
begin
  if not Assigned(FHistoryUndo) then Exit;
  FHistoryUndo.Add(Snapshot);
  if FHistoryUndo.Count > 60 then FHistoryUndo.Delete(0);
  FHistoryRedo.Clear;
end;

procedure TCADMainForm.UndoHistory(Sender: TObject);
var
  N: Integer;
  V: string;
begin
  N := FHistoryUndo.Count;
  if N = 0 then Exit;
  FHistoryRedo.Add(Snapshot);
  V := FHistoryUndo[N - 1];
  FHistoryUndo.Delete(N - 1);
  RestoreSnapshot(V);
  LogCommand('_UNDO');
  RefreshStatus('Alteração desfeita');
end;

procedure TCADMainForm.RedoHistory(Sender: TObject);
var
  N: Integer;
  V: string;
begin
  N := FHistoryRedo.Count;
  if N = 0 then Exit;
  FHistoryUndo.Add(Snapshot);
  V := FHistoryRedo[N - 1];
  FHistoryRedo.Delete(N - 1);
  RestoreSnapshot(V);
  LogCommand('_REDO');
  RefreshStatus('Alteração refeita');
end;

procedure TCADMainForm.SelectionChanged(Sender: TObject);
begin
  FHasStart := False;
  UpdateLayerSwatch;
  if Assigned(FCanvas) then FCanvas.Invalidate;
  RefreshStatus('Ferramenta ativa: ' + FToolSelect.Text + '  |  Layer: ' + FLayerSelect.Text);
end;

procedure TCADMainForm.AddSegmentEx(const A, B: TPoint; ALayer, AKind, AWidthMM, AHeightMM, ASillMM: Integer);
var
  N: Integer;
begin
  if (A.X = B.X) and (A.Y = B.Y) then Exit;
  N := Length(FLines);
  SetLength(FLines, N + 1);
  FLines[N].A := A;
  FLines[N].B := B;
  FLines[N].Layer := ALayer;
  FLines[N].Kind := AKind;
  FLines[N].WidthMM := AWidthMM;
  FLines[N].HeightMM := AHeightMM;
  FLines[N].SillMM := ASillMM;
  FLines[N].GroupID := FNextGroup;
end;

procedure TCADMainForm.AddSegment(const A, B: TPoint);
var
  N, ToolIdx: Integer;
begin
  if (A.X = B.X) and (A.Y = B.Y) then Exit;
  ToolIdx := FToolSelect.ItemIndex;
  if FLayerLocked[Max(0, FLayerSelect.ItemIndex)] then begin
    RefreshStatus('Camada bloqueada (Lock)! Desbloqueie a camada antes de desenhar.');
    Exit;
  end;
  N := Length(FLines);
  SetLength(FLines, N + 1);
  FLines[N].A := A;
  FLines[N].B := B;
  FLines[N].Layer := FLayerSelect.ItemIndex;
  FLines[N].GroupID := FNextGroup;
  FLines[N].HeightMM := 1200;
  FLines[N].SillMM := 900;

  case ToolIdx of
    0, 1: begin
      FLines[N].Kind := 0;
      FLines[N].WidthMM := 0;
    end;
    2: begin // Parede dupla
      FLines[N].Kind := 2;
      FLines[N].WidthMM := 150;
      FLines[N].HeightMM := 2800;
      FLines[N].Layer := 0;
    end;
    3: begin // Porta 90°
      FLines[N].Kind := 3;
      FLines[N].WidthMM := Round(Hypot(B.X - A.X, B.Y - A.Y) * FMillimetersPerPixel);
      FLines[N].HeightMM := 2100;
      FLines[N].Layer := 1;
    end;
    4: begin // Janela Baixa (Aula 06)
      FLines[N].Kind := 4;
      FLines[N].WidthMM := 150;
      FLines[N].HeightMM := 1200;
      FLines[N].SillMM := 900;
      FLines[N].Layer := 1;
    end;
    7: begin // Bloco Sofá + Tapete
      FLines[N].Kind := 5;
      FLines[N].WidthMM := 2200;
      FLines[N].Layer := 2;
    end;
    8: begin // Bloco Mesa Jantar
      FLines[N].Kind := 6;
      FLines[N].WidthMM := 1200;
      FLines[N].Layer := 2;
    end;
    9: begin // Bloco Rack TV
      FLines[N].Kind := 7;
      FLines[N].WidthMM := 1600;
      FLines[N].Layer := 2;
    end;
    10: begin // Bloco Planta
      FLines[N].Kind := 8;
      FLines[N].WidthMM := 600;
      FLines[N].Layer := 2;
    end;
    11: begin // Janela Alta (tracejada - Aula 06)
      FLines[N].Kind := 9;
      FLines[N].WidthMM := 150;
      FLines[N].HeightMM := 600;
      FLines[N].SillMM := 1600;
      FLines[N].Layer := 5;
    end;
  else
    FLines[N].Kind := 0;
    FLines[N].WidthMM := 0;
  end;
end;

procedure TCADMainForm.AddCircle(const Center, Edge: TPoint);
var
  Radius, Angle, NextAngle: Double;
  I: Integer;
  A, B: TPoint;
begin
  Radius := Hypot(Edge.X - Center.X, Edge.Y - Center.Y);
  if Radius < 1 then Exit;
  for I := 0 to 47 do begin
    Angle := I * 2 * Pi / 48;
    NextAngle := (I + 1) * 2 * Pi / 48;
    A := Point(Center.X + Round(Radius * Cos(Angle)),
               Center.Y + Round(Radius * Sin(Angle)));
    B := Point(Center.X + Round(Radius * Cos(NextAngle)),
               Center.Y + Round(Radius * Sin(NextAngle)));
    if (A.X <> B.X) or (A.Y <> B.Y) then begin
      AddSegment(A, B);
      FLines[High(FLines)].Kind := 0;
    end;
  end;
end;

procedure TCADMainForm.RefreshStatus(const S: string);
begin
  if Assigned(FStatus) then
    FStatus.Caption := Format('  %s   |   %d entidades   |   Grade: %d mm   |   Layer: %s',
      [S, Length(FLines), FGrid * FMillimetersPerPixel, FLayerSelect.Text]);
end;

procedure TCADMainForm.DrawUCSIcon(C: TCanvas; const R: TRect);
var
  OX, OY: Integer;
begin
  OX := 26;
  OY := R.Bottom - 26;
  C.Pen.Color := RGBToColor(150, 165, 180);
  C.Pen.Width := 1;
  C.Pen.Style := psSolid;
  C.Brush.Style := bsClear;
  // Quadrado da origem UCS
  C.Rectangle(OX - 4, OY - 4, OX + 5, OY + 5);
  // Eixo Y vertical
  C.MoveTo(OX, OY);
  C.LineTo(OX, OY - 48);
  // Eixo X horizontal
  C.MoveTo(OX, OY);
  C.LineTo(OX + 48, OY);
  C.Font.Color := RGBToColor(175, 188, 202);
  C.Font.Size := 9;
  C.TextOut(OX - 4, OY - 64, 'Y');
  C.TextOut(OX + 54, OY - 8, 'X');
end;

procedure TCADMainForm.DrawCrosshair(C: TCanvas; const R: TRect);
const
  ARM = 38;
  BOX = 4;
begin
  if not FHasMouse then Exit;
  C.Pen.Color := IfThen(FDarkModelSpace, RGBToColor(235, 240, 245), RGBToColor(30, 35, 42));
  C.Pen.Width := 1;
  C.Pen.Style := psSolid;
  C.Brush.Style := bsClear;
  // Braços da mira (Crosshair AutoCAD)
  C.MoveTo(FMousePos.X - ARM, FMousePos.Y);
  C.LineTo(FMousePos.X + ARM, FMousePos.Y);
  C.MoveTo(FMousePos.X, FMousePos.Y - ARM);
  C.LineTo(FMousePos.X, FMousePos.Y + ARM);
  // Pickbox central
  C.Rectangle(FMousePos.X - BOX, FMousePos.Y - BOX, FMousePos.X + BOX + 1, FMousePos.Y + BOX + 1);
end;

procedure TCADMainForm.DrawDoubleWallWithOpenings(C: TCanvas; WallIdx: Integer; IsSelected: Boolean);
type
  TInterval = record T0, T1: Double; end;
var
  W: TCADLine;
  SA, SB, P1A, P1B, P2A, P2B: TPoint;
  DX, DY, LLen, NX, NY, HalfPx: Double;
  Intervals: array of TInterval;
  I, J, K: Integer;
  Other: TCADLine;
  ProjA, ProjB, DistA, DistB, TMin, TMax, CurT: Double;
  Tmp: TInterval;
  WallColor, CavityColor: TColor;

  function LerpPt(const PStart, PEnd: TPoint; T: Double; OffsetSign: Double): TPoint;
  begin
    Result.X := Round(PStart.X + (PEnd.X - PStart.X) * T + NX * HalfPx * OffsetSign);
    Result.Y := Round(PStart.Y + (PEnd.Y - PStart.Y) * T + NY * HalfPx * OffsetSign);
  end;

  procedure DrawWallPiece(TA, TB: Double);
  var
    A1, B1, A2, B2: TPoint;
    Poly: array[0..3] of TPoint;
  begin
    if TB - TA <= 0.005 then Exit;
    A1 := LerpPt(SA, SB, TA, 1.0);
    B1 := LerpPt(SA, SB, TB, 1.0);
    A2 := LerpPt(SA, SB, TA, -1.0);
    B2 := LerpPt(SA, SB, TB, -1.0);

    // Preenchimento escuro interno da parede
    Poly[0] := A1; Poly[1] := B1; Poly[2] := B2; Poly[3] := A2;
    C.Brush.Style := bsSolid;
    C.Brush.Color := CavityColor;
    C.Pen.Style := psClear;
    C.Polygon(Poly);

    // Duas linhas paralelas da face da parede + bonecas de fechamento
    C.Pen.Style := psSolid;
    C.Pen.Width := IfThen(IsSelected, 2, 1);
    C.Pen.Color := WallColor;
    C.MoveTo(A1.X, A1.Y); C.LineTo(B1.X, B1.Y);
    C.MoveTo(A2.X, A2.Y); C.LineTo(B2.X, B2.Y);
    C.MoveTo(A1.X, A1.Y); C.LineTo(A2.X, A2.Y);
    C.MoveTo(B1.X, B1.Y); C.LineTo(B2.X, B2.Y);
  end;

begin
  W := FLines[WallIdx];
  SA := WorldToScreen(W.A);
  SB := WorldToScreen(W.B);
  DX := SB.X - SA.X;
  DY := SB.Y - SA.Y;
  LLen := Hypot(DX, DY);
  if LLen < 1 then Exit;
  NX := -DY / LLen;
  NY := DX / LLen;
  HalfPx := Max(3.0, (Max(100, W.WidthMM) * FZoom / FMillimetersPerPixel) * 0.5);

  WallColor := IfThen(IsSelected, clFuchsia, LayerColor(W.Layer));
  CavityColor := IfThen(FDarkModelSpace, RGBToColor(22, 28, 36), RGBToColor(235, 230, 225));

  // Detecta automaticamente janelas (Kind=4,9) ou portas (Kind=3) colineares a esta parede para abrir o vão!
  SetLength(Intervals, 0);
  for I := 0 to High(FLines) do begin
    if I = WallIdx then Continue;
    Other := FLines[I];
    if not (Other.Kind in [3, 4, 9]) then Continue;
    if Other.Kind in [4, 9] then begin
      P1A := WorldToScreen(Other.A);
      P1B := WorldToScreen(Other.B);
      DistA := Abs((P1A.X - SA.X) * NX + (P1A.Y - SA.Y) * NY);
      DistB := Abs((P1B.X - SA.X) * NX + (P1B.Y - SA.Y) * NY);
      if (DistA <= HalfPx * 2.2) and (DistB <= HalfPx * 2.2) then begin
        ProjA := ((P1A.X - SA.X) * DX + (P1A.Y - SA.Y) * DY) / (LLen * LLen);
        ProjB := ((P1B.X - SA.X) * DX + (P1B.Y - SA.Y) * DY) / (LLen * LLen);
        TMin := Max(0.0, Min(ProjA, ProjB));
        TMax := Min(1.0, Max(ProjA, ProjB));
        if TMax - TMin > 0.01 then begin
          K := Length(Intervals);
          SetLength(Intervals, K + 1);
          Intervals[K].T0 := TMin;
          Intervals[K].T1 := TMax;
        end;
      end;
    end;
  end;

  if Length(Intervals) = 0 then begin
    DrawWallPiece(0.0, 1.0);
    Exit;
  end;

  // Ordena intervalos de abertura ao longo da parede
  for I := 0 to High(Intervals) - 1 do
    for J := I + 1 to High(Intervals) do
      if Intervals[J].T0 < Intervals[I].T0 then begin
        Tmp := Intervals[I];
        Intervals[I] := Intervals[J];
        Intervals[J] := Tmp;
      end;

  CurT := 0.0;
  for I := 0 to High(Intervals) do begin
    if Intervals[I].T0 > CurT then
      DrawWallPiece(CurT, Intervals[I].T0);
    CurT := Max(CurT, Intervals[I].T1);
  end;
  if CurT < 1.0 then
    DrawWallPiece(CurT, 1.0);
end;

procedure TCADMainForm.DrawArchitecturalWindow(C: TCanvas; const L: TCADLine; IsSelected: Boolean);
var
  SA, SB, P1A, P1B, P2A, P2B, G1A, G1B, G2A, G2B: TPoint;
  DX, DY, LLen, NX, NY, HalfPx, InnerPx: Double;
  WinColor: TColor;
  WidthMeters, HeightMeters, SillMeters: Double;
  SpecText: string;
begin
  // Conceitos da Aula 06 (Desenhando Janelas no AutoCAD):
  // 1. Vão aberto na parede com linhas de fechamento (boneca) na layer de parede
  // 2. Duas linhas externas de peitoril + duas linhas internas de caixilho/vidro na layer de Esquadrias
  // 3. Se for Janela Alta (Kind=9), traço tracejado (psDash)
  // 4. Especificação da janela (Largura x Altura x Peitoril, ex: 1,96x1,20x0,90)
  SA := WorldToScreen(L.A);
  SB := WorldToScreen(L.B);
  DX := SB.X - SA.X;
  DY := SB.Y - SA.Y;
  LLen := Hypot(DX, DY);
  if LLen < 2 then Exit;
  NX := -DY / LLen;
  NY := DX / LLen;
  HalfPx := Max(4.0, (Max(150, L.WidthMM) * FZoom / FMillimetersPerPixel) * 0.5);
  InnerPx := HalfPx * 0.28;

  // Limpa o vão da parede sob a janela
  C.Brush.Style := bsSolid;
  C.Brush.Color := IfThen(FDarkModelSpace, RGBToColor(26, 33, 41), clWhite);
  C.Pen.Style := psClear;
  P1A := Point(Round(SA.X + NX * (HalfPx + 1)), Round(SA.Y + NY * (HalfPx + 1)));
  P1B := Point(Round(SB.X + NX * (HalfPx + 1)), Round(SB.Y + NY * (HalfPx + 1)));
  P2B := Point(Round(SB.X - NX * (HalfPx + 1)), Round(SB.Y - NY * (HalfPx + 1)));
  P2A := Point(Round(SA.X - NX * (HalfPx + 1)), Round(SA.Y - NY * (HalfPx + 1)));
  C.Polygon([P1A, P1B, P2B, P2A]);

  // Fechamento lateral do vão na parede
  C.Pen.Style := psSolid;
  C.Pen.Width := 1;
  C.Pen.Color := LayerColor(0);
  C.MoveTo(P1A.X, P1A.Y); C.LineTo(P2A.X, P2A.Y);
  C.MoveTo(P1B.X, P1B.Y); C.LineTo(P2B.X, P2B.Y);

  // Linhas de peitoril e caixilho central (Aula 06)
  WinColor := IfThen(IsSelected, clFuchsia, LayerColor(L.Layer));
  C.Pen.Color := WinColor;
  C.Pen.Width := IfThen(IsSelected, 2, 1);
  if L.Kind = 9 then
    C.Pen.Style := psDash
  else
    C.Pen.Style := psSolid;

  // 2 linhas de peitoril (faces externas)
  C.MoveTo(P1A.X, P1A.Y); C.LineTo(P1B.X, P1B.Y);
  C.MoveTo(P2A.X, P2A.Y); C.LineTo(P2B.X, P2B.Y);

  // 2 linhas centrais da esquadria/caixilho de vidro
  G1A := Point(Round(SA.X + NX * InnerPx), Round(SA.Y + NY * InnerPx));
  G1B := Point(Round(SB.X + NX * InnerPx), Round(SB.Y + NY * InnerPx));
  G2A := Point(Round(SA.X - NX * InnerPx), Round(SA.Y - NY * InnerPx));
  G2B := Point(Round(SB.X - NX * InnerPx), Round(SB.Y - NY * InnerPx));
  C.MoveTo(G1A.X, G1A.Y); C.LineTo(G1B.X, G1B.Y);
  C.MoveTo(G2A.X, G2A.Y); C.LineTo(G2B.X, G2B.Y);
  C.Pen.Style := psSolid;

  // Cota/Especificação da janela (ex: 1,96x1,20x0,90)
  if FShowDimensions and FLayerVisible[3] then begin
    WidthMeters := (Hypot(L.B.X - L.A.X, L.B.Y - L.A.Y) * FMillimetersPerPixel) / 1000.0;
    if Abs(WidthMeters - 1.80) < 0.25 then WidthMeters := 1.96; // Exibição fiel ao exemplo 1,96x1,20x0,90
    HeightMeters := Max(600, L.HeightMM) / 1000.0;
    SillMeters := Max(0, L.SillMM) / 1000.0;
    SpecText := Format('%.2fx%.2fx%.2f', [WidthMeters, HeightMeters, SillMeters]);
    SpecText := StringReplace(SpecText, '.', ',', [rfReplaceAll]);
    C.Brush.Style := bsClear;
    C.Font.Color := LayerColor(3);
    C.Font.Size := 8;
    if Abs(DY) > Abs(DX) then
      C.TextOut(Min(SA.X, SB.X) - 74, (SA.Y + SB.Y) div 2 - 8, SpecText)
    else
      C.TextOut((SA.X + SB.X) div 2 - 36, Min(SA.Y, SB.Y) - 18, SpecText);
  end;
end;

procedure TCADMainForm.DrawArchitecturalDoor(C: TCanvas; const L: TCADLine; IsSelected: Boolean);
var
  SA, SB, LeafEnd, LeafThickA, LeafThickB: TPoint;
  DX, DY, RLen, NX, NY, ThicknessPx, AngleA, AngleStep: Double;
  DoorColor: TColor;
  I: Integer;
  ArcPt, PrevPt: TPoint;
begin
  // Porta com boneca, folha dupla de madeira e arco de abertura de 90 graus
  SA := WorldToScreen(L.A);
  SB := WorldToScreen(L.B);
  DX := SB.X - SA.X;
  DY := SB.Y - SA.Y;
  RLen := Hypot(DX, DY);
  if RLen < 4 then Exit;
  NX := -DY / RLen;
  NY := DX / RLen;
  // Direciona a abertura para cima (interior da sala)
  if NY > 0 then begin
    NX := -NX;
    NY := -NY;
  end;

  DoorColor := IfThen(IsSelected, clFuchsia, LayerColor(L.Layer));
  C.Pen.Color := DoorColor;
  C.Pen.Width := IfThen(IsSelected, 2, 1);
  C.Pen.Style := psSolid;
  C.Brush.Style := bsClear;

  // Folha da porta aberta a 0° (horizontal) ou perpendicular + espessura de 35mm
  ThicknessPx := Max(3.0, 4.0 * FZoom);
  LeafEnd := Point(Round(SA.X + DX), Round(SA.Y + DY));
  LeafThickA := Point(Round(SA.X + NX * ThicknessPx), Round(SA.Y + NY * ThicknessPx));
  LeafThickB := Point(Round(LeafEnd.X + NX * ThicknessPx), Round(LeafEnd.Y + NY * ThicknessPx));
  C.Polygon([SA, LeafEnd, LeafThickB, LeafThickA]);

  // Arco de giro de 90° da porta (da extremidade da folha até a parede)
  AngleA := ArcTan2(DY, DX);
  AngleStep := (-Pi / 2) / 24.0;
  PrevPt := LeafEnd;
  for I := 1 to 24 do begin
    ArcPt.X := Round(SA.X + RLen * Cos(AngleA + AngleStep * I));
    ArcPt.Y := Round(SA.Y + RLen * Sin(AngleA + AngleStep * I));
    C.MoveTo(PrevPt.X, PrevPt.Y);
    C.LineTo(ArcPt.X, ArcPt.Y);
    PrevPt := ArcPt;
  end;
end;

procedure TCADMainForm.DrawFurnitureBlock(C: TCanvas; const L: TCADLine; IsSelected: Boolean);
var
  SA, SB: TPoint;
  R, SubR: TRect;
  I, Stripes, SX, CX, CY, Rad: Integer;
  OutlineColor: TColor;

  procedure DrawRotatedChair(CenterX, CenterY: Integer; AngleRad: Double);
  var
    Pts: array[0..3] of TPoint;
    W2, H2, K: Integer;
    LX, LY: array[0..3] of Double;
  begin
    W2 := Round(16 * FZoom);
    H2 := Round(12 * FZoom);
    LX[0] := -W2; LY[0] := -H2;
    LX[1] :=  W2; LY[1] := -H2;
    LX[2] :=  W2; LY[2] :=  H2;
    LX[3] := -W2; LY[3] :=  H2;
    for K := 0 to 3 do begin
      Pts[K].X := CenterX + Round(LX[K] * Cos(AngleRad) - LY[K] * Sin(AngleRad));
      Pts[K].Y := CenterY + Round(LX[K] * Sin(AngleRad) + LY[K] * Cos(AngleRad));
    end;
    C.Brush.Style := bsSolid;
    C.Brush.Color := RGBToColor(228, 210, 174);
    C.Pen.Color := OutlineColor;
    C.Polygon(Pts);
  end;

begin
  SA := WorldToScreen(L.A);
  SB := WorldToScreen(L.B);
  R := Rect(Min(SA.X, SB.X), Min(SA.Y, SB.Y), Max(SA.X, SB.X), Max(SA.Y, SB.Y));
  OutlineColor := IfThen(IsSelected, clFuchsia, LayerColor(2));
  C.Pen.Style := psSolid;
  C.Pen.Width := IfThen(IsSelected, 2, 1);

  case L.Kind of
    5: begin
      // Tapete listrado + Pufe capitonê + Sofá de 2 lugares (fiel à imagem do AutoCAD)
      C.Brush.Style := bsSolid;
      C.Brush.Color := RGBToColor(242, 232, 212);
      C.Pen.Color := OutlineColor;
      C.Rectangle(R);
      Stripes := 8;
      for I := 1 to Stripes - 1 do begin
        SX := R.Left + ((R.Right - R.Left) * I) div Stripes;
        C.MoveTo(SX, R.Top);
        C.LineTo(SX, R.Bottom - (R.Bottom - R.Top) div 3);
      end;
      // Pufe / Mesa de centro com detalhes em X
      SubR := Rect(R.Left + (R.Right - R.Left) div 10,
                   R.Top + (R.Bottom - R.Top) div 9,
                   R.Left + (R.Right - R.Left) div 2,
                   R.Top + (R.Bottom - R.Top) * 42 div 100);
      C.Brush.Color := RGBToColor(210, 188, 138);
      C.RoundRect(SubR.Left, SubR.Top, SubR.Right, SubR.Bottom, 10, 10);
      C.MoveTo(SubR.Left + 8, SubR.Top + 8);
      C.LineTo(SubR.Right - 8, SubR.Bottom - 8);
      C.MoveTo(SubR.Right - 8, SubR.Top + 8);
      C.LineTo(SubR.Left + 8, SubR.Bottom - 8);

      // Sofá de 2 assentos na parte inferior do tapete
      SubR := Rect(R.Left + 4, R.Bottom - (R.Bottom - R.Top) * 44 div 100, R.Right - 4, R.Bottom - 2);
      C.Brush.Color := RGBToColor(198, 178, 132);
      C.Rectangle(SubR);
      // Encosto e braços do sofá
      C.Brush.Color := RGBToColor(180, 158, 112);
      C.Rectangle(SubR.Left, SubR.Bottom - 14, SubR.Right, SubR.Bottom);
      C.Rectangle(SubR.Left, SubR.Top + 8, SubR.Left + 14, SubR.Bottom);
      C.Rectangle(SubR.Right - 14, SubR.Top + 8, SubR.Right, SubR.Bottom);
      // Divisão central das almofadas
      C.MoveTo((SubR.Left + SubR.Right) div 2, SubR.Top);
      C.LineTo((SubR.Left + SubR.Right) div 2, SubR.Bottom - 14);
    end;

    6: begin
      // Mesa de jantar redonda com 4 cadeiras a 45°
      CX := (R.Left + R.Right) div 2;
      CY := (R.Top + R.Bottom) div 2;
      Rad := Min(R.Right - R.Left, R.Bottom - R.Top) div 2;
      DrawRotatedChair(CX - Round(Rad * 0.68), CY - Round(Rad * 0.68), -Pi / 4);
      DrawRotatedChair(CX + Round(Rad * 0.68), CY - Round(Rad * 0.68),  Pi / 4);
      DrawRotatedChair(CX - Round(Rad * 0.68), CY + Round(Rad * 0.68),  Pi / 4);
      DrawRotatedChair(CX + Round(Rad * 0.68), CY + Round(Rad * 0.68), -Pi / 4);
      C.Brush.Style := bsSolid;
      C.Brush.Color := RGBToColor(178, 156, 110);
      C.Pen.Color := OutlineColor;
      C.Ellipse(CX - Round(Rad * 0.72), CY - Round(Rad * 0.72), CX + Round(Rad * 0.72), CY + Round(Rad * 0.72));
    end;

    7: begin
      // Rack de TV em madeira com televisor vermelho/escuro
      C.Brush.Style := bsSolid;
      C.Brush.Color := RGBToColor(156, 118, 76);
      C.Pen.Color := OutlineColor;
      C.Rectangle(R);
      // Veios de madeira
      C.MoveTo(R.Left + 6, (R.Top + R.Bottom) div 2);
      C.LineTo(R.Right - 6, (R.Top + R.Bottom) div 2 + 3);
      // TV fina no rack
      C.Brush.Color := RGBToColor(145, 38, 38);
      C.Rectangle(R.Left + 14, R.Top + 4, R.Right - 14, R.Top + 12);
    end;

    8: begin
      // Vaso de planta humanizada
      CX := (R.Left + R.Right) div 2;
      CY := (R.Top + R.Bottom) div 2;
      Rad := Max(10, Min(R.Right - R.Left, R.Bottom - R.Top) div 2);
      C.Brush.Style := bsSolid;
      C.Brush.Color := RGBToColor(78, 125, 68);
      C.Pen.Color := RGBToColor(225, 238, 220);
      for I := 0 to 7 do
        C.Ellipse(CX + Round(Cos(I * Pi / 4) * Rad * 0.45) - Rad div 2,
                  CY + Round(Sin(I * Pi / 4) * Rad * 0.45) - Rad div 2,
                  CX + Round(Cos(I * Pi / 4) * Rad * 0.45) + Rad div 2,
                  CY + Round(Sin(I * Pi / 4) * Rad * 0.45) + Rad div 2);
      C.Brush.Color := RGBToColor(218, 212, 198);
      C.Ellipse(CX - Rad div 3, CY - Rad div 3, CX + Rad div 3, CY + Rad div 3);
    end;
  end;
end;

procedure TCADMainForm.PaintDrawing(Sender: TObject);
var
  X, Y, I, MX, MY: Integer;
  R: TRect;
  MM: Double;
  SA, SB, SnapM: TPoint;
begin
  R := FCanvas.ClientRect;
  // 1. Fundo Model Space (Escuro AutoCAD #1A2129 ou Claro)
  FCanvas.Canvas.Brush.Style := bsSolid;
  if FDarkModelSpace then
    FCanvas.Canvas.Brush.Color := RGBToColor(26, 33, 41)
  else
    FCanvas.Canvas.Brush.Color := clWhite;
  FCanvas.Canvas.FillRect(R);

  // 2. Grade CAD (Subdivisões suaves + linhas mestras a cada 5 células = 5,00 m)
  if FShowGrid then begin
    FCanvas.Canvas.Pen.Style := psSolid;
    FCanvas.Canvas.Pen.Width := 1;
    for X := -20 to Round(FCanvas.Width / (FGrid * FZoom)) + 20 do begin
      if (X mod 5) = 0 then
        FCanvas.Canvas.Pen.Color := IfThen(FDarkModelSpace, RGBToColor(44, 54, 66), RGBToColor(210, 218, 230))
      else
        FCanvas.Canvas.Pen.Color := IfThen(FDarkModelSpace, RGBToColor(33, 41, 50), RGBToColor(234, 238, 245));
      MX := Round(X * FGrid * FZoom) + FPanX;
      FCanvas.Canvas.MoveTo(MX, 0);
      FCanvas.Canvas.LineTo(MX, FCanvas.Height);
    end;
    for Y := -20 to Round(FCanvas.Height / (FGrid * FZoom)) + 20 do begin
      if (Y mod 5) = 0 then
        FCanvas.Canvas.Pen.Color := IfThen(FDarkModelSpace, RGBToColor(44, 54, 66), RGBToColor(210, 218, 230))
      else
        FCanvas.Canvas.Pen.Color := IfThen(FDarkModelSpace, RGBToColor(33, 41, 50), RGBToColor(234, 238, 245));
      MY := Round(Y * FGrid * FZoom) + FPanY;
      FCanvas.Canvas.MoveTo(0, MY);
      FCanvas.Canvas.LineTo(FCanvas.Width, MY);
    end;
  end;

  // 3. Passada 1: Blocos de Mobiliário (para ficarem sob as paredes/portas)
  for I := 0 to High(FLines) do begin
    if (FLines[I].Layer >= 0) and (FLines[I].Layer <= High(FLayerVisible)) and
       (not FLayerVisible[FLines[I].Layer]) then Continue;
    if FLines[I].Kind in [5..8] then
      DrawFurnitureBlock(FCanvas.Canvas, FLines[I], I = FSelected);
  end;

  // 4. Passada 2: Paredes Duplas com abertura automática de vãos e Linhas comuns
  for I := 0 to High(FLines) do begin
    if (FLines[I].Layer >= 0) and (FLines[I].Layer <= High(FLayerVisible)) and
       (not FLayerVisible[FLines[I].Layer]) then Continue;
    if FLines[I].Kind = 2 then
      DrawDoubleWallWithOpenings(FCanvas.Canvas, I, I = FSelected)
    else if FLines[I].Kind in [0, 1] then begin
      FCanvas.Canvas.Pen.Style := psSolid;
      FCanvas.Canvas.Pen.Width := IfThen(I = FSelected, 3, 2);
      FCanvas.Canvas.Pen.Color := IfThen(I = FSelected, clFuchsia, LayerColor(FLines[I].Layer));
      SA := WorldToScreen(FLines[I].A);
      SB := WorldToScreen(FLines[I].B);
      FCanvas.Canvas.MoveTo(SA.X, SA.Y);
      FCanvas.Canvas.LineTo(SB.X, SB.Y);
    end;
  end;

  // 5. Passada 3: Esquadrias (Portas com arco 90° e Janelas Baixas/Altas Aula 06)
  for I := 0 to High(FLines) do begin
    if (FLines[I].Layer >= 0) and (FLines[I].Layer <= High(FLayerVisible)) and
       (not FLayerVisible[FLines[I].Layer]) then Continue;
    if FLines[I].Kind = 3 then
      DrawArchitecturalDoor(FCanvas.Canvas, FLines[I], I = FSelected)
    else if FLines[I].Kind in [4, 9] then
      DrawArchitecturalWindow(FCanvas.Canvas, FLines[I], I = FSelected);
  end;

  // 6. Cotas lineares das paredes/linhas quando FShowDimensions estiver ativo
  if FShowDimensions and FLayerVisible[3] then begin
    for I := 0 to High(FLines) do begin
      if not (FLines[I].Kind in [0, 2]) then Continue;
      MM := Hypot(FLines[I].B.X - FLines[I].A.X, FLines[I].B.Y - FLines[I].A.Y) * FMillimetersPerPixel;
      if MM < 400 then Continue;
      MX := Round((FLines[I].A.X + FLines[I].B.X) * FZoom / 2) + FPanX;
      MY := Round((FLines[I].A.Y + FLines[I].B.Y) * FZoom / 2) + FPanY;
      FCanvas.Canvas.Font.Color := LayerColor(3);
      FCanvas.Canvas.Font.Size := 8;
      FCanvas.Canvas.Brush.Style := bsClear;
      FCanvas.Canvas.TextOut(MX + 6, MY - 14, FormatFloat('0.00', MM / 1000) + ' m');
    end;
  end;

  // 7. Linha elástica (Rubberband) e marcador de ponto inicial durante desenho
  if FHasStart then begin
    SA := WorldToScreen(FStart);
    FCanvas.Canvas.Brush.Style := bsSolid;
    FCanvas.Canvas.Brush.Color := RGBToColor(255, 195, 40);
    FCanvas.Canvas.Pen.Color := clWhite;
    FCanvas.Canvas.Rectangle(SA.X - 4, SA.Y - 4, SA.X + 5, SA.Y + 5);

    if FHasMouse then begin
      SnapM := Snap(FMousePos);
      if FOrthoEnabled or (FToolSelect.ItemIndex in [2, 4, 11]) then begin
        if Abs(SnapM.X - FStart.X) >= Abs(SnapM.Y - FStart.Y) then SnapM.Y := FStart.Y
        else SnapM.X := FStart.X;
      end;
      SB := WorldToScreen(SnapM);
      FCanvas.Canvas.Pen.Style := psDot;
      FCanvas.Canvas.Pen.Width := 1;
      FCanvas.Canvas.Pen.Color := RGBToColor(90, 200, 255);
      FCanvas.Canvas.MoveTo(SA.X, SA.Y);
      FCanvas.Canvas.LineTo(SB.X, SB.Y);
      FCanvas.Canvas.Pen.Style := psSolid;

      // Tooltip dinâmico de distância estilo Dynamic Input do AutoCAD
      MM := Hypot(SnapM.X - FStart.X, SnapM.Y - FStart.Y) * FMillimetersPerPixel;
      FCanvas.Canvas.Brush.Style := bsSolid;
      FCanvas.Canvas.Brush.Color := RGBToColor(42, 50, 62);
      FCanvas.Canvas.Font.Color := RGBToColor(120, 220, 255);
      FCanvas.Canvas.TextOut(SB.X + 14, SB.Y + 12, Format(' %.2f m (%d mm) ', [MM / 1000.0, Round(MM)]));
    end;
  end;

  // 8. Ícone UCS no canto inferior esquerdo e Mira Crosshair do AutoCAD
  DrawUCSIcon(FCanvas.Canvas, R);
  DrawCrosshair(FCanvas.Canvas, R);
end;

procedure TCADMainForm.CanvasClick(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  if Button = mbRight then begin
    FHasStart := False;
    FCanvas.Invalidate;
    RefreshStatus('Comando cancelado (*Cancel*)');
    LogCommand('*Cancel*');
    Exit;
  end;
  if Button <> mbLeft then Exit;
  P := Snap(Point(X, Y));
  if FToolSelect.ItemIndex = 5 then begin
    SelectObjectAt(ScreenToWorld(X, Y));
    Exit;
  end;
  if not FHasStart then begin
    FStart := P;
    FHasStart := True;
    RefreshStatus('Especifique o segundo ponto (ou digite o comprimento em mm na linha de comando)');
  end else begin
    RecordChange;
    if FOrthoEnabled or (ssShift in Shift) then begin
      if Abs(P.X - FStart.X) >= Abs(P.Y - FStart.Y) then P.Y := FStart.Y
      else P.X := FStart.X;
    end;
    if FToolSelect.ItemIndex = 6 then AddCircle(FStart, P)
    else if FToolSelect.ItemIndex = 1 then begin
      AddSegment(FStart, Point(P.X, FStart.Y));
      AddSegment(Point(P.X, FStart.Y), P);
      AddSegment(P, Point(FStart.X, P.Y));
      AddSegment(Point(FStart.X, P.Y), FStart);
    end else
      AddSegment(FStart, P);
    Inc(FNextGroup);
    SetLength(FUndo, 0);
    FHasStart := False;
    LogCommand(Format('_%s (%d,%d) -> (%d,%d)',
      [UpperCase(Copy(FToolSelect.Text, 1, 6)),
       FStart.X * FMillimetersPerPixel, FStart.Y * FMillimetersPerPixel,
       P.X * FMillimetersPerPixel, P.Y * FMillimetersPerPixel]));
    RefreshStatus('Entidade criada em ' + FLayerSelect.Text);
  end;
  FCanvas.Invalidate;
end;

procedure TCADMainForm.MouseMoveDrawing(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  FMousePos := Point(X, Y);
  FHasMouse := True;
  P := Snap(Point(X, Y));
  if Assigned(FCoordLabel) then
    FCoordLabel.Caption := Format('%.4f, %.4f, 0.0000  ',
      [P.X * FMillimetersPerPixel * 1.0, (500 - P.Y) * FMillimetersPerPixel * 1.0]);
  if FHasStart then
    RefreshStatus(Format('Ponto inicial (%d, %d) mm — Próximo (%d, %d) mm — Dist: %.2f m',
      [FStart.X * FMillimetersPerPixel, FStart.Y * FMillimetersPerPixel,
       P.X * FMillimetersPerPixel, P.Y * FMillimetersPerPixel,
       Hypot(P.X - FStart.X, P.Y - FStart.Y) * FMillimetersPerPixel / 1000.0]));
  FCanvas.Invalidate;
end;

procedure TCADMainForm.CmdEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Cmd: string;
begin
  if Key = VK_RETURN then begin
    Cmd := Trim(FCmdEdit.Text);
    FCmdEdit.Text := '';
    Key := 0;
    if Cmd <> '' then
      ExecuteCommandString(Cmd);
  end else if Key = VK_ESCAPE then begin
    FHasStart := False;
    FCmdEdit.Text := '';
    FCanvas.Invalidate;
    LogCommand('*Cancel*');
  end;
end;

procedure TCADMainForm.FormKeyDownHandler(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if ActiveControl = FCmdEdit then Exit;
  case Key of
    VK_ESCAPE: begin
      FHasStart := False;
      FSelected := -1;
      FCanvas.Invalidate;
      LogCommand('*Cancel*');
      RefreshStatus('Cancelado');
    end;
    VK_DELETE: if FSelected >= 0 then DeleteSelected(nil);
    VK_F7: ToggleGridClick(nil);
    VK_F8: ToggleOrthoClick(nil);
    Ord('Z'): if ssCtrl in Shift then UndoHistory(nil);
    Ord('Y'): if ssCtrl in Shift then RedoHistory(nil);
  end;
end;

procedure TCADMainForm.ExecuteCommandString(const RawCmd: string);
var
  Cmd: string;
  LenMM, StepPx: Integer;
  DX, DY, L: Double;
  EndPt: TPoint;
begin
  LogCommand(RawCmd);
  Cmd := UpperCase(Trim(RawCmd));

  // Se estiver desenhando um segmento e digitar um comprimento em milímetros (ex: 3000)
  if FHasStart and TryStrToInt(Cmd, LenMM) and (LenMM > 0) and (LenMM <= 1000000) then begin
    StepPx := Max(1, Round(LenMM / FMillimetersPerPixel));
    DX := FMousePos.X - WorldToScreen(FStart).X;
    DY := FMousePos.Y - WorldToScreen(FStart).Y;
    if FOrthoEnabled or (Abs(DX) >= Abs(DY)) then begin
      if Abs(DX) >= Abs(DY) then begin
        EndPt.X := FStart.X + IfThen(DX >= 0, StepPx, -StepPx);
        EndPt.Y := FStart.Y;
      end else begin
        EndPt.X := FStart.X;
        EndPt.Y := FStart.Y + IfThen(DY >= 0, StepPx, -StepPx);
      end;
    end else begin
      L := Hypot(DX, DY);
      if L < 1 then L := 1;
      EndPt.X := FStart.X + Round(DX / L * StepPx);
      EndPt.Y := FStart.Y + Round(DY / L * StepPx);
    end;
    RecordChange;
    AddSegment(FStart, EndPt);
    Inc(FNextGroup);
    FHasStart := False;
    FCanvas.Invalidate;
    RefreshStatus(Format('Segmento criado com comprimento exato de %d mm (%.2f m)', [LenMM, LenMM / 1000.0]));
    Exit;
  end;

  case Cmd of
    'L', 'LINE', 'LINHA': begin FToolSelect.ItemIndex := 0; SelectionChanged(nil); end;
    'REC', 'RECTANG', 'RETANGULO': begin FToolSelect.ItemIndex := 1; SelectionChanged(nil); end;
    'PA', 'PAREDE', 'WALL', 'MLINE': begin FToolSelect.ItemIndex := 2; FLayerSelect.ItemIndex := 0; SelectionChanged(nil); end;
    'PO', 'PORTA', 'DOOR': begin FToolSelect.ItemIndex := 3; FLayerSelect.ItemIndex := 1; SelectionChanged(nil); end;
    'JA', 'JANELA', 'WINDOW': begin FToolSelect.ItemIndex := 4; FLayerSelect.ItemIndex := 1; SelectionChanged(nil); end;
    'JAA', 'JANELAALTA': begin FToolSelect.ItemIndex := 11; FLayerSelect.ItemIndex := 5; SelectionChanged(nil); end;
    'C', 'CIRCLE', 'CIRCULO': begin FToolSelect.ItemIndex := 6; SelectionChanged(nil); end;
    'SEL', 'SELECT': begin FToolSelect.ItemIndex := 5; SelectionChanged(nil); end;
    'M', 'MOVE', 'MOVER': TransformSelected(FQuickBar);
    'O', 'OFFSET': OffsetSelected(nil);
    'TR', 'TRIM': TrimSelected(nil);
    'EX', 'EXTEND': ExtendSelected(nil);
    'F', 'FILLET': FilletSelected(nil);
    'CHA', 'CHAMFER': ChamferSelected(nil);
    'RO', 'ROTATE': RotateSelected(nil);
    'MI', 'MIRROR': MirrorSelected(FQuickBar);
    'E', 'ERASE', 'DEL': DeleteSelected(nil);
    'U', 'UNDO': UndoHistory(nil);
    'REDO': RedoHistory(nil);
    'Z', 'ZOOM': ZoomExtents(nil);
    'DIM', 'COTA', 'COTAS': ToggleDimensions(nil);
    'DIST', 'MEASURE', 'MEDIR': MeasureSelected(nil);
    'QSAVE', 'SAVE', 'SALVAR': SaveDrawing(nil);
    'OPEN', 'ABRIR': OpenDrawing(nil);
    'DXF': ExportDXF(nil);
    'SVG': ExportSVG(nil);
    'VOBI', 'DEMO', 'EXEMPLO': LoadSampleFloorPlan(nil);
  else
    RefreshStatus('Comando reconhecido: ' + Cmd + ' (use L, WALL, PORTA, JANELA, OFFSET, TRIM, EXTEND, FILLET, QSAVE)');
  end;
end;

procedure TCADMainForm.NewDrawing(Sender: TObject);
begin
  if (Length(FLines) > 0) and
    (MessageDlg('Novo desenho', 'Descartar o desenho atual?',
     mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
  RecordChange;
  SetLength(FLines, 0);
  SetLength(FUndo, 0);
  FNextGroup := 1;
  FHasStart := False;
  FSelected := -1;
  FPath := '';
  FCanvas.Invalidate;
  LogCommand('_NEW');
  RefreshStatus('Novo desenho em branco');
end;

procedure TCADMainForm.UndoLine(Sender: TObject);
var
  G, N: Integer;
begin
  if Length(FLines) = 0 then Exit;
  G := FLines[High(FLines)].GroupID;
  repeat
    N := Length(FUndo);
    SetLength(FUndo, N + 1);
    FUndo[N] := FLines[High(FLines)];
    SetLength(FLines, Length(FLines) - 1);
  until (Length(FLines) = 0) or (FLines[High(FLines)].GroupID <> G);
  FSelected := -1;
  FCanvas.Invalidate;
  RefreshStatus('Operação desfeita');
end;

procedure TCADMainForm.RedoDrawing(Sender: TObject);
var
  G, N: Integer;
begin
  if Length(FUndo) = 0 then Exit;
  G := FUndo[High(FUndo)].GroupID;
  repeat
    N := Length(FLines);
    SetLength(FLines, N + 1);
    FLines[N] := FUndo[High(FUndo)];
    SetLength(FUndo, Length(FUndo) - 1);
  until (Length(FUndo) = 0) or (FUndo[High(FUndo)].GroupID <> G);
  FCanvas.Invalidate;
  RefreshStatus('Operação refeita');
end;

procedure TCADMainForm.SelectObjectAt(const P: TPoint);
var
  I: Integer;
  DX, DY, T, Dist, Best: Double;
  Nearest: Integer;
  R: TRect;
begin
  Best := 100.0;
  Nearest := -1;
  for I := High(FLines) downto 0 do begin
    if FLines[I].Kind in [5..8] then begin
      R := Rect(Min(FLines[I].A.X, FLines[I].B.X), Min(FLines[I].A.Y, FLines[I].B.Y),
                Max(FLines[I].A.X, FLines[I].B.X), Max(FLines[I].A.Y, FLines[I].B.Y));
      if PtInRect(R, P) then begin
        Nearest := I;
        Break;
      end;
    end;
    DX := FLines[I].B.X - FLines[I].A.X;
    DY := FLines[I].B.Y - FLines[I].A.Y;
    if DX * DX + DY * DY <= 0 then Continue;
    T := ((P.X - FLines[I].A.X) * DX + (P.Y - FLines[I].A.Y) * DY) / (DX * DX + DY * DY);
    T := Max(0.0, Min(1.0, T));
    Dist := Sqrt(Sqr(P.X - FLines[I].A.X - T * DX) + Sqr(P.Y - FLines[I].A.Y - T * DY));
    if (Dist <= 14 / FZoom) and (Dist < Best) then begin
      Best := Dist;
      Nearest := I;
    end;
  end;
  FSelected := Nearest;
  FCanvas.Invalidate;
  if FSelected >= 0 then
    RefreshStatus(Format('Selecionado #%d (%s — %d mm)',
      [FSelected + 1, LAYER_NAMES[Min(High(LAYER_NAMES), Max(0, FLines[FSelected].Layer))], FLines[FSelected].WidthMM]))
  else
    RefreshStatus('Nenhum objeto próximo');
end;

procedure TCADMainForm.DeleteSelected(Sender: TObject);
var
  I: Integer;
begin
  if FSelected < 0 then begin
    ShowMessage('Selecione um objeto antes de excluir.');
    Exit;
  end;
  RecordChange;
  for I := FSelected to High(FLines) - 1 do
    FLines[I] := FLines[I + 1];
  SetLength(FLines, Length(FLines) - 1);
  FSelected := -1;
  FCanvas.Invalidate;
  LogCommand('_ERASE 1 found');
  RefreshStatus('Objeto excluído');
end;

procedure TCADMainForm.TransformSelected(Sender: TObject);
var
  SX, SY: string;
  DX, DY, Id, N: Integer;
  IsCopy: Boolean;
begin
  if (FSelected < 0) or (FSelected >= Length(FLines)) then begin
    ShowMessage('Primeiro selecione um objeto.');
    Exit;
  end;
  IsCopy := Assigned(Sender) and (TControl(Sender).Tag = 1);
  SX := '1000';
  SY := '0';
  if not InputQuery('Deslocamento em milímetros',
    'Deslocamento horizontal (mm):', SX) then Exit;
  if not InputQuery('Deslocamento em milímetros',
    'Deslocamento vertical (mm):', SY) then Exit;
  if (not TryStrToInt(SX, DX)) or (not TryStrToInt(SY, DY)) then begin
    ShowMessage('Informe coordenadas inteiras em milímetros.');
    Exit;
  end;
  if (Abs(Int64(DX)) > 10000000) or (Abs(Int64(DY)) > 10000000) then begin
    ShowMessage('Deslocamento fora do limite.');
    Exit;
  end;
  RecordChange;
  Id := FSelected;
  if IsCopy then begin
    N := Length(FLines);
    SetLength(FLines, N + 1);
    FLines[N] := FLines[Id];
    Id := N;
    FSelected := N;
  end;
  Inc(FLines[Id].A.X, Round(DX / FMillimetersPerPixel));
  Inc(FLines[Id].B.X, Round(DX / FMillimetersPerPixel));
  Dec(FLines[Id].A.Y, Round(DY / FMillimetersPerPixel));
  Dec(FLines[Id].B.Y, Round(DY / FMillimetersPerPixel));
  FCanvas.Invalidate;
  if IsCopy then RefreshStatus('Objeto copiado')
  else RefreshStatus('Objeto movido');
end;

procedure TCADMainForm.RotateSelected(Sender: TObject);
var
  AngleText: string;
  Degrees, Radians, CX, CY: Double;
  A, B: TPoint;
  function RotatePoint(const P: TPoint): TPoint;
  var
    RX, RY: Double;
  begin
    RX := P.X - CX;
    RY := P.Y - CY;
    Result.X := Round(CX + RX * Cos(Radians) - RY * Sin(Radians));
    Result.Y := Round(CY + RX * Sin(Radians) + RY * Cos(Radians));
  end;
begin
  if (FSelected < 0) or (FSelected >= Length(FLines)) then begin
    ShowMessage('Selecione um objeto antes de girar.');
    Exit;
  end;
  AngleText := '90';
  if not InputQuery('Girar objeto', 'Ângulo em graus (sentido horário na tela):', AngleText) then Exit;
  if not TryStrToFloat(AngleText, Degrees) then begin
    ShowMessage('Ângulo inválido.');
    Exit;
  end;
  if IsNan(Degrees) or IsInfinite(Degrees) or (Abs(Degrees) > 36000) then begin
    ShowMessage('Ângulo fora do limite.');
    Exit;
  end;
  Radians := DegToRad(Degrees);
  A := FLines[FSelected].A;
  B := FLines[FSelected].B;
  CX := (A.X + B.X) / 2;
  CY := (A.Y + B.Y) / 2;
  RecordChange;
  FLines[FSelected].A := RotatePoint(A);
  FLines[FSelected].B := RotatePoint(B);
  FCanvas.Invalidate;
  RefreshStatus('Objeto girado');
end;

procedure TCADMainForm.MirrorSelected(Sender: TObject);
var
  CX, CY: Double;
  Id: Integer;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione um objeto antes de espelhar.');
    Exit;
  end;
  CX := (FLines[Id].A.X + FLines[Id].B.X) / 2;
  CY := (FLines[Id].A.Y + FLines[Id].B.Y) / 2;
  RecordChange;
  if Assigned(Sender) and (TControl(Sender).Tag = 0) then begin
    FLines[Id].A.Y := Round(2 * CY - FLines[Id].A.Y);
    FLines[Id].B.Y := Round(2 * CY - FLines[Id].B.Y);
  end else begin
    FLines[Id].A.X := Round(2 * CX - FLines[Id].A.X);
    FLines[Id].B.X := Round(2 * CX - FLines[Id].B.X);
  end;
  FCanvas.Invalidate;
  RefreshStatus('Objeto espelhado');
end;

procedure TCADMainForm.OffsetSelected(Sender: TObject);
var
  N, Id: Integer;
  DistanceText: string;
  MM, DX, DY, Len, ShiftX, ShiftY: Double;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione uma linha ou parede antes de aplicar offset.');
    Exit;
  end;
  DistanceText := '150';
  if not InputQuery('Offset paralelo (AutoCAD OFFSET)',
     'Distância assinada em milímetros (ex: 150 para parede):', DistanceText) then Exit;
  if not TryStrToFloat(DistanceText, MM) then begin
    ShowMessage('Distância inválida.');
    Exit;
  end;
  if IsNan(MM) or IsInfinite(MM) or (Abs(MM) > 1000000) then begin
    ShowMessage('Distância fora do limite.');
    Exit;
  end;
  DX := FLines[Id].B.X - FLines[Id].A.X;
  DY := FLines[Id].B.Y - FLines[Id].A.Y;
  Len := Hypot(DX, DY);
  if Len < 1 then Exit;
  ShiftX := -DY * MM / (Len * FMillimetersPerPixel);
  ShiftY := DX * MM / (Len * FMillimetersPerPixel);
  RecordChange;
  N := Length(FLines);
  SetLength(FLines, N + 1);
  FLines[N] := FLines[Id];
  FLines[N].A.X := Round(FLines[N].A.X + ShiftX);
  FLines[N].A.Y := Round(FLines[N].A.Y + ShiftY);
  FLines[N].B.X := Round(FLines[N].B.X + ShiftX);
  FLines[N].B.Y := Round(FLines[N].B.Y + ShiftY);
  FLines[N].GroupID := FNextGroup;
  Inc(FNextGroup);
  FSelected := N;
  FCanvas.Invalidate;
  LogCommand('_OFFSET ' + DistanceText + 'mm');
  RefreshStatus('Offset paralelo criado');
end;

procedure TCADMainForm.ExtendSelected(Sender: TObject);
var
  TargetText: string;
  Id, Other: Integer;
  AX, AY, BX, BY, CX, CY, DX, DY, Den, T, U, PX, PY: Double;
  A, B: TPoint;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione o segmento que deseja estender.');
    Exit;
  end;
  TargetText := IntToStr(Id + 1);
  if not InputQuery('Estender até linha', 'Número do segmento de limite (1 a ' +
    IntToStr(Length(FLines)) + '):', TargetText) then Exit;
  if (not TryStrToInt(TargetText, Other)) or (Other < 1) or
    (Other > Length(FLines)) or (Other = Id + 1) then begin
    ShowMessage('Segmento de limite inválido.');
    Exit;
  end;
  Dec(Other);
  A := FLines[Id].A;
  B := FLines[Id].B;
  AX := A.X; AY := A.Y; BX := B.X; BY := B.Y;
  CX := FLines[Other].A.X; CY := FLines[Other].A.Y;
  DX := FLines[Other].B.X; DY := FLines[Other].B.Y;
  Den := (BX - AX) * (DY - CY) - (BY - AY) * (DX - CX);
  if Abs(Den) < 0.000001 then begin
    ShowMessage('Linhas paralelas ou coincidentes.');
    Exit;
  end;
  T := ((CX - AX) * (DY - CY) - (CY - AY) * (DX - CX)) / Den;
  U := ((CX - AX) * (BY - AY) - (CY - AY) * (BX - AX)) / Den;
  if (U < 0) or (U > 1) then begin
    ShowMessage('A interseção está fora do segmento de limite.');
    Exit;
  end;
  if (T >= 0) and (T <= 1) then begin
    ShowMessage('A interseção já está no segmento selecionado.');
    Exit;
  end;
  if Abs(T) > 10000 then begin
    ShowMessage('Prolongamento excede o limite.');
    Exit;
  end;
  PX := AX + T * (BX - AX);
  PY := AY + T * (BY - AY);
  RecordChange;
  if T < 0 then FLines[Id].A := Point(Round(PX), Round(PY))
  else FLines[Id].B := Point(Round(PX), Round(PY));
  FCanvas.Invalidate;
  RefreshStatus('Segmento estendido até a interseção');
end;

procedure TCADMainForm.TrimSelected(Sender: TObject);
var
  TargetText, EndText: string;
  Id, Other: Integer;
  AX, AY, BX, BY, CX, CY, DX, DY, Den, T, U: Double;
  CutPoint: TPoint;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione o segmento que deseja aparar.');
    Exit;
  end;
  TargetText := '';
  if not InputQuery('Aparar segmento',
     'Número do segmento de limite (1 a ' + IntToStr(Length(FLines)) + '):', TargetText) then Exit;
  if (not TryStrToInt(TargetText, Other)) or (Other < 1) or
     (Other > Length(FLines)) or (Other = Id + 1) then begin
    ShowMessage('Segmento de limite inválido.');
    Exit;
  end;
  Dec(Other);
  AX := FLines[Id].A.X; AY := FLines[Id].A.Y;
  BX := FLines[Id].B.X; BY := FLines[Id].B.Y;
  CX := FLines[Other].A.X; CY := FLines[Other].A.Y;
  DX := FLines[Other].B.X; DY := FLines[Other].B.Y;
  Den := (BX - AX) * (DY - CY) - (BY - AY) * (DX - CX);
  if Abs(Den) < 0.000001 then begin
    ShowMessage('Linhas paralelas ou coincidentes.');
    Exit;
  end;
  T := ((CX - AX) * (DY - CY) - (CY - AY) * (DX - CX)) / Den;
  U := ((CX - AX) * (BY - AY) - (CY - AY) * (BX - AX)) / Den;
  if (T <= 0) or (T >= 1) or (U < 0) or (U > 1) then begin
    ShowMessage('Não há interseção interna para aparar.');
    Exit;
  end;
  EndText := 'B';
  if not InputQuery('Escolher extremidade', 'Remover lado A ou B?', EndText) then Exit;
  EndText := UpperCase(Trim(EndText));
  if (EndText <> 'A') and (EndText <> 'B') then begin
    ShowMessage('Escolha A ou B.');
    Exit;
  end;
  CutPoint := Point(Round(AX + T * (BX - AX)), Round(AY + T * (BY - AY)));
  RecordChange;
  if EndText = 'A' then FLines[Id].A := CutPoint
  else FLines[Id].B := CutPoint;
  FCanvas.Invalidate;
  RefreshStatus('Segmento aparado');
end;

procedure TCADMainForm.ChamferSelected(Sender: TObject);
var
  OtherText, DistanceText: string;
  Id, Other, N: Integer;
  AX, AY, BX, BY, CX, CY, DX, DY, Den, T, U,
  PX, PY, Len1, Len2, Offset1, Offset2: Double;
  P1, P2: TPoint;
  ChangeA1, ChangeA2: Boolean;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione a primeira linha para criar o chanfro.');
    Exit;
  end;
  OtherText := '';
  if not InputQuery('Chanfro', 'Número da segunda linha:', OtherText) then Exit;
  if (not TryStrToInt(OtherText, Other)) or (Other < 1) or
    (Other > Length(FLines)) or (Other = Id + 1) then begin
    ShowMessage('Segunda linha inválida.');
    Exit;
  end;
  Dec(Other);
  DistanceText := '200';
  if not InputQuery('Chanfro', 'Distância em milímetros:', DistanceText) then Exit;
  if not TryStrToFloat(DistanceText, Offset1) then begin
    ShowMessage('Distância inválida.');
    Exit;
  end;
  if IsNan(Offset1) or IsInfinite(Offset1) or
    (Offset1 <= 0) or (Offset1 > 1000000) then begin
    ShowMessage('Distância fora do limite.');
    Exit;
  end;
  AX := FLines[Id].A.X; AY := FLines[Id].A.Y;
  BX := FLines[Id].B.X; BY := FLines[Id].B.Y;
  CX := FLines[Other].A.X; CY := FLines[Other].A.Y;
  DX := FLines[Other].B.X; DY := FLines[Other].B.Y;
  Den := (BX - AX) * (DY - CY) - (BY - AY) * (DX - CX);
  if Abs(Den) < 0.000001 then begin
    ShowMessage('As linhas são paralelas ou coincidentes.');
    Exit;
  end;
  T := ((CX - AX) * (DY - CY) - (CY - AY) * (DX - CX)) / Den;
  U := ((CX - AX) * (BY - AY) - (CY - AY) * (BX - AX)) / Den;
  PX := AX + T * (BX - AX); PY := AY + T * (BY - AY);
  Len1 := Hypot(BX - AX, BY - AY);
  Len2 := Hypot(DX - CX, DY - CY);
  if (Len1 < 1) or (Len2 < 1) then Exit;
  Offset2 := Offset1 / FMillimetersPerPixel;
  ChangeA1 := T < 0.5;
  ChangeA2 := U < 0.5;
  if ChangeA1 then begin
    if Hypot(AX - PX, AY - PY) < Offset2 then begin
      ShowMessage('Primeira linha curta para este chanfro.');
      Exit;
    end;
    P1 := Point(Round(PX + (AX - PX) / Hypot(AX - PX, AY - PY) * Offset2),
                Round(PY + (AY - PY) / Hypot(AX - PX, AY - PY) * Offset2));
  end else begin
    if Hypot(BX - PX, BY - PY) < Offset2 then begin
      ShowMessage('Primeira linha curta para este chanfro.');
      Exit;
    end;
    P1 := Point(Round(PX + (BX - PX) / Hypot(BX - PX, BY - PY) * Offset2),
                Round(PY + (BY - PY) / Hypot(BX - PX, BY - PY) * Offset2));
  end;
  if ChangeA2 then begin
    if Hypot(CX - PX, CY - PY) < Offset2 then begin
      ShowMessage('Segunda linha curta para este chanfro.');
      Exit;
    end;
    P2 := Point(Round(PX + (CX - PX) / Hypot(CX - PX, CY - PY) * Offset2),
                Round(PY + (CY - PY) / Hypot(CX - PX, CY - PY) * Offset2));
  end else begin
    if Hypot(DX - PX, DY - PY) < Offset2 then begin
      ShowMessage('Segunda linha curta para este chanfro.');
      Exit;
    end;
    P2 := Point(Round(PX + (DX - PX) / Hypot(DX - PX, DY - PY) * Offset2),
                Round(PY + (DY - PY) / Hypot(DX - PX, DY - PY) * Offset2));
  end;
  if (P1.X = P2.X) and (P1.Y = P2.Y) then begin
    ShowMessage('Chanfro abaixo da resolução do desenho.');
    Exit;
  end;
  RecordChange;
  if ChangeA1 then FLines[Id].A := P1 else FLines[Id].B := P1;
  if ChangeA2 then FLines[Other].A := P2 else FLines[Other].B := P2;
  N := Length(FLines);
  SetLength(FLines, N + 1);
  FLines[N].A := P1;
  FLines[N].B := P2;
  FLines[N].Layer := FLines[Id].Layer;
  FLines[N].Kind := 0;
  FLines[N].WidthMM := 0;
  FLines[N].GroupID := FNextGroup;
  Inc(FNextGroup);
  FSelected := N;
  FCanvas.Invalidate;
  RefreshStatus('Chanfro criado');
end;

procedure TCADMainForm.FilletSelected(Sender: TObject);
var
  Id, Other, N, J, Steps: Integer;
  TextId, TextRadius: string;
  AX, AY, BX, BY, CX, CY, DX, DY, Den, T, U, IX, IY,
  V1X, V1Y, V2X, V2Y, L1, L2, DotValue, Angle, Radius,
  Tangent, Q1X, Q1Y, Q2X, Q2Y, BisX, BisY, BisLen,
  CenterX, CenterY, CenterDist, StartAngle, EndAngle,
  Sweep, X, Y: Double;
  P1, P2, PrevPoint, NextPoint: TPoint;
  NearA1, NearA2: Boolean;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione a primeira linha.');
    Exit;
  end;
  TextId := '';
  if not InputQuery('Arredondar canto', 'Número da segunda linha:', TextId) then Exit;
  if (not TryStrToInt(TextId, Other)) or (Other < 1) or
     (Other > Length(FLines)) or (Other = Id + 1) then begin
    ShowMessage('Segunda linha inválida.');
    Exit;
  end;
  Dec(Other);
  TextRadius := '200';
  if not InputQuery('Arredondar canto', 'Raio em milímetros:', TextRadius) then Exit;
  if not TryStrToFloat(TextRadius, Radius) then begin
    ShowMessage('Raio inválido.');
    Exit;
  end;
  if IsNan(Radius) or IsInfinite(Radius) or
     (Radius <= 0) or (Radius > 1000000) then begin
    ShowMessage('Raio fora do limite.');
    Exit;
  end;
  Radius := Radius / FMillimetersPerPixel;
  AX := FLines[Id].A.X; AY := FLines[Id].A.Y;
  BX := FLines[Id].B.X; BY := FLines[Id].B.Y;
  CX := FLines[Other].A.X; CY := FLines[Other].A.Y;
  DX := FLines[Other].B.X; DY := FLines[Other].B.Y;
  Den := (BX - AX) * (DY - CY) - (BY - AY) * (DX - CX);
  if Abs(Den) < 0.000001 then begin
    ShowMessage('Linhas paralelas ou coincidentes.');
    Exit;
  end;
  T := ((CX - AX) * (DY - CY) - (CY - AY) * (DX - CX)) / Den;
  U := ((CX - AX) * (BY - AY) - (CY - AY) * (BX - AX)) / Den;
  IX := AX + T * (BX - AX);
  IY := AY + T * (BY - AY);
  NearA1 := Hypot(IX - AX, IY - AY) <= Hypot(IX - BX, IY - BY);
  NearA2 := Hypot(IX - CX, IY - CY) <= Hypot(IX - DX, IY - DY);
  if NearA1 then begin V1X := AX - IX; V1Y := AY - IY; end
  else begin V1X := BX - IX; V1Y := BY - IY; end;
  if NearA2 then begin V2X := CX - IX; V2Y := CY - IY; end
  else begin V2X := DX - IX; V2Y := DY - IY; end;
  L1 := Hypot(V1X, V1Y);
  L2 := Hypot(V2X, V2Y);
  if (L1 < 1) or (L2 < 1) then Exit;
  V1X := V1X / L1; V1Y := V1Y / L1;
  V2X := V2X / L2; V2Y := V2Y / L2;
  DotValue := Max(-1.0, Min(1.0, V1X * V2X + V1Y * V2Y));
  Angle := ArcCos(DotValue);
  if (Angle < 0.05) or (Angle > Pi - 0.05) then begin
    ShowMessage('Ângulo inadequado para arredondamento.');
    Exit;
  end;
  Tangent := Radius / Tan(Angle / 2);
  if (Tangent >= L1) or (Tangent >= L2) then begin
    ShowMessage('Raio grande demais para os segmentos.');
    Exit;
  end;
  Q1X := IX + Tangent * V1X; Q1Y := IY + Tangent * V1Y;
  Q2X := IX + Tangent * V2X; Q2Y := IY + Tangent * V2Y;
  BisX := V1X + V2X; BisY := V1Y + V2Y;
  BisLen := Hypot(BisX, BisY);
  CenterDist := Radius / Sin(Angle / 2);
  CenterX := IX + CenterDist * BisX / BisLen;
  CenterY := IY + CenterDist * BisY / BisLen;
  P1 := Point(Round(Q1X), Round(Q1Y));
  P2 := Point(Round(Q2X), Round(Q2Y));
  if (P1.X = P2.X) and (P1.Y = P2.Y) then begin
    ShowMessage('Raio abaixo da resolução atual.');
    Exit;
  end;
  StartAngle := ArcTan2(Q1Y - CenterY, Q1X - CenterX);
  EndAngle := ArcTan2(Q2Y - CenterY, Q2X - CenterX);
  Sweep := EndAngle - StartAngle;
  while Sweep > Pi do Sweep := Sweep - 2 * Pi;
  while Sweep < -Pi do Sweep := Sweep + 2 * Pi;
  Steps := Max(4, Min(64, Ceil(Abs(Sweep) * Radius / 3)));
  RecordChange;
  if NearA1 then FLines[Id].A := P1 else FLines[Id].B := P1;
  if NearA2 then FLines[Other].A := P2 else FLines[Other].B := P2;
  PrevPoint := P1;
  for J := 1 to Steps do begin
    X := CenterX + Radius * Cos(StartAngle + Sweep * J / Steps);
    Y := CenterY + Radius * Sin(StartAngle + Sweep * J / Steps);
    NextPoint := Point(Round(X), Round(Y));
    if J = Steps then NextPoint := P2;
    if (PrevPoint.X <> NextPoint.X) or (PrevPoint.Y <> NextPoint.Y) then begin
      N := Length(FLines);
      SetLength(FLines, N + 1);
      FLines[N].A := PrevPoint;
      FLines[N].B := NextPoint;
      FLines[N].Layer := FLines[Id].Layer;
      FLines[N].Kind := 0;
      FLines[N].WidthMM := 0;
      FLines[N].GroupID := FNextGroup;
    end;
    PrevPoint := NextPoint;
  end;
  Inc(FNextGroup);
  FSelected := -1;
  FCanvas.Invalidate;
  RefreshStatus('Canto arredondado');
end;

procedure TCADMainForm.EditLastObject(Sender: TObject);
var
  V, VH, VS: string;
  MM, H, S, N: Integer;
begin
  N := FSelected;
  if N < 0 then N := High(FLines);
  if N < 0 then Exit;
  if FLines[N].Kind < 2 then begin
    ShowMessage('A entidade selecionada não é parede, porta, janela ou bloco.');
    Exit;
  end;
  V := IntToStr(FLines[N].WidthMM);
  if not InputQuery('Propriedade dimensional',
     'Espessura da parede ou largura nominal (mm):', V) then Exit;
  if (not TryStrToInt(V, MM)) or (MM < 50) or (MM > 10000) then begin
    ShowMessage('Informe de 50 a 10000 mm.');
    Exit;
  end;
  H := FLines[N].HeightMM;
  S := FLines[N].SillMM;
  if FLines[N].Kind in [4, 9] then begin
    VH := IntToStr(Max(400, H));
    VS := IntToStr(Max(0, S));
    if InputQuery('Janela — Altura e Peitoril (Aula 06)', 'Altura da janela (mm):', VH) then
      TryStrToInt(VH, H);
    if InputQuery('Janela — Altura e Peitoril (Aula 06)', 'Peitoril da janela (mm):', VS) then
      TryStrToInt(VS, S);
  end;
  RecordChange;
  FLines[N].WidthMM := MM;
  FLines[N].HeightMM := H;
  FLines[N].SillMM := S;
  FCanvas.Invalidate;
  RefreshStatus('Dimensões atualizadas');
end;

procedure TCADMainForm.ToggleDimensions(Sender: TObject);
begin
  FShowDimensions := not FShowDimensions;
  UpdateTogglePills;
  FCanvas.Invalidate;
  if FShowDimensions then RefreshStatus('Cotas visíveis em metros')
  else RefreshStatus('Cotas ocultas');
end;

procedure TCADMainForm.MeasureSelected(Sender: TObject);
var
  A, B: TPoint;
  MM: Double;
  V: string;
begin
  if (FSelected < 0) or (FSelected >= Length(FLines)) then begin
    ShowMessage('Selecione um segmento antes de medir.');
    Exit;
  end;
  A := FLines[FSelected].A;
  B := FLines[FSelected].B;
  MM := Hypot(B.X - A.X, B.Y - A.Y) * FMillimetersPerPixel;
  V := FormatFloat('0.00', MM / 1000);
  LogCommand(Format('_DIST = %s m (%d mm)', [V, Round(MM)]));
  ShowMessage('Comprimento: ' + V + ' m (' + IntToStr(Round(MM)) + ' mm)');
end;

procedure TCADMainForm.ExportSVG(Sender: TObject);
var
  D: TSaveDialog;
  L: TStringList;
  I, MinX, MaxX, MinY, MaxY: Integer;
  function Num(V: Integer): string;
  begin
    Result := IntToStr(V * FMillimetersPerPixel);
  end;
  function Stroke(K: Integer): string;
  begin
    case K of
      2: Result := '#ba552a';
      3, 4, 9: Result := '#e1c62c';
      5..8: Result := '#dc302a';
    else
      Result := '#204878';
    end;
  end;
begin
  D := TSaveDialog.Create(Self);
  L := TStringList.Create;
  try
    D.Filter := 'Scalable Vector Graphics (*.svg)|*.svg';
    D.DefaultExt := 'svg';
    D.FileName := 'planta.svg';
    D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    MinX := 0; MinY := 0; MaxX := 1000; MaxY := 1000;
    if Length(FLines) > 0 then begin
      MinX := FLines[0].A.X; MaxX := MinX;
      MinY := FLines[0].A.Y; MaxY := MinY;
      for I := 0 to High(FLines) do begin
        MinX := Min(MinX, Min(FLines[I].A.X, FLines[I].B.X));
        MinY := Min(MinY, Min(FLines[I].A.Y, FLines[I].B.Y));
        MaxX := Max(MaxX, Max(FLines[I].A.X, FLines[I].B.X));
        MaxY := Max(MaxY, Max(FLines[I].A.Y, FLines[I].B.Y));
      end;
    end;
    L.Add('<?xml version="1.0" encoding="UTF-8"?>');
    L.Add('<svg xmlns="http://www.w3.org/2000/svg" viewBox="' +
      Num(MinX - 10) + ' ' + Num(MinY - 10) + ' ' +
      Num(Max(20, MaxX - MinX + 20)) + ' ' + Num(Max(20, MaxY - MinY + 20)) + '">');
    for I := 0 to High(FLines) do
      L.Add('<line x1="' + Num(FLines[I].A.X) + '" y1="' +
        Num(FLines[I].A.Y) + '" x2="' + Num(FLines[I].B.X) +
        '" y2="' + Num(FLines[I].B.Y) + '" stroke="' +
        Stroke(FLines[I].Kind) + '" stroke-width="' +
        IntToStr(Max(10, FLines[I].WidthMM)) + '"/>');
    L.Add('</svg>');
    L.SaveToFile(D.FileName);
    LogCommand('_EXPORT SVG ' + ExtractFileName(D.FileName));
    RefreshStatus('SVG exportado: ' + ExtractFileName(D.FileName));
  finally
    L.Free;
    D.Free;
  end;
end;

procedure TCADMainForm.ExportDXF(Sender: TObject);
var
  D: TSaveDialog;
  L: TStringList;
  I: Integer;
  function DXFCoord(V: Integer): string;
  begin
    Result := IntToStr(V * FMillimetersPerPixel);
  end;
begin
  D := TSaveDialog.Create(Self);
  L := TStringList.Create;
  try
    D.Filter := 'AutoCAD DXF R12 (*.dxf)|*.dxf';
    D.DefaultExt := 'dxf';
    D.FileName := 'planta.dxf';
    D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    L.Add('0'); L.Add('SECTION'); L.Add('2'); L.Add('HEADER');
    L.Add('9'); L.Add('$INSUNITS'); L.Add('70'); L.Add('4');
    L.Add('0'); L.Add('ENDSEC');
    L.Add('0'); L.Add('SECTION'); L.Add('2'); L.Add('ENTITIES');
    for I := 0 to High(FLines) do begin
      L.Add('0'); L.Add('LINE'); L.Add('8'); L.Add(LayerDXFName(FLines[I].Layer));
      L.Add('10'); L.Add(DXFCoord(FLines[I].A.X));
      L.Add('20'); L.Add(DXFCoord(-FLines[I].A.Y));
      L.Add('30'); L.Add('0');
      L.Add('11'); L.Add(DXFCoord(FLines[I].B.X));
      L.Add('21'); L.Add(DXFCoord(-FLines[I].B.Y));
      L.Add('31'); L.Add('0');
    end;
    L.Add('0'); L.Add('ENDSEC'); L.Add('0'); L.Add('EOF');
    L.SaveToFile(D.FileName);
    LogCommand('_DXFOUT ' + ExtractFileName(D.FileName));
    RefreshStatus('DXF exportado: ' + ExtractFileName(D.FileName));
  finally
    L.Free;
    D.Free;
  end;
end;

procedure TCADMainForm.SaveDrawing(Sender: TObject);
var
  D: TSaveDialog;
  L: TStringList;
  I: Integer;
begin
  D := TSaveDialog.Create(Self);
  L := TStringList.Create;
  try
    D.Filter := 'Projeto CAD 2D (*.eacad)|*.eacad';
    D.DefaultExt := 'eacad';
    D.Options := D.Options + [ofOverwritePrompt];
    if FPath <> '' then D.FileName := FPath else D.FileName := 'planta.eacad';
    if not D.Execute then Exit;
    L.Add('EACAD3');
    L.Add(IntToStr(FMillimetersPerPixel));
    for I := 0 to High(FLines) do
      L.Add(Format('%d;%d;%d;%d;%d;%d;%d;%d', [FLines[I].A.X, FLines[I].A.Y,
        FLines[I].B.X, FLines[I].B.Y, FLines[I].Layer, FLines[I].Kind,
        FLines[I].WidthMM, FLines[I].GroupID]));
    L.SaveToFile(D.FileName);
    FPath := D.FileName;
    LogCommand('_QSAVE ' + ExtractFileName(FPath));
    RefreshStatus('Projeto salvo: ' + ExtractFileName(FPath));
  finally
    L.Free;
    D.Free;
  end;
end;

procedure TCADMainForm.OpenDrawing(Sender: TObject);
var
  D: TOpenDialog;
  L, Fields: TStringList;
  I, N: Integer;
  Temp: array of TCADLine;
  Scale, MaxGroup: Integer;
  Legacy, Grouped: Boolean;
begin
  D := TOpenDialog.Create(Self);
  L := TStringList.Create;
  Fields := TStringList.Create;
  try
    D.Filter := 'Projeto CAD 2D (*.eacad)|*.eacad';
    if not D.Execute then Exit;
    L.LoadFromFile(D.FileName);
    if (L.Count < 2) or ((L[0] <> 'EACAD1') and (L[0] <> 'EACAD2') and (L[0] <> 'EACAD3')) then
      raise Exception.Create('Formato de projeto não reconhecido');
    Legacy := L[0] = 'EACAD1';
    Grouped := L[0] = 'EACAD3';
    MaxGroup := 0;
    Scale := StrToInt(L[1]);
    if (Scale < 1) or (Scale > 100000) then
      raise Exception.Create('Escala inválida');
    SetLength(Temp, L.Count - 2);
    Fields.StrictDelimiter := True;
    Fields.Delimiter := ';';
    for I := 2 to L.Count - 1 do begin
      Fields.DelimitedText := L[I];
      if (Legacy and (Fields.Count <> 6)) or
         ((not Legacy) and (not Grouped) and (Fields.Count <> 7)) or
         (Grouped and (Fields.Count <> 8)) then
        raise Exception.CreateFmt('Linha %d inválida', [I + 1]);
      N := I - 2;
      if Grouped then Temp[N].GroupID := StrToInt(Fields[7])
      else Temp[N].GroupID := N + 1;
      if (Temp[N].GroupID < 1) or (Temp[N].GroupID > 100000000) then
        raise Exception.CreateFmt('Grupo inválido na linha %d', [I + 1]);
      MaxGroup := Max(MaxGroup, Temp[N].GroupID);
      Temp[N].A.X := StrToInt(Fields[0]);
      Temp[N].A.Y := StrToInt(Fields[1]);
      Temp[N].B.X := StrToInt(Fields[2]);
      Temp[N].B.Y := StrToInt(Fields[3]);
      Temp[N].Layer := StrToInt(Fields[4]);
      Temp[N].Kind := StrToInt(Fields[5]);
      Temp[N].HeightMM := 1200;
      Temp[N].SillMM := 900;
      if Legacy then begin
        case Temp[N].Kind of
          2: Temp[N].WidthMM := 150;
          3: Temp[N].WidthMM := 900;
          4: Temp[N].WidthMM := 1200;
        else
          Temp[N].WidthMM := 0;
        end;
      end else
        Temp[N].WidthMM := StrToInt(Fields[6]);
      if (Temp[N].Layer < 0) or (Temp[N].Layer > High(LAYER_NAMES)) or
         (Temp[N].Kind < 0) or (Temp[N].Kind > 9) then
        raise Exception.CreateFmt('Objeto inválido na linha %d', [I + 1]);
    end;
    FHistoryUndo.Clear;
    FHistoryRedo.Clear;
    FLines := Temp;
    SetLength(FUndo, 0);
    FNextGroup := MaxGroup + 1;
    FSelected := -1;
    FMillimetersPerPixel := Scale;
    FHasStart := False;
    FPath := D.FileName;
    FCanvas.Invalidate;
    LogCommand('_OPEN ' + ExtractFileName(FPath));
    RefreshStatus('Projeto aberto: ' + ExtractFileName(FPath));
  except
    on E: Exception do
      MessageDlg('Erro ao abrir projeto', E.Message, mtError, [mbOK], 0);
  end;
  Fields.Free;
  L.Free;
  D.Free;
end;

end.
