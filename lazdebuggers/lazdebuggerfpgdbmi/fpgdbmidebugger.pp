unit FpGdbmiDebugger;

{$mode objfpc}{$H+}

{$IFdef MSWindows}
{$DEFINE  WithWinMemReader}
{$ENDIF}

interface

uses
  {$IFdef WithWinMemReader}
  windows,
  {$ENDIF}
  Classes, sysutils, math, FpdMemoryTools, FpDbgInfo, FpDbgClasses, GDBMIDebugger,
  DbgIntfBaseTypes, DbgIntfDebuggerBase, GDBMIMiscClasses, GDBTypeInfo, LCLProc, Forms,
  FpDbgLoader, FpDbgDwarf, LazLoggerBase, LazLoggerProfiling, LazClasses, FpPascalParser,
  FpPascalBuilder, FpErrorMessages, FpDbgDwarfDataClasses, FpDbgDwarfFreePascal, MenuIntf;

type

  TFpGDBMIDebugger = class;

  TGDBMIDebuggerCommandMemReader = class(TGDBMIDebuggerCommand)
  end;

  { TFpGDBMIDbgMemReader }

  TFpGDBMIDbgMemReader = class(TFpDbgMemReaderBase)
  private
// TODO
    //FThreadId: Integer;
    //FStackFrame: Integer;
    FDebugger: TFpGDBMIDebugger;
    FCmd: TGDBMIDebuggerCommandMemReader;
  protected
    // TODO: needs to be handled by memory manager
    //FThreadId, FStackFrame: Integer;
  public
    constructor Create(ADebugger: TFpGDBMIDebugger);
    destructor Destroy; override;
    function ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal; ADest: Pointer): Boolean; override;
    function ReadMemoryEx({%H-}AnAddress, {%H-}AnAddressSpace:{%H-} TDbgPtr; ASize: {%H-}Cardinal; ADest: Pointer): Boolean; override;
    function ReadRegister(ARegNum: Cardinal; out AValue: TDbgPtr; AContext: TFpDbgAddressContext): Boolean; override;
    function RegisterSize({%H-}ARegNum: Cardinal): Integer; override;
  end;

  { TFpGDBMIAndWin32DbgMemReader }

  TFpGDBMIAndWin32DbgMemReader = class(TFpGDBMIDbgMemReader)
  private
    hProcess: THandle;
  public
    destructor Destroy; override;
    function ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal; ADest: Pointer): Boolean; override;
    //function ReadRegister(ARegNum: Integer; out AValue: TDbgPtr): Boolean; override;
    procedure OpenProcess(APid: Cardinal);
    procedure CloseProcess;
  end;

const
  MAX_CTX_CACHE = 10;

type
  { TFpGDBMIDebugger }

  TFpGDBMIDebugger = class(TGDBMIDebugger)
  private
    FWatchEvalList: TList;
    FImageLoader: TDbgImageLoader;
    FDwarfInfo: TFpDwarfInfo;
    FPrettyPrinter: TFpPascalPrettyPrinter;
    FMemReader: TFpGDBMIDbgMemReader;
    FMemManager: TFpDbgMemManager;
    // cache last context
    FlastStackFrame, FLastThread: Integer;
    FLastContext: array [0..MAX_CTX_CACHE-1] of TFpDbgInfoContext;
  protected
    function CreateCommandStartDebugging(AContinueCommand: TGDBMIDebuggerCommand): TGDBMIDebuggerCommandStartDebugging; override;
    function CreateLineInfo: TDBGLineInfo; override;
    function  CreateWatches: TWatchesSupplier; override;
    procedure DoState(const OldState: TDBGState); override;
    function  HasDwarf: Boolean;
    procedure LoadDwarf;
    procedure UnLoadDwarf;
    function  RequestCommand(const ACommand: TDBGCommand; const AParams: array of const): Boolean; override;
    procedure QueueCommand(const ACommand: TGDBMIDebuggerCommand; ForceQueue: Boolean = False);

    procedure GetCurrentContext(out AThreadId, AStackFrame: Integer);
    function  GetLocationForContext(AThreadId, AStackFrame: Integer): TDBGPtr;
    function  GetInfoContextForContext(AThreadId, AStackFrame: Integer): TFpDbgInfoContext;
    property CurrentCommand;
    property TargetPID;
  protected
    procedure DoWatchFreed(Sender: TObject);
    function EvaluateExpression(AWatchValue: TWatchValue;
                                AExpression: String;
                                var AResText: String;
                                out ATypeInfo: TDBGType;
                                EvalFlags: TDBGEvaluateFlags = []): Boolean;
    property CurrentThreadId;
    property CurrentStackFrame;
  public
    class function Caption: String; override;
  public
    constructor Create(const AExternalDebugger: String); override;
    destructor Destroy; override;
  end;

procedure Register;

implementation

