{(*}
(*------------------------------------------------------------------------------
 Delphi Code formatter source code 

The Original Code is frClarify.pas, released April 2000.
The Initial Developer of the Original Code is Anthony Steele.
Portions created by Anthony Steele are Copyright (C) 1999-2008 Anthony Steele.
All Rights Reserved. 
Contributor(s): Anthony Steele.

The contents of this file are subject to the Mozilla Public License Version 1.1
(the "License"). you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.mozilla.org/NPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied.
See the License for the specific language governing rights and limitations
under the License.

Alternatively, the contents of this file may be used under the terms of
the GNU General Public License Version 2 or later (the "GPL") 
See http://www.gnu.org/licenses/gpl.html
------------------------------------------------------------------------------*)
{*)}

unit frClarifyReturns;

{$I JcfGlobal.inc}

interface

uses
  { delphi }
  Classes, Controls, LResources, Forms, StdCtrls, ExtCtrls,
  { local}
  IDEOptionsIntf;

type

  { TfClarifyReturns }

  TfClarifyReturns = class(TAbstractIDEOptionsEditor)
    rgReturnChars: TRadioGroup;
    gbRemoveReturns: TGroupBox;
    cbRemoveProcDefReturns: TCheckBox;
    cbRemoveVarReturns: TCheckBox;
    cbRemoveExprReturns: TCheckBox;
    cbRemovePropertyReturns: TCheckBox;
    cbRemoveReturns: TCheckBox;
    gbInsert: TGroupBox;
    cbUsesClauseOnePerLine: TCheckBox;
    cbInsertReturns: TCheckBox;
    cbBreakAfterUses: TCheckBox;
  public
    constructor Create(AOwner: TComponent); override;

    function GetTitle: String; override;
    procedure Setup(ADialog: TAbstractOptionsEditorDialog); override;
    procedure ReadSettings(AOptions: TAbstractIDEOptions); override;
    procedure WriteSettings(AOptions: TAbstractIDEOptions); override;
    class function SupportedOptionsClass: TAbstractIDEOptionsClass; override;
  end;

implementation

uses
  SettingsTypes, JcfSettings, SetReturns, JcfHelp;


constructor TfClarifyReturns.Create(AOwner: TComponent);
begin
  inherited;
  //fiHelpContext := HELP_CLARIFY_RETURNS;
end;

function TfClarifyReturns.GetTitle: String;
begin
  Result := 'Returns';
end;

procedure TfClarifyReturns.Setup(ADialog: TAbstractOptionsEditorDialog);
begin
  //
end;

{-------------------------------------------------------------------------------
  worker procs }

procedure TfClarifyReturns.ReadSettings(AOptions: TAbstractIDEOptions);
begin
  with FormatSettings.Returns do
  begin
    cbRemoveReturns.Checked     := RemoveBadReturns;
    cbRemovePropertyReturns.Checked := RemovePropertyReturns;
    cbRemoveProcDefReturns.Checked := RemoveProcedureDefReturns;
    cbRemoveVarReturns.Checked  := RemoveVarReturns;
    cbRemoveExprReturns.Checked := RemoveExpressionReturns;

    cbInsertReturns.Checked := AddGoodReturns;
    cbUsesClauseOnePerLine.Checked := UsesClauseOnePerLine;
    cbBreakAfterUses.Checked := BreakAfterUses;

    rgReturnChars.ItemIndex := Ord(ReturnChars);
  end;
end;

procedure TfClarifyReturns.WriteSettings(AOptions: TAbstractIDEOptions);
begin
  with FormatSettings.Returns do
  begin
    RemoveBadReturns      := cbRemoveReturns.Checked;
    RemovePropertyReturns := cbRemovePropertyReturns.Checked;
    RemoveProcedureDefReturns := cbRemoveProcDefReturns.Checked;
    RemoveVarReturns      := cbRemoveVarReturns.Checked;
    RemoveExpressionReturns := cbRemoveExprReturns.Checked;

    AddGoodReturns := cbInsertReturns.Checked;
    UsesClauseOnePerLine := cbUsesClauseOnePerLine.Checked;
    BreakAfterUses := cbBreakAfterUses.Checked;

    ReturnChars := TReturnChars(rgReturnChars.ItemIndex);
  end;
end;

class function TfClarifyReturns.SupportedOptionsClass: TAbstractIDEOptionsClass;
begin
  Result := TFormatSettings;
end;

initialization
  {$I frClarifyReturns.lrs}
  RegisterIDEOptionsEditor(JCFOptionsGroup, TfClarifyReturns, JCFOptionReturns, JCFOptionLongLines);
end.
