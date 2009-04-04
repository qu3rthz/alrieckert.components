{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/
Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: SynEditHighlighter.pas, released 2000-04-07.

The Original Code is based on mwHighlighter.pas by Martin Waldenburg, part of
the mwEdit component suite.
Portions created by Martin Waldenburg are Copyright (C) 1998 Martin Waldenburg.
All Rights Reserved.

Contributors to the SynEdit and mwEdit projects are listed in the
Contributors.txt file.

$Id: synedithighlighter.pp 19051 2009-03-21 00:47:33Z martin $

You may retrieve the latest version of this file at the SynEdit home page,
located at http://SynEdit.SourceForge.net

Known Issues:
-------------------------------------------------------------------------------}

unit SynEditHighlighterFoldBase;

{$I synedit.inc}

interface

uses
  SysUtils, Classes,
{$IFDEF SYN_CLX}
  kTextDrawer, Types, QGraphics,
{$ELSE}
  FileUtil, LCLProc, LCLIntf, LCLType,
{$ENDIF}
  SynEditHighlighter, SynEditTypes, SynEditMiscClasses, SynEditTextBuffer,
  SynEditTextBase, AvgLvlTree;

type

  { TSynCustomCodeFoldBlock }

  TSynCustomCodeFoldBlock = class
  private
    FBlockType: Pointer;
    FParent, FChildren: TSynCustomCodeFoldBlock;
    FRight, FLeft: TSynCustomCodeFoldBlock;
    FBalance: Integer;
    function GetChild(ABlockType: Pointer): TSynCustomCodeFoldBlock;
  protected
    function GetOrCreateSibling(ABlockType: Pointer): TSynCustomCodeFoldBlock;
    property Right: TSynCustomCodeFoldBlock read FRight;
    property Left: TSynCustomCodeFoldBlock read FLeft;
    property Children: TSynCustomCodeFoldBlock read FChildren;
  public
    destructor Destroy; override;
    procedure WriteDebugReport;
  public
    procedure InitRootBlockType(AType: Pointer);
    property BlockType: Pointer read FBlockType;
    property Parent: TSynCustomCodeFoldBlock read FParent;
    property Child[ABlockType: Pointer]: TSynCustomCodeFoldBlock read GetChild;
  end;

  { TSynCustomHighlighterRange }

  TSynCustomHighlighterRange = class
  private
    FCodeFoldStackSize: integer; // EndLevel
    FMinimumCodeFoldBlockLevel: integer;
    FRangeType: Pointer;
    FTop: TSynCustomCodeFoldBlock;
  public
    constructor Create(Template: TSynCustomHighlighterRange); virtual;
    destructor Destroy; override;
    function Compare(Range: TSynCustomHighlighterRange): integer; virtual;
    function Add(ABlockType: Pointer = nil; IncreaseLevel: Boolean = True):
        TSynCustomCodeFoldBlock; virtual;
    procedure Pop(DecreaseLevel: Boolean = True); virtual;
    procedure Clear; virtual;
    procedure Assign(Src: TSynCustomHighlighterRange); virtual;
    procedure WriteDebugReport;
    property FoldRoot: TSynCustomCodeFoldBlock read FTop write FTop;
  public
    property RangeType: Pointer read FRangeType write FRangeType;
    property CodeFoldStackSize: integer read FCodeFoldStackSize;
    property MinimumCodeFoldBlockLevel: integer
      read FMinimumCodeFoldBlockLevel write FMinimumCodeFoldBlockLevel;
    property Top: TSynCustomCodeFoldBlock read FTop;
  end;
  TSynCustomHighlighterRangeClass = class of TSynCustomHighlighterRange;

  TSynCustomHighlighterRanges = class;

  TSynFoldAction = (sfaOpen,    // At this node a new Fold can start
                    sfaClose,   // At this node a fold ends
                    sfaMarkup,  // This node can be highlighted, by the matching Word-Pair Markup
                    sfaInvalid  // Wrong Index
                   );
  TSynFoldActions = set of TSynFoldAction;

  TSynFoldNodeInfo = record
    LogXStart, LogXEnd: Integer; // -1 previous line
    FoldLvlStart, FoldLvlEnd: Integer;
    FoldAction: TSynFoldActions;
    FoldType: Pointer;
  end;

  { TSynCustomFoldHighlighter }

  TSynCustomFoldHighlighter = class(TSynCustomHighlighter)
  private
    FCodeFoldRange: TSynCustomHighlighterRange;
    fRanges: TSynCustomHighlighterRanges;
    FRootCodeFoldBlock: TSynCustomCodeFoldBlock;
  protected
    function GetFoldNodeInfo(Line, Index: Integer): TSynFoldNodeInfo; virtual;
    function GetFoldNodeInfoCount(Line: Integer): Integer; virtual;
    property CodeFoldRange: TSynCustomHighlighterRange read FCodeFoldRange;
    function GetRangeClass: TSynCustomHighlighterRangeClass; virtual;
    function TopCodeFoldBlockType(DownIndex: Integer = 0): Pointer;
    function StartCodeFoldBlock(ABlockType: Pointer;
              IncreaseLevel: Boolean = true): TSynCustomCodeFoldBlock; virtual;
    procedure EndCodeFoldBlock(DecreaseLevel: Boolean = True); virtual;
    procedure CreateRootCodeFoldBlock; virtual;
    property RootCodeFoldBlock: TSynCustomCodeFoldBlock read FRootCodeFoldBlock
      write FRootCodeFoldBlock;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetRange: Pointer; override;

    function MinimumCodeFoldBlockLevel: integer; virtual;
    function CurrentCodeFoldBlockLevel: integer; virtual;

    // requires CurrentLines;
    function MinimumFoldLevel(Index: Integer): integer; virtual; abstract;
    function EndFoldLevel(Index: Integer): integer; virtual; abstract;

    // fold-nodes that can be collapsed
    // Highlighter can join several fold structures Or leave out some
    function FoldOpenCount(ALineIndex: Integer): integer; virtual;
    function FoldCloseCount(ALineIndex: Integer): integer; virtual;
    function FoldNestCount(ALineIndex: Integer): integer; virtual;
    function FoldLineLength(ALineIndex, FoldIndex: Integer): integer; virtual;

    // All fold-nodes
    property FoldNodeInfo[Line, Index: Integer]: TSynFoldNodeInfo read GetFoldNodeInfo;
    property FoldNodeInfoCount[Line: Integer]: Integer read GetFoldNodeInfoCount;

    procedure SetRange(Value: Pointer); override;
    procedure ResetRange; override;
    procedure SetLine({$IFDEF FPC}const {$ENDIF}NewValue: String;
                      LineNumber:Integer // 0 based
                      ); override;
  end;

  TSynCustomHighlighterClass = class of TSynCustomFoldHighlighter;

  { TSynCustomHighlighterRanges }

  TSynCustomHighlighterRanges = class
  private
    FAllocatedCount: integer;
    FHighlighterClass: TSynCustomHighlighterClass;
    FItems: TAvgLvlTree;
  public
    constructor Create(TheHighlighterClass: TSynCustomHighlighterClass);
    destructor Destroy; override;
    function GetEqual(Range: TSynCustomHighlighterRange
                      ): TSynCustomHighlighterRange;
    procedure Allocate;
    procedure Release;
    property HighlighterClass: TSynCustomHighlighterClass read FHighlighterClass;
    property AllocatedCount: integer read FAllocatedCount;
  end;

