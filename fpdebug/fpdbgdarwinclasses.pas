unit FpDbgDarwinClasses;

{$mode objfpc}{$H+}
{$linkframework security}

interface

uses
  Classes,
  SysUtils,
  BaseUnix,
  FpDbgClasses,
  FpDbgLoader,
  DbgIntfBaseTypes,
  FpDbgLinuxExtra,
  FpDbgInfo,
  MacOSAll,
  FpDbgUtil,
  LazLoggerBase;

type
  x86_thread_state32_t = record
    __eax: cuint;
    __ebx: cuint;
    __ecx: cuint;
    __edx: cuint;
    __edi: cuint;
    __esi: cuint;
    __ebp: cuint;
    __esp: cuint;
    __ss: cuint;
    __eflags: cuint;
    __eip: cuint;
    __cs: cuint;
    __ds: cuint;
    __es: cuint;
    __fs: cuint;
    __gs: cuint;
  end;

type

  { TDbgDarwinProcess }

  TDbgDarwinProcess = class(TDbgProcess)
  private
    FStatus: cint;
    FProcessStarted: boolean;
    FTaskPort: mach_port_name_t;
    FThreadState: x86_thread_state32_t;
    function GetDebugAccessRights: boolean;
  protected
    function InitializeLoader: TDbgImageLoader; override;
  public
    class function StartInstance(AFileName: string; AParams: string): TDbgProcess; override;
    constructor Create(const AName: string; const AProcessID, AThreadID: Integer); override;

    function ReadData(const AAdress: TDbgPtr; const ASize: Cardinal; out AData): Boolean; override;
    function WriteData(const AAdress: TDbgPtr; const ASize: Cardinal; const AData): Boolean; override;

    function GetInstructionPointerRegisterValue: TDbgPtr; override;
    function GetStackBasePointerRegisterValue: TDbgPtr; override;

    function Continue(AProcess: TDbgProcess; AThread: TDbgThread; AState: TFPDState): boolean; override;
    function WaitForDebugEvent(out ProcessIdentifier: THandle): boolean; override;
    function ResolveDebugEvent(AThread: TDbgThread): TFPDEvent; override;
  end;

procedure RegisterDbgClasses;

implementation

type
  vm_map_t = mach_port_t;
  vm_offset_t = UIntPtr;
  vm_address_t = vm_offset_t;
  vm_size_t = UIntPtr;
  vm_prot_t = cint;
  mach_vm_address_t = uint64;
  mach_msg_Type_number_t = natural_t;
  mach_vm_size_t = uint64;
  task_t = mach_port_t;
  thread_act_t = mach_port_t;
  thread_act_array = array[0..255] of thread_act_t;
  thread_act_array_t = ^thread_act_array;
  thread_state_flavor_t = cint;
  thread_state_t = ^natural_t;

const
  x86_THREAD_STATE32    = 1;

  x86_THREAD_STATE32_COUNT: mach_msg_Type_number_t = sizeof(x86_thread_state32_t) div sizeof(cint);

function task_for_pid(target_tport: mach_port_name_t; pid: integer; var t: mach_port_name_t): kern_return_t; cdecl external name 'task_for_pid';
function mach_task_self: mach_port_name_t; cdecl external name 'mach_task_self';
function mach_error_string(error_value: mach_error_t): pchar; cdecl; external name 'mach_error_string';
function vm_protect(target_task: vm_map_t; adress: vm_address_t; size: vm_size_t; set_maximum: boolean_t; new_protection: vm_prot_t): kern_return_t; cdecl external name 'vm_protect';
function mach_vm_write(target_task: vm_map_t; address: mach_vm_address_t; data: vm_offset_t; dataCnt: mach_msg_Type_number_t): kern_return_t; cdecl external name 'mach_vm_write';
function mach_vm_read(target_task: vm_map_t; address: mach_vm_address_t; size: mach_vm_size_t; var data: vm_offset_t; var dataCnt: mach_msg_Type_number_t): kern_return_t; cdecl external name 'mach_vm_read';

function task_threads(target_task: task_t; var act_list: thread_act_array_t; var act_listCnt: mach_msg_type_number_t): kern_return_t; cdecl external name 'task_threads';
function thread_get_state(target_act: thread_act_t; flavor: thread_state_flavor_t; old_state: thread_state_t; var old_stateCnt: mach_msg_Type_number_t): kern_return_t; cdecl external name 'thread_get_state';

