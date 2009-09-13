unit LHelpControl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, SimpleIPC, Process, UTF8Process;

type
  TRequestType = (rtFile, rtUrl, rtContext);

  TLHelpResponse = (srNoAnswer, srUnknown, srSuccess, srInvalidFile, srInvalidURL, srInvalidContext);

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

  TProcedureOfObject = procedure of object;
  
  { TLHelpConnection }

  TLHelpConnection = class(TObject)
  private
    FProcessWhileWaiting: TProcedureOfObject;
    fServerOut: TSimpleIPCClient; // sends messages to lhelp
    fServerIn:  TSimpleIPCServer; // recieves messages from lhelp
    function  WaitForMsgResponse: TLHelpResponse;
    function  SendMessage(Stream: TStream): TLHelpResponse;
  public
    constructor Create;
    destructor Destroy; override;
    function ServerRunning: Boolean;
    function StartHelpServer(NameForServer: String; ServerEXE: String = ''): Boolean;

    function OpenURL(HelpFileName: String; Url: String): TLHelpResponse;
    function OpenContext(HelpFileName: String; Context: THelpContext): TLHelpResponse;
    function OpenFile(HelpFileName: String): TLHelpResponse;

    property ProcessWhileWaiting: TProcedureOfObject read FProcessWhileWaiting write FProcessWhileWaiting;
  end;
  

implementation

{ TLHelpConnection }

function TLHelpConnection.WaitForMsgResponse: TLHelpResponse;
var
  I: Integer;
  Stream: TStream;
  WaitTime: Integer = 5000;
begin
  Result := srNoAnswer;
  while WaitTime >= 0 do
  begin
    Dec(WaitTime, 50);
    if fServerIn.PeekMessage(50, True) then
    begin
      Stream := fServerIn.MsgData;
      Stream.Position:=0;
      Result := TLHelpResponse(Stream.ReadDWord);
      Exit;
    end;
    if Assigned(FProcessWhileWaiting) then FProcessWhileWaiting();
  end;
end;

function TLHelpConnection.SendMessage(Stream: TStream): TLHelpResponse;
begin
  fServerOut.SendMessage(mtUnknown, Stream);
  Result := WaitForMsgResponse;
end;

constructor TLHelpConnection.Create;
begin
  fServerOut := TSimpleIPCClient.Create(nil);
  fServerIn  := TSimpleIPCServer.Create(nil);
end;

destructor TLHelpConnection.Destroy;
begin
  if fServerOut.Active then
    fServerOut.Active:=False;
  if fServerIn.Active then
    fServerIn.Active:=False;
  fServerOut.Free;
  fServerIn.Free;
  inherited Destroy;

end;

function TLHelpConnection.ServerRunning: Boolean;
begin
  Result := (fServerOut<>nil) and (fServerOut.Active);
end;

function TLHelpConnection.StartHelpServer(NameForServer: String;
  ServerEXE: String): Boolean;
var
  X: Integer;
begin
  Result := False;

  fServerIn.Active := False;
  fServerIn.ServerID := NameForServer+'client';
  fServerIn.Global := True;
  fServerIn.Active := True;

  fServerOut.Active := False;
  fServerOut.ServerID := NameForServer;
  if not fServerOut.ServerRunning then begin
    with TProcessUTF8.Create(nil) do begin
      CommandLine := ServerExe + ' --ipcname ' + NameForServer;
      Execute;
    end;
    // give the server some time to get started
    for X := 0 to 40 do begin
      if not fServerOut.ServerRunning then Sleep(200);
    end;
  end;
  if fServerOut.ServerRunning then begin
    fServerOut.Active := True;
    Result := True;
  end;
end;

function TLHelpConnection.OpenURL(HelpFileName: String; Url: String): TLHelpResponse;
var
UrlRequest: TUrlRequest;
Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  UrlRequest.FileRequest.FileName := HelpFileName+#0;
  UrlRequest.FileRequest.RequestType := rtURL;
  UrlRequest.Url := Url+#0;
  Stream.Write(UrlRequest,SizeOf(UrlRequest));
  Result := SendMessage(Stream);

  // Do I need to free the stream?? the example doesn't


end;

function TLHelpConnection.OpenContext(HelpFileName: String;
  Context: THelpContext) : TLHelpResponse;
var
ContextRequest: TContextRequest;
Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  ContextRequest.FileRequest.FileName := HelpFileName+#0;
  ContextRequest.FileRequest.RequestType := rtContext;
  ContextRequest.HelpContext := Context;
  Stream.Write(ContextRequest, SizeOf(ContextRequest));
  Result := SendMessage(Stream);
  // Do I need to free the stream?? the example doesn't
end;

function TLHelpConnection.OpenFile(HelpFileName: String): TLHelpResponse;
var
FileRequest : TFileRequest;
Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  FileRequest.RequestType := rtFile;
  FileRequest.FileName := HelpFileName+#0;
  Stream.Write(FileRequest, SizeOf(FileRequest));
  Result := SendMessage(Stream);
  // Do I need to free the stream?? the example doesn't
end;

end.

