import 'package:flutter/material.dart';

/// Standard general expense categories for PitStop.
abstract final class ExpenseCategories {
  static const String wash = 'wash';
  static const String parking = 'parking';
  static const String tolls = 'tolls';
  static const String fines = 'fines';
  static const String licensing = 'licensing';
  static const String insurance = 'insurance';
  static const String accessories = 'accessories';
  static const String other = 'other';

  static const List<String> all = [
    wash,
    parking,
    tolls,
    fines,
    licensing,
    insurance,
    accessories,
    other,
  ];

  static String label(String category, {required bool isArabic}) {
    return switch (category) {
      wash => isArabic ? 'غسيل' : 'Wash',
      parking => isArabic ? 'ركن' : 'Parking',
      tolls => isArabic ? 'رسوم طرق' : 'Tolls',
      fines => isArabic ? 'مخالفات' : 'Fines',
      licensing => isArabic ? 'ترخيص' : 'Licensing',
      insurance => isArabic ? 'تأمين' : 'Insurance',
      accessories => isArabic ? 'إكسسوارات' : 'Accessories',
      _ => isArabic ? 'أخرى' : 'Other',
    };
  }

  static IconData icon(String category) {
    return switch (category) {
      wash => Icons.local_car_wash_rounded,
      parking => Icons.local_parking_rounded,
      tolls => Icons.toll_rounded,
      fines => Icons.gavel_rounded,
      licensing => Icons.badge_outlined,
      insurance => Icons.shield_outlined,
      accessories => Icons.auto_awesome_outlined,
      _ => Icons.receipt_outlined,
    };
  }
}