type

  { TFpGDBMIDebuggerCommandStartDebugging }

  TFpGDBMIDebuggerCommandStartDebugging = class(TGDBMIDebuggerCommandStartDebugging)
  protected
    function DoExecute: Boolean; override;
  end;

  TFPGDBMIWatches = class;

  { TFpGDBMIDebuggerCommandEvaluate }

  TFpGDBMIDebuggerCommandEvaluate = class(TGDBMIDebuggerCommand)
  private
    FOwner: TFPGDBMIWatches;
  protected
    function DoExecute: Boolean; override;
    procedure DoFree; override;
    procedure DoCancel; override;
    procedure DoLockQueueExecute; override;
    procedure DoUnLockQueueExecute; override;
  public
    constructor Create(AOwner: TFPGDBMIWatches);
  end;

  { TFPGDBMIWatches }

  TFPGDBMIWatches = class(TGDBMIWatches)
  private
    FWatchEvalLock: Integer;
    FNeedRegValues: Boolean;
    FEvaluationCmdObj: TFpGDBMIDebuggerCommandEvaluate;
  protected
    function  FpDebugger: TFpGDBMIDebugger;
    //procedure DoStateChange(const AOldState: TDBGState); override;
    procedure ProcessEvalList;
    procedure QueueCommand;
    procedure InternalRequestData(AWatchValue: TWatchValue); override;
  public
  end;

  { TFpGDBMILineInfo }

  TFpGDBMILineInfo = class(TDBGLineInfo) //class(TGDBMILineInfo)
  private
    FRequestedSources: TStringList;
  protected
    function  FpDebugger: TFpGDBMIDebugger;
    procedure DoStateChange(const {%H-}AOldState: TDBGState); override;
    procedure ClearSources;
  public
    constructor Create(const ADebugger: TDebuggerIntf);
    destructor Destroy; override;
    function Count: Integer; override;
    function GetAddress(const AIndex: Integer; const ALine: Integer): TDbgPtr; override;
    function GetInfo(AAdress: TDbgPtr; out ASource, ALine, AOffset: Integer): Boolean; override;
    function IndexOf(const ASource: String): integer; override;
    procedure Request(const ASource: String); override;
    procedure Cancel(const ASource: String); override;
  end;

var
  MenuCmd: TIDEMenuCommand;
  CurrentDebugger: TFpGDBMIDebugger;
  UseGDB: Boolean;

procedure IDEMenuClicked(Sender: TObject);
begin
  UseGDB := (MenuCmd.MenuItem <> nil) and MenuCmd.MenuItem.Checked;
  CurrentDebugger.Watches.CurrentWatches.ClearValues;
end;

// This Accessor hack is temporarilly needed / the final version will not show gdb data
type TWatchValueHack = class(TWatchValue) end;
procedure MarkWatchValueAsGdb(AWatchValue: TWatchValue);
begin
  AWatchValue.Value := '{GDB:}' + AWatchValue.Value;
  TWatchValueHack(AWatchValue).DoDataValidityChanged(ddsRequested);
end;

{ TFpGDBMIDebuggerCommandEvaluate }

function TFpGDBMIDebuggerCommandEvaluate.DoExecute: Boolean;
begin
  FOwner.FEvaluationCmdObj := nil;
  FOwner.ProcessEvalList;
  Result := True;
end;

procedure TFpGDBMIDebuggerCommandEvaluate.DoFree;
begin
  FOwner.FEvaluationCmdObj := nil;
  inherited DoFree;
end;

procedure TFpGDBMIDebuggerCommandEvaluate.DoCancel;
begin
  FOwner.FpDebugger.FWatchEvalList.Clear;
  FOwner.FEvaluationCmdObj := nil;
  inherited DoCancel;
end;

procedure TFpGDBMIDebuggerCommandEvaluate.DoLockQueueExecute;
begin
  //
end;

procedure TFpGDBMIDebuggerCommandEvaluate.DoUnLockQueueExecute;
begin
  //
end;

constructor TFpGDBMIDebuggerCommandEvaluate.Create(AOwner: TFPGDBMIWatches);
begin
  inherited Create(AOwner.FpDebugger);
  FOwner := AOwner;
end;

{ TFpGDBMIAndWin32DbgMemReader }

destructor TFpGDBMIAndWin32DbgMemReader.Destroy;
begin
  CloseProcess;
  inherited Destroy;
end;

function TFpGDBMIAndWin32DbgMemReader.ReadMemory(AnAddress: TDbgPtr;
  ASize: Cardinal; ADest: Pointer): Boolean;
var
  BytesRead: Cardinal;
begin
  {$IFdef MSWindows}
  Result := ReadProcessMemory(
    hProcess,
    Pointer(AnAddress),
    ADest, ASize,
    BytesRead) and
  (BytesRead = ASize);
//DebugLn(['*&*&*&*& ReadMem ', dbgs(Result), '  at ', AnAddress, ' Size ',ASize, ' br=',BytesRead, ' b1',PBYTE(ADest)^]);
  {$ELSE}
  Result := inherited ReadMemory(AnAddress, ASize, ADest);
  {$ENDIF}
end;

