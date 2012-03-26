unit EasyLazFreeType;

{ bug list :

- Characters parts may not be well translated, for example i with accent.
- Encoding is ok for ASCII but is mixed up for extended characters

to do :

- multiple font loading
- font face cache
- font style
- text rotation }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LazFreeType, TTTypes, TTRASTER, AvgLvlTree, fpimage, Types, lazutf8; // Graphics, LCLType

type
  TGlyphRenderQuality = (grqMonochrome, grqLowQuality, grqHighQuality);
  ArrayOfSingle= array of single;
  TCharPosition= record
    x,width,
    yTop,yBase,yBottom: single;
  end;
  ArrayOfCharPosition = array of TCharPosition;
  TFreeTypeAlignment = (ftaLeft,ftaCenter,ftaRight,ftaJustify,ftaTop,ftaBaseline,ftaBottom);
  TFreeTypeAlignments = set of TFreeTypeAlignment;

  TFreeTypeInformation = (ftiCopyrightNotice, ftiFamily, ftiStyle, ftiIdentifier, ftiFullName,
     ftiVersionString, ftiPostscriptName, ftiTrademark, ftiManufacturer, ftiDesigner,
     ftiVendorURL, ftiDesignerURL, ftiLicenseDescription, ftiLicenseInfoURL);

  TFreeTypeGlyph = class;

  { TFreeTypeRenderableFont }

  TFreeTypeRenderableFont = class
  protected
    function GetClearType: boolean; virtual; abstract;
    procedure SetClearType(const AValue: boolean); virtual; abstract;
    function GetLineFullHeight: single; virtual; abstract;
    function GetAscent: single; virtual; abstract;
    function GetDescent: single; virtual; abstract;
    function GetLineSpacing: single; virtual; abstract;

  public
    function TextWidth(AText: string): single; virtual; abstract;
    function TextHeight(AText: string): single; virtual; abstract;
    procedure GetTextSize(AText: string; out w,h: single); virtual;
    procedure RenderText(AText: string; x,y: single; ARect: TRect; OnRender : TDirectRenderingFunction); virtual; abstract;
    property ClearType: boolean read GetClearType write SetClearType;
    property Ascent: single read GetAscent;
    property Descent: single read GetDescent;
    property LineSpacing: single read GetLineSpacing;
    property LineFullHeight: single read GetLineFullHeight;
  end;

  { TFreeTypeDrawer }

  TFreeTypeDrawer = class
    procedure DrawText(AText: string; AFont: TFreeTypeRenderableFont; x,y: single; AColor: TFPColor; AOpacity: Byte); virtual; overload;
    procedure DrawText(AText: string; AFont: TFreeTypeRenderableFont; x,y: single; AColor: TFPColor; AOpacity: Byte; AAlign: TFreeTypeAlignments); virtual; overload;
    procedure DrawText(AText: string; AFont: TFreeTypeRenderableFont; x,y: single; AColor: TFPColor); virtual; abstract; overload;
    procedure DrawText(AText: string; AFont: TFreeTypeRenderableFont; x,y: single; AColor: TFPColor; AAlign: TFreeTypeAlignments); virtual; overload;
  end;

  { TFreeTypeFont }

  TFreeTypeFont = class(TFreeTypeRenderableFont)
  private
    FName: String;
    FPointSize: single;
    FHinted: boolean;
    FWidthFactor: single;
    FClearType: boolean;
    FNamesArray: array of string;
    function FindGlyphNode(Index: Integer): TAvgLvlTreeNode;
    function GetCharIndex(AChar: integer): integer;
    function GetDPI: integer;
    function GetFamily: string;
    function GetGlyph(Index: integer): TFreeTypeGlyph;
    function GetGlyphCount: integer;
    function GetInformation(AIndex: TFreeTypeInformation): string;
    function GetPixelSize: single;
    function GetVersionNumber: string;
    procedure SetDPI(const AValue: integer);
    procedure SetHinted(const AValue: boolean);
    procedure SetLineFullHeight(AValue: single);
    procedure SetName(const AValue: String);
    procedure DiscardFace;
    procedure DiscardInstance;
    procedure SetPixelSize(const AValue: single);
    procedure SetPointSize(const AValue: single);
    function LoadGlyphInto(_glyph      : TT_Glyph;
                            glyph_index : Word): boolean;
    procedure SetWidthFactor(const AValue: single);
    procedure UpdateSizeInPoints;
    procedure UpdateMetrics;
    procedure GetCharmap;
  protected
    FFace: TT_Face;
    FFaceLoaded: boolean;
    FInstance: TT_Instance;
    FInstanceCreated : boolean;
    FGlyphTable: TAvgLvlTree;
    FCharMap: TT_CharMap;
    FCharmapOk: boolean;
    FAscentValue, FDescentValue, FLineGapValue, FLargeLineGapValue: single;
    function GetClearType: boolean; override;
    procedure SetClearType(const AValue: boolean); override;
    function GetLineFullHeight: single; override;
    function GetAscent: single; override;
    function GetDescent: single; override;
    function GetLineSpacing: single; override;
    procedure FetchNames;
  public
    Quality : TGlyphRenderQuality;
    SmallLinePadding: boolean;
    constructor Create;
    destructor Destroy; override;
    procedure RenderText(AText: string; x,y: single; ARect: TRect; OnRender : TDirectRenderingFunction); override;
    function TextWidth(AText: string): single; override;
    function TextHeight(AText: string): single; override;
    function CharsWidth(AText: string): ArrayOfSingle;
    function CharsPosition(AText: string): ArrayOfCharPosition; overload;
    function CharsPosition(AText: string; AAlign: TFreeTypeAlignments): ArrayOfCharPosition; overload;
    property Name: String read FName write SetName;
    property DPI: integer read GetDPI write SetDPI;
    property SizeInPoints: single read FPointSize write SetPointSize;
    property SizeInPixels: single read GetPixelSize write SetPixelSize;
    property Glyph[Index: integer]: TFreeTypeGlyph read GetGlyph;
    property GlyphCount: integer read GetGlyphCount;
    property CharIndex[AChar: integer]: integer read GetCharIndex;
    property Hinted: boolean read FHinted write SetHinted;
    property WidthFactor: single read FWidthFactor write SetWidthFactor;
    property LineFullHeight: single read GetLineFullHeight write SetLineFullHeight;
    property Information[AIndex: TFreeTypeInformation]: string read GetInformation;
    property VersionNumber: string read GetVersionNumber;
    property Family: string read GetFamily;
  end;

  { TFreeTypeGlyph }

  TFreeTypeGlyph = class
  private
    FLoaded: boolean;
    FGlyphData: TT_Glyph;
    FIndex: integer;
    function GetAdvance: single;
    function GetBounds: TRect;
    function GetBoundsWithOffset(x, y: single): TRect;
  public
    constructor Create(AFont: TFreeTypeFont; AIndex: integer);
    function RenderDirectly(x,y: single; Rect: TRect; OnRender : TDirectRenderingFunction; quality : TGlyphRenderQuality; ClearType: boolean = false): boolean;
    function RenderDirectly(ARasterizer: TFreeTypeRasterizer; x,y: single; Rect: TRect; OnRender : TDirectRenderingFunction; quality : TGlyphRenderQuality; ClearType: boolean = false): boolean;
    destructor Destroy; override;
    property Loaded: boolean read FLoaded;
    property Data: TT_Glyph read FGlyphData;
    property Index: integer read FIndex;
    property Bounds: TRect read GetBounds;
    property BoundsWithOffset[x,y: single]: TRect read GetBoundsWithOffset;
    property Advance: single read GetAdvance;
  end;

  { TFreeTypeRasterMap }

  TFreeTypeRasterMap = class
  protected
    map: TT_Raster_Map;
    FRasterizer: TFreeTypeRasterizer;
    function GetHeight: integer; virtual;
    function GetWidth: integer; virtual;
    function GetScanLine(y: integer): pointer;
    procedure Init(AWidth,AHeight: integer); virtual; abstract;
  public
    constructor Create(AWidth,AHeight: integer); virtual;
    constructor Create(ARasterizer: TFreeTypeRasterizer; AWidth,AHeight: integer); virtual;
    procedure Clear;
    procedure Fill;
    function RenderGlyph(glyph : TFreeTypeGlyph; x,y: single) : boolean; virtual; abstract;
    procedure ScanMoveTo(x,y: integer); virtual; abstract;
    destructor Destroy; override;

    property Width: integer read GetWidth;
    property Height: integer read GetHeight;
    property ScanLine[y: integer]: pointer read GetScanLine;
  end;

  { TFreeTypeMonochromeMap }

  TFreeTypeMonochromeMap = class(TFreeTypeRasterMap)
  private
    ScanPtrStart,ScanPtrCur: pbyte;
    ScanBit: byte;
    ScanX: integer;
    function GetPixelsInHorizlineNoBoundsChecking(x,y,x2: integer) : integer; inline;
  protected
    procedure Init(AWidth,AHeight: integer); override;
  public
    function RenderGlyph(glyph : TFreeTypeGlyph; x,y: single) : boolean; override;
    procedure ScanMoveTo(x,y: integer); override;
    function ScanNextPixel: boolean;
    function GetPixel(x,y: integer): boolean;
    procedure SetPixel(x,y: integer; value: boolean);
    function GetPixelsInRect(x,y,x2,y2: integer): integer;
    function GetPixelsInHorizline(x,y,x2: integer): integer;
    procedure TogglePixel(x,y: integer);
  end;

  { TFreeTypeGrayscaleMap }

  TFreeTypeGrayscaleMap = class(TFreeTypeRasterMap)
  private
    ScanPtrStart: pbyte;
    ScanX: integer;
  protected
    procedure Init(AWidth, AHeight: integer); override;
  public
    RenderQuality: TGlyphRenderQuality;
    function RenderGlyph(glyph : TFreeTypeGlyph; x,y: single) : boolean; override;
    procedure ScanMoveTo(x,y: integer); override;
    function ScanNextPixel: byte;
    function GetPixel(x,y: integer): byte;
    procedure SetPixel(x,y: integer; value: byte);
    procedure XorPixel(x,y: integer; value: byte);
  end;


