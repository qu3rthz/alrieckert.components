{
 *****************************************************************************
 *                                                                           *
 *  See the file COPYING.modifiedLGPL, included in this distribution,        *
 *  for details about the copyright.                                         *
 *                                                                           *
 *  This program is distributed in the hope that it will be useful,          *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
 *                                                                           *
 *****************************************************************************

  Author: Mattias Gaertner

  Abstract:
   Provides LCL controls that access properties of TPersistent objects via RTTI
   - the FreePascal Run Time Type Information.
   Every published property can be edited in the Object Inspector. There you
   have a TOIPropertyGrid working with TEdit, TComboBox and TButton.
   These controls extends the possibilities to edit single properties and the
   developer can choose how to represent the property.

  ToDo:
    - ploReadOnly
}
unit RTTICtrls;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TypInfo, LResources, LCLProc, LCLType, LCLIntf, Forms,
  Controls, Graphics, MaskEdit, Calendar, Spin, Dialogs, CheckLst, ComCtrls,
  StdCtrls, Buttons, ExtCtrls, ObjectInspector, GraphPropEdits, PropEdits;

type
  { TAliasStrings }
  { Maps strings to alias strings.
    Some RTTI controls uses this to map RTTI values to shown values.
    Eventually accelerate search for Names and Values }

  TAliasStrings = class(TStringList)
  public
    function IndexOfValue(const AValue: string): integer; virtual;
    function ValueAt(Index: integer): string; virtual;
    function ValueToAlias(const AValue: string): string; virtual;
    function AliasToValue(const Alias: string): string; virtual;
  end;
  
  
  { TPropertyLinkNotifier }
  
  TCustomPropertyLink = class;
  
  TPropertyLinkNotifier = class(TComponent)
  private
    FLink: TCustomPropertyLink;
  protected
    procedure Notification(AComponent: TComponent;
                           Operation: TOperation); override;
  public
    constructor Create(TheLink: TCustomPropertyLink); reintroduce;
    property Link: TCustomPropertyLink read FLink;
  end;


  { TCustomPropertyLink
    The connection between an RTTI control and a property editor }
    
  TPropertyLinkOption = (
    ploReadOnIdle
    //ToDo: ploReadOnly
    );
  TPropertyLinkOptions = set of TPropertyLinkOption;
  
  TTestEditing = function(Sender: TObject): boolean of object;

  TCustomPropertyLink = class(TPersistent)
  private
    FAliasValues: TAliasStrings;
    FCollectedValues: TStrings;
    FCollectValues: boolean;
    FEditor: TPropertyEditor;
    FFilter: TTypeKinds;
    FHook: TPropertyEditorHook;
    FIdleHandlerConnected: boolean;
    FLinkNotifier: TPropertyLinkNotifier;
    FOnEditorChanged: TNotifyEvent;
    FOnLoadFromProperty: TNotifyEvent;
    FOnSaveToProperty: TNotifyEvent;
    FOnTestEditing: TTestEditing;
    FOnTestEditor: TPropertyEditorFilterFunc;
    FOptions: TPropertyLinkOptions;
    FOwner: TComponent;
    FSaveEnabled: boolean;
    FTIObject: TPersistent;
    FTIPropertyName: string;
    procedure SetCollectValues(const AValue: boolean);
    procedure SetEditor(const AValue: TPropertyEditor);
    procedure SetFilter(const AValue: TTypeKinds);
    procedure SetOptions(const NewOptions: TPropertyLinkOptions);
    procedure SetTIObject(const AValue: TPersistent);
    procedure SetTIPropertyName(const AValue: string);
  protected
    function GetCanModify: boolean; virtual;
    procedure EditorChanged; virtual;
    procedure SetPropertyEditor(APropertyEditor: TPropertyEditor); virtual;
    function CheckPropInfo(const APropInfo: PPropInfo): boolean; virtual;
    procedure CreateHook; virtual;
    procedure UpdateIdleHandler; virtual;
    procedure OnApplicationIdle(Sender: TObject); virtual;
    procedure Notification(AComponent: TComponent;
                           Operation: TOperation); virtual;
    procedure GetEditorValues(const NewValue: string); virtual;
  public
    constructor Create(TheOwner: TComponent);
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure SetObjectAndProperty(NewPersistent: TPersistent;
                                   const NewPropertyName: string);
    procedure InvalidateEditor; virtual;
    procedure CreateEditor; virtual;
    procedure FetchValues; virtual;
    procedure LoadFromProperty; virtual;
    procedure SaveToProperty; virtual;
    procedure SetAsText(const NewText: string);
    function GetAsText: string;
    procedure SetAsInt(const NewInt: integer);
    function GetAsInt: integer;
    procedure DoError(Writing: boolean; E: Exception); virtual;
  public
    // alias values
    procedure MapValues(Values, AliasStrings: TStrings;
                        var MappedValues: TStrings;
                        UseAllExistingAlias, AddValuesWithoutAlias,
                        IfNoValuesAvailableAddAllAlias: boolean);
    procedure MapCollectedValues(AliasStrings: TStrings;
                                 var MappedValues: TStrings;
                                 UseAllExistingAlias, AddValuesWithoutAlias,
                                 IfNoValuesAvailableAddAllAlias: boolean);
    procedure AssignCollectedAliasValuesTo(DestList: TStrings);
    function HasAliasValues: boolean;
  public
    // for Set property editors
    procedure AssignSetEnumsAliasTo(DestList: TStrings);
    function GetSetElementValue(const AliasName: string): boolean;
    procedure SetSetElementValue(const AliasName: string; NewValue: boolean);
    function GetIndexOfSetElement(const AliasName: string): integer;
    function GetSetTypeData(var CompData: PTypeInfo;
                            var TypeData: PTypeData): boolean;
  public
    property AliasValues: TAliasStrings read FAliasValues;
    property CanModify: boolean read GetCanModify;
    property CollectedValues: TStrings read FCollectedValues write FCollectedValues;
    property CollectValues: boolean read FCollectValues write SetCollectValues;
    property Editor: TPropertyEditor read FEditor write SetEditor;
    property Filter: TTypeKinds read FFilter write SetFilter default AllTypeKinds;
    property Hook: TPropertyEditorHook read FHook;
    property LinkNotifier: TPropertyLinkNotifier read FLinkNotifier;
    property OnEditorChanged: TNotifyEvent read FOnEditorChanged write FOnEditorChanged;
    property OnLoadFromProperty: TNotifyEvent read FOnLoadFromProperty write FOnLoadFromProperty;
    property OnSaveToProperty: TNotifyEvent read FOnSaveToProperty write FOnSaveToProperty;
    property OnTestEditing: TTestEditing read FOnTestEditing write FOnTestEditing;
    property OnTestEditor: TPropertyEditorFilterFunc read FOnTestEditor write FOnTestEditor;
    property Options: TPropertyLinkOptions read FOptions write SetOptions;
    property Owner: TComponent read FOwner;
    property SaveEnabled: boolean read FSaveEnabled write FSaveEnabled;
    property TIObject: TPersistent read FTIObject write SetTIObject;
    property TIPropertyName: string read FTIPropertyName write SetTIPropertyName;
  end;
  

  { TPropertyLink }
  
  TPropertyLink = class(TCustomPropertyLink)
  published
    property AliasValues;
    property Options;
    property TIObject;
    property TIPropertyName;
  end;
  
  
  { TPropertyLinkPropertyEditor }
  
  TPropertyLinkPropertyEditor = class(TClassPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
  end;
  
  
  { TPropertyNamePropertyEditor
    Property editor for TCustomPropertyLink.TIPropertyName, showing
    all compatible properties. }
  
  TPropertyNamePropertyEditor = class(TStringPropertyEditor)
  protected
    FPropEdits: TList; // list of TPropertyEditor
    procedure GetCompatiblePropEdits(Prop: TPropertyEditor);
    function TestEditor(const Prop: TPropertyEditor): boolean;
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetEditLimit: Integer; override;
    procedure GetValues(Proc: TGetStringProc); override;
  end;
  

  { TTIObjectPropertyEditor }

  TTIObjectPropertyEditor = class(TPersistentPropertyEditor)
  end;


  { TAliasStringsPropEditorDlg }
  
  TAliasStringsPropEditorDlg = class(TStringsPropEditorDlg)
    GetDefaultValuesButton: TButton;
    procedure GetDefaultValuesButtonClick(Sender: TObject);
  protected
    FCollectedValues: TAliasStrings;
    procedure AddValue(const s: string); virtual;
  public
    procedure AddButtons(var x, y, BtnWidth: integer); override;
  end;

  
  { TPropLinkAliasPropertyEditor
    Property Editor for TCustomPropertyLink.AliasValues, providing a dialog
    to edit }
    
  TPropLinkAliasPropertyEditor = class(TStringsPropertyEditor)
  public
    function CreateDlg(s: TStrings): TStringsPropEditorDlg; override;
  end;
  

  { TTICustomEdit }

  TTICustomEdit = class(TCustomEdit)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    procedure LinkSaveToProperty(Sender: TObject); virtual;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    procedure EditingDone; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;
  
  
  { TTIEdit }
  
  TTIEdit = class(TTICustomEdit)
  published
    property Action;
    property Align;
    property Anchors;
    property AutoSize;
    property Constraints;
    property CharCase;
    property DragMode;
    property EchoMode;
    property Enabled;
    property Link;
    property MaxLength;
    property OnChange;
    property OnChangeBounds;
    property OnClick;
    property OnEnter;
    property OnExit;
    Property OnKeyDown;
    property OnKeyPress;
    Property OnKeyUp;
    Property OnMouseDown;
    Property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property ParentFont;
    property ParentShowHint;
    property PasswordChar;
    property PopupMenu;
    property ReadOnly;
    property ShowHint;
    property TabStop;
    property TabOrder;
    property Visible;
  end;
  
  
  { TTICustomMaskEdit }

  TTICustomMaskEdit = class(TCustomMaskEdit)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    procedure LinkSaveToProperty(Sender: TObject); virtual;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    procedure EditingDone; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;


  { TTIMaskEdit }

  TTIMaskEdit = class(TTICustomMaskEdit)
  published
    property Align;
    property Anchors;
    property AutoSize;
    property CharCase;
    property Color;
    property Constraints;
    property Ctl3D;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property EditMask;
    property Font;
    property MaxLength;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PasswordChar;
    property PopupMenu;
    property ReadOnly;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnChange;
    property OnClick;
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
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDrag;
  end;


  { TICustomComboBox }

  TTICustomComboBox = class(TCustomComboBox)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    procedure LinkSaveToProperty(Sender: TObject); virtual;
    procedure LinkEditorChanged(Sender: TObject); virtual;
    function LinkTestEditing(Sender: TObject): boolean;
    procedure DropDown; override;
    procedure DrawItem(Index: Integer; ARect: TRect; State: TOwnerDrawState); override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    procedure EditingDone; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;
  
  
  { TTIComboBox }
  
  TTIComboBox = class(TTICustomComboBox)
  public
    property ItemIndex;
  published
    property Align;
    property Anchors;
    property ArrowKeysTraverseList;
    property AutoDropDown;
    property Ctl3D;
    property DropDownCount;
    property Enabled;
    property Font;
    property Link;
    property MaxLength;
    property OnChange;
    property OnChangeBounds;
    property OnClick;
    property OnCloseUp;
    property OnDrawItem;
    property OnDropDown;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnSelect;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property ShowHint;
    property Sorted;
    property Style;
    property TabOrder;
    property TabStop;
    property Visible;
  end;
  
  
  { TTICustomRadioGroup }

  TTICustomRadioGroup = class(TCustomRadioGroup)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    procedure LinkSaveToProperty(Sender: TObject); virtual;
    procedure LinkEditorChanged(Sender: TObject); virtual;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    procedure EditingDone; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;


  { TTIRadioGroup }

  TTIRadioGroup = class(TTICustomRadioGroup)
  published
    property Align;
    property Anchors;
    property Caption;
    property Color;
    property ColumnLayout;
    property Columns;
    property Constraints;
    property Ctl3D;
    property Enabled;
    property ItemIndex;
    property Link;
    property OnChangeBounds;
    property OnClick;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property ParentColor;
    property ParentCtl3D;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Visible;
  end;
  
  
  { TTICustomCheckGroup }

  TTICustomCheckGroup = class(TCustomCheckGroup)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    procedure LinkSaveToProperty(Sender: TObject); virtual;
    procedure LinkEditorChanged(Sender: TObject); virtual;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    procedure EditingDone; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;


  { TTICheckGroup }

  TTICheckGroup = class(TTICustomCheckGroup)
  published
    property Align;
    property Anchors;
    property Caption;
    property Color;
    property ColumnLayout;
    property Columns;
    property Constraints;
    property Ctl3D;
    property Enabled;
    property Items;
    property Link;
    property OnChangeBounds;
    property OnClick;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnItemClick;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property ParentColor;
    property ParentCtl3D;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Visible;
  end;


  { TTICustomCheckListBox }

  TTICustomCheckListBox = class(TCustomCheckListBox)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    procedure LinkSaveToProperty(Sender: TObject); virtual;
    procedure LinkEditorChanged(Sender: TObject); virtual;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    procedure EditingDone; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;


  { TTICheckListBox }

  TTICheckListBox = class(TTICustomCheckListBox)
  published
    property Align;
    property Anchors;
    property BorderStyle;
    property Constraints;
    property ExtendedSelect;
    property Items;
    property ItemHeight;
    property Link;
    property MultiSelect;
    property OnClick;
    property OnDblClick;
    property OnDrawItem;
    property OnEnter;
    property OnExit;
    property OnKeyPress;
    property OnKeyDown;
    property OnKeyUp;
    property OnMouseMove;
    property OnMouseDown;
    property OnMouseUp;
    property OnResize;
    property ParentShowHint;
    property ShowHint;
    property Sorted;
    property Style;
    property TabOrder;
    property TabStop;
    property TopIndex;
    property Visible;
  end;
  
  
  { TTICustomListBox }

  TTICustomListBox = class(TCustomListBox)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    procedure LinkSaveToProperty(Sender: TObject); virtual;
    procedure LinkEditorChanged(Sender: TObject); virtual;
    procedure DrawItem(Index: Integer; ARect: TRect; State: TOwnerDrawState); override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    procedure EditingDone; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;


  { TTIListBox }

  TTIListBox = class(TTICustomListBox)
  published
    property Align;
    property Anchors;
    property BorderStyle;
    property ClickOnSelChange;
    property Constraints;
    property ExtendedSelect;
    property Font;
    property IntegralHeight;
    property ItemHeight;
    property MultiSelect;
    property Link;
    property OnChangeBounds;
    property OnClick;
    property OnDblClick;
    property OnDrawItem;
    property OnEnter;
    property OnExit;
    property OnKeyPress;
    property OnKeyDown;
    property OnKeyUp;
    property OnMouseMove;
    property OnMouseDown;
    property OnMouseUp;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnSelectionChange;
    property ParentShowHint;
    property ParentFont;
    property PopupMenu;
    property ShowHint;
    property Sorted;
    property Style;
    property TabOrder;
    property TabStop;
    property TopIndex;
    property Visible;
  end;


  { TTICustomCheckBox }

  TTICustomCheckBox = class(TCustomCheckBox)
  private
    FLink: TPropertyLink;
    FLinkValueFalse: string;
    FLinkValueTrue: string;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    procedure LinkSaveToProperty(Sender: TObject); virtual;
    procedure LinkEditorChanged(Sender: TObject); virtual;
    procedure DoAutoSize; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    procedure EditingDone; override;
    property LinkValueTrue: string read FLinkValueTrue;
    property LinkValueFalse: string read FLinkValueFalse;
    property Link: TPropertyLink read FLink write SetLink;
  end;


  { TTICheckBox }

  TTICheckBox = class(TTICustomCheckBox)
  published
    property Action;
    property Align;
    property AllowGrayed;
    property Anchors;
    property AutoSize;
    property Caption;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Hint;
    property Link;
    property OnChange;
    property OnChangeBounds;
    property OnClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property OnStartDrag;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property State;
    property TabOrder;
    property TabStop;
    property UseOnChange;
    property Visible;
  end;


  { TTICustomButton }

  TTICustomButton = class(TCustomButton)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    function LinkTestEditor(const ATestEditor: TPropertyEditor): Boolean; virtual;
    procedure Click; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;


  { TTIButton }

  TTIButton = class(TTICustomButton)
  published
    property Action;
    property Align;
    property Anchors;
    property Cancel;
    property Caption;
    property Constraints;
    property Default;
    property Enabled;
    property Font;
    property Link;
    property ModalResult;
    property OnClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
  end;


  { TTICustomLabel }
  
  TTICustomLabel = class(TCustomLabel)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;
  
  
  { TTILabel }
  
  TTILabel = class(TTICustomLabel)
  published
    property Align;
    property Alignment;
    property Anchors;
    property AutoSize;
    property Color;
    property Constraints;
    property FocusControl;
    property Font;
    property Layout;
    property Link;
    property OnChangeBounds;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property ParentFont;
    property ShowAccelChar;
    property Visible;
    property WordWrap;
  end;


  { TTICustomGroupbox }

  TTICustomGroupbox = class(TCustomGroupBox)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;


  { TTIGroupBox }

  TTIGroupBox = class(TTICustomGroupbox)
  published
    property Align;
    property Anchors;
    property ClientHeight;
    property ClientWidth;
    property Color;
    property Constraints;
    property Ctl3D;
    property Enabled;
    property Font;
    property Link;
    property OnChangeBounds;
    property OnClick;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
  end;


  { TTICustomMemo }
  
  TTICustomMemo = class(TCustomMemo)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    procedure LinkSaveToProperty(Sender: TObject); virtual;
    function LinkTestEditor(const ATestEditor: TPropertyEditor): Boolean; virtual;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    procedure EditingDone; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;
  
  
  { TTIMemo }
  
  TTIMemo = class(TTICustomMemo)
  published
    property Align;
    property Anchors;
    property Color;
    property Constraints;
    property Font;
    property Lines;
    property Link;
    property MaxLength;
    property OnChange;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseUp;
    property OnMouseMove;
    property OnMouseEnter;
    property OnMouseLeave;
    property ParentFont;
    property PopupMenu;
    property ReadOnly;
    property ScrollBars;
    property Tabstop;
    property Visible;
    property WordWrap;
  end;
  
  
  { TTICustomCalendar }
  
  TTICustomCalendar = class(TCustomCalendar)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    procedure LinkSaveToProperty(Sender: TObject); virtual;
    function LinkTestEditor(const ATestEditor: TPropertyEditor): Boolean;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    procedure EditingDone; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;
  
  
  { TTICalendar }
  
  TTICalendar = class(TTICustomCalendar)
  published
    property Align;
    property Anchors;
    property Constraints;
    property DisplaySettings;
    property Link;
    property OnChange;
    property OnChangeBounds;
    property OnClick;
    property OnDayChanged;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMonthChanged;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property OnYearChanged;
    property PopupMenu;
    property ReadOnly;
    property Tabstop;
    property Visible;
  end;
  
  
  { TTICustomImage }

  TTICustomImage = class(TCustomImage)
  private
    FLink: TPropertyLink;
    procedure SetLink(const AValue: TPropertyLink);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    function LinkTestEditor(const ATestEditor: TPropertyEditor): Boolean;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    property Link: TPropertyLink read FLink write SetLink;
  end;


  { TTIImage }

  TTIImage = class(TTICustomImage)
  published
    property Align;
    property Anchors;
    property AutoSize;
    property Center;
    property Constraints;
    property Link;
    property OnChangeBounds;
    property OnClick;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnPaint;
    property OnResize;
    property Proportional;
    property Stretch;
    property Transparent;
    property Visible;
  end;


  { TTICustomSpinEdit }
  
  TTICustomSpinEdit = class(TCustomSpinEdit)
  private
    FLink: TPropertyLink;
    FUseRTTIMinMax: boolean;
    procedure SetLink(const AValue: TPropertyLink);
    procedure SetUseRTTIMinMax(const AValue: boolean);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    procedure LinkSaveToProperty(Sender: TObject); virtual;
    procedure LinkEditorChanged(Sender: TObject); virtual;
    procedure GetRTTIMinMax; virtual;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    procedure EditingDone; override;
    property Link: TPropertyLink read FLink write SetLink;
    property UseRTTIMinMax: boolean read FUseRTTIMinMax write SetUseRTTIMinMax default true;
  end;
  
  
  { TTISpinEdit }
  
  TTISpinEdit = class(TTICustomSpinEdit)
  published
    property Align;
    property Anchors;
    property Climb_Rate;
    property Constraints;
    property Decimal_Places;
    property Enabled;
    property Link;
    property MaxValue;
    property MinValue;
    property OnChange;
    property OnChangeBounds;
    property OnClick;
    property OnEnter;
    property OnExit;
    Property OnKeyDown;
    property OnKeyPress;
    Property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabStop;
    property TabOrder;
    property UseRTTIMinMax;
    property Visible;
  end;
  
  
  { TTICustomTrackBar }

  TTICustomTrackBar = class(TCustomTrackBar)
  private
    FLink: TPropertyLink;
    FUseRTTIMinMax: boolean;
    procedure SetLink(const AValue: TPropertyLink);
    procedure SetUseRTTIMinMax(const AValue: boolean);
  protected
    procedure LinkLoadFromProperty(Sender: TObject); virtual;
    procedure LinkSaveToProperty(Sender: TObject); virtual;
    procedure LinkEditorChanged(Sender: TObject); virtual;
    procedure GetRTTIMinMax; virtual;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    procedure EditingDone; override;
    property Link: TPropertyLink read FLink write SetLink;
    property UseRTTIMinMax: boolean read FUseRTTIMinMax write SetUseRTTIMinMax default true;
  end;

  
  { TTITrackBar }
  
  TTITrackBar = class(TTICustomTrackBar)
  published
    property Align;
    property Anchors;
    property Constraints;
    property Ctl3D;
    property DragCursor;
    property DragMode;
    property Enabled;
    property Frequency;
    property Hint;
    property LineSize;
    property Link;
    property Max;
    property Min;
    property OnChange;
    property OnChangeBounds;
    property OnClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnResize;
    property OnStartDrag;
    property Orientation;
    property PageSize;
    property ParentCtl3D;
    property ParentShowHint;
    property PopupMenu;
    property ScalePos;
    property ShowHint;
    property ShowScale;
    property TabOrder;
    property TabStop;
    property TickMarks;
    property TickStyle;
    property UseRTTIMinMax;
    property Visible;
  end;
  

  { TTICustomPropertyGrid }

  TTICustomPropertyGrid = class(TOICustomPropertyGrid)
  private
    FAutoFreeHook: boolean;
    function GetTIObject: TPersistent;
    procedure SetAutoFreeHook(const AValue: boolean);
    procedure SetTIObject(const AValue: TPersistent);
  public
    constructor Create(TheOwner: TComponent); override;
    property TIObject: TPersistent read GetTIObject write SetTIObject;
    property AutoFreeHook: boolean read FAutoFreeHook write SetAutoFreeHook;
  end;


  { TTIPropertyGrid }

  TTIPropertyGrid = class(TTICustomPropertyGrid)
  published
    property Align;
    property Anchors;
    property BackgroundColor;
    property BorderStyle;
    property Constraints;
    property DefaultItemHeight;
    property DefaultValueFont;
    property Indent;
    property NameFont;
    property OnChangeBounds;
    property OnClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnModified;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property PopupMenu;
    property PrefferedSplitterX;
    property SplitterX;
    property Tabstop;
    property TIObject;
    property ValueFont;
    property Visible;
  end;


procedure Register;


implementation


procedure Register;
begin
  RegisterComponents('RTTI',[TTIEdit,TTIComboBox,TTIButton,TTICheckBox,
    TTILabel,TTIGroupBox,TTIRadioGroup,TTICheckGroup,TTICheckListBox,
    TTIListBox,TTIMemo,TTICalendar,TTIImage,TTISpinEdit,TTITrackBar,
    TTIMaskEdit,TTIPropertyGrid]);
end;

{ TAliasStrings }

function TAliasStrings.IndexOfValue(const AValue: string): integer;
var
  S : String;
  Start: Integer;
begin
  Result:=Count-1;
  while (Result>=0) do begin
    S:=Strings[Result];
    Start:=pos('=',S)+1;
    if (Start>0) and (CompareText(AValue,Copy(S,Start,length(S)))=0) then
      exit;
    dec(Result);
  end;
end;

function TAliasStrings.ValueAt(Index: integer): string;
var
  S: string;
  Start: Integer;
begin
  S:=Strings[Index];
  Start:=pos('=',S)+1;
  if (Start>0) then
    Result:=Copy(S,Start,length(S))
  else
    Result:='';
end;

function TAliasStrings.ValueToAlias(const AValue: string): string;
begin
  Result:=Values[AValue];
  if Result='' then Result:=AValue;
end;

function TAliasStrings.AliasToValue(const Alias: string): string;
var
  i: LongInt;
begin
  i:=IndexOfValue(Alias);
  if i>=0 then
    Result:=Names[i]
  else
    Result:=Alias;
end;

{ TCustomPropertyLink }

procedure TCustomPropertyLink.SetEditor(const AValue: TPropertyEditor);
begin
  if FEditor=AValue then exit;
  FEditor:=AValue;
  EditorChanged;
end;

procedure TCustomPropertyLink.SetCollectValues(const AValue: boolean);
begin
  if FCollectValues=AValue then exit;
  FCollectValues:=AValue;
  if FCollectValues then FetchValues;
end;

procedure TCustomPropertyLink.SetFilter(const AValue: TTypeKinds);
begin
  if FFilter=AValue then exit;
  FFilter:=AValue;
  InvalidateEditor;
end;

procedure TCustomPropertyLink.SetOptions(
  const NewOptions: TPropertyLinkOptions);
var
  ChangedOptions: TPropertyLinkOptions;
begin
  if FOptions=NewOptions then exit;
  ChangedOptions:=(FOptions-NewOptions)+(NewOptions-FOptions);
  //writeln('TCustomPropertyLink.SetOptions Old=',ploReadOnIdle in FOptions,
  //  ' New=',ploReadOnIdle in NewOptions,' Changed=',ploReadOnIdle in ChangedOptions);
  FOptions:=NewOptions;
  if (ploReadOnIdle in ChangedOptions) then UpdateIdleHandler;
end;

function TCustomPropertyLink.GetCanModify: boolean;
begin
  Result:=(FEditor<>nil) and (not FEditor.IsReadOnly);
end;

procedure TCustomPropertyLink.SetTIObject(const AValue: TPersistent);
begin
  if FTIObject=AValue then exit;
  SetObjectAndProperty(AValue,TIPropertyName);
end;

procedure TCustomPropertyLink.SetTIPropertyName(const AValue: string);
begin
  if FTIPropertyName=AValue then exit;
  SetObjectAndProperty(TIObject,AValue);
end;

procedure TCustomPropertyLink.EditorChanged;
begin
  if FEditor=nil then begin
    FTIObject:=nil;
    FTIPropertyName:='';
  end else begin
    FTIObject:=FEditor.GetPersistent(0);
    FTIPropertyName:=FEditor.GetName;
  end;
end;

procedure TCustomPropertyLink.InvalidateEditor;
begin
  FreeThenNil(FCollectedValues);
  FreeThenNil(FEditor);
end;

procedure TCustomPropertyLink.SetPropertyEditor(
  APropertyEditor: TPropertyEditor);
begin
  if FEditor=nil then
    FEditor:=APropertyEditor;
end;

function TCustomPropertyLink.CheckPropInfo(const APropInfo: PPropInfo): boolean;
begin
  Result:=CompareText(APropInfo^.Name,FTIPropertyName)=0;
end;

destructor TCustomPropertyLink.Destroy;
begin
  InvalidateEditor;
  if (Application<>nil) and FIdleHandlerConnected then
    Application.RemoveOnIdleHandler(@OnApplicationIdle);
  FreeThenNil(FLinkNotifier);
  FreeThenNil(FAliasValues);
  FreeThenNil(FHook);
  FreeThenNil(FCollectedValues);
  inherited Destroy;
end;

procedure TCustomPropertyLink.Assign(Source: TPersistent);
var
  SrcLink: TCustomPropertyLink;
begin
  if Source is TCustomPropertyLink then begin
    SrcLink:=TCustomPropertyLink(Source);
    SetObjectAndProperty(SrcLink.TIObject,SrcLink.TIPropertyName);
  end else begin
    inherited Assign(Source);
  end;
end;

procedure TCustomPropertyLink.SetObjectAndProperty(NewPersistent: TPersistent;
  const NewPropertyName: string);
begin
  if (NewPropertyName<>'')
  and ((length(NewPropertyName)>254) or (not IsValidIdent(NewPropertyName)))
  then
    raise Exception('TCustomPropertyLink.SetObjectAndProperty invalid identifier "'+NewPropertyName+'"');
  if (NewPersistent=TIObject) and (NewPropertyName=TIPropertyName) then exit;
  if FTIObject is TComponent then
    TComponent(FTIObject).RemoveFreeNotification(FLinkNotifier);
  FTIObject:=NewPersistent;
  if FTIObject is TComponent then
    TComponent(FTIObject).FreeNotification(FLinkNotifier);
  FTIPropertyName:=NewPropertyName;
  InvalidateEditor;
  LoadFromProperty;
end;

procedure TCustomPropertyLink.CreateEditor;
var
  Selection: TPersistentSelectionList;
  OldEditorExisted: Boolean;
begin
  if (FEditor<>nil) or (FTIObject=nil) or (FTIPropertyName='') then exit;
  //writeln('TCustomPropertyLink.CreateEditor A ',FTIObject.ClassName+':'+FTIPropertyName);
  OldEditorExisted:=FEditor<>nil;
  CreateHook;
  Selection := TPersistentSelectionList.Create;
  try
    Selection.Add(FTIObject);
    GetPersistentProperties(Selection,Filter,Hook,@SetPropertyEditor,
      @CheckPropInfo,OnTestEditor);
  finally
    Selection.Free;
  end;
  {if FEditor=nil then begin
    raise Exception.Create('Unable to create property editor for '
                           +FTIObject.ClassName+':'+FTIPropertyName);
  end;}
  if CollectValues then FetchValues;
  if ((FEditor<>nil) or OldEditorExisted) and Assigned(OnEditorChanged) then
    OnEditorChanged(Self);
end;

procedure TCustomPropertyLink.FetchValues;
begin
  FreeThenNil(FCollectedValues);
  if Editor<>nil then
    Editor.GetValues(@GetEditorValues);
end;

procedure TCustomPropertyLink.CreateHook;
begin
  if FHook=nil then FHook:=TPropertyEditorHook.Create;
  FHook.LookupRoot:=TIObject;
end;

procedure TCustomPropertyLink.UpdateIdleHandler;
begin
  if (Application<>nil)
  and ((ploReadOnIdle in Options)<>FIdleHandlerConnected) then begin
    if ploReadOnIdle in Options then begin
      FIdleHandlerConnected:=true;
      Application.AddOnIdleHandler(@OnApplicationIdle);
    end else begin
      FIdleHandlerConnected:=false;
      Application.RemoveOnIdleHandler(@OnApplicationIdle);
    end;
  end;
end;

procedure TCustomPropertyLink.OnApplicationIdle(Sender: TObject);
begin
  if Sender=nil then ;
  if (ploReadOnIdle in FOptions) then begin
    // only update if not editing
    // => check for editing
    if Assigned(OnTestEditing) then begin
      // custom check
      if (OnTestEditing(Self)) then exit;
    end else begin
      // default checks
      if (Owner is TWinControl) and (TWinControl(Owner).Focused) then exit;
    end;
    LoadFromProperty;
  end;
end;

procedure TCustomPropertyLink.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  if (Operation=opRemove) then begin
    if (AComponent=FTIObject) then
      SetObjectAndProperty(nil,FTIPropertyName);
  end;
end;

procedure TCustomPropertyLink.GetEditorValues(const NewValue: string);
begin
  if FCollectedValues=nil then FCollectedValues:=TStringList.Create;
  FCollectedValues.Add(NewValue);
end;

constructor TCustomPropertyLink.Create(TheOwner: TComponent);
begin
  inherited Create;
  FOwner:=TheOwner;
  FSaveEnabled:=true;
  FFilter:=AllTypeKinds;
  FAliasValues:=TAliasStrings.Create;
  FLinkNotifier:=TPropertyLinkNotifier.Create(Self);
end;

procedure TCustomPropertyLink.SaveToProperty;
begin
  if (not SaveEnabled) then exit;
  if (Owner<>nil)
  and ([csDesigning,csDestroying,csLoading]*Owner.ComponentState<>[]) then exit;
  CreateEditor;
  if Assigned(OnSaveToProperty) then OnSaveToProperty(Self);
end;

procedure TCustomPropertyLink.SetAsText(const NewText: string);
begin
  try
    FEditor.SetValue(AliasValues.AliasToValue(NewText));
  except
    on E: Exception do DoError(true,E);
  end;
end;

function TCustomPropertyLink.GetAsText: string;
begin
  Result:='';
  try
    Result:=AliasValues.ValueToAlias(FEditor.GetVisualValue);
  except
    on E: Exception do DoError(false,E);
  end;
end;

procedure TCustomPropertyLink.SetAsInt(const NewInt: integer);
begin
  try
    FEditor.SetValue(IntToStr(NewInt));
  except
    on E: Exception do DoError(true,E);
  end;
end;

function TCustomPropertyLink.GetAsInt: integer;
begin
  Result:=0;
  try
    Result:=FEditor.GetOrdValue;
  except
    on E: Exception do DoError(false,E);
  end;
end;

procedure TCustomPropertyLink.DoError(Writing: boolean; E: Exception);
var
  ACaption: String;
  AText: String;
begin
  ACaption:='Error';
  if Writing then
    AText:='Error while writing property'#13+E.Message
  else
    AText:='Error while reading property'#13+E.Message;
  MessageDlg(ACaption,AText,mtError,[mbCancel],0);
  if Writing then
    LoadFromProperty;
end;

procedure TCustomPropertyLink.MapValues(Values, AliasStrings: TStrings;
  var MappedValues: TStrings; UseAllExistingAlias, AddValuesWithoutAlias,
  IfNoValuesAvailableAddAllAlias: boolean);
var
  AValue: string;
  MappedValue: string;
  i: Integer;
begin
  if (Values=nil) or (Values.Count=0) then begin
    // no values provided by current property editor
    if IfNoValuesAvailableAddAllAlias and (AliasStrings<>nil) then begin
      MappedValues:=TStringList.Create;
      for i:=0 to AliasStrings.Count-1 do
        MappedValues.Add(AliasStrings.Names[i]);
    end else begin
      MappedValues:=nil;
    end;
  end else if AliasStrings<>nil then begin
    // current property editor has provided values
    // => map values via AliasStrings
    MappedValues:=TStringList.Create;
    if UseAllExistingAlias then begin
      // add all existing alias
      for i:=0 to AliasStrings.Count-1 do begin
        AValue:=AliasStrings.Names[i];
        MappedValue:=AliasStrings.Values[AValue];
        //writeln('AAA1 MappedValue=',MappedValue,' AValue=',AValue,' ',Values.IndexOf(AValue));
        if Values.IndexOf(AValue)>=0 then
          MappedValues.Add(MappedValue);
      end;
      // add all values without alias
      if AddValuesWithoutAlias then begin
        for i:=0 to Values.Count-1 do begin
          AValue:=Values[i];
          MappedValue:=AliasStrings.Values[AValue];
          if MappedValue='' then
            // value has no alias
            MappedValues.Add(AValue);
        end;
      end;
    end else begin
      // add all values mapped
      for i:=0 to Values.Count-1 do begin
        AValue:=Values[i];
        MappedValue:=AliasStrings.Values[AValue];
        if MappedValue<>'' then
          // value has alias
          AValue:=MappedValue;
        MappedValues.Add(AValue);
      end;
    end;
  end else begin
    // no alias => simply return a copy of the values
    MappedValues:=TStringList.Create;
    MappedValues.Assign(Values);
  end;
end;

procedure TCustomPropertyLink.MapCollectedValues(AliasStrings: TStrings;
  var MappedValues: TStrings; UseAllExistingAlias, AddValuesWithoutAlias,
  IfNoValuesAvailableAddAllAlias: boolean);
begin
  MapValues(FCollectedValues,AliasStrings,MappedValues,UseAllExistingAlias,
            AddValuesWithoutAlias,IfNoValuesAvailableAddAllAlias);
end;

procedure TCustomPropertyLink.AssignCollectedAliasValuesTo(DestList: TStrings);
var
  MappedValues: TStrings;
begin
  MappedValues:=nil;
  MapCollectedValues(AliasValues,MappedValues,true,true,true);
  try
    DestList.Assign(MappedValues);
  finally
    MappedValues.Free;
  end;
end;

function TCustomPropertyLink.HasAliasValues: boolean;
begin
  Result:=(AliasValues<>nil) and (AliasValues.Count>0);
end;

procedure TCustomPropertyLink.AssignSetEnumsAliasTo(DestList: TStrings);
var
  Enums: TStringList;
  CompData: PTypeInfo;
  TypeData: PTypeData;
  MappedValues: TStrings;
  i: LongInt;
begin
  Enums:=nil;
  MappedValues:=nil;
  try
    // retrieve all set enums
    if GetSetTypeData(CompData,TypeData) then begin
      Enums:=TStringList.Create;
      for i := TypeData^.MinValue to TypeData^.MaxValue do
        Enums.Add(GetEnumName(CompData,i));
      // map values
      MapValues(Enums,AliasValues,MappedValues,true,true,true);
    end;
    // assign values
    if MappedValues<>nil then
      DestList.Assign(MappedValues)
    else
      DestList.Clear;
  finally
    Enums.Free;
    MappedValues.Free;
  end;
end;

function TCustomPropertyLink.GetSetElementValue(const AliasName: string
  ): boolean;
var
  CompData: PTypeInfo;
  TypeData: PTypeData;
  i: LongInt;
  IntegerSet: TIntegerSet;
begin
  Result:=false;
  if not GetSetTypeData(CompData,TypeData) then exit;
  i:=GetIndexOfSetElement(AliasName);
  if i>=0 then begin
    Integer(IntegerSet) := Editor.GetOrdValue;
    Result:=byte(i) in IntegerSet;
  end;
end;

procedure TCustomPropertyLink.SetSetElementValue(const AliasName: string;
  NewValue: boolean);
var
  CompData: PTypeInfo;
  TypeData: PTypeData;
  i: LongInt;
  IntegerSet: TIntegerSet;
begin
  if not GetSetTypeData(CompData,TypeData) then exit;
  i:=GetIndexOfSetElement(AliasName);
  if i>=0 then begin
    Integer(IntegerSet) := Editor.GetOrdValue;
    if NewValue then
      Include(IntegerSet,i)
    else
      Exclude(IntegerSet,i);
    Editor.SetOrdValue(Integer(IntegerSet));
  end;
end;

function TCustomPropertyLink.GetIndexOfSetElement(const AliasName: string
  ): integer;
var
  CompData: PTypeInfo;
  TypeData: PTypeData;
begin
  if not GetSetTypeData(CompData,TypeData) then exit;
  for Result := TypeData^.MinValue to TypeData^.MaxValue do
    if CompareText(AliasName,
                   AliasValues.ValueToAlias(GetEnumName(CompData,Result)))=0
    then
      exit;
  Result:=-1;
end;

function TCustomPropertyLink.GetSetTypeData(var CompData: PTypeInfo;
  var TypeData: PTypeData): boolean;
begin
  Result:=false;
  CompData:=nil;
  TypeData:=nil;
  CreateEditor;
  if (Editor=nil) or (not (Editor is TSetPropertyEditor)) then exit;
  CompData:=GetTypeData(Editor.GetPropType)^.CompType;
  TypeData:=GetTypeData(CompData);
  Result:=(CompData<>nil) and (TypeData<>nil);
end;

procedure TCustomPropertyLink.LoadFromProperty;
begin
  if (Owner<>nil) and (csDestroying in Owner.ComponentState) then exit;
  CreateEditor;
  if Assigned(OnLoadFromProperty) then OnLoadFromProperty(Self);
end;

{ TPropertyLinkPropertyEditor }

function TPropertyLinkPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paSubProperties, paReadOnly];
end;

