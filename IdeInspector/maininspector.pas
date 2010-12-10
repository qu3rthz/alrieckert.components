unit MainInspector;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls, Buttons,
  ComCtrls, Menus, MenuIntf, ObjectInspector, types, typinfo;

type

  { TIdeInspectForm }

  TIdeInspectForm = class(TForm)
    ImageList1: TImageList;
    menuFollowForm: TMenuItem;
    menuFollowFrame: TMenuItem;
    popComponent: TPopupMenu;
    popSubComponent: TPopupMenu;
    popControls: TPopupMenu;
    popFollowType: TPopupMenu;
    Splitter1: TSplitter;
    ToolBar1: TToolBar;
    btnComponent: TToolButton;
    btnSubComponent: TToolButton;
    ToolButton1: TToolButton;
    btnRemoveSelected: TToolButton;
    ToolButton2: TToolButton;
    btnControls: TToolButton;
    ToolButton3: TToolButton;
    ToolButtonActiveType: TToolButton;
    ToolButtonFollowActive: TToolButton;
    TreeView1: TTreeView;
    procedure btnControlsClick(Sender: TObject);
    procedure btnSubComponentClick(Sender: TObject);
    procedure menuFollowFormClick(Sender: TObject);
    procedure menuFollowFrameClick(Sender: TObject);
    procedure MenuItem1Click(Sender: TObject);
    procedure btnComponentClick(Sender: TObject);
    procedure popComponentPopup(Sender: TObject);
    procedure popControlsPopup(Sender: TObject);
    procedure popSubComponentPopup(Sender: TObject);
    procedure btnRemoveSelectedClick(Sender: TObject);
    procedure ToolButtonActiveTypeClick(Sender: TObject);
    procedure ToolButtonFollowActiveClick(Sender: TObject);
    procedure TreeView1Change(Sender: TObject; Node: TTreeNode);
    procedure TreeView1Click(Sender: TObject);
  private
    { private declarations }
  protected
    FPropertiesGrid: TCustomPropertiesGrid;
    FSelected: TComponent;
    FFollowFrames: Boolean;
    procedure SetSelected(AComp: TComponent);
    procedure UpdateTree;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure DoActiveFormChanged(Sender: TObject; Form: TCustomForm);
    procedure DoActiveControChanged(Sender: TObject; LastControl: TControl);
  public
    { public declarations }
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  IdeInspectForm: TIdeInspectForm;

resourcestring
  ideinspInspectIDE = 'Inspect IDE';
  ideinspApplcicationComponents = 'Applcication.Components';
  ideinspScreenForms = 'Screen.Forms';
  ideinspQuickLinks = 'Quick links';
  ideinspComponentsOwned = 'Components (Owned)';
  ideinspRemoveSelectedItemSFromTree = 'Remove selected item(s) from tree';
  ideinspControlsChildren = 'Controls (Children)';
  ideinspInspectingNameClassUnit = 'Inspecting %s: %s (Unit: %s)';
  ideinspInspectingNameClass = 'Inspecting %s: %s';
  ideinspIdeInspector = 'Ide Inspector';

procedure Register;

implementation

{$R *.lfm}

type

  { TExtMenuItem }

  TExtMenuItem = class(TMenuItem)
  private
    FTheObject: TPersistent;
  public
    property TheObject: TPersistent read FTheObject write FTheObject;
  end;

{ TIdeInspectForm }

procedure TIdeInspectForm.MenuItem1Click(Sender: TObject);
begin
  SetSelected(TComponent(TExtMenuItem(Sender).TheObject));
end;

procedure TIdeInspectForm.btnSubComponentClick(Sender: TObject);
begin
  btnSubComponent.CheckMenuDropdown;
end;

procedure TIdeInspectForm.menuFollowFormClick(Sender: TObject);
begin
  FFollowFrames := False;
  ToolButtonActiveType.Caption := menuFollowForm.Caption;
end;

procedure TIdeInspectForm.menuFollowFrameClick(Sender: TObject);
begin
  FFollowFrames := True;
  ToolButtonActiveType.Caption := menuFollowFrame.Caption;
end;

procedure TIdeInspectForm.btnControlsClick(Sender: TObject);
begin
  btnControls.CheckMenuDropdown;
end;

procedure TIdeInspectForm.btnComponentClick(Sender: TObject);
begin
  btnComponent.CheckMenuDropdown;
end;

procedure TIdeInspectForm.popComponentPopup(Sender: TObject);
var
  m: TExtMenuItem;
  i: Integer;
