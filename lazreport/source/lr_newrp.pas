
{*****************************************}
{                                         }
{             FastReport v2.3             }
{             Template viewer             }
{                                         }
{  Copyright (c) 1998-99 by Tzyganenko A. }
{                                         }
{*****************************************}

unit LR_Newrp;

interface

{$I LR_Vers.inc}

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  Buttons, StdCtrls,ExtCtrls, ButtonPanel, LR_Const;

type

  { TfrTemplForm }

  TfrTemplForm = class(TForm)
    ButtonPanel1: TButtonPanel;
    GroupBox1: TGroupBox;
    Memo1: TMemo;
    Image1: TImage;
    LB1: TListBox;
    procedure FormActivate(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
    procedure FormDeactivate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LB1DblClick(Sender: TObject);
  private
    FTemplatePath: String;
  public
    DefaultTemplate: boolean;
    TemplName: String;
  end;

var
  frTemplForm: TfrTemplForm;

implementation
uses LR_Class, LR_Desgn;

{$R *.lfm}

procedure TfrTemplForm.FormActivate(Sender: TObject);
var
  SearchRec: TSearchRec;
  r: Word;
begin
  LB1.Items.Clear;
  R := FindFirstUTF8(FTemplatePath + '*.frt', faAnyFile, SearchRec);
  while R = 0 do
  begin
    if (SearchRec.Attr and faDirectory) = 0 then
      LB1.Items.Add(ChangeFileExt(SearchRec.Name, ''));
    R := FindNextUTF8(SearchRec);
  end;
  FindCloseUTF8(SearchRec);

  R := FindFirstUTF8(FTemplatePath + '*.lrt', faAnyFile, SearchRec);
  while R = 0 do
  begin
    if (SearchRec.Attr and faDirectory) = 0 then
      LB1.Items.Add(ChangeFileExt(SearchRec.Name, ''));
    R := FindNextUTF8(SearchRec);
  end;
  FindCloseUTF8(SearchRec);

  Memo1.Lines.Clear;
  Image1.Picture.Clear;
  ButtonPanel1.OKButton.Enabled := False;
  LB1.Items.InsertObject(0, sTemplEmtpyRp, self);
end;

procedure TfrTemplForm.ListBox1Click(Sender: TObject);
var
  Index: Integer;
begin
  Index := LB1.ItemIndex;
  ButtonPanel1.OKButton.Enabled := Index <> -1;
  if ButtonPanel1.OKButton.Enabled then
  begin
    if LB1.Items.Objects[Index]=Self then
    begin
      Memo1.Lines.Text := sTemplEmptyDesc;
      Image1.Picture.Clear;
    end
    else
      if FileExistsUTF8(FTemplatePath + LB1.Items[Index] + '.frt') then
        CurReport.LoadTemplate(FTemplatePath + LB1.Items[Index] + '.frt', Memo1.Lines, Image1.Picture.Bitmap,False)
      else
      if FileExistsUTF8(FTemplatePath + LB1.Items[Index] + '.lrt') then
        CurReport.LoadTemplateXML(FTemplatePath + LB1.Items[Index] + '.lrt', Memo1.Lines, Image1.Picture.Bitmap,False)
  end;
end;

procedure TfrTemplForm.LB1DblClick(Sender: TObject);
begin
  if ButtonPanel1.OKButton.Enabled then ModalResult := mrOk;
end;

procedure TfrTemplForm.FormDeactivate(Sender: TObject);
begin
  DefaultTemplate := false;
  if ModalResult = mrOk then
  begin
    if LB1.Items.Objects[LB1.ItemIndex]=self then
      DefaultTemplate := true
    else
      if FileExistsUTF8(FTemplatePath + LB1.Items[LB1.ItemIndex] + '.lrt') then
        TemplName := FTemplatePath + LB1.Items[LB1.ItemIndex] + '.lrt'
      else
        TemplName := FTemplatePath + LB1.Items[LB1.ItemIndex] + '.frt';
  end;
end;

procedure TfrTemplForm.FormCreate(Sender: TObject);
begin
  Caption := sTemplFormNewRp;
  GroupBox1.Caption := sTemplFormDesc;

  if frTemplateDir = '' then
    FTemplatePath := ''
  else
    FTemplatePath := AppendPathDelim(frTemplateDir);
end;

end.

