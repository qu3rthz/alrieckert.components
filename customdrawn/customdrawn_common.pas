unit customdrawn_common;

{$mode objfpc}{$H+}

interface

uses
  // RTL
  Classes, SysUtils, Types, Math,
  // LazUtils
  lazutf8,
  // LCL -> Use only TForm, TWinControl, TCanvas and TLazIntfImage
  Graphics, Controls, LCLType,
  // Others only for types
  StdCtrls, ComCtrls,
  //
  customdrawndrawers;

type

  { TCDDrawerCommon }

  TCDDrawerCommon = class(TCDDrawer)
  public
    procedure LoadFallbackPaletteColors; override;
    // General
    function GetMeasures(AMeasureID: Integer): Integer; override;
    function GetMeasuresEx(ADest: TCanvas; AMeasureID: Integer;
      AState: TCDControlState; AStateEx: TCDControlStateEx): Integer; override;
    procedure CalculatePreferredSize(ADest: TCanvas; AControlId: TCDControlID;
      AState: TCDControlState; AStateEx: TCDControlStateEx;
      var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    function GetColor(AColorID: Integer): TColor; override;
    function GetClientArea(ADest: TCanvas; ASize: TSize; AControlId: TCDControlID;
      AState: TCDControlState; AStateEx: TCDControlStateEx): TRect; override;
    // General drawing routines
    procedure DrawFocusRect(ADest: TCanvas; ADestPos: TPoint; ASize: TSize); override;
    procedure DrawRaisedFrame(ADest: TCanvas; ADestPos: TPoint; ASize: TSize); override;
    procedure DrawSunkenFrame(ADest: TCanvas; ADestPos: TPoint; ASize: TSize); override;
    procedure DrawShallowSunkenFrame(ADest: TCanvas; ADestPos: TPoint; ASize: TSize); override;
    procedure DrawTickmark(ADest: TCanvas; ADestPos: TPoint); override;
    procedure DrawSlider(ADest: TCanvas; ADestPos: TPoint; ASize: TSize; AState: TCDControlState); override;
    procedure DrawCompactArrow(ADest: TCanvas; ADestPos: TPoint; ADirection: TCDControlState); override;
    // TCDControl
    procedure DrawControl(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDControlStateEx); override;
    // ===================================
    // Standard Tab
    // ===================================
    // TCDButton
    procedure DrawButton(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDControlStateEx); override;
    // TCDEdit
    procedure DrawEditBackground(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDEditStateEx); override;
    procedure DrawCaret(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDEditStateEx); override;
    procedure DrawEdit(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDEditStateEx); override;
    // TCDCheckBox
    procedure DrawCheckBoxSquare(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDControlStateEx); override;
    procedure DrawCheckBox(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDControlStateEx); override;
    // TCDRadioButton
    procedure DrawRadioButtonCircle(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDControlStateEx); override;
    procedure DrawRadioButton(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDControlStateEx); override;
    // TCDScrollBar
    procedure DrawScrollBar(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDPositionedCStateEx); override;
    // TCDGroupBox
    procedure DrawGroupBox(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDControlStateEx); override;
    // ===================================
    // Additional Tab
    // ===================================
    procedure DrawStaticText(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDControlStateEx); override;
    // ===================================
    // Common Controls Tab
    // ===================================
    // TCDTrackBar
    procedure DrawTrackBar(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDPositionedCStateEx); override;
    // TCDProgressBar
    procedure DrawProgressBar(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDProgressBarStateEx); override;
    // TCDListView
    procedure DrawListView(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDListViewStateEx); override;
    procedure DrawReportListView(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDListViewStateEx); override;
    procedure DrawReportListViewItem(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      ACurItem: TCDListItems; AState: TCDControlState; AStateEx: TCDListViewStateEx); override;
    // TCDCustomTabControl
    procedure DrawCTabControl(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDCTabControlStateEx); override;
    procedure DrawCTabControlFrame(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDCTabControlStateEx); override;
    procedure DrawTabSheet(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDCTabControlStateEx); override;
    procedure DrawTabs(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDCTabControlStateEx); override;
    procedure DrawTab(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDCTabControlStateEx); override;
  end;

implementation

const
  WIN2000_FRAME_WHITE = clWhite;
  WIN2000_FRAME_LIGHT_GRAY = $00E2EFF1;
  WIN2000_FRAME_GRAY = $0099A8AC;
  WIN2000_FRAME_DARK_GRAY = $00646F71;

  WIN2000_SCROLLBAR_BACKGROUND = $00ECF4F6;

  WIN2000_PROGRESSBAR_BLUE = $00C56A31;

  WIN2000_BTNFACE = $00D8E9EC;

  WIN2000_FORM    = WIN2000_BTNFACE;

{ TCDDrawerCommon }

procedure TCDDrawerCommon.LoadFallbackPaletteColors;
begin
  Palette.BtnFace := WIN2000_BTNFACE;
  Palette.Form := WIN2000_FORM;
  Palette.Window := clWhite; // The inside of a Edit control, for example
end;

function TCDDrawerCommon.GetMeasures(AMeasureID: Integer): Integer;
begin
  case AMeasureID of
  TCDEDIT_LEFT_TEXT_SPACING: Result := 4;
  TCDEDIT_RIGHT_TEXT_SPACING: Result := 3;
  TCDEDIT_TOP_TEXT_SPACING: Result := 3;
  TCDEDIT_BOTTOM_TEXT_SPACING: Result := 3;
  //
  TCDCHECKBOX_SQUARE_HALF_HEIGHT: Result := 7;
  TCDCHECKBOX_SQUARE_HEIGHT: Result := 15;
  //
  TCDRADIOBUTTON_CIRCLE_HEIGHT: Result := 15;
  //
  TCDSCROLLBAR_BUTTON_WIDTH: Result := 17;
  TCDSCROLLBAR_LEFT_SPACING: Result := 17;
  TCDSCROLLBAR_RIGHT_SPACING: Result := 17;
  TCDSCROLLBAR_LEFT_BUTTON_POS: Result := 0;
  TCDSCROLLBAR_RIGHT_BUTTON_POS: Result := -17;
  //
  TCDTRACKBAR_LEFT_SPACING: Result := 9;
  TCDTRACKBAR_RIGHT_SPACING: Result := 9;
  TCDTRACKBAR_TOP_SPACING: Result := 5;
  TCDTRACKBAR_FRAME_HEIGHT: Result := 17;
  //
  TCDLISTVIEW_COLUMN_LEFT_SPACING:  Result := 10;
  TCDLISTVIEW_COLUMN_RIGHT_SPACING: Result := 10;
  TCDLISTVIEW_COLUMN_TEXT_LEFT_SPACING:  Result := 5;
  TCDLISTVIEW_LINE_TOP_SPACING: Result := 3;
  TCDLISTVIEW_LINE_BOTTOM_SPACING: Result := 3;
  else
    Result := 0;
  end;
end;

function TCDDrawerCommon.GetMeasuresEx(ADest: TCanvas; AMeasureID: Integer;
  AState: TCDControlState; AStateEx: TCDControlStateEx): Integer;
const
  TCDTabControl_Common_TabCaptionExtraWidth = 20;
var
  ATabsStateEx: TCDCTabControlStateEx absolute AStateEx;
  lCaption: String;
begin
  ADest.Font.Assign(AStateEx.Font);

  case AMeasureID of
  TCDCONTROL_CAPTION_WIDTH:  Result := ADest.TextWidth(AStateEx.Caption);
  TCDCONTROL_CAPTION_HEIGHT: Result := ADest.TextHeight(cddTestStr)+3;
  TCDCTABCONTROL_TAB_HEIGHT: Result := ADest.TextHeight(cddTestStr)+10;
  TCDCTABCONTROL_TAB_WIDTH:
  begin
    lCaption := ATabsStateEx.Tabs.Strings[ATabsStateEx.CurTabIndex];
    Result := ADest.TextWidth(lCaption) + TCDTabControl_Common_TabCaptionExtraWidth;
  end
  else
    Result := 0;
  end;
end;

procedure TCDDrawerCommon.CalculatePreferredSize(ADest: TCanvas;
  AControlId: TCDControlID; AState: TCDControlState;
  AStateEx: TCDControlStateEx; var PreferredWidth, PreferredHeight: integer;
  WithThemeSpace: Boolean);
begin
  PreferredWidth := 0;
  PreferredHeight := 0;

  case AControlId of
  // In the LCL TEdit AutoSizes only its Height, so follow this here
  cidEdit: PreferredHeight := GetMeasuresEx(ADest, TCDCONTROL_CAPTION_HEIGHT, AState, AStateEx)+5;
  cidCheckBox, cidRadioButton:
  begin
    if AStateEx.AutoSize then
      PreferredWidth := 21 + GetMeasuresEx(ADest, TCDCONTROL_CAPTION_WIDTH, AState, AStateEx);

    PreferredHeight := GetMeasuresEx(ADest, TCDCONTROL_CAPTION_HEIGHT, AState, AStateEx);
  end;
  end;
end;

function TCDDrawerCommon.GetColor(AColorID: Integer): TColor;
begin
  case AColorId of
  TCDEDIT_BACKGROUND_COLOR:    Result := clWhite;
  TCDEDIT_TEXT_COLOR:          Result := clBlack;
  TCDEDIT_SELECTED_BACKGROUND_COLOR: Result := clBlue;
  TCDEDIT_SELECTED_TEXT_COLOR: Result := clWhite;
  TCDBUTTON_DEFAULT_COLOR:     Result := $00F1F5F5;
  else
    Result := clBlack;
  end;
end;

function TCDDrawerCommon.GetClientArea(ADest: TCanvas; ASize: TSize;
  AControlId: TCDControlID; AState: TCDControlState; AStateEx: TCDControlStateEx
  ): TRect;
begin
  Result := Bounds(0, 0, ASize.cx, ASize.cy);

  case AControlId of
  cidCTabControl:
  begin
    Result.Top := GetMeasuresEx(ADest, TCDCTABCONTROL_TAB_HEIGHT, AState, AStateEx) + 2;
    Result.Left := 2;
    Result.Right := Result.Right - 2;
    Result.Bottom := Result.Bottom - 2;
  end;
  end;
end;

procedure TCDDrawerCommon.DrawFocusRect(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize);
begin
  ADest.Pen.Color := clWhite;
  ADest.Pen.Style := psSolid;
  ADest.Brush.Style := bsClear;
  ADest.Rectangle(ADestPos.X, ADestPos.Y, ADestPos.X + ASize.CX, ADestPos.Y + ASize.CY);
  ADest.Pen.Color := clBlack;
  ADest.Pen.Style := psDot;
  ADest.Rectangle(ADestPos.X, ADestPos.Y, ADestPos.X + ASize.CX, ADestPos.Y + ASize.CY);
end;

procedure TCDDrawerCommon.DrawRaisedFrame(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize);
begin
  // white lines in the left and top
  ADest.Pen.Style := psSolid;
  ADest.Brush.Style := bsClear;
  ADest.Pen.Color := WIN2000_FRAME_WHITE;
  ADest.MoveTo(ADestPos.X, ADestPos.Y+ASize.cy-1);
  ADest.LineTo(ADestPos.X, ADestPos.Y);
  ADest.LineTo(ADestPos.X+ASize.cy-1, ADestPos.Y);
  // Grey line on the inside left and top
  ADest.Pen.Color := WIN2000_FRAME_LIGHT_GRAY;
  ADest.MoveTo(ADestPos.X+1, ADestPos.Y+ASize.cy-2);
  ADest.LineTo(ADestPos.X+1, ADestPos.Y+1);
  ADest.LineTo(ADestPos.X+ASize.cx-1, ADestPos.Y+1);
  // Dark grey line on the right and bottom
  ADest.Pen.Color := WIN2000_FRAME_DARK_GRAY;
  ADest.MoveTo(ADestPos.X,            ADestPos.Y+ASize.cy-1);
  ADest.LineTo(ADestPos.X+ASize.cx-1, ADestPos.Y+ASize.cy-1);
  ADest.LineTo(ADestPos.X+ASize.cx-1, ADestPos.Y);
  // Grey line on the inside right and bottom
  ADest.Pen.Color := WIN2000_FRAME_GRAY;
  ADest.MoveTo(ADestPos.X+1,          ADestPos.Y+ASize.cy-2);
  ADest.LineTo(ADestPos.X+ASize.cx-2, ADestPos.Y+ASize.cy-2);
  ADest.LineTo(ADestPos.X+ASize.cx-2, ADestPos.Y-1);
end;

procedure TCDDrawerCommon.DrawSunkenFrame(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize);
begin
  // The Frame, except the lower-bottom which is white anyway
  // outter top-right
  ADest.Pen.Style := psSolid;
  ADest.Pen.Color := WIN2000_FRAME_GRAY;
  ADest.MoveTo(ADestPos.X,            ADestPos.Y+ASize.cy-1);
  ADest.LineTo(ADestPos.X,            ADestPos.Y);
  ADest.LineTo(ADestPos.X+ASize.cx-1, ADestPos.Y);
  // inner top-right
  ADest.Pen.Color := WIN2000_FRAME_DARK_GRAY;
  ADest.MoveTo(ADestPos.X+1,          ADestPos.Y+ASize.cy-2);
  ADest.LineTo(ADestPos.X+1,          ADestPos.Y+1);
  ADest.LineTo(ADestPos.X+ASize.cx-2, ADestPos.Y+1);
  // inner bottom-right
  ADest.Pen.Color := WIN2000_FRAME_LIGHT_GRAY;
  ADest.MoveTo(ADestPos.X+1,          ADestPos.Y+ASize.cy-2);
  ADest.LineTo(ADestPos.X+ASize.cx-2, ADestPos.Y+ASize.cy-2);
  ADest.LineTo(ADestPos.X+ASize.cx-2, ADestPos.Y);
  // outter bottom-right
  ADest.Pen.Color := WIN2000_FRAME_WHITE;
  ADest.MoveTo(ADestPos.X+1,          ADestPos.Y+ASize.cy-1);
  ADest.LineTo(ADestPos.X+ASize.cx-1, ADestPos.Y+ASize.cy-1);
  ADest.LineTo(ADestPos.X+ASize.cx-1, ADestPos.Y);
end;

procedure TCDDrawerCommon.DrawShallowSunkenFrame(ADest: TCanvas;
  ADestPos: TPoint; ASize: TSize);
begin
  // Inside area, there is no background because the control occupies the entire area
  ADest.Pen.Style := psSolid;
  ADest.Pen.Color := WIN2000_FRAME_GRAY;
  ADest.MoveTo(ADestPos.X, ADestPos.Y + ASize.cy);
  ADest.LineTo(ADestPos.X, ADestPos.Y);
  ADest.LineTo(ADestPos.X + ASize.cx, ADestPos.Y);
  ADest.Pen.Color := WIN2000_FRAME_WHITE;
  ADest.MoveTo(ADestPos.X, ADestPos.Y + ASize.cy-1);
  ADest.LineTo(ADestPos.X + ASize.cx-1, ADestPos.Y + ASize.cy-1);
  ADest.LineTo(ADestPos.X + ASize.cx-1, ADestPos.Y-1);
end;

procedure TCDDrawerCommon.DrawTickmark(ADest: TCanvas; ADestPos: TPoint);
var
  i: Integer;
begin
  ADest.Pen.Color := clBlack;
  ADest.Pen.Style := psSolid;
  // 4 lines going down and to the right
  for i := 0 to 3 do
    ADest.Line(ADestPos.X+2+i, ADestPos.Y+2+i, ADestPos.X+2+i, ADestPos.Y+5+i);
  // Now 5 lines going up and to the right
  for i := 4 to 8 do
    ADest.Line(ADestPos.X+2+i, ADestPos.Y+2+6-i, ADestPos.X+2+i, ADestPos.Y+5+6-i);
end;

procedure TCDDrawerCommon.DrawSlider(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState);
var
  lPoints: array[0..4] of TPoint;
  lSliderBottom: Integer;
begin
  ADest.Brush.Color := Palette.BtnFace;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Color := WIN2000_FRAME_WHITE;

  if csfHorizontal in AState then
  begin
    lSliderBottom := ADestPos.Y+ASize.CY;
    // outter white frame
    lPoints[0] := Point(ADestPos.X+5, lSliderBottom);
    lPoints[1] := Point(ADestPos.X, lSliderBottom-5);
    lPoints[2] := Point(ADestPos.X, ADestPos.Y);
    lPoints[3] := Point(ADestPos.X+10, ADestPos.Y);
    lPoints[4] := Point(ADestPos.X+10, lSliderBottom-5);
    ADest.Polygon(lPoints);
    // left-top inner frame
    ADest.Pen.Color := WIN2000_FRAME_LIGHT_GRAY;
    ADest.MoveTo(ADestPos.X+5, lSliderBottom-1);
    ADest.LineTo(ADestPos.X+1, lSliderBottom-5);
    ADest.LineTo(ADestPos.X+1, ADestPos.Y+1);
    ADest.LineTo(ADestPos.X+9, ADestPos.Y+1);
    // right inner frame
    ADest.Pen.Color := WIN2000_FRAME_GRAY;
    ADest.MoveTo(ADestPos.X+5, lSliderBottom-1);
    ADest.LineTo(ADestPos.X+9, lSliderBottom-5);
    ADest.LineTo(ADestPos.X+9, ADestPos.Y);
    // right outter frame
    ADest.Pen.Color := WIN2000_FRAME_DARK_GRAY;
    ADest.MoveTo(ADestPos.X+5, lSliderBottom);
    ADest.LineTo(ADestPos.X+10, lSliderBottom-5);
    ADest.LineTo(ADestPos.X+10, ADestPos.Y-1);
  end
  else
  begin
    lSliderBottom := ADestPos.Y+ASize.CY;
    // outter white frame
    lPoints[0] := Point(lSliderBottom, ADestPos.X+5);
    lPoints[1] := Point(lSliderBottom-5, ADestPos.X);
    lPoints[2] := Point(ADestPos.Y, ADestPos.X);
    lPoints[3] := Point(ADestPos.Y, ADestPos.X+10);
    lPoints[4] := Point(lSliderBottom-5, ADestPos.X+10);
    ADest.Polygon(lPoints);
    // left-top inner frame
    ADest.Pen.Color := WIN2000_FRAME_LIGHT_GRAY;
    ADest.MoveTo(lSliderBottom-1, ADestPos.X+5);
    ADest.LineTo(lSliderBottom-5, ADestPos.X+1);
    ADest.LineTo(ADestPos.Y+1, ADestPos.X+1);
    ADest.LineTo(ADestPos.Y+1, ADestPos.X+9);
    // right inner frame
    ADest.Pen.Color := WIN2000_FRAME_GRAY;
    ADest.MoveTo(lSliderBottom-1, ADestPos.X+5);
    ADest.LineTo(lSliderBottom-5, ADestPos.X+9);
    ADest.LineTo(ADestPos.Y, ADestPos.X+9);
    // right outter frame
    ADest.Pen.Color := WIN2000_FRAME_DARK_GRAY;
    ADest.MoveTo(lSliderBottom, ADestPos.X+5);
    ADest.LineTo(lSliderBottom-5, ADestPos.X+10);
    ADest.LineTo(ADestPos.Y-1, ADestPos.X+10);
  end;
end;

procedure TCDDrawerCommon.DrawCompactArrow(ADest: TCanvas; ADestPos: TPoint;
  ADirection: TCDControlState);
var
  lPoints: array[0..2] of TPoint;
  lPos: TPoint;
begin
  lPos := ADestPos;
  // Move the arrow a little bit when a sunken state is passed
  if csfSunken in ADirection then lPos := Point(lPos.X+1, lPos.Y+1);

  if csfLeftArrow in ADirection then
  begin
    lPoints[0] := Point(lPos.X,   lPos.Y+3);// left point
    lPoints[1] := Point(lPos.X+3, lPos.Y+6);// lower point
    lPoints[2] := Point(lPos.X+3, lPos.Y);  // upper point
  end
  else if csfRightArrow in ADirection then
  begin
    lPoints[0] := Point(lPos.X+1, lPos.Y);  // upper point
    lPoints[1] := Point(lPos.X+1, lPos.Y+6);// lower point
    lPoints[2] := Point(lPos.X+4, lPos.Y+3);// right point
  end
  else if csfUpArrow in ADirection then
  begin
    lPoints[0] := Point(lPos.X+3, lPos.Y);  // upper point
    lPoints[1] := Point(lPos.X,   lPos.Y+3);// left point
    lPoints[2] := Point(lPos.X+6, lPos.Y+3);// right point
  end
  else // downArrow
  begin
    lPoints[0] := Point(lPos.X,   lPos.Y+1);// left point
    lPoints[1] := Point(lPos.X+6, lPos.Y+1);// right point
    lPoints[2] := Point(lPos.X+3, lPos.Y+4);// lower point
  end;
  ADest.Brush.Style := bsSolid;
  ADest.Brush.Color := clBlack;
  ADest.Pen.Style := psSolid;
  ADest.Pen.Color := clBlack;
  ADest.Polygon(lPoints);
end;

procedure TCDDrawerCommon.DrawControl(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDControlStateEx);
var
  lColor: TColor;
begin
  // Background
  lColor := AStateEx.RGBColor;
  ADest.Brush.Color := lColor;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Style := psSolid;
  ADest.Pen.Color := lColor;
  ADest.FillRect(0, 0, ASize.cx, ASize.cy);
end;

procedure TCDDrawerCommon.DrawButton(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDControlStateEx);
var
  Str: string;
begin
  // Button shape -> This crashes in Gtk2
  ADest.Brush.Color := AStateEx.RGBColor;
  ADest.Brush.Style := bsSolid;
  ADest.RoundRect(0, 0, ASize.cx, ASize.cy, 8, 8);

  ADest.Brush.Style := bsSolid;
  ADest.Brush.Color := AStateEx.RGBColor;
  ADest.Pen.Color := clWhite;
  ADest.Pen.Style := psSolid;
  ADest.Rectangle(0, 0, ASize.cx - 1, ASize.cy - 1);
  ADest.Pen.Color := clWhite;
  ADest.Line(0, 0, ASize.cx - 1, 0);
  ADest.Line(0, 0, 0, ASize.cy - 1);
  ADest.Pen.Color := clGray;
  ADest.Line(0, ASize.cy - 1, ASize.cx - 1, ASize.cy - 1);
  ADest.Line(ASize.cx - 1, ASize.cy - 1, ASize.cx - 1, -1);
  ADest.Pen.Color := $0099A8AC;
  ADest.Line(1, ASize.cy - 2, ASize.cx - 2, ASize.cy - 2);
  ADest.Line(ASize.cx - 2, ASize.cx - 2, ASize.cx - 2, 0);
  ADest.Pen.Color := $00E2EFF1;
  ADest.Line(1, 1, ASize.cx - 2, 1);
  ADest.Line(1, 1, 1, ASize.cy - 2);

  // Button image
  if csfSunken in AState then
  begin
    ADest.Brush.Style := bsSolid;
    ADest.Brush.Color := AStateEx.RGBColor;
    ADest.Pen.Color := clWhite;
    ADest.Pen.Style := psSolid;
    ADest.Rectangle(0, 0, ASize.cx - 1, ASize.cy - 1);
    ADest.Pen.Color := clGray;
    ADest.Line(0, 0, ASize.cx - 1, 0);
    ADest.Line(0, 0, 0, ASize.cy - 1);
    ADest.Pen.Color := clWhite;
    ADest.Line(0, ASize.cy - 1, ASize.cx - 1, ASize.cy - 1);
    ADest.Line(ASize.cx - 1, ASize.cy - 1, ASize.cx - 1, -1);
    ADest.Pen.Color := $00E2EFF1;
    ADest.Line(1, ASize.cy - 2, ASize.cx - 2, ASize.cy - 2);
    ADest.Line(ASize.cx - 2, ASize.cy - 2, ASize.cx - 2, 0);
    ADest.Pen.Color := $0099A8AC;
    ADest.Line(1, 1, ASize.cx - 2, 1);
    ADest.Line(1, 1, 1, ASize.cy - 2);
  end
  else if csfHasFocus in AState then
  begin
    ADest.Brush.Style := bsClear;
    ADest.Pen.Color := clWhite;
    ADest.Pen.Style := psSolid;
    ADest.Rectangle(3, 3, ASize.cx - 4, ASize.cy - 4);
    ADest.Pen.Color := clBlack;
    ADest.Pen.Style := psDot;
    ADest.Rectangle(3, 3, ASize.cx - 4, ASize.cy - 4);
  end;

  // Button text
  ADest.Font.Assign(AStateEx.Font);
  ADest.Brush.Style := bsClear;
  ADest.Pen.Style := psSolid;
  Str := AStateEx.Caption;
  if csfSunken in AState then
    ADest.TextOut((ASize.cx - ADest.TextWidth(Str)) div 2 + 1,
      (ASize.cy - ADest.TextHeight(Str)) div 2 + 1, Str)
  else
    ADest.TextOut((ASize.cx - ADest.TextWidth(Str)) div 2,
      (ASize.cy - ADest.TextHeight(Str)) div 2, Str);
end;

procedure TCDDrawerCommon.DrawEditBackground(ADest: TCanvas;
  ADestPos: TPoint; ASize: TSize; AState: TCDControlState;
  AStateEx: TCDEditStateEx);
begin
  // The background
  ADest.Brush.Color := clWhite;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Color := WIN2000_FRAME_WHITE;
  ADest.Pen.Style := psSolid;
  ADest.Rectangle(0, 0, ASize.cx, ASize.cy);

  // The Frame, except the lower-bottom which is white anyway
  // outter top-right
  ADest.Pen.Color := WIN2000_FRAME_GRAY;
  ADest.MoveTo(0, ASize.cy-1);
  ADest.LineTo(0, 0);
  ADest.LineTo(ASize.cx-1, 0);
  // inner top-right
  ADest.Pen.Color := WIN2000_FRAME_DARK_GRAY;
  ADest.MoveTo(1, ASize.cy-2);
  ADest.LineTo(1, 1);
  ADest.LineTo(ASize.cx-2, 1);
  // inner bottom-right
  ADest.Pen.Color := WIN2000_FRAME_LIGHT_GRAY;
  ADest.MoveTo(1, ASize.cy-2);
  ADest.LineTo(ASize.cx-2, ASize.cy-2);
  ADest.LineTo(ASize.cx-2, 0);
end;

procedure TCDDrawerCommon.DrawCaret(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDEditStateEx);
var
  lTextTopSpacing, lCaptionHeight: Integer;
  lControlText, lTmpText: string;
  lCaretPixelPos: Integer;
begin
  if not AStateEx.CaretIsVisible then Exit;

  lControlText := AStateEx.Caption;
  lCaptionHeight := GetMeasuresEx(ADest, TCDCONTROL_CAPTION_HEIGHT, AState, AStateEx);
  lTextTopSpacing := GetMeasures(TCDEDIT_TOP_TEXT_SPACING);

  lTmpText := UTF8Copy(lControlText, 1, AStateEx.CaretPos.X-AStateEx.VisibleTextStart.X+1);
  lCaretPixelPos := ADest.TextWidth(lTmpText) + 3;
  ADest.Pen.Color := clBlack;
  ADest.Line(lCaretPixelPos, lTextTopSpacing, lCaretPixelPos, lTextTopSpacing+lCaptionHeight);
end;

procedure TCDDrawerCommon.DrawEdit(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDEditStateEx);
var
  lVisibleText, lControlText: TCaption;
  lSelLeftPos, lSelLeftPixelPos, lSelLength, lSelRightPos: Integer;
  lTextWidth: Integer;
  lControlTextLen: PtrInt;
  lTextLeftSpacing, lTextRightSpacing, lTextTopSpacing, lTextBottomSpacing: Integer;
begin
  // Background
  DrawEditBackground(ADest, ADestPos, ASize, AState, AStateEx);

  lControlText := AStateEx.Caption;
  lControlTextLen := UTF8Length(AStateEx.Caption);
  ADest.Brush.Style := bsClear;
  ADest.Font.Assign(AStateEx.Font);
  lTextLeftSpacing := GetMeasures(TCDEDIT_LEFT_TEXT_SPACING);
  lTextRightSpacing := GetMeasures(TCDEDIT_RIGHT_TEXT_SPACING);
  lTextTopSpacing := GetMeasures(TCDEDIT_TOP_TEXT_SPACING);
  lTextBottomSpacing := GetMeasures(TCDEDIT_BOTTOM_TEXT_SPACING);

  // The text without selection
  ADest.Pen.Style := psClear;
  if AStateEx.SelLength = 0 then
  begin
    lVisibleText := UTF8Copy(lControlText, AStateEx.VisibleTextStart.X, lControlTextLen);
    ADest.TextOut(lTextLeftSpacing, lTextTopSpacing, lVisibleText);
  end
  // Text and Selection
  else
  begin
    lSelLeftPos := AStateEx.SelStart.X;
    if AStateEx.SelLength < 0 then lSelLeftPos := lSelLeftPos + AStateEx.SelLength;
    lSelRightPos := AStateEx.SelStart.X;
    if AStateEx.SelLength > 0 then lSelRightPos := lSelRightPos + AStateEx.SelLength;
    lSelLength := AStateEx.SelLength;
    if lSelLength < 0 then lSelLength := lSelLength * -1;

    // Text left of the selection
    lVisibleText := UTF8Copy(lControlText, AStateEx.VisibleTextStart.X, lSelLeftPos-AStateEx.VisibleTextStart.X+1);
    ADest.TextOut(4, lTextTopSpacing, lVisibleText);
    lSelLeftPixelPos := ADest.TextWidth(lVisibleText)+lTextLeftSpacing;

    // The selection background
    lVisibleText := UTF8Copy(lControlText, lSelLeftPos+1, lSelLength);
    lTextWidth := ADest.TextWidth(lVisibleText);
    ADest.Brush.Color := clBlue;
    ADest.Brush.Style := bsSolid;
    ADest.Rectangle(lSelLeftPixelPos, lTextTopSpacing, lSelLeftPixelPos+lTextWidth, ASize.cy-lTextBottomSpacing);
    ADest.Brush.Style := bsClear;

    // The selection text
    ADest.Font.Color := clWhite;
    ADest.TextOut(lSelLeftPixelPos, lTextTopSpacing, lVisibleText);
    lSelLeftPixelPos := lSelLeftPixelPos + lTextWidth;

    // Text right of the selection
    ADest.Brush.Color := clWhite;
    ADest.Font.Color := AStateEx.Font.Color;
    lVisibleText := UTF8Copy(lControlText, lSelLeftPos+lSelLength+1, lControlTextLen);
    ADest.TextOut(lSelLeftPixelPos, lTextTopSpacing, lVisibleText);
  end;

  // And the caret
  DrawCaret(ADest, ADestPos, ASize, AState, AStateEx);
end;

procedure TCDDrawerCommon.DrawCheckBoxSquare(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDControlStateEx);
var
  lHalf, lSquareHalf, lSquareHeight: Integer;
  lColor: TColor;
begin
  lHalf := ASize.cy div 2;
  lSquareHalf := GetMeasures(TCDCHECKBOX_SQUARE_HALF_HEIGHT);
  lSquareHeight := GetMeasures(TCDCHECKBOX_SQUARE_HEIGHT);

  // the square background
  ADest.Pen.Style := psClear;
  ADest.Brush.Style := bsSolid;
  ADest.Brush.Color := Palette.Window;
  ADest.Rectangle(Bounds(1, lHalf - lSquareHalf, lSquareHeight, lSquareHeight));

  // the square frame
  DrawSunkenFrame(ADest, Point(1, lHalf - lSquareHalf),
    Size(lSquareHeight, lSquareHeight));

{  // The selection inside the square
  ADest.Brush.Style := bsClear;
  ADest.Pen.Color := RGBToColor($31, $C6, $D6);
  ADest.Pen.Style := psSolid;
  if csfHasFocus in AState then
  begin
    ADest.Rectangle(
      2,
      lHalf - lSquareHalf+1,
      lSquareHeight,
      lHalf + lSquareHalf-1);
  end;}
end;

procedure TCDDrawerCommon.DrawCheckBox(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDControlStateEx);
var
  lColor: TColor;
  lSquareHeight: Integer;
begin
  lSquareHeight := GetMeasures(TCDCHECKBOX_SQUARE_HEIGHT);

  // Background
  lColor := AStateEx.ParentRGBColor;
  ADest.Brush.Color := lColor;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Style := psClear;
  ADest.FillRect(0, 0, ASize.cx, ASize.cy);

  // The checkbox item itself
  DrawCheckBoxSquare(ADest, ADestPos, ASize, AState, AStateEx);

  // The Tickmark
  if csfOn in AState then
    DrawTickmark(ADest, Point(3, ASize.cy div 2 - GetMeasures(TCDCHECKBOX_SQUARE_HALF_HEIGHT)+3));

  // The text selection
  if csfHasFocus in AState then
    DrawFocusRect(ADest, Point(lSquareHeight+4, 0),
      Size(ASize.cx-lSquareHeight-4, ASize.cy));

  // Now the text
  ADest.Brush.Style := bsClear;
  ADest.Pen.Style := psClear;
  ADest.Font.Assign(AStateEx.Font);
  ADest.TextOut(lSquareHeight+5, 0, AStateEx.Caption);
end;

procedure TCDDrawerCommon.DrawRadioButtonCircle(ADest: TCanvas;
  ADestPos: TPoint; ASize: TSize; AState: TCDControlState;
  AStateEx: TCDControlStateEx);
var
  lHalf, lCircleThird, lCircleHeight: Integer;
  lColor: TColor;
begin
  lHalf := ASize.cy div 2;
  lCircleHeight := GetMeasures(TCDRADIOBUTTON_CIRCLE_HEIGHT);
  lCircleThird := lCircleHeight div 3;

  // the circle background
  ADest.Pen.Style := psClear;
  ADest.Brush.Style := bsSolid;
  ADest.Brush.Color := Palette.Window; // or WIN2000_FRAME_WHITE ?
  ADest.Rectangle(Bounds(ADestPos.X, ADestPos.Y+lCircleThird-1, lCircleHeight-2, lCircleThird));
  ADest.Rectangle(Bounds(ADestPos.X+lCircleThird-1, ADestPos.Y, lCircleThird, lCircleHeight-2));

  // The circle itself
  ADest.Pen.Style := psSolid;
  // Gray area
  ADest.Pixels[ADestPos.X+4, ADestPos.Y] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X+5, ADestPos.Y] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X+6, ADestPos.Y] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X+7, ADestPos.Y] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X+8, ADestPos.Y+1] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X+9, ADestPos.Y+1] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X+3, ADestPos.Y+1] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X+2, ADestPos.Y+1] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X+1, ADestPos.Y+2] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X+1, ADestPos.Y+3] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X, ADestPos.Y+4] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X, ADestPos.Y+5] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X, ADestPos.Y+6] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X, ADestPos.Y+7] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X+1, ADestPos.Y+8] := WIN2000_FRAME_GRAY;
  ADest.Pixels[ADestPos.X+1, ADestPos.Y+9] := WIN2000_FRAME_GRAY;
  // Dark area
  ADest.Pixels[ADestPos.X+4, ADestPos.Y+1] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+5, ADestPos.Y+1] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+6, ADestPos.Y+1] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+7, ADestPos.Y+1] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+8, ADestPos.Y+2] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+9, ADestPos.Y+2] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+3, ADestPos.Y+2] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+2, ADestPos.Y+2] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+2, ADestPos.Y+3] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+1, ADestPos.Y+4] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+1, ADestPos.Y+5] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+1, ADestPos.Y+6] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+1, ADestPos.Y+7] := WIN2000_FRAME_DARK_GRAY;
  ADest.Pixels[ADestPos.X+2, ADestPos.Y+8] := WIN2000_FRAME_DARK_GRAY;
  // Light area
  ADest.Pixels[ADestPos.X+9, ADestPos.Y+3] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+10, ADestPos.Y+4] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+10, ADestPos.Y+5] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+10, ADestPos.Y+6] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+10, ADestPos.Y+7] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+9, ADestPos.Y+8] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+9, ADestPos.Y+9] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+8, ADestPos.Y+9] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+7, ADestPos.Y+10] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+6, ADestPos.Y+10] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+5, ADestPos.Y+10] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+4, ADestPos.Y+10] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+3, ADestPos.Y+9] := WIN2000_FRAME_LIGHT_GRAY;
  ADest.Pixels[ADestPos.X+2, ADestPos.Y+9] := WIN2000_FRAME_LIGHT_GRAY;
  // white area
  ADest.Pixels[ADestPos.X+10, ADestPos.Y+2] := WIN2000_FRAME_WHITE;
  ADest.Pixels[ADestPos.X+10, ADestPos.Y+3] := WIN2000_FRAME_WHITE;
  ADest.Pixels[ADestPos.X+10, ADestPos.Y+8] := WIN2000_FRAME_WHITE;
  ADest.Pixels[ADestPos.X+10, ADestPos.Y+9] := WIN2000_FRAME_WHITE;
  ADest.Pixels[ADestPos.X+9, ADestPos.Y+10] := WIN2000_FRAME_WHITE;
  ADest.Pixels[ADestPos.X+8, ADestPos.Y+10] := WIN2000_FRAME_WHITE;
  ADest.Pixels[ADestPos.X+3, ADestPos.Y+10] := WIN2000_FRAME_WHITE;
  ADest.Pixels[ADestPos.X+2, ADestPos.Y+10] := WIN2000_FRAME_WHITE;
  ADest.Pixels[ADestPos.X+3, ADestPos.Y+3] := WIN2000_FRAME_WHITE;
  ADest.Pixels[ADestPos.X+3, ADestPos.Y+8] := WIN2000_FRAME_WHITE;
  ADest.Pixels[ADestPos.X+8, ADestPos.Y+3] := WIN2000_FRAME_WHITE;
  ADest.Pixels[ADestPos.X+8, ADestPos.Y+8] := WIN2000_FRAME_WHITE;

  // The Tickmark
  if csfOn in AState then
  begin
    ADest.Pen.Style := psSolid;
    ADest.Pen.Color := clBlack;
    ADest.Rectangle(ADestPos.X+4, ADestPos.Y+5, ADestPos.X+8, ADestPos.Y+7);
    ADest.Rectangle(ADestPos.X+5, ADestPos.Y+4, ADestPos.X+7, ADestPos.Y+8);
  end;
