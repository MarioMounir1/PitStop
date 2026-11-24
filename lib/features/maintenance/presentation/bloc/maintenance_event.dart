import 'package:equatable/equatable.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/features/maintenance/presentation/bloc/maintenance_state.dart';

sealed class MaintenanceEvent extends Equatable {
  const MaintenanceEvent();

  @override
  List<Object?> get props => [];
}

final class MaintenanceVehicleSubscribed extends MaintenanceEvent {
  const MaintenanceVehicleSubscribed({
    required this.vehicleId,
    required this.currentOdometer,
  });

  final String vehicleId;
  final int currentOdometer;

  @override
  List<Object?> get props => [vehicleId, currentOdometer];
}

final class MaintenanceRecordsUpdated extends MaintenanceEvent {
  const MaintenanceRecordsUpdated(this.records);

  final List<MaintenanceRecord> records;

  @override
  List<Object?> get props => [records];
}

final class MaintenanceFilterChanged extends MaintenanceEvent {
  const MaintenanceFilterChanged(this.filter);

  final MaintenanceFilter filter;

  @override
  List<Object?> get props => [filter];
}

final class MaintenanceRecordAdded extends MaintenanceEvent {
  const MaintenanceRecordAdded(this.record);

  final MaintenanceRecordsCompanion record;

  @override
  List<Object?> get props => [record];
}

final class MaintenanceRecordUpdated extends MaintenanceEvent {
  const MaintenanceRecordUpdated(this.record);

  final MaintenanceRecordsCompanion record;

  @override
  List<Object?> get props => [record];
}

final class MaintenanceRecordDeleted extends MaintenanceEvent {
  const MaintenanceRecordDeleted(this.recordId);

  final String recordId;

  @override
  List<Object?> get props => [recordId];
}
