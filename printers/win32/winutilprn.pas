{ force CRLF fix }

{
  Author: Olivier Guilbaud

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

  Abstract:
    This unit provide an access at Printers spool and other functions for manage
    the printers on Win32

  Documentations
    - Wine project
    - Microsoft MSDN Web
}

unit WinUtilPrn;

{$mode objfpc}{$H+}

interface

{$IFNDEF WIN32}
//This unit it's reserved to Win32
{$ENDIF}

uses
  Classes, SysUtils,LCLType;

const
  {$i winutilprnconst.inc}

  LibWinSpool = 'winspool.drv';

type
  PDevNames = ^tagDEVNAMES;
  tagDEVNAMES = record
    wDriverOffset: Word;
    wDeviceOffset: Word;
    wOutputOffset: Word;
    wDefault: Word;
  end;

  TFcntHook = function(Wnd: HWND; uiMsg: UINT; wParam: WPARAM; lParam: LPARAM): UINT stdcall;

  tagPD=packed Record
    lStructSize  : DWORD;
    hWndOwner    : HWND;
    hDevMode     : HGLOBAL;
    hDevNames    : HGLOBAL;
    hDC          : HDC;
    Flags        : DWORD;
    nFromPage    : Word;
    nToPage      : Word;
    nMinPage     : Word;
    nMaxPage     : Word;
    nCopies      : Word;
    hInstance    : HINST;
    lCustData    : LPARAM;
    lpfnPrintHook: TFcntHook;
    lpfnSetupHook: TFcntHook;
    lpPrintTemplateName: PChar;
    lpSetupTemplateName: PChar;
    hPrintTemplate     : HGLOBAL;
    hSetupTemplate     : HGLOBAL;
  end;

  PDeviceMode = ^TDeviceMode;
  TDeviceMode = packed Record
    dmDeviceName      : array[0..31] of AnsiChar;
    dmSpecVersion     : Word;
    dmDriverVersion   : Word;
    dmSize            : Word;
    dmDriverExtra     : Word;
    dmFields          : DWORD;
    dmOrientation     : SHORT;
    dmPaperSize       : SHORT;
    dmPaperLength     : SHORT;
    dmPaperWidth      : SHORT;
    dmScale           : SHORT;
    dmCopies          : SHORT;
    dmDefaultSource   : SHORT;
    dmPrintQuality    : SHORT;
    dmColor           : SHORT;
    dmDuplex          : SHORT;
    dmYResolution     : SHORT;
    dmTTOption        : SHORT;
    dmCollate         : SHORT;
    dmFormName        : Array[0..31] of AnsiChar;
    dmLogPixels       : Word;
    dmBitsPerPel      : DWORD;
    dmPelsWidth       : DWORD;
    dmPelsHeight      : DWORD;
    dmDisplayFlags    : DWORD;
    dmDisplayFrequency: DWORD;
    dmICMMethod       : DWORD;
    dmICMIntent       : DWORD;
    dmMediaType       : DWORD;
    dmDitherType      : DWORD;
    dmICCManufacturer : DWORD;
    dmICCModel        : DWORD;
    dmPanningWidth    : DWORD;
    dmPanningHeight   : DWORD;
  end;

  PPrinterDefaults = ^_PRINTER_DEFAULTS;
  _PRINTER_DEFAULTS = record
    pDatatype    : PChar;
    pDevMode     : PDeviceMode;
    DesiredAccess: DWord;
  end;

  //Size and ImageableArea Specifies the width and height,
  //in thousandths of millimeters, of the form
  PFORM_INFO_1   =^_FORM_INFO_1;
  _FORM_INFO_1    = Record
     Flags        : DWORD;
     pName        : PChar;
     Size         : TSize;
     ImageableArea: TRect;
  end;

  TDocInfo = record
    cbSize      : Integer;
    lpszDocName : PChar;
    lpszOutput  : PChar;
    lpszDatatype: PChar;
    fwType      : DWORD;
  end;

  PPRINTER_INFO_1 = ^_PRINTER_INFO_1;
  _PRINTER_INFO_1 = Record
     Flags        : DWORD;
     pDescription : PChar;
     pName        : PChar;
     pComment     : PChar;
  end;

  PPRINTER_INFO_2 = ^_PRINTER_INFO_2;
  _PRINTER_INFO_2 = Record
     pServerName     : PChar;
     pPrinterName    : PChar;
     pShareName      : PChar;
     pPortName       : PChar;
     pDriverName     : PChar;
     pComment        : PChar;
     pLocation       : PChar;
     pDevMode        : PDeviceMode;
     pSepFile        : PChar;
     pPrintProcessor : PChar;
     pDatatype       : PChar;
     pParameters     : PChar;
     pSecurityDescriptor : Pointer;
     Attributes      : DWORD;
     Priority        : DWORD;
     DefaultPriority : DWORD;
     StartTime       : DWORD;
     UntilTime       : DWORD;
     Status          : DWORD;
     cJobs           : DWORD;
     AveragePPM      : DWORD;
  end;

  PPRINTER_INFO_4 = ^_PRINTER_INFO_4;
  _PRINTER_INFO_4 = Record
     pPrinterName : PChar;
     pServerName  : PChar;
     Attributes   : DWORD;
  end;

  PPRINTER_INFO_5 = ^_PRINTER_INFO_5;
  _PRINTER_INFO_5 = Record
     pPrinterName : PChar;
     pPortName    : PChar;
     Attributes   : DWORD;
     DeviceNotSelectedTimeout : DWORD;
     TransmissionRetryTimeout : DWORD;
  end;


