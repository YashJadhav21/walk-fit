import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import '../tracker.dart';
import 'home_shell.dart';
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

  bool _locating = false;
  bool _askedLocation = false;

  @override
  void initState() {
    super.initState();
    tr.addListener(_onTrack);
    tabIndex.addListener(_onTab);
    _centerOnLastKnown();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTab());
  }

  @override
  void dispose() {
    tr.removeListener(_onTrack);
    tabIndex.removeListener(_onTab);
    super.dispose();
  }

  /// When the Walk tab is opened, get a one-time GPS fix to show where
  /// you are (no continuous tracking until Start).
  void _onTab() {
    if (tabIndex.value == 1 && !tr.active && !_askedLocation) {
      _askedLocation = true;
      _locateOnce();
    }
  }

  Future<void> _locateOnce() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await _ensureReady(forWalk: false)) return;
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted && _here == null) {
        setState(() => _here = LatLng(last.latitude, last.longitude));
        _moveTo(_here!, 16);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _here = LatLng(p.latitude, p.longitude);
        _hereAccuracy = p.accuracy;
      });
      _moveTo(_here!, 17);
    } catch (_) {
      if (mounted && _here == null) {
        toast(context, 'Could not get your location. Try again outside.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  double? _hereAccuracy;

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
  Future<bool> _ensureReady({bool forWalk = true}) async {
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
    if (!forWalk) return true;
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
    final top = MediaQuery.of(context).padding.top;
    return ListenableBuilder(
      listenable: tr,
      builder: (context, _) {
        final fix = tr.lastFix;
        final cur = fix != null && tr.active
            ? LatLng(fix.latitude, fix.longitude)
            : _here;
        return Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: cur ?? const LatLng(20.5937, 78.9629),
                  initialZoom: cur != null ? 16 : 4.5,
                  backgroundColor: cs.surfaceContainerHighest,
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onMapReady: () {
                    _mapReady = true;
                    if (cur != null) _moveTo(cur, 16);
                  },
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture && _follow) setState(() => _follow = false);
                  },
                ),
                children: [
                  mapTiles(context),
                  PolylineLayer(
                      polylines: routeLines(tr.points, cs.onSurface, cs.surface)),
                  MarkerLayer(markers: [
                    if (tr.points.isNotEmpty)
                      endMarker(context,
                          LatLng(tr.points.first.lat, tr.points.first.lng),
                          start: true),
                    if (cur != null) meMarker(context, cur),
                  ]),
                ],
              ),
            ),
            // top bar: title + GPS status
            Positioned(
              top: top + 12,
              left: 16,
              right: 16,
              child: Row(children: [
                _Pill(child: Text('Walk', style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(width: 8),
                Flexible(child: _GpsChip(tracker: tr, locating: _locating, here: _hereAccuracy)),
              ]),
            ),
            // bottom: controls
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, right: 4),
                    child: Material(
                      color: cs.surface,
                      shape: const CircleBorder(),
                      elevation: 3,
                      shadowColor: Colors.black26,
                      child: IconButton(
                        tooltip: 'Center on me',
                        iconSize: 22,
                        padding: const EdgeInsets.all(12),
                        onPressed: () {
                          setState(() => _follow = true);
                          if (cur != null) {
                            _moveTo(cur, 17);
                          } else {
                            _locateOnce();
                          }
                        },
                        icon: Icon(
                            _follow ? Icons.my_location : Icons.location_searching,
                            color: cs.onSurface),
                      ),
                    ),
                  ),
                  _ControlCard(
                    tracker: tr,
                    busy: _busy,
                    onStart: _start,
                    onPause: tr.pause,
                    onResume: _resume,
                    onStop: _stop,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 6),
                    child: Text('© OpenStreetMap · CARTO',
                        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({required this.child});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: child,
      ),
    );
  }
}

