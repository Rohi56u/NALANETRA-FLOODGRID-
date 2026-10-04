import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_store.dart';
import 'config.dart';
import 'models.dart';

class RiskLab extends StatefulWidget {
  const RiskLab({super.key});
  @override
  State<RiskLab> createState() => _LabState();
}

class _LabState extends State<RiskLab> {
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = context
        .read<AppStore>()
        .api
        .get('/api/v1/risk/demo')
        .then((v) => (v as Map).cast<String, dynamic>());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Risk Model Lab')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${snapshot.error ?? "Experiment unavailable"}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(_load),
                    child: const Text('Retry API connection'),
                  ),
                ],
              ),
            ),
          );
        }
        final data = snapshot.data!,
            blocked = records(data['timeline']),
            clear = records(data['clear_drains_timeline']);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: GovColors.navy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SYNTHETIC FIXTURE',
                        style: TextStyle(
                          color: GovColors.gold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${data['horizon_minutes']} minutes · 3 connected storage nodes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['source'] as String,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Blockage and clear-drain comparison',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Same rainfall input; storage-equivalent depth at fixture N1. This is not observed street flood depth.',
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            Text(
                              '● Fixture blockage',
                              style: TextStyle(color: GovColors.orange),
                            ),
                            Text(
                              '● Clear-drain comparison',
                              style: TextStyle(color: GovColors.ok),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 250,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _DepthChart(blocked, clear),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (final node in (blocked.first['depth_m'] as Map).keys)
                  Card(
                    child: ListTile(
                      title: Text('Fixture $node · peak stored depth'),
                      trailing: Text(
                        '${blocked.fold<double>(0, (p, r) => math.max(p, (r['depth_m'][node] as num).toDouble())).toStringAsFixed(3)} m',
                        style: const TextStyle(
                          color: GovColors.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                Card(
                  child: ListTile(
                    title: const Text('Maximum water-balance residual'),
                    subtitle: Text(
                      '${(data['max_balance_error_m3'] as num).toDouble().toStringAsExponential(2)} m³\nNumerical consistency, not forecast accuracy.',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Field validation gates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                for (final item in data['limitations'] as List)
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.science_outlined,
                      color: GovColors.gold,
                    ),
                    title: Text('$item'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => setState(_load),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recompute committed fixture'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _DepthChart extends CustomPainter {
  final List<Map<String, dynamic>> blocked, clear;
  _DepthChart(this.blocked, this.clear);
  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0, top = 12.0, bottom = 34.0;
    final width = size.width - left - 12, height = size.height - top - bottom;
    double depth(Map<String, dynamic> row) =>
        (row['depth_m']['N1'] as num).toDouble();
    final upper =
        math.max(.1, [...blocked, ...clear].map(depth).reduce(math.max)) * 1.15;
    final duration = (blocked.last['minute'] as num).toDouble();
    final grid = Paint()
      ..color = Colors.blueGrey.withValues(alpha: .18)
      ..strokeWidth = 1;
    void label(String text, Offset at) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, at);
    }

    for (var tick = 0; tick <= 4; tick++) {
      final y = top + height - tick * height / 4;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
      label((upper * tick / 4).toStringAsFixed(2), Offset(0, y - 6));
    }
    for (final series in [blocked, clear]) {
      final path = Path();
      for (var index = 0; index < series.length; index++) {
        final row = series[index],
            x = left + (row['minute'] as num).toDouble() / duration * width,
            y = top + height - depth(row) / upper * height;
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = identical(series, blocked) ? GovColors.orange : GovColors.ok
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }
    label('0', Offset(left, size.height - 25));
    label('${duration.toInt()} min', Offset(size.width - 58, size.height - 25));
    label('Stored depth (m)', Offset(left, size.height - 12));
  }

  @override
  bool shouldRepaint(covariant _DepthChart old) =>
      old.blocked != blocked || old.clear != clear;
}
