procedure TCADMainForm.ExportProject(const FileName: string; AsSVG: Boolean);
var L:TStringList; I,J,MinX,MinY,MaxX,MaxY:Integer; Symbol:TCADPoints; E:TCADLine;
    C,D:TPoint; Len,DX,DY,Offset:Double; InkColor,Layer,Weight:string;
  function Num(V:Double):string;
  var F:TFormatSettings;
  begin F:=DefaultFormatSettings; F.DecimalSeparator:='.'; Result:=FloatToStr(V,F); end;
  function Esc(const V:string):string;
  begin
    Result:=StringReplace(V,'&','&amp;',[rfReplaceAll]);
    Result:=StringReplace(Result,'<','&lt;',[rfReplaceAll]);
    Result:=StringReplace(Result,'>','&gt;',[rfReplaceAll]);
    Result:=StringReplace(Result,'"','&quot;',[rfReplaceAll]);
  end;
  procedure Pair(Code:Integer; const Value:string);
  begin L.Add(IntToStr(Code)); L.Add(Value); end;
  procedure Style;
  begin Pair(100,'AcDbEntity'); Pair(8,Layer); Pair(420,IntToStr(StrToInt('$'+Copy(InkColor,2,6)))); end;
  procedure EmitLine(A,B:TPoint);
  begin
    if AsSVG then L.Add('<line x1="'+Num(A.X*FMillimetersPerPixel)+'" y1="'+Num(A.Y*FMillimetersPerPixel)+
      '" x2="'+Num(B.X*FMillimetersPerPixel)+'" y2="'+Num(B.Y*FMillimetersPerPixel)+'" stroke="'+InkColor+'" stroke-width="'+Weight+'"/>')
    else begin
      Pair(0,'LINE'); Style; Pair(100,'AcDbLine'); Pair(10,Num(A.X*FMillimetersPerPixel)); Pair(20,Num(-A.Y*FMillimetersPerPixel)); Pair(30,'0');
      Pair(11,Num(B.X*FMillimetersPerPixel)); Pair(21,Num(-B.Y*FMillimetersPerPixel)); Pair(31,'0');
    end;
  end;
  procedure EmitText(P:TPoint; const Value:string; Height,Angle:Double);
  begin
    if AsSVG then L.Add('<text x="'+Num(P.X*FMillimetersPerPixel)+'" y="'+Num(P.Y*FMillimetersPerPixel)+
      '" font-family="sans-serif" font-size="'+Num(Height)+'" fill="'+InkColor+'" transform="rotate('+Num(Angle)+' '+
      Num(P.X*FMillimetersPerPixel)+' '+Num(P.Y*FMillimetersPerPixel)+')">'+Esc(Value)+'</text>')
    else begin
      Pair(0,'TEXT'); Style; Pair(100,'AcDbText'); Pair(10,Num(P.X*FMillimetersPerPixel)); Pair(20,Num(-P.Y*FMillimetersPerPixel)); Pair(30,'0');
      Pair(40,Num(Height)); Pair(1,Value); Pair(50,Num(-Angle)); Pair(100,'AcDbText');
    end;
  end;
