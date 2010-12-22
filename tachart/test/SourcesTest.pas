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

unit SourcesTest;

{$mode objfpc}{$H+}{$R+}

interface

uses
  Classes, SysUtils, FPCUnit, TestRegistry, TASources;

type

  { TListSourceTest }

  TListSourceTest = class(TTestCase)
  private
    FSource: TListChartSource;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Basic;
    procedure DataPoint;
    procedure Extent;
    procedure Multi;
  end;

  { TRandomSourceTest }

  TRandomSourceTest = class(TTestCase)
  published
    procedure Extent;
  end;

  { TCalculatedSourceTest }

  TCalculatedSourceTest = class(TTestCase)
  private
    FOrigin: TListChartSource;
    FSource: TCalculatedChartSource;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Accumulate;
    procedure Percentage;
    procedure Reorder;
  end;

implementation

uses
  Math, TAChartUtils;

{ TCalculatedSourceTest }

procedure TCalculatedSourceTest.Accumulate;
var
  i, j: Integer;
  rng: TMWCRandomGenerator;
begin
  FSource.AccumulationMethod := camSum;
  FSource.AccumulationRange := 2;
  AssertEquals(3, FSource.YCount);
  AssertEquals(1, FSource[0]^.X);
  AssertEquals(102, FSource[0]^.Y);
  AssertEquals(2, FSource[1]^.X);
  AssertEquals(102 + 202, FSource[1]^.Y);
  AssertEquals(202 + 302, FSource[2]^.Y);
  FSource.AccumulationMethod := camAverage;
  AssertEquals((2002 + 2102) / 2, FSource[20]^.Y);
  AssertEquals(1, FSource[0]^.X);
  AssertEquals(102, FSource[0]^.Y);
  AssertEquals((102 + 202) / 2, FSource[1]^.Y);
  AssertEquals(102, FSource[0]^.Y);

  rng := TMWCRandomGenerator.Create;
  rng.Seed := 89237634;
  FSource.AccumulationRange := 5;
  for i := 1 to 100 do begin
    j := rng.GetInRange(5, FSource.Count - 1);
    AssertEquals(IntToStr(j), (j - 1) * 100 + 2, FSource[j]^.Y);
  end;
  rng.Free;
end;

procedure TCalculatedSourceTest.Percentage;
begin
  FSource.Percentage := true;
  AssertEquals(3, FSource.YCount);
  AssertEquals(102 / (102 + 103 + 104) * 100, FSource[0]^.Y);
  AssertEquals(103 / (102 + 103 + 104) * 100, FSource[0]^.YList[0]);
end;

procedure TCalculatedSourceTest.Reorder;
var
  i, j: Integer;
begin
  AssertEquals(3, FSource.YCount);
  FSource.ReorderYList := '2';
  AssertEquals(2, FSource.YCount);
  AssertEquals(104, FSource[0]^.YList[0]);
  AssertEquals(204, FSource[1]^.YList[0]);
  FSource.ReorderYList := '0,0,0';
  AssertEquals(4, FSource.YCount);
  AssertEquals(103, FSource[0]^.YList[0]);
  AssertEquals(103, FSource[0]^.YList[1]);
  AssertEquals(103, FSource[0]^.YList[2]);
  FSource.ReorderYList := '';
  for i := 0 to FSource.Count - 1 do begin
    AssertEquals(FOrigin[i]^.Y, FSource[i]^.Y);
    for j := 0 to FSource.YCount - 2 do
      AssertEquals(FOrigin[i]^.YList[j], FSource[i]^.YList[j]);
  end;
end;

procedure TCalculatedSourceTest.SetUp;
var
  i: Integer;
begin
  inherited SetUp;
  FOrigin := TListChartSource.Create(nil);
  FSource := TCalculatedChartSource.Create(nil);
  FSource.Origin := FOrigin;
  FOrigin.YCount := 3;
  for i := 1 to 100 do
    FOrigin.SetYList(FOrigin.Add(i, i * 100 + 2), [i * 100 + 3, i * 100 + 4]);
end;

procedure TCalculatedSourceTest.TearDown;
begin
  FreeAndNil(FSource);
  FreeAndNil(FOrigin);
  inherited TearDown;
end;

