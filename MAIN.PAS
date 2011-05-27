unit Main;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, EPStdCmp, ExtCtrls, Htmlview, RXCtrls, Nicetabs,
  Grids, Salat, RXSpin, StDate, RXClock, StrHlder, StDict, ReadFile,
  Menus, SpeedBar, EPGfxCmp, StDateSt, TimerLst, MMSystem, PMSetup, StAstro;

const                            
  StartYear   = 1995;
  Epoch       = 1950;
  YearsToShow = 15;
  AppName     = 'PrayerMinder';
  AppVersion  = '1.0e';

  { command message codes }
  CM_APPMSG_BASE  = CM_BASE + 1000;         { command message }
  CM_PRAYERMINDER = CM_APPMSG_BASE + 0;

  { message parameters }
  MP_SOUNDPRAYERALARM = 0;

type
  TPrayerDisplayType = (pdtToday, pdtTable, pdtCalendar);
  TMoonPhaseDisplay = (mpNone, mpNew, mpFirstQuarter, mpFull, mpLastQuarter);
  TfrmMain = class(TForm)
    dlgPrinterSetup: TPrinterSetupDialog;
    dlgPrint: TPrintDialog;
    barAppControl: TSpeedBar;
    imgAppName: TEPImage;
    btnDisplayToday: TRxSpeedButton;
    btnDisplayTable: TRxSpeedButton;
    btnDisplayCalendar: TRxSpeedButton;
    imgCorpLogo: TEPImage;
    brdBottom: TEPBorder;
    btnPrint: TRxSpeedButton;
    btnSetup: TRxSpeedButton;
    pmPrint: TPopupMenu;
    pmiPrintPrint: TMenuItem;
    pmiPrintPrintSetup: TMenuItem;
    pmiPrintBreak1: TMenuItem;
    pmiPrintSave: TMenuItem;
    nbkPages: TNotebook;
    vwrHTML: THTMLViewer;
    pnlScheduleControl: TPanel;
    pnlStatus: TPanel;
    gbxOneDay: TGroupBox;
    cbxTodayMonth: TComboBox;
    cbxTodayYear: TComboBox;
    calOneDay: TEPCalendar;
    tmlTimers: TRxTimerList;
    tmrEventShowTime: TRxTimerEvent;
    tmrEventShowCurPrayer: TRxTimerEvent;
    dlgSave: TSaveDialog;
    cbxMonth: TComboBox;
    spnMonth: TRxSpinButton;
    cbxYear: TComboBox;
    lblCityName: TRxLabel;
    pnlActivePrayer: TPanel;
    pnlCurTime: TPanel;
    grdTodayPrayers: TStringGrid;
    brdPrayers: TEPBorder;
    brdMoon: TEPBorder;
    cbxShowMoonPhase: TComboBox;
    lblMoonPhasePrompt: TLabel;
    lbxMoonPhaseDates: TRxCheckListBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure DisplayTypeButtonClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure cbxMonthChange(Sender: TObject);
    procedure cbxYearChange(Sender: TObject);
    procedure spnMonthTopClick(Sender: TObject);
    procedure spnMonthBottomClick(Sender: TObject);
    procedure vwrHTMLProcessing(Sender: TObject;
      ProcessingOn: Boolean);
    procedure calOneDayChange(Sender: TObject);
    procedure cbxTodayMonthChange(Sender: TObject);
    procedure cbxTodayYearChange(Sender: TObject);
    procedure tmrEventShowTimeTimer(Sender: TObject);
    procedure tmrEventShowCurPrayerTimer(Sender: TObject);
    procedure pmiPrintPrintClick(Sender: TObject);
    procedure pmiPrintPrintSetupClick(Sender: TObject);
    procedure pmiPrintSaveClick(Sender: TObject);
    procedure btnSetupClick(Sender: TObject);
    procedure cbxShowMoonPhaseChange(Sender: TObject);
  private
    FCurDate : TDateTime;
    FPrayerCalc : TPrayerCalc;
    FDisplayType : TPrayerDisplayType;
    FHTMLPages : TSectionedFileReader;
    FTodaysTimes : TPrayerTimes;
    FCurPrayerInfo : TCurPrayerInfo;
    FShowMoonPhase : TMoonPhaseDisplay;
    FMoonPhasesYear : Integer;

    procedure CreateHTMLTable(pszHTML : PChar);
    procedure CreateHTMLCalendar(pszHTML : PChar);
    procedure CalcPrayerTimes(strSaveToFile : String);
    procedure HandleAppMsg(var Msg : TMessage); message CM_PRAYERMINDER;
    procedure SetCurDate(ADate : TDateTime);
    procedure SetDisplayType(ADisplay : TPrayerDisplayType);
    procedure SetShowMoonPhase(ADisplay : TMoonPhaseDisplay);
    procedure ShowStatus(strMsg : String);
    procedure UpdateOneDayInfo;
  public
    property CurDate : TDateTime read FCurDate write SetCurDate;
    property DisplayType : TPrayerDisplayType read FDisplayType write SetDisplayType;
    property SalatCalc : TPrayerCalc read FPrayerCalc;
    property ShowMoonPhase : TMoonPhaseDisplay read FShowMoonPhase write SetShowMoonPhase;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.DFM}

