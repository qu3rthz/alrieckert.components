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
    Parsing fpc message files.
    FPC prints message IDs with -vq
}
(*
    For example:
general_t_compilername=01000_T_Compiler: $1
% When the \var{-vt} switch is used, this line tells you what compiler
% is used.

<part>_<type>_<txtidentifier>=<id>_<idtype>_<message with plcaeholders>

*)
unit CodeToolsFPCMsgs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileProcs, AVL_Tree;

type

  { TFPCMsgItem }

  TFPCMsgItem = class
  public
    Part: string;
    Typ: string;
    TxtIdentifier: string;
    ID: integer;
    IDTyp: string;
    Msg: string;
    Comment: string; // multi line

    Index: integer; // index in list
  end;

  { TFPCMsgFile }

  TFPCMsgFile = class
  private
    FItems: TFPList; // list of TFPCMsgItem
    fSortedForID: TAVLTree; // tree of TFPCMsgItem sorted for ID
    fItemById: array of TFPCMsgItem;
    function GetItems(Index: integer): TFPCMsgItem;
    procedure CreateArray;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const Filename: string);
    procedure LoadFromList(List: TStrings); virtual;
    procedure Clear; virtual;
    function Count: integer;
    property Items[Index: integer]: TFPCMsgItem read GetItems; default;
    function FindWithID(ID: integer): TFPCMsgItem;
  end;

function CompareFPCMsgId(item1, item2: Pointer): integer;
function CompareIDWithFPCMsgId(PtrID, Item: Pointer): integer;

type
  TFPCMsgRange = record
    StartPos: integer;
    EndPos: integer;
  end;
  PFPCMsgRange = ^TFPCMsgRange;

  { TFPCMsgRanges }

  TFPCMsgRanges = class
  private
    FCount: integer;
    FCapacity: integer;
  public
    Ranges: PFPCMsgRange;
    property Count: integer read FCount;
    property Capacity: integer read FCapacity;
    procedure Add(StartPos, EndPos: integer);
    procedure Clear(FreeMemory: boolean = false);
    destructor Destroy; override;
  end;

procedure ExtractFPCMsgParameters(const Mask, Txt: string; var Ranges: TFPCMsgRanges);

implementation

function CompareFPCMsgId(item1, item2: Pointer): integer;
var
  Msg1: TFPCMsgItem absolute item1;
  Msg2: TFPCMsgItem absolute item2;
begin
  if Msg1.ID<Msg2.ID then
    exit(-1)
  else if Msg1.ID>Msg2.ID then
    exit(1)
  else
    exit(0);
end;

function CompareIDWithFPCMsgId(PtrID, Item: Pointer): integer;
var
  Msg: TFPCMsgItem absolute Item;
  ID: LongInt;
begin
  ID:=PInteger(PtrID)^;
  if ID<Msg.ID then
    exit(-1)
  else if ID>Msg.ID then
    exit(1)
  else
    exit(0);
end;

procedure ExtractFPCMsgParameters(const Mask, Txt: string;
  var Ranges: TFPCMsgRanges);
{ Examples:
   Mask: bla$1blo
   Txt: blatestblo
   Result:=['test']
}

  function FindEndOfNextMatch(MaskStartPos, MaskEndPos, TxtStartPos: PChar): PChar;
  var
    TxtPos: PChar;
    MaskPos: PChar;
  begin
    while TxtStartPos^<>#0 do begin
      TxtPos:=TxtStartPos;
      MaskPos:=MaskStartPos;
      while (MaskPos<MaskEndPos) and (MaskPos^=TxtPos^) do begin
        inc(MaskPos);
        inc(TxtPos);
      end;
      if MaskPos=MaskEndPos then begin
        Result:=TxtPos;
        exit;
      end;
      inc(TxtStartPos);
    end;
    Result:=nil;
  end;

var
  BaseMaskPos: PChar;
  BaseTxtPos: PChar;
  MaskPos: PChar;
  TxtPos: PChar;
  MaskStartPos: PChar;
  TxtEndPos: PChar;