{ TPropertyNamePropertyEditor }

procedure TPropertyNamePropertyEditor.GetCompatiblePropEdits(
  Prop: TPropertyEditor);
begin
  if FPropEdits=nil then FPropEdits:=TList.Create;
  FPropEdits.Add(Prop);
end;

function TPropertyNamePropertyEditor.TestEditor(const Prop: TPropertyEditor
  ): boolean;
var
  i: Integer;
  CurPersistent: TPersistent;
  ALink: TCustomPropertyLink;
begin
  Result:=false;
  for i:=0 to PropCount-1 do begin
    CurPersistent:=GetPersistent(i);
    if (CurPersistent is TCustomPropertyLink) then begin
      ALink:=TCustomPropertyLink(CurPersistent);
      if Assigned(ALink.OnTestEditor) and (not ALink.OnTestEditor(Prop)) then
        exit;
    end;
  end;
  Result:=true;
end;

function TPropertyNamePropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result:=[paMultiSelect,paValueList,paSortList,paRevertable,paHasDefaultValue];
end;

function TPropertyNamePropertyEditor.GetEditLimit: Integer;
begin
  Result:=255;
end;

procedure TPropertyNamePropertyEditor.GetValues(Proc: TGetStringProc);
var
  ALink: TCustomPropertyLink;
  ASelection: TPersistentSelectionList;
  i: Integer;
  CurPersistent: TPersistent;
  CurTIObject: TPersistent;
  Filter: TTypeKinds;
