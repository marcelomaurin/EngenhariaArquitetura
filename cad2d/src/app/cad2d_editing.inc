function PlanSymbol(const E:TCADLine):TCADPoints;
var DX,DY,Len,Offset,Angle:Double; I,N:Integer; P,Q:TPoint;
  procedure Seg(A,B:TPoint);
  begin N:=Length(Result); SetLength(Result,N+2); Result[N]:=A; Result[N+1]:=B; end;
begin
  Result:=nil; DX:=E.B.X-E.A.X; DY:=E.B.Y-E.A.Y; Len:=Hypot(DX,DY);
  if Len=0 then Exit;
  if E.Kind=3 then begin
    Q:=Point(E.A.X-Round(DY),E.A.Y+Round(DX)); Seg(E.A,Q);
    P:=E.B;
    for I:=1 to 16 do begin
      Angle:=I*Pi/32; Q:=Point(E.A.X+Round(DX*Cos(Angle)-DY*Sin(Angle)),E.A.Y+Round(DX*Sin(Angle)+DY*Cos(Angle)));
      Seg(P,Q); P:=Q;
    end;
  end else begin
    for I:=-1 to 1 do begin
      Offset:=I*2; P:=Point(E.A.X-Round(DY/Len*Offset),E.A.Y+Round(DX/Len*Offset));
      Q:=Point(E.B.X-Round(DY/Len*Offset),E.B.Y+Round(DX/Len*Offset)); Seg(P,Q);
    end;
  end;
end;

function EncodeText(const S: string): string;
var I: Integer;
begin Result := ''; for I:=1 to Length(S) do Result:=Result+IntToHex(Ord(S[I]),2); end;
function DecodeText(const S: string): string;
var I: Integer;
begin
  if Odd(Length(S)) then raise Exception.Create('Texto inválido');
  Result:=''; for I:=1 to Length(S) div 2 do Result:=Result+Chr(StrToInt('$'+Copy(S,I*2-1,2)));
end;
function EntityRow(const E: TCADLine): string;
begin
  Result:=Format('%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%s',
    [E.A.X,E.A.Y,E.B.X,E.B.Y,E.Layer,E.Kind,E.WidthMM,E.GroupID,E.Ink,E.Weight,EncodeText(E.Content)]);
end;
function ReadEntity(const S: string; Version: Integer; Index: Integer): TCADLine;
var V: TStringList; Count: Integer;
begin
  Result:=Default(TCADLine); V:=TStringList.Create;
  try
    V.StrictDelimiter:=True; V.Delimiter:=';'; V.DelimitedText:=S;
    case Version of 1: Count:=6; 2: Count:=7; 3: Count:=8; else Count:=11; end;
    if V.Count<>Count then raise Exception.Create('Campos inválidos no projeto');
    Result.A:=Point(StrToInt(V[0]),StrToInt(V[1]));
    Result.B:=Point(StrToInt(V[2]),StrToInt(V[3]));
    Result.Layer:=StrToInt(V[4]); Result.Kind:=StrToInt(V[5]);
    if Version>1 then Result.WidthMM:=StrToInt(V[6]);
    if Version=1 then case Result.Kind of 2: Result.WidthMM:=150; 3: Result.WidthMM:=900; 4: Result.WidthMM:=1200; end;
    Result.GroupID:=Index+1;
    if Version>2 then Result.GroupID:=StrToInt(V[7]);
    if Version>3 then begin Result.Ink:=StrToInt(V[8]); Result.Weight:=StrToInt(V[9]); Result.Content:=DecodeText(V[10]); end;
    if (Result.Layer<0) or (Result.Layer>2) or (Result.Kind<0) or (Result.Kind>6) or
      (Result.GroupID<1) or (Result.GroupID>100000000) or
      (Abs(Int64(Result.A.X))>10000000) or (Abs(Int64(Result.A.Y))>10000000) or
      (Abs(Int64(Result.B.X))>10000000) or (Abs(Int64(Result.B.Y))>10000000) or
      (Abs(Int64(Result.WidthMM))>10000000) or (Result.Weight<0) or (Result.Weight>10000) or
      (Result.Ink<0) or (Result.Ink>$FFFFFF) then raise Exception.Create('Propriedade fora do limite');
  finally V.Free; end;
end;

