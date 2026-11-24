# Torq — Car Maintenance, Fuel & Expense Tracker

An offline-first Flutter application for tracking vehicle maintenance schedules, fuel efficiency, general car expenses, spending analytics, and generating verified A4 resale maintenance reports in **English (LTR)** and **Arabic (RTL)**.

---

## Features

- **Vehicle Garage**
  - Manage multiple vehicles with make, model, year, plate number, fuel type, currency, and odometer tracking.
  - Quick active-vehicle switcher and one-tap odometer updates.
  - License and insurance expiry tracking with automatic due-soon/overdue badges and local reminders.
- **Smart Maintenance Tracking**
  - 10 built-in automotive presets (Engine Oil, Oil Filter, Air Filter, AC Filter, Brake Pads, Tires, Battery, Timing Belt, Spark Plugs, Transmission Oil) with automatic next-due odometer and date calculation.
  - Automatic `OK` / `Due Soon` (`<= 500 km` or `<= 14 days`) / `Overdue` status calculation.
  - Segmented views (`All`, `Upcoming`, `History`) and Pro-gated receipt photo attachments stored locally.
  - Auto-syncs vehicle odometer whenever a higher service reading is logged.
- **Fuel Economy & General Expenses**
  - Smart 2-of-3 fill-up calculator (enter any two of Liters, Price/L, or Total Cost to auto-calculate the third).
  - Accurate consecutive full-tank `km/L` calculation that accumulates intermediate partial fills.
  - Categorized general expenses (`wash`, `parking`, `tolls`, `fines`, `licensing`, `insurance`, `accessories`, `other`) with monthly totals.
- **Analytics & Resale PDF Reports**
  - Live KPI cards (This Month Spend, All-Time Spend, Avg `km/L`, Cost per km).
  - 6-month stacked monthly spend `BarChart` and fuel efficiency trend `LineChart` powered by `fl_chart`.
  - One-tap **A4 Resale Maintenance Report (PDF)** using bundled `Cairo` fonts with full Arabic RTL support (watermarked on Free, clean on Pro).
- **Offline-First Storage & JSON Backup**
  - Local SQLite database powered by `Drift` with cascading foreign keys (`PRAGMA foreign_keys = ON`).
  - Versioned JSON export & transactional restore via `BackupService` (Pro-gated).
- **Localization, Theme & Monetization**
  - Full **English** (`Plus Jakarta Sans`) and **Arabic** (`Cairo`, RTL) localization.
  - Dark Automotive Material 3 palette + clean Light theme persisted via `SharedPreferences`.
  - RevenueCat (`purchases_flutter`) paywall & AdMob (`google_mobile_ads`) banner with safe debug fallback when API keys are placeholders.

---

## Tech Stack

| Layer | Packages |
| --- | --- |
| **State Management** | `flutter_bloc`, `equatable` |
| **Dependency Injection** | `get_it` |
| **Navigation** | `go_router` (`StatefulShellRoute.indexedStack`) |
| **Local Database** | `drift`, `drift_flutter`, `sqlite3_flutter_libs` |
| **Charts & PDF** | `fl_chart`, `pdf`, `printing` |
| **Notifications** | `flutter_local_notifications`, `timezone` |
| **Monetization** | `purchases_flutter`, `google_mobile_ads` |
| **Utilities & Media** | `intl`, `shared_preferences`, `image_picker`, `path_provider`, `share_plus`, `uuid` |

---

## Project Structure

```text
lib/
├── main.dart                     # App entry point & Android 15 edge-to-edge setup
├── app.dart                      # MultiBlocProvider, reactive vehicle sync & MaterialApp.router
├── injection_container.dart      # get_it dependency registration
├── l10n/                         # English & Arabic ARB files + generated AppLocalizations
├── core/
│   ├── constants/                # Maintenance presets
│   ├── database/                 # Drift AppDatabase & 4 SQLite tables
│   ├── router/                   # GoRouter 4-tab shell & sub-routes
│   ├── services/                 # Notification, PDF, Backup & Monetization services
│   ├── theme/                    # Dark Automotive & Light Material 3 themes
│   ├── utils/                    # ReminderCalculator, FuelCalculator, CurrencyFormatter
│   └── widgets/                  # Shared widgets (EmptyState, StatusChip, ProBadge, AdBanner)
└── features/
    ├── analytics/                # Spend & fuel trend aggregation + fl_chart dashboard
    ├── dashboard/                # Active car card, urgent alerts, monthly KPIs & quick actions
    ├── expenses/                 # General expenses CRUD + combined Fuel & Expenses page
    ├── fuel/                     # Fuel logs CRUD, km/L recalculation & smart fill-up form
    ├── garage/                   # Multi-vehicle CRUD, switcher sheet & odometer sync
    ├── maintenance/              # Service records CRUD, preset auto-fill & receipt photos
    ├── paywall/                  # EntitlementCubit & dark glassmorphic PaywallSheet
    └── settings/                 # SettingsCubit & grouped SettingsPage
```

---

## Getting Started

### Prerequisites

- Flutter SDK `>= 3.44.0` (Dart `>= 3.12.2`)

### Setup & Code Generation

```bash
# 1. Install dependencies
flutter pub get

# 2. Generate localizations (app_en.arb / app_ar.arb)
flutter gen-l10n

# 3. Generate Drift database code (app_database.g.dart)
dart run build_runner build --delete-conflicting-outputs
```

### Run & Verify

```bash
# Run the app
flutter run

# Static analysis
flutter analyze

# Run unit tests
flutter test
```

---

## Monetization Configuration

By default, `MonetizationService` (`lib/core/services/monetization_service.dart`) runs in a **safe debug fallback mode** when placeholder RevenueCat API keys are detected and uses official Google AdMob test banner IDs. Replace the placeholder keys with your production RevenueCat and AdMob IDs before store release.
