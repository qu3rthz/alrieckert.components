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
    TFindDeclarationTool enhances the TPascalParserTool with the ability
    to find the source position or code tree node of a declaration.


  ToDo:
}
unit FindDeclarationTool;

{$ifdef FPC}{$mode objfpc}{$endif}{$H+}

interface

{$I codetools.inc}

{ $DEFINE CTDEBUG}

uses
  {$IFDEF MEM_CHECK}
  MemCheck,
  {$ENDIF}
  Classes, SysUtils, CodeTree, CodeAtom, CustomCodeTool, SourceLog,
  KeywordFuncLists, BasicCodeTools, LinkScanner, CodeCache, AVL_Tree, TypInfo,
  PascalParserTool, FileProcs, DefineTemplates;

type
  // searchpath delimiter is semicolon
  TOnGetSearchPath = function(Sender: TObject): string;

  TFindDeclarationTool = class(TPascalParserTool)
  private
    FOnGetUnitSourceSearchPath: TOnGetSearchPath;
    function FindDeclarationInUsesSection(UsesNode: TCodeTreeNode;
      CleanPos: integer;
      var NewPos: TCodeXYPosition; var NewTopLine: integer): boolean;
    function IsIncludeDirectiveAtPos(CleanPos, CleanCodePosInFront: integer;
      var IncludeCode: TCodeBuffer): boolean;
    function FindDeclarationOfIdentifier(DeepestNode: TCodeTreeNode;
      IdentifierStartPos, IdentifierEndPos: integer;
      var NewPos: TCodeXYPosition; var NewTopLine: integer): boolean;
    function FindIdentifierInContext(IdentifierStartPos,
      IdentifierEndPos: integer;  ContextNode: TCodeTreeNode;
      SearchInParentNodes: boolean;
      var NewPos: TCodeXYPosition; var NewTopLine: integer): boolean;
  public
    function FindDeclaration(CursorPos: TCodeXYPosition;
      var NewPos: TCodeXYPosition; var NewTopLine: integer): boolean;
    function FindUnitSource(const AnUnitName,
      AnUnitInFilename: string): TCodeBuffer;
    property OnGetUnitSourceSearchPath: TOnGetSearchPath
      read FOnGetUnitSourceSearchPath write FOnGetUnitSourceSearchPath;
  end;

implementation



{ TFindDeclarationTool }

function TFindDeclarationTool.FindDeclaration(CursorPos: TCodeXYPosition;
  var NewPos: TCodeXYPosition; var NewTopLine: integer): boolean;
var CleanCursorPos: integer;
  CursorNode: TCodeTreeNode;
begin
  Result:=false;
  // build code tree
{$IFDEF CTDEBUG}
writeln('TFindDeclarationTool.FindDeclaration A CursorPos=',CursorPos.X,',',CursorPos.Y);
{$ENDIF}
  BuildTreeAndGetCleanPos(false,CursorPos,CleanCursorPos);
{$IFDEF CTDEBUG}
writeln('TFindDeclarationTool.FindDeclaration C CleanCursorPos=',CleanCursorPos);
{$ENDIF}
  // find CodeTreeNode at cursor
  CursorNode:=FindDeepestNodeAtPos(CleanCursorPos);
  if CursorNode=nil then
    RaiseException('no node found at cursor');
  if IsIncludeDirectiveAtPos(CleanCursorPos,CursorNode.StartPos,NewPos.Code)
  then begin
    NewPos.X:=1;
    NewPos.Y:=1;
    NewTopLine:=1;
    Result:=true;
    exit;
  end;
{$IFDEF CTDEBUG}
writeln('TFindDeclarationTool.FindDeclaration D CursorNode=',NodeDescriptionAsString(CursorNode.Desc));
{$ENDIF}
  if CursorNode.Desc=ctnUsesSection then begin
    // find used unit
    Result:=FindDeclarationInUsesSection(CursorNode,CleanCursorPos,
                                         NewPos,NewTopLine);
  end else begin
    if CursorNode.Desc=ctnBeginBlock then
      BuildSubTreeForBeginBlock(CursorNode);
    MoveCursorToCleanPos(CleanCursorPos);
    while (CurPos.StartPos>1) and (IsIdentChar[Src[CurPos.StartPos-1]]) do
      dec(CurPos.StartPos);
