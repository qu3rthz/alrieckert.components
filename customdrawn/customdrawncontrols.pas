{
  Copyright (C) 2011 Felipe Monteiro de Carvalho

  License: The same modifying LGPL with static linking exception as the LCL

  This unit should be a repository for various custom drawn components,
  such as a custom drawn version of TButton, of TEdit, of TPageControl, etc,
  eventually forming a full set of custom drawn components.
}
unit customdrawncontrols;

{$mode objfpc}{$H+}

interface

uses
  // FPC
  Classes, SysUtils, contnrs, Math, types,
  // fpimage
  fpcanvas, fpimgcanv, fpimage,
  // LCL
  Graphics, Controls, LCLType, LCLIntf, IntfGraphics,
  LMessages, Messages, LCLProc, Forms,
  //
  customdrawnutils;

type

  TCDDrawStyle = (
    // Operating system styles
    dsWinCE, dsWin2000, dsWinXP,
    dsKDE, dsGNOME, dsMacOSX,
    dsAndroid,
    // Other special styles for the user
    dsExtra1, dsExtra2, dsExtra3, dsExtra4
    );

  TCDButtonState = (bbsNormal, bbsDown, bbsMouseOver, bbsFocused, bbsFocusedMouseOver);
  TCDButtonCheckState = (bbcNormal, bbcGrey, bbcChecked);

  TCDControlDrawer = class;

  { TCDControl }

  TCDControl = class(TCustomControl)
  protected
    FDrawStyle: TCDDrawStyle;
    FCurrentDrawer: TCDControlDrawer;
    //constructor Create(AOwner: TComponent); override;
    //destructor Destroy; override;
    procedure PrepareCurrentDrawer(); virtual;
    procedure SetDrawStyle(const AValue: TCDDrawStyle); virtual;
    function GetClientRect: TRect; override;
    procedure EraseBackground(DC: HDC); override;
    property DrawStyle: TCDDrawStyle read FDrawStyle write SetDrawStyle;
  public
  end;
  TCDControlClass = class of TCDControl;

  TCDControlDrawer = class
  public
    function GetClientRect(AControl: TCDControl): TRect; virtual; abstract;
    //procedure DrawToIntfImage(ADest: TFPImageCanvas; AControl: TCDControl);
    //  virtual; abstract;
    //procedure DrawToCanvas(ADest: TCanvas; AControl: TCDControl); virtual; abstract;
  end;

  // ===================================
  // Standard Tab
  // ===================================

  { TCDButton }

  TCDButton = class(TCDControl)
  private
    procedure PrepareCurrentDrawer(); override;
  protected
    FState: TCDButtonState;
    // keyboard
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure KeyDown(var Key: word; Shift: TShiftState); override;
    procedure KeyUp(var Key: word; Shift: TShiftState); override;
    // mouse
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    // button state change
    procedure DoButtonDown();
    procedure DoButtonUp();
    procedure RealSetText(const Value: TCaption); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Paint; override;
  published
    property Action;
    property Anchors;
    property Caption;
    property Color;
    property Constraints;
    property DrawStyle;
    property Enabled;
    property Font;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property OnStartDrag;
    property OnUTF8KeyPress;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
  end;

  { TCDButtonDrawer }

  TCDButtonDrawer = class(TCDControlDrawer)
  public
    function GetClientRect(AControl: TCDControl): TRect; override;
    procedure DrawToIntfImage(ADest: TFPImageCanvas; CDButton: TCDButton);
      virtual; abstract;
    procedure DrawToCanvas(ADest: TCanvas; CDButton: TCDButton;
      FState: TCDButtonState); virtual; abstract;
  end;

  {@@
    TCDGroupBox is a custom-drawn group box control
  }

  { TCDGroupBox }

  TCDGroupBox = class(TCDControl)
  private
    procedure PrepareCurrentDrawer(); override;
    procedure SetDrawStyle(const AValue: TCDDrawStyle); override;
  protected
    procedure RealSetText(const Value: TCaption); override; // to update on caption changes
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure EraseBackground(DC: HDC); override;
    procedure Paint; override;
  published
    property DrawStyle;
    property Caption;
    property TabStop default False;
  end;

  { TCDGroupBoxDrawer }

  TCDGroupBoxDrawer = class(TCDControlDrawer)
  public
    procedure SetClientRectPos(CDGroupBox: TCDGroupBox); virtual; abstract;
    procedure DrawToIntfImage(ADest: TFPImageCanvas; CDGroupBox: TCDGroupBox); virtual; abstract;
    procedure DrawToCanvas(ADest: TCanvas; CDGroupBox: TCDGroupBox); virtual; abstract;
  end;

  { TCDCheckBox }

  TCDCheckBox = class(TCDControl)
  private
    procedure PrepareCurrentDrawer(); override;
  protected
    FState: TCDButtonState;
    FCheckedState: TCDButtonCheckState;
    procedure RealSetText(const Value: TCaption); override; // to update on caption changes
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure EraseBackground(DC: HDC); override;
    procedure Paint; override;
  published
    property DrawStyle;
    property Caption;
    property TabStop default True;
  end;

  { TCDCheckBoxDrawer }

  TCDCheckBoxDrawer = class(TCDControlDrawer)
  public
    procedure DrawToIntfImage(ADest: TFPImageCanvas; CDCheckBox: TCDCheckBox;
      FState: TCDButtonState; FCheckedState: TCDButtonCheckState); virtual; abstract;
    procedure DrawToCanvas(ADest: TCanvas; CDCheckBox: TCDCheckBox;
      FState: TCDButtonState; FCheckedState: TCDButtonCheckState); virtual; abstract;
  end;

  // ===================================
  // Common Controls Tab
  // ===================================

  {@@
    TCDTrackBar is a custom-drawn trackbar control
  }

  TCDTrackBarDrawer = class;

  { TCDTrackBar }

  TCDTrackBar = class(TCDControl)
  private
    DragDropStarted: boolean;
    // fields
    FMin: integer;
    FMax: integer;
    FPosition: integer;
    FOnChange: TNotifyEvent;
    procedure PrepareCurrentDrawer(); override;
    procedure SetMax(Value: integer);
    procedure SetMin(Value: integer);
    procedure SetPosition(Value: integer);
    //
    function GetPositionFromMousePos(X, Y: Integer): integer;
  protected
    procedure Changed; virtual;
    // keyboard
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure KeyDown(var Key: word; Shift: TShiftState); override;
    procedure KeyUp(var Key: word; Shift: TShiftState); override;
    // mouse
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure EraseBackground(DC: HDC); override;
    procedure Paint; override;
  published
    property Color;
    property Max: integer read FMax write SetMax default 10;
    property Min: integer read FMin write SetMin default 0;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property Position: integer read FPosition write SetPosition;
    property TabStop default True;
  end;

  { TCDTrackBarDrawer }

  TCDTrackBarDrawer = class(TCDControlDrawer)
  public
    procedure DrawToIntfImage(ADest: TFPImageCanvas; FPImg: TLazIntfImage;
      CDTrackBar: TCDTrackBar); virtual; abstract;
    procedure GetGeometry(var ALeftBorder, ARightBorder: Integer); virtual; abstract;
  end;

  {TCDTabControl}

  { TCDCustomTabControl }

  TCDCustomTabControl = class;

  { TCDCustomTabSheet }

  TCDCustomTabSheet = class(TCustomControl)
  private
    CDTabControl: TCDCustomTabControl;
    FTabVisible: Boolean;
  protected
    procedure RealSetText(const Value: TCaption); override; // to update on caption changes
  public
    destructor Destroy; override;
    property TabVisible: Boolean read FTabVisible write FTabVisible;
  end;

  TCDCustomTabControl = class(TCDControl)
  private
    FTabIndex: Integer;
    FTabs: TStringList;
    FOnChanging: TNotifyEvent;
    FOnChange: TNotifyEvent;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: integer); override;
    //procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
    //procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
    //procedure MouseEnter; override;
    //procedure MouseLeave; override;
    procedure PrepareCurrentDrawer(); override;
    procedure SetTabIndex(AValue: Integer); virtual;
    procedure SetTabs(AValue: TStringList);
  protected
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Paint; override;
    procedure CorrectTabIndex();
  public
    function GetTabCount: Integer;
    property Tabs: TStringList read FTabs write SetTabs;
    property OnChanging: TNotifyEvent read FOnChanging write FOnChanging;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property TabIndex: integer read FTabIndex write SetTabIndex;
  end;

  { TCDCustomTabControlDrawer }

  TCDCustomTabControlDrawer = class(TCDControlDrawer)
  public
    function GetPageIndexFromXY(x, y: integer): integer; virtual; abstract;
    function GetTabHeight(AIndex: Integer; CDTabControl: TCDCustomTabControl): Integer;  virtual; abstract;
    function GetTabWidth(ADest: TCanvas; AIndex: Integer; CDTabControl: TCDCustomTabControl): Integer; virtual; abstract;
    procedure DrawToIntfImage(ADest: TFPImageCanvas; FPImg: TLazIntfImage;
      CDTabControl: TCDCustomTabControl); virtual; abstract;
    procedure DrawToCanvas(ADest: TCanvas; CDTabControl: TCDCustomTabControl); virtual; abstract;
    procedure DrawTabSheet(ADest: TCanvas; CDTabControl: TCDCustomTabControl); virtual; abstract;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: integer; CDTabControl: TCDCustomTabControl); virtual; abstract;
  end;

