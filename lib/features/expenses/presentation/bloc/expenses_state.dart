import 'package:equatable/equatable.dart';
import 'package:torq/core/database/app_database.dart';

enum ExpensesLoadStatus { initial, loading, loaded, failure }

class ExpensesState extends Equatable {
  const ExpensesState({
    this.status = ExpensesLoadStatus.initial,
    this.vehicleId,
    this.expenses = const [],
    this.monthlyTotal = 0,
    this.allTimeTotal = 0,
    this.error,
  });

  final ExpensesLoadStatus status;
  final String? vehicleId;
  final List<Expense> expenses;
  final double monthlyTotal;
  final double allTimeTotal;
  final String? error;

  ExpensesState copyWith({
    ExpensesLoadStatus? status,
    String? vehicleId,
    List<Expense>? expenses,
    double? monthlyTotal,
    double? allTimeTotal,
    String? error,
    bool clearError = false,
  }) {
    return ExpensesState(
      status: status ?? this.status,
      vehicleId: vehicleId ?? this.vehicleId,
      expenses: expenses ?? this.expenses,
      monthlyTotal: monthlyTotal ?? this.monthlyTotal,
      allTimeTotal: allTimeTotal ?? this.allTimeTotal,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        vehicleId,
        expenses,
        monthlyTotal,
        allTimeTotal,
        error,
      ];
}
