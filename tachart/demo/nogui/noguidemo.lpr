program noguidemo;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads} cthreads, {$ENDIF}{$ENDIF}
  Interfaces, Classes, tachartlazaruspkg { you can add units after this },
  FPCanvas, FPImage, FPImgCanv,
  TAGraph, TASeries, TADrawerFPCanvas;

var
  chart: TChart;
  bs: TBarSeries;
  img: TFPMemoryImage;
  c: TFPImageCanvas;

{$R *.res}

begin
  chart := TChart.Create(nil);
  chart.LeftAxis.Marks.Visible := false;
  chart.LeftAxis.Grid.FPColor := colDkGray;
  chart.BottomAxis.Marks.Visible := false;
  chart.BottomAxis.Grid.FPColor := colDkGray;
  chart.Color := $FFA0A0;
  chart.BackColor := $FFFFFF;
  bs := TBarSeries.Create(nil);
  chart.AddSeries(bs);
  bs.AddXY(1, 10);
  bs.AddXY(2, 7);
  bs.AddXY(3, 8);
  img := TFPMemoryImage.Create(chart.Width, chart.Height);
  c := TFPImageCanvas.Create(img);
  chart.Draw(TFPCanvasDrawer.Create(c), Rect(0, 0, chart.Width, chart.Height));
  img.SaveToFile('test.png');
  c.Free;
  img.Free;
  bs.Free;
  chart.Free;
end.

