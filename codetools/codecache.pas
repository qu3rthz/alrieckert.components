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
    TCodeCache is an AVL Tree of TCodeBuffer. It can load and save files.
    
    TCodeBuffer is an descendent of TSourceLog and manages a single file.
    
  ToDo:
}
unit CodeCache;

{$ifdef fpc}{$mode objfpc}{$endif}{$H+}

interface

{$I codetools.inc}

uses
  {$IFDEF MEM_CHECK}
  MemCheck,
  {$ENDIF}
  Classes, SysUtils, SourceLog, LinkScanner, AVL_Tree, FileProcs, Laz_XMLCfg;

type
  TCodeCache = class;

  TCodeBuffer = class(TSourceLog)
  private
    FFilename: string;
    FScanner: TLinkScanner;
    FOnSetScanner: TNotifyEvent;
    FOnSetFilename: TNotifyEvent;
    FFileDateValid: boolean;
    FFileChangeStep: integer;
    FFileDate: longint;
    FLastIncludedByFile: string;
    FCodeCache: TCodeCache;
    FIsVirtual: boolean;
    FIsDeleted: boolean;
    function GetLastIncludedByFile: string;
    procedure SetFilename(Value: string);
    procedure SetScanner(const Value: TLinkScanner);
    procedure SetIsDeleted(const NewValue: boolean);
    procedure MakeFileDateValid;
  public
    property Scanner: TLinkScanner read FScanner write SetScanner;
    property LastIncludedByFile: string
          read GetLastIncludedByFile write FLastIncludedByFile;
    property Filename: string read FFilename write SetFilename;
    function LoadFromFile(const AFilename: string): boolean; override;
    function Reload: boolean; // = LoadFromFile(Filename)
    function Revert: boolean; // ignore changes and reload source
    function SaveToFile(const AFilename: string): boolean; override;
    function Save: boolean;
    property FileDateValid: boolean read FFileDateValid;
    property FileDate: longint read FFileDate;
    function FileDateOnDisk: longint;
    function FileNeedsUpdate: boolean;
    function FileOnDiskNeedsUpdate: boolean;
    function FileOnDiskHasChanged: boolean;
    property OnSetScanner: TNotifyEvent read FOnSetScanner write FOnSetScanner;
    property OnSetFilename: TNotifyEvent read FOnSetFilename write FOnSetFilename;
    property IsVirtual: boolean read FIsVirtual;
    property IsDeleted: boolean read FIsDeleted write SetIsDeleted;
    property CodeCache: TCodeCache read FCodeCache write FCodeCache;
    constructor Create;
    destructor Destroy;  override;
    function ConsistencyCheck: integer; // 0 = ok
    procedure WriteDebugReport;
  end;
  
  TIncludedByLink = class
  public
    IncludeFilename: string;
    IncludedByFile: string;
    LastTimeUsed: TDateTime;
    constructor Create(const AnIncludeFilename,AnIncludedByFile: string;
       ALastTimeUsed: TDateTime);
  end;

  TCodeCache = class(TObject)
  private
    FItems: TAVLTree;  // tree of TCodeBuffer
    FIncludeLinks: TAVLTree; // tree of TIncludedByLink
    FExpirationTimeInDays: integer;
    function OnScannerGetSource(Sender: TObject; Code: pointer): TSourceLog;
    function OnScannerLoadSource(Sender: TObject; const AFilename: string): pointer;
    function OnScannerGetFileName(Sender: TObject; Code: pointer): string;
    function OnScannerCheckFileOnDisk(Code: pointer): boolean;
    procedure OnScannerIncludeCode(ParentCode, IncludeCode: pointer);
    procedure OnScannerGetSourceStatus(Sender: TObject; Code:Pointer;
                 var ReadOnly: boolean);
    procedure OnScannerDeleteSource(Sender: TObject; Code: Pointer;
                 Pos, Len: integer);
    function FindIncludeLinkNode(const IncludeFilename: string): TIncludedByLink;
    function FindIncludeLink(const IncludeFilename: string): string;
    procedure UpdateIncludeLinks;
  public
    function Count: integer;
    function FindFile(AFilename: string): TCodeBuffer;
    function LoadFile(const AFilename: string): TCodeBuffer;
    function CreateFile(const AFilename: string): TCodeBuffer;
    function SaveBufferAs(OldBuffer: TCodeBuffer; const AFilename: string;
          var NewBuffer: TCodeBuffer): boolean;
    function LastIncludedByFile(const IncludeFilename: string): string;
    function SaveIncludeLinksToFile(const AFilename: string): boolean;
    function LoadIncludeLinksFromFile(const AFilename: string): boolean;
    function SaveIncludeLinksToXML(XMLConfig: TXMLConfig;
          const XMLPath: string): boolean;
    function LoadIncludeLinksFromXML(XMLConfig: TXMLConfig;
          const XMLPath: string): boolean;
    property ExpirationTimeInDays: integer
          read FExpirationTimeInDays write FExpirationTimeInDays;
    procedure Clear;
    procedure ClearAllSourleLogEntries;
    constructor Create;
    destructor Destroy;  override;
    procedure OnBufferSetScanner(Sender: TCodeBuffer);
    procedure OnBufferSetFileName(Sender: TCodeBuffer; 
          const OldFilename: string);
    function ConsistencyCheck: integer; // 0 = ok
    procedure WriteDebugReport;
    procedure WriteAllFileNames;
  end;


