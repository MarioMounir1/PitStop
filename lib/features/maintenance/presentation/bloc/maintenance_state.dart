import 'package:equatable/equatable.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/utils/reminder_calculator.dart';

enum MaintenanceLoadStatus { initial, loading, loaded, failure }

enum MaintenanceFilter { all, upcoming, history }

class MaintenanceState extends Equatable {
  const MaintenanceState({
    this.status = MaintenanceLoadStatus.initial,
    this.vehicleId,
    this.currentOdometer = 0,
    this.records = const [],
    this.statusByRecordId = const {},
    this.statusByCategory = const {},
    this.overdueCount = 0,
    this.dueSoonCount = 0,
    this.filter = MaintenanceFilter.all,
    this.error,
  });

  final MaintenanceLoadStatus status;
  final String? vehicleId;
  final int currentOdometer;
  final List<MaintenanceRecord> records;
  final Map<String, MaintenanceStatus> statusByRecordId;
  final Map<String, MaintenanceStatus> statusByCategory;
  final int overdueCount;
  final int dueSoonCount;
  final MaintenanceFilter filter;
  final String? error;

  List<MaintenanceRecord> get filteredRecords {
    return switch (filter) {
      MaintenanceFilter.all => records,
      MaintenanceFilter.upcoming => records.where((r) {
          final st = statusByRecordId[r.id] ?? MaintenanceStatus.ok;
          return !r.isCompleted ||
              st == MaintenanceStatus.overdue ||
              st == MaintenanceStatus.dueSoon;
        }).toList(),
      MaintenanceFilter.history =>
        records.where((r) => r.isCompleted).toList(),
    };
  }

  MaintenanceState copyWith({
    MaintenanceLoadStatus? status,
    String? vehicleId,
    int? currentOdometer,
    List<MaintenanceRecord>? records,
    Map<String, MaintenanceStatus>? statusByRecordId,
    Map<String, MaintenanceStatus>? statusByCategory,
    int? overdueCount,
    int? dueSoonCount,
    MaintenanceFilter? filter,
    String? error,
    bool clearError = false,
  }) {
    return MaintenanceState(
      status: status ?? this.status,
      vehicleId: vehicleId ?? this.vehicleId,
      currentOdometer: currentOdometer ?? this.currentOdometer,
      records: records ?? this.records,
      statusByRecordId: statusByRecordId ?? this.statusByRecordId,
      statusByCategory: statusByCategory ?? this.statusByCategory,
      overdueCount: overdueCount ?? this.overdueCount,
      dueSoonCount: dueSoonCount ?? this.dueSoonCount,
      filter: filter ?? this.filter,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        vehicleId,
        currentOdometer,
        records,
        statusByRecordId,
        statusByCategory,
        overdueCount,
        dueSoonCount,
        filter,
        error,
      ];
}