{ TListSourceTest }

procedure TListSourceTest.Basic;
begin
  FSource.Clear;
  AssertEquals(0, FSource.Count);
  AssertEquals(0, FSource.Add(1, 2, 'text', $FFFFFF));
  AssertEquals(1, FSource.Count);
  FSource.Delete(0);
  AssertEquals(0, FSource.Count);
end;

procedure TListSourceTest.DataPoint;
begin
  FSource.Clear;
  FSource.DataPoints.Add('3|4|?|text1');
  FSource.DataPoints.Add('5|6|$FF0000|');
  AssertEquals(2, FSource.Count);
  AssertEquals(3, FSource[0]^.X);
  AssertEquals(4, FSource[0]^.Y);
  AssertEquals('text1', FSource[0]^.Text);
  AssertEquals(clTAColor, FSource[0]^.Color);
  AssertEquals(5, FSource[1]^.X);
  AssertEquals(6, FSource[1]^.Y);
  AssertEquals('', FSource[1]^.Text);
  AssertEquals($FF0000, FSource[1]^.Color);
  FSource[0]^.Color := 0;
  AssertEquals('3|4|$000000|text1', FSource.DataPoints[0]);
  FSource.DataPoints.Add('7|8|0|two words');
  AssertEquals('two words', FSource[2]^.Text);
end;

procedure TListSourceTest.Extent;

  procedure AssertExtent(AX1, AY1, AX2, AY2: Double);
  begin
    with FSource.Extent do begin
      AssertEquals('X1', AX1, a.X);
      AssertEquals('Y1', AY1, a.Y);
      AssertEquals('X2', AX2, b.X);
      AssertEquals('Y2', AY2, b.Y);
    end;
  end;

begin
  FSource.Clear;
  Assert(IsInfinite(FSource.Extent.a.X) and IsInfinite(FSource.Extent.a.Y));
  Assert(IsInfinite(FSource.Extent.b.X) and IsInfinite(FSource.Extent.b.Y));

  FSource.Add(1, 2, '', 0);
  AssertExtent(1, 2, 1, 2);

  FSource.Add(3, 4, '', 0);
  AssertExtent(1, 2, 3, 4);

  FSource.SetXValue(0, -1);
  AssertExtent(-1, 2, 3, 4);

  FSource.SetXValue(1, -2);
  AssertExtent(-2, 2, -1, 4);

  FSource.SetYValue(0, 5);
  AssertExtent(-2, 4, -1, 5);

  FSource.SetYValue(0, 4.5);
  AssertExtent(-2, 4, -1, 4.5);
end;

procedure TListSourceTest.Multi;
begin
  FSource.Clear;
  AssertEquals(1, FSource.YCount);
  FSource.Add(1, 2);
  FSource.YCount := 2;
  AssertEquals(1, Length(FSource[0]^.YList));
  AssertEquals(0, FSource[0]^.YList[0]);
  FSource.SetYList(0, [3, 4]);
  AssertEquals(3, FSource[0]^.YList[0]);
  FSource.DataPoints.Add('1|2|3|4|?|t');
  AssertEquals(3, FSource.YCount);
  AssertEquals(4, FSource[1]^.YList[1]);
end;

procedure TListSourceTest.SetUp;
begin
  inherited SetUp;
  FSource := TListChartSource.Create(nil);
end;

procedure TListSourceTest.TearDown;
begin
  FreeAndNil(FSource);
  inherited TearDown;
end;

{ TRandomSourceTest }

procedure TRandomSourceTest.Extent;
var
  s: TRandomChartSource;
  ext: TDoubleRect;
begin
  s := TRandomChartSource.Create(nil);
  try
    s.XMin := 10;
    s.XMax := 20;
    s.YMin := 5;
    s.YMax := 6;
    s.PointsNumber := 1000;
    ext := s.Extent;
    AssertEquals(10, ext.a.X);
    AssertEquals(20, ext.b.X);
    Assert(ext.a.Y > 5);
    Assert(ext.b.Y < 6);
    Assert(ext.a.Y < ext.b.Y);
  finally
    s.Free;
  end;
end;

initialization

  RegisterTests([TListSourceTest, TRandomSourceTest, TCalculatedSourceTest]);

end.

