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
    Registering menu items, shortcuts and components in the Lazarus IDE.
}
unit CodyRegistration;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Controls,
  IDECommands, MenuIntf, IDEWindowIntf, SrcEditorIntf,
  CodyStrConsts, CodyCtrls, PPUListDlg, AddAssignMethodDlg,
  CodyUtils, CodyNodeInfoDlg, CodyFrm, DeclareVarDlg;

procedure Register;

implementation

procedure Register;
var
  CmdCatProjectMenu: TIDECommandCategory;
  CmdCatCodeTools: TIDECommandCategory;
  CmdCatFileMenu: TIDECommandCategory;
  PPUListCommand: TIDECommand;
  AddAssignMethodCommand: TIDECommand;
  RemoveAWithBlockCommand: TIDECommand;
  InsertFileAtCursorCommand: TIDECommand;
  DeclareVariableCommand: TIDECommand;
  TVIconRes: TLResource;
  AddCallInheritedCommand: TIDECommand;
  ShowCodeNodeInfoCommand: TIDECommand;
  CmdCatView: TIDECommandCategory;
  ViewCodyWindowCommand: TIDECommand;
  CopyDeclarationToClipboardCommand: TIDECommand;
  CutDeclarationToClipboardCommand: TIDECommand;
begin
  CmdCatFileMenu:=IDECommandList.FindCategoryByName('FileMenu');
  if CmdCatFileMenu=nil then
    raise Exception.Create('cody: command category FileMenu not found');
  CmdCatProjectMenu:=IDECommandList.FindCategoryByName('ProjectMenu');
  if CmdCatProjectMenu=nil then
    raise Exception.Create('cody: command category ProjectMenu not found');
  CmdCatCodeTools:=IDECommandList.FindCategoryByName(CommandCategoryCodeTools);
  if CmdCatCodeTools=nil then
    raise Exception.Create('cody: command category '+CommandCategoryCodeTools+' not found');
  CmdCatView:=IDECommandList.FindCategoryByName(CommandCategoryViewName);
  if CmdCatView=nil then
    raise Exception.Create('cody: command category '+CommandCategoryViewName+' not found');


  // Source menu - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  // insert file at cursor
  InsertFileAtCursorCommand:=RegisterIDECommand(CmdCatFileMenu,
    'InsertFileAtCursor',crsInsertFileAtCursor,
    CleanIDEShortCut,CleanIDEShortCut,nil,@InsertFileAtCursor);
  RegisterIDEMenuCommand(SrcEditSubMenuSource,'InsertFileAtCursor',
    crsInsertFileAtCursor,nil,nil,InsertFileAtCursorCommand);

  // show ppu list of project
  PPUListCommand:=RegisterIDECommand(CmdCatProjectMenu, 'ShowPPUList',
    crsShowUsedPpuFiles,
    CleanIDEShortCut,CleanIDEShortCut,nil,@ShowPPUList);
  RegisterIDEMenuCommand(itmProjectWindowSection,'PPUList',crsShowUsedPpuFiles,
    nil,nil,PPUListCommand);

  // add call inherited
  AddCallInheritedCommand:=RegisterIDECommand(CmdCatCodeTools, 'AddCallInherited',
    crsAddCallInherited,
    CleanIDEShortCut,CleanIDEShortCut,nil,@AddCallInherited);
  RegisterIDEMenuCommand(SrcEditSubMenuSource, 'AddCallInherited',
    crsAddCallInherited, nil, nil, AddCallInheritedCommand);

  // declare variable
  DeclareVariableCommand:=RegisterIDECommand(CmdCatCodeTools, 'DeclareVariable',
    crsDeclareVariable,
    CleanIDEShortCut,CleanIDEShortCut,nil,@ShowDeclareVariableDialog);
  RegisterIDEMenuCommand(SrcEditSubMenuRefactor, 'DeclareVariable',
    crsDeclareVariable2, nil, nil, DeclareVariableCommand);


  // Refactor menu - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  // add Assign method
  AddAssignMethodCommand:=RegisterIDECommand(CmdCatCodeTools, 'AddAssignMethod',
    crsAddAssignMethod,
    CleanIDEShortCut,CleanIDEShortCut,nil,@ShowAddAssignMethodDialog);
  RegisterIDEMenuCommand(SrcEditSubMenuRefactor, 'AddAssignMethod',
    crsAddAssignMethod2,nil,nil,AddAssignMethodCommand);

  // Copy declaration to clipboard
  CopyDeclarationToClipboardCommand:=RegisterIDECommand(CmdCatCodeTools,
    'CopyDeclarationToClipboard', crsCopyDeclarationToClipboard,
    CleanIDEShortCut,CleanIDEShortCut,nil,@CopyDeclarationToClipboard);
  RegisterIDEMenuCommand(SrcEditSubMenuRefactor, 'CopyDeclarationToClipboard',
    crsCopyDeclarationToClipboard,nil,nil,CopyDeclarationToClipboardCommand){$IFNDEF EnableCodyExperiments}.Visible:=false{$ENDIF};

  // Cut declaration to clipboard
  CutDeclarationToClipboardCommand:=RegisterIDECommand(CmdCatCodeTools,
    'CutDeclarationToClipboard', crsCutDeclarationToClipboard,
    CleanIDEShortCut,CleanIDEShortCut,nil,@CutDeclarationToClipboard);
  RegisterIDEMenuCommand(SrcEditSubMenuRefactor, 'CutDeclarationToClipboard',
    crsCutDeclarationToClipboard,nil,nil,CutDeclarationToClipboardCommand){$IFNDEF EnableCodyExperiments}.Visible:=false{$ENDIF};

  // remove With block
  RemoveAWithBlockCommand:=RegisterIDECommand(CmdCatCodeTools, 'RemoveAWithBlock',
    crsRemoveAWithBlock,
    CleanIDEShortCut,CleanIDEShortCut,nil,@RemoveAWithBlockCmd);
  RegisterIDEMenuCommand(SrcEditSubMenuRefactor, 'RemoveAWithBlock',
    crsRemoveAWithBlock, nil, nil, RemoveAWithBlockCommand);

  // IDE internals menu - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  // Show CodeTools node info
  ShowCodeNodeInfoCommand:=RegisterIDECommand(CmdCatCodeTools, 'ShowCodeNodeInfo',
    crsShowCodeToolsNodeInfo,
    CleanIDEShortCut,CleanIDEShortCut,nil,@ShowCodeNodeInfoDialog);
  RegisterIDEMenuCommand(itmViewIDEInternalsWindows, 'ShowCodeNodeInfo',
    crsShowCodeToolsNodeInfo, nil, nil, ShowCodeNodeInfoCommand);


  // View menu - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ViewCodyWindowCommand:=RegisterIDECommand(CmdCatView, 'Cody',
    'Cody', CleanIDEShortCut, CleanIDEShortCut, nil, @ShowCodyWindow);
  RegisterIDEMenuCommand(itmViewMainWindows, 'ViewCody',
    'Cody', nil, nil, ViewCodyWindowCommand)
  {$IFNDEF EnableCodyExperiments}
   .Visible:=false
  {$ENDIF};


  // Components - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  TVIconRes:=LazarusResources.Find('TTreeView');
  LazarusResources.Add(TCodyTreeView.ClassName,TVIconRes.ValueType,TVIconRes.Value);
  RegisterComponents('LazControls',[TCodyTreeView]);

  // Windows - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  CodyWindowCreator:=IDEWindowCreators.Add(CodyWindowName,@CreateCodyWindow,nil,
    '80%','50%','+18%','+25%','CodeExplorer',alBottom);

  // Global handlers - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  SourceEditorManagerIntf.RegisterCopyPasteEvent(@Cody.SrcEditCopyPaste);
end;

end.

