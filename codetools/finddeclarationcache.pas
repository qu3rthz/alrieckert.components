{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.        *
 *                                                                         *
 ***************************************************************************

  Author: Mattias Gaertner

  Abstract:
    Cache objects for TFindDeclarationTool.

}
unit FindDeclarationCache;

{$mode objfpc}{$H+}

interface

{$I codetools.inc}

uses
  Classes, SysUtils, BasicCodeTools, AVL_Tree, CodeTree, LinkScanner,
  PascalParserTool, CodeToolMemManager;

type
  {
    1. interface cache:
      Every FindIdentifierInInterface call is cached
        - stores: Identifier -> Node+CleanPos
        - cache must be deleted, everytime the codetree is rebuild
           this is enough update, because it does only store internals
       -> This will improve search time for interface requests
  }
  PInterfaceIdentCacheEntry = ^TInterfaceIdentCacheEntry;
  TInterfaceIdentCacheEntry = record
    Identifier: PChar;
    Node: TCodeTreeNode; // if node = nil then identifier does not exists in
                         //                    this interface
    CleanPos: integer;
    NextEntry: PInterfaceIdentCacheEntry; // used by memory manager
  end;

  TInterfaceIdentifierCache = class
  private
    FItems: TAVLTree; // tree of TInterfaceIdentCacheEntry
    FTool: TPascalParserTool;
    function FindAVLNode(Identifier: PChar): TAVLTreeNode;
  public
    function FindIdentifier(Identifier: PChar): PInterfaceIdentCacheEntry;
    procedure Add(Identifier: PChar; Node: TCodeTreeNode; CleanPos: integer);
    procedure Clear;
    constructor Create(ATool: TPascalParserTool);
    destructor Destroy; override;
    property Tool: TPascalParserTool read FTool;
  end;

  {
    2. code tree node cache:
      Some nodes (class, proc, record) contain a node cache. A node cache caches
      search results of searched identifiers for child nodes.
      
      Every entry in the node cache describes the following relationship:
        Identifier+Range -> Source Position
      and can be interpreted as:
      Identifier is a PChar to the beginning of an identifier string.
      Range is a clenaed source range (CleanStartPos-CleanEndPos).
      Source position is a tuple of NewTool, NewNode, NewCleanPos.
      If the current context node is a child of a caching node and it is in the
      range, then the result is valid. If NewNode=nil then there is no such
      identifier valid at the context node.

      Every node that define local identifiers contains a node cache.
      These are: class, proc, record, withstatement
      
      Because node caches can store information of used units, the cache must be
      deleted every time a used unit is changed. Currently all node caches are
      resetted every time the GlobalWriteLock increases.

  }
const
  AllNodeCacheDescs = [ctnClass, ctnProcedure, ctnRecordType, ctnWithStatement];
  
type
  PCodeTreeNodeCacheEntry = ^TCodeTreeNodeCacheEntry;
  TCodeTreeNodeCacheEntry = record
    Identifier: PChar;
    CleanStartPos: integer;
    CleanEndPos: integer;
    NewNode: TCodeTreeNode;
    NewTool: TPascalParserTool;
    NewCleanPos: integer;
    NextEntry: PCodeTreeNodeCacheEntry; // used for mem manager
  end;

  TCodeTreeNodeCache = class
  private
    FItems: TAVLTree; // tree of PCodeTreeNodeCacheEntry
  public
    Next: TCodeTreeNodeCache;
    Owner: TCodeTreeNode;
    function FindLeftMostAVLNode(Identifier: PChar): TAVLTreeNode;
    function FindRightMostAVLNode(Identifier: PChar): TAVLTreeNode;
    function FindAVLNode(Identifier: PChar; CleanPos: integer): TAVLTreeNode;
    function FindAVLNodeInRange(Identifier: PChar;
      CleanStartPos, CleanEndPos: integer): TAVLTreeNode;
    function FindInRange(Identifier: PChar;
      CleanStartPos, CleanEndPos: integer): PCodeTreeNodeCacheEntry;
    function FindNearestAVLNode(Identifier: PChar;
      CleanStartPos, CleanEndPos: integer; InFront: boolean): TAVLTreeNode;
    function FindNearest(Identifier: PChar;
      CleanStartPos, CleanEndPos: integer;
      InFront: boolean): PCodeTreeNodeCacheEntry;
    function Find(Identifier: PChar): PCodeTreeNodeCacheEntry;
    procedure Add(Identifier: PChar; CleanStartPos, CleanEndPos: integer;
      NewNode: TCodeTreeNode; NewTool: TPascalParserTool; NewCleanPos: integer);
    procedure Clear;
    procedure BindToOwner(NewOwner: TCodeTreeNode);
    procedure UnbindFromOwner;
    constructor Create(AnOwner: TCodeTreeNode);
    destructor Destroy; override;
    procedure WriteDebugReport(const Prefix: string);
    function ConsistencyCheck: integer;
  end;
  
  {
    3. Base type node cache
    
    ToDo:
  
  }
  TBaseTypeCache = class
  private
  public
    NewNode: TCodeTreeNode;
    NewTool: TPascalParserTool;
    Next: TBaseTypeCache; // used for mem manager
    Owner: TCodeTreeNode;
    procedure BindToOwner(NewOwner: TCodeTreeNode);
    procedure UnbindFromOwner;
    constructor Create(AnOwner: TCodeTreeNode);
    destructor Destroy; override;
  end;


  //----------------------------------------------------------------------------