procedure TFpGDBMIAndWin32DbgMemReader.OpenProcess(APid: Cardinal);
begin
  {$IFdef MSWindows}
  debugln(['OPEN process ',APid]);
  if APid <> 0 then
    hProcess := windows.OpenProcess(PROCESS_CREATE_THREAD or PROCESS_QUERY_INFORMATION or PROCESS_VM_OPERATION or PROCESS_VM_WRITE or PROCESS_VM_READ, False, APid);
  {$ENDIF}
end;

procedure TFpGDBMIAndWin32DbgMemReader.CloseProcess;
begin
  {$IFdef MSWindows}
  if hProcess <> 0 then
    CloseHandle(hProcess);
  {$ENDIF}
end;

{ TFpGDBMIDbgMemReader }

constructor TFpGDBMIDbgMemReader.Create(ADebugger: TFpGDBMIDebugger);
begin
  FDebugger := ADebugger;
  FCmd := TGDBMIDebuggerCommandMemReader.Create(ADebugger);
end;

destructor TFpGDBMIDbgMemReader.Destroy;
begin
  FCmd.ReleaseReference;
  inherited Destroy;
end;

function TFpGDBMIDbgMemReader.ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal;
  ADest: Pointer): Boolean;
var
  R: TGDBMIExecResult;
  MemDump: TGDBMIMemoryDumpResultList;
  i: Integer;
begin
  Result := False;

  if not FCmd.ExecuteCommand('-data-read-memory %u x 1 1 %u', [AnAddress, ASize], R, [cfNoThreadContext, cfNoStackContext])
  then
    exit;
  if R.State = dsError then exit;

  MemDump := TGDBMIMemoryDumpResultList.Create(R);
  if MemDump.Count <> ASize then exit;

  for i := 0 to MemDump.Count - 1 do begin
    PByte(ADest + i)^ := Byte(MemDump.ItemNum[i]);
  end;

  MemDump.Free;
  Result := True;

debugln(['TFpGDBMIDbgMemReader.ReadMemory ', dbgs(AnAddress), '  ', dbgMemRange(ADest, ASize)]);
end;

function TFpGDBMIDbgMemReader.ReadMemoryEx(AnAddress, AnAddressSpace: TDbgPtr;
  ASize: Cardinal; ADest: Pointer): Boolean;
begin
  Result := False;
end;

function TFpGDBMIDbgMemReader.ReadRegister(ARegNum: Cardinal; out AValue: TDbgPtr;
  AContext: TFpDbgAddressContext): Boolean;
var
  rname: String;
  v: String;
  i: Integer;
  Reg: TRegisters;
  RegVObj: TRegisterDisplayValue;
begin
  Result := False;
  // WINDOWS gdb dwarf names
  {$IFDEF cpu64}
  case ARegNum of
     0:  rname := 'RAX'; // RAX
     1:  rname := 'RDX'; // RDX
     2:  rname := 'RCX'; // RCX
     3:  rname := 'RBX'; // RBX
     4:  rname := 'RSI';
     5:  rname := 'RDI';
     6:  rname := 'RBP';
     7:  rname := 'RSP';
     8:  rname := 'R8'; // R8D , but gdb uses R8
     9:  rname := 'R9';
    10:  rname := 'R10';
    11:  rname := 'R11';
    12:  rname := 'R12';
    13:  rname := 'R13';
    14:  rname := 'R14';
    15:  rname := 'R15';
    else
      exit;
  end;
  {$ELSE}
  case ARegNum of
     0:  rname := 'EAX'; // RAX
     1:  rname := 'ECX'; // RDX
     2:  rname := 'EDX'; // RCX
     3:  rname := 'EBX'; // RBX
     4:  rname := 'ESP';
     5:  rname := 'EBP';
     6:  rname := 'ESI';
     7:  rname := 'EDI';
     8:  rname := 'EIP';
    else
      exit;
  end;
  {$ENDIF}
  Reg := FDebugger.Registers.CurrentRegistersList[AContext.ThreadId, AContext.StackFrame];
  for i := 0 to Reg.Count - 1 do
    if UpperCase(Reg[i].Name) = rname then
      begin
        RegVObj := Reg[i].ValueObjFormat[rdDefault];
        if RegVObj <> nil then
          v := RegVObj.Value[rdDefault]
        else
          v := '';
debugln(['TFpGDBMIDbgMemReader.ReadRegister ',rname, '  ', v]);
        Result := true;
        try
          AValue := StrToQWord(v);
        except
          Result := False;
        end;
        exit;
      end;
end;

function TFpGDBMIDbgMemReader.RegisterSize(ARegNum: Cardinal): Integer;
begin
  {$IFDEF cpu64}
  Result := 8; // for the very few supported...
  {$ELSE}
  Result := 4; // for the very few supported...
  {$ENDIF}
end;

{ TFPGDBMIWatches }

function TFPGDBMIWatches.FpDebugger: TFpGDBMIDebugger;
begin
  Result := TFpGDBMIDebugger(Debugger);
end;

procedure TFPGDBMIWatches.ProcessEvalList;
var
  WatchValue: TWatchValue;
  ResTypeInfo: TDBGType;
  ResText: String;

  function IsWatchValueAlive: Boolean;
  begin
    Result := (FpDebugger.FWatchEvalList.Count > 0) and (FpDebugger.FWatchEvalList[0] = Pointer(WatchValue));
  end;
