{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.        *
 *                                                                         *
 ***************************************************************************

}
unit ExampleForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, GTKGlArea, Forms, LResources, Buttons, StdCtrls,
  gtkglarea_int, gtk, glib, NVGL;

type
  TglTexture = class
    Width,Height: longint;
    Data        : pointer;
  end;
  
type
  TExampleForm = class(TForm)
    GTKGLAreaControl1: TGTKGLAreaControl;
    ExitButton1: TButton;
    LightingButton1: TButton;
    BlendButton1: TButton;
    MoveCubeButton1: TButton;
    MoveBackgroundButton1: TButton;
    RotateZButton1: TButton;
    RotateZButton2: TButton;
    HintLabel1: TLabel;
    procedure IdleFunc(Sender: TObject; var Done: Boolean);
    procedure FormResize(Sender: TObject);
    procedure ExitButton1Click(Sender: TObject);
    procedure LightingButton1Click(Sender: TObject);
    procedure BlendButton1Click(Sender: TObject);
    procedure MoveCubeButton1Click(Sender: TObject);
    procedure MoveBackgroundButton1Click(Sender: TObject);
    procedure RotateZButton1Click(Sender: TObject);
    procedure RotateZButton2Click(Sender: TObject);
    procedure GTKGLAreaControl1Paint(Sender: TObject);
    procedure GTKGLAreaControl1Resize(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  private
    AreaInitialized: boolean;
  end;

  TParticle = class
    x, y, z: GLfloat;
    vx, vy, vz: GLfloat;
    life: single;
  end;

  TParticleEngine = class
    //x, y, z: GLfloat;
    xspawn: GLfloat;
    Particle: array [1..501] of TParticle;
    procedure MoveParticles;
    procedure DrawParticles;
    //procedure Init;
    procedure Start;
    //procedure Stop;
  public
    constructor Create;
  private
    procedure RespawnParticle(i: integer);
  end;
  
var AnExampleForm: TExampleForm;
    front, left1: GLuint;
    rx, ry, rz, rrx, rry, rrz: single;
    LightAmbient : array [0..3] of GLfloat;
    checked, blended, lighted, ParticleBlended, MoveCube, MoveBackground: boolean;
    textures       : array [0..2] of GLuint;    // Storage For 3 Textures
    MyglTextures   : array [0..2] of TglTexture;
    lightamb, lightdif, lightpos, light2pos, light2dif, 
    light3pos, light3dif, light4pos, light4dif, fogcolor: array [0..3] of GLfloat;
    ParticleEngine: TParticleEngine;
    ParticleList, CubeList, BackList: GLuint;

var direction: boolean;


implementation


function LoadFileToMemStream(Filename: string): TMemoryStream;
var FileStream: TFileStream;
begin
  Result:=TMemoryStream.Create;
  try
    FileStream:=TFileStream.Create(Filename, fmOpenRead);
    try
      Result.CopyFrom(FileStream,FileStream.Size);
      Result.Position:=0;
    finally
      FileStream.Free;
    end;
  except
    Result.Free;
    Result:=nil;
  end;  
end;

function LoadglTexImage2DFromBitmapFile(Filename:string; 
  var Image:TglTexture): boolean;
type
  TBITMAPFILEHEADER = packed record
    bfType: Word;
    bfSize: DWORD;
    bfReserved1: Word;
    bfReserved2: Word;
    bfOffBits: DWORD;
  end;

  BITMAPINFOHEADER = packed record
          biSize : DWORD;
          biWidth : Longint;
          biHeight : Longint;
          biPlanes : WORD;
          biBitCount : WORD;
          biCompression : DWORD;
          biSizeImage : DWORD;
          biXPelsPerMeter : Longint;
          biYPelsPerMeter : Longint;
          biClrUsed : DWORD;
          biClrImportant : DWORD;
       end;

  RGBQUAD = packed record
          rgbBlue : BYTE;
          rgbGreen : BYTE;
          rgbRed : BYTE;
       //   rgbReserved : BYTE;
       end;

  BITMAPINFO = packed record
          bmiHeader : BITMAPINFOHEADER;
          bmiColors : array[0..0] of RGBQUAD;
       end;

  PBITMAPINFO = ^BITMAPINFO;

  TBitsObj = array[1..1] of byte;
  PBitsObj = ^TBitsObj;

  TRawImage = packed record
     p:array[0..0] of byte;
   end;
  PRawImage = ^TRawImage;

const
  BI_RGB = 0;

var
  MemStream: TMemoryStream;
  BmpHead: TBitmapFileHeader;
  BmpInfo:PBitmapInfo;
  ImgSize:longint;
  InfoSize, PixelCount, i:integer;
  BitsPerPixel:integer;
  AnRGBQuad: RGBQUAD;
begin
  Result:=false;
  MemStream:=LoadFileToMemStream(Filename);
  if MemStream=nil then begin
    writeln('Unable to load "',Filename,'"');
    exit;
  end;
  try
    if (MemStream.Read(BmpHead, sizeof(BmpHead))<sizeof(BmpHead))
    or (BmpHead.bfType <> $4D42) then begin
      writeln('Invalid windows bitmap (header)');
      exit;
    end;
    InfoSize:=BmpHead.bfOffBits-SizeOf(BmpHead);
    GetMem(BmpInfo,InfoSize);
    try
      if MemStream.Read(BmpInfo^,InfoSize)<>InfoSize then begin
        writeln('Invalid windows bitmap (info)');
        exit;
      end;
      if BmpInfo^.bmiHeader.biSize<>sizeof(BitmapInfoHeader) then begin
        writeln('OS2 bitmaps are not supported yet');
        exit;
      end;
      if BmpInfo^.bmiHeader.biCompression<>bi_RGB then begin
        writeln('RLE compression is not supported yet');
        exit;
      end;
      BitsPerPixel:=BmpInfo^.bmiHeader.biBitCount;
      if BitsPerPixel<>24 then begin
        writeln('Only truecolor bitmaps supported yet');
        exit;
      end;
      ImgSize:=BmpInfo^.bmiHeader.biSizeImage;
      if MemStream.Size-MemStream.Position<ImgSize then begin
        writeln('Invalid windows bitmap (bits)');
        exit;
      end;
      Image.Width:=BmpInfo^.bmiHeader.biWidth;
      Image.Height:=BmpInfo^.bmiHeader.biHeight;
      PixelCount:=Image.Width*Image.Height;
      GetMem(Image.Data,PixelCount * 3);
      try
        for i:=0 to PixelCount-1 do begin
          MemStream.Read(AnRGBQuad,sizeOf(RGBQuad));
          {$IFOPT R+}{$DEFINE RangeCheckOn}{$ENDIF}
          {$R-}
          with PRawImage(Image.Data)^ do begin
            p[i*3+0]:=AnRGBQuad.rgbRed;
            p[i*3+1]:=AnRGBQuad.rgbGreen;
            p[i*3+2]:=AnRGBQuad.rgbBlue;
          end;
          {$IFDEF RangeCheckOn}{$R+}{$ELSE}{$R-}{$ENDIF}
        end;
      except
        writeln('Error converting bitmap');
        FreeMem(Image.Data);
        Image.Data:=nil;
        exit;
      end;
    finally
      FreeMem(BmpInfo);
    end;
    Result:=true;
  finally
    MemStream.Free;
  end;
  Result:=true;
end;


constructor TExampleForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  if LazarusResources.Find(ClassName)=nil then begin
    SetBounds((Screen.Width-800) div 2,(Screen.Height-600) div 2,800,600);
    Caption:='LCL Example for the gtkglarea component';
    
    Application.OnIdle:=@IdleFunc;
    OnResize:=@FormResize;
    blended:=false;
    lighted:=false;
    ParticleEngine:=TParticleEngine.Create;
    
    ExitButton1:=TButton.Create(Self);
    with ExitButton1 do begin
      Name:='ExitButton1';
      Parent:=Self;
      SetBounds(320,10,80,25);
      Caption:='Exit';
      OnClick:=@ExitButton1Click;
      Visible:=true;
    end;

    LightingButton1:=TButton.Create(Self);
    with LightingButton1 do begin
      Name:='LightingButton1';
      Parent:=Self;
      SetBounds(220,0,80,25);
      Caption:='Lighting';
      OnClick:=@LightingButton1Click;
      Visible:=true;
    end;

    BlendButton1:=TButton.Create(Self);
    with BlendButton1 do begin
      Name:='BlendButton1';
      Parent:=Self;
      SetBounds(220,0,80,25);
      Caption:='Blending';
      OnClick:=@BlendButton1Click;
      Visible:=true;
    end;

    MoveCubeButton1:=TButton.Create(Self);
    with MoveCubeButton1 do begin
      Name:='MoveCubeButton1';
      Parent:=Self;
      SetBounds(320,10,80,25);
      Caption:='Move Cube';
      Checked:=false;
      OnClick:=@MoveCubeButton1Click;
      Visible:=true;
    end;

    MoveBackgroundButton1:=TButton.Create(Self);
    with MoveBackgroundButton1 do begin
      Name:='MoveBackgroundButton1';
      Parent:=Self;
      SetBounds(320,10,80,25);
      Caption:='Move Back';
      Checked:=false;
      OnClick:=@MoveBackgroundButton1Click;
      Visible:=true;
    end;
    
    RotateZButton1:=TButton.Create(Self);
    with RotateZButton1 do begin
      Name:='RotateZButton1';
      Parent:=Self;
      SetBounds(320,10,80,25);
      Caption:='P. Respawn';
      Checked:=false;
      OnClick:=@RotateZButton1Click;
      Visible:=true;
    end;

    RotateZButton2:=TButton.Create(Self);
    with RotateZButton2 do begin
      Name:='RotateZButton2';
      Parent:=Self;
      SetBounds(320,10,80,25);
      Caption:='P. Blending';
      Checked:=false;
      OnClick:=@RotateZButton2Click;
      Visible:=true;
    end;

    HintLabel1:=TLabel.Create(Self);
    with HintLabel1 do begin
      Name:='HintLabel1';
      Parent:=Self;
      SetBounds(0,0,280,50);
      Caption:='Demo';
      Visible:=true;
    end;
    
    Resize;
    
    AreaInitialized:=false;
    GTKGLAreaControl1:=TGTKGLAreaControl.Create(Self);
    with GTKGLAreaControl1 do begin
      Name:='GTKGLAreaControl1';
      Parent:=Self;
      SetBounds(10,90,380,200);
      OnPaint:=@GTKGLAreaControl1Paint;
      OnResize:=@GTKGLAreaControl1Resize;
      Visible:=true;
    end;
    
  end;
end;

// --------------------------------------------------------------------------
//                              Particle Engine
// --------------------------------------------------------------------------

constructor TParticleEngine.Create;
var i: integer; 
begin
  for i:=1 to 501 do Particle[i]:=TParticle.Create;
  xspawn:=0;
end;

procedure TParticleEngine.DrawParticles;
var i: integer;
begin
  //if blended then glEnable(GL_DEPTH_TEST) else glEnable(GL_BLEND);
  glBindTexture(GL_TEXTURE_2D, textures[0]);
  for i:=1 to 501 do begin
    glTranslatef(Particle[i].x, Particle[i].y, Particle[i].z);
    glCallList(ParticleList);
    {glBegin(GL_TRIANGLE_STRIP);
      glNormal3f( 0.0, 0.0, 1.0);
      glTexCoord2f( 1.0, 1.0);     glVertex3f(Particle[i].x+0.03, Particle[i].y+0.03, Particle[i].z);
      glTexCoord2f( 0.0, 1.0);     glVertex3f(Particle[i].x-0.03, Particle[i].y+0.03, Particle[i].z);
      glTexCoord2f( 1.0, 0.0);     glVertex3f(Particle[i].x+0.03, Particle[i].y-0.03, Particle[i].z);
      glTexCoord2f( 0.0, 0.0);     glVertex3f(Particle[i].x-0.03, Particle[i].y-0.03, Particle[i].z);
    glEnd;}
    glTranslatef(-Particle[i].x, -Particle[i].y, -Particle[i].z);
  end;
  //if blended then glDisable(GL_DEPTH_TEST) else glDisable(GL_BLEND);
end;

procedure TParticleEngine.RespawnParticle(i: integer);
begin
  {if (xspawn>2) and (direction=true) then direction:=false;
  if (xspawn<-2) and (direction=false) then direction:=true;
  if direction then xspawn:=xspawn+0.005 else xspawn:=xspawn-0.005;}
  Particle[i].x:=xspawn;
  Particle[i].y:=-0.5;
  Particle[i].z:=0;
  Particle[i].vx:=-0.005+random(2000)/200000;
  Particle[i].vy:=0.03+random(750)/100000;
  Particle[i].vz:=-0.005+random(2000)/200000;
  Particle[i].life:=random(1250)/1000+1;
end;

procedure TParticleEngine.MoveParticles;
var i: integer;
begin
  for i:=1 to 501 do begin
    if Particle[i].life>0 then begin
      Particle[i].life:=Particle[i].life-0.01;
      Particle[i].x:=Particle[i].x+Particle[i].vx;
      
      Particle[i].vy:=Particle[i].vy-0.00035; // gravity
      Particle[i].y:=Particle[i].y+Particle[i].vy;
      
      Particle[i].z:=Particle[i].z+Particle[i].vz;
    end else begin
      RespawnParticle(i);
    end;
  end;  
end;

procedure TParticleEngine.Start;
var i: integer;
begin
  for i:=1 to 501 do begin
    RespawnParticle(i);
  end;
end;

{procedure TParticleEngine.Stop;
var i: integer;
begin
  for i:=1 to 1000 do begin
    Particle[i].life:=0;
  end;
end;}

// ---------------------------------------------------------------------------
// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ---------------------------------------------------------------------------

procedure TExampleForm.IdleFunc(Sender: TObject; var Done: Boolean);
begin
  GTKGLAreaControl1Paint(Self);
  Done:=false; // tell lcl to handle messages and return immediatly
end;

// --------------------------------------------------------------------------
//                                 Buttons
// --------------------------------------------------------------------------

procedure TExampleForm.LightingButton1Click(Sender: TObject);
begin
  if lighted then glDisable(GL_LIGHTING) else glEnable(GL_LIGHTING);
  lighted:=not lighted;
  GTKGLAreaControl1Paint(Self);
end;

procedure TExampleForm.BlendButton1Click(Sender: TObject);
begin
  blended:=not blended;
  GTKGLAreaControl1Paint(Self);
end;

procedure TExampleForm.MoveCubeButton1Click(Sender: TObject);
begin
  MoveCube:=not MoveCube;
  GTKGLAreaControl1Paint(Self);
end;

procedure TExampleForm.MoveBackgroundButton1Click(Sender: TObject);
begin
  MoveBackground:=not MoveBackground;
  GTKGLAreaControl1Paint(Self);
end;

procedure TExampleForm.RotateZButton1Click(Sender: TObject);
begin
  ParticleEngine.Start;
end;

procedure TExampleForm.RotateZButton2Click(Sender: TObject);
begin
  ParticleBlended:=not ParticleBlended;
  GTKGLAreaControl1Paint(Self);
end;

// ---------------------------------------------------------------------------
// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ---------------------------------------------------------------------------

procedure TExampleForm.FormResize(Sender: TObject);
begin
  //GTKGLAreaControl1.Width:=Width-100;
  //GTKGLAreaControl1.Height:=Height-100;
  if GTKGLAreaControl1<>nil then
    GTKGLAreaControl1.SetBounds(10, 30, Width-120, Height-40);
  ExitButton1.SetBounds(Width-90, 5, 80, 25);
  LightingButton1.SetBounds(Width-90, 180, 80, 25);
  BlendButton1.SetBounds(Width-90, 210, 80, 25);
  MoveCubeButton1.SetBounds(Width-90, 50, 80, 25);
  MoveBackgroundButton1.SetBounds(Width-90, 80, 80, 25);
  RotateZButton1.SetBounds(Width-90, 115, 80, 25);
  RotateZButton2.SetBounds(Width-90, 145, 80, 25);
  HintLabel1.SetBounds(10, 0, 80, 25);
  //writeln('Form: ',ExitButton1.Width);
  //writeln('GTKGLarea: ',GTKGLareaControl1.Height);
end;

procedure TExampleForm.ExitButton1Click(Sender: TObject);
begin
  Close;
end;

procedure TExampleForm.GTKGLAreaControl1Paint(Sender: TObject);

  procedure myInit;
  begin
    {init rotation variables}
    //xrot:=0; yrot:=0; zrot:=0;
    //xrotspeed:=0; yrotspeed:=0; zrotspeed:=0;
    {init lighting variables}
    {ambient color}
    lightamb[0]:=0.5;
    lightamb[1]:=0.5;
    lightamb[2]:=0.5;
    lightamb[3]:=1.0;
    {diffuse color}
    lightdif[0]:=0.8;
    lightdif[1]:=0.0;
    lightdif[2]:=0.0;
    lightdif[3]:=1.0;
    {diffuse position}
    lightpos[0]:=0.0;
    lightpos[1]:=0.0;
    lightpos[2]:=3.0;
    lightpos[3]:=1.0;
    {diffuse 2 color}
    light2dif[0]:=0.0;
    light2dif[1]:=0.8;
    light2dif[2]:=0.0;
    light2dif[3]:=1.0;
    {diffuse 2 position}
    light2pos[0]:=3.0;
    light2pos[1]:=0.0;
    light2pos[2]:=3.0;
    light2pos[3]:=1.0;
    {diffuse 3 color}
    light3dif[0]:=0.0;
    light3dif[1]:=0.0;
    light3dif[2]:=0.8;
    light3dif[3]:=1.0;
    {diffuse 3 position}
    light3pos[0]:=-3.0;
    light3pos[1]:=0.0;
    light3pos[2]:=0.0;
    light3pos[3]:=1.0;
    {fog color}
    
    fogcolor[0]:=0.5;
    fogcolor[1]:=0.5;
    fogcolor[2]:=0.5;
    fogcolor[3]:=1.0;
    
  end;


procedure InitGL;cdecl;
var i: integer;
begin
  {setting lighting conditions}
  glLightfv(GL_LIGHT0,GL_AMBIENT,lightamb);
  glLightfv(GL_LIGHT1,GL_AMBIENT,lightamb);
  glLightfv(GL_LIGHT2,GL_DIFFUSE,lightdif);
  glLightfv(GL_LIGHT2,GL_POSITION,lightpos);
  glLightfv(GL_LIGHT3,GL_DIFFUSE,light2dif);
  glLightfv(GL_LIGHT3,GL_POSITION,light2pos);
  glLightfv(GL_LIGHT4,GL_POSITION,light3pos);
  glLightfv(GL_LIGHT4,GL_DIFFUSE,light3dif);
  glEnable(GL_LIGHT0);
  glEnable(GL_LIGHT1);
  glEnable(GL_LIGHT2);
  glEnable(GL_LIGHT3);
  glEnable(GL_LIGHT4);
  //glEnable(GL_LIGHTING);
  {}
  for i:=0 to 2 do begin
    Textures[i]:=0;
    MyglTextures[i]:=TglTexture.Create;
  end;
  {loading the texture and setting its parameters}
  if not LoadglTexImage2DFromBitmapFile('data/particle.bmp',MyglTextures[0]) then 
    Halt;
  if not LoadglTexImage2DFromBitmapFile('data/texture2.bmp',MyglTextures[1]) then
    Halt;
  if not LoadglTexImage2DFromBitmapFile('data/texture3.bmp',MyglTextures[2]) then
    Halt;
  glGenTextures(3, textures[0]);
  for i:=0 to 2 do begin
    glBindTexture(GL_TEXTURE_2D, Textures[i]);
    glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP);
    glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D,0,3,MyglTextures[i].Width,MyglTextures[i].Height,0
        ,GL_RGB,GL_UNSIGNED_BYTE,MyglTextures[i].Data^);
  end;
  glTexEnvf(GL_TEXTURE_ENV,GL_TEXTURE_ENV_MODE,GL_MODULATE);
  {instead of GL_MODULATE you can try GL_DECAL or GL_BLEND}
  glEnable(GL_TEXTURE_2D);          // enables 2d textures
  glClearColor(0.0,0.0,0.0,1.0);    // sets background color 
  glClearDepth(1.0);
  glDepthFunc(GL_LEQUAL);           // the type of depth test to do
  glEnable(GL_DEPTH_TEST);          // enables depth testing
  glShadeModel(GL_SMOOTH);          // enables smooth color shading
  {blending}
  //glEnable(GL_BLEND);
  glColor4f(1.0,1.0,1.0,0.5);			// Full Brightness, 50% Alpha ( NEW )
  glBlendFunc(GL_SRC_ALPHA, GL_ONE);
  //glDisable(GL_DEPTH_TEST);
  //glLightModelf(GL_LIGHT_MODEL_AMBIENT, 1.0);
  glLightModeli(GL_LIGHT_MODEL_LOCAL_VIEWER, GL_TRUE);
  {fog}
  glFogi(GL_FOG_MODE,GL_LINEAR);	  // Fog Mode
  glFogfv(GL_FOG_COLOR,fogColor);	  // Set Fog Color
  glFogf(GL_FOG_DENSITY,0.2); 	  // How Dense Will The Fog Be
  glHint(GL_FOG_HINT,GL_NICEST);	  // Fog Hint Value
  glFogf(GL_FOG_START,1.0);		  // Fog Start Depth
  glFogf(GL_FOG_END,2.5);			  // Fog End Depth
  //glEnable(GL_FOG);				  // Enables GL_FOG
  {}
  glHint(GL_LINE_SMOOTH_HINT,GL_NICEST);
  glHint(GL_POLYGON_SMOOTH_HINT,GL_NICEST);
  glHint(GL_PERSPECTIVE_CORRECTION_HINT,GL_NICEST);    
  //glEnable(GL_LIGHTING);
  
  // creating display lists
  
  ParticleList:=glGenLists(3);
  glNewList(ParticleList, GL_COMPILE);
    glBegin(GL_TRIANGLE_STRIP);
      glNormal3f( 0.0, 0.0, 1.0);
      glTexCoord2f( 1.0, 1.0);     glVertex3f(+0.025, +0.025, 0);
      glTexCoord2f( 0.0, 1.0);     glVertex3f(-0.025, +0.025, 0);
      glTexCoord2f( 1.0, 0.0);     glVertex3f(+0.025, -0.025, 0);
      glTexCoord2f( 0.0, 0.0);     glVertex3f(-0.025, -0.025, 0);
    glEnd;
  glEndList;
  
  BackList:=ParticleList+1;
  glNewList(BackList, GL_COMPILE);
    glBindTexture(GL_TEXTURE_2D, textures[2]);
    glBegin(GL_QUADS);
      glNormal3f( 0.0, 0.0, 1.0);
      glTexCoord2f( 1.0, 1.0);     glVertex3f( 2.5, 2.5, 2.5);
      glTexCoord2f( 0.0, 1.0);     glVertex3f(-2.5, 2.5, 2.5);
      glTexCoord2f( 0.0, 0.0);     glVertex3f(-2.5,-2.5, 2.5);
      glTexCoord2f( 1.0, 0.0);     glVertex3f( 2.5,-2.5, 2.5);
    
      glNormal3f( 0.0, 0.0,-1.0);
      glTexCoord2f( 0.0, 1.0);     glVertex3f( 2.5, 2.5,-2.5);
      glTexCoord2f( 0.0, 0.0);     glVertex3f( 2.5,-2.5,-2.5);
      glTexCoord2f( 1.0, 0.0);     glVertex3f(-2.5,-2.5,-2.5);
      glTexCoord2f( 1.0, 1.0);     glVertex3f(-2.5, 2.5,-2.5);      
    
       {Left Face}
      glNormal3f(-1.0, 0.0, 0.0);
      glTexCoord2f( 1.0, 1.0);     glVertex3f(-2.5, 2.5, 2.5);
      glTexCoord2f( 0.0, 1.0);     glVertex3f(-2.5, 2.5,-2.5);
      glTexCoord2f( 0.0, 0.0);     glVertex3f(-2.5,-2.5,-2.5);
      glTexCoord2f( 1.0, 0.0);     glVertex3f(-2.5,-2.5, 2.5);
      {Right Face}
      glNormal3f( 1.0, 0.0, 0.0);
      glTexCoord2f( 1.0, 1.0);     glVertex3f( 2.5, 2.5,-2.5);
      glTexCoord2f( 0.0, 1.0);     glVertex3f( 2.5, 2.5, 2.5);
      glTexCoord2f( 0.0, 0.0);     glVertex3f( 2.5,-2.5, 2.5);
      glTexCoord2f( 1.0, 0.0);     glVertex3f( 2.5,-2.5,-2.5);      

            {Top Face}
      glNormal3f( 0.0, 1.0, 0.0);
      glTexCoord2f( 1.0, 1.0);     glVertex3f( 2.5, 2.5,-2.5);
      glTexCoord2f( 0.0, 1.0);     glVertex3f(-2.5, 2.5,-2.5);
      glTexCoord2f( 0.0, 0.0);     glVertex3f(-2.5, 2.5, 2.5);
      glTexCoord2f( 1.0, 0.0);     glVertex3f( 2.5, 2.5, 2.5);
      {Bottom Face}
      glNormal3f( 0.0,-1.0, 0.0);
      glTexCoord2f( 1.0, 1.0);     glVertex3f(-2.5,-2.5,-2.5);
      glTexCoord2f( 0.0, 1.0);     glVertex3f( 2.5,-2.5,-2.5);
      glTexCoord2f( 0.0, 0.0);     glVertex3f( 2.5,-2.5, 2.5);
      glTexCoord2f( 1.0, 0.0);     glVertex3f(-2.5,-2.5, 2.5);
 
    glEnd;
  glEndList;
  
  CubeList:=BackList+1;
  glNewList(CubeList, GL_COMPILE);
    glBindTexture(GL_TEXTURE_2D, textures[1]);
    glBegin(GL_QUADS);
      {Front Face}
      glNormal3f( 0.0, 0.0, 1.0);
      glTexCoord2f( 1.0, 1.0);     glVertex3f( 0.5, 0.5, 0.5);
      glTexCoord2f( 0.0, 1.0);     glVertex3f(-0.5, 0.5, 0.5);
      glTexCoord2f( 0.0, 0.0);     glVertex3f(-0.5,-0.5, 0.5);
      glTexCoord2f( 1.0, 0.0);     glVertex3f( 0.5,-0.5, 0.5);
      
      {Back Face}
      glNormal3f( 0.0, 0.0,-1.0);
      glTexCoord2f( 0.0, 1.0);     glVertex3f( 0.5, 0.5,-0.5);
      glTexCoord2f( 0.0, 0.0);     glVertex3f( 0.5,-0.5,-0.5);
      glTexCoord2f( 1.0, 0.0);     glVertex3f(-0.5,-0.5,-0.5);
      glTexCoord2f( 1.0, 1.0);     glVertex3f(-0.5, 0.5,-0.5);      
    glEnd;
    glBindTexture(GL_TEXTURE_2D, textures[1]);
    glBegin(GL_QUADS);
      {Left Face}
      glNormal3f(-1.0, 0.0, 0.0);
      glTexCoord2f( 1.0, 1.0);     glVertex3f(-0.5, 0.5, 0.5);
      glTexCoord2f( 0.0, 1.0);     glVertex3f(-0.5, 0.5,-0.5);
      glTexCoord2f( 0.0, 0.0);     glVertex3f(-0.5,-0.5,-0.5);
      glTexCoord2f( 1.0, 0.0);     glVertex3f(-0.5,-0.5, 0.5);
      {Right Face}
      glNormal3f( 1.0, 0.0, 0.0);
      glTexCoord2f( 1.0, 1.0);     glVertex3f( 0.5, 0.5,-0.5);
      glTexCoord2f( 0.0, 1.0);     glVertex3f( 0.5, 0.5, 0.5);
      glTexCoord2f( 0.0, 0.0);     glVertex3f( 0.5,-0.5, 0.5);
      glTexCoord2f( 1.0, 0.0);     glVertex3f( 0.5,-0.5,-0.5);      
    glEnd;
    glBindTexture(GL_TEXTURE_2D, textures[2]);
    glBegin(GL_QUADS);
      {Top Face}
      glNormal3f( 0.0, 1.0, 0.0);
      glTexCoord2f( 1.0, 1.0);     glVertex3f( 0.5, 0.5,-0.5);
      glTexCoord2f( 0.0, 1.0);     glVertex3f(-0.5, 0.5,-0.5);
      glTexCoord2f( 0.0, 0.0);     glVertex3f(-0.5, 0.5, 0.5);
      glTexCoord2f( 1.0, 0.0);     glVertex3f( 0.5, 0.5, 0.5);
      {Bottom Face}
      glNormal3f( 0.0,-1.0, 0.0);
      glTexCoord2f( 1.0, 1.0);     glVertex3f(-0.5,-0.5,-0.5);
      glTexCoord2f( 0.0, 1.0);     glVertex3f( 0.5,-0.5,-0.5);
      glTexCoord2f( 0.0, 0.0);     glVertex3f( 0.5,-0.5, 0.5);
      glTexCoord2f( 1.0, 0.0);     glVertex3f(-0.5,-0.5, 0.5);
    glEnd;
  glEndList;
  