type
  TGlobalIdentifierTree = class
  private
    FItems: TAVLTree; // tree of PChar;
  public
    function AddCopy(Identifier: PChar): PChar;
    function Find(Identifier: PChar): PChar;
    procedure Clear;
    constructor Create;
    destructor Destroy; override;
  end;

  //----------------------------------------------------------------------------
  // Memory Managers

  // memory system for PInterfaceIdentCacheEntry(s)
  TInterfaceIdentCacheEntryMemManager = class(TCodeToolMemManager)
  protected
    procedure FreeFirstItem; override;
  public
    procedure DisposeEntry(Entry: PInterfaceIdentCacheEntry);
    function NewEntry: PInterfaceIdentCacheEntry;
  end;

  // memory system for PCodeTreeNodeCacheEntry(s)
  TNodeCacheEntryMemManager = class(TCodeToolMemManager)
  protected
    procedure FreeFirstItem; override;
  public
    procedure DisposeEntry(Entry: PCodeTreeNodeCacheEntry);
    function NewEntry: PCodeTreeNodeCacheEntry;
  end;

  // memory system for TCodeTreeNodeCache(s)
  TNodeCacheMemManager = class(TCodeToolMemManager)
  protected
    procedure FreeFirstItem; override;
  public
    procedure DisposeNodeCache(NodeCache: TCodeTreeNodeCache);
    function NewNodeCache(AnOwner: TCodeTreeNode): TCodeTreeNodeCache;
  end;

  // memory system for TBaseTypeCache(s)
  TBaseTypeCacheMemManager = class(TCodeToolMemManager)
  protected
    procedure FreeFirstItem; override;
  public
    procedure DisposeBaseTypeCache(BaseTypeCache: TBaseTypeCache);
    function NewBaseTypeCache(AnOwner: TCodeTreeNode): TBaseTypeCache;
  end;

  //----------------------------------------------------------------------------
  // stacks for circle checking
type
  TCodeTreeNodeStackEntry = TCodeTreeNode;
  PCodeTreeNodeStackEntry = ^TCodeTreeNodeStackEntry;
  
  TCodeTreeNodeStack = record
    Fixedtems: array[0..9] of TCodeTreeNodeStackEntry;
    DynItems: TList; // list of PCodeTreeNodeStackEntry
    StackPtr: integer;
  end;
  PCodeTreeNodeStack = ^TCodeTreeNodeStack;

  procedure InitializeNodeStack(NodeStack: PCodeTreeNodeStack);
  procedure AddNodeToStack(NodeStack: PCodeTreeNodeStack;
    NewNode: TCodeTreeNode);
  function NodeExistsInStack(NodeStack: PCodeTreeNodeStack;
    Node: TCodeTreeNode): boolean;
  procedure FinalizeNodeStack(NodeStack: PCodeTreeNodeStack);

var
  GlobalIdentifierTree: TGlobalIdentifierTree;
  InterfaceIdentCacheEntryMemManager: TInterfaceIdentCacheEntryMemManager;
  NodeCacheEntryMemManager: TNodeCacheEntryMemManager;
  NodeCacheMemManager: TNodeCacheMemManager;
  BaseTypeCacheMemManager: TBaseTypeCacheMemManager;

implementation


{ TNodeCacheEntryMemManager }

