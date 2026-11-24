import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/core/theme/app_colors.dart';
import 'package:torq/core/utils/currency_formatter.dart';
import 'package:torq/core/widgets/empty_state_widget.dart';
import 'package:torq/features/expenses/domain/constants/expense_categories.dart';
import 'package:torq/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:torq/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:torq/features/expenses/presentation/bloc/expenses_state.dart';
import 'package:torq/features/expenses/presentation/pages/add_expense_page.dart';
import 'package:torq/features/fuel/presentation/bloc/fuel_bloc.dart';
import 'package:torq/features/fuel/presentation/pages/add_fuel_log_page.dart';
import 'package:torq/features/fuel/presentation/widgets/fuel_list_widget.dart';

enum _LedgerTab { fuel, expenses }

/// Combined page with a segmented toggle switching between Fuel Logs
/// and General Expenses, with a contextual FAB.
class FuelAndExpensesPage extends StatefulWidget {
  const FuelAndExpensesPage({
    required this.vehicle,
    super.key,
  });

  final Vehicle? vehicle;

  @override
  State<FuelAndExpensesPage> createState() => _FuelAndExpensesPageState();
}

class _FuelAndExpensesPageState extends State<FuelAndExpensesPage> {
  _LedgerTab _activeTab = _LedgerTab.fuel;

  void _openAddFuel(BuildContext context, Vehicle vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<FuelBloc>(),
          child: AddFuelLogPage(vehicle: vehicle),
        ),
      ),
    );
  }

  void _openAddExpense(BuildContext context, Vehicle vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<ExpensesBloc>(),
          child: AddExpensePage(vehicle: vehicle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final vehicle = widget.vehicle;

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'الوقود والمصاريف' : 'Fuel & Expenses'),
        ),
        body: EmptyStateWidget(
          icon: Icons.local_gas_station_outlined,
          title: isArabic ? 'اختر سيارة أولاً' : 'No active vehicle',
          subtitle: isArabic
              ? 'أضف سيارة في الجراج لبدء متابعة الوقود والمصاريف.'
              : 'Add a vehicle in your garage to start tracking fuel and expenses.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الوقود والمصاريف' : 'Fuel & Expenses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_activeTab == _LedgerTab.fuel) {
            _openAddFuel(context, vehicle);
          } else {
            _openAddExpense(context, vehicle);
          }
        },
        icon: Icon(
          _activeTab == _LedgerTab.fuel
              ? Icons.local_gas_station_rounded
              : Icons.add_card_rounded,
        ),
        label: Text(
          _activeTab == _LedgerTab.fuel
              ? (isArabic ? 'إضافة وقود' : 'Add Fuel')
              : (isArabic ? 'إضافة مصروف' : 'Add Expense'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: SegmentedButton<_LedgerTab>(
              segments: [
                ButtonSegment(
                  value: _LedgerTab.fuel,
                  icon: const Icon(Icons.local_gas_station_rounded, size: 18),
                  label: Text(isArabic ? 'الوقود' : 'Fuel Logs'),
                ),
                ButtonSegment(
                  value: _LedgerTab.expenses,
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: Text(isArabic ? 'المصاريف' : 'Expenses'),
                ),
              ],
              selected: {_activeTab},
              onSelectionChanged: (selection) {
                setState(() => _activeTab = selection.first);
              },
            ),
          ),
          Expanded(
            child: _activeTab == _LedgerTab.fuel
                ? FuelListWidget(
                    vehicle: vehicle,
                    onAddFuel: () => _openAddFuel(context, vehicle),
                  )
                : _ExpensesListView(
                    vehicle: vehicle,
                    onAddExpense: () => _openAddExpense(context, vehicle),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExpensesListView extends StatelessWidget {
  const _ExpensesListView({
    required this.vehicle,
    required this.onAddExpense,
  });

  final Vehicle vehicle;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final colors = context.appColors;
    final dateFormat = DateFormat('yyyy-MM-dd');

    return BlocBuilder<ExpensesBloc, ExpensesState>(
      builder: (context, state) {
        if (state.status == ExpensesLoadStatus.loading &&
            state.expenses.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.expenses.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.receipt_long_outlined,
            title: isArabic ? 'لا توجد مصاريف بعد' : 'No expenses yet',
            subtitle: isArabic
                ? 'تابع التأمين والغسيل والركن والرسوم والإصلاحات في مكان واحد.'
                : 'Track insurance, washes, parking, tolls, and repairs in one place.',
            actionLabel: isArabic ? 'إضافة مصروف' : 'Add Expense',
            onAction: onAddExpense,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'مصاريف هذا الشهر' : 'This Month Expenses',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: colors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(
                            state.monthlyTotal,
                            currencyCode: vehicle.currencyCode,
                            locale: isArabic ? 'ar' : 'en',
                            decimalDigits: 0,
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isArabic ? 'الإجمالي الكلي' : 'All Time',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: colors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatCompact(
                            state.allTimeTotal,
                            currencyCode: vehicle.currencyCode,
                            locale: isArabic ? 'ar' : 'en',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final expense in state.expenses) ...[
              Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.elevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      ExpenseCategories.icon(expense.category),
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    expense.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${ExpenseCategories.label(expense.category, isArabic: isArabic)} • '
                    '${dateFormat.format(expense.date)}',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyFormatter.format(
                          expense.amount,
                          currencyCode: vehicle.currencyCode,
                          locale: isArabic ? 'ar' : 'en',
                          decimalDigits: 0,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                        ),
                        color: colors.textMuted,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => context
                            .read<ExpensesBloc>()
                            .add(ExpenseDeleted(expense.id)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
