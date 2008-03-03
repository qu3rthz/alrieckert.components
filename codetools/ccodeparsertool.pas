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
    A simple C parser.
}
unit CCodeParserTool;

{$mode objfpc}{$H+}

interface

{$I codetools.inc}

uses
  {$IFDEF MEM_CHECK}
  MemCheck,
  {$ENDIF}
  Classes, SysUtils, FileProcs, CodeToolsStructs, BasicCodeTools,
  KeywordFuncLists, LinkScanner, CodeAtom, CodeCache, AVL_Tree,
  CodeToolsStrConsts, CodeTree, NonPascalCodeTools;

type
  TCCodeNodeDesc = word;

const
  // descriptors
  ccnBase           = 1000;
  ccnNone           =  0+ccnBase;
  
  ccnRoot           =  1+ccnBase;
  ccnDirective      =  2+ccnBase;// e.g. "#define a" ,can be multiple lines, without line end
  ccnExtern         =  3+ccnBase;// e.g. extern "C" {}
  ccnEnums          =  4+ccnBase;// e.g. enum {};
  ccnEnum           =  5+ccnBase;// e.g. name = value;
  ccnConstant       =  6+ccnBase;// e.g. 1
  ccnTypedef        =  7+ccnBase;// e.g. typedef int TInt;
  ccnStruct         =  8+ccnBase;// e.g. struct{};
  ccnVariable       =  9+ccnBase;// e.g. int i
  ccnVariableName   = 10+ccnBase;// e.g. i
  ccnFuncParamList  = 11+ccnBase;// e.g. ()
  ccnStatementBlock = 12+ccnBase;// e.g. {}

type
  TCCodeParserTool = class;

  { ECCodeParserException }

  ECCodeParserException = class(Exception)
  public
    Sender: TCCodeParserTool;
    constructor Create(ASender: TCCodeParserTool; const AMessage: string);
  end;

  { TCCodeParserTool }

  TCCodeParserTool = class
  private
    FChangeStep: integer;
    FDefaultTokenList: TKeyWordFunctionList;

    function OtherToken: boolean;
    function DirectiveToken: boolean;
    function EnumToken: boolean;
    function ExternToken: boolean;
    function CurlyBracketCloseToken: boolean;
    function TypedefToken: boolean;
    function StructToken: boolean;
    procedure InitKeyWordList;

    procedure InitParser;
    procedure CreateChildNode(Desc: TCCodeNodeDesc);
    procedure EndChildNode;
    procedure CloseNodes;
    
    procedure ReadEnum;
    procedure ReadStruct(NeedIdentifier: boolean);
    procedure ReadConstant;
    procedure ReadVariable;
    
    procedure RaiseException(const AMessage: string; ReportPos: integer = 0);
    procedure RaiseExpectedButAtomFound(const AToken: string; ReportPos: integer = 0);
  public
    Code: TCodeBuffer;
    Src: string;
    SrcLen: integer;
    Tree: TCodeTree;
    CurNode: TCodeTreeNode;
    SrcPos: Integer;
    AtomStart: integer;
    ParseChangeStep: integer;// = Code.ChangeStep at the time of last Parse

    VisibleEditorLines: integer;
    JumpCentered: boolean;
    CursorBeyondEOL: boolean;

    LastSrcPos: integer;
    LastAtomStart: integer;
    
    LastErrorMsg: string;
    LastErrorPos: integer;  // the position where the code does no make sense
    LastErrorReportPos: integer; // if the position that gives a human a clue what went wrong
                             // normally LastErrorReportPos=LastErrorPos
                             // but if a closing bracket is missing LastErrorReportPos points
                             // to ( and ErrorPos to next atom

    constructor Create;
    destructor Destroy; override;
    procedure Clear;

    procedure Parse;
    procedure Parse(aCode: TCodeBuffer);
    function UpdateNeeded: boolean;

    function FindDeepestNodeAtPos(P: integer;
      ExceptionOnNotFound: boolean): TCodeTreeNode; inline;
    function FindDeepestNodeAtPos(StartNode: TCodeTreeNode; P: integer;
      ExceptionOnNotFound: boolean): TCodeTreeNode;
    function CaretToCleanPos(Caret: TCodeXYPosition;
        out CleanPos: integer): integer;  // 0=valid CleanPos
                          //-1=CursorPos was skipped, CleanPos between two links
                          // 1=CursorPos beyond scanned code
                          //-2=X,Y beyond source
    function CleanPosToCodePos(CleanPos: integer;
        out CodePos:TCodePosition): boolean; // true=ok, false=invalid CleanPos
    function CleanPosToCaret(CleanPos: integer;
        out Caret:TCodeXYPosition): boolean; // true=ok, false=invalid CleanPos
    function CleanPosToCaretAndTopLine(CleanPos: integer;
        out Caret:TCodeXYPosition; out NewTopLine: integer): boolean; // true=ok, false=invalid CleanPos
    function CleanPosToStr(CleanPos: integer): string;
    function MainFilename: string;

    procedure MoveCursorToPos(p: integer);
    procedure ReadNextAtom;
    procedure UndoReadNextAtom;
    function ReadTilBracketClose(ExceptionOnNotFound: boolean): boolean;
    function AtomIs(const s: shortstring): boolean;
    function AtomIsChar(const c: char): boolean;
    function UpAtomIs(const s: shortstring): boolean;
    function AtomIsIdentifier: boolean;
    function AtomIsStringConstant: boolean;
    function GetAtom: string;
    function LastAtomIs(const s: shortstring): boolean;
    function GetLastAtom: string;

    procedure Replace(FromPos, ToPos: integer; const NewSrc: string);

    procedure IncreaseChangeStep;
    procedure WriteDebugReport;
    procedure CheckNodeTool(Node: TCodeTreeNode);

    property ChangeStep: integer read FChangeStep;
  end;
  
