unit LazSynTextArea;

{$mode objfpc}{$H+}
{$INLINE OFF}

interface

uses
  Classes, SysUtils, Graphics, Controls, LCLType, LCLIntf, LCLProc,
  SynEditTypes, SynEditMiscProcs, SynEditMiscClasses, LazSynEditText,
  SynEditMarkup, SynEditHighlighter, SynTextDrawer;


type
  TLazSynDisplayTokenInfoEx = record
    Tk: TLazSynDisplayTokenInfo;
    StartPos: TLazSynDisplayTokenBound;  // Start according to Logical flow. Left for LTR, or Right for RTL
    EndPos: TLazSynDisplayTokenBound;    // End according to Logical flow.
    // SreenRect Bounds. Ltr/RTL independent. Start is always left. End Always right
    PhysicalCharStart: Integer;          // 1 based - Full char bound (Before StartPos.Physical (PaintStart))
    PhysicalClipStart: Integer;          // 1 based - PaintStart
    PhysicalCharEnd: Integer;            // 1 based - Full char bound (After EndPos.Physical (PaintEnd))
    PhysicalClipEnd: Integer;            // 1 based - PaintEnd
    IsRtl: boolean;
    Attr: TSynSelectedColor;

    ExpandedExtraBytes: Integer;         // tab and space expansion
    HasDoubleWidth: Boolean;

    NextPos: TLazSynDisplayTokenBound;   // Next toxen, may be BIDI
    NextIsRtl: boolean;
  end;

  { TLazSynPaintTokenBreaker }

  TLazSynPaintTokenBreaker = class
  private
    FBackgroundColor: TColor;
    FForegroundColor: TColor;
    FSpaceExtraByteCount: Integer;
    FTabExtraByteCount: Integer;
    FFirstCol, FLastCol: integer; // Physical

    FDisplayView: TLazSynDisplayView;
    FLinesView:  TSynEditStrings;
    FMarkupManager: TSynEditMarkupManager;

    FCharWidths: TPhysicalCharWidths;
    FCharWidthsLen: Integer;
    FCurTxtLineIdx : Integer;

    FCurViewToken: TLazSynDisplayTokenInfoEx;
    FCurViewTokenViewPhysStart: Integer;
    FCurViewinRTL: Boolean;
    FCurViewRtlPhysEnd: integer;
    FCurViewRtlLogEnd: integer;

    FCurMarkupPhysPos, FNextMarkupPhysPos: Integer; // 1, -1
    FCurMarkupEOL: Boolean;
    FCurMarkupNextStart: TLazSynDisplayTokenBound;
    FMarkupTokenAttr: TSynSelectedColor;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Prepare(ADisplayView: TLazSynDisplayView; ALinesView:  TSynEditStrings;
                      AMarkupManager: TSynEditMarkupManager;
                      AFirstCol, ALastCol: integer
                     );
    procedure SetHighlighterTokensLine(ALine: TLineIdx; out ARealLine: TLineIdx);
    function  GetNextHighlighterTokenFromView(out ATokenInfo: TLazSynDisplayTokenInfoEx;
                                              APhysEnd: Integer = -1;
                                              ALogEnd: Integer = -1
                                             ): Boolean;
    function  GetNextHighlighterTokenEx(out ATokenInfo: TLazSynDisplayTokenInfoEx): Boolean;
    property  CharWidths: TPhysicalCharWidths read FCharWidths;
    property ForegroundColor: TColor read FForegroundColor write FForegroundColor;
    property BackgroundColor: TColor read FBackgroundColor write FBackgroundColor;
    property SpaceExtraByteCount: Integer read FSpaceExtraByteCount write FSpaceExtraByteCount;
    property TabExtraByteCount: Integer read FTabExtraByteCount write FTabExtraByteCount;
  end;

  { TLazSynTextArea }

  TLazSynTextArea = class(TLazSynSurface)
  private
    FCharsInWindow: Integer;
    FCharWidth: integer;
    FLinesInWindow: Integer;
    fOnStatusChange: TStatusChangeEvent;
    FTextHeight: integer;

    FCanvas: TCanvas;
    FTextDrawer: TheTextDrawer;
    FTheLinesView: TSynEditStrings;
    FHighlighter: TSynCustomHighlighter;
    FMarkupManager: TSynEditMarkupManager;
    FTokenBreaker: TLazSynPaintTokenBreaker;
    FPaintLineColor, FPaintLineColor2: TSynSelectedColor;
    FForegroundColor: TColor;
    FBackgroundColor: TColor;
    FRightEdgeColor: TColor;

    FTextBounds: TRect;
    FPadding: array [TLazSynBorderSide] of Integer;
    FExtraCharSpacing: integer;
    FExtraLineSpacing: integer;
    FVisibleSpecialChars: TSynVisibleSpecialChars;
    FRightEdgeColumn: integer;
    FRightEdgeVisible: boolean;

    FTopLine: TLinePos;
    FLeftChar: Integer;

    function GetPadding(Side: TLazSynBorderSide): integer;
    procedure SetExtraCharSpacing(AValue: integer);
    procedure SetExtraLineSpacing(AValue: integer);
    procedure SetLeftChar(AValue: Integer);
    procedure SetPadding(Side: TLazSynBorderSide; AValue: integer);
    procedure SetTopLine(AValue: TLinePos);
    procedure DoDrawerFontChanged(Sender: TObject);
  protected
    procedure BoundsChanged; override;
    procedure DoPaint(ACanvas: TCanvas; AClip: TRect); override;
    procedure PaintTextLines(AClip: TRect; FirstLine, LastLine,
      FirstCol, LastCol: integer); virtual;
    property Canvas: TCanvas read FCanvas;
  public
    constructor Create(AOwner: TWinControl; ATextDrawer: TheTextDrawer);
    destructor Destroy; override;
    procedure Assign(Src: TLazSynSurface); override;
    procedure InvalidateLines(FirstTextLine, LastTextLine: TLineIdx); override;

    function ScreenColumnToXValue(Col: integer): integer;  // map screen column to screen pixel
    function RowColumnToPixels(const RowCol: TPoint): TPoint;
    function PixelsToRowColumn(Pixels: TPoint; aFlags: TSynCoordinateMappingFlags): TPoint; // ignores scmLimitToLines

    procedure FontChanged;

    // Settings controlled by SynEdit
    property Padding[Side: TLazSynBorderSide]: integer read GetPadding write SetPadding;
    property ForegroundColor: TColor read FForegroundColor write FForegroundColor;
    property BackgroundColor: TColor read FBackgroundColor write FBackgroundColor;
    property ExtraCharSpacing: integer read FExtraCharSpacing write SetExtraCharSpacing;
    property ExtraLineSpacing: integer read FExtraLineSpacing write SetExtraLineSpacing;
    property VisibleSpecialChars: TSynVisibleSpecialChars read FVisibleSpecialChars write FVisibleSpecialChars;
    property RightEdgeColumn: integer  read FRightEdgeColumn write FRightEdgeColumn;
    property RightEdgeVisible: boolean read FRightEdgeVisible write FRightEdgeVisible;
    property RightEdgeColor: TColor    read FRightEdgeColor write FRightEdgeColor;

    property TopLine: TLinePos read FTopLine write SetTopLine; // TopView
    property LeftChar: Integer read FLeftChar write SetLeftChar;

    property TheLinesView:  TSynEditStrings       read FTheLinesView  write FTheLinesView;
    property Highlighter:   TSynCustomHighlighter read FHighlighter   write FHighlighter;
    property MarkupManager: TSynEditMarkupManager read FMarkupManager write FMarkupManager;
    property TextDrawer: TheTextDrawer read FTextDrawer;
  public
    property TextBounds: TRect read FTextBounds;

    property LineHeight: integer read FTextHeight;
    property CharWidth: integer  read FCharWidth;
    property LinesInWindow: Integer read FLinesInWindow;
    property CharsInWindow: Integer read FCharsInWindow;
    property OnStatusChange: TStatusChangeEvent read fOnStatusChange write fOnStatusChange;
  end;

  { TLazSynSurfaceManager }

  TLazSynSurfaceManager = class(TLazSynSurface)
  private
    FLeftGutterArea: TLazSynSurface;
    FLeftGutterWidth: integer;
    FRightGutterArea: TLazSynSurface;
    FRightGutterWidth: integer;
    FTextArea: TLazSynTextArea;
    procedure SetLeftGutterArea(AValue: TLazSynSurface);
    procedure SetLeftGutterWidth(AValue: integer);
    procedure SetRightGutterArea(AValue: TLazSynSurface);
    procedure SetRightGutterWidth(AValue: integer);
    procedure SetTextArea(AValue: TLazSynTextArea);
  protected
    function GetLeftGutterArea: TLazSynSurface; virtual;
    function GetRightGutterArea: TLazSynSurface; virtual;
    function GetTextArea: TLazSynTextArea; virtual;
  protected
    procedure SetBackgroundColor(AValue: TColor); virtual;
    procedure SetExtraCharSpacing(AValue: integer); virtual;
    procedure SetExtraLineSpacing(AValue: integer); virtual;
    procedure SetForegroundColor(AValue: TColor); virtual;
    procedure SetPadding(Side: TLazSynBorderSide; AValue: integer); virtual;
    procedure SetRightEdgeColor(AValue: TColor); virtual;
    procedure SetRightEdgeColumn(AValue: integer); virtual;
    procedure SetRightEdgeVisible(AValue: boolean); virtual;
    procedure SetVisibleSpecialChars(AValue: TSynVisibleSpecialChars); virtual;
    procedure SetHighlighter(AValue: TSynCustomHighlighter); virtual;
  protected
    procedure DoPaint(ACanvas: TCanvas; AClip: TRect); override;
    procedure DoDisplayViewChanged; override;
    procedure BoundsChanged; override;
  public
    constructor Create(AOwner: TWinControl);
    procedure InvalidateLines(FirstTextLine, LastTextLine: TLineIdx); override;
    procedure InvalidateTextLines(FirstTextLine, LastTextLine: TLineIdx); virtual;
    procedure InvalidateGutterLines(FirstTextLine, LastTextLine: TLineIdx); virtual;

    property TextArea:        TLazSynTextArea read GetTextArea        write SetTextArea;
    property LeftGutterArea:  TLazSynSurface  read GetLeftGutterArea  write SetLeftGutterArea;
    property RightGutterArea: TLazSynSurface  read GetRightGutterArea write SetRightGutterArea;
    property LeftGutterWidth:  integer read FLeftGutterWidth  write SetLeftGutterWidth;
    property RightGutterWidth: integer read FRightGutterWidth write SetRightGutterWidth;
  public
    // Settings forwarded to textarea
    property Padding[Side: TLazSynBorderSide]: integer write SetPadding;
    property ForegroundColor: TColor   write SetForegroundColor;
    property BackgroundColor: TColor   write SetBackgroundColor;
    property ExtraCharSpacing: integer write SetExtraCharSpacing;
    property ExtraLineSpacing: integer write SetExtraLineSpacing;
    property VisibleSpecialChars: TSynVisibleSpecialChars write SetVisibleSpecialChars;
    property RightEdgeColumn: integer  write SetRightEdgeColumn;
    property RightEdgeVisible: boolean write SetRightEdgeVisible;
    property RightEdgeColor: TColor    write SetRightEdgeColor;
    property Highlighter:   TSynCustomHighlighter write SetHighlighter;
  end;