begin
  if FNeedRegValues then begin
    FNeedRegValues := False;
    FpDebugger.Registers.CurrentRegistersList[FpDebugger.CurrentThreadId, FpDebugger.CurrentStackFrame].Count;
    QueueCommand;
    exit;
  end;

  if FWatchEvalLock > 0 then
    exit;
  inc(FWatchEvalLock);
  try // TODO: if the stack/thread is changed, registers will be wrong
    while (FpDebugger.FWatchEvalList.Count > 0) and (FEvaluationCmdObj = nil) do begin
      try
        WatchValue := TWatchValue(FpDebugger.FWatchEvalList[0]);
        ResTypeInfo := nil;
        if UseGDB then begin
          inherited InternalRequestData(WatchValue);
          if IsWatchValueAlive then
            MarkWatchValueAsGdb(WatchValue);
        end
        else
        if not FpDebugger.EvaluateExpression(WatchValue, WatchValue.Expression, ResText, ResTypeInfo)
        then begin
          if IsWatchValueAlive then    debugln(['TFPGDBMIWatches.InternalRequestData FAILED ', WatchValue.Expression]);
          if IsWatchValueAlive then
            inherited InternalRequestData(WatchValue);
          if IsWatchValueAlive then
            MarkWatchValueAsGdb(WatchValue);
        end;
      finally
        if IsWatchValueAlive then begin
          WatchValue.RemoveFreeeNotification(@FpDebugger.DoWatchFreed);
          FpDebugger.FWatchEvalList.Remove(pointer(WatchValue));
        end;
        Application.ProcessMessages;
      end;
    end;
  finally
    dec(FWatchEvalLock);
  end;
end;

procedure TFPGDBMIWatches.QueueCommand;
begin
  FEvaluationCmdObj := TFpGDBMIDebuggerCommandEvaluate.Create(Self);
  FEvaluationCmdObj.Properties := [dcpCancelOnRun];
  // If a ExecCmd is running, then defer exec until the exec cmd is done
  FpDebugger.QueueCommand(FEvaluationCmdObj, ForceQueuing);
end;

procedure TFPGDBMIWatches.InternalRequestData(AWatchValue: TWatchValue);
begin
  if (Debugger = nil) or not(Debugger.State in [dsPause, dsInternalPause]) then begin
    AWatchValue.Validity := ddsInvalid;
    Exit;
  end;

  AWatchValue.AddFreeeNotification(@FpDebugger.DoWatchFreed); // we may call gdb
  FpDebugger.FWatchEvalList.Add(pointer(AWatchValue));

  if FEvaluationCmdObj <> nil then exit;

  FpDebugger.Threads.CurrentThreads.Count; // trigger threads, in case
  if     FpDebugger.Registers.CurrentRegistersList[FpDebugger.CurrentThreadId, FpDebugger.CurrentStackFrame].Count = 0 then   // trigger register, in case
    FNeedRegValues := True
  else
  begin
    FNeedRegValues := False;
  end;

  // Join the queue, registers and threads are needed first
  QueueCommand;
end;

{ TFpGDBMILineInfo }

function TFpGDBMILineInfo.FpDebugger: TFpGDBMIDebugger;
begin
  Result := TFpGDBMIDebugger(Debugger);
end;

procedure TFpGDBMILineInfo.DoStateChange(const AOldState: TDBGState);
begin
  //inherited DoStateChange(AOldState);
  if not (Debugger.State in [dsPause, dsInternalPause, dsRun]) then
    ClearSources;
end;

procedure TFpGDBMILineInfo.ClearSources;
begin
  FRequestedSources.Clear;
end;

constructor TFpGDBMILineInfo.Create(const ADebugger: TDebuggerIntf);
begin
  FRequestedSources := TStringList.Create;
  inherited Create(ADebugger);
end;

destructor TFpGDBMILineInfo.Destroy;
begin
  FreeAndNil(FRequestedSources);
  inherited Destroy;
end;

function TFpGDBMILineInfo.Count: Integer;
begin
  Result := FRequestedSources.Count;
end;

function TFpGDBMILineInfo.GetAddress(const AIndex: Integer; const ALine: Integer): TDbgPtr;
var
  Map: PDWarfLineMap;
begin
  Result := 0;
  if not FpDebugger.HasDwarf then
    exit;
  //Result := FpDebugger.FDwarfInfo.GetLineAddress(FRequestedSources[AIndex], ALine);
  Map := PDWarfLineMap(FRequestedSources.Objects[AIndex]);
  if Map <> nil then
    Result := Map^.GetAddressForLine(ALine);
end;

function TFpGDBMILineInfo.GetInfo(AAdress: TDbgPtr; out ASource, ALine,
  AOffset: Integer): Boolean;
begin
  Result := False;
  //ASource := '';
  //ALine := 0;
  //if not FpDebugger.HasDwarf then
  //  exit(nil);
  //FpDebugger.FDwarfInfo.
end;

function TFpGDBMILineInfo.IndexOf(const ASource: String): integer;
begin
  Result := FRequestedSources.IndexOf(ASource);
