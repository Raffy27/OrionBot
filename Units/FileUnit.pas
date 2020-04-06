unit FileUnit;

interface

uses
  System.SysUtils, System.Classes,
  IOUtils,
  Basics, CommandUnit;

type
  TExplorer = class(TWorker)
  public
    procedure Execute; override;
  end;

implementation

uses NetUnit;

procedure TExplorer.Execute;
var
  P, S: String;
begin
  try
    if FParams.Values['command'] = 'Download' then
    Begin
      if Net.DownloadFile(FParams.Values['file'], FParams.Values['name']) then
        Net.SendResponse(R_SUCCESS, FID)
      else
        Net.SendResponse(E_GENERIC, FID);
    End
    else if FParams.Values['command'] = 'Upload' then
    Begin
      if FileExists(FParams.Values['file']) then
      Begin
        Net.SendFile(FParams.Values['file'], FID);
        Net.SendResponse(R_SUCCESS, FID);
      End
      else
        Net.SendResponse(E_GENERIC, FID);
    End
    else if FParams.Values['command'] = 'List' then
    Begin
      if FParams.Values['type'] = 'Dir' then
        for P in TDirectory.GetDirectories(FParams.Values['path']) do
          S := S + P + #10
      else
        for P in TDirectory.GetFiles(FParams.Values['path']) do
          S := S + P + #10;
      Net.SendResponse(S, FID);
    End
    else if FParams.Values['command'] = 'Open' then
    Begin
      Basics.Open(FParams.Values['file']);
      Net.SendResponse(R_SUCCESS, FID);
    End;
  except
    on E: Exception do
    Begin
      Dbg('File Error ' + E.ClassName + ': ' + E.Message, dError);
    End;
  end;
end;

end.
