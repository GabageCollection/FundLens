; FundLens Windows installer (Inno Setup 6).
;
; Input : apps/fundlens_windows/build/windows/x64/runner/Release
;         (Flutter release bundle with dist/engine/fundlens_engine staged
;         into it as fundlens_engine/ by tools/build_windows_release.ps1)
; Output: dist/installer/FundLens-Setup.exe
;
; Properties:
; - Per-user install by default (no admin rights, no Program Files writes).
; - Start Menu shortcut by default; Desktop shortcut optional.
; - Visual C++ 2015-2022 x64 runtime prerequisite: installed silently when
;   missing, if assets\vc_redist.x64.exe has been placed next to this script
;   (download it from https://aka.ms/vs/17/release/vc_redist.x64.exe).
; - User data lives only under %APPDATA%\FundLens; the installer never
;   writes user data into the install directory.
; - Normal uninstall leaves %APPDATA%\FundLens intact; deleting it requires
;   ticking an explicit checkbox on a separate confirmation dialog.

#define AppName "FundLens"
#define AppVersion "1.0.0"
#define AppPublisher "FundLens"
#define ReleaseDir "..\apps\fundlens_windows\build\windows\x64\runner\Release"

[Setup]
AppId={{7C4E2A91-3B6D-4F58-9E21-5D8C0A6B4F73}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
; Per-user by default: lowest privileges, install under the user's
; Local\Programs directory, never Program Files.
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir=..\dist\installer
OutputBaseFilename=FundLens-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#AppName}

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#ifexist "assets\vc_redist.x64.exe"
Source: "assets\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
#endif
Source: "assets\LICENSES.txt"; DestDir: "{app}"

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\FundLens.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\FundLens.exe"; Tasks: desktopicon

[Run]
#ifexist "assets\vc_redist.x64.exe"
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; \
  StatusMsg: "Installing Visual C++ runtime..."; Check: VCRedistNeeded
#endif
Filename: "{app}\FundLens.exe"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[Code]
// The Visual C++ 2015-2022 x64 runtime registers its presence here.
function VCRedistInstalled: Boolean;
var
  Installed: Cardinal;
begin
  Result := RegQueryDWordValue(HKLM,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Installed', Installed) and (Installed = 1);
end;

function VCRedistNeeded: Boolean;
begin
  Result := not VCRedistInstalled;
  if not Result then Exit;
  // If the redistributable was not bundled we cannot install it; warn once
  // so the user can install it manually.
  if not FileExists(ExpandConstant('{tmp}\vc_redist.x64.exe')) then
    MsgBox('The Microsoft Visual C++ 2015-2022 (x64) runtime appears to be missing.' #13#10
      + 'FundLens may fail to start without it. You can install it from:' #13#10
      + 'https://aka.ms/vs/17/release/vc_redist.x64.exe',
      mbInformation, MB_OK);
end;

// On uninstall, user data under %APPDATA%\FundLens is kept by default.
// Deleting it requires ticking an explicit checkbox on a separate
// confirmation form shown after files are removed.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Form: TSetupForm;
  CheckBox: TNewCheckBox;
  OkButton, CancelButton: TNewButton;
  DataDir: String;
begin
  if CurUninstallStep <> usPostUninstall then Exit;
  DataDir := ExpandConstant('{userappdata}\FundLens');
  if not DirExists(DataDir) then Exit;

  Form := CreateCustomForm(420, 140, False, False);
  try
    Form.Caption := 'FundLens user data';

    CheckBox := TNewCheckBox.Create(Form);
    CheckBox.Parent := Form;
    CheckBox.Left := 16;
    CheckBox.Top := 16;
    CheckBox.Width := Form.ClientWidth - 32;
    CheckBox.Height := 44;
    CheckBox.Caption := 'Also delete all FundLens user data' #13#10
      + '(' + DataDir + ')';
    CheckBox.Checked := False;

    OkButton := TNewButton.Create(Form);
    OkButton.Parent := Form;
    OkButton.Caption := 'OK';
    OkButton.ModalResult := mrOk;
    OkButton.Left := Form.ClientWidth - 180;
    OkButton.Top := Form.ClientHeight - 40;

    CancelButton := TNewButton.Create(Form);
    CancelButton.Parent := Form;
    CancelButton.Caption := 'Cancel';
    CancelButton.ModalResult := mrCancel;
    CancelButton.Left := Form.ClientWidth - 90;
    CancelButton.Top := Form.ClientHeight - 40;

    if (Form.ShowModal = mrOk) and CheckBox.Checked then
      DelTree(DataDir, True, True, True);
  finally
    Form.Free;
  end;
end;
