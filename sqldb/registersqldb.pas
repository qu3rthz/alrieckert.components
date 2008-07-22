{  $Id$  }
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

  Author: Joost van der Sluis
  
  This unit registers the sqldb components of the FCL.
}
unit registersqldb;

{$mode objfpc}{$H+}
{$IFNDEF win64}
{$DEFINE HASMYSQL4CONNECTION}
{$DEFINE HASORACLECONNECTION}
{$DEFINE HASPQCONNECTION}
{$ENDIF}

{ SQLITE }
{$IFNDEF WIN64}
{$IFNDEF VER2_2_0}
{$DEFINE HASSQLITE3CONNECTION}
{$ENDIF}
{$ENDIF}

{ SQLSCRIPT }
{$IFNDEF VER2_2_0}
{$DEFINE HASSQLSCRIPT}
{$ENDIF}
interface

uses
  Classes, SysUtils, LResources, sqldb, ibconnection, odbcconn,
{$IFDEF HASPQCONNECTION}
  pqconnection,
{$ENDIF}
{$IFDEF HASORACLECONNECTION}
  oracleconnection,
{$ENDIF}
{$IFDEF HASMYSQL4CONNECTION}
  mysql40conn, mysql41conn,
{$ENDIF}
{$IFDEF HASSQLITE3CONNECTION}
  sqlite3conn,
{$ENDIF}
  mysql50conn,
  propedits,
  LazarusPackageIntf;

procedure Register;

implementation

procedure RegisterUnitSQLdb;
begin
  RegisterComponents('SQLdb',[TSQLQuery,
                              TSQLTransaction,
{$IFDEF HASSQLSCRIPT}
                              TSQLScript,
                              TSQLConnector,
{$ENDIF}
{$IFDEF HASPQCONNECTION}
                              TPQConnection,
{$ENDIF}
{$IFDEF HASORACLECONNECTION}
                              TOracleConnection,
{$ENDIF}
                              TODBCConnection,
{$IFDEF HASMYSQL4CONNECTION}
                              TMySQL40Connection,
                              TMySQL41Connection,
{$ENDIF}
{$IFDEF HASSQLITE3CONNECTION}
                              TSQLite3Connection,
{$ENDIF}
                              TMySQL50Connection,
                              TIBConnection]);
end;

Type
  TSQLFirebirdFileNamePropertyEditor=class(TFileNamePropertyEditor)
  protected
    function GetFilter: String; override;
    function GetInitialDirectory: string; override;
  end;

Resourcestring
  SFireBirdDatabases = 'Firebird databases';
  SInterbaseDatabases = 'Interbase databases';
  
{ TDbfFileNamePropertyEditor }

function TSQLFirebirdFileNamePropertyEditor.GetFilter: String;
begin
  Result := sFireBirdDatabases+' (*.fb)|*.fb;*.fdb';
  Result := Result + sInterbaseDatabases  +' (*.gdb)|*.gdb;*.GDB';
  Result:= Result+ '|'+ inherited GetFilter;
end;

function TSQLFirebirdFileNamePropertyEditor.GetInitialDirectory: string;
begin
  Result:= (GetComponent(0) as TSQLConnection).DatabaseName;
  Result:= ExtractFilePath(Result);
end;


procedure Register;
begin
  RegisterPropertyEditor(TypeInfo(AnsiString),
    TIBConnection, 'DatabaseName', TSQLFirebirdFileNamePropertyEditor);

  RegisterUnit('sqldb',@RegisterUnitSQLdb);
end;

initialization
 {$i registersqldb.lrs}

end.
