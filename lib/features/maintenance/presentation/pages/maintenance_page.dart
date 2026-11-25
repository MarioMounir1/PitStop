import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pitstop/core/constants/maintenance_presets.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/theme/app_colors.dart';
import 'package:pitstop/core/utils/reminder_calculator.dart';
import 'package:pitstop/core/widgets/empty_state_widget.dart';
import 'package:pitstop/core/widgets/status_chip.dart';
import 'package:pitstop/features/maintenance/presentation/bloc/maintenance_bloc.dart';
import 'package:pitstop/features/maintenance/presentation/bloc/maintenance_event.dart';
import 'package:pitstop/features/maintenance/presentation/bloc/maintenance_state.dart';
import 'package:pitstop/features/maintenance/presentation/pages/add_edit_maintenance_page.dart';

/// Displays vehicle maintenance schedules with clean status pills (`Overdue`,
/// `Due Soon`, `OK`) and a full-width bottom `Log a service` CTA.
class MaintenancePage extends StatelessWidget {
  const MaintenancePage({
    required this.vehicle,
    this.isPro = false,
    this.onPaywallRequired,
    super.key,
  });

  final Vehicle? vehicle;
  final bool isPro;
  final VoidCallback? onPaywallRequired;

  static String presetDisplayName(String category, {required bool isArabic}) {
    return switch (category) {
      MaintenancePresets.engineOil => isArabic ? 'زيت المحرك' : 'Engine Oil',
      MaintenancePresets.oilFilter => isArabic ? 'فلتر الزيت' : 'Oil Filter',
      MaintenancePresets.airFilter => isArabic ? 'فلتر الهواء' : 'Air Filter',
      MaintenancePresets.acFilter => isArabic ? 'فلتر التكييف' : 'AC Filter',
      MaintenancePresets.brakePads => isArabic ? 'تيل الفرامل' : 'Brake Pads',
      MaintenancePresets.tires => isArabic ? 'الإطارات' : 'Tires',
      MaintenancePresets.battery => isArabic ? 'البطارية' : 'Battery',
      MaintenancePresets.timingBelt => isArabic ? 'سير الكاتينة' : 'Timing Belt',
      MaintenancePresets.sparkPlugs => isArabic ? 'البوجيهات' : 'Spark Plugs',
      MaintenancePresets.transmissionOil =>
        isArabic ? 'زيت الفتيس' : 'Transmission Oil',
      _ => category.replaceAll('_', ' '),
    };
  }

  void _openAddEdit(
    BuildContext context, {
    required Vehicle activeVehicle,
    MaintenanceRecord? record,
    MaintenancePreset? initialPreset,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<MaintenanceBloc>(),
          child: AddEditMaintenancePage(
            vehicle: activeVehicle,
            record: record,
            initialPreset: initialPreset,
            isPro: isPro,
            onPaywallRequired: onPaywallRequired,
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    MaintenanceRecord record,
  ) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'حذف سجل الصيانة؟' : 'Delete Record?'),
        content: Text(
          isArabic
              ? 'هل تريد حذف "${record.title}" نهائياً؟'
              : 'Permanently delete "${record.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.overdue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context
          .read<MaintenanceBloc>()
          .add(MaintenanceRecordDeleted(record.id));
      return true;
    }
    return false;
  }

