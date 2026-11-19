import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import 'settings_page.dart';
import 'walk_detail_page.dart';
import 'widgets.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  Future<void> _logWeight(BuildContext context) async {
    final current = AppState.instance.profile!.weightKg;
    final c = TextEditingController(text: fmtNum(current, 1));
    final v = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text("Today's weight"),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: fieldDeco(context, 'Weight', suffix: 'kg'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = parseNum(c.text);
              if (n != null && n >= 30 && n <= 250) Navigator.pop(d, n);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (v != null) await AppState.instance.logWeight(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'weight',
        onPressed: () => _logWeight(context),
        icon: const Icon(Icons.monitor_weight_outlined),
        label: const Text('Log weight'),
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final s = AppState.instance;
          final p = s.profile!;
          final plan = s.plan!;
          final start = s.weights.isNotEmpty ? s.weights.first.kg : p.weightKg;
          final lost = start - p.weightKg;
          final toGo = (p.weightKg - p.goalKg).clamp(0.0, 500.0);
          final totalToLose = (start - p.goalKg);
          final frac = totalToLose > 0 ? (lost / totalToLose).clamp(0.0, 1.0) : 0.0;

          // Last 7 days summary.
          final now = DateTime.now();
          final days = [
            for (var i = 6; i >= 0; i--)
              dayKey(DateTime(now.year, now.month, now.day - i))
          ];
          final loggedDays = days.where((d) => s.foodOn(d).isNotEmpty).toList();
          final avgEaten = loggedDays.isEmpty
              ? 0.0
              : loggedDays.fold(0.0, (a, d) => a + s.kcalEatenOn(d)) / loggedDays.length;
          final weekKm = days.fold(0.0, (a, d) => a + s.walkMetersOn(d)) / 1000;
          final weekKcal = days.fold(0.0, (a, d) => a + s.walkKcalOn(d));
          final walkDays = days.where((d) => s.walksOn(d).isNotEmpty).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Stat(value: fmtNum(p.weightKg, 1), unit: 'kg', label: 'Now', large: true)),
                      Expanded(child: Stat(value: fmtNum(p.goalKg, 1), unit: 'kg', label: 'Goal')),
                    ]),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: frac.toDouble(),
                        minHeight: 8,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${lost >= 0 ? 'Lost' : 'Gained'} ${fmtNum(lost.abs(), 1)} kg since ${s.weights.isNotEmpty ? fmtDate(parseDayKey(s.weights.first.date)) : 'start'}'
                      '${toGo > 0 ? ' · ${fmtNum(toGo, 1)} kg to go' : ' · Goal reached'}',
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (s.weights.length >= 2) ...[
                const SectionTitle('Weight trend'),
                Panel(
                  child: SizedBox(
                    height: 180,
                    child: CustomPaint(
                      painter: _WeightChart(
                        s.weights,
                        p.goalKg,
                        line: cs.onSurface,
                        grid: cs.outlineVariant,
                        text: cs.onSurfaceVariant,
                        goalColor: cs.tertiary,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ],
              const SectionTitle('Last 7 days'),
              Panel(
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Stat(value: fmtNum(weekKm, 1), unit: 'km', label: 'Walked')),
                    Expanded(child: Stat(value: '$walkDays/7', label: 'Walk days')),
                    Expanded(child: Stat(value: '${weekKcal.round()}', unit: 'kcal', label: 'Burned')),
                  ]),
                  const Divider(height: 28),
                  Row(children: [
                    Expanded(
                      child: Stat(
                          value: loggedDays.isEmpty ? '–' : '${avgEaten.round()}',
                          unit: loggedDays.isEmpty ? null : 'kcal',
                          label: 'Avg eaten per logged day'),
                    ),
                    Expanded(
                      child: Stat(value: '${plan.intakeKcal}', unit: 'kcal', label: 'Daily budget'),
                    ),
                  ]),
                ]),
              ),
              const SectionTitle('Walks'),
              Panel(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Walk history'),
                  subtitle: Text('${s.walks.length} walks recorded'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalkHistoryPage())),
                ),
              ),
              if (s.weights.isNotEmpty) ...[
                const SectionTitle('Weight log'),
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final w in s.weights.reversed.take(30))
                      ListTile(
                        dense: true,
                        title: Text('${fmtNum(w.kg, 1)} kg'),
                        subtitle: Text(fmtDayFull(parseDayKey(w.date))),
                        trailing: s.weights.length > 1
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Delete',
                                onPressed: () => AppState.instance.deleteWeight(w.date),
                              )
                            : null,
                      ),
                  ]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WeightChart extends CustomPainter {
  final List<WeightEntry> data;
  final double goal;
  final Color line, grid, text, goalColor;
  _WeightChart(this.data, this.goal,
      {required this.line,
      required this.grid,
      required this.text,
      required this.goalColor});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0, bottom = 20.0, top = 8.0;
    final w = size.width - left - 8;
    final h = size.height - bottom - top;
    final kgs = data.map((e) => e.kg).toList();
    var lo = math.min(kgs.reduce(math.min), goal) - 1;
    var hi = math.max(kgs.reduce(math.max), goal) + 1;
    if (hi - lo < 4) {
      final mid = (hi + lo) / 2;
      lo = mid - 2;
      hi = mid + 2;
    }
    final t0 = parseDayKey(data.first.date).millisecondsSinceEpoch.toDouble();
    final t1 = parseDayKey(data.last.date).millisecondsSinceEpoch.toDouble();
    final span = math.max(t1 - t0, 1.0);

    double x(String d) =>
        left + (parseDayKey(d).millisecondsSinceEpoch - t0) / span * w;
    double y(double kg) => top + (hi - kg) / (hi - lo) * h;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 3; i++) {
      final kg = lo + (hi - lo) * i / 3;
      final yy = y(kg);
      canvas.drawLine(Offset(left, yy), Offset(left + w, yy), gridPaint);
      tp.text = TextSpan(text: kg.toStringAsFixed(0), style: TextStyle(color: text, fontSize: 11));
      tp.layout();
      tp.paint(canvas, Offset(0, yy - tp.height / 2));
    }

    // Goal line (dashed).
    final gp = Paint()
      ..color = goalColor
      ..strokeWidth = 1.5;
    final gy = y(goal);
    for (var xx = left; xx < left + w; xx += 10) {
      canvas.drawLine(Offset(xx, gy), Offset(math.min(xx + 5, left + w), gy), gp);
    }

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final o = Offset(x(data[i].date), y(data[i].kg));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
    final dot = Paint()..color = line;
    for (final e in data) {
      canvas.drawCircle(Offset(x(e.date), y(e.kg)), 3.5, dot);
    }

    for (final e in [data.first, data.last]) {
      tp.text = TextSpan(
          text: fmtDate(parseDayKey(e.date)),
          style: TextStyle(color: text, fontSize: 11));
      tp.layout();
      final dx = (x(e.date) - tp.width / 2).clamp(left, left + w - tp.width);
      tp.paint(canvas, Offset(dx.toDouble(), size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChart old) => true;
}
