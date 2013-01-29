unit TestMarkupHighAll;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, testregistry, TestBase, TestHighlightPas, Forms, LCLProc, Controls,
  Graphics, SynEdit, SynHighlighterPas, SynEditMarkupHighAll;

type

  { TTestMarkupHighAll }

  TTestMarkupHighAll = class(TTestBase)
  private
    FMatchList: Array of record
        p: PChar;
        l: Integer;
      end;
    procedure DoDictMatch(Match: PChar; MatchLen: Integer; var IsMatch: Boolean;
      var StopSeach: Boolean);
  protected
    //procedure SetUp; override; 
    //procedure TearDown; override; 
    //procedure ReCreateEdit; reintroduce;
    //function TestText1: TStringArray;
  published
    procedure TestDictionary;
    procedure TestValidateMatches;
  end; 

implementation

  type

    { TTestSynEditMarkupHighlightAllMulti }

    TTestSynEditMarkupHighlightAllMulti = class(TSynEditMarkupHighlightAllMulti)
    private
      FScannedLineCount: Integer;
    protected
      function FindMatches(AStartPoint, AEndPoint: TPoint; var AIndex: Integer;
        AStopAfterLine: Integer = - 1; ABackward: Boolean = False): TPoint; override;
    public
      procedure ResetScannedCount;
      property Matches;
      property ScannedLineCount: Integer read FScannedLineCount;
    end;

{ TTestSynEditMarkupHighlightAllMulti }

function TTestSynEditMarkupHighlightAllMulti.FindMatches(AStartPoint, AEndPoint: TPoint;
  var AIndex: Integer; AStopAfterLine: Integer; ABackward: Boolean): TPoint;
begin
  FScannedLineCount := FScannedLineCount + AEndPoint.y - AStartPoint.y + 1;
  Result := inherited FindMatches(AStartPoint, AEndPoint, AIndex, AStopAfterLine, ABackward);
end;

procedure TTestSynEditMarkupHighlightAllMulti.ResetScannedCount;
begin
  FScannedLineCount := 0;
end;


{ TTestMarkupHighAll }

procedure TTestMarkupHighAll.DoDictMatch(Match: PChar; MatchLen: Integer;
  var IsMatch: Boolean; var StopSeach: Boolean);
var
  i: Integer;
begin
  i := length(FMatchList);
  SetLength(FMatchList, i+1);
DebugLn([copy(Match, 1, MatchLen)]);
  FMatchList[i].p := Match;
  FMatchList[i].l := MatchLen;
end;

procedure TTestMarkupHighAll.TestDictionary;
var
  Dict: TSynSearchDictionary;
  i, j: Integer;
  s: String;
begin
  Dict := TSynSearchDictionary.Create;
  Dict.Add('debugln',1);
  Dict.Add('debuglnenter',2);
  Dict.Add('debuglnexit',3);
  Dict.Add('dbgout',4);

  Dict.DebugPrint();


  Dict.Free;
exit;

  Dict := TSynSearchDictionary.Create;
  Dict.Add('Hello', 0);
  Dict.Add('hell', 0);
  Dict.Add('hatter', 0);
  Dict.Add('log', 0);
  Dict.Add('lantern', 0);
  Dict.Add('terminal', 0);
  Dict.Add('all', 0);
  Dict.Add('alt', 0);


  Dict.Search('aallhellxlog', 12, @DoDictMatch);

  //Dict.BuildDictionary;
  Dict.DebugPrint();

  //Randomize;
  //Dict.Clear;
  //for i := 0 to 5000 do begin
  //  s := '';
  //  for j := 10 to 11+Random(20) do s := s + chr(Random(127));
  //  Dict.Add(s);
  //end;
  //Dict.BuildDictionary;
  //Dict.DebugPrint(true);


  Dict.Free;
end;

procedure TTestMarkupHighAll.TestValidateMatches;
type
  TMatchLoc = record
    y1, y2, x1, x2: Integer;
  end;