end;

procedure TFpGDBMILineInfo.Request(const ASource: String);
begin
  if not FpDebugger.HasDwarf then
    exit;
  FRequestedSources.AddObject(ASource, TObject(FpDebugger.FDwarfInfo.GetLineAddressMap(ASource)));
  DoChange(ASource);
end;

procedure TFpGDBMILineInfo.Cancel(const ASource: String);
begin
  //
end;


{ TFpGDBMIDebuggerCommandStartDebugging }

function TFpGDBMIDebuggerCommandStartDebugging.DoExecute: Boolean;
begin
  TFpGDBMIDebugger(FTheDebugger).LoadDwarf;
  Result := inherited DoExecute;
{$IFdef WithWinMemReader}
  TFpGDBMIAndWin32DbgMemReader(TFpGDBMIDebugger(FTheDebugger).FMemReader).OpenProcess(
    TFpGDBMIDebugger(FTheDebugger).TargetPid
  );
{$ENDIF}
end;

{ TFpGDBMIDebugger }

procedure TFpGDBMIDebugger.DoState(const OldState: TDBGState);
var
  i: Integer;
begin
  inherited DoState(OldState);
  if State in [dsStop, dsError, dsNone] then
    UnLoadDwarf;

  if OldState in [dsPause, dsInternalPause] then begin
    for i := 0 to MAX_CTX_CACHE-1 do
      ReleaseRefAndNil(FLastContext[i]);
    if not(State in [dsPause, dsInternalPause]) then begin
      for i := 0 to FWatchEvalList.Count - 1 do begin
        TWatchValue(FWatchEvalList[i]).RemoveFreeeNotification(@DoWatchFreed);
        //TWatchValueBase(FWatchEvalList[i]).Validity := ddsInvalid;
      end;
      FWatchEvalList.Clear;
    end;
  end;
end;

function TFpGDBMIDebugger.HasDwarf: Boolean;
begin
  Result := FDwarfInfo <> nil;
end;

procedure TFpGDBMIDebugger.LoadDwarf;
begin
  UnLoadDwarf;
  debugln(['TFpGDBMIDebugger.LoadDwarf ']);
  FImageLoader := TDbgImageLoader.Create(FileName);
  if not FImageLoader.IsValid then begin
    FreeAndNil(FImageLoader);
    exit;
  end;
{$IFdef WithWinMemReader}
  FMemReader := TFpGDBMIAndWin32DbgMemReader.Create(Self);
{$Else}
  FMemReader := TFpGDBMIDbgMemReader.Create(Self);
{$ENDIF}
  FMemManager := TFpDbgMemManager.Create(FMemReader, TFpDbgMemConvertorLittleEndian.Create);

  FDwarfInfo := TFpDwarfInfo.Create(FImageLoader);
  FDwarfInfo.MemManager := FMemManager;
  FDwarfInfo.LoadCompilationUnits;
  FPrettyPrinter := TFpPascalPrettyPrinter.Create(SizeOf(Pointer));
end;

procedure TFpGDBMIDebugger.UnLoadDwarf;
begin
  debugln(['TFpGDBMIDebugger.UnLoadDwarf ']);
  FreeAndNil(FDwarfInfo);
  FreeAndNil(FImageLoader);
  FreeAndNil(FMemReader);
  if FMemManager <> nil then
    FMemManager.TargetMemConvertor.Free;
  FreeAndNil(FMemManager);
  FreeAndNil(FPrettyPrinter);
end;

function TFpGDBMIDebugger.RequestCommand(const ACommand: TDBGCommand;
  const AParams: array of const): Boolean;
var
  EvalFlags: TDBGEvaluateFlags;
begin
  if (ACommand = dcEvaluate) then begin
    EvalFlags := [];
    EvalFlags := TDBGEvaluateFlags(AParams[3].VInteger);
    Result := False;
    if (HasDwarf) and (not UseGDB) then begin
      Result := EvaluateExpression(nil, String(AParams[0].VAnsiString),
        String(AParams[1].VPointer^), TDBGType(AParams[2].VPointer^),
        EvalFlags);
    end;
    if not Result then begin
      Result := inherited RequestCommand(ACommand, AParams);
      String(AParams[1].VPointer^) := '{GDB:}'+String(AParams[1].VPointer^);
    end;
  end
  else
    Result := inherited RequestCommand(ACommand, AParams);
end;

procedure TFpGDBMIDebugger.QueueCommand(const ACommand: TGDBMIDebuggerCommand;
  ForceQueue: Boolean);
begin
  inherited QueueCommand(ACommand, ForceQueue);
end;

procedure TFpGDBMIDebugger.GetCurrentContext(out AThreadId, AStackFrame: Integer);
begin
  if CurrentThreadIdValid then begin
    AThreadId := CurrentThreadId;

    if CurrentStackFrameValid then
      AStackFrame := CurrentStackFrame
    else
      AStackFrame := 0;
  end
  else begin
    AThreadId := 1;
    AStackFrame := 0;
  end;
end;