end;

procedure TCDDrawerCommon.DrawRadioButton(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDControlStateEx);
var
  lColor: TColor;
  lCircleHeight: Integer;
begin
  lCircleHeight := GetMeasures(TCDRADIOBUTTON_CIRCLE_HEIGHT);

  // Background
  lColor := AStateEx.ParentRGBColor;
  ADest.Brush.Color := lColor;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Style := psClear;
  ADest.FillRect(0, 0, ASize.cx, ASize.cy);

  // The radiobutton circle itself
  DrawRadioButtonCircle(ADest, ADestPos, ASize, AState, AStateEx);

  // The text selection
  if csfHasFocus in AState then
    DrawFocusRect(ADest, Point(lCircleHeight+3, 0),
      Size(ASize.cx-lCircleHeight-3, ASize.cy));

  // Now the text
  ADest.Brush.Style := bsClear;
  ADest.Font.Assign(AStateEx.Font);
  ADest.TextOut(lCircleHeight+5, 0, AStateEx.Caption);
end;

procedure TCDDrawerCommon.DrawScrollBar(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDPositionedCStateEx);
var
  lPos: TPoint;
  lSize: TSize;
  lArrowState: TCDControlState;
begin
  // Background
  ADest.Brush.Color := WIN2000_SCROLLBAR_BACKGROUND;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Style := psSolid;
  ADest.Pen.Color := WIN2000_SCROLLBAR_BACKGROUND;
  ADest.Rectangle(0, 0, ASize.cx, ASize.cy);

  // Left/Top button
  lPos := ADestPos;

  if csfHorizontal in AState then
    lSize := Size(GetMeasures(TCDSCROLLBAR_BUTTON_WIDTH), ASize.CY)
  else lSize := Size(ASize.CX, GetMeasures(TCDSCROLLBAR_BUTTON_WIDTH));

  ADest.Brush.Color := Palette.BtnFace;
  ADest.Brush.Style := bsSolid;
  ADest.Rectangle(Bounds(lPos.X, lPos.Y, lSize.cx, lSize.cy));
  if csfLeftArrow in AState then
  begin
    DrawSunkenFrame(ADest, lPos, lSize);
    lArrowState := [csfSunken];
  end
  else
  begin
    DrawRaisedFrame(ADest, lPos, lSize);
    lArrowState := [];
  end;

  if csfHorizontal in AState then
    DrawCompactArrow(ADest, Point(lPos.X+5, lPos.Y+5), [csfLeftArrow]+lArrowState)
  else DrawCompactArrow(ADest, Point(lPos.X+5, lPos.Y+5), [csfUpArrow]+lArrowState);

  // Right/Bottom button
  if csfHorizontal in AState then
    lPos.X := lPos.X+ASize.CX-GetMeasures(TCDSCROLLBAR_BUTTON_WIDTH)
  else
    lPos.Y := lPos.Y+ASize.CY-GetMeasures(TCDSCROLLBAR_BUTTON_WIDTH);
  ADest.Brush.Color := Palette.BtnFace;
  ADest.Brush.Style := bsSolid;
  ADest.Rectangle(Bounds(lPos.X, lPos.Y, lSize.cx, lSize.cy));
  if csfRightArrow in AState then
  begin
    DrawSunkenFrame(ADest, lPos, lSize);
    lArrowState := [csfSunken];
  end
  else
  begin
    DrawRaisedFrame(ADest, lPos, lSize);
    lArrowState := [];
  end;

  if csfHorizontal in AState then
    DrawCompactArrow(ADest, Point(lPos.X+5, lPos.Y+5), [csfRightArrow] + lArrowState)
  else DrawCompactArrow(ADest, Point(lPos.X+5, lPos.Y+5), [csfDownArrow] + lArrowState);

  // The slider
  lPos := Point(0, 0);
  if csfHorizontal in AState then
  begin
    if AStateEx.FloatPageSize > 0 then lSize.cx := Round(
      AStateEx.FloatPageSize * (ASize.cx - GetMeasures(TCDSCROLLBAR_BUTTON_WIDTH) * 2));
    if lSize.cx < 5 then lSize.cx := 5;

    lPos.X := Round(GetMeasures(TCDSCROLLBAR_BUTTON_WIDTH)
      + AStateEx.FloatPos * (ASize.cx - GetMeasures(TCDSCROLLBAR_BUTTON_WIDTH) * 2 - lSize.cx));
  end
  else
  begin
    if AStateEx.FloatPageSize > 0 then lSize.cy := Round(
      AStateEx.FloatPageSize * (ASize.cy - GetMeasures(TCDSCROLLBAR_BUTTON_WIDTH) * 2));
    if lSize.cy < 5 then lSize.cy := 5;

    lPos.Y := Round(GetMeasures(TCDSCROLLBAR_BUTTON_WIDTH)
      + AStateEx.FloatPos * (ASize.cy - GetMeasures(TCDSCROLLBAR_BUTTON_WIDTH) * 2 - lSize.cy));
  end;
  ADest.Brush.Color := Palette.BtnFace;
  ADest.Brush.Style := bsSolid;
  ADest.Rectangle(Bounds(lPos.X, lPos.Y, lSize.cx, lSize.cy));
  DrawRaisedFrame(ADest, lPos, lSize);
