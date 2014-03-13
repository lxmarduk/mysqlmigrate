unit FormMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqldb, mysql55conn, FileUtil, Forms, Controls, Graphics,
  Dialogs, StdCtrls, DBCtrls, CheckLst, Spin, ComCtrls, Buttons, Menus;

type

  { TMainFrom }

  TMainFrom = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    chlDatabases: TCheckListBox;
    chlUsers: TCheckListBox;
    edSrcHost: TComboBox;
    edDstPass: TEdit;
    edDstHost: TComboBox;
    edSrcUser: TEdit;
    edSrcPass: TEdit;
    edDstUser: TEdit;
    Label1: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    Memo1: TMemo;
    dbPopup: TPopupMenu;
    miDeselectAllUsers: TMenuItem;
    miSelectAllUsers: TMenuItem;
    miDeselectAllDB: TMenuItem;
    miSelectAllDB: TMenuItem;
    DestinationQ: TSQLQuery;
    DestinationT: TSQLTransaction;
    DestinationDB: TMySQL55Connection;
    usersPopup: TPopupMenu;
    ProgressBar1: TProgressBar;
    SourceDB: TMySQL55Connection;
    SourceQ: TSQLQuery;
    SourceT: TSQLTransaction;
    reloadDatabases: TSpeedButton;
    reloadUsers: TSpeedButton;
    spSrcPort: TSpinEdit;
    spDstPort: TSpinEdit;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure miDeselectAllDBClick(Sender: TObject);
    procedure miDeselectAllUsersClick(Sender: TObject);
    procedure miSelectAllDBClick(Sender: TObject);
    procedure miSelectAllUsersClick(Sender: TObject);
    procedure reloadDatabasesClick(Sender: TObject);
    procedure reloadUsersClick(Sender: TObject);
  private
    { private declarations }

    procedure Log(s: string);

    procedure LoadDatabases;
    procedure LoadUsers;
    function ConnectToSource: boolean;
    procedure DisconnectSource;

    function ConnectToDestination: boolean;
    procedure DisconnectDestination;

    procedure ExportDB(dbName: string);
    procedure ExportUser(grantQ: TStringList);
    function GetUserGrants(user: string; host: string): TStringList;

    function GetCheckedItemsCount(c: TCheckListBox): integer;
  public
    { public declarations }
  end;

var
  MainFrom: TMainFrom;
  log_file: Text;

implementation

{$R *.lfm}

{ TMainFrom }

procedure TMainFrom.FormCreate(Sender: TObject);
begin
  try
    edSrcHost.Items.Add(edSrcHost.Text);
    edDstHost.Items.Add(edSrcHost.Text);
    ConnectToSource;
    LoadDatabases;
    LoadUsers;
    DisconnectSource;
  except
    exit;
  end;
end;

procedure TMainFrom.FormDestroy(Sender: TObject);
begin

end;

procedure TMainFrom.miDeselectAllDBClick(Sender: TObject);
begin
  chlDatabases.CheckAll(cbUnchecked);
end;

procedure TMainFrom.miDeselectAllUsersClick(Sender: TObject);
begin
  chlUsers.CheckAll(cbUnchecked);
end;

procedure TMainFrom.miSelectAllDBClick(Sender: TObject);
begin
  chlDatabases.CheckAll(cbChecked);
end;

procedure TMainFrom.miSelectAllUsersClick(Sender: TObject);
begin
  chlUsers.CheckAll(cbChecked);
end;

procedure TMainFrom.Button2Click(Sender: TObject);
var
  SelectedDBCount: integer;
  ItemsCount: integer;
  i: integer;
begin
  try
    SelectedDBCount := GetCheckedItemsCount(chlDatabases);
    if SelectedDBCount = 0 then
    begin
      exit;
    end;
    ItemsCount := chlDatabases.Items.Count - 1;
    ProgressBar1.Max := SelectedDBCount;
    ProgressBar1.Position := 0;
    try
      if not ConnectToDestination then
      begin
        Log('Cannot connect to destination server.');
        exit;
      end;
      for i := 0 to ItemsCount do
      begin
        if (chlDatabases.Checked[i]) then
        begin
          ExportDB(chlDatabases.Items[i]);
          Log('Exported ' + chlDatabases.Items[i]);
          ProgressBar1.Position := ProgressBar1.Position + 1;
          Application.ProcessMessages;
        end;
      end;
      DisconnectDestination;
    except
      on e: Exception do
      begin
        Log(e.Message);
        DestinationT.Rollback;
      end;
    end;
  except
    on e: Exception do
    begin
      Log(e.Message);
      ProgressBar1.Position := 0;
      exit;
    end;
  end;
  ProgressBar1.Position := 0;