end;

begin
  if (gint(True) = gtk_gl_area_make_current(GTKGLAreaControl1.Widget)) then
  begin
    if not AreaInitialized then begin
      myInit;
      InitGL;
      glMatrixMode (GL_PROJECTION);    { prepare for and then } 
      glLoadIdentity ();               { define the projection }
      glFrustum (-1.0, 1.0, -1.0, 1.0, 1.5, 20.0); { transformation } 
      glMatrixMode (GL_MODELVIEW);  { back to modelview matrix }
      glViewport (0, 0, GTKGLAreaControl1.Width, GTKGLAreaControl1.Height);      { define the viewport }
      AreaInitialized:=true;
    end;
    
    ParticleEngine.MoveParticles;
    
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
    glLoadIdentity;             { clear the matrix }
    glTranslatef (0.0, 0.0,-2.5);  // -2.5); { viewing transformation }
    glScalef (1.0, 1.0, 1.0);      { modeling transformation }
    {rotate}

    //yrot:=yrot+yrotspeed;
    //zrot:=zrot+zrotspeed;
    
    glPushMatrix;

    if MoveBackground then begin
      rrx:=rrx-0.6;
      rry:=rry-0.5;
      rrz:=rrz-0.3;
    end;
    
    glRotatef(rrx,1.0,0.0,0.0);
    glRotatef(rry,0.0,1.0,0.0);
    glRotatef(rrz,0.0,0.0,1.0);

    // draw background
    if blended then begin
      glEnable(GL_BLEND);
      glDisable(GL_DEPTH_TEST);
    end;
    glCallList(BackList);    
    
    glPopMatrix;
    
    {glRotatef(-rrz,0.0,0.0,1.0);
    glRotatef(-rry,0.0,1.0,0.0);
    glRotatef(-rrx,1.0,0.0,0.0);}
       
    glPushMatrix;

    if MoveCube then begin
      rx:=rx+0.5;
      ry:=ry+0.25;
      rz:=rz+0.8;
    end;
    
    glRotatef(rx,1.0,0.0,0.0);
    glRotatef(ry,0.0,1.0,0.0);
    glRotatef(rz,0.0,0.0,1.0);
    
    // draw cube
    
    
    glCallList(CubeList);
    if blended then begin
      glDisable(GL_BLEND);
      glEnable(GL_DEPTH_TEST);
    end;
    // draw particles here for dynamic particle system
    
    //ParticleEngine.DrawParticles;
    
    glPopMatrix;
    
    {glRotatef(-rz,0.0,0.0,1.0);
    glRotatef(-ry,0.0,1.0,0.0);
    glRotatef(-rx,1.0,0.0,0.0);}
    
    // draw particles here for static particle system
    if ParticleBlended then glEnable(GL_BLEND);
    ParticleEngine.DrawParticles;
    if ParticleBlended then glDisable(GL_BLEND);    
    //glFlush;
    glFinish;    
    // Swap backbuffer to front
    gtk_gl_area_swap_buffers(PGtkGLArea(GTKGLAreaControl1.Widget));
  end;
end;

procedure TExampleForm.GTKGLAreaControl1Resize(Sender: TObject);
begin
  if (gint(True) = gtk_gl_area_make_current(GTKGLAreaControl1.widget)) then
    {glViewport(0, 0, PGtkWidget(GTKGLAreaControl1.Widget)^.allocation.width,
      PGtkWidget(GTKGLAreaControl1.Widget)^.allocation.height);}
    glViewport (0, 0, GTKGLAreaControl1.Width, GTKGLAreaControl1.Height);  
end;


end.
