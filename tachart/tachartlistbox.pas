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

Authors: Werner Pamler, Alexander Klenin

Usage:
- Add the ChartListbox to a form with a TChart
- Connect the chart to the listbox by setting the chart property of the
  TChartlistbox. The ChartListbox will be populated with the series in the
  chart and will automatically track changes of the series.
- Check/uncheck series in the ChartListbox to show/hide them in the chart.
  As usual, checking is done by mouse clicks or by pressing the space bar.
- Play with the properties to modify the standard behavior, e.g. set
  CheckStyle to cbsRadioButton in order to get a radiobutton behavior, i.e. to
  allow only one visible series.
}

unit TAChartListbox;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, StdCtrls,
  TAChartUtils, TACustomSeries, TALegend, TAGraph;

type
  TChartListboxIndexEvent = procedure (
    ASender: TObject; AIndex: Integer) of object;

  TCheckBoxesStyle = (cbsCheckbox, cbsRadiobutton);

  TChartListbox = class(TCustomListbox)
  private
    FChart: TChart;
    FCheckStyle: TCheckBoxesStyle;
    FLegendItems: TChartLegendItems;
    FListener: TListener;
    FLockCount: Integer;
    FOnCheckboxClick: TChartListboxIndexEvent;
    FOnItemClick: TChartListboxIndexEvent;
    FOnPopulate: TNotifyEvent;
    FOnSeriesIconClick: TChartListboxIndexEvent;
    FSeriesIconClicked: Integer;
    FShowCheckboxes: Boolean;
    FShowSeriesIcons: Boolean;
    function GetChecked(AIndex: Integer): Boolean;
    function GetLegendItem(AIndex: Integer): TLegendItem;
    function GetSeries(AIndex: Integer): TCustomChartSeries;
    function GetSeriesCount: Integer;
    procedure SeriesChanged(ASender: TObject);
    procedure SetChart(AValue: TChart);
    procedure SetChecked(AIndex: Integer; AValue: Boolean);
    procedure SetCheckStyle(AValue: TCheckBoxesStyle);
    procedure SetShowCheckboxes(AValue: Boolean);
    procedure SetShowSeriesIcons(AValue: Boolean);

  protected
    procedure DblClick; override;
    procedure DrawItem(
      AIndex: Integer; ARect: TRect; AState: TOwnerDrawState); override;
    procedure KeyDown(var AKey: Word; AShift: TShiftState); override;
    procedure MouseDown(
      AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer); override;
  protected
    procedure CalcRects(
      const AItemRect: TRect; out ACheckboxRect, ASeriesIconRect: TRect);
    procedure ClickedCheckbox(AIndex: Integer); virtual;
    procedure ClickedItem(AIndex: Integer); virtual;
    procedure ClickedSeriesIcon(AIndex: Integer); virtual;
    function CreateLegendItems: TChartLegendItems;
    function FirstCheckedIndex: Integer;
    function IsLocked: Boolean;
    procedure Lock;
    procedure Populate;
    procedure Unlock;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function FindSeriesIndex(ASeries: TCustomChartSeries): Integer;
    procedure MeasureItem(AIndex: Integer; var AHeight: Integer); override;
    procedure RemoveSeries(ASeries: TCustomChartSeries);
    property Checked[AIndex: Integer]: Boolean read GetChecked write SetChecked;
    property Series[AIndex: Integer]: TCustomChartSeries read GetSeries;
    property SeriesCount: Integer read GetSeriesCount;

  published
    property Chart: TChart read FChart write SetChart;
    property CheckStyle: TCheckBoxesStyle
      read FCheckStyle write SetCheckStyle default cbsCheckbox;
    property ShowCheckboxes: Boolean
      read FShowCheckboxes write SetShowCheckboxes default true;
    property ShowSeriesIcons: Boolean
      read FShowSeriesIcons write SetShowSeriesIcons default true;
  published
    property OnCheckboxClick: TChartListboxIndexEvent
      read FOnCheckboxClick write FOnCheckboxClick;
    property OnItemClick: TChartListboxIndexEvent
      read FOnItemClick write FOnItemClick;
    property OnPopulate: TNotifyEvent read FOnPopulate write FOnPopulate;
    property OnSeriesIconClick: TChartListboxIndexEvent
      read FOnSeriesIconClick write FOnSeriesIconClick;
  published
    property Align;
//    property AllowGrayed;
    property Anchors;
    property BidiMode;
    property BorderSpacing;
    property BorderStyle;
    property Color;
    property Columns;
    property Constraints;
    property DragCursor;
    property DragMode;
    property Enabled;
    property ExtendedSelect;
    property Font;
    property IntegralHeight;
