unit cad2d_main;
{$mode objfpc}{$H+}
{$codepage utf8}
interface
uses {$IFDEF WINDOWS}Windows,{$ENDIF} Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, Menus,
  Graphics, Types, Math, Dialogs, LCLType, CheckLst, aiundohistory, fpjson, ea_workflow, ea_workflow_ui, cad_document, cad_dxf, cad_catalog, cad_catalog_ui, cad_health_examples;
type
  TCADIndices = array of Integer;
  TCADMainForm = class(TForm)
  {$IFDEF CAD_TESTS}public{$ELSE}private{$ENDIF}
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
    FLayerPanel: TPanel;
    FLayerList: TCheckListBox;
    FLayerLock: TCheckBox;
    FDocumentLabel: TLabel;
    FMainMenu: TMainMenu;
    FWorkflow: TWorkflow;
    FWorkflowView: TWorkflowPanel;
    FWorkArea, FSideBar: TPanel;
    FWorkflowToken, FTaskID, FOpenPath: string;
    FSaveSucceeded, FDirty, FInitialFitPending: Boolean;
    procedure SaveDocumentFile(const FileName: string);
    procedure LoadDocumentFile(const FileName: string);
    procedure DrawingShown(Sender: TObject);
    procedure FitDrawingAsync(Data: PtrInt);
    function ConfirmDrawingSwitch: Boolean;
    procedure DrawingCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure BuildTaskUI;
    procedure TaskViewClick(Sender: TObject);
    procedure DrawingViewClick(Sender: TObject);
    procedure ReplyTaskClick(Sender: TObject);
    procedure ReturnTaskClick(Sender: TObject);
    procedure PlannerClick(Sender: TObject);
    procedure WorkflowIdentityChanged(Sender: TObject);
    function WorkflowEditAllowed: Boolean;
    function EnsureWorkflow: Boolean;
  {$IFDEF CAD_TESTS}public{$ELSE}private{$ENDIF}
    {$IFDEF WINDOWS}FMenuBrush: THandle;{$ENDIF}
    FRibbonGroups: array[0..7] of TPanel;
    FRibbonTabs: array[0..4] of TLabel;
    FPanning, FUpdatingLayers: Boolean;
    FPanStart: TPoint;
    procedure RibbonTabClick(Sender: TObject);
    procedure LayerListClick(Sender: TObject);
    procedure LayerCheckClick(Sender: TObject);
    procedure SyncLayerPanel;
    procedure UpdateDocumentTitle;
    procedure MouseUpDrawing(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure WheelDrawing(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure ZoomAt(const P: TPoint; Factor: Double);

  {$IFDEF CAD_TESTS}public{$ELSE}private{$ENDIF}
    // Estado do modelo geométrico e arquitetônico
    FLines: TCADLines;
    FLabels: TCADLabels;
    FCatalog: TCADCatalog;
    FPendingCatalogID: string;
    FPendingCatalogWidth,FPendingCatalogDepth: Integer;
    function Catalog: TCADCatalog;
    procedure ChooseCatalog(Sender: TObject);
    procedure InsertCatalog(const ID: string; const Origin: TPoint; WidthMM,DepthMM: Integer);
    function SelectionMembers: TCADIndices;
    function CanModifySelection: Boolean;
    function EntitySelected(I: Integer): Boolean;
    procedure MoveSelectionMM(DX,DY: Integer; CopyIt: Boolean);
    procedure RotateSelectionDegrees(Degrees: Double);
    procedure MirrorSelection(Horizontal: Boolean);
    procedure ResizeCatalogSelection(WidthMM,DepthMM: Integer);
    procedure ChooseCatalogResize;
    procedure ExplodeSelection(Sender: TObject);
    procedure LoadGeneralSampleFloorPlan(Sender: TObject);
    procedure LoadHospitalExample(Sender: TObject);
    procedure LoadHealthcareExample(Hospital: Boolean);
  {$IFDEF CAD_TESTS}public{$ELSE}private{$ENDIF}
    FLayerVisible: TCADLayers;
    FLayerLocked: TCADLayers;
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
    FHistory: TAIUndoHistory;

    // Construção da interface AutoCAD
    procedure BuildAutoCADInterface;
    procedure BuildDropMenus;
    procedure MenuCommand(Sender: TObject);
    procedure DrawDropMenu(Sender: TObject; ACanvas: TCanvas;
      ARect: TRect; AState: TOwnerDrawState);
    procedure MeasureDropMenu(Sender: TObject; ACanvas: TCanvas;
      var AWidth, AHeight: Integer);
    procedure TypeCommand(Sender: TObject; var UTF8Key: TUTF8Char);
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
    procedure ImportDXF(Sender: TObject);
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
  Caption := 'CAD Arquitetônico 2D — EngenhariaArquitetura';
  Width := 1280;
  Height := 820;
  Position := poScreenCenter;
  Constraints.MinWidth := 920;
  Constraints.MinHeight := 600;
  KeyPreview := True;
  OnKeyDown := @FormKeyDownHandler;
  OnMouseWheel := @WheelDrawing;
  OnCloseQuery := @DrawingCloseQuery;
  OnShow := @DrawingShown;
  OnUTF8KeyPress := @TypeCommand;
  Color := RGBToColor(30, 64, 145);
  Font.Name := {$IFDEF WINDOWS}'Segoe UI'{$ELSE}'Sans'{$ENDIF};
  Font.Size := 9;

  FGrid := 1000;
  FMillimetersPerPixel := 1; // Uma unidade do modelo = 1 mm; zoom separado da geometria
  FSelected := -1;
  FZoom := 0.02;
  FPanX := 40;
  FPanY := 20;
  FShowDimensions := False;
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
  FHistory := TAIUndoHistory.Create(60);

  BuildAutoCADInterface;
  LoadSampleFloorPlan(nil);
  FPath := '';
  UpdateDocumentTitle;
  RefreshStatus('Planta 2D de exemplo. Roda: zoom | Botão central: deslocar | Esc: cancelar');
  FDirty := False;
  FInitialFitPending := True;
  BuildTaskUI;
end;

destructor TCADMainForm.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  Menu := nil;
  FreeAndNil(FMainMenu);
  {$IFDEF WINDOWS}if FMenuBrush <> 0 then Windows.DeleteObject(FMenuBrush);{$ENDIF}
  FWorkflow.Free;
  FCatalog.Free;
  FHistory.Free;
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
    Result.Color := RGBToColor(27, 56, 120);
    Result.BorderSpacing.Right := 2;

    CapBar := TPanel.Create(Self);
    CapBar.Parent := Result;
    CapBar.Align := alBottom;
    CapBar.Height := 18;
    CapBar.BevelOuter := bvNone;
    CapBar.Color := RGBToColor(20, 42, 90);

    GroupCaption := TLabel.Create(Self);
    GroupCaption.Parent := CapBar;
    GroupCaption.Align := alClient;
    GroupCaption.Alignment := taCenter;
    GroupCaption.Layout := tlCenter;
    GroupCaption.Caption := ATitle;
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
    Result.Color := RGBToColor(39, 77, 157);
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
    Result.Color := RGBToColor(27, 56, 120);
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
    Result.Color := RGBToColor(27, 56, 120);
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
  GrpModify, GrpDraw, GrpArch, GrpAnnot, GrpLayers, GrpBlock, GrpView, GrpManage: TPanel;
  LayerBoxPanel: TPanel;
  TabNames: array[0..4] of string = ('Desenhar', 'Arquitetura', 'Anotar', 'Vista 2D', 'Gestão');
  I, XPos: Integer;
begin
  // 1. Barra de Acesso Rápido (Quick Access Toolbar estilo AutoCAD LT)
  FQuickBar := TPanel.Create(Self);
  FQuickBar.Parent := Self;
  FQuickBar.Align := alTop;
  FQuickBar.Height := 28;
  FQuickBar.BevelOuter := bvNone;
  FQuickBar.Color := RGBToColor(15, 23, 42);

  Badge := TLabel.Create(Self);
  Badge.Parent := FQuickBar;
  Badge.Align := alLeft;
  Badge.AutoSize := False;
  Badge.Width := 46;
  Badge.Alignment := taCenter;
  Badge.Layout := tlCenter;
  Badge.Caption := 'EA';
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
  AddQuickBtn('Exemplo UBS', 100, @LoadSampleFloorPlan, 'Estudo esquemático de UBS; exemplo geral também disponível no menu Biblioteca');

  Lbl := TLabel.Create(Self);
  Lbl.Parent := FQuickBar;
  Lbl.Align := alClient;
  Lbl.Alignment := taCenter;
  Lbl.Layout := tlCenter;
  Lbl.Caption := 'EngenhariaArquitetura | Desenho técnico 2D';
  Lbl.Font.Color := RGBToColor(200, 208, 218);
  Lbl.Font.Style := [fsBold];

  BuildDropMenus;

  // 2. Barra de Abas da Ribbon (Home | Insert | Annotate | Parametric | View | Manage | Output)
  FRibbonTabsBar := TPanel.Create(Self);
  FRibbonTabsBar.Parent := Self;
  FRibbonTabsBar.Align := alTop;
  FRibbonTabsBar.Height := 24;
  FRibbonTabsBar.BevelOuter := bvNone;
  FRibbonTabsBar.Color := RGBToColor(30, 64, 145);

  XPos := 8;
  for I := 0 to High(TabNames) do begin
    Lbl := TLabel.Create(Self);
    Lbl.Parent := FRibbonTabsBar;
    Lbl.AutoSize := False;
    Lbl.SetBounds(XPos, 2, 76, 20);
    Lbl.Alignment := taCenter;
    Lbl.Layout := tlCenter;
    Lbl.Caption := TabNames[I];
    Lbl.Tag := I;
    Lbl.Cursor := crHandPoint;
    Lbl.OnClick := @RibbonTabClick;
    FRibbonTabs[I] := Lbl;
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
  FRibbonPanel.Color := RGBToColor(30, 64, 145);

  // Grupo MODIFY
  GrpModify := CreateRibbonGroup('Modificar', 222);
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
  GrpDraw := CreateRibbonGroup('Geometria 2D', 158);
  AddRibbonBtn(GrpDraw, '╱ Line', 4, 4, 72, 32, @SelectToolByTag, 0, 'Desenhar Linha por 2 pontos (LINE)');
  AddRibbonBtn(GrpDraw, '▭ Retâng.', 80, 4, 72, 32, @SelectToolByTag, 1, 'Desenhar Retângulo (RECTANG)');
  AddRibbonBtn(GrpDraw, '◯ Circle', 4, 40, 72, 32, @SelectToolByTag, 6, 'Desenhar Círculo por centro e raio (CIRCLE)');
  AddRibbonBtn(GrpDraw, '↖ Selecionar', 80, 40, 72, 32, @SelectToolByTag, 5, 'Selecionar objeto na planta');

  // Grupo ARQUITETURA (Paredes, Portas, Janelas Aula 06)
  GrpArch := CreateRibbonGroup('Elementos em planta', 196);
  AddRibbonBtn(GrpArch, '🧱 Parede Dupla', 4, 4, 90, 32, @SelectToolByTag, 2, 'Desenhar Parede paramétrica com linha dupla (150 mm) e abertura automática de vãos');
  AddRibbonBtn(GrpArch, '🚪 Porta 90°', 98, 4, 92, 32, @SelectToolByTag, 3, 'Inserir Porta (900 mm) com abertura de vão na parede, boneca e arco 90°');
  AddRibbonBtn(GrpArch, '🪟 Janela Baixa', 4, 40, 90, 32, @SelectToolByTag, 4, 'Inserir Janela padrão (Aula 06): abre vão na parede, desenha peitoril + 2 linhas de caixilho e cota LxAxP');
  AddRibbonBtn(GrpArch, '🪟 Janela Alta', 98, 40, 92, 32, @SelectToolByTag, 11, 'Inserir Janela Alta (tracejada acima do plano de corte, peitoril 1,60m - Aula 06)');

  // Grupo ANNOTATION (Cotas e Medidas)
  GrpAnnot := CreateRibbonGroup('Cotas e medidas', 132);
  AddRibbonBtn(GrpAnnot, '📏 Cotas ON/OFF', 4, 4, 122, 22, @ToggleDimensions, 0, 'Exibir/ocultar cotas em metros e especificações de janelas (LxAxP)');
  AddRibbonBtn(GrpAnnot, '📐 Medir Seleção', 4, 28, 122, 22, @MeasureSelected, 0, 'Medir comprimento exato em metros e milímetros (DIST)');
  AddRibbonBtn(GrpAnnot, '✎ Editar Dimensão', 4, 52, 122, 20, @EditLastObject, 0, 'Editar espessura de parede ou largura/altura/peitoril de esquadria');

  // Grupo LAYERS (Idêntico ao destaque da imagem: lâmpada, sol, cadeado, cor e nome da Layer)
  GrpLayers := CreateRibbonGroup('Camada e ferramenta', 240);
  LayerBoxPanel := TPanel.Create(Self);
  LayerBoxPanel.Parent := GrpLayers;
  LayerBoxPanel.SetBounds(6, 6, 226, 30);
  LayerBoxPanel.BevelOuter := bvNone;
  LayerBoxPanel.Color := RGBToColor(15, 23, 42);

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
  FLayerSunLabel.Hint := 'Visibilidade da camada atual';
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
  FLayerSelect.ItemIndex := 0; // "Mobiliário" em destaque como na captura do AutoCAD
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
  FToolSelect.Items.Add('Janela Alta Tracejada');
  FToolSelect.Items.Add('Inserir da biblioteca 2D');    // 11
  FToolSelect.ItemIndex := 5; // Seleção ao iniciar
  FToolSelect.OnChange := @SelectionChanged;

  // Grupo BLOCK (Mobiliário humanizado como na imagem do AutoCAD)
  GrpBlock := CreateRibbonGroup('Biblioteca 2D', 178);
  AddRibbonBtn(GrpBlock, 'Biblioteca...', 4, 4, 82, 32, @ChooseCatalog, 0, 'Saúde e mobiliário de uso geral');
  AddRibbonBtn(GrpBlock, 'Maca', 90, 4, 82, 32, @ChooseCatalog, 1, 'Maca em planta 2D');
  AddRibbonBtn(GrpBlock, 'Cama', 4, 40, 82, 32, @ChooseCatalog, 2, 'Cama hospitalar em planta 2D');
  AddRibbonBtn(GrpBlock, 'Mesa', 90, 40, 82, 32, @ChooseCatalog, 3, 'Mesa de uso geral');

  // Grupo VIEW (Zoom e Pan)
  GrpView := CreateRibbonGroup('Navegação 2D', 140);
  AddRibbonBtn(GrpView, '🔍 Zoom +', 4, 4, 64, 22, @ZoomDrawing, 1, 'Aproximar vista (Zoom In)');
  AddRibbonBtn(GrpView, '🔎 Zoom -', 70, 4, 64, 22, @ZoomDrawing, -1, 'Afastar vista (Zoom Out)');
  AddRibbonBtn(GrpView, '⛶ Enquadrar', 4, 28, 130, 22, @ZoomExtents, 0, 'Centralizar planta na tela (ZOOM EXTENTS)');
  AddRibbonBtn(GrpView, '◀', 4, 52, 30, 20, @PanDrawing, 1, 'Pan esquerda');
  AddRibbonBtn(GrpView, '▶', 37, 52, 30, 20, @PanDrawing, 2, 'Pan direita');
  AddRibbonBtn(GrpView, '▲', 70, 52, 30, 20, @PanDrawing, 3, 'Pan cima');
  AddRibbonBtn(GrpView, '▼', 103, 52, 31, 20, @PanDrawing, 4, 'Pan baixo');

  GrpManage := CreateRibbonGroup('Gestão da tarefa', 540);
  AddRibbonBtn(GrpManage, 'Tarefa e arquivo', 8, 10, 126, 42, @TaskViewClick);
  AddRibbonBtn(GrpManage, 'Responder tarefa', 140, 10, 126, 42, @ReplyTaskClick);
  AddRibbonBtn(GrpManage, 'Devolver tarefa', 272, 10, 126, 42, @ReturnTaskClick);
  AddRibbonBtn(GrpManage, 'Voltar Planejador', 404, 10, 126, 42, @PlannerClick);

  // 4. Barra de Abas de Documento (Start | vobi autocad *)
  FDocTabsBar := TPanel.Create(Self);
  FDocTabsBar.Parent := Self;
  FDocTabsBar.Align := alTop;
  FDocTabsBar.Height := 26;
  FDocTabsBar.BevelOuter := bvNone;
  FDocTabsBar.Color := RGBToColor(15, 23, 42);

  FDocumentLabel := TLabel.Create(Self);
  FDocumentLabel.Parent := FDocTabsBar;
  FDocumentLabel.SetBounds(12, 5, 580, 20);
  FDocumentLabel.Font.Color := clWhite;
  FDocumentLabel.Caption := 'Sem título.eacad | Superior | Estrutura 2D';

  // 5. Barra de Status Inferior estilo AutoCAD (Model | Layout1 | Layout2 | Coordenadas | GRID | SNAP | ORTHO | OSNAP)
  FStatusBar := TPanel.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.Align := alBottom;
  FStatusBar.Height := 26;
  FStatusBar.BevelOuter := bvNone;
  FStatusBar.Color := RGBToColor(30, 64, 145);

  Lbl := TLabel.Create(Self);
  Lbl.Parent := FStatusBar;
  Lbl.Align := alLeft;
  Lbl.AutoSize := False;
  Lbl.Width := 76;
  Lbl.Layout := tlCenter;
  Lbl.Caption := '  MODELO 2D';
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
  FModeLabel.Caption := 'SUPERIOR 2D';
  FModeLabel.Font.Color := RGBToColor(235, 240, 245);
  FModeLabel.Font.Style := [fsBold];

  FCoordLabel := TLabel.Create(Self);
  FCoordLabel.Parent := FStatusBar;
  FCoordLabel.Align := alRight;
  FCoordLabel.AutoSize := False;
  FCoordLabel.Width := 180;
  FCoordLabel.Alignment := taRightJustify;
  FCoordLabel.Layout := tlCenter;
  FCoordLabel.Caption := 'X: 0  Y: 0 mm  ';
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
  CmdLeftPanel.Color := RGBToColor(20, 42, 90);

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
  Lbl.Caption := '  Comando:';
  Lbl.Font.Color := RGBToColor(60, 68, 78);
  Lbl.Font.Style := [fsBold];

  FCmdEdit := TEdit.Create(Self);
  FCmdEdit.Parent := CmdInputRow;
  FCmdEdit.Align := alClient;
  FCmdEdit.BorderStyle := bsNone;
  FCmdEdit.TextHint := 'Digite LINHA, PAREDE, PORTA, JANELA, ZOOM, CAMADAS, SALVAR ou AJUDA';
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
  FCmdHistoryMemo.Lines.Add('CAD Arquitetônico 2D — plantas e desenho técnico em X/Y.');
  FCmdHistoryMemo.Lines.Add('F7: grade | F8: ortogonal | Esc: cancelar | AJUDA: comandos');

  FRibbonGroups[0] := GrpDraw; FRibbonGroups[1] := GrpModify;
  FRibbonGroups[2] := GrpArch; FRibbonGroups[3] := GrpAnnot;
  FRibbonGroups[4] := GrpLayers; FRibbonGroups[5] := GrpBlock;
  FRibbonGroups[6] := GrpView; FRibbonGroups[7] := GrpManage;
  RibbonTabClick(FRibbonTabs[0]);

  FLayerPanel := TPanel.Create(Self);
  FLayerPanel.Parent := Self;
  FLayerPanel.Align := alLeft;
  FLayerPanel.Width := 210;
  FLayerPanel.BevelOuter := bvNone;
  FLayerPanel.Color := RGBToColor(30, 64, 145);
  Lbl := TLabel.Create(Self);
  Lbl.Parent := FLayerPanel;
  Lbl.Align := alTop;
  Lbl.AutoSize := False; Lbl.Height := 44;
  Lbl.Layout := tlCenter;
  Lbl.Caption := '  CAMADAS  /  PROPRIEDADES';
  Lbl.Font.Color := clWhite;
  FLayerLock := TCheckBox.Create(Self);
  FLayerLock.Parent := FLayerPanel;
  FLayerLock.Align := alBottom;
  FLayerLock.Height := 32;
  FLayerLock.Caption := 'Bloquear camada atual';
  FLayerLock.Font.Color := clWhite;
  FLayerLock.OnClick := @ToggleLayerLockClick;
  Lbl := TLabel.Create(Self);
  Lbl.Parent := FLayerPanel;
  Lbl.Align := alBottom;
  Lbl.AutoSize := False; Lbl.Height := 66;
  Lbl.WordWrap := True;
  Lbl.Caption := '  Marque para exibir a camada.' + LineEnding +
    '  Clique no nome para torná-la atual.' + LineEnding +
    '  Camadas bloqueadas não são editadas.';
  Lbl.Font.Color := RGBToColor(175, 188, 202);
  FLayerList := TCheckListBox.Create(Self);
  FLayerList.Parent := FLayerPanel;
  FLayerList.Align := alClient;
  FLayerList.Color := RGBToColor(15, 23, 42);
  FLayerList.Font.Color := RGBToColor(215, 225, 235);
  FLayerList.BorderStyle := bsNone;
  FLayerList.ItemHeight := 30;
  for I := 0 to High(LAYER_NAMES) do FLayerList.Items.Add(LAYER_NAMES[I]);
  FLayerList.OnClick := @LayerListClick;
  FLayerList.OnClickCheck := @LayerCheckClick;

  // 7. Vista superior ortográfica: apenas X/Y
  FCanvas := TPaintBox.Create(Self);
  FCanvas.Parent := Self;
  FCanvas.Align := alClient;
  FCanvas.Cursor := crNone; // Usamos o crosshair classico do AutoCAD com pickbox central
  FCanvas.OnPaint := @PaintDrawing;
  FCanvas.OnMouseDown := @CanvasClick;
  FCanvas.OnMouseMove := @MouseMoveDrawing;
  FCanvas.OnMouseUp := @MouseUpDrawing;

  UpdateLayerSwatch;
  UpdateTogglePills;
  SyncLayerPanel;
end;

procedure TCADMainForm.UpdateLayerSwatch;
var
  Idx: Integer;
begin
  SyncLayerPanel;
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
      P.Color := RGBToColor(37, 99, 235)
    else
      P.Color := RGBToColor(27, 56, 120);
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
  FDirty := True;
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
  if FUpdatingLayers then Exit;
  FDirty := True;
  FLayerLocked[Idx] := not FLayerLocked[Idx];
  if FLayerLocked[Idx] and (FSelected >= 0) and
    (FLines[FSelected].Layer = Idx) then FSelected := -1;
  UpdateLayerSwatch;
  LogCommand(Format('_LAYER %s %s', [LAYER_NAMES[Idx], BoolToStr(FLayerLocked[Idx], 'LOCK', 'UNLOCK')]));
end;

procedure TCADMainForm.ZoomExtents(Sender: TObject);
var I, MinX, MinY, MaxX, MaxY, Pad: Integer;
begin
  if (Length(FLines) = 0) or (FCanvas.Width < 80) or (FCanvas.Height < 80) then Exit;
  MinX := MaxInt; MinY := MaxInt; MaxX := -MaxInt; MaxY := -MaxInt;
  for I := 0 to High(FLines) do begin
    if not FLayerVisible[FLines[I].Layer] then Continue;
    MinX := Min(MinX, Min(FLines[I].A.X, FLines[I].B.X));
    MinY := Min(MinY, Min(FLines[I].A.Y, FLines[I].B.Y));
    MaxX := Max(MaxX, Max(FLines[I].A.X, FLines[I].B.X));
    MaxY := Max(MaxY, Max(FLines[I].A.Y, FLines[I].B.Y));
  end;
  if MinX = MaxInt then Exit;
  Pad := 48;
  FZoom := EnsureRange(Min((FCanvas.Width - 2 * Pad) / Max(1, MaxX - MinX),
    (FCanvas.Height - 2 * Pad) / Max(1, MaxY - MinY)), 0.00001, 20.0);
  FPanX := Round(FCanvas.Width / 2 - (MinX + MaxX) * FZoom / 2);
  FPanY := Round(FCanvas.Height / 2 - (MinY + MaxY) * FZoom / 2);
  FCanvas.Invalidate;
  LogCommand('ZOOM: enquadrar entidades visíveis');
  RefreshStatus(Format('Vista superior 2D | Zoom %.1f%%', [FZoom * 5000]));
end;

procedure TCADMainForm.LoadGeneralSampleFloorPlan(Sender: TObject);
begin
  if not WorkflowEditAllowed then Exit;
  RecordChange;
  SetLength(FLines, 0);
  SetLength(FLabels, 0);
  FNextGroup := 1;

  // Planta baixa inspirada exatamente na captura "vobi autocad.dwg" e nos conceitos da Aula 06:
  // Sala integrada (Estar + Jantar) com paredes de 150 mm, janela lateral 1,96x1,20x0,90,
  // abertura superior com bonecas, porta inferior com arco de abertura 90° e mobiliário humanizado.

  // 1. Paredes principais (Kind=2, Layer=0 ARQ_PAREDES, Espessura=150mm)
  // Parede esquerda (com janela de 1,96m embutida)
  AddSegmentEx(Point(8000, 4000), Point(8000, 21000), 0, 2, 150, 2800, 0);
  // Parede superior esquerda + boneca do vão superior
  AddSegmentEx(Point(8000, 4000), Point(16000, 4000), 0, 2, 150, 2800, 0);
  AddSegmentEx(Point(16000, 2500), Point(16000, 4000), 0, 2, 150, 2800, 0);
  // Parede superior direita + boneca do vão superior
  AddSegmentEx(Point(21500, 2500), Point(21500, 4000), 0, 2, 150, 2800, 0);
  AddSegmentEx(Point(21500, 4000), Point(32000, 4000), 0, 2, 150, 2800, 0);
  // Parede direita (com porta de abrir de 90cm)
  AddSegmentEx(Point(32000, 4000), Point(32000, 21000), 0, 2, 150, 2800, 0);
  // Parede inferior esquerda + vão central + parede inferior direita
  AddSegmentEx(Point(8000, 18000), Point(23000, 18000), 0, 2, 150, 2800, 0);
  AddSegmentEx(Point(27000, 18000), Point(32000, 18000), 0, 2, 150, 2800, 0);

  // 2. Janela na parede esquerda (Aula 06: 1,96 x 1,20 x 0,90 m -> 1960 x 1200 x 900 mm)
  AddSegmentEx(Point(8000, 7000), Point(8000, 16000), 1, 4, 150, 1200, 900);
  // Linha de soleira no vão superior
  AddSegmentEx(Point(16000, 2700), Point(21500, 2700), 1, 0, 50, 0, 0);
  // Linha de soleira no vão inferior
  AddSegmentEx(Point(23000, 18000), Point(27000, 18000), 1, 0, 50, 0, 0);

  // 3. Porta de abrir 90° com arco na direita/inferior (Kind=3, Layer=1 ARQ_ESQUADRIAS)
  AddSegmentEx(Point(32000, 17750), Point(27250, 17750), 1, 3, 900, 2100, 0);

  // 4. Mobiliário humanizado na Layer "Mobiliário" (Layer=2)
  // Rack de TV (Kind=7)
  AddSegmentEx(Point(8750, 4600), Point(16750, 6700), 2, 7, 1600, 500, 0);
  // Tapete listrado + Sofá 2 lugares + Pufe/Mesa de centro (Kind=5)
  AddSegmentEx(Point(8800, 7600), Point(19000, 17250), 2, 5, 2200, 1800, 0);
  // Mesa de jantar redonda com 4 cadeiras (Kind=6)
  AddSegmentEx(Point(23250, 5500), Point(30750, 13000), 2, 6, 1200, 1200, 0);
  // Vaso de planta decorativa (Kind=8)
  AddSegmentEx(Point(19250, 13250), Point(22250, 16500), 2, 8, 600, 600, 0);

  Inc(FNextGroup);
  FSelected := -1;
  if Assigned(FCanvas) then FCanvas.Invalidate;
  FPath := '';
  UpdateDocumentTitle;
  ZoomExtents(nil);
  LogCommand('Planta de exemplo 2D carregada');
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
      if not FLayerVisible[FLines[I].Layer] then Continue;
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
  if TControl(Sender).Tag > 0 then
    ZoomAt(Point(FCanvas.Width div 2, FCanvas.Height div 2), 1.25)
  else ZoomAt(Point(FCanvas.Width div 2, FCanvas.Height div 2), 0.8);
end;

function TCADMainForm.Snapshot: string;
var D: TCADDocument;
begin
  D := TCADDocument.Create;
  try D.Lines := FLines; D.Labels := FLabels; D.GridMM := FGrid;
    D.Visible := FLayerVisible; D.Locked := FLayerLocked; Result := D.Text;
  finally D.Free; end;
end;

procedure TCADMainForm.RestoreSnapshot(const Value: string);
var D: TCADDocument; I: Integer;
begin
  D := TCADDocument.Create;
  try
    D.LoadText(Value); FLines := D.Lines; FLabels := D.Labels; FGrid := D.GridMM;
    FLayerVisible := D.Visible; FLayerLocked := D.Locked; FNextGroup := 1;
    for I := 0 to High(FLines) do FNextGroup := Max(FNextGroup,FLines[I].GroupID+1);
    FSelected := -1; SyncLayerPanel; FCanvas.Invalidate;
  finally D.Free; end;
end;

procedure TCADMainForm.RecordChange;
begin
  if not Assigned(FHistory) then Exit;
  FDirty := True;
  FHistory.BeginChange('Editar desenho 2D', Snapshot);
  FHistory.EndChange;
end;

procedure TCADMainForm.UndoHistory(Sender: TObject);
begin
  if not WorkflowEditAllowed then Exit;
  if not FHistory.CanUndo then Exit;
  RestoreSnapshot(FHistory.Undo(Snapshot));
  FDirty := True;
  LogCommand('UNDO');
  RefreshStatus('Alteração desfeita');
end;

procedure TCADMainForm.RedoHistory(Sender: TObject);
begin
  if not WorkflowEditAllowed then Exit;
  if not FHistory.CanRedo then Exit;
  RestoreSnapshot(FHistory.Redo(Snapshot));
  FDirty := True;
  LogCommand('REDO');
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
  ThicknessPx := Max(3.0, 200.0 * FZoom);
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
    W2 := Round(800 * FZoom);
    H2 := Round(600 * FZoom);
    LX[0] := -W2; LY[0] := -H2;
    LX[1] :=  W2; LY[1] := -H2;
    LX[2] :=  W2; LY[2] :=  H2;
    LX[3] := -W2; LY[3] :=  H2;
    for K := 0 to 3 do begin
      Pts[K].X := CenterX + Round(LX[K] * Cos(AngleRad) - LY[K] * Sin(AngleRad));
      Pts[K].Y := CenterY + Round(LX[K] * Sin(AngleRad) + LY[K] * Cos(AngleRad));
    end;
    C.Brush.Style := bsClear;
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
      C.Brush.Style := bsClear;
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
      C.Brush.Style := bsClear;
      C.Brush.Color := RGBToColor(178, 156, 110);
      C.Pen.Color := OutlineColor;
      C.Ellipse(CX - Round(Rad * 0.72), CY - Round(Rad * 0.72), CX + Round(Rad * 0.72), CY + Round(Rad * 0.72));
    end;

    7: begin
      // Rack de TV em madeira com televisor vermelho/escuro
      C.Brush.Style := bsClear;
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
      C.Brush.Style := bsClear;
      C.Brush.Color := RGBToColor(78, 125, 68);
      C.Pen.Color := OutlineColor;
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
  X, Y, I, MX, MY, GridStep: Integer;
  R: TRect;
  MM: Double;
  SA, SB, SnapM: TPoint;
begin
  R := FCanvas.ClientRect;
  GridStep := FGrid * Max(1, Ceil(8 / (FGrid * FZoom)));
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
    for X := Floor(-FPanX / (GridStep * FZoom)) to Ceil((FCanvas.Width - FPanX) / (GridStep * FZoom)) do begin
      if (X mod 5) = 0 then
        FCanvas.Canvas.Pen.Color := IfThen(FDarkModelSpace, RGBToColor(44, 54, 66), RGBToColor(210, 218, 230))
      else
        FCanvas.Canvas.Pen.Color := IfThen(FDarkModelSpace, RGBToColor(33, 41, 50), RGBToColor(234, 238, 245));
      MX := Round(X * GridStep * FZoom) + FPanX;
      FCanvas.Canvas.MoveTo(MX, 0);
      FCanvas.Canvas.LineTo(MX, FCanvas.Height);
    end;
    for Y := Floor(-FPanY / (GridStep * FZoom)) to Ceil((FCanvas.Height - FPanY) / (GridStep * FZoom)) do begin
      if (Y mod 5) = 0 then
        FCanvas.Canvas.Pen.Color := IfThen(FDarkModelSpace, RGBToColor(44, 54, 66), RGBToColor(210, 218, 230))
      else
        FCanvas.Canvas.Pen.Color := IfThen(FDarkModelSpace, RGBToColor(33, 41, 50), RGBToColor(234, 238, 245));
      MY := Round(Y * GridStep * FZoom) + FPanY;
      FCanvas.Canvas.MoveTo(0, MY);
      FCanvas.Canvas.LineTo(FCanvas.Width, MY);
    end;
  end;

  // 3. Passada 1: Blocos de Mobiliário (para ficarem sob as paredes/portas)
  for I := 0 to High(FLines) do begin
    if (FLines[I].Layer >= 0) and (FLines[I].Layer <= High(FLayerVisible)) and
       (not FLayerVisible[FLines[I].Layer]) then Continue;
    if FLines[I].Kind in [5..8] then
      DrawFurnitureBlock(FCanvas.Canvas, FLines[I], EntitySelected(I));
  end;

  // 4. Passada 2: Paredes Duplas com abertura automática de vãos e Linhas comuns
  for I := 0 to High(FLines) do begin
    if (FLines[I].Layer >= 0) and (FLines[I].Layer <= High(FLayerVisible)) and
       (not FLayerVisible[FLines[I].Layer]) then Continue;
    if FLines[I].Kind = 2 then
      DrawDoubleWallWithOpenings(FCanvas.Canvas, I, EntitySelected(I))
    else if FLines[I].Kind in [0, 1] then begin
      FCanvas.Canvas.Pen.Style := psSolid;
      FCanvas.Canvas.Pen.Width := IfThen(EntitySelected(I), 3, 2);
      FCanvas.Canvas.Pen.Color := IfThen(EntitySelected(I), clFuchsia, LayerColor(FLines[I].Layer));
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
      DrawArchitecturalDoor(FCanvas.Canvas, FLines[I], EntitySelected(I))
    else if FLines[I].Kind in [4, 9] then
      DrawArchitecturalWindow(FCanvas.Canvas, FLines[I], EntitySelected(I));
  end;

  // 6. Cotas lineares das paredes/linhas quando FShowDimensions estiver ativo
  if FShowDimensions and FLayerVisible[3] then begin
    for I := 0 to High(FLines) do begin
      if not (FLines[I].Kind in [0, 2]) or (FLines[I].CatalogID<>'') then Continue;
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
  if FLayerVisible[4] then begin
    FCanvas.Canvas.Brush.Style := bsClear; FCanvas.Canvas.Font.Color := LayerColor(4); FCanvas.Canvas.Font.Size := 9;
    for I := 0 to High(FLabels) do begin
      SA := WorldToScreen(Point(FLabels[I].X,FLabels[I].Y));
      FCanvas.Canvas.TextOut(SA.X,SA.Y,FLabels[I].Text);
    end;
  end;
  DrawUCSIcon(FCanvas.Canvas, R);
  DrawCrosshair(FCanvas.Canvas, R);
end;

procedure TCADMainForm.CanvasClick(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  if Button = mbMiddle then begin
    FPanning := True;
    FPanStart := Point(X, Y);
    SetCaptureControl(FCanvas);
    Exit;
  end;
  if Button = mbRight then begin
    FHasStart := False;
    FCanvas.Invalidate;
    RefreshStatus('Comando cancelado (*Cancel*)');
    LogCommand('*Cancel*');
    Exit;
  end;
  if Button <> mbLeft then Exit;
  if (FToolSelect.ItemIndex <> 5) and not WorkflowEditAllowed then Exit;
  if FToolSelect.ItemIndex <> 5 then
    if FLayerLocked[FLayerSelect.ItemIndex] or not FLayerVisible[FLayerSelect.ItemIndex] then begin
      RefreshStatus('Escolha uma camada visível e desbloqueada para desenhar.');
      Exit;
    end;
  P := Snap(Point(X, Y));
  if FToolSelect.ItemIndex = 12 then begin
    try
      InsertCatalog(FPendingCatalogID,P,FPendingCatalogWidth,FPendingCatalogDepth);
      FToolSelect.ItemIndex := 5; FHasStart := False;
    except on E: Exception do ShowMessage(E.Message); end;
    Exit;
  end;
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
  if FPanning then begin
    Inc(FPanX, X - FPanStart.X); Inc(FPanY, Y - FPanStart.Y);
    FPanStart := Point(X, Y);
  end;
  FMousePos := Point(X, Y);
  FHasMouse := True;
  P := Snap(Point(X, Y));
  if Assigned(FCoordLabel) then
    FCoordLabel.Caption := Format('X: %.0f  Y: %.0f mm  ',
      [P.X * FMillimetersPerPixel * 1.0, -P.Y * FMillimetersPerPixel * 1.0]);
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
  if ssCtrl in Shift then begin
    case Key of
      Ord('N'): NewDrawing(nil);
      Ord('O'): OpenDrawing(nil);
      Ord('S'): SaveDrawing(nil);
      Ord('Z'): if ActiveControl <> FCmdEdit then UndoHistory(nil) else Exit;
      Ord('Y'): if ActiveControl <> FCmdEdit then RedoHistory(nil) else Exit;
      Ord('L'): ToggleOrthoClick(nil);
      Ord('B'): ToggleSnapClick(nil);
      Ord('1'): FLayerPanel.Visible := not FLayerPanel.Visible;
      Ord('9'): begin
        if FCommandDock.Visible and (ActiveControl = FCmdEdit) then ActiveControl := nil;
        FCommandDock.Visible := not FCommandDock.Visible;
      end;
    else Exit;
    end;
    Key := 0;
    Exit;
  end;
  case Key of
    VK_ESCAPE: begin
      FHasStart := False; FSelected := -1;
      FCmdEdit.Clear; ActiveControl := nil;
      FCanvas.Invalidate;
      RefreshStatus('Comando cancelado');
    end;
    VK_F1: ExecuteCommandString('AJUDA');
    VK_F2: begin FCommandDock.Visible := True;
      if FCommandDock.Height = 68 then FCommandDock.Height := 180 else FCommandDock.Height := 68; end;
    VK_F3: ToggleOsnapClick(nil);
    VK_F7: ToggleGridClick(nil);
    VK_F8: ToggleOrthoClick(nil);
    VK_F9: ToggleSnapClick(nil);
    VK_DELETE: begin
      if ActiveControl = FCmdEdit then Exit;
      DeleteSelected(nil);
    end;
  else Exit;
  end;
  Key := 0;
end;

procedure TCADMainForm.TypeCommand(Sender: TObject; var UTF8Key: TUTF8Char);
begin
  if (ActiveControl = FCmdEdit) or (ActiveControl is TCustomEdit) then Exit;
  if (Length(UTF8Key) = 0) or (Ord(UTF8Key[1]) < 32) then Exit;
  FCommandDock.Visible := True;
  FCmdEdit.SetFocus;
  FCmdEdit.SelText := UTF8Key;
  UTF8Key := '';
end;

procedure TCADMainForm.ExecuteCommandString(const RawCmd: string);
var
  Cmd: string;
  LenMM, StepPx: Integer;
  DX, DY, L: Double;
  EndPt: TPoint;
begin
  FCommandDock.Visible := True;
  LogCommand(RawCmd);
  Cmd := UpperCase(Trim(RawCmd));

  // Se estiver desenhando um segmento e digitar um comprimento em milímetros (ex: 3000)
  if FHasStart and TryStrToInt(Cmd, LenMM) and (LenMM > 0) and (LenMM <= 1000000) then begin
    StepPx := Max(1, Round(LenMM / FMillimetersPerPixel));
    DX := FMousePos.X - WorldToScreen(FStart).X;
    DY := FMousePos.Y - WorldToScreen(FStart).Y;
    if FOrthoEnabled then begin
      if Abs(DX) >= Abs(DY) then begin
        EndPt.X := FStart.X + IfThen(DX >= 0, StepPx, -StepPx);
        EndPt.Y := FStart.Y;
      end else begin
        EndPt.X := FStart.X;
        EndPt.Y := FStart.Y + IfThen(DY >= 0, StepPx, -StepPx);
      end;
    end else begin
      L := Hypot(DX, DY);
      if L < 1 then begin DX := 1; DY := 0; L := 1; end;
      EndPt.X := FStart.X + Round(DX / L * StepPx);
      EndPt.Y := FStart.Y + Round(DY / L * StepPx);
    end;
    if not WorkflowEditAllowed then Exit;
    RecordChange;
    AddSegment(FStart, EndPt);
    Inc(FNextGroup);
    FHasStart := False;
    FCanvas.Invalidate;
    RefreshStatus(Format('Comprimento solicitado: %d mm | Resolução do modelo: %d mm', [LenMM, FMillimetersPerPixel]));
    Exit;
  end;

  case Cmd of
    'BIB', 'BIBLIOTECA': ChooseCatalog(nil);
    'DEMOUBS': LoadSampleFloorPlan(nil);
    'DEMOHOSPITAL': LoadHospitalExample(nil);
    'DEMOGERAL': LoadGeneralSampleFloorPlan(nil);
    'X', 'EXPLODE', 'DESAGRUPAR': ExplodeSelection(nil);
    '2D': DrawingViewClick(nil);
    'TAREFA': TaskViewClick(nil);
    'RESPONDER': ReplyTaskClick(nil);
    'DEVOLVER': ReturnTaskClick(nil);
    'PLANEJADOR': PlannerClick(nil);
    'NEW', 'NOVO': NewDrawing(nil);
    'L', 'LINE', 'LINHA': begin FToolSelect.ItemIndex := 0; SelectionChanged(nil); end;
    'REC', 'RECTANG', 'RETANGULO': begin FToolSelect.ItemIndex := 1; SelectionChanged(nil); end;
    'PA', 'PAREDE', 'WALL', 'MLINE': begin FToolSelect.ItemIndex := 2; FLayerSelect.ItemIndex := 0; SelectionChanged(nil); end;
    'PO', 'PORTA', 'DOOR': begin FToolSelect.ItemIndex := 3; FLayerSelect.ItemIndex := 1; SelectionChanged(nil); end;
    'JA', 'JANELA', 'WINDOW': begin FToolSelect.ItemIndex := 4; FLayerSelect.ItemIndex := 1; SelectionChanged(nil); end;
    'JAA', 'JANELAALTA': begin FToolSelect.ItemIndex := 11; FLayerSelect.ItemIndex := 5; SelectionChanged(nil); end;
    'C', 'CIRCLE', 'CIRCULO': begin FToolSelect.ItemIndex := 6; SelectionChanged(nil); end;
    'SEL', 'SELECT': begin FToolSelect.ItemIndex := 5; SelectionChanged(nil); end;
    'M', 'MOVE', 'MOVER': TransformSelected(nil);
    'CO', 'CP', 'COPY', 'COPIAR': begin FQuickBar.Tag := 1; try TransformSelected(FQuickBar); finally FQuickBar.Tag := 0; end; end;
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
    'GRID': ToggleGridClick(nil);
    'SNAP': ToggleSnapClick(nil);
    'ORTHO': ToggleOrthoClick(nil);
    'OSNAP': ToggleOsnapClick(nil);
    'DIM', 'COTA', 'COTAS': ToggleDimensions(nil);
    'DI', 'DIST', 'MEASURE', 'MEDIR': MeasureSelected(nil);
    'QSAVE', 'SAVE', 'SALVAR': SaveDrawing(nil);
    'OPEN', 'ABRIR': OpenDrawing(nil);
    'DXF': ExportDXF(nil);
    'IMPORTDXF', 'DXFIN': ImportDXF(nil);
    'PROPERTIES', 'PROPRIEDADES': EditLastObject(nil);
    'SOFA': begin FToolSelect.ItemIndex := 7; FLayerSelect.ItemIndex := 2; SelectionChanged(nil); end;
    'MESA': begin FToolSelect.ItemIndex := 8; FLayerSelect.ItemIndex := 2; SelectionChanged(nil); end;
    'RACK': begin FToolSelect.ItemIndex := 9; FLayerSelect.ItemIndex := 2; SelectionChanged(nil); end;
    'PLANTA': begin FToolSelect.ItemIndex := 10; FLayerSelect.ItemIndex := 2; SelectionChanged(nil); end;
    'FUNDO': ToggleThemeClick(nil);
    'SVG': ExportSVG(nil);
    'DEMO', 'EXEMPLO': LoadSampleFloorPlan(nil);
    'LA', 'CAMADAS', 'LAYER': begin FLayerPanel.Visible := not FLayerPanel.Visible; end;
    'AJUDA', 'HELP': LogCommand('LINHA, RETANGULO, CIRCULO, PAREDE, PORTA, JANELA, JANELAALTA, SEL, MOVE, OFFSET, TRIM, EXTEND, FILLET, UNDO, REDO, ZOOM, CAMADAS, SALVAR, ABRIR, DXF, SVG');
  else
    RefreshStatus('Comando desconhecido: ' + Cmd + ' (use L, WALL, PORTA, JANELA, OFFSET, TRIM, EXTEND, FILLET, QSAVE)');
  end;
end;

procedure TCADMainForm.NewDrawing(Sender: TObject);
begin
  if not WorkflowEditAllowed then Exit;
  if (Length(FLines) > 0) and
    (MessageDlg('Novo desenho', 'Descartar o desenho atual?',
     mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
  RecordChange;
  SetLength(FLines, 0);
  SetLength(FLabels, 0);
  SetLength(FUndo, 0);
  FNextGroup := 1;
  FHasStart := False;
  FSelected := -1;
  FPath := '';
  UpdateDocumentTitle;
  FCanvas.Invalidate;
  LogCommand('_NEW');
  RefreshStatus('Novo desenho em branco');
end;

procedure TCADMainForm.UndoLine(Sender: TObject);
var
  G, N: Integer;
begin
  if not WorkflowEditAllowed then Exit;
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
  if not WorkflowEditAllowed then Exit;
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
    if not FLayerVisible[FLines[I].Layer] or FLayerLocked[FLines[I].Layer] then Continue;
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
  if (FSelected>=0) and (FLines[FSelected].CatalogID<>'') then begin
    try RefreshStatus('Bloco: '+Catalog.Item(FLines[FSelected].CatalogID).Get('name','')+' | Mover, copiar, girar ou editar envelope');
    except RefreshStatus('Bloco: '+FLines[FSelected].CatalogID); end;
  end else if FSelected >= 0 then
    RefreshStatus(Format('Selecionado #%d (%s — %d mm)',
      [FSelected + 1, LAYER_NAMES[Min(High(LAYER_NAMES), Max(0, FLines[FSelected].Layer))], FLines[FSelected].WidthMM]))
  else
    RefreshStatus('Nenhum objeto próximo');
end;

procedure TCADMainForm.DeleteSelected(Sender: TObject);
var Members: TCADIndices; I,J: Integer;
begin
  if not CanModifySelection then Exit;
  Members := SelectionMembers; if Length(Members)=0 then Exit;
  RecordChange;
  for I := High(Members) downto 0 do begin
    for J := Members[I] to High(FLines)-1 do FLines[J] := FLines[J+1];
    SetLength(FLines,Length(FLines)-1);
  end;
  FSelected := -1; FCanvas.Invalidate; RefreshStatus('Seleção excluída');
end;

procedure TCADMainForm.TransformSelected(Sender: TObject);
var
  SX, SY: string;
  DX, DY, Id, N: Integer;
  IsCopy: Boolean;
begin
  if not WorkflowEditAllowed then Exit;
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
  MoveSelectionMM(DX,DY,IsCopy);
  FCanvas.Invalidate;
  if IsCopy then RefreshStatus('Objeto copiado')
  else RefreshStatus('Objeto movido');
end;

procedure TCADMainForm.RotateSelected(Sender: TObject);
var AngleText: string; Degrees: Double;
begin
  if not CanModifySelection then Exit;
  AngleText := '90';
  if not InputQuery('Girar seleção','Ângulo em graus (sentido horário na tela):',AngleText) then Exit;
  if not TryStrToFloat(AngleText,Degrees) or IsNan(Degrees) or IsInfinite(Degrees) or (Abs(Degrees)>36000) then begin ShowMessage('Ângulo inválido'); Exit; end;
  RotateSelectionDegrees(Degrees);
end;

procedure TCADMainForm.MirrorSelected(Sender: TObject);
begin MirrorSelection(Assigned(Sender) and (TControl(Sender).Tag=0)); end;

procedure TCADMainForm.OffsetSelected(Sender: TObject);
var
  N, Id: Integer;
  DistanceText: string;
  MM, DX, DY, Len, ShiftX, ShiftY: Double;
begin
  if (FSelected>=0) and (FSelected<Length(FLines)) and (FLines[FSelected].CatalogID<>'') then begin ShowMessage('Desagrupe o bloco antes de editar segmentos individuais.'); Exit; end;
  if not WorkflowEditAllowed then Exit;
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
  if (FSelected>=0) and (FSelected<Length(FLines)) and (FLines[FSelected].CatalogID<>'') then begin ShowMessage('Desagrupe o bloco antes de editar segmentos individuais.'); Exit; end;
  if not WorkflowEditAllowed then Exit;
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
  if (FSelected>=0) and (FSelected<Length(FLines)) and (FLines[FSelected].CatalogID<>'') then begin ShowMessage('Desagrupe o bloco antes de editar segmentos individuais.'); Exit; end;
  if not WorkflowEditAllowed then Exit;
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
  if (FSelected>=0) and (FSelected<Length(FLines)) and (FLines[FSelected].CatalogID<>'') then begin ShowMessage('Desagrupe o bloco antes de editar segmentos individuais.'); Exit; end;
  if not WorkflowEditAllowed then Exit;
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
  if (FSelected>=0) and (FSelected<Length(FLines)) and (FLines[FSelected].CatalogID<>'') then begin ShowMessage('Desagrupe o bloco antes de editar segmentos individuais.'); Exit; end;
  if not WorkflowEditAllowed then Exit;
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
  if (FSelected>=0) and (FSelected<Length(FLines)) and (FLines[FSelected].CatalogID<>'') then begin
    ChooseCatalogResize; Exit;
  end;
  if not WorkflowEditAllowed then Exit;
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
  Bounds: TRect; Members: TCADIndices; I,J: Integer;
  MM: Double;
  V: string;
begin
  if (FSelected < 0) or (FSelected >= Length(FLines)) then begin
    ShowMessage('Selecione um segmento antes de medir.');
    Exit;
  end;
  if FLines[FSelected].CatalogID<>'' then begin
    Members:=SelectionMembers; Bounds:=Rect(MaxInt,MaxInt,-MaxInt,-MaxInt);
    for I:=0 to High(Members) do begin J:=Members[I];
      Bounds.Left:=Min(Bounds.Left,Min(FLines[J].A.X,FLines[J].B.X)); Bounds.Right:=Max(Bounds.Right,Max(FLines[J].A.X,FLines[J].B.X));
      Bounds.Top:=Min(Bounds.Top,Min(FLines[J].A.Y,FLines[J].B.Y)); Bounds.Bottom:=Max(Bounds.Bottom,Max(FLines[J].A.Y,FLines[J].B.Y));
    end;
    ShowMessage(Format('Envelope do bloco 2D: %d × %d mm',[Bounds.Right-Bounds.Left,Bounds.Bottom-Bounds.Top])); Exit;
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
  function XMLText(const S: string): string;
  begin
    Result:=StringReplace(S,'&','&amp;',[rfReplaceAll]);
    Result:=StringReplace(Result,'<','&lt;',[rfReplaceAll]);
    Result:=StringReplace(Result,'>','&gt;',[rfReplaceAll]);
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
    for I:=0 to High(FLabels) do begin MinX:=Min(MinX,FLabels[I].X); MinY:=Min(MinY,FLabels[I].Y-200); MaxX:=Max(MaxX,FLabels[I].X+Length(FLabels[I].Text)*180); MaxY:=Max(MaxY,FLabels[I].Y+200); end;
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
    for I:=0 to High(FLabels) do L.Add('<text x="'+Num(FLabels[I].X)+'" y="'+Num(FLabels[I].Y)+'" font-family="sans-serif" font-size="180" fill="#16324f">'+XMLText(FLabels[I].Text)+'</text>');
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

procedure TCADMainForm.SaveDocumentFile(const FileName: string);
var D: TCADDocument;
begin
  FSaveSucceeded := False;
  if not WorkflowEditAllowed then Exit;
  D := TCADDocument.Create;
  try
    D.Lines := FLines; D.Labels := FLabels; D.GridMM := FGrid;
    D.Visible := FLayerVisible; D.Locked := FLayerLocked;
    D.Save(FileName);
    FPath := ExpandFileName(FileName); FSaveSucceeded := True; FDirty := False;
    UpdateDocumentTitle;
  finally D.Free; end;
end;

procedure TCADMainForm.LoadDocumentFile(const FileName: string);
var D: TCADDocument; I, NextGroup: Integer;
begin
  D := TCADDocument.Create;
  try
    D.Load(FileName); NextGroup := 1;
    for I := 0 to High(D.Lines) do NextGroup := Max(NextGroup,D.Lines[I].GroupID+1);
    FLines := D.Lines; FLabels := D.Labels; FGrid := D.GridMM;
    FLayerVisible := D.Visible; FLayerLocked := D.Locked;
    FMillimetersPerPixel := 1; FNextGroup := NextGroup;
    FHistory.Clear; SetLength(FUndo,0); FSelected := -1; FHasStart := False;
    FPath := ExpandFileName(FileName); FDirty := False;
    UpdateDocumentTitle; SyncLayerPanel;
    Application.QueueAsyncCall(@FitDrawingAsync,0);
    FCanvas.Invalidate;
  finally D.Free; end;
end;

procedure TCADMainForm.SaveDrawing(Sender: TObject);
var D: TSaveDialog;
begin
  FSaveSucceeded := False;
  if not WorkflowEditAllowed then Exit;
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Projeto CAD 2D (*.eacad)|*.eacad'; D.DefaultExt := 'eacad';
    D.Options := D.Options + [ofOverwritePrompt];
    if FPath <> '' then D.FileName := FPath else D.FileName := 'planta.eacad';
    if not D.Execute then Exit;
    try
      SaveDocumentFile(D.FileName);
      RefreshStatus('Projeto salvo: '+ExtractFileName(FPath));
    except on E: Exception do MessageDlg('Erro ao salvar projeto',E.Message,mtError,[mbOK],0); end;
  finally D.Free; end;
end;

procedure TCADMainForm.OpenDrawing(Sender: TObject);
var D: TOpenDialog;
begin
  if not ConfirmDrawingSwitch then Exit;
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Projeto CAD 2D (*.eacad)|*.eacad';
    if FOpenPath <> '' then D.FileName := FOpenPath else if not D.Execute then Exit;
    try
      LoadDocumentFile(D.FileName);
      RefreshStatus('Projeto aberto: '+ExtractFileName(FPath));
    except on E: Exception do MessageDlg('Erro ao abrir projeto',E.Message,mtError,[mbOK],0); end;
  finally D.Free; end;
end;

procedure TCADMainForm.DrawingShown(Sender: TObject);
begin
  if FInitialFitPending then begin
    FInitialFitPending := False;
    Application.QueueAsyncCall(@FitDrawingAsync,0);
  end;
end;

procedure TCADMainForm.FitDrawingAsync(Data: PtrInt);
begin ZoomExtents(nil); end;

procedure TCADMainForm.RibbonTabClick(Sender: TObject);
var I, Page, X: Integer; ShowGroup: Boolean;
begin
  Page := TControl(Sender).Tag;
  X := 0;
  FRibbonPanel.DisableAlign;
  try
    for I := 0 to High(FRibbonGroups) do begin
      case Page of
        0: ShowGroup := I in [0, 1, 4, 6];
        1: ShowGroup := I in [2, 4, 5, 6];
        2: ShowGroup := I in [1, 3, 4];
        3: ShowGroup := I in [4, 6];
      else ShowGroup := I = 7;
      end;
      FRibbonGroups[I].Visible := ShowGroup;
      FRibbonGroups[I].Left := X;
      if ShowGroup then Inc(X, FRibbonGroups[I].Width + 2);
    end;
  finally FRibbonPanel.EnableAlign; end;
  for I := 0 to High(FRibbonTabs) do
    if I = Page then begin
      FRibbonTabs[I].Font.Color := clWhite;
      FRibbonTabs[I].Font.Style := [fsBold];
    end else begin
      FRibbonTabs[I].Font.Color := RGBToColor(175, 182, 192);
      FRibbonTabs[I].Font.Style := [];
    end;
end;

procedure TCADMainForm.SyncLayerPanel;
var I: Integer;
begin
  if not Assigned(FLayerList) then Exit;
  FUpdatingLayers := True;
  try
    for I := 0 to High(LAYER_NAMES) do FLayerList.Checked[I] := FLayerVisible[I];
    FLayerList.ItemIndex := FLayerSelect.ItemIndex;
    FLayerLock.Checked := FLayerLocked[Max(0, FLayerSelect.ItemIndex)];
  finally FUpdatingLayers := False; end;
end;

procedure TCADMainForm.LayerListClick(Sender: TObject);
begin
  if FUpdatingLayers or (FLayerList.ItemIndex < 0) then Exit;
  FLayerSelect.ItemIndex := FLayerList.ItemIndex;
  SelectionChanged(nil);
end;

procedure TCADMainForm.LayerCheckClick(Sender: TObject);
var I: Integer;
begin
  if FUpdatingLayers then Exit;
  I := FLayerList.ItemIndex;
  if I < 0 then Exit;
  FDirty := True;
  FLayerVisible[I] := FLayerList.Checked[I];
  FLayerSelect.ItemIndex := I;
  if not FLayerVisible[I] and (FSelected >= 0) and (FLines[FSelected].Layer = I) then FSelected := -1;
  UpdateLayerSwatch;
  FCanvas.Invalidate;
end;

procedure TCADMainForm.UpdateDocumentTitle;
var DocName: string;
begin
  if FPath = '' then DocName := 'Sem título.eacad' else DocName := ExtractFileName(FPath);
  Caption := DocName + ' — CAD Arquitetônico 2D — EngenhariaArquitetura';
  if Assigned(FDocumentLabel) then FDocumentLabel.Caption := DocName + ' | Superior | Estrutura 2D';
end;

procedure TCADMainForm.ZoomAt(const P: TPoint; Factor: Double);
var WX, WY: Double;
begin
  WX := (P.X - FPanX) / FZoom; WY := (P.Y - FPanY) / FZoom;
  FZoom := EnsureRange(FZoom * Factor, 0.00001, 20.0);
  FPanX := Round(P.X - WX * FZoom); FPanY := Round(P.Y - WY * FZoom);
  FCanvas.Invalidate;
  RefreshStatus(Format('Vista superior 2D | Zoom %.1f%%', [FZoom * 5000]));
end;

procedure TCADMainForm.WheelDrawing(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var P: TPoint;
begin
  P := FCanvas.ScreenToClient(MousePos);
  if not PtInRect(FCanvas.ClientRect, P) then Exit;
  if WheelDelta > 0 then ZoomAt(P, 1.25) else ZoomAt(P, 0.8);
  Handled := True;
end;

procedure TCADMainForm.MouseUpDrawing(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbMiddle then begin
    FPanning := False;
    SetCaptureControl(nil);
  end;
end;


procedure TCADMainForm.BuildDropMenus;
var Item, Header: TMenuItem;
  {$IFDEF WINDOWS}Info: Windows.TMenuInfo;{$ENDIF}
  procedure Group(const ACaption: string);
  begin
    Header := TMenuItem.Create(FMainMenu);
    Header.Caption := ACaption;
    FMainMenu.Items.Add(Header);
  end;
  procedure Entry(const ACaption, Cmd, Keys: string);
  begin
    Item := TMenuItem.Create(FMainMenu);
    Item.Caption := ACaption + #9 + Keys;
    Item.Hint := Cmd;
    Item.OnClick := @MenuCommand;
    Header.Add(Item);
  end;
begin
  FMainMenu := TMainMenu.Create(Self);
  FMainMenu.OwnerDraw := True;
  FMainMenu.OnDrawItem := @DrawDropMenu;
  FMainMenu.OnMeasureItem := @MeasureDropMenu;
  Self.Menu := FMainMenu;
  Group('&Arquivo');
  Entry('Novo desenho', 'NEW', 'Ctrl+N'); Entry('Abrir projeto...', 'OPEN', 'Ctrl+O');
  Entry('Salvar projeto...', 'SAVE', 'Ctrl+S'); Entry('Salvar como...', 'SAVE', 'Ctrl+Shift+S');
  Entry('Importar DXF (linhas)...', 'IMPORTDXF', 'DXFIN');
  Entry('Exportar DXF 2D...', 'DXF', 'DXF'); Entry('Exportar SVG 2D...', 'SVG', 'SVG');
  Entry('Carregar exemplo 2D', 'EXEMPLO', '');
  Group('&Editar');
  Entry('Desfazer', 'UNDO', 'Ctrl+Z'); Entry('Refazer', 'REDO', 'Ctrl+Y');
  Entry('Excluir seleção', 'ERASE', 'Del'); Entry('Propriedades...', 'PROPERTIES', '');
  Group('&Desenhar');
  Entry('Linha', 'LINE', 'L'); Entry('Retângulo', 'RECTANG', 'REC'); Entry('Círculo', 'CIRCLE', 'C');
  Entry('Selecionar', 'SELECT', 'SEL');
  Group('&Modificar');
  Entry('Mover...', 'MOVE', 'M'); Entry('Copiar...', 'COPY', 'CO'); Entry('Girar...', 'ROTATE', 'RO');
  Entry('Espelhar...', 'MIRROR', 'MI'); Entry('Deslocamento paralelo...', 'OFFSET', 'O');
  Entry('Aparar...', 'TRIM', 'TR'); Entry('Estender...', 'EXTEND', 'EX');
  Entry('Arredondar...', 'FILLET', 'F'); Entry('Chanfrar...', 'CHAMFER', 'CHA');
  Group('Ar&quitetura');
  Entry('Parede em planta', 'WALL', 'PA'); Entry('Porta em planta', 'PORTA', 'PO');
  Entry('Janela baixa', 'JANELA', 'JA'); Entry('Janela alta tracejada', 'JANELAALTA', 'JAA');
  Entry('Símbolo de sofá', 'SOFA', ''); Entry('Símbolo de mesa', 'MESA', '');
  Entry('Símbolo de rack', 'RACK', ''); Entry('Símbolo de vegetação', 'PLANTA', '');
  Group('An&otar');
  Entry('Exibir comprimentos', 'DIM', 'DIM'); Entry('Medir seleção', 'DIST', 'DI');
  Group('E&xibir');
  Entry('Enquadrar desenho', 'ZOOM', 'Z'); Entry('Camadas', 'LAYER', 'Ctrl+1');
  Entry('Grade', 'GRID', 'F7'); Entry('Ortogonal', 'ORTHO', 'F8');
  Entry('Captura na grade', 'SNAP', 'F9'); Entry('Captura de objetos', 'OSNAP', 'F3');
  Entry('Alternar fundo', 'FUNDO', '');
  Group('&Biblioteca'); Entry('Mobiliário e equipamentos...', 'BIBLIOTECA', 'BIB');
  Entry('Exemplo UBS (esquemático)', 'DEMOUBS', ''); Entry('Exemplo de ala hospitalar', 'DEMOHOSPITAL', '');
  Entry('Exemplo geral', 'DEMOGERAL', ''); Entry('Desagrupar bloco', 'EXPLODE', 'X');
  Group('&Gestão'); Entry('Tarefa e arquivo', 'TAREFA', '');
  Entry('Responder tarefa', 'RESPONDER', ''); Entry('Devolver tarefa', 'DEVOLVER', '');
  Entry('Voltar ao Planejador', 'PLANEJADOR', '');
  Group('A&juda'); Entry('Comandos e atalhos', 'AJUDA', 'F1');
  {$IFDEF WINDOWS}
  FMenuBrush := Windows.CreateSolidBrush(RGBToColor(30, 64, 145));
  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(Info);
  Info.fMask := MIM_BACKGROUND or MIM_APPLYTOSUBMENUS;
  Info.hbrBack := FMenuBrush;
  Windows.SetMenuInfo(FMainMenu.Handle, @Info);
  {$ENDIF}
end;

procedure TCADMainForm.MenuCommand(Sender: TObject);
begin ExecuteCommandString(TMenuItem(Sender).Hint); end;

procedure TCADMainForm.MeasureDropMenu(Sender: TObject; ACanvas: TCanvas;
  var AWidth, AHeight: Integer);
begin
  ACanvas.Font.Name := Font.Name; ACanvas.Font.Size := 9;
  if TMenuItem(Sender).Parent = FMainMenu.Items then begin
    AWidth := ACanvas.TextWidth(StringReplace(TMenuItem(Sender).Caption, '&', '', [rfReplaceAll])) + 24;
    AHeight := 26;
  end else begin AWidth := 300; AHeight := 30; end;
end;

procedure TCADMainForm.DrawDropMenu(Sender: TObject; ACanvas: TCanvas;
  ARect: TRect; AState: TOwnerDrawState);
var MenuText, Keys: string; N: Integer;
begin
  if odSelected in AState then ACanvas.Brush.Color := RGBToColor(37, 99, 235)
  else ACanvas.Brush.Color := RGBToColor(30, 64, 145);
  if (TMenuItem(Sender).Parent = FMainMenu.Items) and not (odSelected in AState) then
    ACanvas.Brush.Color := RGBToColor(30, 64, 145);
  ACanvas.FillRect(ARect);
  ACanvas.Font.Name := Font.Name; ACanvas.Font.Size := 9;
  ACanvas.Font.Color := RGBToColor(235, 240, 245);
  MenuText := StringReplace(TMenuItem(Sender).Caption, '&', '', [rfReplaceAll]); N := Pos(#9, MenuText); Keys := Copy(MenuText, N + 1, MaxInt);
  if N > 0 then MenuText := Copy(MenuText, 1, N - 1) else Keys := '';
  ACanvas.TextOut(ARect.Left + 12, ARect.Top + 7, MenuText);
  ACanvas.Font.Color := RGBToColor(175, 200, 225);
  ACanvas.TextOut(ARect.Right - ACanvas.TextWidth(Keys) - 12, ARect.Top + 7, Keys);
end;


procedure TCADMainForm.BuildTaskUI;
var B: TButton;
begin
  FWorkflow := TWorkflow.Create(WFArg('--workspace'));
  FWorkflowToken := WFArg('--session'); FTaskID := WFArg('--task');
  FWorkArea := TPanel.Create(Self); FWorkArea.Parent := Self;
  FWorkArea.Align := alClient; FWorkArea.BevelOuter := bvNone;
  FLayerPanel.Parent := FWorkArea; FCanvas.Parent := FWorkArea;
  FSideBar := TPanel.Create(Self); FSideBar.Parent := Self;
  FSideBar.Align := alLeft; FSideBar.Width := 76;
  FSideBar.BevelOuter := bvNone; FSideBar.Color := RGBToColor(15,23,42);
  B := TButton.Create(Self); B.Parent := FSideBar; B.SetBounds(6,16,64,46);
  B.Caption := '2D'; B.OnClick := @DrawingViewClick;
  B := TButton.Create(Self); B.Parent := FSideBar; B.SetBounds(6,72,64,46);
  B.Caption := 'Tarefa'; B.OnClick := @TaskViewClick;
  B := TButton.Create(Self); B.Parent := FSideBar; B.SetBounds(6,128,64,46);
  B.Caption := 'Gestão'; B.OnClick := @ReplyTaskClick;
  if (FTaskID <> '') and (FWorkflowToken <> '') then begin
    TaskViewClick(nil);
    if FWorkflowView <> nil then begin
      FWorkflowView.SelectTask(FTaskID);
      DrawingViewClick(FWorkflowView);
    end;
  end;
end;

function TCADMainForm.EnsureWorkflow: Boolean;
var U: TJSONObject;
begin
  Result := False;
  try
    if FWorkflowToken = '' then begin
      if not WFLoginDialog(FWorkflow,FWorkflowToken) then Exit;
    end;
    U := FWorkflow.User(FWorkflowToken); U.Free; Result := True;
  except on E: Exception do begin FWorkflowToken := ''; ShowMessage(E.Message); end; end;
end;

function TCADMainForm.WorkflowEditAllowed: Boolean;
var U,T: TJSONObject;
begin
  Result := True;
  if (FWorkflow = nil) or ((FTaskID = '') and (FWorkflowToken = '')) then Exit;
  Result := False;
  try
    U := FWorkflow.User(FWorkflowToken);
    try
      if U.Get('role','') = 'viewer' then raise EWorkflow.Create('Visualizador: desenho em modo de leitura');
      if FTaskID <> '' then begin T := FWorkflow.Task(FWorkflowToken,FTaskID); T.Free; end;
      Result := True;
    finally U.Free; end;
  except on E: Exception do RefreshStatus(E.Message); end;
end;

procedure TCADMainForm.TaskViewClick(Sender: TObject);
begin
  if not EnsureWorkflow then Exit;
  try
    if FWorkflowView = nil then begin
      FWorkflowView := TWorkflowPanel.Create(Self); FWorkflowView.Parent := FWorkArea;
      FWorkflowView.Align := alClient;
      FWorkflowView.OnOpenCAD := @DrawingViewClick;
      FWorkflowView.OnIdentityChanged := @WorkflowIdentityChanged;
    end;
    FWorkflowView.Setup(FWorkflow,FWorkflowToken);
    if FTaskID <> '' then FWorkflowView.SelectTask(FTaskID);
    FLayerPanel.Visible := False; FCanvas.Visible := False; FWorkflowView.Visible := True;
    FWorkflowView.BringToFront;
  except on E: Exception do ShowMessage(E.Message); end;
end;

procedure TCADMainForm.DrawingViewClick(Sender: TObject);
var T: TJSONObject; FileName: string;
begin
  try
    if Sender = FWorkflowView then begin
      T := FWorkflow.Task(FWorkflowToken,FWorkflowView.SelectedID);
      try
        FileName := T.Get('artifact','');
        if (FileName <> '') and not FileExists(FileName) then raise EWorkflow.Create('Arquivo associado não encontrado');
        if FileName <> '' then begin
          FOpenPath := FileName;
          try OpenDrawing(nil); finally FOpenPath := ''; end;
          if not SameFileName(ExpandFileName(FPath),ExpandFileName(FileName)) then Exit;
        end;
        FTaskID := T.Get('id','');
        RefreshStatus('Tarefa: '+T.Get('title','')+' | '+T.Get('assignee_name',''));
      finally T.Free; end;
    end;
    if FWorkflowView <> nil then FWorkflowView.Visible := False;
    FLayerPanel.Visible := True; FCanvas.Visible := True;
  except on E: Exception do ShowMessage(E.Message); end;
end;

procedure TCADMainForm.ReplyTaskClick(Sender: TObject);
begin TaskViewClick(nil); end;

procedure TCADMainForm.ReturnTaskClick(Sender: TObject);
var ID,ReplyMessage,State: string; Progress: Integer;
begin
  if not EnsureWorkflow then Exit;
  if FWorkflowView = nil then begin TaskViewClick(nil); Exit; end;
  ID := FWorkflowView.SelectedID;
  if (ID = '') or (ID <> FTaskID) then begin
    ShowMessage('Abra a tarefa em 2D antes de devolver o desenho.'); Exit;
  end;
  ReplyMessage := FWorkflowView.ReplyText; State := FWorkflowView.ReplyState;
  Progress := FWorkflowView.ReplyProgress;
  if Trim(ReplyMessage) = '' then begin TaskViewClick(nil); ShowMessage('Informe o que foi feito e o que falta antes de devolver.'); Exit; end;
  if not WorkflowEditAllowed then Exit;
  FSaveSucceeded := False; SaveDrawing(nil);
  if not FSaveSucceeded then Exit;
  try
    FWorkflow.Reply(FWorkflowToken,ID,ReplyMessage,State,Progress,FPath,True);
    FWorkflowView.Refresh; FWorkflowView.SelectTask(ID);
    ShowMessage('Tarefa devolvida ao Planejador com o arquivo associado.');
    PlannerClick(nil);
  except on E: Exception do ShowMessage(E.Message); end;
end;

procedure TCADMainForm.PlannerClick(Sender: TObject);
var T: TJSONObject; SourceFile: string;
begin
  if not EnsureWorkflow then Exit;
  try
    SourceFile := '';
    if FTaskID <> '' then begin
      T := FWorkflow.Task(FWorkflowToken,FTaskID);
      try SourceFile := T.Get('source',''); finally T.Free; end;
    end;
    if (SourceFile <> '') and FileExists(SourceFile) then
      WFLaunch(ExtractFilePath(ParamStr(0))+'planejador.exe',
        [SourceFile,'--workspace',FWorkflow.Path,'--session',FWorkflowToken,'--task',FTaskID])
    else WFLaunch(ExtractFilePath(ParamStr(0))+'planejador.exe',
      ['--workspace',FWorkflow.Path,'--session',FWorkflowToken,'--task',FTaskID]);
  except on E: Exception do ShowMessage(E.Message); end;
end;

procedure TCADMainForm.WorkflowIdentityChanged(Sender: TObject);
begin
  FWorkflowToken := FWorkflowView.Token;
  FTaskID := ''; SetLength(FLines,0); SetLength(FLabels,0); FPath := ''; FHistory.Clear; FDirty := False;
  FSelected := -1; FHasStart := False; UpdateDocumentTitle; FCanvas.Invalidate;
end;


function TCADMainForm.ConfirmDrawingSwitch: Boolean;
var Choice: Integer;
begin
  Result := True;
  if not FDirty then Exit;
  Choice := MessageDlg('Desenho alterado','Salvar as alterações antes de continuar?',mtConfirmation,[mbYes,mbNo,mbCancel],0);
  if Choice = mrCancel then Exit(False);
  if Choice = mrYes then begin
    FSaveSucceeded := False; SaveDrawing(nil); Result := FSaveSucceeded;
  end;
end;

procedure TCADMainForm.DrawingCloseQuery(Sender: TObject; var CanClose: Boolean);
begin CanClose := ConfirmDrawingSwitch; end;


procedure TCADMainForm.ImportDXF(Sender: TObject);
var Dialog: TOpenDialog; D: TCADDocument; Report: string; I: Integer;
begin
  if not WorkflowEditAllowed then Exit;
  Dialog := TOpenDialog.Create(Self); D := TCADDocument.Create;
  try
    Dialog.Filter := 'DXF ASCII (*.dxf)|*.dxf';
    if not Dialog.Execute then Exit;
    try
      CADImportDXF(Dialog.FileName,D,Report);
      if MessageDlg('Importar linhas DXF',Report+LineEnding+LineEnding+
        'Importar em um novo desenho? A geometria atual será substituída.',mtConfirmation,[mbYes,mbNo],0) <> mrYes then Exit;
      if not ConfirmDrawingSwitch then Exit;
      RecordChange;
      FLines := D.Lines; FLabels := D.Labels; FGrid := D.GridMM; FMillimetersPerPixel := 1;
      FLayerVisible := D.Visible; FLayerLocked := D.Locked;
      FNextGroup := 1;
      for I := 0 to High(FLines) do FNextGroup := Max(FNextGroup,FLines[I].GroupID+1);
      FSelected := -1; FHasStart := False; FPath := ''; FDirty := True;
      SyncLayerPanel; UpdateDocumentTitle; ZoomExtents(nil);
      LogCommand(Report); RefreshStatus('Linhas DXF importadas. Salve como projeto .eacad.');
    except on E: Exception do MessageDlg('Falha na importação',E.Message,mtError,[mbOK],0); end;
  finally D.Free; Dialog.Free; end;
end;

function TCADMainForm.Catalog: TCADCatalog;
begin
  if FCatalog=nil then FCatalog:=TCADCatalog.Create(CADCatalogFile);
  Result:=FCatalog;
end;

procedure TCADMainForm.ChooseCatalog(Sender: TObject);
var ID: string; W,D,Shortcut: Integer; O: TJSONObject;
begin
  if not WorkflowEditAllowed then Exit;
  try
    Shortcut:=0; if Sender is TControl then Shortcut:=TControl(Sender).Tag;
    case Shortcut of
      1: ID:='consult_maca'; 2: ID:='internacao_cama'; 3: ID:='geral_mesa';
    else ID:=''; end;
    if ID='' then begin if not CADChooseItem(Catalog,ID,W,D) then Exit; end
    else begin O:=Catalog.Item(ID); W:=O.Get('width_mm',1000); D:=O.Get('depth_mm',1000); end;
    FPendingCatalogID:=ID; FPendingCatalogWidth:=W; FPendingCatalogDepth:=D;
    FToolSelect.ItemIndex:=12; FLayerSelect.ItemIndex:=2; FHasStart:=False;
    DrawingViewClick(nil);
    RefreshStatus('Clique para posicionar: '+Catalog.Item(ID).Get('name','')+' | '+IntToStr(W)+' × '+IntToStr(D)+' mm');
  except on E: Exception do ShowMessage(E.Message); end;
end;

procedure TCADMainForm.InsertCatalog(const ID: string; const Origin: TPoint; WidthMM,DepthMM: Integer);
var Lines: TCADLines; I,N: Integer;
begin
  if not WorkflowEditAllowed then Exit;
  if FLayerLocked[2] or not FLayerVisible[2] then raise Exception.Create('A camada de mobiliário precisa estar visível e desbloqueada.');
  Lines:=Catalog.BuildLines(ID,Origin,WidthMM,DepthMM,FNextGroup);
  if Length(FLines)+Length(Lines)>200000 then raise Exception.Create('Limite de entidades excedido');
  RecordChange; N:=Length(FLines); SetLength(FLines,N+Length(Lines));
  for I:=0 to High(Lines) do FLines[N+I]:=Lines[I];
  FSelected:=N; Inc(FNextGroup); FCanvas.Invalidate;
  RefreshStatus('Bloco inserido: '+Catalog.Item(ID).Get('name',''));
end;

function TCADMainForm.SelectionMembers: TCADIndices;
var I,N: Integer;
begin
  Result:=nil; if (FSelected<0) or (FSelected>=Length(FLines)) then Exit;
  if FLines[FSelected].CatalogID='' then begin SetLength(Result,1); Result[0]:=FSelected; Exit; end;
  for I:=0 to High(FLines) do if (FLines[I].GroupID=FLines[FSelected].GroupID) and (FLines[I].CatalogID=FLines[FSelected].CatalogID) then begin
    N:=Length(Result); SetLength(Result,N+1); Result[N]:=I;
  end;
end;

function TCADMainForm.CanModifySelection: Boolean;
var Members: TCADIndices; I: Integer;
begin
  Result:=False; if not WorkflowEditAllowed then Exit;
  Members:=SelectionMembers;
  if Length(Members)=0 then begin RefreshStatus('Selecione um objeto ou bloco.'); Exit; end;
  for I:=0 to High(Members) do if FLayerLocked[FLines[Members[I]].Layer] then begin RefreshStatus('A seleção contém uma camada bloqueada.'); Exit; end;
  Result:=True;
end;

function TCADMainForm.EntitySelected(I: Integer): Boolean;
begin
  Result:=I=FSelected;
  if (FSelected<0) or (FSelected>=Length(FLines)) then Exit;
  if FLines[FSelected].CatalogID<>'' then Result:=(FLines[I].GroupID=FLines[FSelected].GroupID) and (FLines[I].CatalogID=FLines[FSelected].CatalogID);
end;

function CatalogBounds(const Lines: TCADLines; const Members: TCADIndices): TRect;
var I,J: Integer;
begin
  Result:=Rect(MaxInt,MaxInt,-MaxInt,-MaxInt);
  for I:=0 to High(Members) do begin
    J:=Members[I]; Result.Left:=Min(Result.Left,Min(Lines[J].A.X,Lines[J].B.X));
    Result.Top:=Min(Result.Top,Min(Lines[J].A.Y,Lines[J].B.Y));
    Result.Right:=Max(Result.Right,Max(Lines[J].A.X,Lines[J].B.X));
    Result.Bottom:=Max(Result.Bottom,Max(Lines[J].A.Y,Lines[J].B.Y));
  end;
end;

procedure CheckCatalogCoordinates(const Lines: TCADLines; const Members: TCADIndices);
var I,J: Integer;
begin
  for I:=0 to High(Members) do begin J:=Members[I];
    if (Abs(Int64(Lines[J].A.X))>10000000) or (Abs(Int64(Lines[J].A.Y))>10000000) or
      (Abs(Int64(Lines[J].B.X))>10000000) or (Abs(Int64(Lines[J].B.Y))>10000000) then raise Exception.Create('Transformação fora dos limites do desenho');
  end;
end;

procedure TCADMainForm.MoveSelectionMM(DX,DY: Integer; CopyIt: Boolean);
var Members: TCADIndices; Staged: TCADLines; I,J,N: Integer;
begin
  if not CanModifySelection then Exit;
  if (Abs(Int64(DX))>10000000) or (Abs(Int64(DY))>10000000) then raise Exception.Create('Deslocamento fora dos limites');
  Members:=SelectionMembers; Staged:=Copy(FLines);
  for I:=0 to High(Members) do begin J:=Members[I];
    Inc(Staged[J].A.X,DX); Inc(Staged[J].B.X,DX); Dec(Staged[J].A.Y,DY); Dec(Staged[J].B.Y,DY);
  end;
  CheckCatalogCoordinates(Staged,Members);
  if CopyIt and (Length(FLines)+Length(Members)>200000) then raise Exception.Create('Limite de entidades excedido');
  RecordChange;
  if CopyIt then begin
    N:=Length(FLines); SetLength(FLines,N+Length(Members));
    for I:=0 to High(Members) do begin FLines[N+I]:=Staged[Members[I]]; FLines[N+I].GroupID:=FNextGroup; end;
    Inc(FNextGroup); FSelected:=N;
  end else FLines:=Staged;
  FCanvas.Invalidate;
end;

procedure TCADMainForm.RotateSelectionDegrees(Degrees: Double);
var Members: TCADIndices; Staged: TCADLines; I,J: Integer; R: TRect; CX,CY,A: Double;
  function Rotated(P: TPoint): TPoint;
  var X,Y: Double;
  begin X:=P.X-CX; Y:=P.Y-CY; Result:=Point(Round(CX+X*Cos(A)-Y*Sin(A)),Round(CY+X*Sin(A)+Y*Cos(A))); end;
begin
  if not CanModifySelection then Exit;
  if IsNan(Degrees) or IsInfinite(Degrees) or (Abs(Degrees)>36000) then raise Exception.Create('Ângulo inválido');
  Members:=SelectionMembers; Staged:=Copy(FLines); R:=CatalogBounds(FLines,Members);
  CX:=(R.Left+R.Right)/2; CY:=(R.Top+R.Bottom)/2; A:=DegToRad(Degrees);
  for I:=0 to High(Members) do begin J:=Members[I]; Staged[J].A:=Rotated(FLines[J].A); Staged[J].B:=Rotated(FLines[J].B); end;
  CheckCatalogCoordinates(Staged,Members); RecordChange; FLines:=Staged; FCanvas.Invalidate;
end;

procedure TCADMainForm.MirrorSelection(Horizontal: Boolean);
var Members: TCADIndices; Staged: TCADLines; I,J: Integer; R: TRect;
begin
  if not CanModifySelection then Exit;
  Members:=SelectionMembers; Staged:=Copy(FLines); R:=CatalogBounds(FLines,Members);
  for I:=0 to High(Members) do begin J:=Members[I];
    if Horizontal then begin Staged[J].A.Y:=R.Top+R.Bottom-Staged[J].A.Y; Staged[J].B.Y:=R.Top+R.Bottom-Staged[J].B.Y; end
    else begin Staged[J].A.X:=R.Left+R.Right-Staged[J].A.X; Staged[J].B.X:=R.Left+R.Right-Staged[J].B.X; end;
  end;
  CheckCatalogCoordinates(Staged,Members); RecordChange; FLines:=Staged; FCanvas.Invalidate;
end;

procedure TCADMainForm.ResizeCatalogSelection(WidthMM,DepthMM: Integer);
var Members: TCADIndices; Staged: TCADLines; R: TRect; I,J: Integer; SX,SY: Double;
  function Resized(P: TPoint): TPoint;
  begin Result:=Point(R.Left+Round((P.X-R.Left)*SX),R.Top+Round((P.Y-R.Top)*SY)); end;
begin
  if not CanModifySelection then Exit;
  if FLines[FSelected].CatalogID='' then Exit;
  if (WidthMM<10) or (DepthMM<10) or (WidthMM>1000000) or (DepthMM>1000000) then raise Exception.Create('Dimensões inválidas');
  Members:=SelectionMembers; R:=CatalogBounds(FLines,Members);
  if (R.Right=R.Left) or (R.Bottom=R.Top) then raise Exception.Create('Bloco sem envelope válido');
  SX:=WidthMM/(R.Right-R.Left); SY:=DepthMM/(R.Bottom-R.Top); Staged:=Copy(FLines);
  for I:=0 to High(Members) do begin J:=Members[I]; Staged[J].A:=Resized(FLines[J].A); Staged[J].B:=Resized(FLines[J].B); end;
  CheckCatalogCoordinates(Staged,Members); RecordChange; FLines:=Staged; FCanvas.Invalidate;
end;

procedure TCADMainForm.ChooseCatalogResize;
var R: TRect; WidthText,DepthText: string; W,D: Integer;
begin
  if not CanModifySelection then Exit;
  R:=CatalogBounds(FLines,SelectionMembers); WidthText:=IntToStr(R.Right-R.Left); DepthText:=IntToStr(R.Bottom-R.Top);
  if not InputQuery('Envelope do bloco 2D','Largura (mm):',WidthText) then Exit;
  if not InputQuery('Envelope do bloco 2D','Profundidade (mm):',DepthText) then Exit;
  if not TryStrToInt(WidthText,W) or not TryStrToInt(DepthText,D) then begin ShowMessage('Informe dimensões inteiras em milímetros.'); Exit; end;
  try ResizeCatalogSelection(W,D); except on E: Exception do ShowMessage(E.Message); end;
end;

procedure TCADMainForm.ExplodeSelection(Sender: TObject);
var Members: TCADIndices; I: Integer;
begin
  if not CanModifySelection then Exit;
  Members:=SelectionMembers; if FLines[FSelected].CatalogID='' then Exit;
  RecordChange; for I:=0 to High(Members) do FLines[Members[I]].CatalogID:='';
  FCanvas.Invalidate; RefreshStatus('Bloco convertido em segmentos independentes.');
end;

procedure TCADMainForm.LoadHealthcareExample(Hospital: Boolean);
var D: TCADDocument; I: Integer;
begin
  if not WorkflowEditAllowed then Exit;
  D:=CADHealthcareExample(Catalog,Hospital);
  try
    if not ConfirmDrawingSwitch then Exit;
    RecordChange; FLines:=D.Lines; FLabels:=D.Labels; FGrid:=D.GridMM;
    FLayerVisible:=D.Visible; FLayerLocked:=D.Locked; FMillimetersPerPixel:=1;
    FNextGroup:=1; for I:=0 to High(FLines) do FNextGroup:=Max(FNextGroup,FLines[I].GroupID+1);
    FSelected:=-1; FHasStart:=False; FPath:=''; FDirty:=True;
    SyncLayerPanel; UpdateDocumentTitle; ZoomExtents(nil);
    RefreshStatus('Estudo esquemático de saúde — verificar o programa de necessidades do projeto.');
  finally D.Free; end;
end;

procedure TCADMainForm.LoadSampleFloorPlan(Sender: TObject);
begin
  try LoadHealthcareExample(False);
  except on E: Exception do begin LogCommand(E.Message); LoadGeneralSampleFloorPlan(nil); end; end;
end;

procedure TCADMainForm.LoadHospitalExample(Sender: TObject);
begin
  try LoadHealthcareExample(True); except on E: Exception do ShowMessage(E.Message); end;
end;

end.