uses MdString, VCLUtils, MaxMin, StStrS;

procedure DisposeObject(Data : Pointer); far;
begin
  TObject(Data).Free;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  M, Y : Integer;
  ePrayer : TPrayer;
begin
  FPrayerCalc := TPrayerCalc.Create;
  FPrayerCalc.ReadFromIni;
  FCurDate := SysUtils.Date;

  FHTMLPages := TSectionedFileReader.Create;
  FHTMLPages.SectionId := 'htmlData';
  FHTMLPages.FileName := ForceExtensionS(Application.ExeName, 'DAT');
  FHTMLPages.Process;

  cbxMonth.Items.Clear;
  cbxTodayMonth.Items.Clear;
  for M := 1 to 12 do begin
    cbxMonth.Items.Add(LongMonthNames[M]);
    cbxTodayMonth.Items.Add(LongMonthNames[M]);
  end;

  cbxYear.Items.Clear;
  cbxTodayYear.Items.Clear;
  for Y := StartYear to StartYear+YearsToShow do begin
    cbxYear.Items.Add(IntToStr(Y));
    cbxTodayYear.Items.Add(IntToStr(Y));
  end;

  grdTodayPrayers.Cells[0, 0] := 'Prayer';
  grdTodayPrayers.Cells[1, 0] := 'Start';
  grdTodayPrayers.Cells[2, 0] := 'Duration';

  for ePrayer := Low(TPrayer) to High(TPrayer) do
    grdTodayPrayers.Cells[0, Ord(ePrayer)+1] := SalatCalc.PrayerSettings.Names[ePrayer];

  tmrEventShowTimeTimer(Self);
  tmrEventShowCurPrayerTimer(Self);
  calOneDay.CalendarDate := SysUtils.Date;
  DisplayType := pdtToday;
end;

procedure TfrmMain.FormActivate(Sender: TObject);
const
  FirstTime : Boolean = True;
begin
  if FirstTime then begin
    FirstTime := False;
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FPrayerCalc.WriteToIni;
  FPrayerCalc.Free;
  FHTMLPages.Free;
end;

procedure TfrmMain.CreateHTMLCalendar(pszHTML : PChar);
{type
  TEPDayOfWeek = (epdSunday, epdMonday, epdTuesday, epdWednesday, epdThursday,
                  epdFriday, epdSaturday);}
const
  BufSize = 32767;
