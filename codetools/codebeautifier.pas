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

  Examples for beautification styles: see scanexamples/indentation.pas

  ToDo:
    * ecLineBreak:
      - indent depends on next atom:
          if true then |
            |exit;
          if true then |
          |begin
      - fix last line after pressing return key:
          if true then
          exit;|
          |
    * long lines
    * ecPaste
}
unit CodeBeautifier;

{$mode objfpc}{$H+}

interface

{ $DEFINE ShowCodeBeautifier}
{ $DEFINE ShowCodeBeautifierParser}
{ $DEFINE ShowCodeBeautifierLearn}

{$IFDEF ShowCodeBeautifierParser}
{$DEFINE ShowCodeBeautifierLearn}
{$ENDIF}

uses
  Classes, SysUtils, AVL_Tree, FileProcs, KeywordFuncLists, CodeCache,
  BasicCodeTools;
  
type
  TBeautifySplit =(
    bsNone,
    bsInsertSpace, // insert space before
    bsNewLine,     // break line, no indent
    bsEmptyLine,   // insert empty line, no indent
    bsNewLineAndIndent, // break line, indent
    bsEmptyLineAndIndent, // insert empty line, indent
    bsNewLineUnindent,
    bsEmptyLineUnindent,
    bsNoSplit   // do not break line here when line too long
    );
    
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
    // type blocks
    bbtRecord,
    bbtClass,
    bbtClassInterface,
    bbtClassSection, // public, private, protected, published
    bbtTypeRoundBracket,
    bbtTypeEdgeBracket,
    // statement blocks
    bbtProcedure, // procedure, constructor, destructor
    bbtFunction,
    bbtProcedureParamList,
    bbtProcedureModifiers,
    bbtProcedureBegin,
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
    bbtStatementRoundBracket,
    bbtStatementEdgeBracket
    );
  TFABBlockTypes = set of TFABBlockType;

const
  bbtAllIdentifierSections = [bbtTypeSection,bbtConstSection,bbtVarSection,
       bbtResourceStringSection,bbtLabelSection];
  bbtAllCodeSections = [bbtInterface,bbtImplementation,bbtInitialization,
                        bbtFinalization];
  bbtAllStatements = [bbtMainBegin,bbtFreeBegin,bbtRepeat,bbtProcedureBegin,
                      bbtCaseColon,bbtCaseBegin,bbtCaseElse,
                      bbtTry,bbtFinally,bbtExcept,
                      bbtIfThen,bbtIfElse,bbtIfBegin,
                      bbtStatementRoundBracket,bbtStatementEdgeBracket];
  bbtAllBrackets = [bbtTypeRoundBracket,bbtTypeEdgeBracket,
                    bbtStatementRoundBracket,bbtStatementEdgeBracket];
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
    // type blocks
    'bbtRecord',
    'bbtClass',
    'bbtClassInterface',
    'bbtClassSection',
    'bbtTypeRoundBracket',
    'bbtTypeEdgeBracket',
    // statement blocks
    'bbtProcedure',
    'bbtFunction',
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
    'bbtStatementRoundBracket',
    'bbtStatementEdgeBracket'
    );

