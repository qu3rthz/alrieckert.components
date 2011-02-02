{

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

 Authors: Alexander Klenin

}

unit TARadialSeries;

{$H+}

interface

uses
  Classes, Graphics, SysUtils, Types,
  TACustomSeries, TALegend, TAChartUtils;

type
  TLabelParams = record
    FAttachment: TPoint;
    FCenter: TPoint;
    FText: String;
  end;

  TPieSlice = record
    FAngle: Double;
    FBase: TPoint;
    FLabel: TLabelParams;
  end;

  { TCustomPieSeries }

  TCustomPieSeries = class(TChartSeries)
  private
    FExploded: Boolean;
    FFixedRadius: TChartDistance;
    FRotateLabels: Boolean;
    procedure Measure(ACanvas: TCanvas);
    procedure SetExploded(AValue: Boolean);
    procedure SetFixedRadius(AValue: TChartDistance);
    procedure SetRotateLabels(AValue: Boolean);
    function SliceColor(AIndex: Integer): TColor;
    function TryRadius(ACanvas: TCanvas): TRect;
  private
    FCenter: TPoint;
    FRadius: Integer;
    FSlices: array of TPieSlice;
  protected
    procedure AfterAdd; override;
    procedure GetLegendItems(AItems: TChartLegendItems); override;
  public
    function AddPie(AValue: Double; AText: String; AColor: TColor): Integer;
    procedure Assign(ASource: TPersistent); override;
    procedure Draw(ACanvas: TCanvas); override;
    function FindContainingSlice(const APoint: TPoint): Integer;

    // Offset slices away from center based on X value.
    property Exploded: Boolean read FExploded write SetExploded default false;
    property FixedRadius: TChartDistance
      read FFixedRadius write SetFixedRadius default 0;
    property RotateLabels: Boolean
      read FRotateLabels write SetRotateLabels default false;
  end;

  TSinCos = record
    FSin, FCos: Double;
  end;

  { TPolarSeries }

  TPolarSeries = class(TChartSeries)
  private
    FLinePen: TPen;
    FOriginX: Double;
    FOriginY: Double;
    function IsOriginXStored: Boolean;
    function IsOriginYStored: Boolean;
    procedure SetLinePen(AValue: TPen);
    procedure SetOriginX(AValue: Double);
    procedure SetOriginY(AValue: Double);
  private
    FAngleCache: array of TSinCos;
    function GraphPoint(AIndex: Integer): TDoublePoint;
    procedure PrepareAngleCache;
  protected
    procedure SourceChanged(ASender: TObject); override;
  public
    procedure Assign(ASource: TPersistent); override;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  public
    procedure Draw(ACanvas: TCanvas); override;
    function Extent: TDoubleRect; override;
  published
    property LinePen: TPen read FLinePen write SetLinePen;
    property OriginX: Double read FOriginX write SetOriginX stored IsOriginXStored;
    property OriginY: Double read FOriginY write SetOriginY stored IsOriginYStored;
    property Source;
  end;

implementation

uses
  Math,
  TACustomSource, TADrawUtils, TAGraph;

{ TCustomPieSeries }

function TCustomPieSeries.AddPie(
  AValue: Double; AText: String; AColor: TColor): Integer;
begin
  Result := AddXY(GetXMaxVal + 1, AValue, AText, AColor);
end;

procedure TCustomPieSeries.AfterAdd;
begin
  inherited;
  // disable axis when we have TPie series
  ParentChart.LeftAxis.Visible := false;
  ParentChart.BottomAxis.Visible := false;
end;

procedure TCustomPieSeries.Assign(ASource: TPersistent);
begin
  if ASource is TCustomPieSeries then
    with TCustomPieSeries(ASource) do begin
      Self.FExploded := FExploded;
      Self.FFixedRadius := FFixedRadius;
      Self.FRotateLabels := FRotateLabels;
    end;
  inherited Assign(ASource);
end;

procedure TCustomPieSeries.Draw(ACanvas: TCanvas);
var
  i: Integer;
  prevAngle: Double = 0;
  prevLabelPoly: TPointArray = nil;
begin
  if IsEmpty then exit;

  Marks.SetAdditionalAngle(0);
  Measure(ACanvas);

  ACanvas.Pen.Color := clBlack;
  ACanvas.Pen.Style := psSolid;
  ACanvas.Brush.Style := bsSolid;
  for i := 0 to Count - 1 do begin
    ACanvas.Brush.Color := SliceColor(i);
    with FSlices[i] do begin
      ACanvas.RadialPie(
        FBase.X - FRadius, FBase.Y - FRadius,
        FBase.X + FRadius, FBase.Y + FRadius,
        RadToDeg16(prevAngle), RadToDeg16(FAngle));
      prevAngle += FAngle;
    end;
  end;
  if not Marks.IsMarkLabelsVisible then exit;
  prevAngle := 0;
  for i := 0 to Count - 1 do
    with FSlices[i].FLabel do begin
      if FText <> '' then begin
        if RotateLabels then
          Marks.SetAdditionalAngle(prevAngle + FSlices[i].FAngle / 2);
        Marks.DrawLabel(ACanvas, FAttachment, FCenter, FText, prevLabelPoly);
      end;
      prevAngle += FSlices[i].FAngle;
    end;