end;

procedure TMainFrom.Button1Click(Sender: TObject);
begin
  if (edDstHost.Items.IndexOf(edDstHost.Text) < 0) then
  begin
    edDstHost.Items.Add(edDstHost.Text);
  end;
  if (ConnectToDestination) then
  begin
    DisconnectDestination;
    Log('Connection working propertly.');
  end
  else
  begin
    Log('Fail to connect.');
  end;
end;

procedure TMainFrom.Button3Click(Sender: TObject);
var
  SelectedUsersCount: integer;
  ItemsCount: integer;
  i: integer;
  user, host, s: string;
begin
  try
    SelectedUsersCount := GetCheckedItemsCount(chlUsers);
    if SelectedUsersCount = 0 then
    begin
      exit;
    end;
    ItemsCount := chlUsers.Items.Count - 1;
    ProgressBar1.Max := SelectedUsersCount;
    ProgressBar1.Position := 0;
    try
      if not ConnectToDestination then
      begin
        Log('Cannot connect to destination server.');
        exit;
      end;
      for i := 0 to ItemsCount do
      begin
        if (chlUsers.Checked[i]) then
        begin
          s := chlUsers.Items[i];
          user := Copy(s, 0, Pos('@', s) - 1);
          host := Copy(s, Pos('@', s) + 1, Length(s));
          ExportUser(GetUserGrants(user, host));
          Log('Exported ' + chlUsers.Items[i]);
          ProgressBar1.Position := ProgressBar1.Position + 1;
          Application.ProcessMessages;
        end;
      end;
      DestinationQ.Close;
      DestinationQ.SQL.Text := 'FLUSH PRIVILEGES;';
      DestinationQ.ExecSQL;
      DestinationQ.Close;
      DisconnectDestination;
    except
      on e: Exception do
      begin
        Log(e.Message);
        DestinationT.Rollback;
      end;
    end;
  except
    on e: Exception do
    begin
      Log(e.Message);
      DestinationT.Rollback;
      exit;
    end;
  end;
  ProgressBar1.Position := 0;
end;

procedure TMainFrom.Button4Click(Sender: TObject);
begin
  if (edSrcHost.Items.IndexOf(edSrcHost.Text) < 0) then
  begin
    edSrcHost.Items.Add(edSrcHost.Text);
  end;
  if (ConnectToSource) then
  begin
    DisconnectSource;
    Log('Connection working propertly.');
  end
  else
  begin
    Log('Fail to connect.');
  end;
end;

procedure TMainFrom.reloadDatabasesClick(Sender: TObject);
begin
  try
    ConnectToSource;
    LoadDatabases;
    DisconnectSource;
  except
    exit;
  end;
end;

procedure TMainFrom.reloadUsersClick(Sender: TObject);
begin
  try
    ConnectToSource;
    LoadUsers;
    DisconnectSource;
  except
    exit;
  end;
end;

procedure TMainFrom.Log(s: string);
begin
  Memo1.Lines.Add(s);
  Memo1.CaretPos := Point(0, Memo1.Lines.Count - 1);
  WriteLn(log_file, s);
  Flush(log_file);
end;

procedure TMainFrom.LoadDatabases;
begin
  try
    SourceQ.SQL.Text := 'SHOW DATABASES;';
    SourceQ.Open;
    SourceQ.First;
    chlDatabases.Items.Clear;
    while not SourceQ.EOF do
    begin
      chlDatabases.Items.Add(SourceQ['Database']);
      Application.ProcessMessages;
      SourceQ.Next;
    end;
    SourceQ.Close;
  except
    on e: Exception do
    begin
      Log(e.Message);
      exit;
    end;
  end;
end;

