import 'package:equatable/equatable.dart';
import 'package:torq/features/analytics/domain/models/analytics_models.dart';

enum AnalyticsLoadStatus { initial, loading, loaded, failure }

class AnalyticsState extends Equatable {
  const AnalyticsState({
    this.status = AnalyticsLoadStatus.initial,
    this.vehicleId,
    this.thisMonthSpend = 0,
    this.allTimeSpend = 0,
    this.avgKmPerL,
    this.costPerKm,
    this.monthlySpend = const [],
    this.fuelTrend = const [],
    this.categoryBreakdown = const {},
    this.error,
  });

  final AnalyticsLoadStatus status;
  final String? vehicleId;
  final double thisMonthSpend;
  final double allTimeSpend;
  final double? avgKmPerL;
  final double? costPerKm;
  final List<MonthlySpendPoint> monthlySpend;
  final List<FuelTrendPoint> fuelTrend;
  final Map<String, double> categoryBreakdown;
  final String? error;

  AnalyticsState copyWith({
    AnalyticsLoadStatus? status,
    String? vehicleId,
    double? thisMonthSpend,
    double? allTimeSpend,
    double? avgKmPerL,
    bool clearAvgKmPerL = false,
    double? costPerKm,
    bool clearCostPerKm = false,
    List<MonthlySpendPoint>? monthlySpend,
    List<FuelTrendPoint>? fuelTrend,
    Map<String, double>? categoryBreakdown,
    String? error,
    bool clearError = false,
  }) {
    return AnalyticsState(
      status: status ?? this.status,
      vehicleId: vehicleId ?? this.vehicleId,
      thisMonthSpend: thisMonthSpend ?? this.thisMonthSpend,
      allTimeSpend: allTimeSpend ?? this.allTimeSpend,
      avgKmPerL: clearAvgKmPerL ? null : (avgKmPerL ?? this.avgKmPerL),
      costPerKm: clearCostPerKm ? null : (costPerKm ?? this.costPerKm),
      monthlySpend: monthlySpend ?? this.monthlySpend,
      fuelTrend: fuelTrend ?? this.fuelTrend,
      categoryBreakdown: categoryBreakdown ?? this.categoryBreakdown,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        vehicleId,
        thisMonthSpend,
        allTimeSpend,
        avgKmPerL,
        costPerKm,
        monthlySpend,
        fuelTrend,
        categoryBreakdown,
        error,
      ];
}
