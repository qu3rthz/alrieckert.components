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

  Author: Mattias Gaertner

  Abstract:
    An IDE dialog to paste a gdb backtrace from clipboard and find the
    corresponding lines.
}
unit CodyFindGDBLine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LazLoggerBase, LazLogger, SynEdit,
  IDEDialogs, SrcEditorIntf, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, ButtonPanel, CodyStrConsts, CodeCache, CodeToolManager, CodeTree;

type

  { TCodyFindGDBLineDialog }

  TCodyFindGDBLineDialog = class(TForm)
    BacktraceMemo: TMemo;
    ButtonPanel1: TButtonPanel;
    FoundLabel: TLabel;
    GDBBacktraceLabel: TLabel;
    procedure BacktraceMemoChange(Sender: TObject);
    procedure BacktraceMemoKeyDown(Sender: TObject; var {%H-}Key: Word;
      {%H-}Shift: TShiftState);
    procedure BacktraceMemoKeyPress(Sender: TObject; var {%H-}Key: char);
    procedure BacktraceMemoMouseDown(Sender: TObject; {%H-}Button: TMouseButton;
      Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure BacktraceMemoMouseUp(Sender: TObject; {%H-}Button: TMouseButton;
      {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure ButtonPanel1OKButtonClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var {%H-}CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure OnIdle(Sender: TObject; var {%H-}Done: Boolean);
  private
    FErrorMsg: string;
    FIdleConnected: boolean;
    fLastBacktrace: string;
    fLastBacktraceSelStart: integer;
    fLastBacktraceCaret: TPoint;
    FSrcFilename: string;
    FSrcXY: TPoint;
    procedure SetIdleConnected(AValue: boolean);
    procedure Search(Immediately: boolean);
    procedure Jump;
    procedure ParseGDBBacktraceLine(Line: string; out Identifier, TheErrorMsg: string);
    procedure FindGDBIdentifier(GDBIdentifier: string; out TheErrorMsg: string);
    procedure FindUnit(TheUnitName: string; out aFilename: string);
  public
    property IdleConnected: boolean read FIdleConnected write SetIdleConnected;
    property ErrorMsg: string read FErrorMsg;
    property SrcFilename: string read FSrcFilename;
    property SrcXY: TPoint read FSrcXY;
  end;

procedure ShowFindGDBLineDialog(Sender: TObject);

implementation

procedure ShowFindGDBLineDialog(Sender: TObject);
var
  CodyFindGDBLineDialog: TCodyFindGDBLineDialog;
begin
  CodyFindGDBLineDialog:=TCodyFindGDBLineDialog.Create(nil);
  try
    CodyFindGDBLineDialog.ShowModal;
  finally
    CodyFindGDBLineDialog.Free;
  end;
end;

{$R *.lfm}

{ TCodyFindGDBLineDialog }

procedure TCodyFindGDBLineDialog.FormCreate(Sender: TObject);
begin
  Caption:=crsFindSourceOfGDBBacktrace;
  GDBBacktraceLabel.Caption:=crsPasteLinesOfAGdbBacktrace;
  ButtonPanel1.OKButton.Caption:=crsJump;
  ButtonPanel1.OKButton.OnClick:=@ButtonPanel1OKButtonClick;
  BacktraceMemo.Clear;
  Search(false);
end;

procedure TCodyFindGDBLineDialog.OnIdle(Sender: TObject; var Done: Boolean);
begin
  IdleConnected:=false;
  Search(true);
end;

procedure TCodyFindGDBLineDialog.SetIdleConnected(AValue: boolean);
begin
  if csDestroying in ComponentState then
    AValue:=false;
  if FIdleConnected=AValue then Exit;
  FIdleConnected:=AValue;
  if IdleConnected then
    Application.AddOnIdleHandler(@OnIdle)
  else
    Application.RemoveOnIdleHandler(@OnIdle);
end;

procedure TCodyFindGDBLineDialog.Search(Immediately: boolean);
var
  y: LongInt;
  s: String;
  Line: String;
  GDBIdentifier: string;
  Code: TCodeBuffer;
  SelStart: Integer;
begin
  if not Immediately then begin
    // update on idle
    IdleConnected:=true;
    exit;
  end;

  // check if something changed
  s:=BacktraceMemo.Lines.Text;
  SelStart:=BacktraceMemo.SelStart;
  if (s=fLastBacktrace)
  and (fLastBacktraceSelStart=BacktraceMemo.SelStart) then
    exit;
  fLastBacktrace:=s;
  fLastBacktraceSelStart:=SelStart;
  Code:=TCodeBuffer.Create;
  try
    Code.Source:=s;
    Code.AbsoluteToLineCol(SelStart+1,fLastBacktraceCaret.Y,fLastBacktraceCaret.X);
    FErrorMsg:='No backtrace.';
    FSrcFilename:='';
    FSrcXY:=Point(0,0);

    // get current line
    y:=fLastBacktraceCaret.Y;
    if (y>0) and (y<=Code.LineCount) then begin
      Line:=Code.GetLine(y-1);
      //debugln(['TCodyFindGDBLineDialog.Search Line="',Line,'"']);
      ParseGDBBacktraceLine(Line,GDBIdentifier,fErrorMsg);
      if FErrorMsg='' then begin
        // find gdb identifier
        FindGDBIdentifier(GDBIdentifier,FErrorMsg);
      end;
    end else begin
      // caret outside
      FErrorMsg:='Please move caret to a line with a backtrace.';
    end;
  finally
    Code.Free;
  end;

  // show found source position
  if ErrorMsg<>'' then
    s:='Error: '+ErrorMsg
  else begin
    s:='';
    if FSrcFilename<>'' then begin
      s:=FSrcFilename;
      if (FSrcXY.Y>0) then
        s+=' ('+dbgs(FSrcXY.Y)+','+dbgs(FSrcXY.X)+')';
    end else begin
      s:='not found';
    end;
  end;
  FoundLabel.Caption:=s;
end;

procedure TCodyFindGDBLineDialog.Jump;
begin
  Search(true);
  if ErrorMsg<>'' then begin
    IDEMessageDialog('Error',ErrorMsg,mtError,[mbCancel]);
    exit;
  end;
  ModalResult:=mrOk;
end;

procedure TCodyFindGDBLineDialog.ParseGDBBacktraceLine(Line: string; out
  Identifier, TheErrorMsg: string);
{ For example:
  #0  0x00020e16 in fpc_raiseexception ()
  #1  0x0004cb37 in SYSUTILS_RUNERRORTOEXCEPT$LONGINT$POINTER$POINTER ()
  #2  0x00024e48 in SYSTEM_HANDLEERRORADDRFRAME$LONGINT$POINTER$POINTER ()
  #3  0xbffff548 in ?? ()
  #4  0x007489de in EXTTOOLEDITDLG_TEXTERNALTOOLMENUITEMS_$__LOAD$TCONFIGSTORAGE$$TMODALRESULT ()
  #5  0x00748c44 in EXTTOOLEDITDLG_TEXTERNALTOOLMENUITEMS_$__LOAD$TCONFIGSTORAGE$ANSISTRING$$TMODALRESULT ()
  #6  0x007169a8 in ENVIRONMENTOPTS_TENVIRONMENTOPTIONS_$__LOAD$BOOLEAN ()
  #7  0x0007e620 in MAIN_TMAINIDE_$__LOADGLOBALOPTIONS ()
  #8  0x0007feb1 in MAIN_TMAINIDE_$__CREATE$TCOMPONENT$$TMAINIDE ()
  #9  0x00011124 in PASCALMAIN ()
  #10 0x0002f416 in SYSTEM_FPC_SYSTEMMAIN$LONGINT$PPCHAR$PPCHAR ()
  #11 0x00010eaa in _start ()
  #12 0x00010dd8 in start ()
}
var
  p: PChar;
  StartP: PChar;

  procedure ExpectedChar(Expected: string);
  begin
    TheErrorMsg:='Expected '+Expected+' but found '+DbgStr(p^)
      +' at column '+{%H-}IntToStr(PtrUInt(p-PChar(Line))+1);
  end;

  function CheckChar(c: char; Expected: string): boolean;
  begin
    if p^=c then begin
      inc(p);
      Result:=true;
    end else begin
      ExpectedChar(Expected);
      Result:=false;
    end;
  end;

  function CheckWhiteSpace: boolean;
  begin
    if not CheckChar(' ','space') then exit(false);
    while p^=' ' do inc(p);
    Result:=true;
  end;

begin
  //debugln(['TCodyFindGDBLineDialog.ParseGDBBacktraceLine Line="',Line,'"']);
  Identifier:='';
  if Line='' then begin
    TheErrorMsg:='Not a gdb backtrace';
    exit;
  end;
  p:=PChar(Line);

  // read stackframe (#12)
  // read #
  if not CheckChar('#','# (stackframe)') then exit;
  // read number
  if not (p^ in ['0'..'9']) then begin
    ExpectedChar('number');
    exit;
  end;
  while p^ in ['0'..'9'] do inc(p);
  // skip space
  if not CheckWhiteSpace then exit;

  // read address (hex number 0x007489de)
  if not (p^ in ['0'..'9']) then begin
    ExpectedChar('address as hex number');
    exit;
  end;
  inc(p);
  if not CheckChar('x','x (hex number)') then exit;
  while p^ in ['0'..'9','a'..'f','A'..'F'] do inc(p);
  // skip space
  if not CheckWhiteSpace then exit;

  // read 'in'
  if not CheckChar('i','in') then exit;
  if not CheckChar('n','n') then exit;
  // skip space
  if not CheckWhiteSpace then exit;

  // read identifier
  if not (p^ in ['a'..'z','A'..'Z','_','?']) then begin
    ExpectedChar('identifier');
    exit;
  end;
  StartP:=p;
  while p^ in ['a'..'z','A'..'Z','_','$','?'] do inc(p);
  Identifier:=copy(Line,StartP-PChar(Line)+1,p-StartP);
  debugln(['TCodyFindGDBLineDialog.ParseGDBBacktraceLine Identifier="',Identifier,'"']);

  // success
  TheErrorMsg:='';
end;

procedure TCodyFindGDBLineDialog.FindGDBIdentifier(GDBIdentifier: string; out
  TheErrorMsg: string);
{ Examples:
  fpc_raiseexception
  SYSUTILS_RUNERRORTOEXCEPT$LONGINT$POINTER$POINTER
  SYSTEM_HANDLEERRORADDRFRAME$LONGINT$POINTER$POINTER
  ??
  EXTTOOLEDITDLG_TEXTERNALTOOLMENUITEMS_$__LOAD$TCONFIGSTORAGE$$TMODALRESULT
  EXTTOOLEDITDLG_TEXTERNALTOOLMENUITEMS_$__LOAD$TCONFIGSTORAGE$ANSISTRING$$TMODALRESULT
  ENVIRONMENTOPTS_TENVIRONMENTOPTIONS_$__LOAD$BOOLEAN
  MAIN_TMAINIDE_$__LOADGLOBALOPTIONS
  MAIN_TMAINIDE_$__CREATE$TCOMPONENT$$TMAINIDE
  PASCALMAIN
  SYSTEM_FPC_SYSTEMMAIN$LONGINT$PPCHAR$PPCHAR
}
var
  p: PChar;
  TheUnitName: string;
  Code: TCodeBuffer;
  CurIdentifier: string;
  Tool: TCodeTool;
  Node: TCodeTreeNode;
  CodeXY: TCodeXYPosition;

  procedure ReadIdentifier(out Identifier: string);
  var
    StartP: PChar;
  begin
    StartP:=p;
    while p^ in ['A'..'Z'] do inc(p);
    Identifier:=copy(GDBIdentifier,StartP-PChar(GDBIdentifier)+1,p-StartP);
  end;

begin
  if GDBIdentifier='' then begin
    TheErrorMsg:='missing identifier';
    exit;
  end;
  p:=PChar(GDBIdentifier);
  if p^ in ['a'..'z'] then begin
    // lower case unit name means compiler built in function
    TheErrorMsg:='compiler built in function "'+GDBIdentifier+'"';
    exit;
  end;
  if p^ in ['A'..'Z'] then begin
    ReadIdentifier(TheUnitName);
    debugln(['TCodyFindGDBLineDialog.FindGDBIdentifier first identifier=',TheUnitName]);
    if p^<>'_' then begin
      // only one uppercase identifier, e.g. PASCALMAIN
      TheErrorMsg:='compiler built in function "'+GDBIdentifier+'"';
      exit;
    end;
    // a unit name
    // => search
    FindUnit(TheUnitName,FSrcFilename);
    if (SrcFilename='') then begin
      TheErrorMsg:='can''t find unit '+TheUnitName;
      exit;
    end;
    // load unit source
    Code:=CodeToolBoss.LoadFile(SrcFilename,true,false);
    if Code=nil then begin
      TheErrorMsg:='unable to read file "'+SrcFilename+'"';
      exit;
    end;

    inc(p);
    if p^ in ['A'..'Z'] then begin
      ReadIdentifier(CurIdentifier);
      debugln(['TCodyFindGDBLineDialog.FindGDBIdentifier Identifier="',CurIdentifier,'"']);
      if not CodeToolBoss.Explore(Code,Tool,false,true) then begin
        // syntax error in source => use only SrcFilename
        debugln(['TCodyFindGDBLineDialog.FindGDBIdentifier identifier "',CurIdentifier,'" not found in "',Code.Filename,'" due to syntax error']);
        exit;
      end;

      Node:=Tool.FindDeclarationNodeInInterface(CurIdentifier,true);
      if Node=nil then begin
        // identifier not found => use only SrcFilename
        debugln(['TCodyFindGDBLineDialog.FindGDBIdentifier identifier "',CurIdentifier,'" not found in "',Code.Filename,'"']);
        exit;
      end;
      // identifier found
      Tool.CleanPosToCaret(Node.StartPos,CodeXY);
      fSrcFilename:=CodeXY.Code.Filename;
      FSrcXY.Y:=CodeXY.Y;
      FSrcXY.X:=CodeXY.X;

      if (p^='_') and (p[1]='$') and (p[2]='_') and (p[3]='_') then begin
        inc(p,4);
        if p^ in ['A'..'Z'] then begin
          ReadIdentifier(CurIdentifier);
          debugln(['TCodyFindGDBLineDialog.FindGDBIdentifier SubIdentifier="',CurIdentifier,'"']);
          // find sub identifier

        end;
      end;
    end;
    // unknown operator => use only SrcFilename
    debugln(['TCodyFindGDBLineDialog.FindGDBIdentifier unknown operator ',dbgstr(p^)]);
    exit;
  end else begin
    // example: ??
  end;

  TheErrorMsg:='unkown identifier "'+GDBIdentifier+'"';
end;

procedure TCodyFindGDBLineDialog.FindUnit(TheUnitName: string; out
  aFilename: string);
var
  i: Integer;
  SrcEdit: TSourceEditorInterface;
  InFilename: string;
begin
  // search in project and all its packages
  InFilename:='';
  aFilename:=CodeToolBoss.DirectoryCachePool.FindUnitSourceInCompletePath(
                             '',TheUnitName,InFilename,true);
  if aFilename<>'' then
    exit;
  // search in source editor
  for i:=0 to SourceEditorManagerIntf.SourceEditorCount-1 do begin
    SrcEdit:=SourceEditorManagerIntf.SourceEditors[i];
    aFilename:=SrcEdit.FileName;
    if not FilenameIsPascalUnit(aFileName) then continue;
    if CompareText(ExtractFileNameOnly(aFileName),TheUnitName)<>0 then
      continue;
    exit;
  end;
  // not found
  aFilename:='';
end;

procedure TCodyFindGDBLineDialog.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  IdleConnected:=false;
end;

procedure TCodyFindGDBLineDialog.BacktraceMemoChange(Sender: TObject);
begin
  Search(false);
end;

procedure TCodyFindGDBLineDialog.BacktraceMemoKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  Search(False);
end;

procedure TCodyFindGDBLineDialog.BacktraceMemoKeyPress(Sender: TObject;
  var Key: char);
begin
  Search(false);
end;

procedure TCodyFindGDBLineDialog.BacktraceMemoMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if ssDouble in Shift then
    Jump;
end;

procedure TCodyFindGDBLineDialog.BacktraceMemoMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  Search(false);
end;

procedure TCodyFindGDBLineDialog.ButtonPanel1OKButtonClick(Sender: TObject);
begin
  Jump;
end;

end.