end;

procedure TCDDrawerCommon.DrawGroupBox(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDControlStateEx);
var
  FCaptionMiddle: integer;
  lTextSize: TSize;
  lCaption: String;
begin
  FCaptionMiddle := ADest.TextHeight(cddTestStr) div 2;
  if FCaptionMiddle = 0 then FCaptionMiddle := AStateEx.Font.Size div 2;
  if FCaptionMiddle = 0 then FCaptionMiddle := 5;

  // Background
  ADest.Brush.Color := AStateEx.ParentRGBColor;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Style := psSolid;
  ADest.Pen.Color := AStateEx.ParentRGBColor;
  ADest.Rectangle(0, 0, ASize.cx, ASize.cy);

  // frame
  ADest.Pen.Color := WIN2000_FRAME_WHITE;
  ADest.Pen.Style := psSolid;
  ADest.Brush.Style := bsClear;
  ADest.Rectangle(Bounds(1, 1+FCaptionMiddle, ASize.cx-1, ASize.cy-1-FCaptionMiddle));
  ADest.Pen.Color := WIN2000_FRAME_GRAY;
  ADest.Rectangle(Bounds(0, FCaptionMiddle, ASize.cx-1, ASize.cy-1-FCaptionMiddle));
  ADest.Pixels[0, ASize.cy-1] := WIN2000_FRAME_WHITE;
  ADest.Pixels[ASize.cx-1, FCaptionMiddle] := WIN2000_FRAME_WHITE;

  // ToDo: Make the caption smaller if it is too big
  lCaption := AStateEx.Caption;
  lTextSize := ADest.TextExtent(lCaption);

  // fill the text background
  ADest.Brush.Style := bsSolid;
  ADest.Brush.Color := AStateEx.ParentRGBColor;
  ADest.Pen.Style := psClear;
  ADest.Rectangle(Bounds(FCaptionMiddle, 0, lTextSize.cx+5, lTextSize.cy));

  // paint text
  ADest.Pen.Style := psClear;
  ADest.Brush.Style := bsClear;
  ADest.TextOut(FCaptionMiddle+3, 0, lCaption);