begin
  popComponent.Items.Clear;

  m := TExtMenuItem.Create(Self);
  m.Caption := ideinspApplcicationComponents + ' (' + IntToStr(Application.ComponentCount) + ')' ;
  m.Enabled := False;
  popComponent.Items.Add(m);
  for i := 0 to Application.ComponentCount - 1 do begin
    m := TExtMenuItem.Create(Self);
    m.Caption := Application.Components[i].Name +
                 ' ['+Application.Components[i].ClassName+']'+
                 ' ('+IntToStr(Application.Components[i].ComponentCount)+')';
    m.TheObject := Application.Components[i];
    m.OnClick := @MenuItem1Click;
    popComponent.Items.Add(m);
  end;

  m := TExtMenuItem.Create(Self);
  m.Caption := ideinspScreenForms + ' (' + IntToStr(Screen.FormCount) + ')' ;
  m.Enabled := False;
  popComponent.Items.Add(m);
  for i := 0 to Screen.FormCount - 1 do begin
    m := TExtMenuItem.Create(Self);
    m.Caption := Screen.Forms[i].Name +
                 ' ['+Screen.Forms[i].ClassName+']'+
                 ' ('+IntToStr(Screen.Forms[i].ComponentCount)+')';
    m.TheObject := Screen.Forms[i];
    m.OnClick := @MenuItem1Click;
    popComponent.Items.Add(m);
 end;
end;

procedure TIdeInspectForm.popControlsPopup(Sender: TObject);
var
  i: Integer;
  m: TExtMenuItem;
begin
  popControls.Items.Clear;
  if (FSelected = nil) or not(FSelected is TWinControl) then
    exit;

  for i := 0 to TWinControl(FSelected).ControlCount - 1 do begin
    m := TExtMenuItem.Create(Self);
    m.Caption := TWinControl(FSelected).Controls[i].Name +
                 ' ['+TWinControl(FSelected).Controls[i].ClassName+']'+
                 ' ('+IntToStr(TWinControl(FSelected).Controls[i].ComponentCount)+')';
    m.TheObject := TWinControl(FSelected).Controls[i];
    m.OnClick := @MenuItem1Click;
    popControls.Items.Add(m);
  end;
end;

procedure TIdeInspectForm.popSubComponentPopup(Sender: TObject);
var
  i: Integer;
  m: TExtMenuItem;
begin
  popSubComponent.Items.Clear;

  for i := 0 to FSelected.ComponentCount - 1 do begin
    m := TExtMenuItem.Create(Self);
    m.Caption := FSelected.Components[i].Name +
                 ' ['+FSelected.Components[i].ClassName+']'+
                 ' ('+IntToStr(FSelected.Components[i].ComponentCount)+')';
    m.TheObject := FSelected.Components[i];
    m.OnClick := @MenuItem1Click;
    popSubComponent.Items.Add(m);
  end;
end;

procedure TIdeInspectForm.btnRemoveSelectedClick(Sender: TObject);
begin
  if TreeView1.Selected = nil then
    exit;
  if TreeView1.Selected.Parent <> nil then
    SetSelected(TComponent(TreeView1.Selected.Parent.Data))
  else
    SetSelected(nil);
  TreeView1.Selected.Delete;
  UpdateTree;
end;

procedure TIdeInspectForm.ToolButtonActiveTypeClick(Sender: TObject);
begin
  ToolButtonActiveType.CheckMenuDropdown;
end;

procedure TIdeInspectForm.ToolButtonFollowActiveClick(Sender: TObject);
begin
  if ToolButtonFollowActive.Down then
    SetSelected(Self);
end;

procedure TIdeInspectForm.TreeView1Change(Sender: TObject; Node: TTreeNode);
begin
  TreeView1Click(nil);
end;

procedure TIdeInspectForm.TreeView1Click(Sender: TObject);
begin
  if (TreeView1.Selected = nil) or (TreeView1.Selected.Data = nil) then
    exit;
  SetSelected(TComponent(TreeView1.Selected.Data));
end;

procedure TIdeInspectForm.SetSelected(AComp: TComponent);
var
  TypeInfo: PTypeData;
begin
  FSelected := AComp;
  FPropertiesGrid.TIObject := FSelected;
  btnSubComponent.Enabled := (FSelected <> nil) and (FSelected.ComponentCount > 0);
  btnControls.Enabled := (FSelected <> nil) and
                         (FSelected is TWinControl) and (TWinControl(FSelected).ControlCount > 0);
  UpdateTree;

  if FSelected <> nil then begin
    TypeInfo := GetTypeData(PTypeInfo(FSelected.ClassType.ClassInfo));
    if (TypeInfo <> nil) then begin
      Caption := Format(ideinspInspectingNameClassUnit, [FSelected.Name, FSelected.ClassName,
        TypeInfo ^ .UnitName]);
    end
    else
      Caption := Format(ideinspInspectingNameClass, [FSelected.Name, FSelected.ClassName]);
  end
  else
    Caption := ideinspIdeInspector