implementation


function CompareCodeBuffers(NodeData1, NodeData2: pointer): integer;
var CodeBuf1, CodeBuf2: TCodeBuffer;
begin
  CodeBuf1:=TCodeBuffer(NodeData1);
  CodeBuf2:=TCodeBuffer(NodeData2);
  Result:=CompareFilenames(CodeBuf1.Filename,CodeBuf2.Filename);
end;

function CompareIncludedByLink(NodeData1, NodeData2: pointer): integer;
var Link1, Link2: TIncludedByLink;
begin
  Link1:=TIncludedByLink(NodeData1);
  Link2:=TIncludedByLink(NodeData2);
  Result:=CompareFilenames(Link1.IncludeFilename,Link2.IncludeFilename);
end;


{ TCodeCache }

procedure TCodeCache.Clear;
begin
  FItems.FreeAndClear;
end;

procedure TCodeCache.ClearAllSourleLogEntries;
var
  ANode: TAVLTreeNode;
begin
  ANode:=FItems.FindLowest;
  while ANode<>nil do begin
    TCodeBuffer(ANode.Data).ClearEntries;
    ANode:=FItems.FindSuccessor(ANode);
  end;
end;

function TCodeCache.Count: integer;
begin
  Result:=FItems.Count;
end;

constructor TCodeCache.Create;
begin
  inherited Create;
  FItems:=TAVLTree.Create(@CompareCodeBuffers);
  FIncludeLinks:=TAVLTree.Create(@CompareIncludedByLink);
end;

destructor TCodeCache.Destroy;
begin
  Clear;
  FIncludeLinks.FreeAndClear;
  FIncludeLinks.Free;
  FItems.Free;
  inherited Destroy;
end;

function TCodeCache.FindFile(AFilename: string): TCodeBuffer;
var c: integer;
  ANode: TAVLTreeNode;
begin
  AFilename:=TrimFilename(AFilename);
  ANode:=FItems.Root;
  while ANode<>nil do begin
    Result:=TCodeBuffer(ANode.Data);
    c:=CompareFilenames(AFilename,Result.Filename);
    {$IFDEF CTDEBUG}
    if c=0 then writeln(' File found !!! ',Result.Filename);
    {$ENDIF}
    if c<0 then ANode:=ANode.Left
    else if c>0 then ANode:=ANode.Right
    else exit;
  end;
  Result:=nil;
end;

