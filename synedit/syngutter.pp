unit SynGutter;

{$I synedit.inc}

interface

uses
  SysUtils, Classes, Controls, Graphics, LCLType, LCLIntf, Menus,
  SynEditMarks, SynEditMiscClasses, SynEditMiscProcs,
  SynTextDrawer, SynGutterBase, SynGutterLineNumber, SynGutterCodeFolding,
  SynGutterMarks, SynGutterChanges, SynEditMouseCmds;

type

  TSynGutterSeparator = class;

  { TSynGutter }

  TSynGutter = class(TSynGutterBase)
  private
    FCursor: TCursor;
    FOnGutterClick: TGutterClickEvent;
    FMouseDownPart: Integer;
    function PixelToPartIndex(X: Integer): Integer;
  protected
    procedure DoDefaultGutterClick(Sender: TObject; X, Y, Line: integer;
      mark: TSynEditMark); override;
    function CreatePartList: TSynGutterPartListBase; override;
    procedure CreateDefaultGutterParts; virtual;
  public
    constructor Create(AOwner : TSynEditBase; ASide: TSynGutterSide;
                      ATextDrawer: TheTextDrawer);
    destructor Destroy; override;
    procedure Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer);
    function  HasCustomPopupMenu(out PopMenu: TPopupMenu): Boolean;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MouseMove(Shift: TShiftState; X, Y: Integer);
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    function  MaybeHandleMouseAction(var AnInfo: TSynEditMouseActionInfo;
                         HandleActionProc: TSynEditMouseActionHandler): Boolean;
    function DoHandleMouseAction(AnAction: TSynEditMouseAction;
                                 var AnInfo: TSynEditMouseActionInfo): Boolean;
    procedure DoOnGutterClick(X, Y: integer);
    property  OnGutterClick: TGutterClickEvent
      read FOnGutterClick write FOnGutterClick;
  public
    // Access to well known parts
    Function LineNumberPart(Index: Integer = 0): TSynGutterLineNumber;
    Function CodeFoldPart(Index: Integer = 0): TSynGutterCodeFolding;
    Function ChangesPart(Index: Integer = 0): TSynGutterChanges;
    Function MarksPart(Index: Integer = 0): TSynGutterMarks;
    Function SeparatorPart(Index: Integer = 0): TSynGutterSeparator;
  published
    property AutoSize;
    property Color;
    property Cursor: TCursor read FCursor write FCursor default crDefault;
    property LeftOffset;
    property RightOffset;
    property Visible;
    property Width;
    property Parts;
    property MouseActions;
  end;

  { TSynGutterSeparator }

  TSynGutterSeparator = class(TSynGutterPartBase)
  private
    FLineOffset: Integer;
    FLineOnRight: Boolean;
    FLineWidth: Integer;
    procedure SetLineOffset(const AValue: Integer);
    procedure SetLineOnRight(const AValue: Boolean);
    procedure SetLineWidth(const AValue: Integer);
  protected
    function  PreferedWidth: Integer; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer); override;
  published
    property LineWidth: Integer read FLineWidth write SetLineWidth default 1;
    property LineOffset: Integer read FLineOffset write SetLineOffset default 0;
    property LineOnRight: Boolean read FLineOnRight write SetLineOnRight default True;
  end;

  { TSynEditMouseActionsGutter }

  TSynEditMouseActionsGutter = class(TSynEditMouseActions)
  public
    procedure ResetDefaults; override;
  end;


implementation
uses
  SynEdit;

{ TSynGutter }

constructor TSynGutter.Create(AOwner: TSynEditBase; ASide: TSynGutterSide;
  ATextDrawer: TheTextDrawer);
begin
  inherited;

  FMouseActions := TSynEditMouseActionsGutter.Create(self);
  FMouseActions.ResetDefaults;

  if not(csLoading in AOwner.ComponentState) then
    CreateDefaultGutterParts;
end;

destructor TSynGutter.Destroy;
begin
  OnChange := nil;
  OnResize := nil;
  FreeAndNil(FMouseActions);
  inherited Destroy;
end;

