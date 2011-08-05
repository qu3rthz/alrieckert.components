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

unit TACustomSource;

{$mode objfpc}{$H+}

interface

uses
  Classes, Types, TAChartUtils;

type
  TAxisIntervalParamOption = (
    aipGraphCoords,
    aipUseCount, aipUseMaxLength, aipUseMinLength, aipUseNiceSteps);

const
  DEF_INTERVAL_STEPS = '0.2|0.5|1.0';
  DEF_INTERVAL_OPTIONS = [aipUseMaxLength, aipUseMinLength, aipUseNiceSteps];

type
  TAxisIntervalParamOptions = set of TAxisIntervalParamOption;

  TChartAxisIntervalParams = class(TPersistent)
  strict private
    FCount: Integer;
    FMaxLength: Integer;
    FMinLength: Integer;
    FNiceSteps: String;
    FOptions: TAxisIntervalParamOptions;
    FOwner: TPersistent;
    FStepValues: TDoubleDynArray;
    function NiceStepsIsStored: Boolean;
    procedure ParseNiceSteps;
    procedure SetCount(AValue: Integer);
    procedure SetMaxLength(AValue: Integer);
    procedure SetMinLength(AValue: Integer);
    procedure SetNiceSteps(const AValue: String);
    procedure SetOptions(AValue: TAxisIntervalParamOptions);
  strict protected
    procedure Changed; virtual;
  protected
    function GetOwner: TPersistent; override;
  public
    constructor Create(AOwner: TPersistent);
    property StepValues: TDoubleDynArray read FStepValues;
  published
    property Count: Integer read FCount write SetCount default 5;
    property MaxLength: Integer read FMaxLength write SetMaxLength default 50;
    property MinLength: Integer read FMinLength write SetMinLength default 10;
    property NiceSteps: String
      read FNiceSteps write SetNiceSteps stored NiceStepsIsStored;
    property Options: TAxisIntervalParamOptions
      read FOptions write SetOptions default DEF_INTERVAL_OPTIONS;
  end;

type
  EBufferError = class(EChartError);
  EEditableSourceRequired = class(EChartError);
  EYCountError = class(EChartError);

  TChartValueText = record
    FText: String;
    FValue: Double;
  end;

  TChartValueTextArray = array of TChartValueText;

  { TChartDataItem }

  TChartDataItem = object
    X, Y: Double;
    Color: TChartColor;
    Text: String;
    YList: TDoubleDynArray;
    function GetY(AIndex: Integer): Double;
  end;
  PChartDataItem = ^TChartDataItem;

  TGraphToImageFunc = function (AX: Double): Integer of object;

  TValuesInRangeParams = object
    FAxisToGraph: TTransformFunc;
    FFormat: String;
    FGraphToAxis: TTransformFunc;
    FGraphToImage: TGraphToImageFunc;
    FIntervals: TChartAxisIntervalParams;
    FMin, FMax: Double;
    FMinStep: Double;
    FUseY: Boolean;

    function CountToStep(ACount: Integer): Double; inline;
    function IsAcceptableStep(AStep: Integer): Boolean; inline;
    function ToImage(AX: Double): Integer; inline;
  end;

  { TCustomChartSource }

  TCustomChartSource = class(TComponent)
  strict private
    FBroadcaster: TBroadcaster;
    FUpdateCount: Integer;
  strict protected
    FExtent: TDoubleRect;
    FExtentIsValid: Boolean;
    FValuesTotal: Double;
    FValuesTotalIsValid: Boolean;
    FYCount: Cardinal;

    function GetCount: Integer; virtual; abstract;
    function GetItem(AIndex: Integer): PChartDataItem; virtual; abstract;
    procedure InvalidateCaches;
    procedure Notify;
    procedure SetYCount(AValue: Cardinal); virtual; abstract;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  public
    procedure AfterDraw; virtual;
    procedure BeforeDraw; virtual;
    procedure BeginUpdate;
    procedure EndUpdate; virtual;
    function IsUpdating: Boolean; inline;
  public
    class procedure CheckFormat(const AFormat: String);
    function Extent: TDoubleRect;
    function ExtentCumulative: TDoubleRect;
    function ExtentList: TDoubleRect;
    procedure FindBounds(AXMin, AXMax: Double; out ALB, AUB: Integer);
    function FormatItem(
      const AFormat: String; AIndex, AYIndex: Integer): String;
    function IsSorted: Boolean; virtual;
    procedure ValuesInRange(
      AParams: TValuesInRangeParams; var AValues: TChartValueTextArray); virtual;
    function ValuesTotal: Double; virtual;
    function XOfMax: Double;
    function XOfMin: Double;

    property Broadcaster: TBroadcaster read FBroadcaster;
    property Count: Integer read GetCount;
    property Item[AIndex: Integer]: PChartDataItem read GetItem; default;
    property YCount: Cardinal read FYCount write SetYCount default 1;
  end;

  { TChartSourceBuffer }

  TChartSourceBuffer = class
  strict private
    FBuf: array of TChartDataItem;
    FCount: Cardinal;
    FStart: Cardinal;
    FSum: TChartDataItem;
    procedure AddValue(const AItem: TChartDataItem);
    function EndIndex: Cardinal; inline;
    function GetCapacity: Cardinal; inline;
    procedure SetCapacity(AValue: Cardinal); inline;
  public
    procedure AddFirst(const AItem: TChartDataItem);
    procedure AddLast(const AItem: TChartDataItem);
    procedure Clear; inline;
    function GetPLast: PChartDataItem;
    procedure GetSum(var AItem: TChartDataItem);
    procedure RemoveLast; overload;
    procedure RemoveValue(const AItem: TChartDataItem);
    property Capacity: Cardinal read GetCapacity write SetCapacity;
  end;