//  TTabSelectedEvent = procedure(Sender: TObject; ATab: TTabItem;
//    ASelected: boolean) of object;

  TCDTabControl = class(TCDCustomTabControl)
  published
    property Color;
    property Font;
    property Tabs;
    property TabIndex;
    property OnChanging;
    property OnChange;
  end;

  { TCDTabSheet }

  TCDPageControl = class;

  TCDTabSheet = class(TCDCustomTabSheet)
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure EraseBackground(DC: HDC); override;
    procedure Paint; override;
  published
    property Caption;
    property Color;
    property Font;
    property TabVisible: Boolean;
  end;

  { TCDPageControl }

  TCDPageControl = class(TCDCustomTabControl)
  private
    function GetActivePage: TCDTabSheet;
    function GetPageCount: integer;
    function GetPageIndex: integer;
    procedure SetActivePage(Value: TCDTabSheet);
    procedure SetPageIndex(Value: integer);
    procedure UpdateAllDesignerFlags;
    procedure UpdateDesignerFlags(APageIndex: integer);
    procedure PositionTabSheet(ATabSheet: TCDTabSheet);
  protected
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  public
    function InsertPage(aIndex: integer; S: string): TCDTabSheet;
    procedure RemovePage(aIndex: integer);
    function AddPage(S: string): TCDTabSheet;
    function GetPage(aIndex: integer): TCDTabSheet;
    property PageCount: integer read GetPageCount;
    // Used by the property editor in customdrawnextras
    function FindNextPage(CurPage: TCDTabSheet;
      GoForward, CheckTabVisible: boolean): TCDTabSheet;
    procedure SelectNextPage(GoForward: boolean; CheckTabVisible: boolean = True);
  published
    property ActivePage: TCDTabSheet read GetActivePage write SetActivePage;
    property DrawStyle;
    property Caption;
    property Color;
    property Font;
    property PageIndex: integer read GetPageIndex write SetPageIndex;
    property ParentColor;
    property ParentFont;
    property TabStop default True;
    property TabIndex;
    property OnChanging;
    property OnChange;
  end;