procedure TSynGutter.CreateDefaultGutterParts;
begin
  if Side <> gsLeft then
    exit;

  // Todo: currently there is only one Gutter so names can be fixed
  with TSynGutterMarks.Create(Parts) do
    Name := 'SynGutterMarks1';
  with TSynGutterLineNumber.Create(Parts) do
    Name := 'SynGutterLineNumber1';
  with TSynGutterChanges.Create(Parts) do
    Name := 'SynGutterChanges1';
  with TSynGutterSeparator.Create(Parts) do
    Name := 'SynGutterSeparator1';
  with TSynGutterCodeFolding.Create(Parts) do
    Name := 'SynGutterCodeFolding1';
end;

function TSynGutter.PixelToPartIndex(X: Integer): Integer;
begin
  Result := 0;
  x := x - LeftOffset;
  while Result < PartCount-1 do begin
    if Parts[Result].Visible then begin
      if x >= Parts[Result].Width then
        x := x - Parts[Result].Width
      else
        break;
    end;
    inc(Result)
  end;
end;

procedure TSynGutter.DoDefaultGutterClick(Sender: TObject; X, Y, Line: integer;
  mark: TSynEditMark);
begin
end;

function TSynGutter.CreatePartList: TSynGutterPartListBase;
begin
  case Side of
    gsLeft:
      begin
        Result := TSynGutterPartList.Create(SynEdit, self); //left side gutter
        Result.Name := 'SynLeftGutterPartList1';
      end;
    gsRight:
      begin
        Result := TSynRightGutterPartList.Create(SynEdit, self);
        Result.Name := 'SynRightGutterPartList1';
      end;
  end;
end;

procedure TSynGutter.DoOnGutterClick(X, Y: integer);
begin
  Parts[PixelToPartIndex(X)].DoOnGutterClick(X, Y);
end;

procedure TSynGutter.Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer);
var
  i: integer;
  rcLine: TRect;
  dc: HDC;
begin
  Canvas.Brush.Color := Color;
  dc := Canvas.Handle;
  {$IFDEF SYN_LAZARUS}
  LCLIntf.SetBkColor(dc, TColorRef(Canvas.Brush.Color));
  {$ENDIF}

  // Clear all
  TextDrawer.BeginDrawing(dc);
  TextDrawer.SetBackColor(Color);
  TextDrawer.SetForeColor(TCustomSynEdit(SynEdit).Font.Color);
  TextDrawer.SetFrameColor(clNone);
   with AClip do
     TextDrawer.ExtTextOut(Left, Top, ETO_OPAQUE, AClip, nil, 0);
  TextDrawer.EndDrawing;

  if Side = gsLeft then
    AClip.Left := LeftOffset
  else
    AClip.Left := SynEdit.ClientWidth - Width - ScrollBarWidth + LeftOffset;

  rcLine := AClip;
  rcLine.Right := rcLine.Left;
  for i := 0 to PartCount -1 do
  begin
    if rcLine.Right >= AClip.Right then break;
    if Parts[i].Visible then
    begin
      rcLine.Left := rcLine.Right;
      rcLine.Right := min(rcLine.Left + Parts[i].Width, AClip.Right);
      Parts[i].Paint(Canvas, rcLine, FirstLine, LastLine);
    end;
  end;
end;

function TSynGutter.HasCustomPopupMenu(out PopMenu: TPopupMenu): Boolean;
begin
  Result := Parts[FMouseDownPart].HasCustomPopupMenu(PopMenu);
end;

procedure TSynGutter.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FMouseDownPart := PixelToPartIndex(X);
  Parts[FMouseDownPart].MouseDown(Button, Shift, X, Y);
  if (Button=mbLeft) then
    DoOnGutterClick(X, Y);
end;

procedure TSynGutter.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  Parts[FMouseDownPart].MouseMove(Shift, X, Y);
end;

procedure TSynGutter.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  Parts[FMouseDownPart].MouseUp(Button, Shift, X, Y);
end;

function TSynGutter.MaybeHandleMouseAction(var AnInfo: TSynEditMouseActionInfo;
  HandleActionProc: TSynEditMouseActionHandler): Boolean;