procedure SetDataItemDefaults(var AItem: TChartDataItem);

implementation

uses
  Math, StrUtils, SysUtils;

procedure SetDataItemDefaults(var AItem: TChartDataItem);
var
  i: Integer;
begin
  AItem.X := 0;
  AItem.Y := 0;
  AItem.Color := clTAColor;
  AItem.Text := '';
  for i := 0 to High(AItem.YList) do
    AItem.YList[i] := 0;
end;

{ TValuesInRangeParams }

function TValuesInRangeParams.CountToStep(ACount: Integer): Double;
begin
  Result := Power(10, Floor(Log10((FMax - FMin) / ACount)));
end;

function TValuesInRangeParams.IsAcceptableStep(AStep: Integer): Boolean;
begin
  with FIntervals do
    Result := not (
      (aipUseMinLength in Options) and (AStep < MinLength) or
      (aipUseMaxLength in Options) and (AStep > MaxLength));
end;

function TValuesInRangeParams.ToImage(AX: Double): Integer;
begin
  if not (aipGraphCoords in FIntervals.Options) then
    AX := FAxisToGraph(AX);
  Result := FGraphToImage(AX);
end;

{ TChartAxisIntervalParams }

procedure TChartAxisIntervalParams.Changed;
begin
  with FOwner as TCustomChartSource do begin
    BeginUpdate;
    EndUpdate;
  end;
end;

constructor TChartAxisIntervalParams.Create(AOwner: TPersistent);
begin
  FOwner := AOwner;
  SetPropDefaults(Self, ['Count', 'MaxLength', 'MinLength', 'Options']);
  FNiceSteps := DEF_INTERVAL_STEPS;
  ParseNiceSteps;
end;

function TChartAxisIntervalParams.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

function TChartAxisIntervalParams.NiceStepsIsStored: Boolean;
begin
  Result := NiceSteps <> DEF_INTERVAL_STEPS;
end;

procedure TChartAxisIntervalParams.ParseNiceSteps;
var
  parts: TStringList;
  i: Integer;
begin
  parts := TStringList.Create;
  try
    parts.Delimiter := '|';
    parts.StrictDelimiter := true;
    parts.DelimitedText := IfThen(NiceSteps = '', DEF_INTERVAL_STEPS, NiceSteps);
    SetLength(FStepValues, parts.Count);
    for i := 0 to parts.Count - 1 do
      FStepValues[i] := StrToFloatDefSep(parts[i]);
  finally
    parts.Free;
  end;
end;

procedure TChartAxisIntervalParams.SetCount(AValue: Integer);
begin
  if FCount = AValue then exit;
  FCount := AValue;
  Changed;
end;

procedure TChartAxisIntervalParams.SetMaxLength(AValue: Integer);
begin
  if FMaxLength = AValue then exit;
  FMaxLength := AValue;
  Changed;
end;

procedure TChartAxisIntervalParams.SetMinLength(AValue: Integer);
begin
  if FMinLength = AValue then exit;
  FMinLength := AValue;
  Changed;
end;

procedure TChartAxisIntervalParams.SetNiceSteps(const AValue: String);
begin
  if FNiceSteps = AValue then exit;
  FNiceSteps := AValue;
  ParseNiceSteps;
  Changed;
end;

procedure TChartAxisIntervalParams.SetOptions(
  AValue: TAxisIntervalParamOptions);
begin
  if FOptions = AValue then exit;
  FOptions := AValue;
  Changed;
end;

{ TChartDataItem }