implementation

var
  BitCountTable: packed array[0..255] of byte;
  RegularGray5: TT_Gray_Palette;
  FreeTypeInitialized,FreeTypeCannotInitialize : boolean;

procedure EnsureFreeTypeInitialized;
begin
  if not FreeTypeInitialized and not FreeTypeCannotInitialize then
  begin
    FreeTypeInitialized := (TT_Init_FreeType = TT_Err_Ok);
    FreeTypeCannotInitialize := not FreeTypeInitialized;
  end;
  if FreeTypeCannotInitialize then
    raise Exception.Create('FreeType cannot be initialized');
end;

{ TFreeTypeRenderableFont }

procedure TFreeTypeRenderableFont.GetTextSize(AText: string; out w, h: single);
begin
  w := TextWidth(AText);
  h := TextHeight(AText);
end;

{ TFreeTypeDrawer }

procedure TFreeTypeDrawer.DrawText(AText: string;
  AFont: TFreeTypeRenderableFont; x, y: single; AColor: TFPColor; AOpacity: Byte);
var col: TFPColor;
begin
  col := AColor;
  col.alpha := col.alpha*AOpacity div 255;
  DrawText(AText, AFont, x,y, col, []);
end;

procedure TFreeTypeDrawer.DrawText(AText: string;
  AFont: TFreeTypeRenderableFont; x, y: single; AColor: TFPColor; AOpacity: Byte; AAlign: TFreeTypeAlignments);
var col: TFPColor;
begin
  col := AColor;
  col.alpha := col.alpha*AOpacity div 255;
  DrawText(AText, AFont, x,y, col, AAlign);
end;

procedure TFreeTypeDrawer.DrawText(AText: string;
  AFont: TFreeTypeRenderableFont; x, y: single; AColor: TFPColor; AAlign: TFreeTypeAlignments);