end;

procedure TCDDrawerCommon.DrawStaticText(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDControlStateEx);
var
  lColor: TColor;
begin
  // Background
  lColor := AStateEx.ParentRGBColor;
  ADest.Brush.Color := lColor;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Style := psClear;
  ADest.FillRect(0, 0, ASize.cx, ASize.cy);

  // Now the text
  ADest.Brush.Style := bsClear;
  ADest.Font.Assign(AStateEx.Font);
  ADest.TextOut(0, 0, AStateEx.Caption);
end;

procedure TCDDrawerCommon.DrawTrackBar(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDPositionedCStateEx);
var
  StepsCount, i: Integer;
  lTickmarkLeft, lTickmarkTop: integer; // for drawing the decorative bars
  dRect: TRect;
  CDBarSpacing: Integer;
  pStepWidth, lTickmarkLeftFloat: Double;
  lPoint: TPoint;
  lSize, lMeasureSize: TSize;
begin
  // The orientation i
  if csfHorizontal in AState then lMeasureSize := ASize
  else lMeasureSize := Size(ASize.CY, ASize.CX);

  CDBarSpacing := GetMeasures(TCDTRACKBAR_LEFT_SPACING) + GetMeasures(TCDTRACKBAR_RIGHT_SPACING);

  // Preparations
  StepsCount := AStateEx.PosCount;
  if StepsCount > 0 then pStepWidth := (lMeasureSize.cx - CDBarSpacing) / (StepsCount-1)
  else pStepWidth := 0.0;

  // Background

  ADest.Brush.Color := AStateEx.ParentRGBColor;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Style := psSolid;
  ADest.Pen.Color := AStateEx.ParentRGBColor;
  ADest.Rectangle(0, 0, ASize.cx, ASize.cy);

  // Draws the frame and its inner white area
  if csfHorizontal in AState then
  begin
    lPoint := Point(ADestPos.X + GetMeasures(TCDTRACKBAR_LEFT_SPACING),
       ADestPos.Y + GetMeasures(TCDTRACKBAR_TOP_SPACING));
    lSize := Size(ASize.CX - CDBarSpacing, GetMeasures(TCDTRACKBAR_FRAME_HEIGHT));
  end
  else
  begin
    lPoint := Point(ADestPos.X + GetMeasures(TCDTRACKBAR_TOP_SPACING),
       ADestPos.Y + GetMeasures(TCDTRACKBAR_LEFT_SPACING));
    lSize := Size(GetMeasures(TCDTRACKBAR_FRAME_HEIGHT), ASize.CY - CDBarSpacing);
  end;
  ADest.Brush.Color := Palette.Window;
  ADest.Pen.Style := psClear;
  ADest.Rectangle(Bounds(lPoint.X, lPoint.Y, lSize.cx, lSize.cy));
  DrawSunkenFrame(ADest, lPoint, lSize);

  // Draws the tickmarks and also the slider button
  lTickmarkLeft := GetMeasures(TCDTRACKBAR_LEFT_SPACING);
  lTickmarkLeftFloat := lTickmarkLeft;
  lTickmarkTop := GetMeasures(TCDTRACKBAR_TOP_SPACING) + GetMeasures(TCDTRACKBAR_FRAME_HEIGHT)+5;
  ADest.Pen.Style := psSolid;
  for i := 0 to StepsCount - 1 do
  begin
    ADest.Pen.Color := clBlack;
    if csfHorizontal in AState then
      ADest.Line(lTickmarkLeft, lTickmarkTop, lTickmarkLeft, lTickmarkTop+3)
    else
      ADest.Line(lTickmarkTop, lTickmarkLeft, lTickmarkTop+3, lTickmarkLeft);

    // Draw the slider
    if i = AStateEx.Position then
      DrawSlider(ADest,
        Point(lTickmarkLeft-5, GetMeasures(TCDTRACKBAR_TOP_SPACING)-2),
        Size(11, GetMeasures(TCDTRACKBAR_FRAME_HEIGHT)+5), AState);

    lTickmarkLeftFloat := lTickmarkLeftFloat + pStepWidth;
    lTickmarkLeft := Round(lTickmarkLeftFloat);
  end;

  // Draw the focus
  if csfHasFocus in AState then
    DrawFocusRect(ADest,
      Point(ADestPos.X + 1, ADestPos.Y + 1),
      Size(ASize.CX - 2, ASize.CY - 2));
