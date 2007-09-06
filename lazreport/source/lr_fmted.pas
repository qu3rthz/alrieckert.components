
{*****************************************}
{                                         }
{             FastReport v2.3             }
{              Format editor              }
{                                         }
{  Copyright (c) 1998-99 by Tzyganenko A. }
{                                         }
{*****************************************}

unit LR_fmted;

interface

{$I LR_Vers.inc}

uses
  Classes, SysUtils, LResources,
  Forms, Controls, Graphics, Dialogs,
  Buttons, StdCtrls,ExtCtrls,LR_Class;

type

  { TfrFmtForm }

  TfrFmtForm = class(TForm)
    GroupBox2: TGroupBox;
    ComboBox1: TComboBox;
    ComboBox2: TComboBox;
    Panel1: TPanel;
    Label5: TLabel;
    Label6: TLabel;
    SplEdit: TEdit;
    Button1: TButton;
    Button2: TButton;
    Panel2: TPanel;
    Edit1: TEdit;
    Label1: TLabel;
    Edit3: TEdit;
    procedure FormActivate(Sender: TObject);
    procedure SplEditChange(Sender: TObject);
    procedure ComboBox2Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure SplEditEnter(Sender: TObject);
    procedure ShowPanel1;
    procedure ShowPanel2;
    procedure FormCreate(Sender: TObject);
    procedure frFmtFormShow(Sender: TObject);
  private
    fOldC1 : Integer;
    FFormat: Integer;
    FFormatStr:string;
    function GetFormat: Integer;
    function GetFormatStr: string;
    procedure SetFormat(const AValue: Integer);
    procedure SetFormatStr(const AValue: string);
  public
    { Public declarations }
    property AFormat: Integer read GetFormat write SetFormat;
    property FormatStr:string read GetFormatStr write SetFormatStr;
  end;

var
  frFmtForm: TfrFmtForm;

implementation

uses LR_Const;

{$WARNINGS OFF}
procedure TfrFmtForm.FormActivate(Sender: TObject);
begin
end;

procedure TfrFmtForm.ShowPanel1;
begin
  Panel1.Visible := (ComboBox1.ItemIndex = 1) and (not Panel2.Visible);
{  if Panel1.Visible then
  begin
    Edit3.Text := IntToStr((Format and $0000FF00) div $00000100);
    SplEdit.Text := Chr(Format and $000000FF);
  end;}
end;

procedure TfrFmtForm.ShowPanel2;
begin
  Panel2.Visible := ComboBox2.ItemIndex = 4;
end;

procedure TfrFmtForm.ComboBox1Change(Sender: TObject);
var
  i, k: Integer;
  s: String;
begin
  k := ComboBox1.ItemIndex;
  if (k = -1) or (k=fOldC1) then Exit;
  fOldC1:=k;
  ComboBox2.Items.Clear;
  Case k of
    fmtText   : ComboBox2.Items.Add(sFormat11);
    fmtNumber : begin
                  ComboBox2.Items.Add(sFormat21);
                  ComboBox2.Items.Add(sFormat22);
                  ComboBox2.Items.Add(sFormat23);
                  ComboBox2.Items.Add(sFormat24);
                  ComboBox2.Items.Add(sFormat25);
                end;
    fmtDate   : begin
                  ComboBox2.Items.Add(sFormat31);
                  ComboBox2.Items.Add(sFormat32);
                  ComboBox2.Items.Add(sFormat33);
                  ComboBox2.Items.Add(sFormat34);
                  ComboBox2.Items.Add(sFormat35);
                end;
    fmtTime   : begin
                  ComboBox2.Items.Add(sFormat41);
                  ComboBox2.Items.Add(sFormat42);
                  ComboBox2.Items.Add(sFormat43);
                  ComboBox2.Items.Add(sFormat44);
                  ComboBox2.Items.Add(sFormat45);
                end;
    fmtBoolean: begin
                  ComboBox2.Items.Add(sFormat51);
                  ComboBox2.Items.Add(sFormat52);
                  ComboBox2.Items.Add(sFormat53);
                  ComboBox2.Items.Add(sFormat54);
                  ComboBox2.Items.Add(sFormat55);
                end;
  end;

  ComboBox2.ItemIndex := 0;
  if Sender <> nil then
  begin
    ComboBox2Click(nil);
    ShowPanel1;
    Edit1.Text := '';
  end;
end;

procedure TfrFmtForm.ComboBox2Click(Sender: TObject);
begin
  ShowPanel2;
  ShowPanel1;
end;

procedure TfrFmtForm.SplEditChange(Sender: TObject);
var
  c: Char;
begin
  c := ',';
  if SplEdit.Text <> '' then
    c := SplEdit.Text[1];
end;

procedure TfrFmtForm.SplEditEnter(Sender: TObject);
begin
  SplEdit.SelectAll;
end;
{$WARNINGS ON}

procedure TfrFmtForm.FormCreate(Sender: TObject);
begin
  fOldC1:=-1;
  Caption := sFmtFormFrmtVar;
  GroupBox2.Caption := sFmtFormVarFmt;
  Label5.Caption := sFmtFormDeciD;
  Label6.Caption := sFmtFormFrac;
  Label1.Caption := sFmtFormFrmt;
  Button1.Caption := sOk;
  Button2.Caption := sCancel;
end;

procedure TfrFmtForm.frFmtFormShow(Sender: TObject);
begin
  Panel1.Hide;
  Panel2.Hide;
  ComboBox1.Items.Clear;
  ComboBox1.Items.Add(sCateg1);
  ComboBox1.Items.Add(sCateg2);
  ComboBox1.Items.Add(sCateg3);
  ComboBox1.Items.Add(sCateg4);
  ComboBox1.Items.Add(sCateg5);

  ComboBox1.ItemIndex := (FFormat and $0F000000) div $01000000;
  ComboBox1Change(nil);
  ComboBox2.ItemIndex := (FFormat and $00FF0000) div $00010000;
  ShowPanel2;
  ShowPanel1;
end;

procedure TfrFmtForm.SetFormat(const AValue: Integer);
begin
  FFormat:=AValue;
end;

function TfrFmtForm.GetFormatStr: string;
begin
  if Edit1.Enabled then
    Result := Edit1.Text
  else
    Result := FFormatStr;
end;

procedure TfrFmtForm.SetFormatStr(const AValue: string);
begin
  FFormatStr:=AValue;
  Edit1.Text:=AValue;
end;

function TfrFmtForm.GetFormat: Integer;
var
  c: Char;
begin
  Result := ComboBox1.ItemIndex * $01000000 + ComboBox2.ItemIndex * $00010000 +
    StrToIntDef(Edit3.Text, 0) * $00000100;
  c := ',';
  if SplEdit.Text <> '' then
    c := SplEdit.Text[1];
  Result := Result + Ord(c);
end;

initialization
  {$I lr_fmted.lrs}

end.
