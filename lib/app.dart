import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/core/router/app_router.dart';
import 'package:torq/core/services/notification_service.dart';
import 'package:torq/core/theme/app_theme.dart';
import 'package:torq/features/analytics/presentation/bloc/analytics_bloc.dart';
import 'package:torq/features/analytics/presentation/bloc/analytics_event.dart';
import 'package:torq/features/auth/cubit/auth_cubit.dart';
import 'package:torq/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:torq/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:torq/features/fuel/presentation/bloc/fuel_bloc.dart';
import 'package:torq/features/fuel/presentation/bloc/fuel_event.dart';
import 'package:torq/features/garage/presentation/bloc/garage_bloc.dart';
import 'package:torq/features/garage/presentation/bloc/garage_event.dart';
import 'package:torq/features/garage/presentation/bloc/garage_state.dart';
import 'package:torq/features/maintenance/presentation/bloc/maintenance_bloc.dart';
import 'package:torq/features/maintenance/presentation/bloc/maintenance_event.dart';
import 'package:torq/features/maintenance/presentation/bloc/maintenance_state.dart';
import 'package:torq/features/paywall/cubit/entitlement_cubit.dart';
import 'package:torq/features/settings/cubit/settings_cubit.dart';
import 'package:torq/features/settings/cubit/settings_state.dart';
import 'package:torq/injection_container.dart';
import 'package:torq/l10n/app_localizations.dart';

class TorqApp extends StatefulWidget {
  const TorqApp({super.key});

  @override
  State<TorqApp> createState() => _TorqAppState();
}

class _TorqAppState extends State<TorqApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  void _syncActiveVehicle(BuildContext context, Vehicle? vehicle) {
    if (vehicle == null) return;
    context.read<MaintenanceBloc>().add(
          MaintenanceVehicleSubscribed(
            vehicleId: vehicle.id,
            currentOdometer: vehicle.currentOdometer,
          ),
        );
    context.read<FuelBloc>().add(FuelVehicleSubscribed(vehicle.id));
    context.read<ExpensesBloc>().add(ExpensesVehicleSubscribed(vehicle.id));
    context.read<AnalyticsBloc>().add(
          AnalyticsVehicleSubscribed(
            vehicleId: vehicle.id,
            currentOdometer: vehicle.currentOdometer,
          ),
        );

    unawaited(_scheduleVehicleDocReminders(vehicle));
  }

  Future<void> _scheduleVehicleDocReminders(Vehicle vehicle) async {
    final notifications = sl<NotificationService>();
    final label = '${vehicle.make} ${vehicle.model}';

    if (vehicle.licenseExpiryDate != null) {
      await notifications.scheduleReminder(
        _stableId('license_${vehicle.id}'),
        'License Expiring Soon — $label',
        'Your vehicle license expires soon. Renew it on time.',
        _reminderDate(vehicle.licenseExpiryDate!),
      );
    }

    if (vehicle.insuranceExpiryDate != null) {
      await notifications.scheduleReminder(
        _stableId('insurance_${vehicle.id}'),
        'Insurance Expiring Soon — $label',
        'Your vehicle insurance policy is due for renewal.',
        _reminderDate(vehicle.insuranceExpiryDate!),
      );
    }
  }

  Future<void> _scheduleMaintenanceReminders(
    List<MaintenanceRecord> records,
  ) async {
    final notifications = sl<NotificationService>();
    for (final record in records) {
      final notifId = _stableId('maint_${record.id}');
      if (record.reminderEnabled && record.nextDueDate != null) {
        await notifications.scheduleReminder(
          notifId,
          'Maintenance Due: ${record.title}',
          'Scheduled service reminder for ${record.title}.',
          _reminderDate(record.nextDueDate!),
        );
      } else {
        await notifications.cancelReminder(notifId);
      }
    }
  }

  int _stableId(String key) => key.hashCode & 0x7FFFFFFF;

  DateTime _reminderDate(DateTime dueDate) {
    final sevenDaysBefore = dueDate.subtract(const Duration(days: 7));
    final target = sevenDaysBefore.isAfter(DateTime.now())
        ? sevenDaysBefore
        : dueDate;
    return DateTime(target.year, target.month, target.day, 9);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => sl<AuthCubit>()),
        BlocProvider<SettingsCubit>(create: (_) => sl<SettingsCubit>()),
        BlocProvider<EntitlementCubit>(
          create: (_) => sl<EntitlementCubit>()..loadEntitlements(),
        ),
        BlocProvider<GarageBloc>(
          create: (_) => sl<GarageBloc>()..add(const GarageStarted()),
        ),
        BlocProvider<MaintenanceBloc>(create: (_) => sl<MaintenanceBloc>()),
        BlocProvider<FuelBloc>(create: (_) => sl<FuelBloc>()),
        BlocProvider<ExpensesBloc>(create: (_) => sl<ExpensesBloc>()),
        BlocProvider<AnalyticsBloc>(create: (_) => sl<AnalyticsBloc>()),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<GarageBloc, GarageState>(
            listenWhen: (prev, curr) =>
                prev.activeVehicle != curr.activeVehicle,
            listener: (context, state) {
              _syncActiveVehicle(context, state.activeVehicle);
            },
          ),
          BlocListener<MaintenanceBloc, MaintenanceState>(
            listenWhen: (prev, curr) => prev.records != curr.records,
            listener: (context, state) {
              unawaited(_scheduleMaintenanceReminders(state.records));
            },
          ),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settings) {
            return MaterialApp.router(
              title: 'Torq',
              debugShowCheckedModeBanner: false,
              themeMode: settings.themeMode,
              theme: AppTheme.light(locale: settings.locale),
              darkTheme: AppTheme.dark(locale: settings.locale),
              locale: settings.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: _router,
            );
          },
        ),
      ),
    );
  }
}
