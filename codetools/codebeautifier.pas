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
    Functions to beautify code.
    Goals:
      - Customizable
      - fully automatic
      - Beautification of whole sources. For example a unit, or several
        sources.
      - Beautification of parts of sources. For example selections.
      - Beautification of insertion source. For example beautifying code, that
        will be inserted in another source.
      - Working with syntax errors. The beautification will try its best to
        work, even if the source contains errors.
      - Does not ignore comments and directives
      - Contexts: statements, declarations

  Line break:
    1. indent to the smallest indent
       For example, when there is always an indent after 'try':
         try|
           |
       For example when sometimes no indent is after 'then':
         if expr then|
         |
   2.  unindent when block was closed
       For example after closing blocks with a semicolon:
         if expr then
           if expr then
             doit;|
         |
   3.  optional 'UseLineStart': when next token in line closes block:
         repeat|
         |until
       When 'until' is not current line, ignore it:
         repeat|
           |
         until
       Closing the corresponding block, not all blocks:
         if expr then
           if expr then begin|
           |end

  Examples for beautification styles: see scanexamples/indentation.pas

  ToDo:
    * LineBreak:
      - indent last line after pressing return key:
          if true then
          exit;|
          |
    * long lines
       DoSomething(Param1,
                   Param2);
}
unit CodeBeautifier;

{$mode objfpc}{$H+}

interface

{ $DEFINE ShowCodeBeautifier}
{ $DEFINE ShowCodeBeautifierParser}
{ $DEFINE ShowCodeBeautifierLearn}
{ $DEFINE VerboseIndenter}

{$IFDEF ShowCodeBeautifierParser}
{$DEFINE ShowCodeBeautifierLearn}
{$ENDIF}

uses
  Classes, SysUtils, AVL_Tree, FileProcs, KeywordFuncLists, CodeCache,
  BasicCodeTools;
  
type
  TWordPolicy = (
    wpNone,
    wpLowerCase,
    wpUpperCase,
    wpLowerCaseFirstLetterUp
    );

  TFABBlockType = (
    bbtNone,
    // code sections
    bbtInterface,
    bbtImplementation,
    bbtInitialization,
    bbtFinalization,
    // identifier sections
    bbtUsesSection,
    bbtTypeSection,
    bbtConstSection,
    bbtVarSection,
    bbtResourceStringSection,
    bbtLabelSection,
    bbtDefinition,  // child of bbtTypeSection,bbtConstSection,bbtVarSection,bbtResourceStringSection,bbtLabelSection
    // type blocks
    bbtRecord,
    bbtClass,
    bbtClassInterface,
    bbtClassSection, // public, private, protected, published
    bbtTypeRoundBracket,
    bbtTypeEdgedBracket,
    // statement blocks
    bbtProcedure, // procedure, constructor, destructor
    bbtFunction,  // function, operator
    bbtProcedureHead,      // child of bbtProcedure or bbtFunction
    bbtProcedureParamList, // child of bbtProcedureHead
    bbtProcedureModifiers, // child of bbtProcedureHead
    bbtProcedureBegin,     // child of bbtProcedure or bbtFunction
    bbtMainBegin,
    bbtFreeBegin, // begin without need (e.g. without if-then)
    bbtRepeat,
    bbtCase,
    bbtCaseOf,    // child of bbtCase
    bbtCaseColon, // child of bbtCase
    bbtCaseBegin, // child of bbtCaseColon
    bbtCaseElse,  // child of bbtCase
    bbtTry,
    bbtFinally,
    bbtExcept,
    bbtIf,
    bbtIfThen,    // child of bbtIf
    bbtIfElse,    // child of bbtIf
    bbtIfBegin,   // child of bbtIfThen or bbtIfElse
    bbtStatement,
    bbtStatementRoundBracket,
    bbtStatementEdgedBracket
    );
  TFABBlockTypes = set of TFABBlockType;

const
  bbtAllIdentifierSections = [bbtTypeSection,bbtConstSection,bbtVarSection,
       bbtResourceStringSection,bbtLabelSection];
  bbtAllProcedures = [bbtProcedure,bbtFunction];
  bbtAllCodeSections = [bbtInterface,bbtImplementation,bbtInitialization,
                        bbtFinalization];
  bbtAllStatementParents = [bbtMainBegin,bbtFreeBegin,bbtProcedureBegin,
                        bbtRepeat,
                        bbtCaseColon,bbtCaseBegin,bbtCaseElse,
                        bbtTry,bbtFinally,bbtExcept,
                        bbtIfThen,bbtIfElse,bbtIfBegin];
  bbtAllStatements = bbtAllStatementParents+[
                      bbtStatement,bbtStatementRoundBracket,bbtStatementEdgedBracket];
  bbtAllBrackets = [bbtTypeRoundBracket,bbtTypeEdgedBracket,
                    bbtStatementRoundBracket,bbtStatementEdgedBracket];
const
  FABBlockTypeNames: array[TFABBlockType] of string = (
    'bbtNone',
    // code sections
    'bbtInterface',
    'bbtImplementation',
    'bbtInitialization',
    'bbtFinalization',
    // identifier sections
    'bbtUsesSection',
    'bbtTypeSection',
    'bbtConstSection',
    'bbtVarSection',
    'bbtResourceStringSection',
    'bbtLabelSection',
    'bbtDefinition',
    // type blocks
    'bbtRecord',
    'bbtClass',
    'bbtClassInterface',
    'bbtClassSection',
    'bbtTypeRoundBracket',
    'bbtTypeEdgedBracket',
    // statement blocks
    'bbtProcedure',
    'bbtFunction',
    'bbtProcedureHead',
    'bbtProcedureParamList',
    'bbtProcedureModifiers',
    'bbtProcedureBegin',
    'bbtMainBegin',
    'bbtFreeBegin',
    'bbtRepeat',
    'bbtCase',
    'bbtCaseOf',
    'bbtCaseColon',
    'bbtCaseBegin',
    'bbtCaseElse',
    'bbtTry',
    'bbtFinally',
    'bbtExcept',
    'bbtIf',
    'bbtIfThen',
    'bbtIfElse',
    'bbtIfBegin',
    'bbtStatement',
    'bbtStatementRoundBracket',
    'bbtStatementEdgedBracket'
    );

type
  TOnGetFABExamples = procedure(Sender: TObject; Code: TCodeBuffer;
                                Step: integer; // starting at 0
                                var CodeBuffers: TFPList; // stopping when CodeBuffers=nil
                                var ExpandedFilenames: TStrings  // and ExpandedFilenames=nil
                                ) of object;
  TOnGetFABNestedComments = procedure(Sender: TObject; Code: TCodeBuffer;
                                      out NestedComments: boolean) of object;
  TOnGetFABFile = procedure(Sender: TObject; const ExpandedFilename: string;
                            out Code: TCodeBuffer; var Abort: boolean) of object;

  TFABIndentationPolicy = record
    Indent: integer;
    IndentValid: boolean;
  end;

  TFABFoundIndentationPolicy = packed record
    Typ, SubTyp: TFABBlockType;
    Indent: integer;
  end;
  PFABFoundIndentationPolicy = ^TFABFoundIndentationPolicy;

  { TFABPolicies }

  TFABPolicies = class
  private
    function FindIndentation(Typ, SubType: TFABBlockType;
                             out InsertPos: integer): boolean;
  public
    IndentationCount, IndentationCapacity: integer;
    Indentations: PFABFoundIndentationPolicy;
    Code: TCodeBuffer;
    CodeChangeStep: integer;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure AddIndent(Typ, SubType: TFABBlockType; SrcPos, Indent: integer);
    function GetSmallestIndent(Typ: TFABBlockType): integer;// -1 if none found
    function GetIndent(Typ, SubType: TFABBlockType;
                       UseNoneIfNotFound: boolean;
                       UseSmallestIfNotFound: boolean): integer;// -1 if none found
    function CodePosToStr(p: integer): string;
  end;

type
  TBlock = record
    Typ: TFABBlockType;
    StartPos: integer;
    InnerStartPos: integer;
    InnerIdent: integer; // valid if >=0
  end;
  PBlock = ^TBlock;

const
  CleanBlock: TBlock = (
    Typ: bbtNone;
    StartPos: -1;
    InnerStartPos: -1;
    InnerIdent: -1
  );

