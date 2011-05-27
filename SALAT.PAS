unit Salat;

interface

uses Classes, StDate, StAstro, StDateSt, SysUtils, StRegIni, WinProcs, Dialogs;

type
  TLatLong = class
  private
    FDegrees : Integer;
    FMinutes : Integer;

    function GetDegreesMinutes : Double;
    function GetRadians : Double;
    function GetDegreesMinsStr : String;

    function ExportToText : String;
    procedure ImportFromText(const strEncodedData : String);
  public
    procedure Assign(Source : TLatLong);

    property Degrees : Integer read FDegrees write FDegrees;
    property Minutes : Integer read FMinutes write FMinutes;
    property DegreesMinutes : Double read GetDegreesMinutes;
    property Radians : Double read GetRadians;
    property DegreesMinsStr : String read GetDegreesMinsStr;
    property CodedData : String read ExportToText write ImportFromText;
  end;

  TDaylSavingsCalc = (dscAuto, dscOff);
  TDaylSavingsSettings =
    record
      CalcType : TDaylSavingsCalc;
      StartDay, StartDayName, StartMonth,
      EndDay, EndDayName, EndMonth : Integer;
      AdjustHours, AdjustMinutes : Integer;
    end;

  TDaylSavingsInfo =
    record
      CalcYear : Integer;
      CalcSettings : TDaylSavingsSettings;
      StartDate : TStDate;
      EndDate : TStDate;
    end;

  TGMTTimeDelta = class
  private
    FHours : Integer;
    FMinutes : Integer;
    FSeconds : Integer;
    FDaylSavingsSettings : TDaylSavingsSettings;
    FDaylSavInfo : TDaylSavingsInfo;

    procedure CalcDaylSavInfo(Year : Integer);
    function GetTimeZoneStr : String;
    function ExportToText : String;
    procedure ImportFromText(const strEncodedData : String);
    procedure SetDaylSavings(ADaylSav : TDaylSavingsSettings);
  public
    procedure Assign(Source : TGMTTimeDelta);
    function Localize(ADate : TStDate; UniversalTime : TStTime) : TStTime;

    property CodedData : String read ExportToText write ImportFromText;
    property DaylSavings : TDaylSavingsSettings read FDaylSavingsSettings write SetDaylSavings;
    property Hours : Integer read FHours write FHours;
    property Minutes : Integer read FMinutes write FMinutes;
    property Seconds : Integer read FSeconds write FSeconds;
    property TimeZoneStr : String read GetTimeZoneStr;
  end;

  TEarthPos = class
  protected
    FLocation : String;
    FLatitude : TLatLong;
    FLongitude : TLatLong;
    FTimeDelta : TGMTTimeDelta;

    function ExportToText : String;
    procedure ImportFromText(const strEncodedData : String);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source : TEarthPos);

    property City : String read FLocation write FLocation;
    property Latitude : TLatLong read FLatitude;
    property Longitude : TLatLong read FLongitude;
    property TimeDelta : TGMTTimeDelta read FTimeDelta;
    property CodedData : String read ExportToText write ImportFromText;
  end;

  TQiblaDirection =
    record
      DegreesStr : String[20];
      DegreesMinutes : Double;
      Radians : Double;
    end;

  TPrayer = (prFajr, prSunrise, prZuhr, prAsr, prMaghrib, prIshaa);
  TPrayerTimes = array[TPrayer] of TStTime;
  TPrayerNames = array[TPrayer] of String[15];
  TPrayerSafetyDeltas = array[TPrayer] of Integer;

  TCurPrayerInfo =
    record
      Calculated : Boolean;
      Prayer : TPrayer;
      HoursRemaining : Word;
      MinutesRemaining : Word;
      NextPrayer : TPrayer;
      NextPrayerStart : TStTime;
    end;

  TPrayerSettings =
    record
      Names : TPrayerNames;
      Safety : TPrayerSafetyDeltas; { number of minutes to add (subtract) for safety }
      Fajr : Double;   { positive for by interval (minutes), negative for degrees above horizon }
      Asr : Integer;   { positive for interval (minutes), negative for shadow ratio, 0 for split }
      Ishaa : Double;  { positive for by interval (minutes), negative for degrees above horizon }
    end;

  TPrayerCalc = class
  protected
    FEarthPos : TEarthPos;
    FPrayerSettings : TPrayerSettings;
    FTimeStrFmt : String;

    procedure CalcOneDayPrim(ADate : TStDate; var Times : TPrayerTimes);
    procedure DoTimeReplacements(pszReplaceInStr : PChar; var Times : TPrayerTimes);
    procedure DoDateReplacements(pszReplaceInStr : PChar; ADate : TDateTime);
    function GetQiblaDirection : TQiblaDirection;
  public
    constructor Create;
    destructor Destroy; override;

    procedure ReadFromIni;
    procedure WriteToIni;

    procedure CalcOneDay(ADateTime : TDateTime; var Times : TPrayerTimes);
    procedure CalcOneDayStr(ADate : TDateTime; pszReplaceInStr : PChar);
    procedure CalcOneMonthStr(ADate : TDateTime; const pszOneRowFmt : PChar; pszMonthlyTimes : PChar);
    procedure DoVarReplacements(pszStrBuf : PChar);
    procedure FindPrayer(Times : TPrayerTimes; var CurPrayer : TCurPrayerInfo);
    function FormatTime(ATime : TStTime) : String;

    property EarthPos : TEarthPos read FEarthPos;
    property PrayerSettings : TPrayerSettings read FPrayerSettings write FPrayerSettings;
    property TimeStrFmt : String read FTimeStrFmt write FTimeStrFmt;
    property QiblaDirection : TQiblaDirection read GetQiblaDirection;
  end;

