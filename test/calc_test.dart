import 'package:flutter_test/flutter_test.dart';
import 'package:walkfit/calc.dart';
import 'package:walkfit/models.dart';

void main() {
  Profile p() => Profile(
        name: 'Test',
        sex: 'male',
        age: 25,
        heightCm: 175,
        weightKg: 80,
        goalKg: 70,
        activity: 0,
        paceKgPerWeek: 0.5,
        walkGoalKcal: 190,
      );

  test('BMR (Mifflin-St Jeor)', () {
    // 10*80 + 6.25*175 - 5*25 + 5 = 1773.75
    expect(bmr(p()), closeTo(1773.75, 0.01));
  });

  test('plan keeps total deficit at the chosen pace', () {
    final plan = computePlan(p());
    // TDEE = 1773.75 * 1.2 = 2128.5; deficit 550; walking 190 -> eat 2128.5 - 360
    expect(plan.intakeKcal, 1770);
    expect(plan.dailyDeficit, closeTo(550, 1));
    expect(plan.weeksToGoal, closeTo(20, 0.2));
  });

  test('walking at 5 km/h for 1 h burns ~216 active kcal at 80 kg', () {
    final k = activeKcal(5.0, 3600, 80);
    expect(k, closeTo(216, 5));
    expect(activeKcal(0.5, 3600, 80), 0);
  });

  test('pace formatting', () {
    expect(fmtPace(1000, 720), '12:00');
    expect(fmtKm(1234), '1.23');
  });
}