function TCodeCache.LoadFile(const AFilename: string): TCodeBuffer;
// search file in cache
begin
  Result:=FindFile(AFilename);
  if Result=nil then begin
    // load new buffer
    Result:=TCodeBuffer.Create;
    Result.Filename:=AFilename;
    if (not FileExists(Result.Filename))
    or (not Result.LoadFromFile(Result.Filename)) then
    begin
      Result.Free;
      Result:=nil;
      exit;
    end;
    FItems.Add(Result);
    with Result do begin
      FCodeCache:=Self;
      LastIncludedByFile:=FindIncludeLink(Result.Filename);
      ReadOnly:=not FileIsWritable(Result.Filename);
    end;
  end else if Result.IsDeleted then begin
    // file in cache, but marked as deleted -> load from disk
    if (not FileExists(AFilename)) or (not Result.LoadFromFile(AFilename)) then
    begin
      Result:=nil;
      exit;
    end;
  end;
end;

function TCodeCache.CreateFile(const AFilename: string): TCodeBuffer;
begin
  Result:=FindFile(AFileName);
  if Result<>nil then begin
    Result.Source:='';
  end else begin
    Result:=TCodeBuffer.Create;
    Result.FileName:=AFileName;
    FItems.Add(Result);
    Result.FCodeCache:=Self;
    Result.LastIncludedByFile:=FindIncludeLink(Result.Filename);
  end;
end;

function TCodeCache.SaveBufferAs(OldBuffer: TCodeBuffer; 
  const AFilename: string; var NewBuffer: TCodeBuffer): boolean;
begin
//writeln('[TCodeCache.SaveBufferAs] ',OldBuffer.Filename,' ',AFilename);
  if (OldBuffer=nil) then begin
    NewBuffer:=nil;
    Result:=false;
    exit;
  end;
  if OldBuffer.Filename=AFilename then begin // do not use CompareFilenames() !
    NewBuffer:=OldBuffer;
    Result:=OldBuffer.Save;
    exit;
  end;
  NewBuffer:=FindFile(AFilename);
//writeln('[TCodeCache.SaveBufferAs] B ',NewBuffer=nil);
//WriteAllFileNames;
  if NewBuffer=nil then begin
    NewBuffer:=TCodeBuffer.Create;
    NewBuffer.FileName:=AFilename;
    NewBuffer.Source:=OldBuffer.Source;
    Result:=NewBuffer.Save;
//writeln('[TCodeCache.SaveBufferAs] C ',Result,' ',NewBuffer.IsVirtual);
    if not Result then begin
      NewBuffer.Free;
      NewBuffer:=nil;
      exit;
    end;
    FItems.Add(NewBuffer);
    NewBuffer.FCodeCache:=Self;
    NewBuffer.LastIncludedByFile:=FindIncludeLink(AFilename);
  end else begin
    NewBuffer.Source:=OldBuffer.Source;
    Result:=NewBuffer.Save;
  end;
  if not Result then exit;
  if (OldBuffer<>NewBuffer) then begin
    OldBuffer.IsDeleted:=true;
    OldBuffer.Source:='';
  end;
end;

function TCodeCache.LastIncludedByFile(const IncludeFilename: string): string;
var Code: TCodeBuffer;
begin
  Code:=FindFile(IncludeFilename);
  if Code<>nil then
    Result:=Code.LastIncludedByFile
  else begin
    Result:=FindIncludeLink(IncludeFilename);
  end;
end;

procedure TCodeCache.OnBufferSetScanner(Sender: TCodeBuffer);
begin
  with Sender do begin
    if Scanner<>nil then begin
      Scanner.OnGetSource:={$ifdef FPC}@{$endif}Self.OnScannerGetSource;
      Scanner.OnGetFileName:={$ifdef FPC}@{$endif}Self.OnScannerGetFileName;
      Scanner.OnLoadSource:={$ifdef FPC}@{$endif}Self.OnScannerLoadSource;
      Scanner.OnCheckFileOnDisk:=
          {$ifdef FPC}@{$endif}Self.OnScannerCheckFileOnDisk;
      Scanner.OnIncludeCode:={$ifdef FPC}@{$endif}Self.OnScannerIncludeCode;
      Scanner.OnGetSourceStatus:=
          {$ifdef FPC}@{$endif}Self.OnScannerGetSourceStatus;
      Scanner.OnDeleteSource:={$ifdef FPC}@{$endif}Self.OnScannerDeleteSource;
    end;
  end;
