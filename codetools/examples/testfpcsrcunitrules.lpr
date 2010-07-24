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
    Write all duplicate ppu files and all duplicate unit source files.
}
program TestFPCSrcUnitRules;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, CustApp, AVL_Tree, CodeToolManager, DefineTemplates,
  FileProcs, CodeToolsStructs;

const
  ConfigFilename = 'codetools.config';
type

  { TTestFPCSourceUnitRules }

  TTestFPCSourceUnitRules = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
    procedure Error(Msg: string; DoWriteHelp: Boolean);
    procedure WriteCompilerInfo(ConfigCache: TFPCTargetConfigCache);
    procedure WriteDuplicatesInPPUPath(ConfigCache: TFPCTargetConfigCache);
    procedure WriteMissingPPUSources(UnitSet: TFPCUnitSetCache);
    procedure WriteDuplicateSources(UnitSet: TFPCUnitSetCache);
  end;

{ TMyApplication }

procedure TTestFPCSourceUnitRules.DoRun;
var
  ErrorMsg: String;
  CompilerFilename: String;
  TargetOS: String;
  TargetCPU: String;
  FPCSrcDir: String;
  UnitSet: TFPCUnitSetCache;
  ConfigCache: TFPCTargetConfigCache;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions('hcTPF','help compiler targetos targetcpu fpcsrcdir');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h','help') then begin
    WriteHelp;
    Halt;
  end;

  if not HasOption('F','fpcsrcdir') then
    Error('fpc source directory missing',true);

  if HasOption('c','compiler') then begin
    CompilerFilename:=GetOptionValue('c','compiler');
    CompilerFilename:=CleanAndExpandFilename(CompilerFilename);
  end else begin
    CompilerFilename:=GetDefaultCompilerFilename;
    CompilerFilename:=SearchFileInPath(CompilerFilename,'',
                    GetEnvironmentVariable('PATH'), PathSeparator,ctsfcDefault);
  end;
  TargetOS:=GetOptionValue('T','targetos');
  TargetCPU:=GetOptionValue('P','targetcpu');
  FPCSrcDir:=GetOptionValue('F','fpcsrcdir');
  FPCSrcDir:=CleanAndExpandDirectory(FPCSrcDir);

  if not FileExistsUTF8(CompilerFilename) then
    Error('compiler file not found: '+CompilerFilename,false);
  if not DirPathExists(FPCSrcDir) then
    Error('FPC source directory not found: '+FPCSrcDir,false);

  CodeToolBoss.SimpleInit(ConfigFilename);

  UnitSet:=CodeToolBoss.FPCDefinesCache.FindUnitSet(CompilerFilename,
                                          TargetOS,TargetCPU,'',FPCSrcDir,true);
  UnitSet.Init;
  ConfigCache:=UnitSet.GetConfigCache(false);

  WriteCompilerInfo(ConfigCache);
  WriteDuplicatesInPPUPath(ConfigCache);

  WriteMissingPPUSources(UnitSet);
  WriteDuplicateSources(UnitSet);

  // stop program loop
  Terminate;
end;

constructor TTestFPCSourceUnitRules.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TTestFPCSourceUnitRules.Destroy;
begin
  inherited Destroy;
end;

procedure TTestFPCSourceUnitRules.WriteHelp;
begin
  writeln('Usage: ',ExeName,' -h');
  writeln;
  writeln('  -c <compiler file name>');
  writeln('  --compiler=<compiler file name>');
  writeln('  -T <target OS>');
  writeln('  --targetos=<target OS>');
  writeln('  -P <target CPU>');
  writeln('  --targetcpu=<target CPU>');
  writeln('  -F <FPC source directory>');
  writeln('  --fpcsrcdir=<FPC source directory>');
end;

procedure TTestFPCSourceUnitRules.Error(Msg: string; DoWriteHelp: Boolean);
begin
  writeln('Error: ',Msg);
  if DoWriteHelp then begin
    writeln;
    WriteHelp;
  end;
  Halt;
end;

procedure TTestFPCSourceUnitRules.WriteCompilerInfo(
  ConfigCache: TFPCTargetConfigCache);
var
  i: Integer;
  CfgFile: TFPCConfigFileState;
begin
  writeln('Compiler=',ConfigCache.Compiler);
  writeln('TargetOS=',ConfigCache.TargetOS);
  writeln('TargetCPU=',ConfigCache.TargetCPU);
  writeln('Options=',ConfigCache.CompilerOptions);
  writeln('RealCompiler=',ConfigCache.RealCompiler);
  writeln('RealTargetOS=',ConfigCache.RealTargetOS);
  writeln('RealTargetCPU=',ConfigCache.RealTargetCPU);
  if ConfigCache.ConfigFiles<>nil then begin
    for i:=0 to ConfigCache.ConfigFiles.Count-1 do begin
      CfgFile:=ConfigCache.ConfigFiles[i];
      writeln('Config=',CfgFile.Filename,' Exists=',CfgFile.FileExists);
    end;
  end;
end;

procedure TTestFPCSourceUnitRules.WriteDuplicatesInPPUPath(
  ConfigCache: TFPCTargetConfigCache);
