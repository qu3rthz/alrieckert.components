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
    Functions and classes to build dependency graphs for pascal units.
}
unit CTUnitGraph;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, AVL_Tree, FileProcs, FindDeclarationTool, CodeBeautifier,
  CodeGraph, CodeCache, StdCodeTools, DirectoryCacher, LinkScanner,
  CustomCodeTool, CodeTree, CodeAtom;

type

  { TFindIdentifierReferenceCache }

  TFindIdentifierReferenceCache = class
  public
    IdentifierCode: TCodeBuffer;
    X, Y: integer;

    SourcesChangeStep: int64;
    FilesChangeStep: int64;
    InitValuesChangeStep: integer;
    NewTool: TFindDeclarationTool;
    NewNode: TCodeTreeNode;
    NewPos: TCodeXYPosition;
    IsPrivate: boolean;
    procedure Clear;
  end;

type
  TUGUnitFlag = (
    ugufReached,
    ugufLoadError,
    ugufIsIncludeFile,
    ugufHasSyntaxErrors
    );
  TUGUnitFlags = set of TUGUnitFlag;

  { TUGUnit }

  TUGUnit = class
  public
    Flags: TUGUnitFlags;
    TheUnitName: string;
    Filename: string;
    Code: TCodeBuffer;
    Tool: TStandardCodeTool;
    UsesUnits: TFPList; // list of TUGUses
    UsedByUnits: TFPList; // list of TUGUses
    constructor Create(const aFilename: string);
    destructor Destroy; override;
    procedure Clear;
    function IndexOfUses(const aFilename: string): integer;
  end;

  { TUGUses }

  TUGUses = class
  public
    Owner: TUGUnit;
    UsesUnit: TUGUnit;
    InImplementation: boolean;
    constructor Create(TheOwner, TheUses: TUGUnit);
    destructor Destroy; override;
  end;

  { TUsesGraph }

  TUsesGraph = class
  private
    FFiles: TAVLTree; // tree of TUGUnit sorted for Filename
    FStartFiles: TAVLTree; // tree of TUGUnit sorted for Filename
    FTargetFiles: TAVLTree; // tree of TUGUnit sorted for Filename
    FTargetDirsValid: boolean;
    FTargetDirs: string;
    FTargetInFPCSrc: boolean;
  public
    DirectoryCachePool: TCTDirectoryCachePool;
    OnGetCodeToolForBuffer: TOnGetCodeToolForBuffer;
    OnLoadFile: TOnLoadCTFile;

    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure ConsistencyCheck;
    function GetUnit(const ExpFilename: string; CreateIfNotExists: boolean): TUGUnit;

    procedure AddStartUnit(ExpFilename: string);
    procedure AddTargetUnit(ExpFilename: string);
    function Parse(IgnoreErrors: boolean; out Complete: boolean;
                   StopAfterMs: integer = -1): boolean;
    function GetUnitsTreeUsingTargets: TAVLTree; // tree of TUGUnit sorted for filename
    function GetCodeTreeUsingTargets: TAVLTree; // tree of TCodeBuffer sorted for filename
    function UnitCanFindTarget(ExpFilename: string): boolean;
    function IsTargetDir(ExpDir: string): boolean;

    property FilesTree: TAVLTree read FFiles;
    property StartFilesTree: TAVLTree read FStartFiles;
    property TargetFilesTree: TAVLTree read FTargetFiles;
  end;

function CompareUGUnitFilenames(UGUnit1, UGUnit2: Pointer): integer;
function CompareFilenameAndUGUnit(FileAnsistring, UGUnit: Pointer): integer;

implementation

function CompareUGUnitFilenames(UGUnit1, UGUnit2: Pointer): integer;
var
  Unit1: TUGUnit absolute UGUnit1;
  Unit2: TUGUnit absolute UGUnit2;
begin
  Result:=CompareFilenames(Unit1.Filename,Unit2.Filename);
