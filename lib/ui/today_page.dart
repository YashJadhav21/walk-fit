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
        final deficitNow = plan.tdee +
            walked -
            (eaten > plan.intakeKcal ? eaten : plan.intakeKcal);
        final first = p.name.trim().isEmpty ? '' : p.name.trim().split(' ').first;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Label(fmtDayFull(now)),
              const SizedBox(height: 6),
              Text(first.isEmpty ? 'Today' : 'Hi, $first',
                  style: t.headlineLarge),
              const SizedBox(height: 20),

              // ---- calories hero ----
              Panel(
                padding: const EdgeInsets.all(22),
                child: Row(children: [
                  Ring(
                    progress: plan.intakeKcal > 0 ? eaten / plan.intakeKcal : 0,
                    warn: left < 0,
                    size: 138,
                    stroke: 11,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${left.abs().round()}', style: numStyle(context, 34)),
                      const SizedBox(height: 4),
                      Text(left >= 0 ? 'kcal left' : 'kcal over',
                          style: TextStyle(
                              fontSize: 12,
                              color: left >= 0 ? cs.onSurfaceVariant : cs.error)),
                    ]),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MiniRow(label: 'Budget', value: '${plan.intakeKcal}'),
                        const SizedBox(height: 14),
                        _MiniRow(label: 'Eaten', value: '${eaten.round()}'),
                        const SizedBox(height: 14),
                        _MiniRow(label: 'Walked', value: '${walked.round()}'),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: () => tabIndex.value = 1,
                    icon: Icon(tr.active ? Icons.directions_walk : Icons.play_arrow_rounded),
                    label: Text(tr.active ? 'Walking…' : 'Start walk'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: () => tabIndex.value = 2,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Log food'),
                  ),
                ),
              ]),

              // ---- goals ----
              const SectionTitle('Goals'),
              Panel(
                child: Column(children: [
                  GoalBar(
                      label: 'Walking',
                      value: walked,
                      goal: plan.walkGoalKcal.toDouble(),
                      unit: 'kcal'),
                  const SizedBox(height: 20),
                  GoalBar(
                      label: 'Protein',
                      value: protein,
                      goal: plan.proteinG.toDouble(),
                      unit: 'g'),
                  if (wantsToLose(p)) ...[
                    const SizedBox(height: 20),
                    GoalBar(
                      label: 'Deficit',
                      value: deficitNow.clamp(0.0, 99999.0).toDouble(),
                      goal: plan.dailyDeficit,
                      unit: 'kcal',
                      note: 'Projected for today if you eat your full budget.',
                    ),
                  ],
                ]),
              ),

              // ---- walking ----
              const SectionTitle('Walking today'),
              Panel(
                child: Row(children: [
                  Expanded(child: Stat(value: fmtKm(meters), unit: 'km', label: 'Distance')),
                  Expanded(child: Stat(value: fmtDurationShort(secs), label: 'Time')),
                  Expanded(child: Stat(value: '${walked.round()}', unit: 'kcal', label: 'Active')),
                ]),
              ),

              const SectionTitle('Eat'),
              Panel(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MealPlanPage())),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: cs.onSurface, borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.eco_outlined, color: cs.surface),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vegetarian meal ideas', style: t.titleMedium),
                        const SizedBox(height: 2),
                        Text('Sized to your ${plan.intakeKcal} kcal day',
                            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: cs.onSurfaceVariant),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniRow extends StatelessWidget {
  final String label;
  final String value;
  const _MiniRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(label),
        const SizedBox(height: 4),
        Text.rich(TextSpan(children: [
          TextSpan(text: value, style: numStyle(context, 20)),
          TextSpan(
              text: ' kcal',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ])),
      ],
    );
  }
}