// Standard Tab
procedure RegisterButtonDrawer(ADrawer: TCDButtonDrawer; AStyle: TCDDrawStyle);
procedure RegisterGroupBoxDrawer(ADrawer: TCDGroupBoxDrawer; AStyle: TCDDrawStyle);
procedure RegisterCheckBoxDrawer(ADrawer: TCDCheckBoxDrawer; AStyle: TCDDrawStyle);
// Common Controls Tab
procedure RegisterTrackBarDrawer(ADrawer: TCDTrackBarDrawer; AStyle: TCDDrawStyle);
procedure RegisterCustomTabControlDrawer(ADrawer: TCDCustomTabControlDrawer; AStyle: TCDDrawStyle);

implementation

resourcestring
  sTABSHEET_DEFAULT_NAME = 'CTabSheet';

var
  // Standard Tab
  RegisteredButtonDrawers: array[TCDDrawStyle] of TCDButtonDrawer
    = (nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil);
  RegisteredGroupBoxDrawers: array[TCDDrawStyle] of TCDGroupBoxDrawer
    = (nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil);
  RegisteredCheckBoxDrawers: array[TCDDrawStyle] of TCDCheckBoxDrawer
    = (nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil);
  // Common Controls Tab
  RegisteredTrackBarDrawers: array[TCDDrawStyle] of TCDTrackBarDrawer
    = (nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil);
  RegisteredCustomTabControlDrawers: array[TCDDrawStyle] of TCDCustomTabControlDrawer
    = (nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil);

procedure RegisterButtonDrawer(ADrawer: TCDButtonDrawer; AStyle: TCDDrawStyle);
begin
  if RegisteredButtonDrawers[AStyle] <> nil then RegisteredButtonDrawers[AStyle].Free;
  RegisteredButtonDrawers[AStyle] := ADrawer;
end;

procedure RegisterGroupBoxDrawer(ADrawer: TCDGroupBoxDrawer; AStyle: TCDDrawStyle);
begin
  if RegisteredGroupBoxDrawers[AStyle] <> nil then RegisteredGroupBoxDrawers[AStyle].Free;
  RegisteredGroupBoxDrawers[AStyle] := ADrawer;
end;

procedure RegisterCheckBoxDrawer(ADrawer: TCDCheckBoxDrawer; AStyle: TCDDrawStyle);
begin
  if RegisteredCheckBoxDrawers[AStyle] <> nil then RegisteredCheckBoxDrawers[AStyle].Free;
  RegisteredCheckBoxDrawers[AStyle] := ADrawer;
end;

procedure RegisterTrackBarDrawer(ADrawer: TCDTrackBarDrawer; AStyle: TCDDrawStyle);
begin
  if RegisteredTrackBarDrawers[AStyle] <> nil then RegisteredTrackBarDrawers[AStyle].Free;
  RegisteredTrackBarDrawers[AStyle] := ADrawer;
end;

procedure RegisterCustomTabControlDrawer(ADrawer: TCDCustomTabControlDrawer; AStyle: TCDDrawStyle);
begin
  if RegisteredCustomTabControlDrawers[AStyle] <> nil then RegisteredCustomTabControlDrawers[AStyle].Free;
  RegisteredCustomTabControlDrawers[AStyle] := ADrawer;