function OpenPrinter(pPrinterName : PChar;           // printer or server name
                 var phPrinter    : THandle;         // printer or server handle
                     pDefaults    : PPrinterDefaults // printer defaults
                     ) : BOOL; stdCall; external LibWinSpool name 'OpenPrinterA';

function ClosePrinter(hPrinter : THandle  //handle to printer object
                     ) : BOOL;  stdCall; external LibWinSpool name 'ClosePrinter';

function EnumPrinters(Flags: DWORD;  //Printer objet type
                      Name : PChar;  //Name of printer object
                      Level: DWORD;  //Information level
                      pPrinterEnum: Pointer; //Printer information buffer
                      cbBuf: DWORD; //Size of printer information buffer
                  var pcbNeeded,    //Bytes recieved or required
                      pcReturned: DWORD //Number of printers enumerated
                      ): BOOL; stdcall; external LibWinSpool name 'EnumPrintersA';
{Unsuported on W95/98/Me :o(
Function EnumForms(
      hPrinter  : THandle;  // handle to printer object
      Level     : DWORD;    // data level
      pForm     : Pointer;  // form information buffer
     cbBuf     : DWord;    // size of form information buffer
  var pcbNeeded : DWORD;    // bytes received or required
  var pcReturned: DWORD     // number of forms received

): BOOL; stdcall; external LibWinSpool name 'EnumFormsA';}

{Function not compatible with all versions of Windows
function GetDefaultPrinter(
               pszBuffer   : PChar; // printer name buffer
           var pcchBuffer  : DWord  // size of name buffer
           ) : BOOL stdcall; external LibWinSpool name 'GetDefaultPrinterA';
}

function AdvancedDocumentProperties(
             hWnd           : HWND;        // handle to parent window
             hPrinter       : THandle;     // handle to printer object
             pDeviceName    : PChar;       // driver name
             pDevModeOutput : PDeviceMode; // modified device mode data
             pDevModeInput  : PDeviceMode  // original device mode data
             ): Longint; stdcall; external LibWinSpool name 'AdvancedDocumentPropertiesA';

function DeviceCapabilities(pDevice, pPort: PChar; fwCapability: Word; pOutput: PChar;
  DevMode: PDeviceMode): Integer; stdcall; external LibWinSpool name 'DeviceCapabilitiesA';

function GetProfileString(lpAppName:PChar; lpKeyName:PChar; lpDefault:PChar; lpReturnedString:PChar; nSize:DWORD):DWORD; stdcall; external 'kernel32' name 'GetProfileStringA';

function PrintDlg(var lppd : tagPD): BOOL; stdcall; external 'comdlg32.dll'  name 'PrintDlgA';
function CommDlgExtendedError: DWORD; stdcall; external 'comdlg32.dll'  name 'CommDlgExtendedError';

function CreateIC(lpszDriver, lpszDevice, lpszOutput: PChar; lpdvmInit: PDeviceMode): HDC; stdcall; external 'gdi32.dll' name 'CreateICA';
function CreateDC(lpszDriver, lpszDevice, lpszOutput: PChar; lpdvmInit: PDeviceMode): HDC; stdcall; external 'gdi32.dll' name 'CreateDCA';
function DeleteDC(DC: HDC): BOOL; stdcall; external 'gdi32.dll' name 'DeleteDC';
function StartDoc(DC: HDC; Inf : TDocInfo): Integer; stdcall; external 'gdi32.dll' name 'StartDocA';
function EndDoc(DC: HDC): Integer; stdcall;  external 'gdi32.dll' name 'EndDoc';
function StartPage(DC: HDC): Integer; stdcall; external 'gdi32.dll' name 'StartPage';
function EndPage(DC: HDC): Integer; stdcall; external 'gdi32.dll' name 'EndPage';
function AbortDoc(DC: HDC): Integer; stdcall; external 'gdi32.dll' name 'AbortDoc';

implementation

end.