procedure TNodeCacheEntryMemManager.DisposeEntry(Entry: PCodeTreeNodeCacheEntry);
begin
  if (FFreeCount<FMinFree) or (FFreeCount<((FCount shr 3)*FMaxFreeRatio)) then
  begin
    // add Entry to Free list
    Entry^.NextEntry:=PCodeTreeNodeCacheEntry(FFirstFree);
    PCodeTreeNodeCacheEntry(FFirstFree):=Entry;
    inc(FFreeCount);
  end else begin
    // free list full -> free the Entry
    Dispose(Entry);
    inc(FFreedCount);
  end;
  dec(FCount);
end;

function TNodeCacheEntryMemManager.NewEntry: PCodeTreeNodeCacheEntry;
begin
  if FFirstFree<>nil then begin
    // take from free list
    Result:=PCodeTreeNodeCacheEntry(FFirstFree);
    PCodeTreeNodeCacheEntry(FFirstFree):=Result^.NextEntry;
    Result^.NextEntry:=nil;
    dec(FFreeCount);
  end else begin
    // free list empty -> create new Entry
    New(Result);
    inc(FAllocatedCount);
  end;
  inc(FCount);
end;

procedure TNodeCacheEntryMemManager.FreeFirstItem;
var Entry: PCodeTreeNodeCacheEntry;
begin
  Entry:=PCodeTreeNodeCacheEntry(FFirstFree);
  PCodeTreeNodeCacheEntry(FFirstFree):=Entry^.NextEntry;
  Dispose(Entry);
end;


{ TInterfaceIdentCacheEntryMemManager }

procedure TInterfaceIdentCacheEntryMemManager.DisposeEntry(
  Entry: PInterfaceIdentCacheEntry);
begin
  if (FFreeCount<FMinFree) or (FFreeCount<((FCount shr 3)*FMaxFreeRatio)) then
  begin
    // add Entry to Free list
    Entry^.NextEntry:=PInterfaceIdentCacheEntry(FFirstFree);
    PInterfaceIdentCacheEntry(FFirstFree):=Entry;
    inc(FFreeCount);
  end else begin
    // free list full -> free the Entry
    Dispose(Entry);
    inc(FFreedCount);
  end;
  dec(FCount);
end;

function TInterfaceIdentCacheEntryMemManager.NewEntry: PInterfaceIdentCacheEntry;
begin
  if FFirstFree<>nil then begin
    // take from free list
    Result:=PInterfaceIdentCacheEntry(FFirstFree);
    PInterfaceIdentCacheEntry(FFirstFree):=Result^.NextEntry;
    Result^.NextEntry:=nil;
    dec(FFreeCount);
  end else begin
    // free list empty -> create new Entry
    New(Result);
    inc(FAllocatedCount);
  end;
  inc(FCount);
end;

procedure TInterfaceIdentCacheEntryMemManager.FreeFirstItem;
var Entry: PInterfaceIdentCacheEntry;
begin
  Entry:=PInterfaceIdentCacheEntry(FFirstFree);
  PInterfaceIdentCacheEntry(FFirstFree):=Entry^.NextEntry;
  Dispose(Entry);
end;


{ TInterfaceIdentifierCache }

function CompareTInterfaceIdentCacheEntry(Data1, Data2: Pointer): integer;
begin
  Result:=CompareIdentifiers(PInterfaceIdentCacheEntry(Data1)^.Identifier,
                             PInterfaceIdentCacheEntry(Data2)^.Identifier);
end;


procedure TInterfaceIdentifierCache.Clear;
var
  Node: TAVLTreeNode;
  Entry: PInterfaceIdentCacheEntry;
begin
  if FItems<>nil then begin
    Node:=FItems.FindLowest;
    while Node<>nil do begin
      Entry:=PInterfaceIdentCacheEntry(Node.Data);
      InterfaceIdentCacheEntryMemManager.DisposeEntry(Entry);
      Node:=FItems.FindSuccessor(Node);
    end;
    FItems.Clear;
  end;
end;

constructor TInterfaceIdentifierCache.Create(ATool: TPascalParserTool);
begin
  inherited Create;
  FTool:=ATool;
  if ATool=nil then
    raise Exception.Create('TInterfaceIdentifierCache.Create ATool=nil');
end;

destructor TInterfaceIdentifierCache.Destroy;
begin
  Clear;
  if FItems<>nil then FItems.Free;
  inherited Destroy;
end;

function TInterfaceIdentifierCache.FindAVLNode(Identifier: PChar): TAVLTreeNode;
var
  Entry: PInterfaceIdentCacheEntry;
  comp: integer;
