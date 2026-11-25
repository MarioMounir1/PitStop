import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pitstop/core/constants/maintenance_presets.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/services/backup_service.dart';
import 'package:pitstop/core/services/pdf_service.dart';
import 'package:pitstop/core/theme/app_colors.dart';
import 'package:pitstop/core/widgets/ad_banner_widget.dart';
import 'package:pitstop/features/analytics/presentation/pages/analytics_page.dart';
import 'package:pitstop/features/auth/presentation/pages/sign_in_page.dart';
import 'package:pitstop/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:pitstop/features/expenses/presentation/pages/add_expense_page.dart';
import 'package:pitstop/features/expenses/presentation/pages/fuel_and_expenses_page.dart';
import 'package:pitstop/features/fuel/presentation/bloc/fuel_bloc.dart';
import 'package:pitstop/features/fuel/presentation/pages/add_fuel_log_page.dart';
import 'package:pitstop/features/garage/presentation/bloc/garage_bloc.dart';
import 'package:pitstop/features/garage/presentation/bloc/garage_event.dart';
import 'package:pitstop/features/garage/presentation/pages/add_edit_vehicle_page.dart';
import 'package:pitstop/features/garage/presentation/pages/garage_page.dart';
import 'package:pitstop/features/maintenance/presentation/bloc/maintenance_bloc.dart';
import 'package:pitstop/features/maintenance/presentation/pages/add_edit_maintenance_page.dart';
import 'package:pitstop/features/maintenance/presentation/pages/maintenance_page.dart';
import 'package:pitstop/features/paywall/cubit/entitlement_cubit.dart';
import 'package:pitstop/features/paywall/presentation/paywall_sheet.dart';
import 'package:pitstop/features/settings/cubit/settings_cubit.dart';
import 'package:pitstop/features/settings/presentation/settings_page.dart';
import 'package:pitstop/injection_container.dart';
import 'package:pitstop/l10n/app_localizations.dart';

/// Builds the application's [GoRouter] with a 4-tab [StatefulShellRoute]
/// and all feature sub-routes.
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _PitStopNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          // Tab 2: Maintenance
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/maintenance',
                builder: (context, state) {
                  final vehicle =
                      context.watch<GarageBloc>().state.activeVehicle;
                  final isPro = context.watch<EntitlementCubit>().state.isPro;
                  return MaintenancePage(
                    vehicle: vehicle,
                    isPro: isPro,
                    onPaywallRequired: () => PaywallSheet.show(context),
                  );
                },
              ),
            ],
          ),
          // Tab 3: Fuel & Costs
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/fuel-expenses',
                builder: (context, state) {
                  final vehicle =
                      context.watch<GarageBloc>().state.activeVehicle;
                  return FuelAndExpensesPage(vehicle: vehicle);
                },
              ),
            ],
          ),
          // Tab 4: Analytics (with Settings action + PDF export wired)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const _AnalyticsTabWrapper(),
              ),
            ],
          ),
        ],
      ),

      // Sub-routes
      GoRoute(
        path: '/garage',
        builder: (context, state) {
          final isPro = context.watch<EntitlementCubit>().state.isPro;
          return GaragePage(
            isPro: isPro,
            onPaywallRequired: () => PaywallSheet.show(context),
          );
        },
      ),
      GoRoute(
        path: '/vehicle/add',
        builder: (context, state) {
          final isPro = context.read<EntitlementCubit>().state.isPro;
          final settings = context.read<SettingsCubit>().state;
          return AddEditVehiclePage(
            isPro: isPro,
            defaultDistanceUnit: settings.distanceUnit,
            defaultCurrencyCode: settings.currencyCode,
            onPaywallRequired: () => PaywallSheet.show(context),
          );
        },
      ),
      GoRoute(
        path: '/vehicle/edit',
        builder: (context, state) {
          final vehicle = state.extra as Vehicle?;
          final isPro = context.read<EntitlementCubit>().state.isPro;
          return AddEditVehiclePage(
            vehicle: vehicle,
            isPro: isPro,
            onPaywallRequired: () => PaywallSheet.show(context),
          );
        },
      ),
      GoRoute(
        path: '/maintenance/add',
        builder: (context, state) {
          final vehicle = context.read<GarageBloc>().state.activeVehicle;
          if (vehicle == null) {
            return const DashboardPage();
          }
          final preset = state.extra is MaintenancePreset
              ? state.extra as MaintenancePreset
              : null;
          final isPro = context.read<EntitlementCubit>().state.isPro;
          return AddEditMaintenancePage(
            vehicle: vehicle,
            initialPreset: preset,
            isPro: isPro,
            onPaywallRequired: () => PaywallSheet.show(context),
          );
        },
      ),
      GoRoute(
        path: '/fuel/add',
        builder: (context, state) {
          final vehicle = context.read<GarageBloc>().state.activeVehicle;
          if (vehicle == null) {
            return const DashboardPage();
          }
          return AddFuelLogPage(vehicle: vehicle);
        },
      ),
      GoRoute(
        path: '/expenses/add',
        builder: (context, state) {
          final vehicle = context.read<GarageBloc>().state.activeVehicle;
          if (vehicle == null) {
            return const DashboardPage();
          }
          return AddExpensePage(vehicle: vehicle);
        },
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) {
          return SettingsPage(
            backupService: sl<BackupService>(),
            onOpenSignIn: () => context.push('/sign-in'),
            onBackupRestored: () {
              context.read<GarageBloc>().add(const GarageStarted());
            },
          );
        },
      ),
    ],
  );
}