var
  M: TTestSynEditMarkupHighlightAllMulti;

  function l(y, x1, x2: Integer) : TMatchLoc;
  begin
    Result.y1 := y;
    Result.x1 := x1;
    Result.y2 := y;
    Result.x2 := x2;
  end;

  procedure StartMatch(Words: Array of string);
  var
    i: Integer;
  begin
    SynEdit.BeginUpdate;
    M.Clear;
    for i := 0 to high(Words) do
      M.AddSearchTerm(Words[i]);
    SynEdit.EndUpdate;
    m.MarkupInfo.Foreground := clRed;
  end;

  Procedure TestHasMCount(AName: String; AExpMin: Integer; AExpMax: Integer = -1);
  begin
    AName := AName + '(CNT)';
    if AExpMax < 0 then begin
      AssertEquals(BaseTestName+' '+AName, AExpMin, M.Matches.Count);
    end
    else begin
      AssertTrue(BaseTestName+' '+AName+ '(Min)', AExpMin <= M.Matches.Count);
      AssertTrue(BaseTestName+' '+AName+ '(Max)', AExpMax >= M.Matches.Count);
    end;
  end;

  Procedure TestHasMatches(AName: String; AExp: Array of TMAtchLoc; ExpMusNotExist: Boolean = False);
  var
    i, j: Integer;
  begin
    for i := 0 to High(AExp) do begin
      j := M.Matches.Count - 1;
      while (j >= 0) and
        ( (M.Matches.StartPoint[j].y <> AExp[i].y1) or (M.Matches.StartPoint[j].x <> AExp[i].x1) or
          (M.Matches.EndPoint[j].y <> AExp[i].y2) or (M.Matches.EndPoint[j].x <> AExp[i].x2) )
      do
        dec(j);
      AssertEquals(BaseTestName+' '+AName+'('+IntToStr(i)+')', not ExpMusNotExist, j >= 0);
    end
  end;

  Procedure TestHasMatches(AName: String; AExpCount: Integer; AExp: Array of TMAtchLoc; ExpMusNotExist: Boolean = False);
  begin
    TestHasMatches(AName, AExp, ExpMusNotExist);
    TestHasMCount(AName, AExpCount);
  end;

  Procedure TestHasMatches(AName: String; AExpCountMin, AExpCountMax: Integer; AExp: Array of TMAtchLoc; ExpMusNotExist: Boolean = False);
  begin
    TestHasMatches(AName, AExp, ExpMusNotExist);
    TestHasMCount(AName, AExpCountMin, AExpCountMax);
  end;

  Procedure TestHasScanCnt(AName: String; AExpMin: Integer; AExpMax: Integer = -1);
  begin
    AName := AName + '(SCANNED)';
    if AExpMax < 0 then begin
      AssertEquals(BaseTestName+' '+AName, AExpMin, M.ScannedLineCount);
    end
    else begin
      AssertTrue(BaseTestName+' '+AName+ '(Min)', AExpMin <= M.ScannedLineCount);
      AssertTrue(BaseTestName+' '+AName+ '(Max)', AExpMax >= M.ScannedLineCount);
    end;
  end;

  procedure SetText(ATopLine: Integer = 1; HideSingle: Boolean = False);
  var
    i: Integer;
  begin
    ReCreateEdit;
    SynEdit.BeginUpdate;
    for i := 1 to 700 do
      SynEdit.Lines.Add('  a'+IntToStr(i)+'a  b  c'+IntToStr(i)+'d');
    SynEdit.Align := alTop;
    SynEdit.Height := SynEdit.LineHeight * 40 + SynEdit.LineHeight div 2;
    M := TTestSynEditMarkupHighlightAllMulti.Create(SynEdit);
    M.HideSingleMatch := HideSingle;
    SynEdit.MarkupMgr.AddMarkUp(M);
    SynEdit.TopLine := ATopLine;
    SynEdit.EndUpdate;
  end;

  procedure SetTextAndMatch(ATopLine: Integer; HideSingle: Boolean;
    Words: Array of string;
    AName: String= ''; AExpMin: Integer = -1; AExpMax: Integer = -1);
  begin
    SetText(ATopLine, HideSingle);
    StartMatch(Words);
    if AExpMin >= 0 then
      TestHasMCount(AName + ' init', AExpMin, AExpMax);
  end;

var
  N: string;
  i, j, a, b: integer;