begin
  if FItems<>nil then begin
    Result:=FItems.Root;
    while Result<>nil do begin
      Entry:=PInterfaceIdentCacheEntry(Result.Data);
      comp:=CompareIdentifiers(Identifier,Entry^.Identifier);
      if comp<0 then
        Result:=Result.Left
      else if comp>0 then
        Result:=Result.Right
      else
        exit;
    end;
  end else begin
    Result:=nil;
  end;
end;

function TInterfaceIdentifierCache.FindIdentifier(Identifier: PChar
  ): PInterfaceIdentCacheEntry;
var Node: TAVLTreeNode;
begin
  Node:=FindAVLNode(Identifier);
  if Node<>nil then
    Result:=PInterfaceIdentCacheEntry(Node.Data)
  else
    Result:=nil;
end;

procedure TInterfaceIdentifierCache.Add(Identifier: PChar; Node: TCodeTreeNode;
  CleanPos: integer);
var
  NewEntry: PInterfaceIdentCacheEntry;
begin
  if FItems=nil then
    FItems:=TAVLTree.Create(@CompareTInterfaceIdentCacheEntry);
  NewEntry:=InterfaceIdentCacheEntryMemManager.NewEntry;
  NewEntry^.Identifier:=GlobalIdentifierTree.AddCopy(Identifier);
  NewEntry^.Node:=Node;
  NewEntry^.CleanPos:=CleanPos;
  FItems.Add(NewEntry);
end;


{ TGlobalIdentifierTree }

procedure TGlobalIdentifierTree.Clear;
var Node: TAVLTreeNode;
begin
  if FItems<>nil then begin
    Node:=FItems.FindLowest;
    while Node<>nil do begin
      FreeMem(Node.Data);
      Node:=FItems.FindSuccessor(Node);
    end;
    FItems.Clear;
  end;
end;

constructor TGlobalIdentifierTree.Create;
begin
  inherited Create;
end;

destructor TGlobalIdentifierTree.Destroy;
begin
  Clear;
  FItems.Free;
  inherited Destroy;
end;

function TGlobalIdentifierTree.AddCopy(Identifier: PChar): PChar;
var Len: integer;
begin
  Result:=nil;
  if (Identifier=nil) or (not IsIdentChar[Identifier[0]]) then exit;
  Result:=Find(Identifier);
  if Result<>nil then
    exit;
  Len:=0;
  while IsIdentChar[Identifier[Len]] do inc(Len);
  GetMem(Result,Len+1);
  Move(Identifier^,Result^,Len+1);
  if FItems=nil then
    FItems:=TAVLTree.Create(TListSortCompare(@CompareIdentifiers));
  FItems.Add(Result);
end;

function TGlobalIdentifierTree.Find(Identifier: PChar): PChar;
var
  comp: integer;
  Node: TAVLTreeNode;
begin
  Result:=nil;
  if FItems<>nil then begin
    Node:=FItems.Root;
    while Result<>nil do begin
      Result:=PChar(Node.Data);
      comp:=CompareIdentifiers(Identifier,Result);
      if comp<0 then
        Node:=Node.Left
      else if comp>0 then
        Node:=Node.Right
      else
        exit;
    end;
  end;
end;


{ TCodeTreeNodeCache }

function CompareTCodeTreeNodeCacheEntry(Data1, Data2: Pointer): integer;
var Entry1, Entry2: PCodeTreeNodeCacheEntry;
begin
  Entry1:=PCodeTreeNodeCacheEntry(Data1);
  Entry2:=PCodeTreeNodeCacheEntry(Data2);
  Result:=CompareIdentifiers(Entry1^.Identifier,Entry2^.Identifier);
  if Result=0 then begin
    if Entry1^.CleanStartPos>Entry2^.CleanStartPos then
      Result:=-1
    else if Entry1^.CleanStartPos<Entry2^.CleanStartPos then
      Result:=1
    else
      Result:=0;
  end;
end;

constructor TCodeTreeNodeCache.Create(AnOwner: TCodeTreeNode);
begin
  inherited Create;
  if AnOwner<>nil then BindToOwner(AnOwner);
end;

destructor TCodeTreeNodeCache.Destroy;
begin
  Clear;
  UnbindFromOwner;
  inherited Destroy;
end;

function TCodeTreeNodeCache.FindLeftMostAVLNode(Identifier: PChar): TAVLTreeNode;
// find leftmost avl node with Identifier
var
  Entry: PCodeTreeNodeCacheEntry;
  Node: TAVLTreeNode;
  comp: integer;
