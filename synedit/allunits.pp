{  $Id$  }
{
 /***************************************************************************
                               allunits.pp

                      dummy unit to compile all units 

 /***************************************************************************
}
unit AllUnits;

{$mode objfpc}{$H+}

interface

uses
  SynTextDrawer, SynEditKeyCmds, SynEditTypes, SynEditStrConst,
  SynEditSearch, SynEditMiscProcs, SynEditmiscClasses, SynEditTextbuffer,
  SynEdit, SynEditHighlighter, SynhighlighterPas, SynCompletion,
  SynEditAutoComplete, SynhighlighterHTML, SynhighlighterCPP, SynHighlighterXML,
  SynHighlighterLFM, SynHighlighterPerl, SynHighlighterMulti, SynRegExpr,
  SynEditExport, SynExportHTML, SynMemo, SynMacroRecorder, SynEditPlugins,
  SynEditRegexSearch, SynHighlighterPosition, SynHighlighterJava,
  SynHighlighterUNIXShellScript,
  SynEditLazDsgn;

implementation

end.

{ =============================================================================

  $Log$
  Revision 1.17  2003/06/11 22:56:09  mattias
  added bash scripts highlighter from Tom Lisjac

  Revision 1.16  2003/02/20 00:44:01  mattias
  added synedit to component palette

  Revision 1.15  2003/01/15 10:17:49  mattias
  added java syntax highlighter

  Revision 1.14  2002/12/02 16:38:13  mattias
  started position highlighter

  Revision 1.13  2002/11/29 19:59:40  mattias
  added syneditregexsearch.pas

  Revision 1.12  2002/11/21 21:39:49  mattias
  add synmemo.pas syneditplugins.pas synmacrorecorder.pas

  Revision 1.11  2002/11/21 20:28:26  mattias
  added SynEditExport and SynExportHTML

  Revision 1.10  2002/11/21 20:04:56  mattias
  added SynRegExpr and SynHighlighterMulti

  Revision 1.9  2001/12/10 22:39:37  lazarus
  MG: added perl highlighter

  Revision 1.8  2001/12/06 10:15:06  lazarus
  MG: added xml and lfm highlighter

  Revision 1.7  2001/03/19 18:51:57  lazarus
  MG: added dynhasharray and renamed tsynautocompletion

  Revision 1.6  2001/03/19 14:00:48  lazarus
  MG: fixed many unreleased DC and GDIObj bugs

  Revision 1.4  2001/02/21 22:55:25  lazarus
  small bugfixes + added TOIOptions

  Revision 1.3  2001/02/01 19:34:50  lazarus
  TScrollbar created and a lot of code added.

  It's cose to working.
  Shane

  Revision 1.2  2001/01/30 22:55:00  lazarus
  MWE:
    + Added $mode objfpc directive

  Revision 1.1  2001/01/28 16:16:11  lazarus
  MWE:
    + Added synedit to the components


}