procedure TCADMainForm.SaveProject(const FileName: string);
var L: TStringList; I: Integer;
begin
  L:=TStringList.Create;
  try
    L.Add('EACAD4'); L.Add(IntToStr(FMillimetersPerPixel));
    for I:=0 to High(FLines) do L.Add(EntityRow(FLines[I]));
    L.SaveToFile(FileName); FPath:=FileName;
  finally L.Free; end;
end;
procedure TCADMainForm.LoadProject(const FileName: string);
var L: TStringList; Temp: array of TCADLine; I,V,Scale,G: Integer;
begin
  L:=TStringList.Create;
  try
    L.LoadFromFile(FileName);
    if (L.Count<2) or (L.Count>200002) then raise Exception.Create('Projeto inválido');
    if (Copy(L[0],1,5)<>'EACAD') or not TryStrToInt(Copy(L[0],6,1),V) or
      (Length(L[0])<>6) or (V<1) or (V>4) then raise Exception.Create('Versão não suportada');
    Scale:=StrToInt(L[1]); if (Scale<1) or (Scale>100000) then raise Exception.Create('Escala inválida');
    SetLength(Temp,L.Count-2); G:=0;
    for I:=0 to High(Temp) do begin Temp[I]:=ReadEntity(L[I+2],V,I); G:=Max(G,Temp[I].GroupID); end;
    FLines:=Temp; FMillimetersPerPixel:=Scale; FNextGroup:=G+1;
    FSelected:=-1; SetLength(FPicked,0); FHistoryUndo.Clear; FHistoryRedo.Clear;
    FHasStart:=False; FArcStage:=0; FPath:=FileName;
    FCanvas.Invalidate; RefreshStatus('Projeto aberto');
  finally L.Free; end;
end;

function TCADMainForm.IsPicked(Index: Integer): Boolean;
var J,K: Integer;
begin
  Result:=False;
  if (Index<0) or (Index>=Length(FLines)) then Exit;
  if Length(FPicked)=0 then begin
    Result:=(FSelected>=0) and (FSelected<Length(FLines));
    if Result then Result:=FLines[Index].GroupID=FLines[FSelected].GroupID;
    Exit;
  end;
  for J:=0 to High(FPicked) do begin
    K:=FPicked[J];
    if (K>=0) and (K<Length(FLines)) and (FLines[K].GroupID=FLines[Index].GroupID) then Exit(True);
  end;
end;

procedure TCADMainForm.EditSelection(Mode: Integer; X,Y: Double; Rows: Integer=1; Cols: Integer=1);
var I,J,K,N,G,OldN: Integer; Base: TPoint; E: TCADLine; Mask: array of Boolean;
  function Transform(P: TPoint): TPoint;
  var DX,DY: Double;
  begin
    Result:=P; DX:=P.X-Base.X; DY:=P.Y-Base.Y;
    case Mode of
      0,1,4: Result:=Point(P.X+Round(X/FMillimetersPerPixel),P.Y-Round(Y/FMillimetersPerPixel));
      2: Result:=Point(Base.X+Round(DX*Cos(DegToRad(X))-DY*Sin(DegToRad(X))),Base.Y+Round(DX*Sin(DegToRad(X))+DY*Cos(DegToRad(X))));
      3: Result:=Point(Base.X+Round(DX*X),Base.Y+Round(DY*X));
      5: Result.Y:=2*Base.Y-P.Y;
      6: Result.X:=2*Base.X-P.X;
    end;
    if (Abs(Int64(Result.X))>10000000) or (Abs(Int64(Result.Y))>10000000) then raise Exception.Create('Resultado fora dos limites');
  end;