end;

function CompareFilenameAndUGUnit(FileAnsistring, UGUnit: Pointer): integer;
var
  AnUnit: TUGUnit absolute UGUnit;
  Filename: String;
begin
  Filename:=AnsiString(FileAnsistring);
  Result:=CompareFilenames(Filename,AnUnit.Filename);
end;

{ TFindIdentifierReferenceCache }

procedure TFindIdentifierReferenceCache.Clear;
begin
  SourcesChangeStep:=CTInvalidChangeStamp64;
  FilesChangeStep:=CTInvalidChangeStamp64;
  InitValuesChangeStep:=CTInvalidChangeStamp;
  NewTool:=nil;
  NewNode:=nil;
  NewPos:=CleanCodeXYPosition;
  IsPrivate:=false;
end;

{ TUGUses }

constructor TUGUses.Create(TheOwner, TheUses: TUGUnit);
begin
  Owner:=TheOwner;
  UsesUnit:=TheUses;
end;

destructor TUGUses.Destroy;
begin
  if Owner<>nil then begin
    Owner.UsesUnits.Remove(Self);
    Owner:=nil;
  end;
  if UsesUnit<>nil then begin
    UsesUnit.UsedByUnits.Remove(Self);
    UsesUnit:=nil;
  end;
  inherited Destroy;
end;

{ TUGUnit }

constructor TUGUnit.Create(const aFilename: string);
begin
  Filename:=aFilename;
  TheUnitName:=ExtractFileNameOnly(Filename);
end;

destructor TUGUnit.Destroy;
begin
  Clear;
  FreeAndNil(UsesUnits);
  FreeAndNil(UsedByUnits);
  inherited Destroy;
end;

procedure TUGUnit.Clear;

  procedure FreeUsesList(var List: TFPList);
  begin
    if List=nil then exit;
    while List.Count>0 do TObject(List[0]).Free;
    FreeAndNil(List);
  end;

begin
  FreeUsesList(UsesUnits);
  FreeUsesList(UsedByUnits);
  Flags:=Flags-[ugufHasSyntaxErrors,ugufReached];
end;

function TUGUnit.IndexOfUses(const aFilename: string): integer;
begin
  if UsesUnits=nil then exit(-1);
  Result:=UsesUnits.Count-1;
  while (Result>=0)
  and (CompareFilenames(aFilename,TUGUses(UsesUnits[Result]).UsesUnit.Filename)<>0) do
    dec(Result);
end;

{ TUsesGraph }

constructor TUsesGraph.Create;
begin
  FFiles:=TAVLTree.Create(@CompareUGUnitFilenames);
  FStartFiles:=TAVLTree.Create(@CompareUGUnitFilenames);
  FTargetFiles:=TAVLTree.Create(@CompareUGUnitFilenames);
end;

destructor TUsesGraph.Destroy;
begin
  Clear;
  FreeAndNil(FStartFiles);
  FreeAndNil(FTargetFiles);
  FreeAndNil(FFiles);
  inherited Destroy;
end;

procedure TUsesGraph.Clear;
begin
  FStartFiles.Clear; // all files of StartFiles are in Files too
  FTargetFiles.Clear; // all files of TargetFiles are in Files too
  FFiles.FreeAndClear;
end;

procedure TUsesGraph.ConsistencyCheck;
var
  AVLNode: TAVLTreeNode;
  AnUnit: TUGUnit;
begin
  if FFiles.ConsistencyCheck<>0 then
    raise Exception.Create('FFiles.ConsistencyCheck');
  if FStartFiles.ConsistencyCheck<>0 then
    raise Exception.Create('FStartFiles.ConsistencyCheck');

  AVLNode:=FStartFiles.FindLowest;
  while AVLNode<>nil do begin
    AnUnit:=TUGUnit(AVLNode.Data);
    if AnUnit.Filename='' then
      raise Exception.Create('AnUnit without filename');
    if FFiles.FindKey(PChar(AnUnit.Filename),@CompareFilenameAndUGUnit)=nil then
      raise Exception.Create('startfile not in files: '+AnUnit.Filename);
    AVLNode:=FStartFiles.FindSuccessor(AVLNode);
  end;
