{
Reads an SVG Document

License: The same modified LGPL as the Free Pascal RTL
         See the file COPYING.modifiedLGPL for more details

AUTHORS: Felipe Monteiro de Carvalho
}
unit svgvectorialreader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, math,
  fpimage, fpcanvas, xmlread, dom, fgl,
  fpvectorial, fpvutils;

type
  TSVGTokenType = (sttMoveTo, sttLineTo, sttBezierTo, sttFloatValue);

  TSVGToken = class
    TokenType: TSVGTokenType;
    Value: Float;
  end;

  TSVGTokenList = specialize TFPGList<TSVGToken>;

  { TSVGPathTokenizer }

  TSVGPathTokenizer = class
  public
    FPointSeparator, FCommaSeparator: TFormatSettings;
    Tokens: TSVGTokenList;
    constructor Create;
    Destructor Destroy; override;
    procedure AddToken(AStr: string);
    procedure TokenizePathString(AStr: string);
  end;

  { TvSVGVectorialReader }

  TvSVGVectorialReader = class(TvCustomVectorialReader)
  private
    FPointSeparator, FCommaSeparator: TFormatSettings;
    FSVGPathTokenizer: TSVGPathTokenizer;
    function ReadSVGColor(AValue: string): TFPColor;
    procedure ReadSVGStyle(AValue: string; ADestEntity: TvEntityWithPen);
    procedure ReadSVGPenStyleWithKeyAndValue(AKey, AValue: string; ADestEntity: TvEntityWithPen);
    procedure ReadSVGBrushStyleWithKeyAndValue(AKey, AValue: string; ADestEntity: TvEntityWithPenAndBrush);
    function IsAttributeFromStyle(AStr: string): Boolean;
    //
    procedure ReadEntityFromNode(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    procedure ReadCircleFromNode(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    procedure ReadEllipseFromNode(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    procedure ReadLineFromNode(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    procedure ReadPathFromNode(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    procedure ReadPathFromString(AStr: string; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    procedure ReadRectFromNode(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    function  StringWithUnitToFloat(AStr: string): Double;
    procedure ConvertSVGCoordinatesToFPVCoordinates(
      const AData: TvVectorialPage;
      const ASrcX, ASrcY: Double; var ADestX, ADestY: Double);
    procedure ConvertSVGDeltaToFPVDelta(
      const AData: TvVectorialPage;
      const ASrcX, ASrcY: Double; var ADestX, ADestY: Double);
  public
    { General reading methods }
    constructor Create; override;
    Destructor Destroy; override;
    procedure ReadFromStream(AStream: TStream; AData: TvVectorialDocument); override;
  end;

implementation

const
  // SVG requires hardcoding a DPI value

  // The Opera Browser and Inkscape use 90 DPI, so we follow that

  // 1 Inch = 25.4 milimiters
  // 90 inches per pixel = (1 / 90) * 25.4 = 0.2822
  // FLOAT_MILIMETERS_PER_PIXEL = 0.3528; // DPI 72 = 1 / 72 inches per pixel

  FLOAT_MILIMETERS_PER_PIXEL = 0.2822; // DPI 90 = 1 / 90 inches per pixel
  FLOAT_PIXELS_PER_MILIMETER = 3.5433; // DPI 90 = 1 / 90 inches per pixel

{ TSVGPathTokenizer }

constructor TSVGPathTokenizer.Create;
begin
  inherited Create;

  FPointSeparator := DefaultFormatSettings;
  FPointSeparator.DecimalSeparator := '.';
  FPointSeparator.ThousandSeparator := '#';// disable the thousand separator

  Tokens := TSVGTokenList.Create;
end;

destructor TSVGPathTokenizer.Destroy;
begin
  Tokens.Free;

  inherited Destroy;
end;

procedure TSVGPathTokenizer.AddToken(AStr: string);
var
  lToken: TSVGToken;
  lStr: string;
begin
  lToken := TSVGToken.Create;

  lStr := LowerCase(AStr);
  if lStr = '' then Exit;

  if lStr[1] = 'm' then lToken.TokenType := sttMoveTo
  else if lStr[1] = 'l' then lToken.TokenType := sttLineTo
  else if lStr[1] = 'c' then lToken.TokenType := sttBezierTo
  else
  begin
    lToken.TokenType := sttFloatValue;
    lToken.Value := StrToFloat(AStr, FPointSeparator);
  end;

  // Sometimes we get a command glued to a value, for example M150
  if (lToken.TokenType <> sttFloatValue) and (Length(lStr) > 1) then
  begin
    Tokens.Add(lToken);
    lToken.TokenType := sttFloatValue;
    lStr := Copy(AStr, 2, Length(AStr));
    lToken.Value := StrToFloat(lStr, FPointSeparator);
  end;

  Tokens.Add(lToken);
end;

procedure TSVGPathTokenizer.TokenizePathString(AStr: string);
const
  Str_Space: Char = ' ';
  Str_Comma: Char = ',';
var
  i: Integer;
  lTmpStr: string = '';
  lState: Integer;
  lCurChar: Char;
begin
  lState := 0;

  i := 1;
  while i <= Length(AStr) do
  begin
    case lState of
    0: // Adding to the tmp string
    begin
      lCurChar := AStr[i];
      if lCurChar = Str_Space then
      begin
        lState := 1;
        AddToken(lTmpStr);
        lTmpStr := '';
      end
      else if lCurChar = Str_Comma then
      begin
        AddToken(lTmpStr);
        lTmpStr := '';
      end
      else
        lTmpStr := lTmpStr + lCurChar;

      Inc(i);
    end;
    1: // Removing spaces
    begin
      if AStr[i] <> Str_Space then lState := 0
      else Inc(i);
    end;
    end;
  end;
end;

{ Example of a supported SVG image:

<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!-- Created with fpVectorial (http://wiki.lazarus.freepascal.org/fpvectorial) -->

<svg
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:cc="http://creativecommons.org/ns#"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:svg="http://www.w3.org/2000/svg"
  xmlns="http://www.w3.org/2000/svg"
  xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
  width="100mm"
  height="100mm"
  id="svg2"
  version="1.1"
  sodipodi:docname="New document 1">
  <g id="layer1">
  <path
    style="fill:none;stroke:#000000;stroke-width:10px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
    d="m 0,283.486888731396 l 106.307583274274,-35.4358610914245 "
  id="path0" />
  <path
    style="fill:none;stroke:#000000;stroke-width:10px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
    d="m 0,354.358610914245 l 354.358610914245,0 l 0,-354.358610914245 l -354.358610914245,0 l 0,354.358610914245 "
  id="path1" />
  <path
    style="fill:none;stroke:#000000;stroke-width:10px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
    d="m 0,354.358610914245 l 35.4358610914245,-35.4358610914245 c 0,-35.4358610914246 35.4358610914245,-35.4358610914246 35.4358610914245,0 l 35.4358610914245,35.4358610914245 "
  id="path2" />
  </g>
</svg>
}

{ TvSVGVectorialReader }

function TvSVGVectorialReader.ReadSVGColor(AValue: string): TFPColor;
begin
  Result := colBlack;
  case AValue of
  'black':   Result := colBlack;
  'navy':    Result.Blue := $8080;
  'darkblue':Result.Blue := $8B8B;
  'mediumblue':Result.Blue := $CDCD;
  'blue':    Result := colBlue;
  'darkgreen':Result.Green := $6464;
  'green':   Result.Green := $8080;
  'teal':
  begin
    Result.Green := $8080;
    Result.Blue := $8080;
  end;
  'darkcyan':
  begin
    Result.Green := $8B8B;
    Result.Blue := $8B8B;
  end;
  'deepskyblue':
  begin
    Result.Green := $BFBF;
    Result.Blue := $FFFF;
  end;
  'darkturquoise':
  begin
    Result.Green := $CECE;
    Result.Blue := $D1D1;
  end;
  'mediumspringgreen':
  begin
    Result.Green := $FAFA;
    Result.Blue := $9A9A;
  end;
  'lime': Result := colGreen;
  'springgreen':
  begin
    Result.Green := $FFFF;
    Result.Blue := $7F7F;
  end;
  'cyan':   Result := colCyan;
  'aqua':   Result := colCyan;
  'midnightblue':
  begin
    Result.Red := $1919;
    Result.Green := $1919;
    Result.Blue := $7070;
  end;
  'dodgerblue':
  begin
    Result.Red := $1E1E;
    Result.Green := $9090;
    Result.Blue := $FFFF;
  end;
  'lightseagreen':
  begin
    Result.Red := $2020;
    Result.Green := $B2B2;
    Result.Blue := $AAAA;
  end;
  'forestgreen':
  begin
    Result.Red := $2222;
    Result.Green := $8B8B;
    Result.Blue := $2222;
  end;
  'seagreen':
  begin
    Result.Red := $2E2E;
    Result.Green := $8B8B;
    Result.Blue := $5757;
  end;
{
darkslategray #2F4F4F
 	darkslategrey #2F4F4F		limegreen #32CD32
mediumseagreen #3CB371
 	turquoise #40E0D0		royalblue #4169E1
steelblue #4682B4
 	darkslateblue #483D8B		mediumturquoise #48D1CC
indigo #4B0082
 	darkolivegreen #556B2F		cadetblue #5F9EA0
cornflowerblue #6495ED
 	mediumaquamarine #66CDAA		dimgrey #696969
dimgray #696969
 	slateblue #6A5ACD		olivedrab #6B8E23
slategrey #708090
 	slategray #708090		lightslategray(Hex3) #778899
lightslategrey(Hex3) #778899
 	mediumslateblue #7B68EE		lawngreen #7CFC00
chartreuse #7FFF00
}
  'aquamarine':
  begin
    Result.Red := $7F7F;
    Result.Green := $FFFF;
    Result.Blue := $D4D4;
  end;
  'maroon': Result.Red := $8080;
  'purple': Result := colPurple;
  'olive':  Result := colOlive;
  'gray', 'grey': Result := colGray;
{
 	skyblue #87CEEB		lightskyblue #87CEFA
blueviolet #8A2BE2
 	darkred #8B0000		darkmagenta #8B008B
saddlebrown #8B4513
 	darkseagreen #8FBC8F		lightgreen #90EE90
mediumpurple #9370DB
 	darkviolet #9400D3		palegreen #98FB98
darkorchid #9932CC
 	yellowgreen #9ACD32		sienna #A0522D
brown #A52A2A
 	darkgray #A9A9A9		darkgrey #A9A9A9
lightblue #ADD8E6
 	greenyellow #ADFF2F		paleturquoise #AFEEEE
lightsteelblue #B0C4DE
 	powderblue #B0E0E6		firebrick #B22222
darkgoldenrod #B8860B
 	mediumorchid #BA55D3		rosybrown #BC8F8F
darkkhaki #BDB76B
 	silver(16) #C0C0C0		mediumvioletred #C71585
indianred #CD5C5C
 	peru #CD853F		chocolate #D2691E
tan #D2B48C
 	lightgray #D3D3D3		lightgrey #D3D3D3
thistle #D8BFD8
 	orchid #DA70D6		goldenrod #DAA520
palevioletred #DB7093
 	crimson #DC143C		gainsboro #DCDCDC
plum #DDA0DD
 	burlywood #DEB887		lightcyan #E0FFFF
lavender #E6E6FA
 	darksalmon #E9967A		violet #EE82EE
palegoldenrod #EEE8AA
 	lightcoral #F08080		khaki #F0E68C
aliceblue #F0F8FF
 	honeydew #F0FFF0		azure #F0FFFF
sandybrown #F4A460
 	wheat #F5DEB3		beige #F5F5DC
whitesmoke #F5F5F5
 	mintcream #F5FFFA		ghostwhite #F8F8FF
salmon #FA8072
 	antiquewhite #FAEBD7		linen #FAF0E6
lightgoldenrodyellow #FAFAD2
 	oldlace #FDF5E6
}
  'red':   Result := colRed;
  'fuchsia':   Result := colFuchsia;
  'magenta':   Result := colMagenta;
{	deeppink #FF1493
orangered #FF4500
 	tomato #FF6347		hotpink #FF69B4
coral #FF7F50
 	darkorange #FF8C00		lightsalmon #FFA07A
orange #FFA500
 	lightpink #FFB6C1		pink #FFC0CB
gold #FFD700
 	peachpuff #FFDAB9		navajowhite #FFDEAD
moccasin #FFE4B5
 	bisque #FFE4C4		mistyrose #FFE4E1
blanchedalmond #FFEBCD
 	papayawhip #FFEFD5		lavenderblush #FFF0F5
seashell #FFF5EE
 	cornsilk #FFF8DC		lemonchiffon #FFFACD
floralwhite #FFFAF0
}
  'snow':
  begin
    Result.Red := $FFFF;
    Result.Green := $FAFA;
    Result.Blue := $FAFA;
  end;
  'yellow': Result := colYellow;
  'lightyellow':
  begin
    Result.Red := $FFFF;
    Result.Green := $FEFE;
  end;
  'ivory':
  begin
    Result.Red := $FFFF;
    Result.Green := $FFFF;
    Result.Blue := $F0F0;
  end;
  'white': Result := colWhite;
  end;
end;

// style="fill:none;stroke:black;stroke-width:3"
procedure TvSVGVectorialReader.ReadSVGStyle(AValue: string;
  ADestEntity: TvEntityWithPen);
var
  lStr, lStyleKeyStr, lStyleValueStr: String;
  lStrings: TStringList;
  i, lPosEqual: Integer;
begin
  if AValue = '' then Exit;

  // Now split using ";" separator
  lStrings := TStringList.Create;
  try
    lStrings.Delimiter := ';';
    lStrings.DelimitedText := AValue;
    for i := 0 to lStrings.Count-1 do
    begin
      lStr := lStrings.Strings[i];
      lPosEqual := Pos(':', lStr);
      lStyleKeyStr := Copy(lStr, 0, lPosEqual-1);
      lStyleValueStr := Copy(lStr, lPosEqual+1, Length(lStr));
      ReadSVGPenStyleWithKeyAndValue(lStyleKeyStr, lStyleValueStr, ADestEntity);
      if ADestEntity is TvEntityWithPenAndBrush then
        ReadSVGBrushStyleWithKeyAndValue(lStyleKeyStr, lStyleValueStr, ADestEntity as TvEntityWithPenAndBrush);
    end;
  finally
    lStrings.Free;
  end;
end;

procedure TvSVGVectorialReader.ReadSVGPenStyleWithKeyAndValue(AKey,
  AValue: string; ADestEntity: TvEntityWithPen);
begin
  if AKey = 'stroke' then
  begin
    if ADestEntity.Pen.Style = psClear then ADestEntity.Pen.Style := psSolid;

    if AValue = 'none'  then ADestEntity.Pen.Style := fpcanvas.psClear
    else ADestEntity.Pen.Color := ReadSVGColor(AValue)
  end
  else if AKey = 'stroke-width' then
    ADestEntity.Pen.Width := StrToInt(AValue);
end;

procedure TvSVGVectorialReader.ReadSVGBrushStyleWithKeyAndValue(AKey,
  AValue: string; ADestEntity: TvEntityWithPenAndBrush);
begin
  if AKey = 'fill' then
  begin
    if AValue = 'none'  then ADestEntity.Brush.Style := fpcanvas.bsClear
    else ADestEntity.Brush.Color := ReadSVGColor(AValue)
  end;
end;

function TvSVGVectorialReader.IsAttributeFromStyle(AStr: string): Boolean;
begin
  Result := (AStr = 'stroke') or (AStr = 'stroke-width') or
    (AStr = 'fill');
end;

procedure TvSVGVectorialReader.ReadEntityFromNode(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  lEntityName, lLayerName: DOMString;
  lCurNode, lLayerNameNode: TDOMNode;
  lLayer: TvLayer;
begin
  lEntityName := ANode.NodeName;
  case lEntityName of
    'circle': ReadCircleFromNode(ANode, AData, ADoc);
    'ellipse': ReadEllipseFromNode(ANode, AData, ADoc);
    'line': ReadLineFromNode(ANode, AData, ADoc);
    'path': ReadPathFromNode(ANode, AData, ADoc);
    'rect': ReadRectFromNode(ANode, AData, ADoc);
    // Layers
    'g':
    begin
      // if we are already inside a layer, something may be wrong...
      //if ALayer <> nil then raise Exception.Create('[TvSVGVectorialReader.ReadEntityFromNode] A layer inside a layer was found!');

      lLayerNameNode := ANode.Attributes.GetNamedItem('id');
      lLayerName := '';
      if lLayerNameNode <> nil then lLayerName := lLayerNameNode.NodeValue;
      lLayer := AData.AddLayerAndSetAsCurrent(lLayerName);

      lCurNode := ANode.FirstChild;
      while Assigned(lCurNode) do
      begin
        ReadEntityFromNode(lCurNode, AData, ADoc);
        lCurNode := lCurNode.NextSibling;
      end;
    end;
  end;
end;

procedure TvSVGVectorialReader.ReadCircleFromNode(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  cx, cy, cr, dtmp: double;
  lCircle: TvCircle;
  i: Integer;
  lNodeName: DOMString;
begin
  cx := 0.0;
  cy := 0.0;
  cr := 0.0;

  lCircle := TvCircle.Create;
  // SVG entities start without any pen drawing, but with a black brush
  lCircle.Pen.Style := psClear;
  lCircle.Brush.Style := bsSolid;
  lCircle.Brush.Color := colBlack;

  // read the attributes
  for i := 0 to ANode.Attributes.Length - 1 do
  begin
    lNodeName := ANode.Attributes.Item[i].NodeName;
    if  lNodeName = 'cx' then
      cx := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'cy' then
      cy := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'r' then
      cr := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'style' then
      ReadSVGStyle(ANode.Attributes.Item[i].NodeValue, lCircle)
    else if IsAttributeFromStyle(lNodeName) then
    begin
      ReadSVGPenStyleWithKeyAndValue(lNodeName, ANode.Attributes.Item[i].NodeValue, lCircle);
      ReadSVGBrushStyleWithKeyAndValue(lNodeName, ANode.Attributes.Item[i].NodeValue, lCircle);
    end;
  end;

  ConvertSVGDeltaToFPVDelta(
        AData, cx, cy, lCircle.X, lCircle.Y);
  ConvertSVGDeltaToFPVDelta(
        AData, cr, 0, lCircle.Radius, dtmp);

  AData.AddEntity(lCircle);
end;

procedure TvSVGVectorialReader.ReadEllipseFromNode(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  cx, cy, crx, cry: double;
  lEllipse: TvEllipse;
  i: Integer;
  lNodeName: DOMString;
begin
  cx := 0.0;
  cy := 0.0;
  crx := 0.0;
  cry := 0.0;

  lEllipse := TvEllipse.Create;
  // SVG entities start without any pen drawing, but with a black brush
  lEllipse.Pen.Style := psClear;
  lEllipse.Brush.Style := bsSolid;
  lEllipse.Brush.Color := colBlack;

  // read the attributes
  for i := 0 to ANode.Attributes.Length - 1 do
  begin
    lNodeName := ANode.Attributes.Item[i].NodeName;
    if  lNodeName = 'cx' then
      cx := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'cy' then
      cy := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'rx' then
      crx := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'ry' then
      cry := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'style' then
      ReadSVGStyle(ANode.Attributes.Item[i].NodeValue, lEllipse)
    else if IsAttributeFromStyle(lNodeName) then
    begin
      ReadSVGPenStyleWithKeyAndValue(lNodeName, ANode.Attributes.Item[i].NodeValue, lEllipse);
      ReadSVGBrushStyleWithKeyAndValue(lNodeName, ANode.Attributes.Item[i].NodeValue, lEllipse);
    end;
  end;

  ConvertSVGDeltaToFPVDelta(
        AData, cx, cy, lEllipse.X, lEllipse.Y);
  ConvertSVGDeltaToFPVDelta(
        AData, crx, cry, lEllipse.HorzHalfAxis, lEllipse.VertHalfAxis);

  AData.AddEntity(lEllipse);
end;

procedure TvSVGVectorialReader.ReadLineFromNode(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  x1, y1, x2, y2: double;
  vx1, vy1, vx2, vy2: double;
  i: Integer;
  lNodeName: DOMString;
begin
  x1 := 0.0;
  y1 := 0.0;
  x2 := 0.0;
  y2 := 0.0;

  // read the attributes
  for i := 0 to ANode.Attributes.Length - 1 do
  begin
    lNodeName := ANode.Attributes.Item[i].NodeName;
    if  lNodeName = 'x1' then
      x1 := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'y1' then
      y1 := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'x2' then
      x2 := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'y2' then
      y2 := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue);{
    else if lNodeName = 'style' then
      ReadSVGStyle(ANode.Attributes.Item[i].NodeValue, lEllipse)
    else if IsAttributeFromStyle(lNodeName) then
    begin
      ReadSVGPenStyleWithKeyAndValue(lNodeName, ANode.Attributes.Item[i].NodeValue, lEllipse);
      ReadSVGBrushStyleWithKeyAndValue(lNodeName, ANode.Attributes.Item[i].NodeValue, lEllipse);
    end;}
  end;

  ConvertSVGCoordinatesToFPVCoordinates(
        AData, x1, y1, vx1, vy1);
  ConvertSVGCoordinatesToFPVCoordinates(
        AData, x2, y2, vx2, vy2);

  AData.StartPath();
  AData.AddMoveToPath(vx1, vy1);
  AData.AddLineToPath(vx2, vy2);
  AData.EndPath();
end;

procedure TvSVGVectorialReader.ReadPathFromNode(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  lNodeName, lStyleStr, lDStr: WideString;
  i: Integer;
  lTmpPen: TvEntityWithPen;
begin
  for i := 0 to ANode.Attributes.Length - 1 do
  begin
    lNodeName := ANode.Attributes.Item[i].NodeName;
    if  lNodeName = 'style' then
      lStyleStr := ANode.Attributes.Item[i].NodeValue
    else if lNodeName = 'd' then
      lDStr := ANode.Attributes.Item[i].NodeValue
  end;

  AData.StartPath();
  ReadPathFromString(UTF8Encode(lDStr), AData, ADoc);
  // Add the pen
  lTmpPen := TvEntityWithPen.Create;
  ReadSVGStyle(lStyleStr, lTmpPen);
  AData.SetPenColor(lTmpPen.Pen.Color);
  AData.SetPenStyle(lTmpPen.Pen.Style);
  AData.SetPenWidth(lTmpPen.Pen.Width);
  lTmpPen.Free;
  //
  AData.EndPath();
end;

procedure TvSVGVectorialReader.ReadPathFromString(AStr: string;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  i: Integer;
  X, Y, X2, Y2, X3, Y3: Double;
  CurX, CurY: Double;
begin
  FSVGPathTokenizer.Tokens.Clear;
  FSVGPathTokenizer.TokenizePathString(AStr);
  CurX := 0;
  CurY := 0;

  i := 0;
  while i < FSVGPathTokenizer.Tokens.Count do
  begin
    if FSVGPathTokenizer.Tokens.Items[i].TokenType = sttMoveTo then
    begin
      CurX := FSVGPathTokenizer.Tokens.Items[i+1].Value;
      CurY := FSVGPathTokenizer.Tokens.Items[i+2].Value;
      ConvertSVGCoordinatesToFPVCoordinates(AData, CurX, CurY, CurX, CurY);

      AData.AddMoveToPath(CurX, CurY);

      Inc(i, 3);
    end
    else if FSVGPathTokenizer.Tokens.Items[i].TokenType = sttLineTo then
    begin
      X := FSVGPathTokenizer.Tokens.Items[i+1].Value;
      Y := FSVGPathTokenizer.Tokens.Items[i+2].Value;
      ConvertSVGDeltaToFPVDelta(AData, X, Y, X, Y);

      // LineTo uses relative coordenates in SVG
      CurX := CurX + X;
      CurY := CurY + Y;

      AData.AddLineToPath(CurX, CurY);

      Inc(i, 3);
    end
    else if FSVGPathTokenizer.Tokens.Items[i].TokenType = sttBezierTo then
    begin
      X2 := FSVGPathTokenizer.Tokens.Items[i+1].Value;
      Y2 := FSVGPathTokenizer.Tokens.Items[i+2].Value;
      X3 := FSVGPathTokenizer.Tokens.Items[i+3].Value;
      Y3 := FSVGPathTokenizer.Tokens.Items[i+4].Value;
      X := FSVGPathTokenizer.Tokens.Items[i+5].Value;
      Y := FSVGPathTokenizer.Tokens.Items[i+6].Value;

      ConvertSVGDeltaToFPVDelta(AData, X2, Y2, X2, Y2);
      ConvertSVGDeltaToFPVDelta(AData, X3, Y3, X3, Y3);
      ConvertSVGDeltaToFPVDelta(AData, X, Y, X, Y);

      AData.AddBezierToPath(X2 + CurX, Y2 + CurY, X3 + CurX, Y3 + CurY, X + CurX, Y + CurY);

      // BezierTo uses relative coordenates in SVG
      CurX := CurX + X;
      CurY := CurY + Y;

      Inc(i, 7);
    end
    else
    begin
      Inc(i);
    end;
  end;
end;

//          <rect width="90" height="90" stroke="green" stroke-width="3" fill="yellow" filter="url(#f1)" />
procedure TvSVGVectorialReader.ReadRectFromNode(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  lx, ly, cx, cy: double;
  lRect: TvRectangle;
  i: Integer;
  lNodeName: DOMString;
begin
  lx := 0.0;
  ly := 0.0;
  cx := 0.0;
  cy := 0.0;

  lRect := TvRectangle.Create;
  // SVG entities start without any pen drawing, but with a black brush
  lRect.Pen.Style := psClear;
  lRect.Brush.Style := bsSolid;
  lRect.Brush.Color := colBlack;

  // read the attributes
  for i := 0 to ANode.Attributes.Length - 1 do
  begin
    lNodeName := ANode.Attributes.Item[i].NodeName;
    if  lNodeName = 'x' then
      lx := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'y' then
      ly := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'width' then
      cx := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'height' then
      cy := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'style' then
      ReadSVGStyle(ANode.Attributes.Item[i].NodeValue, lRect)
    else if IsAttributeFromStyle(lNodeName) then
    begin
      ReadSVGPenStyleWithKeyAndValue(lNodeName, ANode.Attributes.Item[i].NodeValue, lRect);
      ReadSVGBrushStyleWithKeyAndValue(lNodeName, ANode.Attributes.Item[i].NodeValue, lRect);
    end;
  end;

  ConvertSVGDeltaToFPVDelta(
        AData, lx, ly, lRect.X, lRect.Y);
  ConvertSVGDeltaToFPVDelta(
        AData, cx, cy, lRect.CX, lRect.CY);

  AData.AddEntity(lRect);
end;

function TvSVGVectorialReader.StringWithUnitToFloat(AStr: string): Double;
var
  UnitStr, ValueStr: string;
  Len: Integer;
begin
  if AStr = '' then Exit(0.0);

  // Check the unit
  Len := Length(AStr);
  UnitStr := Copy(AStr, Len-1, 2);
  if UnitStr = 'mm' then
  begin
    ValueStr := Copy(AStr, 1, Len-2);
    Result := StrToInt(ValueStr);
  end
  else if UnitStr = 'cm' then
  begin
    ValueStr := Copy(AStr, 1, Len-2);
    Result := StrToInt(ValueStr) * 10;
  end
  else // If there is no unit, just use StrToFloat
  begin
    Result := StrToFloat(AStr);
  end;
end;

procedure TvSVGVectorialReader.ConvertSVGCoordinatesToFPVCoordinates(
  const AData: TvVectorialPage; const ASrcX, ASrcY: Double;
  var ADestX,ADestY: Double);
begin
  ADestX := ASrcX * FLOAT_MILIMETERS_PER_PIXEL;
  ADestY := AData.Height - ASrcY * FLOAT_MILIMETERS_PER_PIXEL;
end;

procedure TvSVGVectorialReader.ConvertSVGDeltaToFPVDelta(
  const AData: TvVectorialPage; const ASrcX, ASrcY: Double; var ADestX,
  ADestY: Double);
begin
  ADestX := ASrcX * FLOAT_MILIMETERS_PER_PIXEL;
  ADestY := - ASrcY * FLOAT_MILIMETERS_PER_PIXEL;
end;

constructor TvSVGVectorialReader.Create;
begin
  inherited Create;

  FPointSeparator := DefaultFormatSettings;
  FPointSeparator.DecimalSeparator := '.';
  FPointSeparator.ThousandSeparator := '#';// disable the thousand separator

  FSVGPathTokenizer := TSVGPathTokenizer.Create;
end;

destructor TvSVGVectorialReader.Destroy;
begin
  FSVGPathTokenizer.Free;

  inherited Destroy;
end;

procedure TvSVGVectorialReader.ReadFromStream(AStream: TStream;
  AData: TvVectorialDocument);
var
  Doc: TXMLDocument;
  lCurNode: TDOMNode;
  lPage: TvVectorialPage;
begin
  try
    // Read in xml file from the stream
    ReadXMLFile(Doc, AStream);

    // Read the properties of the <svg> tag
    AData.Width := StringWithUnitToFloat(Doc.DocumentElement.GetAttribute('width'));
    AData.Height := StringWithUnitToFloat(Doc.DocumentElement.GetAttribute('height'));

    // Now process the elements
    lCurNode := Doc.DocumentElement.FirstChild;
    lPage := AData.AddPage();
    lPage.Width := AData.Width;
    lPage.Height := AData.Height;
    while Assigned(lCurNode) do
    begin
      ReadEntityFromNode(lCurNode, lPage, AData);
      lCurNode := lCurNode.NextSibling;
    end;
  finally
    // finally, free the document
    Doc.Free;
  end;
end;

initialization

  RegisterVectorialReader(TvSVGVectorialReader, vfSVG);

end.