end;

procedure TCodeCache.OnBufferSetFileName(Sender: TCodeBuffer;
  const OldFilename: string);
begin
  FItems.Delete(FItems.Find(FindFile(OldFilename)));
  if FindFile(Sender.Filename)=nil then
    FItems.Add(Sender);
end;

function TCodeCache.OnScannerGetFileName(Sender: TObject;
  Code: pointer): string;
begin
  if (Code<>nil) then
    Result:=TCodeBuffer(Code).Filename
  else
    raise Exception.Create('[TCodeCache.OnScannerGetFilename] Code=nil');
end;

function TCodeCache.OnScannerGetSource(Sender: TObject;
  Code: pointer): TSourceLog;
begin
//writeln('[TCodeCache.OnScannerGetSource] A ',HexStr(Cardinal(Code),8),'/',Count);
  if (Code<>nil) then
    Result:=TSourceLog(Code)
  else
    raise Exception.Create('[TCodeCache.OnScannerGetFilename] Code=nil');
end;

function TCodeCache.OnScannerLoadSource(Sender: TObject;
  const AFilename: string): pointer;
begin
  Result:=LoadFile(AFilename);
end;

function TCodeCache.OnScannerCheckFileOnDisk(Code: pointer): boolean;
begin
  Result:=TCodeBuffer(Code).Reload;
end;

procedure TCodeCache.OnScannerIncludeCode(ParentCode, IncludeCode: pointer);
begin
  if (ParentCode<>nil) and (IncludeCode<>nil) and (ParentCode<>IncludeCode) then
    TCodeBuffer(IncludeCode).LastIncludedByFile:=
      TCodeBuffer(ParentCode).Filename;
end;

procedure TCodeCache.OnScannerGetSourceStatus(Sender: TObject; Code:Pointer;
  var ReadOnly: boolean);
begin
  ReadOnly:=TCodeBuffer(Code).ReadOnly;
end;

procedure TCodeCache.OnScannerDeleteSource(Sender: TObject; Code: Pointer;
  Pos, Len: integer);
begin
  TCodeBuffer(Code).Delete(Pos,Len);
end;

function TCodeCache.FindIncludeLinkNode(const IncludeFilename: string
  ): TIncludedByLink;
var
  ANode: TAVLTreeNode;
  cmp: integer;
begin
  ANode:=FIncludeLinks.Root;
  while ANode<>nil do begin
    Result:=TIncludedByLink(ANode.Data);
    cmp:=CompareFilenames(
            IncludeFilename,Result.IncludeFilename);
    if cmp<0 then ANode:=ANode.Left
    else if cmp>0 then ANode:=ANode.Right
    else begin
      exit;
    end;
  end;
  Result:=nil;
end;

function TCodeCache.FindIncludeLink(const IncludeFilename: string): string;
var Link: TIncludedByLink;
begin
  Link:=FindIncludeLinkNode(IncludeFilename);
  if Link<>nil then begin
    Result:=Link.IncludedByFile;
    if CompareFilenames(Result,IncludeFilename)=0 then Result:='';
  end else
    Result:='';
end;

procedure TCodeCache.UpdateIncludeLinks;
var CodeNode: TAVLTreeNode;
  IncludeNode: TIncludedByLink;
  Code: TCodeBuffer;
  CurrDate: TDateTime;