end;

{ TCDCheckBox }

procedure TCDCheckBox.PrepareCurrentDrawer;
begin
  FCurrentDrawer := RegisteredCheckBoxDrawers[DrawStyle];
  if FCurrentDrawer = nil then FCurrentDrawer := RegisteredCheckBoxDrawers[dsWince];
  if FCurrentDrawer = nil then raise Exception.Create('No registered check box drawers were found');
end;

procedure TCDCheckBox.RealSetText(const Value: TCaption);
begin
  inherited RealSetText(Value);
  Invalidate;
end;

constructor TCDCheckBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 75;
  Height := 17;
  TabStop := True;
  ControlStyle := [csCaptureMouse, csClickEvents,
    csDoubleClicks, csReplicatable];

  DrawStyle := dsWinXP;
  PrepareCurrentDrawer();
end;

destructor TCDCheckBox.Destroy;
begin
  inherited Destroy;
end;

procedure TCDCheckBox.EraseBackground(DC: HDC);
begin
end;

procedure TCDCheckBox.Paint;
var
  AImage: TLazIntfImage = nil;
  ABmp: TBitmap = nil;
  lCanvas: TFPImageCanvas = nil;
begin
  inherited Paint;

  PrepareCurrentDrawer();

  ABmp := TBitmap.Create;
  try
    ABmp.Width := Width;
    ABmp.Height := Height;
    AImage := ABmp.CreateIntfImage;
    lCanvas := TFPImageCanvas.Create(AImage);
    // First step of the drawing: FCL TFPCustomCanvas for fast pixel access
    TCDCheckBoxDrawer(FCurrentDrawer).DrawToIntfImage(lCanvas, Self, FState, FCheckedState);
    ABmp.LoadFromIntfImage(AImage);
    // Second step of the drawing: LCL TCustomCanvas for easy font access
    TCDCheckBoxDrawer(FCurrentDrawer).DrawToCanvas(ABmp.Canvas, Self, FState, FCheckedState);
    Canvas.Draw(0, 0, ABmp);
  finally
    if lCanvas <> nil then
      lCanvas.Free;
    if AImage <> nil then
      AImage.Free;
    ABmp.Free;
  end;
end;

{ TCDCustomTabSheet }

procedure TCDCustomTabSheet.RealSetText(const Value: TCaption);
var
  lIndex: Integer;
begin
  inherited RealSetText(Value);
  lIndex := CDTabControl.Tabs.IndexOfObject(Self);
  if lIndex >= 0 then
    CDTabControl.Tabs.Strings[lIndex] := Value;
  CDTabControl.Invalidate;
end;

destructor TCDCustomTabSheet.Destroy;
var
  lIndex: Integer;
begin
  // We should support deleting the tabsheet directly too,
  // and then it should update the tabcontrol
  // This is important mostly for the designer
  if CDTabControl <> nil then
  begin
    lIndex := CDTabControl.FTabs.IndexOfObject(Self);
    if lIndex >= 0 then
    begin
      CDTabControl.FTabs.Delete(lIndex);
      CDTabControl.CorrectTabIndex();
    end;
  end;

  inherited Destroy;
end;

{ TCDCustomTabControl }

procedure TCDCustomTabControl.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: integer);
begin
  TCDCustomTabControlDrawer(FCurrentDrawer).MouseDown(Button, Shift, X, Y, Self);
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCDCustomTabControl.PrepareCurrentDrawer;
begin
  FCurrentDrawer := RegisteredCustomTabControlDrawers[DrawStyle];
  if FCurrentDrawer = nil then FCurrentDrawer := RegisteredCustomTabControlDrawers[dsWince];
  if FCurrentDrawer = nil then raise Exception.Create('No registered custom tab control drawers were found');
end;

procedure TCDCustomTabControl.SetTabIndex(AValue: Integer);
begin
  if FTabIndex = AValue then Exit;
  if Assigned(OnChanging) then OnChanging(Self);
  FTabIndex := AValue;
  if Assigned(OnChange) then OnChange(Self);
  Invalidate;
end;

procedure TCDCustomTabControl.SetTabs(AValue: TStringList);
begin
  if FTabs=AValue then Exit;
  FTabs.Assign(AValue);
  CorrectTabIndex();
  Invalidate;
end;

constructor TCDCustomTabControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Width := 232;
  Height := 184;
  TabStop := True;

  FDrawStyle := dsWinCE;
  PrepareCurrentDrawer();

  ParentColor := True;
  ParentFont := True;
  ControlStyle := ControlStyle + [csAcceptsControls, csDesignInteractive];

  // FTabs should hold only visible tabs
  FTabs := TStringList.Create;
end;

destructor TCDCustomTabControl.Destroy;
begin
  FTabs.Free;

  inherited Destroy;
end;

procedure TCDCustomTabControl.Paint;
var
  AImage: TLazIntfImage = nil;
  ABmp: TBitmap = nil;
  lCanvas: TFPImageCanvas = nil;