var
  pszTimeBuf : PChar;
  ThisMonth : Word;
  Row, Col  : Integer;
  StartOfWeek : TEPDayOfWeek;
  D, M, Y : Word;

  procedure AddDateCell(CellDate : TDateTime; pszStrBuf : PChar);
  var
    pszTimes : array[0..2048] of Char;
  begin
    DecodeDate(CellDate, Y, M, D);
    if ThisMonth <> M then
      StrCat(pszStrBuf, FHTMLPages.GetSection('CalendarCellNoDataFmt'))
    else begin
      StrCopy(pszTimes, FHTMLPages.GetSection('CalendarCellDataFmt'));
      ReplaceWithStr(pszTimes, '${calDayNum}', IntToStr(D));
      SalatCalc.CalcOneDayStr(CellDate, pszTimes);
      StrCat(pszStrBuf, pszTimes);
    end;
  end;

  function GetDates(ACol, ARow: Integer): TDateTime;
  var
    DayNum: Integer;
    LYear, LMonth, LDay: Word;
  begin
    Result := -1;
    if (ARow > 0) then
      begin
        DecodeDate(FCurDate, LYear, LMonth, LDay);
        DayNum := (ACol + (ARow * 7) - 6) - ((SysUtils.DayOfWeek(EncodeDate(LYear, LMonth, 1)) -
                   Ord(StartOfWeek) + 6) mod 7);
        Result := EncodeDate(LYear, LMonth, 1) + DayNum - 1
      end;
  end;

begin
  GetMem(pszTimeBuf, BufSize);
  pszTimeBuf[0] := #0;

  StartOfWeek := epdSunday;
  DecodeDate(FCurDate, Y, ThisMonth, D);

  for Row := 1 to 6 do begin
    StrCat(pszTimeBuf, '<tr>');
    for Col := 0 to 6 do
      AddDateCell(GetDates(Col, Row), pszTimeBuf);
    StrCat(pszTimeBuf, '</tr>');
  end;

  StrCopy(pszHTML, FHTMLPages.GetSection('CalendarPageFmt'));
  Replace(pszHTML, '${pmCalendarPrayerCells}', pszTimeBuf);

  FreeMem(pszTimeBuf, BufSize);
end;

procedure TfrmMain.CreateHTMLTable(pszHTML : PChar);
const
  BufSize = 16384;
var
  pszTimeBuf : PChar;
begin
  GetMem(pszTimeBuf, BufSize);
  pszTimeBuf[0] := #0;

  SalatCalc.CalcOneMonthStr(CurDate, FHTMLPages.GetSection('TableRowFmt'), pszTimeBuf);

  StrCopy(pszHTML, FHTMLPages.GetSection('TablePageFmt'));
  Replace(pszHTML, '${pmTablePrayerRows}', pszTimeBuf);

  FreeMem(pszTimeBuf, BufSize);
end;

procedure TfrmMain.CalcPrayerTimes(strSaveToFile : String);
const
  BufSize = 32767;
var
  pszPageBuf : PChar;
  TextFile : System.Text;

  procedure DoReplacements;
  begin
    SalatCalc.DoVarReplacements(pszPageBuf);
    ReplaceWithStr(pszPageBuf, '${pmMonthYear}', FormatDateTime('mmmm yyyy', CurDate));
    ReplaceWithStr(pszPageBuf, '${pmAppName}', AppName);
    ReplaceWithStr(pszPageBuf, '${pmAppVersion}', AppVersion);
    ReplaceWithStr(pszPageBuf, '${pmCalcOnDateLongFmt}', FormatDateTime('dddd, mmmm d, yyyy', SysUtils.Date));
  end;

begin
  if not (FDisplayType in [pdtTable, pdtCalendar]) then
    Exit;

  ShowStatus('Calculating...');
  GetMem(pszPageBuf, BufSize);
  pszPageBuf[0] := #0;

  case FDisplayType of
    pdtToday : ;
    pdtTable : CreateHTMLTable(pszPageBuf);
    pdtCalendar : CreateHTMLCalendar(pszPageBuf);
  end;

  DoReplacements;
  if strSaveToFile = '' then
    vwrHTML.LoadFromBuffer(pszPageBuf, StrLen(pszPageBuf))
  else begin
    System.Assign(TextFile, strSaveToFile);
    System.Rewrite(TextFile);
    System.WriteLn(TextFile, pszPageBuf);
    System.Close(TextFile);
  end;
  FreeMem(pszPageBuf, BufSize);
  ShowStatus('');
end;

