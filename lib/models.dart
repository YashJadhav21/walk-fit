// Data models. Everything is stored locally on the phone as JSON.

double _d(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;
int _i(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

class Profile {
  String name;
  String sex; // 'male' | 'female'
  int age;
  double heightCm;
  double weightKg;
  double goalKg;
  int activity; // index into activityLevels
  double paceKgPerWeek;
  int walkGoalKcal;

  Profile({
    required this.name,
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.goalKg,
    required this.activity,
    required this.paceKgPerWeek,
    required this.walkGoalKcal,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'sex': sex,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'goalKg': goalKg,
        'activity': activity,
        'pace': paceKgPerWeek,
        'walkGoalKcal': walkGoalKcal,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: (j['name'] ?? '') as String,
        sex: (j['sex'] ?? 'male') as String,
        age: _i(j['age'], 30),
        heightCm: _d(j['heightCm'], 170),
        weightKg: _d(j['weightKg'], 80),
        goalKg: _d(j['goalKg'], 70),
        activity: _i(j['activity'], 0),
        paceKgPerWeek: _d(j['pace'], 0.5),
        walkGoalKcal: _i(j['walkGoalKcal'], 200),
      );
}

/// One GPS point of a walk. [seg] changes after every pause so the map
/// does not draw a straight line across a paused gap.
class TrackPoint {
  final double lat;
  final double lng;
  final int t; // epoch millis
  final int seg;
  const TrackPoint(this.lat, this.lng, this.t, this.seg);

  List<dynamic> toJson() => [
        double.parse(lat.toStringAsFixed(6)),
        double.parse(lng.toStringAsFixed(6)),
        t,
        seg,
      ];

  factory TrackPoint.fromJson(List<dynamic> a) =>
      TrackPoint(_d(a[0]), _d(a[1]), _i(a[2]), a.length > 3 ? _i(a[3]) : 0);
}

class WalkRecord {
  final String id;
  final DateTime start;
  final DateTime end;
  final int durationSec; // moving clock, pauses excluded
  final double distanceM;
  final double kcal; // active calories (above resting)
  final List<TrackPoint> points;

  WalkRecord({
    required this.id,
    required this.start,
    required this.end,
    required this.durationSec,
    required this.distanceM,
    required this.kcal,
    this.points = const [],
  });

  double get avgSpeedKmh =>
      durationSec > 0 ? (distanceM / 1000) / (durationSec / 3600) : 0;

  /// Summary only (route stored in its own file).
  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'durationSec': durationSec,
        'distanceM': distanceM,
        'kcal': kcal,
      };

  factory WalkRecord.fromJson(Map<String, dynamic> j,
          [List<TrackPoint> points = const []]) =>
      WalkRecord(
        id: j['id'] as String,
        start: DateTime.fromMillisecondsSinceEpoch(_i(j['start'])),
        end: DateTime.fromMillisecondsSinceEpoch(_i(j['end'])),
        durationSec: _i(j['durationSec']),
        distanceM: _d(j['distanceM']),
        kcal: _d(j['kcal']),
        points: points,
      );
}

class FoodItem {
  final String id;
  final String name;
  final String serving; // e.g. "1 medium (40 g)"
  final double kcal; // per serving
  final double protein; // grams per serving
  final String category;
  final bool custom;

  const FoodItem(this.id, this.name, this.serving, this.kcal, this.protein,
      this.category,
      {this.custom = false});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serving': serving,
        'kcal': kcal,
        'protein': protein,
        'category': category,
      };

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        j['id'] as String,
        j['name'] as String,
        (j['serving'] ?? '1 serving') as String,
        _d(j['kcal']),
        _d(j['protein']),
        (j['category'] ?? 'My foods') as String,
        custom: true,
      );
}

const meals = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];

class FoodEntry {
  final String id;
  final String date; // yyyy-mm-dd
  final String meal;
  final String foodId;
  final String name;
  final String serving;
  final double qty; // number of servings
  final double kcalPerServing;
  final double proteinPerServing;

  FoodEntry({
    required this.id,
    required this.date,
    required this.meal,
    required this.foodId,
    required this.name,
    required this.serving,
    required this.qty,
    required this.kcalPerServing,
    required this.proteinPerServing,
  });

  double get kcal => kcalPerServing * qty;
  double get protein => proteinPerServing * qty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'meal': meal,
        'foodId': foodId,
        'name': name,
        'serving': serving,
        'qty': qty,
        'kcal': kcalPerServing,
        'protein': proteinPerServing,
      };

  factory FoodEntry.fromJson(Map<String, dynamic> j) => FoodEntry(
        id: j['id'] as String,
        date: j['date'] as String,
        meal: (j['meal'] ?? 'Snacks') as String,
        foodId: (j['foodId'] ?? '') as String,
        name: j['name'] as String,
        serving: (j['serving'] ?? '') as String,
        qty: _d(j['qty'], 1),
        kcalPerServing: _d(j['kcal']),
        proteinPerServing: _d(j['protein']),
      );
}

class WeightEntry {
  final String date; // yyyy-mm-dd, one entry per day
  final double kg;
  const WeightEntry(this.date, this.kg);

  Map<String, dynamic> toJson() => {'date': date, 'kg': kg};
  factory WeightEntry.fromJson(Map<String, dynamic> j) =>
      WeightEntry(j['date'] as String, _d(j['kg']));
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}