function CompareSynHighlighterRanges(Data1, Data2: Pointer): integer;
function AllocateHighlighterRanges(
     HighlighterClass: TSynCustomHighlighterClass): TSynCustomHighlighterRanges;


implementation

function CompareSynHighlighterRanges(Data1, Data2: Pointer): integer;
var
  Range1: TSynCustomHighlighterRange;
  Range2: TSynCustomHighlighterRange;
begin
  Range1:=TSynCustomHighlighterRange(Data1);
  Range2:=TSynCustomHighlighterRange(Data2);
  Result:=Range1.Compare(Range2);
end;

var
  HighlighterRanges: TFPList = nil;

function IndexOfHighlighterRanges(
  HighlighterClass: TSynCustomHighlighterClass): integer;
begin
  if HighlighterRanges=nil then
    Result:=-1
  else begin
    Result:=HighlighterRanges.Count-1;
    while (Result>=0)
    and (TSynCustomHighlighterRanges(HighlighterRanges[Result]).HighlighterClass
      <>HighlighterClass)
    do
      dec(Result);
  end;
end;

function AllocateHighlighterRanges(
  HighlighterClass: TSynCustomHighlighterClass): TSynCustomHighlighterRanges;
var
  i: LongInt;
begin
  if HighlighterRanges=nil then HighlighterRanges:=TFPList.Create;
  i:=IndexOfHighlighterRanges(HighlighterClass);
  if i>=0 then begin
    Result:=TSynCustomHighlighterRanges(HighlighterRanges[i]);
    Result.Allocate;
  end else begin
    Result:=TSynCustomHighlighterRanges.Create(HighlighterClass);
    HighlighterRanges.Add(Result);
  end;
