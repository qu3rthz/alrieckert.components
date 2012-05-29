unit lr_SQLQuery;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Graphics, LR_Class, LR_DBComponent, sqldb;

type

  { TLRSQLQuery }

  TLRSQLQuery = class(TLRDataSetControl)
  private
    FDatabase: string;
    procedure SetDatabase(AValue: string);
  protected
    function GetSQL: TStringList;virtual;
    procedure SetSQL(AValue: TStringList);virtual;
    procedure AfterLoad;override;
  public
    constructor Create(AOwnerPage:TfrPage); override;

    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); override;
    procedure SaveToXML(XML: TLrXMLConfig; const Path: String); override;
  published
    property SQL:TStringList read GetSQL write SetSQL;
    property Database:string read FDatabase write SetDatabase;
  end;

  { TLRSQLConnection }

  TLRSQLConnection = class(TfrNonVisualControl)
  private
    FConnected:boolean;
    function GetCharSet: string;
    function GetConnected: Boolean;
    function GetDatabase: string;
    function GetHostName: string;
    function GetLoginPrompt: Boolean;
    function GetPassword: string;
    function GetUserName: string;
    procedure SetCharSet(AValue: string);
    procedure SetConnected(AValue: Boolean);
    procedure SetDatabase(AValue: string);
    procedure SetHostName(AValue: string);
    procedure SetLoginPrompt(AValue: Boolean);
    procedure SetPassword(AValue: string);
    procedure SetUserName(AValue: string);
  protected
    FConnection: TSQLConnection;
    FSQLTransaction:TSQLTransaction;
    procedure SetName(const AValue: string); override;
    procedure AfterLoad;override;
  public
    constructor Create(AOwnerPage:TfrPage); override;
    destructor Destroy; override;

    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); override;
    procedure SaveToXML(XML: TLrXMLConfig; const Path: String); override;
  published
    property CharSet: string read GetCharSet write SetCharSet;
    property Connected: Boolean read GetConnected write SetConnected;
    property LoginPrompt: Boolean read GetLoginPrompt write SetLoginPrompt;
    property HostName: string read GetHostName write SetHostName;
    property DatabaseName: string read GetDatabase write SetDatabase;
    property UserName: string read GetUserName write SetUserName;
    property Password: string read GetPassword write SetPassword;
  end;


implementation
uses LR_Utils, DBPropEdits, PropEdits;

var
  lrBMP_SQLQuery:TBitmap = nil;

procedure InitLRComp;
begin
  if not assigned(lrBMP_SQLQuery) then
  begin
    lrBMP_SQLQuery := TbitMap.Create;
    lrBMP_SQLQuery.LoadFromLazarusResource('TLRSQLQuery');
    frRegisterObject(TLRSQLQuery, lrBMP_SQLQuery, 'TLRSQLQuery', nil, otlUIControl, nil);
  end;
end;

{ TLRSQLConnection }

function TLRSQLConnection.GetCharSet: string;
begin
  Result:=FConnection.CharSet;
end;

function TLRSQLConnection.GetConnected: Boolean;
begin
  Result:=FConnection.Connected;
end;

function TLRSQLConnection.GetDatabase: string;
begin
  Result:=FConnection.DatabaseName;
end;

function TLRSQLConnection.GetHostName: string;
begin
  Result:=FConnection.HostName;
end;

function TLRSQLConnection.GetLoginPrompt: Boolean;
begin
  Result:=FConnection.LoginPrompt;
end;

function TLRSQLConnection.GetPassword: string;
begin
  Result:=FConnection.Password;
end;

function TLRSQLConnection.GetUserName: string;
begin
  Result:=FConnection.UserName;
end;

procedure TLRSQLConnection.SetCharSet(AValue: string);
begin
  FConnection.CharSet:=AValue;
end;

procedure TLRSQLConnection.SetConnected(AValue: Boolean);
begin
  FConnection.Connected:=AValue;
end;

procedure TLRSQLConnection.SetDatabase(AValue: string);
begin
  FConnection.DatabaseName:=AValue;
end;

procedure TLRSQLConnection.SetHostName(AValue: string);
begin
  FConnection.HostName:=AValue;
end;

procedure TLRSQLConnection.SetLoginPrompt(AValue: Boolean);
begin
  FConnection.LoginPrompt:=AValue;
end;

procedure TLRSQLConnection.SetPassword(AValue: string);
begin
  FConnection.Password:=AValue;
end;

procedure TLRSQLConnection.SetUserName(AValue: string);
begin
  FConnection.UserName:=AValue;
end;

procedure TLRSQLConnection.SetName(const AValue: string);
begin
  inherited SetName(AValue);
  FConnection.Name:=Name;
end;