begin
  ABmp := TBitmap.Create;
  try
    ABmp.Width := Width;
    ABmp.Height := Height;
    AImage := ABmp.CreateIntfImage;
    lCanvas := TFPImageCanvas.Create(AImage);
    TCDCustomTabControlDrawer(FCurrentDrawer).DrawToIntfImage(lCanvas, AImage, Self);
    ABmp.LoadFromIntfImage(AImage);
    ABmp.Canvas.Font.Assign(Font);
    TCDCustomTabControlDrawer(FCurrentDrawer).DrawToCanvas(ABmp.Canvas, Self);
    Canvas.Draw(0, 0, ABmp);
  finally
    if lCanvas <> nil then
      lCanvas.Free;
    if AImage <> nil then
      AImage.Free;
    ABmp.Free;
  end;
end;

function TCDCustomTabControl.GetTabCount: Integer;
begin
  Result := 0;
  if FTabs <> nil then Result := FTabs.Count;
end;

procedure TCDCustomTabControl.CorrectTabIndex;
begin
  if FTabIndex >= FTabs.Count then SetTabIndex(FTabs.Count - 1);
end;

{ TCDControl }

procedure TCDControl.PrepareCurrentDrawer;
begin

end;

procedure TCDControl.SetDrawStyle(const AValue: TCDDrawStyle);
begin
  if FDrawStyle = AValue then exit;
  FDrawStyle := AValue;
  Invalidate;
  PrepareCurrentDrawer();

  //FCurrentDrawer.SetClientRectPos(Self);
end;

function TCDControl.GetClientRect: TRect;
begin
  // Disable this, since although it works in Win32, it doesn't seam to work in LCL-Carbon
  //if (FCurrentDrawer = nil) then
    Result := inherited GetClientRect()
  //else
    //Result := FCurrentDrawer.GetClientRect(Self);
end;

procedure TCDControl.EraseBackground(DC: HDC);
begin

end;

{ TCDButtonDrawer }

function TCDButtonDrawer.GetClientRect(AControl: TCDControl): TRect;
var
  CDButton: TCDButton absolute AControl;
begin
  Result := Rect(1, 1, CDButton.Width - 1, CDButton.Height - 1);
end;

procedure TCDButton.DoEnter;
begin
  DoButtonUp();

  inherited DoEnter;
end;

procedure TCDButton.DoExit;
begin
  DoButtonUp();

  inherited DoExit;
end;

procedure TCDButton.KeyDown(var Key: word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);

  if (Key = VK_SPACE) or (Key = VK_RETURN) then
    DoButtonDown();
end;

procedure TCDButton.KeyUp(var Key: word; Shift: TShiftState);
begin
  DoButtonUp();

  inherited KeyUp(Key, Shift);
end;

procedure TCDButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  if not Focused then
    SetFocus;
  DoButtonDown();

  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCDButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  DoButtonUp();

  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TCDButton.MouseEnter;
begin
  inherited MouseEnter;
end;

procedure TCDButton.MouseLeave;
begin
  inherited MouseLeave;
end;

procedure TCDButton.DoButtonDown();
var
  NewState: TCDButtonState;
begin
  NewState := bbsDown;

  case FState of
    bbsNormal, bbsFocused: NewState := bbsDown;
  end;

  if NewState <> FState then
  begin
    FState := NewState;
    Invalidate;
  end;
end;

procedure TCDButton.DoButtonUp();
var
  NewState: TCDButtonState;
begin
  if Focused then
    NewState := bbsFocused
  else
    NewState := bbsNormal;

  if NewState <> FState then
  begin
    FState := NewState;
    Invalidate;
  end;
end;

procedure TCDButton.PrepareCurrentDrawer;
begin
  FCurrentDrawer := RegisteredButtonDrawers[DrawStyle];
  if FCurrentDrawer = nil then FCurrentDrawer := RegisteredButtonDrawers[dsWince];
  if FCurrentDrawer = nil then raise Exception.Create('No registered button drawers were found');
end;

procedure TCDButton.RealSetText(const Value: TCaption);
begin
  inherited RealSetText(Value);
  Invalidate;
end;

constructor TCDButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  TabStop := True;
  Width := 120;
  Height := 43;
  //Color := clTeal;
  ParentFont := True;
  Color := $00F1F5F5;

  FDrawStyle := dsAndroid;
  PrepareCurrentDrawer();
end;

destructor TCDButton.Destroy;
begin
  inherited Destroy;
end;

procedure TCDButton.Paint;
var
  AImage: TLazIntfImage = nil;
  ABmp: TBitmap = nil;
  lCanvas: TFPImageCanvas = nil;
  pColor: TColor;
