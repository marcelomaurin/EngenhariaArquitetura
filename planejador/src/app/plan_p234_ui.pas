unit plan_p234_ui;

{ Planejador - Interfaces P2/P3/P4:
  - Linha de base (Baseline) e comparação de desvios
  - Curva S física e financeira acumulada
  - Calendário visual mensal das tarefas
  - Vínculo de objetos e texturas/skins por objeto ou face (P4) }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, DateUtils, Math, Forms, Controls, StdCtrls, ExtCtrls,
  ComCtrls, Grids, Graphics, Dialogs,
  plan_tipos, plan_documento, plan_cronograma, plan_p234, ea_money;

procedure PLAbrirDialogoAcompanhamentoP3(Owner: TForm; Doc: TPLProjeto; Crono: TPLCronograma);
function PLEditarObjetoTexturaP4(Owner: TForm; Doc: TPLProjeto; T: TPLTarefa): Boolean;

implementation

type
  TPLP3Form = class(TForm)
  private
    FDoc: TPLProjeto;
    FCrono: TPLCronograma;
    FCurva: TPLCurvaSPontos;
    FBaseGrid: TStringGrid;
    FChart: TPaintBox;
    FCalGrid: TStringGrid;
    FMonthLabel: TLabel;
    FCalYear, FCalMonth: Word;
    procedure RefreshBaseline;
    procedure RefreshCalendar;
    procedure FreezeBaselineClick(Sender: TObject);
    procedure ExportCurveCSVClick(Sender: TObject);
    procedure PaintCurve(Sender: TObject);
    procedure PrevMonthClick(Sender: TObject);
    procedure NextMonthClick(Sender: TObject);
  public
    constructor CreateP3(AOwner: TComponent; ADoc: TPLProjeto; ACrono: TPLCronograma);
  end;

constructor TPLP3Form.CreateP3(AOwner: TComponent; ADoc: TPLProjeto; ACrono: TPLCronograma);
var
  Pages: TPageControl;
  TabBase, TabCurva, TabCal: TTabSheet;
  TopBar: TPanel;
  B: TButton;