begin
  ASelection:=TPersistentSelectionList.Create;
  try
    // get every TIObject of every TCustomPropertyLink in the selection
    Filter:=AllTypeKinds;
    for i:=0 to PropCount-1 do begin
      CurPersistent:=GetPersistent(i);
      if (CurPersistent is TCustomPropertyLink) then begin
        ALink:=TCustomPropertyLink(CurPersistent);
        CurTIObject:=ALink.TIObject;
        if CurTIObject<>nil then begin
          ASelection.Add(CurTIObject);
          Filter:=Filter*ALink.Filter;
        end;
      end;
    end;
    if ASelection.Count=0 then exit;
    // get properties of TIObjects
    GetPersistentProperties(ASelection,Filter,PropertyHook,
      @GetCompatiblePropEdits,nil,@TestEditor);
    if FPropEdits<>nil then begin
      for i:=0 to FPropEdits.Count-1 do
        Proc(TPropertyEditor(FPropEdits[i]).GetName);
    end;
  finally
    ASelection.Free;
    if FPropEdits<>nil then begin
      for i:=0 to FPropEdits.Count-1 do
        TPropertyEditor(FPropEdits[i]).Free;
      FreeThenNil(FPropEdits);
    end;
  end;
end;

{ TAliasStringsPropEditorDlg }

