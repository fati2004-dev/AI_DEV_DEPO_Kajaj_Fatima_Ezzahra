#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

#define MyAppName "sentiment-app"
#define MyAppPublisher "A. Larhlimi"
#define MyAppId "{{9E480D40-4496-44B7-9F8E-E7B2C7FBE5C6}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\sentiment-app
DefaultGroupName=sentiment-app
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
OutputDir=Output
OutputBaseFilename=sentiment-app-{#MyAppVersion}-setup
Compression=lzma2/fast
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=sentiment-app {#MyAppVersion}

[Tasks]
Name: "addtopath"; Description: "Ajouter sentiment au PATH de cet utilisateur"; Flags: checkedonce

[Files]
Source: "build\app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "LISEZMOI.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Analyser un avis"; Filename: "{cmd}"; Parameters: "/K """"{app}\sentiment.cmd"" --help"""; WorkingDir: "{app}"
Name: "{autoprograms}\Désinstaller sentiment-app"; Filename: "{uninstallexe}"

[Code]
const
  WM_SETTINGCHANGE = $001A;

function NormalizePathEntry(Value: string): string;
begin
  Result := Lowercase(Value);
  while (Length(Result) > 3) and (Result[Length(Result)] = '\') do
    Delete(Result, Length(Result), 1);
end;

procedure BroadcastEnvironmentChange;
begin
  SendMessage(HWND_BROADCAST, WM_SETTINGCHANGE, 0, 'Environment');
end;

procedure AddApplicationToPath;
var
  ExistingPath, ApplicationPath: string;
begin
  if not WizardIsTaskSelected('addtopath') then
    exit;

  ApplicationPath := ExpandConstant('{app}');
  if not RegQueryStringValue(HKCU, 'Environment', 'Path', ExistingPath) then
    ExistingPath := '';

  if Pos(';' + NormalizePathEntry(ApplicationPath) + ';',
         ';' + NormalizePathEntry(ExistingPath) + ';') = 0 then begin
    if ExistingPath <> '' then
      ExistingPath := ExistingPath + ';';
    RegWriteExpandStringValue(HKCU, 'Environment', 'Path', ExistingPath + ApplicationPath);
    BroadcastEnvironmentChange;
  end;
end;

procedure RemoveApplicationFromPath;
var
  ExistingPath, ApplicationPath, Entry, UpdatedPath, RemainingPath: string;
  I: Integer;
begin
  ApplicationPath := ExpandConstant('{app}');
  if not RegQueryStringValue(HKCU, 'Environment', 'Path', ExistingPath) then
    exit;

  UpdatedPath := '';
  RemainingPath := ExistingPath;
  while RemainingPath <> '' do begin
    I := Pos(';', RemainingPath);
    if I = 0 then begin
      Entry := Trim(RemainingPath);
      RemainingPath := '';
    end else begin
      Entry := Trim(Copy(RemainingPath, 1, I - 1));
      Delete(RemainingPath, 1, I);
    end;
    if NormalizePathEntry(Entry) <> NormalizePathEntry(ApplicationPath) then begin
      if UpdatedPath <> '' then
        UpdatedPath := UpdatedPath + ';';
      UpdatedPath := UpdatedPath + Entry;
    end;
  end;

  if ExistingPath <> UpdatedPath then begin
    RegWriteExpandStringValue(HKCU, 'Environment', 'Path', UpdatedPath);
    BroadcastEnvironmentChange;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    AddApplicationToPath;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    RemoveApplicationFromPath;
end;