implementation

{ TLazSynPaintTokenBreaker }

constructor TLazSynPaintTokenBreaker.Create;
begin
  FCurViewToken.Attr := TSynSelectedColor.Create;
  FMarkupTokenAttr := TSynSelectedColor.Create;
  FTabExtraByteCount := 0;
  FSpaceExtraByteCount := 0;
end;

destructor TLazSynPaintTokenBreaker.Destroy;
begin
  FreeAndNil(FCurViewToken.Attr);
  FreeAndNil(FMarkupTokenAttr);
  inherited Destroy;
end;

procedure TLazSynPaintTokenBreaker.Prepare(ADisplayView: TLazSynDisplayView;
  ALinesView: TSynEditStrings; AMarkupManager: TSynEditMarkupManager; AFirstCol,
  ALastCol: integer);
begin
  FDisplayView   := ADisplayView;
  FLinesView     := ALinesView;
  FMarkupManager := AMarkupManager;
  FFirstCol      := AFirstCol;
  FLastCol       := ALastCol;
end;

procedure TLazSynPaintTokenBreaker.SetHighlighterTokensLine(ALine: TLineIdx; out
  ARealLine: TLineIdx);
begin
  FDisplayView.SetHighlighterTokensLine(ALine, ARealLine);
  FCharWidths := FLinesView.GetPhysicalCharWidths(ARealLine);
  FCharWidthsLen := Length(FCharWidths);

  FCurViewToken.Tk.TokenLength     := 0;
  FCurViewToken.StartPos.Logical   := 1;
  FCurViewToken.StartPos.Physical  := 1; //FFirstCol;
  FCurViewToken.StartPos.Offset    := 0;
  FCurViewToken.PhysicalCharStart  := 1;
  FCurViewToken.NextPos.Physical   := 1;
  FCurViewinRTL := False;

  FCurMarkupPhysPos  := FFirstCol;
  FNextMarkupPhysPos := -1;
  FCurMarkupEOL := False;
  FCurTxtLineIdx := ARealLine;
end;

function TLazSynPaintTokenBreaker.GetNextHighlighterTokenEx(out
  ATokenInfo: TLazSynDisplayTokenInfoEx): Boolean;
const
  Space = '  ';
begin
  //GetNextHighlighterTokenFromView(ATokenInfo, -1, 1);

  if FCurMarkupPhysPos >= FNextMarkupPhysPos then
    FNextMarkupPhysPos := FMarkupManager.GetNextMarkupColAfterRowCol(FCurTxtLineIdx+1, FCurMarkupPhysPos);

  if FCurMarkupEOL
  then Result := False
  else Result := GetNextHighlighterTokenFromView(ATokenInfo, FNextMarkupPhysPos);

  if (not Result) then begin
    // the first run StartPos is set by GetNextHighlighterTokenFromView
    if FCurMarkupEOL then begin
      ATokenInfo.StartPos   := FCurMarkupNextStart
    end
    else
    if FFirstCol > ATokenInfo.StartPos.Physical then begin
      ATokenInfo.StartPos.Logical := ATokenInfo.StartPos.Logical + (FFirstCol - ATokenInfo.StartPos.Physical);
      ATokenInfo.StartPos.Physical := FFirstCol;
    end;

    FCurMarkupEOL := True;

    Result := (ATokenInfo.StartPos.Physical < FLastCol);
    if not Result then
      exit;
    assert((FNextMarkupPhysPos <= 0) or (FNextMarkupPhysPos > ATokenInfo.StartPos.Physical), 'FNextMarkupPhysPos > ATokenInfo.StartPos.Physical');

    ATokenInfo.Tk.TokenStart      := @Space[1];
    ATokenInfo.Tk.TokenLength     := 1;

    if FNextMarkupPhysPos > 0
    then ATokenInfo.EndPos.Physical    := Min(FNextMarkupPhysPos, FLastCol)
    else ATokenInfo.EndPos.Physical    := FLastCol;
    ATokenInfo.EndPos.Offset      := 0;
    ATokenInfo.EndPos.Logical     := ATokenInfo.StartPos.Logical + (ATokenInfo.EndPos.Physical - ATokenInfo.StartPos.Physical);
    FCurMarkupNextStart := ATokenInfo.EndPos;

    ATokenInfo.PhysicalCharStart  := ATokenInfo.StartPos.Physical;
    ATokenInfo.PhysicalClipStart  := ATokenInfo.StartPos.Physical;
    ATokenInfo.PhysicalCharEnd    := ATokenInfo.EndPos.Physical;
    ATokenInfo.PhysicalClipEnd    := ATokenInfo.EndPos.Physical;
    ATokenInfo.IsRtl              := False;
    FMarkupTokenAttr.Clear;
    FMarkupTokenAttr.Foreground := FForegroundColor;
    FMarkupTokenAttr.Background := FBackgroundColor;

    ATokenInfo.ExpandedExtraBytes := 0;
    ATokenInfo.HasDoubleWidth     := False; // TODO: True, but needs charwidth for painter
    //exit;
  end
  else begin
    FMarkupTokenAttr.Assign(ATokenInfo.Attr);
    FMarkupTokenAttr.CurrentStartX := ATokenInfo.StartPos.Physical; // current sub-token
    FMarkupTokenAttr.CurrentEndX   := ATokenInfo.EndPos.Physical-1;
  end;

  FCurMarkupPhysPos := ATokenInfo.EndPos.Physical;

  fMarkupManager.MergeMarkupAttributeAtRowCol(FCurTxtLineIdx + 1,
    ATokenInfo.StartPos, ATokenInfo.EndPos, ATokenInfo.IsRtl, FMarkupTokenAttr);

  ATokenInfo.Attr := FMarkupTokenAttr;
  // Deal with equal colors
  if (FMarkupTokenAttr.Background = FMarkupTokenAttr.Foreground) then begin // or if diff(gb,fg) < x
    if FMarkupTokenAttr.Background = BackgroundColor then
      FMarkupTokenAttr.Foreground := not(FMarkupTokenAttr.Background) and $00ffffff // or maybe ForegroundColor ?
    else
      FMarkupTokenAttr.Foreground := BackgroundColor;
  end;

  // Todo merge attribute

end;

