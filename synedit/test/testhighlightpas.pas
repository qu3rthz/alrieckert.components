unit TestHighlightPas;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, testregistry, TestBase, Forms, LCLProc,
  SynEdit, SynHighlighterPas, SynEditHighlighterFoldBase;

type

  // used by Fold / MarkupWord

  { TTestBaseHighlighterPas }

  TTestBaseHighlighterPas = class(TTestBase)
  protected
    PasHighLighter: TSynPasSyn;
    procedure SetUp; override;
    procedure TearDown; override;
    procedure ReCreateEdit; reintroduce;
    procedure EnableFolds(AEnbledTypes: TPascalCodeFoldBlockTypes;
                          AHideTypes: TPascalCodeFoldBlockTypes = [];
                          ANoFoldTypes: TPascalCodeFoldBlockTypes = []
                         );
    procedure DebugFoldInfo(ALineIdx: Integer; AFilter: TSynFoldActions);
    procedure DebugFoldInfo(AFilter: TSynFoldActions);
  end;

  { TTestHighlighterPas }

  TTestHighlighterPas = class(TTestBaseHighlighterPas)
  protected
    function TestTextFoldInfo1: TStringArray;
    function TestTextFoldInfo2: TStringArray;
    function TestTextFoldInfo3: TStringArray;
    function TestTextFoldInfo4(AIfCol: Integer): TStringArray;

    procedure CheckFoldOpenCounts(Name: String; Expected: Array of Integer);
    procedure CheckFoldInfoCounts(Name: String; Filter: TSynFoldActions; Expected: Array of Integer);
  published
    procedure TestFoldInfo;
    procedure TestProcedureInContext;
  end; 

implementation

{ TTestBaseHighlighterPas }

procedure TTestBaseHighlighterPas.SetUp;
begin
  PasHighLighter := nil;
  inherited SetUp;
end;

procedure TTestBaseHighlighterPas.TearDown;
begin
  if Assigned(SynEdit) then
    SynEdit.Highlighter := nil;
  FreeAndNil(PasHighLighter);
  inherited TearDown;
end;

procedure TTestBaseHighlighterPas.ReCreateEdit;
begin
  if Assigned(SynEdit) then
    SynEdit.Highlighter := nil;
  FreeAndNil(PasHighLighter);
  inherited ReCreateEdit;
  PasHighLighter := TSynPasSyn.Create(nil);
  SynEdit.Highlighter := PasHighLighter;
end;

procedure TTestBaseHighlighterPas.EnableFolds(AEnbledTypes: TPascalCodeFoldBlockTypes;
  AHideTypes: TPascalCodeFoldBlockTypes; ANoFoldTypes: TPascalCodeFoldBlockTypes);
var
  i: TPascalCodeFoldBlockType;
begin
  for i := low(TPascalCodeFoldBlockType) to high(TPascalCodeFoldBlockType) do begin
    PasHighLighter.FoldConfig[ord(i)].Enabled := i in AEnbledTypes;
    if (i in ANoFoldTypes) then
      PasHighLighter.FoldConfig[ord(i)].Modes := []
    else
      PasHighLighter.FoldConfig[ord(i)].Modes := [fmFold];
    if i in AHideTypes then
      PasHighLighter.FoldConfig[ord(i)].Modes := PasHighLighter.FoldConfig[ord(i)].Modes + [fmHide]
  end;
end;

procedure TTestBaseHighlighterPas.DebugFoldInfo(ALineIdx: Integer; AFilter: TSynFoldActions);
  function fa(x: TSynFoldActions): String;
  const FoldActionName: Array[TSynFoldAction] of String =
       ('sfaOpen','sfaClose', 'sfaMarkup', 'sfaFold', 'sfaFoldFold', 'sfaFoldHide',
        'sfaInvalid', 'sfaDefaultCollapsed', 'sfaOneLineOpen', 'sfaOneLineClose', 'sfaLastLineClose');
  var i: TSynFoldAction;
  begin
    Result:='';
    for i := low(TSynFoldAction) to high(TSynFoldAction) do
      if i in x then
        Result := Result + FoldActionName[i]+',';
  end;
var
  i, c: LongInt;
  n: TSynFoldNodeInfo;
begin
  c := PasHighLighter.FoldNodeInfoCount[ALineIdx, AFilter];
  debugln(['### Foldinfo Line: ', ALineIdx,
           '   PasMinLvl=',PasHighLighter.MinimumPasFoldLevel(ALineIdx,1),
           ' EndLvl=',PasHighLighter.EndPasFoldLevel(ALineIdx,1),
           //' Nestcnt=',PasHighLighter.FoldNestCount(ALineIdx,1),
            ' : ', copy(SynEdit.Lines[ALineIdx],1,40)]);
  for i := 0 to c-1 do begin
    n := PasHighLighter.FoldNodeInfo[ALineIdx, i, AFilter];
    debugln(['  # Ixx: ', i,
             ' LogXStart=', n.LogXStart,
             ' End=', n.LogXEnd,
             '   FoldLvlStart=', n.FoldLvlStart,
             ' End=', n.FoldLvlEnd,
             '   FoldType=', n.FoldType,
             ' FoldGroup=', n.FoldGroup,
             '   FoldAction=', fa(n.FoldAction)
    ]);
  end;
