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
    Demonstrating, how to add a method to a class and extending the uses section.
}
program AddEventMethod;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, CodeCache, CodeToolManager, SimpleUnit1, FileProcs,
  CodeToolsConfig, CodeCompletionTool, ExtCtrls;
  
const
  ConfigFilename = 'codetools.config';
var
  Options: TCodeToolsOptions;
  Filename: string;
  Code: TCodeBuffer;
begin
  // setup the Options
  Options:=TCodeToolsOptions.Create;

  // To not parse the FPC sources every time, the options are saved to a file.
  if FileExists(ConfigFilename) then
    Options.LoadFromFile(ConfigFilename);

  // setup your paths
  Options.FPCPath:='/usr/bin/ppc386';
  Options.FPCSrcDir:=ExpandFileName('~/freepascal/fpc');
  Options.LazarusSrcDir:=ExpandFileName('~/pascal/lazarus');

  // optional: ProjectDir and TestPascalFile exists only to easily test some
  // things.
  Options.ProjectDir:=GetCurrentDir+'/scanexamples/';
  Options.TestPascalFile:=Options.ProjectDir+'addeventexample.pas';

  // init the codetools
  if not Options.UnitLinkListValid then
    writeln('Scanning FPC sources may take a while ...');
  CodeToolBoss.Init(Options);

  // save the options and the FPC unit links results.
  Options.SaveToFile(ConfigFilename);

  // load the file
  Filename:=Options.TestPascalFile;
  Code:=CodeToolBoss.LoadFile(Filename,false,false);
  if Code=nil then
    raise Exception.Create('loading failed '+Filename);

  // Example 1: add a method compatible to TTabChangingEvent
  // TTabChangingEvent is used in ComCtrls, but defined in ExtCtrls.
  // The codetools will search TTabChangingEvent and will add ExtCtrls to the
  // uses section.
  if CodeToolBoss.CreatePublishedMethod(Code,'TForm1','NewMethod',
    typeinfo(TTabChangingEvent),false,'ComCtrls') then
  begin
    writeln('Method added: ');
    writeln(Code.Source);
  end else begin
    raise Exception.Create('Adding method failed');
  end;
end.