var idx : integer;
begin
  if not (ftaBaseline in AAlign) then
  begin
    if ftaTop in AAlign then
      y += AFont.Ascent else
    if ftaBottom in AAlign then
      y -= AFont.TextHeight(AText) - AFont.Ascent;
  end;
  AAlign -= [ftaTop,ftaBaseline,ftaBottom];

  idx := pos(LineEnding, AText);
  while idx <> 0 do
  begin
    DrawText(copy(AText,1,idx-1), AFont, x,y, AColor, AAlign);
    delete(AText,1,idx+length(LineEnding)-1);
    idx := pos(LineEnding, AText);
    y += AFont.LineFullHeight;
  end;

  if not (ftaLeft in AAlign) then
  begin
    if ftaCenter in AAlign then
      x -= AFont.TextWidth(AText)/2 else
    if ftaRight in AAlign then
      x -= AFont.TextWidth(AText);
  end;
  DrawText(AText, AFont, x,y, AColor);
end;

{ TFreeTypeGlyph }

{$hints off}
function TFreeTypeGlyph.GetBounds: TRect;
var metrics: TT_Glyph_Metrics;
begin
  TT_Get_Glyph_Metrics(FGlyphData, metrics);
  with metrics.bbox do
    result := rect(IncludeFullGrainMin(xMin,64) div 64,IncludeFullGrainMin(-yMax,64) div 64,
       (IncludeFullGrainMax(xMax,64)+1) div 64,(IncludeFullGrainMax(-yMin,64)+1) div 64);
end;
{$hints on}

{$hints off}
function TFreeTypeGlyph.GetAdvance: single;
var metrics: TT_Glyph_Metrics;
begin
  TT_Get_Glyph_Metrics(FGlyphData, metrics);
  result := metrics.advance/64;
end;
{$hints on}

{$hints off}
function TFreeTypeGlyph.GetBoundsWithOffset(x, y: single): TRect;
var metrics: TT_Glyph_Metrics;
begin
  TT_Get_Glyph_Metrics(FGlyphData, metrics);
  with metrics.bbox do
    result := rect(IncludeFullGrainMin(xMin+round(x*64),64) div 64,IncludeFullGrainMin(-yMax+round(y*64),64) div 64,
       (IncludeFullGrainMax(xMax+round(x*64),64)+1) div 64,(IncludeFullGrainMax(-yMin+round(y*64),64)+1) div 64);
end;
{$hints on}

constructor TFreeTypeGlyph.Create(AFont: TFreeTypeFont; AIndex: integer);
begin
  if TT_New_Glyph(AFont.FFace, FGlyphData) <> TT_Err_Ok then
    raise Exception.Create('Cannot create empty glyph');
  FLoaded := AFont.LoadGlyphInto(FGlyphData, AIndex);
  FIndex := AIndex;
end;

function TFreeTypeGlyph.RenderDirectly(x, y: single; Rect: TRect;
  OnRender: TDirectRenderingFunction; quality : TGlyphRenderQuality; ClearType: boolean): boolean;
begin
  result := RenderDirectly(TTGetDefaultRasterizer, x,y, Rect, OnRender, quality, ClearType);
end;

function TFreeTypeGlyph.RenderDirectly(ARasterizer: TFreeTypeRasterizer; x,
  y: single; Rect: TRect; OnRender: TDirectRenderingFunction;
  quality: TGlyphRenderQuality; ClearType: boolean): boolean;
var mono: TFreeTypeMonochromeMap;
    tx,xb,yb: integer;
    pdest: pbyte;
    buf: pointer;
    glyphBounds: TRect;
begin
  if ClearType then
  begin
    Rect.Left *= 3;
    Rect.Right *= 3;
    x *= 3;
  end;

  glyphBounds := BoundsWithOffset[x,y];

  if ClearType then
  begin
    InflateRect(glyphBounds,1,0);
    glyphBounds.Left := IncludeFullGrainMin( glyphBounds.Left, 3);
    glyphBounds.Right := IncludeFullGrainMax( glyphBounds.Right-1, 3) + 1;
  end;
  if not IntersectRect(Rect,Rect,glyphBounds) then exit;

  case quality of
    grqMonochrome: begin
                      tx := rect.right-rect.left;
                      mono := TFreeTypeMonochromeMap.Create(ARasterizer,tx,rect.bottom-rect.top);
                      result := mono.RenderGlyph(self,x-rect.left,y-rect.top);
                      if result then
                      begin
                        getmem(buf, tx);
                        for yb := mono.Height-1 downto 0 do
                        begin
                          mono.ScanMoveTo(0,yb);
                          pdest := pbyte(buf);
                          for xb := tx-1 downto 0 do
                          begin
                            if mono.ScanNextPixel then
                              pdest^ := $ff
                            else
                              pdest^ := 0;
                            inc(pdest);
                          end;
                          OnRender(rect.Left,rect.top+yb,tx,buf);
                        end;
                        freemem(buf);
                      end;
                      mono.Free;
                   end;
    grqLowQuality: begin
                     ARasterizer.Set_Raster_Palette(RegularGray5);
                     result := TT_Render_Directly_Glyph_Gray(FGlyphData, round((x-rect.left)*64), round((rect.bottom-y)*64), rect.left,rect.top,rect.right-rect.left,rect.bottom-rect.top, OnRender, ARasterizer) = TT_Err_Ok;
                   end;
    grqHighQuality: result := TT_Render_Directly_Glyph_HQ(FGlyphData, round((x-rect.left)*64), round((rect.bottom-y)*64), rect.left,rect.top,rect.right-rect.left,rect.bottom-rect.top, OnRender, ARasterizer) = TT_Err_Ok;
  else
    result := false;
  end;
end;

destructor TFreeTypeGlyph.Destroy;
begin
  TT_Done_Glyph(FGlyphData);
  inherited Destroy;
end;

{ TFreeTypeFont }

procedure TFreeTypeFont.SetName(const AValue: String);
var errorNum: TT_Error;
    PrevDPI: integer;
