{ Copyright (C) 2004 Dean Zobec

  This library is free software; you can redistribute it and/or modify it
  under the terms of the GNU Library General Public License as published by
  the Free Software Foundation; either version 2 of the License, or (at your
  option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU Library General Public License
  for more details.

  You should have received a copy of the GNU Library General Public License
  along with this library; if not, write to the Free Software Foundation,
  Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
}
unit GuiTestRunner;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  Buttons, ComCtrls, ActnList, Menus, Clipbrd, StdCtrls,
  testreport, fpcunit, testregistry;

type

  { TGUITestRunner }

  TGUITestRunner = class(TForm, ITestListener)
    actCopy: TAction;
    actCut: TAction;
    ActionList1: TActionList;
    btnClose: TBitBtn;
    btnRun: TBitBtn;
    ImageList1: TImageList;
    ImageList2: TImageList;
    Label1: TLabel;
    lblSelectedTest: TLabel;
    Memo1: TMemo;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    pbBar1: TPaintBox;
    PopupMenu1: TPopupMenu;
    PopupMenu2: TPopupMenu;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    XMLMemo: TMemo;
    pbBar: TPaintBox;
    Panel4: TPanel;
    Panel5: TPanel;
    Splitter1: TSplitter;
    PageControl1: TPageControl;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    tsTestTree: TTabSheet;
    tsResultsXML: TTabSheet;
    TestTree: TTreeView;
    procedure BtnCloseClick(Sender: TObject);
    procedure GUITestRunnerCreate(Sender: TObject);
    procedure GUITestRunnerShow(Sender: TObject);
    procedure MenuItem3Click(Sender: TObject);
    procedure TestTreeSelectionChanged(Sender: TObject);
    procedure pbBarPaint(Sender: TObject);
    procedure actCopyExecute(Sender: TObject);
    procedure actCutExecute(Sender: TObject);
    procedure btnRunClick(Sender: TObject);
  private
    failureCounter: Integer;
    errorCounter: Integer;
    testsCounter: Integer;
    barColor: TColor;
    testSuite: TTest;
    procedure BuildTree(rootNode: TTreeNode; aSuite: TTestSuite);
    function FindNode(aTest: TTest): TTreeNode;
    procedure ResetNodeColors;
    procedure PaintNodeError(aNode: TTreeNode);
    procedure PaintNodeFailure(aNode: TTreeNode);
    procedure PaintNodeSuccess(aNode: TTreeNode);
    procedure PaintRunnableSubnodes(aNode: TTreeNode);
  public
    procedure AddFailure(ATest: TTest; AFailure: TTestFailure);
    procedure AddError(ATest: TTest; AError: TTestFailure);
    procedure StartTest(ATest: TTest);
    procedure EndTest(ATest: TTest);
  end;

var
  TestRunner: TGUITestRunner;

implementation

{ TGUITestRunner }

procedure TGUITestRunner.actCopyExecute(Sender: TObject);
begin
  Clipboard.AsText := XMLMemo.Lines.Text;
end;

procedure TGUITestRunner.actCutExecute(Sender: TObject);
begin
  Clipboard.AsText := XMLMemo.Lines.Text;
  XMLMemo.Lines.Clear;
end;

procedure TGUITestRunner.GUITestRunnerCreate(Sender: TObject);
var
  i: integer;
begin
  barColor := clGreen;
  TestTree.Items.Clear;
  BuildTree(TestTree.Items.AddObject(nil, 'All Tests', GetTestRegistry), GetTestRegistry);
end;

procedure TGUITestRunner.BtnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TGUITestRunner.GUITestRunnerShow(Sender: TObject);
begin
  if (ParamStr(1) = '--now') or (ParamStr(1) = '-n') then
    BtnRunClick(Self);
end;

procedure TGUITestRunner.MenuItem3Click(Sender: TObject);
begin
  Clipboard.AsText := Memo1.Lines.Text;
end;

procedure TGUITestRunner.TestTreeSelectionChanged(Sender: TObject);
var
  i: integer;
begin
  if (Sender as TTreeView).Selected <> nil then
  begin
    Memo1.Lines.Text := (Sender as TTreeview).Selected.Text;
    lblSelectedTest.Caption := (Sender as TTreeview).Selected.Text;
  end;
end;

procedure TGUITestRunner.pbBarPaint(Sender: TObject);
var
  msg: string;
begin
  with (Sender as TPaintBox) do
  begin
    Canvas.Brush.Color := clSilver;
    Canvas.Rectangle(0, 0, Width, Height);
    if Assigned(TestSuite) then
    begin
      if (FailureCounter = 0) and (ErrorCounter = 0) and
      (TestsCounter = TestSuite.CountTestCases) then
        barColor := clGreen;
      Canvas.Brush.Color := barColor;
      if TestsCounter <> 0 then
      begin
        Canvas.Rectangle(0, 0, round(TestsCounter / TestSuite.CountTestCases * Width), Height);
        Canvas.Font.Color := clWhite;
        msg := 'Runs: ' + IntToStr(TestsCounter);
        if ErrorCounter <> 0 then
          msg := msg + '    Number of test errors: ' + IntToStr(ErrorCounter);
        if (FailureCounter <> 0) then
        msg := msg + '     Number of test failures: ' + IntToStr(FailureCounter);
        Canvas.Textout(10, 10,  msg)
      end;
    end;
  end;
end;

procedure TGUITestRunner.btnRunClick(Sender: TObject);
var
  testResult: TTestResult;
begin
  barcolor := clGreen;
  ResetNodeColors;
  if (TestTree.Selected <> nil) and (TestTree.Selected.Data <> nil) then
  begin
    testSuite := TTest(TestTree.Selected.Data);
    PaintNodeSuccess(TestTree.Selected);
    PaintRunnableSubnodes(TestTree.Selected);
  end
  else
    begin
      testSuite := GetTestRegistry;
      TestTree.Selected := TestTree.Items[0];
      ResetNodeColors;
      PaintRunnableSubnodes(TestTree.Selected);
    end;
  failureCounter := 0;
  errorCounter := 0;
  testsCounter := 0;
  testResult := TTestResult.Create;
  try
    testResult.AddListener(self);
    testSuite.Run(testResult);
    XMLMemo.lines.text:= '<TestResults>' + system.sLineBreak +
      TestResultAsXML(testResult) + system.sLineBreak + '</TestResults>';
  finally
    testResult.Free;
  end;
  pbBar.invalidate;
  pbBar1.invalidate;
end;

procedure TGUITestRunner.BuildTree(rootNode: TTreeNode; aSuite: TTestSuite);
var
  node: TTreeNode;
  i: integer;
begin
  for i := 0 to ASuite.Tests.Count - 1 do
  begin
    node := TestTree.Items.AddChildObject(rootNode, ASuite.Test[i].TestName, ASuite.Test[i]);
    if ASuite.Test[i] is TTestSuite then
      BuildTree(Node, ASuite.Test[i] as TTestSuite);
    node.ImageIndex := 12;
    node.SelectedIndex := 12;
  end;
end;

function TGUITestRunner.FindNode(aTest: TTest): TTreeNode;
var
  i: integer;
begin
  Result := nil;
  for i := 0 to TestTree.Items.Count -1 do
    if (TTest(TestTree.Items[i].data) = aTest) then
    begin
      Result :=  TestTree.Items[i];
      Exit;
    end;
end;

procedure TGUITestRunner.ResetNodeColors;
var
  i: integer;
begin
  for i := 0 to TestTree.Items.Count - 1 do
  begin
    TestTree.Items[i].ImageIndex := 12;
    TestTree.Items[i].SelectedIndex := 12;
  end;
end;

procedure TGUITestRunner.PaintNodeError(aNode: TTreeNode);
begin
  while Assigned(aNode) do
  begin
    aNode.ImageIndex := 2;
    aNode.SelectedIndex := 2;
    aNode := aNode.Parent;
    if Assigned(aNode) and (aNode.ImageIndex in [0, 3, 12, -1]) then
      PaintNodeError(aNode);
  end;
end;

procedure TGUITestRunner.PaintNodeFailure(aNode: TTreeNode);
begin
  while Assigned(aNode) do
  begin
    if aNode.ImageIndex in [0, -1, 12] then
    begin
      aNode.ImageIndex := 3;
      aNode.SelectedIndex := 3;
    end;
    aNode := aNode.Parent;
    if Assigned(aNode) and (aNode.ImageIndex in [0, -1, 12]) then
      PaintNodeFailure(aNode);
  end;
end;

procedure TGUITestRunner.PaintNodeSuccess(aNode: TTreeNode);
begin
  if Assigned(aNode) then
  begin
    aNode.ImageIndex := 0;
    aNode.SelectedIndex := 0;
  end;
end;

procedure TGUITestRunner.PaintRunnableSubnodes(aNode: TTreeNode);
var
  i: integer;
begin
  if Assigned(aNode) then
  begin
    aNode.ImageIndex := 0;
    aNode.SelectedIndex := 0;
    for i := 0 to aNode.Count - 1 do
      if aNode.Items[i].Count > 0 then
        PaintRunnableSubnodes(aNode.Items[i]);
  end;
end;

procedure TGUITestRunner.AddFailure(ATest: TTest; AFailure: TTestFailure);
var
  FailureNode, node: TTreeNode;
begin
  FailureNode := FindNode(ATest);
  if Assigned(FailureNode) then
  begin
    FailureNode.DeleteChildren;
    node := TestTree.Items.AddChild(FailureNode, 'Message: ' + AFailure.ExceptionMessage);
    node.ImageIndex := 4;
    node.SelectedIndex := 4;
    node := TestTree.Items.AddChild(FailureNode, 'Exception: ' + AFailure.ExceptionClassName);
    node.ImageIndex := 4;
    node.SelectedIndex := 4;
    PaintNodeFailure(FailureNode);
  end;
  Inc(failureCounter);
  if errorCounter = 0 then
    barColor := clFuchsia;
end;

procedure TGUITestRunner.AddError(ATest: TTest; AError: TTestFailure);
var
  ErrorNode, node: TTreeNode;
begin
  ErrorNode := FindNode(ATest);
  if Assigned(ErrorNode) then
  begin
    ErrorNode.DeleteChildren;
    node := TestTree.Items.AddChild(ErrorNode, 'Exception message: ' + AError.ExceptionMessage);
    node.ImageIndex := 4;
    node.SelectedIndex := 4;
    node := TestTree.Items.AddChild(ErrorNode, 'Exception class: ' + AError.ExceptionClassName);
    node.ImageIndex := 4;
    node.SelectedIndex := 4;
    node := TestTree.Items.AddChild(ErrorNode, 'Unit name: ' + AError.SourceUnitName);
    node.ImageIndex := 11;
    node.SelectedIndex := 11;
    node := TestTree.Items.AddChild(ErrorNode, 'Method name: ' + AError.MethodName);
    node.ImageIndex := 11;
    node.SelectedIndex := 11;
    node := TestTree.Items.AddChild(ErrorNode, 'Line number: ' + IntToStr(AError.LineNumber));
    node.ImageIndex := 11;
    node.SelectedIndex := 11;
    PaintNodeError(ErrorNode);
  end;
  Inc(errorCounter);
  barColor := clRed;
end;

procedure TGUITestRunner.StartTest(ATest: TTest);
var
  Node: TTreeNode;
begin
  Node := FindNode(ATest);
  if Assigned(Node) then
  begin
    Node.ImageIndex := 0;
    Node.SelectedIndex := 0;
  end;
  Application.ProcessMessages;
end;

procedure TGUITestRunner.EndTest(ATest: TTest);
begin
  Inc(testsCounter);
  pbBar.invalidate;
  pbBar1.invalidate;
  Application.ProcessMessages;
end;

initialization
  {$I guitestrunner.lrs}

end.