end;

{ TSynCustomFoldHighlighter }

constructor TSynCustomFoldHighlighter.Create(AOwner: TComponent);
begin
  fRanges:=AllocateHighlighterRanges(TSynCustomHighlighterClass(ClassType));
  CreateRootCodeFoldBlock;
  inherited Create(AOwner);
  FCodeFoldRange:=GetRangeClass.Create(nil);
  FCodeFoldRange.FoldRoot := FRootCodeFoldBlock;
end;

destructor TSynCustomFoldHighlighter.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FCodeFoldRange);
  FreeAndNil(FRootCodeFoldBlock);
  fRanges.Release;
end;

function TSynCustomFoldHighlighter.GetRange: pointer;
begin
  // FCodeFoldRange is the working range and changed steadily
  // => return a fixed copy of the current CodeFoldRange instance,
  //    that can be stored by other classes (e.g. TSynEdit)
  Result:=fRanges.GetEqual(FCodeFoldRange);
end;

procedure TSynCustomFoldHighlighter.ResetRange;
begin
  FCodeFoldRange.Clear;
  FCodeFoldRange.FoldRoot := FRootCodeFoldBlock;
end;

function TSynCustomFoldHighlighter.MinimumCodeFoldBlockLevel: integer;
begin
  Result := FCodeFoldRange.MinimumCodeFoldBlockLevel;
end;

procedure TSynCustomFoldHighlighter.SetRange(Value: Pointer);
begin
  FCodeFoldRange.Assign(TSynCustomHighlighterRange(Value));
  // in case we asigned a null range
  if not assigned(FCodeFoldRange.FoldRoot) then
    FCodeFoldRange.FoldRoot := FRootCodeFoldBlock;
end;

procedure TSynCustomFoldHighlighter.SetLine(const NewValue: String;
  LineNumber: Integer);
begin
  inherited;
  FCodeFoldRange.MinimumCodeFoldBlockLevel := FCodeFoldRange.FCodeFoldStackSize;
end;

function TSynCustomFoldHighlighter.CurrentCodeFoldBlockLevel: integer;
begin
  if CodeFoldRange<>nil then
    Result:=CodeFoldRange.CodeFoldStackSize
  else
    Result:=0;
end;

function TSynCustomFoldHighlighter.FoldOpenCount(ALineIndex: Integer): integer;
begin
  result := 0;
end;

function TSynCustomFoldHighlighter.FoldCloseCount(ALineIndex: Integer): integer;
begin
  result := 0;
end;

function TSynCustomFoldHighlighter.FoldNestCount(ALineIndex: Integer): integer;
begin
  Result := 0;
end;

function TSynCustomFoldHighlighter.FoldLineLength(ALineIndex, FoldIndex: Integer): integer;
begin
  result := 0;
end;

function TSynCustomFoldHighlighter.GetFoldNodeInfoCount(Line: Integer): Integer;
begin
  Result := 0;
end;

function TSynCustomFoldHighlighter.GetFoldNodeInfo(Line, Index: Integer): TSynFoldNodeInfo;
begin
  Result.FoldAction := [sfaInvalid];
end;

function TSynCustomFoldHighlighter.GetRangeClass: TSynCustomHighlighterRangeClass;
begin
  Result:=TSynCustomHighlighterRange;
