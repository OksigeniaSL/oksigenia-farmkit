import 'package:flutter/material.dart';
import 'package:oksigenia_farmkit/oksigenia_farmkit.dart';

/// Minimal demo. Shows the kit running headlessly behind a small
/// Material UI: two fields, plant / advance / harvest, current weather
/// label and the per-field state.
///
/// Intentionally without Flame or any rendering library — this file
/// serves as a sanity check that the kit's public API can be driven
/// from a plain Flutter app.
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
  late final Farm farm;
  String _weatherLabel = '—';
  double _weatherFactor = 0.0;

  @override
  void initState() {
    super.initState();
    farm = Farm(
      fields: [
        Field(id: 'north', size: 1.0, soil: SoilType.loam),
        Field(id: 'south', size: 0.5, soil: SoilType.sandy),
      ],
      weather: const MockWeatherProvider.seasonal(),
    );
  }

  void _advance() {
    setState(() {
      _weatherFactor = farm.advanceTurn();
      final w = farm.weather.sample(turn: farm.turn);
      _weatherLabel = '${w.label} · ${w.temperatureC.toStringAsFixed(1)}°C';
    });
  }

  void _plant(String id, Crop crop) {
    setState(() {
      try {
        farm.plant(fieldId: id, crop: crop);
      } on StateError {
        // Field already planted; harmless in demo.
      }
    });
  }

  void _harvest(String id) {
    setState(() {
      farm.harvest(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('oksigenia-farmkit · demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusCard(turn: farm.turn, weather: _weatherLabel, factor: _weatherFactor),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: farm.fields
                    .map((f) => _FieldCard(
                          field: f,
                          onPlant: (c) => _plant(f.id, c),
                          onHarvest: () => _harvest(f.id),
                        ))
                    .toList(),
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
  const _StatusCard({required this.turn, required this.weather, required this.factor});
  final int turn;
  final String weather;
  final double factor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Week $turn', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Weather: $weather'),
            Text('Growth factor: ${factor.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.field, required this.onPlant, required this.onHarvest});
  final Field field;
  final void Function(Crop) onPlant;
  final VoidCallback onHarvest;

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ...Crop.defaultLibrary.map(
                  (c) => OutlinedButton(
                    onPressed: field.crop == null ? () => onPlant(c) : null,
                    child: Text('Plant ${c.displayName}'),
                  ),
                ),
                FilledButton(
                  onPressed: field.crop == null ? null : onHarvest,
                  child: const Text('Harvest'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