procedure TAliasStringsPropEditorDlg.GetDefaultValuesButtonClick(Sender: TObject
  );
var
  ALink: TCustomPropertyLink;
  i: Integer;
  CurPersistent: TPersistent;
begin
  if Sender=nil then ;
  try
    // get every TIObject of every TCustomPropertyLink in the selection
    FCollectedValues:=TAliasStrings.Create;
    FCollectedValues.Text:=Memo.Text;
    for i:=0 to Editor.PropCount-1 do begin
      CurPersistent:=Editor.GetPersistent(i);
      if (CurPersistent is TCustomPropertyLink) then begin
        ALink:=TCustomPropertyLink(CurPersistent);
        ALink.CreateEditor;
        if ALink.Editor<>nil then begin
          ALink.Editor.GetValues(@AddValue);
        end;
      end;
    end;
    Memo.Text:=FCollectedValues.Text;
  finally
    FreeThenNil(FCollectedValues);
  end;
end;

procedure TAliasStringsPropEditorDlg.AddValue(const s: string);
begin
  if FCollectedValues.IndexOfName(s)<0 then
    FCollectedValues.Values[s]:=s;
end;

procedure TAliasStringsPropEditorDlg.AddButtons(var x, y, BtnWidth: integer);
begin
  inherited AddButtons(x, y, BtnWidth);

  GetDefaultValuesButton := TButton.Create(Self);
  with GetDefaultValuesButton do Begin
    Parent := Self;
    dec(x,BtnWidth+8);
    SetBounds(x,y,BtnWidth,Height);
    Anchors:= [akRight, akBottom];
    Caption:='Get Defaults';
    OnClick:=@GetDefaultValuesButtonClick;
  end;