var
  i: Integer;
  Directory: String;
  FileInfo: TSearchRec;
  ShortFilename: String;
  Filename: String;
  Ext: String;
  LowerUnitname: String;
  SearchPaths: TStrings;
  IsSource: Boolean;
  IsPPU: Boolean;
  SourceFiles: TStringList;
  Units: TStringToStringTree;
  Item: PStringToStringTreeItem;
  Node: TAVLTreeNode;
begin
  SearchPaths:=ConfigCache.UnitPaths;
  if SearchPaths=nil then exit;
  SourceFiles:=TStringList.Create;
  Units:=TStringToStringTree.Create(false);
  for i:=SearchPaths.Count-1 downto 0 do begin
    Directory:=CleanAndExpandDirectory(SearchPaths[i]);
    if FindFirstUTF8(Directory+FileMask,faAnyFile,FileInfo)=0 then begin
      repeat
        ShortFilename:=FileInfo.Name;
        if (ShortFilename='') or (ShortFilename='.') or (ShortFilename='..') then
          continue;
        Filename:=Directory+ShortFilename;
        Ext:=LowerCase(ExtractFileExt(ShortFilename));
        IsSource:=(Ext='.pas') or (Ext='.pp') or (Ext='.p');
        IsPPU:=(Ext='.ppu');
        if IsSource then
          SourceFiles.Add(Filename);
        if IsSource or IsPPU then begin
          LowerUnitname:=lowercase(ExtractFileNameOnly(Filename));
          if Units.Contains(LowerUnitname) then
            Units[LowerUnitname]:=Units[LowerUnitname]+';'+Filename
          else
            Units[LowerUnitname]:=Filename;
        end;
      until FindNextUTF8(FileInfo)<>0;
    end;
    FindCloseUTF8(FileInfo);
  end;
  if SourceFiles.Count<>0 then begin
    // source files in PPU search path
    writeln;
    writeln('WARNING: source files found in PPU search paths:');
    writeln(SourceFiles.Text);
    writeln;
  end;
  Node:=Units.Tree.FindLowest;
  i:=0;
  while Node<>nil do begin
    Item:=PStringToStringTreeItem(Node.Data);
    Filename:=Item^.Value;
    if System.Pos(';',Filename)>0 then begin
      // duplicate units
      if i=0 then writeln;
      inc(i);
      writeln('WARNING: duplicate unit in PPU path: '+Filename);
    end;
    Node:=Units.Tree.FindSuccessor(Node);
  end;
  if i>0 then writeln;
  Units.Free;
  SourceFiles.Free;
end;

procedure TTestFPCSourceUnitRules.WriteMissingPPUSources(
  UnitSet: TFPCUnitSetCache);
var
  UnitToSrc: TStringToStringTree;
  Node: TAVLTreeNode;
  Item: PStringToStringTreeItem;
  ConfigCache: TFPCTargetConfigCache;
  aUnitName: String;
  Cnt: Integer;
  Filename: String;
begin
  UnitToSrc:=UnitSet.GetUnitToSourceTree(false);
  ConfigCache:=UnitSet.GetConfigCache(false);
  if ConfigCache.Units<>nil then begin
    Cnt:=0;
    Node:=ConfigCache.Units.Tree.FindLowest;
    while Node<>nil do begin
      Item:=PStringToStringTreeItem(Node.Data);
      aUnitName:=Item^.Name;
      Filename:=Item^.Value;
      if CompareFileExt(Filename,'ppu',false)=0 then begin
        // a ppu in the PPU search path
        if UnitToSrc[aUnitName]='' then begin
          inc(Cnt);
          if Cnt=1 then writeln;
          writeln('WARNING: no source found for PPU file: '+Filename);
        end;
      end;
      Node:=ConfigCache.Units.Tree.FindSuccessor(Node);
    end;
    if Cnt>0 then writeln;
  end;
end;

procedure TTestFPCSourceUnitRules.WriteDuplicateSources(
  UnitSet: TFPCUnitSetCache);
var
  SrcDuplicates: TStringToStringTree;
  Node: TAVLTreeNode;
  Cnt: Integer;
  Item: PStringToStringTreeItem;
  aUnitName: String;
  Files: String;
begin
  SrcDuplicates:=UnitSet.GetSourceDuplicates(false);
  if SrcDuplicates=nil then exit;
  Cnt:=0;
  Node:=SrcDuplicates.Tree.FindLowest;
  while Node<>nil do begin
    Item:=PStringToStringTreeItem(Node.Data);
    if Cnt=0 then writeln;
    inc(Cnt);
    aUnitName:=Item^.Name;
    Files:=Item^.Value;
    writeln('WARNING: duplicate source files: unit=',aUnitName,' files=',Files);
    Node:=SrcDuplicates.Tree.FindSuccessor(Node);
  end;
  if Cnt>0 then writeln;
end;

var
  Application: TTestFPCSourceUnitRules;
begin
  Application:=TTestFPCSourceUnitRules.Create(nil);
  Application.Title:='TestFPCSrcUnitRules';
  Application.Run;
  Application.Free;
end.