begin
  if FName=AValue then exit;
  PrevDPI := DPI;
  DiscardInstance;
  DiscardFace;
  errorNum := TT_Open_Face(AValue,FFace);
  if errorNum = TT_Err_Ok then
  begin
    FFaceLoaded:= true;
    FName:=AValue;

    UpdateMetrics;
    GetCharmap;

    errorNum := TT_New_Instance(FFace, FInstance);
    if errorNum = TT_Err_Ok then
    begin
      FInstanceCreated := true;
      DPI := PrevDPI;
    end else
      raise exception.Create('Cannot create font instance (TT_Error ' + intToStr(errorNum)+')');
  end else
    raise exception.Create('Cannot open font (TT_Error ' + intToStr(errorNum)+')');
end;

{$hints off}
function TFreeTypeFont.GetDPI: integer;
var metrics: TT_Instance_Metrics;
begin
  if not FInstanceCreated then
    result := 96
  else
  begin
    if TT_Get_Instance_Metrics(FInstance,metrics) = TT_Err_Ok then
      result := metrics.y_resolution
    else
      result := 96;
  end;
end;

function TFreeTypeFont.GetFamily: string;
begin
  result := Information[ftiFamily];
end;

{$hints on}

function TFreeTypeFont.FindGlyphNode(Index: Integer): TAvgLvlTreeNode;
var DataValue: integer;
begin
  Result:=FGlyphTable.Root;
  while (Result<>nil) do begin
    DataValue := TFreeTypeGlyph(Result.Data).Index;
    if Index=DataValue then exit;
    if Index<DataValue then begin
      Result:=Result.Left
    end else begin
      Result:=Result.Right
    end;
  end;
end;

function TFreeTypeFont.GetAscent: single;
begin
  result := FAscentValue*SizeInPixels;
end;

function TFreeTypeFont.GetClearType: boolean;
begin
  Result:= FClearType;
end;

function TFreeTypeFont.GetCharIndex(AChar: integer): integer;
begin
  if FCharmapOk then
    result := TT_Char_Index(FCharMap, AChar)
  else
    result := AChar;
end;

function TFreeTypeFont.GetDescent: single;
begin
  result := FDescentValue*SizeInPixels;
end;

function TFreeTypeFont.GetGlyph(Index: integer): TFreeTypeGlyph;
var node: TAvgLvlTreeNode;
    lGlyph: TFreeTypeGlyph;
begin
  node := FindGlyphNode(Index);
  if node = nil then
  begin
    lGlyph := TFreeTypeGlyph.Create(self, Index);;
    FGlyphTable.Add(lGlyph);
  end else
    lGlyph := TFreeTypeGlyph(node.Data);
  result := lGlyph;
end;

{$hints off}
function TFreeTypeFont.GetGlyphCount: integer;
var prop : TT_Face_Properties;
begin
  if not FFaceLoaded then
    result := 0
  else
  begin
    if TT_Get_Face_Properties(FFace, prop) <> TT_Err_Ok then
      result := 0
    else
      result := prop.num_glyphs;
  end;
end;

function TFreeTypeFont.GetInformation(AIndex: TFreeTypeInformation): string;
begin
  if FNamesArray = nil then FetchNames;
  if (ord(AIndex) < 0) or (ord(AIndex) > high(FNamesArray)) then
    result := ''
  else
    result := FNamesArray[ord(AIndex)];
end;

{$hints on}

function TFreeTypeFont.GetLineFullHeight: single;
begin
  result := (FAscentValue + FDescentValue)*SizeInPixels + GetLineSpacing;
end;

function TFreeTypeFont.GetLineSpacing: single;
begin
  if not SmallLinePadding then
    result := FLargeLineGapValue*SizeInPixels
  else
    result := FLineGapValue*SizeInPixels;
end;

function TFreeTypeFont.GetPixelSize: single;
begin
  result := SizeInPoints * DPI / 72;
end;

function TFreeTypeFont.GetVersionNumber: string;
var VersionStr: string;
    idxStart,idxEnd: integer;
begin
  VersionStr := Information[ftiVersionString];
  idxStart := 1;
  while (idxStart < length(VersionStr)) and not (VersionStr[idxStart] in['0'..'9']) do
    inc(idxStart);
  idxEnd := idxStart;
  while (idxEnd+1 <= length(VersionStr)) and (VersionStr[idxEnd+1] in['0'..'9']) do inc(idxEnd);
  if (idxEnd+1 <= length(VersionStr)) and (VersionStr[idxEnd+1] = '.') then inc(idxEnd);
  while (idxEnd+1 <= length(VersionStr)) and (VersionStr[idxEnd+1] in['0'..'9']) do inc(idxEnd);
  result := copy(VersionStr,idxStart,idxEnd-idxStart+1);
end;

procedure TFreeTypeFont.SetClearType(const AValue: boolean);
begin
  if FClearType=AValue then exit;
  FClearType:=AValue;
  UpdateSizeInPoints;
end;

procedure TFreeTypeFont.SetDPI(const AValue: integer);
begin
  if FInstanceCreated then
  begin
    TT_Set_Instance_Resolutions(FInstance, AValue,AValue);
    UpdateSizeInPoints;
  end;
end;

procedure TFreeTypeFont.SetHinted(const AValue: boolean);
begin
  if FHinted=AValue then exit;
  FHinted:=AValue;
  FGlyphTable.FreeAndClear;
end;

procedure TFreeTypeFont.SetLineFullHeight(AValue: single);
var Ratio: single;
begin
  Ratio := FAscentValue + FDescentValue;
  if not SmallLinePadding then
    Ratio += FLargeLineGapValue
  else
    Ratio += FLineGapValue;
  if Ratio <> 0 then
    SizeInPixels := AValue / Ratio
  else
    SizeInPixels := AValue;
end;

procedure TFreeTypeFont.DiscardFace;
begin
  if FFaceLoaded then
  begin
    TT_Close_Face(FFace);
    FFaceLoaded := false;
    FNamesArray := nil;
  end;
  FCharmapOk := false;
end;

procedure TFreeTypeFont.DiscardInstance;
begin
  if FInstanceCreated then
  begin
    TT_Done_Instance(FInstance);
    FInstanceCreated := false;
    FGlyphTable.FreeAndClear;
  end;
end;

procedure TFreeTypeFont.SetPixelSize(const AValue: single);
begin
  if FInstanceCreated then
    SizeInPoints := AValue*72/DPI;