function TChartDataItem.GetY(AIndex: Integer): Double;
begin
  AIndex := EnsureRange(AIndex, 0, Length(YList));
  if AIndex = 0 then
    Result := Y
  else
    Result := YList[AIndex - 1];
end;

{ TChartSourceBuffer }

procedure TChartSourceBuffer.AddFirst(const AItem: TChartDataItem);
begin
  if Capacity = 0 then
    raise EBufferError.Create('');
  FStart := (FStart + Cardinal(High(FBuf))) mod Capacity;
  if FCount = Capacity then
    RemoveValue(FBuf[FStart])
  else
    FCount += 1;
  FBuf[FStart] := AItem;
  AddValue(AItem);
end;

procedure TChartSourceBuffer.AddLast(const AItem: TChartDataItem);
begin
  if Capacity > 0 then
    if FCount = Capacity then begin
      RemoveValue(FBuf[FStart]);
      FBuf[FStart] := AItem;
      FStart := (FStart + 1) mod Capacity;
    end
    else begin
      FCount += 1;
      FBuf[EndIndex] := AItem;
    end;
  AddValue(AItem);
end;

procedure TChartSourceBuffer.AddValue(const AItem: TChartDataItem);
var
  i, oldLen: Integer;
begin
  with FSum do begin
    Y += AItem.Y;
    oldLen := Length(YList);
    SetLength(YList, Max(Length(AItem.YList), oldLen));
    for i := oldLen to High(YList) do
      YList[i] := 0;
    for i := 0 to Min(High(YList), High(AItem.YList)) do
      YList[i] += AItem.YList[i];
  end;
end;

procedure TChartSourceBuffer.Clear;
begin
  FCount := 0;
  FSum.Y := 0;
  FSum.YList := nil;
end;

function TChartSourceBuffer.EndIndex: Cardinal;
begin
  Result := (FStart + Cardinal(FCount - 1)) mod Capacity;
end;

function TChartSourceBuffer.GetCapacity: Cardinal;
begin
  Result := Length(FBuf);
end;

function TChartSourceBuffer.GetPLast: PChartDataItem;
begin
  Result := @FBuf[EndIndex];
end;

procedure TChartSourceBuffer.GetSum(var AItem: TChartDataItem);
begin
  AItem.Y := FSum.Y;
  AItem.YList := Copy(FSum.YList);
end;

procedure TChartSourceBuffer.RemoveLast;
begin
  if FCount = 0 then
    raise EBufferError.Create('Empty');
  RemoveValue(FBuf[EndIndex]);
  FCount -= 1;
end;

procedure TChartSourceBuffer.RemoveValue(const AItem: TChartDataItem);
var
  i: Integer;
begin
  with AItem do begin
    FSum.Y -= Y;
    for i := 0 to Min(High(FSum.YList), High(YList)) do
      FSum.YList[i] -= YList[i];
  end;
end;

procedure TChartSourceBuffer.SetCapacity(AValue: Cardinal);
begin
  if AValue = Capacity then exit;
  SetLength(FBuf, AValue);
  Clear;
end;

{ TCustomChartSource }

procedure TCustomChartSource.AfterDraw;
begin
  // empty
end;

procedure TCustomChartSource.BeforeDraw;
begin
  // empty
end;

procedure TCustomChartSource.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

class procedure TCustomChartSource.CheckFormat(const AFormat: String);
begin
  Format(AFormat, [0.0, 0.0, '', 0.0, 0.0]);
end;

constructor TCustomChartSource.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBroadcaster := TBroadcaster.Create;
  FYCount := 1;
end;

destructor TCustomChartSource.Destroy;
begin
  FreeAndNil(FBroadcaster);
  inherited;
end;

procedure TCustomChartSource.EndUpdate;
begin
  Dec(FUpdateCount);
  Notify;
end;

function TCustomChartSource.Extent: TDoubleRect;
var
  i: Integer;
begin
  if FExtentIsValid then exit(FExtent);
  FExtent := EmptyExtent;
  for i := 0 to Count - 1 do
    with Item[i]^ do begin
      UpdateMinMax(X, FExtent.a.X, FExtent.b.X);
      UpdateMinMax(Y, FExtent.a.Y, FExtent.b.Y);
    end;
  FExtentIsValid := true;
  Result := FExtent;
end;

function TCustomChartSource.ExtentCumulative: TDoubleRect;
var
  h: Double;
  i, j: Integer;
begin
  Result := Extent;
  if YCount < 2 then exit;
  for i := 0 to Count - 1 do begin
    h := Item[i]^.Y;
    for j := 0 to YCount - 2 do begin
      h += Item[i]^.YList[j];
      // If some of Y values are negative, h may be non-monotonic.
      UpdateMinMax(h, Result.a.Y, Result.b.Y);
    end;
  end;
