{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/
Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.
-------------------------------------------------------------------------------}
{ Examples:
  indent (begin, asm, try, var, const, type, resourcestring,
     public, protected, private, published, automated, repeat)
    begin
      |

  unindent (end, until)
    begin
    |end

  unindent and indent (finally, public, published, private, protected)
    finally
      |

  if,else without begin:
    if expr then
      |
    else
      |

  case
    case expr of
    else
      |
    end;

  type as modifier:
    type
      TColor = type integer;
}
unit SynBeautifierPas;

{$I synedit.inc}

interface

uses
  Math, Classes, SysUtils, LCLProc, SynEdit, SynBeautifier, SynEditTextBuffer,
  SynEditHighlighter, SynHighlighterPas;
  
type

  { TSynBeautifierPas }

  TSynBeautifierPas = class(TSynBeautifier)
  public
    function TokenKindIsComment(Kind: integer): boolean;
    function InComment(Editor: TCustomSynEdit; XY: TPoint): boolean;
    procedure ReadPriorToken(Editor: TCustomSynEdit; var Y, StartX, EndX: integer);
  end;

implementation

{ TSynBeautifierPas }

procedure TSynBeautifierPas.ReadPriorToken(Editor: TCustomSynEdit; var Y,
  StartX, EndX: integer);
var
  Lines: TSynEditStringList;
  TokenStart: Integer;
  Line: string;
  Highlighter: TSynCustomHighlighter;
  Token: String;
begin
  Highlighter:=Editor.Highlighter;
  if Highlighter=nil then begin
    Y:=0;
    exit;
  end;

  Lines:=TSynEditStringList(Editor.Lines);
  if Y>Lines.Count then begin
    // cursor after end of code
    // => move to end of last line
    Y:=Lines.Count;
    if Y=0 then exit;
    StartX:=length(Lines[Y-1])+1;
  end else if Y<=0 then begin
    // cursor in front of code => no prior token
    exit;
  end;
  
  Line:=Lines[Y-1];
  if Y = 1 then
    Highlighter.ResetRange
  else
    Highlighter.SetRange(TSynEditStringList(Lines).Ranges[Y - 2]);
  if StartX>length(Line) then begin
    TokenStart:=length(Line)+1;
    //TokenType:=Highlighter.GetTokenKind;
  end else begin
    Highlighter.SetLine(Line, Y-1);
    while not Highlighter.GetEol do begin
      TokenStart := Highlighter.GetTokenPos + 1;
      Token := Highlighter.GetToken;
      DebugLn(['TSynBeautifierPas.ReadPriorToken Start=',TokenStart,' Token="',Token,'"']);
      if (StartX >= TokenStart) and (StartX < TokenStart + Length(Token)) then
      begin
        DebugLn(['TSynBeautifierPas.ReadPriorToken ']);
        //TokenType:=Highlighter.GetTokenKind;
        break;
      end;
      Highlighter.Next;
    end;
  end;
  
end;

function TSynBeautifierPas.TokenKindIsComment(Kind: integer): boolean;
begin
  Result:=(ord(tkComment)=Kind) or (ord(tkDirective)=Kind);
end;

function TSynBeautifierPas.InComment(Editor: TCustomSynEdit; XY: TPoint
  ): boolean;
var
  Highlighter: TSynPasSyn;
  Lines: TSynEditStringList;
  Line: string;
  Start: Integer;
  Token: String;
  TokenType: LongInt;
begin
  DebugLn(['TSynBeautifierPas.InComment ',dbgs(XY)]);
  Highlighter:=TSynPasSyn(Editor.Highlighter);
  if Highlighter=nil then begin
    DebugLn(['TSynBeautifierPas.InComment missing Highlighter']);
    exit(false);
  end;

  Lines:=TSynEditStringList(Editor.Lines);
  if Lines.Count=0 then begin
    DebugLn(['TSynBeautifierPas.InComment Lines empty']);
    exit(false); // no code
  end;
  
  if XY.Y>Lines.Count then begin
    // cursor after end of code
    DebugLn(['TSynBeautifierPas.InComment cursor after end of code']);
    XY.Y:=Lines.Count;
    Highlighter.SetRange(Lines.Ranges[XY.Y - 1]);
    TokenType:=Highlighter.GetTokenKind;
  end else if XY.Y<=0 then begin
    // cursor in front of code => no prior token
    DebugLn(['TSynBeautifierPas.InComment cursor in front of code']);
    exit(false);
  end else begin
    Line:=Lines[XY.Y-1];
    if XY.X<1 then begin
      // cursor left of code
      if XY.Y=1 then begin
        // cursor in front of code => no prior token
        DebugLn(['TSynBeautifierPas.InComment cursor in front of code']);
        exit(false);
      end;
      DebugLn(['TSynBeautifierPas.InComment cursor left of code']);
      Highlighter.SetRange(Lines.Ranges[XY.Y - 2]);
      Highlighter.SetLine(' ',XY.Y-1);
      TokenType:=Highlighter.GetTokenKind;
    end else begin
      if XY.Y = 1 then
        Highlighter.ResetRange
      else
        Highlighter.SetRange(Lines.Ranges[XY.Y - 1]);
      if XY.X>length(Line) then
        XY.X:=length(Line)+1;
      DebugLn(['TSynBeautifierPas.InComment scanning line ...']);
      Highlighter.SetLine(Line+' ', XY.Y-1);
      while not Highlighter.GetEol do begin
        Start := Highlighter.GetTokenPos + 1;
        Token := Highlighter.GetToken;
        DebugLn(['TSynBeautifierPas.InComment "',Token,'"']);
        if (XY.X >= Start) and (XY.X < Start + Length(Token)) then begin
          TokenType := Highlighter.GetTokenKind;
          break;
        end;
        Highlighter.Next;
      end;
    end;
  end;

  DebugLn(['TSynBeautifierPas.InComment ',TokenType]);
  Result:=TokenKindIsComment(TokenType);
end;

end.

