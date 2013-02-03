{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.        *
 *                                                                         *
 ***************************************************************************

  Author: Mattias Gaertner

  Abstract:
    LCL controls for Cody.
}
unit CodyCtrls;

{$mode objfpc}{$H+}

interface

uses
  types, math, contnrs, Classes, SysUtils, FPCanvas, FPimage,
  LazLogger, AvgLvlTree, ComCtrls, Controls, Graphics, LCLType;

type

  { TCodyTreeView }

  TCodyTreeView = class(TTreeView)
  public
    procedure FreeNodeData;
  end;

const
  FullCircle16 = 360*16;
  DefaultCategoryGapDegree16 = 0.02*FullCircle16;
  DefaultFirstCategoryDegree16 = 0;
  DefaultCategoryMinSize = 1.0;
  DefaultItemSize = 1.0;
type
  TCustomCircleDiagramControl = class;
  TCircleDiagramCategory = class;

  { TCircleDiagramItem }

  TCircleDiagramItem = class(TPersistent)
  private
    FCaption: TCaption;
    FCategory: TCircleDiagramCategory;
    FEndDegree16: single;
    FSize: single;
    FStartDegree16: single;
    procedure SetCaption(AValue: TCaption);
    procedure SetSize(AValue: single);
    procedure UpdateLayout;
  public
    Data: Pointer; // free to use by user
    constructor Create(TheCategory: TCircleDiagramCategory);
    destructor Destroy; override;
    property Category: TCircleDiagramCategory read FCategory;
    property Caption: TCaption read FCaption write SetCaption;
    property Size: single read FSize write SetSize default DefaultItemSize; // scaled to fit
    property StartDegree16: single read FStartDegree16; // 360*16 = one full circle, 0 at 3o'clock
    property EndDegree16: single read FEndDegree16;     // 360*16 = one full circle, 0 at 3o'clock
  end;

  { TCircleDiagramCategory }

  TCircleDiagramCategory = class(TPersistent)
  private
    FCaption: TCaption;
    FColor: TColor;
    FDiagram: TCustomCircleDiagramControl;
    FEndDegree16: single;
    FMinSize: single;
    fItems: TFPList; // list of TCircleDiagramItem
    FSize: single;
    FStartDegree16: single;
    function GetItems(Index: integer): TCircleDiagramItem;
    procedure SetCaption(AValue: TCaption);
    procedure SetColor(AValue: TColor);
    procedure SetMinSize(AValue: single);
    procedure UpdateLayout;
    procedure Invalidate;
    procedure InternalRemoveItem(Item: TCircleDiagramItem);
  public
    Data: Pointer; // free to use by user
    constructor Create(TheDiagram: TCustomCircleDiagramControl);
    destructor Destroy; override;
    procedure Clear;
    function InsertItem(Index: integer; aCaption: string): TCircleDiagramItem;
    function AddItem(aCaption: string): TCircleDiagramItem;
    property Diagram: TCustomCircleDiagramControl read FDiagram;
    property Caption: TCaption read FCaption write SetCaption;
    property MinSize: single read FMinSize write SetMinSize default DefaultCategoryMinSize; // scaled to fit
    function Count: integer;
    property Items[Index: integer]: TCircleDiagramItem read GetItems; default;
    property Color: TColor read FColor write SetColor;
    property Size: single read FSize;
    property StartDegree16: single read FStartDegree16; // 360*16 = one full circle, 0 at 3o'clock
    property EndDegree16: single read FEndDegree16;     // 360*16 = one full circle, 0 at 3o'clock
  end;

  TCircleDiagramCtrlFlag = (
    cdcNeedUpdateLayout
    );
  TCircleDiagramCtrlFlags = set of TCircleDiagramCtrlFlag;

  { TCustomCircleDiagramControl }

  TCustomCircleDiagramControl = class(TCustomControl)
  private
    FCategoryGapDegree16: single;
    FCenter: TPoint;
    FCenterCaption: TCaption;
    FCenterCaptionRect: TRect;
    FFirstCategoryDegree16: single;
    fCategories: TObjectList; // list of TCircleDiagramCategory
    FInnerRadius: single;
    FOuterRadius: single;
    fUpdateLock: integer;
    fFlags: TCircleDiagramCtrlFlags;
    function GetCategories(Index: integer): TCircleDiagramCategory;
    procedure SetCategoryGapDegree16(AValue: single);
    procedure SetCenterCaption(AValue: TCaption);
    procedure SetFirstCategoryDegree16(AValue: single);
    procedure InternalRemoveCategory(Category: TCircleDiagramCategory);
  protected
    //procedure WMVScroll(var Msg: TLMScroll); message LM_VSCROLL;
    //procedure WMMouseWheel(var Message: TLMMouseEvent); message LM_MOUSEWHEEL;
    procedure CreateWnd; override;
    procedure UpdateScrollBar;
    procedure DoSetBounds(ALeft, ATop, AWidth, AHeight: integer); override;

    //procedure MouseDown(Button:TMouseButton; Shift:TShiftState; X,Y:integer); override;
    //procedure MouseMove(Shift:TShiftState; X,Y:integer);  override;
    //procedure MouseUp(Button:TMouseButton; Shift:TShiftState; X,Y:integer); override;

    //procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    //procedure HandleStandardKeys(var Key: Word; Shift: TShiftState); virtual;
    //procedure HandleKeyUp(var Key: Word; Shift: TShiftState); virtual;

    procedure Paint; override;
    procedure DrawCategory(i: integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property CenterCaption: TCaption read FCenterCaption write SetCenterCaption;
    procedure Clear;
    procedure BeginUpdate; virtual;
    procedure EndUpdate; virtual;
    procedure UpdateLayout;
    procedure EraseBackground({%H-}DC: HDC); override;
    function InsertCategory(Index: integer; aCaption: TCaption): TCircleDiagramCategory;
    function AddCategory(aCaption: TCaption): TCircleDiagramCategory;
    function IndexOfCategory(aCaption: TCaption): integer;
    function FindCategory(aCaption: TCaption): TCircleDiagramCategory;
    property CategoryGapDegree16: single read FCategoryGapDegree16 write SetCategoryGapDegree16 default DefaultCategoryGapDegree16; // 360*16 = one full circle, 0 at 3o'clock
    property FirstCategoryDegree16: single read FFirstCategoryDegree16 write SetFirstCategoryDegree16 default DefaultFirstCategoryDegree16; // 360*16 = one full circle, 0 at 3o'clock
    function CategoryCount: integer;
    property Categories[Index: integer]: TCircleDiagramCategory read GetCategories; default;
    property Color default clWhite;
    // computed values
    property CenterCaptionRect: TRect read FCenterCaptionRect;
    property Center: TPoint read FCenter;
    property InnerRadius: single read FInnerRadius;
    property OuterRadius: single read FOuterRadius;

    // debugging
    procedure WriteDebugReport(Msg: string);
  end;

  { TCircleDiagramControl }

  TCircleDiagramControl = class(TCustomCircleDiagramControl)
  published
    property Align;
    property Anchors;
    property BorderSpacing;
    property BorderStyle;
    property BorderWidth;
    property Color;
    property Constraints;
    property DragKind;
    property DragCursor;
    property DragMode;
    property Enabled;
    property Font;
    property ParentColor default False;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default True;
    property Tag;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnShowHint;
    property OnStartDrag;
    property OnUTF8KeyPress;
  end;

  TLvlGraph = class;
  TLvlGraphEdge = class;
  TLvlGraphLevel = class;

  { TLvlGraphNode }

  TLvlGraphNode = class(TPersistent)
  private
    FCaption: string;
    FColor: TFPColor;
    FGraph: TLvlGraph;
    FInEdges: TFPList; // list of TLvlGraphEdge
    FDrawSize: integer;
    FInSize: single;
    FLevel: TLvlGraphLevel;
    FOutEdges: TFPList; // list of TLvlGraphEdge
    FDrawPosition: integer;
    FOutSize: single;
    function GetInEdges(Index: integer): TLvlGraphEdge;
    function GetOutEdges(Index: integer): TLvlGraphEdge;
    procedure SetCaption(AValue: string);
    procedure SetColor(AValue: TFPColor);
    procedure OnLevelDestroy;
    procedure SetLevel(AValue: TLvlGraphLevel);
    procedure UnbindLevel;
  public
    Data: Pointer; // free for user data
    constructor Create(TheGraph: TLvlGraph; TheCaption: string; TheLevel: TLvlGraphLevel);
    destructor Destroy; override;
    procedure Clear;
    procedure Invalidate;
    property Color: TFPColor read FColor write SetColor;
    property Caption: string read FCaption write SetCaption;
    property Graph: TLvlGraph read FGraph;
    function IndexOfInEdge(Source: TLvlGraphNode): integer;
    function FindInEdge(Source: TLvlGraphNode): TLvlGraphEdge;
    function InEdgeCount: integer;
    property InEdges[Index: integer]: TLvlGraphEdge read GetInEdges;
    function IndexOfOutEdge(Target: TLvlGraphNode): integer;
    function FindOutEdge(Target: TLvlGraphNode): TLvlGraphEdge;
    function OutEdgeCount: integer;
    property OutEdges[Index: integer]: TLvlGraphEdge read GetOutEdges;
    property DrawPosition: integer read FDrawPosition write FDrawPosition; // position in a level
    function DrawCenter: integer;
    function DrawPositionEnd: integer;// = DrawPosition+Max(InSize,OutSize)
    property DrawSize: integer read FDrawSize default 1;
    property Level: TLvlGraphLevel read FLevel write SetLevel;
    property InSize: single read FInSize; // total weight of InEdges
    property OutSize: single read FOutSize; // total weight of OutEdges
  end;

  { TLvlGraphEdge }

  TLvlGraphEdge = class(TPersistent)
  private
    FBackEdge: boolean;
    FSource: TLvlGraphNode;
    FTarget: TLvlGraphNode;
    FWeight: single;
    procedure SetWeight(AValue: single);
  public
    Data: Pointer; // free for user data
    constructor Create(TheSource: TLvlGraphNode; TheTarget: TLvlGraphNode);
    destructor Destroy; override;
    property Source: TLvlGraphNode read FSource;
    property Target: TLvlGraphNode read FTarget;
    property Weight: single read FWeight write SetWeight;
    function IsBackEdge: boolean;
    property BackEdge: boolean read FBackEdge; // edge was disabled to break a cycle
  end;

  { TLvlGraphLevel }

  TLvlGraphLevel = class(TPersistent)
  private
    FGraph: TLvlGraph;
    FIndex: integer;
    fNodes: TFPList;
    FDrawPosition: integer;
    function GetNodes(Index: integer): TLvlGraphNode;
    procedure SetDrawPosition(AValue: integer);
  public
    constructor Create(TheGraph: TLvlGraph; TheIndex: integer);
    destructor Destroy; override;
    procedure Invalidate;
    property Nodes[Index: integer]: TLvlGraphNode read GetNodes; default;
    function IndexOf(Node: TLvlGraphNode): integer;
    function Count: integer;
    property Index: integer read FIndex;
    property Graph: TLvlGraph read FGraph;
    property DrawPosition: integer read FDrawPosition write SetDrawPosition;
  end;

  { TLvlGraph }

  TLvlGraph = class(TPersistent)
  private
    FOnInvalidate: TNotifyEvent;
    FNodes: TFPList; // list of TLvlGraphNode
    fLevels: TFPList;
    function GetLevelCount: integer;
    function GetLevels(Index: integer): TLvlGraphLevel;
    function GetNodes(Index: integer): TLvlGraphNode;
    procedure SetLevelCount(AValue: integer);
    procedure InternalRemoveLevel(Lvl: TLvlGraphLevel);
  public
    Data: Pointer; // free for user data
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Invalidate;
    property OnInvalidate: TNotifyEvent read FOnInvalidate write FOnInvalidate;
    function NodeCount: integer;
    property Nodes[Index: integer]: TLvlGraphNode read GetNodes;
    function GetNode(aCaption: string; CreateIfNotExists: boolean): TLvlGraphNode;
    function GetEdge(SourceCaption, TargetCaption: string;
      CreateIfNotExists: boolean): TLvlGraphEdge;
    function GetEdge(Source, Target: TLvlGraphNode;
      CreateIfNotExists: boolean): TLvlGraphEdge;
    property Levels[Index: integer]: TLvlGraphLevel read GetLevels;
    property LevelCount: integer read GetLevelCount write SetLevelCount;
    procedure CreateTopologicalLevels; // create levels from edges
    procedure MarkBackEdges;
    procedure MinimizeCrossings; // set all Node.Position to minimize crossings
    procedure MinimizeOverlappings(Gap: integer = 1; aLevel: integer = -1); // set all Node.Position to minimize overlappings
    procedure WriteDebugReport(Msg: string);
    procedure ConsistencyCheck(WithBackEdge: boolean);
  end;

  { TCustomLvlGraphControl }

  TCustomLvlGraphControl = class(TCustomControl)
    procedure FGraphInvalidate(Sender: TObject);
  private
    FGraph: TLvlGraph;
  protected
    procedure DoSetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure EraseBackground({%H-}DC: HDC); override;
    property Graph: TLvlGraph read FGraph;
  end;

  { TLvlGraphControl }

  TLvlGraphControl = class(TCustomLvlGraphControl)
  published
    property Align;
    property Anchors;
    property BorderSpacing;
    property BorderStyle;
    property BorderWidth;
    property Color;
    property Constraints;
    property DragKind;
    property DragCursor;
    property DragMode;
    property Enabled;
    property Font;
    property ParentColor default False;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default True;
    property Tag;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnShowHint;
    property OnStartDrag;
    property OnUTF8KeyPress;
  end;

procedure FreeTVNodeData(TV: TCustomTreeView);

procedure RingSector(Canvas: TFPCustomCanvas; x1, y1, x2, y2: integer;
  InnerSize: single; StartAngle16, EndAngle16: integer); overload;
procedure RingSector(Canvas: TFPCustomCanvas; x1, y1, x2, y2,
  InnerSize, StartAngle, EndAngle: single); overload;

function CompareLGNodesByCenterPos(Node1, Node2: Pointer): integer;

implementation

procedure FreeTVNodeData(TV: TCustomTreeView);
var
  Node: TTreeNode;
begin
  TV.BeginUpdate;
  Node:=TV.Items.GetFirstNode;
  while Node<>nil do begin
    if Node.Data<>nil then begin
      TObject(Node.Data).Free;
      Node.Data:=nil;
    end;
    Node:=Node.GetNext;
  end;
  TV.EndUpdate;
end;

procedure RingSector(Canvas: TFPCustomCanvas; x1, y1, x2, y2: integer;
  InnerSize: single; StartAngle16, EndAngle16: integer);
begin
  RingSector(Canvas,single(x1),single(y1),single(x2),single(y2),InnerSize,
    single(StartAngle16)/16,single(EndAngle16)/16);
end;

procedure RingSector(Canvas: TFPCustomCanvas; x1, y1, x2, y2, InnerSize, StartAngle,
  EndAngle: single);
var
  OuterCnt: integer;
  centerx, centery: single;
  i: Integer;
  Ang: single;
  OuterRadiusX, OuterRadiusY, InnerRadiusX, InnerRadiusY: single;
  Points: array of TPoint;
  j: Integer;
begin
  OuterCnt:=Round(SQRT((Abs(x2-x1)+Abs(y2-y1))*Abs(EndAngle-StartAngle)/FullCircle16)+0.5);
  centerx:=(x1+x2)/2;
  centery:=(y1+y2)/2;
  OuterRadiusX:=(x2-x1)/2;
  OuterRadiusY:=(y2-y1)/2;
  InnerRadiusX:=OuterRadiusX*InnerSize;
  InnerRadiusY:=OuterRadiusY*InnerSize;
  SetLength(Points,OuterCnt*2+2);
  j:=0;
  // outer arc
  for i:=0 to OuterCnt do begin
    Ang:=StartAngle+((EndAngle-StartAngle)/OuterCnt)*single(i);
    Ang:=(Ang/FullCircle16)*2*pi;
    Points[j].x:=round(centerx+cos(Ang)*OuterRadiusX);
    Points[j].y:=round(centery-sin(Ang)*OuterRadiusY);
    inc(j);
  end;
  // inner arc
  for i:=OuterCnt downto 0 do begin
    Ang:=StartAngle+((EndAngle-StartAngle)/OuterCnt)*single(i);
    Ang:=(Ang/FullCircle16)*2*pi;
    Points[j].x:=round(centerx+cos(Ang)*InnerRadiusX);
    Points[j].y:=round(centery-sin(Ang)*InnerRadiusY);
    inc(j);
  end;
  Canvas.Polygon(Points);
  SetLength(Points,0);
end;

function CompareLGNodesByCenterPos(Node1, Node2: Pointer): integer;
var
  LNode1: TLvlGraphNode absolute Node1;
  LNode2: TLvlGraphNode absolute Node2;
  p1: Integer;
  p2: Integer;
begin
  p1:=LNode1.DrawCenter;
  p2:=LNode2.DrawCenter;
  if p1<p2 then
    Result:=1
  else if p1>p2 then
    Result:=-1
  else
    Result:=0;
end;

{ TLvlGraphLevel }

function TLvlGraphLevel.GetNodes(Index: integer): TLvlGraphNode;
begin
  Result:=TLvlGraphNode(fNodes[Index]);
end;

procedure TLvlGraphLevel.SetDrawPosition(AValue: integer);
begin
  if FDrawPosition=AValue then Exit;
  FDrawPosition:=AValue;
  Invalidate;
end;

constructor TLvlGraphLevel.Create(TheGraph: TLvlGraph; TheIndex: integer);
begin
  FGraph:=TheGraph;
  FGraph.fLevels.Add(Self);
  FIndex:=TheIndex;
  fNodes:=TFPList.Create;
end;

destructor TLvlGraphLevel.Destroy;
var
  i: Integer;
begin
  for i:=0 to Count-1 do
    Nodes[i].OnLevelDestroy;
  Graph.InternalRemoveLevel(Self);
  FreeAndNil(fNodes);
  inherited Destroy;
end;

procedure TLvlGraphLevel.Invalidate;
begin
  if Graph<>nil then
    Graph.Invalidate;
end;

function TLvlGraphLevel.IndexOf(Node: TLvlGraphNode): integer;
begin
  for Result:=0 to Count-1 do
    if Nodes[Result]=Node then exit;
  Result:=-1;
end;

function TLvlGraphLevel.Count: integer;
begin
  Result:=fNodes.Count;
end;

{ TCustomLvlGraphControl }

procedure TCustomLvlGraphControl.FGraphInvalidate(Sender: TObject);
begin
  Invalidate;
end;

procedure TCustomLvlGraphControl.DoSetBounds(ALeft, ATop, AWidth,
  AHeight: integer);
begin
  inherited DoSetBounds(ALeft, ATop, AWidth, AHeight);
end;

procedure TCustomLvlGraphControl.Paint;
begin
  inherited Paint;
  // background
  Canvas.Brush.Style:=bsSolid;
  Canvas.Brush.Color:=Color;
  Canvas.FillRect(ClientRect);
end;

constructor TCustomLvlGraphControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGraph:=TLvlGraph.Create;
  FGraph.OnInvalidate:=@FGraphInvalidate;
end;

destructor TCustomLvlGraphControl.Destroy;
begin
  FreeAndNil(FGraph);
  inherited Destroy;
end;

procedure TCustomLvlGraphControl.EraseBackground(DC: HDC);
begin
  // Paint paints all, no need to erase background
end;

type

  { TGraphLevelerNode - used by TLvlGraph.UpdateLevels }

  TGraphLevelerNode = class
  public
    Node: TLvlGraphNode;
    Level: integer;
    Visited: boolean;
    InEdgeCount: integer;
  end;

function CompareGraphLevelerNodes(Node1, Node2: Pointer): integer;
var
  LNode1: TGraphLevelerNode absolute Node1;
  LNode2: TGraphLevelerNode absolute Node2;
begin
  Result:=ComparePointer(LNode1.Node,LNode2.Node);
end;

function CompareLGNodeWithLevelerNode(GNode, LNode: Pointer): integer;
var
  LevelerNode: TGraphLevelerNode absolute LNode;
begin
  Result:=ComparePointer(GNode,LevelerNode.Node);
end;

{ TLvlGraph }

function TLvlGraph.GetNodes(Index: integer): TLvlGraphNode;
begin
  Result:=TLvlGraphNode(FNodes[Index]);
end;

procedure TLvlGraph.SetLevelCount(AValue: integer);
begin
  if AValue<1 then
    raise Exception.Create('at least one level');
  if LevelCount=AValue then Exit;
  while LevelCount<AValue do
    TLvlGraphLevel.Create(Self,LevelCount);
  while LevelCount>AValue do
    Levels[LevelCount-1].Free;
end;

function TLvlGraph.GetLevels(Index: integer): TLvlGraphLevel;
begin
  Result:=TLvlGraphLevel(fLevels[Index]);
end;

function TLvlGraph.GetLevelCount: integer;
begin
  Result:=fLevels.Count;
end;

constructor TLvlGraph.Create;
begin
  FNodes:=TFPList.Create;
  fLevels:=TFPList.Create;
end;

destructor TLvlGraph.Destroy;
begin
  Clear;
  FreeAndNil(fLevels);
  FreeAndNil(FNodes);
  inherited Destroy;
end;

procedure TLvlGraph.Clear;
var
  i: Integer;
begin
  while NodeCount>0 do
    Nodes[NodeCount-1].Free;
  for i:=LevelCount-1 downto 0 do
    Levels[i].Free;
end;

procedure TLvlGraph.Invalidate;
begin
  if OnInvalidate<>nil then
    OnInvalidate(Self);
end;

function TLvlGraph.NodeCount: integer;
begin
  Result:=FNodes.Count;
end;

function TLvlGraph.GetNode(aCaption: string; CreateIfNotExists: boolean
  ): TLvlGraphNode;
var
  i: Integer;
begin
  i:=NodeCount-1;
  while (i>=0) and (aCaption<>Nodes[i].Caption) do dec(i);
  if i>=0 then begin
    Result:=Nodes[i];
  end else if CreateIfNotExists then begin
    if LevelCount=0 then
      LevelCount:=1;
    Result:=TLvlGraphNode.Create(Self,aCaption,Levels[0]);
    FNodes.Add(Result);
  end else
    Result:=nil;
end;

function TLvlGraph.GetEdge(SourceCaption, TargetCaption: string;
  CreateIfNotExists: boolean): TLvlGraphEdge;
var
  Source: TLvlGraphNode;
  Target: TLvlGraphNode;
begin
  Source:=GetNode(SourceCaption,CreateIfNotExists);
  if Source=nil then exit(nil);
  Target:=GetNode(TargetCaption,CreateIfNotExists);
  if Target=nil then exit(nil);
  Result:=GetEdge(Source,Target,CreateIfNotExists);
end;

function TLvlGraph.GetEdge(Source, Target: TLvlGraphNode;
  CreateIfNotExists: boolean): TLvlGraphEdge;
begin
  Result:=Source.FindOutEdge(Target);
  if Result<>nil then exit;
  if CreateIfNotExists then
    Result:=TLvlGraphEdge.Create(Source,Target);
end;

procedure TLvlGraph.InternalRemoveLevel(Lvl: TLvlGraphLevel);
var
  i: Integer;
begin
  if Levels[Lvl.Index]<>Lvl then
    raise Exception.Create('inconsistency');
  fLevels.Delete(Lvl.Index);
  // update level Index
  for i:=Lvl.Index to LevelCount-1 do
    Levels[i].FIndex:=i;
end;

procedure TLvlGraph.CreateTopologicalLevels;
{$DEFINE LvlGraphConsistencyCheck}
var
  InNodes: TAvgLvlTree;
  ExtNodes: TAvgLvlTree;

  function GetExtNode(Node: TLvlGraphNode): TGraphLevelerNode;
  begin
    Result:=TGraphLevelerNode(ExtNodes.FindKey(Pointer(Node),@CompareLGNodeWithLevelerNode).Data);
  end;

  function GetRemainingInEdgeCounts(Node: TLvlGraphNode): PtrInt;
  begin
    Result:=GetExtNode(Node).InEdgeCount;
  end;

  procedure DecRemainingInEdgeCount(Node: TLvlGraphNode);
  var
    i: PtrInt;
  begin
    {$IFDEF LvlGraphConsistencyCheck}
    if GetExtNode(Node).Visited then
      raise Exception.Create('DecRemainingInEdgeCount already visited: '+Node.Caption);
    {$ENDIF}
    i:=GetRemainingInEdgeCounts(Node)-1;
    {$IFDEF LvlGraphConsistencyCheck}
    if i<0 then
      raise Exception.Create('DecRemainingInEdgeCount InEdgeCount<0 '+Node.Caption);
    {$ENDIF}
    GetExtNode(Node).InEdgeCount:=i;
    if i=0 then
      InNodes.Add(Node);
  end;

  function HasVisited(Node: TLvlGraphNode): boolean;
  begin
    Result:=GetExtNode(Node).Visited;
  end;

var
  i: Integer;
  Node: TLvlGraphNode;
  ExtNode: TGraphLevelerNode;
  j: Integer;
  AVLNode: TAvgLvlTreeNode;
  Edge: TLvlGraphEdge;
  BestNode: TLvlGraphNode;
  MaxLevel: Integer;
begin
  WriteDebugReport('TLvlGraph.CreateTopologicalLevels START');
  {$IFDEF LvlGraphConsistencyCheck}
  ConsistencyCheck(false);
  {$ENDIF}
  ExtNodes:=TAvgLvlTree.Create(@CompareGraphLevelerNodes);
  InNodes:=TAvgLvlTree.Create; // nodes with remaining InEdgeCount=0, not yet visited
  try
    // find start nodes with InEdgeCount=0
    // clear BackEdge flags
    // init ExtNodes
    for i:=0 to NodeCount-1 do begin
      Node:=Nodes[i];
      ExtNode:=TGraphLevelerNode.Create;
      ExtNode.Node:=Node;
      ExtNodes.Add(ExtNode);
      ExtNode.InEdgeCount:=Node.InEdgeCount;
      if Node.InEdgeCount=0 then
        InNodes.Add(Node);
      for j:=0 to Node.InEdgeCount-1 do begin
        Edge:=Node.InEdges[j];
        Edge.fBackEdge:=false;
        if Edge.Source=Node then begin
          // edge Source=Target
          Edge.fBackEdge:=true;
          DecRemainingInEdgeCount(Node);
        end;
      end;
    end;
    MaxLevel:=0;
    for i:=1 to NodeCount do begin
      if InNodes.Count=0 then begin
        // all nodes have InEdges => all nodes in cycles
        // find a not visited node with the smallest number of active InEdges
        // ToDo: consider Edge.Size
        BestNode:=nil;
        for j:=0 to NodeCount-1 do begin
          Node:=Nodes[j];
          if HasVisited(Node) then continue;
          if (BestNode=nil)
          or (GetRemainingInEdgeCounts(BestNode)>GetRemainingInEdgeCounts(Node))
          then
            BestNode:=Node;
        end;
        // disable all InEdges to get a cycle free node
        for j:=0 to BestNode.InEdgeCount-1 do begin
          Edge:=BestNode.InEdges[j];
          if Edge.BackEdge then continue;
          if HasVisited(Edge.Source) then continue;
          Edge.fBackEdge:=true;
          DecRemainingInEdgeCount(BestNode); // this adds BestNode to InNodes
        end;
        // now InNodes contains BestNode
        {$IFDEF LvlGraphConsistencyCheck}
        if InNodes.Count=0 then
          raise Exception.Create('BestNode='+BestNode.Caption+' missing in InNodes. InEdgeCount='+dbgs(GetExtNode(BestNode).InEdgeCount)+' should be 0');
        {$ENDIF}
      end;
      // get next node with no active InEdges
      AVLNode:=InNodes.FindLowest;
      Node:=TLvlGraphNode(AVLNode.Data);
      InNodes.Delete(AVLNode);
      ExtNode:=GetExtNode(Node);
      // mark Node as visited
      ExtNode.Visited:=true;
      // set level to the maximum of all InEdges +1
      ExtNode.Level:=0;
      for j:=0 to Node.InEdgeCount-1 do begin
        Edge:=Node.InEdges[j];
        if Edge.BackEdge then continue;
        ExtNode.Level:=Max(ExtNode.Level,GetExtNode(Edge.Source).Level+1);
        MaxLevel:=Max(ExtNode.Level,MaxLevel);
        LevelCount:=Max(LevelCount,MaxLevel+1);
        ExtNode.Node.Level:=Levels[ExtNode.Level];
      end;
      // forget all out edges
      for j:=0 to Node.OutEdgeCount-1 do begin
        Edge:=Node.OutEdges[j];
        if Edge.BackEdge then continue;
        DecRemainingInEdgeCount(Edge.Target);
      end;
    end;
    // delete unneeded levels
    LevelCount:=MaxLevel+1;
  finally
    ExtNodes.FreeAndClear;
    ExtNodes.Free;
    InNodes.Free;
  end;
  WriteDebugReport('TLvlGraph.CreateTopologicalLevels END');
  {$IFDEF LvlGraphConsistencyCheck}
  ConsistencyCheck(true);
  {$ENDIF}
end;

procedure TLvlGraph.MarkBackEdges;
var
  i: Integer;
  Node: TLvlGraphNode;
  j: Integer;
  Edge: TLvlGraphEdge;
begin
  for i:=0 to NodeCount-1 do begin
    Node:=Nodes[i];
    for j:=0 to Node.OutEdgeCount-1 do begin
      Edge:=Node.OutEdges[j];
      Edge.fBackEdge:=Edge.IsBackEdge;
    end;
  end;
end;

procedure TLvlGraph.MinimizeCrossings;
var
  i: Integer;
begin
  for i:=0 to LevelCount-1 do begin

  end;
end;

procedure TLvlGraph.MinimizeOverlappings(Gap: integer; aLevel: integer);
var
  i: Integer;
  Tree: TAvgLvlTree;
  Level: TLvlGraphLevel;
  AVLNode: TAvgLvlTreeNode;
  Node: TLvlGraphNode;
  Last: TLvlGraphNode;
begin
  if aLevel<0 then begin
    for i:=0 to LevelCount-1 do
      MinimizeOverlappings(i);
  end else begin
    Level:=Levels[aLevel];
    Tree:=TAvgLvlTree.Create(@CompareLGNodesByCenterPos);
    try
      for i:=0 to Level.Count-1 do
        Tree.Add(Level[i]);
      Last:=nil;
      AVLNode:=Tree.FindLowest;
      while AVLNode<>nil do begin
        Node:=TLvlGraphNode(AVLNode.Data);
        Last:=Node;
        if (Last<>nil) then
          Node.DrawPosition:=Max(Node.DrawPosition,Last.DrawPositionEnd+Gap);
        AVLNode:=Tree.FindSuccessor(AVLNode);
      end;
    finally
      Tree.Free;
    end;
  end;
end;

procedure TLvlGraph.WriteDebugReport(Msg: string);
var
  l: Integer;
  Level: TLvlGraphLevel;
  i: Integer;
  Node: TLvlGraphNode;
  Edge: TLvlGraphEdge;
  j: Integer;
begin
  debugln([Msg,' NodeCount=',NodeCount,' LevelCount=',LevelCount]);
  debugln(['  Nodes:']);
  for i:=0 to NodeCount-1 do begin
    Node:=Nodes[i];
    dbgout(['   ',i,'/',NodeCount,': "',Node.Caption,'" OutEdges:']);
    for j:=0 to Node.OutEdgeCount-1 do begin
      Edge:=Node.OutEdges[j];
      dbgout('"',Edge.Target.Caption,'",');
    end;
    debugln;
  end;
  debugln(['  Levels:']);
  for l:=0 to LevelCount-1 do begin
    dbgout(['   Level: ',l,'/',LevelCount]);
    Level:=Levels[l];
    if l<>Level.Index then
      debugln(['ERROR: l<>Level.Index=',Level.Index]);
    dbgout('  ');
    for i:=0 to Level.Count-1 do begin
      dbgout('"',Level.Nodes[i].Caption,'",');
    end;
    debugln;
  end;
end;

procedure TLvlGraph.ConsistencyCheck(WithBackEdge: boolean);
var
  i: Integer;
  Node: TLvlGraphNode;
  j: Integer;
  Edge: TLvlGraphEdge;
  Level: TLvlGraphLevel;
begin
  for i:=0 to LevelCount-1 do begin
    Level:=Levels[i];
    if Level.Index<>i then
      raise Exception.Create('');
    for j:=0 to Level.Count-1 do begin
      Node:=Level.Nodes[j];
      if Node.Level<>Level then
        raise Exception.Create('');
      if Level.IndexOf(Node)<j then
        raise Exception.Create('');
    end;
  end;
  for i:=0 to NodeCount-1 do begin
    Node:=Nodes[i];
    for j:=0 to Node.OutEdgeCount-1 do begin
      Edge:=Node.OutEdges[j];
      if Edge.Source<>Node then
        raise Exception.Create('');
      if Edge.Target.FInEdges.IndexOf(Edge)<0 then
        raise Exception.Create('');
      if WithBackEdge and (Edge.BackEdge<>Edge.IsBackEdge) then
        raise Exception.Create('');
    end;
    for j:=0 to Node.InEdgeCount-1 do begin
      Edge:=Node.InEdges[j];
      if Edge.Target<>Node then
        raise Exception.Create('');
      if Edge.Source.FOutEdges.IndexOf(Edge)<0 then
        raise Exception.Create('');
    end;
    if Node.Level.fNodes.IndexOf(Node)<0 then
      raise Exception.Create('');
  end;
end;

{ TLvlGraphEdge }

procedure TLvlGraphEdge.SetWeight(AValue: single);
var
  Diff: single;
begin
  if FWeight=AValue then Exit;
  Diff:=AValue-FWeight;
  Source.FOutSize+=Diff;
  Target.FInSize+=Diff;
  FWeight:=AValue;
  Source.Invalidate;
end;

constructor TLvlGraphEdge.Create(TheSource: TLvlGraphNode;
  TheTarget: TLvlGraphNode);
begin
  FSource:=TheSource;
  FTarget:=TheTarget;
  Source.FOutEdges.Add(Self);
  Target.FInEdges.Add(Self);
end;

destructor TLvlGraphEdge.Destroy;
begin
  Source.FOutEdges.Remove(Self);
  Target.FInEdges.Remove(Self);
  FSource:=nil;
  FTarget:=nil;
  inherited Destroy;
end;

function TLvlGraphEdge.IsBackEdge: boolean;
begin
  Result:=Source.Level.Index>Target.Level.Index;
end;

{ TLvlGraphNode }

function TLvlGraphNode.GetInEdges(Index: integer): TLvlGraphEdge;
begin
  Result:=TLvlGraphEdge(FInEdges[Index]);
end;

function TLvlGraphNode.GetOutEdges(Index: integer): TLvlGraphEdge;
begin
  Result:=TLvlGraphEdge(FOutEdges[Index]);
end;

procedure TLvlGraphNode.SetCaption(AValue: string);
begin
  if FCaption=AValue then Exit;
  FCaption:=AValue;
  Invalidate;
end;

procedure TLvlGraphNode.SetColor(AValue: TFPColor);
begin
  if FColor=AValue then Exit;
  FColor:=AValue;
  Invalidate;
end;

procedure TLvlGraphNode.OnLevelDestroy;
begin
  if Level.Index>0 then
    Level:=Graph.Levels[0]
  else if Graph.LevelCount>1 then
    Level:=Graph.Levels[1]
  else
    fLevel:=nil;
end;

procedure TLvlGraphNode.SetLevel(AValue: TLvlGraphLevel);
begin
  if AValue=nil then
    raise Exception.Create('node needs a level');
  if AValue.Graph<>Graph then
    raise Exception.Create('wrong graph');
  if FLevel=AValue then Exit;
  if FLevel<>nil then
    UnbindLevel;
  FLevel:=AValue;
  FLevel.fNodes.Add(Self);
end;

procedure TLvlGraphNode.UnbindLevel;
begin
  if FLevel<>nil then
    FLevel.fNodes.Remove(Self);
end;

procedure TLvlGraphNode.Invalidate;
begin
  if Graph<>nil then
    Graph.Invalidate;
end;

constructor TLvlGraphNode.Create(TheGraph: TLvlGraph; TheCaption: string;
  TheLevel: TLvlGraphLevel);
begin
  FGraph:=TheGraph;
  FCaption:=TheCaption;
  FInEdges:=TFPList.Create;
  FOutEdges:=TFPList.Create;
  FDrawSize:=1;
  Level:=TheLevel;
end;

destructor TLvlGraphNode.Destroy;
begin
  Clear;
  UnbindLevel;
  inherited Destroy;
end;

procedure TLvlGraphNode.Clear;
begin
  while InEdgeCount>0 do
    InEdges[InEdgeCount-1].Free;
  while OutEdgeCount>0 do
    OutEdges[OutEdgeCount-1].Free;
end;

function TLvlGraphNode.IndexOfInEdge(Source: TLvlGraphNode): integer;
begin
  for Result:=0 to InEdgeCount-1 do
    if InEdges[Result].Source=Source then exit;
  Result:=-1;
end;

function TLvlGraphNode.FindInEdge(Source: TLvlGraphNode): TLvlGraphEdge;
var
  i: Integer;
begin
  i:=IndexOfInEdge(Source);
  if i>=0 then
    Result:=InEdges[i]
  else
    Result:=nil;
end;

function TLvlGraphNode.InEdgeCount: integer;
begin
  Result:=FInEdges.Count;
end;

function TLvlGraphNode.IndexOfOutEdge(Target: TLvlGraphNode): integer;
begin
  for Result:=0 to OutEdgeCount-1 do
    if OutEdges[Result].Target=Target then exit;
  Result:=-1;
end;

function TLvlGraphNode.FindOutEdge(Target: TLvlGraphNode): TLvlGraphEdge;
var
  i: Integer;
begin
  i:=IndexOfOutEdge(Target);
  if i>=0 then
    Result:=OutEdges[i]
  else
    Result:=nil;
end;

function TLvlGraphNode.OutEdgeCount: integer;
begin
  Result:=FOutEdges.Count;
end;

function TLvlGraphNode.DrawCenter: integer;
begin
  Result:=DrawPosition+(DrawSize div 2);
end;

function TLvlGraphNode.DrawPositionEnd: integer;
begin
  Result:=DrawPosition+DrawSize;
end;

{ TCodyTreeView }

procedure TCodyTreeView.FreeNodeData;
begin
  FreeTVNodeData(Self);
end;

{ TCustomCircleDiagramControl }

procedure TCustomCircleDiagramControl.SetCategoryGapDegree16(AValue: single);
begin
  if AValue<0 then AValue:=0;
  if AValue>0.3 then AValue:=0.3;
  if FCategoryGapDegree16=AValue then Exit;
  FCategoryGapDegree16:=AValue;
  UpdateLayout;
end;

function TCustomCircleDiagramControl.GetCategories(Index: integer
  ): TCircleDiagramCategory;
begin
  Result:=TCircleDiagramCategory(fCategories[Index]);
end;

procedure TCustomCircleDiagramControl.SetCenterCaption(AValue: TCaption);
begin
  if FCenterCaption=AValue then Exit;
  FCenterCaption:=AValue;
  UpdateLayout;
end;

procedure TCustomCircleDiagramControl.SetFirstCategoryDegree16(AValue: single);
begin
  if FFirstCategoryDegree16=AValue then Exit;
  FFirstCategoryDegree16:=AValue;
  UpdateLayout;
end;

procedure TCustomCircleDiagramControl.InternalRemoveCategory(
  Category: TCircleDiagramCategory);
begin
  fCategories.Remove(Category);
  UpdateLayout;
end;

procedure TCustomCircleDiagramControl.CreateWnd;
begin
  inherited CreateWnd;
  UpdateScrollBar;
end;

procedure TCustomCircleDiagramControl.UpdateScrollBar;
begin

end;

procedure TCustomCircleDiagramControl.DoSetBounds(ALeft, ATop, AWidth,
  AHeight: integer);
begin
  inherited DoSetBounds(ALeft, ATop, AWidth, AHeight);
  UpdateLayout;
  UpdateScrollBar;
end;

procedure TCustomCircleDiagramControl.Paint;
var
  i: Integer;
begin
  inherited Paint;
  if cdcNeedUpdateLayout in fFlags then
    UpdateLayout;

  // background
  Canvas.Brush.Style:=bsSolid;
  Canvas.Brush.Color:=Color;
  Canvas.FillRect(ClientRect);

  Canvas.Brush.Color:=clRed;

  // draw categories
  for i:=0 to CategoryCount-1 do
    DrawCategory(i);

  // center caption
  Canvas.Brush.Style:=bsSolid;
  Canvas.Brush.Color:=clNone;
  Canvas.TextOut(FCenterCaptionRect.Left,FCenterCaptionRect.Top,CenterCaption);
end;

procedure TCustomCircleDiagramControl.DrawCategory(i: integer);
var
  Cat: TCircleDiagramCategory;
begin
  Cat:=Categories[i];
  Canvas.Brush.Color:=Cat.Color;
  RingSector(Canvas,Center.X-OuterRadius,Center.Y-OuterRadius,
    Center.X+OuterRadius,Center.Y+OuterRadius,
    single(InnerRadius)/single(OuterRadius),
    Cat.StartDegree16,Cat.EndDegree16);
end;

constructor TCustomCircleDiagramControl.Create(AOwner: TComponent);
begin
  BeginUpdate;
  try
    inherited Create(AOwner);
    fCategories:=TObjectList.create(true);
    FFirstCategoryDegree16:=DefaultFirstCategoryDegree16;
    FCategoryGapDegree16:=DefaultCategoryGapDegree16;
    Color:=clWhite;
  finally
    EndUpdate;
  end;
end;

destructor TCustomCircleDiagramControl.Destroy;
begin
  BeginUpdate; // disable updates
  Clear;
  FreeAndNil(fCategories);
  inherited Destroy;
end;

procedure TCustomCircleDiagramControl.Clear;
begin
  if CategoryCount=0 then exit;
  BeginUpdate;
  try
    while CategoryCount>0 do
      fCategories.Delete(CategoryCount-1);
  finally
    EndUpdate;
  end;
end;

procedure TCustomCircleDiagramControl.BeginUpdate;
begin
  inc(fUpdateLock);
end;

procedure TCustomCircleDiagramControl.EndUpdate;
begin
  if fUpdateLock=0 then
    raise Exception.Create('TCustomCircleDiagramControl.EndUpdate');
  dec(fUpdateLock);
  if fUpdateLock=0 then begin
    if cdcNeedUpdateLayout in fFlags then
      UpdateLayout;
  end;
end;

procedure TCustomCircleDiagramControl.UpdateLayout;
var
  aSize: TSize;
  aCategory: TCircleDiagramCategory;
  i: Integer;
  j: Integer;
  TotalSize: Single;
  CurCategoryDegree: Single;
  GapDegree: Single;
  TotalItemDegree: Single;
  Item: TCircleDiagramItem;
  CurItemDegree: Single;
begin
  if (fUpdateLock>0) or (not IsVisible) or (not HandleAllocated) then begin
    Include(fFlags,cdcNeedUpdateLayout);
    exit;
  end;
  Exclude(fFlags,cdcNeedUpdateLayout);

  // center caption
  FCenter:=Point(ClientWidth div 2,ClientHeight div 2);
  aSize:=Canvas.TextExtent(CenterCaption);
  FCenterCaptionRect:=Bounds(FCenter.X-(aSize.cx div 2),FCenter.Y-(aSize.cy div 2)
    ,aSize.cx,aSize.cy);

  // radius
  fInnerRadius:=0.24*Min(ClientWidth,ClientHeight);
  fOuterRadius:=1.2*InnerRadius;

  // degrees
  TotalSize:=0.0;
  CurCategoryDegree:=FirstCategoryDegree16;
  if CategoryCount>0 then begin
    // calculate TotalSize
    for i:=0 to CategoryCount-1 do begin
      aCategory:=Categories[i];
      aCategory.FSize:=0;
      for j:=0 to aCategory.Count-1 do
        aCategory.FSize+=aCategory[j].Size;
      aCategory.FSize:=Max(aCategory.FSize,aCategory.MinSize);
      TotalSize+=aCategory.FSize;
    end;

    // calculate degrees
    GapDegree:=Min(CategoryGapDegree16,(0.8/CategoryCount)*FullCircle16);
    TotalItemDegree:=FullCircle16-(GapDegree*CategoryCount);
    for i:=0 to CategoryCount-1 do begin
      aCategory:=Categories[i];
      aCategory.FStartDegree16:=CurCategoryDegree;
      if TotalSize>0 then
        CurCategoryDegree+=TotalItemDegree*aCategory.Size/TotalSize;
      aCategory.FEndDegree16:=CurCategoryDegree;

      // item degrees
      CurItemDegree:=aCategory.StartDegree16;
      for j:=0 to aCategory.Count-1 do begin
        Item:=aCategory[j];

        Item.FStartDegree16:=CurItemDegree;
        if aCategory.Size>0 then
          CurItemDegree+=(aCategory.EndDegree16-aCategory.StartDegree16)*Item.Size/aCategory.Size;
        Item.FEndDegree16:=CurItemDegree;
      end;

      CurCategoryDegree+=GapDegree;
    end;
  end;

  Invalidate;
  WriteDebugReport('TCustomCircleDiagramControl.UpdateLayout');
end;

procedure TCustomCircleDiagramControl.EraseBackground(DC: HDC);
begin
  // do not erase background, Paint will paint the whole area
end;

function TCustomCircleDiagramControl.InsertCategory(Index: integer;
  aCaption: TCaption): TCircleDiagramCategory;
begin
  Result:=TCircleDiagramCategory.Create(Self);
  Result.Caption:=aCaption;
  fCategories.Insert(Index,Result);
end;

function TCustomCircleDiagramControl.AddCategory(aCaption: TCaption
  ): TCircleDiagramCategory;
begin
  Result:=InsertCategory(CategoryCount,aCaption);
end;

function TCustomCircleDiagramControl.IndexOfCategory(aCaption: TCaption
  ): integer;
begin
  Result:=CategoryCount-1;
  while Result>=0 do begin
    if Categories[Result].Caption=aCaption then exit;
    dec(Result);
  end;
end;

function TCustomCircleDiagramControl.FindCategory(aCaption: TCaption
  ): TCircleDiagramCategory;
var
  i: Integer;
begin
  i:=IndexOfCategory(aCaption);
  if i>=0 then
    Result:=Categories[i]
  else
    Result:=nil;
end;

function TCustomCircleDiagramControl.CategoryCount: integer;
begin
  Result:=fCategories.Count;
end;

procedure TCustomCircleDiagramControl.WriteDebugReport(Msg: string);
var
  aCat: TCircleDiagramCategory;
  i: Integer;
  j: Integer;
  Item: TCircleDiagramItem;
begin
  DebugLn([Msg,' CategoryCount=',CategoryCount]);
  for i:=0 to CategoryCount-1 do begin
    aCat:=Categories[i];
    debugln(['  Category: ',i,'/',CategoryCount,' ',aCat.Caption,
      ' MinSize=',aCat.MinSize,
      ' Size=',aCat.Size,
      ' Start=',round(aCat.StartDegree16),' End=',round(aCat.EndDegree16)]);
    for j:=0 to aCat.Count-1 do begin
      Item:=aCat.Items[j];
      debugln(['    Item: ',j,'/',aCat.Count,' ',Item.Caption,
        ' Size=',Item.Size,
        ' Start=',round(Item.StartDegree16),
        ' End=',round(Item.EndDegree16)]);
    end;
  end;
end;

{ TCircleDiagramCategory }

procedure TCircleDiagramCategory.SetCaption(AValue: TCaption);
begin
  if FCaption=AValue then Exit;
  FCaption:=AValue;
end;

procedure TCircleDiagramCategory.SetColor(AValue: TColor);
begin
  if FColor=AValue then Exit;
  FColor:=AValue;
  Invalidate;
end;

function TCircleDiagramCategory.GetItems(Index: integer): TCircleDiagramItem;
begin
  Result:=TCircleDiagramItem(fItems[Index]);
end;

procedure TCircleDiagramCategory.SetMinSize(AValue: single);
begin
  if AValue<0 then AValue:=0;
  if FMinSize=AValue then Exit;
  FMinSize:=AValue;
  UpdateLayout;
end;

procedure TCircleDiagramCategory.UpdateLayout;
begin
  if Diagram<>nil then
    Diagram.UpdateLayout;
end;

procedure TCircleDiagramCategory.Invalidate;
begin
  if Diagram<>nil then
    Diagram.Invalidate;
end;

procedure TCircleDiagramCategory.InternalRemoveItem(Item: TCircleDiagramItem);
begin
  Item.FCategory:=nil;
  fItems.Remove(Item);
  UpdateLayout;
end;

constructor TCircleDiagramCategory.Create(
  TheDiagram: TCustomCircleDiagramControl);
begin
  FDiagram:=TheDiagram;
  fItems:=TFPList.Create;
  FMinSize:=DefaultCategoryMinSize;
end;

destructor TCircleDiagramCategory.Destroy;
begin
  if Diagram<>nil then
    Diagram.InternalRemoveCategory(Self);
  Clear;
  FreeAndNil(fItems);
  inherited Destroy;
end;

procedure TCircleDiagramCategory.Clear;
begin
  if Count=0 then exit;
  if Diagram<>nil then
    Diagram.BeginUpdate;
  try
    while Count>0 do
      Items[Count-1].Free;
  finally
    if Diagram<>nil then
      Diagram.EndUpdate;
  end;
end;

function TCircleDiagramCategory.InsertItem(Index: integer; aCaption: string
  ): TCircleDiagramItem;
begin
  Result:=TCircleDiagramItem.Create(Self);
  Result.Caption:=aCaption;
  fItems.Insert(Index,Result);
end;

function TCircleDiagramCategory.AddItem(aCaption: string): TCircleDiagramItem;
begin
  Result:=InsertItem(Count,aCaption);
end;

function TCircleDiagramCategory.Count: integer;
begin
  Result:=fItems.Count;
end;

{ TCircleDiagramItem }

procedure TCircleDiagramItem.SetCaption(AValue: TCaption);
begin
  if FCaption=AValue then Exit;
  FCaption:=AValue;
  UpdateLayout;
end;

procedure TCircleDiagramItem.SetSize(AValue: single);
begin
  if AValue<0 then AValue:=0;
  if FSize=AValue then Exit;
  FSize:=AValue;
  UpdateLayout;
end;

procedure TCircleDiagramItem.UpdateLayout;
begin
  if Category<>nil then
    Category.UpdateLayout;
end;

constructor TCircleDiagramItem.Create(TheCategory: TCircleDiagramCategory);
begin
  FCategory:=TheCategory;
  FSize:=DefaultItemSize;
end;

destructor TCircleDiagramItem.Destroy;
begin
  if Category<>nil then
    Category.InternalRemoveItem(Self);
  inherited Destroy;
end;

end.