begin
  CodeNode:=FItems.FindLowest;
  CurrDate:=Date;
  while CodeNode<>nil do begin
    Code:=TCodeBuffer(CodeNode.Data);
    IncludeNode:=FindIncludeLinkNode(Code.Filename);
    if IncludeNode<>nil then begin
      // there is already an entry for this file -> update it
      IncludeNode.IncludedByFile:=Code.LastIncludedByFile;
    end else if Code.LastIncludedByFile<>'' then begin
      // there is no entry for this include file -> add one
      FIncludeLinks.Add(TIncludedByLink.Create(Code.Filename,
                        Code.LastIncludedByFile,CurrDate));
    end;
    CodeNode:=FItems.FindSuccessor(CodeNode);
  end;
end;

function TCodeCache.SaveIncludeLinksToFile(const AFilename: string): boolean;
var XMLConfig: TXMLConfig;
begin
  try
    XMLConfig:=TXMLConfig.Create(AFilename);
    try
      Result:=SaveIncludeLinksToXML(XMLConfig,'');
    finally
      XMLConfig.Free;
    end;
  except
    Result:=false;
  end;
end;

function TCodeCache.LoadIncludeLinksFromFile(const AFilename: string): boolean;
var XMLConfig: TXMLConfig;
begin
  try
    XMLConfig:=TXMLConfig.Create(AFilename);
    try
      Result:=LoadIncludeLinksFromXML(XMLConfig,'');
    finally
      XMLConfig.Free;
    end;
  except
    Result:=false;
  end;
end;

function TCodeCache.SaveIncludeLinksToXML(XMLConfig: TXMLConfig;
  const XMLPath: string): boolean;
var Index: integer;

  procedure SaveLinkTree(ANode: TAVLTreeNode);
  var ALink: TIncludedByLink;
    APath: string;
  begin
    if ANode=nil then exit;
    SaveLinkTree(ANode.Left);
    ALink:=TIncludedByLink(ANode.Data);
    APath:=XMLPath+'IncludeLinks/Link'+IntToStr(Index)+'/';
    XMLConfig.SetValue(APath+'IncludeFilename/Value',ALink.IncludeFilename);
    XMLConfig.SetValue(APath+'IncludedByFilename/Value',ALink.IncludedByFile);
    XMLConfig.SetValue(APath+'LastTimeUsed/Value',DateToStr(ALink.LastTimeUsed));
    inc(Index);
    SaveLinkTree(ANode.Right);
  end;

begin
  try
    UpdateIncludeLinks;
    XMLConfig.SetValue(XMLPath+'IncludeLinks/ExpirationTimeInDays',
        FExpirationTimeInDays);
    XMLConfig.SetValue(XMLPath+'IncludeLinks/Count',FIncludeLinks.Count);
    Index:=0;
    SaveLinkTree(FIncludeLinks.Root);
    Result:=true;
  except
    Result:=false;
  end;
end;

function TCodeCache.LoadIncludeLinksFromXML(XMLConfig: TXMLConfig;
  const XMLPath: string): boolean;
var LinkCnt, i: integer;
  LastTimeUsed, CurrDate: TDateTime;
  IncludeFilename, IncludedByFile, APath: string;
  NewLink: TIncludedByLink;
begin
  try
    FIncludeLinks.FreeAndClear;
    FExpirationTimeInDays:=XMLConfig.GetValue(
        XMLPath+'IncludeLinks/ExpirationTimeInDays',
        FExpirationTimeInDays);
    LinkCnt:=XMLConfig.GetValue(XMLPath+'IncludeLinks/Count',0);
    CurrDate:=Date;
    for i:=0 to LinkCnt-1 do begin
      APath:=XMLPath+'IncludeLinks/Link'+IntToStr(i)+'/';
      try
        LastTimeUsed:=StrToDate(XMLConfig.GetValue(APath+'LastTimeUsed/Value',
             DateToStr(CurrDate)));
      except
        LastTimeUsed:=CurrDate;
      end;
      
      // ToDo: check if link has expired
      
      IncludeFilename:=XMLConfig.GetValue(APath+'IncludeFilename/Value','');
      if IncludeFilename='' then continue;
      IncludedByFile:=XMLConfig.GetValue(APath+'IncludedByFilename/Value','');
      NewLink:=TIncludedByLink.Create(IncludeFilename,IncludedByFile,
                  LastTimeUsed);
      FIncludeLinks.Add(NewLink);
    end;
    Result:=true;
  except
    Result:=false;
  end;
