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
    An IDE window for context sensitive codetools.
}
unit CodyFrm;

{$mode objfpc}{$H+}

{$R *.lfm}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  // codetools
  //FileProcs, CodeToolManager, SourceLog, CodeCache, EventCodeTool,
  //LinkScanner, PascalParserTool, CodeTree,
  // IDEIntf
  //LazIDEIntf, SrcEditorIntf, IDEDialogs,
  // cody
  CodyStrConsts;

type

  TCodyWindow = class(TForm)
  private
  public
  end;

var
  CodyWindow: TCodyWindow;

implementation


end.