begin
  if FItems<>nil then begin
    Result:=FItems.Root;
    while Result<>nil do begin
      Entry:=PCodeTreeNodeCacheEntry(Result.Data);
      comp:=CompareIdentifiers(Identifier,Entry^.Identifier);
      if comp<0 then
        Result:=Result.Left
      else if comp>0 then
        Result:=Result.Right
      else begin
        repeat
          Node:=FItems.FindPrecessor(Result);
          if Node<>nil then begin
            Entry:=PCodeTreeNodeCacheEntry(Node.Data);
            if CompareIdentifiers(Identifier,Entry^.Identifier)=0 then
              Result:=Node
            else
              break;
          end else
            break;
        until false;
        exit;
      end;
    end;
  end else begin
    Result:=nil;
  end;
end;

procedure TCodeTreeNodeCache.Clear;
var
  Node: TAVLTreeNode;
  Entry: PCodeTreeNodeCacheEntry;
begin
  if FItems<>nil then begin
    Node:=FItems.FindLowest;
    while Node<>nil do begin
      Entry:=PCodeTreeNodeCacheEntry(Node.Data);
      NodeCacheEntryMemManager.DisposeEntry(Entry);
      Node:=FItems.FindSuccessor(Node);
    end;
    FItems.Clear;
  end;
end;

procedure TCodeTreeNodeCache.Add(Identifier: PChar;
  CleanStartPos, CleanEndPos: integer;
  NewNode: TCodeTreeNode; NewTool: TPascalParserTool; NewCleanPos: integer);

  procedure AddNewEntry;
  var NewEntry: PCodeTreeNodeCacheEntry;
  begin
    NewEntry:=NodeCacheEntryMemManager.NewEntry;
    NewEntry^.Identifier:=GlobalIdentifierTree.AddCopy(Identifier);
    NewEntry^.CleanStartPos:=CleanStartPos;
    NewEntry^.CleanEndPos:=CleanEndPos;
    NewEntry^.NewNode:=NewNode;
    NewEntry^.NewTool:=NewTool;
    NewEntry^.NewCleanPos:=NewCleanPos;
    FItems.Add(NewEntry);
  end;

var
  OldEntry: PCodeTreeNodeCacheEntry;
  OldNode: TAVLTreeNode;
begin
  if CleanStartPos>=CleanEndPos then
    raise Exception.Create('[TCodeTreeNodeCache.Add] internal error:'
      +' CleanStartPos>=CleanEndPos');
  if FItems=nil then
    FItems:=TAVLTree.Create(@CompareTCodeTreeNodeCacheEntry);
  // if identifier already exists, try to combine them
  OldNode:=FindAVLNodeInRange(Identifier,CleanStartPos,CleanEndPos);
  if OldNode=nil then begin
    // identifier was never searched in this range
    AddNewEntry;
  end else begin
    // identifier was already searched in this range
    OldEntry:=PCodeTreeNodeCacheEntry(OldNode.Data);
    if (NewNode=OldEntry^.NewNode)
    and (NewTool=OldEntry^.NewTool) then
    begin
      // same FindContext with connected search ranges
      // -> combine search ranges
      if OldEntry^.CleanStartPos>CleanStartPos then
        OldEntry^.CleanStartPos:=CleanStartPos;
      if OldEntry^.CleanEndPos<CleanEndPos then
        OldEntry^.CleanEndPos:=CleanEndPos;
    end else begin
      // different FindContext with connected search ranges
      if (OldEntry^.CleanStartPos=CleanEndPos)
      or (OldEntry^.CleanEndPos=CleanStartPos) then begin
        // add new entry
        AddNewEntry;
      end else begin
        raise Exception.Create('[TCodeTreeNodeCache.Add] internal error:'
          +' conflicting cache nodes');
      end;
    end;
  end;
end;

function TCodeTreeNodeCache.Find(Identifier: PChar): PCodeTreeNodeCacheEntry;
var Node: TAVLTreeNode;
begin
  Node:=FindLeftMostAVLNode(Identifier);
  if Node<>nil then begin
    Result:=PCodeTreeNodeCacheEntry(Node.Data);
  end else begin
    Result:=nil;
  end;
end;

function TCodeTreeNodeCache.FindAVLNode(Identifier: PChar; CleanPos: integer
  ): TAVLTreeNode;
begin
  Result:=FindAVLNodeInRange(Identifier,CleanPos,CleanPos);
end;

function TCodeTreeNodeCache.FindRightMostAVLNode(Identifier: PChar
  ): TAVLTreeNode;