begin
  if (FSelected<0) or (FSelected>=Length(FLines)) then raise Exception.Create('Selecione objetos primeiro (Ctrl+clique para adicionar).');
  if IsNan(X) or IsNan(Y) or IsInfinite(X) or IsInfinite(Y) or (Abs(X)>10000000) or (Abs(Y)>10000000) then raise Exception.Create('Valor inválido');
  if (Mode=3) and ((X<=0) or (X>1000)) then raise Exception.Create('Escala deve estar entre 0 e 1000');
  if (Rows<1) or (Cols<1) or (Rows>100) or (Cols>100) then raise Exception.Create('Array limitado a 100 linhas/colunas');
  OldN:=Length(FLines); if Int64(OldN)*Rows*Cols>200000 then raise Exception.Create('Array excede 200000 entidades');
  Base:=FLines[FSelected].A; SetLength(Mask,OldN);
  for I:=0 to OldN-1 do Mask[I]:=IsPicked(I);
  RecordChange;
  try
    if Mode in [7,8] then begin
      G:=FNextGroup; Inc(FNextGroup);
      for I:=0 to OldN-1 do if Mask[I] then begin
        FLines[I].GroupID:=G;
        if Mode=8 then begin G:=FNextGroup; Inc(FNextGroup); end;
      end;
    end else if Mode=9 then begin
      for J:=0 to Rows-1 do for K:=0 to Cols-1 do if (J<>0) or (K<>0) then begin
        G:=FNextGroup; Inc(FNextGroup);
        for I:=0 to OldN-1 do if Mask[I] then begin
          E:=FLines[I]; Inc(E.A.X,Round(K*X/FMillimetersPerPixel)); Inc(E.B.X,Round(K*X/FMillimetersPerPixel));
          Dec(E.A.Y,Round(J*Y/FMillimetersPerPixel)); Dec(E.B.Y,Round(J*Y/FMillimetersPerPixel)); E.GroupID:=G;
          N:=Length(FLines); SetLength(FLines,N+1); FLines[N]:=E;
        end;
      end;
    end else begin
      G:=FNextGroup; if Mode=1 then Inc(FNextGroup);
      for I:=0 to OldN-1 do if Mask[I] then begin
        E:=FLines[I];
        if Mode<>4 then E.A:=Transform(E.A);
        E.B:=Transform(E.B);
        if Mode=3 then E.WidthMM:=Round(E.WidthMM*X);
        if Mode=1 then begin E.GroupID:=G; N:=Length(FLines); SetLength(FLines,N+1); FLines[N]:=E; end
        else FLines[I]:=E;
      end;
    end;
    for I:=0 to High(FLines) do E:=ReadEntity(EntityRow(FLines[I]),4,I);
  except
    RestoreSnapshot(FHistoryUndo[FHistoryUndo.Count-1]); FHistoryUndo.Delete(FHistoryUndo.Count-1); raise;
  end;
  SetLength(FPicked,0); FCanvas.Invalidate; RefreshStatus('Seleção atualizada');
end;

procedure TCADMainForm.AdvancedEdit(Sender: TObject);
var Mode,Rows,Cols: Integer; X,Y: Double; S: string;
  function Ask(const Prompt: string; var Value: Double): Boolean;
  begin
    S:=FloatToStr(Value); Result:=InputQuery('Modificar seleção',Prompt,S);
    if Result and not TryStrToFloat(S,Value) then raise Exception.Create('Número inválido');
  end;
begin
  try
    Mode:=TControl(Sender).Tag; X:=0; Y:=0; Rows:=1; Cols:=1;
    if Mode in [0,1,4,9] then begin
      X:=1000;
      if not Ask('Deslocamento / espaçamento X (mm):',X) then Exit;
      if not Ask('Deslocamento / espaçamento Y (mm, positivo para cima):',Y) then Exit;
    end;
    if Mode=2 then begin X:=90; if not Ask('Ângulo horário (graus), base no início da entidade:',X) then Exit; end;
    if Mode=3 then begin X:=2; if not Ask('Fator de escala, base no início da entidade:',X) then Exit; end;
    if Mode=9 then begin
      S:='2'; if not InputQuery('Array retangular','Colunas (inclui original):',S) then Exit; Cols:=StrToInt(S);
      S:='2'; if not InputQuery('Array retangular','Linhas (inclui original):',S) then Exit; Rows:=StrToInt(S);
    end;
    EditSelection(Mode,X,Y,Rows,Cols);
  except on E:Exception do ShowMessage(E.Message); end;
end;