procedure TLRSQLConnection.AfterLoad;
begin
  inherited AfterLoad;
  FConnection.Connected:=FConnected;
end;

constructor TLRSQLConnection.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  FSQLTransaction:=TSQLTransaction.Create(OwnerForm);
end;

destructor TLRSQLConnection.Destroy;
begin
  if not (Assigned(OwnerPage) and (OwnerPage is TfrPageDialog)) then
  begin
    FreeAndNil(FSQLTransaction);
    FreeAndNil(FConnection);
  end;
  inherited Destroy;
end;

procedure TLRSQLConnection.LoadFromXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited LoadFromXML(XML, Path);
  FConnection.LoginPrompt:=XML.GetValue(Path + 'LoginPrompt/Value'{%H-}, false);
  FConnection.CharSet:=XML.GetValue(Path + 'CharSet/Value'{%H-}, '');

  FConnection.HostName:=XML.GetValue(Path + 'HostName/Value'{%H-}, '');
  FConnection.DatabaseName:=XML.GetValue(Path + 'Database/Value'{%H-}, '');
  FConnection.UserName:=XML.GetValue(Path + 'User/Value'{%H-}, '');
  FConnection.Password:=XML.GetValue(Path + 'Password/Value'{%H-}, '');

  FConnected:=XML.GetValue(Path + 'Connected/Value'{%H-}, false);
end;

procedure TLRSQLConnection.SaveToXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited SaveToXML(XML, Path);
  XML.SetValue(Path + 'LoginPrompt/Value'{%H-}, FConnection.LoginPrompt);
  XML.SetValue(Path + 'CharSet/Value'{%H-}, FConnection.CharSet);

  XML.SetValue(Path + 'HostName/Value'{%H-}, FConnection.HostName);
  XML.SetValue(Path + 'Database/Value'{%H-}, FConnection.DatabaseName);
  XML.SetValue(Path + 'User/Value'{%H-}, FConnection.UserName);
  XML.SetValue(Path + 'Password/Value'{%H-}, FConnection.Password);
  XML.SetValue(Path + 'Connected/Value'{%H-}, FConnection.Connected);
end;

{ TLRSQLQuery }

procedure TLRSQLQuery.SetDatabase(AValue: string);
var
  D:TComponent;
begin
  if FDatabase=AValue then Exit;
  FDatabase:=AValue;

  DataSet.Active:=false;
  D:=frFindComponent(TSQLQuery(DataSet).Owner, FDatabase);
  if Assigned(D) and (D is TSQLConnection)then
    TSQLQuery(DataSet).DataBase:=TSQLConnection(D);
end;

function TLRSQLQuery.GetSQL: TStringList;
begin
  Result:=TSQLQuery(DataSet).SQL;
end;

procedure TLRSQLQuery.SetSQL(AValue: TStringList);
begin
  TSQLQuery(DataSet).SQL.Assign(AValue);
end;

procedure TLRSQLQuery.AfterLoad;
var
  D:TComponent;
begin
  D:=frFindComponent(DataSet.Owner, FDatabase);
  if Assigned(D) and (D is TSQLConnection)then
  begin
    TSQLQuery(DataSet).DataBase:=TSQLConnection(D);
    DataSet.Active:=FActive;
  end;
end;

constructor TLRSQLQuery.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  BaseName := 'lrSQLQuery';
  DataSet:=TSQLQuery.Create(OwnerForm);
end;

procedure TLRSQLQuery.LoadFromXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited LoadFromXML(XML, Path);
  SQL.Text  := XML.GetValue(Path+'SQL/Value'{%H-}, '');
  FDatabase:= XML.GetValue(Path+'Database/Value'{%H-}, '');
end;

procedure TLRSQLQuery.SaveToXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited SaveToXML(XML, Path);
  XML.SetValue(Path+'SQL/Value', SQL.Text);
  XML.SetValue(Path+'Database/Value', FDatabase);
end;

type

  { TLRZConnectionProtocolProperty }

  TLRSQLConnectionProtocolProperty = class(TFieldProperty)
  public
    procedure FillValues(const Values: TStringList); override;
  end;

{ TLRZConnectionProtocolProperty }

procedure TLRSQLConnectionProtocolProperty.FillValues(const Values: TStringList);
begin
  if (GetComponent(0) is TLRSQLQuery) then
    frGetComponents(nil, TSQLConnection, Values, nil);
end;

initialization
  {$I lrsqldb_img.inc}
  InitLRComp;

  RegisterPropertyEditor(TypeInfo(string), TLRSQLQuery, 'Database', TLRSQLConnectionProtocolProperty);
finalization
  if Assigned(lrBMP_SQLQuery) then
    FreeAndNil(lrBMP_SQLQuery);
end.