var
  MouseDownPart: LongInt;
begin
  MouseDownPart := PixelToPartIndex(AnInfo.MouseX);
  Result := Parts[MouseDownPart].MaybeHandleMouseAction(AnInfo, HandleActionProc);
  if not Result then
    Result := HandleActionProc(MouseActions, AnInfo);
end;

function TSynGutter.DoHandleMouseAction(AnAction: TSynEditMouseAction;
  var AnInfo: TSynEditMouseActionInfo): Boolean;
var
  i: Integer;
  ACommand: Word;
begin
  Result := False;
  for i := 0 to Parts.Count - 1 do begin
    Result := Parts[i].DoHandleMouseAction(AnAction, AnInfo);
    if Result then exit;;
  end;

  if AnAction = nil then exit;
  ACommand := AnAction.Command;
  if (ACommand = emcNone) then exit;

  case ACommand of
    emcOnMainGutterClick:
      begin
        if Assigned(FOnGutterClick) then begin
          FOnGutterClick(Self, AnInfo.MouseX, AnInfo.MouseY, AnInfo.NewCaret.LinePos, nil);
          Result := True;
        end;
      end;
  end;
end;

function TSynGutter.LineNumberPart(Index: Integer = 0): TSynGutterLineNumber;
begin
  Result := TSynGutterLineNumber(Parts.ByClass[TSynGutterLineNumber, Index]);
end;

function TSynGutter.CodeFoldPart(Index: Integer = 0): TSynGutterCodeFolding;
begin
  Result := TSynGutterCodeFolding(Parts.ByClass[TSynGutterCodeFolding, Index]);
end;

function TSynGutter.ChangesPart(Index: Integer = 0): TSynGutterChanges;
begin
  Result := TSynGutterChanges(Parts.ByClass[TSynGutterChanges, Index]);
end;

function TSynGutter.MarksPart(Index: Integer = 0): TSynGutterMarks;
begin
  Result := TSynGutterMarks(Parts.ByClass[TSynGutterMarks, Index]);
end;

function TSynGutter.SeparatorPart(Index: Integer = 0): TSynGutterSeparator;
begin
  Result := TSynGutterSeparator(Parts.ByClass[TSynGutterSeparator, Index]);
end;

{ TSynGutterSeparator }

procedure TSynGutterSeparator.SetLineWidth(const AValue: Integer);
begin
  if FLineWidth = AValue then exit;
  FLineWidth := AValue;
  DoChange(Self);
end;

procedure TSynGutterSeparator.SetLineOffset(const AValue: Integer);
begin
  if FLineOffset = AValue then exit;
  FLineOffset := AValue;
  DoChange(Self);
end;

procedure TSynGutterSeparator.SetLineOnRight(const AValue: Boolean);
begin
  if FLineOnRight = AValue then exit;
  FLineOnRight := AValue;
  DoChange(Self);
end;

function TSynGutterSeparator.PreferedWidth: Integer;
begin
  Result := 2;
end;

constructor TSynGutterSeparator.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  MarkupInfo.Background := clWhite;
  MarkupInfo.Foreground := clDkGray;
  FLineWidth := 1;
  FLineOffset := 0;
  FLineOnRight := True;
end;

procedure TSynGutterSeparator.Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer);
begin
  with Canvas do
  begin
    Brush.Color := MarkupInfo.Background;
    Brush.Style := bsSolid;
    FillRect(AClip);
    if FLineOnRight then begin
      dec(AClip.Right, FLineOffset);
      AClip.Left := AClip.Right - FLineWidth;
    end else begin
      inc(AClip.Left, FLineOffset);
      AClip.Right := AClip.Left + FLineWidth;
    end;
    Brush.Color := MarkupInfo.Foreground;
    FillRect(AClip);
  end;
end;

{ TSynEditMouseActionsGutter }

procedure TSynEditMouseActionsGutter.ResetDefaults;
begin
  Clear;
  AddCommand(emcOnMainGutterClick, False, mbLeft, ccAny, cdDown, [], []);
  AddCommand(emcContextMenu, False, mbRight, ccSingle, cdUp, [], []);
end;

end.