  int _statusWeight(MaintenanceStatus s) {
    return switch (s) {
      MaintenanceStatus.overdue => 0,
      MaintenanceStatus.dueSoon => 1,
      MaintenanceStatus.ok => 2,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final colors = context.appColors;
    final activeVehicle = vehicle;

    if (activeVehicle == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'الصيانة' : 'Maintenance'),
        ),
        body: EmptyStateWidget(
          icon: Icons.build_outlined,
          title: isArabic ? 'اختر سيارة أولاً' : 'No active vehicle',
          subtitle: isArabic
              ? 'أضف سيارة في الجراج لبدء تسجيل الصيانات والتنبيهات.'
              : 'Add a vehicle in your garage to start logging maintenance.',
        ),
      );
    }

    return BlocBuilder<MaintenanceBloc, MaintenanceState>(
      builder: (context, state) {
        final sortedRecords = [...state.filteredRecords]..sort((a, b) {
            final sa =
                state.statusByRecordId[a.id] ?? MaintenanceStatus.ok;
            final sb =
                state.statusByRecordId[b.id] ?? MaintenanceStatus.ok;
            final cmp = _statusWeight(sa).compareTo(_statusWeight(sb));
            if (cmp != 0) return cmp;
            return b.serviceDate.compareTo(a.serviceDate);
          });

        return Scaffold(
          appBar: AppBar(
            title: Text(isArabic ? 'الصيانة' : 'Maintenance'),
            actions: [
              // Quick preset menu
              PopupMenuButton<MaintenancePreset>(
                tooltip: isArabic ? 'إضافة سريعة' : 'Quick preset',
                icon: Icon(
                  Icons.bolt_rounded,
                  color: colors.textSecondary,
                ),
                onSelected: (preset) => _openAddEdit(
                  context,
                  activeVehicle: activeVehicle,
                  initialPreset: preset,
                ),
                itemBuilder: (_) => [
                  for (final preset in MaintenancePresets.defaults)
                    PopupMenuItem(
                      value: preset,
                      child: Text(
                        presetDisplayName(preset.category, isArabic: isArabic),
                      ),
                    ),
                ],
              ),
              // Subtle filter menu (All / Upcoming / History)
              PopupMenuButton<MaintenanceFilter>(
                tooltip: isArabic ? 'تصفية' : 'Filter',
                icon: Icon(
                  state.filter == MaintenanceFilter.all
                      ? Icons.tune_rounded
                      : Icons.filter_alt_rounded,
                  color: state.filter == MaintenanceFilter.all
                      ? colors.textSecondary
                      : AppColors.primary,
                ),
                onSelected: (f) => context
                    .read<MaintenanceBloc>()
                    .add(MaintenanceFilterChanged(f)),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: MaintenanceFilter.all,
                    child: Text(isArabic ? 'الكل' : 'All'),
                  ),
                  PopupMenuItem(
                    value: MaintenanceFilter.upcoming,
                    child: Text(isArabic ? 'المستحقة قريباً' : 'Upcoming'),
                  ),
                  PopupMenuItem(
                    value: MaintenanceFilter.history,
                    child: Text(isArabic ? 'السجل' : 'History'),
                  ),
                ],
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: state.status == MaintenanceLoadStatus.loading &&
                        state.records.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : sortedRecords.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.build_circle_outlined,
                            title: isArabic
                                ? 'لا توجد سجلات صيانة'
                                : 'No maintenance records',
                            subtitle: isArabic
                                ? 'سجّل أول صيانة للحصول على تنبيهات ذكية حسب العداد والتاريخ.'
                                : 'Log your first service to get smart odometer and date reminders.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            itemCount: sortedRecords.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final record = sortedRecords[index];
                              final status =
                                  state.statusByRecordId[record.id] ??
                                      MaintenanceStatus.ok;
                              return Dismissible(
                                key: ValueKey(record.id),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) =>
                                    _confirmDelete(context, record),
                                background: Container(
                                  alignment: AlignmentDirectional.centerEnd,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.overdueSurfaceDark,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.overdue,
                                  ),
                                ),
                                child: _MaintenanceRecordCard(
                                  record: record,
                                  vehicle: activeVehicle,
                                  status: status,
                                  isArabic: isArabic,
                                  onEdit: () => _openAddEdit(
                                    context,
                                    activeVehicle: activeVehicle,
                                    record: record,
                                  ),
                                  onLongPressDelete: () =>
                                      _confirmDelete(context, record),
                                ),
                              );
                            },
                          ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton(
                    onPressed: () => _openAddEdit(
                      context,
                      activeVehicle: activeVehicle,
                    ),
                    child: Text(
                      isArabic ? 'تسجيل صيانة' : 'Log a service',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MaintenanceRecordCard extends StatelessWidget {
  const _MaintenanceRecordCard({
    required this.record,
    required this.vehicle,
    required this.status,
    required this.isArabic,
    required this.onEdit,
    required this.onLongPressDelete,
  });

  final MaintenanceRecord record;
  final Vehicle vehicle;
  final MaintenanceStatus status;
  final bool isArabic;
  final VoidCallback onEdit;
  final VoidCallback onLongPressDelete;

  String _statusLabel() {
    return switch (status) {
      MaintenanceStatus.ok => isArabic ? 'سليم' : 'OK',
      MaintenanceStatus.dueSoon => isArabic ? 'قريب الاستحقاق' : 'Due Soon',
      MaintenanceStatus.overdue => isArabic ? 'متأخر' : 'Overdue',
    };
  }

  String _subtitleText() {
    final numberFormat = NumberFormat('#,##0');
    final dateFormat = DateFormat('d MMM yyyy', isArabic ? 'ar' : 'en');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Date-driven due message when due soon / overdue by date, or when only date is set
    if (record.nextDueDate != null) {
      final dueDay = DateTime(
        record.nextDueDate!.year,
        record.nextDueDate!.month,
        record.nextDueDate!.day,
      );
      final days = dueDay.difference(today).inDays;
      final dateStr = dateFormat.format(record.nextDueDate!);

      if (record.nextDueOdometer == null) {
        if (days < 0) {
          return isArabic ? 'كان مستحقاً في $dateStr' : 'Was due $dateStr';
        }
        if (days <= 14) {
          return isArabic
              ? 'خلال $days أيام · $dateStr'
              : 'Next due in $days days · $dateStr';
        }
        return isArabic ? 'الموعد القادم $dateStr' : 'Next due $dateStr';
      }

      // Both odometer & date exist: highlight date if date triggered dueSoon/overdue
      if (days <= 14 &&
          (record.nextDueOdometer! - vehicle.currentOdometer) > 500) {
        if (days < 0) {
          return isArabic ? 'كان مستحقاً في $dateStr' : 'Was due $dateStr';
        }
        return isArabic
            ? 'خلال $days أيام · $dateStr'
            : 'Next due in $days days · $dateStr';
      }
    }

    if (record.nextDueOdometer != null) {
      final dueKm = numberFormat.format(record.nextDueOdometer);
      if (vehicle.currentOdometer >= record.nextDueOdometer!) {
        return isArabic
            ? 'كان مستحقاً عند $dueKm ${vehicle.distanceUnit}'
            : 'Was due at $dueKm ${vehicle.distanceUnit}';
      }
      return isArabic
          ? 'الموعد القادم عند $dueKm ${vehicle.distanceUnit}'
          : 'Next due at $dueKm ${vehicle.distanceUnit}';
    }

    return '${dateFormat.format(record.serviceDate)} · '
        '${numberFormat.format(record.odometerAtService)} ${vehicle.distanceUnit}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Card(
      child: InkWell(
        onTap: onEdit,
        onLongPress: onLongPressDelete,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(
                    type: status.toChipType(),
                    label: _statusLabel(),
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _subtitleText(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                    ),
                  ),
                  if (record.receiptImagePath != null &&
                      record.receiptImagePath!.isNotEmpty)
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: colors.textMuted,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
