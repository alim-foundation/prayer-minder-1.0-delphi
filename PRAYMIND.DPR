program Praymind;

uses
  Forms,
  Main in 'MAIN.PAS' {frmMain},
  Readfile in '\PROJECTS\DELPHI\16-BIT\READFILE.PAS',
  Pmsetup in 'PMSETUP.PAS' {frmPrayerMinderSettings};

{$R *.RES}

begin
  Application.CreateForm(TfrmMain, frmMain);
  Application.CreateForm(TfrmPrayerMinderSettings, frmPrayerMinderSettings);
  Application.Run;
end.
