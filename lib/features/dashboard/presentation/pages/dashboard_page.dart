import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/core/theme/app_colors.dart';
import 'package:torq/core/utils/currency_formatter.dart';
import 'package:torq/core/utils/reminder_calculator.dart';
import 'package:torq/core/widgets/empty_state_widget.dart';
import 'package:torq/core/widgets/status_chip.dart';
import 'package:torq/features/analytics/presentation/bloc/analytics_bloc.dart';
import 'package:torq/features/analytics/presentation/bloc/analytics_state.dart';
import 'package:torq/features/garage/presentation/bloc/garage_bloc.dart';
import 'package:torq/features/garage/presentation/bloc/garage_event.dart';
import 'package:torq/features/garage/presentation/bloc/garage_state.dart';
import 'package:torq/features/garage/presentation/widgets/vehicle_switcher_sheet.dart';
import 'package:torq/features/maintenance/presentation/bloc/maintenance_bloc.dart';
import 'package:torq/features/maintenance/presentation/bloc/maintenance_state.dart';
import 'package:torq/features/paywall/cubit/entitlement_cubit.dart';
import 'package:torq/features/paywall/presentation/paywall_sheet.dart';
import 'package:torq/l10n/app_localizations.dart';

/// Tab 1: Active vehicle overview, urgent alerts, monthly spend, and quick actions.
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Text(l10n.appName),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isArabic ? 'الحساب' : 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/sign-in'),
          ),
          IconButton(
            tooltip: l10n.garageTitle,
            icon: const Icon(Icons.directions_car_outlined),
            onPressed: () => context.push('/garage'),
          ),
          IconButton(
            tooltip: l10n.navSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: BlocBuilder<GarageBloc, GarageState>(
        builder: (context, garageState) {
          if (garageState.status == GarageStatus.loading &&
              garageState.vehicles.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final vehicle = garageState.activeVehicle;
          if (vehicle == null) {
            return EmptyStateWidget(
              icon: Icons.directions_car_filled_outlined,
              title: l10n.emptyVehiclesTitle,
              subtitle: l10n.emptyVehiclesSubtitle,
              actionLabel: l10n.addVehicle,
              onAction: () => context.push('/vehicle/add'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _ActiveVehicleCard(
                vehicle: vehicle,
                vehicleCount: garageState.vehicles.length,
                onSwitchVehicle: () => VehicleSwitcherSheet.show(
                  context,
                  isPro: isPro,
                  onPaywallRequired: () => PaywallSheet.show(context),
                ),
                onUpdateOdometer: () =>
                    _showQuickOdometerDialog(context, vehicle),
              ),
              const SizedBox(height: 14),
              _UrgentAlertsBanner(
                vehicle: vehicle,
                onViewMaintenance: () => context.go('/maintenance'),
              ),
              const SizedBox(height: 14),
              _MonthlySummaryCard(
                vehicle: vehicle,
                locale: isArabic ? 'ar' : 'en',
              ),
              const SizedBox(height: 18),
              Text(
                l10n.quickActions,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.appColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.build_rounded,
                      label: l10n.logService,
                      color: AppColors.primary,
                      onTap: () => context.push('/maintenance/add'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.local_gas_station_rounded,
                      label: l10n.logFuel,
                      color: AppColors.ok,
                      onTap: () => context.push('/fuel/add'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.receipt_long_rounded,
                      label: l10n.logExpense,
                      color: AppColors.dueSoon,
                      onTap: () => context.push('/expenses/add'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActiveVehicleCard extends StatelessWidget {
  const _ActiveVehicleCard({
    required this.vehicle,
    required this.vehicleCount,
    required this.onSwitchVehicle,
    required this.onUpdateOdometer,
  });

  final Vehicle vehicle;
  final int vehicleCount;
  final VoidCallback onSwitchVehicle;
  final VoidCallback onUpdateOdometer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final numberFormat = NumberFormat('#,##0');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onSwitchVehicle,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_rounded,
                      color: AppColors.primary,
                      size: 26,
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
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: colors.textSecondary,
                            ),
                          ],
                        ),
                        Text(
                          '${vehicle.year}'
                          '${vehicle.plateNumber != null && vehicle.plateNumber!.isNotEmpty ? ' • ${vehicle.plateNumber}' : ''}'
                          ' • ${vehicle.fuelType.replaceAll('_', ' ').toUpperCase()}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (vehicleCount > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.elevated,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        '$vehicleCount',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.currentOdometer,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${numberFormat.format(vehicle.currentOdometer)} ${vehicle.distanceUnit}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: onUpdateOdometer,
                  icon: const Icon(Icons.speed_rounded, size: 18),
                  label: Text(l10n.updateOdometer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgentAlertsBanner extends StatelessWidget {
  const _UrgentAlertsBanner({
    required this.vehicle,
    required this.onViewMaintenance,
  });

  final Vehicle vehicle;
  final VoidCallback onViewMaintenance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<MaintenanceBloc, MaintenanceState>(
      builder: (context, mState) {
        final licenseStatus = vehicle.licenseExpiryDate != null
            ? ReminderCalculator.calculateStatus(
                currentOdometer: 0,
                nextDueDate: vehicle.licenseExpiryDate,
              )
            : MaintenanceStatus.ok;
        final insuranceStatus = vehicle.insuranceExpiryDate != null
            ? ReminderCalculator.calculateStatus(
                currentOdometer: 0,
                nextDueDate: vehicle.insuranceExpiryDate,
              )
            : MaintenanceStatus.ok;

        final docOverdue = (licenseStatus == MaintenanceStatus.overdue ? 1 : 0) +
            (insuranceStatus == MaintenanceStatus.overdue ? 1 : 0);
        final docDueSoon = (licenseStatus == MaintenanceStatus.dueSoon ? 1 : 0) +
            (insuranceStatus == MaintenanceStatus.dueSoon ? 1 : 0);

        final totalOverdue = mState.overdueCount + docOverdue;
        final totalDueSoon = mState.dueSoonCount + docDueSoon;

        if (totalOverdue == 0 && totalDueSoon == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.ok.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.ok.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: AppColors.ok,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.allSystemsOk,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.ok,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          );
        }

        final isCritical = totalOverdue > 0;
        final accent = isCritical ? AppColors.overdue : AppColors.dueSoon;

        return InkWell(
          onTap: onViewMaintenance,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(
                  isCritical
                      ? Icons.warning_amber_rounded
                      : Icons.schedule_rounded,
                  color: accent,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.urgentAlerts,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (totalOverdue > 0)
                            StatusChip(
                              type: StatusChipType.overdue,
                              label: '$totalOverdue ${l10n.statusOverdue}',
                              compact: true,
                            ),
                          if (totalDueSoon > 0)
                            StatusChip(
                              type: StatusChipType.dueSoon,
                              label: '$totalDueSoon ${l10n.statusDueSoon}',
                              compact: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: accent),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({
    required this.vehicle,
    required this.locale,
  });

  final Vehicle vehicle;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;

    return BlocBuilder<AnalyticsBloc, AnalyticsState>(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.monthlySpend,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(
                          state.thisMonthSpend,
                          currencyCode: vehicle.currencyCode,
                          locale: locale,
                          decimalDigits: 0,
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 42,
                  color: colors.border,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.avgFuelEconomy,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.avgKmPerL != null
                            ? '${state.avgKmPerL!.toStringAsFixed(1)} ${l10n.unitKmPerL}'
                            : '—',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.ok,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
