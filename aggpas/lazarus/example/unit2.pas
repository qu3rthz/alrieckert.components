unit Unit2;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LCLProc, FileUtil, LResources, Forms, Controls, Graphics,
  Dialogs, FPimage, agg_fpimage, Agg_LCL;

type

  { TForm1 }

  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
  private
  public
    AggLCLCanvas: TAggLCLCanvas;
    Bitmap1: TBitmap;
  end;

var
  Form1: TForm1; 

implementation

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
var
  HasFont: Boolean;
  FontFilename: String;
  s: String;
  TxtW: integer;
  TxtH: integer;
  TxtX: Integer;
  TxtY: Integer;
begin
  Bitmap1:=TBitmap.Create;
  AggLCLCanvas:=TAggLCLCanvas.Create;
  with AggLCLCanvas do begin
    Image.PixelFormat:=afpimRGBA32;
    Image.SetSize(250,250);
  end;
  {$IFDEF LCLGtk2}
  HasFont:=true;
  {$ELSE}
  HasFont:=false;
  {$ENDIF}

  // paint to agg canvas
  with AggLCLCanvas do begin
    if HasFont then begin
      FontFilename:=SetDirSeparators('../../verdana.ttf');
      if not FileExists(FontFilename) then raise Exception.Create('file not found: '+FontFilename+' CurDir='+GetCurrentDirUTF8);
      Font.LoadFromFile(FontFilename);
      Font.Size:=10;
      Font.Color:=clBlack;
    end;

    // solid white background
    Brush.Color:=clWhite;
    FillRect(0,0,Width,Height);

    Brush.Color:=clRed;
    Pen.Color:=clBlue;
    Pen.Width:=1;

    Line(12,10,22,10);
    Line(10,12,10,22);
    Line(12,12,22,22);

    FillRect(40,10,50,20);
    Ellipse(55,10,65,20);
    //GradientFill(Rect(70,10,80,20),clRed,clBlue,gdVertical);
    Frame(85,10,95,20);
    Arc(100,10,110,20,0,2700);
    Arc(115,10,125,20,1000,2700);

    s:='Font.Size='+IntToStr(Font.Size);
    GetTextSize(s,TxtW,TxtH);
    TxtX:=10;
    TxtY:=40;
    FillRect(TxtX,TxtY,TxtX+TxtW,TxtY+TxtH);
    TextOut(TxtX,TxtY,s);
  end;

  // convert to LCL native pixel format
  Bitmap1.LoadFromIntfImage(AggLCLCanvas.Image.IntfImg);

  // paint with widgetset to bitmap
  with Bitmap1.Canvas do begin
    Font.Size:=10;
    Font.Color:=clBlack;

    Brush.Color:=clRed;
    Pen.Color:=clBlue;
    Pen.Width:=1;

    Line(24,10,34,10);
    Line(10,24,10,34);
    Line(24,24,34,34);

    FillRect(40,22,50,32);
    Ellipse(55,22,65,32);
    GradientFill(Rect(70,22,80,32),clRed,clBlue,gdVertical);
    Frame(85,22,95,32);
    Arc(100,22,110,32,0,2700);
    Arc(115,22,125,32,1000,2700);

    s:='Font.Size='+IntToStr(Font.Size);
    GetTextSize(s,TxtW,TxtH);
    TxtX:=10;
    TxtY:=60;
    FillRect(TxtX,TxtY,TxtX+TxtW,TxtY+TxtH);
    TextOut(TxtX,TxtY,s);
  end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  AggLCLCanvas.Free;
  Bitmap1.Free;
end;

procedure TForm1.FormPaint(Sender: TObject);
begin
  Canvas.Draw(0,0,Bitmap1);
end;

initialization
  {$I unit2.lrs}

end.