type
  TOnGetFABExamples = procedure(Sender: TObject; Code: TCodeBuffer;
                                Step: integer; // starting at 0
                                var CodeBuffers: TFPList; // stopping when CodeBuffers=nil
                                var ExpandedFilenames: TStrings  // and Filenames=nil
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

  { TFABBlockStack }

  TFABBlockStack = class
  public
    Stack: PBlock;
    Capacity: integer;
    Top: integer;
    TopType: TFABBlockType;
    constructor Create;
    destructor Destroy; override;
    procedure BeginBlock(Typ: TFABBlockType; StartPos: integer);
    procedure EndBlock;
    function TopMostIndexOf(Typ: TFABBlockType): integer;
    function EndTopMostBlock(Typ: TFABBlockType): boolean;
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
    procedure ParseSource(const Src: string; StartPos, EndPos: integer;
      NestedComments: boolean;
      Stack: TFABBlockStack; Policies: TFABPolicies;
      out LastAtomStart, LastAtomEnd: integer // set if LastAtomStart<EndPos<LastAtomEnd
      );
    procedure ParseSource(const Src: string; StartPos, EndPos: integer;
                          NestedComments: boolean;
                          Stack: TFABBlockStack; Policies: TFABPolicies);
    function FindPolicyInExamples(StartCode: TCodeBuffer;
                                  ParentTyp, Typ: TFABBlockType): TFABPolicies;
    function GetNestedCommentsForCode(Code: TCodeBuffer): boolean;
    function FindStackPosForBlockCloseAtPos(const Source: string;
                             CleanPos: integer; NestedComments: boolean;
                             Stack: TFABBlockStack): integer;
    procedure WriteDebugReport(Msg: string; Stack: TFABBlockStack);
  public
    DefaultTabWidth: integer;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function GetIndent(const Source: string; CleanPos: integer;
                       NewNestedComments: boolean; UseLineStart: boolean;
                       out Indent: TFABIndentationPolicy): boolean;
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
end;

procedure TFABBlockStack.EndBlock;
begin
  {$IFDEF ShowCodeBeautifier}
  DebugLn([GetIndentStr(Top*2),'TFABBlockStack.EndBlock ',FABBlockTypeNames[TopType]]);
  {$ENDIF}
  dec(Top);
  if Top>=0 then
    TopType:=Stack[Top].Typ
  else
    TopType:=bbtNone;
end;

function TFABBlockStack.TopMostIndexOf(Typ: TFABBlockType): integer;
begin
  Result:=Top;
  while (Result>=0) and (Stack[Result].Typ<>Typ) do dec(Result);
end;

function TFABBlockStack.EndTopMostBlock(Typ: TFABBlockType): boolean;
// check if there is this type on the stack and if yes, end it
var
  i: LongInt;
begin
  i:=TopMostIndexOf(Typ);
  if i<0 then exit(false);
  Result:=true;
  while Top>=i do EndBlock;
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
  Policies: TFABPolicies; out LastAtomStart, LastAtomEnd: integer);
var
  p: Integer;
  AtomStart: integer;
  FirstAtomOnNewLine: Boolean;

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
    FirstAtomOnNewLine:=false;
    if (Stack.Top>=0) then begin
      Block:=@Stack.Stack[Stack.Top];
      if (Block^.InnerStartPos=AtomStart)
      and (Policies<>nil) then begin
        if Block^.InnerIdent<0 then UpdateBlockInnerIndent;
        if Block^.InnerIdent>=0 then begin
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
    FirstAtomOnNewLine:=false;
    Stack.EndBlock;
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

  procedure EndIdentifierSectionAndProc;
  begin
    EndStatements;  // fix dangling statements
    if Stack.TopType=bbtProcedureModifiers then
      EndBlock;
    if Stack.TopType in [bbtProcedure,bbtFunction] then begin
      if (Stack.Top=0) or (Stack.Stack[Stack.Top-1].Typ in [bbtImplementation])
      then begin
        // procedure with begin..end
      end else begin
        // procedure without begin..end
        EndBlock;
      end;
    end;
    if Stack.TopType in bbtAllIdentifierSections then
      EndBlock;
  end;

  procedure StartIdentifierSection(Section: TFABBlockType);
  begin
    EndIdentifierSectionAndProc;
    if Stack.TopType in (bbtAllCodeSections+[bbtNone,bbtProcedure,bbtFunction]) then
      BeginBlock(Section);
  end;

  procedure StartProcedure(Typ: TFABBlockType);
  begin
    EndIdentifierSectionAndProc;
    if Stack.TopType in (bbtAllCodeSections+[bbtNone,bbtProcedure,bbtFunction]) then
      BeginBlock(Typ);
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

var
  r: PChar;
  Block: PBlock;
  CommentStartPos: LongInt;
  CommentEndPos: LongInt;