function CCNodeDescAsString(Desc: TCCodeNodeDesc): string;
procedure InitCCodeKeyWordLists;

var
  IsCCodeFunctionModifier: TKeyWordFunctionList = nil;
  IsCCodeCustomOperator: TKeyWordFunctionList = nil;

implementation

var
  KeyWordLists: TFPList;

function CCNodeDescAsString(Desc: TCCodeNodeDesc): string;
begin
  case Desc of
  ccnNone     : Result:='None';
  ccnRoot     : Result:='Root';
  ccnDirective: Result:='Directive';
  ccnExtern   : Result:='extern block';
  ccnEnums    : Result:='enums';
  ccnEnum     : Result:='enum';
  ccnConstant : Result:='constant';
  ccnTypedef  : Result:='typedef';
  ccnStruct   : Result:='struct';
  ccnVariable : Result:='variable';
  ccnVariableName: Result:='variable name';
  ccnFuncParamList: Result:='function param list';
  ccnStatementBlock: Result:='statement block';
  else          Result:='?';
  end;
end;

procedure InitCCodeKeyWordLists;
begin
  if KeyWordLists<>nil then exit;
  KeyWordLists:=TFPList.Create;
  
  IsCCodeFunctionModifier:=TKeyWordFunctionList.Create;
  KeyWordLists.Add(IsCCodeFunctionModifier);
  with IsCCodeFunctionModifier do begin
    Add('static'     ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('inline'     ,{$ifdef FPC}@{$endif}AllwaysTrue);
  end;

  IsCCodeCustomOperator:=TKeyWordFunctionList.Create;
  KeyWordLists.Add(IsCCodeCustomOperator);
  with IsCCodeCustomOperator do begin
    Add('+'     ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('-'     ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('*'     ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('/'     ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('|'     ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('&'     ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('='     ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('++'    ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('--'    ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('+='    ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('-='    ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('*='    ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('/='    ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('&='    ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('|='    ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('=='    ,{$ifdef FPC}@{$endif}AllwaysTrue);
    Add('!='    ,{$ifdef FPC}@{$endif}AllwaysTrue);
  end;
end;

{ ECCodeParserException }

constructor ECCodeParserException.Create(ASender: TCCodeParserTool;
  const AMessage: string);
begin
  inherited Create(AMessage);
  Sender:=ASender;
end;

{ TCCodeParserTool }

function TCCodeParserTool.OtherToken: boolean;
begin
  Result:=true;
  if AtomIsChar(';') then
    // ignore
  else if AtomIsIdentifier then begin
    ReadVariable;
  end else
    RaiseException('unexpected token '+GetAtom);
end;

function TCCodeParserTool.DirectiveToken: boolean;
begin
  Result:=true;
  CreateChildNode(ccnDirective);
  // read til end of line
  ReadTilCLineEnd(Src,SrcPos);
  AtomStart:=SrcPos;
  EndChildNode;
end;

function TCCodeParserTool.EnumToken: boolean;
begin
  Result:=true;
  ReadEnum;
  // read semicolon
  ReadNextAtom;
  if not AtomIsChar(';') then
    RaiseExpectedButAtomFound(';');
end;

function TCCodeParserTool.ExternToken: boolean;
begin
  Result:=true;
  CreateChildNode(ccnExtern);
  ReadNextAtom;
  if not AtomIsStringConstant then
    RaiseExpectedButAtomFound('string constant');
  ReadNextAtom;
  if not AtomIsChar('{') then
    RaiseExpectedButAtomFound('{');
end;

function TCCodeParserTool.CurlyBracketCloseToken: boolean;
// examples:
//  end of 'extern "C" {'
begin
  Result:=true;
  if CurNode.Desc=ccnExtern then
    EndChildNode
  else
    RaiseException('} without {');
end;

procedure TCCodeParserTool.ReadEnum;
(* For example:
  enum {
    TEST_ENUM1 = 1, /* Enum starts at 1 */
    TEST_ENUM2,
    TEST_ENUM3
  };
  enum e1{dark, light};

*)
begin
  CreateChildNode(ccnEnums);
  ReadNextAtom;
  // read optional name
  if AtomIsIdentifier then
    ReadNextAtom;
  if not AtomIsChar('{') then
    RaiseExpectedButAtomFound('{');
  // read enums. Examples
  // name,
  // name = constant,
  ReadNextAtom;
  repeat
    if AtomIsIdentifier then begin
      // read enum
      CreateChildNode(ccnEnum);
      CurNode.EndPos:=SrcPos;
      ReadNextAtom;
      if AtomIsChar('=') then begin
        // read value
        ReadNextAtom;
        ReadConstant;
        CurNode.EndPos:=SrcPos;
        ReadNextAtom;
      end;
      EndChildNode;
    end;
    if AtomIsChar(',') then begin
      // next enum
      ReadNextAtom;
      if not AtomIsIdentifier then
        RaiseExpectedButAtomFound('identifier');
    end else if AtomIsChar('}') then begin
      break;
    end else
      RaiseExpectedButAtomFound('}');
  until false;
  EndChildNode;
end;

procedure TCCodeParserTool.ReadStruct(NeedIdentifier: boolean);
(*  Example for NeedIdentifier=false:
  typedef struct {
    uint8_t b[6]; // implicit type
  } __attribute__((packed)) bdaddr_t;

  Example for NeedIdentifier=true:
    struct hidp_connadd_req {
      int ctrl_sock;
    }
    struct hidp_conninfo *ci;

  typedef struct _sdp_list sdp_list_t;
*)
begin
  CreateChildNode(ccnStruct);
  
  ReadNextAtom;
  if NeedIdentifier then begin
    // read type name
    if not AtomIsIdentifier then
      RaiseExpectedButAtomFound('identifier');
    ReadNextAtom;
  end;
  
  if AtomIsChar('{') then begin
    // read block {}
    repeat
      ReadNextAtom;
      // read variables
      if AtomIsIdentifier then begin
        ReadVariable;
        ReadNextAtom;
        if AtomIsChar('}') then
          break
        else if AtomIsChar(';') then begin
          // next identifier
        end else
          RaiseExpectedButAtomFound('}');
      end else if AtomIsChar('}') then
        break
      else
        RaiseExpectedButAtomFound('identifier');
    until false;
    // read attributes
    ReadNextAtom;
    if AtomIs('__attribute__') then begin
      ReadNextAtom;
      if not AtomIsChar('(') then
        RaiseExpectedButAtomFound('(');
      ReadTilBracketClose(true);
    end else begin
      UndoReadNextAtom;
    end;
  end else if AtomIsIdentifier then begin
    // using another struct
  end else
    RaiseExpectedButAtomFound('{');

  // close node
  EndChildNode;
end;

function TCCodeParserTool.TypedefToken: boolean;
begin
  Result:=true;
  CreateChildNode(ccnTypedef);
  // read type
  ReadNextAtom;
  if AtomIs('enum') then
    ReadEnum
  else if AtomIs('struct') then
    ReadStruct(false)
  else if AtomIsIdentifier then begin

  end else
    RaiseExpectedButAtomFound('identifier');
  // read typedef name
  ReadNextAtom;
  if not AtomIsIdentifier then
    RaiseExpectedButAtomFound('identifier');
  // read semicolon
  ReadNextAtom;
  if not AtomIsChar(';') then
    RaiseExpectedButAtomFound(';');
  EndChildNode;
end;

function TCCodeParserTool.StructToken: boolean;
begin
  Result:=true;
  ReadStruct(true);
end;

procedure TCCodeParserTool.InitKeyWordList;
begin
  if FDefaultTokenList=nil then begin
    FDefaultTokenList:=TKeyWordFunctionList.Create;
    with FDefaultTokenList do begin
      Add('#',{$ifdef FPC}@{$endif}DirectiveToken);
      Add('extern',{$ifdef FPC}@{$endif}ExternToken);
      Add('}',{$ifdef FPC}@{$endif}CurlyBracketCloseToken);
      Add('enum',{$ifdef FPC}@{$endif}EnumToken);
      Add('typedef',{$ifdef FPC}@{$endif}TypedefToken);
      Add('struct',{$ifdef FPC}@{$endif}StructToken);
      DefaultKeyWordFunction:={$ifdef FPC}@{$endif}OtherToken;
    end;
  end;
end;

procedure TCCodeParserTool.InitParser;
begin
  ParseChangeStep:=Code.ChangeStep;
  IncreaseChangeStep;
  InitKeyWordList;
  Src:=Code.Source;
  SrcLen:=length(Src);
  if Tree=nil then
    Tree:=TCodeTree.Create
  else
    Tree.Clear;
  SrcPos:=1;
  AtomStart:=1;
  CurNode:=nil;
  CreateChildNode(ccnRoot);
end;

procedure TCCodeParserTool.CreateChildNode(Desc: TCCodeNodeDesc);
var
  NewNode: TCodeTreeNode;
begin
  NewNode:=NodeMemManager.NewNode;
  Tree.AddNodeAsLastChild(CurNode,NewNode);
  NewNode.Desc:=Desc;
  CurNode:=NewNode;
  CurNode.StartPos:=AtomStart;
  DebugLn([GetIndentStr(CurNode.GetLevel*2),'TCCodeParserTool.CreateChildNode ']);
end;

procedure TCCodeParserTool.EndChildNode;
begin
  DebugLn([GetIndentStr(CurNode.GetLevel*2),'TCCodeParserTool.EndChildNode ']);
  if CurNode.EndPos<=0 then
    CurNode.EndPos:=SrcPos;
  CurNode:=CurNode.Parent;
end;

procedure TCCodeParserTool.CloseNodes;
var
  Node: TCodeTreeNode;
begin
  Node:=CurNode;
  while Node<>nil do begin
    Node.EndPos:=AtomStart;
    Node:=Node.Parent;
  end;
end;

procedure TCCodeParserTool.ReadConstant;
begin
  if AtomIsChar(',') or AtomIsChar(';') then
    RaiseExpectedButAtomFound('identifier');
  CreateChildNode(ccnConstant);
  repeat
    if AtomIsChar('(') or AtomIsChar('[') then
      ReadTilBracketClose(true);
    CurNode.EndPos:=SrcPos;
    ReadNextAtom;
    if AtomIsChar(',') or AtomIsChar(';')
    or AtomIsChar(')') or AtomIsChar(']') or AtomIsChar('}')
    then
      break;
  until false;
  UndoReadNextAtom;
  EndChildNode;
end;

procedure TCCodeParserTool.ReadVariable;
(* Read  type name [specifiers]

  Examples:

  int i
  uint8_t b[6]
  uint8_t lap[MAX_IAC_LAP][3];
  int y = 7;

  static inline int bacmp(const bdaddr_t *ba1, const bdaddr_t *ba2)
  {
        return memcmp(ba1, ba2, sizeof(bdaddr_t));
  }
  bdaddr_t *strtoba(const char *str);

  complex operator+(complex, complex);
*)
var
  IsFunction: Boolean;
  NeedEnd: Boolean;
  LastIsName: Boolean;
begin
  DebugLn(['TCCodeParserTool.ReadVariable ']);
  CreateChildNode(ccnVariable);
  IsFunction:=false;
  if AtomIs('struct') then begin
    ReadNextAtom;
  end else if AtomIs('union') then begin
    ReadNextAtom;
    if not AtomIsChar('{') then
      RaiseExpectedButAtomFound('{');
    ReadTilBracketClose(true);
  end else if IsCCodeFunctionModifier.DoItCaseSensitive(Src,AtomStart,SrcPos-AtomStart)
  then begin
    // read function modifiers
    while IsCCodeFunctionModifier.DoItCaseSensitive(Src,AtomStart,SrcPos-AtomStart)
    do begin
      IsFunction:=true;
      ReadNextAtom;
      if not AtomIsIdentifier then
        RaiseExpectedButAtomFound('identifier');
    end;
  end;
  CreateChildNode(ccnVariableName);

  // prefixes: signed, unsigned
  // prefixes and/or names long, short

  // int, short int, short signed int
  // char, signed char, unsigned char
  // singed short, unsigned short, short
  // long, long long, signed long, signed long long, unsigned long, unsigned long long
  LastIsName:=false;
  repeat
    if AtomIs('signed') or AtomIs('unsigned') then begin
      LastIsName:=false;
      ReadNextAtom;
    end else if AtomIs('short') or AtomIs('long') then begin
      LastIsName:=true;
      ReadNextAtom;
    end else
      break;
  until false;
  if LastIsName then
    UndoReadNextAtom;

  // read name
  ReadNextAtom;
  if AtomIs('operator') then begin
    IsFunction:=true;
    // read operator
    ReadNextAtom;
    if not IsCCodeCustomOperator.DoItCaseSensitive(Src,AtomStart,SrcPos-AtomStart)
    then
      RaiseExpectedButAtomFound('operator');
  end else if AtomIsChar('(') then begin
    // example: int (*fp)(char*);
    //   pointer to function taking a char* argument; returns an int
    ReadNextAtom;
    while AtomIsChar('*') do begin
      // pointer
      ReadNextAtom;
    end;
    DebugLn(['TCCodeParserTool.ReadVariable name=',GetAtom]);
    if not AtomIsIdentifier then
      RaiseExpectedButAtomFound('identifier');
    ReadNextAtom;
    if not AtomIsChar(')') then
      RaiseExpectedButAtomFound(')');
  end else begin
    while AtomIsChar('*') do begin
      // pointer
      ReadNextAtom;
    end;

    DebugLn(['TCCodeParserTool.ReadVariable name=',GetAtom]);
    if not AtomIsIdentifier then
      RaiseExpectedButAtomFound('identifier');
  end;
  EndChildNode;

  ReadNextAtom;
  if IsFunction and (not AtomIsChar('(')) then
    RaiseExpectedButAtomFound('(');
  NeedEnd:=true;
  if AtomIsChar('(') then begin
    // this is a function => read parameter list
    CreateChildNode(ccnFuncParamList);
    ReadTilBracketClose(true);
    CurNode.EndPos:=SrcPos;
    EndChildNode;
    ReadNextAtom;
    if AtomIsChar('{') then begin
      // read statements {}
      CreateChildNode(ccnStatementBlock);
      ReadTilBracketClose(true);
      CurNode.EndPos:=SrcPos;
      EndChildNode;
    end else if not AtomIsChar(';') then begin
      // functions without statements are external and must end with a semicolon
      RaiseExpectedButAtomFound(';');
    end;
    NeedEnd:=false;
    ReadNextAtom;
  end else if AtomIsChar('[') then begin
    // read array brackets
    while AtomIsChar('[') do begin
      ReadTilBracketClose(true);
      ReadNextAtom;
    end;
  end;
  
  // read initial constant
  if AtomIsChar('=') then begin
    ReadNextAtom;
    ReadConstant;
    ReadNextAtom;
    NeedEnd:=true;
  end;
  
  // sanity check
  if (SrcPos<=SrcLen) and NeedEnd
  and not (AtomIsChar(';') or AtomIsChar(',') or AtomIsChar(')')) then
    RaiseExpectedButAtomFound('"end of variable"');
    
  UndoReadNextAtom;

  EndChildNode;
end;

procedure TCCodeParserTool.RaiseException(const AMessage: string; ReportPos: integer);
begin
  LastErrorMsg:=AMessage;
  LastErrorPos:=AtomStart;
  LastErrorReportPos:=LastErrorPos;
  if ReportPos>0 then
    LastErrorReportPos:=ReportPos;
  CloseNodes;
  raise ECCodeParserException.Create(Self,AMessage);
end;

procedure TCCodeParserTool.RaiseExpectedButAtomFound(const AToken: string;
  ReportPos: integer);
begin
  RaiseException(AToken+' expected, but '+GetAtom+' found',ReportPos);
end;

constructor TCCodeParserTool.Create;
begin
  Tree:=TCodeTree.Create;
  InitCCOdeKeyWordLists;
  VisibleEditorLines:=25;
  JumpCentered:=true;
  CursorBeyondEOL:=true;
end;

destructor TCCodeParserTool.Destroy;
begin
  FreeAndNil(Tree);
  inherited Destroy;
end;

procedure TCCodeParserTool.Clear;
begin
  Tree.Clear;
end;

procedure TCCodeParserTool.Parse;
begin
  Parse(Code);
end;

procedure TCCodeParserTool.Parse(aCode: TCodeBuffer);
begin
  if (Code=aCode) and (not UpdateNeeded) then
    exit;
  Code:=aCode;
  InitParser;
  repeat
    ReadNextAtom;
    if SrcPos<=SrcLen then begin
      FDefaultTokenList.DoItCaseSensitive(Src,AtomStart,SrcPos-AtomStart);
    end else begin
      break;
    end;
  until false;
  if (CurNode=nil) or (CurNode.Desc<>ccnRoot) then
    RaiseException('TCCodeParserTool.Parse: internal parser error');
  EndChildNode;
end;

function TCCodeParserTool.UpdateNeeded: boolean;
begin
  Result:=true;
  if (Code=nil) or (Tree=nil) or (Tree.Root=nil) then exit;
  if Code.ChangeStep<>ParseChangeStep then exit;
  Result:=false;
end;

function TCCodeParserTool.FindDeepestNodeAtPos(P: integer;
  ExceptionOnNotFound: boolean): TCodeTreeNode; inline;
begin
  Result:=FindDeepestNodeAtPos(Tree.Root,P,ExceptionOnNotFound);
end;

function TCCodeParserTool.FindDeepestNodeAtPos(StartNode: TCodeTreeNode;
  P: integer; ExceptionOnNotFound: boolean): TCodeTreeNode;

  procedure RaiseNoNodeFoundAtCursor;
  begin
    //DebugLn('RaiseNoNodeFoundAtCursor ',MainFilename);
    RaiseException(ctsNoNodeFoundAtCursor);
  end;

var
  ChildNode: TCodeTreeNode;
  Brother: TCodeTreeNode;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(StartNode);{$ENDIF}
  Result:=nil;
  while StartNode<>nil do begin
    //DebugLn('SearchInNode ',NodeDescriptionAsString(ANode.Desc),
    //',',ANode.StartPos,',',ANode.EndPos,', p=',p,
    //' "',copy(Src,ANode.StartPos,4),'" - "',copy(Src,ANode.EndPos-5,4),'"');
    if (StartNode.StartPos<=P)
    and ((StartNode.EndPos>P) or (StartNode.EndPos<1)) then begin
      // StartNode contains P
      Result:=StartNode;
      // -> search for a child that contains P
      Brother:=StartNode;
      while (Brother<>nil)
      and (Brother.StartPos<=P) do begin
        // brother also contains P
        if Brother.FirstChild<>nil then begin
          ChildNode:=FindDeepestNodeAtPos(Brother.FirstChild,P,false);
          if ChildNode<>nil then begin
            Result:=ChildNode;
            exit;
          end;
        end;
        Brother:=Brother.NextBrother;
      end;
      break;
    end else begin
      // search in next node
      StartNode:=StartNode.NextBrother;
    end;
  end;
  if (Result=nil) and ExceptionOnNotFound then begin
    MoveCursorToPos(P);
    RaiseNoNodeFoundAtCursor;
  end;
end;

function TCCodeParserTool.CaretToCleanPos(Caret: TCodeXYPosition; out
  CleanPos: integer): integer;
begin
  CleanPos:=0;
  if Caret.Code<>Code then
    exit(-1);
  Code.LineColToPosition(Caret.Y,Caret.X,CleanPos);
  if (CleanPos>=1) then
    Result:=0
  else
    Result:=-2; // x,y beyond source
end;

function TCCodeParserTool.CleanPosToCodePos(CleanPos: integer; out
  CodePos: TCodePosition): boolean;
begin
  CodePos.Code:=Code;
  CodePos.P:=CleanPos;
  Result:=(Code<>nil) and (CleanPos>0) and (CleanPos<Code.SourceLength);
end;

function TCCodeParserTool.CleanPosToCaret(CleanPos: integer; out
  Caret: TCodeXYPosition): boolean;
begin
  Caret.Code:=Code;
  Code.AbsoluteToLineCol(CleanPos,Caret.Y,Caret.X);
  Result:=CleanPos>0;
end;

function TCCodeParserTool.CleanPosToCaretAndTopLine(CleanPos: integer; out
  Caret: TCodeXYPosition; out NewTopLine: integer): boolean;
begin
  Caret:=CleanCodeXYPosition;
  NewTopLine:=0;
  Result:=CleanPosToCaret(CleanPos,Caret);
  if Result then begin
    if JumpCentered then begin
      NewTopLine:=Caret.Y-(VisibleEditorLines shr 1);
      if NewTopLine<1 then NewTopLine:=1;
    end else
      NewTopLine:=Caret.Y;
  end;
end;

function TCCodeParserTool.CleanPosToStr(CleanPos: integer): string;
var
  CodePos: TCodeXYPosition;
begin
  if CleanPosToCaret(CleanPos,CodePos) then
    Result:='y='+IntToStr(CodePos.Y)+',x='+IntToStr(CodePos.X)
  else
    Result:='y=?,x=?';
end;

function TCCodeParserTool.MainFilename: string;
begin
  Result:=Code.Filename;
end;

procedure TCCodeParserTool.MoveCursorToPos(p: integer);
begin
  SrcPos:=p;
  AtomStart:=p;
  LastAtomStart:=0;
  LastSrcPos:=0;
end;

procedure TCCodeParserTool.ReadNextAtom;
begin
  //DebugLn(['TCCodeParserTool.ReadNextAtom START ',AtomStart,'-',SrcPos,' ',Src[SrcPos]]);
  LastSrcPos:=SrcPos;
  LastAtomStart:=AtomStart;
  repeat
    ReadRawNextCAtom(Src,SrcPos,AtomStart);
  until (SrcPos>SrcLen) or (not (Src[AtomStart] in [#10,#13]));
  DebugLn(['TCCodeParserTool.ReadNextAtom END ',AtomStart,'-',SrcPos,' "',copy(Src,AtomStart,SrcPos-AtomStart),'"']);
end;

procedure TCCodeParserTool.UndoReadNextAtom;
begin
  if LastSrcPos>0 then begin
    SrcPos:=LastSrcPos;
    AtomStart:=LastAtomStart;
    LastSrcPos:=0;
    LastAtomStart:=0;
  end else begin
    SrcPos:=AtomStart;
  end;
end;

function TCCodeParserTool.ReadTilBracketClose(
  ExceptionOnNotFound: boolean): boolean;
// AtomStart must be on bracket open
// after reading AtomStart is on closing bracket
var
  CloseBracket: Char;
  StartPos: LongInt;
begin
  case Src[AtomStart] of
  '{': CloseBracket:='}';
  '[': CloseBracket:=']';
  '(': CloseBracket:=')';
  '<': CloseBracket:='>';
  else
    if ExceptionOnNotFound then
      RaiseExpectedButAtomFound('(');
    exit(false);
  end;
  StartPos:=AtomStart;
  {$IFOPT R+}{$DEFINE RangeChecking}{$ENDIF}
  {$R-}
  repeat
    ReadRawNextCAtom(Src,SrcPos,AtomStart);
    if AtomStart>SrcLen then begin
      AtomStart:=StartPos;
      SrcPos:=AtomStart+1;
      if ExceptionOnNotFound then
        RaiseException('closing bracket not found');
      exit;
    end;
    case Src[AtomStart] of
    '{','(','[':
      // skip nested bracketss
      begin
        if not ReadTilBracketClose(ExceptionOnNotFound) then
          exit;
      end;
    else
      if Src[AtomStart]=CloseBracket then exit(true);
    end;
  until false;
  {$IFDEF RangeChecking}{$R+}{$UNDEF RangeChecking}{$ENDIF}
end;

function TCCodeParserTool.AtomIs(const s: shortstring): boolean;
var
  len: Integer;
  i: Integer;
begin
  len:=length(s);
  if (len<>SrcPos-AtomStart) then exit(false);
  if SrcPos>SrcLen then exit(false);
  for i:=1 to len do
    if Src[AtomStart+i-1]<>s[i] then exit(false);
  Result:=true;
end;

function TCCodeParserTool.AtomIsChar(const c: char): boolean;
begin
  if SrcPos-AtomStart<>1 then exit(false);
  if SrcPos>SrcLen then exit(false);
  if Src[AtomStart]<>c then exit(false);
  Result:=true;
end;

function TCCodeParserTool.UpAtomIs(const s: shortstring): boolean;
var
  len: Integer;
  i: Integer;
begin
  len:=length(s);
  if (len<>SrcPos-AtomStart) then exit(false);
  if SrcPos>SrcLen then exit(false);
  for i:=1 to len do
    if UpChars[Src[AtomStart+i-1]]<>s[i] then exit(false);
  Result:=true;
end;

function TCCodeParserTool.AtomIsIdentifier: boolean;
var
  p: Integer;
begin
  if (AtomStart>=SrcPos) then exit(false);
  if (SrcPos>SrcLen) or (SrcPos-AtomStart>255) then exit(false);
  if not IsIdentStartChar[Src[AtomStart]] then exit(false);
  p:=AtomStart+1;
  while (p<SrcPos) do begin
    if not IsIdentChar[Src[p]] then exit(false);
    inc(p);
  end;
  Result:=true;
end;

function TCCodeParserTool.AtomIsStringConstant: boolean;
begin
  Result:=(AtomStart<SrcLen) and (Src[AtomStart]='"');
end;

function TCCodeParserTool.LastAtomIs(const s: shortstring): boolean;
var
  len: Integer;
  i: Integer;
begin
  if LastAtomStart<=LastSrcPos then exit(false);
  len:=length(s);
  if (len<>LastSrcPos-LastAtomStart) then exit(false);
  if LastSrcPos>SrcLen then exit(false);
  for i:=1 to len do
    if Src[LastAtomStart+i-1]<>s[i] then exit(false);
  Result:=true;
end;

function TCCodeParserTool.GetLastAtom: string;
begin
  Result:=copy(Src,LastAtomStart,LastSrcPos-LastAtomStart);
end;

function TCCodeParserTool.GetAtom: string;
begin
  Result:=copy(Src,AtomStart,SrcPos-AtomStart);
end;

procedure TCCodeParserTool.Replace(FromPos, ToPos: integer; const NewSrc: string
  );
var
  Node: TCodeTreeNode;
  DiffPos: Integer;
begin
  DebugLn(['TCCodeParserTool.Replace ',FromPos,'-',ToPos,' Old="',copy(Src,FromPos,ToPos-FromPos),'" New="',NewSrc,'"']);
  IncreaseChangeStep;
  Code.Replace(FromPos,ToPos-FromPos,NewSrc);
  Src:=Code.Source;
  SrcLen:=length(Src);
  // update positions
  DiffPos:=length(NewSrc)-(ToPos-FromPos);
  if DiffPos<>0 then begin
    Node:=Tree.Root;
    while Node<>nil do begin
      AdjustPositionAfterInsert(Node.StartPos,true,FromPos,ToPos,DiffPos);
      AdjustPositionAfterInsert(Node.EndPos,false,FromPos,ToPos,DiffPos);
      Node:=Node.Next;
    end;
  end;
end;

procedure TCCodeParserTool.IncreaseChangeStep;
begin
  if FChangeStep<>$7fffffff then
    inc(FChangeStep)
  else
    FChangeStep:=-$7fffffff;
end;

procedure TCCodeParserTool.WriteDebugReport;
var
  Node: TCodeTreeNode;
begin
  DebugLn(['TCCodeParserTool.WriteDebugReport ']);
  if Tree<>nil then begin
    Node:=Tree.Root;
    while Node<>nil do begin
      DebugLn([GetIndentStr(Node.GetLevel*2)+CCNodeDescAsString(Node.Desc)]);
      Node:=Node.Next;
    end;
  end;
end;

procedure TCCodeParserTool.CheckNodeTool(Node: TCodeTreeNode);

  procedure RaiseForeignNode;
  begin
    RaiseCatchableException('TCCodeParserTool.CheckNodeTool '+DbgSName(Self)+' '+CCNodeDescAsString(Node.Desc));
  end;

begin
  if Node=nil then exit;
  while Node.Parent<>nil do Node:=Node.Parent;
  while Node.PriorBrother<>nil do Node:=Node.PriorBrother;
  if (Tree=nil) or (Tree.Root<>Node) then
    RaiseForeignNode;
end;

procedure InternalFinal;
var
  i: Integer;
begin
  if KeyWordLists<>nil then begin
    for i:=0 to KeyWordLists.Count-1 do
      TObject(KeyWordLists[i]).Free;
    FreeAndNil(KeyWordLists);
  end;
end;

finalization
  InternalFinal;

end.