end;

function TSynCustomFoldHighlighter.TopCodeFoldBlockType(DownIndex: Integer = 0): Pointer;
var
  Fold: TSynCustomCodeFoldBlock;
begin
  Result:=nil;
  if (CodeFoldRange<>nil) then begin
    Fold := CodeFoldRange.Top;
    while (Fold <> nil) and (DownIndex > 0) do begin
      Fold := Fold.Parent;
      dec(DownIndex);
    end;
    if Fold <> nil then
      Result := Fold.BlockType
  end;
end;

function TSynCustomFoldHighlighter.StartCodeFoldBlock(ABlockType: Pointer;
  IncreaseLevel: Boolean = True): TSynCustomCodeFoldBlock;
begin
  Result:=CodeFoldRange.Add(ABlockType, IncreaseLevel);
end;

procedure TSynCustomFoldHighlighter.EndCodeFoldBlock(DecreaseLevel: Boolean = True);
begin
  CodeFoldRange.Pop(DecreaseLevel);
end;

procedure TSynCustomFoldHighlighter.CreateRootCodeFoldBlock;
begin
  FRootCodeFoldBlock := TSynCustomCodeFoldBlock.Create;
end;

{ TSynCustomCodeFoldBlock }

function TSynCustomCodeFoldBlock.GetChild(ABlockType: Pointer): TSynCustomCodeFoldBlock;
begin
  if assigned(FChildren) then
    Result := FChildren.GetOrCreateSibling(ABlockType)
  else begin
    Result := TSynCustomCodeFoldBlock(self.ClassType.Create);
    Result.FBlockType := ABlockType;
    Result.FParent := self;
    FChildren := Result;
  end;
end;

var
  CreateSiblingBalanceList: Array of TSynCustomCodeFoldBlock;

function TSynCustomCodeFoldBlock.GetOrCreateSibling(ABlockType: Pointer): TSynCustomCodeFoldBlock;
  procedure BalanceNode(TheNode: TSynCustomCodeFoldBlock);
  var
    i, l: Integer;
    t: Pointer;
    N, P, C: TSynCustomCodeFoldBlock;
  begin
    l := length(CreateSiblingBalanceList);
    i := 0;
    t := TheNode.FBlockType;
    N := self;
    while N.FBlockType <> t do begin
      if i >= l then begin
        inc(l, 20);
        SetLength(CreateSiblingBalanceList, l);
      end;
      CreateSiblingBalanceList[i] := N; // Record all parents
      inc(i);
      if t < N.FBlockType
      then N := N.FLeft
      else N := N.FRight;
    end;
    if i >= l then begin
      inc(l, 20);
      SetLength(CreateSiblingBalanceList, l);
    end;
    CreateSiblingBalanceList[i] := TheNode;
    while i >= 0 do begin
      if CreateSiblingBalanceList[i].FBalance = 0
        then exit;
      if (CreateSiblingBalanceList[i].FBalance = -1) or
         (CreateSiblingBalanceList[i].FBalance = 1) then begin
        if i = 0 then
          exit;
        dec(i);
        if CreateSiblingBalanceList[i+1] = CreateSiblingBalanceList[i].FLeft
        then dec(CreateSiblingBalanceList[i].FBalance)
        else inc(CreateSiblingBalanceList[i].FBalance);
        continue;
      end;
      // rotate
      P := CreateSiblingBalanceList[i];
      if P.FBalance = -2 then begin
        N := P.FLeft;
        if N.FBalance < 0 then begin
          (* ** single rotate ** *)
          (*  []\[]_     _C                []_      C_    _[]
                    N(-1)_     _[]    =>      []_    _P(0)
                          P(-2)                  N(0)           *)
          C := N.FRight;
          N.FRight := P;
          P.FLeft := C;
          N.FBalance := 0;
          P.FBalance := 0;
        end else begin
          (* ** double rotate ** *)
          (*          x1 x2
               []_     _C                  x1    x2
                  N(+1)_     _[]    =>    N _    _ P
                        P(-2)                 C           *)
          C := N.FRight;
          N.FRight := C.FLeft;
          P.FLeft  := C.FRight;
          C.FLeft  := N;
          C.FRight := P;
          // balance
          if (C.FBalance <= 0)
          then N.FBalance := 0
          else N.FBalance := -1;
          if (C.FBalance = -1)
          then P.FBalance := 1
          else P.FBalance := 0;
          C.FBalance := 0;
          N := C;
        end;
      end else begin // *******************
        N := P.FRight;
        if N.FBalance > 0 then begin
          (* ** single rotate ** *)
          C := N.FLeft;
          N.FLeft := P;
          P.FRight := C;
          N.FBalance := 0;
          P.FBalance := 0;
        end else begin
          (* ** double rotate ** *)
          C := N.FLeft;
          N.FLeft := C.FRight;
          P.FRight  := C.FLeft;
          C.FRight  := N;
          C.FLeft := P;
          // balance
          if (C.FBalance >= 0)
          then N.FBalance := 0
          else N.FBalance := +1;
          if (C.FBalance = +1)
          then P.FBalance := -1
          else P.FBalance := 0;
          C.FBalance := 0;
          N := C;
        end;
      end;
      // update parent
      dec(i);
      if i < 0 then begin
        if assigned(self.FParent) then
          self.FParent.FChildren := N
      end else
        if CreateSiblingBalanceList[i].FLeft = P
        then CreateSiblingBalanceList[i].FLeft := N
        else CreateSiblingBalanceList[i].FRight := N;
      break;
    end
  end;
