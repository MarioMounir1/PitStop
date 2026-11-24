import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/theme/app_colors.dart';
import 'package:pitstop/core/utils/reminder_calculator.dart';
import 'package:pitstop/core/widgets/pro_badge_widget.dart';
import 'package:pitstop/core/widgets/status_chip.dart';
import 'package:pitstop/features/garage/presentation/bloc/garage_bloc.dart';
import 'package:pitstop/features/garage/presentation/bloc/garage_event.dart';
import 'package:pitstop/features/garage/presentation/bloc/garage_state.dart';
import 'package:pitstop/features/garage/presentation/pages/add_edit_vehicle_page.dart';

/// Modal bottom sheet to switch the active vehicle or add a new one.
class VehicleSwitcherSheet extends StatelessWidget {
  const VehicleSwitcherSheet({
    this.isPro = false,
    this.onPaywallRequired,
    super.key,
  });

  final bool isPro;
  final VoidCallback? onPaywallRequired;

  static Future<void> show(
    BuildContext context, {
    bool isPro = false,
    VoidCallback? onPaywallRequired,
  }) {
    final garageBloc = context.read<GarageBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: garageBloc,
        child: VehicleSwitcherSheet(
          isPro: isPro,
          onPaywallRequired: onPaywallRequired,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numberFormat = NumberFormat('#,##0');

    return BlocBuilder<GarageBloc, GarageState>(
      builder: (context, state) {
        final isFreeLocked =
            !isPro && state.vehicles.length >= GarageBloc.freeVehicleLimit;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isArabic ? 'اختر السيارة' : 'Switch Vehicle',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.vehicles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final Vehicle v = state.vehicles[index];
                      final isActive = state.activeVehicle?.id == v.id;

                      return InkWell(
                        onTap: () {
                          context
                              .read<GarageBloc>()
                              .add(GarageActiveVehicleSelected(v.id));
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : colors.elevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  isActive ? AppColors.primary : colors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isActive
                                        ? Icons.check_circle_rounded
                                        : Icons.directions_car_outlined,
                                    color: isActive
                                        ? AppColors.primary
                                        : colors.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${v.make} ${v.model} (${v.year})',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        Text(
                                          '${numberFormat.format(v.currentOdometer)} ${v.distanceUnit}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: colors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (v.licenseExpiryDate != null ||
                                  v.insuranceExpiryDate != null) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (v.licenseExpiryDate != null)
                                      StatusChip(
                                        type: ReminderCalculator.calculateStatus(
                                          currentOdometer: 0,
                                          nextDueDate: v.licenseExpiryDate,
                                        ).toChipType(),
                                        label: isArabic ? 'الرخصة' : 'License',
                                        compact: true,
                                      ),
                                    if (v.insuranceExpiryDate != null)
                                      StatusChip(
                                        type: ReminderCalculator.calculateStatus(
                                          currentOdometer: 0,
                                          nextDueDate: v.insuranceExpiryDate,
                                        ).toChipType(),
                                        label:
                                            isArabic ? 'التأمين' : 'Insurance',
                                        compact: true,
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    final garageBloc = context.read<GarageBloc>();
                    Navigator.of(context).pop();
                    if (isFreeLocked) {
                      onPaywallRequired?.call();
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BlocProvider.value(
                          value: garageBloc,
                          child: AddEditVehiclePage(
                            isPro: isPro,
                            onPaywallRequired: onPaywallRequired,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isArabic ? 'إضافة سيارة جديدة' : 'Add New Vehicle'),
                      if (isFreeLocked) ...[
                        const SizedBox(width: 8),
                        const ProBadgeWidget(compact: true),
                      ],
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
