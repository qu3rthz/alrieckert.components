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

 Author: Balázs Székely
 Abstract:
   Implementation of the options dialog.
}

unit opkman_optionsfrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, opkman_VirtualTrees, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ExtCtrls, Spin, ComCtrls, Buttons, EditBtn, LazFileUtils, Math;

type

  { TOptionsFrm }

  TOptionsFrm = class(TForm)
    bCancel: TButton;
    bOk: TButton;
    bRestore: TButton;
    cbProxy: TCheckBox;
    cbForceDownloadExtract: TCheckBox;
    cbDeleteZipAfterInstall: TCheckBox;
    cbSelectProfile: TComboBox;
    cbCheckForUpdates: TComboBox;
    edLocalRepositoryUpdate: TDirectoryEdit;
    edLocalRepositoryPackages: TDirectoryEdit;
    edLocalRepositoryArchive: TDirectoryEdit;
    edProxyPassword: TEdit;
    edProxyServer: TEdit;
    edProxyUser: TEdit;
    edRemoteRepository: TEdit;
    gbProxySettings: TGroupBox;
    lbLastUpdate: TLabel;
    lbUpdates: TLabel;
    lbLocalRepositoryArchive: TLabel;
    lbLocalRepositoryUpdate: TLabel;
    lbRemoteRepository: TLabel;
    lbSelectProfile: TLabel;
    lbServer: TLabel;
    lbLocalRepositoryPackages: TLabel;
    lbUserName: TLabel;
    lbPort: TLabel;
    lbPassword: TLabel;
    pnProfiles: TPanel;
    pnFolders: TPanel;
    pnProxy: TPanel;
    pnGeneral: TPanel;
    pgOptions: TPageControl;
    pnBottom: TPanel;
    SDD: TSelectDirectoryDialog;
    seProxyPort: TSpinEdit;
    tsFolders: TTabSheet;
    tsProfiles: TTabSheet;
    tsGeneral: TTabSheet;
    tsProxy: TTabSheet;
    procedure bOkClick(Sender: TObject);
    procedure bRestoreClick(Sender: TObject);
    procedure cbProxyChange(Sender: TObject);
    procedure edRemoteRepositoryKeyPress(Sender: TObject; var Key: char);
  private
  public
    procedure SetupControls;
  end;

var
  OptionsFrm: TOptionsFrm;

implementation
uses opkman_options, opkman_common, opkman_const;
{$R *.lfm}

{ TOptionsFrm }

procedure TOptionsFrm.bOkClick(Sender: TObject);
begin
  if Trim(edRemoteRepository.Text)  = '' then
  begin
    MessageDlgEx(rsOptions_RemoteRepository_Information, mtInformation, [mbOk], Self);
    edRemoteRepository.SetFocus;
    Exit;
  end;

  if cbProxy.Checked then
  begin
    if Trim(edProxyServer.Text)  = '' then
    begin
      MessageDlgEx(rsOptions_ProxyServer_Info, mtInformation, [mbOk], Self);
      edProxyServer.SetFocus;
      Exit;
    end;
    if seProxyPort.Value = 0 then
    begin
      MessageDlgEx(rsOptions_ProxyPort_Info, mtInformation, [mbOk], Self);
      seProxyPort.SetFocus;
      Exit;
    end;
  end;

  if Trim(edLocalRepositoryPackages.Text)  = '' then
  begin
    MessageDlgEx(rsOptions_InvalidDirectory_Info, mtInformation, [mbOk], Self);
    edLocalRepositoryPackages.SetFocus;
    Exit;
  end;
  if Trim(edLocalRepositoryArchive.Text)  = '' then
  begin
    MessageDlgEx(rsOptions_InvalidDirectory_Info, mtInformation, [mbOk], Self);
    edLocalRepositoryArchive.SetFocus;
    Exit;
  end;
  if Trim(edLocalRepositoryUpdate.Text)  = '' then
  begin
    MessageDlgEx(rsOptions_InvalidDirectory_Info, mtInformation, [mbOk], Self);
    edLocalRepositoryUpdate.SetFocus;
    Exit;
  end;
  Options.RemoteRepository := edRemoteRepository.Text;
  Options.ForceDownloadAndExtract := cbForceDownloadExtract.Checked;
  Options.DeleteZipAfterInstall := cbDeleteZipAfterInstall.Checked;
  Options.UserProfile := cbSelectProfile.ItemIndex;
  Options.CheckForUpdates := cbCheckForUpdates.ItemIndex;
  Options.ProxyEnabled := cbProxy.Checked;
  Options.ProxyServer := edProxyServer.Text;
  Options.ProxyPort := seProxyPort.Value;
  Options.ProxyUser := edProxyUser.Text;
  Options.ProxyPassword := edProxyPassword.Text;
  Options.LocalRepositoryPackages := AppendPathDelim(edLocalRepositoryPackages.Text);
  Options.LocalRepositoryArchive := AppendPathDelim(edLocalRepositoryArchive.Text);
  Options.LocalRepositoryUpdate := AppendPathDelim(edLocalRepositoryUpdate.Text);
  Options.Save;
  ModalResult := mrOk;