begin
  //  inherited Paint;

  PrepareCurrentDrawer();

  ABmp := TBitmap.Create;
  try
    ABmp.Width := Width;
    ABmp.Height := Height;
    AImage := ABmp.CreateIntfImage;
    lCanvas := TFPImageCanvas.Create(AImage);
    // First step of the drawing: FCL TFPCustomCanvas for fast pixel access
    TCDButtonDrawer(FCurrentDrawer).DrawToIntfImage(lCanvas, Self);
    ABmp.LoadFromIntfImage(AImage);
    // Second step of the drawing: LCL TCustomCanvas for easy font access
    TCDButtonDrawer(FCurrentDrawer).DrawToCanvas(ABmp.Canvas, Self, FState);

    Canvas.Draw(0, 0, ABmp);
  finally
    if lCanvas <> nil then
      lCanvas.Free;
    if AImage <> nil then
      AImage.Free;
    ABmp.Free;
  end;
end;


{ TCDGroupBox }

procedure TCDGroupBox.PrepareCurrentDrawer();
begin
  FCurrentDrawer := RegisteredGroupBoxDrawers[DrawStyle];
  if FCurrentDrawer = nil then FCurrentDrawer := RegisteredGroupBoxDrawers[dsWince];
  if FCurrentDrawer = nil then raise Exception.Create('No registered group box drawers were found');
end;

procedure TCDGroupBox.SetDrawStyle(const AValue: TCDDrawStyle);
begin
  if FDrawStyle = AValue then
    exit;
  FDrawStyle := AValue;

  Invalidate;

  PrepareCurrentDrawer();
  TCDGroupBoxDrawer(FCurrentDrawer).SetClientRectPos(Self);
end;

procedure TCDGroupBox.RealSetText(const Value: TCaption);
begin
  inherited RealSetText(Value);
  Invalidate;
end;

constructor TCDGroupBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 100;
  Height := 100;
  TabStop := False;
  ControlStyle := [csAcceptsControls, csCaptureMouse, csClickEvents,
    csDoubleClicks, csReplicatable];

  DrawStyle := dsWinCE;
  PrepareCurrentDrawer();
end;

destructor TCDGroupBox.Destroy;
begin
  inherited Destroy;
end;

procedure TCDGroupBox.EraseBackground(DC: HDC);
begin

end;

procedure TCDGroupBox.Paint;
var
  AImage: TLazIntfImage = nil;
  ABmp: TBitmap = nil;
  lCanvas: TFPImageCanvas = nil;
begin
  inherited Paint;

  PrepareCurrentDrawer();

  ABmp := TBitmap.Create;
  try
    ABmp.Width := Width;
    ABmp.Height := Height;
    AImage := ABmp.CreateIntfImage;
    lCanvas := TFPImageCanvas.Create(AImage);
    // First step of the drawing: FCL TFPCustomCanvas for fast pixel access
    TCDGroupBoxDrawer(FCurrentDrawer).DrawToIntfImage(lCanvas, Self);
    ABmp.LoadFromIntfImage(AImage);
    // Second step of the drawing: LCL TCustomCanvas for easy font access
    TCDGroupBoxDrawer(FCurrentDrawer).DrawToCanvas(ABmp.Canvas, Self);
    Canvas.Draw(0, 0, ABmp);
  finally
    if lCanvas <> nil then
      lCanvas.Free;
    if AImage <> nil then
      AImage.Free;
    ABmp.Free;
  end;
end;

{ TCDTrackBar }

procedure TCDTrackBar.PrepareCurrentDrawer;
begin
  FCurrentDrawer := RegisteredTrackBarDrawers[DrawStyle];
  if FCurrentDrawer = nil then FCurrentDrawer := RegisteredTrackBarDrawers[dsWince];
  if FCurrentDrawer = nil then raise Exception.Create('No registered track bar drawers were found');
end;

procedure TCDTrackBar.SetMax(Value: integer);
begin
  if Value = FMax then
    Exit;
  FMax := Value;
  Invalidate;
end;

procedure TCDTrackBar.SetMin(Value: integer);
begin
  if Value = FMin then
    Exit;
  FMin := Value;
  Invalidate;
end;

procedure TCDTrackBar.SetPosition(Value: integer);
begin
  if Value = FPosition then Exit;
  FPosition := Value;
  Invalidate;
end;

function TCDTrackBar.GetPositionFromMousePos(X, Y: integer): integer;
var
  lLeftBorder, lRightBorder: Integer;
begin
  TCDTrackBarDrawer(FCurrentDrawer).GetGeometry(lLeftBorder, lRightBorder);
  if X > Width - lRightBorder then Result := FMax
  else if X < lLeftBorder then Result := FMin
  else Result := FMin + (X - lLeftBorder) * (FMax - FMin + 1) div (Width - lRightBorder - lLeftBorder);

  // sanity check
  if Result > FMax then Result := FMax;
  if Result < FMin then Result := FMin;
end;

procedure TCDTrackBar.Changed;
begin

end;

procedure TCDTrackBar.DoEnter;
begin
  inherited DoEnter;
end;

procedure TCDTrackBar.DoExit;
begin
  inherited DoExit;
end;

procedure TCDTrackBar.KeyDown(var Key: word; Shift: TShiftState);
var
  NewPosition: Integer;