end;

procedure TTestBaseHighlighterPas.DebugFoldInfo(AFilter: TSynFoldActions);
var
  i: Integer;
begin
  for i := 0 to SynEdit.Lines.Count - 1 do
    DebugFoldInfo(i, AFilter);
end;

  { TTestHighlighterPas }

function TTestHighlighterPas.TestTextFoldInfo1: TStringArray;
begin
  SetLength(Result, 13);
  Result[0] := 'program Foo;';
  Result[1] := 'procedure a;';
  Result[2] := '{$IFDEF A}';
  Result[3] := 'begin';
  Result[4] := '{$ENDIF}';
  Result[5] := '  {$IFDEF B} if a then begin {$ENDIF}';
  Result[6] := '    writeln()';
  Result[7] := '  end;';
  Result[8] := 'end;';
  Result[9] := 'begin';
  Result[10]:= 'end.';
  Result[11]:= '//';
  Result[12]:= '';
end;

function TTestHighlighterPas.TestTextFoldInfo2: TStringArray;
begin
  // mix folds and same-line-closing
  SetLength(Result, 9);
  Result[0] := 'program Foo;';
  Result[1] := 'procedure a;';
  Result[2] := '{$IFDEF A} begin {$IFDEF B} repeat a; {$ENDIF} until b; {$IFDEF c} try {$ELSE} //x';
  Result[3] := '  //foo';
  Result[4] := '  finally repeat x; {$ENDIF C} until y;';
  Result[5] := '  repeat m; until n; end; {$ENDIF A} // end finally';
  Result[6] := 'end';
  Result[7] := 'begin end.';
  Result[8] := '';

end;

function TTestHighlighterPas.TestTextFoldInfo3: TStringArray;
begin
  SetLength(Result, 12);
  Result[0] := 'Unit Foo;';
  Result[1] := 'Interface';
  Result[2] := 'type a=Integer;';
  Result[3] := 'var';
  Result[4] := '  b:Integer';
  Result[5] := 'const';
  Result[6] := '  c = 1;';
  Result[7] := '  d = 2; {$IFDEF A}';
  Result[8] := 'Implementation';
  Result[9] := '//';
  Result[10]:= 'end.';
  Result[11]:= '';
end;

function TTestHighlighterPas.TestTextFoldInfo4(AIfCol: Integer): TStringArray;
begin
  // various mixed of pascal and ifdef blocks => actually a test for pascal highlighter
  SetLength(Result, 8);
  Result[0] := 'program p;';
  Result[1] := 'procedure A;';
  case AIfCol of
    0: Result[2] := '{$IFDEF} begin  if a then begin';
    1: Result[2] := 'begin {$IFDEF} if a then begin';
    2: Result[2] := 'begin  if a then begin {$IFDEF}';
  end;
  Result[3] := '  end; // 2';
  Result[4] := 'end; // 1';
  Result[5] := '{$ENDIF}';
  Result[6] := '//';
  Result[7] := ''; // program fold is open end

end;

procedure TTestHighlighterPas.CheckFoldOpenCounts(Name: String; Expected: array of Integer);
var
  i: Integer;
begin
  for i := 0 to high(Expected) do
    AssertEquals(Name + 'OpenCount Line='+IntToStr(i),  Expected[i], PasHighLighter.FoldOpenCount(i));
end;

procedure TTestHighlighterPas.CheckFoldInfoCounts(Name: String; Filter: TSynFoldActions;
  Expected: array of Integer);
var
  i: Integer;
begin
  for i := 0 to high(Expected) do
    AssertEquals(Name + 'InfoCount Line='+IntToStr(i),  Expected[i], PasHighLighter.FoldNodeInfoCount[i, Filter]);
end;

