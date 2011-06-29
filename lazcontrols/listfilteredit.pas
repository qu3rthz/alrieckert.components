unit ListFilterEdit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, LResources, Graphics, StdCtrls, ComCtrls, EditBtn,
  CodeToolsStructs;

resourcestring
  lisCEFilter = '(Filter)';

type

  TImageIndexEvent = function (Str: String; Data: TObject): Integer of object;

  { TListFilterEdit }

  TListFilterEdit = class(TCustomEditButton)
    procedure FilterEditChange(Sender: TObject);
    procedure FilterEditEnter(Sender: TObject);
    procedure FilterEditExit(Sender: TObject);
    procedure OnIdle(Sender: TObject; var Done: Boolean);
  private
    fFilter: string;
    fImageIndexDirectory: integer;  // Needed if directory structure is shown.
    fNeedUpdate: boolean;
    fIdleConnected: boolean;
    fSelectedPart: TObject;         // Select this node on next update
    fSelectionList: TStringList;    // or store/restore the old selections here.
    fShowDirHierarchy: Boolean;
    fSortData: Boolean;
    fStoreFilenameInNode: boolean;
    fFilenameMap: TStringToStringTree;
    fTVNodeStack: TFPList;
    // Data to be filtered. Objects property can contain data, too.
    fData: TStringList;
    fRootNode: TTreeNode;           // The filtered items are under this node.
    fFilteredTreeview: TTreeview;
    fFilteredListbox: TListbox;
    fOnGetImageIndex: TImageIndexEvent;
    procedure SetFilter(const AValue: string);
    procedure SetFilteredTreeview(const AValue: TTreeview);
    procedure SetFilteredListbox(const AValue: TListBox);
    function PassesFilter(Entry: string): boolean;
    procedure ApplyFilterToListBox;
    procedure  StoreTreeSelection;
    procedure RestoreTreeSelection;
    procedure FreeTVNodeData(Node: TTreeNode);
    procedure TVDeleteUnneededNodes(p: integer);
    procedure TVClearUnneededAndCreateHierachy(Filename: string);
    procedure ApplyFilterToTreeview;
    procedure SetIdleConnected(const AValue: boolean);
  protected
    function GetDefaultGlyph: TBitmap; override;
    function GetDefaultGlyphName: String; override;
    procedure DoButtonClick (Sender: TObject); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure MapShortToFullFilename(ShortFilename, FullFilename: string);
    procedure ApplyFilter(Immediately: Boolean = False);
    procedure Invalidate;
  public
    property Filter: string read fFilter write SetFilter;
    property ImageIndexDirectory: integer read fImageIndexDirectory write fImageIndexDirectory;
    property IdleConnected: boolean read fIdleConnected write SetIdleConnected;
    property SelectedPart: TObject read fSelectedPart write fSelectedPart;
    property ShowDirHierarchy: Boolean read fShowDirHierarchy write fShowDirHierarchy;
    property SortData: Boolean read fSortData write fSortData;
    property StoreFilenameInNode: boolean read fStoreFilenameInNode write fStoreFilenameInNode;
    property Data: TStringList read fData;
    property RootNode: TTreeNode read fRootNode write fRootNode;
  published
    // TListFilterEdit properties.
    property FilteredTreeview: TTreeview read fFilteredTreeview write SetFilteredTreeview;
    property FilteredListbox: TListBox read fFilteredListbox write SetFilteredListbox;
    property OnGetImageIndex: TImageIndexEvent read fOnGetImageIndex write fOnGetImageIndex;
    // TEditButton properties.
    property ButtonWidth;
    property DirectInput;
    property ButtonOnlyWhenFocused;
    // property Glyph;
    property NumGlyphs;
    property Flat;
    // Other properties
    property Align;
    property Anchors;
    property BidiMode;
    property BorderSpacing;
    property BorderStyle;
    property AutoSize;
    property AutoSelect;
    property Color;
    property DragCursor;
    property DragMode;
    property Enabled;
    property Font;
    property MaxLength;
    property ParentBidiMode;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ReadOnly;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
//    property OnChange;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEditingDone;
    property OnEndDrag;
//    property OnEnter;
//    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDrag;
    property OnUTF8KeyPress;
  end;

  { TFileNameItem }

  TFileNameItem = class
  public
    Filename: string;
    constructor Create(AFilename: string);
  end;

var
  ListFilterGlyph: TBitmap;

const
  ResBtnListFilter = 'btnfiltercancel';

procedure Register;

implementation

procedure Register;
begin
  {$I listfilteredit_icon.lrs}
  RegisterComponents('LazControls',[TListFilterEdit]);
end;

constructor TFileNameItem.Create(AFilename: string);
begin
  Filename:=AFilename;
end;


{ TListBoxFilterEdit }

constructor TListFilterEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fData:=TStringList.Create;
  fSelectionList:=TStringList.Create;
  fFilenameMap:=TStringToStringTree.Create(True);
  Button.Enabled:=False;
  Font.Color:=clBtnShadow;
  Text:=lisCEFilter;
  OnChange:=@FilterEditChange;
  OnEnter:=@FilterEditEnter;
  OnExit:=@FilterEditExit;