type
  TFABPositionIndent = record
    CleanPos: integer;
    Indent: TFABIndentationPolicy;
    Block: TBlock;
    SubType: TFABBlockType;
    SubTypeValid: boolean;
  end;
  PFABPositionIndent = ^TFABPositionIndent;

  { TFABPositionIndents }

  TFABPositionIndents = class
  private
    FCount: integer;
    procedure SetCount(const AValue: integer);
  public
    Items: PFABPositionIndent;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    property Count: integer read FCount write SetCount;
  end;

  { TFABBlockStack }

  TFABBlockStack = class
  public
    Stack: PBlock;
    Capacity: integer;
    Top: integer; // -1 = empty, 0 = 1 item
    TopType: TFABBlockType;
    LastBlockClosed: TBlock;
    LastBlockClosedAt: integer;
    constructor Create;
    destructor Destroy; override;
    procedure BeginBlock(Typ: TFABBlockType; StartPos: integer);
    procedure EndBlock(EndPos: integer);
    function TopMostIndexOf(Typ: TFABBlockType): integer;
    function EndTopMostBlock(Typ: TFABBlockType; EndPos: integer): boolean;
    {$IFDEF ShowCodeBeautifier}
    Src: string;
    function PosToStr(p: integer): string;
    {$ENDIF}
  end;

  { TFullyAutomaticBeautifier }

  TFullyAutomaticBeautifier = class
  private
    FOnGetExamples: TOnGetFABExamples;
    FCodePolicies: TAVLTree;// tree of TFABPolicies sorted for Code
    FOnGetNestedComments: TOnGetFABNestedComments;
    FOnLoadFile: TOnGetFABFile;
    FUseDefaultIndentForTypes: TFABBlockTypes;
    procedure ParseSource(const Src: string; StartPos, EndPos: integer;
      NestedComments: boolean;
      Stack: TFABBlockStack; Policies: TFABPolicies;
      out LastAtomStart, LastAtomEnd: integer; // set if LastAtomStart<EndPos<LastAtomEnd
      LearnFromFirstLine: boolean = true
      );
    procedure ParseSource(const Src: string; StartPos, EndPos: integer;
                          NestedComments: boolean;
                          Stack: TFABBlockStack; Policies: TFABPolicies;
                          LearnFromFirstLine: boolean = true);
    function FindPolicyInExamples(StartCode: TCodeBuffer;
                                  Typ, SubTyp: TFABBlockType): TFABPolicies;
    function GetNestedCommentsForCode(Code: TCodeBuffer): boolean;
    function FindStackPosForBlockCloseAtPos(const Source: string;
                             CleanPos: integer; NestedComments: boolean;
                             Stack: TFABBlockStack;
                             out TopType: TFABBlockType;
                             out TopTypeValid: boolean): integer;
    procedure WriteDebugReport(Msg: string; Stack: TFABBlockStack);
  public
    DefaultTabWidth: integer;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function GetIndent(const Source: string; CleanPos: integer;
                       NewNestedComments: boolean; UseLineStart: boolean;
                       out Indent: TFABIndentationPolicy;
                       ContextLearn: boolean = true; // true = learn policies from Source
                       const InsertText: string = ''
                       ): boolean;
    function GetIndents(const Source: string; Positions: TFABPositionIndents;
                        NewNestedComments: boolean; UseLineStart: boolean;
                        ContextLearn: boolean = true // true = learn policies from Source
                        ): boolean;
    procedure GetDefaultSrcIndent(const Source: string; CleanPos: integer;
                               NewNestedComments: boolean;
                               out Indent: TFABIndentationPolicy);
    procedure GetDefaultIndentPolicy(Typ, SubTyp: TFABBlockType;
                                  out Indent: TFABIndentationPolicy);
    property OnGetExamples: TOnGetFABExamples read FOnGetExamples
                                              write FOnGetExamples;
    property OnGetNestedComments: TOnGetFABNestedComments
                           read FOnGetNestedComments write FOnGetNestedComments;
    property OnLoadFile: TOnGetFABFile read FOnLoadFile write FOnLoadFile;
    property UseDefaultIndentForTypes: TFABBlockTypes
                 read FUseDefaultIndentForTypes write FUseDefaultIndentForTypes;
  end;

function CompareFABPoliciesWithCode(Data1, Data2: Pointer): integer;
function CompareCodeWithFABPolicy(Key, Data: Pointer): integer;

implementation

function CompareFABPoliciesWithCode(Data1, Data2: Pointer): integer;
var
  Policies1: TFABPolicies absolute Data1;
  Policies2: TFABPolicies absolute Data2;
begin
  Result:=ComparePointers(Policies1.Code,Policies2.Code);
end;

function CompareCodeWithFABPolicy(Key, Data: Pointer): integer;
var
  Policies: TFABPolicies absolute Data;
begin
  Result:=ComparePointers(Key,Policies.Code);
end;

{ TFABBlockStack }

constructor TFABBlockStack.Create;
begin
  Top:=-1;
end;

destructor TFABBlockStack.Destroy;
begin
  ReAllocMem(Stack,0);
  Capacity:=0;
  Top:=-1;
  inherited Destroy;
end;

procedure TFABBlockStack.BeginBlock(Typ: TFABBlockType; StartPos: integer);
var
  Block: PBlock;
begin
  inc(Top);
  if Top>=Capacity then begin
    if Capacity=0 then
      Capacity:=16
    else
      Capacity:=Capacity*2;
    ReAllocMem(Stack,SizeOf(TBlock)*Capacity);
  end;
  {$IFDEF ShowCodeBeautifier}
  DebugLn([GetIndentStr(Top*2),'TFABBlockStack.BeginBlock ',FABBlockTypeNames[Typ],' ',StartPos,' at ',PosToStr(StartPos)]);
  {$ENDIF}
  Block:=@Stack[Top];
  Block^.Typ:=Typ;
  Block^.StartPos:=StartPos;
  Block^.InnerIdent:=-1;
  Block^.InnerStartPos:=-1;
  TopType:=Typ;
  LastBlockClosed.Typ:=bbtNone;
  LastBlockClosed.StartPos:=0;
  LastBlockClosedAt:=0;
end;

procedure TFABBlockStack.EndBlock(EndPos: integer);
begin
  {$IFDEF ShowCodeBeautifier}
  DebugLn([GetIndentStr(Top*2),'TFABBlockStack.EndBlock ',FABBlockTypeNames[TopType]]);
  {$ENDIF}
  if Top<0 then
    exit;
  dec(Top);
  if Top>=0 then begin
    LastBlockClosed:=Stack[Top+1];
    LastBlockClosedAt:=EndPos;
    TopType:=Stack[Top].Typ;
  end else
    TopType:=bbtNone;
end;

function TFABBlockStack.TopMostIndexOf(Typ: TFABBlockType): integer;
begin
  Result:=Top;
  while (Result>=0) and (Stack[Result].Typ<>Typ) do dec(Result);
end;

function TFABBlockStack.EndTopMostBlock(Typ: TFABBlockType;
  EndPos: integer): boolean;
// check if there is this type on the stack and if yes, end it
var
  i: LongInt;
begin
  i:=TopMostIndexOf(Typ);
  if i<0 then exit(false);
  Result:=true;
  while Top>=i do EndBlock(EndPos);
end;

{$IFDEF ShowCodeBeautifier}
function TFABBlockStack.PosToStr(p: integer): string;
var
  X: integer;
  Y: LongInt;
begin
  Result:='';
  if Src='' then exit;
  Y:=LineEndCount(Src,1,p,X)+1;
  Result:='Line='+dbgs(Y)+' Col='+dbgs(X);
end;
{$ENDIF}

{ TFullyAutomaticBeautifier }

procedure TFullyAutomaticBeautifier.ParseSource(const Src: string;
  StartPos, EndPos: integer; NestedComments: boolean; Stack: TFABBlockStack;
  Policies: TFABPolicies; out LastAtomStart, LastAtomEnd: integer;
  LearnFromFirstLine: boolean);