begin

  {%region Searchrange}
    PushBaseName('Searchrange');
    PushBaseName('HideSingleMatch=False');

    N := 'Find match on first line';
    SetText(250);
    M.HideSingleMatch := False;
    StartMatch(['a250a']);
    TestHasMCount (N, 1);
    TestHasMatches(N, [l(250, 3, 8)]);

    N := 'Find match on last line';
    SetText(250);
    M.HideSingleMatch := False;
    StartMatch(['a289a']);
    TestHasMCount (N, 1);
    TestHasMatches(N, [l(289, 3, 8)]);

    N := 'Find match on last part visible) line';
    SetText(250);
    M.HideSingleMatch := False;
    StartMatch(['a290a']);
    TestHasMCount (N, 1);
    TestHasMatches(N, [l(290, 3, 8)]);

    // Before topline
    SetText(250);
    M.HideSingleMatch := False;
    StartMatch(['a249a']);
    TestHasMCount ('NOT Found before topline', 0);

    // after lastline
    SetText(250);
    M.HideSingleMatch := False;
    StartMatch(['a291a']);
    TestHasMCount ('NOT Found after lastline', 0);

    // first and last
    SetText(250);
    M.HideSingleMatch := False;
    StartMatch(['a250a', 'a290a']);
    TestHasMCount ('Found on first and last line', 2);
    TestHasMatches('Found on first and last line', [l(250, 3, 8), l(290, 3, 8)]);

    // first and last + before
    SetText(250);
    M.HideSingleMatch := False;
    StartMatch(['a250a', 'a290a', 'a249a']);
    TestHasMCount ('Found on first/last (but not before) line', 2);
    TestHasMatches('Found on first/last (but not before) line', [l(250, 3, 8), l(290, 3, 8)]);

    // first and last + after
    SetText(250);
    M.HideSingleMatch := False;
    StartMatch(['a250a', 'a290a', 'a291a']);
    TestHasMCount ('Found on first/last (but not after) line', 2);
    TestHasMatches('Found on first/last (but not after) line', [l(250, 3, 8), l(290, 3, 8)]);

    PopPushBaseName('HideSingleMatch=True');

    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a250a']);
    TestHasMCount ('Found on first line', 1);
    TestHasMatches('Found on first line', [l(250, 3, 8)]);

    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a289a']);
    TestHasMCount ('Found on last line', 1);
    TestHasMatches('Found on last line', [l(289, 3, 8)]);

    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a290a']);
    TestHasMCount ('Found on last (partly) line', 1);
    TestHasMatches('Found on last (partly) line', [l(290, 3, 8)]);

    // Before topline
    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a249a']);
    TestHasMCount ('NOT Found before topline', 0);

    // after lastline
    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a291a']);
    TestHasMCount ('NOT Found after lastline', 0);

    // first and last
    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a250a', 'a290a']);
    TestHasMCount ('Found on first and last line', 2);
    TestHasMatches('Found on first and last line', [l(250, 3, 8), l(290, 3, 8)]);

    // first and last + before
    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a250a', 'a290a', 'a249a']);
    TestHasMCount ('Found on first/last (but not before) line', 2);
    TestHasMatches('Found on first/last (but not before) line', [l(250, 3, 8), l(290, 3, 8)]);

    // first and last + after
    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a250a', 'a290a', 'a291a']);
    TestHasMCount ('Found on first/last (but not after) line', 2);
    TestHasMatches('Found on first/last (but not after) line', [l(250, 3, 8), l(290, 3, 8)]);

    // extend for HideSingle, before
    N := 'Look for 2nd match before startpoint (first match at topline)';
    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a250a', 'a249a']);
    TestHasMCount (N, 2);
    TestHasMatches(N, [l(250, 3, 8), l(249, 3, 8)]);

    N := 'Look for 2nd match before startpoint (first match at lastline)';
    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a290a', 'a249a']);
    TestHasMCount (N, 2);
    TestHasMatches(N, [l(290, 3, 8), l(249, 3, 8)]);

    N := 'Look for 2nd match FAR (99l) before startpoint (first match at topline)';
    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a250a', 'a151a']);
    TestHasMCount (N, 2);
    TestHasMatches(N, [l(250, 3, 8), l(151, 3, 8)]);

    N := 'Look for 2nd match FAR (99l) before startpoint (first match at lastline)';
    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a290a', 'a151a']);
    TestHasMCount (N, 2);
    TestHasMatches(N, [l(290, 3, 8), l(151, 3, 8)]);

    N := 'Look for 2nd match before startpoint, find ONE of TWO';
    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a250a', 'a200a', 'a210a']);
    TestHasMCount (N, 2);
    TestHasMatches(N, [l(250, 3, 8), l(210, 3, 8)]);

    // TODO: Not extend too far...

    // extend for HideSingle, after
    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a250a', 'a291a']);
    TestHasMCount ('Found on first/ext-after line', 2);
    TestHasMatches('Found on first/ext-after line', [l(250, 3, 8), l(291, 3, 8)]);

    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a290a', 'a291a']);
    TestHasMCount ('Found on last/ext-after line', 2);
    TestHasMatches('Found on last/ext-after line', [l(290, 3, 8), l(291, 3, 8)]);

    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a250a', 'a389a']);
    TestHasMCount ('Found on first/ext-after-99 line', 2);
    TestHasMatches('Found on first/ext-after-99 line', [l(250, 3, 8), l(389, 3, 8)]);

    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a290a', 'a389a']);
    TestHasMCount ('Found on last/ext-after-99 line', 2);
    TestHasMatches('Found on last/ext-after-99 line', [l(290, 3, 8), l(389, 3, 8)]);


    PopBaseName;
    PopBaseName;
  {%endregion}

  {%region Scroll / LinesInWindow}
    PushBaseName('Scroll/LinesInWindow');
    PushBaseName('HideSingleMatch=False');


    SetText(250);
    M.HideSingleMatch := False;
    StartMatch(['a249a']);
    TestHasMCount ('Not Found before first line', 0);

    M.ResetScannedCount;
    SynEdit.TopLine := 251;
    TestHasMCount ('Not Found before first line (250=>251)', 0);
    TestHasScanCnt('Not Found before first line (250=>251)', 1, 2); // Allow some range

    M.ResetScannedCount;
    SynEdit.TopLine := 249;
    TestHasMCount ('Found on first line (251=<249', 1);
    TestHasMatches('Found on first line (251=>249)', [l(249, 3, 8)]);
    TestHasScanCnt('Found on first line (251=>249)', 1, 2); // Allow some range


    SetText(250);
    M.HideSingleMatch := False;
    StartMatch(['a291a']);
    TestHasMCount ('Not Found after last line', 0);

    M.ResetScannedCount;
    SynEdit.TopLine := 249;
    TestHasMCount ('Not Found after last line (250=>249)', 0);
    TestHasScanCnt('Not Found after last line (250=>249)', 1, 2); // Allow some range

    M.ResetScannedCount;
    SynEdit.TopLine := 251;
    TestHasMCount ('Found on last line (249=<251', 1);
    TestHasMatches('Found on last line (249=>251)', [l(291, 3, 8)]);
    TestHasScanCnt('Found on last line (249=>251)', 1, 2); // Allow some range


    SetText(250);
    M.HideSingleMatch := False;
    StartMatch(['a291a']);
    TestHasMCount ('Not Found after last line', 0);

    M.ResetScannedCount;
    SynEdit.Height := SynEdit.LineHeight * 41 + SynEdit.LineHeight div 2;
    TestHasMCount ('Found on last line (40=>41', 1);
    TestHasMatches('Found on last line (40=>41)', [l(291, 3, 8)]);
    TestHasScanCnt('Found on last line (40=>41)', 1, 2); // Allow some range


    PopPushBaseName('HideSingleMatch=True');

    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a249a', 'a248a']);
    TestHasMCount ('Not Found before first line', 0);

    M.ResetScannedCount;
    SynEdit.TopLine := 251;
    TestHasMCount ('Not Found before first line (250=>251)', 0);
    TestHasScanCnt('Not Found before first line (250=>251)', 1, 2); // Allow some range

    M.ResetScannedCount;
    SynEdit.TopLine := 249;
    TestHasMCount ('Found on first line+ext (251=<249', 2);
    TestHasMatches('Found on first line+ext (251=>249)', [l(249, 3, 8), l(248, 3, 8)]);


    SetText(250);
    M.HideSingleMatch := True;
    StartMatch(['a291a', 'a292a']);
    TestHasMCount ('Not Found after last line', 0);

    M.ResetScannedCount;
    SynEdit.TopLine := 249;
    TestHasMCount ('Not Found after last line (250=>249)', 0);
    TestHasScanCnt('Not Found after last line (250=>249)', 1, 2); // Allow some range

    M.ResetScannedCount;
    SynEdit.TopLine := 251;
    TestHasMCount ('Found on last line+ext (249=<251', 2);
    TestHasMatches('Found on last line+ext (249=>251)', [l(291, 3, 8), l(292, 3, 8)]);

    PopBaseName;
    PopBaseName;
  {%endregion}

  {%region edit}
    PushBaseName('Searchrange');
    //PushBaseName('HideSingleMatch=False');

    for i := 245 to 295 do begin
      if ((i > 259) and (i < 280)) then continue;

      N := 'Edit at '+IntToStr(i)+' / NO match';
      SetTextAndMatch(250, False,   ['DontMatchMe'],   N+' init/found', 0);
      M.ResetScannedCount;
      SynEdit.TextBetweenPoints[point(1, i), point(1, i)] := 'X';
      SynEdit.SimulatePaintText;
      TestHasMCount (N+' Found after edit', 0);
      if (i >= 250) and (i <= 290)
      then TestHasScanCnt(N+' Found after edit', 1, 3)
      else
      if (i < 247) or (i > 293)
      then TestHasScanCnt(N+' Found after edit', 0)
      else TestHasScanCnt(N+' Found after edit', 0, 3);


      N := 'Edit (new line) at '+IntToStr(i)+' / NO match';
      SetTextAndMatch(250, False,   ['DontMatchMe'],   N+' init/found', 0);
      M.ResetScannedCount;
      SynEdit.TextBetweenPoints[point(1, i), point(1, i)] := LineEnding;
      SynEdit.SimulatePaintText;
      TestHasMCount (N+' Found after edit', 0);
      //if (i >= 250) and (i <= 290)
      //then TestHasScanCnt(N+' Found after edit', 1, 3)
      //else
      //if (i < 247) or (i > 293)
      //then TestHasScanCnt(N+' Found after edit', 0)
      //else TestHasScanCnt(N+' Found after edit', 0, 3);


      N := 'Edit (join line) at '+IntToStr(i)+' / NO match';
      SetTextAndMatch(250, False,   ['DontMatchMe'],   N+' init/found', 0);
      M.ResetScannedCount;
      SynEdit.TextBetweenPoints[point(10, i), point(1, i+1)] := '';
      SynEdit.SimulatePaintText;
      TestHasMCount (N+' Found after edit', 0);
      //if (i >= 250) and (i <= 290)
      //then TestHasScanCnt(N+' Found after edit', 1, 3)
      //else
      //if (i < 247) or (i > 293)
      //then TestHasScanCnt(N+' Found after edit', 0)
      //else TestHasScanCnt(N+' Found after edit', 0, 3);

    end;



    for j := 245 to 295 do begin
      if ((j > 255) and (j < 270)) or ((j > 270) and (j < 285)) then
        continue;

      for i := 245 to 295 do begin
        N := 'Edit at '+IntToStr(i)+' / single match at '+IntToStr(j);
        SetTextAndMatch(250, False,   ['a'+IntToStr(j)+'a']);
        if (j >= 250) and (j <= 290)
        then TestHasMatches(N+' init/found',   1,   [l(j, 3, 8)])
        else TestHasMCount (N+' init/not found', 0);

        M.ResetScannedCount;
        SynEdit.TextBetweenPoints[point(1, i), point(1, i)] := 'X';
        SynEdit.SimulatePaintText;
        if (j >= 250) and (j <= 290) then begin
          if i = j
          then TestHasMatches(N+' Found after edit',   1,  [l(j, 4, 9)])
          else TestHasMatches(N+' Found after edit',   1,  [l(j, 3, 8)]);
        end
        else
          TestHasMCount (N+' still not Found after edit', 0);

        if (i >= 250) and (i <= 290)
        then TestHasScanCnt(N+' Found after edit', 1, 3)
        else
        if (i < 247) or (i > 293)
        then TestHasScanCnt(N+' Found after edit', 0)
        else TestHasScanCnt(N+' Found after edit', 0, 3);
      end;


      for i := 245 to 295 do begin
        N := 'Edit (new line) at '+IntToStr(i)+' / single match at '+IntToStr(j);
        SetTextAndMatch(250, False,   ['a'+IntToStr(j)+'a']);
        if (j >= 250) and (j <= 290)
        then TestHasMatches(N+' init/found',   1,   [l(j, 3, 8)])
        else TestHasMCount (N+' init/not found', 0);

        M.ResetScannedCount;
        SynEdit.BeginUpdate;
        SynEdit.TextBetweenPoints[point(1, i), point(1, i)] := LineEnding;
        SynEdit.TopLine := 250;
        SynEdit.EndUpdate;
        SynEdit.SimulatePaintText;
        a := j;
        if i <= j then inc(a);
        if (a >= 250) and (a <= 290) then begin
          if i = a
          then TestHasMatches(N+' Found after edit',   1,  [l(a, 4, 9)])
          else TestHasMatches(N+' Found after edit',   1,  [l(a, 3, 8)]);
        end
        else
          TestHasMCount (N+' still not Found after edit', 0);

        //if (i >= 250) and (i <= 290)
        //then TestHasScanCnt(N+' Found after edit', 1, 3)
        //else
        //if (i < 247) or (i > 293)
        //then TestHasScanCnt(N+' Found after edit', 0)
        //else TestHasScanCnt(N+' Found after edit', 0, 3);
      end;

    end;



    for j := 0 to 6 do begin
      case j of
        0: begin a := 260; b := 270 end;
        1: begin a := 250; b := 270 end;
        2: begin a := 251; b := 270 end;
        3: begin a := 270; b := 288 end;
        4: begin a := 270; b := 289 end;
        5: begin a := 270; b := 290 end;
        6: begin a := 250; b := 290 end;
      end;

      for i := 245 to 295 do begin
        N := 'Edit at '+IntToStr(i)+' / TWO match at '+IntToStr(a)+', '+IntToStr(b);
        SetTextAndMatch(250, False,   ['a'+IntToStr(a)+'a', 'a'+IntToStr(b)+'a']);
        TestHasMatches(N+' init/found',   2,  [l(a, 3, 8), l(b, 3,8)]);

        M.ResetScannedCount;
        SynEdit.TextBetweenPoints[point(10, i), point(10, i)] := 'X';
        SynEdit.SimulatePaintText;
        TestHasMCount (N+' Found after edit', 2);
        TestHasMatches(N+' init/found', [l(a, 3, 8), l(b, 3,8)]);

        if (i >= 250) and (i <= 290)
        then TestHasScanCnt(N+' Found after edit', 1, 3)
        else
        if (i < 247) or (i > 293)
        then TestHasScanCnt(N+' Found after edit', 0)
        else TestHasScanCnt(N+' Found after edit', 0, 3);
      end;
    end;


    N := 'Edit/Topline/LastLine ';
    SetTextAndMatch(250, False,   ['a265a', 'a275a']);
    TestHasMatches(N+' init/found',   2,  [l(265, 3, 8), l(275, 3,8)]);
    M.ResetScannedCount;
    SynEdit.BeginUpdate;
    SynEdit.TextBetweenPoints[point(10, i), point(10, i)] := 'X';
    SynEdit.TopLine := 248; // 2 new lines
    SynEdit.Height := SynEdit.LineHeight * 44 + SynEdit.LineHeight div 2; // another 2 lines
    SynEdit.EndUpdate;
    SynEdit.SimulatePaintText;
    TestHasMatches(N+' Found after edit',   2,  [l(265, 3, 8), l(275, 3,8)]);
    TestHasScanCnt(N+' Found after edit', 1, 12);


    N := 'Edit/Topline/LastLine find new points';
    SetTextAndMatch(250, False,   ['a265a', 'a275a', 'a248a', 'a292a']);
    TestHasMatches(N+' init/found',   2,  [l(265, 3, 8), l(275, 3,8)]);
    M.ResetScannedCount;
    SynEdit.BeginUpdate;
    SynEdit.TextBetweenPoints[point(10, i), point(10, i)] := 'X';
    SynEdit.TopLine := 248; // 2 new lines
    SynEdit.Height := SynEdit.LineHeight * 44 + SynEdit.LineHeight div 2; // another 2 lines
    SynEdit.EndUpdate;
    SynEdit.SimulatePaintText;
    TestHasMatches(N+' Found after edit',   4,  [l(265, 3, 8), l(275, 3,8), l(248, 3,8), l(292, 3,8)]);
    TestHasScanCnt(N+' Found after edit', 1, 12);

    PopBaseName;
  {%endregion}



end;

initialization

  RegisterTest(TTestMarkupHighAll);
end.