begin
  inherited CreateNew(AOwner);
  FDoc := ADoc;
  FCrono := ACrono;
  if (FCrono <> nil) and FCrono.Valido and (FCrono.Inicio > 0) then
  begin
    FCalYear := YearOf(FCrono.Inicio);
    FCalMonth := MonthOf(FCrono.Inicio);
  end
  else
  begin
    FCalYear := YearOf(Date);
    FCalMonth := MonthOf(Date);
  end;

  Caption := 'Acompanhamento P3 — Linha de Base, Curva S e Calendário';
  SetBounds(0, 0, 960, 620);
  Position := poScreenCenter;
  Font.Name := {$IFDEF WINDOWS}'Segoe UI'{$ELSE}'Sans'{$ENDIF};
  Font.Size := 10;
  Color := RGBToColor(244, 246, 250);

  Pages := TPageControl.Create(Self);
  Pages.Parent := Self;
  Pages.Align := alClient;

  TabBase := TTabSheet.Create(Pages); TabBase.PageControl := Pages; TabBase.Caption := 'Linha de Base';
  TopBar := TPanel.Create(TabBase); TopBar.Parent := TabBase; TopBar.Align := alTop; TopBar.Height := 46; TopBar.BevelOuter := bvNone;
  B := TButton.Create(TopBar); B.Parent := TopBar; B.SetBounds(12, 8, 210, 30);
  B.Caption := 'Congelar linha de base atual'; B.OnClick := @FreezeBaselineClick;
  FBaseGrid := TStringGrid.Create(TabBase); FBaseGrid.Parent := TabBase; FBaseGrid.Align := alClient;
  FBaseGrid.ColCount := 7; FBaseGrid.FixedRows := 1;
  FBaseGrid.Options := FBaseGrid.Options + [goRowSelect, goColSizing];
  FBaseGrid.Cells[0, 0] := 'ID'; FBaseGrid.ColWidths[0] := 70;
  FBaseGrid.Cells[1, 0] := 'Tarefa'; FBaseGrid.ColWidths[1] := 230;
  FBaseGrid.Cells[2, 0] := 'Base Início'; FBaseGrid.ColWidths[2] := 105;
  FBaseGrid.Cells[3, 0] := 'Base Término'; FBaseGrid.ColWidths[3] := 105;
  FBaseGrid.Cells[4, 0] := 'Atual Término'; FBaseGrid.ColWidths[4] := 105;
  FBaseGrid.Cells[5, 0] := 'Desvio (d)'; FBaseGrid.ColWidths[5] := 90;
  FBaseGrid.Cells[6, 0] := 'Custo Base / Atual'; FBaseGrid.ColWidths[6] := 190;

  TabCurva := TTabSheet.Create(Pages); TabCurva.PageControl := Pages; TabCurva.Caption := 'Curva S';
  TopBar := TPanel.Create(TabCurva); TopBar.Parent := TabCurva; TopBar.Align := alTop; TopBar.Height := 46; TopBar.BevelOuter := bvNone;
  B := TButton.Create(TopBar); B.Parent := TopBar; B.SetBounds(12, 8, 170, 30);
  B.Caption := 'Exportar Curva S (CSV)'; B.OnClick := @ExportCurveCSVClick;
  FChart := TPaintBox.Create(TabCurva); FChart.Parent := TabCurva; FChart.Align := alClient;
  FChart.OnPaint := @PaintCurve;

  TabCal := TTabSheet.Create(Pages); TabCal.PageControl := Pages; TabCal.Caption := 'Calendário Visual';
  TopBar := TPanel.Create(TabCal); TopBar.Parent := TabCal; TopBar.Align := alTop; TopBar.Height := 46; TopBar.BevelOuter := bvNone;
  B := TButton.Create(TopBar); B.Parent := TopBar; B.SetBounds(12, 8, 42, 30); B.Caption := '<'; B.OnClick := @PrevMonthClick;
  B := TButton.Create(TopBar); B.Parent := TopBar; B.SetBounds(62, 8, 42, 30); B.Caption := '>'; B.OnClick := @NextMonthClick;
  FMonthLabel := TLabel.Create(TopBar); FMonthLabel.Parent := TopBar; FMonthLabel.SetBounds(120, 12, 320, 24);
  FMonthLabel.Font.Style := [fsBold];
  FCalGrid := TStringGrid.Create(TabCal); FCalGrid.Parent := TabCal; FCalGrid.Align := alClient;
  FCalGrid.ColCount := 7; FCalGrid.RowCount := 7; FCalGrid.FixedRows := 1;
  FCalGrid.DefaultColWidth := 128; FCalGrid.DefaultRowHeight := 74;
  FCalGrid.Cells[0, 0] := 'Dom'; FCalGrid.Cells[1, 0] := 'Seg'; FCalGrid.Cells[2, 0] := 'Ter';
  FCalGrid.Cells[3, 0] := 'Qua'; FCalGrid.Cells[4, 0] := 'Qui'; FCalGrid.Cells[5, 0] := 'Sex';
  FCalGrid.Cells[6, 0] := 'Sáb';

  FCurva := PLCalcularCurvaS(FDoc, FCrono);
  RefreshBaseline;
  RefreshCalendar;
end;

procedure TPLP3Form.RefreshBaseline;
var
  I: Integer;
  BItem: TPLBaselineItem;
  AtualFim: TDateTime;
  DesvioDias: Integer;
  AtualCusto: Int64;
begin
  FBaseGrid.RowCount := Max(2, FDoc.Count + 1);
  if FDoc.Count = 0 then
  begin
    FBaseGrid.Rows[1].Clear;
    Exit;
  end;
  for I := 0 to FDoc.Count - 1 do
  begin
    FBaseGrid.Cells[0, I + 1] := FDoc[I].Id;
    FBaseGrid.Cells[1, I + 1] := FDoc[I].Nome;
    AtualCusto := FDoc.CustoTarefa(FDoc[I], False);
    if (FCrono <> nil) and FCrono.Valido and (I < FDoc.Count) then
      AtualFim := FCrono.Resultado[I].Finish
    else
      AtualFim := 0;
    if AtualFim > 0 then FBaseGrid.Cells[4, I + 1] := FormatDateTime('dd/mm/yyyy', AtualFim)
    else FBaseGrid.Cells[4, I + 1] := '—';
    if PLBuscarBaseline(FDoc, FDoc[I].Id, BItem) then
    begin
      FBaseGrid.Cells[2, I + 1] := FormatDateTime('dd/mm/yyyy', BItem.Inicio);
      FBaseGrid.Cells[3, I + 1] := FormatDateTime('dd/mm/yyyy', BItem.Termino);
      DesvioDias := Round(AtualFim - BItem.Termino);
      FBaseGrid.Cells[5, I + 1] := IntToStr(DesvioDias) + 'd';
      FBaseGrid.Cells[6, I + 1] := EAMoneyText(BItem.CustoCentavos) + ' / ' + EAMoneyText(AtualCusto);
    end
    else
    begin
      FBaseGrid.Cells[2, I + 1] := 'Sem base';
      FBaseGrid.Cells[3, I + 1] := '—';
      FBaseGrid.Cells[5, I + 1] := '—';
      FBaseGrid.Cells[6, I + 1] := '— / ' + EAMoneyText(AtualCusto);
    end;
  end;
