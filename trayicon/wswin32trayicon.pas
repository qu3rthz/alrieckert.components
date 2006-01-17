{
 wswin32trayicon.pas

 *****************************************************************************
 *                                                                           *
 *  See the file COPYING.modifiedLGPL, included in this distribution,        *
 *  for details about the copyright.                                         *
 *                                                                           *
 *  This program is distributed in the hope that it will be useful,          *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
 *                                                                           *
 *****************************************************************************

 Authors: Felipe Monteiro de Carvalho and Andrew Haines

 Win32 specific code.
}
unit wswin32trayicon;

{$ifdef FPC}
  {$mode delphi}{$H+}
{$endif}

interface

uses
  Graphics, Classes, SysUtils, Menus, Forms, Controls;

type

  { TWidgetTrayIcon }

  TWidgetTrayIcon = class(TObject)
    private
      WindowHandle: Cardinal;
      function GetCanvas: TCanvas;
    protected
    public
      uID: Cardinal;
      Icon: TIcon;
      ShowIcon, ShowToolTip: Boolean;
      PopUpMenu: TPopUpMenu;
      ToolTip: array [0..63] of AnsiChar;
      OnPaint, OnClick, OnDblClick: TNotifyEvent;
      OnMouseDown, OnMouseUp: TMouseEvent;
      OnMouseMove: TMouseMoveEvent;
      constructor Create;
      destructor Destroy; override;
      function Hide: Boolean;
      function Show: Boolean;
      property Canvas: TCanvas read GetCanvas;
    published
  end;

implementation

uses WSTrayIcon, Windows, ShellAPI, Messages;

const
  szClassName = 'TTrayIconClass';
  szAppTitle = 'apptytle';

{*******************************************************************
*  TrayWndProc ()
*
*  DESCRIPTION:    Window procedure that processes messages for the
*                 systray icon
*
*  PARAMETERS:     Standard Mouse Messages have this parameters:
*
*                  fwKeys = wParam;        // key flags
*                  xPos = LOWORD(lParam);  // horizontal position of cursor
*                  yPos = HIWORD(lParam);  // vertical position of cursor
*
*  RETURNS:        A pointer to the newly created object
*
*******************************************************************}
function TrayWndProc(Handle: HWND; iMsg: UINT; WParam_: WPARAM; LParam_:LPARAM):LRESULT; stdcall;
begin
  {*******************************************************************
  *  The separate check on vwsTrayIconCreated is necessary because
  *  vwsTrayIcon.uID may not have being initialized yet
  *******************************************************************}
  if vwsTrayIconCreated then
   if iMsg = WM_USER + vwsTrayIcon.uID then
   begin
     case LParam_ of
      WM_RBUTTONUP:
      begin
        if Assigned(vwsTrayIcon.OnMouseUp) then vwsTrayIcon.OnMouseUp(Application,
         mbRight, KeysToShiftState(WParam_), LOWORD(lParam_), HIWORD(lParam_));
        if Assigned(vwsTrayIcon.PopUpMenu) then
         vwsTrayIcon.PopUpMenu.Popup(LOWORD(lParam_), HIWORD(lParam_));
      end;
      WM_RBUTTONDOWN: if Assigned(vwsTrayIcon.OnMouseDown) then vwsTrayIcon.OnMouseDown(Application,
       mbRight, KeysToShiftState(WParam_), LOWORD(lParam_), HIWORD(lParam_));
      WM_RBUTTONDBLCLK: if Assigned(vwsTrayIcon.OnDblClick) then vwsTrayIcon.OnDblClick(Application);

      WM_MBUTTONDOWN: if Assigned(vwsTrayIcon.OnMouseDown) then vwsTrayIcon.OnMouseDown(Application,
       mbMiddle, KeysToShiftState(WParam_), LOWORD(lParam_), HIWORD(lParam_));
      WM_MBUTTONUP: if Assigned(vwsTrayIcon.OnMouseUp) then vwsTrayIcon.OnMouseUp(Application,
       mbMiddle, KeysToShiftState(WParam_), LOWORD(lParam_), HIWORD(lParam_));

      WM_LBUTTONUP:
      begin
        if Assigned(vwsTrayIcon.OnMouseUp) then vwsTrayIcon.OnMouseUp(Application,
         mbLeft, KeysToShiftState(WParam_), LOWORD(lParam_), HIWORD(lParam_));
        if Assigned(vwsTrayIcon.OnClick) then vwsTrayIcon.OnClick(Application);
      end;
      WM_LBUTTONDOWN: if Assigned(vwsTrayIcon.OnMouseDown) then vwsTrayIcon.OnMouseDown(Application,
       mbLeft, KeysToShiftState(WParam_), LOWORD(lParam_), HIWORD(lParam_));
      WM_LBUTTONDBLCLK: if Assigned(vwsTrayIcon.OnDblClick) then vwsTrayIcon.OnDblClick(Application);

      WM_MOUSEMOVE: if Assigned(vwsTrayIcon.OnMouseMove) then
       vwsTrayIcon.OnMouseMove(Application, KeysToShiftState(WParam_), LOWORD(lParam_), HIWORD(lParam_));
     end;

     Result := 1;
     Exit;
   end;

  Result := DefWindowProc(Handle, iMsg, WParam_, LParam_);