var
  p: Integer;
  AtomStart: integer;
  AtomStartedBlock, AtomEndedBlock: boolean;
  FirstAtomOnNewLine: Boolean;
  InFirstLine: boolean;

  {$IFDEF ShowCodeBeautifierLearn}
  function PosToStr(p: integer): string;
  var
    X: integer;
    Y: LongInt;
  begin
    Y:=LineEndCount(Src,1,p,X)+1;
    Result:='Line='+dbgs(Y)+' Col='+dbgs(X);
  end;
  {$ENDIF}

  procedure UpdateBlockInnerIndent;
  var
    Block: PBlock;
    BlockStartPos: LongInt;
  begin
    Block:=@Stack.Stack[Stack.Top];
    if Block^.InnerIdent<0 then begin
      if Block^.Typ in [bbtIfThen,bbtIfElse] then
        BlockStartPos:=Stack.Stack[Stack.Top-1].StartPos
      else
        BlockStartPos:=Block^.StartPos;
      if not PositionsInSameLine(Src,BlockStartPos,Block^.InnerStartPos) then
        Block^.InnerIdent:=
            GetLineIndentWithTabs(Src,Block^.InnerStartPos,DefaultTabWidth)
                  -GetLineIndentWithTabs(Src,BlockStartPos,DefaultTabWidth);
    end;
  end;

  procedure BeginBlock(Typ: TFABBlockType);
  var
    Block: PBlock;
  begin
    AtomStartedBlock:=true;
    FirstAtomOnNewLine:=false;
    if (Stack.Top>=0) then begin
      Block:=@Stack.Stack[Stack.Top];
      if (Block^.InnerStartPos=AtomStart)
      and (Policies<>nil) then begin
        if Block^.InnerIdent<0 then UpdateBlockInnerIndent;
        if Block^.InnerIdent>=0 then begin
          if LearnFromFirstLine or (not InFirstLine) then
            Policies.AddIndent(Block^.Typ,Typ,p,Block^.InnerIdent);
          {$IFDEF ShowCodeBeautifierLearn}
          DebugLn([GetIndentStr(Stack.Top*2),'nested indentation learned ',FABBlockTypeNames[Block^.Typ],'/',FABBlockTypeNames[Typ],': ',GetAtomString(@Src[AtomStart],NestedComments),' at ',PosToStr(p),' Indent=',Block^.InnerIdent]);
          {$ENDIF}
        end;
      end;
    end;
    Stack.BeginBlock(Typ,AtomStart);
    {$IFDEF ShowCodeBeautifierParser}
    DebugLn([GetIndentStr(Stack.Top*2),'BeginBlock ',FABBlockTypeNames[Typ],' ',GetAtomString(@Src[AtomStart],NestedComments),' at ',PosToStr(p)]);
    {$ENDIF}
  end;

  procedure EndBlock;
  begin
    {$IFDEF ShowCodeBeautifierParser}
    DebugLn([GetIndentStr(Stack.Top*2),'EndBlock ',FABBlockTypeNames[Stack.TopType],' ',GetAtomString(@Src[AtomStart],NestedComments),' at ',PosToStr(p)]);
    {$ENDIF}
    AtomEndedBlock:=true;
    FirstAtomOnNewLine:=false;
    Stack.EndBlock(p);
  end;

  procedure EndTopMostBlock(Typ: TFABBlockType);
  var
    i: LongInt;
  begin
    i:=Stack.TopMostIndexOf(Typ);
    if i<0 then exit;
    while Stack.Top>=i do EndBlock;
  end;

  procedure EndStatements;
  begin
    while Stack.TopType in bbtAllStatements do EndBlock;
  end;

  function IsProcedureImplementation: boolean;
  // check if current bbtProcedure/bbtFunction expects a begin..end
  begin
    Result:=(Stack.Top=0)
      or (Stack.Stack[Stack.Top-1].Typ in (bbtAllProcedures+[bbtImplementation]));
  end;

  procedure EndIdentifierSectionAndProc;
  begin
    EndStatements;  // fix dangling statements
    if Stack.TopType=bbtProcedureModifiers then
      EndBlock;
    if Stack.TopType=bbtProcedureHead then
      EndBlock;
    if Stack.TopType in bbtAllProcedures then begin
      if IsProcedureImplementation then begin
        // procedure with begin..end
      end else begin
        // procedure without begin..end
        EndBlock;
      end;
    end;
    if Stack.TopType=bbtDefinition then
      EndBlock;
    if Stack.TopType in bbtAllIdentifierSections then
      EndBlock;
  end;

  procedure StartIdentifierSection(Section: TFABBlockType);
  begin
    EndIdentifierSectionAndProc;
    if Stack.TopType in (bbtAllCodeSections+bbtAllProcedures+[bbtNone]) then
      BeginBlock(Section);
  end;

  procedure StartProcedure(Typ: TFABBlockType);
  begin
    if Stack.TopType<>bbtDefinition then
      EndIdentifierSectionAndProc;
    if Stack.TopType in (bbtAllCodeSections+bbtAllProcedures+[bbtNone,bbtDefinition])
    then begin
      BeginBlock(Typ);
      BeginBlock(bbtProcedureHead);
    end;
  end;

  procedure StartClassSection;
  begin
    if (LastAtomStart>0) and (CompareIdentifiers('STRICT',@Src[LastAtomStart])=0)
    then begin
      exit;
    end;
    if Stack.TopType=bbtClassSection then
      EndBlock;
    if Stack.TopType=bbtClass then
      BeginBlock(bbtClassSection);
  end;

  procedure EndProcedureHead;
  begin
    if Stack.TopType=bbtProcedureModifiers then
      EndBlock;
    if Stack.TopType=bbtProcedureHead then
      EndBlock;
    if (Stack.TopType in bbtAllProcedures) and (not IsProcedureImplementation)
    then
      EndBlock;
  end;

  function CheckProcedureModifiers: boolean;
  var
    NextAtomStart: LongInt;
    NextAtomEnd: LongInt;
    i: LongInt;
    ParentTyp: TFABBlockType;
  begin
    Result:=false;
    i:=Stack.Top;
    if Stack.TopType=bbtProcedureModifiers then
      dec(i);
    if (i<0) then exit;
    if Stack.Stack[i].Typ<>bbtProcedureHead then exit;
    dec(i);
    if i<0 then exit;
    if not (Stack.Stack[i].Typ in bbtAllProcedures) then exit;
    dec(i);
    if i<0 then exit;
    if Stack.Stack[i].Typ=bbtDefinition then begin
      dec(i);
      if i<0 then exit;
    end;
    // cursor is on the semicolon, peek next atom
    NextAtomStart:=AtomStart;
    NextAtomEnd:=p;
    ReadRawNextPascalAtom(Src,NextAtomEnd,NextAtomStart,NestedComments);
    if NextAtomStart>length(Src) then exit;
    ParentTyp:=Stack.Stack[i].Typ;
    case ParentTyp of
    bbtClassSection:
      if not IsKeyWordMethodSpecifier.DoItCaseInsensitive(@Src[NextAtomStart])
      then exit;
    bbtProcedure,bbtFunction,bbtImplementation,bbtInterface:
      if not IsKeyWordProcedureSpecifier.DoItCaseInsensitive(@Src[NextAtomStart])
      then exit;
    bbtTypeSection:
      if not IsKeyWordProcedureTypeSpecifier.DoItCaseInsensitive(@Src[NextAtomStart])
      then exit;
    else
      exit;
    end;
    Result:=true;
  end;

var
  r: PChar;
  Block: PBlock;
  CommentStartPos: LongInt;
  CommentEndPos: LongInt;
