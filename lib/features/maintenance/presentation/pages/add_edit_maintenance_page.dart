import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:torq/core/constants/maintenance_presets.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/core/theme/app_colors.dart';
import 'package:torq/core/utils/reminder_calculator.dart';
import 'package:torq/core/widgets/pro_badge_widget.dart';
import 'package:torq/features/maintenance/presentation/bloc/maintenance_bloc.dart';
import 'package:torq/features/maintenance/presentation/bloc/maintenance_event.dart';
import 'package:torq/features/maintenance/presentation/pages/maintenance_page.dart';
import 'package:uuid/uuid.dart';

/// Form page for logging or editing a maintenance service record.
/// Selecting a preset automatically computes `nextDueOdometer` and `nextDueDate`.
class AddEditMaintenancePage extends StatefulWidget {
  const AddEditMaintenancePage({
    required this.vehicle,
    this.record,
    this.initialPreset,
    this.isPro = false,
    this.onPaywallRequired,
    super.key,
  });

  final Vehicle vehicle;
  final MaintenanceRecord? record;
  final MaintenancePreset? initialPreset;
  final bool isPro;
  final VoidCallback? onPaywallRequired;

  @override
  State<AddEditMaintenancePage> createState() => _AddEditMaintenancePageState();
}

class _AddEditMaintenancePageState extends State<AddEditMaintenancePage> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _odometerController;
  late final TextEditingController _costController;
  late final TextEditingController _serviceCenterController;
  late final TextEditingController _notesController;
  late final TextEditingController _nextDueOdometerController;

  late String _selectedCategory;
  late DateTime _serviceDate;
  DateTime? _nextDueDate;
  late bool _reminderEnabled;
  late bool _isCompleted;
  String? _receiptImagePath;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    final preset = widget.initialPreset;

    _selectedCategory = r?.category ?? preset?.category ?? 'custom';
    _serviceDate = r?.serviceDate ?? DateTime.now();
    _reminderEnabled = r?.reminderEnabled ?? true;
    _isCompleted = r?.isCompleted ?? true;
    _receiptImagePath = r?.receiptImagePath;

    _titleController = TextEditingController(text: r?.title ?? '');
    _odometerController = TextEditingController(
      text: (r?.odometerAtService ?? widget.vehicle.currentOdometer).toString(),
    );
    _costController = TextEditingController(
      text: r != null ? r.cost.toStringAsFixed(0) : '',
    );
    _serviceCenterController = TextEditingController(
      text: r?.serviceCenter ?? '',
    );
    _notesController = TextEditingController(text: r?.notes ?? '');
    _nextDueOdometerController = TextEditingController(
      text: r?.nextDueOdometer?.toString() ?? '',
    );
    _nextDueDate = r?.nextDueDate;

    if (r == null && preset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyPreset(preset);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _odometerController.dispose();
    _costController.dispose();
    _serviceCenterController.dispose();
    _notesController.dispose();
    _nextDueOdometerController.dispose();
    super.dispose();
  }

  void _applyPreset(MaintenancePreset preset) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final currentOdo = int.tryParse(_odometerController.text.trim()) ??
        widget.vehicle.currentOdometer;

    setState(() {
      _selectedCategory = preset.category;
      _titleController.text = MaintenancePage.presetDisplayName(
        preset.category,
        isArabic: isArabic,
      );
      if (preset.hasDistanceInterval) {
        _nextDueOdometerController.text =
            (currentOdo + preset.defaultIntervalKm).toString();
      } else {
        _nextDueOdometerController.clear();
      }
      if (preset.hasTimeInterval) {
        _nextDueDate = ReminderCalculator.addMonths(
          _serviceDate,
          preset.defaultIntervalMonths,
        );
      } else {
        _nextDueDate = null;
      }
    });
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  Future<void> _pickReceiptImage(ImageSource source) async {
    if (!widget.isPro) {
      widget.onPaywallRequired?.call();
      return;
    }

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked == null) return;

      final docsDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory(
        '${docsDir.path}${Platform.pathSeparator}receipts',
      );
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }

      final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
      final destPath =
          '${receiptsDir.path}${Platform.pathSeparator}${const Uuid().v4()}.$ext';
      await File(picked.path).copy(destPath);

      if (mounted) {
        setState(() => _receiptImagePath = destPath);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not attach receipt: $e')),
      );
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final odometer = int.parse(_odometerController.text.trim());
    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    final nextDueOdo = int.tryParse(_nextDueOdometerController.text.trim());
    final center = _serviceCenterController.text.trim();
    final notes = _notesController.text.trim();

    final bloc = context.read<MaintenanceBloc>();

    if (_isEditing) {
      bloc.add(
        MaintenanceRecordUpdated(
          MaintenanceRecordsCompanion(
            id: Value(widget.record!.id),
            vehicleId: Value(widget.vehicle.id),
            category: Value(_selectedCategory),
            title: Value(_titleController.text.trim()),
            serviceDate: Value(_serviceDate),
            odometerAtService: Value(odometer),
            cost: Value(cost),
            serviceCenter: Value(center.isEmpty ? null : center),
            notes: Value(notes.isEmpty ? null : notes),
            receiptImagePath: Value(_receiptImagePath),
            nextDueOdometer: Value(nextDueOdo),
            nextDueDate: Value(_nextDueDate),
            reminderEnabled: Value(_reminderEnabled),
            isCompleted: Value(_isCompleted),
          ),
        ),
      );
    } else {
      bloc.add(
        MaintenanceRecordAdded(
          MaintenanceRecordsCompanion.insert(
            id: const Uuid().v4(),
            vehicleId: widget.vehicle.id,
            category: _selectedCategory,
            title: _titleController.text.trim(),
            serviceDate: _serviceDate,
            odometerAtService: odometer,
            cost: cost,
            serviceCenter: Value(center.isEmpty ? null : center),
            notes: Value(notes.isEmpty ? null : notes),
            receiptImagePath: Value(_receiptImagePath),
            nextDueOdometer: Value(nextDueOdo),
            nextDueDate: Value(_nextDueDate),
            reminderEnabled: Value(_reminderEnabled),
            isCompleted: Value(_isCompleted),
          ),
        ),
      );
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final colors = context.appColors;
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? (isArabic ? 'تعديل الصيانة' : 'Edit Maintenance')
              : (isArabic ? 'تسجيل صيانة' : 'Log Maintenance'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            Text(
              isArabic ? 'اختيار سريع من الصيانات الشائعة' : 'Quick Presets',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MaintenancePresets.defaults.map((preset) {
                final selected = _selectedCategory == preset.category;
                return ChoiceChip(
                  label: Text(
                    MaintenancePage.presetDisplayName(
                      preset.category,
                      isArabic: isArabic,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => _applyPreset(preset),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: isArabic ? 'اسم الخدمة' : 'Service Title',
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
                    controller: _odometerController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'العداد وقت الصيانة' : 'Odometer',
                      suffixText: widget.vehicle.distanceUnit,
                    ),
                    validator: (v) {
                      final parsed = int.tryParse(v?.trim() ?? '');
                      if (parsed == null || parsed < 0) {
                        return isArabic ? 'غير صالح' : 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: isArabic ? 'التكلفة' : 'Cost',
                      suffixText: widget.vehicle.currencyCode,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: Text(isArabic ? 'تاريخ الصيانة' : 'Service Date'),
                subtitle: Text(dateFormat.format(_serviceDate)),
                onTap: () => _pickDate(
                  initialDate: _serviceDate,
                  onSelected: (picked) {
                    setState(() {
                      _serviceDate = picked;
                      final preset =
                          MaintenancePresets.byCategory(_selectedCategory);
                      if (preset != null && preset.hasTimeInterval) {
                        _nextDueDate = ReminderCalculator.addMonths(
                          picked,
                          preset.defaultIntervalMonths,
                        );
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _serviceCenterController,
              decoration: InputDecoration(
                labelText: isArabic
                    ? 'مركز الصيانة (اختياري)'
                    : 'Service Center (optional)',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isArabic ? 'ملاحظات (اختياري)' : 'Notes (optional)',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isArabic ? 'التنبيه القادم' : 'Next Reminder',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nextDueOdometerController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isArabic
                    ? 'العداد المستحق القادم'
                    : 'Next Due Odometer',
                suffixText: widget.vehicle.distanceUnit,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.event_repeat_rounded),
                    title: Text(
                      isArabic ? 'التاريخ المستحق القادم' : 'Next Due Date',
                    ),
                    subtitle: Text(
                      _nextDueDate != null
                          ? dateFormat.format(_nextDueDate!)
                          : (isArabic ? 'غير محدد' : 'Not set'),
                    ),
                    trailing: _nextDueDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () =>
                                setState(() => _nextDueDate = null),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => _pickDate(
                      initialDate: _nextDueDate ??
                          ReminderCalculator.addMonths(_serviceDate, 6),
                      onSelected: (picked) =>
                          setState(() => _nextDueDate = picked),
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(
                      isArabic ? 'تفعيل التنبيه' : 'Enable Reminder',
                    ),
                    value: _reminderEnabled,
                    onChanged: (v) => setState(() => _reminderEnabled = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isArabic ? 'صورة الفاتورة' : 'Receipt Photo',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (!widget.isPro) const ProBadgeWidget(compact: true),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_receiptImagePath != null &&
                        File(_receiptImagePath!).existsSync()) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_receiptImagePath!),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _receiptImagePath = null),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.overdue,
                        ),
                        label: Text(
                          isArabic ? 'إزالة الصورة' : 'Remove Photo',
                          style: const TextStyle(color: AppColors.overdue),
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _pickReceiptImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: Text(isArabic ? 'الكاميرا' : 'Camera'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _pickReceiptImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(isArabic ? 'المعرض' : 'Gallery'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(isArabic ? 'حفظ الصيانة' : 'Save Maintenance'),
            ),
          ],
        ),
      ),
    );
  }
}
