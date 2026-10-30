unit plan_estilo;

{ Planejador - padrao visual da plataforma.
  Paleta e tipografia seguem o padrao visual usado pela suite MultiCNC
  (referencia de estilo; nenhum codigo do MultiCNC e usado). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ExtCtrls, StdCtrls, Buttons, Types;

const
  PL_FONTE = {$IFDEF WINDOWS}'Segoe UI'{$ELSE}'default'{$ENDIF};

var
  clPLSuperficie, clPLCartao, clPLTexto, clPLSuave, clPLBorda, clPLPrimaria,
  clPLSucesso, clPLAlerta, clPLPerigo, clPLMarinho, clPLMarinho2: TColor;

type
  { faixa superior com titulo e subtitulo }
  TPLCabecalho = class(TCustomControl)
  private
    FTitulo, FSubtitulo: string;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Configurar(const ATitulo, ASubtitulo: string);
  end;

function PLRotulo(AParent: TWinControl; const ATexto: string; ANegrito: Boolean = False): TLabel;
function PLBotao(AParent: TWinControl; const ATexto, ADica: string; AClique: TNotifyEvent): TSpeedButton;
procedure PLSeparador(AParent: TWinControl);
function PLPainel(AOwner: TComponent; AParent: TWinControl; AAlign: TAlign; ATamanho: Integer;
  ACor: TColor): TPanel;

implementation

constructor TPLCabecalho.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Height := 72;
  Align := alTop;
end;

procedure TPLCabecalho.Configurar(const ATitulo, ASubtitulo: string);
begin
  FTitulo := ATitulo;
  FSubtitulo := ASubtitulo;
  Invalidate;
end;

procedure TPLCabecalho.Paint;
var R: TRect;
begin
  R := ClientRect;
  Canvas.GradientFill(R, clPLMarinho, clPLMarinho2, gdHorizontal);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := PL_FONTE;
  Canvas.Font.Size := 16;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := clWhite;
  Canvas.TextOut(20, 12, FTitulo);
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [];
  Canvas.Font.Color := RGBToColor(191, 219, 254);
  Canvas.TextOut(21, 43, FSubtitulo);
end;

function PLRotulo(AParent: TWinControl; const ATexto: string; ANegrito: Boolean): TLabel;
begin
  Result := TLabel.Create(AParent);
  Result.Parent := AParent;
  Result.Caption := ATexto;
  Result.Align := alTop;
  Result.BorderSpacing.Top := 8;
  Result.BorderSpacing.Left := 12;
  Result.BorderSpacing.Right := 12;
  Result.Font.Color := clPLSuave;
  if ANegrito then
  begin
    Result.Font.Style := [fsBold];
    Result.Font.Color := clPLTexto;
    Result.BorderSpacing.Top := 14;
  end;
end;

function PLBotao(AParent: TWinControl; const ATexto, ADica: string; AClique: TNotifyEvent): TSpeedButton;
var B: TBitmap;
begin
  Result := TSpeedButton.Create(AParent);
  Result.Parent := AParent;
  Result.Align := alLeft;
  Result.Flat := True;
  Result.Caption := ATexto;
  Result.Hint := ADica;
  Result.ShowHint := True;
  Result.OnClick := AClique;
  B := TBitmap.Create;
  try
    B.Canvas.Font.Name := PL_FONTE;
    B.Canvas.Font.Size := 10;
    Result.Width := B.Canvas.TextWidth(ATexto) + 22;
  finally
    B.Free;
  end;
  Result.BorderSpacing.Around := 4;
end;

procedure PLSeparador(AParent: TWinControl);
var B: TBevel;
begin
  B := TBevel.Create(AParent);
  B.Parent := AParent;
  B.Align := alLeft;
  B.Shape := bsLeftLine;
  B.Width := 9;
  B.BorderSpacing.Top := 8;
  B.BorderSpacing.Bottom := 8;
  B.BorderSpacing.Left := 4;
end;

function PLPainel(AOwner: TComponent; AParent: TWinControl; AAlign: TAlign; ATamanho: Integer;
  ACor: TColor): TPanel;
begin
  Result := TPanel.Create(AOwner);
  Result.Parent := AParent;
  Result.Align := AAlign;
  Result.BevelOuter := bvNone;
  Result.Color := ACor;
  Result.ParentColor := False;
  if AAlign in [alLeft, alRight] then Result.Width := ATamanho
  else if AAlign in [alTop, alBottom] then Result.Height := ATamanho;
end;

initialization
  clPLSuperficie := RGBToColor(244, 246, 250);
  clPLCartao := clWhite;
  clPLTexto := RGBToColor(15, 23, 42);
  clPLSuave := RGBToColor(100, 116, 139);
  clPLBorda := RGBToColor(226, 232, 240);
  clPLPrimaria := RGBToColor(37, 99, 235);
  clPLSucesso := RGBToColor(22, 163, 74);
  clPLAlerta := RGBToColor(217, 119, 6);
  clPLPerigo := RGBToColor(220, 38, 38);
  clPLMarinho := RGBToColor(15, 23, 42);
  clPLMarinho2 := RGBToColor(30, 64, 145);
end.