var
  P: TSynCustomCodeFoldBlock;
begin
  Result := self;
  while (assigned(Result)) do begin
    if Result.FBlockType = ABlockType then
      exit;
    P := Result;
    if ABlockType < Result.FBlockType
    then Result := Result.FLeft
    else Result := Result.FRight;
  end;
  // Not Found
  Result := TSynCustomCodeFoldBlock(self.ClassType.Create);
  Result.FBlockType := ABlockType;
  Result.FParent := self.FParent;

  if ABlockType < P.FBlockType then begin
    P.FLeft := Result;
    dec(P.FBalance);
  end else begin
    P.FRight := Result;
    inc(P.FBalance);
  end;

  // Balance
  if P.FBalance <> 0 then
    BalanceNode(P);

end;

destructor TSynCustomCodeFoldBlock.Destroy;
begin
  FreeAndNil(FRight);
  FreeAndNil(FLeft);
  FreeAndNil(FChildren);
  inherited Destroy;
end;

procedure TSynCustomCodeFoldBlock.WriteDebugReport;
  procedure debugout(n: TSynCustomCodeFoldBlock; s1, s: String; p: TSynCustomCodeFoldBlock);
  begin
    if n = nil then exit;
    if n.FParent <> p then
      DebugLn([s1, 'Wrong Parent for', ' (', PtrInt(n), ')']);
    DebugLn([s1, PtrUInt(n.BlockType), ' (', PtrInt(n), ')']);
    debugout(n.FLeft, s+'L: ', s+'   ', p);
    debugout(n.FRight, s+'R: ', s+'   ', p);
    debugout(n.FChildren, s+'C: ', s+'   ', n);
  end;
begin
  debugout(self, '', '', nil);
end;

procedure TSynCustomCodeFoldBlock.InitRootBlockType(AType: Pointer);
begin
  if assigned(FParent) then
    raise Exception.Create('Attempt to modify a FoldBlock');
  FBlockType := AType;
end;

{ TSynCustomHighlighterRange }

constructor TSynCustomHighlighterRange.Create(
  Template: TSynCustomHighlighterRange);
begin
  if (Template<>nil) and (ClassType<>Template.ClassType) then
    RaiseGDBException('');
  if Template<>nil then
    Assign(Template);
end;

destructor TSynCustomHighlighterRange.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TSynCustomHighlighterRange.Compare(Range: TSynCustomHighlighterRange
  ): integer;
begin
  if RangeType < Range.RangeType then
    Result:=1
  else if RangeType > Range.RangeType then
    Result:=-1
  else if Pointer(FTop) < Pointer(Range.FTop) then
    Result:= -1
  else if Pointer(FTop) > Pointer(Range.FTop) then
    Result:= 1
  else
    Result := FMinimumCodeFoldBlockLevel - Range.FMinimumCodeFoldBlockLevel;
  if Result <> 0 then
    exit;
  Result := FCodeFoldStackSize - Range.FCodeFoldStackSize;