begin
  p:=StartPos;
  if EndPos>length(Src) then EndPos:=length(Src)+1;
  AtomStart:=p;
  repeat
    LastAtomStart:=AtomStart;
    LastAtomEnd:=p;
    ReadRawNextPascalAtom(Src,p,AtomStart,NestedComments);
    //DebugLn(['TFullyAutomaticBeautifier.ParseSource Atom=',copy(Src,AtomStart,p-AtomStart)]);
    if p>EndPos then begin
      if (AtomStart<EndPos) then begin
        LastAtomStart:=AtomStart;
        LastAtomEnd:=p;
      end else begin
        LastAtomStart:=0;
        LastAtomEnd:=0;
        // EndPos between two atom: in space or comment
        CommentStartPos:=FindNextNonSpace(Src,LastAtomEnd);
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

    if Stack.TopType=bbtProcedureModifiers then begin
      // ToDo: check if modifier
      EndBlock;
    end;

    case UpChars[r^] of
    'B':
      if CompareIdentifiers('BEGIN',r)=0 then begin
        while Stack.TopType
        in (bbtAllIdentifierSections+bbtAllCodeSections+bbtAllBrackets) do
          EndBlock;
        case Stack.TopType of
        bbtNone:
          BeginBlock(bbtMainBegin);
        bbtProcedure,bbtFunction:
          BeginBlock(bbtProcedureBegin);
        bbtMainBegin,bbtProcedureBegin:
          BeginBlock(bbtFreeBegin);
        bbtCaseElse,bbtCaseColon:
          BeginBlock(bbtCaseBegin);
        bbtIfThen,bbtIfElse:
          BeginBlock(bbtIfBegin);
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
          if Stack.TopType=bbtTypeSection then
            BeginBlock(bbtClass);
        end;
      'O': // CO
        if CompareIdentifiers('CONST',r)=0 then
          StartIdentifierSection(bbtConstSection);
      end;
    'E':
      case UpChars[r[1]] of
      'L': // EL
        if CompareIdentifiers('ELSE',r)=0 then begin
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
          while Stack.TopType in [bbtIf,bbtIfThen,bbtIfElse] do EndBlock;
          if Stack.TopType in [bbtProcedure,bbtFunction] then
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
              if Stack.TopType in [bbtProcedure,bbtFunction] then
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
          while Stack.TopType in (bbtAllCodeSections+bbtAllIdentifierSections+bbtAllStatements)
          do
            EndBlock;
          if Stack.TopType=bbtNone then
            BeginBlock(bbtInitialization);
        end else if CompareIdentifiers('FINALLY',r)=0 then begin
          if Stack.TopType=bbtTry then begin
            EndBlock;
            BeginBlock(bbtFinally);
          end;
        end;
      'O': // FO
        if CompareIdentifiers('FORWARD',r)=0 then begin
          if Stack.TopType in [bbtProcedure,bbtFunction] then begin
            EndBlock;
          end;
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
            while Stack.TopType in (bbtAllCodeSections+bbtAllIdentifierSections+bbtAllStatements)
            do
              EndBlock;
            if Stack.TopType=bbtNone then
              BeginBlock(bbtInitialization);
          end;
        'T': // INT
          if CompareIdentifiers('INTERFACE',r)=0 then begin
            case Stack.TopType of
            bbtNone:
              BeginBlock(bbtInterface);
            bbtTypeSection:
              BeginBlock(bbtClassInterface);
            end;
          end;
        end;
      'M': // IM
        if CompareIdentifiers('IMPLEMENTATION',r)=0 then begin
          while Stack.TopType in (bbtAllCodeSections+bbtAllIdentifierSections+bbtAllStatements)
          do
            EndBlock;
          if Stack.TopType=bbtNone then
            BeginBlock(bbtImplementation);
        end;
      end;
    'L':
      if CompareIdentifiers('LABEL',r)=0 then
        StartIdentifierSection(bbtLabelSection);
    'O':
      if CompareIdentifiers('OF',r)=0 then begin
        case Stack.TopType of
        bbtCase:
          BeginBlock(bbtCaseOf);
        bbtClass,bbtClassInterface:
          EndBlock;
        end;
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
      bbtUsesSection:
        EndBlock;
      bbtCaseColon:
        begin
          EndBlock;
          BeginBlock(bbtCaseOf);
        end;
      bbtIfThen,bbtIfElse:
        while Stack.TopType in [bbtIf,bbtIfThen,bbtIfElse] do
          EndBlock;
      bbtProcedure,bbtFunction:
        BeginBlock(bbtProcedureModifiers);
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
        bbtProcedure,bbtFunction:
          BeginBlock(bbtProcedureParamList);
        else
          if Stack.TopType in bbtAllStatements then
            BeginBlock(bbtStatementRoundBracket)
          else
            BeginBlock(bbtTypeRoundBracket);
        end;
      end;
    ')':
      if p-AtomStart=1 then begin
        // round bracket close
        EndTopMostBlock(bbtStatementEdgeBracket);
        case Stack.TopType of
        bbtProcedureParamList,bbtTypeRoundBracket,bbtStatementRoundBracket:
          EndBlock;
        end;
      end;
    '[':
      if p-AtomStart=1 then begin
        // edge bracket open
        if Stack.TopType in bbtAllStatements then
          BeginBlock(bbtStatementEdgeBracket)
        else
          BeginBlock(bbtTypeEdgeBracket);
      end;
    ']':
      if p-AtomStart=1 then begin
        // edge bracket close
        EndTopMostBlock(bbtStatementRoundBracket);
        case Stack.TopType of
        bbtTypeEdgeBracket,bbtStatementEdgeBracket:
          EndBlock;
        end;
      end;
    end;

    if FirstAtomOnNewLine then begin
      UpdateBlockInnerIndent;
      if Block^.InnerIdent>=0 then begin
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
  Policies: TFABPolicies);
