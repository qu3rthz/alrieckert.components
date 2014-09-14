program pochecker;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, pocheckermain, pofamilies, resultdlg, simplepofiles, pocheckerconsts,
  graphstat;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TPoCheckerForm, PoCheckerForm);
  Application.CreateForm(TGraphStatForm, GraphStatForm);
  Application.Run;
end.

