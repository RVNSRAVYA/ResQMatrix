import 'package:flutter/material.dart';

import '../services/prediction_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class _Preset {
  final String label;
  final IconData icon;
  final Map<String, String> values;
  final String landCover;
  final String soilType;
  final bool infrastructure;
  final bool historicalFloods;
  const _Preset(this.label, this.icon, this.values, this.landCover, this.soilType, this.infrastructure,
      this.historicalFloods);
}

const _presets = <_Preset>[
  _Preset(
    'Monsoon surge · delta city',
    Icons.thunderstorm_rounded,
    {
      'Latitude': '16.51', 'Longitude': '80.65', 'Rainfall (mm)': '210', 'Rainfall 3-Day (mm)': '430',
      'Temperature (°C)': '28', 'Humidity (%)': '92', 'River Discharge (m³/s)': '3600',
      'Water Level (m)': '7.2', 'Elevation (m)': '11', 'Population Density': '3900',
    },
    'Urban', 'Clay', false, true,
  ),
  _Preset(
    'Heavy showers · river plains',
    Icons.grain_rounded,
    {
      'Latitude': '25.59', 'Longitude': '85.14', 'Rainfall (mm)': '95', 'Rainfall 3-Day (mm)': '200',
      'Temperature (°C)': '31', 'Humidity (%)': '82', 'River Discharge (m³/s)': '2400',
      'Water Level (m)': '5.0', 'Elevation (m)': '53', 'Population Density': '1800',
    },
    'Agricultural', 'Silt', true, false,
  ),
  _Preset(
    'Dry season · highland',
    Icons.wb_sunny_rounded,
    {
      'Latitude': '31.10', 'Longitude': '77.17', 'Rainfall (mm)': '4', 'Rainfall 3-Day (mm)': '9',
      'Temperature (°C)': '22', 'Humidity (%)': '45', 'River Discharge (m³/s)': '250',
      'Water Level (m)': '1.2', 'Elevation (m)': '1500', 'Population Density': '250',
    },
    'Forest', 'Loam', true, false,
  ),
];

class FloodPredictionScreen extends StatefulWidget {
  const FloodPredictionScreen({super.key});

  @override
  State<FloodPredictionScreen> createState() => _FloodPredictionScreenState();
}

