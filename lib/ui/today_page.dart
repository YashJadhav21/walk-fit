import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import '../tracker.dart';
import 'home_shell.dart';
import 'meal_plan_page.dart';
import 'widgets.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppState.instance, WalkTracker.instance]),
      builder: (context, _) {
        final s = AppState.instance;
        final tr = WalkTracker.instance;
        final p = s.profile!;
        final plan = s.plan!;
        final t = Theme.of(context).textTheme;
        final cs = Theme.of(context).colorScheme;
        final now = DateTime.now();
        final day = dayKey(now);

        // Include the walk in progress so numbers move live.
        final liveKcal = tr.active ? tr.kcal : 0.0;
        final liveM = tr.active ? tr.distanceM : 0.0;
        final liveSec = tr.active ? tr.elapsed.inSeconds : 0;

        final eaten = s.kcalEatenOn(day);
        final walked = s.walkKcalOn(day) + liveKcal;
        final meters = s.walkMetersOn(day) + liveM;
        final secs = s.walkSecondsOn(day) + liveSec;
        final protein = s.proteinOn(day);
        final left = plan.intakeKcal - eaten;
        // Projected end-of-day deficit, assuming the full food budget is eaten.
        final deficitNow = plan.tdee + walked - (eaten > plan.intakeKcal ? eaten : plan.intakeKcal);
        final greeting = now.hour < 12
            ? 'Good morning'
            : now.hour < 17
                ? 'Good afternoon'
                : 'Good evening';

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(fmtDayFull(now),
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                  p.name.isEmpty
                      ? greeting
                      : '$greeting, ${p.name.split(' ').first}',
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stat(
                      value: left >= 0 ? '${left.round()}' : '${(-left).round()}',
                      unit: 'kcal',
                      label: left >= 0 ? 'Food left for today' : 'Over your food budget',
                      large: true,
                    ),
                    const SizedBox(height: 20),
                    GoalBar(
                        label: 'Eaten',
                        value: eaten,
                        goal: plan.intakeKcal.toDouble(),
                        unit: 'kcal',
                        overIsBad: true),
                    const SizedBox(height: 16),
                    GoalBar(
                        label: 'Burned walking',
                        value: walked,
                        goal: plan.walkGoalKcal.toDouble(),
                        unit: 'kcal'),
                    const SizedBox(height: 16),
                    GoalBar(
                        label: 'Protein',
                        value: protein,
                        goal: plan.proteinG.toDouble(),
                        unit: 'g'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: () => tabIndex.value = 1,
                    icon: Icon(tr.active ? Icons.directions_walk : Icons.play_arrow),
                    label: Text(tr.active ? 'Walk in progress' : 'Start walk'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: () => tabIndex.value = 2,
                    icon: const Icon(Icons.add),
                    label: const Text('Log food'),
                  ),
                ),
              ]),
              const SectionTitle('Walking today'),
              Panel(
                child: Row(children: [
                  Expanded(child: Stat(value: fmtKm(meters), unit: 'km', label: 'Distance')),
                  Expanded(child: Stat(value: fmtDurationShort(secs), label: 'Time')),
                  Expanded(child: Stat(value: '${walked.round()}', unit: 'kcal', label: 'Active')),
                ]),
              ),
              if (wantsToLose(p)) ...[
                const SectionTitle('Deficit'),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GoalBar(
                        label: 'Projected deficit today',
                        value: deficitNow.clamp(0.0, 99999.0).toDouble(),
                        goal: plan.dailyDeficit,
                        unit: 'kcal',
                        note: 'Assumes you eat your full budget. Walking raises it; '
                            'eating over budget lowers it.',
                      ),
                    ],
                  ),
                ),
              ],
              const SectionTitle('What to eat'),
              Panel(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MealPlanPage())),
                child: Row(children: [
                  Icon(Icons.eco_outlined, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vegetarian meal ideas', style: t.bodyLarge),
                        Text('Fits your ${plan.intakeKcal} kcal budget',
                            style: t.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}
