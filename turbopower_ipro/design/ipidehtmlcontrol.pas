{
 *****************************************************************************
 *                                                                           *
 *  See the file COPYING.modifiedLGPL.txt, included in this distribution,        *
 *  for details about the copyright.                                         *
 *                                                                           *
 *  This program is distributed in the hope that it will be useful,          *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
 *                                                                           *
 *****************************************************************************

  Author: Mattias Gaertner

  Abstract:
    Installs a HTML control in the IDE using TIpHtmlPanel.
}
unit IPIDEHTMLControl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, math, LCLProc, Graphics, Controls, Dialogs,
  IpMsg, Ipfilebroker, IpHtml, IDEHelpIntf, LazHelpIntf;

type
  TLazIPHtmlControl = class;

  { TLazIpHtmlDataProvider }

  TLazIpHtmlDataProvider = class(TIpHtmlDataProvider)
  private
    FControl: TLazIPHtmlControl;
  protected
    function DoGetStream(const URL: string): TStream; override;
  public
    property Control: TLazIPHtmlControl read FControl;
  end;

  { TLazIPHtmlControl }

  TLazIPHtmlControl = class(TIpHtmlPanel,TIDEHTMLControlIntf)
    function DataProviderCanHandle(Sender: TObject; const URL: string): Boolean;
    procedure DataProviderCheckURL(Sender: TObject; const URL: string;
      var Available: Boolean; var ContentType: string);
    procedure DataProviderGetHtml(Sender: TObject; const URL: string;
      const {%H-}aPostData: TIpFormDataEntity; var Stream: TStream);
    procedure DataProviderGetImage(Sender: TIpHtmlNode; const URL: string;
      var Picture: TPicture);
    procedure DataProviderLeave(Sender: TIpHtml);
    procedure DataProviderReportReference(Sender: TObject; const URL: string);
  private
    FIDEProvider: TAbstractIDEHTMLProvider;
    FURL: string;
  public
    constructor Create(AOwner: TComponent); override;
    function GetURL: string;
    procedure SetURL(const AValue: string);
    property IDEProvider: TAbstractIDEHTMLProvider read FIDEProvider write FIDEProvider;
    procedure SetHTMLContent(Stream: TStream; const NewURL: string);
    procedure GetPreferredControlSize(out AWidth, AHeight: integer);
  end;

function IPCreateLazIDEHTMLControl(Owner: TComponent;
  var Provider: TAbstractIDEHTMLProvider): TControl;

procedure Register;

implementation

procedure Register;
begin
  CreateIDEHTMLControl:=@IPCreateLazIDEHTMLControl;
end;

function IPCreateLazIDEHTMLControl(Owner: TComponent;
  var Provider: TAbstractIDEHTMLProvider): TControl;
var
  HTMLControl: TLazIPHtmlControl;
begin
  HTMLControl:=TLazIPHtmlControl.Create(Owner);
  Result:=HTMLControl;
  if Provider=nil then
    Provider:=CreateIDEHTMLProvider(HTMLControl);
  Provider.ControlIntf:=HTMLControl;
  HTMLControl.IDEProvider:=Provider;
end;

{ TLazIpHtmlDataProvider }

function TLazIpHtmlDataProvider.DoGetStream(const URL: string): TStream;
begin
  debugln(['TLazIpHtmlDataProvider.DoGetStream ',URL]);
  Result:=Control.IDEProvider.GetStream(URL);
end;

{ TLazIPHtmlControl }

function TLazIPHtmlControl.DataProviderCanHandle(Sender: TObject;
  const URL: string): Boolean;
begin
  debugln(['TLazIPHtmlControl.DataProviderCanHandle URL=',URL]);
  Result:=false;
end;

procedure TLazIPHtmlControl.DataProviderCheckURL(Sender: TObject;
  const URL: string; var Available: Boolean; var ContentType: string);
begin
  debugln(['TLazIPHtmlControl.DataProviderCheckURL URL=',URL]);
  Available:=false;
  ContentType:='';
end;

procedure TLazIPHtmlControl.DataProviderGetHtml(Sender: TObject;
  const URL: string; const aPostData: TIpFormDataEntity; var Stream: TStream);
begin
  debugln(['TLazIPHtmlControl.DataProviderGetHtml URL=',URL]);
  Stream:=nil;
end;

procedure TLazIPHtmlControl.DataProviderGetImage(Sender: TIpHtmlNode;
  const URL: string; var Picture: TPicture);
var
  URLType: string;
  URLPath: string;
  URLParams: string;
  Filename: String;
  Ext: String;
  Stream: TStream;
  NewURL: String;