end;

procedure TPLP3Form.FreezeBaselineClick(Sender: TObject);
begin
  try
    PLCongelarBaseline(FDoc, FCrono);
    FCurva := PLCalcularCurvaS(FDoc, FCrono);
    RefreshBaseline;
    FChart.Invalidate;
    ShowMessage('Linha de base congelada para ' + IntToStr(FDoc.Count) + ' tarefa(s).');
  except
    on E: Exception do ShowMessage(E.Message);
  end;
end;

procedure TPLP3Form.ExportCurveCSVClick(Sender: TObject);
var
  D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'CSV (*.csv)|*.csv';
    D.DefaultExt := 'csv';
    D.FileName := 'curva_s.csv';
    if D.Execute then
    begin
      PLExportarCurvaSCSV(FCurva, D.FileName);
      ShowMessage('Curva S exportada: ' + D.FileName);
    end;
  finally
    D.Free;
  end;
end;

procedure TPLP3Form.PaintCurve(Sender: TObject);
var
  C: TCanvas;
  W, H, PadL, PadR, PadT, PadB, PW, PH, I: Integer;
  X, Y: Integer;
  PtsPlan, PtsReal, PtsBase: array of TPoint;
begin
  C := FChart.Canvas;
  W := FChart.Width;
  H := FChart.Height;
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  PadL := 60; PadR := 30; PadT := 45; PadB := 45;
  PW := Max(50, W - PadL - PadR);
  PH := Max(50, H - PadT - PadB);

  C.Pen.Color := RGBToColor(148, 163, 184);
  C.Line(PadL, PadT, PadL, PadT + PH);
  C.Line(PadL, PadT + PH, PadL + PW, PadT + PH);
  C.Font.Color := RGBToColor(30, 41, 59);
  C.TextOut(PadL, 12, 'Curva S (% físico acumulado): Azul = Planejado | Verde = Realizado | Cinza = Baseline');
  C.TextOut(14, PadT, '100%');
  C.TextOut(20, PadT + PH div 2, '50%');
  C.TextOut(26, PadT + PH - 14, '0%');

  if Length(FCurva) < 2 then Exit;
  SetLength(PtsPlan, Length(FCurva));
  SetLength(PtsReal, Length(FCurva));
  SetLength(PtsBase, Length(FCurva));
  for I := 0 to High(FCurva) do
  begin
    X := PadL + Round(PW * I / (Length(FCurva) - 1));
    Y := PadT + PH - Round(PH * FCurva[I].PlanejadoPct / 100.0);
    PtsPlan[I] := Point(X, Y);
    Y := PadT + PH - Round(PH * FCurva[I].RealizadoPct / 100.0);
    PtsReal[I] := Point(X, Y);
    Y := PadT + PH - Round(PH * FCurva[I].BaselinePct / 100.0);
    PtsBase[I] := Point(X, Y);
  end;
  if Length(FDoc.Baseline) > 0 then
  begin
    C.Pen.Color := RGBToColor(100, 116, 139); C.Pen.Width := 2;
    C.Polyline(PtsBase);
  end;
  C.Pen.Color := RGBToColor(37, 99, 235); C.Pen.Width := 3;
  C.Polyline(PtsPlan);
  C.Pen.Color := RGBToColor(22, 163, 74); C.Pen.Width := 3;
  C.Polyline(PtsReal);
  C.Pen.Width := 1;
end;

procedure TPLP3Form.RefreshCalendar;
var
  FirstDay, CurDate: TDateTime;
  StartCol, DaysInM, R, C, DayNum, I: Integer;
  CellText: string;
