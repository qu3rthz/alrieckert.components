{

 Function series for TAChart.

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
unit TAFuncSeries;

{$H+}

interface

uses
  Classes, Graphics,
  TAChartUtils, TACustomSeries, TACustomSource, TADrawUtils, TALegend, TATypes;

const
  DEF_COLORMAP_STEP = 4;

type
  TFuncCalculateEvent = procedure (const AX: Double; out AY: Double) of object;

  TFuncSeriesStep = 1..MaxInt;

  { TBasicFuncSeries }

  TBasicFuncSeries = class(TCustomChartSeries)
  private
    FExtent: TChartExtent;
    procedure SetExtent(AValue: TChartExtent);
  protected
    procedure AfterAdd; override;
    procedure GetBounds(var ABounds: TDoubleRect); override;
  public
    procedure Assign(ASource: TPersistent); override;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Active default true;
    property Extent: TChartExtent read FExtent write SetExtent;
    property ShowInLegend;
    property Title;
    property ZPosition;
  end;

  { TFuncSeries }

  TFuncSeries = class(TBasicFuncSeries)
  private
    FDomainExclusions: TIntervalList;
    FOnCalculate: TFuncCalculateEvent;
    FPen: TChartPen;
    FStep: TFuncSeriesStep;

    function DoCalcIdentity(AX: Double): Double;
    function DoCalculate(AX: Double): Double;
    procedure SetOnCalculate(const AValue: TFuncCalculateEvent);
    procedure SetPen(const AValue: TChartPen);
    procedure SetStep(AValue: TFuncSeriesStep);
  protected
    procedure GetLegendItems(AItems: TChartLegendItems); override;

  public
    procedure Assign(ASource: TPersistent); override;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Draw(ADrawer: IChartDrawer); override;
    function IsEmpty: Boolean; override;
  public
    property DomainExclusions: TIntervalList read FDomainExclusions;
  published
    property AxisIndexX;
    property AxisIndexY;
    property OnCalculate: TFuncCalculateEvent
      read FOnCalculate write SetOnCalculate;
    property Pen: TChartPen read FPen write SetPen;
    property Step: TFuncSeriesStep read FStep write SetStep default 2;
  end;

  TFuncCalculate3DEvent =
    procedure (const AX, AY: Double; out AZ: Double) of object;

  { TColorMapSeries }

  TColorMapSeries = class(TBasicFuncSeries)
  private
    FBrush: TBrush;
    FColorSource: TCustomChartSource;
    FColorSourceListener: TListener;
    FInterpolate: Boolean;
    FOnCalculate: TFuncCalculate3DEvent;
    FStepX: TFuncSeriesStep;
    FStepY: TFuncSeriesStep;
    procedure SetBrush(AValue: TBrush);
    procedure SetColorSource(AValue: TCustomChartSource);
    procedure SetInterpolate(AValue: Boolean);
    procedure SetOnCalculate(AValue: TFuncCalculate3DEvent);
    procedure SetStepX(AValue: TFuncSeriesStep);
    procedure SetStepY(AValue: TFuncSeriesStep);
  protected
    procedure GetLegendItems(AItems: TChartLegendItems); override;

  public
    procedure Assign(ASource: TPersistent); override;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

  public
    function ColorByValue(AValue: Double): TColor;
    procedure Draw(ADrawer: IChartDrawer); override;
    function IsEmpty: Boolean; override;
  published
    property AxisIndexX;
    property AxisIndexY;
    property Brush: TBrush read FBrush write SetBrush;
    property ColorSource: TCustomChartSource read FColorSource write SetColorSource;
    property Interpolate: Boolean
      read FInterpolate write SetInterpolate default false;
    property OnCalculate: TFuncCalculate3DEvent
      read FOnCalculate write SetOnCalculate;
    property StepX: TFuncSeriesStep
      read FStepX write SetStepX default DEF_COLORMAP_STEP;
    property StepY: TFuncSeriesStep
      read FStepY write SetStepY default DEF_COLORMAP_STEP;
  end;

implementation

uses
  Math, SysUtils, TAGeometry, TAGraph;

function DoublePointRotated(AX, AY: Double): TDoublePoint;
begin
  Result.X := AY;
  Result.Y := AX;
end;

{ TBasicFuncSeries }

procedure TBasicFuncSeries.AfterAdd;
begin
  inherited AfterAdd;
  FExtent.SetOwner(FChart);
end;

procedure TBasicFuncSeries.Assign(ASource: TPersistent);
begin
  if ASource is TBasicFuncSeries then
    with TBasicFuncSeries(ASource) do
      Self.Extent := FExtent;
  inherited Assign(ASource);
end;

constructor TBasicFuncSeries.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FExtent := TChartExtent.Create(FChart);
end;

destructor TBasicFuncSeries.Destroy;
begin
  FreeAndNil(FExtent);
  inherited Destroy;
end;

procedure TBasicFuncSeries.GetBounds(var ABounds: TDoubleRect);
begin
  with Extent do begin
    if UseXMin then ABounds.a.X := XMin;
    if UseYMin then ABounds.a.Y := YMin;
    if UseXMax then ABounds.b.X := XMax;
    if UseYMax then ABounds.b.Y := YMax;
  end;
end;

procedure TBasicFuncSeries.SetExtent(AValue: TChartExtent);
begin
  if FExtent = AValue then exit;
  FExtent.Assign(AValue);
  UpdateParentChart;
end;

{ TFuncSeries }

procedure TFuncSeries.Assign(ASource: TPersistent);
begin
  if ASource is TFuncSeries then
    with TFuncSeries(ASource) do begin
      Self.FDomainExclusions.Assign(FDomainExclusions);
      Self.FOnCalculate := FOnCalculate;
      Self.Pen := FPen;
      Self.FStep := FStep;
    end;
  inherited Assign(ASource);
end;

constructor TFuncSeries.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDomainExclusions := TIntervalList.Create;
  FDomainExclusions.OnChange := @StyleChanged;
  FPen := TChartPen.Create;
  FPen.OnChange := @StyleChanged;
  FStep := 2;
end;

destructor TFuncSeries.Destroy;
begin
  FreeAndNil(FDomainExclusions);
  FreeAndNil(FPen);
  inherited;
end;

function TFuncSeries.DoCalcIdentity(AX: Double): Double;
begin
  Result := AX;
end;

function TFuncSeries.DoCalculate(AX: Double): Double;
begin
  OnCalculate(AX, Result)
end;

procedure TFuncSeries.Draw(ADrawer: IChartDrawer);
type
  TTransform = function (A: Double): Double of object;
  TMakeDoublePoint = function (AX, AY: Double): TDoublePoint;

var
  axisToGraphXr, axisToGraphYr, graphToAxisXr, calc: TTransform;
  makeDP: TMakeDoublePoint;
  r: TDoubleRect = (coords:(NegInfinity, NegInfinity, Infinity, Infinity));
  prev: TDoublePoint;
  prevInExtent: Boolean;

  procedure CalcAt(AXg, AXa: Double; out APt: TDoublePoint; out AIn: Boolean);
  begin
    APt := makeDP(AXg, axisToGraphYr(calc(AXa)));
    AIn := (r.a <= APt) and (APt <= r.b);
  end;

  procedure MoveTo(AXg, AXa: Double);
  begin
    CalcAt(AXg, AXa, prev, prevInExtent);
    if prevInExtent then
      ADrawer.MoveTo(FChart.GraphToImage(prev));
  end;

  procedure LineTo(AXg, AXa: Double);
  var
    p, t: TDoublePoint;
    inExtent: Boolean;
  begin
    CalcAt(AXg, AXa, p, inExtent);
    t := p;
    if inExtent and prevInExtent then
      ADrawer.LineTo(FChart.GraphToImage(p))
    else if LineIntersectsRect(prev, t, r) then begin
      ADrawer.MoveTo(FChart.GraphToImage(prev));
      ADrawer.LineTo(FChart.GraphToImage(t));
    end;
    prevInExtent := inExtent;
    prev := p;
  end;

var
  hint: Integer;
  xg, xa, xg1, xa1, xmax, graphStep: Double;
begin
  if Assigned(OnCalculate) then
    calc := @DoCalculate
  else if csDesigning in ComponentState then
    calc := @DoCalcIdentity
  else
    exit;
  GetGraphBounds(r);
  RectIntersectsRect(r, FChart.CurrentExtent);

  if IsRotated then begin
    axisToGraphXr := @AxisToGraphY;
    axisToGraphYr := @AxisToGraphX;
    graphToAxisXr := @GraphToAxisY;
    makeDP := @DoublePointRotated;
    graphStep := FChart.YImageToGraph(-Step) - FChart.YImageToGraph(0);
    xg := r.a.Y;
    xmax := r.b.Y;
  end
  else begin
    axisToGraphXr := @AxisToGraphX;
    axisToGraphYr := @AxisToGraphY;
    graphToAxisXr := @GraphToAxisX;
    makeDP := @DoublePoint;
    graphStep := FChart.XImageToGraph(Step) - FChart.XImageToGraph(0);
    xg := r.a.X;
    xmax := r.b.X;
  end;

  hint := 0;
  xa := graphToAxisXr(xg);
  if DomainExclusions.Intersect(xa, xa, hint) then
    xg := axisToGraphXr(xa);

  MoveTo(xg, xa);

  ADrawer.Pen := Pen;
  while xg < xmax do begin
    xg1 := xg + graphStep;
    xa1 := graphToAxisXr(xg1);
    if DomainExclusions.Intersect(xa, xa1, hint) then begin
      LineTo(axisToGraphXr(xa), xa);
      xg1 := axisToGraphXr(xa1);
      MoveTo(xg1, xa1);
    end
    else
      LineTo(xg1, xa1);
    xg := xg1;
    xa := xa1;
  end;
end;

procedure TFuncSeries.GetLegendItems(AItems: TChartLegendItems);
begin
  AItems.Add(TLegendItemLine.Create(Pen, Title));
end;

function TFuncSeries.IsEmpty: Boolean;
begin
  Result := not Assigned(OnCalculate);
end;

procedure TFuncSeries.SetOnCalculate(const AValue: TFuncCalculateEvent);
begin
  if TMethod(FOnCalculate) = TMethod(AValue) then exit;
  FOnCalculate := AValue;
  UpdateParentChart;
end;

procedure TFuncSeries.SetPen(const AValue: TChartPen);
begin
  if FPen = AValue then exit;
  FPen.Assign(AValue);
  UpdateParentChart;
end;

procedure TFuncSeries.SetStep(AValue: TFuncSeriesStep);
begin
  if FStep = AValue then exit;
  FStep := AValue;
  UpdateParentChart;
end;

{ TColorMapSeries }

procedure TColorMapSeries.Assign(ASource: TPersistent);
begin
  if ASource is TColorMapSeries then
    with TColorMapSeries(ASource) do begin
      Self.Brush := FBrush;
      Self.ColorSource := FColorSource;
      Self.FInterpolate := FInterpolate;
      Self.FOnCalculate := FOnCalculate;
      Self.FStepX := FStepX;
      Self.FStepY := FStepY;
    end;
  inherited Assign(ASource);
end;

function TColorMapSeries.ColorByValue(AValue: Double): TColor;
var
  lb, ub: Integer;
  c1, c2: TColor;
  v1, v2: Double;
begin
  if ColorSource = nil then exit(clTAColor);
  ColorSource.FindBounds(AValue, SafeInfinity, lb, ub);
  if Interpolate and InRange(lb, 1, ColorSource.Count - 1) then begin
    with ColorSource[lb - 1]^ do begin
      v1 := X;
      c1 := Color;
    end;
    with ColorSource[lb]^ do begin
      v2 := X;
      c2 := Color;
    end;
    if v2 <= v1 then
      Result := c1
    else
      Result := InterpolateRGB(c1, c2, (AValue - v1) / (v2 - v1));
  end
  else
    Result := ColorSource[EnsureRange(lb, 0, ColorSource.Count - 1)]^.Color;
end;

constructor TColorMapSeries.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FColorSourceListener := TListener.Create(@FColorSource, @StyleChanged);
  FBrush := TBrush.Create;
  FBrush.OnChange := @StyleChanged;
  FStepX := DEF_COLORMAP_STEP;
  FStepY := DEF_COLORMAP_STEP;
end;

destructor TColorMapSeries.Destroy;
begin
  FreeAndNil(FColorSourceListener);
  FreeAndNil(FBrush);
  inherited Destroy;
end;

procedure TColorMapSeries.Draw(ADrawer: IChartDrawer);
var
  ext: TDoubleRect;
  bounds: TDoubleRect;
  r: TRect;
  pt, next, offset: TPoint;
  gp: TDoublePoint;
  v: Double;
begin
  if not (csDesigning in ComponentState) and IsEmpty then exit;

  ext := ParentChart.CurrentExtent;
  bounds := EmptyExtent;
  GetBounds(bounds);
  bounds.a := AxisToGraph(bounds.a);
  bounds.b := AxisToGraph(bounds.b);
  if not RectIntersectsRect(ext, bounds) then exit;

  r.TopLeft := ParentChart.GraphToImage(ext.a);
  r.BottomRight := ParentChart.GraphToImage(ext.b);
  NormalizeRect(r);
  offset := ParentChart.GraphToImage(ZeroDoublePoint);

  ADrawer.Brush := Brush;
  ADrawer.SetPenParams(psClear, clTAColor);
  pt.Y := (r.Top div StepY - 1) * StepY + offset.Y mod StepY;
  while pt.Y <= r.Bottom do begin
    next.Y := pt.Y + StepY;
    if next.Y <= r.Top then begin
      pt.Y := next.Y;
      continue;
    end;
    pt.X := (r.Left div StepX  - 1) * StepX + offset.X mod StepX;
    while pt.X <= r.Right do begin
      next.X := pt.X + StepX;
      if next.X <= r.Left then begin
        pt.X := next.X;
        continue;
      end;
      gp := GraphToAxis(ParentChart.ImageToGraph((pt + next) div 2));
      if not (csDesigning in ComponentState) then
        OnCalculate(gp.X, gp.Y, v);
      if ColorSource <> nil then
        ADrawer.BrushColor := ColorByValue(v);
      ADrawer.Rectangle(
        Max(pt.X, r.Left), Max(pt.Y, r.Top),
        Min(next.X, r.Right) + 1, Min(next.Y, r.Bottom) + 1);
      pt.X := next.X;
    end;
    pt.Y := next.Y;
  end;
end;

procedure TColorMapSeries.GetLegendItems(AItems: TChartLegendItems);
var
  i: Integer;
  prev: Double;

  function ItemTitle(const AText: String; AX: Double): String;
  const
    FORMATS: array [1..3] of String = ('z ≤ %1:g', '%g < z ≤ %g', '%g < z');
  var
    idx: Integer;
  begin
    if AText <> '' then exit(AText);
    if ColorSource.Count = 1 then exit('');
    if i = 0 then idx := 1
    else if i = ColorSource.Count - 1 then idx := 3
    else idx := 2;
    Result := Format(FORMATS[idx], [prev, AX]);
  end;

var
  li: TLegendItemBrushRect;
begin
  case Legend.Multiplicity of
    lmSingle: AItems.Add(TLegendItemBrushRect.Create(Brush, Title));
    lmPoint:
      if ColorSource <> nil then begin
        prev := 0.0;
        for i := 0 to ColorSource.Count - 1 do
          with ColorSource[i]^ do begin
            li := TLegendItemBrushRect.Create(Brush, ItemTitle(Text, X));
            li.Color := Color;
            AItems.Add(li);
            prev := X;
          end;
      end;
  end;
end;

function TColorMapSeries.IsEmpty: Boolean;
begin
  Result := not Assigned(OnCalculate);
end;

procedure TColorMapSeries.SetBrush(AValue: TBrush);
begin
  if FBrush = AValue then exit;
  FBrush := AValue;
  UpdateParentChart;
end;

procedure TColorMapSeries.SetColorSource(AValue: TCustomChartSource);
begin
  if FColorSource = AValue then exit;
  if FColorSourceListener.IsListening then
    ColorSource.Broadcaster.Unsubscribe(FColorSourceListener);
  FColorSource := AValue;
  ColorSource.Broadcaster.Subscribe(FColorSourceListener);
  UpdateParentChart;
end;

procedure TColorMapSeries.SetInterpolate(AValue: Boolean);
begin
  if FInterpolate = AValue then exit;
  FInterpolate := AValue;
  UpdateParentChart;
end;

procedure TColorMapSeries.SetOnCalculate(AValue: TFuncCalculate3DEvent);
begin
  if FOnCalculate = AValue then exit;
  FOnCalculate := AValue;
  UpdateParentChart;
end;

procedure TColorMapSeries.SetStepX(AValue: TFuncSeriesStep);
begin
  if FStepX = AValue then exit;
  FStepX := AValue;
  UpdateParentChart;
end;

procedure TColorMapSeries.SetStepY(AValue: TFuncSeriesStep);
begin
  if FStepY = AValue then exit;
  FStepY := AValue;
  UpdateParentChart;
end;

initialization
  RegisterSeriesClass(TFuncSeries, 'Function series');
  RegisterSeriesClass(TColorMapSeries, 'Color map series');

end.