writeln('AAA ',CurPos.StartPos,',',Src[CurPos.StartPos]);
    if (CurPos.StartPos>=1) and (IsIdentStartChar[Src[CurPos.StartPos]]) then
    begin
writeln('AAA2');
      CurPos.EndPos:=CurPos.StartPos;
      while (CurPos.EndPos<=SrcLen) and IsIdentChar[Src[CurPos.EndPos]] do
        inc(CurPos.EndPos);
      // find declaration of identifier
      Result:=FindDeclarationOfIdentifier(CursorNode,
                 CurPos.StartPos,CurPos.EndPos,NewPos,NewTopLine);
    end else begin
      // find declaration of not identifier
      
    end;
  end;
end;

function TFindDeclarationTool.FindDeclarationInUsesSection(
  UsesNode: TCodeTreeNode; CleanPos: integer;
  var NewPos: TCodeXYPosition; var NewTopLine: integer): boolean;
var UnitName, UnitInFilename: string;
  UnitNamePos, UnitInFilePos: TAtomPosition;
begin
  Result:=false;
{$IFDEF CTDEBUG}
writeln('TFindDeclarationTool.FindDeclarationInUsesSection A');
{$ENDIF}
  // reparse uses section
  MoveCursorToNodeStart(UsesNode);
  ReadNextAtom;
  if not UpAtomIs('USES') then
    RaiseException('syntax error: expected uses, but '+GetAtom+' found');
  repeat
    ReadNextAtom;  // read name
    if CurPos.StartPos>CleanPos then break;
    if AtomIsChar(';') then break;
    AtomIsIdentifier(true);
    UnitNamePos:=CurPos;
    ReadNextAtom;
    if UpAtomIs('IN') then begin
      ReadNextAtom;
      if not AtomIsStringConstant then
        RaiseException(
          'syntax error: string constant expected, but '+GetAtom+' found');
      UnitInFilePos:=CurPos;
      ReadNextAtom;
    end else
      UnitInFilePos.StartPos:=-1;
    if CleanPos<UnitNamePos.EndPos then begin
      // cursor is on a unitname -> try to locate it
      UnitName:=copy(Src,UnitNamePos.StartPos,
                     UnitNamePos.EndPos-UnitNamePos.StartPos);
      if UnitInFilePos.StartPos>=1 then
        UnitInFilename:=copy(Src,UnitInFilePos.StartPos,
                     UnitInFilePos.EndPos-UnitInFilePos.StartPos)
      else
        UnitInFilename:='';
      NewPos.Code:=FindUnitSource(UnitName,UnitInFilename);
      if NewPos.Code=nil then
        RaiseException('unit not found: '+UnitName);
      NewPos.X:=1;
      NewPos.Y:=1;
      NewTopLine:=1;
      Result:=true;
      exit;
    end;
    if AtomIsChar(';') then break;
    if not AtomIsChar(',') then
      RaiseException(
        'syntax error: ; expected, but '+GetAtom+' found')
  until (CurPos.StartPos>SrcLen);
{$IFDEF CTDEBUG}
writeln('TFindDeclarationTool.FindDeclarationInUsesSection END cursor not on unitname');
{$ENDIF}
end;