function TLazSynPaintTokenBreaker.GetNextHighlighterTokenFromView(out
  ATokenInfo: TLazSynDisplayTokenInfoEx; APhysEnd: Integer; ALogEnd: Integer): Boolean;

  procedure InitSynAttr(var ATarget: TSynSelectedColor; ASource: TSynHighlighterAttributes;
    AnAttrStartX: Integer);
  begin
    ATarget.Clear;
    if Assigned(ASource) then begin
      ATarget.Assign(ASource);
      if ATarget.Foreground = clNone then
        ATarget.Foreground := ForegroundColor;
      if ATarget.Background = clNone then
        ATarget.Background := BackgroundColor;
    end else
    begin
      ATarget.Foreground := ForegroundColor;
      ATarget.Background := BackgroundColor;
      ATarget.Style :=  []; // Font.Style; // currently always cleared
    end;
    ATarget.MergeFinalStyle := True;
    ATarget.StyleMask  := [];
    FCurViewToken.Attr.StartX := AnAttrStartX;
    ATarget.EndX   := -1; //PhysicalStartPos + TokenCharLen - 1;
  end;

  function MaybeFetchToken: Boolean; inline;
  begin
    Result := FCurViewToken.Tk.TokenLength > 0;
    if Result or (FCurViewToken.Tk.TokenLength < 0) then exit;
    FCurViewTokenViewPhysStart := FCurViewToken.PhysicalCharStart;
    while FCurViewToken.Tk.TokenLength = 0 do begin // Todo: is SyncroEd-test a zero size token is returned
      Result := FDisplayView.GetNextHighlighterToken(FCurViewToken.Tk);
      if not Result then begin
        FCurViewToken.Tk.TokenLength := -1;
        exit;
      end;
      // Todo: concatenate with next token, if possible (only, if reaching token end)
    end;
  end;

  function GetCharWidthData(AIdx: Integer): TPhysicalCharWidth; inline;
  begin
    if AIdx >= FCharWidthsLen
    then Result := 1
    else Result := FCharWidths[AIdx];
  end;

  Procedure AdjustCurTokenLogStart(ANewLogStart: Integer); inline;
  // ANewLogStart = 1 based
  var
    j: integer;
  begin
    j := (ANewLogStart - FCurViewToken.StartPos.Logical);
    FCurViewToken.Tk.TokenLength := FCurViewToken.Tk.TokenLength - j;
    FCurViewToken.Tk.TokenStart  := FCurViewToken.Tk.TokenStart + j;
    FCurViewToken.StartPos.Logical   := ANewLogStart;
  end;

  procedure SkipLtrBeforeFirstCol(var ALogicIdx: integer; ALogicEnd: Integer); inline;
  var
    j: Integer;
    pcw: TPhysicalCharWidth;
  begin
    if  (FCurViewToken.PhysicalCharStart >= FFirstCol) then
      exit;

    pcw := GetCharWidthData(ALogicIdx);
    if (pcw and PCWFlagRTL <> 0) then exit;

    j := (pcw and PCWMask);
    while (ALogicIdx < ALogicEnd) and (FCurViewToken.PhysicalCharStart + j <= FFirstCol) and
          (pcw and PCWFlagRTL = 0)
    do begin
      inc(FCurViewToken.PhysicalCharStart, j);
      repeat
        inc(ALogicIdx);
      until (ALogicIdx >= ALogicEnd) or
            (ALogicIdx >= FCharWidthsLen) or ((FCharWidths[ALogicIdx] and PCWMask) <> 0);

      pcw := GetCharWidthData(ALogicIdx);
      j := pcw and PCWMask;
    end;

    if ALogicIdx <> FCurViewToken.StartPos.Logical - 1 then begin
      AdjustCurTokenLogStart(ALogicIdx + 1);
      assert(FCurViewToken.Tk.TokenLength >= 0, 'FCurViewToken.Tk.TokenLength > 0');
    end;

    if FCurViewToken.PhysicalCharStart > FCurViewToken.StartPos.Physical then
      FCurViewToken.StartPos.Physical := FCurViewToken.PhysicalCharStart;
    if (FCurViewToken.StartPos.Physical < FFirstCol) and (ALogicIdx < FCharWidthsLen) then
      FCurViewToken.StartPos.Physical := FFirstCol;
  end;

  procedure SkipRtlOffScreen(var ALogicIdx: integer; ALogicEnd: Integer); inline;
  var
    j: Integer;
    pcw: TPhysicalCharWidth;
  begin
    if  (FCurViewToken.PhysicalCharStart <= FFirstCol) then begin
// TODO: end, if FCurViewRtlPhysEnd >= FLastCol;
      if ALogicIdx + FCurViewToken.Tk.TokenLength < FCurViewRtlLogEnd then begin
        if FCurViewToken.Tk.TokenLength > 0 then begin
          FCurViewToken.StartPos.Logical := FCurViewToken.StartPos.Logical + FCurViewToken.Tk.TokenLength;
          FCurViewToken.Tk.TokenLength := 0;
        end;
      end
      else begin
        j :=  FCurViewRtlLogEnd - ALogicIdx;
        FCurViewToken.StartPos.Logical   := FCurViewToken.StartPos.Logical + j;
        FCurViewToken.Tk.TokenStart  := FCurViewToken.Tk.TokenStart + j;
        FCurViewToken.Tk.TokenLength := FCurViewToken.Tk.TokenLength - j;
        ALogicIdx := ALogicIdx + j;
        FCurViewToken.PhysicalCharStart      := FCurViewRtlPhysEnd;
        FCurViewToken.StartPos.Physical := FCurViewRtlPhysEnd;
        assert(FCurViewToken.StartPos.Logical - 1 = FCurViewRtlLogEnd, 'SkipRtlOffScreen: FCurViewToken.StartPos.Logical = FCurViewRtlLogEnd');
      end;
      exit;
    end;

    if  (FCurViewToken.PhysicalCharStart <= FLastCol) then
      exit;

    pcw := GetCharWidthData(ALogicIdx);
    if (pcw and PCWFlagRTL = 0) then exit;

    j := (pcw and PCWMask);
    while (ALogicIdx < ALogicEnd) and (FCurViewToken.PhysicalCharStart - j >= FLastCol) and
          (pcw and PCWFlagRTL <> 0)
    do begin
      dec(FCurViewToken.PhysicalCharStart, j);
      repeat
        inc(ALogicIdx);
      until (ALogicIdx >= ALogicEnd) or
            (ALogicIdx >= FCharWidthsLen) or ((FCharWidths[ALogicIdx] and PCWMask) <> 0);

      pcw := GetCharWidthData(ALogicIdx);
      j := pcw and PCWMask;
    end;

    if ALogicIdx <> FCurViewToken.StartPos.Logical - 1 then begin
      AdjustCurTokenLogStart(ALogicIdx + 1);
      assert(FCurViewToken.Tk.TokenLength >= 0, 'FCurViewToken.Tk.TokenLength > 0');
    end;
    if FCurViewToken.StartPos.Physical > FLastCol then
      FCurViewToken.StartPos.Physical := FLastCol;
  end;

  procedure ChangeToRtl(ALogicIdx, ALogicEnd: Integer);
  var
    RtlRunPhysWidth, j: Integer;
    pcw: TPhysicalCharWidth;
  begin
    pcw := GetCharWidthData(ALogicIdx);

    RtlRunPhysWidth := 0;
    j := (pcw and PCWMask);
    while (ALogicIdx < ALogicEnd) and (pcw and PCWFlagRTL <> 0) do begin
      inc(RtlRunPhysWidth, j);
      repeat
        inc(ALogicIdx);
      until (ALogicIdx >= ALogicEnd) or
            (ALogicIdx >= FCharWidthsLen) or ((FCharWidths[ALogicIdx] and PCWMask) <> 0);

      pcw := GetCharWidthData(ALogicIdx);
      j := pcw and PCWMask;
    end;

    FCurViewinRTL := True;
    FCurViewRTLLogEnd  := ALogicIdx;
    FCurViewRtlPhysEnd := FCurViewToken.PhysicalCharStart + RtlRunPhysWidth;
    FCurViewToken.PhysicalCharStart      := FCurViewRtlPhysEnd;
    FCurViewToken.StartPos.Physical := FCurViewRtlPhysEnd;
  end;

  function MaybeChangeToRtl(ALogicIdx, ALogicEnd: Integer): boolean; inline;
  begin
    Result := (GetCharWidthData(ALogicIdx) and PCWFlagRTL) <> 0;
    if Result then
      ChangeToRtl(ALogicIdx, ALogicEnd);
  end;

  procedure ChangeToLtr(ALogicIdx, ALogicEnd: Integer);
  begin
    FCurViewinRTL := False;
    FCurViewToken.PhysicalCharStart      := FCurViewRtlPhysEnd;
    FCurViewToken.StartPos.Physical := FCurViewRtlPhysEnd;
  end;

  function MaybeChangeToLtr(ALogicIdx, ALogicEnd: Integer): boolean; inline;
  begin
    Result := (GetCharWidthData(ALogicIdx) and PCWFlagRTL) = 0;
    if Result then
      ChangeToLtr(ALogicIdx, ALogicEnd);
  end;

  //procedure SetEOLResult;
  //begin
  //        ATokenInfo.StartPos           := FCurViewToken.StartPos;
  //end;

