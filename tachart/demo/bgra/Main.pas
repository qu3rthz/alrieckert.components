unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, ExtCtrls, PairSplitter, SysUtils, FileUtil, Forms, Controls,
  Graphics, Dialogs, TAGraph, TASeries, TASources;

type

  { TForm1 }

  TForm1 = class(TForm)
    Chart1: TChart;
    Chart1BarSeries1: TBarSeries;
    Chart1LineSeries1: TLineSeries;
    PaintBox1: TPaintBox;
    RandomChartSource1: TRandomChartSource;
    Splitter1: TSplitter;
    procedure PaintBox1Paint(Sender: TObject);
  end;

var
  Form1: TForm1; 

implementation

{$R *.lfm}

uses
  BGRABitmap, TADrawerBGRA;

{ TForm1 }

procedure TForm1.PaintBox1Paint(Sender: TObject);
var
  bmp: TBGRABitmap;
begin
  bmp := TBGRABitmap.Create(PaintBox1.Width, PaintBox1.Height);
  Chart1.DisableRedrawing;
  try
    Chart1.Title.Text.Text := 'BGRABitmap';
    Chart1.Draw(
      TBGRABitmapDrawer.Create(bmp),
      Rect(0, 0, PaintBox1.Width, PaintBox1.Height));
    bmp.Draw(PaintBox1.Canvas, 0, 0);
    Chart1.Title.Text.Text := 'Standard';
  finally
    Chart1.EnableRedrawing;
    bmp.Free;
  end;
end;

end.

