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
    Demonstrating, how to parse a ppu file with the codetools.
}
program PPUDependencies;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, PPUParser;

var
  PPU: TPPU;
  Filename: String;
begin
  if (Paramcount<1) then begin
    writeln('Usage:');
    writeln('  ',ParamStr(0),' <ppu filename>');
    Halt;
  end;

  Filename:=ParamStr(1);

  PPU:=TPPU.Create;
  try
    PPU.LoadFromFile(Filename);
    PPU.Dump('');
  finally
    PPU.Free;
  end;
end.