function TFpGDBMIDebugger.GetLocationForContext(AThreadId, AStackFrame: Integer): TDBGPtr;
var
  t: TThreadEntry;
  s: TCallStackBase;
  f: TCallStackEntry;
  //Instr: TGDBMIDebuggerInstruction;
begin
(*
  Instr := TGDBMIDebuggerInstruction.Create(Format('-stack-list-frames %d %d', [AStackFrame, AStackFrame]), AThreadId, [], 0);
  Instr.AddReference;
  Instr.Cmd := TGDBMIDebuggerCommand.Create(Self);
  FTheDebugger.FInstructionQueue.RunInstruction(Instr);
  ok := Instr.IsSuccess and Instr.FHasResult;
  AResult := Instr.ResultData;
  Instr.Cmd.ReleaseReference;
  Instr.Cmd := nil;
  Instr.ReleaseReference;

  if ok then begin
    List := TGDBMINameValueList.Create(R, ['stack']);
    Result := List.Values['frame'];
    List.Free;
  end;
*)


  Result := 0;
  if (AThreadId <= 0) then begin
    GetCurrentContext(AThreadId, AStackFrame);
  end
  else
  if (AStackFrame < 0) then begin
    AStackFrame := 0;
  end;

  t := Threads.CurrentThreads.EntryById[AThreadId];
  if t = nil then begin
    DebugLn(['NO Threads']);
    exit;
  end;
  if AStackFrame = 0 then begin
    Result := t.TopFrame.Address;
    //DebugLn(['Returning addr from Threads', dbgs(Result)]);
    exit;
  end;

  s := CallStack.CurrentCallStackList.EntriesForThreads[AThreadId];
  if s = nil then begin
    DebugLn(['NO Stackframe list for thread']);
    exit;
  end;
  f := s.Entries[AStackFrame];
  if f = nil then begin
    DebugLn(['NO Stackframe']);
    exit;
  end;

  Result := f.Address;
  //DebugLn(['Returning addr from frame', dbgs(Result)]);

end;

function TFpGDBMIDebugger.GetInfoContextForContext(AThreadId,
  AStackFrame: Integer): TFpDbgInfoContext;
var
  Addr: TDBGPtr;
  i: Integer;
begin
  Result := nil;
  if FDwarfInfo = nil then
    exit;

  if (AThreadId <= 0) then begin
    GetCurrentContext(AThreadId, AStackFrame);
  end;

  Addr := GetLocationForContext(AThreadId, AStackFrame);

  if Addr = 0 then begin
    Result := nil;
    exit;
  end;

  i := AStackFrame - FlastStackFrame;
  if (i >= 0) and
     (i < MAX_CTX_CACHE) and
     (FLastContext[i] <> nil) and
     (FLastContext[i].Address = Addr) and
     (FLastContext[i].ThreadId = AThreadId) and
     (FLastContext[i].StackFrame = AStackFrame)
  then begin
    Result := FLastContext[AStackFrame - FlastStackFrame];
    exit;
  end;

  DebugLn(['* FDwarfInfo.FindContext ', dbgs(Addr)]);
  Result := FDwarfInfo.FindContext(AThreadId, AStackFrame, Addr);

  FLastThread := AThreadId;
  FlastStackFrame := AStackFrame;
  FLastContext[0].ReleaseReference;
  FLastContext[0] := Result;
end;

type
  TGDBMIDwarfTypeIdentifier = class(TFpDwarfSymbolType)
  public
    property InformationEntry;
  end;

procedure TFpGDBMIDebugger.DoWatchFreed(Sender: TObject);
begin
  FWatchEvalList.Remove(pointer(Sender));
end;

function TFpGDBMIDebugger.EvaluateExpression(AWatchValue: TWatchValue;
  AExpression: String; var AResText: String; out ATypeInfo: TDBGType;
  EvalFlags: TDBGEvaluateFlags): Boolean;
