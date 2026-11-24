import 'package:equatable/equatable.dart';
import 'package:pitstop/core/database/app_database.dart';

sealed class FuelEvent extends Equatable {
  const FuelEvent();

  @override
  List<Object?> get props => [];
}

final class FuelVehicleSubscribed extends FuelEvent {
  const FuelVehicleSubscribed(this.vehicleId);

  final String vehicleId;

  @override
  List<Object?> get props => [vehicleId];
}

final class FuelLogsUpdated extends FuelEvent {
  const FuelLogsUpdated(this.logs);

  final List<FuelLog> logs;

  @override
  List<Object?> get props => [logs];
}

final class FuelLogAdded extends FuelEvent {
  const FuelLogAdded(this.log);

  final FuelLogsCompanion log;

  @override
  List<Object?> get props => [log];
}

final class FuelLogUpdated extends FuelEvent {
  const FuelLogUpdated(this.log);

  final FuelLogsCompanion log;

  @override
  List<Object?> get props => [log];
}

final class FuelLogDeleted extends FuelEvent {
  const FuelLogDeleted(this.logId);

  final String logId;

  @override
  List<Object?> get props => [logId];
}
