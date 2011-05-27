unit Pmsetup;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, EPGfxCmp, ExtCtrls, StdCtrls, Buttons, Spin, Nicetabs,
  Salat, StColl, ReadFile, Grids, RXCtrls, RXSpin;

type
  TArea = class(TStCollection)
  protected
    FName : String;

    function GetCity(AIndex : Word) : TEarthPos;
  public
    constructor Create;
    function AddCity(const strData : String) : Word;
    function FindCity(strCity : String; var FoundIndex : Integer) : TEarthPos;

    property Name : String read FName write FName;
    property Cities[Index : Word] : TEarthPos read GetCity;
  end;

  TAreas = class(TStCollection)
  protected
    FUserDefinedAreaIndex : Word;

    function GetArea(AIndex : Word) : TArea;
    procedure OnImportLine(AReader : TControlFileReader;
                           ALineType : TControlLine; pszLine : PChar);
  public
    constructor Create;
    function FindArea(strArea : String; var FoundIndex : Integer) : TArea;
    function FindCity(strSearchForCity : String; var FoundAreaIdx, FoundCityIdx : Integer) : TEarthPos;
    procedure ImportFromFile(const strFName : String);

    property Areas[Index : Word] : TArea read GetArea;
    property UserDefinedAreaIndex : Word read FUserDefinedAreaIndex;
  end;

  TSettingsPage = (spLocation, spPrayers, spDaylightSavings);

  TfrmPrayerMinderSettings = class(TForm)
    pnlDialogName: TPanel;
    pnlDataContainer: TPanel;
    imgDialogName: TEPImage;
    tabSettingsPages: TNiceTab;
    nbkSettingsPages: TNiceNotebook;
    brdCityList: TEPBorder;
    cbxAreaSelector: TComboBox;
    lbxCitiesList: TListBox;
    brdCityInfo: TEPBorder;
    edtCityName: TEdit;
    gbxLatitude: TGroupBox;
    lblLatDegrees: TLabel;
    lblLatMinutes: TLabel;
    spnLatDegrees: TSpinEdit;
    spnLatMin: TSpinEdit;
    gbxLongitude: TGroupBox;
    lblLongDegrees: TLabel;
    lblLongMinutes: TLabel;
    spnLongDegrees: TSpinEdit;
    spnLongMinutes: TSpinEdit;
    gbxTimeZone: TGroupBox;
    lblTimeZoneHours: TLabel;
    lblTimeZoneMins: TLabel;
    spnTimeZoneHrs: TSpinEdit;
    spnTimeZoneMins: TSpinEdit;
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    btnCityAdd: TBitBtn;
    btnDeleteCity: TBitBtn;
    lblLatitudeDescr: TLabel;
    lblLongitudeDescr: TLabel;
    lblTZDescr: TLabel;
    gbxPrayerNames: TGroupBox;
    grdPrayerNames: TStringGrid;
    cbxFajrSetting: TComboBox;
    spnFajrSetting: TRxSpinEdit;
    brdFajrSetting: TEPBorder;
    brdIshaaSetting: TEPBorder;
    cbxIshaaSetting: TComboBox;
    spnIshaaSetting: TRxSpinEdit;
    brdAsrSetting: TEPBorder;
    cbxAsrSetting: TComboBox;
    spnAsrSetting: TRxSpinEdit;
    gbxDaylSavStart: TGroupBox;
    rgpDaylSavOn: TRadioGroup;
    cbxDaylSavStartDay: TComboBox;
    cbxDaylSavStartDayName: TComboBox;
    cbxDaylSavStartMonth: TComboBox;
    lblDaylSavMonthStart: TLabel;
    gbxDaylSavEnd: TGroupBox;
    Label1: TLabel;
    cbxDaylSavEndDay: TComboBox;
    cbxDaylSavEndDayName: TComboBox;
    cbxDaylSavEndMonth: TComboBox;
    gbxAdjust: TGroupBox;
    spnAdjustHours: TRxSpinEdit;
    lblAdjHoursPrompt: TLabel;
    spnAdjustMins: TRxSpinEdit;
    lblAdjustMinsPrompt: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cbxAreaSelectorChange(Sender: TObject);
    procedure lbxCitiesListClick(Sender: TObject);
    procedure btnCityAddClick(Sender: TObject);
    procedure btnDeleteCityClick(Sender: TObject);
    procedure tabSettingsPagesTabChange(Sender: TObject; NewIndex: Integer;
      var AllowChange: Boolean);
    procedure btnOKClick(Sender: TObject);
    procedure grdPrayerNamesGetEditMask(Sender: TObject; ACol,
      ARow: Longint; var Value: OpenString);
    procedure cbxFajrSettingChange(Sender: TObject);
    procedure cbxIshaaSettingChange(Sender: TObject);
    procedure cbxAsrSettingChange(Sender: TObject);
    procedure rgpDaylSavOnClick(Sender: TObject);
  private
    FAreas : TAreas;
    FSalatCalc : TPrayerCalc; { maintained externally }

    function GetAreaIndex : Integer;
    procedure SetAreaIndex(AIndex : Integer);
    function GetCityIndex : Integer;
    procedure SetCityIndex(AIndex : Integer);
    procedure SetSalatCalc(ASalatCalc : TPrayerCalc);
    function GetFajrAsrIshaaValue(Which : TPrayer) : Double;
    procedure SetFajrAsrIshaaValue(Which : TPrayer; Value : Double);
    function GetPage : TSettingsPage;
    procedure SetPage(APage : TSettingsPage);
    function GetDaylSavings : TDaylSavingsSettings;
    procedure SetDaylSavings(ADaylSavings : TDaylSavingsSettings);
  public
    property AreaIndex : Integer read GetAreaIndex write SetAreaIndex;
    property CityIndex : Integer read GetCityIndex write SetCityIndex;
    property SalatCalc : TPrayerCalc read FSalatCalc write SetSalatCalc;
    property Page : TSettingsPage read GetPage write SetPage;
  end;