procedure RegisterDbgClasses;
begin
  OSDbgClasses.DbgProcessClass:=TDbgDarwinProcess;
end;

{ TDbgDarwinProcess }

function TDbgDarwinProcess.GetDebugAccessRights: boolean;
var
  authFlags: AuthorizationFlags;
  stat: OSStatus;
  author: AuthorizationRef;
  authItem: AuthorizationItem;
  authRights: AuthorizationRights;
begin
  result := false;
  authFlags := kAuthorizationFlagExtendRights or kAuthorizationFlagPreAuthorize or kAuthorizationFlagInteractionAllowed or ( 1 << 5);

  stat := AuthorizationCreate(nil, kAuthorizationEmptyEnvironment, authFlags, author);
  if stat <> errAuthorizationSuccess then
    begin
    debugln('Failed to create authorization. Authorization error: ' + inttostr(stat));
    exit;
    end;

  authItem.name:='system.privilege.taskport';
  authItem.flags:=0;
  authItem.value:=nil;
  authItem.valueLength:=0;

  authRights.count:=1;
  authRights.items:=@authItem;

  stat := AuthorizationCopyRights(author, authRights, kAuthorizationEmptyEnvironment, authFlags, nil);
  if stat <> errAuthorizationSuccess then
    begin
    debugln('Failed to get debug-(taskport)-privilege. Authorization error: ' + inttostr(stat));
    exit;
    end;
  result := true;
end;

function TDbgDarwinProcess.InitializeLoader: TDbgImageLoader;
begin
  result := TDbgImageLoader.Create(Name);
end;

constructor TDbgDarwinProcess.Create(const AName: string; const AProcessID, AThreadID: Integer);
var
  aKernResult: kern_return_t;
begin
  inherited Create(AName, AProcessID, AThreadID);

  LoadInfo;

  if DbgInfo.HasInfo
  then FSymInstances.Add(Self);

  GetDebugAccessRights;
  aKernResult:=task_for_pid(mach_task_self, AProcessID, FTaskPort);
  if aKernResult <> KERN_SUCCESS then
    begin
    DebugLn('Failed to get task for process '+IntToStr(AProcessID)+'. Probably insufficient rights to debug applications. Mach error: '+mach_error_string(aKernResult));
    end;
end;

class function TDbgDarwinProcess.StartInstance(AFileName: string; AParams: string): TDbgProcess;
var
  PID: TPid;
  stat: longint;
begin
  pid := FpFork;
  if PID=0 then
    begin
    // We are in the child-process
    fpPTrace(PTRACE_TRACEME, 0, nil, nil);
    FpExecve(AFileName, nil, nil);
    end
  else if PID<>-1 then
    begin
    sleep(100);
    result := TDbgDarwinProcess.Create(AFileName, Pid,-1);
    end;
end;

function TDbgDarwinProcess.ReadData(const AAdress: TDbgPtr;
  const ASize: Cardinal; out AData): Boolean;
var
  aKernResult: kern_return_t;
  cnt: mach_msg_Type_number_t;
  b: pointer;
begin
  result := false;

  aKernResult := mach_vm_read(FTaskPort, AAdress, ASize, PtrUInt(b), cnt);
  if aKernResult <> KERN_SUCCESS then
    begin
    DebugLn('Failed to read data at address '+FormatAddress(ProcessID)+'. Mach error: '+mach_error_string(aKernResult));
    Exit;
    end;
  System.Move(b^, AData, Cnt);
  result := true;
end;

function TDbgDarwinProcess.WriteData(const AAdress: TDbgPtr;
  const ASize: Cardinal; const AData): Boolean;
var
  aKernResult: kern_return_t;