//    property Items;
    property ItemHeight;
    property MultiSelect;
    property OnChangeBounds;
    property OnClick;
//    property OnClickCheck;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnDrawItem;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
//    property OnItemClick;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnShowHint;
    property OnStartDrag;
    property OnUTF8KeyPress;
    property ParentBidiMode;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Sorted;
//    property Style;
    property TabOrder;
    property TabStop;
    property TopIndex;
    property Visible;
  end;

procedure Register;


implementation

uses
  Math, LCLIntf, LCLType, SysUtils, Themes,
  TAGeometry, TADrawUtils, TADrawerCanvas;

procedure Register;
begin
  RegisterComponents(CHART_COMPONENT_IDE_PAGE, [TChartListbox]);
end;

constructor TChartListbox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Style := lbOwnerDrawFixed;
  FListener := TListener.Create(@FChart, @SeriesChanged);
  FShowSeriesIcons := true;
  FShowCheckboxes := true;
end;

destructor TChartListbox.Destroy;
begin
  FreeAndNil(FListener);
  FreeAndNil(FLegendItems);
  inherited;
end;

procedure TChartListbox.CalcRects(
  const AItemRect: TRect; out ACheckboxRect, ASeriesIconRect: TRect);
{ based on the rect of a listbox item, calculates the locations of the
  checkbox and of the series icon }
var
  w, x: Integer;
begin
  ACheckBoxRect := Rect(-1, -1, -1, -1);
  ASeriesIconRect := Rect(-1, -1, -1, -1);
  w := GetSystemMetrics(SM_CYMENUCHECK);
  x := 2;
  if FShowCheckboxes then begin
    ACheckboxRect := Bounds(AItemRect.Left + 1, AItemRect.Top + 1, w, w);
    if FShowSeriesIcons then
      x += ACheckboxRect.Right;
  end
  else begin
    if FShowSeriesIcons then
      x += AItemRect.Left;
  end;
  if FShowSeriesIcons then
    ASeriesIconRect := Rect(
      x, AItemRect.Top + 2, x + FChart.Legend.SymbolWidth, AItemRect.Bottom - 2);
end;

procedure TChartListbox.ClickedCheckbox(AIndex: Integer);
begin
  Checked[AIndex] := not Checked[AIndex];
  if Assigned(OnCheckboxClick) then
    OnCheckboxClick(Self, AIndex);
end;

procedure TChartListbox.ClickedItem(AIndex: Integer);
begin
  if Assigned(OnItemClick) then
    OnItemClick(Self, AIndex);
end;

procedure TChartListbox.ClickedSeriesIcon(AIndex: Integer);
begin
  if Assigned(OnSeriesIconClick) then
    OnSeriesIconClick(Self, AIndex);
end;

function TChartListbox.CreateLegendItems: TChartLegendItems;
{ creates the a TLegendItems list and populates it with information for
  all series contained in the Chart. In case of MultiLegend items, only
  a single legend item is used }
var
  i: Integer;
  j: Integer = MaxInt;
begin
  Result := TChartLegendItems.Create;
  try
    if FChart = nil then exit;
    for i := 0 to FChart.SeriesCount - 1 do
      if FChart.Series[i] is TCustomChartSeries then
        TCustomChartSeries(FChart.Series[i]).GetSingleLegendItem(Result);
    for i := Result.Count - 1 downto 0 do
      if Result[i].Order = LEGEND_ITEM_ORDER_AS_ADDED then begin
        Result[i].Order := j;
        j -= 1;
      end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

procedure TChartListbox.DblClick;
begin
  inherited DblClick;
  if FSeriesIconClicked <> -1 then
    ClickedSeriesIcon(FSeriesIconClicked);
end;

procedure TChartListbox.DrawItem(
  AIndex: Integer; ARect: TRect; AState: TOwnerDrawState);
{ draws the listbox item }
const
  UNTHEMED_FLAGS: array [TCheckboxesStyle, Boolean] of Integer = (
    (DFCS_BUTTONCHECK, DFCS_BUTTONCHECK or DFCS_CHECKED),
    (DFCS_BUTTONRADIO, DFCS_BUTTONRADIO or DFCS_CHECKED)
  );
  THEMED_FLAGS: array [TCheckboxesStyle, Boolean] of TThemedButton = (
    (tbCheckBoxUncheckedNormal, tbCheckBoxCheckedNormal),
    (tbRadioButtonUnCheckedNormal, tbRadioButtonCheckedNormal)
  );
