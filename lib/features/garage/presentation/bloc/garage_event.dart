import 'package:equatable/equatable.dart';
import 'package:torq/core/database/app_database.dart';

sealed class GarageEvent extends Equatable {
  const GarageEvent();

  @override
  List<Object?> get props => [];
}

final class GarageStarted extends GarageEvent {
  const GarageStarted();
}

final class GarageVehiclesUpdated extends GarageEvent {
  const GarageVehiclesUpdated(this.vehicles);

  final List<Vehicle> vehicles;

  @override
  List<Object?> get props => [vehicles];
}

final class GarageVehicleAdded extends GarageEvent {
  const GarageVehicleAdded({
    required this.vehicle,
    required this.isPro,
  });

  final VehiclesCompanion vehicle;
  final bool isPro;

  @override
  List<Object?> get props => [vehicle, isPro];
}

final class GarageVehicleUpdated extends GarageEvent {
  const GarageVehicleUpdated(this.vehicle);

  final VehiclesCompanion vehicle;

  @override
  List<Object?> get props => [vehicle];
}

final class GarageVehicleDeleted extends GarageEvent {
  const GarageVehicleDeleted(this.vehicleId);

  final String vehicleId;

  @override
  List<Object?> get props => [vehicleId];
}

final class GarageActiveVehicleSelected extends GarageEvent {
  const GarageActiveVehicleSelected(this.vehicleId);

  final String vehicleId;

  @override
  List<Object?> get props => [vehicleId];
}

final class GarageOdometerUpdated extends GarageEvent {
  const GarageOdometerUpdated({
    required this.vehicleId,
    required this.newOdometer,
  });

  final String vehicleId;
  final int newOdometer;

  @override
  List<Object?> get props => [vehicleId, newOdometer];
}

final class GaragePaywallAcknowledged extends GarageEvent {
  const GaragePaywallAcknowledged();
}
