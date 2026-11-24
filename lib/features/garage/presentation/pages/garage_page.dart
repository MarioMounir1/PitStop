import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/core/theme/app_colors.dart';
import 'package:torq/core/utils/reminder_calculator.dart';
import 'package:torq/core/widgets/empty_state_widget.dart';
import 'package:torq/core/widgets/pro_badge_widget.dart';
import 'package:torq/core/widgets/status_chip.dart';
import 'package:torq/features/garage/presentation/bloc/garage_bloc.dart';
import 'package:torq/features/garage/presentation/bloc/garage_event.dart';
import 'package:torq/features/garage/presentation/bloc/garage_state.dart';
import 'package:torq/features/garage/presentation/pages/add_edit_vehicle_page.dart';

/// Displays all vehicles in the user's garage with quick odometer updates,
/// active switching, and license/insurance expiry badges.
class GaragePage extends StatelessWidget {
  const GaragePage({
    this.isPro = false,
    this.onPaywallRequired,
    super.key,
  });

  final bool isPro;
  final VoidCallback? onPaywallRequired;

  void _openAddVehicle(BuildContext context, int currentCount) {
    if (!isPro && currentCount >= GarageBloc.freeVehicleLimit) {
      onPaywallRequired?.call();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<GarageBloc>(),
          child: AddEditVehiclePage(
            isPro: isPro,
            onPaywallRequired: onPaywallRequired,
          ),
        ),
      ),
    );
  }

  void _openEditVehicle(BuildContext context, Vehicle vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<GarageBloc>(),
          child: AddEditVehiclePage(
            vehicle: vehicle,
            isPro: isPro,
            onPaywallRequired: onPaywallRequired,
          ),
        ),
      ),
    );
  }

  Future<void> _showQuickOdometerDialog(
    BuildContext context,
    Vehicle vehicle,
  ) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final controller = TextEditingController(
      text: vehicle.currentOdometer.toString(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'تحديث العداد' : 'Update Odometer'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: isArabic ? 'القراءة الحالية' : 'Current Reading',
            suffixText: vehicle.distanceUnit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );

    final parsed = int.tryParse(controller.text.trim());
    controller.dispose();

    if (confirmed == true && parsed != null && context.mounted) {
      context.read<GarageBloc>().add(
            GarageOdometerUpdated(
              vehicleId: vehicle.id,
              newOdometer: parsed,
            ),
          );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Vehicle vehicle) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'حذف السيارة؟' : 'Delete Vehicle?'),
        content: Text(
          isArabic
              ? 'سيتم حذف "${vehicle.make} ${vehicle.model}" وجميع سجلات الصيانة والوقود والمصاريف المرتبطة بها.'
              : 'This will permanently delete "${vehicle.make} ${vehicle.model}" and all linked maintenance, fuel, and expense records.',
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
      context.read<GarageBloc>().add(GarageVehicleDeleted(vehicle.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return BlocConsumer<GarageBloc, GarageState>(
      listenWhen: (prev, curr) =>
          curr.paywallRequired && !prev.paywallRequired,
      listener: (context, state) {
        context.read<GarageBloc>().add(const GaragePaywallAcknowledged());
        onPaywallRequired?.call();
      },
      builder: (context, state) {
        final isFreeLocked =
            !isPro && state.vehicles.length >= GarageBloc.freeVehicleLimit;

        return Scaffold(
          appBar: AppBar(
            title: Text(isArabic ? 'الجراج' : 'My Garage'),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAddVehicle(context, state.vehicles.length),
            icon: const Icon(Icons.directions_car_rounded),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isArabic ? 'إضافة سيارة' : 'Add Vehicle'),
                if (isFreeLocked) ...[
                  const SizedBox(width: 8),
                  const ProBadgeWidget(compact: true),
                ],
              ],
            ),
          ),
          body: state.status == GarageStatus.loading && state.vehicles.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.vehicles.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.directions_car_outlined,
                      title: isArabic ? 'لا توجد سيارات بعد' : 'No vehicles yet',
                      subtitle: isArabic
                          ? 'أضف سيارتك الأولى لبدء متابعة الصيانة والوقود والمصاريف.'
                          : 'Add your first car to start tracking maintenance, fuel, and expenses.',
                      actionLabel: isArabic ? 'إضافة سيارة' : 'Add Vehicle',
                      onAction: () => _openAddVehicle(context, 0),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: state.vehicles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final vehicle = state.vehicles[index];
                        final isActive = state.activeVehicle?.id == vehicle.id;

                        return _VehicleCard(
                          vehicle: vehicle,
                          isActive: isActive,
                          isArabic: isArabic,
                          onSelect: () => context
                              .read<GarageBloc>()
                              .add(GarageActiveVehicleSelected(vehicle.id)),
                          onUpdateOdometer: () =>
                              _showQuickOdometerDialog(context, vehicle),
                          onEdit: () => _openEditVehicle(context, vehicle),
                          onDelete: () => _confirmDelete(context, vehicle),
                        );
                      },
                    ),
        );
      },
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.isActive,
    required this.isArabic,
    required this.onSelect,
    required this.onUpdateOdometer,
    required this.onEdit,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final bool isActive;
  final bool isArabic;
  final VoidCallback onSelect;
  final VoidCallback onUpdateOdometer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final numberFormat = NumberFormat('#,##0');

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primary : colors.border,
            width: isActive ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.16)
                        : colors.elevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    color: isActive ? AppColors.primary : colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${vehicle.make} ${vehicle.model}',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isArabic ? 'النشطة' : 'ACTIVE',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${vehicle.year}'
                        '${vehicle.plateNumber != null && vehicle.plateNumber!.isNotEmpty ? ' • ${vehicle.plateNumber}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(isArabic ? 'تعديل' : 'Edit'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        isArabic ? 'حذف' : 'Delete',
                        style: const TextStyle(color: AppColors.overdue),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.speed_rounded, size: 18, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  '${numberFormat.format(vehicle.currentOdometer)} ${vehicle.distanceUnit}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onUpdateOdometer,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(isArabic ? 'تحديث العداد' : 'Update Odo'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            if (vehicle.licenseExpiryDate != null ||
                vehicle.insuranceExpiryDate != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (vehicle.licenseExpiryDate != null)
                    _ExpiryBadge(
                      label: isArabic ? 'الرخصة' : 'License',
                      expiryDate: vehicle.licenseExpiryDate!,
                    ),
                  if (vehicle.insuranceExpiryDate != null)
                    _ExpiryBadge(
                      label: isArabic ? 'التأمين' : 'Insurance',
                      expiryDate: vehicle.insuranceExpiryDate!,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpiryBadge extends StatelessWidget {
  const _ExpiryBadge({
    required this.label,
    required this.expiryDate,
  });

  final String label;
  final DateTime expiryDate;

  @override
  Widget build(BuildContext context) {
    final status = ReminderCalculator.calculateStatus(
      currentOdometer: 0,
      nextDueDate: expiryDate,
    );
    final dateStr = DateFormat('yyyy-MM-dd').format(expiryDate);

    return StatusChip(
      type: status.toChipType(),
      label: '$label: $dateStr',
      compact: true,
    );
  }
}