end;

function TSynCustomHighlighterRange.Add(ABlockType: Pointer;
  IncreaseLevel: Boolean = True): TSynCustomCodeFoldBlock;
begin
  Result := FTop.Child[ABlockType];
  if IncreaseLevel then
    inc(FCodeFoldStackSize);
  FTop:=Result;
end;

procedure TSynCustomHighlighterRange.Pop(DecreaseLevel: Boolean = True);
// can be called, even if there is no stack
// because it's normal that sources under development have unclosed blocks
begin
  //debugln('TSynCustomHighlighterRange.Pop');
  if assigned(FTop.Parent) then begin
    FTop := FTop.Parent;
    if DecreaseLevel then
      dec(FCodeFoldStackSize);
    if FMinimumCodeFoldBlockLevel > FCodeFoldStackSize then
      FMinimumCodeFoldBlockLevel := FCodeFoldStackSize;
  end;
end;

procedure TSynCustomHighlighterRange.Clear;
begin
  FRangeType:=nil;
  FCodeFoldStackSize := 0;
  FMinimumCodeFoldBlockLevel := 0;
  FTop:=nil;
end;

procedure TSynCustomHighlighterRange.Assign(Src: TSynCustomHighlighterRange);
begin
  if (Src<>nil) and (Src<>TSynCustomHighlighterRange(NullRange)) then begin
    FTop := Src.FTop;
    FCodeFoldStackSize := Src.FCodeFoldStackSize;
    FMinimumCodeFoldBlockLevel := Src.FMinimumCodeFoldBlockLevel;
    FRangeType := Src.FRangeType;
  end
  else begin
    FTop := nil;
    FCodeFoldStackSize := 0;
    FMinimumCodeFoldBlockLevel := 0;
    FRangeType := nil;
  end;
end;

procedure TSynCustomHighlighterRange.WriteDebugReport;
begin
  debugln('TSynCustomHighlighterRange.WriteDebugReport ',DbgSName(Self),
    ' RangeType=',dbgs(RangeType),' StackSize=',dbgs(CodeFoldStackSize));
  debugln(' Block=',dbgs(PtrInt(FTop)));
  FTop.WriteDebugReport;
end;

{ TSynCustomHighlighterRanges }

constructor TSynCustomHighlighterRanges.Create(
  TheHighlighterClass: TSynCustomHighlighterClass);
begin
  Allocate;
  FItems:=TAvgLvlTree.Create(@CompareSynHighlighterRanges);
end;

destructor TSynCustomHighlighterRanges.Destroy;
begin
  if HighlighterRanges<>nil then begin
    HighlighterRanges.Remove(Self);
    if HighlighterRanges.Count=0 then
      FreeAndNil(HighlighterRanges);
  end;
  FItems.FreeAndClear;
  FreeAndNil(FItems);
  inherited Destroy;
end;

function TSynCustomHighlighterRanges.GetEqual(Range: TSynCustomHighlighterRange
  ): TSynCustomHighlighterRange;
var
  Node: TAvgLvlTreeNode;
begin
  if Range=nil then exit(nil);
  Node:=FItems.Find(Range);
  if Node<>nil then begin
    Result:=TSynCustomHighlighterRange(Node.Data);
  end else begin
    // add a copy
    Result:=TSynCustomHighlighterRangeClass(Range.ClassType).Create(Range);
    FItems.Add(Result);
    //if FItems.Count mod 32 = 0 then debugln(['FOLDRANGE Count=', FItems.Count]);
  end;
  //debugln('TSynCustomHighlighterRanges.GetEqual A ',dbgs(Node),' ',dbgs(Result.Compare(Range)),' ',dbgs(Result.CodeFoldStackSize));
end;

procedure TSynCustomHighlighterRanges.Allocate;
begin
  inc(FAllocatedCount);
end;

procedure TSynCustomHighlighterRanges.Release;
begin
  dec(FAllocatedCount);
  if FAllocatedCount=0 then Free;
end;

end.