begin
  p:=StartPos;
  if EndPos>length(Src) then EndPos:=length(Src)+1;
  AtomStart:=p;
  InFirstLine:=true;
  repeat
    LastAtomStart:=AtomStart;
    LastAtomEnd:=p;
    AtomStartedBlock:=false;
    AtomEndedBlock:=false;
    ReadRawNextPascalAtom(Src,p,AtomStart,NestedComments);
    if InFirstLine and (not PositionsInSameLine(Src,LastAtomEnd,AtomStart)) then
      InFirstLine:=false;
    //DebugLn(['TFullyAutomaticBeautifier.ParseSource Atom=',copy(Src,AtomStart,p-AtomStart)]);
    if p>EndPos then begin
      if (AtomStart<EndPos) then begin
        LastAtomStart:=AtomStart;
        LastAtomEnd:=p;
      end else begin
        // EndPos between two atom: in space or comment
        CommentStartPos:=FindNextNonSpace(Src,LastAtomEnd);
        LastAtomStart:=0;
        LastAtomEnd:=0;
        if CommentStartPos<EndPos then begin
          CommentEndPos:=FindCommentEnd(Src,CommentStartPos,NestedComments);
          if CommentEndPos>EndPos then begin
            // EndPos is in comment => return bounds of comment
            LastAtomStart:=CommentStartPos;
            LastAtomEnd:=CommentEndPos;
          end;
        end;
      end;
      break;
    end else if AtomStart=EndPos then
      break;
    // check if first block inner found
    FirstAtomOnNewLine:=false;
    if (Stack.Top>=0) then begin
      Block:=@Stack.Stack[Stack.Top];
      if (Policies<>nil)
      and (Block^.InnerIdent<0)
      and (not PositionsInSameLine(Src,Block^.StartPos,AtomStart)) then begin
        FirstAtomOnNewLine:=true;
        Block^.InnerStartPos:=AtomStart;
      end;
    end;

    r:=@Src[AtomStart];

    case UpChars[r^] of
    'B':
      if CompareIdentifiers('BEGIN',r)=0 then begin
        while Stack.TopType
        in (bbtAllIdentifierSections+bbtAllCodeSections+bbtAllBrackets
          +[bbtDefinition,bbtProcedureModifiers,bbtProcedureHead,bbtStatement])
        do
          EndBlock;
        case Stack.TopType of
        bbtNone:
          BeginBlock(bbtMainBegin);
        bbtProcedure,bbtFunction:
          BeginBlock(bbtProcedureBegin);
        bbtMainBegin,bbtProcedureBegin,bbtStatement:
          BeginBlock(bbtFreeBegin);
        bbtCaseElse,bbtCaseColon:
          BeginBlock(bbtCaseBegin);
        bbtIfThen,bbtIfElse:
          BeginBlock(bbtIfBegin);
        else
          if Stack.TopType in bbtAllStatements then
            BeginBlock(bbtFreeBegin);
        end;
      end;
    'C':
      case UpChars[r[1]] of
      'A': // CA
        if CompareIdentifiers('CASE',r)=0 then begin
          if Stack.TopType in bbtAllStatements then
            BeginBlock(bbtCase);
        end;
      'L': // CL
        if CompareIdentifiers('CLASS',r)=0 then begin
          if Stack.TopType=bbtDefinition then
            BeginBlock(bbtClass);
        end;
      'O': // CO
        if CompareIdentifiers('CONST',r)=0 then
          StartIdentifierSection(bbtConstSection)
        else if CompareIdentifiers('CONSTRUCTOR',r)=0 then
          StartProcedure(bbtProcedure);
      end;
    'D':
      if CompareIdentifiers('DESTRUCTOR',r)=0 then
        StartProcedure(bbtProcedure);
    'E':
      case UpChars[r[1]] of
      'L': // EL
        if CompareIdentifiers('ELSE',r)=0 then begin
          if Stack.TopType=bbtStatement then
            EndBlock;
          case Stack.TopType of
          bbtCaseOf,bbtCaseColon:
            begin
              EndBlock;
              BeginBlock(bbtCaseElse);
            end;
          bbtIfThen:
            begin
              EndBlock;
              BeginBlock(bbtIfElse);
            end;
          end;
        end;
      'N': // EN
        if CompareIdentifiers('END',r)=0 then begin
          // if statements can be closed by end without semicolon
          if Stack.TopType=bbtStatement then
            EndBlock;
          while Stack.TopType in [bbtIf,bbtIfThen,bbtIfElse] do EndBlock;
          if Stack.TopType=bbtProcedureModifiers then
            EndBlock;
          if Stack.TopType=bbtProcedureHead then
            EndBlock;
          if Stack.TopType in bbtAllProcedures then
            EndBlock;
          if Stack.TopType=bbtClassSection then
            EndBlock;

          case Stack.TopType of
          bbtMainBegin,bbtFreeBegin,
          bbtRecord,bbtClass,bbtClassInterface,bbtTry,bbtFinally,bbtExcept,
          bbtCase,bbtCaseBegin,bbtIfBegin:
            EndBlock;
          bbtCaseOf,bbtCaseElse,bbtCaseColon:
            begin
              EndBlock;
              if Stack.TopType=bbtCase then
                EndBlock;
            end;
          bbtProcedureBegin:
            begin
              EndBlock;
              if Stack.TopType in bbtAllProcedures then
                EndBlock;
            end;
          bbtInterface,bbtImplementation,bbtInitialization,bbtFinalization:
            EndBlock;
          end;
        end;
      'X': // EX
        if CompareIdentifiers('EXCEPT',r)=0 then begin
          if Stack.TopType=bbtTry then begin
            EndBlock;
            BeginBlock(bbtExcept);
          end;
        end;
      end;
    'F':
      case UpChars[r[1]] of
      'I': // FI
        if CompareIdentifiers('FINALIZATION',r)=0 then begin
          while Stack.Top>=0 do
            EndBlock;
          if Stack.TopType=bbtNone then
            BeginBlock(bbtFinalization);
        end else if CompareIdentifiers('FINALLY',r)=0 then begin
          if Stack.TopType=bbtTry then begin
            EndBlock;
            BeginBlock(bbtFinally);
          end;
        end;
      'O': // FO
        if CompareIdentifiers('FORWARD',r)=0 then begin
          if Stack.TopType=bbtProcedureModifiers then
            EndBlock;
          if Stack.TopType=bbtProcedureHead then
            EndBlock;
          if Stack.TopType in bbtAllProcedures then
            EndBlock;
        end;
      'U': // FU
        if CompareIdentifiers('FUNCTION',r)=0 then
          StartProcedure(bbtFunction);
      end;
    'I':
      case UpChars[r[1]] of
      'F': // IF
        if p-AtomStart=2 then begin
          // 'IF'
          if Stack.TopType in bbtAllStatements then
            BeginBlock(bbtIf);
        end;
      'N': // IN
        case UpChars[r[2]] of
        'I': // INI
          if CompareIdentifiers('INITIALIZATION',r)=0 then begin
            while Stack.Top>=0 do
              EndBlock;
            if Stack.TopType=bbtNone then
              BeginBlock(bbtInitialization);
          end;
        'T': // INT
          if CompareIdentifiers('INTERFACE',r)=0 then begin
            case Stack.TopType of
            bbtNone:
              BeginBlock(bbtInterface);
            bbtDefinition:
              BeginBlock(bbtClassInterface);
            end;
          end;
        end;
      'M': // IM
        if CompareIdentifiers('IMPLEMENTATION',r)=0 then begin
          while Stack.Top>=0 do
            EndBlock;
          if Stack.TopType=bbtNone then
            BeginBlock(bbtImplementation);
        end;
      end;
    'L':
      if CompareIdentifiers('LABEL',r)=0 then
        StartIdentifierSection(bbtLabelSection);
    'O':
      case UpChars[r[1]] of
      'F': // OF
        if CompareIdentifiers('OF',r)=0 then begin
          case Stack.TopType of
          bbtCase:
            BeginBlock(bbtCaseOf);
          bbtClass,bbtClassInterface:
            EndBlock;
          end;
        end;
      'P': // OP
        if CompareIdentifiers('OPERATOR',r)=0 then
          StartProcedure(bbtFunction);
      end;
    'P':
      case UpChars[r[1]] of
      'R': // PR
        case UpChars[r[2]] of
        'I': // PRI
          if (CompareIdentifiers('PRIVATE',r)=0) then
            StartClassSection;
        'O': // PRO
          case UpChars[r[3]] of
          'T': // PROT
            if (CompareIdentifiers('PROTECTED',r)=0) then
              StartClassSection;
          'C': // PROC
            if CompareIdentifiers('PROCEDURE',r)=0 then
              StartProcedure(bbtProcedure);
          end;
        end;
      'U': // PU
        if (CompareIdentifiers('PUBLIC',r)=0)
        or (CompareIdentifiers('PUBLISHED',r)=0) then
          StartClassSection;
      end;
    'R':
      case UpChars[r[1]] of
      'E': // RE
        case UpChars[r[2]] of
        'C': // REC
          if CompareIdentifiers('RECORD',r)=0 then
            BeginBlock(bbtRecord);
        'P': // REP
          if CompareIdentifiers('REPEAT',r)=0 then
            if Stack.TopType in bbtAllStatements then
              BeginBlock(bbtRepeat);
        'S': // RES
          if CompareIdentifiers('RESOURCESTRING',r)=0 then
            StartIdentifierSection(bbtResourceStringSection);
        end;
      end;
    'S':
      if (CompareIdentifiers('STRICT',r)=0) then
        StartClassSection;
    'T':
      case UpChars[r[1]] of
      'H': // TH
        if CompareIdentifiers('THEN',r)=0 then begin
          if Stack.TopType=bbtIf then
            BeginBlock(bbtIfThen);
        end;
      'R': // TR
        if CompareIdentifiers('TRY',r)=0 then begin
          if Stack.TopType in bbtAllStatements then
            BeginBlock(bbtTry);
        end;
      'Y': // TY
        if CompareIdentifiers('TYPE',r)=0 then begin
          if Stack.TopType<>bbtDefinition then
            StartIdentifierSection(bbtTypeSection);
        end;
      end;
    'U':
      case UpChars[r[1]] of
      'S': // US
        if CompareIdentifiers('USES',r)=0 then begin
          if Stack.TopType in [bbtNone,bbtInterface,bbtImplementation] then
            BeginBlock(bbtUsesSection);
        end;
      'N': // UN
        if CompareIdentifiers('UNTIL',r)=0 then begin
          EndTopMostBlock(bbtRepeat);
        end;
      end;
    'V':
      if CompareIdentifiers('VAR',r)=0 then begin
        StartIdentifierSection(bbtVarSection);
      end;
    ';':
      case Stack.TopType of
      bbtUsesSection,bbtDefinition:
        EndBlock;
      bbtCaseColon:
        begin
          EndBlock;
          BeginBlock(bbtCaseOf);
        end;
      bbtIfThen,bbtIfElse,bbtStatement:
        while Stack.TopType in [bbtIf,bbtIfThen,bbtIfElse,bbtStatement] do
          EndBlock;
      bbtProcedureHead:
        if CheckProcedureModifiers then
          BeginBlock(bbtProcedureModifiers)
        else
          EndProcedureHead;
      bbtProcedureModifiers:
        if not CheckProcedureModifiers then
          EndProcedureHead;
      end;
    ':':
      if p-AtomStart=1 then begin
        // colon
        case Stack.TopType of
        bbtCaseOf:
          begin
            EndBlock;
            BeginBlock(bbtCaseColon);
          end;
        bbtIf:
          EndBlock;
        bbtIfThen,bbtIfElse:
          begin
            EndBlock;
            if Stack.TopType=bbtIf then
              EndBlock;
          end;
        end;
      end;
    '(':
      if p-AtomStart=1 then begin
        // round bracket open
        case Stack.TopType of
        bbtProcedureHead:
          BeginBlock(bbtProcedureParamList);
        else
          if Stack.TopType in bbtAllStatements then begin
            // ignore brackets in statements, there are no consistent rules
            // to indent them
          end else
            BeginBlock(bbtTypeRoundBracket);
        end;
      end;
    ')':
      if p-AtomStart=1 then begin
        // round bracket close
        EndTopMostBlock(bbtStatementEdgedBracket);
        case Stack.TopType of
        bbtProcedureParamList,bbtTypeRoundBracket,bbtStatementRoundBracket:
          EndBlock;
        end;
      end;
    '[':
      if p-AtomStart=1 then begin
        // edge bracket open
        if Stack.TopType in bbtAllStatements then
          BeginBlock(bbtStatementEdgedBracket)
        else
          BeginBlock(bbtTypeEdgedBracket);
      end;
    ']':
      if p-AtomStart=1 then begin
        // edge bracket close
        EndTopMostBlock(bbtStatementRoundBracket);
        case Stack.TopType of
        bbtTypeEdgedBracket,bbtStatementEdgedBracket:
          EndBlock;
        end;
      end;
    end;
    // check blocks that start without keyword/symbol
    if (Stack.TopType in bbtAllIdentifierSections)
    and (IsIdentStartChar[Src[AtomStart]])
    and (not AtomStartedBlock) and (not AtomEndedBlock) then begin
      // new definition
      BeginBlock(bbtDefinition);
    end;
    if (Stack.TopType in bbtAllStatementParents)
    and (not AtomStartedBlock) and (not AtomEndedBlock)
    and (r^<>';') then begin
      // new statement
      BeginBlock(bbtStatement);
    end;

    if FirstAtomOnNewLine then begin
      UpdateBlockInnerIndent;
      if (Block^.InnerIdent>=0)
      and (LearnFromFirstLine or (not InFirstLine)) then begin
        Policies.AddIndent(Block^.Typ,bbtNone,p,Block^.InnerIdent);
        {$IFDEF ShowCodeBeautifierLearn}
        DebugLn([GetIndentStr(Stack.Top*2),'Indentation learned for statements: ',FABBlockTypeNames[Block^.Typ],' Indent=',Block^.InnerIdent,' at ',PosToStr(p)]);
        {$ENDIF}
      end;
    end;
  until false;