var
  frmPrayerMinderSettings: TfrmPrayerMinderSettings;

implementation

uses StStrS;

{$R *.DFM}

procedure DisposeObject(Data : Pointer); far;
begin
  TObject(Data).Free;
end;

constructor TArea.Create;
begin
  inherited Create(64);
  DisposeData := DisposeObject;
end;

function TArea.GetCity(AIndex : Word) : TEarthPos;
begin
  Result := TEarthPos(Items[AIndex]);
end;

function TArea.AddCity(const strData : String) : Word;
var
  EarthPos : TEarthPos;
begin
  EarthPos := TEarthPos.Create;
  EarthPos.CodedData := strData;
  Insert(EarthPos);
  Result := Count-1;
end;

function TArea.FindCity(strCity : String; var FoundIndex : Integer) : TEarthPos;
var
  nCityIdx : Integer;
begin
  FoundIndex := -1;
  Result := Nil;

  if Count <= 0 then
    Exit;

  for nCityIdx := 0 to Count-1 do
    if CompareText(Cities[nCityIdx].City, strCity) = 0 then begin
      FoundIndex := nCityIdx;
      Result := Cities[nCityIdx];
      Exit;
    end;
end;

constructor TAreas.Create;
begin
  inherited Create(8);
  DisposeData := DisposeObject;
end;

function TAreas.FindArea(strArea : String; var FoundIndex : Integer) : TArea;
var
  nAreaIdx : Integer;
begin
  FoundIndex := -1;
  Result := Nil;

  if Count <= 0 then
    Exit;

  for nAreaIdx := 0 to Count-1 do
    if CompareText(Areas[nAreaIdx].Name, strArea) = 0 then begin
      FoundIndex := nAreaIdx;
      Result := Areas[nAreaIdx];
      Exit;
    end;
end;

function TAreas.FindCity(strSearchForCity : String; var FoundAreaIdx, FoundCityIdx : Integer) : TEarthPos;
var
  strCity, strArea : String;
  nSearchItems, nAreaIdx, nCityIdx : Integer;
  Area : TArea;
  EP : TEarthPos;
begin
  FoundAreaIdx := -1;
  FoundCityIdx := -1;
  Result := Nil;

  { are we given an area and city or just a city? }
  nSearchItems := WordCountS(strSearchForCity, ':');
  if nSearchItems = 1 then begin
    strCity := strSearchForCity;

    { look through all the areas for the first city match }
    for nAreaIdx := 0 to Count-1 do begin
      EP := Areas[nAreaIdx].FindCity(strCity, nCityIdx);
      if EP <> Nil then begin
        Result := EP;
        FoundAreaIdx := nAreaIdx;
        FoundCityIdx := nCityIdx;
        Exit;
      end;
    end;
  end else if nSearchItems = 2 then begin
    strArea := ExtractWordS(1, strSearchForCity, ':');
    strCity := ExtractWordS(2, strSearchForCity, ':');

    Area := FindArea(strArea, nAreaIdx);
    if Area <> Nil then begin
      EP := Area.FindCity(strCity, nCityIdx);
      if EP <> Nil then begin
        Result := EP;
        FoundAreaIdx := nAreaIdx;
        FoundCityIdx := nCityIdx;
        Exit;
      end;
    end;
  end;