begin
  inherited KeyDown(Key, Shift);
  if (Key = 37) or (Key = 40) then
    NewPosition := FPosition - (FMax - FMin) div 10;
  if (Key = 38) or (Key = 39) then
    NewPosition := FPosition + (FMax - FMin) div 10;

  // sanity check
  if NewPosition > FMax then NewPosition := FMax;
  if NewPosition < FMin then NewPosition := FMin;

  Position := NewPosition;
end;

procedure TCDTrackBar.KeyUp(var Key: word; Shift: TShiftState);
begin
  inherited KeyUp(Key, Shift);
end;

procedure TCDTrackBar.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: integer);
var
  NewPosition: Integer;
begin
  SetFocus;

  NewPosition := GetPositionFromMousePos(X, Y);

  DragDropStarted := True;

  Position := NewPosition;

  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCDTrackBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  DragDropStarted := False;
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TCDTrackBar.MouseMove(Shift: TShiftState; X, Y: integer);
var
  NewPosition: Integer;
begin
  if DragDropStarted then
  begin
    NewPosition := GetPositionFromMousePos(X, Y);
    Position := NewPosition;
  end;
  inherited MouseMove(Shift, X, Y);
end;

procedure TCDTrackBar.MouseEnter;
begin
  inherited MouseEnter;
end;

procedure TCDTrackBar.MouseLeave;
begin
  inherited MouseLeave;
end;

constructor TCDTrackBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Height := 25;
  Width := 100;

  DrawStyle := dsExtra1;
  PrepareCurrentDrawer();

  Color := clBtnFace;
  FMax := 10;
  FMin := 0;
  TabStop := True;
end;

destructor TCDTrackBar.Destroy;
begin
  FCurrentDrawer.Free;
  inherited Destroy;
end;

procedure TCDTrackBar.EraseBackground(DC: HDC);
begin
  //inherited EraseBackground(DC);
end;

procedure TCDTrackBar.Paint;
var
  AImage: TLazIntfImage = nil;
  ABmp: TBitmap = nil;
  lCanvas: TFPImageCanvas = nil;
begin
  inherited Paint;
  ABmp := TBitmap.Create;
  try
    ABmp.Width := Width;
    ABmp.Height := Height;
    AImage := ABmp.CreateIntfImage;
    lCanvas := TFPImageCanvas.Create(AImage);
    // First step of the drawing: FCL TFPCustomCanvas for fast pixel access
    TCDTrackBarDrawer(FCurrentDrawer).DrawToIntfImage(lCanvas, AImage, Self);
    ABmp.LoadFromIntfImage(AImage);
    Canvas.Draw(0, 0, ABmp);
  finally
    if lCanvas <> nil then
      lCanvas.Free;
    if AImage <> nil then
      AImage.Free;
    ABmp.Free;
  end;
end;

{ TCDTabSheet }

constructor TCDTabSheet.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  TabStop := False;
  ParentColor := True;
  parentFont := True;
  ControlStyle := [csAcceptsControls, csCaptureMouse, csClickEvents,
    csDesignFixedBounds, csDoubleClicks, csDesignInteractive];
  //ControlStyle := ControlStyle + [csAcceptsControls, csDesignFixedBounds,
  //  csNoDesignVisible, csNoFocus];
end;

destructor TCDTabSheet.Destroy;
begin
  inherited Destroy;
end;

procedure TCDTabSheet.EraseBackground(DC: HDC);
begin

end;

procedure TCDTabSheet.Paint;
begin
  if CDTabControl <> nil then
  begin
    TCDCustomTabControlDrawer(CDTabControl.FCurrentDrawer).DrawTabSheet(Canvas, CDTabControl);
  end;
end;

{ TCDPageControl }

function TCDPageControl.AddPage(S: string): TCDTabSheet;
//  InsertPage(FPages.Count, S);
var
  NewPage: TCDTabSheet;
begin
  NewPage := TCDTabSheet.Create(Owner);
  NewPage.Parent := Self;
  NewPage.CDTabControl := Self;
  //Name := Designer.CreateUniqueComponentName(ClassName);
  NewPage.Name := GetUniqueName(sTABSHEET_DEFAULT_NAME, Self.Owner);
  if S = '' then
    NewPage.Caption := NewPage.Name
  else
    NewPage.Caption := S;

  PositionTabSheet(NewPage);

  FTabs.AddObject(S, NewPage);

  SetActivePage(NewPage);

  Result := NewPage;
end;

function TCDPageControl.GetPage(AIndex: integer): TCDTabSheet;
begin
  if (AIndex >= 0) and (AIndex < FTabs.Count) then
    Result := TCDTabSheet(FTabs.Objects[AIndex])
  else
    Result := nil;
end;

function TCDPageControl.InsertPage(aIndex: integer; S: string): TCDTabSheet;
var
  NewPage: TCDTabSheet;
