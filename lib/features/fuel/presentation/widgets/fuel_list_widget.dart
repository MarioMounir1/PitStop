import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/theme/app_colors.dart';
import 'package:pitstop/core/utils/currency_formatter.dart';
import 'package:pitstop/core/widgets/empty_state_widget.dart';
import 'package:pitstop/features/fuel/presentation/bloc/fuel_bloc.dart';
import 'package:pitstop/features/fuel/presentation/bloc/fuel_event.dart';
import 'package:pitstop/features/fuel/presentation/bloc/fuel_state.dart';

/// Displays fuel KPIs and fill-up cards with color-coded `km/L` badges.
class FuelListWidget extends StatelessWidget {
  const FuelListWidget({
    required this.vehicle,
    this.onAddFuel,
    super.key,
  });

  final Vehicle vehicle;
  final VoidCallback? onAddFuel;

  Color _economyColor(double kmPerL) {
    if (kmPerL >= 12.0) return AppColors.ok;
    if (kmPerL >= 8.0) return AppColors.dueSoon;
    return AppColors.overdue;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final colors = context.appColors;
    final dateFormat = DateFormat('yyyy-MM-dd');
    final numberFormat = NumberFormat('#,##0');

    return BlocBuilder<FuelBloc, FuelState>(
      builder: (context, state) {
        if (state.status == FuelLoadStatus.loading && state.logs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.logs.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.local_gas_station_outlined,
            title: isArabic ? 'لا توجد سجلات وقود' : 'No fuel logs yet',
            subtitle: isArabic
                ? 'سجّل عملية التزود بالوقود لحساب الاستهلاك والمصروف الشهري.'
                : 'Record a fill-up to track fuel economy and monthly spend.',
            actionLabel: isArabic ? 'إضافة وقود' : 'Log Fuel',
            onAction: onAddFuel,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: _FuelKpiCard(
                    label: isArabic ? 'متوسط الاستهلاك' : 'Avg Economy',
                    value: state.averageKmPerL != null
                        ? '${state.averageKmPerL!.toStringAsFixed(1)} ${isArabic ? 'كم/لتر' : 'km/L'}'
                        : '—',
                    valueColor: state.averageKmPerL != null
                        ? _economyColor(state.averageKmPerL!)
                        : colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FuelKpiCard(
                    label: isArabic ? 'هذا الشهر' : 'This Month',
                    value: CurrencyFormatter.formatCompact(
                      state.monthlyFuelSpend,
                      currencyCode: vehicle.currencyCode,
                      locale: isArabic ? 'ar' : 'en',
                    ),
                    valueColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FuelKpiCard(
                    label: isArabic ? 'إجمالي اللترات' : 'Total Liters',
                    value:
                        '${state.totalLiters.toStringAsFixed(0)} ${isArabic ? 'لتر' : 'L'}',
                    valueColor: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final log in state.logs) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.local_gas_station_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CurrencyFormatter.format(
                                    log.totalCost,
                                    currencyCode: vehicle.currencyCode,
                                    locale: isArabic ? 'ar' : 'en',
                                    decimalDigits: 0,
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '${dateFormat.format(log.date)} • '
                                  '${numberFormat.format(log.odometer)} ${vehicle.distanceUnit}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (log.consumptionKmPerL != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _economyColor(log.consumptionKmPerL!)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _economyColor(log.consumptionKmPerL!)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                '${log.consumptionKmPerL!.toStringAsFixed(1)} ${isArabic ? 'كم/لتر' : 'km/L'}',
                                style: TextStyle(
                                  color: _economyColor(log.consumptionKmPerL!),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            '${log.liters.toStringAsFixed(1)} ${isArabic ? 'لتر' : 'L'} @ '
                            '${log.pricePerLiter.toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                          if (log.isFullTank) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.elevated,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isArabic ? 'تفويل كامل' : 'Full Tank',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                            ),
                            color: colors.textMuted,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => context
                                .read<FuelBloc>()
                                .add(FuelLogDeleted(log.id)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _FuelKpiCard extends StatelessWidget {
  const _FuelKpiCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
