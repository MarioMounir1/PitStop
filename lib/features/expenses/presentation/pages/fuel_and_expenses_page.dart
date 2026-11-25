import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/theme/app_colors.dart';
import 'package:pitstop/core/widgets/empty_state_widget.dart';
import 'package:pitstop/features/expenses/domain/constants/expense_categories.dart';
import 'package:pitstop/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:pitstop/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:pitstop/features/expenses/presentation/bloc/expenses_state.dart';
import 'package:pitstop/features/expenses/presentation/pages/add_expense_page.dart';
import 'package:pitstop/features/fuel/presentation/bloc/fuel_bloc.dart';
import 'package:pitstop/features/fuel/presentation/bloc/fuel_event.dart';
import 'package:pitstop/features/fuel/presentation/pages/add_fuel_log_page.dart';
import 'package:pitstop/features/fuel/presentation/widgets/fuel_list_widget.dart';
import 'package:uuid/uuid.dart';

enum _LedgerTab { fuel, expenses }

enum _QuickFuelField { liters, pricePerLiter, totalCost }

/// Fuel & Costs tab matching the new design:
/// - Inline smart 2-of-3 `New fill-up` card (or `New expense` card)
/// - Dual pill toggle (`Fuel` | `Expenses`)
/// - Clean chronological ledger cards below.
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

  void _openFullAddFuel(BuildContext context, Vehicle vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<FuelBloc>(),
          child: AddFuelLogPage(vehicle: vehicle),
        ),
      ),
    );
  }

  void _openFullAddExpense(BuildContext context, Vehicle vehicle) {
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
          title: Text(isArabic ? 'الوقود والمصاريف' : 'Fuel & Costs'),
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
        title: Text(isArabic ? 'الوقود والمصاريف' : 'Fuel & Costs'),
        actions: [
          IconButton(
            tooltip: _activeTab == _LedgerTab.fuel
                ? (isArabic ? 'تفاصيل متقدمة' : 'Detailed fuel form')
                : (isArabic ? 'إضافة مصروف مفصل' : 'Detailed expense form'),
            icon: Icon(
              Icons.tune_rounded,
              color: context.appColors.textSecondary,
            ),
            onPressed: () {
              if (_activeTab == _LedgerTab.fuel) {
                _openFullAddFuel(context, vehicle);
              } else {
                _openFullAddExpense(context, vehicle);
              }
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // Top Inline Quick Entry Card
          if (_activeTab == _LedgerTab.fuel)
            _InlineNewFillUpCard(vehicle: vehicle, isArabic: isArabic)
          else
            _InlineNewExpenseCard(vehicle: vehicle, isArabic: isArabic),

          const SizedBox(height: 16),

          // Dual Pill Toggle (Fuel | Expenses)
          Row(
            children: [
              Expanded(
                child: _TabPillButton(
                  label: isArabic ? 'الوقود' : 'Fuel',
                  isSelected: _activeTab == _LedgerTab.fuel,
                  onTap: () => setState(() => _activeTab = _LedgerTab.fuel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TabPillButton(
                  label: isArabic ? 'المصاريف' : 'Expenses',
                  isSelected: _activeTab == _LedgerTab.expenses,
                  onTap: () => setState(() => _activeTab = _LedgerTab.expenses),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Ledger list
          if (_activeTab == _LedgerTab.fuel)
            FuelListWidget(
              vehicle: vehicle,
              embedded: true,
              onAddFuel: () => _openFullAddFuel(context, vehicle),
            )
          else
            _ExpensesLedgerList(
              vehicle: vehicle,
              isArabic: isArabic,
            ),
        ],
      ),
    );
  }
}

class _TabPillButton extends StatelessWidget {
  const _TabPillButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: isSelected ? AppColors.primary : colors.elevated,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? AppColors.primary : colors.border,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isSelected
                        ? AppColors.onPrimary
                        : colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineNewFillUpCard extends StatefulWidget {
  const _InlineNewFillUpCard({
    required this.vehicle,
    required this.isArabic,
  });

  final Vehicle vehicle;
  final bool isArabic;

  @override
  State<_InlineNewFillUpCard> createState() => _InlineNewFillUpCardState();
}

class _InlineNewFillUpCardState extends State<_InlineNewFillUpCard> {
  final _litersController = TextEditingController();
  final _priceController = TextEditingController();
  final _totalController = TextEditingController();
  bool _isUpdating = false;
  final List<_QuickFuelField> _recentEdited = [];

  @override
  void dispose() {
    _litersController.dispose();
    _priceController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _onChanged(_QuickFuelField field) {
    if (_isUpdating) return;

    _recentEdited.remove(field);
    _recentEdited.add(field);
    if (_recentEdited.length > 2) {
      _recentEdited.removeAt(0);
    }
    if (_recentEdited.length < 2) return;

    final liters = double.tryParse(_litersController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    final total = double.tryParse(_totalController.text.trim());

    final hasLiters = _recentEdited.contains(_QuickFuelField.liters);
    final hasPrice = _recentEdited.contains(_QuickFuelField.pricePerLiter);
    final hasTotal = _recentEdited.contains(_QuickFuelField.totalCost);

    _isUpdating = true;
    try {
      if (hasLiters && hasPrice && liters != null && price != null) {
        _totalController.text = (liters * price).toStringAsFixed(2);
      } else if (hasLiters &&
          hasTotal &&
          liters != null &&
          liters > 0 &&
          total != null) {
        _priceController.text = (total / liters).toStringAsFixed(2);
      } else if (hasPrice &&
          hasTotal &&
          price != null &&
          price > 0 &&
          total != null) {
        _litersController.text = (total / price).toStringAsFixed(2);
      }
    } finally {
      _isUpdating = false;
    }
  }

  void _saveFillUp() {
    final liters = double.tryParse(_litersController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    final total = double.tryParse(_totalController.text.trim());

    if (liters == null ||
        liters <= 0 ||
        price == null ||
        price <= 0 ||
        total == null ||
        total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isArabic
                ? 'أدخل قيمتين صحيحتين على الأقل لحفظ التفويلة.'
                : 'Enter at least two valid values to save the fill-up.',
          ),
        ),
      );
      return;
    }

    context.read<FuelBloc>().add(
          FuelLogAdded(
            FuelLogsCompanion.insert(
              id: const Uuid().v4(),
              vehicleId: widget.vehicle.id,
              date: DateTime.now(),
              odometer: widget.vehicle.currentOdometer,
              liters: liters,
              pricePerLiter: price,
              totalCost: total,
              isFullTank: const Value(true),
              fuelGrade: Value(widget.vehicle.fuelType),
            ),
          ),
        );

    _litersController.clear();
    _priceController.clear();
    _totalController.clear();
    _recentEdited.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = widget.vehicle.currencyCode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isArabic ? 'تفويلة جديدة' : 'New fill-up',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isArabic
                  ? 'أدخل أي قيمتين، وسيتم حساب الثالثة.'
                  : 'Enter any two, the third is calculated.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                  ),
            ),
            const SizedBox(height: 16),

            _FieldLabel(text: widget.isArabic ? 'اللترات' : 'Liters'),
            const SizedBox(height: 6),
            TextField(
              controller: _litersController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: '40'),
              onChanged: (_) => _onChanged(_QuickFuelField.liters),
            ),
            const SizedBox(height: 12),

            _FieldLabel(
              text: widget.isArabic
                  ? 'سعر اللتر ($currency)'
                  : 'Price per liter ($currency)',
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: '15.00'),
              onChanged: (_) => _onChanged(_QuickFuelField.pricePerLiter),
            ),
            const SizedBox(height: 12),

            _FieldLabel(
              text: widget.isArabic
                  ? 'التكلفة الإجمالية ($currency)'
                  : 'Total cost ($currency)',
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _totalController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: '600.00'),
              onChanged: (_) => _onChanged(_QuickFuelField.totalCost),
            ),
            const SizedBox(height: 16),

            FilledButton(
              onPressed: _saveFillUp,
              child: Text(
                widget.isArabic ? 'حفظ التفويلة' : 'Save fill-up',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineNewExpenseCard extends StatefulWidget {
  const _InlineNewExpenseCard({
    required this.vehicle,
    required this.isArabic,
  });

  final Vehicle vehicle;
  final bool isArabic;

  @override
  State<_InlineNewExpenseCard> createState() => _InlineNewExpenseCardState();
}

class _InlineNewExpenseCardState extends State<_InlineNewExpenseCard> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = ExpenseCategories.all.first;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _saveExpense() {
    final amount = double.tryParse(_amountController.text.trim());
    final rawTitle = _titleController.text.trim();
    final title = rawTitle.isNotEmpty
        ? rawTitle
        : ExpenseCategories.label(_category, isArabic: widget.isArabic);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isArabic
                ? 'أدخل قيمة مصروف صحيحة.'
                : 'Enter a valid expense amount.',
          ),
        ),
      );
      return;
    }

    context.read<ExpensesBloc>().add(
          ExpenseAdded(
            ExpensesCompanion.insert(
              id: const Uuid().v4(),
              vehicleId: widget.vehicle.id,
              category: _category,
              title: title,
              date: DateTime.now(),
              amount: amount,
            ),
          ),
        );

    _titleController.clear();
    _amountController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = widget.vehicle.currencyCode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isArabic ? 'مصروف جديد' : 'New expense',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isArabic
                  ? 'سجّل الغسيل أو الركن أو الرسوم والتأمين.'
                  : 'Log washes, parking, tolls, licensing, or accessories.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                  ),
            ),
            const SizedBox(height: 16),

            _FieldLabel(text: widget.isArabic ? 'التصنيف' : 'Category'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: ExpenseCategories.all
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        ExpenseCategories.label(c, isArabic: widget.isArabic),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 12),

            _FieldLabel(text: widget.isArabic ? 'الوصف' : 'Title'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: widget.isArabic ? 'غسيل كامل' : 'Car wash',
              ),
            ),
            const SizedBox(height: 12),

            _FieldLabel(
              text: widget.isArabic
                  ? 'المبلغ ($currency)'
                  : 'Amount ($currency)',
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: '150.00'),
            ),
            const SizedBox(height: 16),

            FilledButton(
              onPressed: _saveExpense,
              child: Text(
                widget.isArabic ? 'حفظ المصروف' : 'Save expense',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
    );
  }
}

class _ExpensesLedgerList extends StatelessWidget {
  const _ExpensesLedgerList({
    required this.vehicle,
    required this.isArabic,
  });

  final Vehicle vehicle;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dateFormat = DateFormat('d MMM', isArabic ? 'ar' : 'en');
    final amountFormat = NumberFormat('#,##0.##');

    return BlocBuilder<ExpensesBloc, ExpensesState>(
      builder: (context, state) {
        if (state.status == ExpensesLoadStatus.loading &&
            state.expenses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.expenses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                isArabic ? 'لا توجد مصاريف مسجلة بعد' : 'No expenses logged yet',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final expense in state.expenses) ...[
              Dismissible(
                key: ValueKey(expense.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => context
                    .read<ExpensesBloc>()
                    .add(ExpenseDeleted(expense.id)),
                background: Container(
                  alignment: AlignmentDirectional.centerEnd,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: AppColors.overdueSurfaceDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.overdue,
                  ),
                ),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${dateFormat.format(expense.date)} · '
                                '${ExpenseCategories.label(expense.category, isArabic: isArabic)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 13.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${amountFormat.format(expense.amount)} ${vehicle.currencyCode}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}