end;

function TUsesGraph.GetUnit(const ExpFilename: string;
  CreateIfNotExists: boolean): TUGUnit;
var
  AVLNode: TAVLTreeNode;
begin
  if ExpFilename='' then begin
    Result:=nil;
    if CreateIfNotExists then
      raise Exception.Create('TUsesGraph.GetUnit missing filename');
    exit;
  end;
  AVLNode:=FFiles.FindKey(PChar(ExpFilename),@CompareFilenameAndUGUnit);
  if AVLNode<>nil then begin
    Result:=TUGUnit(AVLNode.Data);
  end else if CreateIfNotExists then begin
    Result:=TUGUnit.Create(ExpFilename);
    FFiles.Add(Result);
  end else
    Result:=nil;
end;

procedure TUsesGraph.AddStartUnit(ExpFilename: string);
var
  NewUnit: TUGUnit;
begin
  if ExpFilename='' then exit;
  if FStartFiles.FindKey(PChar(ExpFilename),@CompareFilenameAndUGUnit)<>nil then
    exit; // already a start file
  NewUnit:=GetUnit(ExpFilename,true);
  if ugufReached in NewUnit.Flags then exit; // already parsed
  // add to FFiles and FStartFiles
  //debugln(['TUsesGraph.AddStartUnit ',ExpFilename]);
  FStartFiles.Add(NewUnit);
end;

procedure TUsesGraph.AddTargetUnit(ExpFilename: string);
begin
  if ExpFilename='' then exit;
  if FStartFiles.FindKey(PChar(ExpFilename),@CompareFilenameAndUGUnit)<>nil then
    exit; // already a start file
  // add to FFiles and FTargetFiles
  //debugln(['TUsesGraph.AddTargetUnit ',ExpFilename]);
  FTargetFiles.Add(GetUnit(ExpFilename,true));
  FTargetDirsValid:=false;
end;

