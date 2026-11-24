import 'package:equatable/equatable.dart';

sealed class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object?> get props => [];
}

final class AnalyticsVehicleSubscribed extends AnalyticsEvent {
  const AnalyticsVehicleSubscribed({
    required this.vehicleId,
    required this.currentOdometer,
  });

  final String vehicleId;
  final int currentOdometer;

  @override
  List<Object?> get props => [vehicleId, currentOdometer];
}

final class AnalyticsRecomputeRequested extends AnalyticsEvent {
  const AnalyticsRecomputeRequested();
}