end;

// Felipe: Smooth=False is not supported for now
procedure TCDDrawerCommon.DrawProgressBar(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDProgressBarStateEx);
var
  lProgPos, lProgMult: TPoint;
  lProgSize: TSize;
  lProgWidth, i: Integer;
begin
  // Inside area, there is no background because the control occupies the entire area
  ADest.Brush.Color := AStateEx.RGBColor;//WIN2000_FRAME_LIGHT_GRAY;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Style := psClear;
  ADest.Rectangle(0, 0, ASize.cx, ASize.cy);

  // The Frame
  DrawShallowSunkenFrame(ADest, ADestPos, ASize);

  // Preparations to have 1 code for all orientations
  lProgSize := Size(ASize.cx-4, ASize.cy-4);
  if csfHorizontal in AState then
  begin
    lProgPos := Point(ADestPos.X+2, ADestPos.Y+2);
    lProgMult := Point(1, 0);
    lProgWidth := lProgSize.cx;
  end
  else if csfVertical in AState then
  begin
    lProgPos := Point(ADestPos.X+2, ADestPos.Y+ASize.cy-2);
    lProgMult := Point(0, -1);
    lProgWidth := lProgSize.cy;
  end else if csfRightToLeft in AState then
  begin
    lProgPos := Point(ADestPos.X+ASize.cx-2, ADestPos.Y+2);
    lProgMult := Point(-1, 0);
    lProgWidth := lProgSize.cx;
  end
  else
  begin
    lProgPos := Point(ADestPos.X+2, ADestPos.Y+2);
    lProgMult := Point(0, 1);
    lProgWidth := lProgSize.cy;
  end;
  lProgWidth := Round(lProgWidth * AStateEx.PercentPosition);

  // Draws the filling
  ADest.Pen.Color := WIN2000_PROGRESSBAR_BLUE;
  ADest.Pen.Style := psSolid;
  ADest.Brush.Color := WIN2000_PROGRESSBAR_BLUE;
  ADest.Brush.Style := bsSolid;
  ADest.Rectangle(
    lProgPos.X,
    lProgPos.Y,
    lProgPos.X+lProgWidth*lProgMult.X+lProgSize.cx*Abs(lProgMult.Y),
    lProgPos.Y+lProgWidth*lProgMult.Y+lProgSize.cy*Abs(lProgMult.X));
