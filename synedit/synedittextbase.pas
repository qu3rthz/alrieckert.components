{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

Alternatively, the contents of this file may be used under the terms of the
GNU General Public License Version 2 or later (the "GPL"), in which case
the provisions of the GPL are applicable instead of those above.
If you wish to allow use of your version of this file only under the terms
of the GPL and not to allow others to use your version of this file
under the MPL, indicate your decision by deleting the provisions above and
replace them with the notice and other provisions required by the GPL.
If you do not delete the provisions above, a recipient may use your version
of this file under either the MPL or the GPL.

-------------------------------------------------------------------------------}
unit SynEditTextBase;

{$I synedit.inc}

interface

uses
  Classes, SysUtils, LCLProc, SynEditMiscProcs, SynEditKeyCmds;

type
  TSynEditStrings = class;

  TStringListLineCountEvent = procedure(Sender: TSynEditStrings;
                                        Index, Count: Integer) of object;
  TSynEditNotifyReason = (senrLineCount, senrLineChange, senrEditAction);

  TStringListLineEditEvent = procedure(Sender: TSynEditStrings;
                                       LinePos, BytePos, Count, LineBrkCnt: Integer;
                                       Text: String) of object;

  TPhysicalCharWidths = Array of Shortint;

  TSynEditUndoList = class;
  TSynEditUndoItem = class;

