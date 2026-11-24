import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/features/fuel/presentation/bloc/fuel_bloc.dart';
import 'package:torq/features/fuel/presentation/bloc/fuel_event.dart';
import 'package:uuid/uuid.dart';

enum _FuelField { liters, pricePerLiter, totalCost }

/// Smart fuel fill-up form: entering any 2 of (`liters`, `pricePerLiter`,
/// `totalCost`) automatically calculates the 3rd.
class AddFuelLogPage extends StatefulWidget {
  const AddFuelLogPage({
    required this.vehicle,
    super.key,
  });

  final Vehicle vehicle;

  @override
  State<AddFuelLogPage> createState() => _AddFuelLogPageState();
}

class _AddFuelLogPageState extends State<AddFuelLogPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _odometerController;
  final _litersController = TextEditingController();
  final _priceController = TextEditingController();
  final _totalController = TextEditingController();
  final _stationController = TextEditingController();

  DateTime _date = DateTime.now();
  bool _isFullTank = true;
  late String _fuelGrade;

  bool _isUpdatingField = false;
  final List<_FuelField> _recentEditedFields = [];

  @override
  void initState() {
    super.initState();
    _odometerController = TextEditingController(
      text: widget.vehicle.currentOdometer.toString(),
    );
    _fuelGrade = widget.vehicle.fuelType;
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _litersController.dispose();
    _priceController.dispose();
    _totalController.dispose();
    _stationController.dispose();
    super.dispose();
  }

  void _onNumericFieldChanged(_FuelField field) {
    if (_isUpdatingField) return;

    _recentEditedFields.remove(field);
    _recentEditedFields.add(field);
    if (_recentEditedFields.length > 2) {
      _recentEditedFields.removeAt(0);
    }
    if (_recentEditedFields.length < 2) return;

    final liters = double.tryParse(_litersController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    final total = double.tryParse(_totalController.text.trim());

    final hasLiters = _recentEditedFields.contains(_FuelField.liters);
    final hasPrice = _recentEditedFields.contains(_FuelField.pricePerLiter);
    final hasTotal = _recentEditedFields.contains(_FuelField.totalCost);

    _isUpdatingField = true;
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
      _isUpdatingField = false;
    }
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

    final odometer = int.parse(_odometerController.text.trim());
    final liters = double.parse(_litersController.text.trim());
    final price = double.parse(_priceController.text.trim());
    final total = double.parse(_totalController.text.trim());
    final station = _stationController.text.trim();

    context.read<FuelBloc>().add(
          FuelLogAdded(
            FuelLogsCompanion.insert(
              id: const Uuid().v4(),
              vehicleId: widget.vehicle.id,
              date: _date,
              odometer: odometer,
              liters: liters,
              pricePerLiter: price,
              totalCost: total,
              isFullTank: Value(_isFullTank),
              fuelGrade: Value(_fuelGrade),
              stationName: Value(station.isEmpty ? null : station),
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
        title: Text(isArabic ? 'تسجيل وقود' : 'Add Fuel Log'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
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
              controller: _odometerController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isArabic ? 'قراءة العداد' : 'Odometer',
                suffixText: widget.vehicle.distanceUnit,
              ),
              validator: (v) {
                final odo = int.tryParse(v?.trim() ?? '');
                if (odo == null || odo < 0) {
                  return isArabic ? 'قيمة غير صالحة' : 'Invalid odometer';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _litersController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: isArabic ? 'اللترات' : 'Liters',
                      suffixText: isArabic ? 'لتر' : 'L',
                    ),
                    onChanged: (_) =>
                        _onNumericFieldChanged(_FuelField.liters),
                    validator: (v) {
                      final val = double.tryParse(v?.trim() ?? '');
                      if (val == null || val <= 0) {
                        return isArabic ? 'مطلوب' : 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: isArabic ? 'سعر اللتر' : 'Price / Liter',
                      suffixText: widget.vehicle.currencyCode,
                    ),
                    onChanged: (_) =>
                        _onNumericFieldChanged(_FuelField.pricePerLiter),
                    validator: (v) {
                      final val = double.tryParse(v?.trim() ?? '');
                      if (val == null || val <= 0) {
                        return isArabic ? 'مطلوب' : 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _totalController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: isArabic ? 'التكلفة الإجمالية' : 'Total Cost',
                suffixText: widget.vehicle.currencyCode,
                helperText: isArabic
                    ? 'أدخل أي قيمتين لحساب الثالثة تلقائياً'
                    : 'Enter any 2 of Liters, Price/L, or Total to auto-calculate the 3rd',
              ),
              onChanged: (_) => _onNumericFieldChanged(_FuelField.totalCost),
              validator: (v) {
                final val = double.tryParse(v?.trim() ?? '');
                if (val == null || val <= 0) {
                  return isArabic ? 'مطلوب' : 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Card(
              child: SwitchListTile(
                title: Text(isArabic ? 'تفويل كامل للخزان' : 'Full Tank'),
                subtitle: Text(
                  isArabic
                      ? 'يُستخدم لحساب معدل الاستهلاك (كم/لتر) بدقة'
                      : 'Required to compute accurate km/L fuel economy',
                ),
                value: _isFullTank,
                onChanged: (v) => setState(() => _isFullTank = v),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _stationController,
              decoration: InputDecoration(
                labelText: isArabic
                    ? 'محطة الوقود (اختياري)'
                    : 'Fuel Station (optional)',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(isArabic ? 'حفظ سجل الوقود' : 'Save Fuel Log'),
            ),
          ],
        ),
      ),
    );
  }
}
