{
  BEWARE !!!
  This is a TEMPORARY file.
  As soon as it is moved to the fcl, it will be removed.
}

{
    $Id$
    This file is part of the Free Component Library

    XML reading routines.
    Copyright (c) 1999-2000 by Sebastian Guenther, sg@freepascal.org

    See the file COPYING.modifiedLGPL, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit Laz_XMLRead;

{$MODE objfpc}
{$H+}

interface

{off $DEFINE MEM_CHECK}

uses
  {$IFDEF MEM_CHECK}MemCheck,{$ENDIF}
  SysUtils, Classes, FileProcs, Laz_DOM;

type

  EXMLReadError = class(Exception);


procedure ReadXMLFile(var ADoc: TXMLDocument; const AFilename: String);
procedure ReadXMLFile(var ADoc: TXMLDocument; var f: File);
procedure ReadXMLFile(var ADoc: TXMLDocument; var f: TStream);
procedure ReadXMLFile(var ADoc: TXMLDocument; var f: TStream;
  const AFilename: String);

procedure ReadDTDFile(var ADoc: TXMLDocument; const AFilename: String);
procedure ReadDTDFile(var ADoc: TXMLDocument; var f: File);
procedure ReadDTDFile(var ADoc: TXMLDocument; var f: TStream);
procedure ReadDTDFile(var ADoc: TXMLDocument; var f: TStream;
  const AFilename: String);


// =======================================================

implementation

const

  Letter = ['A'..'Z', 'a'..'z'];
  Digit = ['0'..'9'];
  PubidChars: set of Char = [' ', #13, #10, 'a'..'z', 'A'..'Z', '0'..'9',
    '-', '''', '(', ')', '+', ',', '.', '/', ':', '=', '?', ';', '!', '*',
    '#', '@', '$', '_', '%'];
  WhitespaceChars: set of Char = [#9, #10, #13, ' '];

  NmToken: set of Char = Letter + Digit + ['.', '-', '_', ':'];

function ComparePChar(p1, p2: PChar): boolean;
begin
  if p1<>p2 then begin
    if (p1<>nil) and (p2<>nil) then begin
      while true do begin
        if (p1^=p2^) then begin
          if p1^<>#0 then begin
            inc(p1);
            inc(p2);
          end else begin
            Result:=true;
            exit;
          end;
        end else begin
          Result:=false;
          exit;
        end;
      end;
      Result:=true;
    end else begin
      Result:=false;
    end;
  end else begin
    Result:=true;
  end;
end;

function CompareLPChar(p1, p2: PChar; Max: integer): boolean;
begin
  if p1<>p2 then begin
    if (p1<>nil) and (p2<>nil) then begin
      while Max>0 do begin
        if (p1^=p2^) then begin
          if (p1^<>#0) then begin
            inc(p1);
            inc(p2);
            dec(Max);
          end else begin
            Result:=true;
            exit;
          end;
        end else begin
          Result:=false;
          exit;
        end;
      end;
      Result:=true;
    end else begin
      Result:=false;
    end;
  end else begin
    Result:=true;
  end;
end;

function CompareIPChar(p1, p2: PChar): boolean;
begin
  if p1<>p2 then begin
    if (p1<>nil) and (p2<>nil) then begin
      while true do begin
        if (p1^=p2^) or (upcase(p1^)=upcase(p2^)) then begin
          if p1^<>#0 then begin
            inc(p1);
            inc(p2);
          end else begin
            Result:=true;
            exit;
          end;
        end else begin
          Result:=false;
          exit;
        end;
      end;
      Result:=true;
    end else begin
      Result:=false;
    end;
  end else begin
    Result:=true;
  end;
end;

function CompareLIPChar(p1, p2: PChar; Max: integer): boolean;
begin
  if p1<>p2 then begin
    if (p1<>nil) and (p2<>nil) then begin
      while Max>0 do begin
        if (p1^=p2^) or (upcase(p1^)=upcase(p2^)) then begin
          if (p1^<>#0) then begin
            inc(p1);
            inc(p2);
            dec(Max);
          end else begin
            Result:=true;
            exit;
          end;
        end else begin
          Result:=false;
          exit;
        end;
      end;
      Result:=true;
    end else begin
      Result:=false;
    end;
  end else begin
    Result:=true;
  end;
end;


type
  TXMLReaderDocument = class(TXMLDocument)
  public
    procedure SetDocType(ADocType: TDOMDocumentType);
  end;

  TXMLReaderDocumentType = class(TDOMDocumentType)
  public
    constructor Create(ADocument: TXMLReaderDocument);
    property Name: DOMString read FNodeName write FNodeName;
  end;


  TSetOfChar = set of Char;

  TXMLReader = class
  protected
    buf, BufStart: PChar;
    Filename: String;

    procedure RaiseExc(const descr: String);
    function  SkipWhitespace: Boolean;
    procedure ExpectWhitespace;
    procedure ExpectString(const s: String);
    function  CheckFor(s: PChar): Boolean;
    function  CheckForChar(c: Char): Boolean;
    procedure SkipString(const ValidChars: TSetOfChar);
    function  GetString(const ValidChars: TSetOfChar): String;
    function  GetString(BufPos: PChar; Len: integer): String;

    function  CheckName: Boolean;
    function  GetName(var s: String): Boolean;
    function  ExpectName: String;                                       // [5]
    procedure SkipName;
    procedure ExpectAttValue(attr: TDOMAttr);                           // [10]
    function  ExpectPubidLiteral: String;                               // [12]
    procedure SkipPubidLiteral;
    function  ParseComment(AOwner: TDOMNode): Boolean;                  // [15]
    function  ParsePI: Boolean;                                         // [16]
    procedure ExpectProlog;                                             // [22]
    function  ParseEq: Boolean;                                         // [25]
    procedure ExpectEq;
    procedure ParseMisc(AOwner: TDOMNode);                              // [27]
    function  ParseMarkupDecl: Boolean;                                 // [29]
    function  ParseElement(AOwner: TDOMNode): Boolean;                  // [39]
    procedure ExpectElement(AOwner: TDOMNode);
    function  ParseReference(AOwner: TDOMNode): Boolean;                // [67]
    procedure ExpectReference(AOwner: TDOMNode);
    function  ParsePEReference: Boolean;                                // [69]
    function  ParseExternalID: Boolean;                                 // [75]
    procedure ExpectExternalID;
    function  ParseEncodingDecl: String;                                // [80]
    procedure SkipEncodingDecl;

    procedure ResolveEntities(RootNode: TDOMNode);
  public
    doc: TXMLReaderDocument;
    procedure ProcessXML(ABuf: PChar; const AFilename: String);  // [1]
    procedure ProcessDTD(ABuf: PChar; const AFilename: String);  // ([29])
  end;

{ TXMLReaderDocument }

procedure TXMLReaderDocument.SetDocType(ADocType: TDOMDocumentType);
begin
  FDocType := ADocType;
end;


constructor TXMLReaderDocumentType.Create(ADocument: TXMLReaderDocument);
begin
  inherited Create(ADocument);
end;



procedure TXMLReader.RaiseExc(const descr: String);
var
  apos: PChar;
  x, y: Integer;
begin
  // find out the line in which the error occured
  apos := BufStart;
  x := 1;
  y := 1;
  while apos < buf do begin
    if apos[0] = #10 then begin
      Inc(y);
      x := 1;
    end else
      Inc(x);
    Inc(apos);
  end;

  raise EXMLReadError.Create('In ' + Filename + ' (line ' + IntToStr(y) + ' pos ' +
    IntToStr(x) + '): ' + descr);
end;

function TXMLReader.SkipWhitespace: Boolean;
begin
  Result := False;
  while buf[0] in WhitespaceChars do
  begin
    Inc(buf);
    Result := True;
  end;
end;

procedure TXMLReader.ExpectWhitespace;
begin
  if not SkipWhitespace then
    RaiseExc('Expected whitespace');
end;

procedure TXMLReader.ExpectString(const s: String);

  procedure RaiseStringNotFound;
  var
    s2: PChar;
    s3: String;
  begin
    GetMem(s2, Length(s) + 1);
    StrLCopy(s2, buf, Length(s));
    s3 := StrPas(s2);
    FreeMem(s2, Length(s) + 1);
    RaiseExc('Expected "' + s + '", found "' + s3 + '"');
  end;

var
  i: Integer;
begin
  for i := 1 to Length(s) do
    if buf[i - 1] <> s[i] then begin
      RaiseStringNotFound;
    end;
  Inc(buf, Length(s));
end;

function TXMLReader.CheckFor(s: PChar): Boolean;
begin
  if buf[0] <> #0 then begin
    if (buf[0]=s[0]) and (CompareLPChar(buf, s, StrLen(s))) then begin
      Inc(buf, StrLen(s));
      Result := True;
    end else
      Result := False;
  end else begin
    Result := False;
  end;
end;

function TXMLReader.CheckForChar(c: Char): Boolean;
begin
  if (buf[0]=c) and (c<>#0) then begin
    inc(buf);
    Result:=true;
  end else begin
    Result:=false;
  end;
end;

procedure TXMLReader.SkipString(const ValidChars: TSetOfChar);
begin
  while buf[0] in ValidChars do begin
    Inc(buf);
  end;
end;

function TXMLReader.GetString(const ValidChars: TSetOfChar): String;
var
  OldBuf: PChar;
  i, len: integer;
begin
  OldBuf:=Buf;
  while buf[0] in ValidChars do begin
    Inc(buf);
  end;
  len:=buf-OldBuf;
  SetLength(Result, Len);
  for i:=1 to len do begin
    Result[i]:=OldBuf[0];
    inc(OldBuf);
  end;
end;

function TXMLReader.GetString(BufPos: PChar; Len: integer): string;
var i: integer;
begin
  SetLength(Result,Len);
  for i:=1 to Len do begin
    Result[i]:=BufPos[0];
    inc(BufPos);
  end;
end;

procedure TXMLReader.ProcessXML(ABuf: PChar; const AFilename: String);    // [1]
begin
  buf := ABuf;
  BufStart := ABuf;
  Filename := AFilename;

  doc := TXMLReaderDocument.Create;
  ExpectProlog;
  {$IFDEF MEM_CHECK}CheckHeapWrtMemCnt('TXMLReader.ProcessXML A');{$ENDIF}
  ExpectElement(doc);
  {$IFDEF MEM_CHECK}CheckHeapWrtMemCnt('TXMLReader.ProcessXML B');{$ENDIF}
  ParseMisc(doc);

  if buf[0] <> #0 then
    RaiseExc('Text after end of document element found');
end;

function TXMLReader.CheckName: Boolean;
var OldBuf: PChar;
begin
  if not (buf[0] in (Letter + ['_', ':'])) then begin
    Result := False;
    exit;
  end;

  OldBuf := buf;
  Inc(buf);
  SkipString(Letter + ['0'..'9', '.', '-', '_', ':']);
  buf := OldBuf;
  Result := True;
end;

function TXMLReader.GetName(var s: String): Boolean;    // [5]
var OldBuf: PChar;
begin
  if not (buf[0] in (Letter + ['_', ':'])) then begin
    SetLength(s, 0);
    Result := False;
    exit;
  end;

  OldBuf := buf;
  Inc(buf);
  SkipString(Letter + ['0'..'9', '.', '-', '_', ':']);
  s := GetString(OldBuf,buf-OldBuf);
  Result := True;
end;

function TXMLReader.ExpectName: String;    // [5]

  procedure RaiseNameNotFound;
  begin
    RaiseExc('Expected letter, "_" or ":" for name, found "' + buf[0] + '"');
  end;

var OldBuf: PChar;
begin
  if not (buf[0] in (Letter + ['_', ':'])) then
    RaiseNameNotFound;

  OldBuf := buf;
  Inc(buf);
  SkipString(Letter + ['0'..'9', '.', '-', '_', ':']);
  Result:=GetString(OldBuf,buf-OldBuf);
end;

procedure TXMLReader.SkipName;

  procedure RaiseSkipNameNotFound;
  begin
    RaiseExc('Expected letter, "_" or ":" for name, found "' + buf[0] + '"');
  end;

begin
  if not (buf[0] in (Letter + ['_', ':'])) then
    RaiseSkipNameNotFound;

  Inc(buf);
  SkipString(Letter + ['0'..'9', '.', '-', '_', ':']);
end;

procedure TXMLReader.ExpectAttValue(attr: TDOMAttr);    // [10]
var
  OldBuf: PChar;

  procedure FlushStringBuffer;
  var
    s: String;
  begin
    if OldBuf<>buf then begin
      s := GetString(OldBuf,buf-OldBuf);
      OldBuf := buf;
      attr.AppendChild(doc.CreateTextNode(s));
      SetLength(s, 0);
    end;
  end;

var
  StrDel: char;
begin
  if (buf[0] <> '''') and (buf[0] <> '"') then
    RaiseExc('Expected quotation marks');
  StrDel:=buf[0];
  Inc(buf);
  OldBuf := buf;
  while (buf[0]<>StrDel) and (buf[0]<>#0) do begin
    if buf[0] <> '&' then begin
      Inc(buf);
    end else
    begin
      if OldBuf<>buf then FlushStringBuffer;
      ParseReference(attr);
      OldBuf := buf;
    end;
  end;
  if OldBuf<>buf then FlushStringBuffer;
  inc(buf);
  ResolveEntities(Attr);
end;

function TXMLReader.ExpectPubidLiteral: String;
begin
  SetLength(Result, 0);
  if CheckForChar('''') then begin
    SkipString(PubidChars - ['''']);
    ExpectString('''');
  end else if CheckForChar('"') then begin
    SkipString(PubidChars - ['"']);
    ExpectString('"');
  end else
    RaiseExc('Expected quotation marks');
end;

procedure TXMLReader.SkipPubidLiteral;
begin
  if CheckForChar('''') then begin
    SkipString(PubidChars - ['''']);
    ExpectString('''');
  end else if CheckForChar('"') then begin
    SkipString(PubidChars - ['"']);
    ExpectString('"');
  end else
    RaiseExc('Expected quotation marks');
end;

function TXMLReader.ParseComment(AOwner: TDOMNode): Boolean;    // [15]
var
  comment: String;
  OldBuf: PChar;
begin
  if CheckFor('<!--') then begin
    OldBuf := buf;
    while (buf[0] <> #0) and (buf[1] <> #0) and
      ((buf[0] <> '-') or (buf[1] <> '-')) do begin
      Inc(buf);
    end;
    comment:=GetString(OldBuf,buf-OldBuf);
    AOwner.AppendChild(doc.CreateComment(comment));
    ExpectString('-->');
    Result := True;
  end else
    Result := False;
end;

function TXMLReader.ParsePI: Boolean;    // [16]
begin
  if CheckFor('<?') then begin
    if CompareLIPChar(buf,'XML',3) then
      RaiseExc('"<?xml" processing instruction not allowed here');
    SkipName;
    if SkipWhitespace then
      while (buf[0] <> #0) and (buf[1] <> #0) and not
        ((buf[0] = '?') and (buf[1] = '>')) do Inc(buf);
    ExpectString('?>');
    Result := True;
  end else
    Result := False;
end;

procedure TXMLReader.ExpectProlog;    // [22]

  procedure ParseVersionNum;
  begin
    doc.XMLVersion :=
      GetString(['a'..'z', 'A'..'Z', '0'..'9', '_', '.', ':', '-']);
  end;

  procedure ParseDoctypeDecls;
  begin
    repeat
      SkipWhitespace;
    until not (ParseMarkupDecl or ParsePEReference);
    ExpectString(']');
  end;


var
  DocType: TXMLReaderDocumentType;

begin
  if CheckFor('<?xml') then
  begin
    // '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'

    // VersionInfo: S 'version' Eq (' VersionNum ' | " VersionNum ")
    SkipWhitespace;
    ExpectString('version');
    ParseEq;
    if buf[0] = '''' then
    begin
      Inc(buf);
      ParseVersionNum;
      ExpectString('''');
    end else if buf[0] = '"' then
    begin
      Inc(buf);
      ParseVersionNum;
      ExpectString('"');
    end else
      RaiseExc('Expected single or double quotation mark');

    // EncodingDecl?
    SkipEncodingDecl;

    // SDDecl?
    SkipWhitespace;
    if CheckFor('standalone') then
    begin
      ExpectEq;
      if buf[0] = '''' then
      begin
        Inc(buf);
        if not (CheckFor('yes''') or CheckFor('no''')) then
          RaiseExc('Expected ''yes'' or ''no''');
      end else if buf[0] = '''' then
      begin
        Inc(buf);
        if not (CheckFor('yes"') or CheckFor('no"')) then
          RaiseExc('Expected "yes" or "no"');
      end;
      SkipWhitespace;
    end;

    ExpectString('?>');
  end;

  // Check for "Misc*"
  ParseMisc(doc);

  // Check for "(doctypedecl Misc*)?"    [28]
  if CheckFor('<!DOCTYPE') then
  begin
    DocType := TXMLReaderDocumentType.Create(doc);
    doc.SetDocType(DocType);
    SkipWhitespace;
    DocType.Name := ExpectName;
    SkipWhitespace;
    if CheckForChar('[') then
    begin
      ParseDoctypeDecls;
      SkipWhitespace;
      ExpectString('>');
    end else if not CheckForChar('>') then
    begin
      ParseExternalID;
      SkipWhitespace;
      if CheckForChar('[') then
      begin
        ParseDoctypeDecls;
        SkipWhitespace;
      end;
      ExpectString('>');
    end;
    ParseMisc(doc);
  end;
end;

function TXMLReader.ParseEq: Boolean;    // [25]
var
  savedbuf: PChar;
begin
  savedbuf := buf;
  SkipWhitespace;
  if buf[0] = '=' then begin
    Inc(buf);
    SkipWhitespace;
    Result := True;
  end else begin
    buf := savedbuf;
    Result := False;
  end;
end;

procedure TXMLReader.ExpectEq;
begin
  if not ParseEq then
    RaiseExc('Expected "="');
end;


// Parse "Misc*":
//   Misc ::= Comment | PI | S

procedure TXMLReader.ParseMisc(AOwner: TDOMNode);    // [27]
begin
  repeat
    SkipWhitespace;
  until not (ParseComment(AOwner) or ParsePI);
end;

function TXMLReader.ParseMarkupDecl: Boolean;    // [29]

  function ParseElementDecl: Boolean;    // [45]

    procedure ExpectChoiceOrSeq;    // [49], [50]

      procedure ExpectCP;    // [48]
      begin
        if CheckForChar('(') then
          ExpectChoiceOrSeq
        else
          SkipName;
        if CheckForChar('?') then
        else if CheckForChar('*') then
        else if CheckForChar('+') then;
      end;

    var
      delimiter: Char;
    begin
      SkipWhitespace;
      ExpectCP;
      SkipWhitespace;
      delimiter := #0;
      while not CheckForChar(')') do begin
        if delimiter = #0 then begin
          if (buf[0] = '|') or (buf[0] = ',') then
            delimiter := buf[0]
          else
            RaiseExc('Expected "|" or ","');
          Inc(buf);
        end else
          ExpectString(delimiter);
        SkipWhitespace;
        ExpectCP;
      end;
    end;

  begin
    if CheckFor('<!ELEMENT') then begin
      ExpectWhitespace;
      SkipName;
      ExpectWhitespace;

      // Get contentspec [46]

      if CheckFor('EMPTY') then
      else if CheckFor('ANY') then
      else if CheckForChar('(') then begin
        SkipWhitespace;
        if CheckFor('#PCDATA') then begin
          // Parse Mixed section [51]
          SkipWhitespace;
          if not CheckForChar(')') then
            repeat
              ExpectString('|');
              SkipWhitespace;
              SkipName;
            until CheckFor(')*');
        end else begin
          // Parse Children section [47]

          ExpectChoiceOrSeq;

          if CheckForChar('?') then
          else if CheckForChar('*') then
          else if CheckForChar('+') then;
        end;
      end else
        RaiseExc('Invalid content specification');

      SkipWhitespace;
      ExpectString('>');
      Result := True;
    end else
      Result := False;
  end;

  function ParseAttlistDecl: Boolean;    // [52]
  var
    attr: TDOMAttr;
  begin
    if CheckFor('<!ATTLIST') then begin
      ExpectWhitespace;
      SkipName;
      SkipWhitespace;
      while not CheckForChar('>') do begin
        SkipName;
        ExpectWhitespace;

        // Get AttType [54], [55], [56]
        if CheckFor('CDATA') then
        else if CheckFor('ID') then
        else if CheckFor('IDREF') then
        else if CheckFor('IDREFS') then
        else if CheckFor('ENTITTY') then
        else if CheckFor('ENTITIES') then
        else if CheckFor('NMTOKEN') then
        else if CheckFor('NMTOKENS') then
        else if CheckFor('NOTATION') then begin   // [57], [58]
          ExpectWhitespace;
          ExpectString('(');
          SkipWhitespace;
          SkipName;
          SkipWhitespace;
          while not CheckForChar(')') do begin
            ExpectString('|');
            SkipWhitespace;
            SkipName;
            SkipWhitespace;
          end;
        end else if CheckForChar('(') then begin    // [59]
          SkipWhitespace;
          SkipString(Nmtoken);
          SkipWhitespace;
          while not CheckForChar(')') do begin
            ExpectString('|');
            SkipWhitespace;
            SkipString(Nmtoken);
            SkipWhitespace;
          end;
        end else
          RaiseExc('Invalid tokenized type');

        ExpectWhitespace;

        // Get DefaultDecl [60]
        if CheckFor('#REQUIRED') then
        else if CheckFor('#IMPLIED') then
        else begin
          if CheckFor('#FIXED') then
            SkipWhitespace;
          attr := doc.CreateAttribute('');
          ExpectAttValue(attr);
        end;

        SkipWhitespace;
      end;
      Result := True;
    end else
      Result := False;
  end;

  function ParseEntityDecl: Boolean;    // [70]
  var
    NewEntity: TDOMEntity;

    function ParseEntityValue: Boolean;    // [9]
    var
      strdel: Char;
    begin
      if (buf[0] <> '''') and (buf[0] <> '"') then begin
        Result := False;
        exit;
      end;
      strdel := buf[0];
      Inc(buf);
      while not CheckForChar(strdel) do
        if ParsePEReference then
        else if ParseReference(NewEntity) then
        else begin
          Inc(buf);             // Normal haracter
        end;
      Result := True;
    end;

  begin
    if CheckFor('<!ENTITY') then begin
      ExpectWhitespace;
      if CheckForChar('%') then begin    // [72]
        ExpectWhitespace;
        NewEntity := doc.CreateEntity(ExpectName);
        ExpectWhitespace;
        // Get PEDef [74]
        if ParseEntityValue then
        else if ParseExternalID then
        else
          RaiseExc('Expected entity value or external ID');
      end else begin    // [71]
        NewEntity := doc.CreateEntity(ExpectName);
        ExpectWhitespace;
        // Get EntityDef [73]
        if ParseEntityValue then
        else begin
          ExpectExternalID;
          // Get NDataDecl [76]
          ExpectWhitespace;
          ExpectString('NDATA');
          ExpectWhitespace;
          SkipName;
        end;
      end;
      SkipWhitespace;
      ExpectString('>');
      Result := True;
    end else
      Result := False;
  end;

  function ParseNotationDecl: Boolean;    // [82]
  begin
    if CheckFor('<!NOTATION') then begin
      ExpectWhitespace;
      SkipName;
      ExpectWhitespace;
      if ParseExternalID then
      else if CheckFor('PUBLIC') then begin    // [83]
        ExpectWhitespace;
        SkipPubidLiteral;
      end else
        RaiseExc('Expected external or public ID');
      SkipWhitespace;
      ExpectString('>');
      Result := True;
    end else
      Result := False;
  end;

begin
  Result := False;
  while ParseElementDecl or ParseAttlistDecl or ParseEntityDecl or
    ParseNotationDecl or ParsePI or ParseComment(doc) or SkipWhitespace do
    Result := True;
end;

procedure TXMLReader.ProcessDTD(ABuf: PChar; const AFilename: String);
begin
  buf := ABuf;
  BufStart := ABuf;
  Filename := AFilename;

  doc := TXMLReaderDocument.Create;
  ParseMarkupDecl;

  {
  if buf[0] <> #0 then begin
    DebugLn('=== Unparsed: ===');
    //DebugLn(buf);
    DebugLn(StrLen(buf), ' chars');
  end;
  }
end;

function TXMLReader.ParseElement(AOwner: TDOMNode): Boolean;    // [39] [40] [44]
var
  NewElem: TDOMElement;

  procedure CreateTextNode(BufStart: PChar; BufLen: integer);
  // Note: this proc exists, to reduce creating temporary strings
  begin
    NewElem.AppendChild(doc.CreateTextNode(GetString(BufStart,BufLen)));
  end;

  function ParseCharData: Boolean;    // [14]
  var
    p: PChar;
    DataLen: integer;
    OldBuf: PChar;
  begin
    OldBuf := buf;
    while not (buf[0] in [#0, '<', '&']) do
    begin
      Inc(buf);
    end;
    DataLen:=buf-OldBuf;
    if DataLen > 0 then
    begin
      // Check if chardata has non-whitespace content
      p:=OldBuf;
      while (p<buf) and (p[0] in WhitespaceChars) do
        inc(p);
      if p<buf then
        CreateTextNode(OldBuf,DataLen);
      Result := True;
    end else
      Result := False;
  end;

  procedure CreateCDATASectionChild(BufStart: PChar; BufLen: integer);
  // Note: this proc exists, to reduce creating temporary strings
  begin
    NewElem.AppendChild(doc.CreateCDATASection(GetString(BufStart,BufLen)));
  end;

  function ParseCDSect: Boolean;    // [18]
  var
    OldBuf: PChar;
  begin
    if CheckFor('<![CDATA[') then
    begin
      OldBuf := buf;
      while not CheckFor(']]>') do
      begin
        Inc(buf);
      end;
      CreateCDATASectionChild(OldBuf,buf-OldBuf);
      Result := True;
    end else
      Result := False;
  end;

  procedure CreateNameElement;
  var
    IsEmpty: Boolean;
    attr: TDOMAttr;
    name: string;
  begin
    {$IFDEF MEM_CHECK}CheckHeapWrtMemCnt('  CreateNameElement A');{$ENDIF}
    GetName(name);
    NewElem := doc.CreateElement(name);
    AOwner.AppendChild(NewElem);

    SkipWhitespace;
    IsEmpty := False;
    while True do
    begin
      {$IFDEF MEM_CHECK}CheckHeapWrtMemCnt('  CreateNameElement E');{$ENDIF}
      if CheckFor('/>') then
      begin
        IsEmpty := True;
        break;
      end;
      if CheckForChar('>') then
        break;

      // Get Attribute [41]
      attr := doc.CreateAttribute(ExpectName);
      NewElem.Attributes.SetNamedItem(attr);
      ExpectEq;
      ExpectAttValue(attr);

      SkipWhitespace;
    end;

    if not IsEmpty then
    begin
      // Get content
      SkipWhitespace;
      while ParseCharData or ParseCDSect or ParsePI or
        ParseComment(NewElem) or ParseElement(NewElem) or
        ParseReference(NewElem) do;

      // Get ETag [42]
      ExpectString('</');
      if ExpectName <> name then
        RaiseExc('Unmatching element end tag (expected "</' + name + '>")');
      SkipWhitespace;
      ExpectString('>');
    end;

    {$IFDEF MEM_CHECK}CheckHeapWrtMemCnt('  CreateNameElement END');{$ENDIF}
    ResolveEntities(NewElem);
  end;

var
  OldBuf: PChar;
begin
  OldBuf := Buf;
  if CheckForChar('<') then
  begin
    {$IFDEF MEM_CHECK}CheckHeapWrtMemCnt('TXMLReader.ParseElement A');{$ENDIF}
    if not CheckName then
    begin
      Buf := OldBuf;
      Result := False;
    end else begin
      CreateNameElement;
      Result := True;
    end;
  end else
    Result := False;
  {$IFDEF MEM_CHECK}CheckHeapWrtMemCnt('TXMLReader.ParseElement END');{$ENDIF}
end;

procedure TXMLReader.ExpectElement(AOwner: TDOMNode);
begin
  if not ParseElement(AOwner) then
    RaiseExc('Expected element');
end;

function TXMLReader.ParsePEReference: Boolean;    // [69]
begin
  if CheckForChar('%') then begin
    SkipName;
    ExpectString(';');
    Result := True;
  end else
    Result := False;
end;

function TXMLReader.ParseReference(AOwner: TDOMNode): Boolean;    // [67] [68]
begin
  if not CheckForChar('&') then begin
    Result := False;
    exit;
  end;
  if CheckForChar('#') then begin    // Test for CharRef [66]
    if CheckForChar('x') then begin
      // !!!: there must be at least one digit
      while buf[0] in ['0'..'9', 'a'..'f', 'A'..'F'] do Inc(buf);
    end else
      // !!!: there must be at least one digit
      while buf[0] in ['0'..'9'] do Inc(buf);
  end else
    AOwner.AppendChild(doc.CreateEntityReference(ExpectName));
  ExpectString(';');
  Result := True;
end;

procedure TXMLReader.ExpectReference(AOwner: TDOMNode);
begin
  if not ParseReference(AOwner) then
    RaiseExc('Expected reference ("&Name;" or "%Name;")');
end;


function TXMLReader.ParseExternalID: Boolean;    // [75]

  function GetSystemLiteral: String;
  var
    OldBuf: PChar;
  begin
    if buf[0] = '''' then begin
      Inc(buf);
      OldBuf := buf;
      while (buf[0] <> '''') and (buf[0] <> #0) do begin
        Inc(buf);
      end;
      Result := GetString(OldBuf,buf-OldBuf);
      ExpectString('''');
    end else if buf[0] = '"' then begin
      Inc(buf);
      OldBuf := buf;
      while (buf[0] <> '"') and (buf[0] <> #0) do begin
        Inc(buf);
      end;
      Result := GetString(OldBuf,buf-OldBuf);
      ExpectString('"');
    end else
      Result:='';
  end;

  procedure SkipSystemLiteral;
  begin
    if buf[0] = '''' then begin
      Inc(buf);
      while (buf[0] <> '''') and (buf[0] <> #0) do begin
        Inc(buf);
      end;
      ExpectString('''');
    end else if buf[0] = '"' then begin
      Inc(buf);
      while (buf[0] <> '"') and (buf[0] <> #0) do begin
        Inc(buf);
      end;
      ExpectString('"');
    end;
  end;

begin
  if CheckFor('SYSTEM') then begin
    ExpectWhitespace;
    SkipSystemLiteral;
    Result := True;
  end else if CheckFor('PUBLIC') then begin
    ExpectWhitespace;
    SkipPubidLiteral;
    ExpectWhitespace;
    SkipSystemLiteral;
    Result := True;
  end else
    Result := False;
end;

procedure TXMLReader.ExpectExternalID;
begin
  if not ParseExternalID then
    RaiseExc('Expected external ID');
end;

function TXMLReader.ParseEncodingDecl: String;    // [80]

  function ParseEncName: String;
  var OldBuf: PChar;
  begin
    if not (buf[0] in ['A'..'Z', 'a'..'z']) then
      RaiseExc('Expected character (A-Z, a-z)');
    OldBuf := buf;
    Inc(buf);
    SkipString(['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-']);
    Result := GetString(OldBuf,buf-OldBuf);
  end;

begin
  SetLength(Result, 0);
  SkipWhitespace;
  if CheckFor('encoding') then begin
    ExpectEq;
    if buf[0] = '''' then begin
      Inc(buf);
      Result := ParseEncName;
      ExpectString('''');
    end else if buf[0] = '"' then begin
      Inc(buf);
      Result := ParseEncName;
      ExpectString('"');
    end;
  end;
end;

procedure TXMLReader.SkipEncodingDecl;

  procedure ParseEncName;
  begin
    if not (buf[0] in ['A'..'Z', 'a'..'z']) then
      RaiseExc('Expected character (A-Z, a-z)');
    Inc(buf);
    SkipString(['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-']);
  end;

begin
  SkipWhitespace;
  if CheckFor('encoding') then begin
    ExpectEq;
    if buf[0] = '''' then begin
      Inc(buf);
      ParseEncName;
      ExpectString('''');
    end else if buf[0] = '"' then begin
      Inc(buf);
      ParseEncName;
      ExpectString('"');
    end;
  end;
end;


{ Currently, this method will only resolve the entities which are
  predefined in XML: }

procedure TXMLReader.ResolveEntities(RootNode: TDOMNode);

  procedure ReplaceEntityRef(EntityNode: TDOMNode; const Replacement: String);
  var
    PrevSibling, NextSibling: TDOMNode;
  begin
    PrevSibling := EntityNode.PreviousSibling;
    NextSibling := EntityNode.NextSibling;
    if Assigned(PrevSibling) and (PrevSibling.NodeType = TEXT_NODE) then
    begin
      TDOMCharacterData(PrevSibling).AppendData(Replacement);
      RootNode.RemoveChild(EntityNode);
      if Assigned(NextSibling) and (NextSibling.NodeType = TEXT_NODE) then
      begin
        TDOMCharacterData(PrevSibling).AppendData(
        TDOMCharacterData(NextSibling).Data);
        RootNode.RemoveChild(NextSibling);
      end
    end else
      if Assigned(NextSibling) and (NextSibling.NodeType = TEXT_NODE) then
      begin
        TDOMCharacterData(NextSibling).InsertData(0, Replacement);
        RootNode.RemoveChild(EntityNode);
      end else
        RootNode.ReplaceChild(Doc.CreateTextNode(Replacement), EntityNode);
  end;

var
  Node, NextSibling: TDOMNode;
begin
  Node := RootNode.FirstChild;
  while Assigned(Node) do
  begin
    NextSibling := Node.NextSibling;
    if Node.NodeType = ENTITY_REFERENCE_NODE then
      if Node.NodeName = 'amp' then
        ReplaceEntityRef(Node, '&')
      else if Node.NodeName = 'apos' then
        ReplaceEntityRef(Node, '''')
      else if Node.NodeName = 'gt' then
        ReplaceEntityRef(Node, '>')
      else if Node.NodeName = 'lt' then
        ReplaceEntityRef(Node, '<')
      else if Node.NodeName = 'quot' then
        ReplaceEntityRef(Node, '"');
    Node := NextSibling;
  end;
end;



procedure ReadXMLFile(var ADoc: TXMLDocument; var f: File);
var
  reader: TXMLReader;
  buf: PChar;
  BufSize: LongInt;
begin
  ADoc := nil;
  BufSize := FileSize(f) + 1;
  if BufSize <= 1 then exit;

  GetMem(buf, BufSize);
  BlockRead(f, buf^, BufSize - 1);
  buf[BufSize - 1] := #0;
  reader := TXMLReader.Create;
  reader.ProcessXML(buf, Filerec(f).name);
  FreeMem(buf, BufSize);
  ADoc := reader.doc;
  reader.Free;
end;

procedure ReadXMLFile(var ADoc: TXMLDocument; var f: TStream;
  const AFilename: String);
var
  reader: TXMLReader;
  buf: PChar;
begin
  ADoc := nil;
  if f.Size = 0 then exit;

  GetMem(buf, f.Size + 1);
  f.Read(buf^, TFPCMemStreamSeekType(f.Size));
  buf[f.Size] := #0;
  
  reader := TXMLReader.Create;
  try
    reader.ProcessXML(buf, AFilename);
  finally
    FreeMem(buf, f.Size + 1);
    ADoc := reader.doc;
    reader.Free;
  end;
end;

procedure ReadXMLFile(var ADoc: TXMLDocument; var f: TStream);
begin
  ReadXMLFile(ADoc, f, '<Stream>');
end;

procedure ReadXMLFile(var ADoc: TXMLDocument; const AFilename: String);
var
  FileStream: TFileStream;
  MemStream: TMemoryStream;
begin
  ADoc := nil;
  FileStream := TFileStream.Create(AFilename, fmOpenRead);
  if FileStream=nil then exit;
  MemStream := TMemoryStream.Create;
  try
    try
      MemStream.LoadFromStream(FileStream);
    except
      on E: Exception do begin
        DebugLn('ERROR reading file "',AFilename,'": ',E.Message);
        exit;
      end;
    end;
    ReadXMLFile(ADoc, MemStream, AFilename);
  finally
    FileStream.Free;
    MemStream.Free;
  end;
end;


procedure ReadDTDFile(var ADoc: TXMLDocument; var f: File);
var
  reader: TXMLReader;
  buf: PChar;
  BufSize: LongInt;
begin
  ADoc := nil;
  BufSize := FileSize(f) + 1;
  if BufSize <= 1 then exit;

  GetMem(buf, BufSize + 1);
  BlockRead(f, buf^, BufSize - 1);
  buf[BufSize - 1] := #0;
  reader := TXMLReader.Create;
  reader.ProcessDTD(buf, Filerec(f).name);
  FreeMem(buf, BufSize);
  ADoc := reader.doc;
  reader.Free;
end;

procedure ReadDTDFile(var ADoc: TXMLDocument; var f: TStream;
  const AFilename: String);
var
  reader: TXMLReader;
  buf: PChar;
begin
  ADoc := nil;
  if f.Size = 0 then exit;

  GetMem(buf, f.Size + 1);
  f.Read(buf^, TFPCMemStreamSeekType(f.Size));
  buf[f.Size] := #0;
  reader := TXMLReader.Create;
  reader.ProcessDTD(buf, AFilename);
  FreeMem(buf, f.Size + 1);
  ADoc := reader.doc;
  reader.Free;
end;

procedure ReadDTDFile(var ADoc: TXMLDocument; var f: TStream);
begin
  ReadDTDFile(ADoc, f, '<Stream>');
end;

procedure ReadDTDFile(var ADoc: TXMLDocument; const AFilename: String);
var
  stream: TFileStream;
begin
  ADoc := nil;
  stream := TFileStream.Create(AFilename, fmOpenRead);
  try
    ReadDTDFile(ADoc, stream, AFilename);
  finally
    stream.Free;
  end;
end;


end.


{
  $Log$
  Revision 1.14  2004/12/17 14:41:41  vincents
  fixed memleak after parsing error.

  Revision 1.13  2004/10/28 09:38:16  mattias
  fixed COPYING.modifiedLGPL links

  Revision 1.12  2004/05/22 14:35:32  mattias
  fixed button return key

  Revision 1.11  2003/12/25 14:17:06  mattias
  fixed many range check warnings

  Revision 1.10  2003/12/19 09:06:07  mattias
  replaced StrLComp by CompareLPChar

  Revision 1.9  2003/12/18 23:47:03  mattias
  added classes incpath

  Revision 1.8  2002/12/16 12:12:50  mattias
  fixes for fpc 1.1

  Revision 1.7  2002/10/22 08:48:04  lazarus
  MG: fixed segfault on loading xmlfile

  Revision 1.6  2002/10/05 14:03:58  lazarus
  MG: accelerated calculating guidelines

  Revision 1.5  2002/10/01 08:27:35  lazarus
  MG: fixed parsing textnodes

  Revision 1.4  2002/09/13 16:58:27  lazarus
  MG: removed the 1x1 bitmap from TBitBtn

  Revision 1.3  2002/08/04 07:44:44  lazarus
  MG: fixed xml reading writing of special chars

  Revision 1.2  2002/07/30 14:36:28  lazarus
  MG: accelerated xmlread and xmlwrite

  Revision 1.1  2002/07/30 06:24:06  lazarus
  MG: added a faster version of TXMLConfig

  Revision 1.5  2000/10/14 09:41:45  sg
  * Fixed typo in previous fix. (forgot closing bracket. Oops.)

  Revision 1.4  2000/10/14 09:40:44  sg
  * Extended the "Unmatching element end tag" exception, now the expected
    tag name is included in the message string.

  Revision 1.3  2000/07/29 14:52:25  sg
  * Modified the copyright notice to remove ambiguities

  Revision 1.2  2000/07/13 11:33:07  michael
  + removed logs
 
}