var
  Ctx: TFpDbgInfoContext;
  PasExpr: TFpPascalExpression;
  ResValue: TFpDbgValue;

  function IsWatchValueAlive: Boolean;
  begin
    Result := (State in [dsPause, dsInternalPause]) and
              (  (AWatchValue = nil) or
                 ( (FWatchEvalList.Count > 0) and (FWatchEvalList[0] = Pointer(AWatchValue)) )
              );
  end;

  function ResTypeName(v: TFpDbgValue = nil): String;
  begin
    if v = nil then v := ResValue;
    if not((v.TypeInfo<> nil) and
           GetTypeName(Result, v.TypeInfo, []))
    then
      Result := '';
  end;

  procedure DoPointer;
  begin
    if not FPrettyPrinter.PrintValue(AResText, ResValue, []) then
      exit;
    ATypeInfo := TDBGType.Create(skPointer, ResTypeName);
    ATypeInfo.Value.AsPointer := Pointer(ResValue.AsCardinal); // TODO: no cut off
    ATypeInfo.Value.AsString := AResText;
  end;

  procedure DoSimple;
  begin
    if not FPrettyPrinter.PrintValue(AResText, ResValue, []) then
      exit;
    ATypeInfo := TDBGType.Create(skSimple, ResTypeName);
    ATypeInfo.Value.AsString := AResText;
  end;

  procedure DoEnum;
  begin
    if not FPrettyPrinter.PrintValue(AResText, ResValue, []) then
      exit;
    ATypeInfo := TDBGType.Create(skEnum, ResTypeName);
    ATypeInfo.Value.AsString := AResText;
  end;

  procedure DoSet;
  begin
    if not FPrettyPrinter.PrintValue(AResText, ResValue, []) then
      exit;
    ATypeInfo := TDBGType.Create(skSet, ResTypeName);
    ATypeInfo.Value.AsString := AResText;
  end;

  procedure DoRecord;
  var
    s2, n: String;
    m: TFpDbgValue;
    i: Integer;
    DBGType: TGDBType;
    f: TDBGField;
  begin
    if not FPrettyPrinter.PrintValue(AResText, ResValue, []) then
      exit;
    ATypeInfo := TDBGType.Create(skRecord, ResTypeName);
    ATypeInfo.Value.AsString := AResText;

    if not(defFullTypeInfo in EvalFlags) then exit;
    for i := 0 to ResValue.MemberCount - 1 do begin
      m := ResValue.Member[i];
      if m = nil then Continue; // Todo: procedures.
      case m.Kind of
        skProcedure, skFunction: ; //  DBGType := TGDBType.Create(skProcedure, TGDBTypes.CreateFromCSV(Params))
        else
          begin
            DBGType := TGDBType.Create(skSimple, ResTypeName(m));
            FPrettyPrinter.PrintValue(s2, m, []);
            DBGType.Value.AsString := s2;
            n := '';
            if m.DbgSymbol <> nil then n := m.DbgSymbol.Name;
            f := TDBGField.Create(n, DBGType, flPublic);
            ATypeInfo.Fields.Add(f);
          end;
      end;
    end;
  end;

  procedure DoClass;
  var
    m: TFpDbgValue;
    s, s2, n, CastName: String;
    DBGType: TGDBType;
    f: TDBGField;
    i: Integer;
    ClassAddr, CNameAddr: TFpDbgMemLocation;
    NameLen: QWord;
    PasExpr2: TFpPascalExpression;
  begin
    if (ResValue.Kind = skClass) and (ResValue.AsCardinal = 0) then begin
      if not FPrettyPrinter.PrintValue(AResText, ResValue, []) then
        exit;
      ATypeInfo := TDBGType.Create(skSimple, ResTypeName);
      ATypeInfo.Value.AsString := AResText;
      Result := True;
      exit;
    end;

    CastName := '';
    if (defClassAutoCast in EvalFlags) then begin
      if FMemManager.ReadAddress(ResValue.DataAddress, Ctx.SizeOfAddress, ClassAddr) then begin
        ClassAddr.Address := ClassAddr.Address + 3 * Ctx.SizeOfAddress;
        if FMemManager.ReadAddress(ClassAddr, Ctx.SizeOfAddress, CNameAddr) then begin
          if (FMemManager.ReadUnsignedInt(CNameAddr, 1, NameLen)) then
            if NameLen > 0 then begin
              SetLength(CastName, NameLen);
              CNameAddr.Address := CNameAddr.Address + 1;
              FMemManager.ReadMemory(CNameAddr, NameLen, @CastName[1]);
              PasExpr2 := TFpPascalExpression.Create(CastName+'('+AExpression+')', Ctx);
              if PasExpr2.Valid and (PasExpr2.ResultValue <> nil) then begin
                PasExpr.Free;
                PasExpr := PasExpr2;
                ResValue := PasExpr.ResultValue;
              end
              else
                PasExpr2.Free;
            end;
        end;
      end;
    end;


    if not FPrettyPrinter.PrintValue(AResText, ResValue, []) then
      exit;
    if CastName <> '' then AResText := CastName + AResText;
    //if PasExpr.ResultValue.Kind = skObject then
    //  ATypeInfo := TDBGType.Create(skObject, ResTypeName)
    //else
      ATypeInfo := TDBGType.Create(skClass, ResTypeName);
    ATypeInfo.Value.AsString := AResText;

    if not(defFullTypeInfo in EvalFlags) then exit;
    for i := 0 to ResValue.MemberCount - 1 do begin
      m := ResValue.Member[i];
      if m = nil then Continue; // Todo: procedures.
      case m.Kind of
        skProcedure, skFunction: ; //  DBGType := TGDBType.Create(skProcedure, TGDBTypes.CreateFromCSV(Params))
        else
          begin
            DBGType := TGDBType.Create(skSimple, ResTypeName(m));
            FPrettyPrinter.PrintValue(s2, m, []);
            DBGType.Value.AsString := s2;
            n := '';
            if m.DbgSymbol <> nil then n := m.DbgSymbol.Name;
            s := '';
            if m.ContextTypeInfo <> nil then s := m.ContextTypeInfo.Name;