class _FloodPredictionScreenState extends State<FloodPredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    'Latitude': TextEditingController(text: '16.51'),
    'Longitude': TextEditingController(text: '80.65'),
    'Elevation (m)': TextEditingController(text: '11'),
    'Population Density': TextEditingController(text: '3900'),
    'Rainfall (mm)': TextEditingController(text: '210'),
    'Rainfall 3-Day (mm)': TextEditingController(text: '430'),
    'Temperature (°C)': TextEditingController(text: '28'),
    'Humidity (%)': TextEditingController(text: '92'),
    'River Discharge (m³/s)': TextEditingController(text: '3600'),
    'Water Level (m)': TextEditingController(text: '7.2'),
  };
  static const _landCovers = ['Urban', 'Agricultural', 'Forest', 'Water Body', 'Grassland'];
  static const _soilTypes = ['Clay', 'Peat', 'Loam', 'Sandy', 'Silt'];

  String _landCover = 'Urban';
  String _soilType = 'Clay';
  bool _infrastructure = false;
  bool _historicalFloods = true;
  bool _loading = false;
  String? _error;
  PredictionResult? _result;
  int? _activePreset = 0;
  final PredictionService _service = PredictionService();

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _value(String key) => double.parse(_controllers[key]!.text.trim());

  void _applyPreset(int index) {
    final p = _presets[index];
    setState(() {
      _activePreset = index;
      p.values.forEach((k, v) => _controllers[k]?.text = v);
      _landCover = p.landCover;
      _soilType = p.soilType;
      _infrastructure = p.infrastructure;
      _historicalFloods = p.historicalFloods;
      _result = null;
      _error = null;
    });
  }

  Future<void> _predict() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _service.predictFlood(
        latitude: _value('Latitude'),
        longitude: _value('Longitude'),
        rainfall: _value('Rainfall (mm)'),
        rainfall3Day: _value('Rainfall 3-Day (mm)'),
        temperature: _value('Temperature (°C)'),
        humidity: _value('Humidity (%)'),
        riverDischarge: _value('River Discharge (m³/s)'),
        waterLevel: _value('Water Level (m)'),
        elevation: _value('Elevation (m)'),
        landCover: _landCover,
        soilType: _soilType,
        populationDensity: _value('Population Density'),
        infrastructure: _infrastructure ? 1 : 0,
        historicalFloods: _historicalFloods ? 1 : 0,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not generate a prediction. Check that the ResQMatrix API is running.\n$error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Flood Risk Intelligence')),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final form = _buildForm();
        final result = _buildResultPanel();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 36),
              children: [
                const GradientHeader(
                  eyebrow: 'ResQMatrix  /  AI analytics',
                  title: 'Understand the risk\nbefore response.',
                  subtitle:
                      'Enter weather, river and terrain conditions to get a model-estimated flood probability learned from 25 years of station records.',
                  icon: Icons.query_stats_rounded,
                ),
                const SizedBox(height: 16),
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: form),
                    const SizedBox(width: 18),
                    Expanded(flex: 2, child: result),
                  ])
                else ...[
                  form,
                  const SizedBox(height: 16),
                  result,
                ],
                const SizedBox(height: 20),
                const Center(
                  child: Text('Decision support only · Confirm conditions with official authorities',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 11)),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 4, 2, 10),
          child: Text('QUICK SCENARIOS',
              style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < _presets.length; i++)
            ChoiceChip(
              avatar: Icon(_presets[i].icon, size: 16, color: _activePreset == i ? AppColors.teal : AppColors.muted),
              label: Text(_presets[i].label),
              selected: _activePreset == i,
              showCheckmark: false,
              onSelected: (_) => _applyPreset(i),
            ),
        ]),
        const SectionTitle(step: '1', title: 'Location & terrain', subtitle: 'Where is the area and how exposed is it?'),
        _gridFields(['Latitude', 'Longitude', 'Elevation (m)', 'Population Density']),
        const SectionTitle(
            step: '2', title: 'Weather & hydrology', subtitle: 'Current rainfall, river and water-level readings.'),
        _gridFields([
          'Rainfall (mm)',
          'Rainfall 3-Day (mm)',
          'Temperature (°C)',
          'Humidity (%)',
          'River Discharge (m³/s)',
          'Water Level (m)',
        ]),
        const SectionTitle(step: '3', title: 'Area characteristics', subtitle: 'Select the closest category.'),
        LayoutBuilder(builder: (context, c) {
          final two = c.maxWidth > 520;
          final w = two ? (c.maxWidth - 12) / 2 : c.maxWidth;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
              width: w,
              child: DropdownButtonFormField<String>(
                value: _landCover,
                decoration: const InputDecoration(labelText: 'Land cover'),
                items: _landCovers.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() {
                  _landCover = v ?? _landCover;
                  _activePreset = null;
                }),
              ),
            ),
            SizedBox(
              width: w,
              child: DropdownButtonFormField<String>(
                value: _soilType,
                decoration: const InputDecoration(labelText: 'Soil type'),
                items: _soilTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() {
                  _soilType = v ?? _soilType;
                  _activePreset = null;
                }),
              ),
            ),
          ]);
        }),
        const SizedBox(height: 12),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Flood-control infrastructure',
                  style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 13.5)),
              subtitle: const Text('Drainage or embankments present in the area',
                  style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
              value: _infrastructure,
              onChanged: (v) => setState(() {
                _infrastructure = v;
                _activePreset = null;
              }),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Frequent recent floods',
                  style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 13.5)),
              subtitle: const Text('Three or more flood events at this location last year',
                  style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
              value: _historicalFloods,
              onChanged: (v) => setState(() {
                _historicalFloods = v;
                _activePreset = null;
              }),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _predict,
            icon: _loading
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.bolt_rounded),
            label: Text(_loading ? 'Analysing conditions…' : 'Estimate flood risk'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          InfoBanner(text: _error!, icon: Icons.error_outline_rounded, color: AppColors.red),
        ],
      ]),
    );
  }

  Widget _buildResultPanel() {
    final r = _result;
    if (r == null) {
      return SoftCard(
        padding: const EdgeInsets.all(26),
        child: Column(children: [
          const IconBadge(icon: Icons.insights_rounded, color: AppColors.indigo, size: 62),
          const SizedBox(height: 16),
          const Text('Your estimate appears here',
              style: TextStyle(color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
            'Pick a quick scenario or adjust the inputs, then choose “Estimate flood risk”.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 18),
          const InfoBanner(
            text:
                'The model is trained on simulated historical-style station records (2000–2025). Treat results as a demonstration, not an official warning.',
          ),
        ]),
      );
    }
    final color = AppColors.risk(r.riskLevel);
    return SoftCard(
      borderColor: color.withValues(alpha: .4),
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('MODEL ESTIMATE',
              style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
          const Spacer(),
          StatusChip(
            label: r.floodLabel,
            color: r.floodOccurred == 1 ? AppColors.red : AppColors.green,
            icon: r.floodOccurred == 1 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
          ),
        ]),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 150,
            height: 150,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: r.floodProbability.clamp(0.0, 1.0).toDouble(),
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: color.withValues(alpha: .12),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${r.floodProbabilityPercent.toStringAsFixed(1)}%',
                    style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
                const Text('flood probability', style: TextStyle(color: AppColors.muted, fontSize: 10.5)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(r.riskLevel.toUpperCase(),
              style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
        const SizedBox(height: 18),
        _RiskScale(probability: r.floodProbability),
        const SizedBox(height: 18),
        Text('Model: ${r.model}',
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 8),
        Text(r.disclaimer, style: const TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.45)),
      ]),
    );
  }

  Widget _gridFields(List<String> keys) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 520 ? 2 : 1;
          const gap = 12.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: 12,
            children: keys
                .map((key) => SizedBox(
                      width: width,
                      child: TextFormField(
                        controller: _controllers[key],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(labelText: key),
                        onChanged: (_) {
                          if (_activePreset != null) setState(() => _activePreset = null);
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Required';
                          if (double.tryParse(value.trim()) == null) return 'Enter a number';
                          return null;
                        },
                      ),
                    ))
                .toList(),
          );
        },
      );
}

/// Four-band risk scale with a marker at the predicted probability.
class _RiskScale extends StatelessWidget {
  final double probability;
  const _RiskScale({required this.probability});

  @override
  Widget build(BuildContext context) {
    final p = probability.clamp(0.0, 1.0).toDouble();
    const bands = [
      ('Low', AppColors.green),
      ('Moderate', AppColors.amber),
      ('High', AppColors.orange),
      ('Critical', AppColors.red),
    ];
    return LayoutBuilder(builder: (context, c) {
      final x = (c.maxWidth * p).clamp(5.0, c.maxWidth - 5).toDouble();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 18,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              top: 5,
              bottom: 5,
              child: Row(children: [
                for (final b in bands)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(color: b.$2, borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
              ]),
            ),
            Positioned(
              left: x - 5,
              top: 0,
              child: Container(
                width: 10,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 7),
        Row(children: [
          for (final b in bands)
            Expanded(
              child: Text(b.$1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
        ]),
      ]);
    });
  }
}
