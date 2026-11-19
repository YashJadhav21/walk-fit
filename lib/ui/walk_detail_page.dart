import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import 'route_map.dart';
import 'widgets.dart';

class WalkDetailPage extends StatefulWidget {
  final WalkRecord walk;
  final bool justFinished;
  const WalkDetailPage({super.key, required this.walk, this.justFinished = false});

  @override
  State<WalkDetailPage> createState() => _WalkDetailPageState();
}

class _WalkDetailPageState extends State<WalkDetailPage> {
  List<TrackPoint>? _points;

  @override
  void initState() {
    super.initState();
    if (widget.walk.points.isNotEmpty) {
      _points = widget.walk.points;
    } else {
      AppState.instance.loadRoute(widget.walk.id).then((p) {
        if (mounted) setState(() => _points = p);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.walk;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.justFinished ? 'Walk saved' : fmtDayFull(w.start)),
        actions: [
          IconButton(
            tooltip: 'Delete walk',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final nav = Navigator.of(context);
              final ok = await confirm(context, 'Delete this walk?',
                  'Its distance and calories will be removed.',
                  ok: 'Delete', destructive: true);
              if (!ok) return;
              await AppState.instance.deleteWalk(w.id);
              nav.pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 300,
              child: _points == null
                  ? const Center(child: CircularProgressIndicator())
                  : RoutePreview(points: _points!),
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(children: [
              Row(children: [
                Expanded(child: Stat(value: fmtKm(w.distanceM), unit: 'km', label: 'Distance', large: true)),
                Expanded(child: Stat(value: '${w.kcal.round()}', unit: 'kcal', label: 'Active calories', large: true)),
              ]),
              const Divider(height: 28),
              Row(children: [
                Expanded(child: Stat(value: fmtDuration(Duration(seconds: w.durationSec)), label: 'Moving time')),
                Expanded(child: Stat(value: fmtPace(w.distanceM, w.durationSec), unit: '/km', label: 'Avg pace')),
                Expanded(child: Stat(value: w.avgSpeedKmh.toStringAsFixed(1), unit: 'km/h', label: 'Avg speed')),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Text(
            '${fmtTime(w.start)} – ${fmtTime(w.end)}. Active calories count only the energy above resting, '
            'based on your speed and weight.',
            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (widget.justFinished) ...[
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ],
      ),
    );
  }
}

class WalkHistoryPage extends StatelessWidget {
  const WalkHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Walk history')),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final walks = AppState.instance.walks;
          if (walks.isEmpty) {
            return Center(
              child: Text('Your walks will show up here.',
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            );
          }
          final totalM = walks.fold(0.0, (s, w) => s + w.distanceM);
          final totalK = walks.fold(0.0, (s, w) => s + w.kcal);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Panel(
                child: Row(children: [
                  Expanded(child: Stat(value: '${walks.length}', label: 'Walks')),
                  Expanded(child: Stat(value: fmtNum(totalM / 1000, 1), unit: 'km', label: 'Total')),
                  Expanded(child: Stat(value: '${totalK.round()}', unit: 'kcal', label: 'Burned')),
                ]),
              ),
              const SizedBox(height: 8),
              for (final w in walks)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Icon(Icons.directions_walk, color: cs.onPrimaryContainer),
                  ),
                  title: Text('${fmtKm(w.distanceM)} km · ${w.kcal.round()} kcal'),
                  subtitle: Text(
                      '${fmtDayFull(w.start)}, ${fmtTime(w.start)} · ${fmtDurationShort(w.durationSec)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => WalkDetailPage(walk: w))),
                ),
            ],
          );
        },
      ),
    );
  }
}
