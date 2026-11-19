import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import '../tracker.dart';
import 'route_map.dart';
import 'walk_detail_page.dart';
import 'widgets.dart';

class WalkPage extends StatefulWidget {
  const WalkPage({super.key});

  @override
  State<WalkPage> createState() => _WalkPageState();
}

class _WalkPageState extends State<WalkPage> {
  final _map = MapController();
  bool _mapReady = false;
  bool _follow = true;
  LatLng? _here; // shown before a walk starts
  int _lastPointCount = 0;
  bool _busy = false;

  WalkTracker get tr => WalkTracker.instance;

  @override
  void initState() {
    super.initState();
    tr.addListener(_onTrack);
    _centerOnLastKnown();
  }

  @override
  void dispose() {
    tr.removeListener(_onTrack);
    super.dispose();
  }

  Future<void> _centerOnLastKnown() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return;
      }
      final p = await Geolocator.getLastKnownPosition();
      if (p != null && mounted) {
        setState(() => _here = LatLng(p.latitude, p.longitude));
        _moveTo(_here!, 16);
      }
    } catch (_) {}
  }

  void _moveTo(LatLng at, [double? zoom]) {
    if (!_mapReady) return;
    _map.move(at, zoom ?? _map.camera.zoom);
  }

  void _onTrack() {
    final fix = tr.lastFix;
    if (fix == null || !_mapReady) return;
    final at = LatLng(fix.latitude, fix.longitude);
    if (tr.status == WalkStatus.running && _follow &&
        tr.points.length != _lastPointCount) {
      _lastPointCount = tr.points.length;
      _moveTo(at, _map.camera.zoom < 15 ? 17 : null);
    }
  }

  // ---------- permissions ----------
  Future<bool> _ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return false;
      final ok = await confirm(context, 'Turn on location',
          'GPS is off. Turn on location to track your walk.',
          ok: 'Open settings');
      if (ok) await Geolocator.openLocationSettings();
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (!mounted) return false;
      final ok = await confirm(context, 'Location permission needed',
          'Allow location for WalkFit in Settings → Permissions → Location → '
              '"Allow only while using the app" and turn on "Use precise location".',
          ok: 'Open settings');
      if (ok) await Geolocator.openAppSettings();
      return false;
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.unableToDetermine) {
      return false;
    }
    try {
      final acc = await Geolocator.getLocationAccuracy();
      if (acc == LocationAccuracyStatus.reduced && mounted) {
        final fix = await confirm(
          context,
          'Precise location is off',
          'With approximate location, distance and calories will be wrong. '
              'Turn on "Use precise location" for WalkFit.',
          ok: 'Open settings',
        );
        if (fix) {
          await Geolocator.openAppSettings();
          return false;
        }
      }
    } catch (_) {}
    // Android 13+: needed to show the "Walk in progress" notification.
    try {
      if (await ph.Permission.notification.isDenied) {
        await ph.Permission.notification.request();
      }
    } catch (_) {}
    return true;
  }

  // ---------- actions ----------
  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await _ensureReady()) return;
      _follow = true;
      _lastPointCount = 0;
      await tr.start(AppState.instance.profile!.weightKg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resume() async {
    if (!await _ensureReady()) return;
    _follow = true;
    await tr.resume();
  }

  Future<void> _stop() async {
    final wasRunning = tr.status == WalkStatus.running;
    if (wasRunning) await tr.pause();
    if (!mounted) return;

    if (tr.distanceM < 50) {
      final choice = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Very short walk'),
          content: Text(
              'Only ${tr.distanceM.round()} m recorded. Save it anyway?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, 'continue'),
                child: const Text('Keep walking')),
            TextButton(
                onPressed: () => Navigator.pop(c, 'discard'),
                child: const Text('Discard')),
            FilledButton(
                onPressed: () => Navigator.pop(c, 'save'),
                child: const Text('Save')),
          ],
        ),
      );
      if (choice == 'discard') {
        await tr.discard();
        return;
      }
      if (choice != 'save') {
        if (wasRunning) await tr.resume();
        return;
      }
    } else {
      final ok = await confirm(context, 'Finish walk?',
          '${fmtKm(tr.distanceM)} km in ${fmtDuration(tr.elapsed)}. GPS tracking will stop.',
          ok: 'Finish');
      if (!ok) {
        if (wasRunning) await tr.resume();
        return;
      }
    }
    final rec = await tr.stop();
    if (rec == null) return;
    await AppState.instance.addWalk(rec);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WalkDetailPage(walk: rec, justFinished: true)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: tr,
      builder: (context, _) {
        final fix = tr.lastFix;
        final cur = fix != null ? LatLng(fix.latitude, fix.longitude) : _here;
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: cur ?? const LatLng(20.5937, 78.9629),
                      initialZoom: cur != null ? 16 : 4,
                      interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                      onMapReady: () {
                        _mapReady = true;
                        if (cur != null) _moveTo(cur, 16);
                      },
                      onPositionChanged: (camera, hasGesture) {
                        if (hasGesture && _follow && tr.active) {
                          setState(() => _follow = false);
                        }
                      },
                    ),
                    children: [
                      osmTiles(),
                      PolylineLayer(polylines: routeLines(tr.points, cs.primary)),
                      MarkerLayer(markers: [
                        if (tr.points.isNotEmpty)
                          dotMarker(LatLng(tr.points.first.lat, tr.points.first.lng),
                              Colors.green.shade600,
                              size: 14),
                        if (cur != null) dotMarker(cur, Colors.blue.shade600),
                      ]),
                      osmAttribution(),
                    ],
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 12,
                    child: _GpsChip(tracker: tr),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 28,
                    child: FloatingActionButton.small(
                      heroTag: 'locate',
                      tooltip: 'Center on me',
                      onPressed: () async {
                        setState(() => _follow = true);
                        if (cur != null) {
                          _moveTo(cur, 17);
                        } else if (await _ensureReady()) {
                          try {
                            final p = await Geolocator.getCurrentPosition(
                                locationSettings: const LocationSettings(
                                    accuracy: LocationAccuracy.high));
                            if (!mounted) return;
                            setState(() => _here = LatLng(p.latitude, p.longitude));
                            _moveTo(_here!, 17);
                          } catch (_) {}
                        }
                      },
                      child: Icon(_follow ? Icons.my_location : Icons.location_searching),
                    ),
                  ),
                ],
              ),
            ),
            _ControlPanel(
              tracker: tr,
              busy: _busy,
              onStart: _start,
              onPause: tr.pause,
              onResume: _resume,
              onStop: _stop,
            ),
          ],
        );
      },
    );
  }
}

