import 'package:equatable/equatable.dart';
import 'package:torq/core/database/app_database.dart';

enum GarageStatus { initial, loading, loaded, failure }

class GarageState extends Equatable {
  const GarageState({
    this.status = GarageStatus.initial,
    this.vehicles = const [],
    this.activeVehicle,
    this.paywallRequired = false,
    this.error,
  });

  final GarageStatus status;
  final List<Vehicle> vehicles;
  final Vehicle? activeVehicle;

  /// Set to `true` when a Free user attempts to add a 2nd vehicle.
  final bool paywallRequired;
  final String? error;

  GarageState copyWith({
    GarageStatus? status,
    List<Vehicle>? vehicles,
    Vehicle? activeVehicle,
    bool clearActiveVehicle = false,
    bool? paywallRequired,
    String? error,
    bool clearError = false,
  }) {
    return GarageState(
      status: status ?? this.status,
      vehicles: vehicles ?? this.vehicles,
      activeVehicle:
          clearActiveVehicle ? null : (activeVehicle ?? this.activeVehicle),
      paywallRequired: paywallRequired ?? this.paywallRequired,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        vehicles,
        activeVehicle,
        paywallRequired,
        error,
      ];
}
