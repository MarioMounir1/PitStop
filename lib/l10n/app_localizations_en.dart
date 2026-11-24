// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Torq';

  @override
  String get appTagline => 'Car Maintenance, Fuel & Expense Tracker';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navMaintenance => 'Maintenance';

  @override
  String get navFuel => 'Fuel';

  @override
  String get navExpenses => 'Expenses';

  @override
  String get navSettings => 'Settings';

  @override
  String get statusOk => 'OK';

  @override
  String get statusDueSoon => 'Due Soon';

  @override
  String get statusOverdue => 'Overdue';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionRetry => 'Retry';

  @override
  String get proBadge => 'PRO';

  @override
  String get unitKm => 'km';

  @override
  String get unitMi => 'mi';

  @override
  String get unitLiters => 'L';

  @override
  String get unitKmPerL => 'km/L';

  @override
  String get presetEngineOil => 'Engine Oil';

  @override
  String get presetOilFilter => 'Oil Filter';

  @override
  String get presetAirFilter => 'Air Filter';

  @override
  String get presetAcFilter => 'AC Filter';

  @override
  String get presetBrakePads => 'Brake Pads';

  @override
  String get presetTires => 'Tires';

  @override
  String get presetBattery => 'Battery';

  @override
  String get presetTimingBelt => 'Timing Belt';

  @override
  String get presetSparkPlugs => 'Spark Plugs';

  @override
  String get presetTransmissionOil => 'Transmission Oil';

  @override
  String get emptyVehiclesTitle => 'No vehicles yet';

  @override
  String get emptyVehiclesSubtitle =>
      'Add your first car to start tracking maintenance, fuel, and expenses.';

  @override
  String get emptyMaintenanceTitle => 'No maintenance records';

  @override
  String get emptyMaintenanceSubtitle =>
      'Log your first service to get smart odometer and date reminders.';

  @override
  String get emptyFuelTitle => 'No fuel logs yet';

  @override
  String get emptyFuelSubtitle =>
      'Record a fill-up to track fuel economy and monthly spend.';

  @override
  String get emptyExpensesTitle => 'No expenses yet';

  @override
  String get emptyExpensesSubtitle =>
      'Track insurance, washes, parking, tolls, and repairs in one place.';
}
