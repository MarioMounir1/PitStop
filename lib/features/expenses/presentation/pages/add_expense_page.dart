import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/core/theme/app_colors.dart';
import 'package:torq/features/expenses/domain/constants/expense_categories.dart';
import 'package:torq/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:torq/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:uuid/uuid.dart';

/// Form page for adding a general vehicle expense.
class AddExpensePage extends StatefulWidget {
  const AddExpensePage({
    required this.vehicle,
    super.key,
  });

  final Vehicle vehicle;

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = ExpenseCategories.wash;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 10),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final rawTitle = _titleController.text.trim();
    final title = rawTitle.isNotEmpty
        ? rawTitle
        : ExpenseCategories.label(_selectedCategory, isArabic: isArabic);
    final amount = double.parse(_amountController.text.trim());
    final notes = _notesController.text.trim();

    context.read<ExpensesBloc>().add(
          ExpenseAdded(
            ExpensesCompanion.insert(
              id: const Uuid().v4(),
              vehicleId: widget.vehicle.id,
              category: _selectedCategory,
              title: title,
              date: _date,
              amount: amount,
              notes: Value(notes.isEmpty ? null : notes),
            ),
          ),
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'إضافة مصروف' : 'Add Expense'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              isArabic ? 'الفئة' : 'Category',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.appColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpenseCategories.all.map((category) {
                final selected = _selectedCategory == category;
                return ChoiceChip(
                  avatar: Icon(ExpenseCategories.icon(category), size: 16),
                  label: Text(
                    ExpenseCategories.label(category, isArabic: isArabic),
                  ),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: isArabic ? 'المبلغ' : 'Amount',
                suffixText: widget.vehicle.currencyCode,
              ),
              validator: (v) {
                final val = double.tryParse(v?.trim() ?? '');
                if (val == null || val <= 0) {
                  return isArabic ? 'أدخل مبلغاً صالحاً' : 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: isArabic ? 'العنوان (اختياري)' : 'Title (optional)',
                hintText: ExpenseCategories.label(
                  _selectedCategory,
                  isArabic: isArabic,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: Text(isArabic ? 'التاريخ' : 'Date'),
                subtitle: Text(dateFormat.format(_date)),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isArabic ? 'ملاحظات (اختياري)' : 'Notes (optional)',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(isArabic ? 'حفظ المصروف' : 'Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