end;

procedure TOptionsFrm.bRestoreClick(Sender: TObject);
begin
  if MessageDlgEx(rsOptions_RestoreDefaults_Conf, mtInformation, [mbYes, mbNo], Self) = mrYes then
  begin
    Options.LoadDefault;
    Options.CreateMissingPaths;
    SetupControls;
  end;
end;

procedure TOptionsFrm.cbProxyChange(Sender: TObject);
begin
  gbProxySettings.Enabled:= cbProxy.Checked;
end;

procedure TOptionsFrm.edRemoteRepositoryKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
    bOkClick(bOk);
end;

procedure TOptionsFrm.SetupControls;
begin
  Caption := rsOptions_FrmCaption;
  pgOptions.ActivePageIndex := 0;
  tsGeneral.Caption := rsOptions_tsGeneral_Caption;
  lbRemoteRepository.Caption := rsOptions_lbRemoteRepository_Caption;
  edRemoteRepository.Text := Options.RemoteRepository;
  cbForceDownloadExtract.Checked := Options.ForceDownloadAndExtract;
  cbDeleteZipAfterInstall.Checked := Options.DeleteZipAfterInstall;
  cbForceDownloadExtract.Caption := rsOptions_cbForceDownloadExtract_Caption;
  cbForceDownloadExtract.Hint := rsOptions_cbForceDownloadExtract_Hint;
  cbDeleteZipAfterInstall.Caption := rsOptions_cbDelete_Caption;
  cbDeleteZipAfterInstall.Hint := rsOptions_cbDelete_Hint;
  lbUpdates.Caption := rsOptions_lbCheckForUpdates_Caption;
  cbCheckForUpdates.Clear;
  cbCheckForUpdates.Items.Add(rsOptions_cbCheckForUpdates_Item0);
  cbCheckForUpdates.Items.Add(rsOptions_cbCheckForUpdates_Item1);
  cbCheckForUpdates.Items.Add(rsOptions_cbCheckForUpdates_Item2);
  cbCheckForUpdates.Items.Add(rsOptions_cbCheckForUpdates_Item3);
  cbCheckForUpdates.Items.Add(rsOptions_cbCheckForUpdates_Item4);
  cbCheckForUpdates.Items.Add(rsOptions_cbCheckForUpdates_Item5);
  cbCheckForUpdates.ItemIndex := Options.CheckForUpdates;
  if CompareValue(Options.LastUpdate, 0.0, 0.1) <= 0 then
    lbLastUpdate.Caption := rsOptions_lbLastUpdate_Caption + rsOptions_LastUpdate_Never
  else
    lbLastUpdate.Caption := rsOptions_lbLastUpdate_Caption + FormatDateTime('YYYY.MM.DD  hh:mm:ss', Options.LastUpdate);
  tsProxy.Caption := rsOptions_tsProxy_Caption;
  cbProxy.Caption := rsOptions_cbProxy_Caption;
  gbProxySettings.Caption := rsOptions_gbProxySettings_Caption;
  lbServer.Caption := rsOptions_lbServer_Caption;
  lbPort.Caption := rsOptions_lbPort_Caption;
  lbUserName.Caption := rsOptions_lbUsername_Caption;
  lbPassword.Caption := rsOptions_lbPassword_Caption;
  cbProxy.Checked := Options.ProxyEnabled;
  gbProxySettings.Enabled := Options.ProxyEnabled;
  edProxyServer.Text := Options.ProxyServer;
  seProxyPort.Value := Options.ProxyPort;
  edProxyUser.Text := Options.ProxyUser;
  edProxyPassword.Text := Options.ProxyPassword;

  tsFolders.Caption := rsOptions_tsFolders_Caption;
  lbLocalRepositoryPackages.Caption := rsOptions_lbLocalRepositoryPackages_Caption;
  edLocalRepositoryPackages.Hint := rsOptions_edLocalRepositoryPackages_Hint;
  lbLocalRepositoryArchive.Caption := rsOptions_lbLocalRepositoryArchive_Caption;
  edLocalRepositoryArchive.Hint := rsOptions_edLocalRepositoryArchive_Hint;
  lbLocalRepositoryUpdate.Caption := rsOptions_lbLocalRepositoryUpdate_Caption;
  edLocalRepositoryUpdate.Hint := rsOptions_edLocalRepositoryUpdate_Hint;
  edLocalRepositoryPackages.Text := Options.LocalRepositoryPackages;
  edLocalRepositoryArchive.Text := Options.LocalRepositoryArchive;
  edLocalRepositoryUpdate.Text := Options.LocalRepositoryUpdate;

  tsProfiles.Caption := rsOptions_tsProfiles_Caption;
  lbSelectProfile.Caption := rsOptions_lbSelectProfile_Caption;
  cbSelectProfile.Clear;
  cbSelectProfile.Items.Add(rsOptions_cbSelectProfile_Item0);
  cbSelectProfile.Items.Add(rsOptions_cbSelectProfile_Item1);
  cbSelectProfile.ItemIndex := Options.UserProfile;
  cbSelectProfile.Hint := rsOptions_cbSelectProfile_Hint;
end;

end.