procedure TfrmMain.HandleAppMsg(var Msg : TMessage);
var
  SoundFile : String;
begin
  case Msg.wParam of
    MP_SOUNDPRAYERALARM :
      begin
        SoundFile := ForceExtensionS(Application.ExeName, 'WAV');
        SndPlaySound(StringToPChar(SoundFile), SND_ASYNC);
        MessageDlg('It is now time for '+SalatCalc.PrayerSettings.Names[FCurPrayerInfo.Prayer]+' Prayers.',
                   mtInformation, [mbOk], 0);
      end;
  end;
end;

procedure TfrmMain.SetCurDate(ADate : TDateTime);
var
  Y, M, D : Word;
begin
  FCurDate := ADate;
  DecodeDate(FCurDate, Y, M, D);
  cbxMonth.ItemIndex := M-1;
  cbxYear.ItemIndex := Y-StartYear;
  cbxMonth.Update;
  cbxYear.Update;

  CalcPrayerTimes('');
end;

procedure TfrmMain.UpdateOneDayInfo;
var
  Times : TPrayerTimes;
  Y, M, D : Word;
  strCityInfo : String;

  function Duration(Earlier, Later : TStTime; ShowMins : Boolean) : String;
  var
    H, M, S : Byte;
  begin
    TimeDiff(Earlier, Later, H, M, S);
    FmtStr(Result, '%.2dh %.2dm', [H, M]);
  end;

begin
  FmtStr(strCityInfo, '%s (Latitude %s, Longitude %s, TZ %s)',
                      [SalatCalc.EarthPos.City, SalatCalc.EarthPos.Latitude.DegreesMinsStr,
                       SalatCalc.EarthPos.Longitude.DegreesMinsStr,
                       SalatCalc.EarthPos.TimeDelta.TimeZoneStr]);
  lblCityName.Caption := strCityInfo;

  cbxTodayMonth.ItemIndex := calOneDay.Month-1;
  cbxTodayYear.ItemIndex := calOneDay.Year-StartYear;
  gbxOneDay.Caption := FormatDateTime('dddd, mmmm d, yyyy', calOneDay.CalendarDate);
  SalatCalc.CalcOneDay(calOneDay.CalendarDate, Times);

  grdTodayPrayers.Cells[1, 1] := StTimeToAmPmString('hh:mm', Times[prFajr], True);
  grdTodayPrayers.Cells[1, 2] := StTimeToAmPmString('hh:mm', Times[prSunrise], True);
  grdTodayPrayers.Cells[1, 3] := StTimeToAmPmString('hh:mm', Times[prZuhr], True);
  grdTodayPrayers.Cells[1, 4] := StTimeToAmPmString('hh:mm', Times[prAsr], True);
  grdTodayPrayers.Cells[1, 5] := StTimeToAmPmString('hh:mm', Times[prMaghrib], True);
  grdTodayPrayers.Cells[1, 6] := StTimeToAmPmString('hh:mm', Times[prIshaa], True);

  grdTodayPrayers.Cells[2, 1] := Duration(Times[prFajr], Times[prSunrise], True);
  grdTodayPrayers.Cells[2, 2] := Duration(Times[prSunrise], Times[prZuhr], True);
  grdTodayPrayers.Cells[2, 3] := Duration(Times[prZuhr], Times[prAsr], True);
  grdTodayPrayers.Cells[2, 4] := Duration(Times[prAsr], Times[prMaghrib], True);
  grdTodayPrayers.Cells[2, 5] := Duration(Times[prMaghrib], Times[prIshaa], True);
  grdTodayPrayers.Cells[2, 6] := Duration(Times[prIshaa], Times[prFajr], False);
end;

procedure TfrmMain.SetDisplayType(ADisplay : TPrayerDisplayType);
begin
  FDisplayType := ADisplay;
  btnPrint.Visible := ADisplay in [pdtTable, pdtCalendar];

  case ADisplay of
    pdtToday    : begin
        UpdateOneDayInfo;
        nbkPages.PageIndex := 0;
        btnDisplayToday.Down := True;
      end;
    pdtTable,
    pdtCalendar : begin
        nbkPages.PageIndex := 1;
        CurDate := CurDate;
        btnDisplayTable.Down := ADisplay = pdtTable;
        btnDisplayCalendar.Down := ADisplay = pdtCalendar;
      end;
  end;
