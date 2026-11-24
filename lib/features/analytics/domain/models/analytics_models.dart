import 'package:equatable/equatable.dart';

/// Monthly spend breakdown point for the last-6-months bar chart.
class MonthlySpendPoint extends Equatable {
  const MonthlySpendPoint({
    required this.month,
    required this.maintenance,
    required this.fuel,
    required this.expenses,
  });

  final DateTime month;
  final double maintenance;
  final double fuel;
  final double expenses;

  double get total => maintenance + fuel + expenses;

  @override
  List<Object?> get props => [month, maintenance, fuel, expenses];
}

/// Fuel economy data point for the `km/L` trend line chart.
class FuelTrendPoint extends Equatable {
  const FuelTrendPoint({
    required this.date,
    required this.kmPerL,
  });

  final DateTime date;
  final double kmPerL;

  @override
  List<Object?> get props => [date, kmPerL];
}
