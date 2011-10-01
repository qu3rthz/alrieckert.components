unit InstantFPCRegisterLaz;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ProjectIntf, Forms, LazIDEIntf;

const
  FileDescNameInstantFPC = 'InstantFPC program';
  ProjDescNameInstantFPCProject = 'InstantFPC project';
type
  { TFileDescInstantFPCScript }

  TFileDescInstantFPCScript = class(TProjectFileDescriptor)
  public
    constructor Create; override;
    function GetLocalizedName: string; override;
    function GetLocalizedDescription: string; override;
    function CreateSource(const {%H-}Filename, {%H-}SourceName,
                          {%H-}ResourceName: string): string; override;
  end;

  { TProjectInstantFPCDescriptor }

  TProjectInstantFPCDescriptor = class(TProjectDescriptor)
  public
    constructor Create; override;
    function GetLocalizedName: string; override;
    function GetLocalizedDescription: string; override;
    function InitProject(AProject: TLazProject): TModalResult; override;
    function CreateStartFiles(AProject: TLazProject): TModalResult; override;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterProjectFileDescriptor(TFileDescInstantFPCScript.Create);
  RegisterProjectDescriptor(TProjectInstantFPCDescriptor.Create);
end;

{ TProjectInstantFPCDescriptor }

constructor TProjectInstantFPCDescriptor.Create;
begin
  inherited Create;
  Name:=ProjDescNameInstantFPCProject;
  Flags:=Flags-[pfMainUnitHasCreateFormStatements,pfMainUnitHasTitleStatement]
              +[pfUseDefaultCompilerOptions];
end;

function TProjectInstantFPCDescriptor.GetLocalizedName: string;
begin
  Result:='InstantFPC program';
end;

function TProjectInstantFPCDescriptor.GetLocalizedDescription: string;
begin
  Result:=GetLocalizedName+#13
    +'Single file Free Pascal program executed by instantfpc';
end;

function TProjectInstantFPCDescriptor.InitProject(AProject: TLazProject
  ): TModalResult;
var
  MainFile: TLazProjectFile;
  NewSource: TStringList;
begin
  Result:=inherited InitProject(AProject);

  MainFile:=AProject.CreateProjectFile('program1.pas');
  MainFile.IsPartOfProject:=true;
  AProject.AddFile(MainFile,false);
  AProject.MainFileID:=0;

  AProject.LazCompilerOptions.UnitOutputDirectory:='';
  AProject.LazCompilerOptions.TargetFilename:='program1';
  AProject.LazCompilerOptions.Win32GraphicApp:=false;
  AProject.LazCompilerOptions.SetAlternativeCompile(
    'instantfpc --skip-run -B -gl "-Fu$(ProjUnitPath)" $Name($(ProjFile))',true);

  // create program source
  NewSource:=TStringList.Create;
  NewSource.Add('#!/usr/bin/env instantfpc');
  NewSource.Add('{$mode objfpc}{$H+}');
  NewSource.Add('uses');
  NewSource.Add('  Classes, SysUtils;');
  NewSource.Add('');
  NewSource.Add('begin');
  NewSource.Add('');
  NewSource.Add('end.');
  NewSource.Add('');
  AProject.MainFile.SetSourceText(NewSource.Text);
  NewSource.Free;
end;

function TProjectInstantFPCDescriptor.CreateStartFiles(AProject: TLazProject
  ): TModalResult;
begin
  Result:=LazarusIDE.DoOpenEditorFile(AProject.MainFile.Filename,-1,-1,
                                      [ofProjectLoading,ofRegularFile]);
end;

{ TFileDescInstantFPCScript }

constructor TFileDescInstantFPCScript.Create;
begin
  inherited Create;
  Name:=FileDescNameInstantFPC;
  DefaultFilename:='program1.pas';
  DefaultSourceName:='program1';
  DefaultFileExt:='.pas';
  RunFileIfActive:=true;
  IsPascalUnit:=true;
  AddToProject:=false;
end;

function TFileDescInstantFPCScript.GetLocalizedName: string;
begin
  Result:='InstantFPC script';
end;

function TFileDescInstantFPCScript.GetLocalizedDescription: string;
begin
  Result:=GetLocalizedName+#13
         +'Single file program using instantfpc to compile and execute';
end;

function TFileDescInstantFPCScript.CreateSource(const Filename, SourceName,
  ResourceName: string): string;
begin
  Result:='#!/usr/bin/instantfpc'+LineEnding
    +'{$mode objfpc}{$H+}'+LineEnding
    +LineEnding
    +'uses Classes, SysUtils;'+LineEnding
    +LineEnding
    +'begin'+LineEnding
    +LineEnding
    +'end.'+LineEnding;
end;

end.