class _GpsChip extends StatelessWidget {
  final WalkTracker tracker;
  const _GpsChip({required this.tracker});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!tracker.active) return const SizedBox.shrink();
    String text;
    Color dot;
    if (tracker.error != null) {
      text = tracker.error!;
      dot = cs.error;
    } else if (tracker.status == WalkStatus.paused) {
      text = 'Paused · GPS off';
      dot = cs.outline;
    } else if (tracker.lastFix == null) {
      text = 'Finding GPS…';
      dot = Colors.orange;
    } else if (!tracker.gpsGood) {
      text = 'Weak GPS ±${tracker.accuracy!.round()} m';
      dot = Colors.orange;
    } else {
      text = 'GPS ±${tracker.accuracy!.round()} m';
      dot = Colors.green;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 90),
      child: Material(
        color: cs.surface,
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text,
                  style: Theme.of(context).textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final WalkTracker tracker;
  final bool busy;
  final VoidCallback onStart;
  final Future<void> Function() onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  const _ControlPanel({
    required this.tracker,
    required this.busy,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tr = tracker;
    final secs = tr.elapsed.inSeconds;
    final kmh = secs > 0 ? (tr.distanceM / 1000) / (secs / 3600) : 0.0;

    return Material(
      color: cs.surface,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tr.active) ...[
              Text(fmtDuration(tr.elapsed),
                  style: t.displayMedium?.copyWith(
                      fontWeight: FontWeight.w600, fontFeatures: tabular)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Stat(value: fmtKm(tr.distanceM), unit: 'km', label: 'Distance')),
                Expanded(child: Stat(value: '${tr.kcal.round()}', unit: 'kcal', label: 'Active calories')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Stat(value: fmtPace(tr.distanceM, secs), unit: '/km', label: 'Avg pace')),
                Expanded(child: Stat(value: kmh.toStringAsFixed(1), unit: 'km/h', label: 'Avg speed')),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: tr.status == WalkStatus.running ? () => onPause() : onResume,
                    icon: Icon(tr.status == WalkStatus.running ? Icons.pause : Icons.play_arrow),
                    label: Text(tr.status == WalkStatus.running ? 'Pause' : 'Resume'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                    ),
                    onPressed: onStop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ),
              ]),
            ] else ...[
              _LastWalk(),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: busy ? null : onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start walk'),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('GPS runs only between Start and Stop.',
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LastWalk extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        final day = dayKey(DateTime.now());
        final today = s.walksOn(day);
        final goal = s.plan!.walkGoalKcal;
        final burned = s.walkKcalOn(day);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalkHistoryPage())),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      today.isEmpty
                          ? 'No walk yet today'
                          : '${today.length} walk${today.length > 1 ? 's' : ''} today · ${fmtKm(s.walkMetersOn(day))} km',
                      style: t.titleMedium,
                    ),
                    Text(
                      burned >= goal
                          ? 'Walking goal done (${burned.round()} kcal)'
                          : '${(goal - burned).round()} kcal left to your $goal kcal goal',
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text('History', style: t.labelLarge?.copyWith(color: cs.primary)),
              Icon(Icons.chevron_right, color: cs.primary),
            ]),
          ),
        );
      },
    );
  }
}