var
  id: IChartDrawer;
  rcb, ricon: TRect;
  te: TThemedElementDetails;
  x: Integer;
  ch: Boolean;
begin
  Unused(AState);

  if FChart = nil then exit;

  CalcRects(ARect, rcb, ricon);

  if FShowCheckboxes then begin
    ch := Checked[AIndex];
    if ThemeServices.ThemesEnabled then begin
      te := ThemeServices.GetElementDetails(THEMED_FLAGS[FCheckStyle, ch]);
      ThemeServices.DrawElement(Canvas.Handle, te, rcb);
    end
    else
      DrawFrameControl(
        Canvas.Handle, rcb, DFC_BUTTON, UNTHEMED_FLAGS[FCheckStyle, ch]);
    x := rcb.Right;
  end
  else
    x := ARect.Left;

  if FShowSeriesIcons then begin
    id := TCanvasDrawer.Create(Canvas);
    id.Pen := Chart.Legend.SymbolFrame;
    FLegendItems[AIndex].Draw(id, ricon);
  end
  else
    Canvas.TextOut(x + 2, ARect.Top, FLegendItems.Items[AIndex].Text);
end;

function TChartListbox.FindSeriesIndex(ASeries: TCustomChartSeries): Integer;
{ searches the internal legend items list for the specified series }
begin
  for Result := 0 to FLegendItems.Count - 1 do
    if GetSeries(Result) = ASeries then exit;
  Result := -1;
end;

function TChartListbox.FirstCheckedIndex: Integer;
{ Returns the index of the first listbox series that is active }
begin
  for Result := 0 to FLegendItems.Count - 1 do
    if Checked[Result] then exit;
  Result := -1;
end;

function TChartListbox.GetChecked(AIndex: Integer): Boolean;
{ report the checked status. This is determined by the visibility of the
  series with the given index. }
var
  ser: TBasicChartSeries;
begin
  ser := GetSeries(AIndex);
  Result := (ser <> nil) and ser.Active;
end;

function TChartListbox.GetLegendItem(AIndex: Integer): TLegendItem;
begin
  Result := FLegendItems[AIndex];
end;

function TChartListbox.GetSeries(AIndex: Integer): TCustomChartSeries;
{ extracts, for the given index, the series from the internal
  legend items list. }
var
  legitem: TLegendItem;
begin
  legitem := GetLegendItem(AIndex);
  if (legitem <> nil) and (legitem.Owner is TCustomChartSeries) then
    Result := TCustomChartSeries(legitem.Owner)
  else
    Result := nil;
end;

function TChartListbox.GetSeriesCount : Integer;
{ determines the number of series displayed in the listbox.
  Note that this may be different from the Chart.SeriesCount if
  RemoveSeries has been called }
begin
  Result := FLegendItems.Count;
end;

function TChartListbox.IsLocked : Boolean;
begin
  Result := FLockCount <> 0;
end;

procedure TChartListbox.KeyDown(var AKey: Word; AShift: TShiftState);
{ allows checking/unchecking of items by means of pressing the space bar }
begin
  if (AKey = VK_SPACE) and (AShift = []) and FShowCheckboxes then begin
    ClickedCheckbox(ItemIndex);
    AKey := VK_UNKNOWN;
  end
  else
    inherited KeyDown(AKey, AShift);
end;

procedure TChartListbox.Lock;
{ locking mechanism to avoid excessive broadcasting of chart changes.
  See also: IsLocked and UnLock }
begin
  FLockCount += 1;
end;

procedure TChartListbox.MeasureItem(AIndex: Integer; var AHeight: Integer);
{ inherited from ancestor: measures the height of a listbox item taking into
  account the height of the checkbox }
begin
  Unused(AIndex);
  AHeight := CalculateStandardItemHeight;
  if FShowCheckboxes then
    AHeight := Max(AHeight, GetSystemMetrics(SM_CYMENUCHECK) + 2);
end;

procedure TChartListbox.MouseDown(
  AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer);
{ standard MouseDown handler: checks if the click occured on the checkbox,
  on the series icon, or on the text.
  The visibility state of the item's series is changed when clicking on the
  checkbox, and an event OnCheckboxClick is generated.
  An event OnSeriesIconClick is generated when double-clicking on the
  series icon; the method stores the series list index here.
  An event OnItemClick is generated when the click occured neither on the
  checkbox nor the series icon.
}
var
  rcb, ricon: TRect;
  index: Integer;
  p: TPoint;