end;

function TAreas.GetArea(AIndex : Word) : TArea;
begin
  Result := TArea(Items[AIndex]);
end;

procedure TAreas.OnImportLine(AReader : TControlFileReader;
                              ALineType : TControlLine; pszLine : PChar);
const
  CurArea : TArea = Nil;
begin
  case ALineType of
    clFileBegin : CurArea := Nil;
    clCmd : begin
        if CompareText(AReader.CurCmd, 'area') = 0 then begin
          CurArea := TArea.Create;
          CurArea.Name := AReader.CurCmdParams;
          Insert(CurArea);
          if CompareText(CurArea.Name, 'User Defined') = 0 then
            FUserDefinedAreaIndex := Count-1;
        end else
          raise Exception.CreateFmt('Unknown import cmd %s', [AReader.CurCmd]);
      end;
    clData : begin
        if CurArea <> Nil then
          CurArea.AddCity(StrPas(pszLine))
        else
          raise Exception.CreateFmt('No city area defined for importing [%s]', [pszLine]);
      end;
    clFileEnd : CurArea := Nil;
  end;
end;

procedure TAreas.ImportFromFile(const strFName : String);
var
  Reader : TControlFileReader;
begin
  Reader := TControlFileReader.Create;
  try
    Reader.FileName := strFName;
    Reader.OnRead := OnImportLine;
    Reader.Process;
  finally
    Reader.Free;
  end;
end;

{-----------------------------------------------------------------------------}

procedure TfrmPrayerMinderSettings.FormCreate(Sender: TObject);
var
  Idx : Integer;
  Area : TArea;
begin
  FAreas := TAreas.Create;
  FAreas.ImportFromFile(JustPathNameS(Application.ExeName)+'\pmsetup.dat');

  cbxAreaSelector.Items.Clear;
  for Idx := 0 to FAreas.Count-1 do begin
    Area := FAreas.Areas[Idx];
    cbxAreaSelector.Items.AddObject(Area.Name, Area);
  end;

  grdPrayerNames.Cells[0,0] := 'Prayer';
  grdPrayerNames.Cells[1,0] := 'Name';
  grdPrayerNames.Cells[2,0] := 'Safety';
  grdPrayerNames.Cells[0,1] := 'Morning';
  grdPrayerNames.Cells[0,2] := 'Sunrise';
  grdPrayerNames.Cells[0,3] := 'Noon';
  grdPrayerNames.Cells[0,4] := 'Afternoon';
  grdPrayerNames.Cells[0,5] := 'Evening';
  grdPrayerNames.Cells[0,6] := 'Night';

  cbxDaylSavStartDayName.Items.Clear;
  cbxDaylSavEndDayName.Items.Clear;
  cbxDaylSavStartMonth.Items.Clear;
  cbxDaylSavEndMonth.Items.Clear;
  for Idx := 1 to 7 do begin
    cbxDaylSavStartDayName.Items.Add(LongDayNames[Idx]);
    cbxDaylSavEndDayName.Items.Add(LongDayNames[Idx]);
  end;

  for Idx := 1 to 12 do begin
    cbxDaylSavStartMonth.Items.Add(LongMonthNames[Idx]);
    cbxDaylSavEndMonth.Items.Add(LongMonthNames[Idx]);
  end;

  Page := spLocation;
end;

procedure TfrmPrayerMinderSettings.FormDestroy(Sender: TObject);
begin
  FAreas.Free;
end;

function TfrmPrayerMinderSettings.GetAreaIndex : Integer;
begin
  Result := cbxAreaSelector.ItemIndex;
end;

procedure TfrmPrayerMinderSettings.SetAreaIndex(AIndex : Integer);
var
  Idx : Integer;
  Area : TArea;
  EarthPos : TEarthPos;
  EditAllowed : Boolean;