// TODO visibility // flags virtual, constructor
            f := TDBGField.Create(n, DBGType, flPublic, [], s);
            ATypeInfo.Fields.Add(f);
          end;
      end;
    end;
  end;

  procedure DoArray;
  begin
    if not FPrettyPrinter.PrintValue(AResText, ResValue, []) then
      exit;
    ATypeInfo := TDBGType.Create(skArray, ResTypeName);
    ATypeInfo.Value.AsString := AResText;
    //ATypeInfo.Len;
    //ATypeInfo.BoundLow;
    //ATypeInfo.BoundHigh;
  end;

begin
  Result := False;
  ATypeInfo := nil;
  if AWatchValue <> nil then begin
    EvalFlags := AWatchValue.EvaluateFlags;
    AExpression := AWatchValue.Expression;
    //FMemReader.FThreadId := AWatchValue.ThreadId;
    //FMemReader.FStackFrame := AWatchValue.StackFrame;
  //end
  //else begin
  //  FMemReader.FThreadId := CurrentThreadId;
  //  FMemReader.FStackFrame := CurrentStackFrame;
  end;

  if AWatchValue <> nil then
    Ctx := GetInfoContextForContext(AWatchValue.ThreadId, AWatchValue.StackFrame)
  else
    Ctx := GetInfoContextForContext(CurrentThreadId, CurrentStackFrame);
  if Ctx = nil then exit;

  FMemManager.DefaultContext := Ctx;
  FPrettyPrinter.AddressSize := ctx.SizeOfAddress;

  PasExpr := TFpPascalExpression.Create(AExpression, Ctx);
  try
    if not IsWatchValueAlive then exit;
    PasExpr.ResultValue; // trigger evaluate // and check errors
    if not IsWatchValueAlive then exit;

    if not PasExpr.Valid then begin
DebugLn(ErrorHandler.ErrorAsString(PasExpr.Error));
      if ErrorCode(PasExpr.Error) <> fpErrAnyError then begin
        Result := True;
        AResText := ErrorHandler.ErrorAsString(PasExpr.Error);;
        if AWatchValue <> nil then begin;
          AWatchValue.Value    := AResText;
          AWatchValue.Validity := ddsError;
        end;
        exit;
      end;
    end;

    if not (PasExpr.Valid and (PasExpr.ResultValue <> nil)) then
      exit; // TODO handle error
    if not IsWatchValueAlive then exit;

    ResValue := PasExpr.ResultValue;

    case ResValue.Kind of
      skUnit: ;
      skProcedure: ;
      skFunction: ;
      skPointer:  DoPointer;
      skInteger:  DoSimple;
      skCardinal: DoSimple;
      skBoolean:  DoSimple;
      skChar:     DoSimple;
      skFloat:    DoSimple;
      skString: ;
      skAnsiString: ;
      skCurrency: ;
      skVariant: ;
      skWideString: ;
      skEnum:      DoEnum;
      skEnumValue: DoSimple;
      skSet:       DoSet;
      skRecord:    DoRecord;
      skObject:    DoClass;
      skClass:     DoClass;
      skInterface: ;
      skArray:     DoArray;
    end;
    if not IsWatchValueAlive then exit;

    if ATypeInfo <> nil then begin
      Result := True;
      debugln(['TFPGDBMIWatches.InternalRequestData   GOOOOOOD ', AExpression]);
      if AWatchValue <> nil then begin;
        AWatchValue.Value    := AResText;
        AWatchValue.TypeInfo := ATypeInfo;
        if IsError(ResValue.LastError) then
          AWatchValue.Validity := ddsError
        else
          AWatchValue.Validity := ddsValid;
      end;
    end;

  finally
    PasExpr.Free;
    FMemManager.DefaultContext := nil;
  end;
end;

function TFpGDBMIDebugger.CreateCommandStartDebugging(AContinueCommand: TGDBMIDebuggerCommand): TGDBMIDebuggerCommandStartDebugging;
begin
  Result := TFpGDBMIDebuggerCommandStartDebugging.Create(Self, AContinueCommand);
end;

function TFpGDBMIDebugger.CreateLineInfo: TDBGLineInfo;
begin
  Result := TFpGDBMILineInfo.Create(Self);
end;

function TFpGDBMIDebugger.CreateWatches: TWatchesSupplier;
begin
  Result := TFPGDBMIWatches.Create(Self);
end;

class function TFpGDBMIDebugger.Caption: String;
begin
  Result := 'GNU debugger (with fpdebug)';
end;

constructor TFpGDBMIDebugger.Create(const AExternalDebugger: String);
begin
  FWatchEvalList := TList.Create;
  inherited Create(AExternalDebugger);
  CurrentDebugger := self;
end;

destructor TFpGDBMIDebugger.Destroy;
begin
  CurrentDebugger := nil;
  UnLoadDwarf;
  FWatchEvalList.Free;
  inherited Destroy;
end;

procedure Register;
begin
  RegisterDebugger(TFpGDBMIDebugger);

  MenuCmd := RegisterIDEMenuCommand(itmRunDebugging, 'fpGdbmiToggleGDB', 'Display GDB instead of FpDebug Watches', nil,
    @IDEMenuClicked);
  MenuCmd.AutoCheck := True;
  MenuCmd.Checked := False;

end;

end.