end;

procedure TFullyAutomaticBeautifier.ParseSource(const Src: string; StartPos,
  EndPos: integer; NestedComments: boolean; Stack: TFABBlockStack;
  Policies: TFABPolicies; LearnFromFirstLine: boolean);
var
  LastAtomStart, LastAtomEnd: integer;
begin
  ParseSource(Src,StartPos,EndPos,NestedComments,Stack,Policies,
              LastAtomStart,LastAtomEnd,LearnFromFirstLine);
end;

function TFullyAutomaticBeautifier.FindPolicyInExamples(StartCode: TCodeBuffer;
  Typ, SubTyp: TFABBlockType): TFABPolicies;

  function CheckCode(Code: TCodeBuffer; out Policies: TFABPolicies): boolean;
  // result=false : abort
  var
    AVLNode: TAVLTreeNode;
    Stack: TFABBlockStack;
  begin
    Policies:=nil;
    if Code=nil then exit(true);
    {$IFDEF VerboseIndenter}
    DebugLn(['TFullyAutomaticBeautifier.FindPolicyInExamples ',Code.Filename]);
    {$ENDIF}
    // search Policies for code
    AVLNode:=FCodePolicies.FindKey(Code,@CompareCodeWithFABPolicy);
    if AVLNode=nil then begin
      Policies:=TFABPolicies.Create;
      Policies.Code:=Code;
      FCodePolicies.Add(Policies);
    end else
      Policies:=TFABPolicies(AVLNode.Data);
    if Policies.CodeChangeStep<>Code.ChangeStep then begin
      // parse code
      Policies.Clear;
      Policies.CodeChangeStep:=Code.ChangeStep;
      Stack:=TFABBlockStack.Create;
      try
        ParseSource(Code.Source,1,length(Code.Source)+1,
           GetNestedCommentsForCode(Code),Stack,Policies);
      finally
        Stack.Free;
      end;
    end;
    // search policy
    if Policies.GetIndent(Typ,SubTyp,true,false)>=0 then begin
      exit;
    end;
    Policies:=nil;
    Result:=true;
  end;

var
  CodeBuffers: TFPList;
  i: Integer;
  Code: TCodeBuffer;
  Step: Integer;
  Filenames: TStrings;
  Abort: boolean;
begin
  Result:=nil;
  if not Assigned(OnGetExamples) then exit;
  Step:=0;
  repeat
    // get examples for current step
    CodeBuffers:=nil;
    Filenames:=nil;
    try
      OnGetExamples(Self,StartCode,Step,CodeBuffers,Filenames);
      if (CodeBuffers=nil) and (Filenames=nil) then exit;
      // search policy in every example
      if CodeBuffers<>nil then
        for i:=0 to CodeBuffers.Count-1 do begin
          Code:=TCodeBuffer(CodeBuffers[i]);
          if not CheckCode(Code,Result) then exit;
          if Result<>nil then exit;
        end;
      if (Filenames<>nil) and Assigned(OnLoadFile) then
        for i:=0 to Filenames.Count-1 do begin
          Abort:=false;
          Code:=nil;
          OnLoadFile(Self,Filenames[i],Code,Abort);
          if Abort then exit;
          if Code=nil then continue;
          if not CheckCode(Code,Result) then exit;
          if Result<>nil then exit;
        end;
    finally
      CodeBuffers.Free;
      Filenames.Free;
    end;
    // next step
    inc(Step);
  until false;
end;

function TFullyAutomaticBeautifier.GetNestedCommentsForCode(Code: TCodeBuffer
  ): boolean;
begin
  Result:=true;
  if Assigned(OnGetNestedComments) then
    OnGetNestedComments(Self,Code,Result);
end;

function TFullyAutomaticBeautifier.FindStackPosForBlockCloseAtPos(
  const Source: string; CleanPos: integer; NestedComments: boolean;
  Stack: TFABBlockStack; out TopType: TFABBlockType; out TopTypeValid: boolean
  ): integer;
{ For example:
    if expr then
      begin
        |DoSomething;

    if expr then
      begin
      |end;
}

  function StackTopType: TFABBlockType;
  var
    i: Integer;
  begin
    i:=Stack.Top+FindStackPosForBlockCloseAtPos;
    if (i>=0) and (i<=Stack.Top) then
      Result:=Stack.Stack[i].Typ
    else
      Result:=bbtNone;
  end;

  procedure EndBlock(aCount: integer = 1);
  begin
    dec(FindStackPosForBlockCloseAtPos,aCount);
    TopTypeValid:=false;
  end;

  procedure EndIdentifierSectionAndProc;
  begin
    if StackTopType=bbtDefinition then
      EndBlock;
    if StackTopType in bbtAllIdentifierSections then
      EndBlock;
  end;

  procedure StartProcedure;
  begin
    if StackTopType=bbtDefinition then
      EndBlock;
    if StackTopType in bbtAllIdentifierSections then
      EndBlock;
  end;

  function IsMethodDeclaration: boolean;
  var
    i: Integer;
  begin
    i:=Stack.Top+FindStackPosForBlockCloseAtPos;
    Result:=(StackTopType in bbtAllProcedures)
      and (i>0)
      and (Stack.Stack[i-1].Typ=bbtClassSection);
  end;

  procedure EndClassSection;
  begin
    if StackTopType=bbtClassSection then
      EndBlock
    else if IsMethodDeclaration then
      EndBlock(2);
  end;

  procedure EndBigSection;
  var
    i: Integer;
  begin
    i:=Stack.Top+FindStackPosForBlockCloseAtPos;
    if i>=0 then
      EndBlock(i+1);
  end;

  procedure EndTopMostBlock(BlockTyp: TFABBlockType);
  var
    i: LongInt;
  begin
    i:=Stack.TopMostIndexOf(BlockTyp);
    if i>=0 then
      FindStackPosForBlockCloseAtPos:=i-1;
  end;

var
  AtomStart: integer;
  r: PChar;
  p: LongInt;
