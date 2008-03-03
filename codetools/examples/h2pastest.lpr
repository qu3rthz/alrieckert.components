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
    Demonstration of how to convert c header files to pascal interfaces.
    
  Usage:
    h2pastest [filename.h]
}
program H2PasTest;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, CodeCache, CodeToolManager, FileProcs,
  CodeAtom, CodeTree, NonPascalCodeTools, CCodeParserTool;
  
const
  ConfigFilename = 'codetools.config';
var
  Filename: String;
  Code: TCodeBuffer;
  Tool: TCCodeParserTool;
  Caret: TCodeXYPosition;
begin
  try
    CodeToolBoss.SimpleInit(ConfigFilename);
    Filename:=GetCurrentDir+'/scanexamples/test.h';
    if ParamCount=1 then
      Filename:=ParamStr(1);

    // Step 1: load the file
    Code:=CodeToolBoss.LoadFile(Filename,false,false);
    if Code=nil then
      raise Exception.Create('loading failed '+Filename);

    Tool:=TCCodeParserTool.Create;
    Tool.Parse(Code);
    Tool.WriteDebugReport;
    Tool.Free;
  except
    on E: ECCodeParserException do begin
      Tool:=ECCodeParserException(E).Sender;
      Tool.CleanPosToCaret(Tool.LastErrorReportPos,Caret);
      writeln(Caret.Code.Filename+'('+IntToStr(Caret.Y)+','+IntToStr(Caret.X)+')'+' Error: '+E.Message);
    end;
    on E: Exception do begin
      writeln(E.Message);
    end;
  end;
end.