end;

function TCustomChartSource.ExtentList: TDoubleRect;
var
  i, j: Integer;
begin
  Result := Extent;
  for i := 0 to Count - 1 do
    with Item[i]^ do
      for j := 0 to High(YList) do
        UpdateMinMax(YList[j], Result.a.Y, Result.b.Y);
end;

procedure TCustomChartSource.FindBounds(
  AXMin, AXMax: Double; out ALB, AUB: Integer);

  function FindLB(X: Double; L, R: Integer): Integer;
  begin
    while L <= R do begin
      Result := (R - L) div 2 + L;
      if Item[Result]^.X < X then
        L := Result + 1
      else
        R := Result - 1;
    end;
    Result := L;
  end;

  function FindUB(X: Double; L, R: Integer): Integer;
  begin
    while L <= R do begin
      Result := (R - L) div 2 + L;
      if Item[Result]^.X <= X then
        L := Result + 1
      else
        R := Result - 1;
    end;
    Result := R;
  end;

begin
  EnsureOrder(AXMin, AXMax);
  if IsSorted then begin
    ALB := FindLB(AXMin, 0, Count - 1);
    AUB := FindUB(AXMax, 0, Count - 1);
  end
  else begin
    ALB := 0;
    while (ALB < Count) and (Item[ALB]^.X < AXMin) do
      Inc(ALB);
    AUB := Count - 1;
    while (AUB >= 0) and (Item[AUB]^.X > AXMax) do
      Dec(AUB);
  end;
end;

function TCustomChartSource.FormatItem(
  const AFormat: String; AIndex, AYIndex: Integer): String;
const
  TO_PERCENT = 100;
var
  total, percent, vy: Double;
begin
  total := ValuesTotal;
  if total = 0 then
    percent := 0
  else
    percent := TO_PERCENT / total;
  with Item[AIndex]^ do begin
    vy := GetY(AYIndex);
    Result := Format(AFormat, [vy, vy * percent, Text, total, X]);
  end;
end;

procedure TCustomChartSource.InvalidateCaches;
begin
  FExtentIsValid := false;
  FValuesTotalIsValid := false;
end;

function TCustomChartSource.IsSorted: Boolean;
begin
  Result := false;
end;

function TCustomChartSource.IsUpdating: Boolean; inline;
begin
  Result := FUpdateCount > 0;
end;

procedure TCustomChartSource.Notify;
begin
  if not IsUpdating then
    FBroadcaster.Broadcast(Self);
end;

procedure TCustomChartSource.ValuesInRange(
  AParams: TValuesInRangeParams; var AValues: TChartValueTextArray);

var
  cnt: Integer;

  procedure Push(AValue: Double; AIndex: Integer);
  begin
    AValues[cnt].FValue := AValue;
    AValues[cnt].FText := FormatItem(AParams.FFormat, AIndex, 0);
    cnt += 1;
  end;

var
  i, li, vi, pvi: Integer;
  pv, v: Double;
begin
  cnt := Length(AValues);
  SetLength(AValues, cnt + Count + 2);
  v := 0;
  li := 0;
  pvi := MaxInt;
  for i := 0 to Count - 1 do begin
    pv := v;
    v := IfThen(AParams.FUseY, Item[i]^.Y, Item[i]^.X);
    if not InRange(v, AParams.FMin, AParams.FMax) then continue;
    if aipUseMinLength in AParams.FIntervals.Options then begin
      vi := AParams.ToImage(v);
      if Abs(vi - pvi) < AParams.FIntervals.MinLength then continue;
      pvi := vi;
    end;
    if (cnt = 0) and (i > 0) then
      Push(pv, i - 1);
    Push(v, i);
    li := i;
  end;
  if not InRange(v, AParams.FMin, AParams.FMax) then
    Push(v, li);
  SetLength(AValues, cnt);
end;

function TCustomChartSource.ValuesTotal: Double;
var
  i: Integer;
begin
  if FValuesTotalIsValid then exit(FValuesTotal);
  FValuesTotal := 0;
  for i := 0 to Count - 1 do
    FValuesTotal += Item[i]^.Y;
  FValuesTotalIsValid := true;
  Result := FValuesTotal;
end;

function TCustomChartSource.XOfMax: Double;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    with Item[i]^ do
      if Y = Extent.b.Y then exit(X);
  Result := 0.0;
end;

function TCustomChartSource.XOfMin: Double;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    with Item[i]^ do
      if Y = Extent.a.Y then exit(X);
  Result := 0.0;
end;

end.

