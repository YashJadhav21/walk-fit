import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../meal_ideas.dart';
import '../models.dart';
import 'widgets.dart';

class MealPlanPage extends StatelessWidget {
  const MealPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final plan = s.plan!;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('What to eat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            'Vegetarian ideas (dairy, no egg) for your ${plan.intakeKcal} kcal day, '
            'aiming for ${plan.proteinG} g protein. Tap an idea to log it.',
            style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          for (final meal in meals) ...[
            SectionTitle(meal,
                trailing: Text(
                    '~${(plan.intakeKcal * mealSplit[meal]!).round()} kcal',
                    style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
            for (final idea in ideasFor(meal, plan.intakeKcal * mealSplit[meal]!).take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  onTap: () => _logIdea(context, idea),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            idea.items.map((e) => '${fmtNum(e.$2, 2)} ${e.$1.name}').join(' + '),
                            style: t.bodyLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${idea.kcal.round()} kcal · ${idea.protein.round()} g protein',
                            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.add_circle_outline, color: cs.primary),
                  ]),
                ),
              ),
          ],
          const SectionTitle('Tips'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final tip in vegTips)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.check, size: 18, color: cs.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(tip, style: t.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logIdea(BuildContext context, MealIdea idea) async {
    final ok = await confirm(
      context,
      'Log this ${idea.meal.toLowerCase()}?',
      '${idea.items.map((e) => '${fmtNum(e.$2, 2)} × ${e.$1.name}').join('\n')}\n\n'
          '${idea.kcal.round()} kcal for today.',
      ok: 'Log it',
    );
    if (!ok) return;
    final day = dayKey(DateTime.now());
    var n = 0;
    for (final (f, q) in idea.items) {
      await AppState.instance.addFood(FoodEntry(
        id: 'f${DateTime.now().microsecondsSinceEpoch}_${n++}',
        date: day,
        meal: idea.meal,
        foodId: f.id,
        name: f.name,
        serving: f.serving,
        qty: q,
        kcalPerServing: f.kcal,
        proteinPerServing: f.protein,
      ));
    }
    if (context.mounted) toast(context, 'Logged to ${idea.meal}');
  }
}
