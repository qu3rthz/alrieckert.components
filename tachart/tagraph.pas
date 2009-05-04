{
 /***************************************************************************
                               TAGraph.pas
                               -----------
                    Component Library Standard Graph


 ***************************************************************************/

 *****************************************************************************
 *                                                                           *
 *  See the file COPYING.modifiedLGPL.txt, included in this distribution,    *
 *  for details about the copyright.                                         *
 *                                                                           *
 *  This program is distributed in the hope that it will be useful,          *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
 *                                                                           *
 *****************************************************************************

Authors: Luís Rodrigues, Philippe Martinole, Alexander Klenin

}
unit TAGraph;

{$H+}

interface

uses
  LCLIntF, LCLType, LResources,
  SysUtils, Classes, Controls, Graphics, Dialogs,
  TAChartUtils, TATypes;

const
  clTAColor = clScrollBar;
  LEGEND_SPACING = 5;

type
  TChart = class;

  TReticuleMode = (rmNone, rmVertical, rmHorizontal, rmCross);

  TDrawReticuleEvent = procedure(
    ASender: TChart; ASeriesIndex, AIndex: Integer;
    const AImg: TPoint; const AData: TDoublePoint) of object;

  TChartZPosition = 0..MaxInt;

  { TBasicChartSeries }

  TBasicChartSeries = class(TComponent)
  protected
    FActive: Boolean;
    FChart: TChart;
    FDepth: TChartZPosition;
    FShowInLegend: Boolean;
    FTitle: String;
    FZPosition: TChartZPosition;

    procedure AfterAdd; virtual;
    procedure DrawLegend(ACanvas: TCanvas; const ARect: TRect); virtual; abstract;
    function GetLegendCount: Integer; virtual; abstract;
    function GetLegendWidth(ACanvas: TCanvas): Integer; virtual; abstract;
    function GetNearestPoint(
      ADistFunc: TPointDistFunc; const APoint: TPoint;
      out AIndex: Integer; out AImg: TPoint; out AValue: TDoublePoint): Boolean;
      virtual;
    function GetSeriesColor: TColor; virtual; abstract;
    procedure SetActive(AValue: Boolean); virtual; abstract;
    procedure SetDepth(AValue: TChartZPosition); virtual; abstract;
    procedure SetSeriesColor(const AValue: TColor); virtual; abstract;
    procedure SetShowInLegend(AValue: Boolean); virtual; abstract;
    procedure SetZPosition(AValue: TChartZPosition); virtual; abstract;
    procedure UpdateBounds(var ABounds: TDoubleRect); virtual; abstract;
    procedure UpdateMargins(ACanvas: TCanvas; var AMargins: TRect); virtual;

  protected
    procedure ReadState(Reader: TReader); override;
    procedure SetParentComponent(AParent: TComponent); override;

  public
    destructor Destroy; override;

    function GetParentComponent: TComponent; override;
    function HasParent: Boolean; override;

  public
    procedure Draw(ACanvas: TCanvas); virtual; abstract;
    function IsEmpty: Boolean; virtual; abstract;

    property Active: Boolean read FActive write SetActive;
    property Depth: TChartZPosition read FDepth write SetDepth default 0;
    property ParentChart: TChart read FChart;
    property SeriesColor: TColor
      read GetSeriesColor write SetSeriesColor default clTAColor;
    property ShowInLegend: Boolean
      read FShowInLegend write SetShowInLegend default true;
    property Title: String read FTitle write FTitle;
    property ZPosition: TChartZPosition read FZPosition write SetZPosition default 0;
  end;

  TSeriesClass = class of TBasicChartSeries;

  { TChartSeriesList }

  TChartSeriesList = class(TPersistent)
  private
    FChart: TChart;
    FList: TFPList;
    function GetItem(AIndex: Integer): TBasicChartSeries;
    procedure SetItem(AIndex: Integer; const AValue: TBasicChartSeries);
  public
    function Count: Integer;
    constructor Create(AOwner: TChart);
    destructor Destroy; override;

  public
    property Chart: TChart read FChart;
    property Items[AIndex: Integer]: TBasicChartSeries
      read GetItem write SetItem; default;
  end;

  { TChart }

  TChart = class(TCustomChart)
  private // Property fields
    FAllowZoom: Boolean;
    FAxisColor: TColor;
    FAxisVisible: Boolean;
    FBottomAxis: TChartAxis;
    FDepth: TChartZPosition;
    FExpandPercentage: Integer;
    FExtent: TChartExtent;
    FFoot: TChartTitle;
    FFrame: TChartPen;
    FGraphBrush: TBrush;
    FLeftAxis: TChartAxis;
    FLegend: TChartLegend;
    FMirrorX: Boolean;                // From right to left ?
    FOnDrawReticule: TDrawReticuleEvent;
    FSeries: TChartSeriesList;
    FTitle: TChartTitle;

  private
    FClipRect: TRect;
    FCurrentExtent: TDoubleRect;
    FIsMouseDown: Boolean;
    FIsZoomed: Boolean;
    FOffset: TDoublePoint;   // Coordinates transformation
    FReticuleMode: TReticuleMode;
    FReticulePos: TPoint;
    FScale: TDoublePoint;    // Coordinates transformation
    FSelectionRect: TRect;

    procedure CalculateTransformationCoeffs(const AMargin: TRect);
    procedure DrawReticule(ACanvas: TCanvas);
    function GetChartHeight: Integer;
    function GetChartWidth: Integer;
    function GetLegendWidth(ACanvas: TCanvas): Integer;
    function GetMargins(ACanvas: TCanvas): TRect;
    function GetSeriesCount: Integer;
    function GetSeriesInZOrder: TFPList;
    procedure PrepareXorPen;

    procedure SetAxisColor(const AValue: TColor);
    procedure SetAxisVisible(Value: Boolean);
    procedure SetBottomAxis(Value: TChartAxis);
    procedure SetDepth(AValue: TChartZPosition);
    procedure SetExpandPercentage(AValue: Integer);
    procedure SetExtent(const AValue: TChartExtent);
    procedure SetFoot(Value: TChartTitle);
    procedure SetFrame(Value: TChartPen);
    procedure SetGraphBrush(Value: TBrush);
    procedure SetLeftAxis(Value: TChartAxis);
    procedure SetLegend(Value: TChartLegend);
    procedure SetMirrorX(AValue: Boolean);
    procedure SetReticuleMode(const AValue: TReticuleMode);
    procedure SetTitle(Value: TChartTitle);

  protected
    procedure Clean(ACanvas: TCanvas; ARect: TRect);
    procedure DisplaySeries(ACanvas: TCanvas);
    procedure DoDrawReticule(
      ASeriesIndex, AIndex: Integer; const AImg: TPoint;
      const AData: TDoublePoint); virtual;
    procedure DrawAxis(ACanvas: TCanvas; ARect: TRect);
    procedure DrawLegend(ACanvas: TCanvas);
    procedure DrawTitleFoot(ACanvas: TCanvas);
    procedure MouseDown(
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure StyleChanged(Sender: TObject);
    procedure UpdateExtent;

  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
    procedure EraseBackground(DC: HDC); override;
    procedure GetChildren(AProc: TGetChildProc; ARoot: TComponent); override;
    procedure Paint; override;
    procedure SetChildOrder(Child: TComponent; Order: Integer); override;

  public // Helpers for series drawing
    function GetNewColor: TColor;
    function GetRectangle: TRect;
    function IsPointInViewPort(const AP: TDoublePoint): Boolean;
    function LineInViewPort(var AG1, AG2: TDoublePoint): Boolean;

  public
    procedure AddSeries(ASeries: TBasicChartSeries);
    procedure CopyToClipboardBitmap;
    procedure DeleteSeries(ASeries: TBasicChartSeries);
    procedure DrawLineHoriz(ACanvas: TCanvas; AY: Integer);
    procedure DrawLineVert(ACanvas: TCanvas; AX: Integer);
    procedure DrawOnCanvas(Rect: TRect; ACanvas: TCanvas);
    procedure PaintOnCanvas(ACanvas: TCanvas; ARect: TRect);
    procedure SaveToBitmapFile(const FileName: String);
    procedure ZoomFull;

  public // Coordinate conversion
    function GraphToImage(const AGraphPoint: TDoublePoint): TPoint;
    function ImageToGraph(const APoint: TPoint): TDoublePoint;
    function XGraphToImage(AX: Double): Integer; inline;
    function XImageToGraph(AX: Integer): Double; inline;
    function YGraphToImage(AY: Double): Integer; inline;
    function YImageToGraph(AY: Integer): Double; inline;

  public
    property ChartHeight: Integer read GetChartHeight;
    property ChartWidth: Integer read GetChartWidth;
    property ClipRect: TRect read FClipRect;
    property SeriesCount: Integer read GetSeriesCount;
    property XGraphMax: Double read FCurrentExtent.b.X;
    property XGraphMin: Double read FCurrentExtent.a.X;
    property YGraphMax: Double read FCurrentExtent.b.Y;
    property YGraphMin: Double read FCurrentExtent.a.Y;

  published
    property AllowZoom: Boolean read FAllowZoom write FAllowZoom default true;
    property AxisColor: TColor read FAxisColor write SetAxisColor default clBlack;
    property AxisVisible: Boolean read FAxisVisible write SetAxisVisible default true;
    property BottomAxis: TChartAxis read FBottomAxis write SetBottomAxis;
    property Depth: TChartZPosition read FDepth write SetDepth default 0;
    property ExpandPercentage: Integer
      read FExpandPercentage write SetExpandPercentage default 0;
    property Extent: TChartExtent read FExtent write SetExtent;
    property Foot: TChartTitle read FFoot write SetFoot;
    property Frame: TChartPen read FFrame write SetFrame;
    property GraphBrush: TBrush read FGraphBrush write SetGraphBrush;
    property LeftAxis: TChartAxis read FLeftAxis write SetLeftAxis;
    property Legend: TChartLegend read FLegend write SetLegend;
    property MirrorX: Boolean read FMirrorX write SetMirrorX default false;
    property ReticuleMode: TReticuleMode
      read FReticuleMode write SetReticuleMode default rmNone;
    property Series: TChartSeriesList read FSeries;
    property Title: TChartTitle read FTitle write SetTitle;

  published
    property OnDrawReticule: TDrawReticuleEvent
      read FOnDrawReticule write FOnDrawReticule;

  published
    property Align;
    property Anchors;
    property Color default clBtnFace;
    property DoubleBuffered;
    property DragCursor;
    property DragMode;
    property Enabled;
    property ParentColor;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Visible;

  published
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDrag;
  end;

procedure Register;
procedure RegisterSeriesClass(ASeriesClass: TSeriesClass; const ACaption: string);

var
  SeriesClassRegistry: TStringList;

implementation

uses
  Clipbrd, LCLProc, GraphMath, Math, Types;

function CompareZPosition(AItem1, AItem2: Pointer): Integer;
begin
  Result :=
    TBasicChartSeries(AItem1).ZPosition - TBasicChartSeries(AItem2).ZPosition;
end;

procedure Register;
var
  i: Integer;
  sc: TSeriesClass;
begin
  RegisterComponents('Additional', [TChart]);
  for i := 0 to SeriesClassRegistry.Count - 1 do begin
    sc := TSeriesClass(SeriesClassRegistry.Objects[i]);
    RegisterClass(sc);
    RegisterNoIcon([sc]);
  end;
end;

procedure RegisterSeriesClass(ASeriesClass: TSeriesClass; const ACaption: string);
begin
  if SeriesClassRegistry.IndexOfObject(TObject(ASeriesClass)) < 0 then
    SeriesClassRegistry.AddObject(ACaption, TObject(ASeriesClass));
end;

{ TChart }

constructor TChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FAllowZoom := True;
  FAxisVisible := true; 

  Width := 400;
  Height := 300;

  FReticulePos := Point(-1, -1);
  FReticuleMode := rmNone;

  FSeries := TChartSeriesList.Create(Self);

  Color := clBtnFace;
  AxisColor := clBlack;

  FCurrentExtent := EmptyDoubleRect;

  MirrorX := false;
  FIsZoomed := false;

  FGraphBrush := TBrush.Create;
  FGraphBrush.OnChange := @StyleChanged;

  FLegend := TChartLegend.Create(Self);
  FTitle := TChartTitle.Create(Self);
  FTitle.Alignment := taCenter;
  FTitle.Text.Add('TAChart');
  FFoot := TChartTitle.Create(Self);

  FLeftAxis := TChartAxis.Create(Self);
  FLeftAxis.Title.Angle := 90;
  FLeftAxis.Inverted := false;
  FLeftAxis.Grid.Visible := True;
  FLeftAxis.Grid.Style := psDot;
  FBottomAxis := TChartAxis.Create(Self);
  FBottomAxis.Title.Angle := 0;
  FBottomAxis.Inverted := false;
  FBottomAxis.Grid.Visible := True;
  FBottomAxis.Grid.Style := psDot;

  FFrame :=  TChartPen.Create;
  FFrame.Visible := true;
  FFrame.OnChange := @StyleChanged;

  FExtent := TChartExtent.Create(Self);
end;

destructor TChart.Destroy;
begin
  FSeries.Free;
  FGraphBrush.Free;

  FLegend.Free;
  FTitle.Free;
  FFoot.Free;
  FLeftAxis.Free;
  FBottomAxis.Free;
  FFrame.Free;
  FExtent.Free;

  inherited Destroy;
end;

procedure TChart.EraseBackground(DC: HDC);
begin
  // do not erase, since we will paint over it anyway
  Unused(DC);
end;

procedure TChart.StyleChanged(Sender: TObject);
begin
  Invalidate;
end;

procedure TChart.Paint;
begin
  PaintOnCanvas(Canvas, Rect(0, 0, Width, Height));
end;

procedure TChart.PaintOnCanvas(ACanvas: TCanvas; ARect: TRect);
begin
  Clean(ACanvas, ARect);

  FClipRect := ARect;
  InflateRect(FClipRect, -2, -2);

  UpdateExtent;
  DrawTitleFoot(ACanvas);
  DrawLegend(ACanvas);
  DrawAxis(ACanvas, ARect);
  DisplaySeries(ACanvas);
  DrawReticule(ACanvas);
end;

procedure TChart.PrepareXorPen;
begin
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Mode := pmXor;
  Canvas.Pen.Color := clWhite;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := 1;
end;

procedure TChart.CalculateTransformationCoeffs(const AMargin: TRect);
type
  TConvFunc = function (AX: Integer): Double of object;

  procedure CalcOneCoord(
    AInverted: boolean; AConv: TConvFunc; var AGraphMin, AGraphMax: Double;
    AImageLo, AImageHi, AMarginLo, AMarginHi, ASign: Integer;
    out AScale, AOffset: Double);
  var
    lo, hi: Integer;
  begin
    lo := AImageLo + AMarginLo;
    hi := AImageHi + AMarginHi;

    if (AGraphMax = AGraphMin) or (Sign(hi - lo) <> ASign) then begin
      AScale := 1;
      AOffset := 0;
      exit;
    end;

    if AInverted then
      Exchange(lo, hi);

    AScale := (hi - lo) / (AGraphMax - AGraphMin);
    AOffset := hi - AScale * AGraphMax;
    AGraphMin := AConv(AImageLo);
    AGraphMax := AConv(AImageHi);;
    if AInverted then
      Exchange(AGraphMin, AGraphMax);
  end;

begin
  CalcOneCoord(
    BottomAxis.Inverted, @XImageToGraph, FCurrentExtent.a.X, FCurrentExtent.b.X,
    FClipRect.Left, FClipRect.Right, AMargin.Left, -AMargin.Right, 1,
    FScale.X, FOffset.X);
  CalcOneCoord(
    LeftAxis.Inverted, @YImageToGraph, FCurrentExtent.a.Y, FCurrentExtent.b.Y,
    FClipRect.Bottom, FClipRect.Top, -AMargin.Bottom, AMargin.Top, -1,
    FScale.Y, FOffset.Y);
end;

procedure TChart.Clean(ACanvas: TCanvas; ARect: TRect);
begin
  ACanvas.Pen.Mode := pmCopy;
  ACanvas.Pen.Style := psSolid;
  ACanvas.Pen.Color := Color;
  ACanvas.Brush.Color := Color;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Rectangle(ARect);
end;

procedure TChart.DrawTitleFoot(ACanvas: TCanvas);

  function AlignedTextPos(AAlign: TAlignment; const AText: String): TSize;
  begin
    Result := ACanvas.TextExtent(AText);
    case AAlign of
      taLeftJustify:
        Result.cx := FClipRect.Left;
      taCenter:
        Result.cx := (FClipRect.Left + FClipRect.Right - Result.cx) div 2;
      taRightJustify:
        Result.cx := FClipRect.Right - Result.cx;
    end;
  end;

var
  sz: TSize;
  i: Integer;
  pbf: TPenBrushFontRecall;
begin
  pbf := TPenBrushFontRecall.Create(ACanvas, [pbfBrush, pbfFont]);
  try
    with FTitle do
      if Visible and (Text.Count > 0) then begin
        ACanvas.Brush.Assign(Brush);
        ACanvas.Font.Assign(Font);
        for i := 0 to Text.Count - 1 do begin
          sz := AlignedTextPos(Alignment, Text[i]);
          ACanvas.TextOut(sz.cx, FClipRect.Top, Text[i]);
          FClipRect.Top += sz.cy;
        end;
        FClipRect.Top += 4;
      end;
    with FFoot do
      if Visible and (Text.Count > 0) then begin
        ACanvas.Brush.Assign(Brush);
        ACanvas.Font.Assign(Font);
        for i := Text.Count - 1 downto 0 do begin
          sz := AlignedTextPos(Alignment, Text[i]);
          FClipRect.Bottom -= sz.cy;
          ACanvas.TextOut(sz.cy, FClipRect.Bottom, Text[i]);
        end;
        FClipRect.Bottom -= 4;
      end;
  finally
    pbf.Free;
  end;
end;

procedure TChart.DrawAxis(ACanvas: TCanvas; ARect: TRect);
var
  leftOffset: Integer = 0;
  bottomOffset: Integer = 0;

  function MarkToText(AMark: Double): String;
  begin
    if Abs(AMark) <= 1e-16 then AMark := 0;
    Result := Trim(FloatToStr(AMark));
  end;

  procedure DrawAxisTitles;
  const
    DEGREES_TO_ORIENT = 10;
  var
    x, w: Integer;
    c: TPoint;
    sz: TSize;
    s: String;
  begin
    // FIXME: Angle assumed to be around 0 for bottom and 90 for left axis.
    c := CenterPoint(FClipRect);
    s := FLeftAxis.Title.Caption;
    if FLeftAxis.Visible and (s <> '') then begin
      w := ACanvas.TextHeight(FLeftAxis.Title.Caption);
      if FMirrorX then begin
        x := FClipRect.Right - w;
        FClipRect.Right := x - 4;
      end
      else begin
        x := FClipRect.Left;
        leftOffset := w + 4;
      end;
      ACanvas.Font.Orientation := FLeftAxis.Title.Angle * DEGREES_TO_ORIENT;
      ACanvas.TextOut(x, c.Y - w div 2, s);
    end;

    s := FBottomAxis.Title.Caption;
    if FBottomAxis.Visible and (s <> '') then begin
      sz := ACanvas.TextExtent(s);
      ACanvas.Font.Orientation := FBottomAxis.Title.Angle * DEGREES_TO_ORIENT;
      ACanvas.TextOut(c.X - sz.cx div 2, FClipRect.Bottom - sz.cy, s);
      bottomOffset := sz.cy + 4;
    end;
    ACanvas.Font.Orientation := 0;
  end;

  procedure DrawXMark(AMark: Double);
  var
    x, w: Integer;
    markText: String;
  begin
    x := XGraphToImage(AMark);

    if FBottomAxis.Grid.Visible then begin
      ACanvas.Pen.Assign(FBottomAxis.Grid);
      ACanvas.Brush.Style := bsClear;
      DrawLineVert(ACanvas, x);
    end;

    ACanvas.Pen.Color := AxisColor;
    ACanvas.Pen.Style := psSolid;
    ACanvas.Pen.Mode := pmCopy;
    ACanvas.Line(x, FClipRect.Bottom - 4, x, FClipRect.Bottom + 4);

    ACanvas.Brush.Assign(FGraphBrush);
    ACanvas.Brush.Color := Color;
    markText := MarkToText(AMark);
    w := ACanvas.TextWidth(markText);
    ACanvas.TextOut(
      EnsureRange(x - w div 2, 1, ARect.Right - w),
      FClipRect.Bottom + 5, markText);
  end;

  procedure DrawYMark(AMark: Double);
  var
    x, y, w, h: Integer;
    markText: String;
  begin
    y := YGraphToImage(AMark);

    if FLeftAxis.Grid.Visible then begin
      ACanvas.Pen.Assign(FLeftAxis.Grid);
      ACanvas.Brush.Style := bsClear;
      DrawLineHoriz(ACanvas, y);
    end;

    ACanvas.Pen.Color := AxisColor;
    ACanvas.Pen.Style := psSolid;
    ACanvas.Pen.Mode := pmCopy;
    ACanvas.Line(FClipRect.Left - 4, y, FClipRect.Left + 4, y);

    ACanvas.Brush.Assign(FGraphBrush);
    ACanvas.Brush.Color := Color;
    markText := MarkToText(AMark);
    w := ACanvas.TextWidth(markText);
    h := ACanvas.TextHeight(markText) div 2;
    if FMirrorX then
      x := FClipRect.Right + 5
    else
      x := FClipRect.Left - 5 - w;
    ACanvas.TextOut(x, y - h, markText);
  end;

var
  leftAxisWidth, maxWidth: Integer;
  leftAxisScale, bottomAxisScale: TAxisScale;
  step, mark: Double;
const
  INV_TO_SCALE: array [Boolean] of TAxisScale = (asIncreasing, asDecreasing);
begin
  if not FAxisVisible then begin
    FClipRect.Left += Depth;
    FClipRect.Bottom -= Depth;
    exit;
  end;

  DrawAxisTitles;

  // Check AxisScale for both axes
  leftAxisScale := INV_TO_SCALE[LeftAxis.Inverted];
  bottomAxisScale := INV_TO_SCALE[BottomAxis.Inverted];

  leftAxisWidth := 0;
  if FLeftAxis.Visible then begin
    // Find max mark width
    maxWidth := 0;
    if YGraphMin <> YGraphMax then begin
      CalculateIntervals(YGraphMin, YGraphMax, leftAxisScale, mark, step);
      case leftAxisScale of
        asIncreasing:
          while mark <= YGraphMax + step * 10e-10 do begin
            if mark >= YGraphMin then
              maxWidth := Max(ACanvas.TextWidth(MarkToText(mark)), maxWidth);
            mark += step;
          end;
        asDecreasing:
          while mark >= YGraphMin - step * 10e-10 do begin
            if mark <= YGraphMax then
              maxWidth := Max(ACanvas.TextWidth(MarkToText(mark)), maxWidth);
            mark -= step;
          end;
      end;
    end;

    leftAxisWidth := maxWidth + 5;
    // CalculateTransformationCoeffs changes axis interval, so it is possibile
    // that a new mark longer then existing ones is introduced.
    // That will change marks width and reduce view area,
    // requiring another call to CalculateTransformationCoeffs...
    // So punt for now and just reserve space for extra digit unconditionally.
    leftAxisWidth += ACanvas.TextWidth('0');
    if FMirrorX then
      FClipRect.Right -= leftAxisWidth
    else
      leftOffset += leftAxisWidth;
  end;

  if FBottomAxis.Visible then
    bottomOffset += ACanvas.TextHeight('0') + 5;

  FClipRect.Left += Max(leftOffset, Depth);
  FClipRect.Bottom -= Max(bottomOffset, Depth);

  CalculateTransformationCoeffs(GetMargins(ACanvas));

  // Background
  with ACanvas do begin
    if FFrame.Visible then
      Pen.Assign(FFrame)
    else
      Pen.Style := psClear;
    Brush.Color := Color;
    with FClipRect do
      Rectangle(Left, Top, Right + 1, Bottom + 1);
  end;

  // X graduations
  if FBottomAxis.Visible and (XGraphMin <> XGraphMax) then begin
    CalculateIntervals(XGraphMin, XGraphMax, bottomAxisScale, mark, step);
    case bottomAxisScale of
      asIncreasing:
        while mark <= XGraphMax + step * 10e-10 do begin
          if mark >= XGraphMin then
            DrawXMark(mark);
          mark += step;
        end;
      asDecreasing:
        while mark >= XGraphMin - step * 10e-10 do begin
          if mark <= XGraphMax then
            DrawXMark(mark);
          mark -= step;
        end;
    end;
  end;

  // Y graduations
  if FLeftAxis.Visible and (YGraphMin <> YGraphMax) then begin
    CalculateIntervals(YGraphMin, YGraphMax, leftAxisScale, mark, step);
    case leftAxisScale of
      asIncreasing:
        while mark <= YGraphMax + step * 10e-10 do begin
          if mark >= YGraphMin then
            DrawYMark(mark);
          mark += step;
        end;
      asDecreasing:
        while mark >= YGraphMin - step * 10e-10 do begin
          if mark <= YGraphMax then
            DrawYMark(mark);
          mark -= step;
        end;
    end;
  end;

  // Z axis
  if Depth > 0 then
    with FClipRect do
      ACanvas.Line(Left, Bottom, Left - Depth, Bottom + Depth);
end;

procedure TChart.DrawLegend(ACanvas: TCanvas);
var
  w, h, x1, y1, x2, y2, i, TH: Integer;
  pbf: TPenBrushFontRecall;
  r: TRect;
begin
  if not Legend.Visible then exit;

  // TODO: Legend.Alignment

  pbf := TPenBrushFontRecall.Create(ACanvas, [pbfPen, pbfBrush, pbfFont]);
  try
    ACanvas.Font.Assign(FLegend.Font);

    w := GetLegendWidth(ACanvas);
    TH := ACanvas.TextHeight('I');
    h := 0;
    for i := 0 to SeriesCount - 1 do
      with Series[i] do
        if Active and ShowInLegend then
          Inc(h, GetLegendCount);
    FClipRect.Right -= w + 10;
    x1 := FClipRect.Right + 5;
    y1 := FClipRect.Top;
    x2 := x1 + w;
    y2 := y1 + LEGEND_SPACING + h * (TH + LEGEND_SPACING);

    // Border
    ACanvas.Brush.Assign(FGraphBrush);
    ACanvas.Pen.Assign(FLegend.Frame);
    ACanvas.Rectangle(x1, y1, x2, y2);

    r := Bounds(x1 + LEGEND_SPACING, y1 + LEGEND_SPACING, 17, TH);
    for i := 0 to SeriesCount - 1 do
      with Series[i] do
        if Active and ShowInLegend then begin
          ACanvas.Pen.Color := FLegend.Frame.Color;
          ACanvas.Brush.Assign(FGraphBrush);
          DrawLegend(ACanvas, r);
          OffsetRect(r, 0, GetLegendCount * (TH + LEGEND_SPACING));
        end;
  finally
    pbf.Free;
  end;
end;

procedure TChart.DrawLineHoriz(ACanvas: TCanvas; AY: Integer);
begin
  if (FClipRect.Top < AY) and (AY < FClipRect.Bottom) then
    ACanvas.Line(FClipRect.Left, AY, FClipRect.Right, AY);
end;

procedure TChart.DrawLineVert(ACanvas: TCanvas; AX: Integer);
begin
  if (FClipRect.Left < AX) and (AX < FClipRect.Right) then
    ACanvas.Line(AX, FClipRect.Top, AX, FClipRect.Bottom);
end;

procedure TChart.SetMirrorX(AValue: Boolean);
begin
  if AValue = FMirrorX then exit;
  FMirrorX := AValue;
  Invalidate;
end;

procedure TChart.SetReticuleMode(const AValue: TReticuleMode);
begin
  if FReticuleMode = AValue then exit;
  DrawReticule(Canvas);
  FReticuleMode := AValue;
  Invalidate;
end;

procedure TChart.SetTitle(Value: TChartTitle);
begin
  FTitle.Assign(Value);
  Invalidate;
end;

procedure TChart.SetFoot(Value: TChartTitle);
begin
  FFoot.Assign(Value);
  Invalidate;
end;


function TChart.GetLegendWidth(ACanvas: TCanvas): Integer;
var
  i: Integer;
begin
  Result := 0;
  if not FLegend.Visible then
    exit;

  for i := 0 to SeriesCount - 1 do
    with Series[i] do
      if Active and ShowInLegend then
        Result := Max(GetLegendWidth(ACanvas), Result);
  if Result > 0 then
    Result += 20 + 10;
end;

function TChart.GetMargins(ACanvas: TCanvas): TRect;
const
  DEF_MARGIN = 4;
var
  i: Integer;
begin
  Result := Rect(DEF_MARGIN, DEF_MARGIN, DEF_MARGIN, DEF_MARGIN);
  for i := 0 to SeriesCount - 1 do
    if Series[i].Active then
      Series[i].UpdateMargins(ACanvas, Result);
end;

procedure TChart.SetGraphBrush(Value: TBrush);
begin
  FGraphBrush.Assign(Value);
end;

procedure TChart.AddSeries(ASeries: TBasicChartSeries);
begin
  DrawReticule(Canvas);
  Series.FList.Add(ASeries);
  ASeries.FChart := Self;
  ASeries.AfterAdd;
end;

procedure TChart.DeleteSeries(ASeries: TBasicChartSeries);
var
  i: Integer;
begin
  i := FSeries.FList.IndexOf(ASeries);
  if i < 0 then exit;
  FSeries.FList.Delete(i);
  Invalidate;
end;

function TChart.XGraphToImage(AX: Double): Integer;
begin
  Result := Round(FScale.X * AX + FOffset.X);
end;

function TChart.YGraphToImage(AY: Double): Integer;
begin
  Result := Round(FScale.Y * AY + FOffset.Y);
end;

function TChart.GraphToImage(const AGraphPoint: TDoublePoint): TPoint;
begin
  Result := Point(XGraphToImage(AGraphPoint.X), YGraphToImage(AGraphPoint.Y));
end;

function TChart.XImageToGraph(AX: Integer): Double;
begin
  Result := (AX - FOffset.X) / FScale.X;
end;

function TChart.YImageToGraph(AY: Integer): Double;
begin
  Result := (AY - FOffset.Y) / FScale.Y;
end;

function TChart.ImageToGraph(const APoint: TPoint): TDoublePoint;
begin
  Result.X := XImageToGraph(APoint.X);
  Result.Y := YImageToGraph(APoint.Y);
end;

function TChart.IsPointInViewPort(const AP: TDoublePoint): Boolean;
begin
  Result :=
    InRange(AP.X, XGraphMin, XGraphMax) and InRange(AP.Y, YGraphMin, YGraphMax);
end;

function TChart.LineInViewPort(var AG1, AG2: TDoublePoint): Boolean;
var
  dx, dy, dxy, u1, u2, u3, u4: Double;

  procedure CalcDeltas;
  begin
    dy := AG1.Y - AG2.Y;
    dx := AG1.X - AG2.X;
    dxy := AG1.X * AG2.Y - AG1.Y * AG2.X;
  end;

begin
  CalcDeltas;
  u1 := XGraphMin * dy - YGraphMin * dx + dxy;
  u2 := XGraphMin * dy - YGraphMax * dx + dxy;
  u3 := XGraphMax * dy - YGraphMax * dx + dxy;
  u4 := XGraphMax * dy - YGraphMin * dx + dxy;

  Result := false;
  if u1 * u2 < 0 then begin
    Result := true;
    if AG1.X < XGraphMin then begin
      AG1.Y := (XGraphMin * dy + dxy) / dx;
      AG1.X := XGraphMin;
      CalcDeltas;
    end;
    if AG2.X < XGraphMin then begin
      AG2.Y := (XGraphMin * dy + dxy) / dx;
      AG2.X := XGraphMin;
      CalcDeltas;
    end;
  end;

  if u2 * u3 < 0 then begin
    Result := true;
    if AG2.Y > YGraphMax then begin
       AG2.X := (YGraphMax * dx - dxy) / dy;
       AG2.Y := YGraphMax;
       CalcDeltas;
    end;
  end;

  if u3 * u4 < 0 then begin
    Result := true;
    if AG1.X > XGraphMax then begin
       AG1.Y := (XGraphMax * dy + dxy) / dx;
       AG1.X := XGraphMax;
       CalcDeltas;
    end;
    if AG2.X > XGraphMax then begin
       AG2.Y := (XGraphMax * dy + dxy) / dx;
       AG2.X := XGraphMax;
       CalcDeltas;
    end;
  end;

  if u4 * u1 < 0 then begin
    Result := true;
    if AG1.Y < YGraphMin then begin
       AG1.X := (YGraphMin * dx - dxy) / dy;
       AG1.Y := YGraphMin;
       CalcDeltas;
    end;
  end;
end;

procedure TChart.SaveToBitmapFile(const FileName: String);
var
  tmpR: TRect;
  tmpBitmap: TBitmap;
begin
  try
    tmpBitmap := TBitmap.Create;
    tmpR := GetRectangle;
    tmpBitmap.Width := tmpR.Right - tmpR.Left;
    tmpBitmap.Height:= tmpR.Bottom - tmpR.Top;
    tmpBitmap.Canvas.CopyRect(tmpR, Canvas, tmpR);
    tmpBitmap.SaveToFile(FileName);
  finally
    tmpBitmap.Free;
  end;
end;

procedure TChart.SetAxisColor(const AValue: TColor);
begin
  if FAxisColor = AValue then exit;
  FAxisColor := AValue;
  Invalidate;
end;

procedure TChart.CopyToClipboardBitmap;
var
  tmpBitmap: TBitmap;
  tmpR: TRect;
begin
  try
    tmpBitmap := TBitmap.Create;
    tmpR := GetRectangle;
    tmpBitmap.Width := tmpR.Right - tmpR.Left;
    tmpBitmap.Height:= tmpR.Bottom - tmpR.Top;
    tmpBitmap.Canvas.CopyRect(tmpR, Canvas, tmpR);
    ClipBoard.Assign(tmpBitmap);
  finally
    tmpBitmap.Free;
  end;
end;

procedure TChart.DrawOnCanvas(Rect: TRect; ACanvas: TCanvas);
begin
  PaintOnCanvas(ACanvas, Rect);
end;

procedure TChart.DisplaySeries(ACanvas: TCanvas);

  procedure OffsetDrawArea(AZPos, ADepth: Integer);
  begin
    FOffset.X -= AZPos;
    FOffset.Y += AZPos;
    OffsetRect(FClipRect, -AZPos, AZPos);
    FClipRect.Right += ADepth;
    FClipRect.Top -= ADepth;
  end;

var
  i: Integer;
  seriesInZOrder: TFPList;
begin
  if SeriesCount = 0 then exit;

  seriesInZOrder := GetSeriesInZOrder;
  try
    for i := 0 to SeriesCount - 1 do
      with TBasicChartSeries(seriesInZOrder[i]) do begin
        if not Active then continue;
        OffsetDrawArea(ZPosition, Depth);
        Canvas.ClipRect := FClipRect;
        Canvas.Clipping := true;
        Draw(ACanvas);
        OffsetDrawArea(-ZPosition, -Depth);
        Canvas.Clipping := false;
      end;
  finally
    seriesInZOrder.Free;
  end;

end;

procedure TChart.DrawReticule(ACanvas: TCanvas);
begin
  PrepareXorPen;
  if ReticuleMode in [rmVertical, rmCross] then
    DrawLineVert(ACanvas, FReticulePos.X);
  if ReticuleMode in [rmHorizontal, rmCross] then
    DrawLineHoriz(ACanvas, FReticulePos.Y);
end;

procedure TChart.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  Unused(Button, Shift);
  if PtInRect(FClipRect, Point(X, Y)) and FAllowZoom then begin
    FIsMouseDown := true;
    FSelectionRect := Rect(X, Y, X, Y);
  end;
end;

procedure TChart.MouseMove(Shift: TShiftState; X, Y: Integer);
const
  DIST_FUNCS: array [TReticuleMode] of TPointDistFunc = (
    nil, @PointDistX, @PointDistY, @PointDist);
var
  i, pointIndex: Integer;
  pt, newRetPos: TPoint;
  value: TDoublePoint;
begin
  Unused(Shift);
  pt := Point(X, Y);
  if FIsMouseDown then begin
    PrepareXorPen;
    Canvas.Rectangle(FSelectionRect);
    FSelectionRect.BottomRight := pt;
    Canvas.Rectangle(FSelectionRect);
    exit;
  end;

  if FReticuleMode = rmNone then exit;
  for i := 0 to SeriesCount - 1 do begin
    if
      Series[i].GetNearestPoint(
        DIST_FUNCS[FReticuleMode], pt, pointIndex, newRetPos, value) and
      (newRetPos <> FReticulePos) and PtInRect(FClipRect, newRetPos)
    then begin
      DoDrawReticule(i, pointIndex, newRetPos, value);
      DrawReticule(Canvas);
      FReticulePos := newRetPos;
      DrawReticule(Canvas);
    end;
  end;
end;

procedure TChart.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  Unused(Button, Shift);
  if not FIsMouseDown then exit;
  FReticulePos := Point(X, Y);

  PrepareXorPen;
  Canvas.Rectangle(FSelectionRect);

  FIsMouseDown := false;

  with FSelectionRect do begin
    FIsZoomed := (Left < Right) and (Top < Bottom);
    if FIsZoomed then begin
      FCurrentExtent.a := ImageToGraph(Point(Left, Bottom));
      FCurrentExtent.b := ImageToGraph(Point(Right, Top));
    end;
  end;

  Invalidate;
end;

procedure TChart.DoDrawReticule(
  ASeriesIndex, AIndex: Integer; const AImg: TPoint; const AData: TDoublePoint);
begin
  if Assigned(FOnDrawReticule) then
    FOnDrawReticule(Self, ASeriesIndex, AIndex, AImg, AData);
end;

function TChart.GetNewColor: TColor;
var
  i, j: Integer;
  ColorFound: Boolean;
begin
  for i := 1 to MaxColor do begin
    ColorFound := false;
    for j := 0 to SeriesCount - 1 do begin
      if Series[j].SeriesColor = Colors[i] then
        ColorFound := true;
    end;
    if not ColorFound then begin
      Result := Colors[i];
      exit;
    end;
  end;
  Result := RGB(Random(255), Random(255), Random(255));
end;

function TChart.GetRectangle: TRect;
begin
  Result.Left := 0;
  Result.Top := 0;
  Result.Right := Width;
  Result.Bottom := Height;
end;

procedure TChart.SetLegend(Value: TChartLegend);
begin
  FLegend.Assign(Value);
  Invalidate;
end;

procedure TChart.SetLeftAxis(Value: TChartAxis);
begin
  FLeftAxis.Assign(Value);
  Invalidate;
end;

procedure TChart.SetBottomAxis(Value: TChartAxis);
begin
  FBottomAxis.Assign(Value);
  Invalidate;
end;

procedure TChart.SetChildOrder(Child: TComponent; Order: Integer);
var
  i: Integer;
begin
  i := Series.FList.IndexOf(Child);
  if i >= 0 then
    Series.FList.Move(i, Order);
end;

procedure TChart.SetDepth(AValue: TChartZPosition);
begin
  if FDepth = AValue then exit;
  FDepth := AValue;
  Invalidate;
end;

procedure TChart.SetExpandPercentage(AValue: Integer);
begin
  if FExpandPercentage = AValue then exit;
  FExpandPercentage := AValue;
  Invalidate;
end;

procedure TChart.SetExtent(const AValue: TChartExtent);
begin
  FExtent.Assign(AValue);
  Invalidate;
end;

procedure TChart.SetFrame(Value: TChartPen);
begin
  FFrame.Assign(Value);
  Invalidate;
end;

procedure TChart.SetAxisVisible(Value: Boolean);
begin
  FAxisVisible := Value;
  Invalidate;
end; 

function TChart.GetChartHeight: Integer;
begin
  Result := FClipRect.Right - FClipRect.Left;
end;

function TChart.GetChartWidth: Integer;
begin
  Result := FClipRect.Bottom - FClipRect.Top;
end;

procedure TChart.GetChildren(AProc: TGetChildProc; ARoot: TComponent);
var
  i: Integer;
begin
  for i := 0 to SeriesCount - 1 do
   if Series[i].Owner = ARoot then
     AProc(Series[i]);
end;

function TChart.GetSeriesCount: Integer;
begin
  Result := FSeries.FList.Count;
end;

function TChart.GetSeriesInZOrder: TFPList;
begin
  Result := TFPList.Create;
  try
    Result.Assign(FSeries.FList);
    Result.Sort(@CompareZPosition);
  except
    Result.Free;
    raise;
  end;
end;

procedure TChart.UpdateExtent;

  procedure SetBounds(
    var ALo, AHi: Double; AMin, AMax: Double; AUseMin, AUseMax: Boolean);

    procedure SetLo(AValue: Double);
    begin
      ALo := IfThen(AUseMin and (AValue < AMin), AMin, AValue);
    end;

    procedure SetHi(AValue: Double);
    begin
      AHi := IfThen(AUseMax and (AValue > AMax), AMax, AValue);
    end;

  const
    PERCENT = 0.01;
  var
    ext: Double;
  begin
    if (ALo = Infinity) and (AHi = NegInfinity) then begin
      // No boundaries, try to use extent
      if not AUseMin and not AUseMax then begin
        // Nothing we can do, give up
        ALo := -1;
        AHi := 1;
      end
      else if AUseMin then begin
        ALo := AMin;
        AHi := IfThen(AUseMax, AMax, ALo + 1);
      end
      else begin // Only AUseMax is true
        AHi := AMax;
        ALo := AHi - 1;
      end;
    end
    else if ALo = Infinity then begin
      SetHi(AHi);
      if AUseMin then begin
        ALo := AMin;
        if ALo >= AHi then SetHi(ALo + 1);
      end
      else
        ALo := AHi - 1;
    end
    else if AHi = NegInfinity then begin
      SetLo(ALo);
      if AUseMax then begin
        AHi := AMax;
        if ALo >= AHi then SetLo(AHi - 1);
      end
      else
        AHi := ALo + 1;
    end
    else begin
      // Both high and low boundary defined
      SetLo(ALo);
      if ALo >= AHi then SetHi(ALo + 1);
      SetHi(AHi);
      if ALo >= AHi then SetLo(AHi - 1);
      // Expand view slightly to avoid puttind data points on the chart edge.
      ext := ExpandPercentage * PERCENT * (AHi - ALo);
      SetLo(ALo - ext);
      SetHi(AHi + ext);
    end;

  end;

var
  i: Integer;
begin
  if FIsZoomed then exit;
  Extent.CheckBoundsOrder;

  FCurrentExtent := DoubleRect(Infinity, Infinity, NegInfinity, NegInfinity);
  for i := 0 to SeriesCount - 1 do
    with Series[i] do
      if Active then
        UpdateBounds(FCurrentExtent);
  with FCurrentExtent, Extent do begin
    SetBounds(a.X, b.X, XMin, XMax, UseXMin, UseXMax);
    SetBounds(a.Y, b.Y, YMin, YMax, UseYMin, UseYMax);
  end;
end;

procedure TChart.ZoomFull;
begin
  FIsZoomed := false;
  Invalidate;
end;

{ TBasicChartSeries }

procedure TBasicChartSeries.AfterAdd;
begin
  // nothing
end;

destructor TBasicChartSeries.Destroy;
begin
  if FChart <> nil then
    FChart.DeleteSeries(Self);
  inherited Destroy;
end;

function TBasicChartSeries.GetNearestPoint(
  ADistFunc: TPointDistFunc; const APoint: TPoint;
  out AIndex: Integer; out AImg: TPoint; out AValue: TDoublePoint): Boolean;
begin
  Unused(ADistFunc, APoint);
  AIndex := 0;
  AImg := Point(0, 0);
  AValue.X := 0;
  AValue.Y := 0;
  Result := false;
end;

function TBasicChartSeries.GetParentComponent: TComponent;
begin
  Result := FChart;
end;

function TBasicChartSeries.HasParent: Boolean;
begin
  Result := true;
end;

procedure TBasicChartSeries.ReadState(Reader: TReader);
begin
  inherited ReadState(Reader);
  if Reader.Parent is TChart then begin
    (Reader.Parent as TChart).AddSeries(Self);
    //DebugLn('TAChart %s: %d series', [Reader.Parent.Name, (Reader.Parent as TChart).SeriesCount]);
  end;
end;

procedure TBasicChartSeries.SetParentComponent(AParent: TComponent);
begin
  if not (csLoading in ComponentState) then
    (AParent as TChart).AddSeries(Self);
end;

procedure TBasicChartSeries.UpdateMargins(
  ACanvas: TCanvas; var AMargins: TRect);
begin
  // nothing
  Unused(ACanvas, AMargins);
end;

{ TChartSeriesList }

function TChartSeriesList.Count: Integer;
begin
  Result := FList.Count;
end;

constructor TChartSeriesList.Create(AOwner: TChart);
begin
  FChart := AOwner;
  FList := TFPList.Create;
end;

destructor TChartSeriesList.Destroy;
var
  i: Integer;
begin
  for i := 0 to FList.Count - 1 do begin
    Items[i].FChart := nil;
    Items[i].Free;
  end;
  FList.Free;
  inherited Destroy;
end;

function TChartSeriesList.GetItem(AIndex: Integer): TBasicChartSeries;
begin
  Result := TBasicChartSeries(FList.Items[AIndex]);
end;

procedure TChartSeriesList.SetItem(
  AIndex: Integer; const AValue: TBasicChartSeries);
begin
  GetItem(AIndex).Assign(AValue);
end;

procedure SkipObsoleteChartProperties;
const
  NOTE = 'Obsolete, use Extent instead';
  NAMES: array [1..4] of String = (
    'XGraph', 'YGraph', 'AutoUpdateX', 'AutoUpdateY');
var
  i: Integer;
begin
  RegisterPropertyToSkip(TChart, 'BackColor', 'Obsolete, use Color instead', '');
  for i := 1 to High(NAMES) do begin
    RegisterPropertyToSkip(TChart, NAMES[i] + 'Min', NOTE, '');
    RegisterPropertyToSkip(TChart, NAMES[i] + 'Max', NOTE, '');
  end;
end;

initialization
  {$I tagraph.lrs}
  SkipObsoleteChartProperties;
  SeriesClassRegistry := TStringList.Create;

finalization
  SeriesClassRegistry.Free;

end.
