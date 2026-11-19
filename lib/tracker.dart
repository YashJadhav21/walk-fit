import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'calc.dart';
import 'models.dart';
import 'storage.dart';

enum WalkStatus { idle, running, paused }

/// Records a walk. GPS (and the Android foreground service that keeps it
/// alive with the screen off) runs ONLY between Start/Resume and
/// Pause/Stop. Nothing runs in the background otherwise.
///
/// Distance uses WGS-84 latitude/longitude from the GPS and the geodesic
/// distance between consecutive fixes. Noise handling:
///  * fixes with poor accuracy (> 25 m) are ignored;
///  * a new point is accepted only after moving more than about half the
///    GPS accuracy (3–10 m), so standing still does not add "jitter" distance;
///  * jumps faster than 25 km/h are rejected as GPS glitches.
class WalkTracker extends ChangeNotifier {
  WalkTracker._();
  static final WalkTracker instance = WalkTracker._();

  static const _maxAccuracyM = 25.0;
  static const _maxSpeedKmh = 25.0;

  WalkStatus status = WalkStatus.idle;
  final List<TrackPoint> points = [];
  double distanceM = 0;
  double kcal = 0;
  DateTime? startedAt;
  Duration _elapsedBefore = Duration.zero;
  DateTime? _runningSince;
  int _seg = 0;

  Position? lastFix; // latest fix, even if rejected (for the map/GPS badge)
  String? error;

  double weightKg = 80;

  TrackPoint? _anchor;
  int _glitches = 0;
  StreamSubscription<Position>? _sub;
  Timer? _ticker;

  bool get active => status != WalkStatus.idle;

  Duration get elapsed => _elapsedBefore +
      (_runningSince != null
          ? DateTime.now().difference(_runningSince!)
          : Duration.zero);

  double? get accuracy => lastFix?.accuracy;
  bool get gpsGood => lastFix != null && lastFix!.accuracy <= _maxAccuracyM;

  LocationSettings get _settings => AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 2,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Walk in progress',
          notificationText:
              'Tracking distance and calories. Open WalkFit to pause or stop.',
          notificationChannelName: 'Walk tracking',
          notificationIcon:
              AndroidResource(name: 'ic_stat_walk', defType: 'drawable'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );

  Future<void> start(double weight) async {
    if (active) return;
    weightKg = weight;
    points.clear();
    distanceM = 0;
    kcal = 0;
    _seg = 0;
    _elapsedBefore = Duration.zero;
    startedAt = DateTime.now();
    error = null;
    await _beginStream();
  }

  Future<void> resume() async {
    if (status != WalkStatus.paused) return;
    _seg++;
    error = null;
    await _beginStream();
  }

  Future<void> _beginStream() async {
    _anchor = null;
    _glitches = 0;
    _runningSince = DateTime.now();
    status = WalkStatus.running;
    _sub = Geolocator.getPositionStream(locationSettings: _settings).listen(
      _onPosition,
      onError: (Object e) {
        error = e is LocationServiceDisabledException
            ? 'Location is turned off. Turn it on to keep tracking.'
            : 'GPS error: $e';
        notifyListeners();
      },
    );
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    notifyListeners();
  }

  Future<void> pause() async {
    if (status != WalkStatus.running) return;
    await _endStream();
    status = WalkStatus.paused;
    await _persist();
    notifyListeners();
  }

  Future<void> _endStream() async {
    await _sub?.cancel(); // stops GPS and the foreground service
    _sub = null;
    _ticker?.cancel();
    _ticker = null;
    if (_runningSince != null) {
      _elapsedBefore += DateTime.now().difference(_runningSince!);
      _runningSince = null;
    }
  }

  /// Ends the walk and returns the record (not yet saved).
  Future<WalkRecord?> stop() async {
    if (!active) return null;
    await _endStream();
    final rec = WalkRecord(
      id: 'w${startedAt!.millisecondsSinceEpoch}',
      start: startedAt!,
      end: DateTime.now(),
      durationSec: _elapsedBefore.inSeconds,
      distanceM: distanceM,
      kcal: kcal,
      points: List.of(points),
    );
    _reset();
    await Store.delete('active_walk.json');
    notifyListeners();
    return rec;
  }

  Future<void> discard() async {
    await _endStream();
    _reset();
    await Store.delete('active_walk.json');
    notifyListeners();
  }

  void _reset() {
    status = WalkStatus.idle;
    points.clear();
    distanceM = 0;
    kcal = 0;
    startedAt = null;
    _elapsedBefore = Duration.zero;
    _runningSince = null;
    _anchor = null;
    error = null;
  }

  void _onPosition(Position p) {
    lastFix = p;
    if (error != null) error = null;
    if (status != WalkStatus.running) return;
    if (p.accuracy > _maxAccuracyM) {
      notifyListeners();
      return;
    }
    final t = p.timestamp.millisecondsSinceEpoch;
    final pt = TrackPoint(p.latitude, p.longitude, t, _seg);

    final a = _anchor;
    if (a == null) {
      _anchor = pt;
      points.add(pt);
      notifyListeners();
      return;
    }
    final d = Geolocator.distanceBetween(a.lat, a.lng, pt.lat, pt.lng);
    final dt = (t - a.t) / 1000.0;
    if (dt <= 0) return;
    final minStep = (p.accuracy * 0.5).clamp(3.0, 10.0);
    if (d < minStep) {
      notifyListeners();
      return;
    }
    final kmh = d / dt * 3.6;
    if (kmh > _maxSpeedKmh) {
      // Probably a GPS jump. If it keeps happening we have really moved
      // (e.g. got into a vehicle): re-anchor without adding distance.
      if (++_glitches >= 3) {
        _anchor = pt;
        _glitches = 0;
      }
      return;
    }
    _glitches = 0;
    distanceM += d;
    kcal += activeKcal(kmh, dt, weightKg);
    points.add(pt);
    _anchor = pt;
    if (points.length % 15 == 0) _persist();
    notifyListeners();
  }

  // ---------- crash safety ----------
  Future<void> _persist() async {
    if (startedAt == null) return;
    await Store.write('active_walk.json', {
      'startedAt': startedAt!.millisecondsSinceEpoch,
      'elapsedMs': elapsed.inMilliseconds,
      'distanceM': distanceM,
      'kcal': kcal,
      'seg': _seg,
      'weightKg': weightKg,
      'points': points.map((e) => e.toJson()).toList(),
    });
  }

  /// If the app was closed during a walk, bring it back as paused.
  Future<bool> restore() async {
    final j = await Store.read('active_walk.json');
    if (j is! Map<String, dynamic>) return false;
    try {
      startedAt = DateTime.fromMillisecondsSinceEpoch((j['startedAt'] as num).toInt());
      _elapsedBefore = Duration(milliseconds: (j['elapsedMs'] as num).toInt());
      distanceM = (j['distanceM'] as num).toDouble();
      kcal = (j['kcal'] as num).toDouble();
      _seg = (j['seg'] as num).toInt();
      weightKg = (j['weightKg'] as num?)?.toDouble() ?? weightKg;
      points
        ..clear()
        ..addAll((j['points'] as List)
            .whereType<List<dynamic>>()
            .map(TrackPoint.fromJson));
      status = WalkStatus.paused;
      notifyListeners();
      return true;
    } catch (_) {
      await Store.delete('active_walk.json');
      return false;
    }
  }
}
