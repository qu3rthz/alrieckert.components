{
 ***************************************************************************
                                osprinters.pas
                                ------------
                               Printer object
                     Initial Revision  : 09 Mars 2005

 ***************************************************************************

 *****************************************************************************
 *                                                                           *
 *  This file is part of the Lazarus Component Library (LCL)                 *
 *                                                                           *
 *  See the file COPYING.LCL, included in this distribution,                 *
 *  for details about the copyright.                                         *
 *                                                                           *
 *  This program is distributed in the hope that it will be useful,          *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
 *                                                                           *
 *****************************************************************************

  Author: Olivier

  Abstract :
    Unit to centralize the implementation of Printer according to the target OS

  history
    09/03/2005 OG - Create
-----------------------------------------------------------------------------}
unit OSPrinters;

{$mode objfpc}{$H+}

interface

{$IFDEF LINUX}
{$I ./linux/cupsprinters_h.inc}
{$ENDIF}

{$IFDEF WIN32}
{$I ./win32/winprinters_h.inc}
{$ENDIF}

implementation

{$IFDEF LINUX}
{$I ./linux/cupsprinters.inc}
{$ENDIF}

{$IFDEF WIN32}
{$I ./win32/winprinters.inc}
{$ENDIF}

end.