begin
  cbxAreaSelector.ItemIndex := AIndex;
  lbxCitiesList.Items.Clear;
  Area := TArea(cbxAreaSelector.Items.Objects[AIndex]);
  for Idx := 0 to Area.Count-1 do begin
    EarthPos := Area.Cities[Idx];
    lbxCitiesList.Items.AddObject(EarthPos.City, EarthPos);
  end;

  EditAllowed := AIndex = FAreas.UserDefinedAreaIndex;
  btnDeleteCity.Enabled := EditAllowed;
  edtCityName.Enabled := EditAllowed;
  spnLatDegrees.Enabled := EditAllowed;
  spnLatMin.Enabled := EditAllowed;
  spnLongDegrees.Enabled := EditAllowed;
  spnLongMinutes.Enabled := EditAllowed;
  spnTimeZoneHrs.Enabled := EditAllowed;
  spnTimeZoneMins.Enabled := EditAllowed;
end;

function TfrmPrayerMinderSettings.GetCityIndex : Integer;
begin
  Result := lbxCitiesList.ItemIndex;
end;

procedure TfrmPrayerMinderSettings.SetCityIndex(AIndex : Integer);
var
  Area : TArea;
  EarthPos : TEarthPos;
begin
  lbxCitiesList.ItemIndex := AIndex;
  Area := TArea(cbxAreaSelector.Items.Objects[cbxAreaSelector.ItemIndex]);
  with Area.Cities[AIndex] do begin
    edtCityName.Text := City;
    spnLatDegrees.Value := Latitude.Degrees;
    spnLatMin.Value := Latitude.Minutes;
    spnLongDegrees.Value := Longitude.Degrees;
    spnLongMinutes.Value := Longitude.Minutes;
    spnTimeZoneHrs.Value := TimeDelta.Hours;
    spnTimeZoneMins.Value := TimeDelta.Minutes;
  end;
end;

procedure TfrmPrayerMinderSettings.SetSalatCalc(ASalatCalc : TPrayerCalc);
var
  ePrayer : TPrayer;
  nAreaIdx, nCityIdx : Integer;
begin
  FSalatCalc := ASalatCalc;

  if FAreas.FindCity(FSalatCalc.EarthPos.City, nAreaIdx, nCityIdx) <> Nil then begin
    AreaIndex := nAreaIdx;
    CityIndex := nCityIdx;
  end;

  for ePrayer := Low(TPrayer) to High(TPrayer) do begin
    grdPrayerNames.Cells[1,Ord(ePrayer)+1] := FSalatCalc.PrayerSettings.Names[ePrayer];
    grdPrayerNames.Cells[2,Ord(ePrayer)+1] := IntToStr(FSalatCalc.PrayerSettings.Safety[ePrayer]);
  end;

  SetFajrAsrIshaaValue(prFajr, FSalatCalc.PrayerSettings.Fajr);
  SetFajrAsrIshaaValue(prAsr, FSalatCalc.PrayerSettings.Asr);
  SetFajrAsrIshaaValue(prIshaa, FSalatCalc.PrayerSettings.Ishaa);

  SetDaylSavings(FSalatCalc.EarthPos.TimeDelta.DaylSavings);
end;

