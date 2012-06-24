{
Reads a MathML Document

License: The same modified LGPL as the Free Pascal RTL
         See the file COPYING.modifiedLGPL for more details

AUTHORS: Felipe Monteiro de Carvalho
}
unit mathmlvectorialreader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, math,
  laz2_xmlread, laz2_dom,
  fpvectorial, fpvutils;

type
  { TvMathMLVectorialReader }

  TvMathMLVectorialReader = class(TvCustomVectorialReader)
  private
    FPointSeparator, FCommaSeparator: TFormatSettings;
    function StringToFloat(AStr: string): Single;
  public
    { General reading methods }
    constructor Create; override;
    Destructor Destroy; override;
    procedure AddNodeToFormula(ANode: TDOMNode; APage: TvVectorialPage; var AFormula: TvFormula);
    procedure ReadFormulaFromNodeChildren(ACurNode: TDOMNode; APage: TvVectorialPage; var AFormula: TvFormula);
    procedure ReadFromStream(AStream: TStream; AData: TvVectorialDocument); override;
  end;

implementation

{ TvMathMLVectorialReader }

function TvMathMLVectorialReader.StringToFloat(AStr: string): Single;
begin
  Result := StrToInt(AStr);
end;

constructor TvMathMLVectorialReader.Create;
begin
  inherited Create;

  FPointSeparator := DefaultFormatSettings;
  FPointSeparator.DecimalSeparator := '.';
  FPointSeparator.ThousandSeparator := '#';// disable the thousand separator
end;

destructor TvMathMLVectorialReader.Destroy;
begin
  inherited Destroy;
end;

procedure TvMathMLVectorialReader.AddNodeToFormula(ANode: TDOMNode;
  APage: TvVectorialPage; var AFormula: TvFormula);
var
  lNodeName, lNodeText, lSubNodeName: DOMString;
  lFormula, lFormulaBottom: TvFormula;
  lFormElem: TvFormulaElement;
  lMFracRow: TDOMNode;
  lSubNodeNameStr: DOMString;
