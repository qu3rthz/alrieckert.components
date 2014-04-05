unit FpDebugDebugger;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Forms,
  LazLogger,
  FpDbgClasses,
  FpDbgInfo,
  DbgIntfBaseTypes,
  DbgIntfDebuggerBase,
  FPDbgController;

type

  { TFpDebugThread }
  TFpDebugDebugger = class;
  TFpDebugThread = class(TThread)
  private
    FFpDebugDebugger: TFpDebugDebugger;
    procedure DoDebugLoopFinishedASync({%H-}Data: PtrInt);
  public
    constructor Create(AFpDebugDebugger: TFpDebugDebugger);
    destructor Destroy; override;
    procedure Execute; override;
  end;

  { TFpDebugDebugger }

  TFpDebugDebugger = class(TDebuggerIntf)
  private
    FDbgController: TDbgController;
    FFpDebugThread: TFpDebugThread;
    FDebugLoopRunning: boolean;
    procedure FDbgControllerHitBreakpointEvent(var continue: boolean);
    procedure FDbgControllerCreateProcessEvent(var continue: boolean);
    procedure FDbgControllerProcessExitEvent(AExitCode: DWord);
    procedure FDbgControllerExceptionEvent(var continue: boolean);
  protected
    function  RequestCommand(const ACommand: TDBGCommand;
                             const AParams: array of const): Boolean; override;
    function ChangeFileName: Boolean; override;

    procedure OnLog(AString: String);
    procedure StartDebugLoop;
    procedure DebugLoopFinished;
  public
    constructor Create(const AExternalDebugger: String); override;
    destructor Destroy; override;
    function GetLocation: TDBGLocationRec; override;
    class function Caption: String; override;
    class function HasExePath: boolean; override;
    function  GetSupportedCommands: TDBGCommands; override;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterDebugger(TFpDebugDebugger);
end;

{ TFpDebugThread }

procedure TFpDebugThread.DoDebugLoopFinishedASync(Data: PtrInt);
begin
  FFpDebugDebugger.DebugLoopFinished;
end;

constructor TFpDebugThread.Create(AFpDebugDebugger: TFpDebugDebugger);
begin
  FFpDebugDebugger := AFpDebugDebugger;
  inherited Create(false);
end;

destructor TFpDebugThread.Destroy;
begin
  inherited Destroy;
end;

procedure TFpDebugThread.Execute;
begin
  FFpDebugDebugger.FDbgController.ProcessLoop;
  Application.QueueAsyncCall(@DoDebugLoopFinishedASync, 0);
end;

{ TFpDebugDebugger }

procedure TFpDebugDebugger.FDbgControllerProcessExitEvent(AExitCode: DWord);
begin
  SetExitCode(AExitCode);
  DoDbgEvent(ecProcess, etProcessExit, Format('Process exited with exit-code %d',[AExitCode]));
  SetState(dsStop);
end;

procedure TFpDebugDebugger.FDbgControllerExceptionEvent(var continue: boolean);
begin
  DoException(deInternal, 'unknown', GetLocation, 'Unknown exception', continue);
  if not continue then
    begin
    SetState(dsPause);
    DoCurrent(GetLocation);
    end;
end;

procedure TFpDebugDebugger.FDbgControllerHitBreakpointEvent(var continue: boolean);
begin
  BreakPoints[0].Hit(continue);
  SetState(dsPause);
  DoCurrent(GetLocation);
end;

procedure TFpDebugDebugger.FDbgControllerCreateProcessEvent(var continue: boolean);
var
  i: integer;
  bp: TDBGBreakPoint;
  ibp: FpDbgClasses.TDbgBreakpoint;
