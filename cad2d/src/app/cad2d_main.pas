unit cad2d_main;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, Menus,
  Graphics, Types, Math, Dialogs, ComCtrls, ValEdit, LCLType, cad2d_importador, cad2d_controls;
type
  TCADPoints = array of TPoint;
  TCADLine = record
    A, B: TPoint;
    Layer: Integer;
    Kind: Integer; // 0 linha, 1 retangulo, 2 parede, 3 porta, 4 janela
    WidthMM: Integer;
    GroupID: Integer;
    Ink, Weight: Integer;
    Content: string;
  end;
  TCADMainForm = class(TForm)
  private
    FCanvas: TPaintBox;
    FPropertyEditor: TValueListEditor;
    FPicked: array of Integer;
    FArcCenter: TPoint;
    FArcStage: Integer;
    procedure AdvancedEdit(Sender: TObject);
    procedure ApplyProperties(Sender: TObject);
    procedure UpdatePropertyEditor;
    function IsPicked(Index: Integer): Boolean;
    procedure AddArc(const Center, StartPoint, EndPoint: TPoint);
    procedure AddAnnotation(const A,B: TPoint; const AText: string; Dimension: Boolean);
    procedure PaintAnnotation(const E: TCADLine);
    procedure AddPlanComponent(Tool: Integer; const A,B: TPoint);
  private
    FStatus, FCoordinates, FProperties, FDocument: TLabel;
    FGridCheck, FSnapCheck, FOrthoCheck: TCheckBox;
    FPropertiesPanel, FLibrary: TScrollBox;
    FPropertiesToggle: TButton;
    FLibraryGroups, FLibraryItems: array[0..1] of TPanel;
    FLibraryHeaders: array[0..1] of TButton;
    procedure ToggleProperties(Sender: TObject);
    procedure ToggleLibraryGroup(Sender: TObject);
    procedure LayoutLibrary;
    procedure ChooseTool(Sender: TObject);
    procedure ViewOptionsChanged(Sender: TObject);
    procedure FitView(Sender: TObject);
    procedure Shortcut(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FLayerSelect, FToolSelect: TComboBox;
    FLines: array of TCADLine;
    FHasStart: Boolean;
    FStart: TPoint;
    FGrid: Integer;
    FMillimetersPerPixel: Integer;
    FPath: string;
    FSelected: Integer;
    FZoom: Double;
    FPanX, FPanY: Integer;
    FShowDimensions: Boolean;
    FNextGroup: Integer;
    FUndo: array of TCADLine;
    FHistoryUndo, FHistoryRedo: TStringList;
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
    procedure AddCircle(const Center, Edge: TPoint);
    procedure PaintDrawing(Sender: TObject);
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
    procedure ImportDWGDXF(Sender: TObject);
    procedure ImportIFCDrawing(Sender: TObject);
    procedure ApplyImportedEntities(const AEntities: array of TImportedEntity; ACount: Integer);
    procedure FitDrawingToBounds;
    procedure UndoLine(Sender: TObject);
    procedure EditLastObject(Sender: TObject);
    function Snap(P: TPoint): TPoint;
    procedure RefreshStatus(const S: string);
  public
    procedure ExportProject(const FileName: string; AsSVG: Boolean);
    procedure StretchWindow(const Bounds:TRect; DX,DY:Integer);
    procedure SaveProject(const FileName: string);
    procedure LoadProject(const FileName: string);
    procedure EditSelection(Mode: Integer; X,Y: Double; Rows: Integer=1; Cols: Integer=1);
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;
var CADMainForm: TCADMainForm;
implementation
{$I cad2d_editing.inc}
{$I cad2d_export.inc}
constructor TCADMainForm.Create(AOwner: TComponent);
var Header, Footer, ModelBar: TPanel; Side: TScrollBox;
  Ribbon: TPageControl; Page: TTabSheet; Strip: TScrollBox;
  Group: TPanel; B: TCADCommandButton; L: TLabel; ApplyButton: TButton;
  GX, BI, LibraryIndex: Integer;
  procedure LabelAt(ParentControl: TWinControl; const Text: string; Y: Integer);
  begin
    L := TLabel.Create(Self); L.Parent := ParentControl;
    L.SetBounds(16,Y,220,24); L.Caption := Text;
  end;
  procedure Tab(const Text: string);
  begin
    Page := TTabSheet.Create(Self); Page.PageControl := Ribbon;
    Page.Caption := Text;
    Strip := TScrollBox.Create(Self); Strip.Parent := Page;
    Strip.Align := alClient; Strip.BorderStyle := bsNone;
    Strip.VertScrollBar.Visible := False; Strip.Color := RGBToColor(47,57,71); GX := 8;
  end;
  procedure Section(const Text: string; Columns: Integer);
  begin
    Group := TPanel.Create(Self); Group.Parent := Strip;
    Group.BevelOuter := bvNone; Group.Color := RGBToColor(47,57,71);
    Group.SetBounds(GX,4,Columns*180+16,104);
    L := TLabel.Create(Self); L.Parent := Group; L.Align := alBottom;
    L.AutoSize := False; L.Height := 20; L.Alignment := taCenter;
    L.Caption := Text; L.Font.Size := 8; L.Font.Color := RGBToColor(148,163,184);
    Inc(GX,Group.Width+8); BI := 0;
  end;
  procedure Button(const Text: string; Action: TNotifyEvent; ATag: Integer = 0);
  begin
    B := TCADCommandButton.Create(Self); B.Parent := Group;
    B.SetBounds(8+BI*90,2,86,78);
    B.Caption := Text; B.OnClick := Action; B.Tag := ATag;
    B.Hint := Text; B.ShowHint := True;
    if (Text='Linha') or (Text='Retângulo') or (Text='Círculo') or
       (Text='Parede') or (Text='Porta') or (Text='Janela') or (Text='Selecionar') or
       (Text='Polilinha') or (Text='Arco') or (Text='Texto') or (Text='Cota alinhada') then
      B.ToolIndex := ATag;
    B.Active := B.ToolIndex=0; Inc(BI);
  end;
  procedure LibraryGroup(const Text: string; Index: Integer; Expanded: Boolean);
  begin
    LibraryIndex := Index; BI := 0;
    FLibraryGroups[Index] := TPanel.Create(Self);
    with FLibraryGroups[Index] do begin
      Parent := FLibrary; BevelOuter := bvNone;
      Color := RGBToColor(47,57,71); SetBounds(0,0,110,32);
    end;
    FLibraryHeaders[Index] := TButton.Create(Self);
    with FLibraryHeaders[Index] do begin
      Parent := FLibraryGroups[Index]; SetBounds(2,0,106,30);
      Name := 'LibraryGroup'+IntToStr(Index); Tag := Index;
      Hint := Text+' — expandir / recolher'; ShowHint := True;
      OnClick := @ToggleLibraryGroup;
    end;
    FLibraryItems[Index] := TPanel.Create(Self);
    with FLibraryItems[Index] do begin
      Parent := FLibraryGroups[Index]; SetBounds(0,32,110,0);
      BevelOuter := bvNone; Color := RGBToColor(47,57,71);
      Visible := Expanded;
    end;
  end;
  procedure LibraryTool(const Text: string; Index: Integer);
  begin
    B := TCADCommandButton.Create(Self); B.Parent := FLibraryItems[LibraryIndex];
    B.SetBounds(5,4+BI*84,100,78);
    B.Caption := Text; B.Tag := Index; B.ToolIndex := Index;
    B.Active := Index=0; B.OnClick := @ChooseTool;
    B.ShowHint := True; B.Hint := Text+' — clique e marque os pontos no desenho';
    Inc(BI); FLibraryItems[LibraryIndex].Height := BI*84+8;
  end;
  procedure Check(var C: TCheckBox; const Text: string; X: Integer; Value: Boolean);
  begin
    C := TCheckBox.Create(Self); C.Parent := ModelBar;
    C.SetBounds(X,5,94,26); C.Caption := Text; C.Checked := Value;
    C.OnChange := @ViewOptionsChanged;
  end;
begin
  inherited CreateNew(AOwner, 1);
  Caption := 'CAD 2D | Engenharia e Arquitetura';
  Width := 1280; Height := 820; Position := poScreenCenter;
  Constraints.MinWidth := 960; Constraints.MinHeight := 640;
  Color := RGBToColor(244,246,250); Font.Name := 'Segoe UI'; Font.Size := 10;
  KeyPreview := True; OnKeyDown := @Shortcut;
  FGrid := 20; FSelected := -1; FZoom := 1.0;
  FPanX := 0; FPanY := 0; FShowDimensions := False; FNextGroup := 1;
  FHistoryUndo := TStringList.Create; FHistoryRedo := TStringList.Create;
  FMillimetersPerPixel := 50;

  Header := TPanel.Create(Self); Header.Parent := Self; Header.Align := alTop;
  Header.Height := 72; Header.BevelOuter := bvNone;
  Header.Color := RGBToColor(15,23,42);
  LabelAt(Header,'CAD 2D',10); L.Font.Size := 18; L.Font.Style := [fsBold];
  L.Font.Color := clWhite;
  LabelAt(Header,'Engenharia e Arquitetura  /  Plantas baixas',43);
  L.Font.Color := RGBToColor(148,163,184);

  Ribbon := TPageControl.Create(Self); Ribbon.Name := 'CommandRibbon';
  Ribbon.Parent := Self; Ribbon.Align := alTop; Ribbon.Height := 148;
  Ribbon.Top := Header.Height;
  Tab('Início');
  Section('Projeto',2);
  Button('Novo',@NewDrawing); Button('Abrir',@OpenDrawing);
  Button('Salvar',@SaveDrawing); Button('Selecionar',@ChooseTool,5);
  Section('Desenhar',2);
  Button('Linha',@ChooseTool,0); Button('Retângulo',@ChooseTool,1);
  Button('Círculo',@ChooseTool,6); Button('Parede',@ChooseTool,2);
  Section('Planta baixa',1);
  Button('Porta',@ChooseTool,3); Button('Janela',@ChooseTool,4);
  Section('Histórico',1);
  Button('Desfazer',@UndoHistory); Button('Refazer',@RedoHistory);
  Tab('Desenhar');
  Section('Formas',3);
  Button('Linha',@ChooseTool,0); Button('Polilinha',@ChooseTool,7);
  Button('Retângulo',@ChooseTool,1); Button('Círculo',@ChooseTool,6);
  Button('Arco',@ChooseTool,8);
  Section('Contornos',2); Button('Elipse',@ChooseTool,18);
  Button('Polígono',@ChooseTool,19); Button('Hachura',@ChooseTool,20);
  Tab('Modificar');
  Section('Transformar',3);
  Button('Mover',@AdvancedEdit,0); Button('Copiar',@AdvancedEdit,1);
  Button('Girar',@AdvancedEdit,2); Button('Offset',@OffsetSelected);
  Button('Espelhar X',@AdvancedEdit,5); Button('Espelhar Y',@AdvancedEdit,6);
  Section('Escala e repetição',2);
  Button('Escala',@AdvancedEdit,3); Button('Stretch',@ChooseTool,17);
  Button('Array',@AdvancedEdit,9);
  Section('Ajustar',2);
  Button('Aparar',@TrimSelected); Button('Estender',@ExtendSelected);
  Button('Chanfro',@ChamferSelected); Button('Arredondar',@FilletSelected);
  Section('Objeto',1);
  Button('Excluir',@DeleteSelected); Button('Editar dimensão',@EditLastObject);
  Section('Grupos',1);
  Button('Agrupar',@AdvancedEdit,7); Button('Desagrupar',@AdvancedEdit,8);
  Tab('Anotar');
  Section('Anotações',1);
  Button('Texto',@ChooseTool,9); Button('Cota alinhada',@ChooseTool,10);
  Section('Medidas',1);
  Button('Exibir / ocultar cotas',@ToggleDimensions); Button('Medir seleção',@MeasureSelected);
  Tab('Visualizar');
  Section('Enquadramento',2);
  Button('Zoom +',@ZoomDrawing,1); Button('Zoom -',@ZoomDrawing,-1);
  Button('Enquadrar tudo',@FitView);
  Section('Deslocar vista',2);
  Button('Esquerda',@PanDrawing,1); Button('Direita',@PanDrawing,2);
  Button('Cima',@PanDrawing,3); Button('Baixo',@PanDrawing,4);
  Tab('Importar / Exportar');
  Section('Importar',1);
  Button('DWG / DXF',@ImportDWGDXF); Button('IFC',@ImportIFCDrawing);
  Section('Exportar',1);
  Button('DXF',@ExportDXF); Button('SVG',@ExportSVG);
  Ribbon.ActivePageIndex := 0;

  Footer := TPanel.Create(Self); Footer.Parent := Self; Footer.Align := alBottom;
  Footer.Height := 32; Footer.BevelOuter := bvNone; Footer.Color := clWhite;
  FStatus := TLabel.Create(Self); FStatus.Parent := Footer; FStatus.Align := alClient;
  FStatus.AutoSize := False; FStatus.Layout := tlCenter;
  FStatus.BorderSpacing.Left := 12;
  Side := TScrollBox.Create(Self); Side.Parent := Self; Side.Align := alRight;
  FPropertiesPanel := Side; Side.Name := 'PropertiesPanel'; Side.Visible := False;
  Side.Width := 248; Side.BorderStyle := bsNone; Side.Color := clWhite;
  LabelAt(Side,'FERRAMENTA ATIVA',16); L.Font.Style := [fsBold];
  FToolSelect := TComboBox.Create(Self); FToolSelect.Parent := Side;
  FToolSelect.Name := 'ActiveTool'; FToolSelect.SetBounds(16,44,216,30);
  FToolSelect.Style := csDropDownList;
  FToolSelect.Items.Add('Linha'); FToolSelect.Items.Add('Retângulo');
  FToolSelect.Items.Add('Parede'); FToolSelect.Items.Add('Porta');
  FToolSelect.Items.Add('Janela'); FToolSelect.Items.Add('Selecionar');
  FToolSelect.Items.Add('Círculo');
  FToolSelect.Items.Add('Polilinha'); FToolSelect.Items.Add('Arco');
  FToolSelect.Items.Add('Texto'); FToolSelect.Items.Add('Cota alinhada');
  FToolSelect.Items.Add('Medir'); FToolSelect.Items.Add('Escada');
  FToolSelect.Items.Add('Pilar'); FToolSelect.Items.Add('Cama');
  FToolSelect.Items.Add('Sofá'); FToolSelect.Items.Add('Mesa');
  FToolSelect.Items.Add('Stretch');
  FToolSelect.Items.Add('Elipse'); FToolSelect.Items.Add('Polígono'); FToolSelect.Items.Add('Hachura');
  FToolSelect.Items.Add('Vão'); FToolSelect.Items.Add('Vaso sanitário'); FToolSelect.Items.Add('Lavatório');
  FToolSelect.ItemIndex := 0;
  FToolSelect.OnChange := @SelectionChanged;
  LabelAt(Side,'CAMADA ATIVA',96); L.Font.Style := [fsBold];
  FLayerSelect := TComboBox.Create(Self); FLayerSelect.Parent := Side;
  FLayerSelect.Name := 'ActiveLayer'; FLayerSelect.SetBounds(16,124,216,30);
  FLayerSelect.Style := csDropDownList;
  FLayerSelect.Items.Add('Arquitetura'); FLayerSelect.Items.Add('Estrutura');
  FLayerSelect.Items.Add('Instalações'); FLayerSelect.ItemIndex := 0;
  FLayerSelect.OnChange := @SelectionChanged;
  LabelAt(Side,'PROPRIEDADES DA SELEÇÃO',182); L.Font.Style := [fsBold];
  FProperties := TLabel.Create(Self); FProperties.Parent := Side;
  FProperties.Name := 'SelectionProperties'; FProperties.AutoSize := False;
  FProperties.SetBounds(16,214,216,188); FProperties.WordWrap := True; FProperties.Visible:=False;
  FPropertyEditor:=TValueListEditor.Create(Self); FPropertyEditor.Parent:=Side;
  FPropertyEditor.Name:='PropertyEditor'; FPropertyEditor.SetBounds(8,206,214,244);
  FPropertyEditor.ColWidths[0]:=132; FPropertyEditor.ColWidths[1]:=75;
  FPropertyEditor.TitleCaptions.Clear; FPropertyEditor.TitleCaptions.Add('Propriedade'); FPropertyEditor.TitleCaptions.Add('Valor');
  ApplyButton:=TButton.Create(Self); ApplyButton.Parent:=Side;
  ApplyButton.Name:='ApplyProperties'; ApplyButton.SetBounds(16,458,208,30);
  ApplyButton.Caption:='Aplicar propriedades'; ApplyButton.OnClick:=@ApplyProperties;
  LabelAt(Side,'Ctrl+clique: seleção múltipla',732); L.Font.Size := 9;
  LabelAt(Side,'Dimensão: altura texto / afastamento cota',756); L.Font.Size := 9;

  ModelBar := TPanel.Create(Self); ModelBar.Parent := Self; ModelBar.Align := alBottom;
  ModelBar.Height := 36; ModelBar.BevelOuter := bvNone;
  Check(FGridCheck,'Grade',12,True); Check(FSnapCheck,'Snap',108,True);
  Check(FOrthoCheck,'Orto',204,False);
  FCoordinates := TLabel.Create(Self); FCoordinates.Parent := ModelBar;
  FCoordinates.SetBounds(310,10,390,24); FCoordinates.Caption := 'X: 0 mm   Y: 0 mm';
  FPropertiesToggle := TButton.Create(Self); FPropertiesToggle.Parent := ModelBar;
  FPropertiesToggle.Name := 'ToggleProperties'; FPropertiesToggle.Align := alRight;
  FPropertiesToggle.Width := 160; FPropertiesToggle.Caption := 'Propriedades / camadas';
  FPropertiesToggle.Hint := 'Exibir ou ocultar o painel (Ctrl+I)';
  FPropertiesToggle.ShowHint := True; FPropertiesToggle.OnClick := @ToggleProperties;
  FLibrary := TScrollBox.Create(Self); FLibrary.Name := 'PartsLibrary';
  FLibrary.Parent := Self; FLibrary.Align := alLeft; FLibrary.Width := 132;
  FLibrary.BorderStyle := bsNone; FLibrary.Color := RGBToColor(47,57,71);
  FLibrary.HorzScrollBar.Visible := False; FLibrary.VertScrollBar.Tracking := True;
  LibraryGroup('Formas',0,True);
  LibraryTool('Selecionar',5); LibraryTool('Linha',0);
  LibraryTool('Retângulo',1); LibraryTool('Círculo',6);
  LibraryTool('Polilinha',7); LibraryTool('Arco',8); LibraryTool('Texto',9);
  LibraryTool('Cota alinhada',10); LibraryTool('Medir',11);
  LibraryTool('Elipse',18); LibraryTool('Polígono',19); LibraryTool('Hachura',20);
  LibraryGroup('Peças',1,False);
  LibraryTool('Parede',2); LibraryTool('Porta',3); LibraryTool('Janela',4);
  LibraryTool('Escada',12); LibraryTool('Pilar',13); LibraryTool('Cama',14);
  LibraryTool('Sofá',15); LibraryTool('Mesa',16);
  LibraryTool('Vão',21); LibraryTool('Vaso sanitário',22); LibraryTool('Lavatório',23);
  LayoutLibrary;
  FDocument := TLabel.Create(Self); FDocument.Parent := Self; FDocument.Align := alTop;
  FDocument.Top := Header.Height+Ribbon.Height; FDocument.AutoSize := False;
  FDocument.Height := 30; FDocument.Layout := tlCenter; FDocument.BorderSpacing.Left := 12;
  FCanvas := TPaintBox.Create(Self); FCanvas.Parent := Self;
  FCanvas.Name := 'DrawingCanvas'; FCanvas.Align := alClient; FCanvas.Cursor := crCross;
  FCanvas.OnPaint := @PaintDrawing; FCanvas.OnMouseDown := @CanvasClick;
  FCanvas.OnMouseMove := @MouseMoveDrawing;
  RefreshStatus('Clique em dois pontos para desenhar.');
end;

procedure TCADMainForm.ToggleProperties(Sender: TObject);
begin
  FPropertiesPanel.Visible := not FPropertiesPanel.Visible;
  if FPropertiesPanel.Visible then FPropertiesToggle.Caption := 'Ocultar propriedades'
  else FPropertiesToggle.Caption := 'Propriedades / camadas';
end;

procedure TCADMainForm.LayoutLibrary;
const Titles: array[0..1] of string = ('Formas','Peças');
var I, Y: Integer;
begin
  FLibrary.VertScrollBar.Position := 0; Y := 4;
  for I := 0 to 1 do begin
    if FLibraryItems[I].Visible then begin
      FLibraryGroups[I].Height := 32+FLibraryItems[I].Height;
      FLibraryHeaders[I].Caption := '−  '+Titles[I];
    end else begin
      FLibraryGroups[I].Height := 32;
      FLibraryHeaders[I].Caption := '+  '+Titles[I];
    end;
    FLibraryGroups[I].Top := Y;
    Inc(Y,FLibraryGroups[I].Height+4);
  end;
end;

procedure TCADMainForm.ToggleLibraryGroup(Sender: TObject);
var Index: Integer;
begin
  Index := TControl(Sender).Tag;
  FLibraryItems[Index].Visible := not FLibraryItems[Index].Visible;
  LayoutLibrary;
end;

procedure TCADMainForm.ChooseTool(Sender: TObject);
begin
  FToolSelect.ItemIndex := TControl(Sender).Tag;
  SelectionChanged(FToolSelect);
end;

procedure TCADMainForm.ViewOptionsChanged(Sender: TObject);
begin
  if Assigned(FCanvas) then begin
    FCanvas.Invalidate; RefreshStatus('Precisão atualizada');
  end;
end;

procedure TCADMainForm.FitView(Sender: TObject);
begin
  FitDrawingToBounds; FCanvas.Invalidate; RefreshStatus('Desenho enquadrado');
end;

procedure TCADMainForm.Shortcut(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then begin
    if FHasStart then Inc(FNextGroup); FHasStart := False; FArcStage:=0; FCanvas.Invalidate; RefreshStatus('Comando cancelado'); Key := 0;
  end;
  if Shift <> [ssCtrl] then Exit;
  case Key of
    VK_I: ToggleProperties(Self);
    VK_Z: UndoHistory(Self);
    VK_Y: RedoHistory(Self);
    VK_S: SaveDrawing(Self);
    VK_O: OpenDrawing(Self);
  else Exit;
  end;
  Key := 0;
end;

destructor TCADMainForm.Destroy;
begin
  FHistoryRedo.Free;
  FHistoryUndo.Free;
  inherited Destroy;
end;
function TCADMainForm.Snap(P: TPoint): TPoint;
begin
  if not FSnapCheck.Checked then begin
    Result := Point(Round((P.X-FPanX)/FZoom),Round((P.Y-FPanY)/FZoom));
    Exit;
  end;
  Result.X := Round((P.X-FPanX) / (FGrid * FZoom)) * FGrid;
  Result.Y := Round((P.Y-FPanY) / (FGrid * FZoom)) * FGrid;
end;
procedure TCADMainForm.PanDrawing(Sender: TObject);
begin
  case TControl(Sender).Tag of
    1: Dec(FPanX,40);
    2: Inc(FPanX,40);
    3: Dec(FPanY,40);
    4: Inc(FPanY,40);
  end;
  FCanvas.Invalidate;
  RefreshStatus('Vista deslocada');
end;
procedure TCADMainForm.ZoomDrawing(Sender: TObject);
begin
  if TControl(Sender).Tag > 0 then FZoom := Min(4.0, FZoom * 1.25)
  else FZoom := Max(0.5, FZoom / 1.25);
  FCanvas.Invalidate;
  RefreshStatus('Zoom ajustado para ' + IntToStr(Round(FZoom*100)) + '%');
end;
function TCADMainForm.Snapshot: string;
var I: Integer;
begin
  Result:=IntToStr(FNextGroup);
  for I:=0 to High(FLines) do Result:=Result+LineEnding+EntityRow(FLines[I]);
end;
procedure TCADMainForm.RestoreSnapshot(const Value: string);
var L: TStringList; I: Integer;
begin
  L:=TStringList.Create;
  try
    L.Text:=Value; FNextGroup:=StrToInt(L[0]); SetLength(FLines,L.Count-1);
    for I:=0 to High(FLines) do FLines[I]:=ReadEntity(L[I+1],4,I);
    FSelected:=-1; SetLength(FPicked,0); FHasStart:=False; FArcStage:=0; FCanvas.Invalidate;
  finally L.Free; end;
end;
procedure TCADMainForm.RecordChange;
begin
  FHistoryUndo.Add(Snapshot);
  if FHistoryUndo.Count > 60 then FHistoryUndo.Delete(0);
  FHistoryRedo.Clear;
end;
procedure TCADMainForm.UndoHistory(Sender: TObject);
var N: Integer; V: string;
begin
  N := FHistoryUndo.Count;
  if N = 0 then Exit;
  FHistoryRedo.Add(Snapshot);
  V := FHistoryUndo[N-1]; FHistoryUndo.Delete(N-1);
  RestoreSnapshot(V); RefreshStatus('Alteração desfeita');
end;
procedure TCADMainForm.RedoHistory(Sender: TObject);
var N: Integer; V: string;
begin
  N := FHistoryRedo.Count;
  if N = 0 then Exit;
  FHistoryUndo.Add(Snapshot);
  V := FHistoryRedo[N-1]; FHistoryRedo.Delete(N-1);
  RestoreSnapshot(V); RefreshStatus('Alteração refeita');
end;
procedure TCADMainForm.SelectionChanged(Sender: TObject);
var I: Integer;
begin
  for I := 0 to ComponentCount-1 do
    if Components[I] is TCADCommandButton then
      with TCADCommandButton(Components[I]) do
        Active := (ToolIndex >= 0) and (ToolIndex=FToolSelect.ItemIndex);
  if FHasStart then Inc(FNextGroup);
  FHasStart := False; FArcStage:=0;
  FCanvas.Invalidate;
  RefreshStatus('Ferramenta: '+FToolSelect.Text+' — botão direito termina/cancela');
end;
procedure TCADMainForm.AddSegment(const A, B: TPoint);
var N: Integer;
begin
  if (A.X = B.X) and (A.Y = B.Y) then Exit;
  N := Length(FLines); SetLength(FLines, N+1);
  FLines[N]:=Default(TCADLine);
  FLines[N].A := A; FLines[N].B := B;
  FLines[N].Layer := FLayerSelect.ItemIndex;
  FLines[N].GroupID := FNextGroup;
  FLines[N].Kind := FToolSelect.ItemIndex;
  if not (FLines[N].Kind in [2,3,4]) then FLines[N].Kind := 0;
  case FLines[N].Kind of
    2: FLines[N].WidthMM := 150;
    3: FLines[N].WidthMM := 900;
    4: FLines[N].WidthMM := 1200;
  else FLines[N].WidthMM := 0;
  end;
  if FLines[N].Kind = 2 then FLines[N].Layer := 0;
end;
procedure TCADMainForm.AddCircle(const Center, Edge: TPoint);
var Radius, Angle, NextAngle: Double; I: Integer; A, B: TPoint;
begin
  Radius := Hypot(Edge.X-Center.X, Edge.Y-Center.Y);
  if Radius < 1 then Exit;
  for I := 0 to 47 do begin
    Angle := I * 2 * Pi / 48;
    NextAngle := (I+1) * 2 * Pi / 48;
    A := Point(Center.X+Round(Radius*Cos(Angle)),
               Center.Y+Round(Radius*Sin(Angle)));
    B := Point(Center.X+Round(Radius*Cos(NextAngle)),
               Center.Y+Round(Radius*Sin(NextAngle)));
    if (A.X<>B.X) or (A.Y<>B.Y) then begin
      AddSegment(A,B);
      FLines[High(FLines)].Kind := 0;
    end;
  end;
end;
procedure TCADMainForm.RefreshStatus(const S: string);
begin
  FStatus.Caption := Format('%s   |   %d segmentos   |   Zoom %d%%   |   Grade %d mm',
    [S, Length(FLines), Round(FZoom*100), FGrid * FMillimetersPerPixel]);
  if FPath = '' then FDocument.Caption := 'MODELO  /  Sem título'
  else FDocument.Caption := 'MODELO  /  ' + ExtractFileName(FPath);
  if (FSelected >= 0) and (FSelected < Length(FLines)) then
    with FLines[FSelected] do
      FProperties.Caption := Format('Segmento %d • Grupo %d'+LineEnding+
        'Camada: %s'+LineEnding+'Início: %d, %d mm'+LineEnding+
        'Fim: %d, %d mm'+LineEnding+'Comprimento: %.2f m'+LineEnding+
        'Dimensão nominal: %d mm', [FSelected+1,GroupID,
        FLayerSelect.Items[EnsureRange(Layer,0,FLayerSelect.Items.Count-1)],
        A.X*FMillimetersPerPixel,A.Y*FMillimetersPerPixel,
        B.X*FMillimetersPerPixel,B.Y*FMillimetersPerPixel,
        Hypot(B.X-A.X,B.Y-A.Y)*FMillimetersPerPixel/1000,WidthMM])
  else FProperties.Caption := 'Nenhum objeto selecionado.'+LineEnding+LineEnding+
    'Use Selecionar e clique em um segmento para consultar suas propriedades.';
  UpdatePropertyEditor;
end;
procedure TCADMainForm.PaintDrawing(Sender: TObject);
var X, Y, I, J, MX, MY: Integer; R: TRect; MM, Step: Double; Symbol:TCADPoints;
begin
  R := FCanvas.ClientRect;
  FCanvas.Canvas.Brush.Color := RGBToColor(33,40,48);
  FCanvas.Canvas.FillRect(R);
  FCanvas.Canvas.Pen.Color := RGBToColor(49,59,70);
  FCanvas.Canvas.Pen.Width := 1;
  Step := FGrid * FZoom;
  if FGridCheck.Checked then begin
    for X := Floor(-FPanX/Step) to Ceil((FCanvas.Width-FPanX)/Step) do begin
      FCanvas.Canvas.MoveTo(Round(X*Step)+FPanX,0);
      FCanvas.Canvas.LineTo(Round(X*Step)+FPanX,FCanvas.Height);
    end;
    for Y := Floor(-FPanY/Step) to Ceil((FCanvas.Height-FPanY)/Step) do begin
      FCanvas.Canvas.MoveTo(0,Round(Y*Step)+FPanY);
      FCanvas.Canvas.LineTo(FCanvas.Width,Round(Y*Step)+FPanY);
    end;
  end;
  FCanvas.Canvas.Pen.Color := RGBToColor(96,165,250);
  FCanvas.Canvas.Pen.Width := 2;
  for I := 0 to High(FLines) do begin
    case FLines[I].Layer of
      1: FCanvas.Canvas.Pen.Color := RGBToColor(251,191,36);
      2: FCanvas.Canvas.Pen.Color := RGBToColor(52,211,153);
    else FCanvas.Canvas.Pen.Color := RGBToColor(96,165,250);
    end;
    case FLines[I].Kind of
      2: begin
        FCanvas.Canvas.Pen.Width := Max(1, Round(FLines[I].WidthMM * FZoom / FMillimetersPerPixel));
        FCanvas.Canvas.Pen.Color := RGBToColor(226,232,240);
      end;
      3: begin FCanvas.Canvas.Pen.Width := 3; FCanvas.Canvas.Pen.Color := clRed; end;
      4: begin FCanvas.Canvas.Pen.Width := 3; FCanvas.Canvas.Pen.Color := clAqua; end;
    else FCanvas.Canvas.Pen.Width := 2;
    end;
    if FLines[I].Ink<>0 then FCanvas.Canvas.Pen.Color:=RGBToColor((FLines[I].Ink shr 16) and 255,(FLines[I].Ink shr 8) and 255,FLines[I].Ink and 255);
    if FLines[I].Weight>0 then FCanvas.Canvas.Pen.Width:=Max(1,Round(FLines[I].Weight*FZoom/FMillimetersPerPixel));
    if IsPicked(I) then begin
      FCanvas.Canvas.Pen.Color := clFuchsia;
      FCanvas.Canvas.Pen.Width := Max(3, FCanvas.Canvas.Pen.Width);
    end;
    if FLines[I].Kind in [5,6] then begin PaintAnnotation(FLines[I]); Continue; end;
    // Portas e janelas ganham uma faixa de abertura visual sobre a parede,
    // mas ainda não modificam a topologia da geometria arquitetônica.
    if FLines[I].Kind in [3,4] then begin
      FCanvas.Canvas.Pen.Width := Max(4,Round(180*FZoom/FMillimetersPerPixel));
      FCanvas.Canvas.Pen.Color := RGBToColor(33,40,48);
      FCanvas.Canvas.MoveTo(Round(FLines[I].A.X*FZoom)+FPanX,Round(FLines[I].A.Y*FZoom)+FPanY);
      FCanvas.Canvas.LineTo(Round(FLines[I].B.X*FZoom)+FPanX,Round(FLines[I].B.Y*FZoom)+FPanY);
      if FLines[I].Kind=3 then FCanvas.Canvas.Pen.Color := clRed
      else FCanvas.Canvas.Pen.Color := clAqua;
      FCanvas.Canvas.Pen.Width := 2;
    end;
    if FLines[I].Kind in [3,4] then begin
      if IsPicked(I) then FCanvas.Canvas.Pen.Color:=clFuchsia;
      Symbol:=PlanSymbol(FLines[I]);
      for J:=0 to Length(Symbol) div 2-1 do begin
        FCanvas.Canvas.MoveTo(Round(Symbol[J*2].X*FZoom)+FPanX,Round(Symbol[J*2].Y*FZoom)+FPanY);
        FCanvas.Canvas.LineTo(Round(Symbol[J*2+1].X*FZoom)+FPanX,Round(Symbol[J*2+1].Y*FZoom)+FPanY);
      end;
      Continue;
    end;
    FCanvas.Canvas.MoveTo(Round(FLines[I].A.X*FZoom)+FPanX, Round(FLines[I].A.Y*FZoom)+FPanY);
    FCanvas.Canvas.LineTo(Round(FLines[I].B.X*FZoom)+FPanX, Round(FLines[I].B.Y*FZoom)+FPanY);
    if FShowDimensions then begin
      MM := Hypot(FLines[I].B.X-FLines[I].A.X,
        FLines[I].B.Y-FLines[I].A.Y)*FMillimetersPerPixel;
      MX := Round((FLines[I].A.X+FLines[I].B.X)*FZoom/2)+FPanX;
      MY := Round((FLines[I].A.Y+FLines[I].B.Y)*FZoom/2)+FPanY;
      FCanvas.Canvas.Font.Color := RGBToColor(251,191,36);
      FCanvas.Canvas.Brush.Style := bsClear;
      FCanvas.Canvas.TextOut(MX+5,MY-14,FormatFloat('0.00',MM/1000)+' m');
      FCanvas.Canvas.Brush.Style := bsSolid;
    end;
  end;
  FCanvas.Canvas.Pen.Width := 1;
  if FHasStart then begin
    FCanvas.Canvas.Brush.Color := clRed;
    FCanvas.Canvas.Ellipse(Round(FStart.X*FZoom)+FPanX-4,Round(FStart.Y*FZoom)+FPanY-4,
      Round(FStart.X*FZoom)+FPanX+4,Round(FStart.Y*FZoom)+FPanY+4);
  end;
end;
procedure TCADMainForm.CanvasClick(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X,Y: Integer);
var P:TPoint; AText,SX,SY:string; Old,I,DX,DY:Integer;
begin
  if Button=mbRight then begin
    if FHasStart then Inc(FNextGroup); FHasStart:=False; FArcStage:=0;
    FCanvas.Invalidate; RefreshStatus('Comando encerrado'); Exit;
  end;
  if Button<>mbLeft then Exit;
  P:=Snap(Point(X,Y));
  if FToolSelect.ItemIndex=5 then begin
    Old:=FSelected;
    if not (ssCtrl in Shift) then SetLength(FPicked,0)
    else if (Length(FPicked)=0) and (Old>=0) then begin SetLength(FPicked,1); FPicked[0]:=Old; end;
    SelectObjectAt(Point(Round((X-FPanX)/FZoom),Round((Y-FPanY)/FZoom)));
    if (ssCtrl in Shift) and (FSelected>=0) then begin
      I:=Length(FPicked); SetLength(FPicked,I+1); FPicked[I]:=FSelected;
      FCanvas.Invalidate;
    end;
    Exit;
  end;
  if FToolSelect.ItemIndex=9 then begin
    AText:='Ambiente'; if not InputQuery('Texto','Conteúdo:',AText) or (AText='') then Exit;
    RecordChange; AddAnnotation(P,Point(P.X+Max(10,Length(AText)*4),P.Y),AText,False);
    Inc(FNextGroup); FCanvas.Invalidate; RefreshStatus('Texto inserido'); Exit;
  end;
  if FToolSelect.ItemIndex=8 then begin
    case FArcStage of
      0: begin FArcCenter:=P; FArcStage:=1; RefreshStatus('Arco: indique o início (raio)'); end;
      1: begin FStart:=P; FArcStage:=2; RefreshStatus('Arco: indique o fim, sentido horário'); end;
      2: begin RecordChange; AddArc(FArcCenter,FStart,P); Inc(FNextGroup); FArcStage:=0; RefreshStatus('Arco criado'); end;
    end;
    FCanvas.Invalidate; Exit;
  end;
  if not FHasStart then begin FStart:=P; FHasStart:=True; RefreshStatus('Indique o próximo ponto'); end
  else begin
    if ((ssShift in Shift) or FOrthoCheck.Checked) and (FToolSelect.ItemIndex in [0,2,3,4,7]) then
      if Abs(P.X-FStart.X)>=Abs(P.Y-FStart.Y) then P.Y:=FStart.Y else P.X:=FStart.X;
    if FToolSelect.ItemIndex=11 then begin
      RefreshStatus('Distância: '+FormatFloat('0.00',Hypot(P.X-FStart.X,P.Y-FStart.Y)*FMillimetersPerPixel/1000)+' m');
      FHasStart:=False; Exit;
    end;
    if (P.X=FStart.X) and (P.Y=FStart.Y) then Exit;
    if FToolSelect.ItemIndex=17 then begin
      FHasStart:=False; SX:='1000'; SY:='0';
      if not InputQuery('Stretch','Deslocamento X em mm:',SX) then Exit;
      if not InputQuery('Stretch','Deslocamento Y em mm (positivo para cima):',SY) then Exit;
      if not TryStrToInt(SX,DX) or not TryStrToInt(SY,DY) then begin ShowMessage('Valor inválido'); Exit; end;
      try StretchWindow(Rect(Min(FStart.X,P.X),Min(FStart.Y,P.Y),Max(FStart.X,P.X),Max(FStart.Y,P.Y)),DX,DY);
      except on E:Exception do ShowMessage(E.Message); end;
      Exit;
    end;
    RecordChange;
    case FToolSelect.ItemIndex of
      6: AddCircle(FStart,P);
      10: AddAnnotation(FStart,P,'',True);
      1: begin AddSegment(FStart,Point(P.X,FStart.Y)); AddSegment(Point(P.X,FStart.Y),P);
        AddSegment(P,Point(FStart.X,P.Y)); AddSegment(Point(FStart.X,P.Y),FStart); end;
      12..16,18..23: AddPlanComponent(FToolSelect.ItemIndex,FStart,P);
    else AddSegment(FStart,P);
    end;
    if FToolSelect.ItemIndex=7 then begin FStart:=P; RefreshStatus('Polilinha: próximo ponto; botão direito termina'); end
    else begin Inc(FNextGroup); FHasStart:=False; RefreshStatus('Elemento criado'); end;
    SetLength(FUndo,0);
  end;
  FCanvas.Invalidate;
end;
procedure TCADMainForm.MouseMoveDrawing(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var P: TPoint;
begin
  P := Snap(Point(X,Y));
  FCoordinates.Caption := Format('X: %d mm   Y: %d mm',
    [P.X*FMillimetersPerPixel,P.Y*FMillimetersPerPixel]);
  if not FHasStart then Exit;
  RefreshStatus(Format('Início (%d,%d) — próximo (%d,%d)',
    [FStart.X,FStart.Y,P.X,P.Y]));
end;
procedure TCADMainForm.NewDrawing(Sender: TObject);
begin
  if (Length(FLines) > 0) and
    (MessageDlg('Novo desenho','Descartar o desenho atual?',
     mtConfirmation,[mbYes,mbNo],0) <> mrYes) then Exit;
  RecordChange;
  SetLength(FLines,0); SetLength(FUndo,0);
  FNextGroup := 1; FHasStart := False; FArcStage:=0; SetLength(FPicked,0); FSelected := -1; FPath := '';
  FCanvas.Invalidate; RefreshStatus('Novo desenho');
end;
procedure TCADMainForm.UndoLine(Sender: TObject);
var G, N: Integer;
begin
  if Length(FLines) = 0 then Exit;
  G := FLines[High(FLines)].GroupID;
  repeat
    N := Length(FUndo); SetLength(FUndo,N+1);
    FUndo[N] := FLines[High(FLines)];
    SetLength(FLines,Length(FLines)-1);
  until (Length(FLines) = 0) or (FLines[High(FLines)].GroupID <> G);
  FSelected := -1;
  FCanvas.Invalidate; RefreshStatus('Operação desfeita');
end;
procedure TCADMainForm.RedoDrawing(Sender: TObject);
var G, N: Integer;
begin
  if Length(FUndo) = 0 then Exit;
  G := FUndo[High(FUndo)].GroupID;
  repeat
    N := Length(FLines); SetLength(FLines,N+1);
    FLines[N] := FUndo[High(FUndo)];
    SetLength(FUndo,Length(FUndo)-1);
  until (Length(FUndo)=0) or (FUndo[High(FUndo)].GroupID <> G);
  FCanvas.Invalidate; RefreshStatus('Operação refeita');
end;
procedure TCADMainForm.SelectObjectAt(const P: TPoint);
var I: Integer; DX, DY, T, Dist, Best: Double; Nearest: Integer;
begin
  Best := 100.0; Nearest := -1;
  for I := 0 to High(FLines) do begin
    DX := FLines[I].B.X - FLines[I].A.X;
    DY := FLines[I].B.Y - FLines[I].A.Y;
    if DX*DX + DY*DY <= 0 then Continue;
    T := ((P.X-FLines[I].A.X)*DX+(P.Y-FLines[I].A.Y)*DY)/(DX*DX+DY*DY);
    T := Max(0.0,Min(1.0,T));
    Dist := Sqrt(Sqr(P.X-FLines[I].A.X-T*DX)+Sqr(P.Y-FLines[I].A.Y-T*DY));
    if (Dist <= 12/FZoom) and (Dist < Best) then begin Best := Dist; Nearest := I; end;
  end;
  FSelected := Nearest; FCanvas.Invalidate;
  if FSelected >= 0 then RefreshStatus('Objeto selecionado')
  else RefreshStatus('Nenhum objeto próximo');
end;
procedure TCADMainForm.DeleteSelected(Sender:TObject);
var I,N:Integer; Temp:array of TCADLine;
begin
  if FSelected<0 then Exit;
  RecordChange; SetLength(Temp,Length(FLines)); N:=0;
  for I:=0 to High(FLines) do if not IsPicked(I) then begin Temp[N]:=FLines[I]; Inc(N); end;
  SetLength(Temp,N); FLines:=Temp; SetLength(FPicked,0); FSelected:=-1;
  FCanvas.Invalidate; RefreshStatus('Seleção excluída');
end;
procedure TCADMainForm.TransformSelected(Sender: TObject);
var SX, SY: string; DX, DY, Id, N: Integer; IsCopy: Boolean;
begin
  if (FSelected < 0) or (FSelected >= Length(FLines)) then begin
    ShowMessage('Primeiro selecione um objeto.'); Exit;
  end;
  IsCopy := TControl(Sender).Tag = 1;
  SX := '1000'; SY := '0';
  if not InputQuery('Deslocamento em milímetros',
    'Deslocamento horizontal (mm):', SX) then Exit;
  if not InputQuery('Deslocamento em milímetros',
    'Deslocamento vertical (mm):', SY) then Exit;
  if (not TryStrToInt(SX, DX)) or (not TryStrToInt(SY, DY)) then begin
    ShowMessage('Informe coordenadas inteiras em milímetros.'); Exit;
  end;
  if (Abs(Int64(DX)) > 10000000) or (Abs(Int64(DY)) > 10000000) then begin
    ShowMessage('Deslocamento fora do limite.'); Exit;
  end;
  RecordChange;
  Id := FSelected;
  if IsCopy then begin
    N := Length(FLines);
    SetLength(FLines, N+1);
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
var AngleText: string; Degrees, Radians, CX, CY: Double;
  A, B: TPoint;
  function RotatePoint(const P: TPoint): TPoint;
  var RX, RY: Double;
  begin
    RX := P.X-CX; RY := P.Y-CY;
    Result.X := Round(CX+RX*Cos(Radians)-RY*Sin(Radians));
    Result.Y := Round(CY+RX*Sin(Radians)+RY*Cos(Radians));
  end;
begin
  if (FSelected < 0) or (FSelected >= Length(FLines)) then begin
    ShowMessage('Selecione um objeto antes de girar.'); Exit;
  end;
  AngleText := '90';
  if not InputQuery('Girar objeto', 'Ângulo em graus (sentido horário na tela):',AngleText) then Exit;
  if not TryStrToFloat(AngleText,Degrees) then begin
    ShowMessage('Ângulo inválido.'); Exit;
  end;
  if (IsNan(Degrees)) or (IsInfinite(Degrees)) or (Abs(Degrees)>36000) then begin
    ShowMessage('Ângulo fora do limite.'); Exit;
  end;
  Radians := DegToRad(Degrees);
  A := FLines[FSelected].A; B := FLines[FSelected].B;
  CX := (A.X+B.X)/2; CY := (A.Y+B.Y)/2;
  RecordChange;
  FLines[FSelected].A := RotatePoint(A);
  FLines[FSelected].B := RotatePoint(B);
  FCanvas.Invalidate; RefreshStatus('Objeto girado');
end;
procedure TCADMainForm.MirrorSelected(Sender: TObject);
var CX, CY: Double; Id: Integer;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione um objeto antes de espelhar.'); Exit;
  end;
  CX := (FLines[Id].A.X+FLines[Id].B.X)/2;
  CY := (FLines[Id].A.Y+FLines[Id].B.Y)/2;
  RecordChange;
  if TControl(Sender).Tag=0 then begin
    FLines[Id].A.Y := Round(2*CY-FLines[Id].A.Y);
    FLines[Id].B.Y := Round(2*CY-FLines[Id].B.Y);
  end else begin
    FLines[Id].A.X := Round(2*CX-FLines[Id].A.X);
    FLines[Id].B.X := Round(2*CX-FLines[Id].B.X);
  end;
  FCanvas.Invalidate; RefreshStatus('Objeto espelhado');
end;
procedure TCADMainForm.OffsetSelected(Sender: TObject);
var N, Id: Integer; DistanceText: string; MM, DX, DY, Len, ShiftX, ShiftY: Double;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione uma linha antes de aplicar offset.'); Exit;
  end;
  DistanceText := '200';
  if not InputQuery('Offset paralelo',
     'Distância assinada em milímetros:', DistanceText) then Exit;
  if not TryStrToFloat(DistanceText,MM) then begin
    ShowMessage('Distância inválida.'); Exit;
  end;
  if IsNan(MM) or IsInfinite(MM) or (Abs(MM)>1000000) then begin
    ShowMessage('Distância fora do limite.'); Exit;
  end;
  DX := FLines[Id].B.X-FLines[Id].A.X;
  DY := FLines[Id].B.Y-FLines[Id].A.Y;
  Len := Hypot(DX,DY);
  if Len < 1 then Exit;
  ShiftX := -DY*MM/(Len*FMillimetersPerPixel);
  ShiftY := DX*MM/(Len*FMillimetersPerPixel);
  RecordChange;
  N := Length(FLines);
  SetLength(FLines,N+1);
  FLines[N] := FLines[Id];
  FLines[N].A.X := Round(FLines[N].A.X+ShiftX);
  FLines[N].A.Y := Round(FLines[N].A.Y+ShiftY);
  FLines[N].B.X := Round(FLines[N].B.X+ShiftX);
  FLines[N].B.Y := Round(FLines[N].B.Y+ShiftY);
  FLines[N].GroupID := FNextGroup;
  Inc(FNextGroup);
  FSelected := N;
  FCanvas.Invalidate;
  RefreshStatus('Offset paralelo criado');
end;
procedure TCADMainForm.ExtendSelected(Sender: TObject);
var TargetText: string; Id, Other: Integer;
  AX, AY, BX, BY, CX, CY, DX, DY, Den, T, U, PX, PY: Double;
  A, B: TPoint;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione o segmento que deseja estender.'); Exit;
  end;
  TargetText := IntToStr(Id+1);
  if not InputQuery('Estender até linha', 'Número do segmento de limite (1 a '+
    IntToStr(Length(FLines))+'):', TargetText) then Exit;
  if (not TryStrToInt(TargetText,Other)) or (Other<1) or
    (Other>Length(FLines)) or (Other=Id+1) then begin
    ShowMessage('Segmento de limite inválido.'); Exit;
  end;
  Dec(Other);
  A := FLines[Id].A; B := FLines[Id].B;
  AX := A.X; AY := A.Y; BX := B.X; BY := B.Y;
  CX := FLines[Other].A.X; CY := FLines[Other].A.Y;
  DX := FLines[Other].B.X; DY := FLines[Other].B.Y;
  Den := (BX-AX)*(DY-CY)-(BY-AY)*(DX-CX);
  if Abs(Den)<0.000001 then begin
    ShowMessage('Linhas paralelas ou coincidentes.'); Exit;
  end;
  T := ((CX-AX)*(DY-CY)-(CY-AY)*(DX-CX))/Den;
  U := ((CX-AX)*(BY-AY)-(CY-AY)*(BX-AX))/Den;
  if (U<0) or (U>1) then begin
    ShowMessage('A interseção está fora do segmento de limite.'); Exit;
  end;
  if (T>=0) and (T<=1) then begin
    ShowMessage('A interseção já está no segmento selecionado.'); Exit;
  end;
  if (Abs(T)>10000) then begin
    ShowMessage('Prolongamento excede o limite.'); Exit;
  end;
  PX := AX+T*(BX-AX); PY := AY+T*(BY-AY);
  RecordChange;
  if T<0 then FLines[Id].A := Point(Round(PX),Round(PY))
  else FLines[Id].B := Point(Round(PX),Round(PY));
  FCanvas.Invalidate;
  RefreshStatus('Segmento estendido até a interseção');
end;
procedure TCADMainForm.TrimSelected(Sender: TObject);
var TargetText, EndText: string; Id, Other: Integer;
  AX, AY, BX, BY, CX, CY, DX, DY, Den, T, U: Double;
  CutPoint: TPoint;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione o segmento que deseja aparar.'); Exit;
  end;
  TargetText := '';
  if not InputQuery('Aparar segmento',
     'Número do segmento de limite (1 a '+IntToStr(Length(FLines))+'):',TargetText) then Exit;
  if (not TryStrToInt(TargetText,Other)) or (Other < 1) or
     (Other > Length(FLines)) or (Other = Id+1) then begin
    ShowMessage('Segmento de limite inválido.'); Exit;
  end;
  Dec(Other);
  AX := FLines[Id].A.X; AY := FLines[Id].A.Y;
  BX := FLines[Id].B.X; BY := FLines[Id].B.Y;
  CX := FLines[Other].A.X; CY := FLines[Other].A.Y;
  DX := FLines[Other].B.X; DY := FLines[Other].B.Y;
  Den := (BX-AX)*(DY-CY)-(BY-AY)*(DX-CX);
  if Abs(Den) < 0.000001 then begin
    ShowMessage('Linhas paralelas ou coincidentes.'); Exit;
  end;
  T := ((CX-AX)*(DY-CY)-(CY-AY)*(DX-CX))/Den;
  U := ((CX-AX)*(BY-AY)-(CY-AY)*(BX-AX))/Den;
  if (T<=0) or (T>=1) or (U<0) or (U>1) then begin
    ShowMessage('Não há interseção interna para aparar.'); Exit;
  end;
  EndText := 'B';
  if not InputQuery('Escolher extremidade', 'Remover lado A ou B?',EndText) then Exit;
  EndText := UpperCase(Trim(EndText));
  if (EndText <> 'A') and (EndText <> 'B') then begin
    ShowMessage('Escolha A ou B.'); Exit;
  end;
  CutPoint := Point(Round(AX+T*(BX-AX)),Round(AY+T*(BY-AY)));
  RecordChange;
  if EndText='A' then FLines[Id].A := CutPoint
  else FLines[Id].B := CutPoint;
  FCanvas.Invalidate;
  RefreshStatus('Segmento aparado');
end;
procedure TCADMainForm.ChamferSelected(Sender: TObject);
var OtherText, DistanceText: string; Id, Other, N: Integer;
    AX, AY, BX, BY, CX, CY, DX, DY, Den, T, U,
    PX, PY, Len1, Len2, Offset1, Offset2: Double;
    P1, P2: TPoint; ChangeA1, ChangeA2: Boolean;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione a primeira linha para criar o chanfro.'); Exit;
  end;
  OtherText := '';
  if not InputQuery('Chanfro', 'Número da segunda linha:', OtherText) then Exit;
  if (not TryStrToInt(OtherText,Other)) or (Other < 1) or
    (Other > Length(FLines)) or (Other = Id+1) then begin
    ShowMessage('Segunda linha inválida.'); Exit;
  end;
  Dec(Other);
  DistanceText := '200';
  if not InputQuery('Chanfro', 'Distância em milímetros:', DistanceText) then Exit;
  if not TryStrToFloat(DistanceText,Offset1) then begin
    ShowMessage('Distância inválida.'); Exit;
  end;
  if IsNan(Offset1) or IsInfinite(Offset1) or
    (Offset1 <= 0) or (Offset1 > 1000000) then begin
    ShowMessage('Distância fora do limite.'); Exit;
  end;
  AX := FLines[Id].A.X; AY := FLines[Id].A.Y;
  BX := FLines[Id].B.X; BY := FLines[Id].B.Y;
  CX := FLines[Other].A.X; CY := FLines[Other].A.Y;
  DX := FLines[Other].B.X; DY := FLines[Other].B.Y;
  Den := (BX-AX)*(DY-CY)-(BY-AY)*(DX-CX);
  if Abs(Den) < 0.000001 then begin
    ShowMessage('As linhas são paralelas ou coincidentes.'); Exit;
  end;
  T := ((CX-AX)*(DY-CY)-(CY-AY)*(DX-CX))/Den;
  U := ((CX-AX)*(BY-AY)-(CY-AY)*(BX-AX))/Den;
  PX := AX+T*(BX-AX); PY := AY+T*(BY-AY);
  Len1 := Hypot(BX-AX,BY-AY);
  Len2 := Hypot(DX-CX,DY-CY);
  if (Len1 < 1) or (Len2 < 1) then Exit;
  Offset2 := Offset1 / FMillimetersPerPixel;
  ChangeA1 := T < 0.5;
  ChangeA2 := U < 0.5;
  if ChangeA1 then begin
    if (Hypot(AX-PX,AY-PY) < Offset2) then begin
      ShowMessage('Primeira linha curta para este chanfro.'); Exit;
    end;
    P1 := Point(Round(PX+(AX-PX)/Hypot(AX-PX,AY-PY)*Offset2),
                Round(PY+(AY-PY)/Hypot(AX-PX,AY-PY)*Offset2));
  end else begin
    if Hypot(BX-PX,BY-PY) < Offset2 then begin
      ShowMessage('Primeira linha curta para este chanfro.'); Exit;
    end;
    P1 := Point(Round(PX+(BX-PX)/Hypot(BX-PX,BY-PY)*Offset2),
                Round(PY+(BY-PY)/Hypot(BX-PX,BY-PY)*Offset2));
  end;
  if ChangeA2 then begin
    if Hypot(CX-PX,CY-PY) < Offset2 then begin
      ShowMessage('Segunda linha curta para este chanfro.'); Exit;
    end;
    P2 := Point(Round(PX+(CX-PX)/Hypot(CX-PX,CY-PY)*Offset2),
                Round(PY+(CY-PY)/Hypot(CX-PX,CY-PY)*Offset2));
  end else begin
    if Hypot(DX-PX,DY-PY) < Offset2 then begin
      ShowMessage('Segunda linha curta para este chanfro.'); Exit;
    end;
    P2 := Point(Round(PX+(DX-PX)/Hypot(DX-PX,DY-PY)*Offset2),
                Round(PY+(DY-PY)/Hypot(DX-PX,DY-PY)*Offset2));
  end;
  if (P1.X=P2.X) and (P1.Y=P2.Y) then begin
    ShowMessage('Chanfro abaixo da resolução do desenho.'); Exit;
  end;
  RecordChange;
  if ChangeA1 then FLines[Id].A := P1 else FLines[Id].B := P1;
  if ChangeA2 then FLines[Other].A := P2 else FLines[Other].B := P2;
  N := Length(FLines); SetLength(FLines,N+1);
  FLines[N].A := P1; FLines[N].B := P2;
  FLines[N].Layer := FLines[Id].Layer;
  FLines[N].Kind := 0; FLines[N].WidthMM := 0;
  FLines[N].GroupID := FNextGroup; Inc(FNextGroup);
  FSelected := N;
  FCanvas.Invalidate;
  RefreshStatus('Chanfro criado');
end;
procedure TCADMainForm.FilletSelected(Sender: TObject);
var Id, Other, N, J, Steps: Integer; TextId, TextRadius: string;
    AX, AY, BX, BY, CX, CY, DX, DY, Den, T, U, IX, IY,
    V1X, V1Y, V2X, V2Y, L1, L2, DotValue, Angle, Radius,
    Tangent, Q1X, Q1Y, Q2X, Q2Y, BisX, BisY, BisLen,
    CenterX, CenterY, CenterDist, StartAngle, EndAngle,
    Sweep, PrevX, PrevY, X, Y: Double;
    P1, P2, PrevPoint, NextPoint: TPoint;
    NearA1, NearA2: Boolean;
begin
  Id := FSelected;
  if (Id < 0) or (Id >= Length(FLines)) then begin
    ShowMessage('Selecione a primeira linha.'); Exit;
  end;
  TextId := '';
  if not InputQuery('Arredondar canto','Número da segunda linha:',TextId) then Exit;
  if (not TryStrToInt(TextId,Other)) or (Other<1) or
     (Other>Length(FLines)) or (Other=Id+1) then begin
    ShowMessage('Segunda linha inválida.'); Exit;
  end;
  Dec(Other);
  TextRadius := '200';
  if not InputQuery('Arredondar canto','Raio em milímetros:',TextRadius) then Exit;
  if not TryStrToFloat(TextRadius,Radius) then begin
    ShowMessage('Raio inválido.'); Exit;
  end;
  if IsNan(Radius) or IsInfinite(Radius) or
     (Radius <= 0) or (Radius > 1000000) then begin
    ShowMessage('Raio fora do limite.'); Exit;
  end;
  Radius := Radius / FMillimetersPerPixel;
  AX := FLines[Id].A.X; AY := FLines[Id].A.Y;
  BX := FLines[Id].B.X; BY := FLines[Id].B.Y;
  CX := FLines[Other].A.X; CY := FLines[Other].A.Y;
  DX := FLines[Other].B.X; DY := FLines[Other].B.Y;
  Den := (BX-AX)*(DY-CY)-(BY-AY)*(DX-CX);
  if Abs(Den)<0.000001 then begin
    ShowMessage('Linhas paralelas ou coincidentes.'); Exit;
  end;
  T := ((CX-AX)*(DY-CY)-(CY-AY)*(DX-CX))/Den;
  U := ((CX-AX)*(BY-AY)-(CY-AY)*(BX-AX))/Den;
  IX := AX+T*(BX-AX); IY := AY+T*(BY-AY);
  NearA1 := Hypot(IX-AX,IY-AY) <= Hypot(IX-BX,IY-BY);
  NearA2 := Hypot(IX-CX,IY-CY) <= Hypot(IX-DX,IY-DY);
  if NearA1 then begin V1X:=AX-IX; V1Y:=AY-IY; end
  else begin V1X:=BX-IX; V1Y:=BY-IY; end;
  if NearA2 then begin V2X:=CX-IX; V2Y:=CY-IY; end
  else begin V2X:=DX-IX; V2Y:=DY-IY; end;
  L1 := Hypot(V1X,V1Y); L2 := Hypot(V2X,V2Y);
  if (L1<1) or (L2<1) then Exit;
  V1X:=V1X/L1; V1Y:=V1Y/L1;
  V2X:=V2X/L2; V2Y:=V2Y/L2;
  DotValue := Max(-1.0,Min(1.0,V1X*V2X+V1Y*V2Y));
  Angle := ArcCos(DotValue);
  if (Angle < 0.05) or (Angle > Pi-0.05) then begin
    ShowMessage('Ângulo inadequado para arredondamento.'); Exit;
  end;
  Tangent := Radius/Tan(Angle/2);
  if (Tangent >= L1) or (Tangent >= L2) then begin
    ShowMessage('Raio grande demais para os segmentos.'); Exit;
  end;
  Q1X:=IX+Tangent*V1X; Q1Y:=IY+Tangent*V1Y;
  Q2X:=IX+Tangent*V2X; Q2Y:=IY+Tangent*V2Y;
  BisX:=V1X+V2X; BisY:=V1Y+V2Y;
  BisLen:=Hypot(BisX,BisY);
  CenterDist:=Radius/Sin(Angle/2);
  CenterX:=IX+CenterDist*BisX/BisLen;
  CenterY:=IY+CenterDist*BisY/BisLen;
  P1:=Point(Round(Q1X),Round(Q1Y));
  P2:=Point(Round(Q2X),Round(Q2Y));
  if (P1.X=P2.X) and (P1.Y=P2.Y) then begin
    ShowMessage('Raio abaixo da resolução atual.'); Exit;
  end;
  StartAngle:=ArcTan2(Q1Y-CenterY,Q1X-CenterX);
  EndAngle:=ArcTan2(Q2Y-CenterY,Q2X-CenterX);
  Sweep:=EndAngle-StartAngle;
  while Sweep>Pi do Sweep:=Sweep-2*Pi;
  while Sweep< -Pi do Sweep:=Sweep+2*Pi;
  Steps:=Max(4,Min(64,Ceil(Abs(Sweep)*Radius/3)));
  RecordChange;
  if NearA1 then FLines[Id].A:=P1 else FLines[Id].B:=P1;
  if NearA2 then FLines[Other].A:=P2 else FLines[Other].B:=P2;
  PrevPoint:=P1;
  for J:=1 to Steps do begin
    X:=CenterX+Radius*Cos(StartAngle+Sweep*J/Steps);
    Y:=CenterY+Radius*Sin(StartAngle+Sweep*J/Steps);
    NextPoint:=Point(Round(X),Round(Y));
    if J=Steps then NextPoint:=P2;
    if (PrevPoint.X<>NextPoint.X) or (PrevPoint.Y<>NextPoint.Y) then begin
      N:=Length(FLines); SetLength(FLines,N+1);
      FLines[N].A:=PrevPoint; FLines[N].B:=NextPoint;
      FLines[N].Layer:=FLines[Id].Layer; FLines[N].Kind:=0;
      FLines[N].WidthMM:=0; FLines[N].GroupID:=FNextGroup;
    end;
    PrevPoint:=NextPoint;
  end;
  Inc(FNextGroup);
  FSelected:=-1; FCanvas.Invalidate;
  RefreshStatus('Canto arredondado');
end;
procedure TCADMainForm.EditLastObject(Sender: TObject);
var V: string; MM, N: Integer;
begin
  N := FSelected;
  if N < 0 then N := High(FLines);
  if N < 0 then Exit;
  if FLines[N].Kind < 2 then begin
    ShowMessage('A última entidade não é parede, porta ou janela.'); Exit;
  end;
  V := IntToStr(FLines[N].WidthMM);
  if not InputQuery('Propriedade dimensional',
     'Espessura ou largura nominal (mm):', V) then Exit;
  if (not TryStrToInt(V, MM)) or (MM < 50) or (MM > 10000) then begin
    ShowMessage('Informe de 50 a 10000 mm.'); Exit;
  end;
  RecordChange;
  FLines[N].WidthMM := MM;
  FCanvas.Invalidate;
  RefreshStatus('Dimensão atualizada');
end;
procedure TCADMainForm.ToggleDimensions(Sender: TObject);
begin
  FShowDimensions := not FShowDimensions;
  FCanvas.Invalidate;
  if FShowDimensions then RefreshStatus('Cotas visíveis em metros')
  else RefreshStatus('Cotas ocultas');
end;
procedure TCADMainForm.MeasureSelected(Sender: TObject);
var A, B: TPoint; MM: Double; V: string; I:Integer;
begin
  if (FSelected < 0) or (FSelected >= Length(FLines)) then begin
    ShowMessage('Selecione um segmento antes de medir.'); Exit;
  end;
  A := FLines[FSelected].A; B := FLines[FSelected].B;
  MM:=0;
  for I:=0 to High(FLines) do if IsPicked(I) then MM:=MM+Hypot(FLines[I].B.X-FLines[I].A.X,FLines[I].B.Y-FLines[I].A.Y)*FMillimetersPerPixel;
  V := FormatFloat('0.00',MM/1000);
  ShowMessage('Comprimento: ' + V + ' m (' +
    IntToStr(Round(MM)) + ' mm)');
end;
procedure TCADMainForm.ExportSVG(Sender: TObject);
var D:TSaveDialog;
begin
  D:=TSaveDialog.Create(Self);
  try
    D.Filter:='SVG (*.svg)|*.svg'; D.DefaultExt:='svg'; D.Options:=D.Options+[ofOverwritePrompt];
    if D.Execute then begin ExportProject(D.FileName,True); RefreshStatus('SVG exportado'); end;
  finally D.Free; end;
end;
procedure TCADMainForm.ExportDXF(Sender: TObject);
var D:TSaveDialog;
begin
  D:=TSaveDialog.Create(Self);
  try
    D.Filter:='DXF 2007 (*.dxf)|*.dxf'; D.DefaultExt:='dxf'; D.Options:=D.Options+[ofOverwritePrompt];
    if D.Execute then begin ExportProject(D.FileName,False); RefreshStatus('DXF exportado'); end;
  finally D.Free; end;
end;
procedure TCADMainForm.SaveDrawing(Sender: TObject);
var D:TSaveDialog;
begin
  D:=TSaveDialog.Create(Self);
  try
    D.Filter:='Projeto CAD 2D (*.eacad)|*.eacad'; D.DefaultExt:='eacad'; D.Options:=D.Options+[ofOverwritePrompt];
    if FPath<>'' then D.FileName:=FPath else D.FileName:='planta.eacad';
    if D.Execute then begin SaveProject(D.FileName); RefreshStatus('Projeto salvo'); end;
  finally D.Free; end;
end;
procedure TCADMainForm.OpenDrawing(Sender: TObject);
var D:TOpenDialog;
begin
  D:=TOpenDialog.Create(Self);
  try
    D.Filter:='Projeto CAD 2D (*.eacad)|*.eacad';
    if D.Execute then try LoadProject(D.FileName); except on E:Exception do ShowMessage(E.Message); end;
  finally D.Free; end;
end;

procedure TCADMainForm.FitDrawingToBounds;
var
  I, MinX, MaxX, MinY, MaxY, SpanX, SpanY: Integer;
  ScaleX, ScaleY: Double;
begin
  if Length(FLines) = 0 then Exit;
  MinX := FLines[0].A.X; MaxX := FLines[0].A.X;
  MinY := FLines[0].A.Y; MaxY := FLines[0].A.Y;
  for I := 0 to High(FLines) do
  begin
    MinX := Min(MinX, Min(FLines[I].A.X, FLines[I].B.X));
    MaxX := Max(MaxX, Max(FLines[I].A.X, FLines[I].B.X));
    MinY := Min(MinY, Min(FLines[I].A.Y, FLines[I].B.Y));
    MaxY := Max(MaxY, Max(FLines[I].A.Y, FLines[I].B.Y));
  end;
  SpanX := MaxX - MinX;
  SpanY := MaxY - MinY;
  if (SpanX <= 0) or (SpanY <= 0) then Exit;

  ScaleX := (FCanvas.Width - 80) / SpanX;
  ScaleY := (FCanvas.Height - 80) / SpanY;
  FZoom := Max(0.05, Min(3.0, Min(ScaleX, ScaleY)));
  FPanX := Round(40 - MinX * FZoom);
  FPanY := Round(40 - MinY * FZoom);
  FCanvas.Invalidate;
end;

procedure TCADMainForm.ApplyImportedEntities(const AEntities: array of TImportedEntity; ACount: Integer);
var
  I, BaseIdx, OffsetGroup: Integer;
begin
  if ACount <= 0 then Exit;
  RecordChange;
  OffsetGroup := FNextGroup;
  BaseIdx := Length(FLines);
  SetLength(FLines, BaseIdx + ACount);
  for I := 0 to ACount - 1 do
  begin
    FLines[BaseIdx + I].A := AEntities[I].A;
    FLines[BaseIdx + I].B := AEntities[I].B;
    FLines[BaseIdx + I].Layer := AEntities[I].Layer;
    FLines[BaseIdx + I].Kind := AEntities[I].Kind;
    FLines[BaseIdx + I].WidthMM := AEntities[I].WidthMM;
    FLines[BaseIdx + I].GroupID := OffsetGroup + AEntities[I].GroupID;
    FNextGroup := Max(FNextGroup, FLines[BaseIdx + I].GroupID + 1);
  end;
  FSelected := -1;
  FHasStart := False;
  FitDrawingToBounds;
end;

procedure TCADMainForm.ImportDWGDXF(Sender: TObject);
var
  D: TOpenDialog;
  Buffer: array[0..32767] of TImportedEntity;
  Count: Integer;
  Report: TImportReport;
  Ext, Ver: string;
  Fmt: TFileFormat;
  Ok: Boolean;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Title := 'Importar Desenho Técnico (DWG / DXF)';
    D.Filter := 'Desenhos CAD (*.dwg;*.dxf)|*.dwg;*.dxf|AutoCAD DXF (*.dxf)|*.dxf|AutoCAD DWG (*.dwg)|*.dwg|Todos os arquivos (*.*)|*.*';
    if not D.Execute then Exit;

    InitReport(Report, D.FileName);
    try
      Fmt := DetectFormat(D.FileName, Ver);
      Ext := LowerCase(ExtractFileExt(D.FileName));

      if (Fmt = fmtDWG) or (Ext = '.dwg') then
        Ok := ImportDWG(D.FileName, Buffer, Count, Report, FMillimetersPerPixel)
      else
        Ok := ImportDXF(D.FileName, Buffer, Count, Report, FMillimetersPerPixel);

      if Ok and (Count > 0) then
      begin
        ApplyImportedEntities(Buffer, Count);
        RefreshStatus(Format('Importado: %s (%d objetos)', [ExtractFileName(D.FileName), Count]));
        MessageDlg('Importação Concluída', FormatReportSummary(Report), mtInformation, [mbOK], 0);
      end
      else
      begin
        MessageDlg('Resultado da Importação', FormatReportSummary(Report), mtWarning, [mbOK], 0);
      end;
    finally
      FreeReport(Report);
    end;
  finally
    D.Free;
  end;
end;

procedure TCADMainForm.ImportIFCDrawing(Sender: TObject);
var
  D: TOpenDialog;
  Buffer: array[0..32767] of TImportedEntity;
  Count: Integer;
  Report: TImportReport;
  Floors: TStringList;
  TargetFloor: string;
  Ok: Boolean;
begin
  D := TOpenDialog.Create(Self);
  Floors := TStringList.Create;
  try
    D.Title := 'Importar Modelo BIM IFC (Vistas 2D de Pavimentos)';
    D.Filter := 'Modelos BIM IFC (*.ifc;*.ifczip)|*.ifc;*.ifczip|Todos os arquivos (*.*)|*.*';
    if not D.Execute then Exit;

    InitReport(Report, D.FileName);
    try
      TargetFloor := '';
      if GetIFCFloors(D.FileName, Floors) and (Floors.Count > 0) then
        TargetFloor := Floors[0];

      Ok := ImportIFC(D.FileName, TargetFloor, Buffer, Count, Report, FMillimetersPerPixel);

      if Ok and (Count > 0) then
      begin
        ApplyImportedEntities(Buffer, Count);
        RefreshStatus(Format('Modelo IFC extraído: %s (%d elementos)', [ExtractFileName(D.FileName), Count]));
        MessageDlg('Extração 2D de Modelo BIM IFC', FormatReportSummary(Report), mtInformation, [mbOK], 0);
      end
      else
      begin
        MessageDlg('Resultado da Importação IFC', FormatReportSummary(Report), mtWarning, [mbOK], 0);
      end;
    finally
      FreeReport(Report);
    end;
  finally
    Floors.Free;
    D.Free;
  end;
end;

end.