procedure TCADMainForm.UpdatePropertyEditor;
var E: TCADLine;
begin
  if not Assigned(FPropertyEditor) then Exit;
  FPropertyEditor.Strings.Clear;
  if (FSelected<0) or (FSelected>=Length(FLines)) then Exit;
  E:=FLines[FSelected];
  FPropertyEditor.Values['Camada (0 a 2)']:=IntToStr(E.Layer);
  FPropertyEditor.Values['X inicial mm']:=IntToStr(E.A.X*FMillimetersPerPixel);
  FPropertyEditor.Values['Y inicial mm']:=IntToStr(-E.A.Y*FMillimetersPerPixel);
  FPropertyEditor.Values['X final mm']:=IntToStr(E.B.X*FMillimetersPerPixel);
  FPropertyEditor.Values['Y final mm']:=IntToStr(-E.B.Y*FMillimetersPerPixel);
  FPropertyEditor.Values['Dimensão mm']:=IntToStr(E.WidthMM);
  FPropertyEditor.Values['Cor RGB hex']:=IntToHex(E.Ink,6);
  FPropertyEditor.Values['Traço mm (0 auto)']:=IntToStr(E.Weight);
  FPropertyEditor.Values['Texto']:=E.Content;
end;
procedure TCADMainForm.ApplyProperties(Sender: TObject);
var E: TCADLine;
  function Value(const Key: string): Integer;
  begin Result:=StrToInt(FPropertyEditor.Values[Key]); if Abs(Int64(Result))>10000000 then raise Exception.Create('Valor fora do limite'); end;
begin
  if (FSelected<0) or (FSelected>=Length(FLines)) then Exit;
  try
    E:=FLines[FSelected];
    E.Layer:=Value('Camada (0 a 2)');
    E.A:=Point(Round(Value('X inicial mm')/FMillimetersPerPixel),-Round(Value('Y inicial mm')/FMillimetersPerPixel));
    E.B:=Point(Round(Value('X final mm')/FMillimetersPerPixel),-Round(Value('Y final mm')/FMillimetersPerPixel));
    E.WidthMM:=Value('Dimensão mm'); E.Weight:=Value('Traço mm (0 auto)');
    E.Ink:=StrToInt('$'+FPropertyEditor.Values['Cor RGB hex']); E.Content:=FPropertyEditor.Values['Texto'];
    E:=ReadEntity(EntityRow(E),4,FSelected);
    if (E.Kind=5) and (E.WidthMM<50) then raise Exception.Create('Altura de texto mínima: 50 mm');
    RecordChange; FLines[FSelected]:=E;
    FCanvas.Invalidate; RefreshStatus('Propriedades aplicadas à entidade');
  except on Ex:Exception do ShowMessage(Ex.Message); end;
end;

procedure TCADMainForm.AddArc(const Center, StartPoint, EndPoint: TPoint);
var R,A,Z,T: Double; I,Steps: Integer; P,Q: TPoint;
begin
  R:=Hypot(StartPoint.X-Center.X,StartPoint.Y-Center.Y); if R<1 then Exit;
  A:=ArcTan2(StartPoint.Y-Center.Y,StartPoint.X-Center.X);
  Z:=ArcTan2(EndPoint.Y-Center.Y,EndPoint.X-Center.X); while Z<=A do Z:=Z+2*Pi;
  Steps:=Max(2,Ceil((Z-A)*24)); P:=StartPoint;
  for I:=1 to Steps do begin T:=A+(Z-A)*I/Steps; Q:=Point(Center.X+Round(R*Cos(T)),Center.Y+Round(R*Sin(T)));
    AddSegment(P,Q); P:=Q;
  end;
end;

procedure TCADMainForm.AddAnnotation(const A,B: TPoint; const AText: string; Dimension: Boolean);
var N: Integer;
begin
  N:=Length(FLines); SetLength(FLines,N+1); FLines[N]:=Default(TCADLine);
  FLines[N].A:=A; FLines[N].B:=B; FLines[N].GroupID:=FNextGroup;
  FLines[N].Layer:=FLayerSelect.ItemIndex; FLines[N].Content:=AText;
  if Dimension then begin FLines[N].Kind:=6; FLines[N].WidthMM:=500; end
  else begin FLines[N].Kind:=5; FLines[N].WidthMM:=250; end;
end;

procedure TCADMainForm.PaintAnnotation(const E: TCADLine);
var A,B,C,D: TPoint; DX,DY,Len,Offset: Double; AText: string;
  function Screen(P:TPoint):TPoint;
  begin Result:=Point(Round(P.X*FZoom)+FPanX,Round(P.Y*FZoom)+FPanY); end;
