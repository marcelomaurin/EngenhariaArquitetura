unit ea_undo;

{ Núcleo Comum - Adaptador reutilizável de histórico Desfazer/Refazer
  sobre TAIUndoHistory (AIProjectCore da suíte CHATGPT). Sem dependência LCL. }

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, aiundohistory;

type
  TEASnapshotGet = function: string of object;
  TEASnapshotSet = procedure(const S: string) of object;

  TEASnapshotUndo = class
  private
    FHistory: TAIUndoHistory;
    FGetSnap: TEASnapshotGet;
    FSetSnap: TEASnapshotSet;
  public
    constructor Create(AGetSnap: TEASnapshotGet; ASetSnap: TEASnapshotSet; ALimit: Integer = 80);
    destructor Destroy; override;
    procedure RecordBefore(const Desc: string);
    function Undo: Boolean;
    function Redo: Boolean;
    function CanUndo: Boolean;
    function CanRedo: Boolean;
    procedure Clear;
    property History: TAIUndoHistory read FHistory;
  end;

implementation

constructor TEASnapshotUndo.Create(AGetSnap: TEASnapshotGet; ASetSnap: TEASnapshotSet; ALimit: Integer);
begin
  inherited Create;
  FHistory := TAIUndoHistory.Create(ALimit);
  FGetSnap := AGetSnap;
  FSetSnap := ASetSnap;
end;

destructor TEASnapshotUndo.Destroy;
begin
  FHistory.Free;
  inherited Destroy;
end;

procedure TEASnapshotUndo.RecordBefore(const Desc: string);
begin
  if not Assigned(FGetSnap) then Exit;
  if FHistory.BeginChange(Desc, FGetSnap()) then
    FHistory.EndChange;
end;

function TEASnapshotUndo.Undo: Boolean;
var
  Snap: string;
begin
  Result := False;
  if (not FHistory.CanUndo) or (not Assigned(FGetSnap)) or (not Assigned(FSetSnap)) then Exit;
  FHistory.Suspend;
  try
    Snap := FHistory.Undo(FGetSnap());
    FSetSnap(Snap);
    Result := True;
  finally
    FHistory.Resume;
  end;
end;

function TEASnapshotUndo.Redo: Boolean;
var
  Snap: string;
begin
  Result := False;
  if (not FHistory.CanRedo) or (not Assigned(FGetSnap)) or (not Assigned(FSetSnap)) then Exit;
  FHistory.Suspend;
  try
    Snap := FHistory.Redo(FGetSnap());
    FSetSnap(Snap);
    Result := True;
  finally
    FHistory.Resume;
  end;
end;

function TEASnapshotUndo.CanUndo: Boolean;
begin
  Result := FHistory.CanUndo;
end;

function TEASnapshotUndo.CanRedo: Boolean;
begin
  Result := FHistory.CanRedo;
end;

procedure TEASnapshotUndo.Clear;
begin
  FHistory.Clear;
end;

end.