// find rightmost avl node with Identifier
var
  Entry: PCodeTreeNodeCacheEntry;
  Node: TAVLTreeNode;
  comp: integer;
begin
  if FItems<>nil then begin
    Result:=FItems.Root;
    while Result<>nil do begin
      Entry:=PCodeTreeNodeCacheEntry(Result.Data);
      comp:=CompareIdentifiers(Identifier,Entry^.Identifier);
      if comp<0 then
        Result:=Result.Left
      else if comp>0 then
        Result:=Result.Right
      else begin
        repeat
          Node:=FItems.FindSuccessor(Result);
          if Node<>nil then begin
            Entry:=PCodeTreeNodeCacheEntry(Node.Data);
            if CompareIdentifiers(Identifier,Entry^.Identifier)=0 then
              Result:=Node
            else
              break;
          end else
            break;
        until false;
        exit;
      end;
    end;
  end else begin
    Result:=nil;
  end;
end;

function TCodeTreeNodeCache.FindAVLNodeInRange(Identifier: PChar;
  CleanStartPos, CleanEndPos: integer): TAVLTreeNode;
var
  Entry: PCodeTreeNodeCacheEntry;
begin
  Result:=FindNearestAVLNode(Identifier,CleanStartPos,CleanEndPos,true);
  if Result<>nil then begin
    Entry:=PCodeTreeNodeCacheEntry(Result.Data);
    if (CleanStartPos>Entry^.CleanEndPos)
    or (CleanEndPos<Entry^.CleanStartPos) then begin
      // node is not in range
      Result:=nil;
    end;
  end;
end;

function TCodeTreeNodeCache.FindNearestAVLNode(Identifier: PChar;
  CleanStartPos, CleanEndPos: integer; InFront: boolean): TAVLTreeNode;
var
  Entry: PCodeTreeNodeCacheEntry;
  comp: integer;
  DirectionSucc: boolean;
  NextNode: TAVLTreeNode;
begin
  if CleanStartPos>CleanEndPos then begin
    raise Exception.Create('[TCodeTreeNodeCache.FindNearestAVLNode]'
      +' internal error: CleanStartPos>CleanEndPos');
  end;
  if FItems<>nil then begin
    Result:=FItems.Root;
    while Result<>nil do begin
      Entry:=PCodeTreeNodeCacheEntry(Result.Data);
      comp:=CompareIdentifiers(Identifier,Entry^.Identifier);
      if comp<0 then
        Result:=Result.Left
      else if comp>0 then
        Result:=Result.Right
      else begin
        // cached result with identifier found
        // -> check range
        if CleanStartPos>=Entry^.CleanEndPos then begin
          NextNode:=FItems.FindSuccessor(Result);
          DirectionSucc:=true;
        end else if CleanEndPos<=Entry^.CleanStartPos then begin
          NextNode:=FItems.FindPrecessor(Result);
          DirectionSucc:=false;
        end else begin
          // cached result in range found
          exit;
        end;
        while (NextNode<>nil) do begin
          Entry:=PCodeTreeNodeCacheEntry(NextNode.Data);
          if CompareIdentifiers(Identifier,Entry^.Identifier)<>0 then begin
            exit;
          end;
          Result:=NextNode;
          if (CleanStartPos<Entry^.CleanEndPos)
          and (CleanEndPos>Entry^.CleanStartPos) then begin
            // cached result in range found
            exit;
          end;
          if DirectionSucc then
            NextNode:=FItems.FindSuccessor(Result)
          else
            NextNode:=FItems.FindPrecessor(Result);
        end;
        exit;
      end;
    end;
  end else begin
    Result:=nil;
  end;
end;

function TCodeTreeNodeCache.ConsistencyCheck: integer;
begin
  if (FItems<>nil) then begin
    Result:=FItems.ConsistencyCheck;
    if Result<>0 then begin
      dec(Result,100);
      exit;
    end;
  end;
  if Owner<>nil then begin
    if Owner.Cache<>Self then begin
      Result:=-1;
      exit;
    end;
  end;
  Result:=0;
end;

procedure TCodeTreeNodeCache.WriteDebugReport(const Prefix: string);
var Node: TAVLTreeNode;
  Entry: PCodeTreeNodeCacheEntry;
begin
  writeln(Prefix,'[TCodeTreeNodeCache.WriteDebugReport] Self=',
    HexStr(Cardinal(Self),8),' Consistency=',ConsistencyCheck);
  if FItems<>nil then begin
    Node:=FItems.FindLowest;
    while Node<>nil do begin
      Entry:=PCodeTreeNodeCacheEntry(Node.Data);
      write(Prefix,' Ident="',GetIdentifier(Entry^.Identifier),'"');
      writeln('');
      Node:=FItems.FindSuccessor(Node);
    end;
  end;
