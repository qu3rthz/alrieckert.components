{ Copyright (C) 2008 Darius Blaszijk

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
}

unit SVNUpdateForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  ComCtrls, StdCtrls, ButtonPanel, Process, Buttons, Menus, LCLProc;

type

  { TSVNUpdateFrm }

  TSVNUpdateFrm = class(TForm)
    mnuShowDiff: TMenuItem;
    UpdatePopupMenu: TPopupMenu;
    ShowLogButton: TBitBtn;
    ButtonPanel: TButtonPanel;
    SVNUpdateListView: TListView;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure mnuShowDiffClick(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure ShowLogButtonClick(Sender: TObject);
  private
    { private declarations }
    FRepoPath: string;
    procedure ProcessSVNUpdateOutput(var MemStream: TMemoryStream; var BytesRead: LongInt);
  public
    { public declarations }
    procedure Execute;
  end; 

procedure ShowSVNUpdateFrm(ARepoPath: string);

implementation

uses
  SVNLogForm, SVNDiffForm, SVNClasses;

{ TSVNUpdateFrm }

procedure ShowSVNUpdateFrm(ARepoPath: string);
var
  SVNUpdateFrm: TSVNUpdateFrm;
begin
  SVNUpdateFrm := TSVNUpdateFrm.Create(nil);

  SVNUpdateFrm.FRepoPath:=ARepoPath;
  SVNUpdateFrm.ShowModal;

  SVNUpdateFrm.Free;
end;

procedure TSVNUpdateFrm.FormCreate(Sender: TObject);
begin
  SetColumn(SVNUpdateListView, 0, 75, rsAction);
  SetColumn(SVNUpdateListView, 1, 400, rsPath);
  //SetColumn(SVNUpdateListView, 2, 100,'Mime type');

  ButtonPanel.OKButton.OnClick := @OKButtonClick;
  ShowLogButton.Caption := rsShowLog;
  mnuShowDiff.Caption:=rsShowDiff;
end;

procedure TSVNUpdateFrm.FormShow(Sender: TObject);
begin
  Caption := Format(rsLazarusSVNUpdate, [FRepoPath]);
  Execute;
end;

procedure TSVNUpdateFrm.mnuShowDiffClick(Sender: TObject);
begin
  {$note implement opening file in source editor}
  if Assigned(SVNUpdateListView.Selected) then
  begin
    if (SVNUpdateListView.Selected.Caption = rsAdded) or
       (SVNUpdateListView.Selected.Caption = rsDeleted) or
       (SVNUpdateListView.Selected.Caption = rsUpdated) or
       (SVNUpdateListView.Selected.Caption = rsConflict) or
       (SVNUpdateListView.Selected.Caption = rsMerged) then
    begin
      debugln('TSVNUpdateFrm.mnuShowDiffClick Path=' ,SVNUpdateListView.Selected.SubItems[0]);
      ShowSVNDiffFrm('-r PREV', SVNUpdateListView.Selected.SubItems[0]);
    end;
  end;
end;

procedure TSVNUpdateFrm.OKButtonClick(Sender: TObject);
begin
  Close;
end;

procedure TSVNUpdateFrm.ShowLogButtonClick(Sender: TObject);
begin
  ShowSVNLogFrm(FRepoPath);
end;

procedure TSVNUpdateFrm.ProcessSVNUpdateOutput(var MemStream: TMemoryStream; var BytesRead: LongInt);
var
  S: TStringList;
  n: LongInt;
  i: integer;
  str: string;
begin
  Memstream.SetSize(BytesRead);
  S := TStringList.Create;
  S.LoadFromStream(MemStream);

  for n := 0 to S.Count - 1 do
    with SVNUpdateListView.Items.Add do
    begin
      //find position of first space character
      i := pos(' ', S[n]);
      str := Copy(S[n],1, i - 1);

      if str = 'A'then str := rsAdded;
      if str = 'D'then str := rsDeleted;
      if str = 'U'then str := rsUpdated;
      if str = 'C'then str := rsConflict;
      if str = 'G'then str := rsMerged;
      Caption := str;

      Subitems.Add(Trim(Copy(S[n],i, Length(S[n])-i+1)));
    end;

  S.Free;
  BytesRead := 0;
  MemStream.Clear;

  //repaint the listview
  SVNUpdateListView.Invalidate;
  Invalidate;
end;

procedure TSVNUpdateFrm.Execute;
var
  M: TMemoryStream;
  P: TProcess;
  n: LongInt;
  BytesRead: LongInt;
begin
  SVNUpdateListView.Clear;

  M := TMemoryStream.Create;
  BytesRead := 0;

  P := TProcess.Create(nil);
  P.CommandLine := SVNExecutable + ' update ' + FRepoPath + ' --non-interactive';
  debugln('TSVNUpdateFrm.Execute CommandLine ' + P.CommandLine);
  P.Options := [poUsePipes, poStdErrToOutput];
  P.ShowWindow := swoHIDE;
  P.Execute;

  while P.Running do
  begin
    // make sure we have room
    M.SetSize(BytesRead + READ_BYTES);

    // try reading it
    n := P.Output.Read((M.Memory + BytesRead)^, READ_BYTES);
    if n > 0
    then begin
      Inc(BytesRead, n);
      ProcessSVNUpdateOutput(m, BytesRead);
    end
    else begin
      // no data, wait 100 ms
      Sleep(100);
      Invalidate;
    end;
  end;
  // read last part
  repeat
    // make sure we have room
    M.SetSize(BytesRead + READ_BYTES);
    // try reading it
    n := P.Output.Read((M.Memory + BytesRead)^, READ_BYTES);
    if n > 0
    then begin
      Inc(BytesRead, n);
      ProcessSVNUpdateOutput(m, BytesRead);
    end;
  until n <= 0;

  P.Free;
  M.Free;
end;

initialization
  {$I svnupdateform.lrs}

end.

