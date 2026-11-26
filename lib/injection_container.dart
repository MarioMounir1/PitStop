import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/services/auth_service.dart';
import 'package:pitstop/core/services/backup_service.dart';
import 'package:pitstop/core/services/car_view_generator_service.dart';
import 'package:pitstop/core/services/cloud_sync_service.dart';
import 'package:pitstop/core/services/monetization_service.dart';
import 'package:pitstop/core/services/notification_service.dart';
import 'package:pitstop/core/services/pdf_service.dart';
import 'package:pitstop/core/services/push_notification_service.dart';
import 'package:pitstop/features/analytics/presentation/bloc/analytics_bloc.dart';
import 'package:pitstop/features/auth/cubit/auth_cubit.dart';
import 'package:pitstop/features/expenses/data/repositories/expenses_repository_impl.dart';
import 'package:pitstop/features/expenses/domain/repositories/expenses_repository.dart';
import 'package:pitstop/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:pitstop/features/fuel/data/repositories/fuel_repository_impl.dart';
import 'package:pitstop/features/fuel/domain/repositories/fuel_repository.dart';
import 'package:pitstop/features/fuel/presentation/bloc/fuel_bloc.dart';
import 'package:pitstop/features/garage/data/repositories/garage_repository_impl.dart';
import 'package:pitstop/features/garage/domain/repositories/garage_repository.dart';
import 'package:pitstop/features/garage/presentation/bloc/garage_bloc.dart';
import 'package:pitstop/features/maintenance/data/repositories/maintenance_repository_impl.dart';
import 'package:pitstop/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:pitstop/features/maintenance/presentation/bloc/maintenance_bloc.dart';
import 'package:pitstop/features/paywall/cubit/entitlement_cubit.dart';
import 'package:pitstop/features/settings/cubit/settings_cubit.dart';

final GetIt sl = GetIt.instance;

/// Registers all core services, Drift database, repositories, and BLoCs/Cubits.
Future<void> initDependencies() async {
  // External & Storage
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPreferences);
  sl.registerLazySingleton<AppDatabase>(AppDatabase.new);

  // Core Services
  final notificationService = NotificationService();
  await notificationService.initialize();
  sl.registerSingleton<NotificationService>(notificationService);

  final monetizationService = MonetizationService();
  await monetizationService.initialize();
  sl.registerSingleton<MonetizationService>(monetizationService);

  sl.registerLazySingleton<PdfService>(PdfService.new);
  sl.registerLazySingleton<BackupService>(
    () => BackupService(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<AuthService>(AuthService.new);
  sl.registerLazySingleton<CloudSyncService>(
    () => CloudSyncService(backupService: sl<BackupService>()),
  );
  sl.registerLazySingleton<CarViewGeneratorService>(
    () => CarViewGeneratorService(
      authService: sl<AuthService>(),
      prefs: sl<SharedPreferences>(),
    ),
  );
  sl.registerLazySingleton<PushNotificationService>(
    () => PushNotificationService(
      authService: sl<AuthService>(),
      notificationService: sl<NotificationService>(),
    ),
  );

  // Repositories
  sl.registerLazySingleton<GarageRepository>(
    () => GarageRepositoryImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<MaintenanceRepository>(
    () => MaintenanceRepositoryImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<FuelRepository>(
    () => FuelRepositoryImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<ExpensesRepository>(
    () => ExpensesRepositoryImpl(sl<AppDatabase>()),
  );

  // Cubits & BLoCs
  sl.registerFactory<AuthCubit>(
    () => AuthCubit(
      authService: sl<AuthService>(),
      cloudSyncService: sl<CloudSyncService>(),
    ),
  );
  sl.registerFactory<SettingsCubit>(
    () => SettingsCubit(sl<SharedPreferences>()),
  );
  sl.registerFactory<EntitlementCubit>(
    () => EntitlementCubit(sl<MonetizationService>()),
  );
  sl.registerFactory<GarageBloc>(
    () => GarageBloc(sl<GarageRepository>()),
  );
  sl.registerFactory<MaintenanceBloc>(
    () => MaintenanceBloc(sl<MaintenanceRepository>()),
  );
  sl.registerFactory<FuelBloc>(
    () => FuelBloc(sl<FuelRepository>()),
  );
  sl.registerFactory<ExpensesBloc>(
    () => ExpensesBloc(sl<ExpensesRepository>()),
  );
  sl.registerFactory<AnalyticsBloc>(
    () => AnalyticsBloc(sl<AppDatabase>()),
  );
}