begin
  //DebugLn(['TIPLazHtmlControl.HTMLGetImageX URL=',URL]);
  if IDEProvider=nil then exit;
  NewURL:=IDEProvider.MakeURLAbsolute(IDEProvider.BaseURL,URL);
  //DebugLn(['TIPLazHtmlControl.HTMLGetImageX NewURL=',NewURL,' Provider.BaseURL=',IDEProvider.BaseURL,' URL=',URL]);

  Picture:=nil;
  Stream:=nil;
  try
    try
      SplitURL(NewURL,URLType,URLPath,URLParams);
      if URLPath='' then
        URLPath:=NewURL;
      Filename:=URLPathToFilename(URLPath);
      Ext:=ExtractFileExt(Filename);
      //DebugLn(['TIPLazHtmlControl.HTMLGetImageX URLPath=',URLPath,' Filename=',Filename,' Ext=',Ext]);
      Picture:=TPicture.Create;
      // quick check if file format is supported (raises an exception)
      Picture.FindGraphicClassWithFileExt(Ext);
      // get stream
      Stream:=IDEProvider.GetStream(NewURL);
      // load picture
      Picture.LoadFromStreamWithFileExt(Stream,Ext);
    finally
      if Stream<>nil then
        IDEProvider.ReleaseStream(NewURL);
    end;
  except
    on E: Exception do begin
      FreeAndNil(Picture);
      DebugLn(['TIPLazHtmlControl.HTMLGetImageX ERROR: ',E.Message]);
    end;
  end;
end;

procedure TLazIPHtmlControl.DataProviderLeave(Sender: TIpHtml);
begin
  //debugln(['TLazIPHtmlControl.DataProviderLeave ']);
end;

procedure TLazIPHtmlControl.DataProviderReportReference(Sender: TObject;
  const URL: string);
begin
  debugln(['TLazIPHtmlControl.DataProviderReportReference URL=',URL]);
end;

constructor TLazIPHtmlControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DefaultFontSize := 8;
  MarginHeight := 0;
  MarginWidth := 0;
  DataProvider:=TLazIpHtmlDataProvider.Create(Self);
  with TLazIpHtmlDataProvider(DataProvider) do begin
    FControl:=Self;
    Name:='TLazIPHtmlControlDataProvider';
    OnCanHandle:=@DataProviderCanHandle;
    OnGetHtml:=@DataProviderGetHtml;
    OnGetImage:=@DataProviderGetImage;
    OnLeave:=@DataProviderLeave;
    OnCheckURL:=@DataProviderCheckURL;
    OnReportReference:=@DataProviderReportReference;
  end;
end;

function TLazIPHtmlControl.GetURL: string;
begin
  Result:=FURL;
end;

procedure TLazIPHtmlControl.SetURL(const AValue: string);
var
  Stream: TStream;
  NewHTML: TIpHtml;
  NewURL: String;
  ok: Boolean;
begin
  if IDEProvider=nil then raise Exception.Create('TIPLazHtmlControl.SetURL missing Provider');
  if FURL=AValue then exit;
  NewURL:=IDEProvider.MakeURLAbsolute(IDEProvider.BaseURL,AValue);
  if FURL=NewURL then exit;
  FURL:=NewURL;
  try
    Stream:=IDEProvider.GetStream(FURL);
    ok:=false;
    NewHTML:=nil;
    try
      NewHTML:=TIpHtml.Create; // Beware: Will be freed automatically TIpHtmlPanel
      NewHTML.LoadFromStream(Stream);
      ok:=true;
    finally
      if not ok then NewHTML.Free;
      IDEProvider.ReleaseStream(FURL);
    end;
    SetHtml(NewHTML);
  except
    on E: Exception do begin
      MessageDlg('Unable to open HTML file',
        'HTML File: '+FURL+#13
        +'Error: '+E.Message,mtError,[mbCancel],0);
    end;
  end;
end;

procedure TLazIPHtmlControl.SetHTMLContent(Stream: TStream; const NewURL: string
  );
var
  NewHTML: TIpHtml;
begin
  FURL:=NewURL;
  NewHTML:=TIpHtml.Create; // Beware: Will be freed automatically by TIpHtmlPanel
  SetHtml(NewHTML);
  NewHTML.LoadFromStream(Stream);
end;

procedure TLazIPHtmlControl.GetPreferredControlSize(out AWidth, AHeight: integer);
begin
  with GetContentSize do
  begin
    AWidth := Max(0,Min(cx,10000));
    AHeight := Max(0,Min(cy,10000));
  end;
  debugln(['TLazIPHtmlControl.GetPreferredControlSize Width=',AWidth,' Height=',AHeight]);
end;

end.

