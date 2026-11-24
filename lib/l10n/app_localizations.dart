import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Torq'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Car Maintenance, Fuel & Expense Tracker'**
  String get appTagline;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get navMaintenance;

  /// No description provided for @navFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get navFuel;

  /// No description provided for @navFuelAndCosts.
  ///
  /// In en, this message translates to:
  /// **'Fuel & Costs'**
  String get navFuelAndCosts;

  /// No description provided for @navAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navAnalytics;

  /// No description provided for @navExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get navExpenses;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @garageTitle.
  ///
  /// In en, this message translates to:
  /// **'My Garage'**
  String get garageTitle;

  /// No description provided for @addVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add Vehicle'**
  String get addVehicle;

  /// No description provided for @currentOdometer.
  ///
  /// In en, this message translates to:
  /// **'Current Odometer'**
  String get currentOdometer;

  /// No description provided for @updateOdometer.
  ///
  /// In en, this message translates to:
  /// **'Update Odo'**
  String get updateOdometer;

  /// No description provided for @urgentAlerts.
  ///
  /// In en, this message translates to:
  /// **'Attention Needed'**
  String get urgentAlerts;

  /// No description provided for @allSystemsOk.
  ///
  /// In en, this message translates to:
  /// **'All maintenance & documents are up to date'**
  String get allSystemsOk;

  /// No description provided for @monthlySpend.
  ///
  /// In en, this message translates to:
  /// **'This Month Spend'**
  String get monthlySpend;

  /// No description provided for @avgFuelEconomy.
  ///
  /// In en, this message translates to:
  /// **'Avg Economy'**
  String get avgFuelEconomy;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @logService.
  ///
  /// In en, this message translates to:
  /// **'Log Service'**
  String get logService;

  /// No description provided for @logFuel.
  ///
  /// In en, this message translates to:
  /// **'Log Fuel'**
  String get logFuel;

  /// No description provided for @logExpense.
  ///
  /// In en, this message translates to:
  /// **'Log Expense'**
  String get logExpense;

  /// No description provided for @statusOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get statusOk;

  /// No description provided for @statusDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due Soon'**
  String get statusDueSoon;

  /// No description provided for @statusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get statusOverdue;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @proBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get proBadge;

  /// No description provided for @unitKm.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get unitKm;

  /// No description provided for @unitMi.
  ///
  /// In en, this message translates to:
  /// **'mi'**
  String get unitMi;

  /// No description provided for @unitLiters.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get unitLiters;

  /// No description provided for @unitKmPerL.
  ///
  /// In en, this message translates to:
  /// **'km/L'**
  String get unitKmPerL;

  /// No description provided for @presetEngineOil.
  ///
  /// In en, this message translates to:
  /// **'Engine Oil'**
  String get presetEngineOil;

  /// No description provided for @presetOilFilter.
  ///
  /// In en, this message translates to:
  /// **'Oil Filter'**
  String get presetOilFilter;

  /// No description provided for @presetAirFilter.
  ///
  /// In en, this message translates to:
  /// **'Air Filter'**
  String get presetAirFilter;

  /// No description provided for @presetAcFilter.
  ///
  /// In en, this message translates to:
  /// **'AC Filter'**
  String get presetAcFilter;

  /// No description provided for @presetBrakePads.
  ///
  /// In en, this message translates to:
  /// **'Brake Pads'**
  String get presetBrakePads;

  /// No description provided for @presetTires.
  ///
  /// In en, this message translates to:
  /// **'Tires'**
  String get presetTires;

  /// No description provided for @presetBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get presetBattery;

  /// No description provided for @presetTimingBelt.
  ///
  /// In en, this message translates to:
  /// **'Timing Belt'**
  String get presetTimingBelt;

  /// No description provided for @presetSparkPlugs.
  ///
  /// In en, this message translates to:
  /// **'Spark Plugs'**
  String get presetSparkPlugs;

  /// No description provided for @presetTransmissionOil.
  ///
  /// In en, this message translates to:
  /// **'Transmission Oil'**
  String get presetTransmissionOil;

  /// No description provided for @emptyVehiclesTitle.
  ///
  /// In en, this message translates to:
  /// **'No vehicles yet'**
  String get emptyVehiclesTitle;

  /// No description provided for @emptyVehiclesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first car to start tracking maintenance, fuel, and expenses.'**
  String get emptyVehiclesSubtitle;

  /// No description provided for @emptyMaintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'No maintenance records'**
  String get emptyMaintenanceTitle;

  /// No description provided for @emptyMaintenanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log your first service to get smart odometer and date reminders.'**
  String get emptyMaintenanceSubtitle;

  /// No description provided for @emptyFuelTitle.
  ///
  /// In en, this message translates to:
  /// **'No fuel logs yet'**
  String get emptyFuelTitle;

  /// No description provided for @emptyFuelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record a fill-up to track fuel economy and monthly spend.'**
  String get emptyFuelSubtitle;

  /// No description provided for @emptyExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get emptyExpensesTitle;

  /// No description provided for @emptyExpensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track insurance, washes, parking, tolls, and repairs in one place.'**
  String get emptyExpensesSubtitle;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Torq Pro'**
  String get paywallTitle;

  /// No description provided for @paywallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock unlimited vehicles, clean resale PDFs, backups, and zero ads.'**
  String get paywallSubtitle;

  /// No description provided for @paywallUnlimitedCars.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Cars'**
  String get paywallUnlimitedCars;

  /// No description provided for @paywallCleanPdf.
  ///
  /// In en, this message translates to:
  /// **'Clean Resale PDF'**
  String get paywallCleanPdf;

  /// No description provided for @paywallReceiptPhotos.
  ///
  /// In en, this message translates to:
  /// **'Receipt Photos'**
  String get paywallReceiptPhotos;

  /// No description provided for @paywallJsonBackup.
  ///
  /// In en, this message translates to:
  /// **'JSON Backup & Restore'**
  String get paywallJsonBackup;

  /// No description provided for @paywallZeroAds.
  ///
  /// In en, this message translates to:
  /// **'Zero Ads'**
  String get paywallZeroAds;

  /// No description provided for @paywallMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get paywallMonthly;

  /// No description provided for @paywallYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get paywallYearly;

  /// No description provided for @paywallLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get paywallLifetime;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get paywallRestore;

  /// No description provided for @settingsAppearanceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Appearance & Language'**
  String get settingsAppearanceLanguage;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsDark;

  /// No description provided for @settingsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsLight;

  /// No description provided for @settingsUnitsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Units & Currency'**
  String get settingsUnitsCurrency;

  /// No description provided for @settingsDefaultDistanceUnit.
  ///
  /// In en, this message translates to:
  /// **'Default Distance Unit'**
  String get settingsDefaultDistanceUnit;

  /// No description provided for @settingsDefaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default Currency'**
  String get settingsDefaultCurrency;

  /// No description provided for @settingsDataBackup.
  ///
  /// In en, this message translates to:
  /// **'Data & Backup'**
  String get settingsDataBackup;

  /// No description provided for @settingsExportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export JSON Backup'**
  String get settingsExportBackup;

  /// No description provided for @settingsRestoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore JSON Backup'**
  String get settingsRestoreBackup;

  /// No description provided for @settingsUpgradePro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Torq Pro'**
  String get settingsUpgradePro;

  /// No description provided for @settingsProActive.
  ///
  /// In en, this message translates to:
  /// **'Torq Pro Active'**
  String get settingsProActive;

  /// No description provided for @exportResalePdf.
  ///
  /// In en, this message translates to:
  /// **'Export Resale Maintenance Report (PDF)'**
  String get exportResalePdf;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