begin
  L:=TStringList.Create;
  try
    MinX:=0; MinY:=0; MaxX:=100; MaxY:=100;
    for I:=0 to High(FLines) do begin
      E:=FLines[I]; Offset:=Abs(E.WidthMM/FMillimetersPerPixel)+20;
      MinX:=Min(MinX,Min(E.A.X,E.B.X)-Ceil(Offset)); MinY:=Min(MinY,Min(E.A.Y,E.B.Y)-Ceil(Offset));
      MaxX:=Max(MaxX,Max(E.A.X,E.B.X)+Ceil(Offset)); MaxY:=Max(MaxY,Max(E.A.Y,E.B.Y)+Ceil(Offset));
    end;
    if AsSVG then L.Add('<svg xmlns="http://www.w3.org/2000/svg" viewBox="'+Num(MinX*FMillimetersPerPixel)+' '+Num(MinY*FMillimetersPerPixel)+' '+
      Num((MaxX-MinX)*FMillimetersPerPixel)+' '+Num((MaxY-MinY)*FMillimetersPerPixel)+'">')
    else begin
      Pair(0,'SECTION'); Pair(2,'HEADER'); Pair(9,'$ACADVER'); Pair(1,'AC1021');
      Pair(9,'$INSUNITS'); Pair(70,'4'); Pair(0,'ENDSEC'); Pair(0,'SECTION'); Pair(2,'ENTITIES');
    end;
    for I:=0 to High(FLines) do begin
      E:=FLines[I];
      case E.Layer of 1: begin Layer:='ESTRUTURA'; InkColor:='#B45309'; end;
        2: begin Layer:='INSTALACOES'; InkColor:='#059669'; end;
      else Layer:='ARQUITETURA'; InkColor:='#2563EB'; end;
      if E.Ink<>0 then InkColor:='#'+IntToHex(E.Ink,6);
      Weight:=IntToStr(Max(10,E.Weight)); if E.Kind=2 then Weight:=IntToStr(Max(10,E.WidthMM));
      if E.Kind=5 then EmitText(E.A,E.Content,Max(50,E.WidthMM),RadToDeg(ArcTan2(E.B.Y-E.A.Y,E.B.X-E.A.X)))
      else if E.Kind=6 then begin
        DX:=E.B.X-E.A.X; DY:=E.B.Y-E.A.Y; Len:=Hypot(DX,DY);
        if Len<=0 then Continue;
        Offset:=E.WidthMM/FMillimetersPerPixel;
        C:=Point(E.A.X-Round(DY/Len*Offset),E.A.Y+Round(DX/Len*Offset));
        D:=Point(E.B.X-Round(DY/Len*Offset),E.B.Y+Round(DX/Len*Offset));
        EmitLine(E.A,C); EmitLine(E.B,D); EmitLine(C,D);
        EmitLine(Point(C.X-3,C.Y+3),Point(C.X+3,C.Y-3)); EmitLine(Point(D.X-3,D.Y+3),Point(D.X+3,D.Y-3));
        EmitText(Point((C.X+D.X) div 2,(C.Y+D.Y) div 2-4),FormatFloat('0.00',Len*FMillimetersPerPixel/1000)+' m',250,0);
      end else if E.Kind in [3,4] then begin
        Symbol:=PlanSymbol(E);
        for J:=0 to Length(Symbol) div 2-1 do EmitLine(Symbol[J*2],Symbol[J*2+1]);
      end else EmitLine(E.A,E.B);
    end;
    if AsSVG then L.Add('</svg>') else begin Pair(0,'ENDSEC'); Pair(0,'EOF'); end;
    L.SaveToFile(FileName);
  finally L.Free; end;
end;

procedure TCADMainForm.StretchWindow(const Bounds:TRect; DX,DY:Integer);
var I:Integer; E:TCADLine;
  function Inside(P:TPoint):Boolean;
  begin Result:=(P.X>=Bounds.Left) and (P.X<=Bounds.Right) and (P.Y>=Bounds.Top) and (P.Y<=Bounds.Bottom); end;
begin
  if (Abs(Int64(DX))>10000000) or (Abs(Int64(DY))>10000000) then raise Exception.Create('Deslocamento fora do limite');
  RecordChange;
  try
  for I:=0 to High(FLines) do begin
    if Inside(FLines[I].A) then begin Inc(FLines[I].A.X,Round(DX/FMillimetersPerPixel)); Dec(FLines[I].A.Y,Round(DY/FMillimetersPerPixel)); end;
    if Inside(FLines[I].B) then begin Inc(FLines[I].B.X,Round(DX/FMillimetersPerPixel)); Dec(FLines[I].B.Y,Round(DY/FMillimetersPerPixel)); end;
  end;
  for I:=0 to High(FLines) do E:=ReadEntity(EntityRow(FLines[I]),4,I);
  except RestoreSnapshot(FHistoryUndo[FHistoryUndo.Count-1]); FHistoryUndo.Delete(FHistoryUndo.Count-1); raise; end;
  FCanvas.Invalidate; RefreshStatus('Vértices dentro da janela deslocados');
end;
