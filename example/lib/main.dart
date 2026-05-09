import 'package:flutter/material.dart';
import 'package:oksigenia_farmkit/oksigenia_farmkit.dart';

/// Live demo for `oksigenia-farmkit`.
///
/// The kit itself is engine-only — it ships zero rendering, zero
/// audio, zero assets. This demo's job is to prove that everything
/// you need to drive a farming-game UI is exposed by the public API:
/// turn loop, weather, fertility, rotation, pest pressure, action
/// budget, dynamic pricing, narrative events.
///
/// What you see on screen below is plain Flutter widgets reading from
/// the engine's read-only state and calling its public methods. Drop
/// the kit into any Flutter / Flame app and render however you like.
void main() {
  runApp(const _ExampleApp());
}

class _ExampleApp extends StatelessWidget {
  const _ExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'oksigenia-farmkit demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2F5243),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFBF5ED),
      ),
      home: const _DemoScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _DemoScreen extends StatefulWidget {
  const _DemoScreen();

  @override
  State<_DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<_DemoScreen> {
  late Farm farm;
  String _weatherLabel = '—';
  double _weatherFactor = 0.0;
  final List<FarmEvent> _eventLog = [];

  @override
  void initState() {
    super.initState();
    _resetFarm();
  }

  void _resetFarm() {
    farm = Farm(
      fields: [
        Field(id: 'north', size: 1.0, soil: SoilType.loam),
        Field(id: 'south', size: 0.5, soil: SoilType.sandy),
        Field(id: 'creek', size: 0.7, soil: SoilType.clay),
      ],
      weather: const MockWeatherProvider.forClimate(
        ClimatePreset.subtropicalSouthernCone,
      ),
      economy: const SeasonalDynamicPricing(southernHemisphere: true),
      actionsPerTurn: 3,
    );
    _weatherLabel = '—';
    _weatherFactor = 0.0;
    _eventLog.clear();
  }

  void _drainEvents() {
    final fresh = farm.drainEvents();
    if (fresh.isEmpty) return;
    _eventLog.addAll(fresh);
  }

  void _advance() {
    setState(() {
      _weatherFactor = farm.advanceTurn();
      final w = farm.weather.sample(turn: farm.turn);
      _weatherLabel = '${w.label} · ${w.temperatureC.toStringAsFixed(1)}°C';
      _drainEvents();
    });
  }

  void _plant(String id, Crop crop) {
    setState(() {
      try {
        farm.plant(fieldId: id, crop: crop);
      } on OutOfActionsError {
        _flash('No actions left this turn — advance one week.');
      } on StateError {
        // Field already planted; harmless.
      }
      _drainEvents();
    });
  }

  void _harvest(String id) {
    setState(() {
      try {
        farm.harvest(id);
      } on OutOfActionsError {
        _flash('No actions left this turn — advance one week.');
      }
      _drainEvents();
    });
  }

  void _treat(String id) {
    setState(() {
      try {
        farm.treat(id);
      } on OutOfActionsError {
        _flash('No actions left this turn — advance one week.');
      }
      _drainEvents();
    });
  }

  void _flash(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _restart() {
    setState(_resetFarm);
  }

  @override
  Widget build(BuildContext context) {
    final season = seasonForTurn(farm.turn, southernHemisphere: true);
    final actionsLeft = farm.actionsRemaining ?? 0;
    final actionsTotal = farm.actionsPerTurn ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('oksigenia-farmkit · live demo'),
        backgroundColor: const Color(0xFF2F5243),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset',
            onPressed: _restart,
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 32 : 16,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HeroCard(),
              const SizedBox(height: 16),
              _StatusCard(
                turn: farm.turn,
                weather: _weatherLabel,
                factor: _weatherFactor,
                season: season,
                actionsLeft: actionsLeft,
                actionsTotal: actionsTotal,
              ),
              const SizedBox(height: 16),
              ...farm.fields.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FieldCard(
                      field: f,
                      farm: farm,
                      onPlant: (c) => _plant(f.id, c),
                      onHarvest: () => _harvest(f.id),
                      onTreat: () => _treat(f.id),
                    ),
                  )),
              if (_eventLog.isNotEmpty) ...[
                const SizedBox(height: 8),
                _EventLogCard(events: _eventLog),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _advance,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFBE5D38),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.skip_next),
                label: const Text(
                  'Advance one week',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              const _Footer(),
            ],
          ),
        );
      }),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF2F5243),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.agriculture, color: Color(0xFFE4E2DA), size: 28),
                SizedBox(width: 10),
                Text(
                  'oksigenia-farmkit',
                  style: TextStyle(
                    color: Color(0xFFE4E2DA),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Modular farming-game engine for Flutter / Flame.\n'
              'Turn-based, weather-driven crop yield, quality-driven economy.',
              style: TextStyle(color: Color(0xFFE4E2DA), fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FeaturePill(icon: Icons.calendar_today, label: 'Weekly turns'),
                _FeaturePill(icon: Icons.thermostat, label: 'Weather-driven yield'),
                _FeaturePill(icon: Icons.refresh, label: 'Crop rotation'),
                _FeaturePill(icon: Icons.bug_report, label: 'Pest pressure'),
                _FeaturePill(icon: Icons.bolt, label: 'Action budget'),
                _FeaturePill(icon: Icons.trending_up, label: 'Dynamic pricing'),
                _FeaturePill(icon: Icons.history_edu, label: 'Narrative events'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This demo is engine-only — every panel below reads from '
              '`Farm` and `Field` state and calls public methods on the '
              'kit. Drop it into any Flutter / Flame app and render '
              'however you like.',
              style: TextStyle(
                  color: const Color(0xFFE4E2DA).withValues(alpha: 0.85),
                  fontSize: 12,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE4E2DA).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE4E2DA).withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFE4E2DA)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFE4E2DA), fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.turn,
    required this.weather,
    required this.factor,
    required this.season,
    required this.actionsLeft,
    required this.actionsTotal,
  });
  final int turn;
  final String weather;
  final double factor;
  final Season season;
  final int actionsLeft;
  final int actionsTotal;

  IconData _seasonIcon() {
    switch (season) {
      case Season.summer:
        return Icons.wb_sunny;
      case Season.autumn:
        return Icons.eco;
      case Season.winter:
        return Icons.ac_unit;
      case Season.spring:
        return Icons.local_florist;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Week $turn',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Chip(
                  avatar: Icon(_seasonIcon(), size: 16),
                  label: Text(season.name),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.cloud_outlined, size: 16),
                const SizedBox(width: 6),
                Text('Weather:  $weather'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.trending_up, size: 16),
                const SizedBox(width: 6),
                Text(
                    'Growth factor:  ${factor.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.bolt, size: 16, color: Color(0xFFDD923F)),
                const SizedBox(width: 6),
                Text('Actions:  $actionsLeft / $actionsTotal',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.field,
    required this.farm,
    required this.onPlant,
    required this.onHarvest,
    required this.onTreat,
  });
  final Field field;
  final Farm farm;
  final void Function(Crop) onPlant;
  final VoidCallback onHarvest;
  final VoidCallback onTreat;

  String _trendBadge(Crop c) {
    final econ = farm.economy;
    if (econ is! SeasonalDynamicPricing) return '';
    final m = econ.seasonalTrend(c, turn: farm.turn);
    if (m >= 1.10) return ' ↑';
    if (m <= 0.95) return ' ↓';
    return '';
  }

  IconData _stageIcon() {
    switch (field.growthStage) {
      case GrowthStage.empty:
        return Icons.crop_square;
      case GrowthStage.seedling:
        return Icons.eco;
      case GrowthStage.growing:
        return Icons.spa;
      case GrowthStage.ready:
        return Icons.local_florist;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_stageIcon(), size: 20, color: const Color(0xFF2F5243)),
                const SizedBox(width: 8),
                Text(
                  'Field "${field.id}"',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  '${field.soil.name} · size ${field.size}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const Spacer(),
                Chip(
                  label: Text(field.growthStage.name),
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      const Color(0xFF2F5243).withValues(alpha: 0.08),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _StatBar(
              label: 'Fertility',
              value: field.fertility,
              color: _fertilityColor(field.fertility),
            ),
            if (field.crop != null) ...[
              const SizedBox(height: 6),
              _StatBar(
                label: 'Quality',
                value: field.quality,
                color: const Color(0xFFBE5D38),
              ),
              const SizedBox(height: 6),
              _StatBar(
                label: 'Growth',
                value: (field.turnsGrown / field.crop!.turnsToMature)
                    .clamp(0.0, 1.0),
                color: const Color(0xFF2F5243),
              ),
              const SizedBox(height: 6),
              Text('Crop: ${field.crop!.displayName} · '
                  'turns ${field.turnsGrown}/${field.crop!.turnsToMature}'),
            ],
            if (field.lastHarvestedFamily != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.refresh,
                      size: 14, color: Colors.black54),
                  const SizedBox(width: 4),
                  Text(
                    'Last family: ${field.lastHarvestedFamily!.name}'
                    '${field.consecutiveSameFamily > 0 ? '  · streak ${field.consecutiveSameFamily + 1} ⚠' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: field.consecutiveSameFamily > 0
                          ? const Color(0xFFBE5D38)
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
            if (field.pestPressure > 0) ...[
              const SizedBox(height: 6),
              _StatBar(
                label: 'Pests',
                value: field.pestPressure,
                color: field.pestPressure > 0.5
                    ? Colors.red.shade700
                    : Colors.orange.shade700,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...Crop.defaultLibrary.map(
                  (c) => OutlinedButton(
                    onPressed:
                        field.crop == null ? () => onPlant(c) : null,
                    child: Text('Plant ${c.displayName}${_trendBadge(c)}'),
                  ),
                ),
                FilledButton.icon(
                  onPressed: field.crop == null ? null : onHarvest,
                  icon: const Icon(Icons.eco),
                  label: const Text('Harvest'),
                ),
                if (field.pestPressure > 0.2)
                  FilledButton.tonalIcon(
                    onPressed: onTreat,
                    icon: const Icon(Icons.bug_report),
                    label: const Text('Treat'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _fertilityColor(double f) {
    if (f >= 0.7) return const Color(0xFF2F5243);
    if (f >= 0.4) return const Color(0xFFDD923F);
    return const Color(0xFFBE5D38);
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFE4E2DA),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _EventLogCard extends StatelessWidget {
  const _EventLogCard({required this.events});
  final List<FarmEvent> events;

  @override
  Widget build(BuildContext context) {
    final tail = events.length > 6
        ? events.sublist(events.length - 6)
        : events;
    return Card(
      elevation: 0,
      color: const Color(0xFFE4E2DA).withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFF2F5243).withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined,
                    size: 18, color: Color(0xFF2F5243)),
                const SizedBox(width: 6),
                Text('Recent events',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('${events.length} total',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 6),
            ...tail.map(
              (e) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '· ${e.kind.name}'
                  '${e.fieldId != null ? ' (${e.fieldId})' : ''}',
                  style: const TextStyle(
                      fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '© Oksigenia SL · MIT · github.com/OksigeniaSL/oksigenia-farmkit',
        style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.45)),
      ),
    );
  }
}