end;

procedure TIdeInspectForm.UpdateTree;
  function FindNode(AComp: TComponent): TTreeNode;
  var
    AParent: TTreeNode;
  begin
    Result := TreeView1.Items.FindNodeWithData(AComp);
    if Result = nil then begin
      if AComp.Owner <> nil then begin
        AParent := FindNode(AComp.Owner);
        Result := AParent.TreeNodes.AddChildObject
          (AParent,
           AComp.Name + ': ' + AComp.ClassName
           + ' ('+IntToStr(AComp.ComponentCount)+')'
             + ' ' + IntToHex(PtrUInt(AComp), 8),
           AComp);
      end else begin
        Result := TreeView1.Items.AddObject
          (nil,
           AComp.Name + ': ' + AComp.ClassName
           + ' ('+IntToStr(AComp.ComponentCount)+')'
           + ' ' + IntToHex(PtrUInt(AComp), 8),
           AComp);
      end;
      AComp.FreeNotification(Self);
    end;
  end;
var
  ANode: TTreeNode;
begin
  if FSelected = nil then exit;

  ANode := FindNode(FSelected);
  ANode.Expanded := True;
  ANode.Selected := True;
end;

procedure TIdeInspectForm.Notification(AComponent: TComponent; Operation: TOperation);
var
  ANode: TTreeNode;
begin
  if (Operation = opRemove) and (TreeView1 <> nil) then begin
    ANode := TreeView1.Items.FindNodeWithData(AComponent);
    if ANode <> nil then begin
      ANode.DeleteChildren;
      if (AComponent = FSelected) or (TreeView1.Items.FindNodeWithData(FSelected) = nil) then begin
        if ANode.Parent <> nil then
          SetSelected(TComponent(ANode.Parent.Data))
        else
          SetSelected(nil);
      end;
      ANode.Delete;
      UpdateTree;
    end
    else
    if AComponent = FSelected then
      SetSelected(nil);
  end;
  inherited Notification(AComponent, Operation);
end;

procedure TIdeInspectForm.DoActiveFormChanged(Sender: TObject; Form: TCustomForm);
begin
  If not ToolButtonFollowActive.Down then
    exit;

  if Form <> Self then
    SetSelected(Form);
end;

procedure TIdeInspectForm.DoActiveControChanged(Sender: TObject; LastControl: TControl);
begin
  If (not ToolButtonFollowActive.Down) or (not FFollowFrames) then
    exit;
  if Screen.ActiveForm = Self then
    exit;

  if (Screen.ActiveControl <> nil) and (Screen.ActiveControl.Owner <> nil) then
    SetSelected(Screen.ActiveControl.Owner);
end;

constructor TIdeInspectForm.Create(TheOwner: TComponent);
begin
  Screen.AddHandlerActiveFormChanged(@DoActiveFormChanged);
  Screen.AddHandlerActiveControlChanged(@DoActiveControChanged);
  inherited Create(TheOwner);
  FPropertiesGrid := TCustomPropertiesGrid.Create(Self);
  with FPropertiesGrid do
  begin
    Name := 'FPropertiesGrid';
    Parent := self;
    Align := alClient;
    BorderSpacing.Around := 6;
  end;
  btnComponent.Caption := ideinspQuickLinks;
  btnSubComponent.Caption := ideinspComponentsOwned;
  btnControls.Caption := ideinspControlsChildren;
  btnRemoveSelected.Hint := ideinspRemoveSelectedItemSFromTree;

  FFollowFrames := False;
  ToolButtonActiveType.Caption := menuFollowForm.Caption;

  SetSelected(Application);
end;

destructor TIdeInspectForm.Destroy;
begin
  Screen.RemoveHandlerActiveControlChanged(@DoActiveControChanged);
  Screen.RemoveHandlerActiveFormChanged(@DoActiveFormChanged);
  FreeAndNil(TreeView1);
  inherited Destroy;
end;

procedure IDEMenuClicked(Sender: TObject);
begin
  if not Assigned(IdeInspectForm) then begin
    IdeInspectForm := TIdeInspectForm.Create(Application);
  end;
  IdeInspectForm.Show;
end;

procedure Register;
begin
  RegisterIDEMenuCommand(itmViewIDEInternalsWindows, 'mnuIdeInspector', ideinspInspectIDE, nil,
    @IDEMenuClicked);
end;

end.

