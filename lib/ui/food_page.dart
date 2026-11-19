import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import 'add_food_page.dart';
import 'meal_plan_page.dart';
import 'widgets.dart';

class FoodPage extends StatefulWidget {
  const FoodPage({super.key});

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  DateTime _day = DateTime.now();

  bool get _isToday => dayKey(_day) == dayKey(DateTime.now());

  void _shift(int days) {
    final next = DateTime(_day.year, _day.month, _day.day + days);
    if (next.isAfter(DateTime.now())) return;
    setState(() => _day = next);
  }

  static String defaultMeal() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Breakfast';
    if (h < 16) return 'Lunch';
    if (h < 19) return 'Snacks';
    return 'Dinner';
  }

  void _add(String meal) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AddFoodPage(meal: meal, date: dayKey(_day))));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food'),
        actions: [
          IconButton(
            tooltip: 'Meal ideas',
            icon: const Icon(Icons.eco_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MealPlanPage())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addFood',
        onPressed: () => _add(_isToday ? defaultMeal() : 'Lunch'),
        icon: const Icon(Icons.add),
        label: const Text('Add food'),
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final s = AppState.instance;
          final key = dayKey(_day);
          final entries = s.foodOn(key);
          final plan = s.plan!;
          final eaten = s.kcalEatenOn(key);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              Row(children: [
                IconButton(
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Center(
                    child: Text(_isToday ? 'Today' : fmtDayFull(_day),
                        style: t.titleMedium),
                  ),
                ),
                IconButton(
                    onPressed: _isToday ? null : () => _shift(1),
                    icon: const Icon(Icons.chevron_right)),
              ]),
              const SizedBox(height: 4),
              Panel(
                child: Column(children: [
                  GoalBar(
                    label: 'Calories',
                    value: eaten,
                    goal: plan.intakeKcal.toDouble(),
                    unit: 'kcal',
                    overIsBad: true,
                    note: eaten <= plan.intakeKcal
                        ? '${(plan.intakeKcal - eaten).round()} kcal left'
                        : '${(eaten - plan.intakeKcal).round()} kcal over budget',
                  ),
                  const SizedBox(height: 16),
                  GoalBar(
                    label: 'Protein',
                    value: s.proteinOn(key),
                    goal: plan.proteinG.toDouble(),
                    unit: 'g',
                  ),
                ]),
              ),
              for (final meal in meals) ...[
                SectionTitle(
                  meal,
                  trailing: Text(
                    '${entries.where((e) => e.meal == meal).fold(0.0, (a, e) => a + e.kcal).round()} kcal',
                    style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final e in entries.where((e) => e.meal == meal))
                      _EntryTile(entry: e),
                    ListTile(
                      leading: Icon(Icons.add, color: cs.primary),
                      title: Text('Add to $meal',
                          style: TextStyle(color: cs.primary)),
                      onTap: () => _add(meal),
                    ),
                  ]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final FoodEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = entry;
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: cs.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      onDismissed: (_) {
        AppState.instance.removeFood(e.id);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Removed ${e.name}'),
            action: SnackBarAction(
                label: 'Undo', onPressed: () => AppState.instance.addFood(e)),
          ));
      },
      child: ListTile(
        title: Text(e.name),
        subtitle: Text('${fmtNum(e.qty, 2)} × ${e.serving}'),
        trailing: Text('${e.kcal.round()} kcal',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontFeatures: tabular)),
        onTap: () => showQuantitySheet(
          context,
          name: e.name,
          serving: e.serving,
          kcal: e.kcalPerServing,
          protein: e.proteinPerServing,
          initialQty: e.qty,
          initialMeal: e.meal,
          confirmLabel: 'Update',
          onDelete: () => AppState.instance.removeFood(e.id),
          onConfirm: (qty, meal) => AppState.instance.updateFood(FoodEntry(
            id: e.id,
            date: e.date,
            meal: meal,
            foodId: e.foodId,
            name: e.name,
            serving: e.serving,
            qty: qty,
            kcalPerServing: e.kcalPerServing,
            proteinPerServing: e.proteinPerServing,
          )),
        ),
      ),
    );
  }
}
