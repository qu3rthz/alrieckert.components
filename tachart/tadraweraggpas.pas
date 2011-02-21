unit TADrawerAggPas;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FPCanvas, Graphics, Agg_LCL, TADrawUtils;

type

  { TAggPasDrawer }

  TAggPasDrawer = class(TFPCanvasDrawer, IChartDrawer, ISimpleTextOut)
  strict private
    FCanvas: TAggLCLCanvas;
    procedure SetBrush(ABrush: TFPCustomBrush);
    procedure SetFont(AFont: TFPCustomFont);
    procedure SetPen(APen: TFPCustomPen);
  strict protected
    function GetFontAngle: Double; override;
    procedure SimpleTextOut(AX, AY: Integer; const AText: String); override;
    function SimpleTextExtent(const AText: String): TPoint; override;
  public
    constructor Create(ACanvas: TAggLCLCanvas);
  public
    procedure AddToFontOrientation(ADelta: Integer);
    procedure ClippingStart;
    procedure ClippingStart(const AClipRect: TRect);
    procedure ClippingStop;
    procedure FillRect(AX1, AY1, AX2, AY2: Integer);
    function GetBrushColor: TChartColor;
    function GetCanvas: TCanvas;
    function HasCanvas: Boolean;
    procedure Line(AX1, AY1, AX2, AY2: Integer);
    procedure Line(const AP1, AP2: TPoint);
    procedure Polygon(
      const APoints: array of TPoint;
      AStartIndex: Integer = 0; ANumPts: Integer = -1); override;
    procedure Polyline(
      const APoints: array of TPoint;
      AStartIndex: Integer = 0; ANumPts: Integer = -1);
    procedure PrepareSimplePen(AColor: TChartColor);
    procedure RadialPie(
      AX1, AY1, AX2, AY2: Integer;
      AStartAngle16Deg, AAngleLength16Deg: Integer);
    procedure Rectangle(const ARect: TRect);
    procedure Rectangle(AX1, AY1, AX2, AY2: Integer);
    procedure SetBrushColor(AColor: TChartColor);
    procedure SetBrushParams(AStyle: TFPBrushStyle; AColor: TChartColor);
    procedure SetPenParams(AStyle: TFPPenStyle; AColor: TChartColor);
  end;

implementation

uses
  TAChartUtils;

{ TAggPasDrawer }

procedure TAggPasDrawer.AddToFontOrientation(ADelta: Integer);
begin
  with FCanvas.Font do
    AggAngle := AggAngle + OrientToRad(ADelta);
end;

procedure TAggPasDrawer.ClippingStart(const AClipRect: TRect);
begin
  FCanvas.ClipRect := AClipRect;
  FCanvas.Clipping := true;
end;

procedure TAggPasDrawer.ClippingStart;
begin
  FCanvas.Clipping := true;
end;

procedure TAggPasDrawer.ClippingStop;
begin
  FCanvas.Clipping := false;
end;

constructor TAggPasDrawer.Create(ACanvas: TAggLCLCanvas);
begin
  FCanvas := ACanvas;
end;

procedure TAggPasDrawer.FillRect(AX1, AY1, AX2, AY2: Integer);
begin
  FCanvas.FillRect(AX1, AY1, AX2, AY2);
end;

function TAggPasDrawer.GetBrushColor: TChartColor;
begin
  Result := FCanvas.Brush.Color;
end;

function TAggPasDrawer.GetCanvas: TCanvas;
begin
  raise Exception.Create('TAggPasDrawer.GetCanvas');
  Result := nil;
end;

function TAggPasDrawer.GetFontAngle: Double;
begin
  Result := FCanvas.Font.AggAngle;
end;

function TAggPasDrawer.HasCanvas: Boolean;
begin
  Result := false;
end;

procedure TAggPasDrawer.Line(AX1, AY1, AX2, AY2: Integer);
begin
  FCanvas.Line(AX1, AY1, AX2, AY2);
end;

procedure TAggPasDrawer.Line(const AP1, AP2: TPoint);
begin
  FCanvas.Line(AP1, AP2);
end;

procedure TAggPasDrawer.Polygon(
  const APoints: array of TPoint; AStartIndex, ANumPts: Integer);
begin
  FCanvas.Polygon(APoints, false, AStartIndex, ANumPts);
  FCanvas.Polyline(APoints, AStartIndex, ANumPts);
end;

procedure TAggPasDrawer.Polyline(
  const APoints: array of TPoint; AStartIndex, ANumPts: Integer);
begin
  FCanvas.Polyline(APoints, AStartIndex, ANumPts);
end;

procedure TAggPasDrawer.PrepareSimplePen(AColor: TChartColor);
begin
  with FCanvas.Pen do begin
    Color := AColor;
    Style := psSolid;
    Mode := pmCopy;
    Width := 1;
  end;
end;

procedure TAggPasDrawer.RadialPie(
  AX1, AY1, AX2, AY2: Integer;
  AStartAngle16Deg, AAngleLength16Deg: Integer);
begin
  FCanvas.RadialPie(
    AX1, AY1, AX2, AY2, AStartAngle16Deg, AAngleLength16Deg);
end;

procedure TAggPasDrawer.Rectangle(AX1, AY1, AX2, AY2: Integer);
begin
  FCanvas.Rectangle(AX1, AY1, AX2, AY2);
end;

procedure TAggPasDrawer.Rectangle(const ARect: TRect);
begin
  FCanvas.Rectangle(ARect);
end;

procedure TAggPasDrawer.SetBrush(ABrush: TFPCustomBrush);
begin
  with FCanvas.Brush do begin
    Style := ABrush.Style;
    Image := ABrush.Image;
    Pattern := ABrush.Pattern;
    if ABrush is TBrush then
      Color := (ABrush as TBrush).Color;
  end;
end;

procedure TAggPasDrawer.SetBrushColor(AColor: TChartColor);
begin
  FCanvas.Brush.Color := AColor;
end;

procedure TAggPasDrawer.SetBrushParams(
  AStyle: TFPBrushStyle; AColor: TChartColor);
begin
  FCanvas.Brush.Style := AStyle;
  FCanvas.Brush.Color := AColor;
end;

procedure TAggPasDrawer.SetFont(AFont: TFPCustomFont);
var
  f: TAggLCLFont;
begin
  f := FCanvas.Font;
  // This should be: FCanvas.Font.DoCopyProps(AFont);
  f.LoadFromFile(
    AFont.Name, f.SizeToAggHeight(AFont.Size), AFont.Bold, AFont.Italic);
  if AFont is TFont then
    with TFont(AFont) do begin
      f.Color := Color;
      f.AggAngle := OrientToRad(Orientation);
    end;
end;

type
  TAggLCLPenCrack = class(TAggLCLPen);

procedure TAggPasDrawer.SetPen(APen: TFPCustomPen);
begin
  TAggLCLPenCrack(FCanvas.Pen).DoCopyProps(APen);
  if APen is TPen then
    FCanvas.Pen.Color := (APen as TPen).Color;
end;

procedure TAggPasDrawer.SetPenParams(AStyle: TFPPenStyle; AColor: TChartColor);
begin
  FCanvas.Pen.Style := AStyle;
  FCanvas.Pen.Color := AColor;
end;

function TAggPasDrawer.SimpleTextExtent(const AText: String): TPoint;
begin
  Result := FCanvas.TextExtent(AText);
end;

procedure TAggPasDrawer.SimpleTextOut(AX, AY: Integer; const AText: String);
begin
  FCanvas.TextOut(AX, AY, AText);
end;

end.