end;

procedure TCDDrawerCommon.DrawListView(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDListViewStateEx);
begin
  // Inside area, there is no background because the control occupies the entire area
  ADest.Brush.Color := Palette.Window;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Style := psClear;
  ADest.Rectangle(0, 0, ASize.cx, ASize.cy);

  // The frame
  DrawSunkenFrame(ADest, ADestPos, ASize);

  // The contents depend on the view style
  case AStateEx.ViewStyle of
  vsReport: DrawReportListView(ADest, ADestPos, ASize, AState, AStateEx);
  end;
end;

procedure TCDDrawerCommon.DrawReportListView(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDListViewStateEx);
var
  lColumn: TListColumn;
  lWidth: TWidth;
  i, j: Integer;
  lCurPos: TPoint;
  lItemSize: TSize;
  lItemCount: Integer;
  lCurItem: TCDListItems;
begin
  lCurPos := Point(2, 2);
  lItemCount := AStateEx.Items.GetItemCount();

  // i is an column zero-based index
  for i := AStateEx.FirstVisibleColumn to AStateEx.Columns.Count-1 do
  begin
    lColumn := AStateEx.Columns[i];
    lCurPos.Y := 2;

    // get the column width
    if lColumn.AutoSize then
    begin
      lItemSize.cx := ADest.GetTextWidth(lColumn.Caption)
        + GetMeasures(TCDLISTVIEW_COLUMN_LEFT_SPACING)
        + GetMeasures(TCDLISTVIEW_COLUMN_RIGHT_SPACING);
      if (lColumn.MinWidth > 0) and (lItemSize.cx < lColumn.MinWidth) then lItemSize.cx := lColumn.MinWidth
      else if (lColumn.MaxWidth > 0) and (lItemSize.cx > lColumn.MaxWidth) then lItemSize.cx := lColumn.MaxWidth;
    end
    else lItemSize.cx := lColumn.Width;

    // line height measure
    lItemSize.cy := ADest.TextHeight(cddTestStr)
      + GetMeasures(TCDLISTVIEW_LINE_TOP_SPACING)
      + GetMeasures(TCDLISTVIEW_LINE_BOTTOM_SPACING);

    // Draw the column header
    if AStateEx.ShowColumnHeader then
    begin
      // Foreground
      ADest.Brush.Style := bsSolid;
      ADest.Brush.Color := Palette.BtnFace; // WIN2000_BTNFACE
      ADest.Pen.Style := psClear;
      ADest.FillRect(Bounds(lCurPos.X, lCurPos.Y, lItemSize.cx, lItemSize.cy));

      // Frame
      DrawRaisedFrame(ADest, lCurPos, lItemSize);

      // The caption
      ADest.Brush.Style := bsClear;
      ADest.Pen.Style := psClear;
      ADest.TextOut(
        lCurPos.X+GetMeasures(TCDLISTVIEW_COLUMN_TEXT_LEFT_SPACING),
        lCurPos.Y+GetMeasures(TCDLISTVIEW_LINE_TOP_SPACING),
        lColumn.Caption);

      Inc(lCurPos.Y, lItemSize.cy);
    end;

    // j is a zero-based index for lines, ignoring the header
    // Draw all items until we get out of the visible area
    for j := 0 to lItemCount-1 do
    begin
      lCurItem := nil;
      if i = 0 then lCurItem := AStateEx.Items.GetItem(j)
      else if AStateEx.Items.GetItem(j).GetItemCount >= i then
        lCurItem := AStateEx.Items.GetItem(j).GetItem(i-1);

      if lCurItem = nil then Continue;

      // Draw the item
      DrawReportListViewItem(ADest, lCurPos, lItemSize, lCurItem, AState, AStateEx);

      Inc(lCurPos.Y, lItemSize.CY);
    end;

    Inc(lCurPos.X, lItemSize.CX);
  end;