function TfrmPrayerMinderSettings.GetFajrAsrIshaaValue(Which : TPrayer) : Double;

  function GetFajrIshaa(ComboBox : TComboBox; Spinner : TRxSpinEdit) : Double;
  begin
    if ComboBox.ItemIndex = 0 then begin
      Result := -Spinner.Value    { negative is sun's angle }
    end else if ComboBox.ItemIndex = 1 then begin
      Result := Spinner.Value;  { positive is by interval }
    end else
      raise Exception.CreateFmt('Unknown Fajr/Ishaa type %d', [ComboBox.ItemIndex]);
  end;

begin
  case Which of
    prFajr : Result := GetFajrIshaa(cbxFajrSetting, spnFajrSetting);
    prAsr :
      case cbxAsrSetting.ItemIndex of
        0 : Result := -1;  { shadow equal to size of object }
        1 : Result := -2;  { shadow twice object }
        2 : Result := 0;   { middle of zurh/maghrib }
        3 : Result := spnAsrSetting.Value; { by interval }
      else
        raise Exception.CreateFmt('Unknown asr setting type %d', [cbxAsrSetting.ItemIndex]);
      end;
    prIshaa : Result := GetFajrIshaa(cbxIshaaSetting, spnIshaaSetting);
  end;
end;

procedure TfrmPrayerMinderSettings.SetFajrAsrIshaaValue(Which : TPrayer; Value : Double);

  procedure ActivateFajrIshaa(ComboBox : TComboBox; Spinner : TRxSpinEdit);
  begin
    if Value < 0 then begin
      ComboBox.ItemIndex := 0;
      Spinner.Decimal := 2;
      Spinner.MinValue := 6;
      Spinner.MaxValue := 20;
      Spinner.Value := Abs(Value);
    end else begin
      ComboBox.ItemIndex := 1;
      Spinner.Decimal := 0;
      Spinner.MinValue := 15;
      Spinner.MaxValue := 900;
      Spinner.Value := Value;
    end;
  end;

begin
  case Which of
    prFajr : ActivateFajrIshaa(cbxFajrSetting, spnFajrSetting);
    prAsr : begin
        if Value > 0 then begin
          cbxAsrSetting.ItemIndex := 3;
          spnAsrSetting.Value := Trunc(Value);
        end else
          case Trunc(Value) of
            -2 : cbxAsrSetting.ItemIndex := 1;
            -1 : cbxAsrSetting.ItemIndex := 0;
             0 : cbxAsrSetting.ItemIndex := 2;
          end;
        spnAsrSetting.Visible := cbxAsrSetting.ItemIndex = 3;
      end;
    prIshaa : ActivateFajrIshaa(cbxIshaaSetting, spnIshaaSetting);
  end;
end;

function TfrmPrayerMinderSettings.GetDaylSavings : TDaylSavingsSettings;
begin
  Result.CalcType := TDaylSavingsCalc(rgpDaylSavOn.ItemIndex);
  Result.StartDay := cbxDaylSavStartDay.ItemIndex;
  Result.StartDayName := cbxDaylSavStartDayName.ItemIndex;
  Result.StartMonth := cbxDaylSavStartMonth.ItemIndex+1;
  Result.EndDay := cbxDaylSavEndDay.ItemIndex;
  Result.EndDayName := cbxDaylSavEndDayName.ItemIndex;
  Result.EndMonth := cbxDaylSavEndMonth.ItemIndex+1;
  Result.AdjustHours := Trunc(spnAdjustHours.Value);
  Result.AdjustMinutes := Trunc(spnAdjustMins.Value);
end;

procedure TfrmPrayerMinderSettings.SetDaylSavings(ADaylSavings : TDaylSavingsSettings);

  procedure Populate(cbxDay, cbxDayName, cbxMonth : TComboBox;
                     nDay, nDayName, nMonth : Integer);
  begin
    cbxDay.ItemIndex := nDay;
    cbxDayName.ItemIndex := nDayName;
    cbxMonth.ItemIndex := nMonth-1;
  end;

begin
  rgpDaylSavOn.ItemIndex := Ord(ADaylSavings.CalcType);
  gbxDaylSavStart.Visible := ADaylSavings.CalcType = dscAuto;
  gbxDaylSavEnd.Visible := ADaylSavings.CalcType = dscAuto;
  gbxAdjust.Visible := ADaylSavings.CalcType = dscAuto;

  case ADaylSavings.CalcType of
    dscAuto :
      begin
        Populate(cbxDaylSavStartDay, cbxDaylSavStartDayName, cbxDaylSavStartMonth,
                 ADaylSavings.StartDay, ADaylSavings.StartDayName, ADaylSavings.StartMonth);
        Populate(cbxDaylSavEndDay, cbxDaylSavEndDayName, cbxDaylSavEndMonth,
                 ADaylSavings.EndDay, ADaylSavings.EndDayName, ADaylSavings.EndMonth);
        spnAdjustHours.Value := ADaylSavings.AdjustHours;
        spnAdjustMins.Value := ADaylSavings.AdjustMinutes;
      end;
    dscOff : ;
  end;
end;

function TfrmPrayerMinderSettings.GetPage : TSettingsPage;
begin
  Result := TSettingsPage(tabSettingsPages.TabIndex);
end;

procedure TfrmPrayerMinderSettings.SetPage(APage : TSettingsPage);
begin
  tabSettingsPages.TabIndex := Ord(APage);
  nbkSettingsPages.ActivePageIndex := Ord(APage);
end;

procedure TfrmPrayerMinderSettings.cbxAreaSelectorChange(Sender: TObject);
begin
  AreaIndex := cbxAreaSelector.ItemIndex;
  lbxCitiesList.SetFocus;
end;

procedure TfrmPrayerMinderSettings.lbxCitiesListClick(Sender: TObject);
begin
  CityIndex := lbxCitiesList.ItemIndex;
end;

procedure TfrmPrayerMinderSettings.btnCityAddClick(Sender: TObject);
var
  strNewData : String;
  wNewCityIdx : Word;
  UserArea : TArea;
begin
  UserArea := FAreas.Areas[FAreas.UserDefinedAreaIndex];

  FmtStr(strNewData, 'UserCity%d:%d %d,%d %d,%d %d',
                     [UserArea.Count+1,
                      spnLatDegrees.Value, spnLatMin.Value,
                      spnLongDegrees.Value, spnLongMinutes.Value,
                      spnTimeZoneHrs.Value, spnTimeZoneMins.Value]);

  wNewCityIdx := UserArea.AddCity(strNewData);
  AreaIndex := FAreas.UserDefinedAreaIndex;
  CityIndex := wNewCityIdx;
  edtCityName.SetFocus;
end;

procedure TfrmPrayerMinderSettings.btnDeleteCityClick(Sender: TObject);
var
  Area : TArea;
begin
  Area := TArea(cbxAreaSelector.Items.Objects[cbxAreaSelector.ItemIndex]);
  Area.Delete(Pointer(Area.Cities[lbxCitiesList.ItemIndex]));

  { force an update }
  AreaIndex := AreaIndex;
end;

procedure TfrmPrayerMinderSettings.tabSettingsPagesTabChange(
  Sender: TObject; NewIndex: Integer; var AllowChange: Boolean);
begin
  nbkSettingsPages.ActivePageIndex := NewIndex;
end;

procedure TfrmPrayerMinderSettings.btnOKClick(Sender: TObject);
var
  ePrayer : TPrayer;
  Settings : TPrayerSettings;
begin
  for ePrayer := Low(TPrayer) to High(TPrayer) do begin
    Settings.Names[ePrayer] := grdPrayerNames.Cells[1,Ord(ePrayer)+1];
    Settings.Safety[ePrayer] := StrToInt(TrimS(grdPrayerNames.Cells[2,Ord(ePrayer)+1]));
  end;

  Settings.Fajr := GetFajrAsrIshaaValue(prFajr);
  Settings.Asr := Trunc(GetFajrAsrIshaaValue(prAsr));
  Settings.Ishaa := GetFajrAsrIshaaValue(prIshaa);

  SalatCalc.EarthPos.Assign(FAreas.Areas[AreaIndex].Cities[CityIndex]);
  SalatCalc.EarthPos.TimeDelta.DaylSavings := GetDaylSavings;
  SalatCalc.PrayerSettings := Settings;
end;

procedure TfrmPrayerMinderSettings.grdPrayerNamesGetEditMask(
  Sender: TObject; ACol, ARow: Longint; var Value: OpenString);
begin
  if ACol = 2 then
    Value := '#99';
end;

procedure TfrmPrayerMinderSettings.cbxFajrSettingChange(Sender: TObject);
begin
  case cbxFajrSetting.ItemIndex of
    0 : SetFajrAsrIshaaValue(prFajr, -18);
    1 : SetFajrAsrIshaaValue(prFajr, 90);
  end;
end;

procedure TfrmPrayerMinderSettings.cbxIshaaSettingChange(Sender: TObject);
begin
  case cbxIshaaSetting.ItemIndex of
    0 : SetFajrAsrIshaaValue(prIshaa, -18);
    1 : SetFajrAsrIshaaValue(prIshaa, 90);
  end;
end;

procedure TfrmPrayerMinderSettings.cbxAsrSettingChange(Sender: TObject);
begin
  case cbxAsrSetting.ItemIndex of
    0, {: SetFajrAsrIshaaValue(prAsr, -1); }
    1, {: SetFajrAsrIshaaValue(prAsr, -2);}
    2  : SetFajrAsrIshaaValue(prAsr, 0);
    3  : SetFajrAsrIshaaValue(prAsr, spnAsrSetting.Value);
  end;
end;

procedure TfrmPrayerMinderSettings.rgpDaylSavOnClick(Sender: TObject);
begin
  SetDaylSavings(GetDaylSavings);
end;

end.
