{  $Id$  }
{
 /***************************************************************************
                               allunits.pp

                      dummy unit to compile all units 

 /***************************************************************************
}
unit allunits;

{$mode objfpc}{$H+}

interface

uses
  syntextdrawer, syneditkeycmds, synedittypes, syneditstrconst,
  syneditsearch, syneditmiscprocs, syneditmiscclasses, synedittextbuffer,
  synedit, synedithighlighter, synhighlighterpas, syncompletion,
  syneditautocomplete, synhighlighterhtml, synhighlightercpp;
	
implementation

end.

{ =============================================================================

  $Log$
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