class _GpsChip extends StatelessWidget {
  final WalkTracker tracker;
  final bool locating;
  final double? here;
  const _GpsChip({required this.tracker, required this.locating, this.here});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String text;
    Color dot;
    if (tracker.error != null) {
      text = tracker.error!;
      dot = cs.error;
    } else if (!tracker.active) {
      if (locating) {
        text = 'Finding you…';
        dot = cs.outline;
      } else if (here != null) {
        text = 'GPS ±${here!.round()} m · not tracking';
        dot = cs.outline;
      } else {
        return const SizedBox.shrink();
      }
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
      text = 'Tracking · ±${tracker.accuracy!.round()} m';
      dot = const Color(0xFF22C55E);
    }
    return _Pill(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData? icon;
  final String? text;
  final String label;
  final double size;
  final bool filled;
  final Color? color;
  final VoidCallback? onTap;
  const _RoundButton({
    this.icon,
    this.text,
    required this.label,
    this.size = 68,
    this.filled = true,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = filled ? (color ?? cs.onSurface) : cs.surfaceContainerHighest;
    final fg = filled ? cs.surface : cs.onSurface;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        color: bg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: text != null
                  ? Text(text!,
                      style: TextStyle(
                          fontFamily: 'InterDisplay',
                          fontSize: size * 0.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: fg))
                  : Icon(icon, color: fg, size: size * 0.4),
            ),
          ),
        ),
      ),
      if (label.isNotEmpty) ...[
        const SizedBox(height: 6),
        Label(label),
      ],
    ]);
  }
}

class _ControlCard extends StatelessWidget {
  final WalkTracker tracker;
  final bool busy;
  final VoidCallback onStart;
  final Future<void> Function() onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  const _ControlCard({
    required this.tracker,
    required this.busy,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tr = tracker;
    final secs = tr.elapsed.inSeconds;

    return Material(
      color: cs.surface,
      elevation: 6,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: tr.active
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Label(tr.status == WalkStatus.running ? 'Time' : 'Paused'),
                  const SizedBox(height: 6),
                  Text(fmtDuration(tr.elapsed), style: numStyle(context, 56, weight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: _Center(Stat(value: fmtKm(tr.distanceM), unit: 'km', label: 'Distance'))),
                    Expanded(child: _Center(Stat(value: '${tr.kcal.round()}', unit: 'kcal', label: 'Active'))),
                    Expanded(child: _Center(Stat(value: fmtPace(tr.distanceM, secs), label: 'Pace /km'))),
                  ]),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _RoundButton(
                      icon: tr.status == WalkStatus.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      label: tr.status == WalkStatus.running ? 'Pause' : 'Resume',
                      filled: tr.status != WalkStatus.running,
                      onTap: tr.status == WalkStatus.running ? () => onPause() : onResume,
                    ),
                    _RoundButton(
                      icon: Icons.stop_rounded,
                      label: 'Finish',
                      color: cs.error,
                      onTap: onStop,
                    ),
                  ]),
                ],
              )
            : Row(children: [
                const Expanded(child: _TodaySummary()),
                const SizedBox(width: 12),
                _RoundButton(
                  text: busy ? '…' : 'START',
                  label: '',
                  size: 92,
                  onTap: busy ? null : onStart,
                ),
              ]),
      ),
    );
  }
}

class _Center extends StatelessWidget {
  final Widget child;
  const _Center(this.child);
  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.center, child: child);
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        final day = dayKey(DateTime.now());
        final goal = s.plan!.walkGoalKcal;
        final burned = s.walkKcalOn(day);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalkHistoryPage())),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Label('Today'),
              const SizedBox(height: 6),
              Text.rich(TextSpan(children: [
                TextSpan(text: fmtKm(s.walkMetersOn(day)), style: numStyle(context, 32)),
                TextSpan(text: ' km', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              ])),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: goal > 0 ? (burned / goal).clamp(0.0, 1.0).toDouble() : 0,
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                burned >= goal
                    ? 'Goal done · ${burned.round()} kcal'
                    : '${burned.round()} of $goal kcal · History ›',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }
}