begin
  result := false;
  aKernResult:=vm_protect(FTaskPort, PtrUInt(AAdress), ASize, boolean_t(false), 7 {VM_PROT_READ + VM_PROT_WRITE + VM_PROT_COPY});
  if aKernResult <> KERN_SUCCESS then
    begin
    DebugLn('Failed to call vm_protect for address '+FormatAddress(AAdress)+'. Mach error: '+mach_error_string(aKernResult));
    Exit;
    end;

  aKernResult := mach_vm_write(FTaskPort, AAdress, vm_offset_t(@AData), ASize);
  if aKernResult <> KERN_SUCCESS then
    begin
    DebugLn('Failed to write data at address '+FormatAddress(AAdress)+'. Mach error: '+mach_error_string(aKernResult));
    Exit;
    end;

  result := true;
end;

function TDbgDarwinProcess.GetInstructionPointerRegisterValue: TDbgPtr;
begin
  result := FThreadState.__eip;
end;

function TDbgDarwinProcess.GetStackBasePointerRegisterValue: TDbgPtr;
begin
  result := FThreadState.__ebp;

end;

function TDbgDarwinProcess.Continue(AProcess: TDbgProcess; AThread: TDbgThread;
  AState: TFPDState): boolean;
var
  e: integer;
begin
  fpseterrno(0);
{$ifdef linux}
  fpPTrace(PTRACE_CONT, ProcessID, nil, nil);
{$endif linux}
{$ifdef darwin}
  fpPTrace(PTRACE_CONT, ProcessID, pointer(1), nil);
{$endif darwin}
  writeln('Cont');
  e := fpgeterrno;
  if e <> 0 then
    begin
    writeln('Failed to continue process. Errcode: ',e);
    result := false;
    end
  else
    result := true;
end;

function TDbgDarwinProcess.WaitForDebugEvent(out ProcessIdentifier: THandle): boolean;
var
  aKernResult: kern_return_t;
  act_list: thread_act_array_t;
  act_listCtn: mach_msg_type_number_t;
  old_StateCnt: mach_msg_Type_number_t;
begin
  ProcessIdentifier:=FpWaitPid(-1, FStatus, 0);

  result := ProcessIdentifier<>-1;
  if not result then
    writeln('Failed to wait for debug event. Errcode: ', fpgeterrno)
  else
    begin
    // Read thread-information
    aKernResult := task_threads(FTaskPort, act_list, act_listCtn);
    if aKernResult <> KERN_SUCCESS then
      begin
      Log('Failed to call task_threads. Mach error: '+mach_error_string(aKernResult));
      end;

    old_StateCnt:=x86_THREAD_STATE32_COUNT;
    aKernResult:=thread_get_state(act_list^[0],x86_THREAD_STATE32, @FThreadState,old_StateCnt);
    if aKernResult <> KERN_SUCCESS then
      begin
      Log('Failed to call thread_get_state. Mach error: '+mach_error_string(aKernResult));
      end;
    writeln(Format('eip: %s, eax: %s, ebx: %s, ecx: %s, edx: %s',[FormatAddress(FThreadState.__eip), FormatAddress(FThreadState.__eax),FormatAddress(FThreadState.__ebx),FormatAddress(FThreadState.__ecx), FormatAddress(FThreadState.__edx)]));
    end
end;

function TDbgDarwinProcess.ResolveDebugEvent(AThread: TDbgThread): TFPDEvent;

  Function WIFSTOPPED(Status: Integer): Boolean;
  begin
    WIFSTOPPED:=((Status and $FF)=$7F);
  end;

begin
  if wifexited(FStatus) then
    begin
    SetExitCode(wexitStatus(FStatus));
    writeln('Exit');
    result := deExitProcess
    end
  else if WIFSTOPPED(FStatus) then
    begin
    writeln('Stopped ',FStatus, ' signal: ',wstopsig(FStatus));
    case wstopsig(FStatus) of
      SIGTRAP:
        begin
        if not FProcessStarted then
          begin
          result := deCreateProcess;
          FProcessStarted:=true;
          end
        else
          begin
          result := deBreakpoint;
          writeln('Breakpoint');
          end;
        end;
      SIGBUS:
        begin
        writeln('Received SIGBUS');
        result := deException;
        end;
      SIGINT:
        begin
        writeln('Received SIGINT');
        result := deException;
        end;
      SIGSEGV:
        begin
        writeln('Received SIGSEGV');
        result := deException;
        end;
    end; {case}
    end
  else if wifsignaled(FStatus) then
    writeln('ERROR: ', wtermsig(FStatus));
end;

end.