end;

function TCustomPieSeries.FindContainingSlice(const APoint: TPoint): Integer;
var
  prevAngle: Double = 0;
  c: TPoint;
  pointAngle: Double;
begin
  if IsEmpty then exit(-1);

  for Result := 0 to Count - 1 do
    with FSlices[Result] do begin
      c := APoint - FBase;
      pointAngle := ArcTan2(-c.Y, c.X);
      if pointAngle < 0 then
        pointAngle += 2 * Pi;
      if
        InRange(pointAngle - prevAngle, 0, FAngle) and
        (Sqr(c.X) + Sqr(c.Y) <= Sqr(FRadius))
      then
        exit;
      prevAngle += FAngle;
    end;
  Result := -1;
end;

procedure TCustomPieSeries.GetLegendItems(AItems: TChartLegendItems);
var
  i: Integer;
  br: TLegendItemBrushRect;
  ps: TLegendItemPieSlice;
begin
  case Legend.Multiplicity of
    lmSingle: begin
      br := TLegendItemBrushRect.Create(nil, Title);
      br.Color := SliceColor(0);
      AItems.Add(br);
    end;
    lmPoint:
      for i := 0 to Count - 1 do begin
        ps := TLegendItemPieSlice.Create(FormattedMark(i));
        ps.Color := SliceColor(i);
        AItems.Add(ps);
      end;
  end;
end;

procedure TCustomPieSeries.Measure(ACanvas: TCanvas);
const
  MIN_RADIUS = 5;
var
  a, b: Integer;
begin
  FCenter := CenterPoint(ParentChart.ClipRect);
  if FixedRadius = 0 then begin
    // Use binary search to find maximum radius fitting into the parent chart.
    a := MIN_RADIUS;
    with Size(ParentChart.ClipRect) do
      b := Max(cx div 2, cy div 2);
    while a < b - 1 do begin
      FRadius := (a + b) div 2;
      if IsRectInRect(TryRadius(ACanvas), ParentChart.ClipRect) then
        a := FRadius
      else
        b := FRadius - 1;
    end;
  end
  else begin
    FRadius := FixedRadius;
    TryRadius(ACanvas);
  end;
end;

procedure TCustomPieSeries.SetExploded(AValue: Boolean);
begin
  if FExploded = AValue then exit;
  FExploded := AValue;
  UpdateParentChart;
end;

procedure TCustomPieSeries.SetFixedRadius(AValue: TChartDistance);
begin
  if FFixedRadius = AValue then exit;
  FFixedRadius := AValue;
  UpdateParentChart;
end;

procedure TCustomPieSeries.SetRotateLabels(AValue: Boolean);
begin
  if FRotateLabels = AValue then exit;
  FRotateLabels := AValue;
  UpdateParentChart;
end;

function TCustomPieSeries.SliceColor(AIndex: Integer): TColor;
begin
  Result :=
    ColorOrDefault(Source[AIndex]^.Color, Colors[AIndex mod High(Colors) + 1]);
end;

function TCustomPieSeries.TryRadius(ACanvas: TCanvas): TRect;

  function EndPoint(AAngle, ARadius: Double): TPoint;
  begin
    Result := RotatePoint(Point(Round(ARadius), 0), -AAngle);
  end;

  function LabelExtraDist(APoly: TPointArray; AAngle: Double): Double;
  const
    ALMOST_INF = 1e100;
  var
    sa, ca: Extended;
    denom, t, tmin: Double;
    a, b, d: TPoint;
    i: Integer;
  begin
    // x = t * ca; y = t * sa
    // (t * ca - a.x) * dy = (t * sa - a.y) * dx
    // t * (ca * dy - sa * dx) = a.x * dy - a.y * dx
    SinCos(-Pi - AAngle, sa, ca);
    b := APoly[High(APoly)];
    tmin := ALMOST_INF;
    for i := 0 to High(APoly) do begin
      a := APoly[i];
      d := b - a;
      denom := ca * d.Y - sa * d.X;
      if denom <> 0 then begin
        t := (a.X * d.Y - a.Y * d.X) / denom;
        if t > 0 then
          tmin := Min(tmin, t);
      end;
      b := a;
    end;
    Result := Norm([tmin * ca, tmin * sa]);
  end;

  procedure PrepareLabel(
    var ALabel: TLabelParams; AIndex: Integer; AAngle: Double);
  var
    i: Integer;
    p: TPointArray;
  begin
    with ALabel do begin
      FCenter := FAttachment;
      if not Marks.IsMarkLabelsVisible then exit;
        FText := FormattedMark(AIndex);
      if FText = '' then exit;
      if RotateLabels then
        Marks.SetAdditionalAngle(AAngle);
      p := Marks.GetLabelPolygon(ACanvas.TextExtent(FText));
      FCenter += EndPoint(AAngle, Marks.Distance + LabelExtraDist(p, AAngle));
      for i := 0 to High(p) do
        ExpandRect(Result, p[i] + FCenter);
    end;
  end;