end;

procedure TCDDrawerCommon.DrawReportListViewItem(ADest: TCanvas;
  ADestPos: TPoint; ASize: TSize; ACurItem: TCDListItems; AState: TCDControlState;
  AStateEx: TCDListViewStateEx);
begin
  ADest.Brush.Style := bsClear;
  ADest.Pen.Style := psClear;
  ADest.TextOut(
    ADestPos.X+GetMeasures(TCDLISTVIEW_COLUMN_TEXT_LEFT_SPACING),
    ADestPos.Y+GetMeasures(TCDLISTVIEW_LINE_TOP_SPACING),
    ACurItem.Caption);
end;

procedure TCDDrawerCommon.DrawCTabControl(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDCTabControlStateEx);
begin
  // Background
  ADest.Pen.Style := psSolid;
  ADest.Pen.Color := AStateEx.ParentRGBColor;
  ADest.Brush.Style := bsSolid;
  ADest.Brush.Color := AStateEx.ParentRGBColor;
  ADest.Rectangle(ADestPos.X, ADestPos.Y, ADestPos.X+ASize.cx, ADestPos.Y+ASize.cy);

  // frame
  DrawCTabControlFrame(ADest, ADestPos, ASize, AState, AStateEx);

  // Tabs
  ADest.Font.Assign(AStateEx.Font);
  DrawTabs(ADest, ADestPos, ASize, AState, AStateEx);
