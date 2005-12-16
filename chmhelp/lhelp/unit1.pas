{ Copyright (C) <2005> <Andrew Haines> unit1.pas consisting of THelpForm

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
unit unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs, ChmReader,
  Buttons, LCLProc, StdCtrls, IpHtml, ChmDataProvider, ComCtrls, ExtCtrls,
  Menus, SimpleIPC;

type

  { THelpForm }

  THelpForm = class(TForm)
    ContentsTree: TTreeView;
    FileMenuCloseItem: TMenuItem;
    FileMenuExitItem: TMenuItem;
    FileMenuItem: TMenuItem;
    FileMenuOpenItem: TMenuItem;
    FileSeperater: TMenuItem;
    ImageList1: TImageList;
    IndexView: TListView;
    IpHtmlPanel1: TIpHtmlPanel;
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    ConentsPanel: TPanel;
    PopupForward: TMenuItem;
    PopupBack: TMenuItem;
    PopupHome: TMenuItem;
    PopupCopy: TMenuItem;
    Panel1: TPanel;
    ForwardBttn: TSpeedButton;
    BackBttn: TSpeedButton;
    HomeBttn: TSpeedButton;
    OpenDialog1: TOpenDialog;
    IndexTab: TTabSheet;
    PopupMenu1: TPopupMenu;
    SearchTab: TTabSheet;
    TabsControl: TPageControl;
    Splitter1: TSplitter;
    TabPanel: TPanel;
    StatusBar1: TStatusBar;
    ContentsTab: TTabSheet;
    ViewMenuContents: TMenuItem;
    ViewMenuItem: TMenuItem;
    procedure BackToolBtnClick(Sender: TObject);
    procedure ContentsTreeSelectionChanged(Sender: TObject);
    procedure FileMenuCloseItemClick(Sender: TObject);
    procedure FileMenuExitItemClick(Sender: TObject);
    procedure FileMenuOpenItemClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure ForwardToolBtnClick(Sender: TObject);
    procedure HomeToolBtnClick(Sender: TObject);
    procedure ImageList1Change(Sender: TObject);
    procedure IndexViewSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure IpHtmlPanel1DocumentOpen(Sender: TObject);
    procedure IpHtmlPanel1HotChange(Sender: TObject);
    procedure IpHtmlPanel1HotClick(Sender: TObject);
    procedure PopupCopyClick(Sender: TObject);
    procedure ViewMenuContentsClick(Sender: TObject);
    procedure FillTOCTimer(Sender: TObject);
  private
    { private declarations }
    fStopTimer: Boolean;
    fFillingToc: Boolean;
    fHelpFile: String;
    fChm: TChmReader;
    fHistory: TStringList;
    fHotUrl: String;
    fHistoryIndex: Integer;
    fServerName: String;
    fServer: TSimpleIPCServer;
    fServerTimer: TTimer;
    fContext: LongInt; // used once when we are started on the command line with --context
    procedure ServerMessage(Sender: TObject);
    procedure AddHistory(URL: String);
    procedure DoOpenChm(AFile: String);
    procedure DoCloseChm;
    procedure DoLoadContext(Context: THelpContext);
    procedure DoLoadUrl(Url: String);
    procedure DoError(Error: Integer);
    procedure ReadCommandLineOptions;
    procedure StartServer(ServerName: String);
    procedure StopServer;
  public
    { public declarations }
  end; 

var
  HelpForm: THelpForm;
const INVALID_FILE_TYPE = 1;

implementation
uses ChmSpecialParser, LHelpControl;

{ THelpForm }


procedure THelpForm.BackToolBtnClick(Sender: TObject);
begin
  if fHistoryIndex > 0 then begin
    Dec(fHistoryIndex);
    IpHtmlPanel1.OpenURL(fHistory.Strings[fHistoryIndex]);
  end;
end;

procedure THelpForm.ContentsTreeSelectionChanged(Sender: TObject);
var
ATreeNode: TContentTreeNode;
begin
  if ContentsTree.Selected = nil then Exit;
  ATreeNode := TContentTreeNode(ContentsTree.Selected);
  if ATreeNode.Url <> '' then begin
    DoLoadUrl(ATreeNode.Url);
  end;
end;

procedure THelpForm.FileMenuCloseItemClick(Sender: TObject);
begin
  DoCloseChm;// checks if it is open first
end;

procedure THelpForm.FileMenuExitItemClick(Sender: TObject);
begin
  DoCloseChm;
  Close;
end;

procedure THelpForm.FileMenuOpenItemClick(Sender: TObject);
begin
  if OpenDialog1.Execute then DoOpenChm(OpenDialog1.FileName);
end;

procedure THelpForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  DoCloseChm;
  FileMenuCloseItemClick(Sender);
  Stopserver;
  
end;

procedure THelpForm.FormCreate(Sender: TObject);
begin
  fContext := -1;
  //Chm := TCHMFile.Create;
  fHistory := TStringList.Create;
  IpHtmlPanel1.DataProvider := TIpChmDataProvider.Create(fChm);
  ReadCommandLineOptions;
  if fServerName <> '' then begin
    StartServer(fServerName);
  end;
end;

procedure THelpForm.ForwardToolBtnClick(Sender: TObject);
begin
  if fHistoryIndex < fHistory.Count-1 then begin
    Inc(fHistoryIndex);
    IpHtmlPanel1.OpenURL(fHistory.Strings[fHistoryIndex]);
  end;
end;

procedure THelpForm.HomeToolBtnClick(Sender: TObject);
begin
  if (fChm <> nil) and (fChm.DefaultPage <> '') then begin
    DoLoadUrl(fChm.DefaultPage);
  end;
end;

procedure THelpForm.ImageList1Change(Sender: TObject);
begin

end;

procedure THelpForm.IndexViewSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
RealItem: TIndexItem;
begin
  if not Selected then Exit;
  RealItem := TIndexItem(Item);
  if RealItem.Url <> '' then begin
    DoLoadUrl(RealItem.Url);
  end;
end;

procedure THelpForm.IpHtmlPanel1DocumentOpen(Sender: TObject);
begin
 // StatusBar1.Panels.Items[1] := IpHtmlPanel1.DataProvider.;
end;

procedure THelpForm.IpHtmlPanel1HotChange(Sender: TObject);
begin
  StatusBar1.Panels.Items[0].Text := IpHtmlPanel1.HotURL;
  fHotUrl := IpHtmlPanel1.HotURL;
end;

procedure THelpForm.IpHtmlPanel1HotClick(Sender: TObject);
begin
  AddHistory(fHotUrl);
end;

procedure THelpForm.PopupCopyClick(Sender: TObject);
begin
  IpHtmlPanel1.CopyToClipboard;
end;

procedure THelpForm.ViewMenuContentsClick(Sender: TObject);
begin
  TMenuItem(Sender).Checked := not TMenuItem(Sender).Checked;
  Splitter1.Visible := TMenuItem(Sender).Checked;
  TabPanel.Visible := Splitter1.Visible;

end;

procedure THelpForm.FillTOCTimer(Sender: TObject);
var
 Stream: TMemoryStream;
begin
  if fFillingToc = True then begin
    TTimer(Sender).Interval := 40;
    exit;
  end;
  fFillingToc := True;
  fStopTimer := False;
  ContentsTree.Visible := False;
  TTimer(Sender).Free;
  if fChm <> nil then begin
    Stream := TMemoryStream(fchm.GetObject(fchm.TOCFile));
    if Stream <> nil then begin
      Stream.position := 0;
      //Memo1.Lines.LoadFromStream(Stream);
      with TContentsFiller.Create(ContentsTree, Stream, @fStopTimer) do begin
        DoFill;
        Free;
      end;
    end;
    Stream.Free;
  end;
  ContentsTree.Visible := True;
  fFillingToc := False;
  fStopTimer := False;
end;

procedure THelpForm.ServerMessage(Sender: TObject);
var
  UrlReq: TUrlRequest;
  FileReq:TFileRequest;
  ConReq: TContextRequest;
  Stream: TStream;
begin
  if fServer.PeekMessage(5, True) then begin
    Stream := fServer.MsgData;
    Stream.Position := 0;
    Stream.Read(FileReq, SizeOf(FileReq));
    case FileReq.RequestType of
      rtFile    : begin
                    DoOpenChm(FileReq.FileName);
                  end;
      rtUrl     : begin
                    Stream.Position := 0;
                    Stream.Read(UrlReq, SizeOf(UrlReq));
                    DoOpenChm(UrlReq.FileRequest.FileName);
                    DoLoadUrl(UrlReq.Url);
                  end;
      rtContext : begin
                    Stream.Position := 0;
                    Stream.Read(ConReq, SizeOf(ConReq));
                    DoOpenChm(ConReq.FileRequest.FileName);
                    DoLoadContext(ConReq.HelpContext);
                  end;
    end;
    Self.BringToFront;
  end;
end;

procedure THelpForm.AddHistory(URL: String);
begin
  if fHistoryIndex < fHistory.Count then begin
    while fHistory.Count-1 > fHistoryIndex do
      fHistory.Delete(fHistory.Count-1);
  end;
  fHistory.Add(URL);
  Inc(fHistoryIndex);
end;

procedure THelpForm.DoOpenChm(AFile: String);
var
Stream: TStream;
Timer: TTimer;
begin
  if fHelpFile = AFile then Exit;
  DoCloseChm;
  if not FileExists(AFile) or DirectoryExists(AFile) then
  begin
    Exit;
  end;
  try
    Stream := TFileStream.Create(AFile, fmOpenRead);
    fChm := TChmReader.Create(Stream, True); // fChm becomes responsible for freeing the stream
    if Not(fChm.IsValidFile) then begin      // when the second param is true
      FreeAndNil(fChm);
      DoError(INVALID_FILE_TYPE);
      Exit;
    end;
    TIpChmDataProvider(IpHtmlPanel1.DataProvider).Chm := fChm;
  except
    FreeAndNil(fChm);
    DoError(INVALID_FILE_TYPE);
    Exit;
  end;
  if fChm = nil then Exit;
  fHelpFile := AFile;
  fHistoryIndex := -1;
  fHistory.Clear;
  
  // Fill the table of contents. This actually works very well
  Timer := TIdleTimer.Create(Self);
  if fChm.ObjectExists(fChm.TOCFile) > 5000 then
    Timer.Interval := 500
  else
    Timer.Interval := 5;
  Timer.OnTimer := @FillTOCTimer;
  Timer.Enabled := True;
  ContentsTree.Visible := False;

  Stream := fchm.GetObject(fchm.IndexFile);
  if Stream <> nil then begin
    Stream.position := 0;
    //Memo2.Lines.LoadFromStream(Stream);
    with TIndexFiller.Create(IndexView, Stream) do begin;
      DoFill;
      Free;
    end;
    Stream.Free;
  end;
  
  if fContext > -1 then begin
    DoLoadContext(fContext);
    fContext := -1;
  end
  else if fChm.DefaultPage <> '' then begin
    DoLoadUrl(fChm.DefaultPage);
  end;
  FileMenuCloseItem.Enabled := True;
  if fChm.Title <> '' then Caption := 'LHelp - '+fChm.Title;
end;

procedure THelpForm.DoCloseChm;
begin
  fStopTimer := True;
  if fChm<>nil then begin
    FreeAndNil(fChm);
    FileMenuCloseItem.Enabled := False;
    fContext := -1;
  end;
  Caption := 'LHelp';
  IndexView.Clear;
  fHelpFile := '';
  ContentsTree.Items.Clear;
  IpHtmlPanel1.SetHtml(nil);
  TIpChmDataProvider(IpHtmlPanel1.DataProvider).CurrentPath := '/';
  TIpChmDataProvider(IpHtmlPanel1.DataProvider).Chm := nil;
end;

procedure THelpForm.DoLoadContext(Context: THelpContext);
var
 Str: String;
begin
  if fChm = nil then exit;
  Str := fChm.GetContextUrl(Context);
  if Str <> '' then DoLoadUrl(Str);
end;

procedure THelpForm.DoLoadUrl(Url: String);
begin
  if fChm = nil then exit;
  if fChm.ObjectExists(Url) = 0 then Exit;
  IpHtmlPanel1.OpenURL(Url);
  TIpChmDataProvider(IpHtmlPanel1.DataProvider).CurrentPath := ExtractFileDir(URL)+'/';
  AddHistory(Url);
end;

procedure THelpForm.DoError(Error: Integer);
begin
  //what to do with these errors?
  //INVALID_FILE_TYPE;
end;

procedure THelpForm.ReadCommandLineOptions;
var
  X: Integer;
  IsHandled: array[0..50] of boolean;
begin
  FillChar(IsHandled, 51, 0);
  for  X := 1 to ParamCount do begin
    if LowerCase(ParamStr(X)) = '--ipcname' then begin
      IsHandled[X] := True;
      if X < ParamCount then begin
        fServerName := ParamStr(X+1);
        IsHandled[X+1] := True;
      end;
    end;
    if LowerCase(ParamStr(X)) = '--context' then begin
      IsHandled[X] := True;
      if (X < ParamCount) then
        if TryStrToInt(ParamStr(X+1), fContext) then
          IsHandled[X+1] := True;
    end;
  end;
  // Loop through a second time for the filename
  for X := 1 to ParamCount do
    if not IsHandled[X] then begin
      DoOpenChm(ParamStr(X));
      Break;
    end;
  //we reset the context because at this point the file has been loaded and the
  //context shown
  fContext := -1;
    

end;

procedure THelpForm.StartServer(ServerName: String);
begin
  fServer := TSimpleIPCServer.Create(nil);
  fServer.ServerID := fServerName;
  fServer.Global := True;
  fServer.Active := True;
  fServerTimer := TTimer.Create(nil);
  fServerTimer.OnTimer := @ServerMessage;
  fServerTimer.Interval := 200;
  fServerTimer.Enabled := True;
  ServerMessage(nil);
end;

procedure THelpForm.StopServer;
begin
   if fServer = nil then exit;
   FreeAndNil(fServerTimer);
   if fServer.Active then fServer.Active := False;
   FreeAndNil(fServer);
   
end;

initialization
  {$I unit1.lrs}

end.

