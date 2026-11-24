import 'package:equatable/equatable.dart';
import 'package:torq/core/database/app_database.dart';

enum FuelLoadStatus { initial, loading, loaded, failure }

class FuelState extends Equatable {
  const FuelState({
    this.status = FuelLoadStatus.initial,
    this.vehicleId,
    this.logs = const [],
    this.averageKmPerL,
    this.monthlyFuelSpend = 0,
    this.totalLiters = 0,
    this.error,
  });

  final FuelLoadStatus status;
  final String? vehicleId;
  final List<FuelLog> logs;
  final double? averageKmPerL;
  final double monthlyFuelSpend;
  final double totalLiters;
  final String? error;

  FuelState copyWith({
    FuelLoadStatus? status,
    String? vehicleId,
    List<FuelLog>? logs,
    double? averageKmPerL,
    bool clearAverageKmPerL = false,
    double? monthlyFuelSpend,
    double? totalLiters,
    String? error,
    bool clearError = false,
  }) {
    return FuelState(
      status: status ?? this.status,
      vehicleId: vehicleId ?? this.vehicleId,
      logs: logs ?? this.logs,
      averageKmPerL: clearAverageKmPerL
          ? null
          : (averageKmPerL ?? this.averageKmPerL),
      monthlyFuelSpend: monthlyFuelSpend ?? this.monthlyFuelSpend,
      totalLiters: totalLiters ?? this.totalLiters,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        vehicleId,
        logs,
        averageKmPerL,
        monthlyFuelSpend,
        totalLiters,
        error,
      ];
}