var
  i, j: Integer;
  pcw: TPhysicalCharWidth;
  c: Char;
  LogicIdx, LogicEnd, PhysPos: Integer;
  PrevLogicIdx, PrevPhysPos: Integer;
  PhysTokenStop: Integer;
  TabExtra: Integer;
  HasDouble: Boolean;
begin
  while True do begin
    Result := MaybeFetchToken;    // Get token from View/Highlighter
    if not Result then begin
      ATokenInfo.StartPos           := FCurViewToken.StartPos;
      exit;
    end;

    LogicIdx := FCurViewToken.StartPos.Logical - 1;
    LogicEnd := LogicIdx + FCurViewToken.Tk.TokenLength;
    assert(GetCharWidthData(LogicIdx)<>0, 'GetNextHighlighterTokenFromView: Token starts with char');

    case FCurViewinRTL of
      False: // Left To Right
        begin
          SkipLtrBeforeFirstCol(LogicIdx, LogicEnd);    // Skip out of screen
          if FCurViewToken.Tk.TokenLength = 0 then
            continue;  // Get NEXT token

          if MaybeChangeToRtl(LogicIdx, LogicEnd) then
            continue;

          if APhysEnd > 0
          then PhysTokenStop := Min(FLastCol, APhysEnd)
          else PhysTokenStop := FLastCol;
          // TODO: APhysEnd should always allow some data. Compare with FLastCol? Assert for APhysEnd
          Result := PhysTokenStop > FCurViewToken.StartPos.Physical;
          if not Result then begin
            ATokenInfo.StartPos           := FCurViewToken.StartPos;
            exit;
          end;

          // Find end according to PhysTokenStop
          PhysPos      := FCurViewToken.PhysicalCharStart;
          PrevLogicIdx := LogicIdx;
          PrevPhysPos  := PhysPos;
          HasDouble := False;
          TabExtra      := 0; // Extra bytes needed for expanded Tab/Space(utf8 visible space/dot)
          i := 0;

          if (ALogEnd > 0) and (LogicEnd >= ALogEnd) then
            LogicEnd := ALogEnd - 1;

          pcw := GetCharWidthData(LogicIdx);
          while (LogicIdx < LogicEnd) and (PhysPos < PhysTokenStop) and
                (pcw and PCWFlagRTL = 0)
          do begin
            j := pcw and PCWMask;

            PrevLogicIdx := LogicIdx;
            PrevPhysPos  := PhysPos;
            inc(PhysPos, j);
            if j <> 0 then begin
              c := (FCurViewToken.Tk.TokenStart + i)^;
              if c = #9  then
                inc(TabExtra, j-1 + FTabExtraByteCount)
              else
              if j > 1 then
                HasDouble := True;
              if c = ' ' then
                inc(TabExtra, FSpaceExtraByteCount);
            end;

            repeat
              inc(LogicIdx);
              inc(i);
            until (LogicIdx >= FCharWidthsLen) or
                  (LogicIdx >= LogicEnd) or ((FCharWidths[LogicIdx] and PCWMask) <> 0);
            pcw := GetCharWidthData(LogicIdx);
          end;
          Assert((PhysPos > FCurViewToken.PhysicalCharStart) or (ALogEnd > 0), 'PhysPos > FCurViewToken.PhysicalCharStart');

          ATokenInfo.Tk                 := FCurViewToken.Tk;
          ATokenInfo.Tk.TokenLength     := LogicIdx + 1 - FCurViewToken.StartPos.Logical;

          ATokenInfo.StartPos           := FCurViewToken.StartPos;
          ATokenInfo.StartPos.Offset    := ATokenInfo.StartPos.Physical - FCurViewToken.PhysicalCharStart; // >= 0

          ATokenInfo.EndPos.Logical     := LogicIdx + 1;
          ATokenInfo.EndPos.Physical    := Min(PhysPos, PhysTokenStop);
          ATokenInfo.EndPos.Offset      := ATokenInfo.EndPos.Physical - PhysPos; // Zero or Negative. Paint ends before Logical

          ATokenInfo.PhysicalCharStart  := FCurViewToken.PhysicalCharStart;
          ATokenInfo.PhysicalClipStart  := ATokenInfo.StartPos.Physical;
          ATokenInfo.PhysicalCharEnd    := PhysPos;
          ATokenInfo.PhysicalClipEnd    := ATokenInfo.EndPos.Physical;
          ATokenInfo.IsRtl              := False;
          ATokenInfo.Attr               := FCurViewToken.Attr;

          ATokenInfo.ExpandedExtraBytes := TabExtra;
          ATokenInfo.HasDoubleWidth     := HasDouble;
          assert(FCurViewToken.StartPos.Offset >= 0, 'FCurViewToken.StartPos.Offset >= 0');
          assert(FCurViewToken.EndPos.Offset   <= 0, 'FCurViewToken.EndPos.Offset <= 0');

          if PhysPos > PhysTokenStop then begin      // Last char goes over paint boundary
            LogicIdx := PrevLogicIdx;
            PhysPos  := PrevPhysPos;
          end
          else
            PhysTokenStop := PhysPos;
          AdjustCurTokenLogStart(LogicIdx + 1);
          FCurViewToken.PhysicalCharStart   := PhysPos;
          if PhysTokenStop > FCurViewToken.StartPos.Physical  then
            FCurViewToken.StartPos.Physical := PhysTokenStop;

          assert(FCurViewToken.Tk.TokenLength >= 0, 'FCurViewToken.Tk.TokenLength >= 0');

          InitSynAttr(FCurViewToken.Attr, FCurViewToken.Tk.TokenAttr, FCurViewTokenViewPhysStart);
          if FCurViewToken.Tk.TokenLength = 0 then
            ATokenInfo.Attr.EndX := PhysPos-1;

          MaybeFetchToken;
          if MaybeChangeToRtl(LogicIdx, LogicEnd) then begin // get NextTokenPhysStart
            SkipRtlOffScreen(LogicIdx, LogicEnd);
            while FCurViewToken.Tk.TokenLength = 0 do
              if MaybeFetchToken then
                SkipRtlOffScreen(LogicIdx, LogicEnd);
          end;

          ATokenInfo.NextPos.Physical := FCurViewToken.StartPos.Physical;
          ATokenInfo.NextPos.Logical  := FCurViewToken.StartPos.Logical;
          ATokenInfo.NextPos.Offset   := FCurViewToken.StartPos.Physical - FCurViewToken.PhysicalCharStart;
          ATokenInfo.NextIsRtl        := FCurViewinRTL;

          break;
        end; // case FCurViewinRTL = False;
      True: // Right To Left
        begin
          SkipRtlOffScreen(LogicIdx, LogicEnd);
          if FCurViewToken.Tk.TokenLength = 0 then
            continue;  // Get NEXT token

          if MaybeChangeToLtr(LogicIdx, LogicEnd) then
            continue;

          if APhysEnd >= FCurViewRtlPhysEnd
          then PhysTokenStop := FFirstCol
          else PhysTokenStop := Max(FFirstCol, APhysEnd);
          // TODO: APhysEnd should always allow some data. Assert for APhysEnd
          // FFirstCol must be less PPS. Otherwise it would have gone LTR