procedure TTestHighlighterPas.TestFoldInfo;
begin
  ReCreateEdit;

  //  DebugFoldInfo([]);

  {%region}
  SetLines(TestTextFoldInfo1);
  EnableFolds([cfbtBeginEnd..cfbtNone]);
  PushBaseName('Text 1 all folds');

  AssertEquals('Len Prog',  10, PasHighLighter.FoldLineLength(0,0));
  AssertEquals('Len Proc',   7, PasHighLighter.FoldLineLength(1,0));
  AssertEquals('Len IF A',   2, PasHighLighter.FoldLineLength(2,0));
  AssertEquals('Len Begin',  5, PasHighLighter.FoldLineLength(3,0));
  AssertEquals('Len if beg', 2, PasHighLighter.FoldLineLength(5,0));
  AssertEquals('Len PrgBeg', 1, PasHighLighter.FoldLineLength(9,0));

  AssertEquals('Len invalid', -1, PasHighLighter.FoldLineLength(4,0)); // endif
  AssertEquals('Len // (no hide)', -1, PasHighLighter.FoldLineLength(11,0));

  //                       Pg pc $I bg $E be w  e  e be  e  //
  CheckFoldOpenCounts('', [1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0]);
  CheckFoldInfoCounts('', [sfaOpen, sfaFold],
                          [1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0]);

  EnableFolds([cfbtBeginEnd..cfbtNone], [cfbtSlashComment]);
  AssertEquals('Len // (with hide)', 0, PasHighLighter.FoldLineLength(11,0));

  //                       Pg pc $I bg $E be w  e  e be  e  //
  CheckFoldOpenCounts('', [1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0]); // TODO: does not include the //
  CheckFoldInfoCounts('', [sfaOpen, sfaFold], // includes the //
                          [1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1]);
  CheckFoldInfoCounts('', [sfaOpen, sfaFold, sfaFoldFold],
                          [1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0]);
  CheckFoldInfoCounts('', [sfaOpen, sfaOneLineOpen, sfaFold, sfaFoldHide],
                          [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]);
  {%endregion}

  {%region}
  SetLines(TestTextFoldInfo2);
  EnableFolds([cfbtBeginEnd..cfbtNone]-[cfbtRepeat], [cfbtSlashComment]);
  PopPushBaseName('Text 2 all folds except repeat');

  AssertEquals('Len Prog',    7, PasHighLighter.FoldLineLength(0,0));
  AssertEquals('Len Proc',    5, PasHighLighter.FoldLineLength(1,0));

  AssertEquals('Len IFDEF A', 3, PasHighLighter.FoldLineLength(2,0));
  AssertEquals('Len Begin',   4, PasHighLighter.FoldLineLength(2,1));
  AssertEquals('Len Try',     3, PasHighLighter.FoldLineLength(2,2));
  AssertEquals('Len ELSE C',  2, PasHighLighter.FoldLineLength(2,3));

  AssertEquals('Len //',      0, PasHighLighter.FoldLineLength(3,0));
  AssertEquals('Finally',     1, PasHighLighter.FoldLineLength(4,0));

  AssertEquals('Len invalid begin end', -1, PasHighLighter.FoldLineLength(7,0));

  //                       Pg pc 4  // fi e  e  be-
  CheckFoldOpenCounts('', [1, 1, 4, 0, 1, 0, 0, 0]);
  CheckFoldInfoCounts('', [sfaOpen, sfaFold],
                          [1, 1, 4, 1, 1, 0, 0, 0]);
  {%endregion}

  {%region}
  SetLines(TestTextFoldInfo3);
  EnableFolds([cfbtBeginEnd..cfbtNone], [cfbtSlashComment]);
  PushBaseName('Text 3 (end-last-line)');

  AssertEquals('Len Unit',     10, PasHighLighter.FoldLineLength(0,0));
  AssertEquals('Len Intf',      6, PasHighLighter.FoldLineLength(1,0));
  AssertEquals('Len type(non)',-1, PasHighLighter.FoldLineLength(2,0));
  AssertEquals('Len var',       1, PasHighLighter.FoldLineLength(3,0));
  AssertEquals('Len const',     2, PasHighLighter.FoldLineLength(5,0));
  AssertEquals('Len Impl',      1, PasHighLighter.FoldLineLength(8,0));
  AssertEquals('Len //',        0, PasHighLighter.FoldLineLength(9,0));

  //                       Un If ty va -  co -  $  Im // e
  CheckFoldOpenCounts('', [1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0]);
  CheckFoldInfoCounts('', [sfaOpen, sfaFold],
                          [1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0]);
  CheckFoldInfoCounts('', [sfaClose, sfaFold, sfaLastLineClose],
                          [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]);
  CheckFoldInfoCounts('', [sfaLastLineClose],
                          [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]);
  {%endregion}

  {%region}
  SetLines(TestTextFoldInfo4(0));
  EnableFolds([cfbtBeginEnd..cfbtNone], [cfbtSlashComment]);
  PushBaseName('Text 4 (mixed group) 0');

  AssertEquals('Len Prog',   6, PasHighLighter.FoldLineLength(0,0));
  AssertEquals('Len Proc',   3, PasHighLighter.FoldLineLength(1,0));
  AssertEquals('Len IF',     3, PasHighLighter.FoldLineLength(2,0));
  AssertEquals('Len beg 1',  2, PasHighLighter.FoldLineLength(2,1));
  AssertEquals('Len beg 2',  1, PasHighLighter.FoldLineLength(2,2));
  AssertEquals('Len //',     0, PasHighLighter.FoldLineLength(6,0));

  //                       Pg Pc 3  e  e  $e //
  CheckFoldOpenCounts('', [1, 1, 3, 0, 0, 0, 0]);
  CheckFoldInfoCounts('', [sfaOpen, sfaFold],
                          [1, 1, 3, 0, 0, 0, 1]);
  CheckFoldInfoCounts('', [sfaClose, sfaFold, sfaLastLineClose],
                          [0, 0, 0, 0, 0, 0, 2]);
  CheckFoldInfoCounts('', [sfaLastLineClose],
                          [0, 0, 0, 0, 0, 0, 2]);


  SetLines(TestTextFoldInfo4(1));
  EnableFolds([cfbtBeginEnd..cfbtNone], [cfbtSlashComment]);
  PushBaseName('Text 4 (mixed group) 1');

  AssertEquals('Len Prog',   6, PasHighLighter.FoldLineLength(0,0));
  AssertEquals('Len Proc',   3, PasHighLighter.FoldLineLength(1,0));
  AssertEquals('Len IF',     3, PasHighLighter.FoldLineLength(2,1));
  AssertEquals('Len beg 1',  2, PasHighLighter.FoldLineLength(2,0));
  AssertEquals('Len beg 2',  1, PasHighLighter.FoldLineLength(2,2));
  AssertEquals('Len //',     0, PasHighLighter.FoldLineLength(6,0));

  //                       Pg Pc 3  e  e  $e //
  CheckFoldOpenCounts('', [1, 1, 3, 0, 0, 0, 0]);
  CheckFoldInfoCounts('', [sfaOpen, sfaFold],
                          [1, 1, 3, 0, 0, 0, 1]);


  SetLines(TestTextFoldInfo4(2));
  EnableFolds([cfbtBeginEnd..cfbtNone], [cfbtSlashComment]);
  PushBaseName('Text 4 (mixed group) 1');

  AssertEquals('Len Prog',   6, PasHighLighter.FoldLineLength(0,0));
  AssertEquals('Len Proc',   3, PasHighLighter.FoldLineLength(1,0));
  AssertEquals('Len IF',     3, PasHighLighter.FoldLineLength(2,2));
  AssertEquals('Len beg 1',  2, PasHighLighter.FoldLineLength(2,0));
  AssertEquals('Len beg 2',  1, PasHighLighter.FoldLineLength(2,1));
  AssertEquals('Len //',     0, PasHighLighter.FoldLineLength(6,0));

  //                       Pg Pc 3  e  e  $e //
  CheckFoldOpenCounts('', [1, 1, 3, 0, 0, 0, 0]);
  CheckFoldInfoCounts('', [sfaOpen, sfaFold],
                          [1, 1, 3, 0, 0, 0, 1]);
  {%endregion}