end;

destructor TListFilterEdit.Destroy;
begin
  FreeTVNodeData(fRootNode);
  fFilenameMap.Free;
  fSelectionList.Free;
  fData.Free;
  inherited Destroy;
end;

procedure TListFilterEdit.FilterEditChange(Sender: TObject);
begin
  Filter:=Text;
end;

procedure TListFilterEdit.FilterEditEnter(Sender: TObject);
begin
  if Text=lisCEFilter then
    Text:='';
end;

procedure TListFilterEdit.FilterEditExit(Sender: TObject);
begin
  Filter:=Text;
end;

procedure TListFilterEdit.DoButtonClick(Sender: TObject);
begin
  Filter:='';
end;

procedure TListFilterEdit.SetFilter(const AValue: string);
var
  NewValue: String;
begin
  NewValue:=LowerCase(AValue);
  if AValue=lisCEFilter then
    NewValue:='';
  Button.Enabled:=NewValue<>'';
  if (NewValue='') and not Focused then begin
    Text:=lisCEFilter;
    Font.Color:=clBtnShadow;
  end
  else begin
    Text:=NewValue;
    Font.Color:=clDefault;
  end;
  if fFilter=NewValue then exit;
  fFilter:=NewValue;
  ApplyFilter;
end;

procedure TListFilterEdit.OnIdle(Sender: TObject; var Done: Boolean);
begin
  if fNeedUpdate then
    ApplyFilter(true);
  IdleConnected:=false;
end;

procedure TListFilterEdit.SetIdleConnected(const AValue: boolean);
begin
  if fIdleConnected=AValue then exit;
  fIdleConnected:=AValue;
  if fIdleConnected then
    Application.AddOnIdleHandler(@OnIdle)
  else
    Application.RemoveOnIdleHandler(@OnIdle);
end;

function TListFilterEdit.GetDefaultGlyph: TBitmap;
begin
  Result := ListFilterGlyph;
end;

function TListFilterEdit.GetDefaultGlyphName: String;
begin
  Result := ResBtnListFilter;
end;

procedure TListFilterEdit.SetFilteredTreeview(const AValue: TTreeview);
begin
  if Assigned(fFilteredListbox) then
    raise Exception.Create('Sorry, both Treeview and ListBox should not be assigned.');
  fFilteredTreeview := AValue;
end;

procedure TListFilterEdit.SetFilteredListbox(const AValue: TListBox);
begin
  if Assigned(fFilteredTreeview) then
    raise Exception.Create('Sorry, both Treeview and ListBox should not be assigned.');
  fFilteredListbox := AValue;
end;

function TListFilterEdit.PassesFilter(Entry: string): boolean;
begin
  Result:=(Filter='') or (System.Pos(Filter,lowercase(Entry))>0);
end;

procedure TListFilterEdit.ApplyFilterToListBox;
begin                                      // use fFilteredListbox
  raise Exception.Create('Under construction.');
end;

procedure TListFilterEdit.MapShortToFullFilename(ShortFilename, FullFilename: string);
begin
  fFilenameMap[ShortFilename]:=FullFilename;
end;

procedure TListFilterEdit.StoreTreeSelection;
var
  ANode: TTreeNode;
begin
  ANode:=fFilteredTreeview.Selected;
  while ANode<>nil do begin
    fSelectionList.Insert(0,ANode.Text);
    ANode:=ANode.Parent;
  end;
end;

procedure TListFilterEdit.RestoreTreeSelection;
var
  ANode: TTreeNode;
  CurText: string;
begin
  ANode:=nil;
  while fSelectionList.Count>0 do begin
    CurText:=fSelectionList[0];
    if ANode=nil then
      ANode:=fFilteredTreeview.Items.GetFirstNode
    else
      ANode:=ANode.GetFirstChild;
    while (ANode<>nil) and (ANode.Text<>CurText) do
      ANode:=ANode.GetNextSibling;
    if ANode=nil then break;
    fSelectionList.Delete(0);
  end;
  if ANode<>nil then
    fFilteredTreeview.Selected:=ANode;
  fSelectionList.Clear;
end;

procedure TListFilterEdit.FreeTVNodeData(Node: TTreeNode);
var
  Child: TTreeNode;
begin
  if Node=nil then exit;
  if (Node.Data<>nil) then begin
    TObject(Node.Data).Free;
    Node.Data:=nil;
  end;
  Child:=Node.GetFirstChild;
  while Child<>nil do
  begin
    FreeTVNodeData(Child);
    Child:=Child.GetNextSibling;
  end;
end;

procedure TListFilterEdit.TVDeleteUnneededNodes(p: integer);
// delete all nodes behind the nodes in the stack, and depth>=p
var
  i: Integer;
  Node: TTreeNode;