const
  Epoch = 1950;
  DefaultPrayerSettings : TPrayerSettings =
    (
      Names : ('Fajr', 'Shurooq', 'Dhurh', 'Asr', 'Maghrib', 'Ishaa');
      Safety : (0, 0, 0, 0, 0, 0);
      Fajr : -15;
      Asr : 0;
      Ishaa : -18
    );

  DefaultDaylSavings : TDaylSavingsSettings =
    (
      CalcType : dscAuto;
      StartDay : 1;
      StartDayName : 0;
      StartMonth : 4;
      EndDay : 0;
      EndDayName : 0;
      EndMonth : 10;
      AdjustHours : 1;
      AdjustMinutes : 0
    );

implementation

uses StUtils, MdString, VCLUtils, StStrS;

  procedure TLatLong.Assign(Source : TLatLong);
  begin
    Degrees := Source.Degrees;
    Minutes := Source.Minutes;
  end;

  function TLatLong.GetDegreesMinutes : Double;
  begin
    Result := SignL(FDegrees) * (Abs(FDegrees) + (FMinutes/60));
  end;

  function TLatLong.GetRadians : Double;
  begin
    Result := DegreesMinutes * (PI/180);
  end;

  function TLatLong.GetDegreesMinsStr : String;
  begin
    Result := IntToStr(FDegrees)+'° '+IntToStr(FMinutes)+'''';
  end;

  function TLatLong.ExportToText : String;
  begin
    FmtStr(Result, '%d %d', [Degrees, Minutes]);
  end;

  procedure TLatLong.ImportFromText(const strEncodedData : String);
  begin
    Degrees := StrToInt(ExtractWordS(1, strEncodedData, ' '));
    Minutes := StrToInt(ExtractWordS(2, strEncodedData, ' '));
  end;

{------------------------------------------------------------------------------}

  procedure TGMTTimeDelta.Assign(Source : TGMTTimeDelta);
  begin
    Hours := Source.Hours;
    Minutes := Source.Minutes;
    Seconds := Source.Seconds;
  end;

  function TGMTTimeDelta.GetTimeZoneStr : String;
  begin
    if (Hours = 0) and (Minutes = 0) then
      Result := 'GMT'
    else if Hours > 0 then
      FmtStr(Result, 'GMT+%.2d:%.2d', [Hours, Minutes])
    else if Hours < 0 then
      FmtStr(Result, 'GMT%.2d:%.2d', [Hours, Minutes]);
  end;

  function TGMTTimeDelta.ExportToText : String;
  begin
    with DaylSavings do
      FmtStr(Result, '%d %d %d.%d.%d.%d.%d.%d.%d.%d.%d',
                     [Hours, Minutes, Ord(CalcType), StartDay, StartDayName, StartMonth,
                      EndDay, EndDayName, EndMonth, AdjustHours, AdjustMinutes]);
  end;

  procedure TGMTTimeDelta.ImportFromText(const strEncodedData : String);
  var
    strDaylSavData : String;

    function ExtractInt(Idx : Integer) : Integer;
    begin
      Result := StrToInt(ExtractWordS(Idx, strDaylSavData, '.'));
    end;

  begin
    Hours := StrToInt(ExtractWordS(1, strEncodedData, ' '));
    Minutes := StrToInt(ExtractWordS(2, strEncodedData, ' '));

    strDaylSavData := TrimS(ExtractWordS(3, strEncodedData, ' '));
    if (Length(strDaylSavData) > 0) and (WordCountS(strDaylSavData, '.') = 9) then
      with FDaylSavingsSettings do begin
        CalcType := TDaylSavingsCalc(ExtractInt(1));
        StartDay := ExtractInt(2);
        StartDayName := ExtractInt(3);
        StartMonth := ExtractInt(4);
        EndDay := ExtractInt(5);
        EndDayName := ExtractInt(6);
        EndMonth := ExtractInt(7);
        AdjustHours := ExtractInt(8);
        AdjustMinutes := ExtractInt(9);
      end;
  end;

type
  TWeekdayDates =
    record
      Weekday : TStDayType;
      Month : Integer;
      Year : Integer;
      Count : Integer;
      Dates : array[0..9] of TStDate;
    end;

  function GetWeekdayDates(Day : TStDayType; Month, Year : Integer) : TWeekdayDates;
  var
    CheckDay, LastDay : Integer;
    TheDate : TStDate;
  begin
    FillChar(Result, SizeOf(Result), 0);
    Result.Weekday := Day;
    Result.Month := Month;
    Result.Year := Year;
    Result.Count := 0;

    LastDay := DaysInMonth(Month, Year, Epoch);
    for CheckDay := 1 to LastDay do begin
      TheDate := DMYToStDate(CheckDay, Month, Year, Epoch);
      if DayOfWeekDMY(CheckDay, Month, Year, Epoch) = Day then begin
        Inc(Result.Count);
        Result.Dates[Result.Count] := TheDate;   { this is x'th weekday of the month }
        Result.Dates[0] := TheDate;              { the latest will always be the last }
      end;
    end;
  end;

  procedure TGMTTimeDelta.SetDaylSavings(ADaylSav : TDaylSavingsSettings);
  begin
    FDaylSavingsSettings := ADaylSav;
    FillChar(FDaylSavInfo, SizeOf(FDaylSavInfo), 0);
  end;

  procedure TGMTTimeDelta.CalcDaylSavInfo(Year : Integer);
  var
    StartWD, EndWD : TWeekdayDates;
  begin
    FDaylSavInfo.CalcYear := Year;
    FDaylSavInfo.CalcSettings := FDaylSavingsSettings;

    StartWD := GetWeekdayDates(TStDayType(FDaylSavInfo.CalcSettings.StartDayName),
                               FDaylSavInfo.CalcSettings.StartMonth,
                               Year);
    EndWD := GetWeekdayDates(TStDayType(FDaylSavInfo.CalcSettings.EndDayName),
                             FDaylSavInfo.CalcSettings.EndMonth,
                             Year);

    FDaylSavInfo.StartDate := StartWD.Dates[FDaylSavInfo.CalcSettings.StartDay];
    FDaylSavInfo.EndDate := EndWD.Dates[FDaylSavInfo.CalcSettings.EndDay];
  end;

  function TGMTTimeDelta.Localize(ADate : TStDate; UniversalTime : TStTime) : TStTime;
  var
    Year, M, D : Integer;
  begin
    if FHours < 0 then
      Result := DecTime(UniversalTime, Abs(FHours), FMinutes, FSeconds)
    else
      Result := IncTime(UniversalTime, FHours, FMinutes, FSeconds);

    StDateToDMY(ADate, D, M, Year);
    if FDaylSavingsSettings.CalcType <> dscOff then begin
      if FDaylSavInfo.CalcYear <> Year then
        CalcDaylSavInfo(Year);

      if (ADate >= FDaylSavInfo.StartDate) and (ADate < FDaylSavInfo.EndDate) then
        if FDaylSavingsSettings.AdjustHours < 0 then
          Result := DecTime(Result, FDaylSavingsSettings.AdjustHours,
                            FDaylSavingsSettings.AdjustMinutes, 0)
        else
          Result := IncTime(Result, FDaylSavingsSettings.AdjustHours,
                            FDaylSavingsSettings.AdjustMinutes, 0);
    end;
  end;

{------------------------------------------------------------------------------}

  constructor TEarthPos.Create;
  begin
    inherited Create;

    FLatitude := TLatLong.Create;
    FLongitude := TLatLong.Create;
    FTimeDelta := TGMTTimeDelta.Create;

    { setup some defaults, everyone expects good values }
    City := 'Washington, D.C.';
    Latitude.Degrees := 38;
    Latitude.Minutes := 55;
    Longitude.Degrees := -77;
    Longitude.Minutes := 2;
    TimeDelta.Hours := -5;
    TimeDelta.DaylSavings := DefaultDaylSavings;
  end;

  destructor TEarthPos.Destroy;
  begin
    FLatitude.Free;
    FLongitude.Free;
    FTimeDelta.Free;

    inherited Destroy;
  end;

  procedure TEarthPos.Assign(Source : TEarthPos);
  begin
    City := Source.City;
    Latitude.Assign(Source.Latitude);
    Longitude.Assign(Source.Longitude);
    TimeDelta.Assign(Source.TimeDelta);
  end;

  function TEarthPos.ExportToText : String;
  begin
    FmtStr(Result, '%s:%s,%s,%s', [City, Latitude.CodedData, Longitude.CodedData, TimeDelta.CodedData]);
  end;

  procedure TEarthPos.ImportFromText(const strEncodedData : String);
  var
    strData : String;
  begin
    if WordCountS(strEncodedData, ':') <> 2 then
      raise Exception.CreateFmt('Invalid EarthPos format [%s]', [strEncodedData]);

    City := ExtractWordS(1, strEncodedData, ':');
    strData := ExtractWordS(2, strEncodedData, ':');

    if WordCountS(strData, ',') <> 3 then
      raise Exception.CreateFmt('City %s is missing data [%s]', [City, strData]);

    Latitude.CodedData := ExtractWordS(1, strData, ',');
    Longitude.CodedData := ExtractWordS(2, strData, ',');
    TimeDelta.CodedData := ExtractWordS(3, strData, ',');
  end;

{------------------------------------------------------------------------------}

  constructor TPrayerCalc.Create;
  begin
    inherited Create;

    FEarthPos := TEarthPos.Create;
    FPrayerSettings := DefaultPrayerSettings;
    TimeStrFmt := 'h:nna/p';
  end;

  destructor TPrayerCalc.Destroy;
  begin
    FEarthPos.Free;
    inherited Destroy;
  end;

  function IniFileName : String;
  var
    Path : array[0..255] of Char;
  begin
    GetWindowsDirectory(Path, 255);
    Result := AddBackSlashS(StrPas(Path))+'PMSETUP.INI';
  end;

  procedure TPrayerCalc.ReadFromIni;
  var
    Ini : TStRegIni;
    ePrayer : TPrayer;
    strNames, strSafety : String;
  begin
    Ini := TStRegIni.Create(IniFileName, True);
    Ini.CurSubKey := 'PrayerMinder';
    EarthPos.CodedData := Ini.ReadString('EarthPos', EarthPos.CodedData);

    strNames := Ini.ReadString('Names', 'Fajr,Shuruq,Dhurh,Asr,Maghrib,Ishaa');
    strSafety := Ini.ReadString('Safety', '5,-5,5,5,5,5');
    for ePrayer := Low(TPrayer) to High(TPrayer) do begin
      FPrayerSettings.Names[ePrayer] := ExtractWordS(Ord(ePrayer)+1,strNames,',');
      FPrayerSettings.Safety[ePrayer] := StrToInt(TrimS(ExtractWordS(Ord(ePrayer)+1,strSafety,',')));
    end;

    FPrayerSettings.Fajr := Ini.ReadFloat('Fajr', DefaultPrayerSettings.Fajr);
    FPrayerSettings.Asr := Ini.ReadInteger('Asr', DefaultPrayerSettings.Asr);
    FPrayerSettings.Ishaa := Ini.ReadFloat('Ishaa', DefaultPrayerSettings.Ishaa);

    Ini.Free;
  end;

  procedure TPrayerCalc.WriteToIni;
  var
    Ini : TStRegIni;
    ePrayer : TPrayer;
    strNames, strSafety : String;
  begin
    strNames := '';
    strSafety := '';
    for ePrayer := Low(TPrayer) to High(TPrayer) do begin
      strNames := strNames+FPrayerSettings.Names[ePrayer]+',';
      strSafety := strSafety+IntToStr(FPrayerSettings.Safety[ePrayer])+',';
    end;
    Delete(strNames, Length(strNames), 1);
    Delete(strSafety, Length(strSafety), 1);

    Ini := TStRegIni.Create(IniFileName, True);
    Ini.CurSubKey := 'PrayerMinder';
    Ini.WriteString('EarthPos', EarthPos.CodedData);
    Ini.WriteString('Names', strNames);
    Ini.WriteString('Safety', strSafety);
    Ini.WriteFloat('Fajr', FPrayerSettings.Fajr);
    Ini.WriteInteger('Asr', FPrayerSettings.Asr);
    Ini.WriteFloat('Ishaa', FPrayerSettings.Ishaa);
    Ini.Free;
  end;

  function TPrayerCalc.GetQiblaDirection : TQiblaDirection;
  const
    { lat, long of Mecca in radians }
    lat0 : Double = 0.3739077;
    long0 : Double = 0.69504828;
  var
    dflong : Double;
    latitudeRads : Double;
  begin
    dflong := long0-FEarthPos.Longitude.Radians;
    latitudeRads := FEarthPos.Latitude.Radians;
    Result.Radians := InvTan2(cos(latitudeRads)*Tan(lat0)-sin(latitudeRads)*cos(dflong), sin(dflong));
    Result.DegreesMinutes := Result.Radians * 180 / PI;
    Result.DegreesStr := DegsMin(Result.Radians);
  end;

  function ArbitraryTwilight(LD : TStDate; Longitude, Latitude : Double;
                             H0 : Double) : TStRiseSetRec;
    {-compute the beginning or end of twilight}
    {twilight computations are based on the zenith distance of the center }
    {of the solar disc (HO, negative angle) }
  var
    I  : Integer;
    UT : TStDateTimeRec;
    RP : TStPosRecArray;
  begin
    UT.D := LD-1;
    UT.T := 0;
    if not CheckDate(UT) then
    begin
      Result.ORise := -4;
      Result.OSet  := -4;
      Exit;
    end;

    if (H0 > -10) or (H0 < -22) then
      raise Exception.CreateFmt('Horizon value out of range: %f', [H0]);

    for I := 1 to 3 do
    begin
      UT.D := LD + I-1;
      RP[I] := SunPos(UT);
    end;
    Result := RiseSetPrim(LD, Longitude, Latitude, H0, RP);
  end;

  procedure TPrayerCalc.CalcOneDayPrim(ADate : TStDate; var Times : TPrayerTimes);
  type
    TInterval = (inBefore, inAfter);

    function MiddleTime(StartTime, EndTime : TStTime) : TStTime;
    var
      H, M, S : Byte;
    begin
      if (StartTime < 0) or (EndTime < 0) then begin
        MiddleTime := -1;
        Exit;
      end;

      TimeDiff(StartTime, EndTime, H, M, S);
      Result := IncTime(StartTime, H div 2, M div 2, S div 2);
    end;

    function ByInterval(How : TInterval; FromPrayer : TPrayer; Interval : Double) : TStTime;
    var
      IntervalMinutes : Word;
      H, M : Word;
    begin
      IntervalMinutes := Abs(Trunc(Interval));
      H := IntervalMinutes div MinutesInHour;
      M := IntervalMinutes - (H * MinutesInHour);
      if How = inBefore then
        Result := DecTime(Times[FromPrayer], H, M, 0)
      else
        Result := IncTime(Times[FromPrayer], H, M, 0);
    end;

    procedure CalcSunRiseSet;
    var
      RiseSetInfo : TStRiseSetRec;
    begin
      RiseSetInfo := SunRiseSet(ADate, FEarthPos.Longitude.DegreesMinutes, FEarthPos.Latitude.DegreesMinutes);
      Times[prSunrise] := FEarthPos.TimeDelta.Localize(ADate, RiseSetInfo.ORise);
      Times[prMaghrib] := FEarthPos.TimeDelta.Localize(ADate, RiseSetInfo.OSet);
      Times[prZuhr] := MiddleTime(Times[prSunrise], Times[prMaghrib]);
    end;

    procedure CalcFajr;
    var
      RiseSetInfo : TStRiseSetRec;
    begin
      if (FPrayerSettings.Fajr > 0) and (Times[prFajr] > 0) then
        Times[prFajr] := ByInterval(inBefore, prSunrise, FPrayerSettings.Fajr)
      else begin
        RiseSetInfo := ArbitraryTwilight(ADate,
                                         FEarthPos.Longitude.DegreesMinutes,
                                         FEarthPos.Latitude.DegreesMinutes,
                                         FPrayerSettings.Fajr);
        Times[prFajr] := FEarthPos.TimeDelta.Localize(ADate, RiseSetInfo.ORise);
      end;
    end;

    procedure CalcAsr;
    begin
      case FPrayerSettings.Asr of
        -1, { shadow ratio doesn't work yet }
        -2, { shadow ratio doesn't work yet }
         0 : Times[prAsr] := MiddleTime(Times[prZuhr], Times[prMaghrib]);
      else
        if Times[prMaghrib] > 0 then
          Times[prAsr] := ByInterval(inBefore, prMaghrib, FPrayerSettings.Asr);
      end;
    end;

    procedure CalcIshaa;
    var
      RiseSetInfo : TStRiseSetRec;
    begin
      if (FPrayerSettings.Ishaa > 0) and (Times[prMaghrib] > 0) then
        Times[prIshaa] := ByInterval(inAfter, prMaghrib, FPrayerSettings.Ishaa)
      else begin
        RiseSetInfo := ArbitraryTwilight(ADate,
                                         FEarthPos.Longitude.DegreesMinutes,
                                         FEarthPos.Latitude.DegreesMinutes,
                                         FPrayerSettings.Ishaa);
        Times[prIshaa] := FEarthPos.TimeDelta.Localize(ADate, RiseSetInfo.OSet);
      end;
    end;

    procedure AddSafeties;
    var
      ePrayer : TPrayer;
      eHow : TInterval;
    begin
      for ePrayer := Low(ePrayer) to High(ePrayer) do begin
        if FPrayerSettings.Safety[ePrayer] = 0 then
          continue
        else if FPrayerSettings.Safety[ePrayer] > 0 then
          eHow := inAfter
        else
          eHow := inBefore;
        Times[ePrayer] := ByInterval(eHow, ePrayer, FPrayerSettings.Safety[ePrayer]);
      end;
    end;

  begin
    FillChar(Times, SizeOf(Times), 0);

    CalcSunRiseSet;
    CalcFajr;
    CalcAsr;
    CalcIshaa;
    AddSafeties;
  end;

  procedure TPrayerCalc.FindPrayer(Times : TPrayerTimes; var CurPrayer : TCurPrayerInfo);
  var
    CurTime : TStTime;
    P : TPrayer;
    H, M, S : Byte;
  begin
    FillChar(CurPrayer, SizeOf(CurPrayer), 0);

    CurTime := CurrentTime;
    CurPrayer.Prayer := prIshaa;
    for P := prMaghrib downto prFajr do
      if CurTime >= Times[P] then begin
        CurPrayer.Prayer := P;
        break;
      end;

    if CurPrayer.Prayer = prIshaa then
      CurPrayer.NextPrayer := prFajr
    else
      CurPrayer.NextPrayer := Succ(P);
    TimeDiff(CurTime, Times[CurPrayer.NextPrayer], H, M, S);

    CurPrayer.HoursRemaining := H;
    CurPrayer.MinutesRemaining := M;
    CurPrayer.NextPrayerStart := Times[CurPrayer.NextPrayer];
    CurPrayer.Calculated := True;
  end;

  function TPrayerCalc.FormatTime(ATime : TStTime) : String;
  begin
    if ATime < 0 then
      Result := '*'
    else
      Result := FormatDateTime(FTimeStrFmt, StTimeToDateTime(ATime));
  end;

  procedure TPrayerCalc.DoTimeReplacements(pszReplaceInStr : PChar; var Times : TPrayerTimes);

    function Duration(Earlier, Later : TStTime; ShowMins : Boolean) : String;
    var
      H, M, S : Byte;
    begin
      if (Earlier < 0) or (Later < 0) then begin
        Result := '*';
        Exit;
      end;

      TimeDiff(Earlier, Later, H, M, S);
      Result := IntToStr(H)+'h';
      if ShowMins then
        Result := Result+' '+IntToStr(M)+'m';
    end;

  begin
    ReplaceWithStr(pszReplaceInStr, '${scFajrTime}', FormatTime(Times[prFajr]));
    ReplaceWithStr(pszReplaceInStr, '${scSunriseTime}', FormatTime(Times[prSunrise]));
    ReplaceWithStr(pszReplaceInStr, '${scZuhrTime}', FormatTime(Times[prZuhr]));
    ReplaceWithStr(pszReplaceInStr, '${scAsrTime}', FormatTime(Times[prAsr]));
    ReplaceWithStr(pszReplaceInStr, '${scMaghribTime}', FormatTime(Times[prMaghrib]));
    ReplaceWithStr(pszReplaceInStr, '${scIshaaTime}', FormatTime(Times[prIshaa]));

    ReplaceWithStr(pszReplaceInStr, '${scFajrDuration}', Duration(Times[prFajr], Times[prSunrise], True));
    ReplaceWithStr(pszReplaceInStr, '${scSunriseDuration}', Duration(Times[prSunrise], Times[prZuhr], True));
    ReplaceWithStr(pszReplaceInStr, '${scZuhrDuration}', Duration(Times[prZuhr], Times[prAsr], True));
    ReplaceWithStr(pszReplaceInStr, '${scAsrDuration}', Duration(Times[prAsr], Times[prMaghrib], True));
    ReplaceWithStr(pszReplaceInStr, '${scMaghribDuration}', Duration(Times[prMaghrib], Times[prIshaa], True));
    ReplaceWithStr(pszReplaceInStr, '${scIshaaDuration}', Duration(Times[prIshaa], Times[prFajr], False));
  end;

  procedure TPrayerCalc.DoVarReplacements(pszStrBuf : PChar);
  begin
    ReplaceWithStr(pszStrBuf, '${scCityName}', EarthPos.City);
    ReplaceWithStr(pszStrBuf, '${scLatitude}', EarthPos.Latitude.DegreesMinsStr);
    ReplaceWithStr(pszStrBuf, '${scLongitude}', EarthPos.Longitude.DegreesMinsStr);

    ReplaceWithStr(pszStrBuf, '${scFajrName}', PrayerSettings.Names[prFajr]);
    ReplaceWithStr(pszStrBuf, '${scSunriseName}', PrayerSettings.Names[prSunrise]);
    ReplaceWithStr(pszStrBuf, '${scZuhrName}', PrayerSettings.Names[prZuhr]);
    ReplaceWithStr(pszStrBuf, '${scAsrName}', PrayerSettings.Names[prAsr]);
    ReplaceWithStr(pszStrBuf, '${scMaghribName}', PrayerSettings.Names[prMaghrib]);
    ReplaceWithStr(pszStrBuf, '${scIshaaName}', PrayerSettings.Names[prIshaa]);
  end;

  procedure TPrayerCalc.DoDateReplacements(pszReplaceInStr : PChar; ADate : TDateTime);
  begin
    ReplaceWithStr(pszReplaceInStr, '${scCalcDateWeekday}', FormatDateTime('dddd', ADate));
    ReplaceWithStr(pszReplaceInStr, '${scCalcDateDayNum}', FormatDateTime('d', ADate));
    ReplaceWithStr(pszReplaceInStr, '${scCalcDateMonthDay}', FormatDateTime('mmm d', ADate));
  end;

  procedure TPrayerCalc.CalcOneDay(ADateTime : TDateTime; var Times : TPrayerTimes);
  begin
    CalcOneDayPrim(DateTimeToStDate(ADateTime), Times);
  end;

  procedure TPrayerCalc.CalcOneDayStr(ADate : TDateTime; pszReplaceInStr : PChar);
  var
    Times : TPrayerTimes;
  begin
    CalcOneDay(ADate, Times);

    DoDateReplacements(pszReplaceInStr, ADate);
    DoTimeReplacements(pszReplaceInStr, Times);
  end;

  procedure TPrayerCalc.CalcOneMonthStr(ADate : TDateTime; const pszOneRowFmt : PChar; pszMonthlyTimes : PChar);
  const
    Epoch = 1950;
  var
    Y, M, D : Word;
    TotalDays : Word;
    Times : TPrayerTimes;
    szOneRow : array[0..1024] of Char;
  begin
    DecodeDate(ADate, Y, M, D);
    TotalDays := DaysInMonth(M, Y, Epoch);

    for D := 1 to TotalDays do begin
      CalcOneDayPrim(DMYToStDate(D, M, Y, Epoch), Times);

      StrCopy(szOneRow, pszOneRowFmt);
      DoDateReplacements(szOneRow, EncodeDate(Y, M, D));
      DoTimeReplacements(szOneRow, Times);

      StrCat(pszMonthlyTimes, szOneRow);
    end;
  end;

end.