begin
  A:=Screen(E.A); B:=Screen(E.B);
  FCanvas.Canvas.Brush.Style:=bsClear;
  FCanvas.Canvas.Font.Color:=FCanvas.Canvas.Pen.Color;
  if E.Kind=5 then begin
    FCanvas.Canvas.Font.Height:=Max(8,Round(E.WidthMM*FZoom/FMillimetersPerPixel));
    FCanvas.Canvas.Font.Orientation:=-Round(RadToDeg(ArcTan2(E.B.Y-E.A.Y,E.B.X-E.A.X))*10);
    FCanvas.Canvas.TextOut(A.X,A.Y,E.Content); FCanvas.Canvas.Font.Orientation:=0;
  end else begin
    DX:=E.B.X-E.A.X; DY:=E.B.Y-E.A.Y; Len:=Hypot(DX,DY);
    if Len>0 then begin
      Offset:=E.WidthMM*FZoom/FMillimetersPerPixel;
      C:=Point(A.X-Round(DY/Len*Offset),A.Y+Round(DX/Len*Offset));
      D:=Point(B.X-Round(DY/Len*Offset),B.Y+Round(DX/Len*Offset));
      FCanvas.Canvas.Line(A,C); FCanvas.Canvas.Line(B,D); FCanvas.Canvas.Line(C,D);
      FCanvas.Canvas.Line(C.X-4,C.Y+4,C.X+4,C.Y-4); FCanvas.Canvas.Line(D.X-4,D.Y+4,D.X+4,D.Y-4);
      FCanvas.Canvas.Font.Height:=13;
      AText:=FormatFloat('0.00',Len*FMillimetersPerPixel/1000)+' m';
      FCanvas.Canvas.TextOut((C.X+D.X-FCanvas.Canvas.TextWidth(AText)) div 2,(C.Y+D.Y) div 2-18,AText);
    end;
  end;
  FCanvas.Canvas.Font.Height:=13; FCanvas.Canvas.Brush.Style:=bsSolid;
end;

procedure TCADMainForm.AddPlanComponent(Tool: Integer; const A,B: TPoint);
var I,X,Y,W,H,Count: Integer; P,Q:TPoint; Angle:Double;
  procedure Seg(X1,Y1,X2,Y2: Integer);
  begin AddSegment(Point(X1,Y1),Point(X2,Y2)); end;
  procedure Box(X1,Y1,X2,Y2: Integer);
  begin Seg(X1,Y1,X2,Y1); Seg(X2,Y1,X2,Y2); Seg(X2,Y2,X1,Y2); Seg(X1,Y2,X1,Y1); end;
begin
  X:=Min(A.X,B.X); Y:=Min(A.Y,B.Y); W:=Abs(B.X-A.X); H:=Abs(B.Y-A.Y);
  if (W<2) or (H<2) then Exit;
  if Tool in [18,19] then begin
    if Tool=18 then Count:=64 else Count:=6;
    P:=Point(X+W,Y+H div 2);
    for I:=1 to Count do begin
      Angle:=I*2*Pi/Count; Q:=Point(X+W div 2+Round(W/2*Cos(Angle)),Y+H div 2+Round(H/2*Sin(Angle)));
      AddSegment(P,Q); P:=Q;
    end; Exit;
  end;
  Box(X,Y,X+W,Y+H);
  case Tool of
    12: begin for I:=1 to 9 do Seg(X,Y+H*I div 10,X+W,Y+H*I div 10); Seg(X+W div 2,Y+H,X+W div 2,Y); end;
    13: begin Seg(X,Y,X+W,Y+H); Seg(X+W,Y,X,Y+H); end;
    14: begin Box(X+W div 10,Y+H div 10,X+W*9 div 10,Y+H div 3); end;
    15: begin Box(X+W div 10,Y+H div 5,X+W*9 div 10,Y+H*4 div 5); Seg(X+W div 2,Y+H div 5,X+W div 2,Y+H*4 div 5); end;
    16,23: begin Box(X+W div 5,Y+H div 5,X+W*4 div 5,Y+H*4 div 5); end;
    20: begin for I:=1 to 10 do Seg(X,Y+H*I div 10,X+W*I div 10,Y); for I:=1 to 9 do Seg(X+W*I div 10,Y+H,X+W,Y+H*I div 10); end;
    21: begin Seg(X,Y+H div 2,X+W,Y+H div 2); end;
    22: begin Box(X,Y,X+W,Y+H div 3); Box(X+W div 4,Y+H div 3,X+W*3 div 4,Y+H*4 div 5); end;
  end;
end;