end;

procedure TCDDrawerCommon.DrawCTabControlFrame(ADest: TCanvas;
  ADestPos: TPoint; ASize: TSize; AState: TCDControlState;
  AStateEx: TCDCTabControlStateEx);
var
  CaptionHeight: Integer;
begin
  if AStateEx.TabCount = 0 then CaptionHeight := 0
  else CaptionHeight := GetMeasuresEx(ADest, TCDCTABCONTROL_TAB_HEIGHT, AState, AStateEx);

  DrawRaisedFrame(ADest, Point(0, CaptionHeight), Size(ASize.cx, ASize.cy-CaptionHeight));
end;

procedure TCDDrawerCommon.DrawTabSheet(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDCTabControlStateEx);
begin
  ADest.Brush.Color := AStateEx.RGBColor;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Style := psSolid;
  ADest.Pen.Color := AStateEx.RGBColor;
  ADest.Rectangle(0, 0, ASize.cx, ASize.cy);
end;

procedure TCDDrawerCommon.DrawTabs(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDCTabControlStateEx);
var
  IsPainting: Boolean = False;
  i: Integer;
begin
  AStateEx.CurStartLeftPos := 0;
  for i := 0 to AStateEx.Tabs.Count - 1 do
  begin
    if i = AStateEx.LeftmostTabVisibleIndex then
      IsPainting := True;

    if IsPainting then
    begin
      AStateEx.CurTabIndex := i;
      DrawTab(ADest, ADestPos, ASize, AState, AStateEx);
      AStateEx.CurStartLeftPos := AStateEx.CurStartLeftPos + GetMeasuresEx(ADest, TCDCTABCONTROL_TAB_WIDTH, AState, AStateEx);
    end;
  end;
end;

procedure TCDDrawerCommon.DrawTab(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDCTabControlStateEx);
var
  IsSelected: Boolean;
  lTabWidth, lTabHeight, lTabTopPos: Integer;
  Points: array of TPoint;
  lCaption: String;
  lTabHeightCorrection: Integer = 0;
  lTabRightBorderExtraHeight: Integer = 0;
begin
  IsSelected := AStateEx.TabIndex = AStateEx.CurTabIndex;

  if not IsSelected then lTabHeightCorrection := 3;
  if IsSelected then lTabRightBorderExtraHeight := 1;

  lTabTopPos := lTabHeightCorrection;
  lTabHeight := GetMeasuresEx(ADest, TCDCTABCONTROL_TAB_HEIGHT, AState, AStateEx)-lTabHeightCorrection;
  lTabWidth := GetMeasuresEx(ADest, TCDCTABCONTROL_TAB_WIDTH, AState, AStateEx);

  // Fill the area inside the outer border
  // And at the same time fill the white border (part of it will be erased later)
  ADest.Pen.Style := psSolid;
  ADest.Pen.Color := WIN2000_FRAME_WHITE;
  ADest.Brush.Style := bsSolid;
  ADest.Brush.Color := AStateEx.RGBColor;
  SetLength(Points, 6);
  Points[0] := Point(AStateEx.CurStartLeftPos, lTabTopPos+lTabHeight);
  Points[1] := Point(AStateEx.CurStartLeftPos, lTabTopPos+2);
  Points[2] := Point(AStateEx.CurStartLeftPos+2, lTabTopPos);
  Points[3] := Point(AStateEx.CurStartLeftPos+lTabWidth-3, lTabTopPos);
  Points[4] := Point(AStateEx.CurStartLeftPos+lTabWidth-1, lTabTopPos+2);
  Points[5] := Point(AStateEx.CurStartLeftPos+lTabWidth-1, lTabTopPos+lTabHeight);
  ADest.Polygon(Points);

  // Draw the inner border of the top and right sides,
  ADest.Pen.Style := psSolid;
  ADest.Brush.Style := bsClear;
  ADest.Pen.Color := WIN2000_FRAME_LIGHT_GRAY;
  ADest.MoveTo(AStateEx.CurStartLeftPos+1, lTabTopPos+lTabHeight-1);
  ADest.LineTo(AStateEx.CurStartLeftPos+1, lTabTopPos+2);
  ADest.LineTo(AStateEx.CurStartLeftPos+2, lTabTopPos+1);
  ADest.LineTo(AStateEx.CurStartLeftPos+lTabWidth-3, lTabTopPos+1);

  // Draw the inner border of the right side
  ADest.Pen.Color := WIN2000_FRAME_GRAY;
  ADest.MoveTo(AStateEx.CurStartLeftPos+lTabWidth-2, lTabTopPos+2);
  ADest.LineTo(AStateEx.CurStartLeftPos+lTabWidth-2, lTabTopPos+lTabHeight+lTabRightBorderExtraHeight);
  // Draw the outter border of the right side
  ADest.Pen.Color := WIN2000_FRAME_DARK_GRAY;
  ADest.MoveTo(AStateEx.CurStartLeftPos+lTabWidth-1, lTabTopPos+2);
  ADest.LineTo(AStateEx.CurStartLeftPos+lTabWidth-1, lTabTopPos+lTabHeight+lTabRightBorderExtraHeight);
  ADest.Pixels[AStateEx.CurStartLeftPos+lTabWidth-2, lTabTopPos+1] := WIN2000_FRAME_DARK_GRAY;

  if IsSelected then
  begin
    // If it is selected, add a selection frame
    DrawFocusRect(ADest, Point(AStateEx.CurStartLeftPos+3, lTabTopPos+3),
      Size(lTabWidth-8, lTabHeight-6));

    // and Clear the bottom area if selected
    ADest.Pen.Style := psSolid;
    ADest.Pen.Color := AStateEx.RGBColor;
    ADest.Line(AStateEx.CurStartLeftPos+1,  lTabTopPos+lTabHeight,
      AStateEx.CurStartLeftPos+lTabWidth-2, lTabTopPos+lTabHeight);
    ADest.Line(AStateEx.CurStartLeftPos+1,  lTabTopPos+lTabHeight+1,
      AStateEx.CurStartLeftPos+lTabWidth-2, lTabTopPos+lTabHeight+1);
  end;

  // Now the text
  lCaption := AStateEx.Tabs.Strings[AStateEx.CurTabIndex];
  ADest.TextOut(AStateEx.CurStartLeftPos+5, lTabTopPos+5, lCaption);
end;

{ TCDListViewDrawerCommon }

initialization
  RegisterDrawer(TCDDrawerCommon.Create, dsCommon);
end.