end;

procedure TFreeTypeFont.SetPointSize(const AValue: single);
begin
  if FPointSize=AValue then exit;
  FPointSize:=AValue;
  if FInstanceCreated then
    UpdateSizeInPoints;
end;

function TFreeTypeFont.LoadGlyphInto(_glyph: TT_Glyph; glyph_index: Word): boolean;
var flags: integer;
begin
  if not FInstanceCreated then
    raise Exception.Create('No font instance');
  flags := TT_Load_Scale_Glyph;
  if FHinted then flags := flags or TT_Load_Hint_Glyph;
  result := (TT_Load_Glyph(FInstance, _glyph, glyph_index, flags) <> TT_Err_Ok);
end;

procedure TFreeTypeFont.SetWidthFactor(const AValue: single);
begin
  if FWidthFactor=AValue then exit;
  FWidthFactor:=AValue;
  FGlyphTable.FreeAndClear;
  if FInstanceCreated then
    UpdateSizeInPoints;
end;

procedure TFreeTypeFont.UpdateSizeInPoints;
var charsizex: integer;
begin
  if FInstanceCreated then
  begin
    if not FClearType then
      charsizex := round(FPointSize*64*FWidthFactor)
    else
      charsizex := round(FPointSize*64*FWidthFactor*3);

    if TT_Set_Instance_CharSizes(FInstance,charsizex,round(FPointSize*64)) <> TT_Err_Ok then
      raise Exception.Create('Unable to set point size');
    FGlyphTable.FreeAndClear;
  end;
end;

procedure TFreeTypeFont.UpdateMetrics;
var prop: TT_Face_Properties;
begin
  if FFaceLoaded then
  begin
    TT_Get_Face_Properties(FFace,prop);
    FAscentValue := prop.horizontal^.ascender;
    FDescentValue := prop.horizontal^.descender;
    FLineGapValue:= prop.horizontal^.line_gap;
    FLargeLineGapValue:= FLineGapValue;

    if (FAscentValue = 0) and (FDescentValue = 0) then
    begin
      if prop.os2^.version <> $ffff then
      begin
        if (prop.os2^.usWinAscent <> 0) or (prop.os2^.usWinDescent <> 0) then
        begin
          FAscentValue := prop.os2^.usWinAscent;
          FDescentValue := -prop.os2^.usWinDescent;
        end else
        begin
          FAscentValue := prop.os2^.sTypoAscender;
          FDescentValue := prop.os2^.sTypoDescender;
        end;
      end;
    end;

    if prop.os2^.version <> $ffff then
    begin
      if prop.os2^.sTypoLineGap > FLargeLineGapValue then
        FLargeLineGapValue := prop.os2^.sTypoLineGap;
    end;

    FAscentValue /= prop.header^.units_per_EM;
    FDescentValue /= -prop.header^.units_per_EM;
    FLineGapValue /= prop.header^.units_per_EM;
    FLargeLineGapValue /= prop.header^.units_per_EM;

    if FLargeLineGapValue = 0 then
      FLargeLineGapValue := (FAscentValue+FDescentValue)*0.1;

  end else
  begin
    FAscentValue := -0.5;
    FDescentValue := 0.5;
    FLineGapValue := 0;
  end;
end;

procedure TFreeTypeFont.GetCharmap;
var i,n: integer;
    platform,encoding: integer;
begin
  if FCharmapOk then exit;
  if not FFaceLoaded then
  begin
    FCharmapOk := false;
    exit;
  end;

  n := TT_Get_CharMap_Count(FFace);
  platform := 0;
  encoding := 0;

  //MS Unicode
  for i := 0 to n-1 do
  begin
    if TT_Get_CharMap_ID(FFace, i, platform, encoding) = TT_Err_Ok then
    begin
      if (platform = 3) and (encoding = 1) then
        if TT_Get_CharMap(FFace, i, FCharMap) = TT_Err_Ok then
        begin
          FCharmapOk := true;
          exit;
        end;
    end;
  end;

  //Apple Unicode
  for i := 0 to n-1 do
  begin
    if TT_Get_CharMap_ID(FFace, i, platform, encoding) = TT_Err_Ok then
    begin
      if (platform = 0) then
        if TT_Get_CharMap(FFace, i, FCharMap) = TT_Err_Ok then
        begin
          FCharmapOk := true;
          exit;
        end;
    end;
  end;

  //ISO Unicode
  for i := 0 to n-1 do
  begin
    if TT_Get_CharMap_ID(FFace, i, platform, encoding) = TT_Err_Ok then
    begin
      if (platform = 2) and (encoding = 1) then
        if TT_Get_CharMap(FFace, i, FCharMap) = TT_Err_Ok then
        begin
          FCharmapOk := true;
          exit;
        end;
    end;
  end;

  FCharmapOk := false;
end;

constructor TFreeTypeFont.Create;
begin
  EnsureFreeTypeInitialized;
  FFaceLoaded := false;
  FInstanceCreated := false;
  FCharmapOk := false;
  FPointSize := 10;
  FGlyphTable := TAvgLvlTree.Create;
  FHinted := true;
  FWidthFactor := 1;
  FClearType := false;
  SmallLinePadding:= true;
  Quality := grqHighQuality;
end;

destructor TFreeTypeFont.Destroy;
begin
  DiscardInstance;
  DiscardFace;
  FGlyphTable.Free;
  inherited Destroy;
end;

procedure TFreeTypeFont.RenderText(AText: string; x, y: single; ARect: TRect;
  OnRender: TDirectRenderingFunction);
var
  pstr: pchar;
  left,charcode,charlen: integer;
  idx: integer;
begin
  if AText = '' then exit;
  idx := pos(LineEnding,AText);
  while idx <> 0 do
  begin
    RenderText(copy(AText,1,idx-1),x,y,ARect,OnRender);
    delete(AText,1,idx+length(LineEnding)-1);
    y += LineFullHeight;
    idx := pos(LineEnding,AText);
  end;
  pstr := @AText[1];
  left := length(AText);
  while left > 0 do
  begin
    charcode := UTF8CharacterToUnicode(pstr, charlen);
    inc(pstr,charlen);
    dec(left,charlen);
    with Glyph[CharIndex[charcode]] do
    begin
      if Hinted then
       RenderDirectly(x,round(y),ARect,OnRender,quality,FClearType)
      else
       RenderDirectly(x,y,ARect,OnRender,quality,FClearType);
      if FClearType then
        x += Advance/3
      else
        x += Advance;
    end;
  end;
