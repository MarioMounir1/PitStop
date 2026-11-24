import 'package:equatable/equatable.dart';
import 'package:pitstop/core/database/app_database.dart';

sealed class ExpensesEvent extends Equatable {
  const ExpensesEvent();

  @override
  List<Object?> get props => [];
}

final class ExpensesVehicleSubscribed extends ExpensesEvent {
  const ExpensesVehicleSubscribed(this.vehicleId);

  final String vehicleId;

  @override
  List<Object?> get props => [vehicleId];
}

final class ExpensesListUpdated extends ExpensesEvent {
  const ExpensesListUpdated(this.expenses);

  final List<Expense> expenses;

  @override
  List<Object?> get props => [expenses];
}

final class ExpensesMonthlyTotalUpdated extends ExpensesEvent {
  const ExpensesMonthlyTotalUpdated(this.monthlyTotal);

  final double monthlyTotal;

  @override
  List<Object?> get props => [monthlyTotal];
}

final class ExpenseAdded extends ExpensesEvent {
  const ExpenseAdded(this.expense);

  final ExpensesCompanion expense;

  @override
  List<Object?> get props => [expense];
}

final class ExpenseUpdated extends ExpensesEvent {
  const ExpenseUpdated(this.expense);

  final ExpensesCompanion expense;

  @override
  List<Object?> get props => [expense];
}

final class ExpenseDeleted extends ExpensesEvent {
  const ExpenseDeleted(this.expenseId);

  final String expenseId;

  @override
  List<Object?> get props => [expenseId];
}