//          Result := PhysTokenStop < FCurViewToken.StartPos.Physical;
//          if not Result then exit;

          // Find end according to PhysTokenStop
          PhysPos      := FCurViewToken.PhysicalCharStart;
          PrevLogicIdx := LogicIdx;
          PrevPhysPos  := PhysPos;
          HasDouble := False;
          TabExtra      := 0; // Extra bytes needed for expanded Tab/Space(utf8 visible space/dot)
          i := 0;

          if (ALogEnd > 0) and (LogicEnd >= ALogEnd) then
            LogicEnd := ALogEnd - 1;

          pcw := GetCharWidthData(LogicIdx);
          while (LogicIdx < LogicEnd) and (PhysPos > PhysTokenStop) and
                (pcw and PCWFlagRTL <> 0)
          do begin
            j := pcw and PCWMask;

            PrevLogicIdx := LogicIdx;
            PrevPhysPos  := PhysPos;
            dec(PhysPos, j);
            if j <> 0 then begin
              c := (FCurViewToken.Tk.TokenStart + i)^;
              if c = #9  then
                inc(TabExtra, j-1 + FTabExtraByteCount)
              else
              if j > 1 then
                HasDouble := True;
              if c = ' ' then
                inc(TabExtra, FSpaceExtraByteCount);
            end;

            repeat
              inc(LogicIdx);
              inc(i);
            until (LogicIdx >= FCharWidthsLen) or
                  (LogicIdx >= LogicEnd) or ((FCharWidths[LogicIdx] and PCWMask) <> 0);
            pcw := GetCharWidthData(LogicIdx);
          end;
          Assert((PhysPos < FCurViewToken.PhysicalCharStart) or (ALogEnd > 0), 'PhysPos > FCurViewToken.PhysicalCharStart');

          ATokenInfo.Tk                 := FCurViewToken.Tk;
          ATokenInfo.Tk.TokenLength     := LogicIdx + 1 - FCurViewToken.StartPos.Logical;

          ATokenInfo.StartPos           := FCurViewToken.StartPos;
          //ATokenInfo.StartPos.Logical   := LogicIdx + 1;
          //ATokenInfo.StartPos.Physical  := ATokenInfo.StartPos.Physical;
          ATokenInfo.StartPos.Offset    := FCurViewToken.PhysicalCharStart - ATokenInfo.StartPos.Physical; //  >= 0

          ATokenInfo.EndPos.Logical     := LogicIdx + 1;
          ATokenInfo.EndPos.Physical    := Max(PhysPos, PhysTokenStop);
          ATokenInfo.EndPos.Offset      := PhysPos - ATokenInfo.EndPos.Physical; //  <= 0

          ATokenInfo.PhysicalCharStart  := PhysPos;
          ATokenInfo.PhysicalClipStart  := ATokenInfo.EndPos.Physical;
          ATokenInfo.PhysicalCharEnd    := FCurViewToken.PhysicalCharStart;
          ATokenInfo.PhysicalClipEnd    := ATokenInfo.StartPos.Physical;
          ATokenInfo.IsRtl              := True;
          ATokenInfo.Attr               := FCurViewToken.Attr;

          ATokenInfo.ExpandedExtraBytes := TabExtra;
          ATokenInfo.HasDoubleWidth     := HasDouble;
          assert(FCurViewToken.StartPos.Offset <= 0, 'FCurViewToken.StartPos.Offset >= 0');
          assert(FCurViewToken.EndPos.Offset   >= 0, 'FCurViewToken.EndPos.Offset <= 0');

          if (PhysPos < PhysTokenStop) and (PhysTokenStop > FFirstCol) then begin      // Last char goes over paint boundary
            LogicIdx := PrevLogicIdx;
            PhysPos  := PrevPhysPos;
          end
          else
            PhysTokenStop := Max(PhysPos, PhysTokenStop);

          AdjustCurTokenLogStart(LogicIdx + 1);
          FCurViewToken.PhysicalCharStart   := PhysPos;
          if PhysTokenStop < FCurViewToken.StartPos.Physical then
            FCurViewToken.StartPos.Physical := PhysTokenStop;

          assert(FCurViewToken.Tk.TokenLength >= 0, 'FCurViewToken.Tk.TokenLength >= 0');

          InitSynAttr(FCurViewToken.Attr, FCurViewToken.Tk.TokenAttr, FCurViewTokenViewPhysStart);
          if FCurViewToken.Tk.TokenLength = 0 then
            ATokenInfo.Attr.EndX := PhysPos-1;

          MaybeFetchToken;
          SkipRtlOffScreen(LogicIdx, LogicEnd);
          while FCurViewToken.Tk.TokenLength = 0 do
            if MaybeFetchToken then
              SkipRtlOffScreen(LogicIdx, LogicEnd);
          MaybeChangeToLtr(LogicIdx, LogicEnd);  // get NextTokenPhysStart

          // If the next token is RTL, then NextPos is the next EndPos
          ATokenInfo.NextPos.Physical := FCurViewToken.StartPos.Physical;
          ATokenInfo.NextPos.Logical  := FCurViewToken.StartPos.Logical;
          ATokenInfo.NextPos.Offset   := FCurViewToken.PhysicalCharStart - FCurViewToken.StartPos.Physical;
          ATokenInfo.NextIsRtl        := FCurViewinRTL;

          break;
        end; // case FCurViewinRTL = True;
    end;


  end; // while True
end;

{ TLazSynSurfaceManager }

procedure TLazSynSurfaceManager.SetLeftGutterWidth(AValue: integer);
begin
  if FLeftGutterWidth = AValue then Exit;
  FLeftGutterWidth := AValue;
  BoundsChanged;
end;

procedure TLazSynSurfaceManager.SetPadding(Side: TLazSynBorderSide; AValue: integer);
begin
  FTextArea.Padding[Side] := AValue;
end;

procedure TLazSynSurfaceManager.SetRightEdgeColor(AValue: TColor);
begin
  FTextArea.RightEdgeColor := AValue;
end;

procedure TLazSynSurfaceManager.SetRightEdgeColumn(AValue: integer);
begin
  FTextArea.RightEdgeColumn := AValue;
end;

procedure TLazSynSurfaceManager.SetRightEdgeVisible(AValue: boolean);
begin
  FTextArea.RightEdgeVisible := AValue;
end;

procedure TLazSynSurfaceManager.SetLeftGutterArea(AValue: TLazSynSurface);
begin
  if FLeftGutterArea = AValue then Exit;
  FLeftGutterArea := AValue;
  FLeftGutterArea.DisplayView := DisplayView;
end;

function TLazSynSurfaceManager.GetLeftGutterArea: TLazSynSurface;
begin
  Result := FLeftGutterArea;
end;

function TLazSynSurfaceManager.GetRightGutterArea: TLazSynSurface;
begin
  Result := FRightGutterArea;
end;

function TLazSynSurfaceManager.GetTextArea: TLazSynTextArea;
begin
  Result := FTextArea;
end;

procedure TLazSynSurfaceManager.SetBackgroundColor(AValue: TColor);
begin
  FTextArea.BackgroundColor := AValue;
end;

procedure TLazSynSurfaceManager.SetExtraCharSpacing(AValue: integer);
begin
  FTextArea.ExtraCharSpacing := AValue;
end;

procedure TLazSynSurfaceManager.SetExtraLineSpacing(AValue: integer);
begin
  FTextArea.ExtraLineSpacing := AValue;
end;

procedure TLazSynSurfaceManager.SetForegroundColor(AValue: TColor);
begin
  FTextArea.ForegroundColor := AValue;
end;

procedure TLazSynSurfaceManager.SetRightGutterArea(AValue: TLazSynSurface);
begin
  if FRightGutterArea = AValue then Exit;
  FRightGutterArea := AValue;
  FRightGutterArea.DisplayView := DisplayView;
end;

procedure TLazSynSurfaceManager.SetRightGutterWidth(AValue: integer);
begin
  if FRightGutterWidth = AValue then Exit;
  FRightGutterWidth := AValue;
  BoundsChanged;
end;

procedure TLazSynSurfaceManager.SetTextArea(AValue: TLazSynTextArea);
begin
  if FTextArea = AValue then Exit;
  FTextArea := AValue;
  FTextArea.DisplayView := DisplayView;
end;

procedure TLazSynSurfaceManager.SetVisibleSpecialChars(AValue: TSynVisibleSpecialChars);
begin
  FTextArea.VisibleSpecialChars := AValue;
end;

procedure TLazSynSurfaceManager.SetHighlighter(AValue: TSynCustomHighlighter);
begin
  FTextArea.Highlighter := AValue;
end;

procedure TLazSynSurfaceManager.DoPaint(ACanvas: TCanvas; AClip: TRect);
begin
  FLeftGutterArea.Paint(ACanvas, AClip);
  FTextArea.Paint(ACanvas, AClip);
  FRightGutterArea.Paint(ACanvas, AClip);
end;

procedure TLazSynSurfaceManager.DoDisplayViewChanged;
begin
  FLeftGutterArea.DisplayView  := DisplayView;
  FRightGutterArea.DisplayView := DisplayView;
  FTextArea.DisplayView        := DisplayView;
end;

procedure TLazSynSurfaceManager.BoundsChanged;
var
  l, r: Integer;
begin
  r := Max(Left, Right - RightGutterWidth);
  l := Min(r, Left + LeftGutterWidth);
  FLeftGutterArea.SetBounds(Top, Left, Bottom, l);
  FTextArea.SetBounds(Top, l, Bottom, r);
  FRightGutterArea.SetBounds(Top, r, Bottom, Right);
end;

constructor TLazSynSurfaceManager.Create(AOwner: TWinControl);
begin
  inherited Create(AOwner);
  FLeftGutterWidth := 0;
  FRightGutterWidth := 0;
end;

procedure TLazSynSurfaceManager.InvalidateLines(FirstTextLine, LastTextLine: TLineIdx);
var
  rcInval: TRect;
begin
  rcInval := Bounds;
  if (FirstTextLine >= 0) then
    rcInval.Top := Max(TextArea.TextBounds.Top,
                       TextArea.TextBounds.Top
                       + (DisplayView.TextToViewIndex(FirstTextLine).Top
                          - TextArea.TopLine + 1) * TextArea.LineHeight);
  if (LastTextLine >= 0) then
    rcInval.Bottom := Min(TextArea.TextBounds.Bottom,
                          TextArea.TextBounds.Top
                          + (DisplayView.TextToViewIndex(LastTextLine).Bottom
                             - TextArea.TopLine + 2)  * TextArea.LineHeight);

  {$IFDEF VerboseSynEditInvalidate}
  DebugLn(['TCustomSynEdit.InvalidateGutterLines ',DbgSName(self), ' FirstLine=',FirstTextLine, ' LastLine=',LastTextLine, ' rect=',dbgs(rcInval)]);
  {$ENDIF}
  if (rcInval.Top < rcInval.Bottom) and (rcInval.Left < rcInval.Right) then
    InvalidateRect(Handle, @rcInval, FALSE);