var
  LastAtomStart, LastAtomEnd: integer;
begin
  ParseSource(Src,StartPos,EndPos,NestedComments,Stack,Policies,
              LastAtomStart,LastAtomEnd);
end;

function TFullyAutomaticBeautifier.FindPolicyInExamples(StartCode: TCodeBuffer;
  ParentTyp, Typ: TFABBlockType): TFABPolicies;

  function CheckCode(Code: TCodeBuffer; out Policies: TFABPolicies): boolean;
  // result=false : abort
  var
    AVLNode: TAVLTreeNode;
    Stack: TFABBlockStack;
  begin
    Policies:=nil;
    if Code=nil then exit(true);
    DebugLn(['TFullyAutomaticBeautifier.FindPolicyInExamples ',Code.Filename]);
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
    if Policies.GetSmallestIndent(Typ)>=0 then begin
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
  Stack: TFABBlockStack): integer;
{ For example:
    if expr then
      begin
        |DoSomething;

    if expr then
      begin
      |end;
}

  procedure EndIdentifierSectionAndProc;
  begin
    if Stack.TopType in bbtAllIdentifierSections then
      dec(FindStackPosForBlockCloseAtPos);
  end;

  procedure StartProcedure;
  begin
    if Stack.TopType in bbtAllIdentifierSections then
      dec(FindStackPosForBlockCloseAtPos);
  end;

  function IsMethodDeclaration: boolean;
  begin
    Result:=(Stack.TopType in [bbtProcedure,bbtFunction])
      and (Stack.Top>0) and (Stack.Stack[Stack.Top-1].Typ=bbtClassSection);
  end;

  procedure EndClassSection;
  begin
    if Stack.TopType=bbtClassSection then
      dec(FindStackPosForBlockCloseAtPos)
    else if IsMethodDeclaration then
      dec(FindStackPosForBlockCloseAtPos,2);
  end;

  procedure EndBigSection;
  begin
    while Stack.TopType in (bbtAllCodeSections+bbtAllIdentifierSections+bbtAllStatements)
    do
      dec(FindStackPosForBlockCloseAtPos);
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
  Result:=Stack.Top;
  if Result<0 then exit;
  if (CleanPos<1) or (CleanPos>length(Source))
  or (Source[CleanPos] in [#0..#31,' ']) then
    exit;
  p:=CleanPos;
  ReadRawNextPascalAtom(Source,p,AtomStart,NestedComments);
  if AtomStart<>p then exit;
  DebugLn(['TFullyAutomaticBeautifier.FindStackPosForBlockCloseAtPos Atom=',copy(Source,AtomStart,CleanPos-AtomStart)]);
  r:=@Source[AtomStart];
  case UpChars[r^] of
  'C':
    if CompareIdentifiers('CONST',r)=0 then
      EndIdentifierSectionAndProc;
  'E':
    case UpChars[r[1]] of
    'L': // EL
      if CompareIdentifiers('ELSE',r)=0 then begin
        case Stack.TopType of
        bbtCaseOf,bbtCaseColon:
          dec(Result);
        bbtIfThen:
          dec(Result);
        end;
      end;
    'N': // EN
      if CompareIdentifiers('END',r)=0 then begin
        // if statements can be closed by end without semicolon
        while Stack.TopType in [bbtIf,bbtIfThen,bbtIfElse] do
          dec(Result);
        if IsMethodDeclaration then
          dec(Result,2);
        if Stack.TopType=bbtClassSection then
          dec(Result);

        case Stack.TopType of
        bbtMainBegin,bbtFreeBegin,
        bbtRecord,bbtClass,bbtClassInterface,bbtTry,bbtFinally,bbtExcept,
        bbtCase,bbtCaseBegin,bbtIfBegin:
          dec(Result);
        bbtCaseOf,bbtCaseColon,bbtCaseElse:
          begin
            dec(Result);
            if Stack.TopType=bbtCase then
              dec(Result);
          end;
        bbtProcedureBegin:
          dec(Result);
        bbtInterface,bbtImplementation,bbtInitialization,bbtFinalization:
          dec(Result);
        end;
      end;
    'X': // EX
      if CompareIdentifiers('EXCEPT',r)=0 then begin
        if Stack.TopType=bbtTry then
          dec(Result);
      end;
    end;
  'F':
    case UpChars[r[1]] of
    'I': // FI
      if CompareIdentifiers('FINALIZATION',r)=0 then begin
        EndBigSection;
      end else if CompareIdentifiers('FINALLY',r)=0 then begin
        if Stack.TopType=bbtTry then
          dec(Result);
      end;
    end;
  'I':
    case UpChars[r[1]] of
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
  UseLineStart: boolean; out Indent: TFABIndentationPolicy): boolean;
var
  Block: TBlock;

  function CheckPolicies(Policies: TFABPolicies; var Found: boolean): boolean;
  // returns true to stop searching
  var
    BlockIndent: LongInt;
  begin
    Result:=false;
    Found:=false;
    if (Policies=nil) then exit;
    BlockIndent:=Policies.GetSmallestIndent(Block.Typ);
    if (BlockIndent<0) then exit;
    // policy found
    DebugLn(['TFullyAutomaticBeautifier.GetIndent policy found: Block.Typ=',FABBlockTypeNames[Block.Typ],' BlockIndent=',BlockIndent]);
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
  ParentBlock: TBlock;
  StackIndex: LongInt;
begin
  Result:=false;
  FillByte(Indent,SizeOf(Indent),0);

  CleanPos:=FindStartOfAtom(Source,CleanPos);
  if CleanPos<1 then exit;

  if UseLineStart then begin
    while (CleanPos<=length(Source)) and (Source[CleanPos] in [' ',#9]) do
      inc(CleanPos);
  end;

  Block:=CleanBlock;
  ParentBlock:=CleanBlock;
  Policies:=TFABPolicies.Create;
  Stack:=TFABBlockStack.Create;
  try
    {$IFDEF ShowCodeBeautifierLearn}
    Policies.Code:=TCodeBuffer.Create;
    Policies.Code.Source:=Source;
    {$ENDIF}
    // parse source in front
    DebugLn(['TFullyAutomaticBeautifier.GetIndent "',dbgstr(copy(Source,CleanPos-10,10)),'|',dbgstr(copy(Source,CleanPos,10)),'"']);
    ParseSource(Source,1,CleanPos,NewNestedComments,Stack,Policies,
                LastAtomStart,LastAtomEnd);
    WriteDebugReport('After parsing code in front:',Stack);
    if (LastAtomStart>0) and (CleanPos>LastAtomStart) then begin
      // in comment or atom
      DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed code in front: position in middle of atom, e.g. comment']);
      GetDefaultSrcIndent(Source,CleanPos,NewNestedComments,Indent);
      exit(Indent.IndentValid);
    end;
    if LastAtomStart>0 then CleanPos:=LastAtomStart;

    StackIndex:=Stack.Top;
    if UseLineStart then
      StackIndex:=FindStackPosForBlockCloseAtPos(Source,CleanPos,
                                                 NewNestedComments,Stack);

    if (StackIndex<0) then begin
      // no context
      DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed code in front: no context']);
      GetDefaultSrcIndent(Source,CleanPos,NewNestedComments,Indent);
      exit(Indent.IndentValid);
    end;

    Block:=Stack.Stack[StackIndex];

    if StackIndex>0 then
      ParentBlock:=Stack.Stack[StackIndex-1];
    DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed code in front: context=',FABBlockTypeNames[ParentBlock.Typ],'/',FABBlockTypeNames[Block.Typ],' indent=',GetLineIndentWithTabs(Source,Block.StartPos,DefaultTabWidth)]);
    if CheckPolicies(Policies,Result) then exit;

    // parse source behind
    ParseSource(Source,CleanPos,length(Source)+1,NewNestedComments,Stack,Policies);
    DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed source behind']);
    if CheckPolicies(Policies,Result) then exit;

  finally
    Stack.Free;
    FreeAndNil(Policies.Code);
    Policies.Free;
  end;

  // parse examples
  Policies:=FindPolicyInExamples(nil,ParentBlock.Typ,Block.Typ);
  DebugLn(['TFullyAutomaticBeautifier.GetIndent parsed examples']);
  if CheckPolicies(Policies,Result) then exit;

  //GetDefaultIndentPolicy(ParentBlock.Typ,Block.Typ);
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

end.