end;

function TFreeTypeFont.TextWidth(AText: string): single;
var
  pstr: pchar;
  left,charcode,charlen: integer;
  maxWidth,w: single;
  idx: integer;
begin
  result := 0;
  if AText = '' then exit;

  maxWidth := 0;
  idx := pos(LineEnding,AText);
  while idx <> 0 do
  begin
    w := TextWidth(copy(AText,1,idx-1));
    if w > maxWidth then maxWidth:= w;
    delete(AText,1,idx+length(LineEnding)-1);
    idx := pos(LineEnding,AText);
  end;
  if AText = '' then
  begin
    result := maxWidth;
    exit;
  end;

  pstr := @AText[1];
  left := length(AText);
  while left > 0 do
  begin
    charcode := UTF8CharacterToUnicode(pstr, charlen);
    inc(pstr,charlen);
    dec(left,charlen);
    with Glyph[CharIndex[charcode]] do
    begin
      if FClearType then
        result += Advance/3
      else
        result += Advance;
    end;
  end;
  if maxWidth > result then
    result := maxWidth;
end;

function TFreeTypeFont.TextHeight(AText: string): single;
var idx: integer;
    nb: integer;
begin
  if AText= '' then result := 0
   else
  begin
    result := LineFullHeight;
    nb := 1;
    idx := pos(LineEnding,AText);
    while idx <> 0 do
    begin
      nb += 1;
      delete(AText,1,idx+length(LineEnding)-1);
      idx := pos(LineEnding,AText);
    end;
    result *= nb;
  end;
end;

function TFreeTypeFont.CharsWidth(AText: string): ArrayOfSingle;
var
  pstr: pchar;
  left,charcode,charlen: integer;
  resultIndex,i: integer;
  w: single;
begin
  if AText = '' then exit;
  pstr := @AText[1];
  left := length(AText);
  setlength(result, UTF8Length(AText));
  resultIndex := 0;
  while left > 0 do
  begin
    charcode := UTF8CharacterToUnicode(pstr, charlen);
    inc(pstr,charlen);
    dec(left,charlen);

    with Glyph[CharIndex[charcode]] do
    begin
      if FClearType then
        w := Advance/3
      else
        w := Advance;
    end;

    for i := 1 to charlen do
    begin
      result[resultIndex] := w;
      inc(resultIndex);
    end;
  end;
end;

function TFreeTypeFont.CharsPosition(AText: string): ArrayOfCharPosition;
begin
  result := CharsPosition(AText, []);
end;

function TFreeTypeFont.CharsPosition(AText: string; AAlign: TFreeTypeAlignments): ArrayOfCharPosition;
var
  resultIndex,resultLineStart: integer;
  curX: single;

  procedure ApplyHorizAlign;
  var delta: single;
      i: integer;
  begin
    if ftaLeft in AAlign then exit;
    if ftaCenter in AAlign then
      delta := -curX/2
    else if ftaRight in AAlign then
      delta := -curX
    else
      exit;

    for i := resultLineStart to resultIndex-1 do
      result[i].x += delta;
  end;

var
  pstr: pchar;
  left,charcode,charlen: integer;
  i : integer;
  w,h,y,yTopRel,yBottomRel: single;
  Found: boolean;
  StrLineEnding: string; // a string version of LineEnding, don't remove or else wont compile in UNIXes
begin
  if AText = '' then exit;
  StrLineEnding := LineEnding;
  pstr := @AText[1];
  left := length(AText);
  setlength(result, UTF8Length(AText)+1);
  resultIndex := 0;
  resultLineStart := 0;
  if ftaLeft in AAlign then AAlign -= [ftaLeft, ftaCenter, ftaRight];
  if ftaBaseline in AAlign then AAlign -= [ftaTop, ftaBaseline, ftaBottom];
  curX := 0;
  y := 0;
  if ftaTop in AAlign then
  begin
    y += Ascent;
    AAlign -= [ftaTop, ftaBottom];
  end;
  yTopRel := -Ascent;
  yBottomRel := Descent;
  h := LineFullHeight;
  while left > 0 do
  begin
    if (left > length(StrLineEnding)) and (pstr^ = StrLineEnding[1]) then
    begin
      Found := true;
      for i := 2 to length(StrLineEnding) do
        if (pstr+(i-1))^ <> StrLineEnding[i] then
        begin
          Found := false;
          break;
        end;
      if Found then
      begin
        for i := 1 to length(StrLineEnding) do
        begin
          with result[resultIndex] do
          begin
            x := curX;
            width := 0;
            yTop := y+yTopRel;
            yBase := y;
            yBottom := y+yBottomRel;
          end;
          inc(resultIndex);
          inc(pstr);
          dec(left);
        end;
        ApplyHorizAlign;
        y += h;
        curX := 0;
        resultLineStart := resultIndex;
        if left <= 0 then break;
      end;
    end;
    charcode := UTF8CharacterToUnicode(pstr, charlen);
    inc(pstr,charlen);
    dec(left,charlen);
    with Glyph[CharIndex[charcode]] do
    begin
      if FClearType then
        w := Advance/3
      else
        w := Advance;
    end;
    for i := 1 to charlen do
    with result[resultIndex] do
    begin
      x := curX;
      width := w;
      yTop := y+yTopRel;
      yBase := y;
      yBottom := y+yBottomRel;
      inc(resultIndex);
    end;
    curX += w;
  end;
  with result[resultIndex] do
  begin
    x := curX;
    width := 0;
    yTop := y+yTopRel;
    yBase := y;
    yBottom := y+yBottomRel;
  end;
  inc(resultIndex);
  ApplyHorizAlign;

  if ftaBottom in AAlign then
  begin
    y += LineFullHeight-Ascent;
    for i := 0 to high(result) do
    with result[i] do
    begin
      yTop -= y;
      yBase -= y;
      yBottom -= y;
    end;
  end;