procedure TMainFrom.LoadUsers;
begin
  try
    SourceQ.SQL.Text := 'SELECT user, host FROM mysql.user WHERE user != '''';';
    SourceQ.Open;
    SourceQ.First;
    chlUsers.Items.Clear;
    while not SourceQ.EOF do
    begin
      chlUsers.Items.Add(SourceQ['user'] + '@' + SourceQ['host']);
      Application.ProcessMessages;
      SourceQ.Next;
    end;
    SourceQ.Close;
  except
    on e: Exception do
    begin
      Log(e.Message);
      exit;
    end;
  end;
end;

function TMainFrom.ConnectToSource: boolean;
begin
  SourceDB.DatabaseName := 'mysql';
  SourceDB.UserName := edSrcUser.Text;
  SourceDB.Password := edSrcPass.Text;
  SourceDB.HostName := edSrcHost.Text;
  SourceDB.Port := spSrcPort.Value;

  Result := False;
  try
    Log('Connecting ' + SourceDB.HostName + ':' + IntToStr(SourceDB.Port));
    SourceDB.Connected := True;
    SourceT.Active := True;
    Log('Connected.');
    Result := True;
  except
    on e: Exception do
    begin
      Log(e.Message);
      MessageDlg('Error', 'Cannot connect to server.', mtError, [mbOK], 0);
      raise e;
    end;
  end;
end;

procedure TMainFrom.DisconnectSource;
begin
  SourceT.Active := False;
  SourceDB.Connected := False;
  Log('Disconnected.');
end;

function TMainFrom.ConnectToDestination: boolean;
begin
  DestinationDB.DatabaseName := 'mysql';
  DestinationDB.UserName := edDstUser.Text;
  DestinationDB.Password := edDstPass.Text;
  DestinationDB.HostName := edDstHost.Text;
  DestinationDB.Port := spDstPort.Value;

  Result := False;
  try
    Log('Connecting ' + DestinationDB.HostName + ':' + IntToStr(DestinationDB.Port));
    DestinationDB.Connected := True;
    DestinationT.Active := True;
    Log('Connected.');
    Result := True;
  except
    on e: Exception do
    begin
      Log(e.Message);
      MessageDlg('Error', 'Cannot connect to server.', mtError, [mbOK], 0);
      raise e;
    end;
  end;
end;

procedure TMainFrom.DisconnectDestination;
begin
  DestinationT.Commit;
  DestinationDB.Connected := False;
  DestinationT.Active := False;
  Log('Disconnected.');
end;

procedure TMainFrom.ExportDB(dbName: string);
begin
  DestinationQ.SQL.Text := 'CREATE DATABASE IF NOT EXISTS ''' + dbName + '''';
  try
    DestinationQ.ExecSQL;
    DestinationQ.Close;
  except
    on e: Exception do
    begin
      Log(e.Message);
      raise e;
    end;
  end;
end;

procedure TMainFrom.ExportUser(grantQ: TStringList);
var
  i: integer;
  s: string;
begin
  try
    Log('Exporting...');
    for i := 0 to grantQ.Count - 1 do
    begin
      s := grantQ[i];
      Log(s);
      DestinationQ.SQL.Text := s;
      DestinationQ.ExecSQL;
      DestinationQ.Close;
      Application.ProcessMessages;
    end;
  except
    on e: Exception do
    begin
      Log(e.Message);
      raise e;
    end;
  end;
end;

function TMainFrom.GetUserGrants(user: string; host: string): TStringList;
var
  s: string;
begin
  Result := TStringList.Create;
  SourceQ.SQL.Text := 'SHOW GRANTS FOR ''' + user + '''@''' + host + '''';
  try
    Log('Getting grants for ' + user + '@' + host);
    SourceQ.Open;
    SourceQ.First;
    while not SourceQ.EOF do
    begin
      s := SourceQ['Grants for ' + user + '@' + host + ''] + ';';
      Result.Add(s);
      Log(s);
      Application.ProcessMessages;
      SourceQ.Next;
    end;
    SourceQ.Close;
  except
    on e: Exception do
    begin
      Log(e.Message);
      exit;
    end;
  end;
end;

function TMainFrom.GetCheckedItemsCount(c: TCheckListBox): integer;
var
  i: integer;
  len: integer;
  r: integer;
begin
  r := 0;
  len := c.Items.Count - 1;
  for i := 0 to len do
  begin
    if c.Checked[i] then
    begin
      r := r + 1;
    end;
  end;
  Result := r;
end;

initialization

  AssignFile(log_file, StringReplace(StringReplace(DateTimeToStr(Now),
    ':', '_', [rfReplaceAll]), '/', '_', [rfReplaceAll]) + '.txt');
  Rewrite(log_file);

finalization

  CloseFile(log_file);

end.