begin
  for i:=fTVNodeStack.Count-1 downto p do begin
    Node:=TTreeNode(fTVNodeStack[i]);
    while Node.GetNextSibling<>nil do
      Node.GetNextSibling.Free;
  end;
  fTVNodeStack.Count:=p;
end;

procedure TListFilterEdit.TVClearUnneededAndCreateHierachy(Filename: string);
// TVNodeStack contains a path of TTreeNode for the last filename
var
  DelimPos: Integer;
  FilePart: String;
  Node: TTreeNode;
  p: Integer;
begin
  p:=0;
  while Filename<>'' do begin
    // get the next file name part
    if fShowDirHierarchy then
      DelimPos:=System.Pos(PathDelim,Filename)
    else
      DelimPos:=0;
    if DelimPos>0 then begin
      FilePart:=copy(Filename,1,DelimPos-1);
      Filename:=copy(Filename,DelimPos+1,length(Filename));
    end else begin
      FilePart:=Filename;
      Filename:='';
    end;
    //debugln(['ClearUnneededAndCreateHierachy FilePart=',FilePart,' Filename=',Filename,' p=',p]);
    if p < fTVNodeStack.Count then begin
      Node:=TTreeNode(fTVNodeStack[p]);
      if (FilePart=Node.Text) and (Node.Data=nil) then begin
        // same sub directory
      end
      else begin
        // change directory => last directory is complete
        // => delete unneeded nodes after last path
        TVDeleteUnneededNodes(p+1);
        if Node.GetNextSibling<>nil then begin
          Node:=Node.GetNextSibling;
          Node.Text:=FilePart;
        end
        else
          Node:=fFilteredTreeview.Items.Add(Node,FilePart);
        fTVNodeStack[p]:=Node;
      end;
    end else begin
      // new sub node
      if p>0 then
        Node:=TTreeNode(fTVNodeStack[p-1])
      else
        Node:=fRootNode;
      if Node.GetFirstChild<>nil then begin
        Node:=Node.GetFirstChild;
        Node.Text:=FilePart;
      end
      else
        Node:=fFilteredTreeview.Items.AddChild(Node,FilePart);
      fTVNodeStack.Add(Node);
    end;
    if (Filename<>'') then begin
      Node.ImageIndex:=fImageIndexDirectory;
      Node.SelectedIndex:=Node.ImageIndex;
    end;
    inc(p);
  end;
end;

procedure TListFilterEdit.ApplyFilterToTreeview;
var
  TVNode: TTreeNode;
  ImgIndex, i: Integer;
  s: string;
begin
  fNeedUpdate:=false;
  ImgIndex:=-1;
  fData.Sorted:=SortData;
  fFilteredTreeview.BeginUpdate;
  if fSelectedPart=Nil then
    StoreTreeSelection;
  if Assigned(fRootNode) then begin
    if fStoreFilenameInNode then
      FreeTVNodeData(fRootNode);
    fRootNode.DeleteChildren;
    fTVNodeStack:=TFPList.Create;
  end
  else
    fFilteredTreeview.Items.Clear;
  for i:=0 to fData.Count-1 do
    if PassesFilter(fData[i]) then begin
      if Assigned(fRootNode) then begin
        TVClearUnneededAndCreateHierachy(fData[i]);
        TVNode:=TTreeNode(fTVNodeStack[fTVNodeStack.Count-1]);
      end
      else begin
        TVNode:=fFilteredTreeview.Items.Add(nil,fData[i]);
      end;
      if fStoreFilenameInNode then begin
        s:=fData[i];
        if fFilenameMap.Contains(fData[i]) then
          s:=fFilenameMap[fData[i]];           // Full file name.
        TVNode.Data:=TFileNameItem.Create(s);
      end;
      if Assigned(OnGetImageIndex) then
        ImgIndex:=OnGetImageIndex(fData[i], fData.Objects[i]);
      TVNode.ImageIndex:=ImgIndex;
      TVNode.SelectedIndex:=ImgIndex;
      if Assigned(fSelectedPart) then
        TVNode.Selected:=fSelectedPart=fData.Objects[i];
    end;
  if Assigned(fRootNode) then begin
    TVDeleteUnneededNodes(0);
    fTVNodeStack.Free;
    fRootNode.Expanded:=True;
  end;
  if fSelectedPart=Nil then
    RestoreTreeSelection;
  fFilteredTreeview.EndUpdate;
  fData.Sorted:=False;
end;

procedure TListFilterEdit.ApplyFilter(Immediately: Boolean);
begin
  if Immediately then begin
    if Assigned(fFilteredTreeview) then
      ApplyFilterToTreeview
    else if Assigned(fFilteredListbox) then
      ApplyFilterToListBox
    else
      raise Exception.Create(
        'Set either FilteredTreeview or FilteredListbox before using the filter.');
  end
  else begin
    if csDestroying in ComponentState then exit;
    Invalidate;
  end;
end;

procedure TListFilterEdit.Invalidate;
begin
  fNeedUpdate:=true;
  IdleConnected:=true;
end;


end.

