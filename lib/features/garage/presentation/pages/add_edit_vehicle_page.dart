import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/services/car_view_generator_service.dart';
import 'package:pitstop/core/theme/app_colors.dart';
import 'package:pitstop/core/widgets/car_turntable_360_widget.dart';
import 'package:pitstop/core/widgets/pro_badge_widget.dart';
import 'package:pitstop/features/garage/domain/repositories/garage_repository.dart';
import 'package:pitstop/features/garage/presentation/bloc/garage_bloc.dart';
import 'package:pitstop/features/garage/presentation/bloc/garage_event.dart';
import 'package:pitstop/injection_container.dart';
import 'package:uuid/uuid.dart';

/// Add / Edit Vehicle page featuring the 2-stage flow:
/// 1) Clean vehicle details form (including Color)
/// 2) "Creating your car" 8-angle Gemini 360° studio view builder.
class AddEditVehiclePage extends StatefulWidget {
  const AddEditVehiclePage({
    this.vehicle,
    this.isPro = false,
    this.onPaywallRequired,
    this.defaultDistanceUnit = 'km',
    this.defaultCurrencyCode = 'EGP',
    super.key,
  });

  final Vehicle? vehicle;
  final bool isPro;
  final VoidCallback? onPaywallRequired;
  final String defaultDistanceUnit;
  final String defaultCurrencyCode;

  @override
  State<AddEditVehiclePage> createState() => _AddEditVehiclePageState();
}

class _AddEditVehiclePageState extends State<AddEditVehiclePage> {
  static const List<String> _fuelTypes = [
    'petrol_80',
    'petrol_92',
    'petrol_95',
    'diesel',
    'hybrid',
    'electric',
  ];
  static const List<String> _currencies = ['EGP', 'SAR', 'AED', 'USD'];
  static const List<String> _distanceUnits = ['km', 'mi'];
  static const List<String> _presetColors = [
    'White',
    'Black',
    'Silver',
    'Gray',
    'Red',
    'Blue',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _colorController;
  late final TextEditingController _plateController;
  late final TextEditingController _odometerController;

  late String _fuelType;
  late String _currencyCode;
  late String _distanceUnit;
  DateTime? _licenseExpiryDate;
  DateTime? _insuranceExpiryDate;

  // Stage 2 ("Creating your car" 8-view builder) state
  bool _isCreatingViews = false;
  late String _pendingVehicleId;
  bool _vehiclePersisted = false;
  CarViewsProgress _viewsProgress = CarViewsProgress(
    statusByAngle: {
      for (final a in CarViewAngle.values) a: CarAngleBuildStatus.waiting,
    },
    localPathsByAngle: const {},
    usedAiImages: false,
    blueprint: const Car3dBlueprint(),
  );
  StreamSubscription<CarViewsProgress>? _generationSub;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _pendingVehicleId = v?.id ?? const Uuid().v4();
    _makeController = TextEditingController(text: v?.make ?? '');
    _modelController = TextEditingController(text: v?.model ?? '');
    _yearController = TextEditingController(
      text: v?.year.toString() ?? DateTime.now().year.toString(),
    );
    _colorController = TextEditingController(text: v?.color ?? 'White');
    _plateController = TextEditingController(text: v?.plateNumber ?? '');
    _odometerController = TextEditingController(
      text: v?.currentOdometer.toString() ?? '0',
    );
    _fuelType = v?.fuelType ?? 'petrol_92';
    _currencyCode = v?.currencyCode ?? widget.defaultCurrencyCode;
    _distanceUnit = v?.distanceUnit ?? widget.defaultDistanceUnit;
    _licenseExpiryDate = v?.licenseExpiryDate;
    _insuranceExpiryDate = v?.insuranceExpiryDate;
  }

