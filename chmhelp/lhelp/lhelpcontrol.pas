{ Copyright (C) <2005> <Andrew Haines> lhelpcontrol.pas

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
unit LHelpControl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SimpleIPC, Process;

type
  TRequestType = (rtFile, rtUrl, rtContext);
  
  TFileRequest = record
    RequestType: TRequestType;
    FileName: array[0..512] of char;
  end;
  TUrlRequest = record
    FileRequest: TFileRequest;
    Url: array[0..512] of char;
  end;
  TContextRequest = record
    FileRequest: TFileRequest;
    HelpContext: THelpContext;
  end;
  
  { TLHelpConnection }

  TLHelpConnection = class(TObject)
  private
    fIniqueID: String;
    fServerString: String;
    fClient: TSimpleIPCClient;
  public
    constructor Create;
    destructor Destroy;
    function StartHelpServer(NameForServer: String; ServerEXE: String = ''): Boolean;
    procedure OpenURL(HelpFileName: String; Url: String);
    procedure OpenContext(HelpFileName: String; Context: THelpContext);
    procedure OpenFile(HelpFileName: String);
  end;
  

implementation

{ TLHelpConnection }


constructor TLHelpConnection.Create;
begin
  fClient := TSimpleIPCClient.Create(nil);
end;

destructor TLHelpConnection.Destroy;
begin
  if fCLient.Active then fClient.Active:=False;
  fClient.Free;
  inherited Destroy;

end;

function TLHelpConnection.StartHelpServer(NameForServer: String;
  ServerEXE: String): Boolean;
var
  X: Integer;
begin
  Result := False;
  fClient.Active := False;
  fClient.ServerID := NameForServer;
  if not fClient.ServerRunning then begin
    with TProcess.Create(nil) do begin
      CommandLine := ServerExe + ' --ipcname ' + NameForServer;
      Execute;
    end;
    // give the server some time to get started
    for X := 0 to 40 do begin
      if not fClient.ServerRunning then Sleep(200);
    end;
  end;
  if fClient.ServerRunning then begin
    fClient.Active := True;
    Result := True;
  end;
end;

procedure TLHelpConnection.OpenURL(HelpFileName: String; Url: String);
var
UrlRequest: TUrlRequest;
Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  UrlRequest.FileRequest.FileName := HelpFileName+#0;
  UrlRequest.FileRequest.RequestType := rtURL;
  UrlRequest.Url := Url+#0;
  Stream.Write(UrlRequest,SizeOf(UrlRequest));
  fClient.SendMessage(mtUnknown, Stream);
  // Do I need to free the stream?? the example doesn't
end;

procedure TLHelpConnection.OpenContext(HelpFileName: String;
  Context: THelpContext);
var
ContextRequest: TContextRequest;
Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  ContextRequest.FileRequest.FileName := HelpFileName+#0;
  ContextRequest.FileRequest.RequestType := rtContext;
  ContextRequest.HelpContext := Context;
  Stream.Write(ContextRequest, SizeOf(ContextRequest));
  fClient.SendMessage(mtUnknown, Stream);
  // Do I need to free the stream?? the example doesn't
end;

procedure TLHelpConnection.OpenFile(HelpFileName: String);
var
FileRequest : TFileRequest;
Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  FileRequest.RequestType := rtFile;
  FileRequest.FileName := HelpFileName+#0;
  Stream.Write(FileRequest, SizeOf(FileRequest));
  fClient.SendMessage(mtUnknown, Stream);
  // Do I need to free the stream?? the example doesn't
end;

end.