end;

procedure TLazSynSurfaceManager.InvalidateTextLines(FirstTextLine, LastTextLine: TLineIdx);
begin
  FTextArea.InvalidateLines(FirstTextLine, LastTextLine);
end;

procedure TLazSynSurfaceManager.InvalidateGutterLines(FirstTextLine, LastTextLine: TLineIdx);
begin
  FLeftGutterArea.InvalidateLines(FirstTextLine, LastTextLine);
  FRightGutterArea.InvalidateLines(FirstTextLine, LastTextLine);
end;

{ TLazSynTextArea }

function TLazSynTextArea.GetPadding(Side: TLazSynBorderSide): integer;
begin
  Result := FPadding[Side];
end;

procedure TLazSynTextArea.SetExtraCharSpacing(AValue: integer);
begin
  if FExtraCharSpacing = AValue then Exit;
  FExtraCharSpacing := AValue;
  FontChanged;
end;

procedure TLazSynTextArea.SetExtraLineSpacing(AValue: integer);
begin
  if FExtraLineSpacing = AValue then Exit;
  FExtraLineSpacing := AValue;
  FTextHeight := FTextDrawer.CharHeight + FExtraLineSpacing;
  FontChanged;
end;

procedure TLazSynTextArea.SetLeftChar(AValue: Integer);
begin
  if FLeftChar = AValue then Exit;
  FLeftChar := AValue;
end;

procedure TLazSynTextArea.SetPadding(Side: TLazSynBorderSide; AValue: integer);
begin
  FPadding[Side] := AValue;
  case Side of
    bsLeft:   FTextBounds.Left   := Left + FPadding[bsLeft];
    bsTop:    FTextBounds.Top    := Top + FPadding[bsTop];
    bsRight:  FTextBounds.Right  := Right - FPadding[bsRight];
    bsBottom: FTextBounds.Bottom := Bottom - FPadding[bsBottom];
  end;
  FontChanged;
end;

procedure TLazSynTextArea.SetTopLine(AValue: TLinePos);
begin
  if AValue < 1 then AValue := 1;
  if FTopLine = AValue then Exit;
  FTopLine := AValue;
end;

procedure TLazSynTextArea.DoDrawerFontChanged(Sender: TObject);
begin
  FontChanged;
end;

procedure TLazSynTextArea.BoundsChanged;
begin
  FTextBounds.Left   := Left + FPadding[bsLeft];
  FTextBounds.Top    := Top + FPadding[bsTop];
  FTextBounds.Right  := Right - FPadding[bsRight];
  FTextBounds.Bottom := Bottom - FPadding[bsBottom];
  FontChanged;
end;

function TLazSynTextArea.ScreenColumnToXValue(Col: integer): integer;
begin
  Result := FTextBounds.Left + (Col - LeftChar) * fCharWidth;
end;

function TLazSynTextArea.RowColumnToPixels(const RowCol: TPoint): TPoint;
begin
  // Inludes LeftChar, but not Topline
  Result.X := FTextBounds.Left + (RowCol.X - LeftChar) * CharWidth;
  Result.Y := FTextBounds.Top + RowCol.Y * LineHeight;
end;

function TLazSynTextArea.PixelsToRowColumn(Pixels: TPoint;
  aFlags: TSynCoordinateMappingFlags): TPoint;
begin
  // Inludes LeftChar, but not Topline
  Result.X := (Pixels.X
               - FTextBounds.Left
               + (CharWidth div 2)  // nearest side of char
              ) div CharWidth
              + LeftChar;
  Result.Y := (Pixels.Y - FTextBounds.Top) div LineHeight;

  if (not(scmIncludePartVisible in aFlags)) and (Result.Y >= LinesInWindow) then begin
    // don't return a partially visible last line
    Result.Y := LinesInWindow - 1;
  end;
  if Result.X < 0 then Result.X := 0;
  if Result.Y < 0 then Result.Y := 0;
end;

constructor TLazSynTextArea.Create(AOwner: TWinControl; ATextDrawer: TheTextDrawer);
var
  i: TLazSynBorderSide;
begin
  inherited Create(AOwner);
  FTokenBreaker := TLazSynPaintTokenBreaker.Create;
  FTextDrawer := ATextDrawer;
  FTextDrawer.RegisterOnFontChangeHandler(@DoDrawerFontChanged);
  FPaintLineColor := TSynSelectedColor.Create;
  FPaintLineColor2 := TSynSelectedColor.Create;
  for i := low(TLazSynBorderSide) to high(TLazSynBorderSide) do
    FPadding[i] := 0;
  FTopLine := 1;
  FLeftChar := 1;
  FRightEdgeColumn  := 80;
  FRightEdgeVisible := True;
  FRightEdgeColor   := clSilver;
  FontChanged;
end;

destructor TLazSynTextArea.Destroy;
begin
  FreeAndNil(FTokenBreaker);
  FTextDrawer.UnRegisterOnFontChangeHandler(@DoDrawerFontChanged);
  FreeAndNil(FPaintLineColor);
  FreeAndNil(FPaintLineColor2);
  inherited Destroy;
end;

procedure TLazSynTextArea.Assign(Src: TLazSynSurface);
var
  i: TLazSynBorderSide;
begin
  inherited Assign(Src);

  FTextDrawer    := TLazSynTextArea(Src).FTextDrawer;
  FTheLinesView  := TLazSynTextArea(Src).FTheLinesView;
  DisplayView   := TLazSynTextArea(Src).DisplayView;
  FHighlighter   := TLazSynTextArea(Src).FHighlighter;
  FMarkupManager := TLazSynTextArea(Src).FMarkupManager;
  FForegroundColor := TLazSynTextArea(Src).FForegroundColor;
  FBackgroundColor := TLazSynTextArea(Src).FBackgroundColor;
  FRightEdgeColor  := TLazSynTextArea(Src).FRightEdgeColor;

  FExtraCharSpacing := TLazSynTextArea(Src).FExtraCharSpacing;
  FExtraLineSpacing := TLazSynTextArea(Src).FExtraLineSpacing;
  FVisibleSpecialChars := TLazSynTextArea(Src).FVisibleSpecialChars;
  FRightEdgeColumn := TLazSynTextArea(Src).FRightEdgeColumn;
  FRightEdgeVisible := TLazSynTextArea(Src).FRightEdgeVisible;

  for i := low(TLazSynBorderSide) to high(TLazSynBorderSide) do
    FPadding[i] := TLazSynTextArea(Src).FPadding[i];

  FTopLine := TLazSynTextArea(Src).FTopLine;
  FLeftChar := TLazSynTextArea(Src).FLeftChar;

  BoundsChanged;
end;

procedure TLazSynTextArea.InvalidateLines(FirstTextLine, LastTextLine: TLineIdx);
var
  rcInval: TRect;
begin
  rcInval := Bounds;
  if (FirstTextLine >= 0) then
    rcInval.Top := Max(TextBounds.Top,
                       TextBounds.Top
                       + (DisplayView.TextToViewIndex(FirstTextLine).Top
                          - TopLine + 1) * LineHeight);
  if (LastTextLine >= 0) then
    rcInval.Bottom := Min(TextBounds.Bottom,
                          TextBounds.Top
                          + (DisplayView.TextToViewIndex(LastTextLine).Bottom
                             - TopLine + 2)  * LineHeight);

  {$IFDEF VerboseSynEditInvalidate}
  DebugLn(['TCustomSynEdit.InvalidateTextLines ',DbgSName(self), ' FirstLine=',FirstTextLine, ' LastLine=',LastTextLine, ' rect=',dbgs(rcInval)]);
  {$ENDIF}
  if (rcInval.Top < rcInval.Bottom) and (rcInval.Left < rcInval.Right) then
    InvalidateRect(Handle, @rcInval, FALSE);
end;

procedure TLazSynTextArea.FontChanged;
var
  OldChars, OldLines: Integer;
  Chg: TSynStatusChanges;
begin
  // ToDo: wait for handle creation
  // Report FLinesInWindow=-1 if no handle
  FCharWidth := FTextDrawer.CharWidth;  // includes extra
  FTextHeight := FTextDrawer.CharHeight + FExtraLineSpacing;

  OldChars := FCharsInWindow;
  OldLines := FLinesInWindow;
  FCharsInWindow :=  0;
  FLinesInWindow :=  0;
  if FCharWidth > 0 then
    FCharsInWindow := Max(0, (FTextBounds.Right - FTextBounds.Left) div FCharWidth);
  if FTextHeight > 0 then
    FLinesInWindow := Max(0, (FTextBounds.Bottom - FTextBounds.Top) div FTextHeight);

  if assigned(fOnStatusChange) then begin
    Chg := [];
    if OldChars <> FCharsInWindow then
      Chg := Chg + [scCharsInWindow];
    if OldLines <> FLinesInWindow then
      Chg := Chg + [scLinesInWindow];
    if (Chg <> []) then
      fOnStatusChange(Self, Chg);
  end;