end;

procedure TfrmMain.SetShowMoonPhase(ADisplay : TMoonPhaseDisplay);
type
  TLunarCalcFunc = function(D : TStDate) : TStLunarRecord;
var
  bFirstUnchecked : Boolean;

  procedure AddDateTime(DT : TStDateTimeRec);
  var
    nMostRecentIdx : Integer;
  begin
    if DT.D = BadDate then
      Exit;

    nMostRecentIdx :=
      lbxMoonPhaseDates.Items.Add(StDateToDateString('mm/dd/yy', DT.D, True) + ' ' +
                                  StTimeToAmPmString('hh:mm', DT.T, True)+ ' UT');

    if DT.D < CurrentDate then begin
      lbxMoonPhaseDates.Checked[nMostRecentIdx] := True;
      lbxMoonPhaseDates.EnabledItem[nMostRecentIdx] := False;
    end else
      if bFirstUnchecked then begin
        lbxMoonPhaseDates.ItemIndex := nMostRecentIdx;
        lbxMoonPhaseDates.TopIndex := nMostRecentIdx;
        bFirstUnchecked := False;
      end;
  end;

  procedure DoLunarCalc(CalcFunc : TLunarCalcFunc);
  var
    LR : TStLunarRecord;
    nMonth : Integer;
    LunarCalcDate : TStDate;
  begin
    lbxMoonPhaseDates.Items.BeginUpdate;
    bFirstUnchecked := True;

    for nMonth := 1 to 12 do begin
      LunarCalcDate := DMYToStDate(1, nMonth, FMoonPhasesYear, Epoch);

      LR := CalcFunc(LunarCalcDate);
      AddDateTime(LR.T[0]);
      AddDateTime(LR.T[1]);
    end;

    LunarCalcDate := DMYToStDate(1, 1, Succ(FMoonPhasesYear), Epoch);
    LR := CalcFunc(LunarCalcDate);
    AddDateTime(LR.T[0]);
    AddDateTime(LR.T[1]);
    lbxMoonPhaseDates.Items.EndUpdate;
  end;

begin
  if (calOneDay.Year = FMoonPhasesYear) and (FShowMoonPhase = ADisplay) then
    Exit;

  FShowMoonPhase := ADisplay;
  cbxShowMoonPhase.ItemIndex := Ord(ADisplay);
  lbxMoonPhaseDates.Items.Clear;
  FMoonPhasesYear := calOneDay.Year;

  case ADisplay of
    mpNone : FMoonPhasesYear := 0;
    mpNew : DoLunarCalc(NewMoon);
    mpFirstQuarter : DoLunarCalc(FirstQuarter);
    mpFull : DoLunarCalc(FullMoon);
    mpLastQuarter : DoLunarCalc(LastQuarter);
  end;
end;

procedure TfrmMain.ShowStatus(strMsg : String);
begin
  pnlStatus.Caption := strMsg;
  pnlStatus.Update;
end;

procedure TfrmMain.DisplayTypeButtonClick(Sender: TObject);
begin
  DisplayType := TPrayerDisplayType((Sender as TRxSpeedButton).Tag);
end;

procedure TfrmMain.cbxMonthChange(Sender: TObject);
var
  Y, M, D : Word;
begin
  DecodeDate(CurDate, Y, M, D);
  M := cbxMonth.ItemIndex+1;
  D := 1;
  CurDate := EncodeDate(Y, M, D);
end;

procedure TfrmMain.cbxYearChange(Sender: TObject);
var
  Y, M, D : Word;
begin
  DecodeDate(CurDate, Y, M, D);
  Y := cbxYear.ItemIndex+StartYear;
  D := 1;
  CurDate := EncodeDate(Y, M, D);
end;

procedure TfrmMain.spnMonthTopClick(Sender: TObject);
var
  Y, M, D : Word;
