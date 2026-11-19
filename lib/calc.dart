import 'models.dart';

/// Energy maths used across the app.
///
/// * BMR: Mifflin–St Jeor equation.
/// * Daily energy (TDEE): BMR x activity factor. The activity level describes
///   the day *without* the walks, because walks are tracked and counted
///   separately.
/// * 1 kg of body fat is taken as ~7700 kcal.
/// * Walking calories: MET values from the Compendium of Physical Activities,
///   interpolated by speed. The app counts *active* calories
///   ((MET - 1) x kg x hours), i.e. only the energy above what you would
///   burn resting anyway, so nothing is counted twice with the TDEE.

class ActivityLevel {
  final String title;
  final String detail;
  final double factor;
  const ActivityLevel(this.title, this.detail, this.factor);
}

const activityLevels = [
  ActivityLevel('Mostly sitting', 'Desk job, little movement', 1.2),
  ActivityLevel('Lightly active', 'On your feet part of the day', 1.375),
  ActivityLevel('Active', 'Physical job or workouts 3–5 days', 1.55),
  ActivityLevel('Very active', 'Hard physical work most days', 1.725),
];

const paceOptions = [0.25, 0.5, 0.75, 1.0];

double bmr(Profile p) {
  final base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age;
  return p.sex == 'female' ? base - 161 : base + 5;
}

double tdee(Profile p) =>
    bmr(p) * activityLevels[p.activity.clamp(0, activityLevels.length - 1)].factor;

bool wantsToLose(Profile p) => p.goalKg < p.weightKg - 0.05;

double minIntake(Profile p) => p.sex == 'female' ? 1200 : 1500;

double bmi(Profile p) {
  final m = p.heightCm / 100;
  return m > 0 ? p.weightKg / (m * m) : 0;
}

String bmiLabel(double b) {
  if (b < 18.5) return 'Underweight';
  if (b < 25) return 'Healthy';
  if (b < 30) return 'Overweight';
  return 'Obese';
}

class Plan {
  final double bmr;
  final double tdee;
  final double dailyDeficit; // total target deficit (food + walking)
  final int intakeKcal; // eat this much
  final int walkGoalKcal; // burn this much walking (active kcal)
  final int proteinG;
  final double weeksToGoal;
  final bool intakeFloored; // intake was raised to the safe minimum
  final double paceUsed;

  const Plan({
    required this.bmr,
    required this.tdee,
    required this.dailyDeficit,
    required this.intakeKcal,
    required this.walkGoalKcal,
    required this.proteinG,
    required this.weeksToGoal,
    required this.intakeFloored,
    required this.paceUsed,
  });
}

/// Suggested daily walking goal for a pace: about a third of the deficit,
/// kept between 150 and 400 kcal.
int suggestedWalkGoal(Profile p) {
  if (!wantsToLose(p)) return 150;
  final deficit = p.paceKgPerWeek * 7700 / 7;
  final v = (deficit * 0.35).clamp(150, 400);
  return (v / 10).round() * 10;
}

Plan computePlan(Profile p) {
  final b = bmr(p);
  final t = tdee(p);
  final lose = wantsToLose(p);
  final deficit = lose ? p.paceKgPerWeek * 7700 / 7 : 0.0;
  final walk = p.walkGoalKcal.toDouble();
  final double foodDeficit =
      (deficit - walk).clamp(0.0, double.infinity).toDouble();
  double intake = t - foodDeficit;
  var floored = false;
  if (intake < minIntake(p)) {
    intake = minIntake(p);
    floored = true;
  }
  final double actualDeficit = (t - intake) + walk;
  final double weeks = lose && actualDeficit > 0
      ? (p.weightKg - p.goalKg) * 7700 / (actualDeficit * 7)
      : 0.0;
  final refKg = p.goalKg < p.weightKg ? p.goalKg : p.weightKg;
  return Plan(
    bmr: b,
    tdee: t,
    dailyDeficit: lose ? actualDeficit : 0,
    intakeKcal: (intake / 10).round() * 10,
    walkGoalKcal: p.walkGoalKcal,
    proteinG: (refKg * 1.2).round(),
    weeksToGoal: weeks,
    intakeFloored: floored,
    paceUsed: lose ? actualDeficit * 7 / 7700 : 0,
  );
}

// Speed (km/h) -> gross MET, Compendium of Physical Activities.
const _metTable = <List<double>>[
  [0.0, 1.0],
  [1.0, 1.3],
  [3.2, 2.8],
  [4.0, 3.0],
  [4.8, 3.5],
  [5.6, 4.3],
  [6.4, 5.0],
  [7.2, 7.0],
  [8.0, 8.3],
  [9.7, 9.8],
  [11.3, 11.0],
  [12.9, 11.8],
];

double metForSpeed(double kmh) {
  if (kmh <= 0) return 1.0;
  for (var i = 1; i < _metTable.length; i++) {
    final a = _metTable[i - 1], b = _metTable[i];
    if (kmh <= b[0]) {
      final f = (kmh - a[0]) / (b[0] - a[0]);
      return a[1] + f * (b[1] - a[1]);
    }
  }
  return _metTable.last[1];
}

/// Active kcal for covering a stretch at [kmh] for [seconds].
double activeKcal(double kmh, double seconds, double weightKg) {
  if (kmh < 1.0) return 0; // standing still
  final net = metForSpeed(kmh) - 1.0;
  return net * weightKg * seconds / 3600.0;
}

/// Minutes of walking at 5 km/h needed for [kcal] active calories.
double minutesForKcal(double kcal, double weightKg) {
  final perHour = (metForSpeed(5.0) - 1.0) * weightKg;
  return perHour > 0 ? kcal / perHour * 60 : 0;
}

// ---------- formatting ----------

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String fmtDurationShort(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '$m min';
  return '$seconds s';
}

String fmtKm(double meters) => (meters / 1000).toStringAsFixed(2);

/// Pace in min/km, e.g. "11:30".
String fmtPace(double meters, int seconds) {
  if (meters < 30 || seconds <= 0) return '--:--';
  final secPerKm = seconds / (meters / 1000);
  if (secPerKm > 3600) return '--:--';
  final m = secPerKm ~/ 60;
  final s = (secPerKm % 60).round().toString().padLeft(2, '0');
  return '$m:$s';
}

String fmtNum(double v, [int decimals = 0]) {
  final s = v.toStringAsFixed(decimals);
  if (decimals > 0 && s.contains('.')) {
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';
String fmtDayFull(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

String fmtMonthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';