end;

procedure TLazSynTextArea.DoPaint(ACanvas: TCanvas; AClip: TRect);
var
  PadRect, PadRect2: TRect;
  ScreenRow1, ScreenRow2, TextColumn1, TextColumn2: integer;
  dc: HDC;
begin

  // paint padding
  FCanvas := ACanvas;
  dc := ACanvas.Handle;
  SetBkColor(dc, ColorToRGB(BackgroundColor));

  if (AClip.Top < FTextBounds.Top) then begin
    PadRect2 := Bounds;
    PadRect2.Bottom := FTextBounds.Top;
    IntersectRect(PadRect{%H-}, AClip, PadRect2);
    InternalFillRect(dc, PadRect);
  end;
  if (AClip.Bottom > FTextBounds.Bottom) then begin
    PadRect2 := Bounds;
    PadRect2.Top := FTextBounds.Bottom;
    IntersectRect(PadRect, AClip, PadRect2);
    InternalFillRect(dc, PadRect);
  end;
  if (AClip.Left < FTextBounds.Left) then begin
    PadRect2 := Bounds;
    PadRect2.Right := FTextBounds.Left;
    IntersectRect(PadRect, AClip, PadRect2);
    InternalFillRect(dc, PadRect);
  end;
  if (AClip.Right > FTextBounds.Right) then begin
    PadRect2 := Bounds;
    PadRect2.Left := FTextBounds.Right;
    IntersectRect(PadRect, AClip, PadRect2);
    InternalFillRect(dc, PadRect);
  end;

  if (AClip.Left   >= FTextBounds.Right) or
     (AClip.Right  <= FTextBounds.Left) or
     (AClip.Top    >= FTextBounds.Bottom) or
     (AClip.Bottom <= FTextBounds.Top)
  then
    exit;

  TextColumn1 := LeftChar;
  if (AClip.Left > FTextBounds.Left) then
    Inc(TextColumn1, (AClip.Left - FTextBounds.Left) div CharWidth);
  TextColumn2 := LeftChar +
    ( Min(AClip.Right, FTextBounds.Right) - FTextBounds.Left + CharWidth - 1) div CharWidth;
  // lines
  ScreenRow1 := Max((AClip.Top - FTextBounds.Top) div fTextHeight, 0);
  ScreenRow2 := Min((AClip.Bottom-1 - FTextBounds.Top) div fTextHeight, LinesInWindow + 1);

  AClip.Left   := Max(AClip.Left, FTextBounds.Left); // Todo: This is also checked in paintLines (together with right side)
  AClip.Right  := Min(AClip.Right, FTextBounds.Right);
  //AClip.Top    := Max(AClip.Top, FTextBounds.Top);
  //AClip.Bottom := Min(AClip.Bottom, FTextBounds.Bottom);

  SetBkMode(dc, TRANSPARENT);
  PaintTextLines(AClip, ScreenRow1, ScreenRow2, TextColumn1, TextColumn2);

  FCanvas := nil;
end;

procedure TLazSynTextArea.PaintTextLines(AClip: TRect; FirstLine, LastLine,
  FirstCol, LastCol: integer);
// FirstLine, LastLine are based 0
// FirstCol, LastCol are screen based 1 without scrolling (physical position).
//  i.e. the real screen position is fTextOffset+Pred(FirstCol)*CharWidth
var
  bDoRightEdge: boolean; // right edge
  nRightEdge: integer;
  colEditorBG: TColor;
    // painting the background and the text
  rcLine, rcToken: TRect;
  EraseLeft, DrawLeft: Integer;  // LeftSide for EraseBackground, Text
  CurLine: integer;         // Screen-line index for the loop
  CurTextIndex: Integer;    // Current Index in text
  dc: HDC;
  CharWidths: TPhysicalCharWidths;

  var
    LineBuffer: PChar;
    LineBufferLen: Integer;

  procedure DrawHiLightMarkupToken(ATokenInfo: TLazSynDisplayTokenInfoEx);
  var
    HasFrame: Boolean;
    s: TLazSynBorderSide;
    Attr: TSynSelectedColor;
    TxtFlags: Integer;
    tok: TRect;
    NeedExpansion: Boolean;
    c, i, j, k, e, Len, CWLen: Integer;
    pl, pt: PChar;
    Eto: TEtoBuffer;
    TxtLeft: Integer;
  begin
    Attr := ATokenInfo.Attr;
    FTextDrawer.SetForeColor(Attr.Foreground);
    FTextDrawer.SetBackColor(Attr.Background);
    FTextDrawer.SetStyle    (Attr.Style);
    HasFrame := False;
    for s := low(TLazSynBorderSide) to high(TLazSynBorderSide) do begin
      HasFrame := HasFrame or (Attr.FrameSideColors[s] <> clNone);
      FTextDrawer.FrameColor[s] := Attr.FrameSideColors[s];
      FTextDrawer.FrameStyle[s] := Attr.FrameSideStyles[s];
    end;

    rcToken.Right := ScreenColumnToXValue(ATokenInfo.PhysicalClipEnd);
    if rcToken.Right > AClip.Right then begin
      rcToken.Right := AClip.Right;
      FTextDrawer.FrameColor[bsRight] := clNone; // right side of char is not painted
    end;

    if (rcToken.Right <= rcToken.Left) then exit;
    rcToken.Left := ScreenColumnToXValue(ATokenInfo.PhysicalClipStart); // because for the first token, this can be middle of a char, and lead to wrong frame
    TxtLeft := ScreenColumnToXValue(ATokenInfo.PhysicalCharStart); // because for the first token, this can be middle of a char, and lead to wrong frame

    (* rcToken.Bottom may be less that crLine.Bottom. If a Divider was drawn, then RcToken will not contain it *)
    TxtFlags := ETO_OPAQUE;

    (* If token includes RightEdge, draw background, and edge first *)
    if bDoRightEdge and (nRightEdge<rcToken.Right) and (nRightEdge>=rcToken.Left)
    then begin
      TxtFlags := 0;
      if rcToken.Left < nRightEdge then begin
        // draw background left of edge (use rcToken, so we do not delete the divider-draw-line)
        tok := rcToken;
        tok.Right := nRightEdge;
        FTextDrawer.FillRect(tok);
      end;
      if rcToken.Right > nRightEdge then begin
        // draw background right of edge (use rcLine, full height)
        tok := rcToken;
        tok.Left   := nRightEdge;
        tok.Bottom := rcLine.Bottom;
        FTextDrawer.FillRect(tok);
      end;
      // draw edge (use rcLine / rcToken may be reduced)
      LCLIntf.MoveToEx(dc, nRightEdge, rcLine.Top, nil);
      LCLIntf.LineTo  (dc, nRightEdge, rcLine.Bottom + 1);
    end
    else
    if HasFrame then begin
      (* Draw background for frame *)
      TxtFlags := 0;
      tok := rcToken;
      if rcToken.Right > nRightEdge + 1 then
        tok.Bottom := rcLine.Bottom;
      FTextDrawer.FillRect(tok);
    end;

    if HasFrame then begin
      // draw frame
      tok := rcToken;
      if rcToken.Right > nRightEdge + 1 then
        tok.Bottom := rcLine.Bottom;
      FTextDrawer.DrawFrame(tok);
    end;

    NeedExpansion := ATokenInfo.ExpandedExtraBytes > 0;
    Len := ATokenInfo.Tk.TokenLength;
    Eto := nil;
    If FTextDrawer.NeedsEto or ATokenInfo.HasDoubleWidth or NeedExpansion then begin
      // prepare LineBuffer
      if NeedExpansion then begin
        if (LineBufferLen < Len + ATokenInfo.ExpandedExtraBytes + 1) then begin
          LineBufferLen := Len + ATokenInfo.ExpandedExtraBytes + 1 + 128;
          ReAllocMem(LineBuffer, LineBufferLen);
        end;
        pl := LineBuffer;
        pt := ATokenInfo.Tk.TokenStart;
      end;

      // Prepare ETO
      if FTextDrawer.NeedsEto or ATokenInfo.HasDoubleWidth then begin
        Eto := FTextDrawer.Eto;
        Eto.SetMinLength(Len + ATokenInfo.ExpandedExtraBytes + 1);
        c := FTextDrawer.GetCharWidth;
        e := 0;
      end;

      CWLen := Length(CharWidths);

      // Copy to LineBuffer (and maybe eto
      if NeedExpansion then begin
        j := ATokenInfo.StartPos.Logical - 1;
        for i := 0 to Len - 1 do begin
          if j < CWLen
          then k := (CharWidths[j] and PCWMask)
          else k := 1;
          if (k <> 0) and (eto <> nil) then begin
            Eto.EtoData[e] := k * c;
            inc(e);
          end;

          case pt^ of
            #9: begin
                if (vscTabAtFirst in FVisibleSpecialChars) and (j < CWLen) then begin
                  pl^ := #194; inc(pl);
                  pl^ := #187; inc(pl);
                  dec(k);
                  if eto <> nil then Eto.EtoData[e] := c;
                  inc(e);
                end;
                while k > 0 do begin
                  pl^ := ' '; inc(pl);
                  dec(k);
                  if eto <> nil then Eto.EtoData[e] := c;
                  inc(e);
                end;
                if (vscTabAtLast in FVisibleSpecialChars) and ((pl-1)^=' ') and (j < CWLen) then begin
                  (pl-1)^ := #194;
                  pl^ := #187; inc(pl);
                end;
              end;
            ' ': begin
                if (vscSpace in FVisibleSpecialChars) and (j < CWLen) then begin
                  pl^ := #194; inc(pl);
                  pl^ := #183; inc(pl);
                end
                else begin
                  pl^ := pt^;
                  inc(pl);
                end;
              end;
            else begin
                pl^ := pt^;
                inc(pl);
              end;
          end;
          inc(pt);
          inc(j);
        end;
        pl^ := #0;

      // Finish linebuffer
      ATokenInfo.Tk.TokenStart  := LineBuffer;
      ATokenInfo.Tk.TokenLength := Len + ATokenInfo.ExpandedExtraBytes;
      // TODO skip expanded half tab

      end
      else
      // ETO only
      begin
        for j := ATokenInfo.StartPos.Logical - 1 to ATokenInfo.StartPos.Logical - 1 + Len do begin
          if j < CWLen
          then k := (CharWidths[j] and PCWMask)
          else k := 1;
          if k <> 0 then begin
            Eto.EtoData[e] := k * c;
            inc(e);
          end;
        end;
      end;
    end;

    if (ATokenInfo.PhysicalCharStart <> ATokenInfo.PhysicalClipStart) or
       (ATokenInfo.PhysicalCharEnd <> ATokenInfo.PhysicalClipEnd)
    then
      TxtFlags := TxtFlags + ETO_CLIPPED;

    tok := rcToken;
    if rcToken.Right > nRightEdge + 1 then
      tok.Bottom := rcLine.Bottom;
    fTextDrawer.NewTextOut(TxtLeft, rcToken.Top, TxtFlags, tok,
      ATokenInfo.Tk.TokenStart, ATokenInfo.Tk.TokenLength, Eto);


    rcToken.Left := rcToken.Right;
  end;

  procedure PaintLines;
  var
    ypos, xpos: Integer;
    DividerInfo: TSynDividerDrawConfigSetting;
    TV, cl: Integer;
    TokenInfoEx: TLazSynDisplayTokenInfoEx;
    MaxLine: Integer;
  begin
    // Initialize rcLine for drawing. Note that Top and Bottom are updated
    // inside the loop. Get only the starting point for this.
    rcLine := AClip;
    rcLine.Bottom := TextBounds.Top + FirstLine * fTextHeight;

    TV := TopLine - 1;

    // Now loop through all the lines. The indices are valid for Lines.
    MaxLine := DisplayView.GetLinesCount-1;

    CurLine := FirstLine-1;
    while CurLine<LastLine do begin
      inc(CurLine);
      if TV + CurLine > MaxLine then break;
      // Update the rcLine rect to this line.
      rcLine.Top := rcLine.Bottom;
      Inc(rcLine.Bottom, fTextHeight);
      // Paint the lines depending on the assigned highlighter.
      rcToken := rcLine;
      // Delete the whole Line
      fTextDrawer.BackColor := colEditorBG;
      SetBkColor(dc, ColorToRGB(colEditorBG));
      rcLine.Left := EraseLeft;
      InternalFillRect(dc, rcLine);
      rcLine.Left := DrawLeft;

      FTokenBreaker.SetHighlighterTokensLine(TV + CurLine, CurTextIndex);
      CharWidths := FTheLinesView.GetPhysicalCharWidths(CurTextIndex);
      fMarkupManager.PrepareMarkupForRow(CurTextIndex+1);

      DividerInfo := DisplayView.GetDrawDividerInfo;
      if (DividerInfo.Color <> clNone) and (nRightEdge >= FTextBounds.Left) then
      begin
        ypos := rcToken.Bottom - 1;
        cl := DividerInfo.Color;
        if cl = clDefault then
          cl := RightEdgeColor;
        fTextDrawer.DrawLine(nRightEdge, ypos, FTextBounds.Left - 1, ypos, cl);
        dec(rcToken.Bottom);
      end;

      xpos := FirstCol;
      while FTokenBreaker.GetNextHighlighterTokenEx(TokenInfoEx) do begin
        xpos := TokenInfoEx.EndPos.Physical;
        DrawHiLightMarkupToken(TokenInfoEx);
      end;

      fMarkupManager.FinishMarkupForRow(CurTextIndex+1);
    end;
    CurLine:=-1;
    AClip.Top := rcLine.Bottom;
  end;