function TUsesGraph.Parse(IgnoreErrors: boolean; out Complete: boolean;
  StopAfterMs: integer): boolean;

  procedure AddUses(CurUnit: TUGUnit; UsedFiles: TStrings;
    InImplementation: boolean);
  var
    i: Integer;
    Filename: string;
    NewUnit: TUGUnit;
    NewUses: TUGUses;
  begin
    if UsedFiles=nil then exit;
    for i:=0 to UsedFiles.Count-1 do begin
      Filename:=UsedFiles[i];
      // check if already used
      if CurUnit.IndexOfUses(Filename)>=0 then continue;
      // add connection
      NewUnit:=GetUnit(Filename,true);
      if CurUnit.UsesUnits=nil then
        CurUnit.UsesUnits:=TFPList.Create;
      NewUses:=TUGUses.Create(CurUnit,NewUnit);
      NewUses.InImplementation:=InImplementation;
      CurUnit.UsesUnits.Add(NewUses);
      if NewUnit.UsedByUnits=nil then
        NewUnit.UsedByUnits:=TFPList.Create;
      NewUnit.UsedByUnits.Add(NewUses);
      // put new file on queue
      if UnitCanFindTarget(Filename) then
        AddStartUnit(Filename);
    end;
  end;

  function ParseUnit(CurUnit: TUGUnit): boolean;
  // returns true to continue
  var
    Abort: boolean;
    MainUsesSection: TStrings;
    ImplementationUsesSection: TStrings;
  begin
    Result:=false;
    Include(CurUnit.Flags,ugufLoadError);
    // load file
    Abort:=false;
    OnLoadFile(Self,CurUnit.Filename,CurUnit.Code,Abort);
    if Abort then exit;
    if CurUnit.Code=nil then begin
      debugln(['TUsesGraph.Parse failed loading file ',CurUnit.Filename]);
      Result:=IgnoreErrors;
      exit;
    end;
    try
      MainUsesSection:=nil;
      ImplementationUsesSection:=nil;
      try
        // create tool
        CurUnit.Tool:=OnGetCodeToolForBuffer(Self,CurUnit.Code,true) as TStandardCodeTool;
        if CurUnit.Tool=nil then begin
          debugln(['TUsesGraph.Parse failed getting tool for file ',CurUnit.Code.Filename]);
          Result:=IgnoreErrors;
          exit;
        end;
        // check if include file
        if CompareFilenames(CurUnit.Tool.MainFilename,CurUnit.Code.Filename)<>0 then
        begin
          Include(CurUnit.Flags,ugufIsIncludeFile);
          exit(true);
        end;
        Exclude(CurUnit.Flags,ugufLoadError);
        // parse both uses sections
        Include(CurUnit.Flags,ugufHasSyntaxErrors);
        CurUnit.Tool.BuildTree(lsrImplementationUsesSectionEnd);
        Exclude(CurUnit.Flags,ugufHasSyntaxErrors);
        // locate used units
        if not CurUnit.Tool.FindUsedUnitFiles(MainUsesSection,
                                              ImplementationUsesSection)
        then begin
          Result:=IgnoreErrors;
          exit;
        end;
        AddUses(CurUnit,MainUsesSection,false);
        AddUses(CurUnit,ImplementationUsesSection,true);
        Result:=true;
      finally
        MainUsesSection.Free;
        ImplementationUsesSection.Free;
      end;
    except
      on E: ECodeToolError do begin
        if not IgnoreErrors then raise;
      end;
      on E: ELinkScannerError do begin
        if not IgnoreErrors then raise;
      end;
    end;
  end;

var
  StartTime: TDateTime;
  AVLNode: TAVLTreeNode;
  CurUnit: TUGUnit;
begin
  Result:=false;
  Complete:=false;
  if StopAfterMs>=0 then
    StartTime:=Now
  else
    StartTime:=0;
  while FStartFiles.Count>0 do begin
    AVLNode:=FStartFiles.FindLowest;
    CurUnit:=TUGUnit(AVLNode.Data);
    FStartFiles.Delete(AVLNode);
    Include(CurUnit.Flags,ugufReached);
    //debugln(['TUsesGraph.Parse Unit=',CurUnit.Filename]);
    if UnitCanFindTarget(CurUnit.Filename) then begin
      if not ParseUnit(CurUnit) then exit;
    end;

    if (StopAfterMs>=0) and (Abs(Now-StartTime)*86400000>=StopAfterMs) then
      exit(true);
  end;

  Complete:=true;
  Result:=true;
end;

function TUsesGraph.GetUnitsTreeUsingTargets: TAVLTree;

  procedure Add(Units: TAVLTree; NewUnit: TUGUnit);
  var
    i: Integer;
    CurUses: TUGUses;
  begin
    if NewUnit=nil then exit;
    if not (ugufReached in NewUnit.Flags) then exit; // this unit was not reached
    if ugufIsIncludeFile in NewUnit.Flags then exit;
    if Units.Find(NewUnit)<>nil then exit; // already added
    Units.Add(NewUnit);
    if NewUnit.UsedByUnits=nil then exit;
    for i:=0 to NewUnit.UsedByUnits.Count-1 do begin
      CurUses:=TUGUses(NewUnit.UsedByUnits[i]);
      Add(Units,CurUses.Owner);
    end;
  end;

var
  AVLNode: TAVLTreeNode;
begin
  Result:=TAVLTree.Create(@CompareUGUnitFilenames);
  AVLNode:=FTargetFiles.FindLowest;
  while AVLNode<>nil do begin
    Add(Result,TUGUnit(AVLNode.Data));
    AVLNode:=FTargetFiles.FindSuccessor(AVLNode);
  end;
