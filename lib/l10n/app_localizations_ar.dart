// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'تورك';

  @override
  String get appTagline => 'متابعة صيانة السيارة والوقود والمصاريف';

  @override
  String get navDashboard => 'الرئيسية';

  @override
  String get navMaintenance => 'الصيانة';

  @override
  String get navFuel => 'الوقود';

  @override
  String get navExpenses => 'المصاريف';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get statusOk => 'سليم';

  @override
  String get statusDueSoon => 'قريب الاستحقاق';

  @override
  String get statusOverdue => 'متأخر';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionEdit => 'تعديل';

  @override
  String get actionAdd => 'إضافة';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get proBadge => 'برو';

  @override
  String get unitKm => 'كم';

  @override
  String get unitMi => 'ميل';

  @override
  String get unitLiters => 'لتر';

  @override
  String get unitKmPerL => 'كم/لتر';

  @override
  String get presetEngineOil => 'زيت المحرك';

  @override
  String get presetOilFilter => 'فلتر الزيت';

  @override
  String get presetAirFilter => 'فلتر الهواء';

  @override
  String get presetAcFilter => 'فلتر التكييف';

  @override
  String get presetBrakePads => 'تيل الفرامل';

  @override
  String get presetTires => 'الإطارات';

  @override
  String get presetBattery => 'البطارية';

  @override
  String get presetTimingBelt => 'سير الكاتينة';

  @override
  String get presetSparkPlugs => 'البوجيهات';

  @override
  String get presetTransmissionOil => 'زيت الفتيس';

  @override
  String get emptyVehiclesTitle => 'لا توجد سيارات بعد';

  @override
  String get emptyVehiclesSubtitle =>
      'أضف سيارتك الأولى لبدء متابعة الصيانة والوقود والمصاريف.';

  @override
  String get emptyMaintenanceTitle => 'لا توجد سجلات صيانة';

  @override
  String get emptyMaintenanceSubtitle =>
      'سجّل أول صيانة للحصول على تنبيهات ذكية حسب العداد والتاريخ.';

  @override
  String get emptyFuelTitle => 'لا توجد سجلات وقود';

  @override
  String get emptyFuelSubtitle =>
      'سجّل عملية التزود بالوقود لحساب الاستهلاك والمصروف الشهري.';

  @override
  String get emptyExpensesTitle => 'لا توجد مصاريف بعد';

  @override
  String get emptyExpensesSubtitle =>
      'تابع التأمين والغسيل والركن والرسوم والإصلاحات في مكان واحد.';
}