end;

{ TPropLinkAliasPropertyEditor }

function TPropLinkAliasPropertyEditor.CreateDlg(s: TStrings
  ): TStringsPropEditorDlg;
begin
  if s=nil then ;
  Result:=TAliasStringsPropEditorDlg.Create(Application);
  Result.Editor:=Self;
  Result.Memo.Text:=s.Text;
end;

{ TTICustomEdit }

procedure TTICustomEdit.LinkLoadFromProperty(Sender: TObject);
begin
  if Sender=nil then ;
  //writeln('TTICustomEdit.LinkLoadFromProperty A ',Name,
  //  ' FLink.GetAsText=',FLink.GetAsText,' Text=',Text,
  //  ' PropName=',FLink.TIPropertyName);
  if (FLink.Editor=nil) then exit;
  Text:=FLink.GetAsText;
end;

procedure TTICustomEdit.LinkSaveToProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if FLink.Editor=nil then exit;
  FLink.SetAsText(Text);
end;

procedure TTICustomEdit.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

constructor TTICustomEdit.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,}tkInteger,tkChar,tkEnumeration,
                 tkFloat,{tkSet,tkMethod,}tkSString,tkLString,tkAString,
                 tkWString,tkVariant,{tkArray,tkRecord,tkInterface,}
                 {tkClass,tkObject,}tkWChar,tkBool,tkInt64,
                 tkQWord{,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnSaveToProperty:=@LinkSaveToProperty;
end;

destructor TTICustomEdit.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomEdit.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

procedure TTICustomEdit.EditingDone;
begin
  inherited EditingDone;
  FLink.SaveToProperty;
end;

{ TTICustomComboBox }

procedure TTICustomComboBox.LinkEditorChanged(Sender: TObject);
begin
  if Sender=nil then ;
  if Link=nil then exit;
  FLink.AssignCollectedAliasValuesTo(Items);
end;

procedure TTICustomComboBox.DropDown;
var
  MaxItemWidth: LongInt;
  Cnt: LongInt;
  i: Integer;
  ItemValue: string;
  CurItemWidth: LongInt;
begin
  if (Link.Editor<>nil) and (not Link.HasAliasValues) then begin
    MaxItemWidth:=Width;
    Cnt:=Items.Count;
    for i:=0 to Cnt-1 do begin
      ItemValue:=Items[i];
      CurItemWidth:=Canvas.TextWidth(ItemValue);
      Link.Editor.ListMeasureWidth(ItemValue,i,Canvas,CurItemWidth);
      if MaxItemWidth<CurItemWidth then
        MaxItemWidth:=CurItemWidth;
    end;
    ItemWidth:=MaxItemWidth;
  end;
  inherited DropDown;
end;

procedure TTICustomComboBox.DrawItem(Index: Integer; ARect: TRect;
  State: TOwnerDrawState);
var
  AState: TPropEditDrawState;
  ItemValue: string;
begin
  if (Link.Editor=nil) or Link.HasAliasValues then
    inherited DrawItem(Index,ARect,State)
  else begin
    if (Index>=0) and (Index<Items.Count) then
      ItemValue:=Items[Index]
    else
      ItemValue:=Text;

    AState:=[];
    if odPainted in State then Include(AState,pedsPainted);
    if odSelected in State then Include(AState,pedsSelected);
    if odFocused in State then Include(AState,pedsFocused);
    if odComboBoxEdit in State then
      Include(AState,pedsInEdit)
    else
      Include(AState,pedsInComboList);

    // clear background
    with Canvas do begin
      Brush.Color:=clWhite;
      Pen.Color:=clBlack;
      Font.Color:=Pen.Color;
      FillRect(ARect);
    end;

    Link.Editor.ListDrawValue(ItemValue,Index,Canvas,ARect,AState);

    // custom draw
    if Assigned(OnDrawItem) then
      OnDrawItem(Self, Index, ARect, State);
  end;
end;

function TTICustomComboBox.LinkTestEditing(Sender: TObject): boolean;
begin
  if Sender=nil then ;
  Result:=Focused or DroppedDown;
end;

procedure TTICustomComboBox.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomComboBox.LinkLoadFromProperty(Sender: TObject);
begin
  if Sender=nil then ;
  //writeln('TTICustomComboBox.LinkLoadFromProperty A FLink.GetAsText=',FLink.GetAsText,' Text=',Text);
  if (FLink.Editor=nil) then exit;
  //writeln('TTICustomComboBox.LinkLoadFromProperty B FLink.Editor=',FLink.Editor.ClassName);
  Text:=FLink.GetAsText;
end;

procedure TTICustomComboBox.LinkSaveToProperty(Sender: TObject);
begin
  if Sender=nil then ;
  //writeln('TTICustomComboBox.LinkSaveToProperty FLink.GetAsText=',FLink.GetAsText,' Text=',Text);
  if (FLink.Editor=nil) then exit;
  FLink.SetAsText(Text);
end;

constructor TTICustomComboBox.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,}tkInteger,tkChar,tkEnumeration,
                 tkFloat,{tkSet,}tkMethod,tkSString,tkLString,tkAString,
                 tkWString,tkVariant,{tkArray,tkRecord,tkInterface,}
                 tkClass,tkObject,tkWChar,tkBool,tkInt64,
                 tkQWord{,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnSaveToProperty:=@LinkSaveToProperty;
  FLink.OnEditorChanged:=@LinkEditorChanged;
  FLink.CollectValues:=true;
  FLink.OnTestEditing:=@LinkTestEditing;
end;

destructor TTICustomComboBox.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomComboBox.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

procedure TTICustomComboBox.EditingDone;
begin
  inherited EditingDone;
  FLink.SaveToProperty;
end;

{ TTICustomCheckBox }

procedure TTICustomCheckBox.LinkEditorChanged(Sender: TObject);
begin
  if Sender=nil then ;
  if (FLink<>nil) and (FLink.Editor<>nil) then begin
    if FLink.Editor is TBoolPropertyEditor then begin
      FLinkValueFalse:='False';
      FLinkValueTrue:='True';
    end else if FLink.Editor is TOrdinalPropertyEditor then begin
      FLinkValueFalse:='0';
      FLinkValueTrue:='-1';
    end else begin
      FLinkValueFalse:='';
      FLinkValueTrue:='True';
    end;
  end;
end;

procedure TTICustomCheckBox.DoAutoSize;
var
  R : TRect;
  DC : hDC;
begin
  If AutoSizing or not AutoSize then
    Exit;
  if (not HandleAllocated) or ([csLoading,csDestroying]*ComponentState<>[]) then
    exit;
  AutoSizing := True;
  DC := GetDC(Handle);
  Try
    R := Rect(0,0, Width, Height);
    DrawText(DC, PChar(Caption), Length(Caption), R,
      DT_CalcRect);
    If R.Right > Width then
      Width := R.Right + 25;
    If R.Bottom > Height then
      Height := R.Bottom + 2;
  Finally
    ReleaseDC(0, DC);
    AutoSizing := False;
  end;
end;

procedure TTICustomCheckBox.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomCheckBox.LinkLoadFromProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  Checked:=FLink.GetAsText<>FLinkValueFalse;
end;

procedure TTICustomCheckBox.LinkSaveToProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if FLink.Editor=nil then exit;
  if Checked then
    FLink.SetAsText(FLinkValueTrue)
  else
    FLink.SetAsText(FLinkValueFalse);
end;

constructor TTICustomCheckBox.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLinkValueFalse:='False';
  FLinkValueTrue:='True';
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,}tkInteger{,tkChar},tkEnumeration,
                 {tkFloat,tkSet,tkMethod,}tkSString,tkLString,tkAString,
                 tkWString,tkVariant,{tkArray,tkRecord,tkInterface,}
                 {tkClass,tkObject,}tkWChar,tkBool,tkInt64,
                 tkQWord{,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnSaveToProperty:=@LinkSaveToProperty;
  FLink.OnEditorChanged:=@LinkEditorChanged;
end;

destructor TTICustomCheckBox.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomCheckBox.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

procedure TTICustomCheckBox.EditingDone;
begin
  inherited EditingDone;
  FLink.SaveToProperty;
end;

{ TTICustomLabel }

procedure TTICustomLabel.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomLabel.LinkLoadFromProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  Caption:=FLink.GetAsText;
end;

constructor TTICustomLabel.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,}tkInteger,tkChar,tkEnumeration,
                 tkFloat,{tkSet,tkMethod,}tkSString,tkLString,tkAString,
                 tkWString,tkVariant,{tkArray,tkRecord,tkInterface,}
                 {tkClass,tkObject,}tkWChar,tkBool,tkInt64,
                 tkQWord{,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
end;

destructor TTICustomLabel.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomLabel.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

{ TTICustomGroupbox }

procedure TTICustomGroupbox.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomGroupbox.LinkLoadFromProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  Caption:=FLink.GetAsText;
end;

constructor TTICustomGroupbox.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,}tkInteger,tkChar,tkEnumeration,
                 tkFloat,{tkSet,tkMethod,}tkSString,tkLString,tkAString,
                 tkWString,tkVariant,{tkArray,tkRecord,tkInterface,}
                 {tkClass,tkObject,}tkWChar,tkBool,tkInt64,
                 tkQWord{,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
end;

destructor TTICustomGroupbox.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomGroupbox.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

{ TTICustomRadioGroup }

procedure TTICustomRadioGroup.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomRadioGroup.LinkLoadFromProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  ItemIndex:=Items.IndexOf(FLink.GetAsText);
end;

procedure TTICustomRadioGroup.LinkSaveToProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  if ItemIndex>=0 then
    FLink.SetAsText(Items[ItemIndex]);
end;

procedure TTICustomRadioGroup.LinkEditorChanged(Sender: TObject);
begin
  if Sender=nil then ;
  if Link=nil then exit;
  FLink.AssignCollectedAliasValuesTo(Items);
end;

constructor TTICustomRadioGroup.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,}tkInteger,{tkChar,}tkEnumeration,
                 {tkFloat,tkSet,tkMethod,}tkSString,tkLString,tkAString,
                 tkWString,{tkVariant,tkArray,tkRecord,tkInterface,}
                 {tkClass,tkObject,tkWChar,}tkBool{,tkInt64,}
                 {tkQWord,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnSaveToProperty:=@LinkSaveToProperty;
  FLink.CollectValues:=true;
  FLink.OnEditorChanged:=@LinkEditorChanged;
end;

destructor TTICustomRadioGroup.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomRadioGroup.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

procedure TTICustomRadioGroup.EditingDone;
begin
  inherited EditingDone;
  FLink.SaveToProperty;
end;

{ TTICustomCheckGroup }

procedure TTICustomCheckGroup.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomCheckGroup.LinkLoadFromProperty(Sender: TObject);
var
  i: Integer;
begin
  if Sender=nil then ;
  if Link.Editor=nil then exit;
  for i:=0 to Items.Count-1 do
    Checked[i]:=Link.GetSetElementValue(Items[i]);
end;

procedure TTICustomCheckGroup.LinkSaveToProperty(Sender: TObject);
var
  i: Integer;
begin
  if Sender=nil then ;
  if Link.Editor=nil then exit;
  for i:=0 to Items.Count-1 do
    Link.SetSetElementValue(Items[i],Checked[i]);
end;

procedure TTICustomCheckGroup.LinkEditorChanged(Sender: TObject);
begin
  if Sender=nil then ;
  if Link=nil then exit;
  Link.AssignSetEnumsAliasTo(Items);
end;

constructor TTICustomCheckGroup.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,tkInteger,tkChar,tkEnumeration,}
                 {tkFloat,}tkSet{,tkMethod,tkSString,tkLString,tkAString,}
                 {tkWString,tkVariant,tkArray,tkRecord,tkInterface,}
                 {tkClass,tkObject,tkWChar,tkBool,tkInt64,}
                 {tkQWord,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnSaveToProperty:=@LinkSaveToProperty;
  FLink.CollectValues:=true;
  FLink.OnEditorChanged:=@LinkEditorChanged;
end;

destructor TTICustomCheckGroup.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomCheckGroup.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

procedure TTICustomCheckGroup.EditingDone;
begin
  inherited EditingDone;
  FLink.SaveToProperty;
end;

{ TTICustomMemo }

function TTICustomMemo.LinkTestEditor(const ATestEditor: TPropertyEditor
  ): Boolean;
begin
  Result:=(ATestEditor is TStringPropertyEditor)
       or (ATestEditor is TStringsPropertyEditor);
end;

procedure TTICustomMemo.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomMemo.LinkLoadFromProperty(Sender: TObject);
var
  PropKind: TTypeKind;
  CurObject: TObject;
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  PropKind:=FLink.Editor.GetPropType^.Kind;
  if PropKind=tkClass then begin
    CurObject:=FLink.Editor.GetObjectValue;
    if CurObject is TStrings then
      Lines.Assign(TStrings(CurObject))
    else
      Lines.Clear;
  end else if PropKind in [tkSString,tkLString,tkAString,tkWString] then begin
    Lines.Text:=FLink.GetAsText;
  end else
    Lines.Clear;
end;

procedure TTICustomMemo.LinkSaveToProperty(Sender: TObject);
var
  PropKind: TTypeKind;
  CurObject: TObject;
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  PropKind:=FLink.Editor.GetPropType^.Kind;
  if PropKind=tkClass then begin
    CurObject:=FLink.Editor.GetObjectValue;
    if CurObject is TStrings then
      TStrings(CurObject).Assign(Lines);
  end else if PropKind in [tkSString,tkLString,tkAString,tkWString] then begin
    FLink.SetAsText(Lines.Text);
  end;
end;

constructor TTICustomMemo.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,tkInteger,tkChar,tkEnumeration,}
                 {tkFloat,tkSet,tkMethod,}tkSString,tkLString,tkAString,
                 tkWString,{tkVariant,tkArray,tkRecord,tkInterface,}
                 tkClass{,tkObject,tkWChar,tkBool,tkInt64,}
                 {tkQWord,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnSaveToProperty:=@LinkSaveToProperty;
  FLink.OnTestEditor:=@LinkTestEditor;
end;

destructor TTICustomMemo.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomMemo.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

procedure TTICustomMemo.EditingDone;
begin
  inherited EditingDone;
  FLink.SaveToProperty;
end;

{ TTICustomCalendar }

function TTICustomCalendar.LinkTestEditor(const ATestEditor: TPropertyEditor
  ): Boolean;
begin
  Result:=(ATestEditor is TDatePropertyEditor)
       or (ATestEditor is TStringPropertyEditor);
end;

procedure TTICustomCalendar.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomCalendar.LinkLoadFromProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  try
    Date:=FLink.GetAsText;
  except
    // ignore invalid dates
    on E: EInvalidDate do ;
  end;
end;

procedure TTICustomCalendar.LinkSaveToProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  FLink.SetAsText(Date);
end;

constructor TTICustomCalendar.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,tkInteger,tkChar,tkEnumeration,}
                 tkFloat,{tkSet,tkMethod,}tkSString,tkLString,tkAString,
                 tkWString{,tkVariant,tkArray,tkRecord,tkInterface,}
                 {tkClass,tkObject,tkWChar,tkBool,tkInt64,}
                 {tkQWord,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnSaveToProperty:=@LinkSaveToProperty;
  FLink.OnTestEditor:=@LinkTestEditor;
end;

destructor TTICustomCalendar.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomCalendar.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

procedure TTICustomCalendar.EditingDone;
begin
  inherited EditingDone;
  FLink.SaveToProperty;
end;

{ TTICustomPropertyGrid }

procedure TTICustomPropertyGrid.SetTIObject(const AValue: TPersistent);
var
  NewSelection: TPersistentSelectionList;
begin
  if (TIObject=AValue) then begin
    if ((AValue<>nil) and (Selection.Count=1) and (Selection[0]=AValue))
    or (AValue=nil) then
      exit;
  end;
  if PropertyEditorHook=nil then
    PropertyEditorHook:=TPropertyEditorHook.Create;
  PropertyEditorHook.LookupRoot:=AValue;
  if (AValue<>nil) and ((Selection.Count<>1) or (Selection[0]<>AValue)) then
  begin
    NewSelection:=TPersistentSelectionList.Create;
    try
      if AValue<>nil then
        NewSelection.Add(AValue);
      Selection:=NewSelection;
    finally
      NewSelection.Free;
    end;
  end;
end;

function TTICustomPropertyGrid.GetTIObject: TPersistent;
begin
  if PropertyEditorHook<>nil then Result:=PropertyEditorHook.LookupRoot;
end;

procedure TTICustomPropertyGrid.SetAutoFreeHook(const AValue: boolean);
begin
  if FAutoFreeHook=AValue then exit;
  FAutoFreeHook:=AValue;
end;

constructor TTICustomPropertyGrid.Create(TheOwner: TComponent);
var
  Hook: TPropertyEditorHook;
begin
  Hook:=TPropertyEditorHook.Create;
  AutoFreeHook:=true;
  CreateWithParams(TheOwner,Hook,AllTypeKinds,25);
end;

{ TTICustomSpinEdit }

procedure TTICustomSpinEdit.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomSpinEdit.SetUseRTTIMinMax(const AValue: boolean);
begin
  if FUseRTTIMinMax=AValue then exit;
  FUseRTTIMinMax:=AValue;
  if UseRTTIMinMax then GetRTTIMinMax;
end;

procedure TTICustomSpinEdit.LinkLoadFromProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  try
    Value:=Single(StrToFloat(FLink.GetAsText));
  except
  end;
end;

procedure TTICustomSpinEdit.LinkSaveToProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if FLink.Editor=nil then exit;
  FLink.SetAsText(FloatToStr(Value));
end;

procedure TTICustomSpinEdit.LinkEditorChanged(Sender: TObject);
var
  TypeData: PTypeData;
  PropKind: TTypeKind;
  OldLinkSaveEnabled: Boolean;
  f: Extended;
begin
  if Sender=nil then ;
  if FLink.Editor=nil then exit;
  OldLinkSaveEnabled:=FLink.SaveEnabled;
  FLink.SaveEnabled:=false;
  try
    PropKind:=FLink.Editor.GetPropType^.Kind;
    case PropKind of

    tkInteger,tkChar,tkEnumeration,tkWChar:
      begin
        TypeData:=GetTypeData(FLink.Editor.GetPropType);
        MinValue:=TypeData^.MinValue;
        MaxValue:=TypeData^.MaxValue;
        Climb_Rate:=1;
        Decimal_Places:=0;
      end;

    tkInt64:
      begin
        TypeData:=GetTypeData(FLink.Editor.GetPropType);
        MinValue:=TypeData^.MinInt64Value;
        MaxValue:=TypeData^.MaxInt64Value;
        Climb_Rate:=1;
        Decimal_Places:=0;
      end;
      
    tkQWord:
      begin
        TypeData:=GetTypeData(FLink.Editor.GetPropType);
        MinValue:=TypeData^.MinQWordValue;
        MaxValue:=TypeData^.MaxQWordValue;
        Climb_Rate:=1;
        Decimal_Places:=0;
      end;

    else
      begin
        try
          f:=StrToFloat(FLink.GetAsText);
        except
        end;
        if f<MinValue then MinValue:=Single(f);
        if f>MaxValue then MaxValue:=Single(f);
      end;
      
    end;
  finally
    FLink.SaveEnabled:=OldLinkSaveEnabled;
  end;
end;

procedure TTICustomSpinEdit.GetRTTIMinMax;
begin
  if UseRTTIMinMax then GetRTTIMinMax;
end;

constructor TTICustomSpinEdit.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FUseRTTIMinMax:=true;
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,}tkInteger,{tkChar,tkEnumeration,}
                 tkFloat,{tkSet,tkMethod,}tkSString,tkLString,tkAString,
                 tkWString{,tkVariant,tkArray,tkRecord,tkInterface,}
                 {tkClass,tkObject,tkWChar,tkBool},tkInt64,
                 tkQWord{,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnSaveToProperty:=@LinkSaveToProperty;
  FLink.OnEditorChanged:=@LinkEditorChanged;
end;

destructor TTICustomSpinEdit.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomSpinEdit.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

procedure TTICustomSpinEdit.EditingDone;
begin
  inherited EditingDone;
  FLink.SaveToProperty;
end;

{ TTICustomImage }

function TTICustomImage.LinkTestEditor(const ATestEditor: TPropertyEditor
  ): Boolean;
begin
  Result:=(ATestEditor is TGraphicPropertyEditor);
end;

procedure TTICustomImage.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomImage.LinkLoadFromProperty(Sender: TObject);
var
  AnObject: TObject;
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  if FLink.Editor is TClassPropertyEditor then begin
    AnObject:=FLink.Editor.GetObjectValue;
    if AnObject is TImage then begin
      Picture.Assign(TImage(AnObject).Picture);
    end else if AnObject is TPicture then begin
      Picture.Assign(TPicture(AnObject));
    end else if AnObject is TGraphic then begin
      Picture.Assign(TGraphic(AnObject));
    end;
  end;
end;

constructor TTICustomImage.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,tkInteger,tkChar,tkEnumeration,}
                 {tkFloat,tkSet,tkMethod,tkSString,tkLString,tkAString,}
                 {tkWString,tkVariant,tkArray,tkRecord,tkInterface,}
                 tkClass{,tkObject,tkWChar,tkBool,tkInt64,}
                 {tkQWord,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnTestEditor:=@LinkTestEditor;
end;

destructor TTICustomImage.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomImage.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

{ TTICustomTrackBar }

procedure TTICustomTrackBar.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomTrackBar.SetUseRTTIMinMax(const AValue: boolean);
begin
  if FUseRTTIMinMax=AValue then exit;
  FUseRTTIMinMax:=AValue;
  if UseRTTIMinMax then GetRTTIMinMax;
end;

procedure TTICustomTrackBar.LinkLoadFromProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  try
    Position:=StrToInt(FLink.GetAsText);
  except
  end;
end;

procedure TTICustomTrackBar.LinkSaveToProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  FLink.SetAsText(IntToStr(Position));
end;

procedure TTICustomTrackBar.LinkEditorChanged(Sender: TObject);
begin
  if Sender=nil then ;
  if UseRTTIMinMax then GetRTTIMinMax;
end;

procedure TTICustomTrackBar.GetRTTIMinMax;
var
  TypeData: PTypeData;
  PropKind: TTypeKind;
  OldLinkSaveEnabled: Boolean;
  i: Integer;
begin
  if FLink.Editor=nil then exit;
  OldLinkSaveEnabled:=FLink.SaveEnabled;
  FLink.SaveEnabled:=false;
  try
    PropKind:=FLink.Editor.GetPropType^.Kind;
    case PropKind of

    tkInteger,tkChar,tkEnumeration,tkWChar:
      begin
        TypeData:=GetTypeData(FLink.Editor.GetPropType);
        Min:=TypeData^.MinValue;
        Max:=TypeData^.MaxValue;
        Frequency:=1;
      end;

    else
      begin
        try
          i:=StrToInt(FLink.GetAsText);
        except
        end;
        if i<Min then Min:=i;
        if i>Max then Max:=i;
      end;

    end;
  finally
    FLink.SaveEnabled:=OldLinkSaveEnabled;
  end;
end;

constructor TTICustomTrackBar.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FUseRTTIMinMax:=true;
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,}tkInteger,{tkChar,tkEnumeration,}
                 tkFloat,{tkSet,tkMethod,}tkSString,tkLString,tkAString,
                 tkWString{,tkVariant,tkArray,tkRecord,tkInterface,}
                 {tkClass,tkObject,tkWChar,tkBool,tkInt64,}
                 {tkQWord,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnSaveToProperty:=@LinkSaveToProperty;
  FLink.OnEditorChanged:=@LinkEditorChanged;
end;

destructor TTICustomTrackBar.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomTrackBar.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

procedure TTICustomTrackBar.EditingDone;
begin
  inherited EditingDone;
  FLink.SaveToProperty;
end;

{ TTICustomMaskEdit }

procedure TTICustomMaskEdit.LinkLoadFromProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if (FLink.Editor=nil) then exit;
  Text:=FLink.GetAsText;
end;

procedure TTICustomMaskEdit.LinkSaveToProperty(Sender: TObject);
begin
  if Sender=nil then ;
  if FLink.Editor=nil then exit;
  FLink.SetAsText(Text);
end;

procedure TTICustomMaskEdit.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

constructor TTICustomMaskEdit.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,}tkInteger,tkChar,tkEnumeration,
                 tkFloat,{tkSet,tkMethod,}tkSString,tkLString,tkAString,
                 tkWString,tkVariant,{tkArray,tkRecord,tkInterface,}
                 {tkClass,tkObject,}tkWChar,tkBool,tkInt64,
                 tkQWord{,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnSaveToProperty:=@LinkSaveToProperty;
end;

destructor TTICustomMaskEdit.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomMaskEdit.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

procedure TTICustomMaskEdit.EditingDone;
begin
  inherited EditingDone;
  FLink.SaveToProperty;
end;

{ TTICustomButton }

function TTICustomButton.LinkTestEditor(const ATestEditor: TPropertyEditor
  ): Boolean;
begin
  Result:=paDialog in ATestEditor.GetAttributes;
end;

procedure TTICustomButton.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomButton.Click;
begin
  inherited Click;
  if Link.Editor<>nil then
    Link.Editor.Edit;
end;

constructor TTICustomButton.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=AllTypeKinds;
  FLink.OnTestEditor:=@LinkTestEditor;
end;

destructor TTICustomButton.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

{ TTICustomCheckListBox }

procedure TTICustomCheckListBox.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomCheckListBox.LinkLoadFromProperty(Sender: TObject);
var
  i: Integer;
begin
  if Sender=nil then ;
  if Link.Editor=nil then exit;
  for i:=0 to Items.Count-1 do
    Checked[i]:=Link.GetSetElementValue(Items[i]);
end;

procedure TTICustomCheckListBox.LinkSaveToProperty(Sender: TObject);
var
  i: Integer;
begin
  if Sender=nil then ;
  if Link.Editor=nil then exit;
  for i:=0 to Items.Count-1 do
    Link.SetSetElementValue(Items[i],Checked[i]);
end;

procedure TTICustomCheckListBox.LinkEditorChanged(Sender: TObject);
begin
  if Sender=nil then ;
  if Link=nil then exit;
  Link.AssignSetEnumsAliasTo(Items);
end;

constructor TTICustomCheckListBox.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[{tkUnknown,tkInteger,tkChar,tkEnumeration,}
                 {tkFloat,}tkSet{,tkMethod,tkSString,tkLString,tkAString,}
                 {tkWString,tkVariant,tkArray,tkRecord,tkInterface,}
                 {tkClass,tkObject,tkWChar,tkBool,tkInt64,}
                 {tkQWord,tkDynArray,tkInterfaceRaw}];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnSaveToProperty:=@LinkSaveToProperty;
  FLink.CollectValues:=true;
  FLink.OnEditorChanged:=@LinkEditorChanged;
end;

destructor TTICustomCheckListBox.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomCheckListBox.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

procedure TTICustomCheckListBox.EditingDone;
begin
  inherited EditingDone;
  FLink.SaveToProperty;
end;

{ TTICustomListBox }

procedure TTICustomListBox.SetLink(const AValue: TPropertyLink);
begin
  if FLink=AValue then exit;
  FLink.Assign(AValue);
end;

procedure TTICustomListBox.LinkLoadFromProperty(Sender: TObject);
var
  i: Integer;
begin
  if Sender=nil then ;
  if Link.Editor=nil then exit;
  if Link.Editor is TSetPropertyEditor then begin
    for i:=0 to Items.Count-1 do
      Selected[i]:=Link.GetSetElementValue(Items[i]);
  end else begin
    ItemIndex:=Items.IndexOf(Link.GetAsText);
  end;
end;

procedure TTICustomListBox.LinkSaveToProperty(Sender: TObject);
var
  i: Integer;
begin
  if Sender=nil then ;
  if Link.Editor=nil then exit;
  if Link.Editor is TSetPropertyEditor then begin
    for i:=0 to Items.Count-1 do
      Link.SetSetElementValue(Items[i],Selected[i]);
  end else begin
    if ItemIndex>=0 then
      Link.SetAsText(Items[ItemIndex]);
  end;
end;

procedure TTICustomListBox.LinkEditorChanged(Sender: TObject);
begin
  if Sender=nil then ;
  if Link=nil then exit;
  if Link.Editor is TSetPropertyEditor then begin
    MultiSelect:=true;
    Link.AssignSetEnumsAliasTo(Items);
  end else begin
    Link.AssignCollectedAliasValuesTo(Items);
  end;
end;

procedure TTICustomListBox.DrawItem(Index: Integer; ARect: TRect;
  State: TOwnerDrawState);
var
  AState: TPropEditDrawState;
  ItemValue: string;
begin
  if (Link.Editor=nil) or Link.HasAliasValues then
    inherited DrawItem(Index,ARect,State)
  else begin
    if (Index>=0) and (Index<Items.Count) then
      ItemValue:=Items[Index]
    else
      ItemValue:=Text;

    AState:=[];
    if odPainted in State then Include(AState,pedsPainted);
    if odSelected in State then Include(AState,pedsSelected);
    if odFocused in State then Include(AState,pedsFocused);
    Include(AState,pedsInEdit);

    // clear background
    with Canvas do begin
      if odSelected in State then
        Brush.Color:=clLtGray
      else
        Brush.Color:=clWhite;
      Pen.Color:=clBlack;
      Font.Color:=Pen.Color;
      FillRect(ARect);
    end;

    Link.Editor.ListDrawValue(ItemValue,Index,Canvas,ARect,AState);

    // custom draw
    if Assigned(OnDrawItem) then
      OnDrawItem(Self, Index, ARect, State);
  end;
end;

constructor TTICustomListBox.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FLink:=TPropertyLink.Create(Self);
  FLink.Filter:=[tkUnknown,tkInteger,tkChar,tkEnumeration,
                 tkFloat,tkSet,tkMethod,tkSString,tkLString,tkAString,
                 tkWString,tkVariant,tkArray,tkRecord,tkInterface,
                 tkClass,tkObject,tkWChar,tkBool,tkInt64,
                 tkQWord,tkDynArray,tkInterfaceRaw];
  FLink.OnLoadFromProperty:=@LinkLoadFromProperty;
  FLink.OnSaveToProperty:=@LinkSaveToProperty;
  FLink.CollectValues:=true;
  FLink.OnEditorChanged:=@LinkEditorChanged;
end;

destructor TTICustomListBox.Destroy;
begin
  FreeThenNil(FLink);
  inherited Destroy;
end;

procedure TTICustomListBox.Loaded;
begin
  inherited Loaded;
  FLink.LoadFromProperty;
end;

procedure TTICustomListBox.EditingDone;
begin
  inherited EditingDone;
  FLink.SaveToProperty;
end;

{ TPropertyLinkNotifier }

procedure TPropertyLinkNotifier.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Flink<>nil then FLink.Notification(AComponent,Operation);
end;

constructor TPropertyLinkNotifier.Create(TheLink: TCustomPropertyLink);
begin
  inherited Create(nil);
  FLink:=TheLink;
end;

initialization
  {$I rttictrls.lrs}
  // TPropertyLink
  RegisterPropertyEditor(ClassTypeInfo(TPropertyLink),
    nil, '', TPropertyLinkPropertyEditor);
  // property editor for TCustomPropertyLink.TIPropertyName
  RegisterPropertyEditor(TypeInfo(string),
    TCustomPropertyLink, 'TIPropertyName', TPropertyNamePropertyEditor);
  // property editor for TCustomPropertyLink.TIObject
  RegisterPropertyEditor(ClassTypeInfo(TPersistent),
    TCustomPropertyLink, 'TIObject', TTIObjectPropertyEditor);
  // property editor for TCustomPropertyLink.AliasValues
  RegisterPropertyEditor(ClassTypeInfo(TAliasStrings),
    TCustomPropertyLink, 'AliasValues', TPropLinkAliasPropertyEditor);
  // property editor for TTICustomPropertyGrid.TIObject
  RegisterPropertyEditor(ClassTypeInfo(TPersistent),
    TTICustomPropertyGrid, 'TIObject', TTIObjectPropertyEditor);

end.