begin
  SetState(dsInit);
  for i := 0 to BreakPoints.Count-1 do
    begin
    bp := BreakPoints.Items[i];
    if bp.Enabled then
      begin
      case bp.Kind of
        bpkAddress:   ibp := FDbgController.CurrentProcess.AddBreak(bp.Address);
        bpkSource:    ibp := TDbgInstance(FDbgController.CurrentProcess).AddBreak(bp.Source, cardinal(bp.Line));
      else
        Raise Exception.Create('Breakpoints of this kind are not suported.');
      end;
      if not assigned(ibp) then
        begin
        DoDbgOutput('Failed to set breakpoint '+inttostr(bp.ID));
        DoOutput('Failed to set breakpoint '+inttostr(bp.ID));
        //bp.Valid:=vsInvalid;
        end
      //else
        //bp.Valid:=vsValid;
      end;
    end;
end;

function TFpDebugDebugger.RequestCommand(const ACommand: TDBGCommand;
  const AParams: array of const): Boolean;
begin
  result := False;
  case ACommand of
    dcRun:
      begin
      if not assigned(FDbgController.MainProcess) then
        begin
        FDbgController.ExecutableFilename:=FileName;
        Result := FDbgController.Run;
        if not Result then
          Exit;
        SetState(dsInit);
        end
      else
        begin
        SetState(dsRun);
        end;
      StartDebugLoop;
      end;
    dcStop:
      begin
        FDbgController.Stop;
        result := true;
      end;
  end; {case}
end;

function TFpDebugDebugger.ChangeFileName: Boolean;
begin
  result := true;
end;

procedure TFpDebugDebugger.OnLog(AString: String);
begin
  DebugLn(AString);
end;

procedure TFpDebugDebugger.StartDebugLoop;
begin
  DebugLn('StartDebugLoop');
  FDebugLoopRunning:=true;
  FFpDebugThread := TFpDebugThread.Create(Self);
end;

procedure TFpDebugDebugger.DebugLoopFinished;
var
  Cont: boolean;
begin
  FFpDebugThread.WaitFor;
  FFpDebugThread.Free;
  FDebugLoopRunning:=false;
  DebugLn('DebugLoopFinished');

  FDbgController.SendEvents(Cont);

  if Cont then
    begin
    SetState(dsRun);
    StartDebugLoop;
    end
end;

constructor TFpDebugDebugger.Create(const AExternalDebugger: String);
begin
  inherited Create(AExternalDebugger);
  FDbgController := TDbgController.Create;
  FDbgController.OnLog:=@OnLog;
  FDbgController.OnCreateProcessEvent:=@FDbgControllerCreateProcessEvent;
  FDbgController.OnHitBreakpointEvent:=@FDbgControllerHitBreakpointEvent;
  FDbgController.OnProcessExitEvent:=@FDbgControllerProcessExitEvent;
  FDbgController.OnExceptionEvent:=@FDbgControllerExceptionEvent;
end;

destructor TFpDebugDebugger.Destroy;
begin
  FDbgController.Free;
  inherited Destroy;
end;

function TFpDebugDebugger.GetLocation: TDBGLocationRec;
var
  sym, symproc: TFpDbgSymbol;
begin
  if Assigned(FDbgController.CurrentProcess) then
    begin
    result.FuncName:='';
    result.SrcFile:='';
    result.SrcFullName:='';
    result.SrcLine:=0;

    result.Address := FDbgController.CurrentProcess.GetInstructionPointerRegisterValue;

    sym := FDbgController.CurrentProcess.FindSymbol(result.Address);
    if sym = nil then
      Exit;

    result.SrcFile := sym.FileName;
    result.SrcLine := sym.Line;
    result.SrcFullName := sym.FileName;

    debugln('Locatie: '+sym.FileName+':'+sym.Name+':'+inttostr(sym.Line));

    symproc := sym;
    while not (symproc.kind in [skProcedure, skFunction]) do
      symproc := symproc.Parent;

    if assigned(symproc) then
      result.FuncName:=symproc.Name;
    end
  else
    result := inherited;
end;

class function TFpDebugDebugger.Caption: String;
begin
  Result:='FpDebug internal Dwarf-debugger (alfa)';
end;

class function TFpDebugDebugger.HasExePath: boolean;
begin
  Result:=False;
end;

function TFpDebugDebugger.GetSupportedCommands: TDBGCommands;
begin
  Result:=[dcRun, dcStop];
end;

end.