end;

procedure TTestHighlighterPas.TestProcedureInContext;
begin
  ReCreateEdit;
  SetLines
    ([ 'Unit A;',
       'interface',
       '',
       'var',
       '  Foo: Procedure of object;', // no folding // do not end var block
       '',
       'type',
       '  TBar: ',
       '    Function(): Boolean;',  // no folding // do not end type block
       '',
       'Procedure a;', // no folding in interface
       '',
       'implementation',
       '',
       'var',
       '  Foo2: Procedure of object;', // no folding // do not end var block
       '',
       'type',
       '  TBar2: ',
       '    Function(): Boolean;',  // no folding // do not end type block
       '',
       'Procedure a;', // fold
       'var',
       '  Foo3: Procedure of object;', // no folding // do not end var block
       '',
       'begin end;',
       '',
       'end.',
       ''
    ]);
  EnableFolds([cfbtBeginEnd..cfbtNone]);
  CheckFoldOpenCounts('', [ 1, 1, 0, 1 {var}, 0, 0, 1 {type}, 0, 0, 0, 0 {Proc}, 0,
                            1 {impl}, 0, 1 {var}, 0, 0, 1 {type}, 0, 0, 0,
                            1 {proc}, 1 {var}, 0, 0, 0, 0, 0
                     ]);
  AssertEquals('Len var 1 ',   2, PasHighLighter.FoldLineLength(3, 0));
  AssertEquals('Len type 1 ',  3, PasHighLighter.FoldLineLength(6, 0));
  AssertEquals('Len var 2 ',   2, PasHighLighter.FoldLineLength(14, 0));
  AssertEquals('Len type 2 ',  3, PasHighLighter.FoldLineLength(17, 0));
  AssertEquals('Len var 3 ',   2, PasHighLighter.FoldLineLength(22, 0));

end;

initialization

  RegisterTest(TTestHighlighterPas); 
end.