end;

function TCodeCache.ConsistencyCheck: integer;
// 0 = ok
var ANode: TAVLTreeNode;
begin
  Result:=FItems.ConsistencyCheck;
  if Result<>0 then begin
    dec(Result,100);  exit;
  end;
  Result:=FIncludeLinks.ConsistencyCheck;
  if Result<>0 then begin
    dec(Result,200);  exit;
  end;
  ANode:=FItems.FindLowest;
  while ANode<>nil do begin
    if ANode.Data=nil then begin
      Result:=-1;
      exit;
    end;
    Result:=TCodeBuffer(ANode.Data).ConsistencyCheck;
    if Result<>0 then begin
      dec(Result,300);  exit;
    end;
    ANode:=FItems.FindSuccessor(ANode);
  end;
  ANode:=FIncludeLinks.FindLowest;
  while ANode<>nil do begin
    if ANode.Data=nil then begin
      Result:=-2;
      exit;
    end;
    ANode:=FIncludeLinks.FindSuccessor(ANode);
  end;
  Result:=0;
end;

procedure TCodeCache.WriteDebugReport;
begin
  writeln('[TCodeCache.WriteDebugReport] Consistency=',ConsistencyCheck);
  writeln(FItems.ReportAsString);
  writeln(FIncludeLinks.ReportAsString);
end;

procedure TCodeCache.WriteAllFileNames;
  procedure WriteNode(ANode: TAVLTreeNode);
  begin
    if ANode=nil then exit;
    WriteNode(ANode.Left);
    writeln('  ',TCodeBuffer(ANode.Data).Filename);
    WriteNode(ANode.Right);
  end;

begin
  writeln('TCodeCache.WriteAllFileNames: ',FItems.Count);
  WriteNode(FItems.Root);
end;

{ TCodeBuffer }

constructor TCodeBuffer.Create;
begin
  inherited Create('');
  FFilename:='';
  FLastIncludedByFile:='';
  FFileDateValid:=false;
  FIsVirtual:=true;
  FIsDeleted:=false;
end;

destructor TCodeBuffer.Destroy;
begin
  if Scanner<>nil then Scanner.Free;
  inherited Destroy;
end;

function TCodeBuffer.LoadFromFile(const AFilename: string): boolean;
begin
//writeln('[TCodeBuffer.LoadFromFile] WriteLock=',WriteLock,' ReadOnly=',ReadOnly,
//' IsVirtual=',IsVirtual,' Old="',Filename,'" ',CompareFilenames(AFilename,Filename));
  if (WriteLock>0) or (ReadOnly) then begin
    Result:=false;
    exit;
  end;
  if not IsVirtual then begin
    if CompareFilenames(AFilename,Filename)=0 then begin
//writeln('****** [TCodeBuffer.LoadFromFile] ',Filename,' FileDateValid=',FileDateValid,' ',FFileDate,',',FileAge(Filename),',',FFileChangeStep,',',ChangeStep,', NeedsUpdate=',FileNeedsUpdate);
      if FileNeedsUpdate then begin
        Result:=inherited LoadFromFile(AFilename);
        if Result then MakeFileDateValid;
      end else
        Result:=true;
      if FIsDeleted then FIsDeleted:=not Result;
    end else begin
      Result:=inherited LoadFromFile(AFilename);
      if Result then MakeFileDateValid;
    end;
  end else
    Result:=false;
end;

function TCodeBuffer.SaveToFile(const AFilename: string): boolean;
begin
  Result:=inherited SaveToFile(AFilename);
//writeln('TCodeBuffer.SaveToFile ',Filename,' -> ',AFilename,' ',Result);
  if CompareFilenames(AFilename,Filename)=0 then begin
    if FIsDeleted then FIsDeleted:=not Result;
    if Result then MakeFileDateValid;
  end;
