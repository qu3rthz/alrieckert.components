{ Mouse Command Configuration for SynEdit

  Copyright (C) 2009 Martn Friebe

  The contents of this file are subject to the Mozilla Public License
  Version 1.1 (the "License"); you may not use this file except in compliance
  with the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL/

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
  the specific language governing rights and limitations under the License.

  Alternatively, the contents of this file may be used under the terms of the
  GNU General Public License Version 2 or later (the "GPL"), in which case
  the provisions of the GPL are applicable instead of those above.
  If you wish to allow use of your version of this file only under the terms
  of the GPL and not to allow others to use your version of this file
  under the MPL, indicate your decision by deleting the provisions above and
  replace them with the notice and other provisions required by the GPL.
  If you do not delete the provisions above, a recipient may use your version
  of this file under either the MPL or the GPL.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.

}

unit SynEditMouseCmds;

{$I synedit.inc}

interface

uses
  Classes, Controls, SysUtils, SynEditStrConst;

const
  // EditorMouseCommands

  emcNone                     =  0;
  emcStartSelections          =  1;    // Start BlockSelection (Default Left Mouse Btn)
  emcContinueSelections       =  2;    // Continue BlockSelection (Default Shift - Left Mouse Btn)
  emcStartColumnSelections    =  3;    // Column BlockSelection (Default Alt - Left Mouse Btn)
  emcContinueColumnSelections =  4;    // column BlockSelection (Default Alt-Shift - Left Mouse Btn)

  emcSelectWord               =  6;
  emcSelectLine               =  7;
  emcSelectPara               =  8;

  emcStartDragMove            =  9;
  emcPasteSelection           = 10;
  emcMouseLink                = 11;

  emcContextMenu              = 12;
  emcMax = 12;

type

  TSynEditorMouseCommand = type word;
  TSynMAClickCount = (ccSingle, ccDouble, ccTriple, ccQuad);
  TSynMAClickDir = (cdUp, cdDown);
  ESynMouseCmdError = class(Exception);

  { TSynEditMouseAction }

  TSynEditMouseAction = class(TCollectionItem)
  private
    FClickDir: TSynMAClickDir;
    FShift, FShiftMask: TShiftState;
    FButton: TMouseButton;
    FClickCount: TSynMAClickCount;
    FCommand: TSynEditorMouseCommand;
    FMoveCaret: Boolean;
    procedure SetButton(const AValue: TMouseButton);
    procedure SetClickCount(const AValue: TSynMAClickCount);
    procedure SetClickDir(const AValue: TSynMAClickDir);
    procedure SetCommand(const AValue: TSynEditorMouseCommand);
    procedure SetMoveCaret(const AValue: Boolean);
    procedure SetShift(const AValue: TShiftState);
    procedure SetShiftMask(const AValue: TShiftState);
  protected
    function GetDisplayName: string; override;
  public
    procedure Assign(Source: TPersistent); override;
    function IsMatchingShiftState(AShift: TShiftState): Boolean;
    function IsFallback: Boolean;
    function Conflicts(Other: TSynEditMouseAction): Boolean;
    function Equals(Other: TSynEditMouseAction; IgnoreCmd: Boolean = False): Boolean;
  published
    property Shift: TShiftState read FShift write SetShift;
    property ShiftMask: TShiftState read FShiftMask write SetShiftMask;
    property Button: TMouseButton read FButton write SetButton;
    property ClickCount: TSynMAClickCount read FClickCount write SetClickCount;
    property ClickDir: TSynMAClickDir read FClickDir write SetClickDir;
    property Command: TSynEditorMouseCommand read FCommand write SetCommand;
    property MoveCaret: Boolean read FMoveCaret write SetMoveCaret;
  end;

  { TSynEditMouseActions }

  TSynEditMouseActions = class(TCollection)
  private
    FOwner: TPersistent;
    FAssertLock: Integer;
    function GetItem(Index: Integer): TSynEditMouseAction;
    procedure SetItem(Index: Integer; const AValue: TSynEditMouseAction);
  protected
    function GetOwner: TPersistent; override;
  public
    constructor Create(AOwner: TPersistent);
    function Add: TSynEditMouseAction;
    procedure Assign(Source: TPersistent); override;
    procedure AssertNoConflict(MAction: TSynEditMouseAction);
    function FindCommand(AButton: TMouseButton; AShift: TShiftState;
                         AClickCount: TSynMAClickCount; ADir: TSynMAClickDir
                        ): TSynEditMouseAction;
    procedure ResetDefaults; virtual;
    procedure IncAssertLock;
    procedure DecAssertLock;
    function  IndexOf(MAction: TSynEditMouseAction;
                      IgnoreCmd: Boolean = False): Integer;
    procedure AddCommand(const ACmd: TSynEditorMouseCommand;
             const AMoveCaret: Boolean;
             const AButton: TMouseButton; const AClickCount: TSynMAClickCount;
             const ADir: TSynMAClickDir; const AShift, AShiftMask: TShiftState);
  public
    property Items[Index: Integer]: TSynEditMouseAction read GetItem
      write SetItem; default;
  end;

  { TSynEditSelMouseActions }

  TSynEditMouseSelActions = class(TSynEditMouseActions)
  public
    procedure ResetDefaults; override;
  end;

  function MouseCommandName(emc: TSynEditorMouseCommand): String;