end;

procedure TFreeTypeFont.FetchNames;
const
  maxNameIndex = 22;
var i,j: integer;
  nrPlatformID,nrEncodingID,nrLanguageID,nrNameID,len: integer;
  value,value2: string;

begin
  setlength(FNamesArray, maxNameIndex+1);
  if FFaceLoaded then
  begin
    for i := 0 to TT_Get_Name_Count(FFace)-1 do
    begin
      if TT_Get_Name_ID(FFace, i, nrPlatformID, nrEncodingID,
                        nrLanguageID, nrNameID) <> TT_Err_Ok then continue;

      if (nrNameID < 0) or (nrNameID > maxNameIndex) then continue;

        { check for Microsoft, Unicode, English }
      if ((nrPlatformID=3) and (nrEncodingID=1) and
         ((nrLanguageID=$0409) or (nrLanguageID=$0809) or
          (nrLanguageID=$0c09) or (nrLanguageID=$1009) or
          (nrLanguageID=$1409) or (nrLanguageID=$1809))) or
        { or for Unicode, English }
        ((nrPlatformID=0) and
         (nrLanguageID=0)) then
      begin
        value := TT_Get_Name_String(FFace, i);
        for j := 1 to length(value) div 2 do
          pword(@value[j*2-1])^ := BEtoN(pword(@value[j*2-1])^);
        setlength(value2, 3*(length(value) div 2) + 1); //maximum is 3-byte chars and NULL char at the end
        len := system.UnicodeToUtf8(@value2[1],length(value2),PUnicodeChar( @value[1] ),length(value) div 2);
        if len > 0 then
        begin
          setlength(value2, len-1 );
          value := value2;
        end;
        FNamesArray[nrNameID] := value;
      end;
    end;
  end;
end;

{ TFreeTypeGrayscaleMap }

procedure TFreeTypeGrayscaleMap.Init(AWidth, AHeight: integer);
begin
  map.Width := AWidth;
  map.Rows := AHeight;
  map.Cols:= (AWidth+3) and not 3;
  map.flow:= TT_Flow_Down;
  map.Size:= map.Rows*map.Cols;
  getmem(map.Buffer,map.Size);
  Clear;
  RenderQuality := grqHighQuality;
end;

function TFreeTypeGrayscaleMap.RenderGlyph(glyph: TFreeTypeGlyph; x, y: single): boolean;
var mono: TFreeTypeMonochromeMap;
    psrc,pdest: pbyte;
    xb,yb,tx: integer;
    curBit: byte;
begin
  case RenderQuality of
    grqMonochrome:
      begin
        tx := Width;
        mono := TFreeTypeMonochromeMap.Create(FRasterizer, tx,Height);
        result := mono.RenderGlyph(glyph,x,y);
        if result then
        begin
          for yb := mono.Height-1 downto 0 do
          begin
            psrc := mono.ScanLine[yb];
            pdest := self.ScanLine[yb];
            curBit := $80;
            for xb := tx-1 downto 0 do
            begin
              if psrc^ and curBit <> 0 then
                pdest^ := $ff;
              curBit := curBit shr 1;
              if curBit = 0 then
              begin
                curBit := $80;
                inc(psrc);
              end;
              inc(pdest);
            end;
          end;
        end;
        mono.Free;
      end;
    grqLowQuality:
      begin
        FRasterizer.Set_Raster_Palette(RegularGray5);
        result := TT_Get_Glyph_Pixmap(glyph.data, map, round(x*64), round((height-y)*64), FRasterizer) = TT_Err_Ok;
      end;
    grqHighQuality:
      begin
        result := TT_Get_Glyph_Pixmap_HQ(glyph.data, map, round(x*64), round((height-y)*64), FRasterizer) = TT_Err_Ok;
      end;
  end;
end;

procedure TFreeTypeGrayscaleMap.ScanMoveTo(x, y: integer);
begin
  ScanPtrStart := pbyte(ScanLine[y]);
  ScanX := x mod Width;
  if ScanX < 0 then inc(ScanX,Width);
end;

function TFreeTypeGrayscaleMap.ScanNextPixel: byte;
begin
  if ScanPtrStart = nil then
    result := 0
  else
  begin
    result := (ScanPtrStart+ScanX)^;
    inc(ScanX);
    if ScanX = map.Width then ScanX := 0;
  end;
end;

function TFreeTypeGrayscaleMap.GetPixel(x, y: integer): byte;
begin
  if (x < 0) or (x>= width) or (y <0) or (y >= height) then
    result := 0
  else
    result := (pbyte(map.Buffer) + y*map.Cols + x)^;
end;

procedure TFreeTypeGrayscaleMap.SetPixel(x, y: integer; value: byte);
begin
  if (x < 0) or (x>= width) or (y <0) or (y >= height) then
    exit
  else
    (pbyte(map.Buffer) + y*map.Cols + x)^ := value;
end;

procedure TFreeTypeGrayscaleMap.XorPixel(x, y: integer; value: byte);
var p : pbyte;
begin
  if (x < 0) or (x>= width) or (y <0) or (y >= height) then
    exit
  else
  begin
    p := (pbyte(map.Buffer) + y*map.Cols + x);
    p^ := p^ xor value;
  end;
end;

{ TFreeTypeRasterMap }

function TFreeTypeRasterMap.GetHeight: integer;
begin
  result := map.Rows;
end;

function TFreeTypeRasterMap.GetWidth: integer;
begin
  result := map.Width;
end;

function TFreeTypeRasterMap.GetScanLine(y: integer): pointer;
begin
  if (y <0) or (y >= height) then
    result := nil
  else
    Result:= pointer(pbyte(map.Buffer) + y*map.Cols);
end;

constructor TFreeTypeRasterMap.Create(AWidth, AHeight: integer);
begin
  FRasterizer := TTGetDefaultRasterizer;
  Init(AWidth,AHeight);
end;

constructor TFreeTypeRasterMap.Create(ARasterizer: TFreeTypeRasterizer; AWidth,
  AHeight: integer);