end;

function TUsesGraph.GetCodeTreeUsingTargets: TAVLTree;
var
  Units: TAVLTree;
  AVLNode: TAVLTreeNode;
  CurUnit: TUGUnit;
begin
  Result:=TAVLTree.Create(@CompareCodeBuffers);
  Units:=GetUnitsTreeUsingTargets;
  try
    AVLNode:=Units.FindLowest;
    while AVLNode<>nil do begin
      CurUnit:=TUGUnit(AVLNode.Data);
      if not (ugufIsIncludeFile in CurUnit.Flags)
      and (Result.Find(CurUnit.Code)=nil) then
        Result.Add(CurUnit.Code);
      AVLNode:=Units.FindSuccessor(AVLNode);
    end;
  finally
    Units.Free;
  end;
end;

function TUsesGraph.UnitCanFindTarget(ExpFilename: string): boolean;
// returns true if units search path allows finding a target unit
var
  BaseDir: String;
  SrcPath: String;
  p: integer;
  ReachableDir: String;
begin
  Result:=true;
  if FTargetInFPCSrc then exit; // standard units can always be found

  BaseDir:=ExtractFilePath(ExpFilename);
  if IsTargetDir(BaseDir) then exit;

  // check complete search path, including SrcPath, UnitPath
  // and resolved compiled unit paths
  SrcPath:=DirectoryCachePool.GetString(BaseDir,ctdcsCompleteSrcPath);
  p:=1;
  repeat
    ReachableDir:=GetNextDelimitedItem(SrcPath,';',p);
    if ReachableDir<>'' then begin
      if not FilenameIsAbsolute(ReachableDir) then
        ReachableDir:=BaseDir+ReachableDir;
      if IsTargetDir(ReachableDir) then exit;
    end;
  until p>length(SrcPath);

  Result:=false;
end;

function TUsesGraph.IsTargetDir(ExpDir: string): boolean;
var
  AVLNode: TAVLTreeNode;
  CurUnit: TUGUnit;
  Dir: String;
  p: Integer;
  TargetDir: String;
begin
  if FTargetFiles.Count=0 then exit(false);

  if not FTargetDirsValid then begin
    FTargetDirsValid:=true;
    FTargetInFPCSrc:=false;
    // build list of target directories for quick lookup
    AVLNode:=FTargetFiles.FindLowest;
    while AVLNode<>nil do begin
      CurUnit:=TUGUnit(AVLNode.Data);
      Dir:=ExtractFilePath(CurUnit.Filename);
      if FilenameIsAbsolute(Dir)
      and (CompareFilenames(DirectoryCachePool.FindUnitInUnitSet(Dir,CurUnit.TheUnitName),
             CurUnit.Filename)=0)
      then begin
        // this is a standard unit (e.g. in FPC sources)
        // they are not reachable via search paths, but via the UnitSet
        FTargetInFPCSrc:=true;
      end else if Dir='' then begin
        // in virtual directory
        if (FTargetDirs='') or (FTargetDirs[1]<>';') then
          FTargetDirs:=';'+FTargetDirs;
      end else if not FileIsInPath(Dir,FTargetDirs) then begin
        // normal source directory
        if FTargetDirs='' then
          FTargetDirs:=Dir
        else
          FTargetDirs:=FTargetDirs+';'+Dir;
      end;
      AVLNode:=FTargetFiles.FindSuccessor(AVLNode);
    end;
  end;

  Result:=true;
  if (ExpDir='') and (FTargetDirs[1]=';') then exit;
  p:=1;
  repeat
    TargetDir:=GetNextDelimitedItem(FTargetDirs,';',p);
    if TargetDir<>'' then begin
      if CompareFilenames(TargetDir,ExpDir)=0 then exit;
    end;
  until p>length(FTargetDirs);
  Result:=false;
end;

end.