const
  SYNEDIT_LINK_MODIFIER = {$IFDEF LCLcarbon}ssMeta{$ELSE}ssCtrl{$ENDIF};

implementation

function MouseCommandName(emc: TSynEditorMouseCommand): String;
begin
  case emc of
    emcNone:    Result := SYNS_emcNone;
    emcStartSelections:    Result := SYNS_emcStartSelection;
    emcContinueSelections: Result := SYNS_emcContinueSelections;
    emcStartColumnSelections:    Result := SYNS_emcStartColumnSelections;
    emcContinueColumnSelections: Result := SYNS_emcContinueColumnSelections;
    emcSelectWord: Result := SYNS_emcSelectWord;
    emcSelectLine: Result := SYNS_emcSelectLine;
    emcSelectPara: Result := SYNS_emcSelectPara;
    emcStartDragMove:  Result := SYNS_emcStartDragMove;
    emcPasteSelection: Result := SYNS_emcPasteSelection;
    emcMouseLink:   Result := SYNS_emcMouseLink;
    emcContextMenu: Result := SYNS_emcContextMenu;

    else Result := ''
  end;
end;

{ TSynEditMouseAction }

procedure TSynEditMouseAction.SetButton(const AValue: TMouseButton);
begin
  if FButton = AValue then exit;
  FButton := AValue;
  if Collection <> nil then
    TSynEditMouseActions(Collection).AssertNoConflict(self);
end;

procedure TSynEditMouseAction.SetClickCount(const AValue: TSynMAClickCount);
begin
  if FClickCount = AValue then exit;
  FClickCount := AValue;
  if Collection <> nil then
    TSynEditMouseActions(Collection).AssertNoConflict(self);
end;

procedure TSynEditMouseAction.SetClickDir(const AValue: TSynMAClickDir);
begin
  if FClickDir = AValue then exit;
  FClickDir := AValue;
  if Collection <> nil then
    TSynEditMouseActions(Collection).AssertNoConflict(self);
end;

procedure TSynEditMouseAction.SetCommand(const AValue: TSynEditorMouseCommand);
begin
  if FCommand = AValue then exit;
  FCommand := AValue;
  if Collection <> nil then
    TSynEditMouseActions(Collection).AssertNoConflict(self);
end;

procedure TSynEditMouseAction.SetMoveCaret(const AValue: Boolean);
begin
  if FMoveCaret = AValue then exit;
  FMoveCaret := AValue;
  if Collection <> nil then
    TSynEditMouseActions(Collection).AssertNoConflict(self);
end;