{ end local procedures }

begin
  FTokenBreaker.Prepare(DisplayView, FTheLinesView, FMarkupManager, FirstCol, LastCol);
  FTokenBreaker.ForegroundColor := ForegroundColor;
  FTokenBreaker.BackgroundColor := BackgroundColor;
  FTokenBreaker.SpaceExtraByteCount := 0;
  FTokenBreaker.TabExtraByteCount := 0;
  if (vscSpace in FVisibleSpecialChars) then
    FTokenBreaker.SpaceExtraByteCount := 1;
  if (vscTabAtFirst in FVisibleSpecialChars) then
    FTokenBreaker.TabExtraByteCount := FTokenBreaker.TabExtraByteCount + 1;
  if (vscTabAtLast in FVisibleSpecialChars) then
    FTokenBreaker.TabExtraByteCount := FTokenBreaker.TabExtraByteCount + 1;
  //if (AClip.Right < TextLeftPixelOffset(False)) then exit;
  //if (AClip.Left > ClientWidth - TextRightPixelOffset) then exit;

  //DebugLn(['TCustomSynEdit.PaintTextLines ',dbgs(AClip)]);
  CurLine:=-1;
  //DebugLn('TCustomSynEdit.PaintTextLines ',DbgSName(Self),' TopLine=',dbgs(TopLine),' AClip=',dbgs(AClip));
  colEditorBG := BackgroundColor;
  // If the right edge is visible and in the invalid area, prepare to paint it.
  // Do this first to realize the pen when getting the dc variable.
  bDoRightEdge := FALSE;
  if FRightEdgeVisible then begin // column value
    nRightEdge := FTextBounds.Left + (RightEdgeColumn - LeftChar + 1) * CharWidth; // pixel value
    if (nRightEdge >= AClip.Left) and (nRightEdge <= AClip.Right) then
      bDoRightEdge := TRUE;
    if nRightEdge > AClip.Right then
      nRightEdge := AClip.Right; // for divider draw lines (don't draw into right gutter)
  end
  else
    nRightEdge := AClip.Right;

  Canvas.Pen.Color := RightEdgeColor; // used for code folding too
  Canvas.Pen.Width := 1;
  // Do everything else with API calls. This (maybe) realizes the new pen color.
  dc := Canvas.Handle;
  SetBkMode(dc, TRANSPARENT);

  // Adjust the invalid area to not include the gutter (nor the 2 ixel offset to the guttter).
  EraseLeft := AClip.Left;
  if (AClip.Left < FTextBounds.Left) then
    AClip.Left := FTextBounds.Left ;
  DrawLeft := AClip.Left;

  if (LastLine >= FirstLine) then begin
    // Paint the visible text lines. To make this easier, compute first the
    // necessary information about the selected area: is there any visible
    // selected area, and what are its lines / columns?
    // Moved to two local procedures to make it easier to read.

    LineBufferLen := 0;
    LineBuffer := nil;
    if Assigned(fHighlighter) then begin
      fHighlighter.CurrentLines := FTheLinesView;
    end;

    DisplayView.InitHighlighterTokens(FHighlighter);
    fTextDrawer.Style := []; //Font.Style;
    fTextDrawer.BeginDrawing(dc);
    try
      PaintLines;
    finally
      fTextDrawer.EndDrawing;
      DisplayView.FinishHighlighterTokens;
      ReAllocMem(LineBuffer, 0);
    end;
  end;

  if (AClip.Top < AClip.Bottom) then begin
    // Delete the remaining area
    SetBkColor(dc, ColorToRGB(colEditorBG));
    AClip.Left := EraseLeft;
    InternalFillRect(dc, AClip);
    AClip.Left := DrawLeft;

    // Draw the right edge if necessary.
    if bDoRightEdge then begin
      LCLIntf.MoveToEx(dc, nRightEdge, AClip.Top, nil);
      LCLIntf.LineTo(dc, nRightEdge, AClip.Bottom + 1);
    end;
  end;

  fMarkupManager.EndMarkup;
end;

end.

