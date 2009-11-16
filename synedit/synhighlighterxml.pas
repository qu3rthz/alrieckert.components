{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: SynHighlighterXML.pas, released 2000-11-20.
The Initial Author of this file is Jeff Rafter.
All Rights Reserved.

Contributors to the SynEdit and mwEdit projects are listed in the
Contributors.txt file.

Alternatively, the contents of this file may be used under the terms of the
GNU General Public License Version 2 or later (the "GPL"), in which case
the provisions of the GPL are applicable instead of those above.
If you wish to allow use of your version of this file only under the terms
of the GPL and not to allow others to use your version of this file
under the MPL, indicate your decision by deleting the provisions above and
replace them with the notice and other provisions required by the GPL.
If you do not delete the provisions above, a recipient may use your version
of this file under either the MPL or the GPL.

$Id$

You may retrieve the latest version of this file at the SynEdit home page,
located at http://SynEdit.SourceForge.net

History:
-------------------------------------------------------------------------------
2000-11-30 Removed mHashTable and MakeIdentTable per Michael Hieke

Known Issues:
- Nothing is really constrained (properly) to valid name chars
- Entity Refs are not constrained to valid name chars
- Support for "Combining Chars and Extender Chars" in names are lacking
- The internal DTD is not parsed (and not handled correctly)
-------------------------------------------------------------------------------}

{
@abstract(Provides an XML highlighter for SynEdit)
@author(Jeff Rafter-- Phil 4:13, based on SynHighlighterHTML by Hideo Koiso)
@created(2000-11-17)
@lastmod(2001-03-12)
The SynHighlighterXML unit provides SynEdit with an XML highlighter.
}

unit SynHighlighterXML;

interface

{$I SynEdit.inc}

uses
  SysUtils, Classes, math, LCLProc,
  {$IFDEF SYN_CLX}
  Qt, QControls, QGraphics,
  {$ELSE}
  {$IFDEF SYN_LAZARUS}
  LCLIntf, LCLType,
  {$ELSE}
  Windows, Messages, Registry,
  {$ENDIF}
  Controls, Graphics,
  {$ENDIF}
  SynEditTypes, SynEditTextBuffer, SynEditHighlighter, SynEditHighlighterFoldBase;