end;

function TCodeBuffer.Reload: boolean;
begin
  Result:=LoadFromFile(Filename);
end;

function TCodeBuffer.Revert: boolean;
// ignore changes and reload source
begin
  if not IsVirtual then begin
    Result:=inherited LoadFromFile(Filename);
    if Result then MakeFileDateValid;
  end else
    Result:=false;
end;

function TCodeBuffer.Save: boolean;
begin
  if not IsVirtual then
    Result:=SaveToFile(Filename)
  else
    Result:=false;
end;

function TCodeBuffer.GetLastIncludedByFile: string;
begin
  Result:=FLastIncludedByFile;
  if Result=Filename then Result:='';
end;

procedure TCodeBuffer.SetFilename(Value: string);
var OldFilename: string;
begin
  Value:=TrimFilename(Value);
  if FFilename=Value then exit;
  OldFilename:=FFilename;
  FFilename := Value;
  FIsVirtual:=not FilenameIsAbsolute(Filename);
  if CompareFilenames(OldFileName,Value)<>0 then begin
    FFileDateValid:=false;
  end;
  FLastIncludedByFile:='';
  if FCodeCache<>nil then FCodeCache.OnBufferSetFilename(Self,OldFilename);
  if Assigned(FOnSetFilename) then FOnSetFilename(Self);
end;

procedure TCodeBuffer.SetScanner(const Value: TLinkScanner);
begin
  if FScanner=Value then exit;
  FScanner := Value;
  if Assigned(FOnSetScanner) then FOnSetScanner(Self);
  if FCodeCache<>nil then FCodeCache.OnBufferSetScanner(Self);
  if FScanner<>nil then
    FScanner.MainCode:=Self;
end;

procedure TCodeBuffer.SetIsDeleted(const NewValue: boolean);
begin
  if FIsDeleted=NewValue then exit;
  FIsDeleted:=NewValue;
  if FIsDeleted then begin
    Clear;
    FFileDateValid:=false;
    ReadOnly:=false;
  end;
end;

procedure TCodeBuffer.MakeFileDateValid;
begin
  FFileChangeStep:=ChangeStep;
  FFileDateValid:=true;
  FFileDate:=FileAge(Filename);
end;

function TCodeBuffer.FileDateOnDisk: longint;
begin
  Result:=FileAge(Filename);
end;

function TCodeBuffer.FileNeedsUpdate: boolean;
// file needs update, if file is not modified and file on disk is changed
begin
  if FileDateValid then
    Result:=(not Modified) and (FFileChangeStep=ChangeStep) 
             and (FileDateOnDisk>FileDate)
  else
    Result:=true;
end;

function TCodeBuffer.FileOnDiskNeedsUpdate: boolean;
// file on disk needs update, if file is modified
begin
  if FileDateValid then
    Result:=Modified or (FFileChangeStep<>ChangeStep) 
  else
    Result:=false;
end;

function TCodeBuffer.FileOnDiskHasChanged: boolean;
begin
  if FileDateValid then
    Result:=(FileDateOnDisk<>FileDate)
  else
    Result:=false;
end;

function TCodeBuffer.ConsistencyCheck: integer; // 0 = ok
begin
  if FScanner<>nil then begin
    Result:=FScanner.ConsistencyCheck;
  end;
  Result:=0;
end;

procedure TCodeBuffer.WriteDebugReport;
begin
  writeln('[TCodeBuffer.WriteDebugReport] Consistency=',ConsistencyCheck);
end;

{ TIncludedByLink }

constructor TIncludedByLink.Create(const AnIncludeFilename,
  AnIncludedByFile: string; ALastTimeUsed: TDateTime);
begin
  inherited Create;
  IncludeFilename:=AnIncludeFilename;
  IncludedByFile:=AnIncludedByFile;
  LastTimeUsed:=ALastTimeUsed;
end;


end.
 
