{ Copyright (C) <2005> <Andrew Haines> chmspecialparser.pas

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
{
  See the file COPYING.LCL, included in this distribution,
  for details about the copyright.
}
unit ChmSpecialParser;

{$mode objfpc}{$H+}
//{$INLINING ON}

interface

uses
  Classes, Forms, SysUtils, Controls, ComCtrls;
  
type

  TContentTreeNode = class(TTreeNode)
  private
    fUrl: String;
  public
    property Url:String read fUrl write fUrl;
  end;
  
  TContentNode = record
    Name: String;
    Url: String;
    LineCount: Integer;
  end;
  
  TIndexItem = class(TListITem)
  private
    fUrl: String;
  public
    property Url:String read fUrl write fUrl;
  end;
  
  
  { TContentsFiller }

  TContentsFiller = class(TObject)
  private
    fTreeView: TTreeView;
    fStream: TStream;
    fText: TStringList;
    fBranchCount: DWord;
    fStop: PBoolean;
    procedure CustomCreateContentTreeItem(Sender: TCustomTreeView;
      var ATreeNode: TTreenode);
    function AddULTree(StartLine, EndLine: Integer; ParentNode: TTreeNode): Boolean;
    function GetULEnd(StartLine: Integer): Integer;
    function GetLIData(StartLine: Integer): TContentNode;
  public
    constructor Create(ATreeView: TTreeView; AStream: TStream; StopBoolean: PBoolean);
    procedure DoFill; //inline;
    

  end;
  
  { TIndexFiller }

  TIndexFiller = class(TObject)
  private
    fListView: TListView;
    fStream: TStream;
    fText: TStringList;
    function GetLIEnd(StartLine: Integer): Integer;
    function GetNextLI(StartLine: Integer): Integer;
    function AddLIObjects(StartLine: Integer): Integer;
    function LineHasLI(ALine: Integer): Boolean;
  public
    constructor Create(AListView: TListView; AStream: TStream);
    procedure DoFill;

  end;

implementation

function FixURL(URL: String):String;
var
  X: LongInt;
begin
  X := Pos('%20', Url);
  while X > 0 do begin
    Delete(Url, X, 3);
    Insert(' ', Url, X);
    X := Pos('%20', Url);
  end;
  Result := Url;
end;

{ TContentsFiller }

procedure TContentsFiller.CustomCreateContentTreeItem(Sender: TCustomTreeView;
  var ATreeNode: TTreenode);
begin
  ATreeNode := TContentTreeNode.Create(TTreeView(Sender).Items);
end;

function TContentsFiller.AddULTree(StartLine, EndLine: Integer; ParentNode: TTreeNode): Boolean;
var
  X: LongInt;
  TreeNode: TContentTreeNode = nil;
  NodeInfo: TContentNode;
  ULEnd: Integer;
begin
  Result := True;
  Inc(fBranchCount);
  for X := StartLine to EndLine do begin
    if Pos('<LI>', fText.Strings[X]) > 0 then begin
      NodeInfo := GetLIData(X);
      TreeNode := TContentTreeNode(fTreeView.Items.AddChild(ParentNode, NodeInfo.Name));
      TreeNode.Url := NodeInfo.Url;
      Inc(PInteger(@X)^, NodeInfo.LineCount); // >:D
    end;
    if (X <> StartLine) and (Pos('<UL>', fText.Strings[X]) > 0) then begin
      ULEnd := GetULEnd(X);
      if not AddULTree(X, ULEnd, TreeNode) then exit(False);
      Inc(PInteger(@X)^, ULEnd-X); // >:D
    end;
  end;
  if fBranchCount mod 200 = 0 then begin
    Application.ProcessMessages;
    if fStop^ = True then Exit(False);
  end;
end;

function TContentsFiller.GetULEnd(StartLine: Integer): Integer;
var
ULDepth: Integer = 0;
X: LongInt;
begin
  for X := StartLine to fText.Count-1 do begin
    if Pos('<UL>', fText.Strings[X]) > 0 then Inc(ULDepth);
    if Pos('</UL>', fText.Strings[X]) > 0 then Dec(ULDepth);
    if ULDepth = 0 then begin
      Result := X;
      Exit;
    end;
  end;

end;

function TContentsFiller.GetLIData(StartLine: Integer): TContentNode;
var
 X: Integer;
 NameCount: Integer = 0;
 fLength: Integer;
 fPos: Integer;
 Line: String;
begin
  FillChar(Result, SizeOf(Result), 0);
  for X := StartLine to fText.Count-1 do begin
    Line := fText.Strings[X];
    fPos := Pos('<param name="name" value="', LowerCase(Line));
    if fPos > 0 then begin
      fLength := Length('<param name="name" value="');
      Result.Name := Copy(Line, fPos+fLength, Length(Line)-(fLength+fPos));
      Result.Name := Copy(Result.Name, 1, Pos('"', Result.Name)-1);
    end
    else begin
      fPos := Pos('<param name="local" value="', LowerCase(Line));
      if fPos > 0 then begin
        fLength := Length('<param name="local" value="');
        Result.Url := Copy(Line, fPos+fLength, Length(Line)-(fLength+fPos));
        Result.Url := '/'+Copy(Result.Url, 1, Pos('"', Result.Url)-1);
      end
      else if Pos('</OBJECT>', UpperCase(Line)) > 0 then begin
        Result.LineCount := X-StartLine;
        Break;
      end;
    end;
  end;
  Result.Url := FixURL(Result.Url);
end;


constructor TContentsFiller.Create(ATreeView: TTreeView; AStream: TStream; StopBoolean: PBoolean);
begin
  inherited Create;
  fTreeView := ATreeView;
  fStream := AStream;
  fStop := StopBoolean;
end;

procedure TContentsFiller.DoFill;
var
 OrigEvent: TTVCustomCreateNodeEvent;
 X: Integer;
begin
  OrigEvent := fTreeView.OnCustomCreateItem;
  fTreeView.OnCustomCreateItem := @CustomCreateContentTreeItem;
  
  fText := TStringList.Create;
  //TMemoryStream(fStream).SaveToFile('/tmp/contents.txt');
  fStream.Position := 0;
  fTreeView.BeginUpdate;
  fTreeView.Items.Clear;
  fText.LoadFromStream(fStream);
  for X := 0 to fText.Count-1 do begin
    if Pos('<UL>', UpperCase(fText.Strings[X])) > 0 then begin
      if not AddULTree(X, GetULEnd(X), nil) then begin
      //then we have either closed the file or are exiting the program
        fTreeView.Items.Clear;
      end;
      Break;
    end;
  end;
  fTreeView.OnCustomCreateItem := OrigEvent;
  fText.Free;
  fTreeView.EndUpdate;

end;

{ TIndexFiller }

function TIndexFiller.GetLIEnd(StartLine: Integer): Integer;
begin
//  for X := StartLine to
end;

function TIndexFiller.GetNextLI(StartLine: Integer): Integer;
begin

end;

function TIndexFiller.AddLIObjects(StartLine: Integer): Integer;
var
  NeedsUrl: Boolean = True;
  NeedsName: Boolean = True;
  ItemNAme: String;
  ItemUrl: String;
  Line: String;
  fPos: Integer;
  fLength: Integer;
  Item: TIndexItem;
  X: LongInt;
begin
  for X:= StartLine to fText.Count-1 do begin
    Line := fText.Strings[X];
    if NeedsName then begin
      fPos := Pos('<param name="name" value="', LowerCase(Line));
      if fPos > 0 then begin
        fLength := Length('<param name="name" value="');
        ItemName := Copy(Line, fPos+fLength, Length(Line)-(fLength+fPos));
        ItemName := Copy(ItemNAme, 1, Pos('"', ItemName)-1);
        NeedsName := False;
        NeedsUrl := True;
      end;
    end
    else if NeedsUrl then begin
      fPos := Pos('<param name="local" value="', LowerCase(Line));
      if fPos > 0 then begin
        fLength := Length('<param name="Local" value="');
        ItemUrl := Copy(Line, fPos+fLength, Length(Line)-(fLength+fPos));
        ItemUrl := FixUrl('/'+Copy(ItemUrl, 1, Pos('"', ItemUrl)-1));
        NeedsName := False;
        NeedsUrl := False;
        Item := TIndexItem.Create(fListView.Items);
        fListView.Items.AddItem(Item);
        Item.Caption := ItemName;
        Item.Url := ItemUrl;
        //WriteLn('Added IndexItem. Caption = ', ItemName,' Url = ',ItemUrl);
        ItemName := '';
        ItemUrl := '';
      end;
    end;
    if Pos('</OBJECT>', UpperCase(Line)) > 0 then begin
      Result := X-StartLine;
      Break;
    end;
  end;

end;

function TIndexFiller.LineHasLI(ALine: Integer): Boolean;
begin
  Result := Pos('<LI>', UpperCase(fText.Strings[ALine])) > 0;
end;

constructor TIndexFiller.Create(AListView: TListView; AStream: TStream);
begin
 inherited Create;
 fListView := AListView;
 fStream := AStream;
end;

procedure TIndexFiller.DoFill;
var
  X: Integer;
begin
  //TMemoryStream(fStream).SaveToFile('/tmp/index.txt');
  fStream.Position := 0;
  fText := TStringList.Create;
  fText.LoadFromStream(fStream);
  fListView.BeginUpdate;
  fListView.Items.Clear;
  for X := 0 to fText.Count-1 do begin
    if LineHasLI(X) then Inc(PInteger(@X)^, AddLIObjects(X));
  end;
  fText.Free;
  fListView.EndUpdate;
end;

end.