type


  { TSynEditStorageMem }

  TSynEditStorageMem = class
  private
    FMem: PByte;
    FCount, FCapacity: Integer;
    function GetItemPointer(Index: Integer): Pointer;
  protected
    procedure SetCapacity(const AValue: Integer); virtual;
    procedure SetCount(const AValue: Integer); virtual;
    function ItemSize: Integer; virtual; abstract;

    property Mem: PByte read FMem;
    property ItemPointer[Index: Integer]: Pointer read GetItemPointer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Move(AFrom, ATo, ALen: Integer); virtual;
    property Capacity: Integer read FCapacity write SetCapacity;
    // Count must be maintained by owner
    property Count: Integer read FCount write SetCount;
  end;

  { TSynEditStrings }

  TSynEditStrings = class(TStrings)
  protected
    FIsUtf8: Boolean;
    function  GetIsUtf8 : Boolean; virtual;
    procedure SetIsUtf8(const AValue : Boolean); virtual;
    function GetRange: TSynEditStorageMem; virtual; abstract;
    procedure PutRange(ARange: TSynEditStorageMem); virtual; abstract;
    function  GetAttribute(const Owner: TClass; const Index: Integer): Pointer; virtual; abstract;
    procedure SetAttribute(const Owner: TClass; const Index: Integer; const AValue: Pointer); virtual; abstract;

    function GetExpandedString(Index: integer): string; virtual; abstract;
    function GetLengthOfLongestLine: integer; virtual; abstract;
    procedure SetTextStr(const Value: string); override;

    function GetRedoList: TSynEditUndoList; virtual; abstract;
    function GetUndoList: TSynEditUndoList; virtual; abstract;
    procedure SetIsUndoing(const AValue: Boolean); virtual; abstract;
    procedure SendNotification(AReason: TSynEditNotifyReason;
                ASender: TSynEditStrings; aIndex, aCount: Integer;
                aBytePos: Integer = -1; aLen: Integer = 0;
                aTxt: String = ''); virtual; abstract;
    procedure IgnoreSendNotification(AReason: TSynEditNotifyReason;
                                     ReEnable: Boolean); virtual; abstract;
  public
    constructor Create;
    procedure DeleteLines(Index, NumLines: integer); virtual; abstract;
    procedure InsertLines(Index, NumLines: integer); virtual; abstract;
    procedure InsertStrings(Index: integer; NewStrings: TStrings); virtual; abstract;

    procedure RegisterAttribute(const Index: TClass; const Size: Word); virtual; abstract;
    property Attribute[Owner: TClass; Index: Integer]: Pointer
      read GetAttribute write SetAttribute;
    procedure AddChangeHandler(AReason: TSynEditNotifyReason;
                AHandler: TStringListLineCountEvent); virtual; abstract;
    procedure RemoveChangeHandler(AReason: TSynEditNotifyReason;
                AHandler: TStringListLineCountEvent); virtual; abstract;
    procedure AddEditHandler(AHandler: TStringListLineEditEvent); virtual; abstract;
    procedure RemoveEditHandler(AHandler: TStringListLineEditEvent); virtual; abstract;
  public
    function GetPhysicalCharWidths(Index: Integer): TPhysicalCharWidths;
    function GetPhysicalCharWidths(const Line: String; Index: Integer): TPhysicalCharWidths; virtual; abstract;
    // Byte to Char
    function LogicalToPhysicalPos(const p: TPoint): TPoint;
    function LogicalToPhysicalCol(const Line: String;
                                  Index, LogicalPos: integer): integer; virtual;
    // Char to Byte
    function PhysicalToLogicalPos(const p: TPoint): TPoint;
    function PhysicalToLogicalCol(const Line: string;
                                  Index, PhysicalPos: integer): integer; virtual;
  public
    procedure EditInsert(LogX, LogY: Integer; AText: String); virtual; abstract;
    function  EditDelete(LogX, LogY, ByteLen: Integer): String; virtual; abstract;
    procedure EditLineBreak(LogX, LogY: Integer); virtual; abstract;
    procedure EditLineJoin(LogY: Integer; FillText: String = ''); virtual; abstract;
    procedure EditLinesInsert(LogY, ACount: Integer; AText: String = ''); virtual; abstract;
    procedure EditLinesDelete(LogY, ACount: Integer); virtual; abstract;
    procedure EditUndo(Item: TSynEditUndoItem); virtual; abstract;
    procedure EditRedo(Item: TSynEditUndoItem); virtual; abstract;
    property UndoList: TSynEditUndoList read GetUndoList;
    property RedoList: TSynEditUndoList read GetRedoList;
    property IsUndoing: Boolean write SetIsUndoing;
  public
    property ExpandedStrings[Index: integer]: string read GetExpandedString;
    property LengthOfLongestLine: integer read GetLengthOfLongestLine;
    property IsUtf8: Boolean read GetIsUtf8 write SetIsUtf8;
    property Ranges: TSynEditStorageMem read GetRange write PutRange;
  end;

  { TSynEditStringsLinked }

  TSynEditStringsLinked = class(TSynEditStrings)
  protected
    fSynStrings: TSynEditStrings;

    function  GetIsUtf8 : Boolean;  override;
    procedure SetIsUtf8(const AValue : Boolean);  override;

    function GetRange: TSynEditStorageMem;  override;
    procedure PutRange(ARange: TSynEditStorageMem);  override;

    function  GetAttribute(const Owner: TClass; const Index: Integer): Pointer; override;
    procedure SetAttribute(const Owner: TClass; const Index: Integer; const AValue: Pointer); override;

    function GetExpandedString(Index: integer): string; override;
    function GetLengthOfLongestLine: integer; override;

    procedure SendNotification(AReason: TSynEditNotifyReason;
                ASender: TSynEditStrings; aIndex, aCount: Integer;
                aBytePos: Integer = -1; aLen: Integer = 0;
                aTxt: String = ''); override;
    procedure IgnoreSendNotification(AReason: TSynEditNotifyReason;
                                     IncIgnore: Boolean); override;
    function GetRedoList: TSynEditUndoList; override;
    function GetUndoList: TSynEditUndoList; override;
    procedure SetIsUndoing(const AValue: Boolean); override;
  protected
    function GetCount: integer; override;
    function GetCapacity: integer;
      {$IFDEF SYN_COMPILER_3_UP} override; {$ELSE} virtual; {$ENDIF}
    procedure SetCapacity(NewCapacity: integer);
      {$IFDEF SYN_COMPILER_3_UP} override; {$ELSE} virtual; {$ENDIF}
    function  Get(Index: integer): string; override;
    function  GetObject(Index: integer): TObject; override;
    procedure Put(Index: integer; const S: string); override;
    procedure PutObject(Index: integer; AObject: TObject); override;

    procedure SetUpdateState(Updating: Boolean); override;
  public
    constructor Create(ASynStringSource: TSynEditStrings);

    function Add(const S: string): integer; override;
    procedure AddStrings(AStrings: TStrings); override;
    procedure Clear; override;
    procedure Delete(Index: integer); override;
    procedure DeleteLines(Index, NumLines: integer);  override;
    procedure Insert(Index: integer; const S: string); override;
    procedure InsertLines(Index, NumLines: integer); override;
    procedure InsertStrings(Index: integer; NewStrings: TStrings); override;

    // Size: 0 = Bit (TODO); 1..8 Size In Byte "SizeOf()"
    procedure RegisterAttribute(const Index: TClass; const Size: Word); override;
    procedure AddChangeHandler(AReason: TSynEditNotifyReason;
                AHandler: TStringListLineCountEvent); override;
    procedure RemoveChangeHandler(AReason: TSynEditNotifyReason;
                AHandler: TStringListLineCountEvent); override;
    procedure AddEditHandler(AHandler: TStringListLineEditEvent); override;
    procedure RemoveEditHandler(AHandler: TStringListLineEditEvent); override;

    function GetPhysicalCharWidths(const Line: String; Index: Integer): TPhysicalCharWidths; override;
    property NextLines: TSynEditStrings read fSynStrings;
  public
    // LogX, LogY are 1-based
    procedure EditInsert(LogX, LogY: Integer; AText: String); override;
    function  EditDelete(LogX, LogY, ByteLen: Integer): String; override;
    procedure EditLineBreak(LogX, LogY: Integer); override;
    procedure EditLineJoin(LogY: Integer; FillText: String = ''); override;
    procedure EditLinesInsert(LogY, ACount: Integer; AText: String = ''); override;
    procedure EditLinesDelete(LogY, ACount: Integer); override;
    procedure EditUndo(Item: TSynEditUndoItem); override;
    procedure EditRedo(Item: TSynEditUndoItem); override;
  end;

  { TSynEditUndoItem }

  TSynEditUndoItem = class(TObject)
  protected
    // IsEqual is only needed/implemented for Carets
    function IsEqualContent(AnItem: TSynEditUndoItem): Boolean; virtual;
    function IsEqual(AnItem: TSynEditUndoItem): Boolean;
    function DebugString: String; virtual;
  public
    function IsCaretInfo: Boolean; virtual;
    function PerformUndo(Caller: TObject): Boolean; virtual; abstract;
  end;

  { TSynEditUndoGroup }

  TSynEditUndoGroup = class(TObject)
  private
    FItems: Array of TSynEditUndoItem;
    FCount, FCapacity: Integer;
    FReason: TSynEditorCommand;
    function GetItem(Index: Integer): TSynEditUndoItem;
    procedure Grow;
  protected
    Function HasUndoInfo: Boolean;
    procedure Append(AnUndoGroup: TSynEditUndoItem);
    procedure TranferTo(AnUndoGroup: TSynEditUndoGroup);
    function CanMergeWith(AnUndoGroup: TSynEditUndoGroup): Boolean;
    procedure MergeWith(AnUndoGroup: TSynEditUndoGroup);
  public
    constructor Create;
    Destructor Destroy; override;

    procedure Assign(AnUndoGroup: TSynEditUndoGroup);
    procedure Add(AnItem: TSynEditUndoItem);
    procedure Clear;
    procedure Insert(AIndex: Integer; AnItem: TSynEditUndoItem);
    function  Pop: TSynEditUndoItem;
    property Count: Integer read FCount;
    property Items [Index: Integer]: TSynEditUndoItem read GetItem;
    property Reason: TSynEditorCommand read FReason write FReason;
  end;


  TSynGetCaretUndoProc = function: TSynEditUndoItem of object;

  { TSynEditUndoList }

  TSynEditUndoList = class(TObject)
  private
    FGroupUndo: Boolean;
    FIsInsideRedo: Boolean;
    FUndoGroup: TSynEditUndoGroup;
    FInGroupCount: integer;
    fFullUndoImposible: boolean;
    fItems: TList;
    fLockCount: integer;
    fMaxUndoActions: integer;
    fOnAdded: TNotifyEvent;
    FOnNeedCaretUndo: TSynGetCaretUndoProc;
    fUnModifiedItem: integer;
    FForceGroupEnd: Boolean;
    procedure EnsureMaxEntries;
    function GetCanUndo: boolean;
    function GetCurrentReason: TSynEditorCommand;
    function GetItemCount: integer;
    procedure SetCurrentReason(const AValue: TSynEditorCommand);
    procedure SetMaxUndoActions(Value: integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddChange(AChange: TSynEditUndoItem);
    procedure AppendToLastChange(AChange: TSynEditUndoItem);
    procedure BeginBlock;
    procedure EndBlock;
    procedure Clear;
    procedure Lock;
    function PopItem: TSynEditUndoGroup;
    procedure Unlock;
    function IsLocked: Boolean;
    procedure MarkTopAsUnmodified;
    procedure ForceGroupEnd;
    function RealCount: Integer;
    function IsTopMarkedAsUnmodified: boolean;
    function UnModifiedMarkerExists: boolean;
  public
    property CanUndo: boolean read GetCanUndo;
    property FullUndoImpossible: boolean read fFullUndoImposible;
    property ItemCount: integer read GetItemCount;
    property MaxUndoActions: integer read fMaxUndoActions
      write SetMaxUndoActions;
    property IsInsideRedo: Boolean read FIsInsideRedo write FIsInsideRedo;
    property OnAddedUndo: TNotifyEvent read fOnAdded write fOnAdded;
    property OnNeedCaretUndo : TSynGetCaretUndoProc
      read FOnNeedCaretUndo write FOnNeedCaretUndo;
    property GroupUndo: Boolean read FGroupUndo write FGroupUndo;
    property CurrentGroup: TSynEditUndoGroup read FUndoGroup;
    property CurrentReason: TSynEditorCommand read GetCurrentReason
      write SetCurrentReason;
  end;

implementation


{ TSynEditStrings }

constructor TSynEditStrings.Create;
begin
  inherited Create;
  IsUtf8 := True;
end;

function TSynEditStrings.GetPhysicalCharWidths(Index: Integer): TPhysicalCharWidths;
begin
  Result := GetPhysicalCharWidths(Strings[Index], Index);
end;

function TSynEditStrings.GetIsUtf8 : Boolean;
begin
  Result := FIsUtf8;
end;

procedure TSynEditStrings.SetIsUtf8(const AValue : Boolean);
begin
  FIsUtf8 := AValue;
end;

procedure TSynEditStrings.SetTextStr(const Value : string);
var
  StartPos: PChar;
  p: PChar;
  Last: PChar;
  sl: TStringList;
  s: string;
begin
  if Value='' then begin
    Clear;
    exit;
  end;
  BeginUpdate;
  sl:=TStringList.Create;
  try
    Clear;
    p:=PChar(Value);
    StartPos:=p;
    Last:=p+length(Value);
    while p<Last do begin
      if not (p^ in [#10,#13]) then begin
        inc(p);
      end else begin
        SetLength(s,p-StartPos);
        if s<>'' then
          System.Move(StartPos^,s[1],length(s));
        sl.Add(s);
        if (p[1] in [#10,#13]) and (p[1]<>p^) then
          inc(p);
        inc(p);
        StartPos:=p;
      end;
    end;
    if StartPos<Last then begin
      SetLength(s,Last-StartPos);
      if s<>'' then
        System.Move(StartPos^,s[1],length(s));
      sl.Add(s);
    end;
    AddStrings(sl);
  finally
    sl.Free;
    EndUpdate;
  end;
end;

function TSynEditStrings.LogicalToPhysicalPos(const p : TPoint) : TPoint;
begin
  Result := p;
  if Result.Y - 1 < Count then
    Result.X:=LogicalToPhysicalCol(self[Result.Y - 1], Result.Y, Result.X);
end;

function TSynEditStrings.LogicalToPhysicalCol(const Line : String;
  Index, LogicalPos: integer) : integer;
var
  i, ByteLen: integer;
  CharWidths: TPhysicalCharWidths;
begin
  CharWidths := GetPhysicalCharWidths(Line, Index);
  ByteLen := length(Line);
  dec(LogicalPos);

  if LogicalPos > ByteLen then begin
    Result := 1 + LogicalPos - ByteLen;
    LogicalPos := ByteLen;
  end
  else
    Result := 1;

  for i := 0 to LogicalPos - 1 do
    Result := Result + CharWidths[i];
end;

function TSynEditStrings.PhysicalToLogicalPos(const p : TPoint) : TPoint;
begin
  Result := p;
  if (Result.Y>=1) and (Result.Y <= Count) then
    Result.X:=PhysicalToLogicalCol(self[Result.Y - 1], Result.Y - 1, Result.X);
end;

function TSynEditStrings.PhysicalToLogicalCol(const Line : string;
  Index, PhysicalPos : integer) : integer;
var
  BytePos, ByteLen: integer;
  ScreenPos: integer;
  CharWidths: TPhysicalCharWidths;
begin
  CharWidths := GetPhysicalCharWidths(Line, Index);
  ByteLen := Length(Line);
  ScreenPos := 1;
  BytePos := 0;

  while BytePos < ByteLen do begin
    if ScreenPos + CharWidths[BytePos] > PhysicalPos then
      exit(BytePos+1);
    ScreenPos := ScreenPos + CharWidths[BytePos];
    inc(BytePos);
  end;

  Result := BytePos + 1 + PhysicalPos - ScreenPos;
end;

{ TSynEditStringsLinked }

constructor TSynEditStringsLinked.Create(ASynStringSource: TSynEditStrings);
begin
  fSynStrings := ASynStringSource;
  Inherited Create;
end;

function TSynEditStringsLinked.Add(const S: string): integer;
begin
  Result := fSynStrings.Add(S);
end;

procedure TSynEditStringsLinked.AddStrings(AStrings: TStrings);
begin
  fSynStrings.AddStrings(AStrings);
end;

procedure TSynEditStringsLinked.Clear;
begin
  fSynStrings.Clear;
end;

procedure TSynEditStringsLinked.Delete(Index: integer);
begin
  fSynStrings.Delete(Index);
end;

procedure TSynEditStringsLinked.DeleteLines(Index, NumLines: integer);
begin
  fSynStrings.DeleteLines(Index, NumLines);
end;

procedure TSynEditStringsLinked.Insert(Index: integer; const S: string);
begin
  fSynStrings.Insert(Index, S);
end;

procedure TSynEditStringsLinked.InsertLines(Index, NumLines: integer);
begin
  fSynStrings.InsertLines(Index, NumLines);
end;

procedure TSynEditStringsLinked.InsertStrings(Index: integer; NewStrings: TStrings);
begin
  fSynStrings.InsertStrings(Index, NewStrings);
end;

procedure TSynEditStringsLinked.SetIsUndoing(const AValue: Boolean);
begin
  fSynStrings.IsUndoing := AValue;
end;

function TSynEditStringsLinked.GetIsUtf8: Boolean;
begin
  Result := FSynStrings.IsUtf8;
end;

procedure TSynEditStringsLinked.SetIsUtf8(const AValue: Boolean);
begin
  FSynStrings.IsUtf8 := AValue;
end;

//Ranges
function TSynEditStringsLinked.GetRange: TSynEditStorageMem;
begin
  Result:= fSynStrings.Ranges;
end;

procedure TSynEditStringsLinked.PutRange(ARange: TSynEditStorageMem);
begin
  fSynStrings.Ranges := ARange;
end;

function TSynEditStringsLinked.GetAttribute(const Owner: TClass; const Index: Integer): Pointer;
begin
  Result := fSynStrings.Attribute[Owner, Index];
end;

procedure TSynEditStringsLinked.SetAttribute(const Owner: TClass;
                                const Index: Integer; const AValue: Pointer);
begin
  fSynStrings.Attribute[Owner, Index] := AValue;
end;

function TSynEditStringsLinked.GetExpandedString(Index: integer): string;
begin
  Result:= fSynStrings.GetExpandedString(Index);
end;

function TSynEditStringsLinked.GetLengthOfLongestLine: integer;
begin
  Result:= fSynStrings.GetLengthOfLongestLine;
end;

function TSynEditStringsLinked.GetRedoList: TSynEditUndoList;
begin
  Result := fSynStrings.GetRedoList;
end;

function TSynEditStringsLinked.GetUndoList: TSynEditUndoList;
begin
  Result := fSynStrings.GetUndoList;
end;

procedure TSynEditStringsLinked.RegisterAttribute(const Index: TClass; const Size: Word);
begin
  fSynStrings.RegisterAttribute(Index, Size);
end;

procedure TSynEditStringsLinked.AddChangeHandler(AReason: TSynEditNotifyReason; AHandler: TStringListLineCountEvent);
begin
  fSynStrings.AddChangeHandler(AReason, AHandler);
end;

procedure TSynEditStringsLinked.RemoveChangeHandler(AReason: TSynEditNotifyReason; AHandler: TStringListLineCountEvent);
begin
  fSynStrings.RemoveChangeHandler(AReason, AHandler);
end;

procedure TSynEditStringsLinked.AddEditHandler(AHandler: TStringListLineEditEvent);
begin
  fSynStrings.AddEditHandler(AHandler);
end;

procedure TSynEditStringsLinked.RemoveEditHandler(AHandler: TStringListLineEditEvent);
begin
  fSynStrings.RemoveEditHandler(AHandler);
end;

// Count
function TSynEditStringsLinked.GetCount: integer;
begin
  Result:= fSynStrings.Count;
end;

function TSynEditStringsLinked.GetCapacity: integer;
begin
  Result:= fSynStrings.Capacity;
end;

procedure TSynEditStringsLinked.SetCapacity(NewCapacity: integer);
begin
  fSynStrings.Capacity := NewCapacity;
end;

function TSynEditStringsLinked.Get(Index: integer): string;
begin
  Result:= fSynStrings.Get(Index);
end;

function TSynEditStringsLinked.GetObject(Index: integer): TObject;
begin
  Result:= fSynStrings.GetObject(Index);
end;

procedure TSynEditStringsLinked.Put(Index: integer; const S: string);
begin
  fSynStrings.Put(Index, S);
end;

procedure TSynEditStringsLinked.PutObject(Index: integer; AObject: TObject);
begin
  fSynStrings.PutObject(Index, AObject);
end;

function TSynEditStringsLinked.GetPhysicalCharWidths(const Line: String; Index: Integer): TPhysicalCharWidths;
begin
  Result := fSynStrings.GetPhysicalCharWidths(Line, Index);
end;

procedure TSynEditStringsLinked.SetUpdateState(Updating: Boolean);
begin
  if Updating then
    fSynStrings.BeginUpdate
  else
   fSynStrings.EndUpdate;
end;

procedure TSynEditStringsLinked.EditInsert(LogX, LogY: Integer; AText: String);
begin
  fSynStrings.EditInsert(LogX, LogY, AText);
end;

function TSynEditStringsLinked.EditDelete(LogX, LogY, ByteLen: Integer): String;
begin
  Result := fSynStrings.EditDelete(LogX, LogY, ByteLen);
end;

procedure TSynEditStringsLinked.EditLineBreak(LogX, LogY: Integer);
begin
  fSynStrings.EditLineBreak(LogX, LogY);
end;

procedure TSynEditStringsLinked.EditLineJoin(LogY: Integer;
  FillText: String = '');
begin
  fSynStrings.EditLineJoin(LogY, FillText);
end;

procedure TSynEditStringsLinked.EditLinesInsert(LogY, ACount: Integer; AText: String = '');
begin
  fSynStrings.EditLinesInsert(LogY, ACount, AText);
end;

procedure TSynEditStringsLinked.EditLinesDelete(LogY, ACount: Integer);
begin
  fSynStrings.EditLinesDelete(LogY, ACount);
end;

procedure TSynEditStringsLinked.EditUndo(Item: TSynEditUndoItem);
begin
  fSynStrings.EditUndo(Item);
end;

procedure TSynEditStringsLinked.EditRedo(Item: TSynEditUndoItem);
begin
  fSynStrings.EditRedo(Item);
end;

procedure TSynEditStringsLinked.SendNotification(AReason: TSynEditNotifyReason;
  ASender: TSynEditStrings; aIndex, aCount: Integer;
  aBytePos: Integer = -1; aLen: Integer = 0; aTxt: String = '');
begin
  fSynStrings.SendNotification(AReason, ASender, aIndex, aCount, aBytePos, aLen, aTxt);
end;

procedure TSynEditStringsLinked.IgnoreSendNotification(AReason: TSynEditNotifyReason;
  IncIgnore: Boolean);
begin
  fSynStrings.IgnoreSendNotification(AReason, IncIgnore);
end;

{ TSynEditUndoList }

constructor TSynEditUndoList.Create;
begin
  inherited Create;
  // Create and keep one undo group => avoids resizing the FItems list
  FUndoGroup := TSynEditUndoGroup.Create;
  FIsInsideRedo := False;
  fItems := TList.Create;
  fMaxUndoActions := 1024;
  fUnModifiedItem:=-1;
  FForceGroupEnd := False;
end;

destructor TSynEditUndoList.Destroy;
begin
  Clear;
  fItems.Free;
  FreeAndNil(FUndoGroup);
  inherited Destroy;
end;

procedure TSynEditUndoList.AddChange(AChange: TSynEditUndoItem);
var
  ugroup: TSynEditUndoGroup;
begin
  if fLockCount > 0 then begin
    AChange.Free;
    exit;
  end;

  if FInGroupCount > 0 then
    FUndoGroup.Add(AChange)
  else begin
    ugroup := TSynEditUndoGroup.Create;
    ugroup.Add(AChange);
    fItems.Add(ugroup);
    if Assigned(fOnAdded) then
      fOnAdded(Self);
  end;

  EnsureMaxEntries;
end;

procedure TSynEditUndoList.AppendToLastChange(AChange: TSynEditUndoItem);
var
  cur: Boolean;
begin
  cur := FUndoGroup.HasUndoInfo;
  if (fLockCount <> 0) or ((fItems.Count = 0) and not cur) then begin
    AChange.Free;
    exit;
  end;

  if cur then
    FUndoGroup.Append(AChange)
  else
    TSynEditUndoGroup(fItems[fItems.Count-1]).Append(AChange);

  // Do not callback to synedit, or Redo Info is lost
  EnsureMaxEntries;
end;

procedure TSynEditUndoList.BeginBlock;
begin
  Inc(FInGroupCount);
  if (FInGroupCount = 1) then begin
    FUndoGroup.Clear;
    if assigned(FOnNeedCaretUndo) then
      FUndoGroup.add(FOnNeedCaretUndo());
  end
end;

procedure TSynEditUndoList.Clear;
var
  i: integer;
begin
  for i := 0 to fItems.Count - 1 do
    TSynEditUndoGroup(fItems[i]).Free;
  fItems.Clear;
  fFullUndoImposible := FALSE;
  fUnModifiedItem:=-1;
end;

procedure TSynEditUndoList.EndBlock;
var
  ugroup: TSynEditUndoGroup;
begin
  if FInGroupCount > 0 then begin
    Dec(FInGroupCount);
    if (FInGroupCount = 0) and FUndoGroup.HasUndoInfo then
    begin
      // Keep position for REDO; Do not replace if present
      if (not FUndoGroup.Items[FUndoGroup.Count - 1].IsCaretInfo)
          and assigned(FOnNeedCaretUndo) then
        FUndoGroup.Add(FOnNeedCaretUndo());
      if (fItems.Count > 0) and FGroupUndo and (not IsTopMarkedAsUnmodified) and
        (not FForceGroupEnd) and
        FUndoGroup.CanMergeWith(TSynEditUndoGroup(fItems[fItems.Count - 1])) then
      begin
        FUndoGroup.MergeWith(TSynEditUndoGroup(fItems[fItems.Count - 1]));
        FUndoGroup.TranferTo(TSynEditUndoGroup(fItems[fItems.Count - 1]));
      end else begin
        ugroup := TSynEditUndoGroup.Create;
        FUndoGroup.TranferTo(ugroup);
        fItems.Add(ugroup);
      end;
      if Assigned(fOnAdded) then
        fOnAdded(Self);
      FIsInsideRedo := False;
      FForceGroupEnd := False;
    end;
  end;
end;

procedure TSynEditUndoList.EnsureMaxEntries;
var
  Item: TSynEditUndoGroup;
begin
  if fItems.Count > fMaxUndoActions then begin
    fFullUndoImposible := TRUE;
    while fItems.Count > fMaxUndoActions do begin
      Item := TSynEditUndoGroup(fItems[0]);
      Item.Free;
      fItems.Delete(0);
      if fUnModifiedItem>=0 then dec(fUnModifiedItem);
    end;
  end;
end;

function TSynEditUndoList.GetCanUndo: boolean;
begin
  Result := fItems.Count > 0;
end;

function TSynEditUndoList.GetCurrentReason: TSynEditorCommand;
begin
  Result := FUndoGroup.Reason;
end;

function TSynEditUndoList.GetItemCount: integer;
begin
  Result := fItems.Count;
end;

procedure TSynEditUndoList.SetCurrentReason(const AValue: TSynEditorCommand);
begin
  if FUndoGroup.Reason = ecNone then
    FUndoGroup.Reason := AValue;
end;

procedure TSynEditUndoList.Lock;
begin
  Inc(fLockCount);
end;

function TSynEditUndoList.PopItem: TSynEditUndoGroup;
var
  iLast: integer;
begin
  Result := nil;
  iLast := fItems.Count - 1;
  if iLast >= 0 then begin
    Result := TSynEditUndoGroup(fItems[iLast]);
    fItems.Delete(iLast);
    if fUnModifiedItem>fItems.Count then
      fUnModifiedItem:=-1;
  end;
end;

procedure TSynEditUndoList.SetMaxUndoActions(Value: integer);
begin
  if Value < 0 then
    Value := 0;
  if Value <> fMaxUndoActions then begin
    fMaxUndoActions := Value;
    EnsureMaxEntries;
  end;
end;

function TSynEditUndoList.RealCount: Integer;
begin
  Result := fItems.Count;
  if (FInGroupCount > 0) and FUndoGroup.HasUndoInfo then
    Result := Result + 1;
end;

procedure TSynEditUndoList.Unlock;
begin
  if fLockCount > 0 then
    Dec(fLockCount);
end;

function TSynEditUndoList.IsLocked: Boolean;
begin
  Result := fLockCount > 0;
end;

procedure TSynEditUndoList.MarkTopAsUnmodified;
begin
  fUnModifiedItem := RealCount;
end;

procedure TSynEditUndoList.ForceGroupEnd;
begin
  FForceGroupEnd := True;
end;

function TSynEditUndoList.IsTopMarkedAsUnmodified: boolean;
begin
  Result := (RealCount = fUnModifiedItem);
end;

function TSynEditUndoList.UnModifiedMarkerExists: boolean;
begin
  Result := fUnModifiedItem >= 0;
end;

{ TSynEditUndoItem }

function TSynEditUndoItem.IsEqualContent(AnItem: TSynEditUndoItem): Boolean;
begin
  Result := False;
end;

function TSynEditUndoItem.IsEqual(AnItem: TSynEditUndoItem): Boolean;
begin
  Result := (ClassType = AnItem.ClassType);
  if Result then Result := Result and IsEqualContent(AnItem);
end;

function TSynEditUndoItem.DebugString: String;
begin
  Result := '';
end;

function TSynEditUndoItem.IsCaretInfo: Boolean;
begin
  Result := False;
end;

(*
function TSynEditUndoItem.ChangeStartPos: TPoint;
begin
  if (fChangeStartPos.Y < fChangeEndPos.Y)
    or ((fChangeStartPos.Y = fChangeEndPos.Y) and (fChangeStartPos.X < fChangeEndPos.X))
  then result := fChangeStartPos
  else result := fChangeEndPos;
end;

function TSynEditUndoItem.ChangeEndPos: TPoint;
begin
  if (fChangeStartPos.Y < fChangeEndPos.Y)
    or ((fChangeStartPos.Y = fChangeEndPos.Y) and (fChangeStartPos.X < fChangeEndPos.X))
  then result := fChangeEndPos
  else result := fChangeStartPos;
end;
*)

{ TSynEditUndoGroup }

procedure TSynEditUndoGroup.Grow;
begin
  FCapacity := FCapacity + Max(10, FCapacity Div 8);
  SetLength(FItems, FCapacity);
end;

function TSynEditUndoGroup.HasUndoInfo: Boolean;
var
  i: Integer;
begin
  i := 0;
  while i < FCount do
    if FItems[i].IsCaretInfo then
      inc(i)
    else
      exit(true);
  Result := False;
end;

procedure TSynEditUndoGroup.Append(AnUndoGroup: TSynEditUndoItem);
var
  i: Integer;
begin
  i := FCount - 1;
  while (i >= 0) and FItems[i].IsCaretInfo do
    dec(i);
  inc(i);
  Insert(i, AnUndoGroup);
end;

procedure TSynEditUndoGroup.TranferTo(AnUndoGroup: TSynEditUndoGroup);
begin
  AnUndoGroup.Assign(self);
  FCount := 0; // Do not clear; that would free the items
end;

function TSynEditUndoGroup.CanMergeWith(AnUndoGroup: TSynEditUndoGroup): Boolean;
begin
  // Check if the other group can be merged to the START of this node
  if AnUndoGroup.Count = 0 then exit(True);
  Result := (FReason <> ecNone) and (AnUndoGroup.Reason = FReason)
        and Items[0].IsCaretInfo
        and AnUndoGroup.Items[AnUndoGroup.Count - 1].IsEqual(Items[0]);
end;

procedure TSynEditUndoGroup.MergeWith(AnUndoGroup: TSynEditUndoGroup);
begin
  // Merge other group to start
  AnUndoGroup.Pop.Free;
  if AnUndoGroup.Count > 0 then begin
    fItems[0].Free;
    fItems[0] := AnUndoGroup.Pop;
  end;
  while AnUndoGroup.Count > 0 do
    Insert(0, AnUndoGroup.Pop);
end;

function TSynEditUndoGroup.GetItem(Index: Integer): TSynEditUndoItem;
begin
  Result := FItems[Index];
end;

constructor TSynEditUndoGroup.Create;
begin
  FCount := 0;
  FCapacity := 0;
end;

destructor TSynEditUndoGroup.Destroy;
begin
  Clear;
  FItems := nil;
  inherited Destroy;
end;

procedure TSynEditUndoGroup.Assign(AnUndoGroup: TSynEditUndoGroup);
begin
  Clear;
  FCapacity := AnUndoGroup.Count;
  FCount := FCapacity;
  SetLength(FItems, FCapacity);
  if FCapacity = 0 then
    exit;
  System.Move(AnUndoGroup.FItems[0], FItems[0], FCapacity * SizeOf(TSynEditUndoItem));
  FReason := AnUndoGroup.Reason;
end;

procedure TSynEditUndoGroup.Add(AnItem: TSynEditUndoItem);
begin
  if (FCount > 0) and AnItem.IsCaretInfo
     and FItems[FCount - 1].IsCaretInfo then
  begin
    FItems[FCount - 1].Free;
    FItems[FCount - 1] := AnItem;
    exit;
  end;
  if FCount >= FCapacity then
    Grow;
  FItems[FCount] := AnItem;
  inc (FCount);
end;

procedure TSynEditUndoGroup.Clear;
begin
  while FCount > 0 do begin
    dec(FCount);
    FItems[FCount].Free;
  end;
  if FCapacity > 100 then begin
    FCapacity := 100;
    SetLength(FItems, FCapacity);
  end;
  FReason := ecNone;
end;

procedure TSynEditUndoGroup.Insert(AIndex: Integer; AnItem: TSynEditUndoItem);
begin
  if FCount >= FCapacity then
    Grow;
  If AIndex < FCount then
    System.Move(FItems[AIndex], FItems[AIndex+1],
                (FCount - AIndex) * SizeOf(TSynEditUndoItem));
  FItems[AIndex] := AnItem;
  inc (FCount);
end;

function TSynEditUndoGroup.Pop: TSynEditUndoItem;
begin
  if FCount <= 0 then
    exit(nil);
  dec(FCount);
  Result := FItems[FCount];
end;

{ TSynEditStorageMem }

function TSynEditStorageMem.GetItemPointer(Index: Integer): Pointer;
begin
  Result := Pointer(FMem + Index * ItemSize);
end;

procedure TSynEditStorageMem.SetCapacity(const AValue: Integer);
begin
  if FCapacity = AValue then exit;
  FMem := ReallocMem(FMem, AValue * ItemSize);
  if AValue > FCapacity then
    FillChar((FMem+FCapacity*ItemSize)^, (AValue-FCapacity)*ItemSize, 0);
  FCapacity := AValue;
end;

procedure TSynEditStorageMem.SetCount(const AValue: Integer);
begin
  FCount := AValue;
end;

constructor TSynEditStorageMem.Create;
begin
  FCapacity := 0;
  FCount := 0;
end;

destructor TSynEditStorageMem.Destroy;
begin
  SetCount(0);
  SetCapacity(0);
  inherited Destroy;
end;

procedure TSynEditStorageMem.Move(AFrom, ATo, ALen: Integer);
var
  len: Integer;
begin
  if ATo < AFrom then begin
    Len := Min(ALen, AFrom-ATo);
    System.Move((FMem+AFrom*ItemSize)^, (FMem+ATo*ItemSize)^, Alen*ItemSize);
    FillChar((FMem+(AFrom+ALen-Len)*ItemSize)^, Len*ItemSize, 0);
  end else begin
    Len := Min(ALen, ATo-AFrom);
    System.Move((FMem+AFrom*ItemSize)^, (FMem+ATo*ItemSize)^, Alen*ItemSize);
    FillChar((FMem+AFrom*ItemSize)^, Len*ItemSize, 0);
  end;
end;

end.

