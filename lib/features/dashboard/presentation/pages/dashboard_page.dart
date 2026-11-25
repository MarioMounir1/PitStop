import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/theme/app_colors.dart';
import 'package:pitstop/core/utils/reminder_calculator.dart';
import 'package:pitstop/core/widgets/car_turntable_360_widget.dart';
import 'package:pitstop/core/widgets/empty_state_widget.dart';
import 'package:pitstop/core/widgets/pro_badge_widget.dart';
import 'package:pitstop/core/widgets/status_chip.dart';
import 'package:pitstop/features/garage/presentation/bloc/garage_bloc.dart';
import 'package:pitstop/features/garage/presentation/bloc/garage_event.dart';
import 'package:pitstop/features/garage/presentation/bloc/garage_state.dart';
import 'package:pitstop/features/garage/presentation/widgets/vehicle_switcher_sheet.dart';
import 'package:pitstop/features/maintenance/presentation/bloc/maintenance_bloc.dart';
import 'package:pitstop/features/maintenance/presentation/bloc/maintenance_state.dart';
import 'package:pitstop/features/paywall/cubit/entitlement_cubit.dart';
import 'package:pitstop/features/paywall/presentation/paywall_sheet.dart';
import 'package:pitstop/l10n/app_localizations.dart';

/// Tab 1: Active vehicle 360° hero card, odometer update, priority maintenance
/// alert card, and license/insurance countdown cards.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<void> _showQuickOdometerDialog(
    BuildContext context,
    Vehicle vehicle,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: vehicle.currentOdometer.toString(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.updateOdometer),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.currentOdometer,
            suffixText: vehicle.distanceUnit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionSave),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isPro = context.watch<EntitlementCubit>().state.isPro;
    final colors = context.appColors;

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<GarageBloc, GarageState>(
          builder: (context, garageState) {
            if (garageState.status == GarageStatus.loading &&
                garageState.vehicles.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final vehicle = garageState.activeVehicle;
            if (vehicle == null) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                    child: Row(
                      children: [
                        Text(
                          l10n.appName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: isArabic ? 'الحساب' : 'Account',
                          icon: const Icon(Icons.account_circle_outlined),
                          onPressed: () => context.push('/sign-in'),
                        ),
                        IconButton(
                          tooltip: l10n.navSettings,
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: EmptyStateWidget(
                      icon: Icons.directions_car_filled_outlined,
                      title: l10n.emptyVehiclesTitle,
                      subtitle: l10n.emptyVehiclesSubtitle,
                      actionLabel: l10n.addVehicle,
                      onAction: () => context.push('/vehicle/add'),
                    ),
                  ),
                ],
              );
            }

            final plateText =
                vehicle.plateNumber != null && vehicle.plateNumber!.isNotEmpty
                    ? ' · ${vehicle.plateNumber}'
                    : '';

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                // Header: Active vehicle · Plate / Model Year + Switch pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            context.push('/vehicle/edit', extra: vehicle),
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${isArabic ? 'السيارة النشطة' : 'Active vehicle'}$plateText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 13,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${vehicle.model} ${vehicle.year}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 28,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: isArabic ? 'الحساب والمزامنة' : 'Cloud & Account',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.cloud_outlined,
                        color: colors.textSecondary,
                        size: 21,
                      ),
                      onPressed: () => context.push('/sign-in'),
                    ),
                    IconButton(
                      tooltip: l10n.navSettings,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.settings_outlined,
                        color: colors.textSecondary,
                        size: 21,
                      ),
                      onPressed: () => context.push('/settings'),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: colors.elevated,
                      shape: StadiumBorder(
                        side: BorderSide(color: colors.border),
                      ),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => VehicleSwitcherSheet.show(
                          context,
                          isPro: isPro,
                          onPaywallRequired: () => PaywallSheet.show(context),
                        ),
                        onLongPress: () => context.push('/garage'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          child: Text(
                            isArabic ? 'تبديل' : 'Switch',
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Hero 360° Vehicle Card
                _HeroVehicle360Card(
                  vehicle: vehicle,
                  isArabic: isArabic,
                  onUpdateOdometer: () =>
                      _showQuickOdometerDialog(context, vehicle),
                ),
                const SizedBox(height: 14),

                // Priority Maintenance Card
                _PriorityMaintenanceCard(
                  vehicle: vehicle,
                  isArabic: isArabic,
                  onTap: () => context.go('/maintenance'),
                  onLogFirstService: () => context.push('/maintenance/add'),
                ),
                const SizedBox(height: 14),

                // License & Insurance Expiry Cards
                Row(
                  children: [
                    Expanded(
                      child: _DocumentCountdownCard(
                        label: isArabic ? 'انتهاء الرخصة' : 'License expires',
                        expiryDate: vehicle.licenseExpiryDate,
                        isArabic: isArabic,
                        onTap: () =>
                            context.push('/vehicle/edit', extra: vehicle),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DocumentCountdownCard(
                        label:
                            isArabic ? 'انتهاء التأمين' : 'Insurance expires',
                        expiryDate: vehicle.insuranceExpiryDate,
                        isArabic: isArabic,
                        onTap: () =>
                            context.push('/vehicle/edit', extra: vehicle),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroVehicle360Card extends StatelessWidget {
  const _HeroVehicle360Card({
    required this.vehicle,
    required this.isArabic,
    required this.onUpdateOdometer,
  });

  final Vehicle vehicle;
  final bool isArabic;
  final VoidCallback onUpdateOdometer;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final numberFormat = NumberFormat('#,##0');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProBadgeWidget(
                  label: isArabic
                      ? 'نموذج 3D بالذكاء الاصطناعي'
                      : 'AI-generated 3D model',
                ),
                const Spacer(),
                Text(
                  isArabic ? 'اسحب للدوران 360°' : 'Drag to rotate 360°',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CarTurntable360Viewer(
              vehicleColor: vehicle.color,
              carViewsJson: vehicle.carViewsJson,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'العداد' : 'Odometer',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${numberFormat.format(vehicle.currentOdometer)} ${vehicle.distanceUnit}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 25,
                              letterSpacing: -0.4,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onUpdateOdometer,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(98, 46),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(isArabic ? 'تحديث' : 'Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityMaintenanceCard extends StatelessWidget {
  const _PriorityMaintenanceCard({
    required this.vehicle,
    required this.isArabic,
    required this.onTap,
    required this.onLogFirstService,
  });

  final Vehicle vehicle;
  final bool isArabic;
  final VoidCallback onTap;
  final VoidCallback onLogFirstService;

  int _statusWeight(MaintenanceStatus s) {
    return switch (s) {
      MaintenanceStatus.overdue => 0,
      MaintenanceStatus.dueSoon => 1,
      MaintenanceStatus.ok => 2,
    };
  }

  String _statusLabel(MaintenanceStatus s) {
    return switch (s) {
      MaintenanceStatus.overdue => isArabic ? 'متأخر' : 'Overdue',
      MaintenanceStatus.dueSoon => isArabic ? 'قريب الاستحقاق' : 'Due Soon',
      MaintenanceStatus.ok => isArabic ? 'سليم' : 'OK',
    };
  }

  String _formatDueSummary(MaintenanceRecord record, MaintenanceStatus status) {
    final numberFormat = NumberFormat('#,##0');
    final dateFormat = DateFormat('d MMM yyyy', isArabic ? 'ar' : 'en');
    final now = DateTime.now();

    if (record.nextDueOdometer != null) {
      final target = numberFormat.format(record.nextDueOdometer);
      final diffKm = record.nextDueOdometer! - vehicle.currentOdometer;
      if (diffKm <= 0) {
        return isArabic
            ? 'كان مستحقاً عند $target ${vehicle.distanceUnit}'
            : 'Was due at $target ${vehicle.distanceUnit}';
      }
      final remaining = numberFormat.format(diffKm);
      return isArabic
          ? 'الموعد القادم عند $target ${vehicle.distanceUnit} · متبقي $remaining ${vehicle.distanceUnit}'
          : 'Next due at $target ${vehicle.distanceUnit} · in $remaining ${vehicle.distanceUnit}';
    }

    if (record.nextDueDate != null) {
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(
        record.nextDueDate!.year,
        record.nextDueDate!.month,
        record.nextDueDate!.day,
      );
      final days = dueDay.difference(today).inDays;
      final dateStr = dateFormat.format(record.nextDueDate!);
      if (days < 0) {
        return isArabic ? 'انتهى في $dateStr' : 'Was due $dateStr';
      }
      return isArabic
          ? 'خلال $days يوم · $dateStr'
          : 'Next due in $days days · $dateStr';
    }

    return '${dateFormat.format(record.serviceDate)} · '
        '${numberFormat.format(record.odometerAtService)} ${vehicle.distanceUnit}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocBuilder<MaintenanceBloc, MaintenanceState>(
      builder: (context, mState) {
        if (mState.records.isEmpty) {
          return Card(
            child: InkWell(
              onTap: onLogFirstService,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'الصيانة الدورية' : 'Maintenance',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isArabic
                                ? 'سجّل أول صيانة لتفعيل تنبيهات العداد والتاريخ'
                                : 'Tap to log your first service schedule',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 13.5,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const StatusChip(
                      type: StatusChipType.ok,
                      label: 'OK',
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final sorted = [...mState.records]..sort((a, b) {
            final sa =
                mState.statusByRecordId[a.id] ?? MaintenanceStatus.ok;
            final sb =
                mState.statusByRecordId[b.id] ?? MaintenanceStatus.ok;
            final w = _statusWeight(sa).compareTo(_statusWeight(sb));
            if (w != 0) return w;
            final oa = a.nextDueOdometer ?? 999999999;
            final ob = b.nextDueOdometer ?? 999999999;
            return oa.compareTo(ob);
          });

        final topRecord = sorted.first;
        final topStatus =
            mState.statusByRecordId[topRecord.id] ?? MaintenanceStatus.ok;

        return Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          topRecord.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                        ),
                      ),
                      StatusChip(
                        type: topStatus.toChipType(),
                        label: _statusLabel(topStatus),
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDueSummary(topRecord, topStatus),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          fontSize: 14,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DocumentCountdownCard extends StatelessWidget {
  const _DocumentCountdownCard({
    required this.label,
    required this.expiryDate,
    required this.isArabic,
    required this.onTap,
  });

  final String label;
  final DateTime? expiryDate;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    String valueText;
    Color valueColor = colors.textPrimary;

    if (expiryDate == null) {
      valueText = isArabic ? 'حدد التاريخ' : 'Set date';
      valueColor = colors.textSecondary;
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(
        expiryDate!.year,
        expiryDate!.month,
        expiryDate!.day,
      );
      final days = target.difference(today).inDays;
      if (days < 0) {
        valueText = isArabic ? 'منتهية' : 'Expired';
        valueColor = colors.overdue;
      } else {
        valueText = isArabic ? '$days يوم' : '$days days';
      }
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontSize: 13,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                valueText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: valueColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
