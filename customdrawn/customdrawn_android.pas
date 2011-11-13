unit customdrawn_android;

{$mode objfpc}{$H+}

interface

uses
  // RTL
  Classes, SysUtils, Types,
  // fpimage
  fpcanvas, fpimgcanv, fpimage,
  // LCL -> Use only TForm, TWinControl, TCanvas and TLazIntfImage
  Graphics, Controls, LCLType, LCLIntf, IntfGraphics, LResources,
  //
  customdrawndrawers, customdrawn_common;

type

  { TCDDrawerAndroid }

  TCDDrawerAndroid = class(TCDDrawerCommon)
  private
    bmpCheckbox, bmpCheckboxChecked: TBitmap;
  public
    procedure CreateResources; override;
    procedure LoadResources; override;
    procedure FreeResources; override;
    // General drawing routines
    {procedure DrawFocusRect(ADest: TCanvas; ADestPos: TPoint; ASize: TSize); override;
    procedure DrawRaisedFrame(ADest: TCanvas; ADestPos: TPoint; ASize: TSize); override;
    procedure DrawSunkenFrame(ADest: TCanvas; ADestPos: TPoint; ASize: TSize); override;
    procedure DrawShallowSunkenFrame(ADest: TCanvas; ADestPos: TPoint; ASize: TSize); override;}
    procedure DrawTickmark(ADest: TCanvas; ADestPos: TPoint); override;
    {procedure DrawSlider(ADest: TCanvas; ADestPos: TPoint; ASize: TSize; AState: TCDControlState); override;
    procedure DrawCompactArrow(ADest: TCanvas; ADestPos: TPoint; ADirection: TCDControlState); override;}
    // ===================================
    // Standard Tab
    // ===================================
    // TCDButton
{    procedure DrawButton(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDControlStateEx); override;
    // TCDEdit
    procedure DrawEditBackground(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDEditStateEx); override;}
    // TCDCheckBox
    procedure DrawCheckBoxSquare(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDControlStateEx); override;
  end;

implementation

const
  ANDROID_DPI = 'vldpi';

{procedure TCDButtonDrawerAndroid.DrawToIntfImage(ADest: TFPImageCanvas;
  CDButton: TCDButton);
begin

end;

procedure TCDButtonDrawerAndroid.DrawToCanvas(ADest: TCanvas; CDButton: TCDButton);
var
  //TmpB: TBitmap;
  Str: string;
begin
  // Button shape -> This crashes in Gtk2
{  TmpB.Canvas.Brush.Color := CDButton.Color;
  TmpB.Canvas.Brush.Style := bsSolid;
  TmpB.Canvas.RoundRect(0, 0, TmpB.Width, TmpB.Height, 8, 8);
  CDButton.SetShape(TmpB);
  ADest.Draw(0, 0, TmpB);
  TmpB.Free;
  }

  ADest.Brush.Color := CDButton.Parent.Color;
  ADest.Brush.Style := bsSolid;
  ADest.Pen.Color := ADest.Brush.Color;
  ADest.RecTangle(0, 0, CDButton.Width, CDButton.Height);

  // Button image
  if CDButton.IsDown then
    DrawCDButtonDown(ADest, CDButton.GetRGBBackgroundColor)
  else if CDButton.Focused then
    DrawAndroidButton(ADest, GetAColor(CDButton.Color, 98))
  else
    DrawAndroidButton(ADest, GetAColor(CDButton.Color, 96));

  // Button text
  ADest.Font.Assign(CDButton.Font);
  ADest.Brush.Style := bsClear;
  ADest.Pen.Style := psSolid;
  Str := CDButton.Caption;
  ADest.TextOut((CDButton.Width - ADest.TextWidth(Str)) div 2,
    (CDButton.Height - ADest.TextHeight(Str)) div 2, Str);
end;

initialization
  RegisterButtonDrawer(TCDButtonDrawerAndroid.Create, dsAndroid);}

{ TCDDrawerAndroid }

procedure TCDDrawerAndroid.CreateResources;
begin
  bmpCheckbox := TBitmap.Create;
  bmpCheckboxChecked := TBitmap.Create;
end;

procedure TCDDrawerAndroid.LoadResources;
begin
  bmpCheckbox.LoadFromLazarusResource('android_checkbox');
  bmpCheckboxChecked.LoadFromLazarusResource('android_checkbox_checked');

  // for now hardcoded to ldpi
  bmpCheckbox.Canvas.StretchDraw(Bounds(0, 0, 22, 22), bmpCheckbox);
  bmpCheckbox.Width := 22;
  bmpCheckbox.Height := 22;
  bmpCheckboxChecked.Canvas.StretchDraw(Bounds(0, 0, 22, 22), bmpCheckboxChecked);
  bmpCheckboxChecked.Width := 22;
  bmpCheckboxChecked.Height := 22;
end;

procedure TCDDrawerAndroid.FreeResources;
begin
  bmpCheckbox.Free;
  bmpCheckboxChecked.Free;
end;

procedure TCDDrawerAndroid.DrawTickmark(ADest: TCanvas; ADestPos: TPoint);
begin
  // Don't draw anything, tickmarks are impressed into the general images
end;

procedure TCDDrawerAndroid.DrawCheckBoxSquare(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDControlStateEx);
begin
  if csfOn in AState then ADest.Draw(0, 0, bmpCheckboxChecked)
  else ADest.Draw(0, 0, bmpCheckbox);
end;

initialization
  {$I customdrawnimages/android.lrs}

  RegisterDrawer(TCDDrawerAndroid.Create, dsAndroid);
end.

