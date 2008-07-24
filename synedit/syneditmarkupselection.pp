unit SynEditMarkupSelection;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, SynEditMarkup, SynEditMiscClasses, Controls, LCLProc;

type

  { TSynEditMarkupSelection }

  TSynEditMarkupSelection = class(TSynEditMarkup)
  private
    FMarkupInfoIncr: TSynSelectedColor; // Markup during incremental search
    FMarkupInfoSelection: TSynSelectedColor; // Markup for normal Selection
    FUseIncrementalColor : Boolean;
    nSelStart, nSelEnd: integer; // start, end of selected area in current line (physical)
    procedure SetUseIncrementalColor(const AValue : Boolean);
    procedure MarkupChangedIntern(AMarkup: TObject);
  public
    constructor Create(ASynEdit : TCustomControl);
    destructor Destroy; override;

    Procedure PrepareMarkupForRow(aRow : Integer); override;
    Function GetMarkupAttributeAtRowCol(const aRow, aCol : Integer) : TSynSelectedColor; override;
    Function GetNextMarkupColAfterRowCol(const aRow, aCol : Integer) : Integer; override;

    property UseIncrementalColor : Boolean read FUseIncrementalColor write SetUseIncrementalColor;
    property MarkupInfoSeletion : TSynSelectedColor read FMarkupInfoSelection;
    property MarkupInfoIncr : TSynSelectedColor read FMarkupInfoIncr;
  end;

implementation
uses SynEdit, SynEditTypes;

{ TSynEditMarkupSelection }

procedure TSynEditMarkupSelection.SetUseIncrementalColor(const AValue : Boolean);
begin
  if FUseIncrementalColor=AValue then exit;
  FUseIncrementalColor:=AValue;
  if FUseIncrementalColor
  then MarkupInfo.Assign(FMarkupInfoIncr)
  else MarkupInfo.Assign(FMarkupInfoSelection);
end;

procedure TSynEditMarkupSelection.MarkupChangedIntern(AMarkup : TObject);
begin
  if FUseIncrementalColor
  then MarkupInfo.Assign(FMarkupInfoIncr)
  else MarkupInfo.Assign(FMarkupInfoSelection);
end;

constructor TSynEditMarkupSelection.Create(ASynEdit : TCustomControl);
begin
  inherited Create(ASynEdit);
  FMarkupInfoSelection := TSynSelectedColor.Create;
  FMarkupInfoSelection.OnChange := @MarkupChangedIntern;
  FMarkupInfoIncr := TSynSelectedColor.Create;
  FMarkupInfoIncr.OnChange := @MarkupChangedIntern;

  MarkupInfo.Style := [];
  MarkupInfo.StyleMask := [];
end;

destructor TSynEditMarkupSelection.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FMarkupInfoIncr);
  FreeAndNil(FMarkupInfoSelection);
end;

procedure TSynEditMarkupSelection.PrepareMarkupForRow(aRow : Integer);
var
  p1, p2 : TPoint;
begin
  nSelStart := 0;
  nSelEnd := 0;

  if (not TSynEdit(SynEdit).HideSelection or TSynEdit(SynEdit).Focused) then begin
    p1 := TSynEdit(SynEdit).BlockBegin;  // always ordered
    p2 := TSynEdit(SynEdit).BlockEnd;

    if (p1.y > aRow) or (p2.y < aRow)
    then exit;
    
    p1 := LogicalToPhysicalPos(p1);
    p2 := LogicalToPhysicalPos(p2);
    nSelStart := 1;
    nSelEnd := -1; // line end
    if (TSynEdit(SynEdit).SelectionMode = smColumn) then begin
      if (p1.X < p2.X) then begin
        nSelStart := p1.X;
        nSelEnd := p2.X;
      end else begin
        nSelStart := p2.X;
        nSelEnd := p1.X;
      end;
    end else if (TSynEdit(SynEdit).SelectionMode = smNormal) then begin
      if p1.y = aRow
      then nSelStart := p1.x;
      if p2.y = aRow
      then nSelEnd := p2.x;
    end;
  end;
end;

function TSynEditMarkupSelection.GetMarkupAttributeAtRowCol(const aRow, aCol : Integer) : TSynSelectedColor;
begin
  result := nil;
  if (aCol >= nSelStart) and ((aCol < nSelEnd) or (nSelEnd < 0))
  then Result := MarkupInfo;
end;

function TSynEditMarkupSelection.GetNextMarkupColAfterRowCol(const aRow, aCol : Integer) : Integer;
begin
  result := -1;
  if (aCol < nSelStart)
  then Result := nSelStart;
  if (aCol < nSelEnd) and (aCol >= nSelStart)
  then result := nSelEnd;
end;

end.

