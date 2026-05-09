import 'package:flutter/material.dart';
import 'package:oksigenia_farmkit/oksigenia_farmkit.dart';

/// Live demo for `oksigenia-farmkit`. The goal of this app is to
/// exercise every public subsystem of the kit through a small Material
/// UI, so visitors of the GitHub Pages deploy can see what the engine
/// actually does without needing to read tests.
///
/// What this surfaces today:
/// - Weekly turn loop, weather (label + growth factor).
/// - Field state: soil, fertility, rotation streak, growth stage,
///   quality, pest pressure.
/// - Action budget per turn (`actionsPerTurn`).
/// - Narrative events (`Farm.drainEvents` queue) shown as a bottom
///   banner.
/// - Seasonal dynamic pricing — current trend per crop badged on the
///   plant buttons (↑ / ↓ / ·).
/// - Pest treatment action.
///
/// Intentionally engine-only: no Flame, no audio, no sprites. The kit
/// is meant to be embedded into another renderer; this demo is the
/// reference for "what the API gives you for free".
void main() {
  runApp(const _ExampleApp());
}

class _ExampleApp extends StatelessWidget {
  const _ExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'oksigenia-farmkit demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
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
      // 3 actions/week. Plant + treat + harvest can't all happen the
      // same turn — the player has to prioritise.
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
        _flash('No actions left this turn.');
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
        _flash('No actions left this turn.');
      }
      _drainEvents();
    });
  }

  void _treat(String id) {
    setState(() {
      try {
        farm.treat(id);
      } on OutOfActionsError {
        _flash('No actions left this turn.');
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
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset',
            onPressed: _restart,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusCard(
              turn: farm.turn,
              weather: _weatherLabel,
              factor: _weatherFactor,
              season: season,
              actionsLeft: actionsLeft,
              actionsTotal: actionsTotal,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  ...farm.fields.map((f) => _FieldCard(
                        field: f,
                        farm: farm,
                        onPlant: (c) => _plant(f.id, c),
                        onHarvest: () => _harvest(f.id),
                        onTreat: () => _treat(f.id),
                      )),
                  if (_eventLog.isNotEmpty) _EventLogCard(events: _eventLog),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _advance,
              icon: const Icon(Icons.skip_next),
              label: const Text('Advance one week'),
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Week $turn',
                    style: Theme.of(context).textTheme.titleLarge),
                Chip(
                  label: Text('Season: ${season.name}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Weather: $weather'),
            Text('Growth factor: ${factor.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.bolt, size: 16),
                const SizedBox(width: 4),
                Text('Actions: $actionsLeft / $actionsTotal'),
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

  @override
  Widget build(BuildContext context) {
    final pestColor = field.pestPressure > 0.5
        ? Colors.red
        : field.pestPressure > 0.2
            ? Colors.orange
            : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Field "${field.id}" — ${field.soil.name}, size ${field.size}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Stage: ${field.growthStage.name}'),
            Text('Turns grown: ${field.turnsGrown}'),
            Text('Quality: ${field.quality.toStringAsFixed(2)}'),
            Text('Fertility: ${field.fertility.toStringAsFixed(2)}'),
            if (field.lastHarvestedFamily != null)
              Text(
                'Last family: ${field.lastHarvestedFamily!.name}'
                '${field.consecutiveSameFamily > 0 ? '  (streak ${field.consecutiveSameFamily + 1})' : ''}',
                style: TextStyle(
                  color: field.consecutiveSameFamily > 0
                      ? Colors.deepOrange
                      : null,
                ),
              ),
            if (field.pestPressure > 0)
              Text(
                'Pest pressure: ${field.pestPressure.toStringAsFixed(2)}',
                style: TextStyle(color: pestColor),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...Crop.defaultLibrary.map(
                  (c) => OutlinedButton(
                    onPressed: field.crop == null ? () => onPlant(c) : null,
                    child: Text('Plant ${c.displayName}${_trendBadge(c)}'),
                  ),
                ),
                FilledButton(
                  onPressed: field.crop == null ? null : onHarvest,
                  child: const Text('Harvest'),
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
}

class _EventLogCard extends StatelessWidget {
  const _EventLogCard({required this.events});
  final List<FarmEvent> events;

  @override
  Widget build(BuildContext context) {
    // Show only the most recent 6 entries; older drift off the top.
    final tail = events.length > 6
        ? events.sublist(events.length - 6)
        : events;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined, size: 18),
                const SizedBox(width: 6),
                Text('Recent events',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            ...tail.map(
              (e) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '· ${e.kind.name}'
                  '${e.fieldId != null ? ' (${e.fieldId})' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