procedure TSynEditMouseAction.SetShift(const AValue: TShiftState);
begin
  if FShift = AValue then exit;
  FShift := AValue;
  if Collection <> nil then
    TSynEditMouseActions(Collection).AssertNoConflict(self);
end;

procedure TSynEditMouseAction.SetShiftMask(const AValue: TShiftState);
begin
  if FShiftMask = AValue then exit;
  FShiftMask := AValue;
  if Collection <> nil then
    TSynEditMouseActions(Collection).AssertNoConflict(self);
end;

function TSynEditMouseAction.GetDisplayName: string;
begin
  Result := MouseCommandName(FCommand);
end;

procedure TSynEditMouseAction.Assign(Source: TPersistent);
begin
  if Source is TSynEditMouseAction then
  begin
    FCommand    := TSynEditMouseAction(Source).Command;
    FClickCount := TSynEditMouseAction(Source).ClickCount;
    FClickDir   := TSynEditMouseAction(Source).ClickDir;
    FButton     := TSynEditMouseAction(Source).Button;
    FShift      := TSynEditMouseAction(Source).Shift;
    FShiftMask  := TSynEditMouseAction(Source).ShiftMask;
    FMoveCaret  := TSynEditMouseAction(Source).MoveCaret;
  end else
    inherited Assign(Source);
  if Collection <> nil then
    TSynEditMouseActions(Collection).AssertNoConflict(self);
end;

function TSynEditMouseAction.IsMatchingShiftState(AShift: TShiftState): Boolean;
begin
  Result := AShift * FShiftMask = FShift;
end;

function TSynEditMouseAction.IsFallback: Boolean;
begin
  Result := FShiftMask = [];
end;

function TSynEditMouseAction.Conflicts(Other: TSynEditMouseAction): Boolean;
begin
  If (Other = nil) or (Other = self) then exit(False);
  Result := (Other.Button     = self.Button)
        and (Other.ClickCount = self.ClickCount)
        and (Other.ClickDir   = self.ClickDir)
        and (Other.Shift * self.ShiftMask = self.Shift * Other.ShiftMask)
        and ((Other.Command   <> self.Command) or
             (Other.MoveCaret <> self.MoveCaret)) // Only conflicts, if Command differs
        and not(Other.IsFallback xor self.IsFallback);
end;

function TSynEditMouseAction.Equals(Other: TSynEditMouseAction;
  IgnoreCmd: Boolean = False): Boolean;
begin
  Result := (Other.Button     = self.Button)
        and (Other.ClickCount = self.ClickCount)
        and (Other.ClickDir   = self.ClickDir)
        and (Other.Shift      = self.Shift)
        and (Other.ShiftMask  = self.ShiftMask)
        and ((Other.Command   = self.Command) or IgnoreCmd)
        and ((Other.MoveCaret = self.MoveCaret) or IgnoreCmd);
end;

{ TSynEditMouseActions }

function TSynEditMouseActions.GetItem(Index: Integer): TSynEditMouseAction;
begin
 Result := TSynEditMouseAction(inherited GetItem(Index));
end;

procedure TSynEditMouseActions.SetItem(Index: Integer; const AValue: TSynEditMouseAction);
begin
  inherited SetItem(Index, AValue);
end;

function TSynEditMouseActions.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

constructor TSynEditMouseActions.Create(AOwner: TPersistent);
begin
  inherited Create(TSynEditMouseAction);
  FOwner := AOwner;
  FAssertLock := 0;
end;

function TSynEditMouseActions.Add: TSynEditMouseAction;
begin
  Result := TSynEditMouseAction(inherited Add);
end;

procedure TSynEditMouseActions.Assign(Source: TPersistent);
var
  i: Integer;
begin
  if Source is TSynEditMouseActions then
  begin
    Clear;
    for i := 0 to TSynEditMouseActions(Source).Count-1 do
      Add.Assign(TSynEditMouseActions(Source)[i]);
  end
  else
    inherited Assign(Source);
end;