function TFindDeclarationTool.FindUnitSource(const AnUnitName,
  AnUnitInFilename: string): TCodeBuffer;

  function LoadFile(const ExpandedFilename: string;
    var NewCode: TCodeBuffer): boolean;
  begin
{$IFDEF CTDEBUG}
writeln('TFindDeclarationTool.FindUnitSource.LoadFile ',ExpandedFilename);
{$ENDIF}
    NewCode:=TCodeBuffer(Scanner.OnLoadSource(Self,ExpandedFilename));
    Result:=NewCode<>nil;
  end;
  
  function SearchUnitFileInDir(const ADir, AnUnitName: string): TCodeBuffer;
  var APath: string;
  begin
    APath:=ADir;
    if (APath<>'') and (APath[length(APath)]<>PathDelim) then
      APath:=APath+PathDelim;
    {$IFNDEF win32}
    if LoadFile(ADir+lowercase(AnUnitName)+'.pp',Result) then exit;
    if LoadFile(ADir+lowercase(AnUnitName)+'.pas',Result) then exit;
    {$ENDIF}
    if LoadFile(ADir+AnUnitName+'.pp',Result) then exit;
    if LoadFile(ADir+AnUnitName+'.pas',Result) then exit;
    Result:=nil;
  end;

  function SearchUnitFileInPath(const APath, TheUnitName: string): TCodeBuffer;
  var PathStart, PathEnd: integer;
    ADir: string;
  begin
    PathStart:=1;
    while PathStart<=length(APath) do begin
      PathEnd:=PathStart;
      while (PathEnd<=length(APath)) and (APath[PathEnd]<>';') do inc(PathEnd);
      if PathEnd>PathStart then begin
        ADir:=copy(APath,PathStart,PathEnd-PathStart);
        if (ADir<>'') and (ADir[length(ADir)]<>PathDelim) then
          ADir:=ADir+PathDelim;
        if not FilenameIsAbsolute(ADir) then
          ADir:=ExtractFilePath(TCodeBuffer(Scanner.MainCode).Filename)+ADir;
        Result:=SearchUnitFileInDir(ADir,TheUnitName);
        if Result<>nil then exit;
      end;
      PathStart:=PathEnd+1;
    end;
    Result:=nil;
  end;

  function SearchFileInPath(const APath, RelativeFilename: string): TCodeBuffer;
  var PathStart, PathEnd: integer;
    ADir: string;
  begin
    PathStart:=1;
    while PathStart<=length(APath) do begin
      PathEnd:=PathStart;
      while (PathEnd<=length(APath)) and (APath[PathEnd]<>';') do inc(PathEnd);
      if PathEnd>PathStart then begin
        ADir:=copy(APath,PathStart,PathEnd-PathStart);
        if (ADir<>'') and (ADir[length(ADir)]<>PathDelim) then
          ADir:=ADir+PathDelim;
        if not FilenameIsAbsolute(ADir) then
          ADir:=ExtractFilePath(TCodeBuffer(Scanner.MainCode).Filename)+ADir;
        if LoadFile(ADir+RelativeFilename,Result) then exit;
      end;
      PathStart:=PathEnd+1;
    end;
    Result:=nil;
  end;
  
  function SearchUnitInUnitLinks(const TheUnitName: string): TCodeBuffer;
  var UnitLinks, CurFilename: string;
    UnitLinkStart, UnitLinkEnd: integer;
  begin
    Result:=nil;
    UnitLinks:=Scanner.Values[ExternalMacroStart+'UnitLinks'];
{$IFDEF CTDEBUG}
writeln('TFindDeclarationTool.FindUnitSource.SearchUnitInUnitLinks');
{$ENDIF}
    UnitLinkStart:=1;
    while UnitLinkStart<=length(UnitLinks) do begin
      while (UnitLinkStart<=length(UnitLinks))
      and (UnitLinks[UnitLinkStart] in [#10,#13]) do
        inc(UnitLinkStart);
      UnitLinkEnd:=UnitLinkStart;
      while (UnitLinkEnd<=length(UnitLinks)) and (UnitLinks[UnitLinkEnd]<>' ')
      do
        inc(UnitLinkEnd);
      if UnitLinkEnd>UnitLinkStart then begin
{$IFDEF CTDEBUG}
writeln('  unit "',copy(UnitLinks,UnitLinkStart,UnitLinkEnd-UnitLinkStart),'"');
{$ENDIF}
        if AnsiCompareText(TheUnitName,
                     copy(UnitLinks,UnitLinkStart,UnitLinkEnd-UnitLinkStart))=0
        then begin
          // unit found -> parse filename
          UnitLinkStart:=UnitLinkEnd+1;
          UnitLinkEnd:=UnitLinkStart;
          while (UnitLinkEnd<=length(UnitLinks))
          and (not (UnitLinks[UnitLinkEnd] in [#10,#13])) do
            inc(UnitLinkEnd);
          if UnitLinkEnd>UnitLinkStart then begin
            CurFilename:=copy(UnitLinks,UnitLinkStart,UnitLinkEnd-UnitLinkStart);
            LoadFile(CurFilename,Result);
            exit;
          end;
        end else begin
          UnitLinkStart:=UnitLinkEnd+1;
          while (UnitLinkStart<=length(UnitLinks))
          and (not (UnitLinks[UnitLinkStart] in [#10,#13])) do
            inc(UnitLinkStart);
        end;
      end else
        break;
    end;
  end;


var CurDir, UnitSrcSearchPath: string;
  MainCodeIsVirtual: boolean;
begin
{$IFDEF CTDEBUG}
writeln('TFindDeclarationTool.FindUnitSource A AnUnitName=',AnUnitName,' AnUnitInFilename=',AnUnitInFilename);
{$ENDIF}
  Result:=nil;
  if (AnUnitName='') or (Scanner=nil) or (Scanner.MainCode=nil)
  or (not (TObject(Scanner.MainCode) is TCodeBuffer))
  or (Scanner.OnLoadSource=nil) then
    exit;
  if Assigned(OnGetUnitSourceSearchPath) then
    UnitSrcSearchPath:=OnGetUnitSourceSearchPath(Self)
  else
    UnitSrcSearchPath:=Scanner.Values[ExternalMacroStart+'SrcPath'];
{$IFDEF CTDEBUG}
writeln('TFindDeclarationTool.FindUnitSource UnitSrcSearchPath=',UnitSrcSearchPath);
{$ENDIF}
//writeln('>>>>>',Scanner.Values.AsString,'<<<<<');
  if AnUnitInFilename<>'' then begin
    // unitname in 'filename'
    if FilenameIsAbsolute(AnUnitInFilename) then begin
      Result:=TCodeBuffer(Scanner.OnLoadSource(Self,AnUnitInFilename));
    end else begin
      // search AnUnitInFilename in searchpath
      Result:=SearchFileInPath(UnitSrcSearchPath,AnUnitInFilename);
    end;
  end else begin
    // normal unit name -> search as the compiler would search
    // first search in current directory (= where the maincode is)
    MainCodeIsVirtual:=TCodeBuffer(Scanner.MainCode).IsVirtual;
    if not MainCodeIsVirtual then begin
      CurDir:=ExtractFilePath(TCodeBuffer(Scanner.MainCode).Filename);
    end else begin
      CurDir:='';
    end;
{$IFDEF CTDEBUG}
writeln('TFindDeclarationTool.FindUnitSource Search in current dir=',CurDir);
{$ENDIF}
    Result:=SearchUnitFileInDir(CurDir,AnUnitName);
    if Result=nil then begin
      // search in search path
{$IFDEF CTDEBUG}
writeln('TFindDeclarationTool.FindUnitSource Search in search path=',UnitSrcSearchPath);
{$ENDIF}
      Result:=SearchUnitFileInPath(UnitSrcSearchPath,AnUnitName);
      if Result=nil then begin
        // search in FPC source directory
        Result:=SearchUnitInUnitLinks(AnUnitName);
      end;
    end;
  end;
end;

function TFindDeclarationTool.IsIncludeDirectiveAtPos(CleanPos,
  CleanCodePosInFront: integer; var IncludeCode: TCodeBuffer): boolean;
var LinkIndex, CommentStart, CommentEnd: integer;
  SrcLink: TSourceLink;
begin
  Result:=false;
  if (Scanner=nil) then exit;
  LinkIndex:=Scanner.LinkIndexAtCleanPos(CleanPos);
  if (LinkIndex<0) or (LinkIndex>=Scanner.LinkCount-1) then exit;
  SrcLink:=Scanner.Links[LinkIndex+1];
  if (SrcLink.Code=nil) or (SrcLink.Code=Scanner.Links[LinkIndex].Code) then
    exit;
  if CleanPosIsInComment(CleanPos,CleanCodePosInFront,CommentStart,CommentEnd)
  and (CommentEnd=SrcLink.CleanedPos) then begin
    IncludeCode:=TCodeBuffer(SrcLink.Code);
    Result:=true;
    exit;
  end;
end;

function TFindDeclarationTool.FindDeclarationOfIdentifier(
  DeepestNode: TCodeTreeNode; IdentifierStartPos, IdentifierEndPos: integer;
  var NewPos: TCodeXYPosition; var NewTopLine: integer): boolean;
{ searches an identifier in clean code, parses code in front of identifier
  For example:
    A^.B().C[].Identifier
}
begin
{$IFDEF CTDEBUG}
writeln('[TFindDeclarationTool.FindDeclarationOfIdentifier] Identifier=',
  copy(Src,IdentifierStartPos,IdentifierEndPos-IdentifierStartPos),
  ' DeepestNode=',NodeDescriptionAsString(DeepestNode.Desc));
{$ENDIF}
  Result:=false;
  MoveCursorToCleanPos(IdentifierStartPos);
  ReadPriorAtom;
{$IFDEF CTDEBUG}
writeln('[TFindDeclarationTool.FindDeclarationOfIdentifier] B PriorAtom=',GetAtom);
{$ENDIF}
  if AtomIsChar('.') then begin
    // first search context, then search in context
    
    // ToDo
    
  end else if UpAtomIs('INHERITED') then begin
    // first search ancestor, then search in ancestor

    // ToDo

  end else begin
    // context is DeepestNode
    Result:=FindIdentifierInContext(IdentifierStartPos,IdentifierEndPos,
              DeepestNode,true,NewPos,NewTopLine);
  end;
  { ToDo:

  - Difficulties:
     1. Searching recursively
          - ParentNodes
          - Ancestor Classes/Objects/Interfaces
          - with statements
          - operators: '.', '()', 'A()', '^', 'inherited'
     2. Searching enums must be searched in sub nodes
          -> all classes node trees must be built
     3. Searching in used units (interface USES and implementation USES)
     4. Searching forward for pointer types e.g. ^Tralala
     5. Mass Search: searching a compatible proc will result
        in searching every parameter type of every reachable proc
          (implementation section + interface section
  	    + used interface sections + class and ancestor methods)
        How can this be achieved in good time?
          -> Caching
  - Caching:
     Where:
       For each section node (Interface, Implementation, ...)
       For each BeginBlock
     Entries: (What, Declaration Pos)
       What: Identifier -> Ansistring (to reduce memory usage,
         maintain a list of all identifier ansistrings)
       Pos: Code+SrcPos
         1. Source: TCodeTreeNode
         2. PPU, PPW, DFU, ...:
  }

end;

function TFindDeclarationTool.FindIdentifierInContext(IdentifierStartPos,
  IdentifierEndPos: integer; ContextNode: TCodeTreeNode;
  SearchInParentNodes: boolean;
  var NewPos: TCodeXYPosition; var NewTopLine: integer): boolean;
{ searches an identifier in context node
  It does not care about code in front of the identifier like 'a.Identifer'.
}
var LastContextNode: TCodeTreeNode;
begin
  Result:=false;
  if ContextNode<>nil then begin
    repeat
{$IFDEF CTDEBUG}
writeln('[TFindDeclarationTool.FindIdentifierInContext] ',NodeDescriptionAsString(ContextNode.Desc));
{$ENDIF}
      LastContextNode:=ContextNode;
      case ContextNode.Desc of
      
      ctnTypeSection, ctnVarSection, ctnConstSection, ctnResStrSection:
        begin
          if ContextNode.LastChild<>nil then
            ContextNode:=ContextNode.LastChild;
        end;
        
      ctnTypeDefinition, ctnVarDefinition, ctnConstDefinition:
        begin
          if CompareSrcIdentifiers(IdentifierStartPos,ContextNode.StartPos) then
          begin
            // identifier found
            Result:=CleanPosToCaretAndTopLine(ContextNode.StartPos,
                                              NewPos,NewTopLine);
            exit;
          end;
          // search for enums
          
          // ToDo
          
        end;

      end;
      if LastContextNode=ContextNode then begin
        // same context -> search in higher context
        if not SearchInParentNodes then exit;
        if ContextNode.PriorBrother<>nil then
          ContextNode:=ContextNode.PriorBrother
        else if ContextNode.Parent<>nil then
          ContextNode:=ContextNode.Parent
        else
          break;
      end;
    until ContextNode=nil;
  end else begin
    // DeepestNode=nil
  end;
end;

end.




