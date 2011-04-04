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
unit TADrawerBGRA;

{$H+}

interface

uses
  BGRABitmap, BGRABitmapTypes, Classes, FPCanvas, TADrawUtils;

type

  { TBGRABitmapDrawer }
  TBGRABitmapDrawer = class(TBasicDrawer, IChartDrawer)
  strict private
    FBrushColor: TBGRAPixel;
    FCanvas: TBGRABitmap;
    FFontColor: TBGRAPixel;
    FFontOrientation: Integer;
    FPenColor: TBGRAPixel;
    FPenWidth: Integer;
    FPrevPoint: TPoint;

    procedure SetBrush(ABrush: TFPCustomBrush);
    procedure SetFont(AFont: TFPCustomFont);
    procedure SetPen(APen: TFPCustomPen);
  strict protected
    function GetFontAngle: Double; override;
    function SimpleTextExtent(const AText: String): TPoint; override;
    procedure SimpleTextOut(AX, AY: Integer; const AText: String); override;
  public
    constructor Create(ACanvas: TBGRABitmap);
  public
    procedure AddToFontOrientation(ADelta: Integer);
    procedure ClippingStart;
    procedure ClippingStart(const AClipRect: TRect);
    procedure ClippingStop;
    procedure Ellipse(AX1, AY1, AX2, AY2: Integer);
    procedure FillRect(AX1, AY1, AX2, AY2: Integer);
    function GetBrushColor: TChartColor;
    procedure Line(AX1, AY1, AX2, AY2: Integer);
    procedure Line(const AP1, AP2: TPoint);
    procedure LineTo(AX, AY: Integer); override;
    procedure MoveTo(AX, AY: Integer); override;
    procedure Polygon(
      const APoints: array of TPoint;
      AStartIndex: Integer = 0; ANumPts: Integer = -1); override;
    procedure Polyline(
      const APoints: array of TPoint; AStartIndex: Integer = 0;
      ANumPts: Integer = -1; AEndPoint: Boolean = false);
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
  TAChartUtils, TAGeometry;

function PointsToPointsF(
  APoints: array of TPoint; AStartIndex, ANumPts: Integer): ArrayOfTPointF;
var
  i: Integer;
begin
  if ANumPts = -1 then
    ANumPts := Length(APoints) - AStartIndex;
  SetLength(Result, ANumPts);
  for i := 0 to ANumPts - 1 do
    with APoints[i + AStartIndex] do
      Result[i] := PointF(X, Y);
end;

procedure BoundingBoxToCenterAndHalfRadius(
  AX1, AY1, AX2, AY2: Integer;
  out ACX, ACY, ARX, ARY: Integer);
begin
  ACX := (AX1 + AX2) div 2;
  ACY := (AY1 + AY2) div 2;
  ARX := Abs(AX1 - AX2) div 2;
  ARY := Abs(AY1 - AY2) div 2;
end;

{ TBGRABitmapDrawer }

procedure TBGRABitmapDrawer.AddToFontOrientation(ADelta: Integer);
begin
  FFontOrientation += ADelta;
end;

procedure TBGRABitmapDrawer.ClippingStart(const AClipRect: TRect);
begin
  // NA
end;

procedure TBGRABitmapDrawer.ClippingStart;
begin
  // NA
end;

procedure TBGRABitmapDrawer.ClippingStop;
begin
  // NA
end;

constructor TBGRABitmapDrawer.Create(ACanvas: TBGRABitmap);
begin
  FCanvas := ACanvas;
end;

procedure TBGRABitmapDrawer.Ellipse(AX1, AY1, AX2, AY2: Integer);
var
  cx, cy, rx, ry: Integer;
begin
  BoundingBoxToCenterAndHalfRadius(AX1, AY1, AX2, AY2, cx, cy, rx, ry);
  FCanvas.FillEllipseAntialias(cx, cy, rx, ry, FBrushColor);
  FCanvas.EllipseAntialias(cx, cy, rx, ry, FPenColor, 1.0);
end;

procedure TBGRABitmapDrawer.FillRect(AX1, AY1, AX2, AY2: Integer);
begin
  FCanvas.FillRect(AX1, AY1, AX2, AY2, FBrushColor, dmSet);
end;

function TBGRABitmapDrawer.GetBrushColor: TChartColor;
begin
  Result := TChartColor(BGRAToColor(FBrushColor));
end;

function TBGRABitmapDrawer.GetFontAngle: Double;
begin
  Result := 0.0;
