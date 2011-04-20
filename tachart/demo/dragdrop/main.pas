unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, ExtCtrls, StdCtrls, SysUtils, FileUtil, LResources, Forms, Controls,
  Graphics, Dialogs, TAGraph, TASeries, TATools, Types;

type

  { TForm1 }

  TForm1 = class(TForm)
    Chart1: TChart;
    Chart1LineSeries1: TLineSeries;
    ChartToolset1: TChartToolset;
    ChartToolset1DataPointClickTool1: TDataPointClickTool;
    ChartToolset1DataPointDragTool1: TDataPointDragTool;
    cbSorted: TCheckBox;
    ChartToolset1DataPointHintTool1: TDataPointHintTool;
    Panel1: TPanel;
    procedure cbSortedChange(Sender: TObject);
    procedure Chart1LineSeries1GetMark(out AFormattedMark: String;
      AIndex: Integer);
    procedure ChartToolset1DataPointClickTool1PointClick(ATool: TChartTool;
      APoint: TPoint);
    procedure ChartToolset1DataPointHintTool1Hint(ATool: TDataPointHintTool;
      const APoint: TPoint; var AHint: String);
    procedure FormCreate(Sender: TObject);
  end;

var
  Form1: TForm1; 

implementation

{$R *.lfm}

uses
  TAChartUtils;

{ TForm1 }

procedure TForm1.cbSortedChange(Sender: TObject);
begin
  Chart1LineSeries1.ListSource.Sorted := cbSorted.Checked;
end;

procedure TForm1.Chart1LineSeries1GetMark(
  out AFormattedMark: String; AIndex: Integer);
begin
  if AIndex = ChartToolset1DataPointDragTool1.PointIndex then
    with Chart1LineSeries1 do
      AFormattedMark := Source.FormatItem(Marks.Format, AIndex)
  else
    AFormattedMark := '';
end;

procedure TForm1.ChartToolset1DataPointClickTool1PointClick(
  ATool: TChartTool; APoint: TPoint);
begin
  Chart1LineSeries1.SetColor(ChartToolset1DataPointClickTool1.PointIndex, clRed);
end;

procedure TForm1.ChartToolset1DataPointHintTool1Hint(ATool: TDataPointHintTool;
  const APoint: TPoint; var AHint: String);
begin
  AHint := 'Custom hint for point ' + IntToStr(ATool.PointIndex);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  i: Integer;
begin
  RandSeed := 675402;
  for i := 1 to 10 do
    Chart1LineSeries1.AddXY(i, Random(20) - 10);
end;

end.