end;

{ TWidgetTrayIcon }

function TWidgetTrayIcon.GetCanvas: TCanvas;
begin
  Result := Icon.Canvas;
end;

{*******************************************************************
*  TWidgetTrayIcon.Create ()
*
*  DESCRIPTION:    Creates a object from the TWidgetTrayIcon class
*
*  PARAMETERS:     None
*
*  RETURNS:        A pointer to the newly created object
*
*******************************************************************}
constructor TWidgetTrayIcon.Create;
var
  Window: TWndClassEx;
begin
  inherited Create;

  Icon := TIcon.Create;

  uID := 3;

  ZeroMemory(@Window, SizeOf(TWndClassEx));
  Window.cbSize := SizeOf(TWndClassEx);
  Window.style := CS_OWNDC;
  Window.lpfnWndProc := @TrayWndProc;
  Window.cbClsExtra := 0;
  Window.cbWndExtra := 0;
  Window.hInstance := hInstance;
//  Window.hIcon := Icon.Picture.Icon.Handle;
  Window.hCursor := LoadCursor(0, IDC_ARROW);
  Window.hbrBackground := HBRUSH(GetStockObject(NULL_BRUSH));
  Window.lpszMenuName := nil;
  Window.lpszClassName := szClassName;
//  Window.hIconSm := hSmallIcon;

  Windows.RegisterClassEx(Window);

  WindowHandle := CreateWindowEx(
        0,            //* Ensure that there will be no button in the bar */
        szClassName,        //* Name of the registered class */
        szAppTitle,         //* Title of the window */
        0,                  //* Style of the window */
        0,                  //* x-position (at beginning) */
        0,                  //* y-position (at beginning) */
        CW_USEDEFAULT,      //* window width */
        CW_USEDEFAULT,      //* window height */
        0,                  //* handle to parent or owner window */
        0,                  //* handle to menu */
        hInstance,          //* handle to application instance */
        nil);               //* pointer to window-creation data */
end;

{*******************************************************************
*  TWidgetTrayIcon.Destroy ()
*
*  DESCRIPTION:    Destroys a object derived from the TWidgetTrayIcon class
*
*  PARAMETERS:     None
*
*  RETURNS:        Nothing
*
*******************************************************************}
destructor TWidgetTrayIcon.Destroy;
begin
  // Destroys the helper Windows
  Hide;
  PostMessage(WindowHandle, WM_CLOSE, 0, 0);
  PostMessage(WindowHandle, WM_DESTROY, 0, 0);

  Application.ProcessMessages;

  Icon.Free;

  inherited Destroy;
end;

{*******************************************************************
*  TWidgetTrayIcon.Hide ()
*
*  DESCRIPTION:    Hides the main tray icon of the program
*
*  PARAMETERS:     None
*
*  RETURNS:        True if sucessfull, otherwise False
*
*******************************************************************}
function TWidgetTrayIcon.Hide: Boolean;
var
  tnid: TNotifyIconData;
begin
  // Fill TNotifyIconData
  tnid.cbSize := SizeOf(TNotifyIconData);
{$IFNDEF FPC}
  tnid.Wnd := WindowHandle;
{$ELSE}
  tnid.hWnd := WindowHandle;
{$ENDIF}
  tnid.uID := uID;

  // Remove the icon
  Result := Shell_NotifyIconA(NIM_DELETE, @tnid);
end;

{*******************************************************************
*  TWidgetTrayIcon.Show ()
*
*  DESCRIPTION:    Shows the main tray icon of the program
*
*  PARAMETERS:     None
*
*  RETURNS:        True if sucessfull, otherwise False
*
*******************************************************************}
function TWidgetTrayIcon.Show: Boolean;
var
  tnid: TNotifyIconData;
begin
  // Fill TNotifyIconData
  FillChar(tnid, SizeOf(tnid), 0);
  tnid.cbSize := SizeOf(TNotifyIconData);
{$IFNDEF FPC}
  tnid.Wnd := WindowHandle;
{$ELSE}
  tnid.hWnd := WindowHandle;
{$ENDIF}
  tnid.uID := uID;
  tnid.uFlags := NIF_MESSAGE or NIF_ICON;
  if ShowToolTip then tnid.uFlags := tnid.uFlags or NIF_TIP;
  tnid.uCallbackMessage := WM_USER + uID;
  tnid.hIcon := Icon.Handle;
  Move(ToolTip, tnid.szTip, SizeOf(tnid.szTip));

  // Create Taskbar icon
  Result := Shell_NotifyIconA(NIM_ADD, @tnid);
end;

end.

