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
unit TAGUIConnectorAggPas;

{$H+}

interface

uses
  Classes,
  TAGUIConnector;

type
  TChartGUIConnectorAggPas = class(TChartGUIConnector)
  public
    procedure CreateDrawer(var AData: TChartGUIConnectorData); override;
    procedure SetBounds(var AData: TChartGUIConnectorData); override;
    procedure Display(var AData: TChartGUIConnectorData); override;
  end;

procedure Register;

implementation

uses
  Agg_LCL, Graphics, SysUtils, TAChartUtils, TADrawerAggPas, TADrawerCanvas,
  TAGeometry;

type
  TAggPasOwnerDrawer = class(TAggPasDrawer)
  strict protected
    FBitmap: TBitmap;
  public
    constructor Create(ACanvas: TAggLCLCanvas);
    destructor Destroy; override;
    procedure SetSize(ASize: TPoint);
    procedure PaintOnCanvas(ACanvas: TCanvas; const ARect: TRect);
  end;

procedure Register;
begin
  RegisterComponents(CHART_COMPONENT_IDE_PAGE, [TChartGUIConnectorAggPas]);
end;

{ TChartGUIConnectorAggPas }

procedure TChartGUIConnectorAggPas.CreateDrawer(
  var AData: TChartGUIConnectorData);
begin
  AData.FDrawer := TAggPasOwnerDrawer.Create(TAggLCLCanvas.Create);
  AData.FDrawer.DoGetFontOrientation := @CanvasGetFontOrientationFunc;
end;

procedure TChartGUIConnectorAggPas.Display(var AData: TChartGUIConnectorData);
begin
  (AData.FDrawer as TAggPasOwnerDrawer).PaintOnCanvas(
    AData.FCanvas, AData.FBounds);
end;

procedure TChartGUIConnectorAggPas.SetBounds(var AData: TChartGUIConnectorData);
begin
  AData.FDrawerBounds.TopLeft := Point(0, 0);
  AData.FDrawerBounds.BottomRight :=
    AData.FBounds.BottomRight - AData.FBounds.TopLeft;
  (AData.FDrawer as TAggPasOwnerDrawer).SetSize(
    AData.FDrawerBounds.BottomRight);
end;

{ TAggPasOwnerDrawer }

constructor TAggPasOwnerDrawer.Create(ACanvas: TAggLCLCanvas);
begin
  inherited Create(ACanvas);
  FBitmap := TBitmap.Create;
end;

destructor TAggPasOwnerDrawer.Destroy;
begin
  inherited;
  FreeAndNil(FBitmap);
  FreeAndNil(FCanvas);
end;

procedure TAggPasOwnerDrawer.PaintOnCanvas(
  ACanvas: TCanvas; const ARect: TRect);
begin
  FBitmap.LoadFromIntfImage(FCanvas.Image.IntfImg);
  ACanvas.Draw(ARect.Left, ARect.Top, FBitmap);
end;

procedure TAggPasOwnerDrawer.SetSize(ASize: TPoint);
begin
  FBitmap.SetSize(ASize.X, ASize.Y);
  FCanvas.Width := ASize.X;
  FCanvas.Height := ASize.Y;
end;

end.