type
  TtkTokenKind = (tkAposAttrValue, tkAposEntityRef, tkAttribute, tkCDATA,
    tkComment, tkElement, tkEntityRef, tkEqual, tkNull, tkProcessingInstruction,
    tkQuoteAttrValue, tkQuoteEntityRef, tkSpace, tkSymbol, tkText,
    //
    tknsAposAttrValue, tknsAposEntityRef, tknsAttribute, tknsEqual,
    tknsQuoteAttrValue, tknsQuoteEntityRef,
    //These are unused at the moment
    tkDocType
    {tkDocTypeAposAttrValue, tkDocTypeAposEntityRef, tkDocTypeAttribute,
     tkDocTypeElement, tkDocTypeEqual tkDocTypeQuoteAttrValue,
     tkDocTypeQuoteEntityRef}
  );

  TRangeState = (rsAposAttrValue, rsAPosEntityRef, rsAttribute, rsCDATA,
    rsComment, rsElement, rsCloseElement, rsOpenElement, rsEntityRef, rsEqual, rsProcessingInstruction,
    rsQuoteAttrValue, rsQuoteEntityRef, rsText,
    //
    rsnsAposAttrValue, rsnsAPosEntityRef, rsnsEqual, rsnsQuoteAttrValue,
    rsnsQuoteEntityRef,
    //These are unused at the moment
    rsDocType, rsDocTypeSquareBraces                                           //ek 2001-11-11
    {rsDocTypeAposAttrValue, rsDocTypeAposEntityRef, rsDocTypeAttribute,
     rsDocTypeElement, rsDocTypeEqual, rsDocTypeQuoteAttrValue,
     rsDocTypeQuoteEntityRef}
  );

 TXmlCodeFoldBlockType = (
    cfbtXmlNone,
    cfbtXmlElement,  // <foo>
    cfbtXmlComment,  // <!-- -->
    cfbtXmlCData,    // <![CDATA[ ]]>
    cfbtXmlDocType,  // <!DOCTYPE
    cfbtXmlProcess   // <?
  );

  TSynXmlRangeInfo = record
    ElementOpenList: Array of String; // List of words opened in this line (and still open at the end of line)
    ElementCloseList: Array of Smallint; // include close, for open on same line
  end;

  { TSynHighlighterXmlRangeList }

  TSynHighlighterXmlRangeList = class(TSynHighlighterRangeList)
  private
    function GetXmlRangeInfo(Index: Integer): TSynXmlRangeInfo;
    procedure SetXmlRangeInfo(Index: Integer; const AValue: TSynXmlRangeInfo);
  protected
    procedure SetCapacity(const AValue: Integer); override;
    function ItemSize: Integer; override;
  public
    procedure Move(AFrom, ATo, ALen: Integer); override;
    property XmlRangeInfo[Index: Integer]: TSynXmlRangeInfo
      read GetXmlRangeInfo write SetXmlRangeInfo;
  end;

  TProcTableProc = procedure of object;

  { TSynXMLSyn }

  TSynXMLSyn = class(TSynCustomFoldHighlighter)
  private
    fRange: TRangeState;
    FXmlRangeInfo: TSynXmlRangeInfo;
    FXmlRangeInfoChanged: Boolean;
    FXmlRangeInfoOpenPos: integer;
    FXmlRangeInfoClosePos: integer;
    fLine: PChar;
    Run: Longint;
    fTokenPos: Integer;
    fTokenID: TtkTokenKind;
    fLineNumber: Integer;
    fElementAttri: TSynHighlighterAttributes;
    fSpaceAttri: TSynHighlighterAttributes;
    fTextAttri: TSynHighlighterAttributes;
    fEntityRefAttri: TSynHighlighterAttributes;
    fProcessingInstructionAttri: TSynHighlighterAttributes;
    fCDATAAttri: TSynHighlighterAttributes;
    fCommentAttri: TSynHighlighterAttributes;
    fDocTypeAttri: TSynHighlighterAttributes;
    fAttributeAttri: TSynHighlighterAttributes;
    fnsAttributeAttri: TSynHighlighterAttributes;
    fAttributeValueAttri: TSynHighlighterAttributes;
    fnsAttributeValueAttri: TSynHighlighterAttributes;
    fSymbolAttri: TSynHighlighterAttributes;
    fProcTable: array[#0..#255] of TProcTableProc;
    FWantBracesParsed: Boolean;
    procedure NullProc;
    procedure CarriageReturnProc;
    procedure LineFeedProc;
    procedure SpaceProc;
    procedure LessThanProc;
    procedure GreaterThanProc;
    procedure CommentProc;
    procedure ProcessingInstructionProc;
    procedure DocTypeProc;
    procedure CDATAProc;
    procedure TextProc;
    procedure ElementProc;
    procedure AttributeProc;
    procedure QAttributeValueProc;
    procedure AAttributeValueProc;
    procedure EqualProc;
    procedure IdentProc;
    procedure MakeMethodTables;
    function NextTokenIs(T: String): Boolean;
    procedure EntityRefProc;
    procedure QEntityRefProc;
    procedure AEntityRefProc;
  protected
    function UpdateRangeInfoAtLine(Index: Integer): Boolean; override; // Returns true if range changed
    function GetIdentChars: TSynIdentChars; override;
    function GetSampleSource : String; override;
  protected
    // folding
    procedure CreateRootCodeFoldBlock; override;
    function CreateRangeList: TSynHighlighterRangeList; override;

    function StartXmlCodeFoldBlock(ABlockType: TXmlCodeFoldBlockType): TSynCustomCodeFoldBlock;
    function StartXmlElemCodeFoldBlock(ABlockType: TXmlCodeFoldBlockType;
                                   OpenPos: Integer; AName: String): TSynCustomCodeFoldBlock;
    procedure EndXmlCodeFoldBlock;
    procedure EndXmlElemCodeFoldBlock(ClosePos: Integer = -1; AName: String = '');
    function TopXmlCodeFoldBlockType(DownIndex: Integer = 0): TXmlCodeFoldBlockType;
  public
    {$IFNDEF SYN_CPPB_1} class {$ENDIF}
    function GetLanguageName: string; override;
  public
    constructor Create(AOwner: TComponent); override;
    function GetDefaultAttribute(Index: integer): TSynHighlighterAttributes;
      override;
    function GetEol: Boolean; override;
    function GetRange: Pointer; override;
    function GetTokenID: TtkTokenKind;
    procedure SetLine({$IFDEF FPC}const {$ENDIF}NewValue: string; LineNumber:Integer); override;
    function GetToken: string; override;
    {$IFDEF SYN_LAZARUS}
    procedure GetTokenEx(out TokenStart: PChar; out TokenLength: integer); override;
    {$ENDIF}
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: integer; override;
    function GetTokenPos: Integer; override;
    procedure Next; override;
    procedure SetRange(Value: Pointer); override;
    procedure ReSetRange; override;
    property IdentChars;
  public
    // folding
    function FoldOpenCount(ALineIndex: Integer; AType: Integer = 0): integer; override;
    function FoldCloseCount(ALineIndex: Integer; AType: Integer = 0): integer; override;
    function FoldNestCount(ALineIndex: Integer; AType: Integer = 0): integer; override;
    function FoldLineLength(ALineIndex, FoldIndex: Integer): integer; override;
    // TODO: make private
    function MinimumFoldLevel(ALineIndex: Integer): integer; override;
    function EndFoldLevel(ALineIndex: Integer): integer; override;
  published
    property ElementAttri: TSynHighlighterAttributes read fElementAttri
      write fElementAttri;
    property AttributeAttri: TSynHighlighterAttributes read fAttributeAttri
      write fAttributeAttri;
    property NamespaceAttributeAttri: TSynHighlighterAttributes
      read fnsAttributeAttri write fnsAttributeAttri;
    property AttributeValueAttri: TSynHighlighterAttributes
      read fAttributeValueAttri write fAttributeValueAttri;
    property NamespaceAttributeValueAttri: TSynHighlighterAttributes
      read fnsAttributeValueAttri write fnsAttributeValueAttri;
    property TextAttri: TSynHighlighterAttributes read fTextAttri
      write fTextAttri;
    property CDATAAttri: TSynHighlighterAttributes read fCDATAAttri
      write fCDATAAttri;
    property EntityRefAttri: TSynHighlighterAttributes read fEntityRefAttri
      write fEntityRefAttri;
    property ProcessingInstructionAttri: TSynHighlighterAttributes
      read fProcessingInstructionAttri write fProcessingInstructionAttri;
    property CommentAttri: TSynHighlighterAttributes read fCommentAttri
      write fCommentAttri;
    property DocTypeAttri: TSynHighlighterAttributes read fDocTypeAttri
      write fDocTypeAttri;
    property SpaceAttri: TSynHighlighterAttributes read fSpaceAttri
      write fSpaceAttri;
    property SymbolAttri: TSynHighlighterAttributes read fSymbolAttri
      write fSymbolAttri;
    property WantBracesParsed : Boolean read FWantBracesParsed
      write FWantBracesParsed default True;
  end;

implementation

uses
  SynEditStrConst;

const
  NameChars : set of char = ['0'..'9', 'a'..'z', 'A'..'Z', '_', '.', ':', '-'];
  MaxFoldNestDeep = 500;

constructor TSynXMLSyn.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  fElementAttri:= TSynHighlighterAttributes.Create(SYNS_AttrElementName, SYNS_XML_AttrElementName);
  fTextAttri:= TSynHighlighterAttributes.Create(SYNS_AttrText, SYNS_XML_AttrText);
  fSpaceAttri:= TSynHighlighterAttributes.Create(SYNS_AttrWhitespace, SYNS_XML_AttrWhitespace);
  fEntityRefAttri:= TSynHighlighterAttributes.Create(SYNS_AttrEntityReference, SYNS_XML_AttrEntityReference);
  fProcessingInstructionAttri:= TSynHighlighterAttributes.Create(SYNS_AttrProcessingInstr, SYNS_XML_AttrProcessingInstr);
  fCDATAAttri:= TSynHighlighterAttributes.Create(SYNS_AttrCDATASection, SYNS_XML_AttrCDATASection);
  fCommentAttri:= TSynHighlighterAttributes.Create(SYNS_AttrComment, SYNS_XML_AttrComment);
  fDocTypeAttri:= TSynHighlighterAttributes.Create(SYNS_AttrDOCTYPESection, SYNS_XML_AttrDOCTYPESection);
  fAttributeAttri:= TSynHighlighterAttributes.Create(SYNS_AttrAttributeName, SYNS_XML_AttrAttributeName);
  fnsAttributeAttri:= TSynHighlighterAttributes.Create(SYNS_AttrNamespaceAttrName, SYNS_XML_AttrNamespaceAttrName);
  fAttributeValueAttri:= TSynHighlighterAttributes.Create(SYNS_AttrAttributeValue, SYNS_XML_AttrAttributeValue);
  fnsAttributeValueAttri:= TSynHighlighterAttributes.Create(SYNS_AttrNamespaceAttrValue, SYNS_XML_AttrNamespaceAttrValue);
  fSymbolAttri:= TSynHighlighterAttributes.Create(SYNS_AttrSymbol, SYNS_XML_AttrSymbol);

  fElementAttri.Foreground:= clMaroon;
  fElementAttri.Style:= [fsBold];

  fDocTypeAttri.Foreground:= clblue;
  fDocTypeAttri.Style:= [fsItalic];

  fCDATAAttri.Foreground:= clOlive;
  fCDATAAttri.Style:= [fsItalic];

  fEntityRefAttri.Foreground:= clblue;
  fEntityRefAttri.Style:= [fsbold];

  fProcessingInstructionAttri.Foreground:= clblue;
  fProcessingInstructionAttri.Style:= [];

  fTextAttri.Foreground:= clBlack;
  fTextAttri.Style:= [fsBold];

  fAttributeAttri.Foreground:= clMaroon;
  fAttributeAttri.Style:= [];

  fnsAttributeAttri.Foreground:= clRed;
  fnsAttributeAttri.Style:= [];

  fAttributeValueAttri.Foreground:= clNavy;
  fAttributeValueAttri.Style:= [fsBold];

  fnsAttributeValueAttri.Foreground:= clRed;
  fnsAttributeValueAttri.Style:= [fsBold];

  fCommentAttri.Background:= clSilver;
  fCommentAttri.Foreground:= clGray;
  fCommentAttri.Style:= [fsbold, fsItalic];

  fSymbolAttri.Foreground:= clblue;
  fSymbolAttri.Style:= [];

  AddAttribute(fSymbolAttri);
  AddAttribute(fProcessingInstructionAttri);
  AddAttribute(fDocTypeAttri);
  AddAttribute(fCommentAttri);
  AddAttribute(fElementAttri);
  AddAttribute(fAttributeAttri);
  AddAttribute(fnsAttributeAttri);
  AddAttribute(fAttributeValueAttri);
  AddAttribute(fnsAttributeValueAttri);
  AddAttribute(fEntityRefAttri);
  AddAttribute(fCDATAAttri);
  AddAttribute(fSpaceAttri);
  AddAttribute(fTextAttri);

  SetAttributesOnChange({$IFDEF FPC}@{$ENDIF}DefHighlightChange);

  MakeMethodTables;
  fRange := rsText;
  fDefaultFilter := SYNS_FilterXML;
end;

procedure TSynXMLSyn.MakeMethodTables;
var
  i: Char;
begin
  for i:= #0 To #255 do begin
    case i of
    #0:
      begin
        fProcTable[i] := {$IFDEF FPC}@{$ENDIF}NullProc;
      end;
    #10:
      begin
        fProcTable[i] := {$IFDEF FPC}@{$ENDIF}LineFeedProc;
      end;
    #13:
      begin
        fProcTable[i] := {$IFDEF FPC}@{$ENDIF}CarriageReturnProc;
      end;
    #1..#9, #11, #12, #14..#32:
      begin
        fProcTable[i] := {$IFDEF FPC}@{$ENDIF}SpaceProc;
      end;
    '<':
      begin
        fProcTable[i] := {$IFDEF FPC}@{$ENDIF}LessThanProc;
      end;
    '>':
      begin
        fProcTable[i] := {$IFDEF FPC}@{$ENDIF}GreaterThanProc;
      end;
    else
      fProcTable[i] := {$IFDEF FPC}@{$ENDIF}IdentProc;
    end;
  end;
end;

procedure TSynXMLSyn.SetLine({$IFDEF FPC}const {$ENDIF}NewValue: string;
  LineNumber:Integer);
begin
  inherited;
  FXmlRangeInfo := TSynHighlighterXmlRangeList(CurrentRanges).XmlRangeInfo[LineIndex]; // From this line, not from the previous line
  FXmlRangeInfoChanged := False;
  FXmlRangeInfoOpenPos := 0;
  FXmlRangeInfoClosePos := 0;

  fLine := PChar(NewValue);
  Run := 0;
  fLineNumber := LineNumber;
  Next;
end;

procedure TSynXMLSyn.NullProc;
begin
  fTokenID := tkNull;
end;

procedure TSynXMLSyn.CarriageReturnProc;
begin
  fTokenID := tkSpace;
  Inc(Run);
  if fLine[Run] = #10 then Inc(Run);
end;

procedure TSynXMLSyn.LineFeedProc;
begin
  fTokenID := tkSpace;
  Inc(Run);
end;

procedure TSynXMLSyn.SpaceProc;
begin
  Inc(Run);
  fTokenID := tkSpace;
  while fLine[Run] <= #32 do begin
    if fLine[Run] in [#0, #9, #10, #13] then break;
    Inc(Run);
  end;
end;

procedure TSynXMLSyn.LessThanProc;
begin
  Inc(Run);
  if (fLine[Run] = '/') then begin
    Inc(Run);
    fTokenID := tkSymbol;
    fRange := rsCloseElement;
    exit;
  end;

  if (fLine[Run] = '!') then
  begin
    if NextTokenIs('--') then begin
      fTokenID := tkSymbol;
      fRange := rsComment;
      StartXmlCodeFoldBlock(cfbtXmlComment);
      Inc(Run, 3);
    end else if NextTokenIs('DOCTYPE') then begin
      fTokenID := tkDocType;
      fRange := rsDocType;
      StartXmlCodeFoldBlock(cfbtXmlDocType);
      Inc(Run, 7);
    end else if NextTokenIs('[CDATA[') then begin
      fTokenID := tkCDATA;
      fRange := rsCDATA;
      StartXmlCodeFoldBlock(cfbtXmlCData);
      Inc(Run, 7);
    end else begin
      fTokenID := tkSymbol;
      fRange := rsElement;
      Inc(Run);
    end;
  end else if fLine[Run]= '?' then begin
    fTokenID := tkProcessingInstruction;
    fRange := rsProcessingInstruction;
    StartXmlCodeFoldBlock(cfbtXmlProcess);
    Inc(Run);
  end else begin
    fTokenID := tkSymbol;
    fRange := rsOpenElement;
  end;
end;

procedure TSynXMLSyn.GreaterThanProc;
begin
  if (Run > 0) and (fLine[Run - 1] = '/') then
    if TopXmlCodeFoldBlockType = cfbtXmlElement then
      EndXmlElemCodeFoldBlock;

  fTokenId := tkSymbol;
  fRange:= rsText;
  Inc(Run);
end;

procedure TSynXMLSyn.CommentProc;
begin
  if (fLine[Run] = '-') and (fLine[Run + 1] = '-') and
     (fLine[Run + 2] = '>')
  then begin
    fTokenID := tkSymbol;
    fRange:= rsText;
    Inc(Run, 3);
    if TopXmlCodeFoldBlockType = cfbtXmlComment then
      EndXmlCodeFoldBlock;
    Exit;
  end;

  fTokenID := tkComment;

  if (fLine[Run] In [#0, #10, #13]) then begin
    fProcTable[fLine[Run]]{$IFDEF FPC}(){$ENDIF};
    Exit;
  end;

  while not (fLine[Run] in [#0, #10, #13]) do begin
    if (fLine[Run] = '-') and (fLine[Run + 1] = '-') and (fLine[Run + 2] = '>')
    then begin
      fRange := rsComment;
      break;
    end;
    Inc(Run);
  end;
end;

procedure TSynXMLSyn.ProcessingInstructionProc;
begin
  fTokenID := tkProcessingInstruction;
  if (fLine[Run] In [#0, #10, #13]) then begin
    fProcTable[fLine[Run]]{$IFDEF FPC}(){$ENDIF};
    Exit;
  end;

  while not (fLine[Run] in [#0, #10, #13]) do begin
    if (fLine[Run] = '>') and (fLine[Run - 1] = '?')
    then begin
      fRange := rsText;
      Inc(Run);
      if TopXmlCodeFoldBlockType = cfbtXmlProcess then
        EndXmlCodeFoldBlock;
      break;
    end;
    Inc(Run);
  end;
end;

procedure TSynXMLSyn.DocTypeProc;                                              //ek 2001-11-11
begin
  fTokenID := tkDocType;

  if (fLine[Run] In [#0, #10, #13]) then begin
    fProcTable[fLine[Run]]{$IFDEF FPC}(){$ENDIF};
    Exit;
  end;

  case fRange of
    rsDocType:
      begin
        while not (fLine[Run] in [#0, #10, #13]) do
        begin
          case fLine[Run] of
            '[': begin
                   while True do
                   begin
                     inc(Run);
                     case fLine[Run] of
                       ']':
                         begin
                           Inc(Run);
                           Exit;
                         end;
                       #0, #10, #13:
                         begin
                           fRange:=rsDocTypeSquareBraces;
                           Exit;
                         end;
                     end;
                   end;
                 end;
            '>': begin
                   fRange := rsAttribute;
                   if TopXmlCodeFoldBlockType = cfbtXmlDocType then
                     EndXmlCodeFoldBlock;
                   Inc(Run);
                   Break;
                 end;
          end;
          inc(Run);
        end;
    end;
    rsDocTypeSquareBraces:
      begin
        while not (fLine[Run] in [#0, #10, #13]) do
        begin
          if (fLine[Run]=']') then
          begin
            fRange := rsDocType;
            Inc(Run);
            Exit;
          end;
          inc(Run);
        end;
      end;
  end;
end;

procedure TSynXMLSyn.CDATAProc;
begin
  fTokenID := tkCDATA;
  if (fLine[Run] In [#0, #10, #13]) then
  begin
    fProcTable[fLine[Run]]{$IFDEF FPC}(){$ENDIF};
    Exit;
  end;

  while not (fLine[Run] in [#0, #10, #13]) do
  begin
    if (Run >= 2) and (fLine[Run] = '>') and (fLine[Run - 1] = ']') and
       (fLine[Run - 2] = ']')
    then begin
      fRange := rsText;
      Inc(Run);
      if TopXmlCodeFoldBlockType = cfbtXmlCData then
        EndXmlCodeFoldBlock;
      break;
    end;
    Inc(Run);
  end;
end;

procedure TSynXMLSyn.ElementProc;
var
  NameStart: LongInt;
begin
  if fLine[Run] = '/' then
    Inc(Run);
  NameStart := Run;
  while (fLine[Run] in NameChars) do Inc(Run);

  if fRange = rsOpenElement then
    StartXmlElemCodeFoldBlock(cfbtXmlElement, NameStart, Copy(fLine, NameStart + 1, Run - NameStart));

  if fRange = rsCloseElement then
    EndXmlElemCodeFoldBlock(NameStart, Copy(fLine, NameStart + 1, Run - NameStart));   // TODO: defer until ">" reached

  fRange := rsAttribute;
  fTokenID := tkElement;
end;

procedure TSynXMLSyn.AttributeProc;
begin
  //Check if we are starting on a closing quote
  if (fLine[Run] in [#34, #39]) then
  begin
    fTokenID := tkSymbol;
    fRange := rsAttribute;
    Inc(Run);
    Exit;
  end;
  //Read the name
  while (fLine[Run] in NameChars) do Inc(Run);
  //Check if this is an xmlns: attribute
  if (Pos('xmlns', GetToken) > 0) then begin
    fTokenID := tknsAttribute;
    fRange := rsnsEqual;
  end else begin
    fTokenID := tkAttribute;
    fRange := rsEqual;
  end;
end;

procedure TSynXMLSyn.EqualProc;
begin
  if fRange = rsnsEqual then
    fTokenID := tknsEqual
  else
    fTokenID := tkEqual;

  while not (fLine[Run] in [#0, #10, #13]) do
  begin
    if (fLine[Run] = '/') then
    begin
      fTokenID := tkSymbol;
      fRange := rsElement;
      Inc(Run);
      Exit;
    end else if (fLine[Run] = #34) then
    begin
      if fRange = rsnsEqual then
        fRange := rsnsQuoteAttrValue
      else
        fRange := rsQuoteAttrValue;
      Inc(Run);
      Exit;
    end else if (fLine[Run] = #39) then
    begin
      if fRange = rsnsEqual then
        fRange := rsnsAPosAttrValue
      else
        fRange := rsAPosAttrValue;
      Inc(Run);
      Exit;
    end;
    Inc(Run);
  end;
end;

procedure TSynXMLSyn.QAttributeValueProc;
begin
  if fRange = rsnsQuoteAttrValue then
    fTokenID := tknsQuoteAttrValue
  else
    fTokenID := tkQuoteAttrValue;

  while not (fLine[Run] in [#0, #10, #13, '&', #34]) do Inc(Run);

  if fLine[Run] = '&' then
  begin
    if fRange = rsnsQuoteAttrValue then
      fRange := rsnsQuoteEntityRef
    else
      fRange := rsQuoteEntityRef;
    Exit;
  end else if fLine[Run] <> #34 then
  begin
    Exit;
  end;

  fRange := rsAttribute;
end;

procedure TSynXMLSyn.AAttributeValueProc;
begin
  if fRange = rsnsAPosAttrValue then
    fTokenID := tknsAPosAttrValue
  else
    fTokenID := tkAPosAttrValue;

  while not (fLine[Run] in [#0, #10, #13, '&', #39]) do Inc(Run);

  if fLine[Run] = '&' then
  begin
    if fRange = rsnsAPosAttrValue then
      fRange := rsnsAPosEntityRef
    else
      fRange := rsAPosEntityRef;
    Exit;
  end else if fLine[Run] <> #39 then
  begin
    Exit;
  end;

  fRange := rsAttribute;
end;

procedure TSynXMLSyn.TextProc;
const StopSet = [#0..#31, '<', '&'];
begin
  if fLine[Run] in (StopSet - ['&']) then begin
    fProcTable[fLine[Run]]{$IFDEF FPC}(){$ENDIF};
    exit;
  end;

  fTokenID := tkText;
  while not (fLine[Run] in StopSet) do Inc(Run);

  if (fLine[Run] = '&') then begin
    fRange := rsEntityRef;
    Exit;
  end;
end;

procedure TSynXMLSyn.EntityRefProc;
begin
  fTokenID := tkEntityRef;
  fRange := rsEntityRef;
  while not (fLine[Run] in [#0..#32, ';']) do Inc(Run);
  if (fLine[Run] = ';') then Inc(Run);
  fRange := rsText;
end;

procedure TSynXMLSyn.QEntityRefProc;
begin
  if fRange = rsnsQuoteEntityRef then
    fTokenID := tknsQuoteEntityRef
  else
    fTokenID := tkQuoteEntityRef;

  while not (fLine[Run] in [#0..#32, ';']) do Inc(Run);
  if (fLine[Run] = ';') then Inc(Run);

  if fRange = rsnsQuoteEntityRef then
    fRange := rsnsQuoteAttrValue
  else
    fRange := rsQuoteAttrValue;
end;

procedure TSynXMLSyn.AEntityRefProc;
begin
  if fRange = rsnsAPosEntityRef then
    fTokenID := tknsAPosEntityRef
  else
    fTokenID := tkAPosEntityRef;

  while not (fLine[Run] in [#0..#32, ';']) do Inc(Run);
  if (fLine[Run] = ';') then Inc(Run);

  if fRange = rsnsAPosEntityRef then
    fRange := rsnsAPosAttrValue
  else
    fRange := rsAPosAttrValue;
end;

function TSynXMLSyn.UpdateRangeInfoAtLine(Index: Integer): Boolean;
var
  InfoOpenLenChanged, InfoCloseLenChanged: Boolean;
begin
  Result := inherited UpdateRangeInfoAtLine(Index);
  InfoOpenLenChanged := Length(FXmlRangeInfo.ElementOpenList) <> FXmlRangeInfoOpenPos;
  InfoCloseLenChanged := Length(FXmlRangeInfo.ElementCloseList) <> FXmlRangeInfoClosePos;
  if FXmlRangeInfoChanged or InfoOpenLenChanged or InfoCloseLenChanged then begin
    Result := True;
    if InfoOpenLenChanged then
      SetLength(FXmlRangeInfo.ElementOpenList, FXmlRangeInfoOpenPos);
    if InfoCloseLenChanged then
      SetLength(FXmlRangeInfo.ElementCloseList, FXmlRangeInfoClosePos);
    TSynHighlighterXmlRangeList(CurrentRanges).XmlRangeInfo[LineIndex] := FXmlRangeInfo; // Store on this line
    FXmlRangeInfoChanged := False;
  end;
end;

procedure TSynXMLSyn.IdentProc;
begin
  case fRange of
  rsElement, rsOpenElement, rsCloseElement:
    begin
      ElementProc{$IFDEF FPC}(){$ENDIF};
    end;
  rsAttribute:
    begin
      AttributeProc{$IFDEF FPC}(){$ENDIF};
    end;
  rsEqual, rsnsEqual:
    begin
      EqualProc{$IFDEF FPC}(){$ENDIF};
    end;
  rsQuoteAttrValue, rsnsQuoteAttrValue:
    begin
      QAttributeValueProc{$IFDEF FPC}(){$ENDIF};
    end;
  rsAposAttrValue, rsnsAPosAttrValue:
    begin
      AAttributeValueProc{$IFDEF FPC}(){$ENDIF};
    end;
  rsQuoteEntityRef, rsnsQuoteEntityRef:
    begin
      QEntityRefProc{$IFDEF FPC}(){$ENDIF};
    end;
  rsAposEntityRef, rsnsAPosEntityRef:
    begin
      AEntityRefProc{$IFDEF FPC}(){$ENDIF};
    end;
  rsEntityRef:
    begin
      EntityRefProc{$IFDEF FPC}(){$ENDIF};
    end;
  else ;
  end;
end;

procedure TSynXMLSyn.Next;
begin
  fTokenPos := Run;
  case fRange of
  rsText:
    begin
      TextProc{$IFDEF FPC}(){$ENDIF};
    end;
  rsComment:
    begin
      CommentProc{$IFDEF FPC}(){$ENDIF};
    end;
  rsProcessingInstruction:
    begin
      ProcessingInstructionProc{$IFDEF FPC}(){$ENDIF};
    end;
  rsDocType, rsDocTypeSquareBraces:                                            //ek 2001-11-11
    begin
      DocTypeProc{$IFDEF FPC}(){$ENDIF};
    end;
  rsCDATA:
    begin
      CDATAProc{$IFDEF FPC}(){$ENDIF};
    end;
  else
    fProcTable[fLine[Run]]{$IFDEF FPC}(){$ENDIF};
  end;
end;

function TSynXMLSyn.NextTokenIs(T : String) : Boolean;
var I, Len : Integer;
begin
  Result:= True;
  Len:= Length(T);
  for I:= 1 to Len do
    if (fLine[Run + I] <> T[I]) then
    begin
      Result:= False;
      Break;
    end;
end;

function TSynXMLSyn.GetDefaultAttribute(
  Index: integer): TSynHighlighterAttributes;
begin
  case Index of
    SYN_ATTR_COMMENT: Result := fCommentAttri;
    SYN_ATTR_IDENTIFIER: Result := fAttributeAttri;
    SYN_ATTR_KEYWORD: Result := fElementAttri;
    SYN_ATTR_WHITESPACE: Result := fSpaceAttri;
    SYN_ATTR_SYMBOL: Result := fSymbolAttri;
  else
    Result := nil;
  end;
end;

function TSynXMLSyn.GetEol: Boolean;
begin
  Result := fTokenId = tkNull;
end;

function TSynXMLSyn.GetToken: string;
var
  len: Longint;
begin
  Result := '';
  Len := (Run - fTokenPos);
  SetString(Result, (FLine + fTokenPos), len);
end;

{$IFDEF SYN_LAZARUS}
procedure TSynXMLSyn.GetTokenEx(out TokenStart: PChar;
  out TokenLength: integer);
begin
  TokenLength:=Run-fTokenPos;
  TokenStart:=FLine + fTokenPos;
end;
{$ENDIF}

function TSynXMLSyn.GetTokenID: TtkTokenKind;
begin
  Result := fTokenId;
end;

function TSynXMLSyn.GetTokenAttribute: TSynHighlighterAttributes;
begin
  case fTokenID of
    tkElement: Result:= fElementAttri;
    tkAttribute: Result:= fAttributeAttri;
    tknsAttribute: Result:= fnsAttributeAttri;
    tkEqual: Result:= fSymbolAttri;
    tknsEqual: Result:= fSymbolAttri;
    tkQuoteAttrValue: Result:= fAttributeValueAttri;
    tkAPosAttrValue: Result:= fAttributeValueAttri;
    tknsQuoteAttrValue: Result:= fnsAttributeValueAttri;
    tknsAPosAttrValue: Result:= fnsAttributeValueAttri;
    tkText: Result:= fTextAttri;
    tkCDATA: Result:= fCDATAAttri;
    tkEntityRef: Result:= fEntityRefAttri;
    tkQuoteEntityRef: Result:= fEntityRefAttri;
    tkAposEntityRef: Result:= fEntityRefAttri;
    tknsQuoteEntityRef: Result:= fEntityRefAttri;
    tknsAposEntityRef: Result:= fEntityRefAttri;
    tkProcessingInstruction: Result:= fProcessingInstructionAttri;
    tkComment: Result:= fCommentAttri;
    tkDocType: Result:= fDocTypeAttri;
    tkSymbol: Result:= fSymbolAttri;
    tkSpace: Result:= fSpaceAttri;
  else
    Result := nil;
  end;
end;

function TSynXMLSyn.GetTokenKind: integer;
begin
  Result := Ord(fTokenId);
end;

function TSynXMLSyn.GetTokenPos: Integer;
begin
  Result := fTokenPos;
end;

function TSynXMLSyn.GetRange: Pointer;
begin
  CodeFoldRange.RangeType:=Pointer(PtrUInt(Integer(fRange)));
  Result := inherited;
end;

procedure TSynXMLSyn.SetRange(Value: Pointer);
begin
  inherited;
  fRange := TRangeState(Integer(PtrUInt(CodeFoldRange.RangeType)));
end;

procedure TSynXMLSyn.ReSetRange;
begin
  inherited;
  fRange:= rsText;
end;

function TSynXMLSyn.FoldOpenCount(ALineIndex: Integer; AType: Integer): integer;
begin
  Result := EndFoldLevel(ALineIndex) - MinimumFoldLevel(ALineIndex);
end;

function TSynXMLSyn.FoldCloseCount(ALineIndex: Integer; AType: Integer): integer;
begin
  Result := EndFoldLevel(ALineIndex - 1) - MinimumFoldLevel(ALineIndex);
end;

function TSynXMLSyn.FoldNestCount(ALineIndex: Integer; AType: Integer): integer;
begin
  Result := EndFoldLevel(ALineIndex);
end;

function TSynXMLSyn.FoldLineLength(ALineIndex, FoldIndex: Integer): integer;
var
  i, lvl, cnt: Integer;
  e, m: Integer;
begin
  //atype := FoldTypeAtNodeIndex(ALineIndex, FoldIndex);
  cnt := CurrentLines.Count;
  e := EndFoldLevel(ALineIndex);
  m := MinimumFoldLevel(ALineIndex);
  lvl := Min(m+1+FoldIndex, e);
  i := ALineIndex + 1;
  while (i < cnt) and (MinimumFoldLevel(i) >= lvl) do inc(i);
  // check if fold last line of block (not mixed "end begin")
  // and not lastlinefix
  if (i = cnt) or (EndFoldLevel(i) > MinimumFoldLevel(i)) then
    dec(i);
  // Amount of lines, that will become invisible (excludes the cfCollapsed line)
  Result := i - ALineIndex;
end;

function TSynXMLSyn.MinimumFoldLevel(ALineIndex: Integer): integer;
var
  r: TSynCustomHighlighterRange;
begin
  if (ALineIndex < 0) or (ALineIndex >= CurrentLines.Count) then
    exit(0);
  r := TSynCustomHighlighterRange(CurrentRanges[ALineIndex]);
  if (r <> nil) and (Pointer(r) <> NullRange) then
    Result := r.MinimumCodeFoldBlockLevel
  else
    Result := 0;
end;

function TSynXMLSyn.EndFoldLevel(ALineIndex: Integer): integer;
var
  r: TSynCustomHighlighterRange;
begin
  if (ALineIndex < 0) or (ALineIndex >= CurrentLines.Count) then
    exit(0);
  r := TSynCustomHighlighterRange(CurrentRanges[ALineIndex]);
  if (r <> nil) and (Pointer(r) <> NullRange) then
    Result := r.CodeFoldStackSize
  else
    Result := 0;
end;

function TSynXMLSyn.GetIdentChars: TSynIdentChars;
begin
  Result := ['0'..'9', 'a'..'z', 'A'..'Z', '_', '.', '-'] + TSynSpecialChars;
end;

{$IFNDEF SYN_CPPB_1} class {$ENDIF}
function TSynXMLSyn.GetLanguageName: string;
begin
  Result := SYNS_LangXML;
end;

function TSynXMLSyn.GetSampleSource: String;
begin
  Result:= '<?xml version="1.0"?>'#13#10+
           '<!DOCTYPE root ['#13#10+
           '  ]>'#13#10+
           '<!-- Comment -->'#13#10+
           '<root version="&test;">'#13#10+
           '  <![CDATA[ **CDATA section** ]]>'#13#10+
           '</root>';
end;

procedure TSynXMLSyn.CreateRootCodeFoldBlock;
begin
  inherited CreateRootCodeFoldBlock;
  RootCodeFoldBlock.InitRootBlockType(Pointer(PtrInt(cfbtXmlNone)));
end;

function TSynXMLSyn.CreateRangeList: TSynHighlighterRangeList;
begin
  Result := TSynHighlighterXmlRangeList.Create;
end;

function TSynXMLSyn.StartXmlCodeFoldBlock(ABlockType: TXmlCodeFoldBlockType): TSynCustomCodeFoldBlock;
begin
  if CodeFoldRange.CodeFoldStackSize >= MaxFoldNestDeep then exit;
  StartCodeFoldBlock(Pointer(PtrInt(ABlockType)));
end;

function TSynXMLSyn.StartXmlElemCodeFoldBlock(ABlockType: TXmlCodeFoldBlockType;
  OpenPos: Integer; AName: String): TSynCustomCodeFoldBlock;
var
  i: Integer;
begin
  If IsScanning then begin
    AName := LowerCase(AName);
    i := Length(FXmlRangeInfo.ElementOpenList);
    if (FXmlRangeInfoOpenPos < i) then begin
      if (FXmlRangeInfo.ElementOpenList[FXmlRangeInfoOpenPos] <> AName) then begin
        FXmlRangeInfo.ElementOpenList[FXmlRangeInfoOpenPos] := AName;
        FXmlRangeInfoChanged := true; // TODO:if this node closes on the same line, it may not be amodified ....
      end;
    end else begin     // append - modified will be deteced by the new length
      SetLength(FXmlRangeInfo.ElementOpenList, FXmlRangeInfoOpenPos + 10);
      FXmlRangeInfo.ElementOpenList[FXmlRangeInfoOpenPos] := AName;
    end;
  end;
  inc(FXmlRangeInfoOpenPos);
  StartXmlCodeFoldBlock(ABlockType);
end;

procedure TSynXMLSyn.EndXmlCodeFoldBlock;
begin
  EndCodeFoldBlock();
end;

procedure TSynXMLSyn.EndXmlElemCodeFoldBlock(ClosePos: Integer = -1; AName: String = '');
var
  cnt, i, k, lvl: Integer;
  LInfo: Array of String;
begin
  if not (TopXmlCodeFoldBlockType = cfbtXmlElement) then debugln('---- XXXXX TSynXMLSyn.EndXmlElemCodeFoldBlock XXXXX');
  AName := LowerCase(AName);

  cnt := 0;
  If IsScanning then begin
    if (AName = '') and (CodeFoldRange.CodeFoldStackSize > 0) then begin
      cnt := 1;
    end
    else begin
      cnt := 1;
      i := FXmlRangeInfoOpenPos;
      while i > 0 do begin
        if TopXmlCodeFoldBlockType(FXmlRangeInfoOpenPos - i) <> cfbtXmlElement then debugln('---- XXXXX TSynXMLSyn.EndXmlElemCodeFoldBlock XXXXX');
        if (FXmlRangeInfo.ElementOpenList[i-1] = AName) then
          break;
        dec(i);
        inc(cnt);
      end;

      if i = 0 then begin
        i := LineIndex - 1;
        lvl := EndFoldLevel(i);
        while i >= 0 do begin
          if MinimumFoldLevel(i) < lvl then begin
            LInfo := TSynHighlighterXmlRangeList(CurrentRanges).XmlRangeInfo[i].ElementOpenList;
            k := length(LInfo) - Max(EndFoldLevel(i) - lvl, 0) - 1;
            while (k >= 0) do begin
              if (LInfo[k] = AName) then
                break;
              inc(cnt);
              dec(k);
              dec(lvl);
            end;
            if k >= 0 then break;
          end;
          dec(i);
        end;

        if (i < 0) or (cnt > CodeFoldRange.CodeFoldStackSize ) then cnt := 0; // never opened, do not close
      end;
    end;

    i := Length(FXmlRangeInfo.ElementCloseList);
    if (FXmlRangeInfoClosePos < i) then begin
      if (FXmlRangeInfo.ElementCloseList[FXmlRangeInfoClosePos] <> cnt) then begin
        FXmlRangeInfo.ElementCloseList[FXmlRangeInfoClosePos] := cnt;
        FXmlRangeInfoChanged := true;
      end;
    end else begin  // append - modified will be deteced by the new length
      SetLength(FXmlRangeInfo.ElementCloseList, FXmlRangeInfoClosePos + 10);
      FXmlRangeInfo.ElementCloseList[FXmlRangeInfoClosePos] := cnt;
    end;
  end
  else begin
    if FXmlRangeInfoClosePos < length(FXmlRangeInfo.ElementCloseList) then
      cnt := FXmlRangeInfo.ElementCloseList[FXmlRangeInfoClosePos]
    else
      cnt := 0;
  end;
  inc(FXmlRangeInfoClosePos);

  for i := 1 to cnt do begin
    if FXmlRangeInfoOpenPos > 0 then
      dec(FXmlRangeInfoOpenPos);
    EndXmlCodeFoldBlock;
  end;
end;

function TSynXMLSyn.TopXmlCodeFoldBlockType(DownIndex: Integer): TXmlCodeFoldBlockType;
begin
  Result := TXmlCodeFoldBlockType(PtrUInt(TopCodeFoldBlockType(DownIndex)));
end;

{ TSynHighlighterXmlRangeList }

function TSynHighlighterXmlRangeList.GetXmlRangeInfo(Index: Integer): TSynXmlRangeInfo;
begin
  if (Index < 0) or (Index >= Count) then begin
    Result.ElementOpenList := nil;
    exit;
  end;
  Result := TSynXmlRangeInfo((ItemPointer[Index] + inherited ItemSize)^);
end;

procedure TSynHighlighterXmlRangeList.SetXmlRangeInfo(Index: Integer;
  const AValue: TSynXmlRangeInfo);
begin
  TSynXmlRangeInfo((ItemPointer[Index] + inherited ItemSize)^) := AValue;
end;

procedure TSynHighlighterXmlRangeList.SetCapacity(const AValue: Integer);
var
  i: LongInt;
begin
  for i := AValue to Capacity-1 do
    with TSynXmlRangeInfo((ItemPointer[i] + inherited ItemSize)^) do begin
      ElementOpenList := nil;
      ElementCloseList := nil;
    end;
  inherited SetCapacity(AValue);
end;

function TSynHighlighterXmlRangeList.ItemSize: Integer;
begin
  Result := inherited ItemSize + SizeOf(TSynXmlRangeInfo);
end;

procedure TSynHighlighterXmlRangeList.Move(AFrom, ATo, ALen: Integer);
var
  i: LongInt;
begin
  if ATo > AFrom then
    for i:= Max(AFrom + ALen, ATo) to ATo + ALen - 1 do // move forward
      with TSynXmlRangeInfo((ItemPointer[i] + inherited ItemSize)^) do begin
        ElementOpenList := nil;
        ElementCloseList := nil;
      end
  else
    for i:= ATo to Min(ATo + ALen , AFrom) - 1 do // move backward
      with TSynXmlRangeInfo((ItemPointer[i] + inherited ItemSize)^) do begin
        ElementOpenList := nil;
        ElementCloseList := nil;
      end;
  inherited Move(AFrom, ATo, ALen);
end;

initialization

  {$IFNDEF SYN_CPPB_1}
  RegisterPlaceableHighlighter(TSynXMLSyn);
  {$ENDIF}

end.