begin
  DecodeDate(CurDate, Y, M, D);
  if M = 1 then
    Exit;

  Dec(M);
  D := 1;
  CurDate := EncodeDate(Y, M, D);
end;

procedure TfrmMain.spnMonthBottomClick(Sender: TObject);
var
  Y, M, D : Word;
begin
  DecodeDate(CurDate, Y, M, D);
  if M = 12 then
    Exit;

  Inc(M);
  D := 1;
  CurDate := EncodeDate(Y, M, D);
end;

procedure TfrmMain.vwrHTMLProcessing(Sender: TObject;
  ProcessingOn: Boolean);
begin
  if ProcessingOn then
    ShowStatus('Displaying...')
  else
    ShowStatus('');
end;

procedure TfrmMain.calOneDayChange(Sender: TObject);
begin
  UpdateOneDayInfo;
  ShowMoonPhase := ShowMoonPhase; { force an update on the year }
end;

procedure TfrmMain.cbxTodayMonthChange(Sender: TObject);
begin
  calOneDay.Month := cbxTodayMonth.ItemIndex+1;
end;

procedure TfrmMain.cbxTodayYearChange(Sender: TObject);
begin
  calOneDay.Year := cbxTodayYear.ItemIndex+StartYear;
end;

procedure TfrmMain.tmrEventShowTimeTimer(Sender: TObject);
begin
  pnlCurTime.Caption := FormatDateTime('h:mma/p', Now);
end;

procedure TfrmMain.tmrEventShowCurPrayerTimer(Sender: TObject);
var
  strActivePrayer : String;
  CurPrayerInfo : TCurPrayerInfo;
  GridRect : TGridRect;
begin
  SalatCalc.CalcOneDay(Date, FTodaysTimes);
  SalatCalc.FindPrayer(FTodaysTimes, CurPrayerInfo);

  FmtStr(strActivePrayer, '%s [%s in %d:%.2d]',
         [SalatCalc.PrayerSettings.Names[CurPrayerInfo.Prayer],
          SalatCalc.PrayerSettings.Names[CurPrayerInfo.NextPrayer],
          CurPrayerInfo.HoursRemaining, CurPrayerInfo.MinutesRemaining]);
  pnlActivePrayer.Caption := strActivePrayer;

  GridRect.Left := 0;
  GridRect.Right := 2;
  GridRect.Top := Ord(CurPrayerInfo.Prayer)+1;
  GridRect.Bottom := GridRect.Top;
  grdTodayPrayers.Selection := GridRect;

  if FCurPrayerInfo.Calculated and (FCurPrayerInfo.Prayer <> CurPrayerInfo.Prayer) then
    PostMessage(Handle, CM_PRAYERMINDER, MP_SOUNDPRAYERALARM, 0);

  FCurPrayerInfo := CurPrayerInfo;
end;

procedure TfrmMain.pmiPrintPrintClick(Sender: TObject);
begin
  if dlgPrint.Execute then
    vwrHTML.Print(1, 9999);
end;

procedure TfrmMain.pmiPrintPrintSetupClick(Sender: TObject);
begin
  dlgPrinterSetup.Execute;
end;

procedure TfrmMain.pmiPrintSaveClick(Sender: TObject);
begin
  if dlgSave.Execute then
    CalcPrayerTimes(dlgSave.FileName);
end;

procedure TfrmMain.btnSetupClick(Sender: TObject);
begin
  frmPrayerMinderSettings.SalatCalc := SalatCalc;
  if frmPrayerMinderSettings.ShowModal = mrOk then begin
    Application.ProcessMessages;
    FillChar(FCurPrayerInfo, SizeOf(FCurPrayerInfo), 0);  { make sure erroneous alarm doesn't occur }
    DisplayType := DisplayType;  { force an update }
  end;
end;

procedure TfrmMain.cbxShowMoonPhaseChange(Sender: TObject);
begin
  ShowMoonPhase := TMoonPhaseDisplay(cbxShowMoonPhase.ItemIndex);
end;

end.