const
  MARGIN = 4;
var
  i: Integer;
  di: PChartDataItem;
  prevAngle: Double = 0;
  a: Double;
begin
  Result.TopLeft := FCenter;
  Result.BottomRight := FCenter;
  SetLength(FSlices, Count);
  for i := 0 to Count - 1 do begin
    di := Source[i];
    with FSlices[i] do begin
      FAngle := CycleToRad(di^.Y / Source.ValuesTotal);
      FBase := FCenter;
      a := prevAngle + FAngle / 2;
      if Exploded and (di^.X > 0) then
        FBase += EndPoint(a, FRadius * di^.X);
      ExpandRect(Result, FBase, FRadius, - prevAngle, - prevAngle - FAngle);
      FLabel.FAttachment := EndPoint(a, FRadius) + FBase;
      PrepareLabel(FLabel, i, a);
      prevAngle += FAngle;
    end;
  end;
  InflateRect(Result, MARGIN, MARGIN);
end;

{ TPolarSeries }

procedure TPolarSeries.Assign(ASource: TPersistent);
begin
  if ASource is TPolarSeries then
    with TPolarSeries(ASource) do begin
      Self.LinePen := FLinePen;
      Self.FOriginX := FOriginX;
      Self.FOriginY := FOriginY;
    end;
  inherited Assign(ASource);
end;

constructor TPolarSeries.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FLinePen := TPen.Create;
  FLinePen.OnChange := @StyleChanged;
end;

destructor TPolarSeries.Destroy;
begin
  FreeAndNil(FLinePen);
  inherited;
end;

procedure TPolarSeries.Draw(ACanvas: TCanvas);
var
  i: Integer;
  pts: TPointArray;
begin
  PrepareAngleCache;
  SetLength(pts, Count);
  for i := 0 to Count - 1 do
    pts[i] := FChart.GraphToImage(GraphPoint(i));
  ACanvas.Pen := LinePen;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Polygon(pts);
end;

function TPolarSeries.Extent: TDoubleRect;
var
  i: Integer;
begin
  PrepareAngleCache;
  Result := EmptyExtent;
  for i := 0 to Count - 1 do
    ExpandRect(Result, GraphPoint(i));
end;

function TPolarSeries.GraphPoint(AIndex: Integer): TDoublePoint;
begin
  with Source[AIndex]^, FAngleCache[AIndex] do
    Result := DoublePoint(Y * FCos + OriginX, Y * FSin + OriginY);
end;

function TPolarSeries.IsOriginXStored: Boolean;
begin
  Result := OriginX <> 0;
end;

function TPolarSeries.IsOriginYStored: Boolean;
begin
  Result := OriginY <> 0;
end;

procedure TPolarSeries.PrepareAngleCache;
var
  i: Integer;
  s, c: Extended;
begin
  if Length(FAngleCache) = Count then exit;
  SetLength(FAngleCache, Count);
  for i := 0 to Count - 1 do begin
    SinCos(Source[i]^.X, s, c);
    FAngleCache[i].FSin := s;
    FAngleCache[i].FCos := c;
  end;
end;

procedure TPolarSeries.SetLinePen(AValue: TPen);
begin
  if FLinePen = AValue then exit;
  FLinePen := AValue;
end;

procedure TPolarSeries.SetOriginX(AValue: Double);
begin
  if FOriginX = AValue then exit;
  FOriginX := AValue;
  UpdateParentChart;
end;

procedure TPolarSeries.SetOriginY(AValue: Double);
begin
  if FOriginY = AValue then exit;
  FOriginY := AValue;
  UpdateParentChart;
end;

procedure TPolarSeries.SourceChanged(ASender: TObject);
begin
  FAngleCache := nil;
  inherited;
end;

initialization

  RegisterSeriesClass(TPolarSeries, 'Polar series');

end.