begin
  FSeriesIconClicked := -1;
  try
    if AButton <> mbLeft then exit;
    p := Point(AX, AY);
    index := GetIndexAtXY(AX, AY);
    if index < 0 then exit;
    CalcRects(ItemRect(index), rcb, ricon);
    if FShowCheckboxes and IsPointInRect(p, rcb) then
      ClickedCheckbox(index)
    else if FShowSeriesIcons and IsPointInRect(p, ricon) then
      // Remember clicked index for the double click event.
      FSeriesIconClicked := index
    else
      ClickedItem(index);
  finally
    inherited MouseDown(AButton, AShift, AX, AY);
  end;
end;

procedure TChartListbox.Populate;
{ populates the listbox with all series contained in the chart. Use the event
  OnPopulate if you don't omit special series from the listbox (RemoveSeries) }
var
  i: Integer;
begin
  Items.BeginUpdate;
  try
    Items.Clear;
    if FChart = nil then exit;
    FreeAndNil(FLegendItems);
    FLegendItems := CreateLegendItems;
    for i := 0 to FLegendItems.Count - 1 do
      // The caption is owner-drawn, but add it anyway for user convenience.
      Items.AddObject(FLegendItems[i].Text, FLegendItems[i]);

    if Assigned(OnPopulate) then
      OnPopulate(Self);
  finally
    Items.EndUpdate;
  end;
end;

procedure TChartListbox.RemoveSeries(ASeries: TCustomChartSeries);
{ removes the series from the listbox, but keeps it in the chart }
var
  index: Integer;
begin
  index := FindSeriesIndex(ASeries);
  if index = -1 then exit;
  FLegendItems.Delete(index);
  Items.Delete(index);
  Invalidate;
end;

procedure TChartListbox.SeriesChanged(ASender: TObject);
{ Notification procedure of the listener. Responds to chart broadcasts
  by populating the listbox with the chart's series }
var
  index: Integer;
begin
  if IsLocked then exit;
  Populate;
  { in case of radiobutton mode, it is necessary to uncheck the other
    series; there can be only one active series in this mode }
  if (FCheckStyle = cbsRadioButton) and (ASender is TBasicChartSeries) then
  begin
    index := FindSeriesIndex(ASender as TCustomChartSeries);
    if index <> -1 then
      Checked[index] := (ASender as TCustomChartSeries).Active;
  end;
end;

procedure TChartListbox.SetChart(AValue: TChart);
{ connects the ListBox to the chart }
begin
  if FChart = AValue then exit;

  if FListener.IsListening then
    FChart.Broadcaster.Unsubscribe(FListener);
  FChart := AValue;
  if FChart <> nil then
    FChart.Broadcaster.Subscribe(FListener);
  SeriesChanged(Self);
end;

procedure TChartListbox.SetChecked(AIndex: Integer; AValue: Boolean);
{ shows/hides the series with the specified index of its listbox item.
  In case of radiobutton style, all other series are hidden if AValue=true }
var
  ser: TBasicChartSeries;
  i: Integer;
begin
  ser := GetSeries(AIndex);
  if ser = nil then exit;
  Lock;
  try
    ser.Active := AValue;
    if AValue and (FCheckStyle = cbsRadioButton) then
      for i := 0 to FLegendItems.Count - 1 do begin
        ser := GetSeries(i);
        if (i <> AIndex) and (ser <> nil) then
          ser.Active := false;
      end;
    Invalidate;
  finally
    Unlock;
  end;
end;

procedure TChartlistbox.SetCheckStyle(AValue: TCheckBoxesStyle);
{ selects "checkbox" or "radiobutton" styles. In radiobutton mode, only
  one series can be visible }
var
  j: Integer;
begin
  if FCheckStyle = AValue then exit;
  FCheckStyle := AValue;
  if FCheckStyle = cbsRadioButton then begin
    j := FirstCheckedIndex;
    if j <> -1 then
      Checked[j] := true;
  end;
  Invalidate;
end;

procedure TChartListbox.SetShowCheckboxes(AValue: Boolean);
begin
  if FShowCheckboxes = AValue then exit;
  FShowCheckboxes := AValue;
  Invalidate;
end;

procedure TChartListbox.SetShowSeriesIcons(AValue: Boolean);
begin
  if FShowSeriesIcons = AValue then exit;
  FShowSeriesIcons := AValue;
  Invalidate;
end;

procedure TChartListbox.Unlock;
begin
  FLockCount -= 1;
end;

end.