end;

procedure TCodeTreeNodeCache.UnbindFromOwner;
begin
  if Owner<>nil then begin
    if Owner.Cache<>Self then
      raise Exception.Create('[TCodeTreeNodeCache.UnbindFromOwner] '
        +' internal error: Owner.Cache<>Self');
    Owner.Cache:=nil;
    Owner:=nil;
  end;
end;

procedure TCodeTreeNodeCache.BindToOwner(NewOwner: TCodeTreeNode);
begin
  if NewOwner<>nil then begin
    if NewOwner.Cache<>nil then
      raise Exception.Create('[TCodeTreeNodeCache.BindToOwner] internal error:'
        +' NewOwner.Cache<>nil');
    NewOwner.Cache:=Self;
  end;
  Owner:=NewOwner;
end;

function TCodeTreeNodeCache.FindNearest(Identifier: PChar; CleanStartPos,
  CleanEndPos: integer; InFront: boolean): PCodeTreeNodeCacheEntry;
var Node: TAVLTreeNode;
begin
  Node:=FindNearestAVLNode(Identifier,CleanStartPos,CleanEndPos,InFront);
  if Node<>nil then
    Result:=PCodeTreeNodeCacheEntry(Node.Data)
  else
    Result:=nil;
end;

function TCodeTreeNodeCache.FindInRange(Identifier: PChar; CleanStartPos,
  CleanEndPos: integer): PCodeTreeNodeCacheEntry;
var Node: TAVLTreeNode;
begin
  Node:=FindAVLNodeInRange(Identifier,CleanStartPos,CleanEndPos);
  if Node<>nil then
    Result:=PCodeTreeNodeCacheEntry(Node.Data)
  else
    Result:=nil;
end;

{ TNodeCacheMemManager }

procedure TNodeCacheMemManager.DisposeNodeCache(NodeCache: TCodeTreeNodeCache);
begin
  if (FFreeCount<FMinFree) or (FFreeCount<((FCount shr 3)*FMaxFreeRatio)) then
  begin
    // add Entry to Free list
    NodeCache.Next:=TCodeTreeNodeCache(FFirstFree);
    TCodeTreeNodeCache(FFirstFree):=NodeCache;
    NodeCache.UnbindFromOwner;
    inc(FFreeCount);
  end else begin
    // free list full -> free the NodeCache
    NodeCache.Free;
    inc(FFreedCount);
  end;
  dec(FCount);
end;

procedure TNodeCacheMemManager.FreeFirstItem;
var NodeCache: TCodeTreeNodeCache;
begin
  NodeCache:=TCodeTreeNodeCache(FFirstFree);
  TCodeTreeNodeCache(FFirstFree):=NodeCache.Next;
  NodeCache.Free;
end;

function TNodeCacheMemManager.NewNodeCache(
  AnOwner: TCodeTreeNode): TCodeTreeNodeCache;
begin
  if FFirstFree<>nil then begin
    // take from free list
    Result:=TCodeTreeNodeCache(FFirstFree);
    TCodeTreeNodeCache(FFirstFree):=Result.Next;
    Result.Clear;
    Result.Owner:=AnOwner;
    dec(FFreeCount);
  end else begin
    // free list empty -> create new NodeCache
    Result:=TCodeTreeNodeCache.Create(AnOwner);
    inc(FAllocatedCount);
  end;
  inc(FCount);
end;

//------------------------------------------------------------------------------

procedure InitializeNodeStack(NodeStack: PCodeTreeNodeStack);
begin
  NodeStack^.StackPtr:=0;
  NodeStack^.DynItems:=nil;
end;

procedure AddNodeToStack(NodeStack: PCodeTreeNodeStack;
  NewNode: TCodeTreeNode);
begin
  if (NodeStack^.StackPtr<=High(NodeStack^.Fixedtems)) then begin
    NodeStack^.Fixedtems[NodeStack^.StackPtr]:=NewNode;
  end else begin
    if NodeStack^.DynItems=nil then begin
      NodeStack^.DynItems:=TList.Create;
    end;
    NodeStack^.DynItems.Add(NewNode);
  end;
  inc(NodeStack^.StackPtr);
end;

function NodeExistsInStack(NodeStack: PCodeTreeNodeStack;
  Node: TCodeTreeNode): boolean;