begin
  {$IFDEF VerboseIndenter}
  DebugLn(['TFullyAutomaticBeautifier.FindStackPosForBlockCloseAtPos START']);
  {$ENDIF}
  Result:=Stack.Top;
  TopType:=bbtNone;
  TopTypeValid:=false;
  if Result<0 then exit;
  if (CleanPos<1) or (CleanPos>length(Source))
  or (Source[CleanPos] in [#0..#31,' ']) then
    exit;
  p:=CleanPos;
  ReadRawNextPascalAtom(Source,p,AtomStart,NestedComments);
  {$IFDEF VerboseIndenter}
  DebugLn(['TFullyAutomaticBeautifier.FindStackPosForBlockCloseAtPos ',AtomStart<>CleanPos,' CleanPos=',dbgstr(copy(Source,CleanPos,10)),' AtomStart=',dbgstr(copy(Source,AtomStart,10))]);
  {$ENDIF}
  if AtomStart<>CleanPos then exit;
  {$IFDEF VerboseIndenter}
  DebugLn(['TFullyAutomaticBeautifier.FindStackPosForBlockCloseAtPos Atom=',copy(Source,AtomStart,p-AtomStart)]);
  {$ENDIF}
  TopTypeValid:=true;
  r:=@Source[AtomStart];
  case UpChars[r^] of
  'B':
    if CompareIdentifiers('BEGIN',r)=0 then begin
      if StackTopType=bbtDefinition then
        EndBlock;
      if StackTopType in bbtAllIdentifierSections then
        EndBlock;
      case StackTopType of
      bbtIfThen:
        begin
          TopType:=bbtIfBegin;
          TopTypeValid:=true;
        end;
      end;
    end;
  'C':
    if CompareIdentifiers('CONST',r)=0 then
      EndIdentifierSectionAndProc;
  'E':
    case UpChars[r[1]] of
    'L': // EL
      if CompareIdentifiers('ELSE',r)=0 then begin
        case StackTopType of
        bbtCaseOf,bbtCaseColon:
          EndBlock;
        bbtIfThen:
          EndBlock;
        bbtStatement:
          begin
            EndBlock;
            if StackTopType in [bbtIfThen] then
              EndBlock;
          end;
        end;
      end;
    'N': // EN
      if CompareIdentifiers('END',r)=0 then begin
        // if statements can be closed by end without semicolon
        while StackTopType in [bbtIf,bbtIfThen,bbtIfElse] do
          EndBlock;
        if IsMethodDeclaration then
          EndBlock;
        if StackTopType=bbtClassSection then
          EndBlock;

        case StackTopType of
        bbtMainBegin,bbtFreeBegin,
        bbtRecord,bbtClass,bbtClassInterface,bbtTry,bbtFinally,bbtExcept,
        bbtCase,bbtCaseBegin,bbtIfBegin:
          EndBlock;
        bbtCaseOf,bbtCaseColon,bbtCaseElse:
          begin
            EndBlock;
            if StackTopType=bbtCase then
              EndBlock;
          end;
        bbtProcedureBegin:
          EndBlock;
        bbtInterface,bbtImplementation,bbtInitialization,bbtFinalization:
          EndBlock;
        end;
      end;
    'X': // EX
      if CompareIdentifiers('EXCEPT',r)=0 then begin
        if StackTopType=bbtTry then
          EndBlock;
      end;
    end;
  'F':
    case UpChars[r[1]] of
    'I': // FI
      if CompareIdentifiers('FINALIZATION',r)=0 then begin
        EndBigSection;
      end else if CompareIdentifiers('FINALLY',r)=0 then begin
        if StackTopType=bbtTry then
          EndBlock;
      end;
    end;
  'I':
    case UpChars[r[1]] of
    'F': // IF
      if p-AtomStart=2 then begin
        TopType:=bbtIf;
      end;
    'N': // IN
      case UpChars[r[2]] of
      'I': // INI
        if CompareIdentifiers('INITIALIZATION',r)=0 then
          EndBigSection;
      end;
    'M': // IM
      if CompareIdentifiers('IMPLEMENTATION',r)=0 then begin
        EndBigSection;
      end;
    end;
  'L':
    if CompareIdentifiers('LABEL',r)=0 then
      EndIdentifierSectionAndProc;
  'P':
    case UpChars[r[1]] of
    'R': // PR
      case UpChars[r[2]] of
      'I': // PRI
        if CompareIdentifiers('PRIVATE',r)=0 then
          EndClassSection;
      'O': // PRO
        case UpChars[r[3]] of
        'C': // PROC
          if CompareIdentifiers('PROCEDURE',r)=0 then
            StartProcedure;
        'T': // PROT
          if CompareIdentifiers('PROTECTED',r)=0 then
            EndClassSection;
        end;
      end;
    'U': // PU
      if (CompareIdentifiers('PUBLIC',r)=0)
      or (CompareIdentifiers('PUBLISHED',r)=0) then
        EndClassSection;
    end;
  'R':
    case UpChars[r[1]] of
    'E': // RE
      case UpChars[r[2]] of
      'S': // RES
        if CompareIdentifiers('RESOURCESTRING',r)=0 then
          EndIdentifierSectionAndProc;
      end;
    end;
  'S':
    if (CompareIdentifiers('STRICT',r)=0) then
      EndClassSection;
  'T':
    case UpChars[r[1]] of
    'Y': // TY
      if CompareIdentifiers('TYPE',r)=0 then
        EndIdentifierSectionAndProc;
    end;
  'U':
    case UpChars[r[1]] of
    'N': // UN
      if CompareIdentifiers('UNTIL',r)=0 then begin
        EndTopMostBlock(bbtRepeat);
      end;
    end;
  'V':
    if CompareIdentifiers('VAR',r)=0 then
      EndIdentifierSectionAndProc;
  end;
  {$IFDEF VerboseIndenter}
  if (Stack.Top<>Result)  then
    DebugLn(['TFullyAutomaticBeautifier.FindStackPosForBlockCloseAtPos block close: Stack.Top=',Stack.Top,' Result=',Result]);
  if TopTypeValid then
    DebugLn(['TFullyAutomaticBeautifier.FindStackPosForBlockCloseAtPos block open: TopType=',FABBlockTypeNames[TopType]]);
  {$ENDIF}
end;

procedure TFullyAutomaticBeautifier.WriteDebugReport(Msg: string;
  Stack: TFABBlockStack);
var
  i: Integer;
  Block: PBlock;
begin
  DebugLn(['TFullyAutomaticBeautifier.WriteDebugReport ',Msg]);
  if Stack<>nil then begin
    for i:=0 to Stack.Top do begin
      Block:=@Stack.Stack[i];
      DebugLn([GetIndentStr(i*2),' : Typ=',FABBlockTypeNames[Block^.Typ],' StartPos=',Block^.StartPos,' InnerIdent=',Block^.InnerIdent,' InnerStartPos=',Block^.InnerStartPos]);
    end;
  end;
end;

constructor TFullyAutomaticBeautifier.Create;
begin
  FCodePolicies:=TAVLTree.Create(@CompareFABPoliciesWithCode);
  DefaultTabWidth:=4;
  UseDefaultIndentForTypes:=[bbtStatement,bbtStatementRoundBracket,
    bbtStatementEdgedBracket,bbtTypeRoundBracket,bbtTypeEdgedBracket];
end;

destructor TFullyAutomaticBeautifier.Destroy;
begin
  Clear;
  FreeAndNil(FCodePolicies);
  inherited Destroy;
end;

procedure TFullyAutomaticBeautifier.Clear;
begin
  FCodePolicies.FreeAndClear;
end;

function TFullyAutomaticBeautifier.GetIndent(const Source: string;
  CleanPos: integer; NewNestedComments: boolean;
  UseLineStart: boolean; out Indent: TFABIndentationPolicy;
  ContextLearn: boolean; const InsertText: string): boolean;
var
  Block: TBlock;
  SubType: TFABBlockType;
  SubTypeValid: Boolean;

  function CheckPolicies(Policies: TFABPolicies; var Found: boolean): boolean;
  // returns true to stop searching
  var
    BlockIndent: LongInt;
  begin
    Result:=false;
    Found:=false;
    if (Policies=nil) then exit;
    if SubTypeValid then
      BlockIndent:=Policies.GetIndent(Block.Typ,SubType,true,true)
    else
      BlockIndent:=Policies.GetSmallestIndent(Block.Typ);
    if (BlockIndent<0) then exit;
    // policy found
    {$IFDEF VerboseIndenter}
    DebugLn(['TFullyAutomaticBeautifier.GetIndent policy found: Block.Typ=',FABBlockTypeNames[Block.Typ],' BlockIndent=',BlockIndent]);
    {$ENDIF}
    Indent.Indent:=GetLineIndentWithTabs(Source,Block.StartPos,DefaultTabWidth)
                   +BlockIndent;
    Indent.IndentValid:=true;
    Result:=true;
    Found:=true;
  end;

var
  Stack: TFABBlockStack;
  Policies: TFABPolicies;
  LastAtomStart, LastAtomEnd: integer;
  StackIndex: LongInt;
  PrevLineAtomEndPos: LongInt;
  InsertTextStartPos: Integer;
begin
  Result:=false;
  FillByte(Indent,SizeOf(Indent),0);

  CleanPos:=FindStartOfAtom(Source,CleanPos);
  if CleanPos<1 then exit;

  if UseLineStart and (InsertText='') then begin
    while (CleanPos<=length(Source)) and (Source[CleanPos] in [' ',#9]) do
      inc(CleanPos);
  end;

  Block:=CleanBlock;
  Policies:=nil;
  Stack:=TFABBlockStack.Create;
  try
    if ContextLearn then
      Policies:=TFABPolicies.Create;
    {$IFDEF ShowCodeBeautifierLearn}
    Policies.Code:=TCodeBuffer.Create;
    Policies.Code.Source:=Source;
    {$ENDIF}
    // parse source in front
    {$IFDEF VerboseIndenter}
    DebugLn(['TFullyAutomaticBeautifier.GetIndent "',dbgstr(copy(Source,CleanPos-10,10)),'|',dbgstr(copy(Source,CleanPos,10)),'"']);
    {$ENDIF}
    ParseSource(Source,1,CleanPos,NewNestedComments,Stack,Policies,
                LastAtomStart,LastAtomEnd);
    {$IFDEF VerboseIndenter}
    WriteDebugReport('After parsing code in front:',Stack);
    {$ENDIF}
    if (LastAtomStart>0) and (CleanPos>LastAtomStart) then begin
      // in comment or atom
      {$IFDEF VerboseIndenter}
      DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed code in front: position in middle of atom, e.g. comment']);
      {$ENDIF}
      GetDefaultSrcIndent(Source,CleanPos,NewNestedComments,Indent);
      exit(Indent.IndentValid);
    end;
    if LastAtomStart>0 then CleanPos:=LastAtomStart;

    StackIndex:=Stack.Top;
    SubType:=bbtNone;
    SubTypeValid:=false;
    if UseLineStart then begin
      if InsertText='' then begin
        StackIndex:=FindStackPosForBlockCloseAtPos(Source,CleanPos,
                                  NewNestedComments,Stack,SubType,SubTypeValid);
      end else begin
        InsertTextStartPos:=1;
        while (InsertTextStartPos<=length(InsertText))
        and (InsertText[InsertTextStartPos] in [' ',#9]) do
          inc(InsertTextStartPos);
        StackIndex:=FindStackPosForBlockCloseAtPos(InsertText,InsertTextStartPos,
                                  NewNestedComments,Stack,SubType,SubTypeValid);
      end;
    end;
    if (StackIndex<0) then begin
      // no context
      {$IFDEF VerboseIndenter}
      DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed code in front: no context']);
      {$ENDIF}
      Indent.Indent:=0;
      Indent.IndentValid:=true;
      exit(Indent.IndentValid);
    end;

    if (Stack.Stack[StackIndex].Typ in UseDefaultIndentForTypes) then begin
      // use default indent
      {$IFDEF VerboseIndenter}
      DebugLn(['TFullyAutomaticBeautifier.GetIndent use default for this type: ',FABBlockTypeNames[Stack.Stack[StackIndex].Typ]]);
      {$ENDIF}
      GetDefaultSrcIndent(Source,CleanPos,NewNestedComments,Indent);
      exit(Indent.IndentValid);
    end;

    if (StackIndex<Stack.Top) then begin
      // block(s) closed by next token
      // use indent of block start
      Block:=Stack.Stack[StackIndex+1];
      {$IFDEF VerboseIndenter}
      DebugLn(['TFullyAutomaticBeautifier.GetIndent next token close block: ',FABBlockTypeNames[Stack.TopType],' Block=',dbgstr(copy(Source,Block.StartPos,20))]);
      {$ENDIF}
      Indent.Indent:=GetLineIndentWithTabs(Source,Block.StartPos,DefaultTabWidth);
      Indent.IndentValid:=true;
      exit(true);
    end;
    Block:=Stack.Stack[StackIndex];

    // search last non empty line start
    PrevLineAtomEndPos:=CleanPos;
    while (PrevLineAtomEndPos>0)
    and (not (Source[PrevLineAtomEndPos] in [#10,#13])) do
      dec(PrevLineAtomEndPos);
    if (PrevLineAtomEndPos>0) then
      PrevLineAtomEndPos:=FindPrevNonSpace(Source,PrevLineAtomEndPos);

    if Stack.LastBlockClosed.StartPos>0 then begin
      // a child block was closed
      if (Stack.LastBlockClosedAt>0)
      and PositionsInSameLine(Source,Stack.LastBlockClosedAt,PrevLineAtomEndPos)
      then begin
        // between block end and CleanPos are only empty lines
        // => indent like the last child block one
        {$IFDEF VerboseIndenter}
        DebugLn(['TFullyAutomaticBeautifier.GetIndent line after end of last sibling block, copy indent']);
        {$ENDIF}
        Indent.Indent:=GetLineIndentWithTabs(Source,
                                Stack.LastBlockClosed.StartPos,DefaultTabWidth);
      end else begin
        // between block end and CleanPos are non empty lines
        // => indent like the last non empty line
        {$IFDEF VerboseIndenter}
        DebugLn(['TFullyAutomaticBeautifier.GetIndent unstructural code found, indent as last line: LastBlockClosedAt=',dbgstr(copy(Source,Stack.LastBlockClosedAt,10)),' PrevAtom=',dbgstr(copy(Source,PrevLineAtomEndPos,10))]);
        {$ENDIF}
        Indent.Indent:=GetLineIndentWithTabs(Source,
                                            PrevLineAtomEndPos,DefaultTabWidth);
      end;
      Indent.IndentValid:=true;
      exit(true);
    end;

    {$IFDEF VerboseIndenter}
    DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed code in front: context=',FABBlockTypeNames[Block.Typ],'/',FABBlockTypeNames[SubType],' indent=',GetLineIndentWithTabs(Source,Block.StartPos,DefaultTabWidth)]);
    {$ENDIF}
    if CheckPolicies(Policies,Result) then exit;
    SubTypeValid:=false;

    if ContextLearn then begin
      // parse source behind
      ParseSource(Source,CleanPos,length(Source)+1,NewNestedComments,Stack,
                  Policies,false);
      {$IFDEF VerboseIndenter}
      DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed source behind']);
      {$ENDIF}
      if CheckPolicies(Policies,Result) then exit;
    end;
  finally
    {$IFDEF VerboseIndenter}
    DebugLn(['TFullyAutomaticBeautifier.GetIndent Valid=',Indent.IndentValid,' Indent=',Indent.Indent]);
    {$ENDIF}
    Stack.Free;
    if Policies<>nil then
      FreeAndNil(Policies.Code);
    Policies.Free;
  end;

  // parse examples
  Policies:=FindPolicyInExamples(nil,Block.Typ,SubType);
  {$IFDEF VerboseIndenter}
  DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed examples']);
  {$ENDIF}
  if CheckPolicies(Policies,Result) then exit;

  {$IFDEF VerboseIndenter}
  DebugLn(['TFullyAutomaticBeautifier.GetIndent no examples found']);
  {$ENDIF}
  if SubTypeValid then
    GetDefaultIndentPolicy(Block.Typ,SubType,Indent)
  else
    GetDefaultIndentPolicy(Block.Typ,bbtNone,Indent);
  if Indent.IndentValid then begin
    {$IFDEF VerboseIndenter}
    DebugLn(['TFullyAutomaticBeautifier.GetIndent using default ',Indent.Indent]);
    {$ENDIF}
    inc(Indent.Indent,GetLineIndentWithTabs(Source,Block.StartPos,DefaultTabWidth));
    Result:=true;
  end;
end;

function TFullyAutomaticBeautifier.GetIndents(const Source: string;
  Positions: TFABPositionIndents; NewNestedComments: boolean;
  UseLineStart: boolean; ContextLearn: boolean): boolean;
var
  Needed: LongInt;

  function CheckPolicies(Policies: TFABPolicies;
    Item: PFABPositionIndent): boolean;
  // returns true to stop searching
  var
    BlockIndent: LongInt;
  begin
    Result:=false;
    if (Policies=nil) then exit;
    if Item^.SubTypeValid then
      BlockIndent:=Policies.GetIndent(Item^.Block.Typ,Item^.SubType,true,true)
    else
      BlockIndent:=Policies.GetSmallestIndent(Item^.Block.Typ);
    if (BlockIndent<0) then exit;
    // policy found
    {$IFDEF VerboseIndenter}
    DebugLn(['TFullyAutomaticBeautifier.GetIndent policy found: Block.Typ=',FABBlockTypeNames[Item^.Block.Typ],' BlockIndent=',BlockIndent]);
    {$ENDIF}
    Item^.Indent.Indent:=GetLineIndentWithTabs(Source,Item^.Block.StartPos,DefaultTabWidth)
                   +BlockIndent;
    Item^.Indent.IndentValid:=true;
    dec(Needed);
    Result:=Needed=0;
  end;

var
  Item: PFABPositionIndent;
  ItemIndex: Integer;
  LastAtomStart, LastAtomEnd: integer;
  Stack: TFABBlockStack;
  StackIndex: LongInt;
  Policies: TFABPolicies;
begin
  Result:=false;
  if (Positions=nil) or (Positions.Count=0) then exit;
  Needed:=Positions.Count;
  for ItemIndex:=0 to Positions.Count-1 do begin
    Item:=@Positions.Items[ItemIndex];
    Item^.CleanPos:=FindStartOfAtom(Source,Item^.CleanPos);
    if Item^.CleanPos<1 then exit;
    FillByte(Item^.Indent,SizeOf(Item^.Indent),0);
    if (ItemIndex>0)
    and (Item^.CleanPos<=Positions.Items[ItemIndex-1].CleanPos) then
      exit;
    Item^.Block:=CleanBlock;
    Item^.SubType:=bbtNone;
    Item^.SubTypeValid:=false;
  end;

  if UseLineStart then begin
    Item:=@Positions.Items[0];
    while (Item^.CleanPos<=length(Source))
    and (Source[Item^.CleanPos] in [' ',#9]) do
      inc(Item^.CleanPos);
  end;

  Policies:=nil;
  Stack:=TFABBlockStack.Create;
  try
    if ContextLearn then
      Policies:=TFABPolicies.Create;
    {$IFDEF ShowCodeBeautifierLearn}
    Policies.Code:=TCodeBuffer.Create;
    Policies.Code.Source:=Source;
    {$ENDIF}
    for ItemIndex:=0 to Positions.Count-1 do begin
      Item:=@Positions.Items[ItemIndex];
      if ItemIndex=0 then begin
        // parse source in front
        {$IFDEF VerboseIndenter}
        DebugLn(['TFullyAutomaticBeautifier.GetIndent Index=',ItemIndex,' "',dbgstr(copy(Source,Item^.CleanPos-10,10)),'|',dbgstr(copy(Source,Item^.CleanPos,10)),'"']);
        {$ENDIF}
        ParseSource(Source,1,Item^.CleanPos,NewNestedComments,Stack,Policies,
                    LastAtomStart,LastAtomEnd);
      end else begin
        // parse to next position
        ParseSource(Source,Positions.Items[ItemIndex-1].CleanPos,
                    Item^.CleanPos,NewNestedComments,Stack,nil,
                    LastAtomStart,LastAtomEnd);
      end;
      {$IFDEF VerboseIndenter}
      WriteDebugReport('After parsing code: ',Stack);
      {$ENDIF}
      if (LastAtomStart>0) and (Item^.CleanPos>LastAtomStart) then begin
        // in comment or atom
        {$IFDEF VerboseIndenter}
        DebugLn(['TFullyAutomaticBeautifier.GetIndent Index=',ItemIndex,' parsed code in front: position in middle of atom, e.g. comment']);
        {$ENDIF}
        GetDefaultSrcIndent(Source,Item^.CleanPos,NewNestedComments,Item^.Indent);
        if Item^.Indent.IndentValid then begin
          dec(Needed);
          if Needed=0 then exit;
        end;
      end;
      if not Item^.Indent.IndentValid then begin
        if LastAtomStart>0 then Item^.CleanPos:=LastAtomStart;

        Item^.SubType:=bbtNone;
        Item^.SubTypeValid:=false;
        if UseLineStart then
          StackIndex:=FindStackPosForBlockCloseAtPos(Source,Item^.CleanPos,
                      NewNestedComments,Stack,Item^.SubType,Item^.SubTypeValid);
        if (StackIndex<0) then begin
          // no context
          {$IFDEF VerboseIndenter}
          DebugLn(['TFullyAutomaticBeautifier.GetIndent Index=',ItemIndex,' parsed code in front: no context']);
          {$ENDIF}
          GetDefaultSrcIndent(Source,Item^.CleanPos,NewNestedComments,Item^.Indent);
          if Item^.Indent.IndentValid then begin
            dec(Needed);
            if Needed=0 then exit(true);
          end;
        end;
      end;
      StackIndex:=Stack.Top;
      if not Item^.Indent.IndentValid then begin
        if StackIndex=0 then begin
          dec(Needed);
          if Needed=0 then exit(true);
        end else begin
          Item^.Block:=Stack.Stack[StackIndex];
          {$IFDEF VerboseIndenter}
          DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed code in front: context=',FABBlockTypeNames[Item^.Block.Typ],'/',FABBlockTypeNames[Item^.SubType],' indent=',GetLineIndentWithTabs(Source,Item^.Block.StartPos,DefaultTabWidth)]);
          {$ENDIF}
          if CheckPolicies(Policies,Item) then exit(true);
        end;
      end;
    end;

    if Policies<>nil then begin
      // parse source behind
      ParseSource(Source,Item^.CleanPos,length(Source)+1,NewNestedComments,
                  Stack,Policies,false);
      {$IFDEF VerboseIndenter}
      DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed source behind']);
      {$ENDIF}
      for ItemIndex:=0 to Positions.Count-1 do begin
        Item:=@Positions.Items[ItemIndex];
        if (not Item^.Indent.IndentValid) and (Item^.Block.Typ<>bbtNone) then
          if CheckPolicies(Policies,Item) then exit(true);
      end;
    end;
  finally
    Stack.Free;
    if Policies<>nil then
      FreeAndNil(Policies.Code);
    Policies.Free;
  end;

  // parse examples
  for ItemIndex:=0 to Positions.Count-1 do begin
    Item:=@Positions.Items[ItemIndex];
    if (not Item^.Indent.IndentValid) and (Item^.Block.Typ<>bbtNone) then begin
      Policies:=FindPolicyInExamples(nil,Item^.Block.Typ,Item^.SubType);
      {$IFDEF VerboseIndenter}
      DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed examples']);
      {$ENDIF}
      if (Policies<>nil) and CheckPolicies(Policies,Item) then
        exit(true);
    end;
  end;
end;

procedure TFullyAutomaticBeautifier.GetDefaultSrcIndent(const Source: string;
  CleanPos: integer; NewNestedComments: boolean; out
  Indent: TFABIndentationPolicy);
// return indent of last non empty line
begin
  Indent.Indent:=0;
  Indent.IndentValid:=false;
  // go to start of line
  while (CleanPos>1) and (not (Source[CleanPos-1] in [#10,#13])) do
    dec(CleanPos);
  while CleanPos>1 do begin
    // skip line end
    dec(CleanPos);
    if (CleanPos>1) and (Source[CleanPos-1] in [#10,#13])
    and (Source[CleanPos]<>Source[CleanPos-1]) then
      dec(CleanPos);
    // read line
    while (CleanPos>1) do begin
      case Source[CleanPos-1] of
      ' ',#9: dec(CleanPos);
      #10,#13:
        begin
          // empty line
          break;
        end;
      else
        dec(CleanPos);
        Indent.Indent:=GetLineIndentWithTabs(Source,CleanPos,DefaultTabWidth);
        Indent.IndentValid:=true;
        exit;
      end;
      dec(CleanPos);
    end;
  end;
  // only empty lines in front
end;

procedure TFullyAutomaticBeautifier.GetDefaultIndentPolicy(Typ,
  SubTyp: TFABBlockType; out Indent: TFABIndentationPolicy);
begin
  Indent.IndentValid:=false;
  Indent.Indent:=0;
  case Typ of
  bbtInterface,
  bbtImplementation,
  bbtInitialization,
  bbtFinalization,
  bbtClass,
  bbtClassInterface,
  bbtProcedure,
  bbtFunction,
  bbtCase,
  bbtCaseOf,
  bbtIf:
    begin
      Indent.Indent:=0;
      Indent.IndentValid:=true;
    end;
  bbtUsesSection,
  bbtTypeSection,
  bbtConstSection,
  bbtVarSection,
  bbtResourceStringSection,
  bbtLabelSection,
  bbtDefinition,
  bbtRecord,
  bbtClassSection,
  bbtMainBegin,
  bbtFreeBegin,
  bbtRepeat,
  bbtProcedureBegin,
  bbtCaseColon,
  bbtCaseBegin,
  bbtCaseElse,
  bbtTry,
  bbtFinally,
  bbtExcept,
  bbtIfBegin:
    begin
      Indent.Indent:=2;
      Indent.IndentValid:=true;
    end;
  bbtIfThen,
  bbtIfElse:
    if SubTyp=bbtIfBegin then begin
      Indent.Indent:=0;
      Indent.IndentValid:=true;
    end else begin
      Indent.Indent:=2;
      Indent.IndentValid:=true;
    end;
  end;
end;

{ TFABPolicies }

function TFABPolicies.FindIndentation(Typ, SubType: TFABBlockType;
  out InsertPos: integer): boolean;
// binary search
var
  l: Integer;
  r: Integer;
  m: Integer;
  Ind: PFABFoundIndentationPolicy;
begin
  l:=0;
  r:=IndentationCount-1;
  while l<=r do begin
    m:=(l+r) div 2;
    Ind:=@Indentations[m];
    if (Typ>Ind^.Typ) then
      r:=m-1
    else if (Typ<Ind^.Typ) then
      l:=m+1
    else if SubType>Ind^.SubTyp then
      r:=m-1
    else if SubType<Ind^.SubTyp then
      l:=m+1
    else begin
      InsertPos:=m;
      exit(true);
    end;
  end;
  Result:=false;
  if IndentationCount=0 then
    InsertPos:=0
  else if r<m then
    InsertPos:=m
  else
    InsertPos:=m+1;
end;

constructor TFABPolicies.Create;
begin

end;

destructor TFABPolicies.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TFABPolicies.Clear;
begin
  ReAllocMem(Indentations,0);
end;

procedure TFABPolicies.AddIndent(Typ, SubType: TFABBlockType;
  SrcPos, Indent: integer);
var
  i: Integer;
  Ind: PFABFoundIndentationPolicy;
begin
  if not FindIndentation(Typ,SubType,i) then begin
    inc(IndentationCount);
    if IndentationCount>IndentationCapacity then begin
      IndentationCapacity:=IndentationCapacity*2+12;
      ReAllocMem(Indentations,SizeOf(TFABFoundIndentationPolicy)*IndentationCapacity);
    end;
    if i<IndentationCount-1 then
      System.Move(Indentations[i],Indentations[i+1],
        SizeOf(TFABFoundIndentationPolicy)*(IndentationCount-i-1));
    Ind:=@Indentations[i];
    Ind^.Typ:=Typ;
    Ind^.SubTyp:=SubType;
    Ind^.Indent:=Indent;
    {$IFDEF ShowCodeBeautifierLearn}
    DebugLn(['TFABPolicies.AddIndent New SubTyp ',FABBlockTypeNames[Typ],'-',FABBlockTypeNames[SubType],': indent=',Indent,' ',CodePosToStr(SrcPos)]);
    {$ENDIF}
  end else begin
    Ind:=@Indentations[i];
    if Ind^.Indent<>Indent then begin
      Ind^.Indent:=Indent;
      {$IFDEF ShowCodeBeautifierLearn}
      DebugLn(['TFABPolicies.AddIndent Changed SubTyp ',FABBlockTypeNames[Typ],'-',FABBlockTypeNames[SubType],': indent=',Indent,' ',CodePosToStr(SrcPos)]);
      {$ENDIF}
    end;
  end;
end;

function TFABPolicies.GetSmallestIndent(Typ: TFABBlockType): integer;
var
  i: Integer;
begin
  Result:=High(integer);
  for i:=0 to IndentationCount-1 do begin
    if Indentations[i].Typ=Typ then
      if Indentations[i].Indent<Result then
        Result:=Indentations[i].Indent;
  end;
  if Result=High(integer) then
    Result:=-1;
end;

function TFABPolicies.GetIndent(Typ, SubType: TFABBlockType;
  UseNoneIfNotFound: boolean; UseSmallestIfNotFound: boolean): integer;
var
  i: integer;
begin
  if FindIndentation(Typ,SubType,i) then
    Result:=Indentations[i].Indent
  else if UseNoneIfNotFound and FindIndentation(Typ,bbtNone,i) then
    Result:=Indentations[i].Indent
  else
    Result:=GetSmallestIndent(Typ);
end;

function TFABPolicies.CodePosToStr(p: integer): string;
var
  Line: integer;
  Col: integer;
begin
  if Code<>nil then begin
    Code.AbsoluteToLineCol(p,Line,Col);
    Result:='('+IntToStr(Line)+','+IntToStr(Col)+')';
  end else begin
    Result:='(p='+IntToStr(p)+')';
  end;
end;

{ TFABPositionIndents }

procedure TFABPositionIndents.SetCount(const AValue: integer);
begin
  if FCount=AValue then exit;
  ReAllocMem(Items,SizeOf(TFABPositionIndent)*AValue);
  if AValue>FCount then
    FillByte(Items[FCount],SizeOf(TFABPositionIndent)*(AValue-FCount),0);
  FCount:=AValue;
end;

constructor TFABPositionIndents.Create;
begin

end;

destructor TFABPositionIndents.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TFABPositionIndents.Clear;
begin
  Count:=0;
end;

end.

