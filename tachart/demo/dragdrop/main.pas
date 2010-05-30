unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, ExtCtrls, SysUtils, FileUtil, LResources, Forms, Controls, Graphics,
  Dialogs, TAGraph, TASeries, TATools;

type

  { TForm1 }

  TForm1 = class(TForm)
    Chart1: TChart;
    Chart1LineSeries1: TLineSeries;
    ChartToolset1: TChartToolset;
    ChartToolset1DataPointDragTool1: TDataPointDragTool;
    procedure Chart1LineSeries1GetMark(out AFormattedMark: String;
      AIndex: Integer);
    procedure FormCreate(Sender: TObject);
  private
    FDragIndex: Integer;
    FNearestIndex: Integer;
  end;

var
  Form1: TForm1; 

implementation

{$R *.lfm}

uses
  TAChartUtils;

{ TForm1 }

procedure TForm1.Chart1LineSeries1GetMark(
  out AFormattedMark: String; AIndex: Integer);
begin
  if AIndex = ChartToolset1DataPointDragTool1.PointIndex then
    with Chart1LineSeries1 do
      AFormattedMark := Source.FormatItem(Marks.Format, AIndex)
  else
    AFormattedMark := '';
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  i: Integer;
begin
  RandSeed := 675402;
  for i := 1 to 10 do
    Chart1LineSeries1.AddXY(i, Random(20) - 10);
  FDragIndex := -1;
  FNearestIndex := -1;
end;

end.

