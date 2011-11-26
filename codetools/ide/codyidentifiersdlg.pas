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
    Dictionary of identifiers.
    Dialog to view and search the whole list.

  ToDo:
    -quickfix for identifier not found
      -show dialog
      -check if identifier still exists
      -check if unit conflicts with another unit in path
      -buttons: add unit to interface, add unit to implementation
      -button: jump to identifier
      -add dependency to owner
    -clean up old entries
      -When, How?
    -gzip? lot of cpu, may be faster on first load
}
unit CodyIdentifiersDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileProcs, LResources, LCLProc, avl_tree, Forms, Controls,
  Graphics, Dialogs, ButtonPanel, StdCtrls, ExtCtrls, LCLType,
  PackageIntf, LazIDEIntf, SrcEditorIntf, ProjectIntf,
  CodeCache, BasicCodeTools, CustomCodeTool, CodeToolManager, UnitDictionary,
  CodeTree, LinkScanner, DefineTemplates,
  CodyStrConsts, CodyUtils;

const
  PackageNameFPCSrcDir = 'FPCSrcDir';
type
  TCodyUnitDictionary = class;

  { TCodyUDLoadSaveThread }

  TCodyUDLoadSaveThread = class(TThread)
  public
    Load: boolean;
    Dictionary: TCodyUnitDictionary;
    Filename: string;
    Done: boolean;
    procedure Execute; override;
  end;

  { TCodyUnitDictionary }

  TCodyUnitDictionary = class(TUnitDictionary)
  private
    FLoadAfterStartInS: integer;
    FLoadSaveError: string;
    FSaveIntervalInS: integer;
    fTimer: TTimer;
    FIdleConnected: boolean;
    fQueuedTools: TAVLTree; // tree of TCustomCodeTool
    fParsingTool: TCustomCodeTool;
    fLoadSaveThread: TCodyUDLoadSaveThread;
    fCritSec: TRTLCriticalSection;
    fLoaded: boolean; // has loaded the file
    fStartTime: TDateTime;
    fClosing: boolean;
    procedure SetIdleConnected(AValue: boolean);
    procedure SetLoadAfterStartInS(AValue: integer);
    procedure SetLoadSaveError(AValue: string);
    procedure SetSaveIntervalInS(AValue: integer);
    procedure ToolTreeChanged(Tool: TCustomCodeTool; {%H-}NodesDeleting: boolean);
    procedure OnIdle(Sender: TObject; var Done: Boolean);
    procedure WaitForThread;
    procedure OnTimer(Sender: TObject);
    function StartLoadSaveThread: boolean;
    procedure OnIDEClose(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load;
    procedure Save;
    property Loaded: boolean read fLoaded;
    function GetFilename: string;
    property IdleConnected: boolean read FIdleConnected write SetIdleConnected;
    property SaveIntervalInS: integer read FSaveIntervalInS write SetSaveIntervalInS;
    property LoadAfterStartInS: integer read FLoadAfterStartInS write SetLoadAfterStartInS;
    procedure BeginCritSec;
    procedure EndCritSec;
    property LoadSaveError: string read FLoadSaveError write SetLoadSaveError;
  end;

  { TCodyIdentifiersDlg }

  TCodyIdentifiersDlg = class(TForm)
    ButtonPanel1: TButtonPanel;
    FilterEdit: TEdit;
    InfoLabel: TLabel;
    ItemsListBox: TListBox;
    PackageLabel: TLabel;
    UnitLabel: TLabel;
    procedure ButtonPanel1OKButtonClick(Sender: TObject);
    procedure FileLabelClick(Sender: TObject);
    procedure FilterEditChange(Sender: TObject);
    procedure FilterEditExit(Sender: TObject);
    procedure FilterEditKeyDown(Sender: TObject; var Key: Word;
      {%H-}Shift: TShiftState);
    procedure FormClose(Sender: TObject; var {%H-}CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure ItemsListBoxClick(Sender: TObject);
    procedure ItemsListBoxSelectionChange(Sender: TObject; {%H-}User: boolean);
    procedure OnIdle(Sender: TObject; var {%H-}Done: Boolean);
  private
    FLastFilter: string;
    FIdleConnected: boolean;
    FMaxItems: integer;
    FNoFilterText: string;
    FItems: TStringList;
    procedure SetIdleConnected(AValue: boolean);
    procedure SetMaxItems(AValue: integer);
    procedure UpdateGeneralInfo;
    procedure UpdateItemsList;
    procedure UpdateIdentifierInfo;
    function GetFilterEditText: string;
    function FindSelectedItem(out Identifier, UnitFilename,
      GroupFilename: string): boolean;
    procedure GetCurOwnerOfUnit;
    procedure AddToUsesSection;
    procedure UpdateTool;
    function GetFPCSrcDir(const Directory: string): string;
  public
    CurIdentifier: string;
    CurIdentStart: integer;
    CurIdentEnd: integer;
    CurInitError: TCUParseError;
    CurTool: TCodeTool;
    CurCleanPos: integer;
    CurNode: TCodeTreeNode;
    CurCodePos: TCodeXYPosition;
    CurSrcEdit: TSourceEditorInterface;
    CurMainFilename: string; // if CurSrcEdit is an include file, then CurMainFilename<>CurSrcEdit.Filename
    CurMainCode: TCodeBuffer;
    CurOwner: TObject;
    NewIdentifier: string;
    NewUnitFilename: string;
    NewGroupFilename: string;
    function Init: boolean;
    procedure UseIdentifier;
    property IdleConnected: boolean read FIdleConnected write SetIdleConnected;
    property MaxItems: integer read FMaxItems write SetMaxItems;
  end;

var
  CodyUnitDictionary: TCodyUnitDictionary = nil;

procedure ShowUnitDictionaryDialog(Sender: TObject);
procedure InitUnitDictionary;

implementation

{$R *.lfm}

procedure ShowUnitDictionaryDialog(Sender: TObject);
var
  CodyIdentifiersDlg: TCodyIdentifiersDlg;
begin
  CodyIdentifiersDlg:=TCodyIdentifiersDlg.Create(nil);
  try
    if not CodyIdentifiersDlg.Init then exit;
    if CodyIdentifiersDlg.ShowModal=mrOk then
      CodyIdentifiersDlg.UseIdentifier;
  finally
    CodyIdentifiersDlg.Free;
  end;
end;

procedure InitUnitDictionary;
begin
  CodyUnitDictionary:=TCodyUnitDictionary.Create;
end;

{ TCodyUDLoadSaveThread }

procedure TCodyUDLoadSaveThread.Execute;
var
  UncompressedMS: TMemoryStream;
  TempFilename: String;
begin
  Dictionary.LoadSaveError:='';
  FreeOnTerminate:=true;
  try
    if Load then begin
      // load
      //debugln('TCodyUDLoadSaveThread.Execute loading '+Filename+' exists='+dbgs(FileExistsUTF8(Filename)));
      if FileExistsUTF8(Filename) then begin
        UncompressedMS:=TMemoryStream.Create;
        try
          UncompressedMS.LoadFromFile(Filename);
          UncompressedMS.Position:=0;
          Dictionary.BeginCritSec;
          try
            // Note: if loading fails, then the format or read permissions are wrong
            // mark as loaded, so that the next save will create a valid one
            Dictionary.fLoaded:=true;
            Dictionary.LoadFromStream(UncompressedMS,true);
          finally
            Dictionary.EndCritSec;
          end;
        finally
          UncompressedMS.Free;
        end;
      end;
    end else begin
      // save
      //debugln('TCodyUDLoadSaveThread.Execute saving '+Filename);
      UncompressedMS:=TMemoryStream.Create;
      try
        Dictionary.BeginCritSec;
        try
          Dictionary.SaveToStream(UncompressedMS);
        finally
          Dictionary.EndCritSec;
        end;
        UncompressedMS.Position:=0;
        // reduce the risk of file corruption due to crashes while saving:
        // save to a temporary file and then rename
        TempFilename:=FileProcs.GetTempFilename(Filename,'unitdictionary');
        UncompressedMS.SaveToFile(TempFilename);
        if not RenameFileUTF8(TempFilename,Filename) then
          raise Exception.Create('unable to rename "'+TempFilename+'" to "'+Filename+'"');
      finally
        UncompressedMS.Free;
      end;
    end;
  except
    on E: Exception do begin
      debugln('TCodyUDLoadSaveThread.Execute '+E.Message);
      Dictionary.LoadSaveError:=E.Message;
    end;
  end;
  Done:=true;
  Dictionary.BeginCritSec;
  try
    Dictionary.fLoadSaveThread:=nil;
  finally
    Dictionary.EndCritSec;
  end;
  WakeMainThread(nil);
  //debugln('TCodyUDLoadSaveThread.Execute END');
end;

{ TCodyUnitDictionary }

procedure TCodyUnitDictionary.ToolTreeChanged(Tool: TCustomCodeTool;
  NodesDeleting: boolean);
begin
  if fParsingTool=Tool then exit;
  //debugln(['TCodyUnitDictionary.ToolTreeChanged ',Tool.MainFilename]);
  if fQueuedTools.Find(Tool)<>nil then exit;
  fQueuedTools.Add(Tool);
  IdleConnected:=true;
end;

procedure TCodyUnitDictionary.OnIdle(Sender: TObject; var Done: Boolean);
var
  OwnerList: TFPList;
  i: Integer;
  Pkg: TIDEPackage;
  UDUnit: TUDUnit;
  UDGroup: TUDUnitGroup;
  ok: Boolean;
  OldChangeStamp: Int64;
  UnitSet: TFPCUnitSetCache;
begin
  // check without critical section if currently loading/saving
  if fLoadSaveThread<>nil then
    exit;

  if fQueuedTools.Root<>nil then begin
    fParsingTool:=TCustomCodeTool(fQueuedTools.Root.Data);
    fQueuedTools.Delete(fQueuedTools.Root);
    //debugln(['TCodyUnitDictionary.OnIdle parsing ',fParsingTool.MainFilename]);
    OwnerList:=nil;
    try
      ok:=false;
      OldChangeStamp:=ChangeStamp;
      try
        BeginCritSec;
        try
          UDUnit:=ParseUnit(fParsingTool.MainFilename);
        finally
          EndCritSec;
        end;
        ok:=true;
      except
        // parse error
      end;
      if Ok then begin
        OwnerList:=PackageEditingInterface.GetPossibleOwnersOfUnit(
          fParsingTool.MainFilename,[piosfIncludeSourceDirectories]);
        if (OwnerList<>nil) then begin
          BeginCritSec;
          try
            for i:=0 to OwnerList.Count-1 do begin
              if TObject(OwnerList[i]) is TIDEPackage then begin
                Pkg:=TIDEPackage(OwnerList[i]);
                if Pkg.IsVirtual then continue;
                UDGroup:=AddUnitGroup(Pkg.Filename,Pkg.Name);
                //debugln(['TCodyUnitDictionary.OnIdle Pkg=',Pkg.Filename]);
                UDGroup.AddUnit(UDUnit);
              end;
            end;
          finally
            EndCritSec;
          end;
        end;

        // check if in FPC source directory
        UnitSet:=CodeToolBoss.GetUnitSetForDirectory('');
        if (UnitSet<>nil) and (UnitSet.FPCSourceDirectory<>'')
        and FileIsInPath(fParsingTool.MainFilename,UnitSet.FPCSourceDirectory)
        then begin
          BeginCritSec;
          try
            UDGroup:=AddUnitGroup(
              AppendPathDelim(UnitSet.FPCSourceDirectory)+PackageNameFPCSrcDir+'.lpk',
              PackageNameFPCSrcDir);
            UDGroup.AddUnit(UDUnit);
          finally
            EndCritSec;
          end;
        end;

        if ChangeStamp<>OldChangeStamp then begin
          if (fTimer=nil) and (not fClosing) then begin
            fTimer:=TTimer.Create(nil);
            fTimer.Interval:=SaveIntervalInS*1000;
            fTimer.OnTimer:=@OnTimer;
          end;
          if fTimer<>nil then
            fTimer.Enabled:=true;
        end;
      end;
    finally
      fParsingTool:=nil;
      OwnerList.Free;
    end;
  end else begin
    // nothing to do, maybe it's time to load the database
    if fStartTime=0 then
      fStartTime:=Now
    else if (fLoadSaveThread=nil) and (not fLoaded)
    and (Abs(Now-fStartTime)*86400>=LoadAfterStartInS) then
      StartLoadSaveThread;
  end;
  Done:=fQueuedTools.Count=0;
  if Done then
    IdleConnected:=false;
end;

procedure TCodyUnitDictionary.WaitForThread;
begin
  repeat
    BeginCritSec;
    try
      if fLoadSaveThread=nil then exit;
    finally
      EndCritSec;
    end;
    Sleep(10);
  until false;
end;

procedure TCodyUnitDictionary.OnTimer(Sender: TObject);
begin
  if StartLoadSaveThread then
    if fTimer<>nil then
      fTimer.Enabled:=false;
end;

function TCodyUnitDictionary.GetFilename: string;
begin
  Result:=AppendPathDelim(LazarusIDE.GetPrimaryConfigPath)+'codyunitdictionary.txt';
end;

function TCodyUnitDictionary.StartLoadSaveThread: boolean;
begin
  Result:=false;
  if (Self=nil) or fClosing then exit;
  if (Application=nil) or (CodyUnitDictionary=nil) then exit;
  //debugln(['TCodyUnitDictionary.StartLoadSaveThread ',fLoadSaveThread<>nil]);
  BeginCritSec;
  try
    if fLoadSaveThread<>nil then exit;
  finally
    EndCritSec;
  end;
  Result:=true;
  fLoadSaveThread:=TCodyUDLoadSaveThread.Create(true);
  fLoadSaveThread.Load:=not fLoaded;
  fLoadSaveThread.Dictionary:=Self;
  fLoadSaveThread.Filename:=GetFilename;
  fLoadSaveThread.Start;
end;

procedure TCodyUnitDictionary.OnIDEClose(Sender: TObject);
begin
  fClosing:=true;
  FreeAndNil(fTimer);
end;

procedure TCodyUnitDictionary.SetIdleConnected(AValue: boolean);
begin
  if FIdleConnected=AValue then Exit;
  FIdleConnected:=AValue;
  if Application=nil then exit;
  if IdleConnected then
    Application.AddOnIdleHandler(@OnIdle)
  else
    Application.RemoveOnIdleHandler(@OnIdle);
end;

procedure TCodyUnitDictionary.SetLoadAfterStartInS(AValue: integer);
begin
  if FLoadAfterStartInS=AValue then Exit;
  FLoadAfterStartInS:=AValue;
end;

procedure TCodyUnitDictionary.SetLoadSaveError(AValue: string);
begin
  BeginCritSec;
  try
    FLoadSaveError:=AValue;
  finally
    EndCritSec;
  end;
end;

procedure TCodyUnitDictionary.SetSaveIntervalInS(AValue: integer);
begin
  if FSaveIntervalInS=AValue then Exit;
  FSaveIntervalInS:=AValue;
  if fTimer<>nil then
    fTimer.Interval:=SaveIntervalInS;
end;

constructor TCodyUnitDictionary.Create;
begin
  inherited Create;
  FSaveIntervalInS:=60*3; // every 3 minutes
  FLoadAfterStartInS:=3;
  InitCriticalSection(fCritSec);
  fQueuedTools:=TAVLTree.Create;
  CodeToolBoss.AddHandlerToolTreeChanging(@ToolTreeChanged);
  LazarusIDE.AddHandlerOnIDEClose(@OnIDEClose);
end;

destructor TCodyUnitDictionary.Destroy;
begin
  fClosing:=true;
  CodeToolBoss.RemoveHandlerToolTreeChanging(@ToolTreeChanged);
  FreeAndNil(fTimer);
  WaitForThread;
  IdleConnected:=false;
  FreeAndNil(fQueuedTools);
  inherited Destroy;
  DoneCriticalsection(fCritSec);
end;

procedure TCodyUnitDictionary.Load;
begin
  if fLoaded then exit;
  WaitForThread;
  if fLoaded then exit;
  StartLoadSaveThread;
  WaitForThread;
end;

procedure TCodyUnitDictionary.Save;
begin
  WaitForThread;
  fLoaded:=true;
  StartLoadSaveThread;
  WaitForThread;
end;

procedure TCodyUnitDictionary.BeginCritSec;
begin
  EnterCriticalsection(fCritSec);
end;

procedure TCodyUnitDictionary.EndCritSec;
begin
  LeaveCriticalsection(fCritSec);
end;

{ TCodyIdentifiersDlg }

procedure TCodyIdentifiersDlg.FilterEditChange(Sender: TObject);
begin
  IdleConnected:=true;
end;

procedure TCodyIdentifiersDlg.FileLabelClick(Sender: TObject);
begin

end;

procedure TCodyIdentifiersDlg.ButtonPanel1OKButtonClick(Sender: TObject);
begin
  if FindSelectedItem(NewIdentifier, NewUnitFilename, NewGroupFilename) then
    ModalResult:=mrOk
  else
    ModalResult:=mrNone;
end;

procedure TCodyIdentifiersDlg.FilterEditExit(Sender: TObject);
begin
  if GetFilterEditText='' then
    FilterEdit.Text:=FNoFilterText;
end;

procedure TCodyIdentifiersDlg.FilterEditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  i: Integer;
begin
  i:=ItemsListBox.ItemIndex;
  case Key of
  VK_DOWN:
    if i<0 then
      ItemsListBox.ItemIndex:=0
    else if i<ItemsListBox.Count-1 then
      ItemsListBox.ItemIndex:=i+1;
  VK_UP:
    if i<0 then
      ItemsListBox.ItemIndex:=ItemsListBox.Count-1
    else if i>0 then
      ItemsListBox.ItemIndex:=i-1;
  end;
end;

procedure TCodyIdentifiersDlg.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  FreeAndNil(FItems);
end;

procedure TCodyIdentifiersDlg.FormCreate(Sender: TObject);
begin
  Caption:=crsCodyIdentifierDictionary;
  ButtonPanel1.OKButton.Caption:=crsUseIdentifier;
  ButtonPanel1.OKButton.OnClick:=@ButtonPanel1OKButtonClick;
  FMaxItems:=20;
  FNoFilterText:=crsFilter;
  FItems:=TStringList.Create;
end;

procedure TCodyIdentifiersDlg.ItemsListBoxClick(Sender: TObject);
begin

end;

procedure TCodyIdentifiersDlg.ItemsListBoxSelectionChange(Sender: TObject;
  User: boolean);
begin
  UpdateIdentifierInfo;
end;

procedure TCodyIdentifiersDlg.OnIdle(Sender: TObject; var Done: Boolean);
begin
  if not CodyUnitDictionary.Loaded then begin
    CodyUnitDictionary.Load;
    UpdateGeneralInfo;
  end;
  if FLastFilter<>GetFilterEditText then
    UpdateItemsList;
  IdleConnected:=false;
end;

procedure TCodyIdentifiersDlg.SetIdleConnected(AValue: boolean);
begin
  if FIdleConnected=AValue then Exit;
  FIdleConnected:=AValue;
  if Application=nil then exit;
  if IdleConnected then
    Application.AddOnIdleHandler(@OnIdle)
  else
    Application.RemoveOnIdleHandler(@OnIdle);
end;

procedure TCodyIdentifiersDlg.SetMaxItems(AValue: integer);
begin
  if FMaxItems=AValue then Exit;
  FMaxItems:=AValue;
  UpdateItemsList;
end;

procedure TCodyIdentifiersDlg.UpdateItemsList;
var
  Filter: String;
  Node: TAVLTreeNode;
  FilterP: PChar;
  sl: TStringList;
  Item: TUDIdentifier;
  s: String;
  Found: Integer;
  GroupNode: TAVLTreeNode;
  Group: TUDUnitGroup;
  FPCSrcDir: String;
  Dir: String;
  UseGroup: Boolean;
begin
  Filter:=GetFilterEditText;
  FilterP:=PChar(Filter);
  FItems.Clear;
  sl:=TStringList.Create;
  try
    Found:=0;
    FPCSrcDir:=ChompPathDelim(GetFPCSrcDir(''));
    Node:=CodyUnitDictionary.Identifiers.FindLowest;
    //debugln(['TCodyIdentifiersDlg.UpdateItemsList Filter="',Filter,'"']);
    while Node<>nil do begin
      if ComparePrefixIdent(FilterP,PChar(Pointer(TUDIdentifier(Node.Data).Name)))
      then begin
        inc(Found);
        if Found<MaxItems then begin
          Item:=TUDIdentifier(Node.Data);
          GroupNode:=Item.DUnit.UnitGroups.FindLowest;
          while GroupNode<>nil do begin
            Group:=TUDUnitGroup(GroupNode.Data);
            UseGroup:=false;
            if Group.Name='' then begin
              // it's a unit without package
              UseGroup:=true
            end else if Group.Name=PackageNameFPCSrcDir then begin
              // it's a FPC source directory
              // => check if it is the current one
              Dir:=ExtractFilePath(Group.Filename);
              UseGroup:=CompareFilenames(Dir,FPCSrcDir)=0;
            end else if FileExistsCached(Group.Filename) then begin
              // lpk exists
              UseGroup:=true;
            end;
            if UseGroup then begin
              s:=Item.Name+' in '+Item.DUnit.Name;
              if Group.Name<>'' then
                s:=s+' of '+Group.Name;
              if FileExistsCached(Item.DUnit.Filename) then begin
                FItems.Add(Item.Name+#10+Item.DUnit.Filename+#10+Group.Filename);
                sl.Add(s);
              end;
            end;
            GroupNode:=Item.DUnit.UnitGroups.FindSuccessor(GroupNode);
          end;
        end;
      end;
      Node:=CodyUnitDictionary.Identifiers.FindSuccessor(Node);
    end;

    if Found>sl.Count then
      sl.Add(Format(crsAndMoreIdentifiers, [IntToStr(Found-sl.Count)]));

    ItemsListBox.Items.Assign(sl);
    if Found>0 then
      ItemsListBox.ItemIndex:=0;
    UpdateIdentifierInfo;
  finally
    sl.Free;
  end;
end;

procedure TCodyIdentifiersDlg.UpdateIdentifierInfo;
var
  Identifier: string;
  UnitFilename: string;
  GroupFilename: string;
begin
  if FindSelectedItem(Identifier, UnitFilename, GroupFilename) then begin
    if GroupFilename<>'' then
      UnitFilename:=CreateRelativePath(UnitFilename,ExtractFilePath(GroupFilename));
    UnitLabel.Caption:='Unit: '+UnitFilename;
    PackageLabel.Caption:='Package: '+GroupFilename;
    ButtonPanel1.OKButton.Enabled:=true;
  end else begin
    UnitLabel.Caption:='Unit: none selected';
    PackageLabel.Caption:='Package: none selected';
    ButtonPanel1.OKButton.Enabled:=false;
  end;
end;

procedure TCodyIdentifiersDlg.UpdateGeneralInfo;
var
  s: String;
begin
  s:=Format(crsPackagesUnitsIdentifiersFile,
    [IntToStr(CodyUnitDictionary.UnitGroupsByFilename.Count),
     IntToStr(CodyUnitDictionary.UnitsByFilename.Count),
     IntToStr(CodyUnitDictionary.Identifiers.Count),
     #13#10,
     CodyUnitDictionary.GetFilename]);
  if CodyUnitDictionary.LoadSaveError<>'' then
    s:=s+#13#10+Format(crsError, [CodyUnitDictionary.LoadSaveError]);
  InfoLabel.Caption:=s;
end;

function TCodyIdentifiersDlg.GetFilterEditText: string;
begin
  Result:=FilterEdit.Text;
  if Result=FNoFilterText then
    Result:='';
end;

function TCodyIdentifiersDlg.FindSelectedItem(out Identifier, UnitFilename,
  GroupFilename: string): boolean;
var
  i: Integer;
  s: String;
  p: SizeInt;
begin
  Result:=false;
  i:=ItemsListBox.ItemIndex;
  if (i<0) or (i>=FItems.Count) then exit;
  s:=FItems[i];
  p:=Pos(#10,s);
  if p<1 then exit;
  Identifier:=copy(s,1,p-1);
  System.Delete(s,1,p);
  p:=Pos(#10,s);
  if p<1 then begin
    UnitFilename:=s;
    GroupFilename:='';
  end else begin
    UnitFilename:=copy(s,1,p-1);
    System.Delete(s,1,p);
    GroupFilename:=s;
  end;
  //debugln(['TCodyIdentifiersDlg.FindSelectedItem ',Identifier,' Unit=',UnitFilename,' Pkg=',GroupFilename]);
  Result:=true;
end;

function TCodyIdentifiersDlg.Init: boolean;
var
  ErrorHandled: boolean;
  Line: String;
begin
  Result:=true;
  CurInitError:=ParseTilCursor(CurTool, CurCleanPos, CurNode, ErrorHandled, false, @CurCodePos);

  CurIdentifier:='';
  CurIdentStart:=0;
  CurIdentEnd:=0;
  if (CurCodePos.Code<>nil) then begin
    Line:=CurCodePos.Code.GetLine(CurCodePos.Y-1);
    GetIdentStartEndAtPosition(Line,CurCodePos.X,CurIdentStart,CurIdentEnd);
    if CurIdentStart<CurIdentEnd then
      CurIdentifier:=copy(Line,CurIdentStart,CurIdentEnd-CurIdentStart);
  end;

  UpdateGeneralInfo;
  FLastFilter:='...'; // force one update
  if CurIdentifier='' then
    FilterEdit.Text:=FNoFilterText
  else
    FilterEdit.Text:=CurIdentifier;
  IdleConnected:=true;
end;

procedure TCodyIdentifiersDlg.UseIdentifier;
begin
  CurSrcEdit:=SourceEditorManagerIntf.ActiveEditor;
  if CurSrcEdit=nil then exit;
  CurSrcEdit.BeginUndoBlock;
  try
    // insert or replace identifier
    if (not CurSrcEdit.SelectionAvailable)
    and (CurIdentStart<CurIdentEnd) then
      CurSrcEdit.SelectText(CurCodePos.Y,CurIdentStart,CurCodePos.Y,CurIdentEnd);
    CurSrcEdit.Selection:=NewIdentifier;

    if CurTool<>nil then begin
      CurMainFilename:=CurTool.MainFilename;
      CurMainCode:=TCodeBuffer(CurTool.Scanner.MainCode);
    end else begin
      CurMainFilename:=CurSrcEdit.FileName;
      CurMainCode:=TCodeBuffer(CurSrcEdit.CodeToolsBuffer);
    end;
    GetCurOwnerOfUnit;

    if CurOwner<>nil then begin
      // ToDo: add dependency

    end;

    AddToUsesSection;
  finally
    CurSrcEdit.EndUndoBlock;
  end;
end;

procedure TCodyIdentifiersDlg.GetCurOwnerOfUnit;

  procedure GetBest(OwnerList: TFPList);
  var
    i: Integer;
  begin
    if OwnerList=nil then exit;
    for i:=0 to OwnerList.Count-1 do begin
      if (TObject(OwnerList[i]) is TLazProject)
      or ((TObject(OwnerList[i]) is TIDEPackage) and (CurOwner=nil)) then
        CurOwner:=TObject(OwnerList[i]);
    end;
    OwnerList.Free;
  end;

begin
  if CurMainFilename='' then exit;
  GetBest(PackageEditingInterface.GetOwnersOfUnit(CurMainFilename));
  if CurOwner=nil then
    GetBest(PackageEditingInterface.GetPossibleOwnersOfUnit(CurMainFilename,
             [piosfIncludeSourceDirectories]));
end;

procedure TCodyIdentifiersDlg.AddToUsesSection;
var
  NewUnitCode: TCodeBuffer;
  NewUnitName: String;
begin
  if (CurTool=nil) or (NewUnitFilename='') then exit;
  UpdateTool;
  if (CurNode=nil) then exit;

  // get unit name
  NewUnitCode:=CodeToolBoss.LoadFile(NewUnitFilename,true,false);
  if NewUnitCode=nil then exit;
  NewUnitName:=CodeToolBoss.GetSourceName(NewUnitCode,false);
  if NewUnitName='' then
    NewUnitName:=ExtractFileNameOnly(NewUnitFilename);

  if (CurNode.Desc in [ctnUnit,ctnUsesSection]) then exit;
  // add to uses section
  CodeToolBoss.AddUnitToMainUsesSection(CurMainCode,NewUnitName,'');
end;

procedure TCodyIdentifiersDlg.UpdateTool;
begin
  if (CurTool=nil) or (NewUnitFilename='') then exit;
  if not LazarusIDE.BeginCodeTools then exit;
  try
    CurTool.BuildTree(lsrEnd);
  except
  end;
  CurNode:=CurTool.FindDeepestNodeAtPos(CurCleanPos,false);
end;

function TCodyIdentifiersDlg.GetFPCSrcDir(const Directory: string): string;
var
  UnitSet: TFPCUnitSetCache;
begin
  Result:='';
  UnitSet:=CodeToolBoss.GetUnitSetForDirectory(Directory);
  if (UnitSet<>nil) then
    Result:=ChompPathDelim(UnitSet.FPCSourceDirectory);
end;

finalization
  FreeAndNil(CodyUnitDictionary);

end.