procedure TSynEditMouseActions.AssertNoConflict(MAction: TSynEditMouseAction);
var
  i: Integer;
begin
  if FAssertLock > 0 then exit;
  for i := 0 to Count-1 do begin
    if Items[i].Conflicts(MAction) then
      raise ESynMouseCmdError.Create(SYNS_EDuplicateShortCut);
  end;
end;

function TSynEditMouseActions.FindCommand(AButton: TMouseButton; AShift: TShiftState;
  AClickCount: TSynMAClickCount; ADir: TSynMAClickDir): TSynEditMouseAction;
var
  i: Integer;
  act, fback: TSynEditMouseAction;
begin
  fback := nil;
  for i := 0 to Count-1 do begin
    act := Items[i];
    if (act.Button = AButton) and (act.ClickCount = AClickCount) and
       (act.ClickDir = ADir)and (act.IsMatchingShiftState(AShift))
    then begin
      if act.IsFallback then
        fback := act
      else
        exit(act);
    end;
  end;
  if fback <> nil then
    exit(fback);
  Result := nil;
end;

procedure TSynEditMouseActions.AddCommand(const ACmd: TSynEditorMouseCommand;
  const AMoveCaret: Boolean; const AButton: TMouseButton;
  const AClickCount: TSynMAClickCount; const ADir: TSynMAClickDir;
  const AShift, AShiftMask: TShiftState);
var
  new: TSynEditMouseAction;
begin
  new := Add;
  try
    inc(FAssertLock);
    with new do begin
      Command := ACmd;
      MoveCaret := AMoveCaret;
      Button := AButton;
      ClickCount := AClickCount;
      ClickDir := ADir;
      Shift := AShift;
      ShiftMask := AShiftMask;
    end;
  finally
    dec(FAssertLock);
  end;
  try
    AssertNoConflict(new);
  except
    Delete(Count-1);
    raise;
  end;
end;

procedure TSynEditMouseActions.ResetDefaults;
begin
  Clear;
  AddCommand(emcStartSelections, True,    mbLeft, ccSingle, cdDown, [],        [ssShift, ssAlt]);
  AddCommand(emcContinueSelections, True, mbLeft, ccSingle, cdDown, [ssShift], [ssShift, ssAlt]);
  AddCommand(emcStartColumnSelections, True,    mbLeft, ccSingle, cdDown, [ssAlt],          [ssShift, ssAlt]);
  AddCommand(emcContinueColumnSelections, True, mbLeft, ccSingle, cdDown, [ssShift, ssAlt], [ssShift, ssAlt]);
  AddCommand(emcContextMenu, False, mbRight, ccSingle, cdUp, [], []);

  AddCommand(emcSelectWord, True, mbLeft, ccDouble, cdDown, [], []);
  AddCommand(emcSelectLine, True, mbLeft, ccTriple, cdDown, [], []);
  AddCommand(emcSelectPara, True, mbLeft, ccQuad, cdDown, [], []);

  AddCommand(emcPasteSelection, True, mbMiddle, ccSingle, cdDown, [], []);

  AddCommand(emcMouseLink, False, mbLeft, ccSingle, cdUp, [SYNEDIT_LINK_MODIFIER], [ssShift, ssAlt, ssCtrl]);
end;

procedure TSynEditMouseActions.IncAssertLock;
begin
  inc(FAssertLock);
end;

procedure TSynEditMouseActions.DecAssertLock;
begin
  dec(FAssertLock);
end;

function TSynEditMouseActions.IndexOf(MAction: TSynEditMouseAction;
  IgnoreCmd: Boolean = False): Integer;
begin
  Result := Count - 1;
  while Result >= 0 do begin
    if Items[Result].Equals(MAction, IgnoreCmd) then exit;
    Dec(Result);
  end;
end;

{ TSynEditSelMouseActions }

procedure TSynEditMouseSelActions.ResetDefaults;
begin
  Clear;
  AddCommand(emcStartDragMove, False, mbLeft, ccSingle, cdDown, [], []);
end;

end.

