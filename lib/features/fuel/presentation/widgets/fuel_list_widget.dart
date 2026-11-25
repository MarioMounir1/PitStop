import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/theme/app_colors.dart';
import 'package:pitstop/core/widgets/empty_state_widget.dart';
import 'package:pitstop/features/fuel/presentation/bloc/fuel_bloc.dart';
import 'package:pitstop/features/fuel/presentation/bloc/fuel_event.dart';
import 'package:pitstop/features/fuel/presentation/bloc/fuel_state.dart';

/// Displays clean chronological fill-up cards (`Fill-up · 40 L`, `22 Nov · 11.4 km/L`, `600 EGP`).
class FuelListWidget extends StatelessWidget {
  const FuelListWidget({
    required this.vehicle,
    this.embedded = false,
    this.onAddFuel,
    super.key,
  });

  final Vehicle vehicle;
  final bool embedded;
  final VoidCallback? onAddFuel;

  String _formatLiters(double liters) {
    if (liters == liters.roundToDouble()) {
      return liters.toInt().toString();
    }
    return liters.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final colors = context.appColors;
    final dateFormat = DateFormat('d MMM', isArabic ? 'ar' : 'en');
    final costFormat = NumberFormat('#,##0.##');
    final odoFormat = NumberFormat('#,##0');

    return BlocBuilder<FuelBloc, FuelState>(
      builder: (context, state) {
        if (state.status == FuelLoadStatus.loading && state.logs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.logs.isEmpty) {
          if (embedded) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  isArabic
                      ? 'لا توجد سجلات وقود بعد'
                      : 'No fill-ups logged yet',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            );
          }
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

        final cards = <Widget>[
          for (final log in state.logs) ...[
            Dismissible(
              key: ValueKey(log.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) =>
                  context.read<FuelBloc>().add(FuelLogDeleted(log.id)),
              background: Container(
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  color: AppColors.overdueSurfaceDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.overdue,
                ),
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'تفويل · ${_formatLiters(log.liters)} لتر'
                                  : 'Fill-up · ${_formatLiters(log.liters)} L',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              log.consumptionKmPerL != null
                                  ? '${dateFormat.format(log.date)} · ${log.consumptionKmPerL!.toStringAsFixed(1)} ${isArabic ? 'كم/لتر' : 'km/L'}'
                                  : '${dateFormat.format(log.date)} · ${odoFormat.format(log.odometer)} ${vehicle.distanceUnit}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 13.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${costFormat.format(log.totalCost)} ${vehicle.currencyCode}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ];

        if (embedded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: cards,
        );
      },
    );
  }
}