begin
  lNodeName := ANode.NodeName;
  lNodeText := ANode.FirstChild.NodeValue;
  // mi - variables
  // Examples:
  // <mi>x</mi>
  if lNodeName = 'mi' then
  begin
    AFormula.AddElementWithKindAndText(fekVariable, lNodeText);
  end
  // mn - numbers
  // Examples:
  // <mn>4</mn>
  else if lNodeName = 'mn' then
  begin
    AFormula.AddElementWithKindAndText(fekVariable, lNodeText);
  end
  // <mo>=</mo>
  else if lNodeName = 'mo' then
  begin
    // equal
    if lNodeText = '=' then
      AFormula.AddElementWithKind(fekEqual)
    // minus
    else if (lNodeText = '&#x2212;') or (lNodeText = #$22#$12) then
      AFormula.AddElementWithKind(fekSubtraction)
    // &InvisibleTimes;
    else if (lNodeText = '&#x2062;') or (lNodeText = #$20#$62) then
      AFormula.AddElementWithKind(fekMultiplication)
    // &PlusMinus;
    else if (lNodeText = '&#x00B1;') or (lNodeText = #$00#$B1) then
      AFormula.AddElementWithKind(fekPlusMinus)
    //
    else
      AFormula.AddElementWithKindAndText(fekVariable, lNodeText);
  end
  // Fraction
  // should contain two sets of: <mrow>...elements...</mrow>
  else if lNodeName = 'mfrac' then
  begin
    // Top line
    lMFracRow := ANode.FirstChild;
    lSubNodeName := lMFracRow.NodeName;
    if lSubNodeName = 'mrow' then
    begin
      lFormula := TvFormula.Create;
      ReadFormulaFromNodeChildren(lMFracRow, APage, lFormula);
    end
    else
      raise Exception.Create(Format('[TvMathMLVectorialReader.ReadFormulaFromNode] Error reading mfrac: expected mrow, got %s', [lSubNodeName]));    // Bottom line
    lMFracRow := lMFracRow.NextSibling;
    lSubNodeName := lMFracRow.NodeName;
    if lSubNodeName = 'mrow' then
    begin
      lFormulaBottom := TvFormula.Create;
      ReadFormulaFromNodeChildren(lMFracRow, APage, lFormulaBottom);
    end
    else
      raise Exception.Create(Format('[TvMathMLVectorialReader.ReadFormulaFromNode] Error reading mfrac: expected mrow, got %s', [lSubNodeName]));
    // Now add both formulas into our element
    lFormElem := AFormula.AddElementWithKind(fekFraction);
    lFormElem.Formula := lFormula;
    lFormElem.AdjacentFormula := lFormulaBottom;
  end
  // Square Root
  // might contain 1 set of: <mrow>...elements...</mrow>
  // or just: ...elements...
  else if lNodeName = 'msqrt' then
  begin
    lFormula := TvFormula.Create;

    lMFracRow := ANode.FirstChild;
    lSubNodeName := lMFracRow.NodeName;
    if lSubNodeName = 'mrow' then
      ReadFormulaFromNodeChildren(lMFracRow, APage, lFormula)
    else
      ReadFormulaFromNodeChildren(ANode, APage, lFormula);

    lFormElem := AFormula.AddElementWithKind(fekRoot);
    lFormElem.Formula := lFormula;
  end
  // msup - Power
  // Example: b^2
  //<msup>
  //  <mi>b</mi>
  //  <mn>2</mn>
  //</msup>
  else if lNodeName = 'msup' then
  begin
    lFormElem := AFormula.AddElementWithKind(fekPower);
    lFormElem.Formula := TvFormula.Create;
    lFormElem.AdjacentFormula := TvFormula.Create;

    // First read the bottom element
    lMFracRow := ANode.FirstChild;
    AddNodeToFormula(lMFracRow, APage, lFormElem.Formula);

    // Now the top element
    lMFracRow := lMFracRow.NextSibling;
    AddNodeToFormula(lMFracRow, APage, lFormElem.AdjacentFormula);
  end
  // mrow may appear where unnecessary, in this cases just keep reading further
  else if lNodeName = 'mrow' then
  begin
    lMFracRow := ANode.FirstChild;
    ReadFormulaFromNodeChildren(lMFracRow, APage, AFormula);
  end;
end;

procedure TvMathMLVectorialReader.ReadFormulaFromNodeChildren(ACurNode: TDOMNode;
  APage: TvVectorialPage; var AFormula: TvFormula);
var
  lCurNode: TDOMNode;
begin
  // Now process the elements inside the first layer
  lCurNode := ACurNode.FirstChild;
  while Assigned(lCurNode) do
  begin
    AddNodeToFormula(lCurNode, APage, AFormula);

    lCurNode := lCurNode.NextSibling;
  end;
end;

procedure TvMathMLVectorialReader.ReadFromStream(AStream: TStream;
  AData: TvVectorialDocument);
var
  Doc: TXMLDocument;
  lFirstLayer, lCurNode: TDOMNode;
  lPage: TvVectorialPage;
  lFormula: TvFormula;
  lStr: DOMString;
begin
  try
    // Read in xml file from the stream
    ReadXMLFile(Doc, AStream);

    {// Read the properties of the <svg> tag
    AData.Width := StringWithUnitToFloat(Doc.DocumentElement.GetAttribute('width'));
    AData.Height := StringWithUnitToFloat(Doc.DocumentElement.GetAttribute('height'));}

    // Now process the elements inside the first layer
    lFirstLayer := Doc.DocumentElement;
    lCurNode := lFirstLayer.FirstChild;
    lPage := AData.AddPage();
    lPage.Width := AData.Width;
    lPage.Height := AData.Height;
    while Assigned(lCurNode) do
    begin
      lStr := lCurNode.NodeName;
      if lStr = 'mrow' then
      begin
        lFormula := TvFormula.Create;
        ReadFormulaFromNodeChildren(lCurNode, lPage, lFormula);
        lPage.AddEntity(lFormula);
      end
      else
        raise Exception.Create(Format('[TvMathMLVectorialReader.ReadFromStream] Expected mrow, got %s', [lStr]));

      lCurNode := lCurNode.NextSibling;
    end;
  finally
    // finally, free the document
    Doc.Free;
  end;
end;

initialization

  RegisterVectorialReader(TvMathMLVectorialReader, vfMathML);

end.