  @override
  void dispose() {
    if (!_vehiclePersisted) {
      _generationSub?.cancel();
    }
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? initialDate,
    required ValueChanged<DateTime?> onSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  void _startGeneratingViews() {
    if (!_formKey.currentState!.validate()) return;

    final bloc = context.read<GarageBloc>();
    if (!_isEditing &&
        !widget.isPro &&
        bloc.state.vehicles.length >= GarageBloc.freeVehicleLimit) {
      widget.onPaywallRequired?.call();
      return;
    }

    final make = _makeController.text.trim();
    final model = _modelController.text.trim();
    final year = int.parse(_yearController.text.trim());
    final color = _colorController.text.trim().isEmpty
        ? 'White'
        : _colorController.text.trim();

    setState(() {
      _isCreatingViews = true;
      _viewsProgress = CarViewsProgress(
        statusByAngle: {
          for (final a in CarViewAngle.values) a: CarAngleBuildStatus.waiting,
        },
        localPathsByAngle: const {},
        usedAiImages: false,
        blueprint: Car3dBlueprint.heuristic(
          make: make,
          model: model,
          color: color,
        ),
      );
    });

    final generator = sl<CarViewGeneratorService>();
    final repo = sl<GarageRepository>();
    final targetId = _pendingVehicleId;

    _generationSub?.cancel();
    _generationSub = generator
        .generateAllViews(
          vehicleId: targetId,
          make: make,
          model: model,
          year: year,
          color: color,
        )
        .listen((progress) {
      if (mounted) {
        setState(() => _viewsProgress = progress);
      }
      if (_vehiclePersisted && progress.isComplete) {
        repo.updateVehicle(
          VehiclesCompanion(
            id: Value(targetId),
            carViewsJson: Value(progress.toCarViewsJson()),
          ),
        );
      }
    });
  }

  void _persistAndFinish({required bool goToDashboard}) {
    final bloc = context.read<GarageBloc>();
    final plate = _plateController.text.trim();
    final color = _colorController.text.trim().isEmpty
        ? 'White'
        : _colorController.text.trim();
    final odometer = int.tryParse(_odometerController.text.trim()) ?? 0;
    final year = int.parse(_yearController.text.trim());
    final carViewsJson = _isCreatingViews
        ? _viewsProgress.toCarViewsJson()
        : widget.vehicle?.carViewsJson;

    _vehiclePersisted = true;

    if (_isEditing) {
      final companion = VehiclesCompanion(
        id: Value(widget.vehicle!.id),
        make: Value(_makeController.text.trim()),
        model: Value(_modelController.text.trim()),
        year: Value(year),
        color: Value(color),
        plateNumber: Value(plate.isEmpty ? null : plate),
        currentOdometer: Value(odometer),
        distanceUnit: Value(_distanceUnit),
        currencyCode: Value(_currencyCode),
        fuelType: Value(_fuelType),
        licenseExpiryDate: Value(_licenseExpiryDate),
        insuranceExpiryDate: Value(_insuranceExpiryDate),
        carViewsJson: Value(carViewsJson),
      );
      bloc.add(GarageVehicleUpdated(companion));
    } else {
      final companion = VehiclesCompanion.insert(
        id: _pendingVehicleId,
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        year: year,
        color: Value(color),
        plateNumber: Value(plate.isEmpty ? null : plate),
        currentOdometer: Value(odometer),
        distanceUnit: Value(_distanceUnit),
        currencyCode: Value(_currencyCode),
        fuelType: Value(_fuelType),
        licenseExpiryDate: Value(_licenseExpiryDate),
        insuranceExpiryDate: Value(_insuranceExpiryDate),
        carViewsJson: Value(carViewsJson),
        isActive: const Value(true),
      );
      bloc.add(GarageVehicleAdded(vehicle: companion, isPro: widget.isPro));
    }

    if (goToDashboard) {
      try {
        context.go('/dashboard');
      } catch (_) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  void _cancelCreationStep() {
    _generationSub?.cancel();
    _generationSub = null;
    setState(() => _isCreatingViews = false);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_isCreatingViews) {
      return _buildCreatingYourCarScreen(context, isArabic: isArabic);
    }
    return _buildVehicleFormScreen(context, isArabic: isArabic);
  }

  Widget _buildCreatingYourCarScreen(
    BuildContext context, {
    required bool isArabic,
  }) {
    final colors = context.appColors;
    final make = _makeController.text.trim();
    final model = _modelController.text.trim();
    final year = _yearController.text.trim();
    final color = _colorController.text.trim().isEmpty
        ? 'White'
        : _colorController.text.trim();
    final plate = _plateController.text.trim();
    final readyCount = _viewsProgress.readyCount;
    final totalViews = CarViewAngle.values.length;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(isArabic ? 'إضافة سيارة' : 'Add vehicle'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vehicle identity summary card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic
                            ? 'الماركة · الموديل · السنة · اللون'
                            : 'Make · Model · Year · Color',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$make $model $year',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plate.isNotEmpty
                            ? '$color · ${isArabic ? 'لوحة' : 'Plate'} $plate'
                            : color,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // "Creating your car" 8-view grid card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'جارٍ تصميم سيارتك'
                                  : 'Creating your car',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 19,
                                  ),
                            ),
                          ),
                          ProBadgeWidget(
                            label: isArabic
                                ? '$readyCount من $totalViews زوايا'
                                : '$readyCount of $totalViews views',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isArabic
                            ? 'الزاوية الأولى توجّه باقي الزوايا لتبدو السيارة متطابقة من كل جانب.'
                            : 'The first view guides the rest, so the car looks the same from every side.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                              height: 1.35,
                              fontSize: 13,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // 2x4 Grid of 8 angles
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: CarViewAngle.values.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.94,
                        ),
                        itemBuilder: (context, index) {
                          final angle = CarViewAngle.values[index];
                          final status =
                              _viewsProgress.statusByAngle[angle] ??
                                  CarAngleBuildStatus.waiting;
                          final imagePath =
                              _viewsProgress.localPathsByAngle[angle.key];

                          return _AngleStatusTile(
                            angle: angle,
                            status: status,
                            imagePath: imagePath,
                            make: make,
                            model: model,
                            vehicleColor: color,
                            blueprint: _viewsProgress.blueprint,
                            isArabic: isArabic,
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: readyCount / totalViews,
                          minHeight: 8,
                          backgroundColor: colors.elevated,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _viewsProgress.statusNote ??
                            (isArabic
                                ? 'متصل: جاهز · متقطع: قيد الإنشاء · خافت: بالانتظار'
                                : 'Solid: ready · Dashed: building · Dim: waiting'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              FilledButton(
                onPressed: () => _persistAndFinish(goToDashboard: true),
                child: Text(
                  isArabic ? 'المتابعة إلى الرئيسية' : 'Continue to dashboard',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _cancelCreationStep,
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleFormScreen(
    BuildContext context, {
    required bool isArabic,
  }) {
    final colors = context.appColors;
    final dateFormat = DateFormat('d MMM yyyy', isArabic ? 'ar' : 'en');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? (isArabic ? 'تعديل السيارة' : 'Edit vehicle')
              : (isArabic ? 'إضافة سيارة' : 'Add vehicle'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'بيانات السيارة' : 'Vehicle details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _makeController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'الماركة (Toyota)' : 'Make (e.g. Toyota)',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? (isArabic ? 'مطلوب' : 'Required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _modelController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'الموديل (Corolla)' : 'Model (e.g. Corolla)',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? (isArabic ? 'مطلوب' : 'Required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _yearController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'سنة الصنع' : 'Year',
                            ),
                            validator: (v) {
                              final year = int.tryParse(v?.trim() ?? '');
                              if (year == null || year < 1950 || year > 2035) {
                                return isArabic ? 'غير صالح' : 'Invalid year';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _colorController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'اللون' : 'Color',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final c in _presetColors)
                          ChoiceChip(
                            label: Text(c),
                            selected: _colorController.text.trim().toLowerCase() ==
                                c.toLowerCase(),
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.22),
                            onSelected: (_) {
                              setState(() => _colorController.text = c);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _plateController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: isArabic
                                  ? 'رقم اللوحة (اختياري)'
                                  : 'Plate (optional)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _odometerController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'العداد' : 'Odometer',
                              suffixText: _distanceUnit,
                            ),
                            validator: (v) {
                              final odo = int.tryParse(v?.trim() ?? '');
                              if (odo == null || odo < 0) {
                                return isArabic ? 'غير صالح' : 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _fuelTypes.contains(_fuelType)
                                ? _fuelType
                                : _fuelTypes[1],
                            decoration: InputDecoration(
                              labelText:
                                  isArabic ? 'نوع الوقود' : 'Fuel type',
                            ),
                            items: _fuelTypes
                                .map(
                                  (f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(
                                      f.replaceAll('_', ' ').toUpperCase(),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _fuelType = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _currencies.contains(_currencyCode)
                                ? _currencyCode
                                : _currencies.first,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'العملة' : 'Currency',
                            ),
                            items: _currencies
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _currencyCode = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _distanceUnit,
                      decoration: InputDecoration(
                        labelText:
                            isArabic ? 'وحدة المسافة' : 'Distance unit',
                      ),
                      items: _distanceUnits
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _distanceUnit = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.badge_outlined,
                      color: colors.textSecondary,
                    ),
                    title: Text(
                      isArabic ? 'انتهاء الرخصة' : 'License expiry',
                    ),
                    subtitle: Text(
                      _licenseExpiryDate != null
                          ? dateFormat.format(_licenseExpiryDate!)
                          : (isArabic ? 'غير محدد' : 'Not set'),
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    trailing: _licenseExpiryDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () =>
                                setState(() => _licenseExpiryDate = null),
                          )
                        : Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                    onTap: () => _pickDate(
                      initialDate: _licenseExpiryDate,
                      onSelected: (d) => setState(() => _licenseExpiryDate = d),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(
                      Icons.shield_outlined,
                      color: colors.textSecondary,
                    ),
                    title: Text(
                      isArabic ? 'انتهاء التأمين' : 'Insurance expiry',
                    ),
                    subtitle: Text(
                      _insuranceExpiryDate != null
                          ? dateFormat.format(_insuranceExpiryDate!)
                          : (isArabic ? 'غير محدد' : 'Not set'),
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    trailing: _insuranceExpiryDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () =>
                                setState(() => _insuranceExpiryDate = null),
                          )
                        : Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                    onTap: () => _pickDate(
                      initialDate: _insuranceExpiryDate,
                      onSelected: (d) =>
                          setState(() => _insuranceExpiryDate = d),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_isEditing) ...[
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _persistAndFinish(goToDashboard: false);
                  }
                },
                child: Text(isArabic ? 'حفظ التغييرات' : 'Save changes'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _startGeneratingViews,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  isArabic
                      ? 'إعادة إنشاء زوايا السيارة 360°'
                      : 'Rebuild 8-view 360° model',
                ),
              ),
            ] else ...[
              FilledButton(
                onPressed: _startGeneratingViews,
                child: Text(
                  isArabic ? 'إنشاء السيارة (8 زوايا)' : 'Create your car',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AngleStatusTile extends StatelessWidget {
  const _AngleStatusTile({
    required this.angle,
    required this.status,
    required this.make,
    required this.model,
    required this.vehicleColor,
    required this.blueprint,
    required this.isArabic,
    this.imagePath,
  });

  final CarViewAngle angle;
  final CarAngleBuildStatus status;
  final String? imagePath;
  final String make;
  final String model;
  final String vehicleColor;
  final Car3dBlueprint blueprint;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final Widget innerContent = switch (status) {
      CarAngleBuildStatus.ready => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                child: CarAngleArtwork(
                  angle: angle,
                  imagePath: imagePath,
                  make: make,
                  model: model,
                  vehicleColor: vehicleColor,
                  blueprint: blueprint,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                angle.label(isArabic: isArabic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      CarAngleBuildStatus.building => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Text(
              '•••',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                angle.label(isArabic: isArabic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      CarAngleBuildStatus.waiting => Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                angle.label(isArabic: isArabic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
    };

    if (status == CarAngleBuildStatus.building) {
      return CustomPaint(
        painter: _DashedRoundedRectPainter(
          color: AppColors.primary,
          radius: 14,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.inputFill.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: innerContent,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.inputFill.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == CarAngleBuildStatus.ready
              ? AppColors.primary
              : colors.border.withValues(alpha: 0.75),
          width: status == CarAngleBuildStatus.ready ? 1.5 : 1.0,
        ),
      ),
      child: innerContent,
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      const dashLength = 4.5;
      const gapLength = 3.5;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
