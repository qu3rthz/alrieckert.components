unit customdrawn_winxp;

{$mode objfpc}{$H+}

interface

uses
  // RTL
  Classes, SysUtils, Types,
  // LCL -> Use only TForm, TWinControl, TCanvas and TLazIntfImage
  Graphics, Controls, LCLType,
  //
  customdrawndrawers, customdrawn_common, customdrawnutils;

type

  { TCDDrawerWinXP }

  TCDDrawerWinXP = class(TCDDrawerCommon)
  public
    // ===================================
    // Standard Tab
    // ===================================
    // TCDButton
    procedure DrawButton(ADest: TCanvas; ADestPos: TPoint; ASize: TSize;
      AState: TCDControlState; AStateEx: TCDControlStateEx); override;
  end;

implementation

{ TCDDrawerWinXP }

procedure TCDDrawerWinXP.DrawButton(ADest: TCanvas; ADestPos: TPoint;
  ASize: TSize; AState: TCDControlState; AStateEx: TCDControlStateEx);
var
  Str: string;
  lColor: TColor;
begin
  if csfSunken in AState then
  begin
    lColor := AStateEx.RGBColor;

    ADest.Brush.Style := bsSolid;
    ADest.Brush.Color := lColor;
    ADest.Pen.Color := lColor;
    ADest.Rectangle(0, 0, ASize.cx, ASize.cy);
    ADest.FillRect(0, 0, ASize.cx, ASize.cy);
    ADest.Brush.Color := GetAColor(lColor, 93);
    ADest.Pen.Color := GetAColor(lColor, 76);
    ADest.RoundRect(0, 0, ASize.cx, ASize.cy, 8, 8);
  end
  else
  begin
    if csfHasFocus in AState then
      lColor := RGBToColor($FB, $FB, $FB)
    else
      lColor := AStateEx.RGBColor;

    ADest.Brush.Color := lColor;
    ADest.Brush.Style := bsSolid;
    ADest.FillRect(0, 0, ASize.cx, ASize.cy);
    ADest.Pen.Color := lColor;
    ADest.RecTangle(0, 0, ASize.cx, ASize.cy);
    ADest.Pen.Color := GetAColor(lColor, 86);
    ADest.RoundRect(0, 0, ASize.cx, ASize.cy, 8, 8);
    //    Pen.Color := aColor;
    //    RecTangle(0, 6, Width, Height);
    ADest.Pen.Color := GetAColor(lColor, 86);
    ADest.Line(0, 3, 0, ASize.cy - 3);
    ADest.Line(ASize.cx, 3, ASize.cx, ASize.cy - 3);
    ADest.Line(3, ASize.cy - 1, ASize.cx - 3, ASize.cy - 1);
    ADest.Line(2, ASize.cy - 2, ASize.cx - 2, ASize.cy - 2);
    ADest.Pen.Color := GetAColor(lColor, 93);
    ADest.Line(1, ASize.cy - 4, ASize.cx - 1, ASize.cy - 4);
    ADest.Pen.Color := GetAColor(lColor, 91);
    ADest.Line(1, ASize.cy - 3, ASize.cx - 1, ASize.cy - 3);
    ADest.Pen.Color := GetAColor(lColor, 88);
    ADest.Line(ASize.cx - 2, 4, ASize.cx - 2, ASize.cy - 3);
    //Pen.Color := GetAColor(aColor, 94);
    //Line(2, 2, 6, 2);
  end;

  // Button text
  ADest.Font.Assign(AStateEx.Font);
  ADest.Brush.Style := bsClear;
  ADest.Pen.Style := psSolid;
  Str := AStateEx.Caption;
  ADest.TextOut((ASize.cx - ADest.TextWidth(Str)) div 2,
    (ASize.cy - ADest.TextHeight(Str)) div 2, Str);
end;

initialization
  RegisterDrawer(TCDDrawerWinXP.Create, dsWinXP);
end.