begin
  if Ranges=nil then
    Ranges:=TFPCMsgRanges.Create;
  Ranges.Clear();
  if Mask='' then exit;
  BaseMaskPos:=PChar(Mask);
  if Txt='' then
    BaseTxtPos:=#0
  else
    BaseTxtPos:=PChar(Txt);

  MaskPos:=BaseMaskPos;
  TxtPos:=BaseTxtPos;
  while (MaskPos^=TxtPos^) do begin
    if MaskPos^=#0 then exit;
    if (MaskPos^='$') and (MaskPos[1]<>'$') then break;
    inc(MaskPos);
    inc(TxtPos);
  end;
  while MaskPos^='$' do begin
    // skip variable in mask
    inc(MaskPos);
    while MaskPos^ in ['0'..'9','A'..'Z','a'..'z','_'] do inc(MaskPos);
    // get next pattern in mask
    MaskStartPos:=MaskPos;
    while (MaskPos^<>#0) and (MaskPos^<>'$') do inc(MaskPos);
    if MaskPos^=#0 then begin
      // variable at end of mask
      Ranges.Add(TxtPos-BaseTxtPos,length(Txt)+1);
      exit;
    end;
    // search pattern in txt
    TxtEndPos:=FindEndOfNextMatch(MaskStartPos,MaskPos,TxtPos);
    if TxtEndPos=nil then exit;
    Ranges.Add(TxtPos-BaseTxtPos,TxtEndPos-BaseTxtPos);
    TxtPos:=TxtEndPos;
  end;
end;

{ TFPCMsgFile }

function TFPCMsgFile.GetItems(Index: integer): TFPCMsgItem;
begin
  Result:=TFPCMsgItem(FItems[Index]);
end;

procedure TFPCMsgFile.CreateArray;
var
  MaxID: Integer;
  i: Integer;
  Item: TFPCMsgItem;
begin
  SetLength(fItemById,0);
  if fSortedForID.Count=0 then
    exit;
  MaxID:=TFPCMsgItem(fSortedForID.FindHighest.Data).ID;
  if MaxID>100000 then begin
    debugln(['TFPCMsgFile.CreateArray WARNING: MaxID ',MaxID,' too high']);
    exit;
  end;
  SetLength(fItemById,MaxID+1);
  for i:=0 to length(fItemById)-1 do fItemById[i]:=nil;
  for i:=0 to FItems.Count-1 do begin
    Item:=TFPCMsgItem(FItems[i]);
    fItemById[Item.ID]:=Item;
  end;
end;

constructor TFPCMsgFile.Create;
begin
  FItems:=TFPList.Create;
  fSortedForID:=TAVLTree.Create(@CompareFPCMsgId);
end;

destructor TFPCMsgFile.Destroy;
begin
  Clear;
  FreeAndNil(FItems);
  FreeAndNil(fSortedForID);
  inherited Destroy;
end;

procedure TFPCMsgFile.LoadFromFile(const Filename: string);
var
  sl: TStringList;
begin
  sl:=TStringList.Create;
  try
    sl.LoadFromFile(UTF8ToSys(Filename));
    LoadFromList(sl);
  finally
    sl.Free;
  end;
end;

procedure TFPCMsgFile.LoadFromList(List: TStrings);

  function ReadTilChar(var p: PChar; EndChar: char; out s: string): boolean;
  var
    c: Char;
    StartPos: PChar;
  begin
    StartPos:=p;
    repeat
      c:=p^;
      if c=#0 then exit(false);
      if c=EndChar then begin
        break;
      end;
      inc(p);
    until false;
    if p=StartPos then exit(false);
    SetLength(s,p-StartPos);
    System.Move(StartPos^,s[1],length(s));
    inc(p);
    Result:=true;
  end;

  function ReadItem(var Line: integer; const s: string): TFPCMsgItem;
  // <part>_<typ>_<txtidentifier>=<id>_<idtype>_<message with plcaeholders>
  // options are different:
  //   <part>_<txtidentifier>=<id>_<idtype>_<message with plcaeholders>
  // and
  //   <part>_<txtidentifier>=<id>_[<multi line message with plcaeholders>
  //      ...]
  //
  var
    p: PChar;
    Part: string;
    Typ: string;
    TxtID: string;
    IdTyp: string;
    IDStr: string;
    ID: LongInt;
    Msg: string;
    h: string;
  begin
    Result:=nil;
    p:=PChar(s);
    if not ReadTilChar(p,'_',Part) then begin
      debugln(['TFPCMsgFile.LoadFromList invalid <part>, line ',Line,': "',s,'"']);
      exit;
    end;
    if (Part='option') or (Part='wpo') then
      Typ:=''
    else if not ReadTilChar(p,'_',Typ) then begin
      debugln(['TFPCMsgFile.LoadFromList invalid <type>, line ',Line,': "',s,'"']);
      exit;
    end else if (length(Typ)<>1)
      or (not (Typ[1] in ['f','e','w','n','h','i','l','u','t','c','d','x','o']))
    then begin
      debugln(['TFPCMsgFile.LoadFromList invalid <type>, line ',Line,': "',s,'"']);
      exit;
    end;
    if not ReadTilChar(p,'=',TxtID) then begin
      debugln(['TFPCMsgFile.LoadFromList invalid <textidentifier>, line ',Line,': "',s,'"']);
      exit;
    end;
    if not ReadTilChar(p,'_',IDStr) then begin
      debugln(['TFPCMsgFile.LoadFromList invalid id, line ',Line,': "',s,'"']);
      exit;
    end;
    ID:=StrToIntDef(IDStr,-1);
    if ID<0 then begin
      debugln(['TFPCMsgFile.LoadFromList invalid id, line ',Line,': "',s,'"']);
      exit;
    end;
    IdTyp:='';
    if p<>'[' then begin
      if not ReadTilChar(p,'_',IdTyp) then begin
        debugln(['TFPCMsgFile.LoadFromList invalid urgency, line ',Line,': "',s,'"']);
        exit;
      end;
      Msg:=p;
    end else begin
      // multi line message
      Msg:='';
      repeat
        inc(Line);
        if Line>=List.Count then exit;
        h:=List[Line];
        //debugln(['ReadItem ID=',ID,' h=',h]);
        if (h<>'') and (h=']') then break;
        Msg:=Msg+h+LineEnding;
      until false;
    end;

    Result:=TFPCMsgItem.Create;
    Result.Part:=Part;
    Result.Typ:=Typ;
    Result.TxtIdentifier:=TxtID;
    Result.ID:=ID;
    Result.IDTyp:=IdTyp;
    Result.Msg:=Msg;
    //debugln(['ReadItem Part=',Part,' Typ=',Typ,' TxtID=',TxtID,' ID=',ID,' IdTyp=',IdTyp,' Msg="',copy(Result.Msg,1,20),'"']);
  end;

var
  Line: Integer;
  s: string;
  Item: TFPCMsgItem;
begin
  Clear;
  Line:=0;
  Item:=nil;
  while Line<List.Count do begin
    s:=List[Line];
    if s='' then begin
      // empty line
      Item:=nil;
    end else if s[1]='#' then begin
      // comment
    end else if s[1]='%' then begin
      // item comment
      if Item<>nil then begin
        if Item.Comment<>'' then
          Item.Comment:=Item.Comment+LineEnding;
        Item.Comment:=Item.Comment+copy(s,2,length(s));
      end;
    end else begin
      Item:=ReadItem(Line,s);
      if Item<>nil then begin
        Item.Index:=FItems.Count;
        FItems.Add(Item);
        fSortedForID.Add(Item);
      end;
    end;
    inc(Line);
  end;
  CreateArray;
end;

procedure TFPCMsgFile.Clear;
var
  i: Integer;
begin
  SetLength(fItemById,0);
  fSortedForID.Clear;
  for i:=0 to FItems.Count-1 do
    TObject(FItems[i]).Free;
end;

function TFPCMsgFile.Count: integer;
begin
  Result:=FItems.Count;
end;

function TFPCMsgFile.FindWithID(ID: integer): TFPCMsgItem;
var
  Node: TAVLTreeNode;
begin
  if (ID>=0) and (ID<length(fItemById)) then begin
    Result:=fItemById[ID];
    exit;
  end;
  Node:=fSortedForID.FindKey(@ID,@CompareIDWithFPCMsgId);
  if Node<>nil then
    Result:=TFPCMsgItem(Node.Data)
  else
    Result:=nil;
end;

{ TFPCMsgRanges }

procedure TFPCMsgRanges.Add(StartPos, EndPos: integer);
begin
  if Count=Capacity then begin
    if Capacity<8 then
      fCapacity:=8
    else
      fCapacity:=Capacity*2;
    ReAllocMem(Ranges,Capacity*SizeOf(TFPCMsgRange));
  end;
  Ranges[FCount].StartPos:=StartPos;
  Ranges[FCount].EndPos:=EndPos;
  inc(FCount);
end;

procedure TFPCMsgRanges.Clear(FreeMemory: boolean);
begin
  FCount:=0;
  if not FreeMemory then begin
    ReAllocMem(Ranges,0);
    FCapacity:=0;
  end;
end;

destructor TFPCMsgRanges.Destroy;
begin
  Clear(true);
  inherited Destroy;
end;

end.