end;

procedure TBGRABitmapDrawer.Line(AX1, AY1, AX2, AY2: Integer);
begin
  FCanvas.DrawLineAntialias(AX1, AY1, AX2, AY2, FPenColor, FPenWidth);
end;

procedure TBGRABitmapDrawer.Line(const AP1, AP2: TPoint);
begin
  FCanvas.DrawLineAntialias(AP1.X, AP1.Y, AP2.X, AP2.Y, FPenColor, FPenWidth);
end;

procedure TBGRABitmapDrawer.LineTo(AX, AY: Integer);
var
  p: TPoint;
begin
  p := Point(AX, AY);
  Line(FPrevPoint, p);
  FPrevPoint := p;
end;

procedure TBGRABitmapDrawer.MoveTo(AX, AY: Integer);
begin
  FPrevPoint := Point(AX, AY);
end;

procedure TBGRABitmapDrawer.Polygon(
  const APoints: array of TPoint; AStartIndex: Integer; ANumPts: Integer);
begin
  FCanvas.DrawPolygonAntialias(
    PointsToPointsF(APoints, AStartIndex, ANumPts), FBrushColor, 1.0);
end;

procedure TBGRABitmapDrawer.Polyline(
  const APoints: array of TPoint;
  AStartIndex: Integer; ANumPts: Integer; AEndPoint: Boolean);
begin
  FCanvas.DrawPolyLineAntialias(
    PointsToPointsF(APoints, AStartIndex, ANumPts), FPenColor, FPenWidth);
end;

procedure TBGRABitmapDrawer.PrepareSimplePen(AColor: TChartColor);
begin
  FPenColor := ColorToBGRA(AColor);
  FCanvas.PenStyle := psSolid;
end;

procedure TBGRABitmapDrawer.RadialPie(
  AX1, AY1, AX2, AY2: Integer; AStartAngle16Deg, AAngleLength16Deg: Integer);
begin
  // NA
end;

procedure TBGRABitmapDrawer.Rectangle(AX1, AY1, AX2, AY2: Integer);
begin
  FCanvas.Rectangle(AX1, AY1, AX2, AY2, FPenColor, FBrushColor, dmSet);
end;

procedure TBGRABitmapDrawer.Rectangle(const ARect: TRect);
begin
  FCanvas.Rectangle(ARect, FPenColor, FBrushColor, dmSet);
end;

procedure TBGRABitmapDrawer.SetBrush(ABrush: TFPCustomBrush);
begin
  with ABrush.FPColor do
    FBrushColor := BGRA(red shr 8, green shr 8, blue shr 8, alpha shr 8);
end;

procedure TBGRABitmapDrawer.SetBrushColor(AColor: TChartColor);
begin
  FBrushColor := ColorToBGRA(AColor);
end;

procedure TBGRABitmapDrawer.SetBrushParams(
  AStyle: TFPBrushStyle; AColor: TChartColor);
begin
  Unused(AStyle);
  FBrushColor := ColorToBGRA(AColor);
end;

procedure TBGRABitmapDrawer.SetFont(AFont: TFPCustomFont);
begin
  FCanvas.FontName := AFont.Name;
  FCanvas.FontHeight := AFont.Size * 96 div 72;
  FFontOrientation := FGetFontOrientationFunc(AFont);
  with AFont.FPColor do
    FFontColor := BGRA(red shr 8, green shr 8, blue shr 8, alpha shr 8);
  // TODO: FontStyle
end;

procedure TBGRABitmapDrawer.SetPen(APen: TFPCustomPen);
begin
  FCanvas.PenStyle := APen.Style;
  FPenWidth := APen.Width;
  // TODO: JoinStyle
  with APen.FPColor do
    FPenColor := BGRA(red shr 8, green shr 8, blue shr 8, alpha shr 8);
end;

procedure TBGRABitmapDrawer.SetPenParams(
  AStyle: TFPPenStyle; AColor: TChartColor);
begin
  FCanvas.PenStyle := AStyle;
  FPenColor := ColorToBGRA(AColor);
end;

function TBGRABitmapDrawer.SimpleTextExtent(const AText: String): TPoint;
begin
  Result := FCanvas.TextSize(AText);
end;

procedure TBGRABitmapDrawer.SimpleTextOut(AX, AY: Integer; const AText: String);
begin
  FCanvas.TextOutAngle(
    AX, AY, FFontOrientation, AText, FFontColor, taLeftJustify);
end;

end.

