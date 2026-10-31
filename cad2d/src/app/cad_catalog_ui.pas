unit cad_catalog_ui;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Spin, Graphics, Dialogs, fpjson, cad_catalog, cad_document, Types, Math;
function CADChooseItem(Catalog: TCADCatalog; out ID: string; out WidthMM,DepthMM: Integer): Boolean;
implementation
type
  TCatalogForm = class(TForm)
  public
    Catalog: TCADCatalog;
    Category: TComboBox;
    ItemList: TListBox;
    Details: TMemo;
    Preview: TPaintBox;
    procedure PaintPreview(Sender: TObject);
  public
    W,D: TSpinEdit;
    IDs: TStringList;
    procedure Filter(Sender: TObject);
    procedure Pick(Sender: TObject);
    constructor Build(ACatalog: TCADCatalog);
    destructor Destroy; override;
  end;
constructor TCatalogForm.Build(ACatalog: TCADCatalog);
var I: Integer; Categories: TStringList; L: TLabel; B: TButton;
begin
  inherited CreateNew(nil); Catalog:=ACatalog; IDs:=TStringList.Create;
  Caption:='Biblioteca 2D — Saúde e uso geral'; Width:=840; Height:=570;
  Position:=poScreenCenter; BorderStyle:=bsDialog; Font.Name:='Segoe UI'; Font.Size:=10;
  Category:=TComboBox.Create(Self); Category.Parent:=Self; Category.SetBounds(20,20,790,28); Category.Style:=csDropDownList;
  Categories:=TStringList.Create;
  try
    Categories.Sorted:=True; Categories.Duplicates:=dupIgnore;
    for I:=0 to Catalog.Items.Count-1 do Categories.Add(Catalog.Items.Objects[I].Get('category',''));
    Category.Items.Add('Todas as categorias'); Category.Items.AddStrings(Categories);
  finally Categories.Free; end;
  Category.ItemIndex:=0; Category.OnChange:=@Filter;
  ItemList:=TListBox.Create(Self); ItemList.Parent:=Self; ItemList.SetBounds(20,64,390,420); ItemList.OnClick:=@Pick;
  Details:=TMemo.Create(Self); Details.Parent:=Self; Details.SetBounds(430,64,380,180); Details.ReadOnly:=True; Details.ScrollBars:=ssAutoVertical;
  Preview:=TPaintBox.Create(Self); Preview.Parent:=Self; Preview.SetBounds(430,254,380,100); Preview.OnPaint:=@PaintPreview;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(430,365,350,24); L.Caption:='Largura × profundidade (mm) — editável';
  W:=TSpinEdit.Create(Self); W.Parent:=Self; W.SetBounds(430,397,180,30); W.MinValue:=10; W.MaxValue:=1000000;
  D:=TSpinEdit.Create(Self); D.Parent:=Self; D.SetBounds(630,397,180,30); D.MinValue:=10; D.MaxValue:=1000000;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(430,438,380,44); L.AutoSize:=False; L.WordWrap:=True;
  L.Caption:='Inserir ativa o posicionamento: clique no desenho. A dimensão deve ser conferida com o equipamento ou mobiliário escolhido.';
  B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(560,495,120,34); B.Caption:='Inserir'; B.ModalResult:=mrOK;
  B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(690,495,120,34); B.Caption:='Cancelar'; B.ModalResult:=mrCancel;
  Filter(nil);
end;
destructor TCatalogForm.Destroy;
begin IDs.Free; inherited Destroy; end;
procedure TCatalogForm.Filter(Sender: TObject);
var I: Integer; O: TJSONObject;
begin
  IDs.Clear; ItemList.Items.Clear;
  for I:=0 to Catalog.Items.Count-1 do begin
    O:=Catalog.Items.Objects[I];
    if (Category.ItemIndex=0) or (O.Get('category','')=Category.Text) then begin IDs.Add(O.Get('id','')); ItemList.Items.Add(O.Get('name','')); end;
  end;
  if IDs.Count>0 then ItemList.ItemIndex:=0; Pick(nil);
end;
procedure TCatalogForm.Pick(Sender: TObject);
var O: TJSONObject;
begin
  Details.Clear; if ItemList.ItemIndex<0 then Exit;
  O:=Catalog.Item(IDs[ItemList.ItemIndex]); W.Value:=O.Get('width_mm',1000); D.Value:=O.Get('depth_mm',1000);
  Preview.Invalidate;
  Details.Lines.Add(O.Get('name','')); Details.Lines.Add(O.Get('category','')); Details.Lines.Add('Representação em planta 2D');
  Details.Lines.Add(''); Details.Lines.Add(O.Get('notes','')); Details.Lines.Add(''); Details.Lines.Add('Referência de planejamento: '+O.Get('reference_url','Uso geral'));
end;
procedure TCatalogForm.PaintPreview(Sender: TObject);
var Lines: TCADLines; I,WMM,DMM,OX,OY: Integer; Zoom: Double;
begin
  Preview.Canvas.Brush.Color:=clWhite; Preview.Canvas.FillRect(Preview.ClientRect);
  if ItemList.ItemIndex<0 then Exit;
  try
    WMM:=Catalog.Item(IDs[ItemList.ItemIndex]).Get('width_mm',1000);
    DMM:=Catalog.Item(IDs[ItemList.ItemIndex]).Get('depth_mm',1000);
    Lines:=Catalog.BuildLines(IDs[ItemList.ItemIndex],Point(0,0),WMM,DMM,1);
    Zoom:=Min((Preview.Width-16)/WMM,(Preview.Height-16)/DMM);
    OX:=Round((Preview.Width-WMM*Zoom)/2); OY:=Round((Preview.Height-DMM*Zoom)/2);
    Preview.Canvas.Pen.Color:=RGBToColor(30,64,145);
    for I:=0 to High(Lines) do begin
      Preview.Canvas.MoveTo(OX+Round(Lines[I].A.X*Zoom),OY+Round(Lines[I].A.Y*Zoom));
      Preview.Canvas.LineTo(OX+Round(Lines[I].B.X*Zoom),OY+Round(Lines[I].B.Y*Zoom));
    end;
  except on E: Exception do Preview.Canvas.TextOut(8,8,'Prévia indisponível'); end;
end;

function CADChooseItem(Catalog: TCADCatalog; out ID: string; out WidthMM,DepthMM: Integer): Boolean;
var F: TCatalogForm;
begin
  Result:=False; F:=TCatalogForm.Build(Catalog);
  try
    if F.ShowModal<>mrOK then Exit;
    if F.ItemList.ItemIndex<0 then Exit;
    ID:=F.IDs[F.ItemList.ItemIndex]; WidthMM:=F.W.Value; DepthMM:=F.D.Value; Result:=True;
  finally F.Free; end;
end;
end.