begin
  NewPage := TCDTabSheet.Create(Owner);
  NewPage.Parent := Self;
  //Name := Designer.CreateUniqueComponentName(ClassName);
  NewPage.Name := GetUniqueName(sTABSHEET_DEFAULT_NAME, Self.Owner);
  if S = '' then
    NewPage.Caption := NewPage.Name
  else
    NewPage.Caption := S;

  PositionTabSheet(NewPage);

  FTabs.InsertObject(AIndex, S, NewPage);

  SetActivePage(NewPage);
  Result := NewPage;
end;

procedure TCDPageControl.RemovePage(aIndex: integer);
begin
  if (AIndex < 0) or (AIndex >= FTabs.Count) then Exit;

  Application.ReleaseComponent(TComponent(FTabs.Objects[AIndex]));

  FTabs.Delete(aIndex);
  if FTabIndex >= FTabs.Count then SetTabIndex(FTabIndex-1);

  Invalidate;
end;

function TCDPageControl.FindNextPage(CurPage: TCDTabSheet;
  GoForward, CheckTabVisible: boolean): TCDTabSheet;
var
  I, TempStartIndex: integer;
begin
  if FTabs.Count <> 0 then
  begin
    //StartIndex := FPages.IndexOfObject(CurPage);
    TempStartIndex := FTabs.IndexOfObject(CurPage);
    if TempStartIndex = -1 then
      if GoForward then
        TempStartIndex := FTabs.Count - 1
      else
        TempStartIndex := 0;
    I := TempStartIndex;
    repeat
      if GoForward then
      begin
        Inc(I);
        if I = FTabs.Count then
          I := 0;
      end
      else
      begin
        if I = 0 then
          I := FTabs.Count;
        Dec(I);
      end;
      Result := TCDTabSheet(FTabs.Objects[I]);
      if not CheckTabVisible or Result.Visible then
        Exit;
    until I = TempStartIndex;
  end;
  Result := nil;
end;

procedure TCDPageControl.SelectNextPage(GoForward: boolean;
  CheckTabVisible: boolean = True);
var
  Page: TCDTabSheet;
begin
  Page := FindNextPage(ActivePage, GoForward, CheckTabVisible);
  if (Page <> nil) and (Page <> ActivePage) then
    SetActivePage(Page);
end;

constructor TCDPageControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  ControlStyle := ControlStyle - [csAcceptsControls];
end;

destructor TCDPageControl.Destroy;
begin
  inherited Destroy;
end;

procedure TCDPageControl.SetActivePage(Value: TCDTabSheet);
var
  i: integer;
  CurPage: TCDTabSheet;
begin
  for i := 0 to FTabs.Count - 1 do
  begin
    CurPage := TCDTabSheet(FTabs.Objects[i]);
    if CurPage = Value then
    begin
      PositionTabSheet(CurPage);
      CurPage.BringToFront;
      CurPage.Visible := True;

      // Check first, Tab is Visible?
      SetTabIndex(i);
    end
    else if CurPage <> nil then
    begin
      //CurPage.Align := alNone;
      //CurPage.Height := 0;
      CurPage.Visible := False;
    end;
  end;

  Invalidate;
end;

procedure TCDPageControl.SetPageIndex(Value: integer);
begin
  if (Value > -1) and (Value < FTabs.Count) then
  begin
    SetTabIndex(Value);
    ActivePage := GetPage(Value);
  end;
end;

procedure TCDPageControl.UpdateAllDesignerFlags;
var
  i: integer;
begin
  for i := 0 to FTabs.Count - 1 do
    UpdateDesignerFlags(i);
end;

procedure TCDPageControl.UpdateDesignerFlags(APageIndex: integer);
var
  CurPage: TCDTabSheet;
begin
  CurPage := GetPage(APageIndex);
  if APageIndex <> fTabIndex then
    CurPage.ControlStyle := CurPage.ControlStyle + [csNoDesignVisible]
  else
    CurPage.ControlStyle := CurPage.ControlStyle - [csNoDesignVisible];
end;

procedure TCDPageControl.PositionTabSheet(ATabSheet: TCDTabSheet);
var
  lTabHeight, lIndex: Integer;
begin
//  ATabSheet.SetBounds(1, 32 + 1, Width - 3, Height - 32 - 4);
  lIndex := FTabs.IndexOfObject(ATabSheet);
  lTabHeight := TCDCustomTabControlDrawer(FCurrentDrawer).GetTabHeight(lIndex, Self);
  ATabSheet.BorderSpacing.Top := lTabHeight;
  ATabSheet.BorderSpacing.Left := 2;
  ATabSheet.BorderSpacing.Right := 3;
  ATabSheet.BorderSpacing.Bottom := 3;
  ATabSheet.Align := alClient;
end;

function TCDPageControl.GetActivePage: TCDTabSheet;
begin
  Result := GetPage(FTabIndex);
end;

function TCDPageControl.GetPageCount: integer;
begin
  Result := FTabs.Count;
end;

function TCDPageControl.GetPageIndex: integer;
begin
  Result := FTabIndex;
end;

end.