begin
  FRasterizer := ARasterizer;
  Init(AWidth,AHeight);
end;

procedure TFreeTypeRasterMap.Clear;
begin
  fillchar(map.Buffer^, map.Size, 0);
end;

procedure TFreeTypeRasterMap.Fill;
begin
  fillchar(map.Buffer^, map.Size, $ff);
end;

destructor TFreeTypeRasterMap.Destroy;
begin
  freemem(map.Buffer);
  inherited Destroy;
end;

{ TFreeTypeMonochromeMap }

function TFreeTypeMonochromeMap.RenderGlyph(glyph: TFreeTypeGlyph; x,y: single): boolean;
begin
  result := TT_Get_Glyph_Bitmap(glyph.data, map, round(x*64), round((height-y)*64), FRasterizer) = TT_Err_Ok;
end;

procedure TFreeTypeMonochromeMap.ScanMoveTo(x, y: integer);
begin
  ScanPtrStart := pbyte(ScanLine[y]);
  ScanX := x mod Width;
  if ScanX < 0 then inc(ScanX,Width);

  if ScanPtrStart <> nil then
  begin
    ScanPtrCur := ScanPtrStart + (ScanX shr 3);
    ScanBit := $80 shr (ScanX and 7);
  end else
  begin
    ScanPtrCur := nil;
    ScanBit := 0;
  end;
end;

function TFreeTypeMonochromeMap.ScanNextPixel: boolean;
begin
  if ScanPtrCur = nil then
    result := false
  else
  begin
    result := (pbyte(ScanPtrCur)^ and ScanBit) <> 0;
    inc(ScanX);
    if ScanX = map.Width then
    begin
      ScanX := 0;
      ScanBit := $80;
      ScanPtrCur := ScanPtrStart;
    end else
    begin
      ScanBit := ScanBit shr 1;
      if ScanBit = 0 then
      begin
        ScanBit := $80;
        inc(ScanPtrCur);
      end;
    end;
  end;
end;

function TFreeTypeMonochromeMap.GetPixel(x, y: integer): boolean;
begin
  if (x < 0) or (x>= width) or (y <0) or (y >= height) then
    result := false
  else
    result := (pbyte(map.Buffer) + y*map.Cols + (x shr 3))^ and ($80 shr (x and 7)) <> 0;
end;

procedure TFreeTypeMonochromeMap.SetPixel(x, y: integer; value: boolean);
var p: pbyte;
begin
  if (x < 0) or (x>= width) or (y <0) or (y >= height) then
    exit
  else
  begin
    p := pbyte(map.Buffer) + y*map.Cols + (x shr 3);
    if not value then
      p^ := p^ and not ($80 shr (x and 7))
    else
      p^ := p^ or ($80 shr (x and 7));
  end;
end;

function TFreeTypeMonochromeMap.GetPixelsInRect(x, y, x2, y2: integer): integer;
var yb: integer;
begin
  result := 0;

  if x < 0 then x := 0;
  if x2 > width then x2 := width;
  if x2 <= x then exit;

  if y < 0 then y := 0;
  if y2 > height then y2 := height;
  for yb := y to y2-1 do
    result += GetPixelsInHorizlineNoBoundsChecking(x,yb,x2-1);
end;

function TFreeTypeMonochromeMap.GetPixelsInHorizline(x, y, x2: integer): integer;
begin
  if x < 0 then x := 0;
  if x2 >= width then x2 := width-1;
  if x2 <= x then
  begin
    result := 0;
    exit;
  end;
  if (y < 0) or (y >= height) then
  begin
    result := 0;
    exit;
  end;

  result := GetPixelsInHorizlineNoBoundsChecking(x,y,x2);
end;

function TFreeTypeMonochromeMap.GetPixelsInHorizlineNoBoundsChecking(x, y, x2: integer
  ): integer;
var p: pbyte;
    ix,ix2: integer;
begin
  result := 0;
  ix := x shr 3;
  ix2 := x2 shr 3;
  p := pbyte(map.Buffer) + y*map.Cols + ix;
  if ix2 > ix then
  begin
    result += BitCountTable[ p^ and ($ff shr (x and 7)) ];
    inc(p^);
    inc(ix);
    while (ix2 > ix) do
    begin
      result += BitCountTable[p^];
      inc(ix);
      inc(p^);
    end;
    result += BitCountTable[ p^ and ($ff shl (x2 and 7 xor 7)) ];
  end else
    result += BitCountTable[ p^ and ($ff shr (x and 7)) and ($ff shl (x2 and 7 xor 7))];
end;

procedure TFreeTypeMonochromeMap.Init(AWidth, AHeight: integer);
begin
  map.Width := AWidth;
  map.Rows := AHeight;
  map.Cols:= (AWidth+7) shr 3;
  map.flow:= TT_Flow_Down;
  map.Size:= map.Rows*map.Cols;
  getmem(map.Buffer,map.Size);
  Clear;
end;

procedure TFreeTypeMonochromeMap.TogglePixel(x, y: integer);
var p: pbyte;
begin
  if (x < 0) or (x>= width) or (y <0) or (y >= height) then
    exit
  else
  begin
    p := pbyte(map.Buffer) + y*map.Cols + (x shr 3);
    p^ := p^ xor ($80 shr (x and 7));
  end;
end;

procedure InitTables;
var i: integer;
begin
  for i := 0 to 255 do
  begin
    BitCountTable[i] := (i and 1) + (i shr 1 and 1) + (i shr 2 and 1) + (i shr 3 and 1) +
       (i shr 4 and 1) + (i shr 5 and 1) + (i shr 6 and 1) + (i shr 7 and 1);
  end;

  RegularGray5[0] := 0;
  RegularGray5[1] := $60;
  RegularGray5[2] := $a0;
  RegularGray5[3] := $d0;
  RegularGray5[4] := $ff;
end;

initialization

  FreeTypeInitialized := false;
  FreeTypeCannotInitialize := false;
  InitTables;

finalization

  if FreeTypeInitialized then
  begin
    TT_Done_FreeType;
    FreeTypeInitialized := false;
  end;

end.

