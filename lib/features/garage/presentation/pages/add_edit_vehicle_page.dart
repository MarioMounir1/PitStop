import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/features/garage/presentation/bloc/garage_bloc.dart';
import 'package:torq/features/garage/presentation/bloc/garage_event.dart';
import 'package:uuid/uuid.dart';

/// Form page for adding a new vehicle or editing an existing one.
class AddEditVehiclePage extends StatefulWidget {
  const AddEditVehiclePage({
    this.vehicle,
    this.isPro = false,
    this.onPaywallRequired,
    this.defaultDistanceUnit = 'km',
    this.defaultCurrencyCode = 'EGP',
    super.key,
  });

  final Vehicle? vehicle;
  final bool isPro;
  final VoidCallback? onPaywallRequired;
  final String defaultDistanceUnit;
  final String defaultCurrencyCode;

  @override
  State<AddEditVehiclePage> createState() => _AddEditVehiclePageState();
}

class _AddEditVehiclePageState extends State<AddEditVehiclePage> {
  static const List<String> _fuelTypes = [
    'petrol_80',
    'petrol_92',
    'petrol_95',
    'diesel',
    'hybrid',
    'electric',
  ];
  static const List<String> _currencies = ['EGP', 'SAR', 'AED', 'USD'];
  static const List<String> _distanceUnits = ['km', 'mi'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _plateController;
  late final TextEditingController _odometerController;

  late String _fuelType;
  late String _currencyCode;
  late String _distanceUnit;
  DateTime? _licenseExpiryDate;
  DateTime? _insuranceExpiryDate;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _makeController = TextEditingController(text: v?.make ?? '');
    _modelController = TextEditingController(text: v?.model ?? '');
    _yearController = TextEditingController(
      text: v?.year.toString() ?? DateTime.now().year.toString(),
    );
    _plateController = TextEditingController(text: v?.plateNumber ?? '');
    _odometerController = TextEditingController(
      text: v?.currentOdometer.toString() ?? '0',
    );
    _fuelType = v?.fuelType ?? 'petrol_92';
    _currencyCode = v?.currencyCode ?? widget.defaultCurrencyCode;
    _distanceUnit = v?.distanceUnit ?? widget.defaultDistanceUnit;
    _licenseExpiryDate = v?.licenseExpiryDate;
    _insuranceExpiryDate = v?.insuranceExpiryDate;
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? initialDate,
    required ValueChanged<DateTime?> onSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final bloc = context.read<GarageBloc>();
    final plate = _plateController.text.trim();
    final odometer = int.tryParse(_odometerController.text.trim()) ?? 0;
    final year = int.parse(_yearController.text.trim());

    if (_isEditing) {
      final companion = VehiclesCompanion(
        id: Value(widget.vehicle!.id),
        make: Value(_makeController.text.trim()),
        model: Value(_modelController.text.trim()),
        year: Value(year),
        plateNumber: Value(plate.isEmpty ? null : plate),
        currentOdometer: Value(odometer),
        distanceUnit: Value(_distanceUnit),
        currencyCode: Value(_currencyCode),
        fuelType: Value(_fuelType),
        licenseExpiryDate: Value(_licenseExpiryDate),
        insuranceExpiryDate: Value(_insuranceExpiryDate),
      );
      bloc.add(GarageVehicleUpdated(companion));
    } else {
      if (!widget.isPro &&
          bloc.state.vehicles.length >= GarageBloc.freeVehicleLimit) {
        widget.onPaywallRequired?.call();
        return;
      }
      final companion = VehiclesCompanion.insert(
        id: const Uuid().v4(),
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        year: year,
        plateNumber: Value(plate.isEmpty ? null : plate),
        currentOdometer: Value(odometer),
        distanceUnit: Value(_distanceUnit),
        currencyCode: Value(_currencyCode),
        fuelType: Value(_fuelType),
        licenseExpiryDate: Value(_licenseExpiryDate),
        insuranceExpiryDate: Value(_insuranceExpiryDate),
      );
      bloc.add(GarageVehicleAdded(vehicle: companion, isPro: widget.isPro));
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? (isArabic ? 'تعديل السيارة' : 'Edit Vehicle')
              : (isArabic ? 'إضافة سيارة' : 'Add Vehicle'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            TextFormField(
              controller: _makeController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: isArabic ? 'الماركة (مثال: Toyota)' : 'Make (e.g. Toyota)',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? (isArabic ? 'مطلوب' : 'Required')
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _modelController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: isArabic ? 'الموديل (مثال: Corolla)' : 'Model (e.g. Corolla)',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? (isArabic ? 'مطلوب' : 'Required')
                  : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'سنة الصنع' : 'Year',
                    ),
                    validator: (v) {
                      final year = int.tryParse(v?.trim() ?? '');
                      if (year == null || year < 1950 || year > 2035) {
                        return isArabic ? 'سنة غير صالحة' : 'Invalid year';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _plateController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'رقم اللوحة (اختياري)' : 'Plate (optional)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _odometerController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'قراءة العداد الحالية' : 'Current Odometer',
                      suffixText: _distanceUnit,
                    ),
                    validator: (v) {
                      final odo = int.tryParse(v?.trim() ?? '');
                      if (odo == null || odo < 0) {
                        return isArabic ? 'قيمة غير صالحة' : 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _distanceUnit,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'الوحدة' : 'Unit',
                    ),
                    items: _distanceUnits
                        .map(
                          (u) => DropdownMenuItem(value: u, child: Text(u)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _distanceUnit = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _fuelTypes.contains(_fuelType)
                        ? _fuelType
                        : _fuelTypes[1],
                    decoration: InputDecoration(
                      labelText: isArabic ? 'نوع الوقود' : 'Fuel Type',
                    ),
                    items: _fuelTypes
                        .map(
                          (f) => DropdownMenuItem(
                            value: f,
                            child: Text(f.replaceAll('_', ' ').toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _fuelType = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _currencies.contains(_currencyCode)
                        ? _currencyCode
                        : _currencies.first,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'العملة' : 'Currency',
                    ),
                    items: _currencies
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _currencyCode = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(
                      isArabic ? 'انتهاء الرخصة' : 'License Expiry Date',
                    ),
                    subtitle: Text(
                      _licenseExpiryDate != null
                          ? dateFormat.format(_licenseExpiryDate!)
                          : (isArabic ? 'غير محدد' : 'Not set'),
                    ),
                    trailing: _licenseExpiryDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () =>
                                setState(() => _licenseExpiryDate = null),
                          )
                        : const Icon(Icons.calendar_today_rounded, size: 18),
                    onTap: () => _pickDate(
                      initialDate: _licenseExpiryDate,
                      onSelected: (d) => setState(() => _licenseExpiryDate = d),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(
                      isArabic ? 'انتهاء التأمين' : 'Insurance Expiry Date',
                    ),
                    subtitle: Text(
                      _insuranceExpiryDate != null
                          ? dateFormat.format(_insuranceExpiryDate!)
                          : (isArabic ? 'غير محدد' : 'Not set'),
                    ),
                    trailing: _insuranceExpiryDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () =>
                                setState(() => _insuranceExpiryDate = null),
                          )
                        : const Icon(Icons.calendar_today_rounded, size: 18),
                    onTap: () => _pickDate(
                      initialDate: _insuranceExpiryDate,
                      onSelected: (d) =>
                          setState(() => _insuranceExpiryDate = d),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(isArabic ? 'حفظ السيارة' : 'Save Vehicle'),
            ),
          ],
        ),
      ),
    );
  }
}