var i: integer;
begin
  Result:=true;
  i:=0;
  while i<NodeStack^.StackPtr do begin
    if i<=High(NodeStack^.Fixedtems) then begin
      if NodeStack^.Fixedtems[i]=Node then exit;
    end else begin
      if NodeStack^.DynItems[i-High(NodeStack^.Fixedtems)-1]=Pointer(Node) then
        exit;
    end;
    inc(i);
  end;
  Result:=false;
end;

procedure FinalizeNodeStack(NodeStack: PCodeTreeNodeStack);
begin
  NodeStack^.DynItems.Free;
end;


{ TBaseTypeCacheMemManager }

procedure TBaseTypeCacheMemManager.DisposeBaseTypeCache(
  BaseTypeCache: TBaseTypeCache);
begin
  if (FFreeCount<FMinFree) or (FFreeCount<((FCount shr 3)*FMaxFreeRatio)) then
  begin
    // add Entry to Free list
    BaseTypeCache.Next:=TBaseTypeCache(FFirstFree);
    TBaseTypeCache(FFirstFree):=BaseTypeCache;
    BaseTypeCache.UnbindFromOwner;
    inc(FFreeCount);
  end else begin
    // free list full -> free the BaseType
    BaseTypeCache.Free;
    inc(FFreedCount);
  end;
  dec(FCount);
end;

procedure TBaseTypeCacheMemManager.FreeFirstItem;
var BaseTypeCache: TBaseTypeCache;
begin
  BaseTypeCache:=TBaseTypeCache(FFirstFree);
  TBaseTypeCache(FFirstFree):=BaseTypeCache.Next;
  BaseTypeCache.Free;
end;

function TBaseTypeCacheMemManager.NewBaseTypeCache(
  AnOwner: TCodeTreeNode): TBaseTypeCache;
begin
  if FFirstFree<>nil then begin
    // take from free list
    Result:=TBaseTypeCache(FFirstFree);
    TBaseTypeCache(FFirstFree):=Result.Next;
    Result.Owner:=AnOwner;
    dec(FFreeCount);
  end else begin
    // free list empty -> create new BaseType
    Result:=TBaseTypeCache.Create(AnOwner);
    inc(FAllocatedCount);
  end;
  inc(FCount);
end;

//------------------------------------------------------------------------------

procedure InternalInit;
begin
  GlobalIdentifierTree:=TGlobalIdentifierTree.Create;
  InterfaceIdentCacheEntryMemManager:=TInterfaceIdentCacheEntryMemManager.Create;
  NodeCacheEntryMemManager:=TNodeCacheEntryMemManager.Create;
  NodeCacheMemManager:=TNodeCacheMemManager.Create;
  BaseTypeCacheMemManager:=TBaseTypeCacheMemManager.Create;
end;

procedure InternalFinal;
begin
  GlobalIdentifierTree.Free;
  GlobalIdentifierTree:=nil;
  InterfaceIdentCacheEntryMemManager.Free;
  InterfaceIdentCacheEntryMemManager:=nil;
  NodeCacheEntryMemManager.Free;
  NodeCacheEntryMemManager:=nil;
  NodeCacheMemManager.Free;
  NodeCacheMemManager:=nil;
  BaseTypeCacheMemManager.Free;
  BaseTypeCacheMemManager:=nil;
end;

{ TBaseTypeCache }

procedure TBaseTypeCache.BindToOwner(NewOwner: TCodeTreeNode);
begin
  if NewOwner<>nil then begin
    if NewOwner.Cache<>nil then
      raise Exception.Create('[TBaseTypeCache.BindToOwner] internal error:'
        +' NewOwner.Cache<>nil');
    NewOwner.Cache:=Self;
  end;
  Owner:=NewOwner;
end;

constructor TBaseTypeCache.Create(AnOwner: TCodeTreeNode);
begin
  inherited Create;
  if AnOwner<>nil then BindToOwner(AnOwner);
end;

destructor TBaseTypeCache.Destroy;
begin
  UnbindFromOwner;
  inherited Destroy;
end;

procedure TBaseTypeCache.UnbindFromOwner;
begin
  if Owner<>nil then begin
    if Owner.Cache<>Self then
      raise Exception.Create('[TBaseTypeCache.UnbindFromOwner] '
        +' internal error: Owner.Cache<>Self');
    Owner.Cache:=nil;
    Owner:=nil;
  end;
end;

initialization
  InternalInit;

finalization
  InternalFinal;


end.

