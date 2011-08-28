unit TADataPointsEditor;

{$H+}

interface

uses
  ButtonPanel, Classes, ExtCtrls, Grids, Menus, SysUtils, FileUtil, Forms,
  Controls, Graphics, Dialogs;

type
  TDataPointsEditorForm = class(TForm)
    ButtonPanel1: TButtonPanel;
    miInsertRow: TMenuItem;
    miDeleteRow: TMenuItem;
    pmRows: TPopupMenu;
    sgData: TStringGrid;
    procedure miDeleteRowClick(Sender: TObject);
    procedure miInsertRowClick(Sender: TObject);
    procedure pmRowsPopup(Sender: TObject);
  strict private
    FCurrentRow: Integer;
    FDataPoints: TStrings;
    FYCount: Integer;
  public
    procedure InitData(AYCount: Integer; ADataPoints: TStrings);
    procedure ExtractData;
  end;

procedure Register;

implementation

uses
  Math, PropEdits, TASources;

{$R *.lfm}

type
  TDataPointsPropertyEditor = class(TPropertyEditor)
  public
    procedure Edit; override;
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: AnsiString; override;
  end;

procedure Register;
begin
  RegisterPropertyEditor(
    TypeInfo(TStrings), TListChartSource, 'DataPoints',
    TDataPointsPropertyEditor);
end;

{ TDataPointsEditorForm }

procedure TDataPointsEditorForm.ExtractData;
var
  i: Integer;
  s: String;
begin
  FDataPoints.BeginUpdate;
  try
    FDataPoints.Clear;
    for i := 1 to sgData.RowCount - 1 do begin
      with sgData.Rows[i] do begin
        Delimiter := '|';
        StrictDelimiter := true;
        s := DelimitedText;
      end;
      if Length(s) >= sgData.ColCount then
        FDataPoints.Add(Copy(s, 2, MaxInt));
    end;
  finally
    FDataPoints.EndUpdate;
  end;
end;

procedure TDataPointsEditorForm.InitData(
  AYCount: Integer; ADataPoints: TStrings);
var
  i: Integer;
begin
  FYCount := AYCount;
  FDataPoints := ADataPoints;
  sgData.ColCount := AYCount + 4;
  sgData.RowCount := Max(ADataPoints.Count + 1, 2);
  sgData.Cells[0, 0] := 'No.';
  sgData.Cells[1, 0] := 'X';
  sgData.Cells[2, 0] := 'Y';
  for i := 2 to AYCount do
    sgData.Cells[i + 1, 0] := 'Y' + IntToStr(i);
  sgData.Cells[AYCount + 2, 0] := 'Color';
  sgData.Cells[AYCount + 3, 0] := 'Text';
  for i := 0 to ADataPoints.Count - 1 do
    with sgData.Rows[i + 1] do begin
      Delimiter := '|';
      StrictDelimiter := true;
      DelimitedText := '|' + ADataPoints[i];
  end;
end;

procedure TDataPointsEditorForm.miDeleteRowClick(Sender: TObject);
begin
  if sgData.RowCount <= 2 then begin
    sgData.Rows[1].Clear;
    exit;
  end;
  if InRange(FCurrentRow, 1, sgData.RowCount - 1) then begin
    sgData.DeleteRow(FCurrentRow);
  end;
end;

procedure TDataPointsEditorForm.miInsertRowClick(Sender: TObject);
begin
  sgData.InsertColRow(false, FCurrentRow);
end;

procedure TDataPointsEditorForm.pmRowsPopup(Sender: TObject);
begin
  FCurrentRow := sgData.MouseToCell(sgData.ScreenToClient(Mouse.CursorPos)).Y;
  if not InRange(FCurrentRow, 1, sgData.RowCount - 1) then
    Abort;
  sgData.Row := FCurrentRow;
end;

{ TDataPointsPropertyEditor }

procedure TDataPointsPropertyEditor.Edit;
begin
  with TDataPointsEditorForm.Create(nil) do
    try
      InitData(
        (GetComponent(0) as TListChartSource).YCount,
        GetObjectValue as TStrings);
      if ShowModal = mrOK then
        ExtractData;
    finally
      Free;
    end;
end;

function TDataPointsPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paDialog, paMultiSelect, paReadOnly, paRevertable];
end;

function TDataPointsPropertyEditor.GetValue: AnsiString;
begin
  Result := (GetObjectValue as TStrings).Text;
end;

end.