begin
  FMonthLabel.Caption := FormatDateTime('mmmm "de" yyyy', EncodeDate(FCalYear, FCalMonth, 1));
  for R := 1 to 6 do
    for C := 0 to 6 do
      FCalGrid.Cells[C, R] := '';
  FirstDay := EncodeDate(FCalYear, FCalMonth, 1);
  StartCol := DayOfWeek(FirstDay) - 1; // 0 = Dom
  DaysInM := DaysInAMonth(FCalYear, FCalMonth);
  R := 1; C := StartCol;
  for DayNum := 1 to DaysInM do
  begin
    CurDate := EncodeDate(FCalYear, FCalMonth, DayNum);
    CellText := IntToStr(DayNum);
    if (FCrono <> nil) and FCrono.Valido then
    begin
      for I := 0 to FDoc.Count - 1 do
      begin
        if (I < FDoc.Count) and
           (Trunc(CurDate) >= Trunc(FCrono.Resultado[I].Start)) and
           (Trunc(CurDate) <= Trunc(FCrono.Resultado[I].Finish)) then
          CellText := CellText + LineEnding + FDoc[I].Id + ' ' + Copy(FDoc[I].Nome, 1, 14);
      end;
    end;
    FCalGrid.Cells[C, R] := CellText;
    Inc(C);
    if C > 6 then begin C := 0; Inc(R); if R > 6 then Break; end;
  end;
end;

procedure TPLP3Form.PrevMonthClick(Sender: TObject);
begin
  if FCalMonth = 1 then begin FCalMonth := 12; Dec(FCalYear); end else Dec(FCalMonth);
  RefreshCalendar;
end;

procedure TPLP3Form.NextMonthClick(Sender: TObject);
begin
  if FCalMonth = 12 then begin FCalMonth := 1; Inc(FCalYear); end else Inc(FCalMonth);
  RefreshCalendar;
end;

procedure PLAbrirDialogoAcompanhamentoP3(Owner: TForm; Doc: TPLProjeto; Crono: TPLCronograma);
var
  F: TPLP3Form;
begin
  F := TPLP3Form.CreateP3(Owner, Doc, Crono);
  try
    F.ShowModal;
  finally
    F.Free;
  end;
end;

function PLEditarObjetoTexturaP4(Owner: TForm; Doc: TPLProjeto; T: TPLTarefa): Boolean;
var
  F: TForm;
  ObjEd, TexEd, FaceEd: TEdit;
  DestCb: TComboBox;
  B: TButton;
  L: TLabel;
begin
  Result := False;
  if T = nil then Exit;
  F := TForm.CreateNew(Owner);
  try
    F.Caption := 'P4 — Vincular Objeto e Textura (' + T.Id + ')';
    F.SetBounds(0, 0, 480, 320);
    F.Position := poScreenCenter;
    F.BorderStyle := bsDialog;
    L := TLabel.Create(F); L.Parent := F; L.SetBounds(16, 16, 440, 22); L.Caption := 'ID do Objeto na Maquete 3D (object_id):';
    ObjEd := TEdit.Create(F); ObjEd.Parent := F; ObjEd.SetBounds(16, 40, 440, 28); ObjEd.Text := T.ObjetoId;
    L := TLabel.Create(F); L.Parent := F; L.SetBounds(16, 78, 440, 22); L.Caption := 'ID da Textura / Skin (textura_id):';
    TexEd := TEdit.Create(F); TexEd.Parent := F; TexEd.SetBounds(16, 102, 440, 28);
    if Length(T.Texturas) > 0 then TexEd.Text := T.Texturas[High(T.Texturas)].TexturaId;
    L := TLabel.Create(F); L.Parent := F; L.SetBounds(16, 140, 200, 22); L.Caption := 'Destino:';
    DestCb := TComboBox.Create(F); DestCb.Parent := F; DestCb.SetBounds(16, 164, 200, 28);
    DestCb.Style := csDropDownList; DestCb.Items.Add('objeto'); DestCb.Items.Add('face'); DestCb.ItemIndex := 0;
    L := TLabel.Create(F); L.Parent := F; L.SetBounds(236, 140, 220, 22); L.Caption := 'ID da Face (se destino = face):';
    FaceEd := TEdit.Create(F); FaceEd.Parent := F; FaceEd.SetBounds(236, 164, 220, 28);
    B := TButton.Create(F); B.Parent := F; B.SetBounds(240, 250, 100, 34); B.Caption := 'Vincular'; B.ModalResult := mrOK; B.Default := True;
    B := TButton.Create(F); B.Parent := F; B.SetBounds(356, 250, 100, 34); B.Caption := 'Cancelar'; B.ModalResult := mrCancel; B.Cancel := True;
    while F.ShowModal = mrOK do
    begin
      try
        PLVincularObjetoTextura(Doc, T, ObjEd.Text, TexEd.Text, DestCb.Text, FaceEd.Text, '1.0');
        Result := True;
        Break;
      except
        on E: Exception do ShowMessage(E.Message);
      end;
    end;
  finally
    F.Free;
  end;
end;

end.