class _PitStopNavigationShell extends StatelessWidget {
  const _PitStopNavigationShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: context.appColors.border, width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: AdBannerWidget()),
            NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_outlined),
                  label: l10n.navDashboard,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.build_outlined),
                  selectedIcon: const Icon(Icons.build_rounded),
                  label: l10n.navMaintenance,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.local_gas_station_outlined),
                  selectedIcon: const Icon(Icons.local_gas_station_outlined),
                  label: l10n.navFuelAndCosts,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bar_chart_rounded),
                  selectedIcon: const Icon(Icons.bar_chart_rounded),
                  label: l10n.navAnalytics,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsTabWrapper extends StatefulWidget {
  const _AnalyticsTabWrapper();

  @override
  State<_AnalyticsTabWrapper> createState() => _AnalyticsTabWrapperState();
}

class _AnalyticsTabWrapperState extends State<_AnalyticsTabWrapper> {
  bool _isExporting = false;

  Future<void> _exportResalePdf(Vehicle vehicle) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final maintenanceRecords = context.read<MaintenanceBloc>().state.records;
      final fuelLogs = context.read<FuelBloc>().state.logs;
      final isPro = context.read<EntitlementCubit>().state.isPro;
      final isArabic = context.read<SettingsCubit>().state.isArabic;

      final pdfService = sl<PdfService>();
      final bytes = await pdfService.generateResaleReport(
        vehicle: vehicle,
        maintenanceRecords: maintenanceRecords,
        fuelLogs: fuelLogs,
        isPro: isPro,
        isArabic: isArabic,
      );

      final safeName =
          'pitstop_resale_${vehicle.make}_${vehicle.model}_${vehicle.year}.pdf'
              .replaceAll(RegExp(r'\s+'), '_')
              .toLowerCase();

      await pdfService.sharePdf(
        pdfBytes: bytes,
        fileName: safeName,
        subject: '${vehicle.make} ${vehicle.model} (${vehicle.year}) Report',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = context.watch<GarageBloc>().state.activeVehicle;

    return AnalyticsPage(
      vehicle: vehicle,
      isExportingPdf: _isExporting,
      onExportPdf: vehicle != null ? () => _exportResalePdf(vehicle) : null,
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}
