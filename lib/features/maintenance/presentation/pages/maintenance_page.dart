import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:torq/core/constants/maintenance_presets.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/core/theme/app_colors.dart';
import 'package:torq/core/utils/currency_formatter.dart';
import 'package:torq/core/utils/reminder_calculator.dart';
import 'package:torq/core/widgets/empty_state_widget.dart';
import 'package:torq/core/widgets/status_chip.dart';
import 'package:torq/features/maintenance/presentation/bloc/maintenance_bloc.dart';
import 'package:torq/features/maintenance/presentation/bloc/maintenance_event.dart';
import 'package:torq/features/maintenance/presentation/bloc/maintenance_state.dart';
import 'package:torq/features/maintenance/presentation/pages/add_edit_maintenance_page.dart';

/// Displays vehicle maintenance records with segmented filters, status chips,
/// and quick-add preset chips.
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

  Future<void> _confirmDelete(
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.overdue),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
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
        final filtered = state.filteredRecords;

        return Scaffold(
          appBar: AppBar(
            title: Text(isArabic ? 'الصيانة' : 'Maintenance'),
            actions: [
              if (state.overdueCount > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: StatusChip(
                    type: StatusChipType.overdue,
                    label: '${state.overdueCount}',
                    compact: true,
                  ),
                ),
              if (state.dueSoonCount > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: StatusChip(
                    type: StatusChipType.dueSoon,
                    label: '${state.dueSoonCount}',
                    compact: true,
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAddEdit(
              context,
              activeVehicle: activeVehicle,
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(isArabic ? 'تسجيل صيانة' : 'Log Service'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: SegmentedButton<MaintenanceFilter>(
                  segments: [
                    ButtonSegment(
                      value: MaintenanceFilter.all,
                      label: Text(isArabic ? 'الكل' : 'All'),
                    ),
                    ButtonSegment(
                      value: MaintenanceFilter.upcoming,
                      label: Text(isArabic ? 'المستحقة' : 'Upcoming'),
                    ),
                    ButtonSegment(
                      value: MaintenanceFilter.history,
                      label: Text(isArabic ? 'السجل' : 'History'),
                    ),
                  ],
                  selected: {state.filter},
                  onSelectionChanged: (selection) {
                    context
                        .read<MaintenanceBloc>()
                        .add(MaintenanceFilterChanged(selection.first));
                  },
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: MaintenancePresets.defaults.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final preset = MaintenancePresets.defaults[index];
                    return ActionChip(
                      avatar: const Icon(Icons.bolt_rounded, size: 16),
                      label: Text(
                        presetDisplayName(
                          preset.category,
                          isArabic: isArabic,
                        ),
                      ),
                      onPressed: () => _openAddEdit(
                        context,
                        activeVehicle: activeVehicle,
                        initialPreset: preset,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: state.status == MaintenanceLoadStatus.loading &&
                        state.records.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.build_circle_outlined,
                            title: isArabic
                                ? 'لا توجد سجلات صيانة'
                                : 'No maintenance records',
                            subtitle: isArabic
                                ? 'سجّل أول صيانة للحصول على تنبيهات ذكية حسب العداد والتاريخ.'
                                : 'Log your first service to get smart odometer and date reminders.',
                            actionLabel:
                                isArabic ? 'تسجيل صيانة' : 'Log Service',
                            onAction: () => _openAddEdit(
                              context,
                              activeVehicle: activeVehicle,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final record = filtered[index];
                              final status = state.statusByRecordId[record.id] ??
                                  MaintenanceStatus.ok;
                              return _MaintenanceRecordCard(
                                record: record,
                                vehicle: activeVehicle,
                                status: status,
                                isArabic: isArabic,
                                onEdit: () => _openAddEdit(
                                  context,
                                  activeVehicle: activeVehicle,
                                  record: record,
                                ),
                                onDelete: () =>
                                    _confirmDelete(context, record),
                              );
                            },
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
    required this.onDelete,
  });

  final MaintenanceRecord record;
  final Vehicle vehicle;
  final MaintenanceStatus status;
  final bool isArabic;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _statusLabel() {
    return switch (status) {
      MaintenanceStatus.ok => isArabic ? 'سليم' : 'OK',
      MaintenanceStatus.dueSoon => isArabic ? 'قريب الاستحقاق' : 'Due Soon',
      MaintenanceStatus.overdue => isArabic ? 'متأخر' : 'Overdue',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dateFormat = DateFormat('yyyy-MM-dd');
    final numberFormat = NumberFormat('#,##0');

    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${dateFormat.format(record.serviceDate)} • '
                          '${numberFormat.format(record.odometerAtService)} ${vehicle.distanceUnit}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    type: status.toChipType(),
                    label: _statusLabel(),
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    CurrencyFormatter.format(
                      record.cost,
                      currencyCode: vehicle.currencyCode,
                      locale: isArabic ? 'ar' : 'en',
                      decimalDigits: 0,
                    ),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (record.serviceCenter != null &&
                      record.serviceCenter!.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        record.serviceCenter!,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (record.receiptImagePath != null &&
                      record.receiptImagePath!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: colors.textMuted,
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                  ),
                ],
              ),
              if (record.nextDueOdometer != null ||
                  record.nextDueDate != null) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 15,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          if (record.nextDueOdometer != null)
                            '${isArabic ? 'التالي عند' : 'Next at'} ${numberFormat.format(record.nextDueOdometer)} ${vehicle.distanceUnit}',
                          if (record.nextDueDate != null)
                            dateFormat.format(record.nextDueDate!),
                        ].join('  •  '),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
