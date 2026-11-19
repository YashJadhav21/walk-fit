import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../food_db.dart';
import '../gemini.dart';
import '../models.dart';
import 'settings_page.dart';
import 'widgets.dart';

String _newId() => 'f${DateTime.now().microsecondsSinceEpoch}';

class AddFoodPage extends StatefulWidget {
  final String meal;
  final String date;
  const AddFoodPage({super.key, required this.meal, required this.date});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  final _search = TextEditingController();
  String _q = '';
  String? _category;
  late String _meal = widget.meal;
  bool _asking = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FoodItem> _results() {
    final all = AppState.instance.allFoods;
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) {
      if (_category == null) return const [];
      if (_category == 'My foods') {
        return all.where((f) => f.custom).toList();
      }
      return all.where((f) => f.category == _category).toList();
    }
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final matches = all.where((f) {
      final hay = '${f.name} ${f.category}'.toLowerCase();
      return words.every(hay.contains);
    }).toList();
    // Names starting with the query first.
    matches.sort((a, b) {
      final sa = a.name.toLowerCase().startsWith(q) ? 0 : 1;
      final sb = b.name.toLowerCase().startsWith(q) ? 0 : 1;
      return sa != sb ? sa - sb : a.name.compareTo(b.name);
    });
    return matches;
  }

  void _pick(FoodItem f) {
    showQuantitySheet(
      context,
      name: f.name,
      serving: f.serving,
      kcal: f.kcal,
      protein: f.protein,
      initialQty: 1,
      initialMeal: _meal,
      confirmLabel: 'Add',
      onConfirm: (qty, meal) async {
        _meal = meal;
        await AppState.instance.addFood(FoodEntry(
          id: _newId(),
          date: widget.date,
          meal: meal,
          foodId: f.id,
          name: f.name,
          serving: f.serving,
          qty: qty,
          kcalPerServing: f.kcal,
          proteinPerServing: f.protein,
        ));
        if (mounted) toast(context, 'Added ${f.name} to $meal');
      },
    );
  }

  Future<void> _askGemini() async {
    final key = AppState.instance.geminiKey;
    final q = _q.trim();
    if (q.isEmpty) return;
    if (key.isEmpty) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SettingsPage()));
      if (AppState.instance.geminiKey.isEmpty) return;
    }
    setState(() => _asking = true);
    try {
      final foods = await Gemini.estimate(AppState.instance.geminiKey, q,
          preferredModel: AppState.instance.geminiModel);
      if (!mounted) return;
      await _showAiResults(foods);
    } on GeminiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) toast(context, 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  void _showError(String msg) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Gemini could not answer'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _showAiResults(List<AiFood> foods) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => _AiResultSheet(
        foods: foods,
        meal: _meal,
        onAdd: (items, meal) async {
          for (final it in items) {
            final saved = await AppState.instance.addCustomFood(
                it.name, it.serving, it.kcal, it.protein);
            await AppState.instance.addFood(FoodEntry(
              id: _newId(),
              date: widget.date,
              meal: meal,
              foodId: saved.id,
              name: saved.name,
              serving: saved.serving,
              qty: 1,
              kcalPerServing: saved.kcal,
              proteinPerServing: saved.protein,
            ));
          }
          if (mounted) {
            toast(context, 'Added ${items.length} item${items.length > 1 ? 's' : ''} to $meal');
            _search.clear();
            setState(() => _q = '');
          }
        },
      ),
    );
  }

  Future<void> _customFood() async {
    final r = await showDialog<FoodItem>(
      context: context,
      builder: (_) => _CustomFoodDialog(initialName: _q.trim()),
    );
    if (r == null) return;
    final saved = await AppState.instance
        .addCustomFood(r.name, r.serving, r.kcal, r.protein);
    if (mounted) _pick(saved);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Add to $_meal')),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final s = AppState.instance;
          final results = _results();
          final recent = s.recentFoods();
          final hasCustom = s.customFoods.isNotEmpty;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() => _q = v),
                  onSubmitted: (_) {
                    if (results.isEmpty && _q.trim().isNotEmpty) _askGemini();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search food, e.g. roti, dal, paneer',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _q.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              setState(() => _q = '');
                            },
                          ),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                    border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(28))),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    if (_q.trim().isEmpty) ...[
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final c in [
                              if (hasCustom) 'My foods',
                              ...foodCategories
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(c),
                                  selected: _category == c,
                                  onSelected: (sel) =>
                                      setState(() => _category = sel ? c : null),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_category == null && recent.isNotEmpty) ...[
                        const SectionTitle('Recent'),
                        for (final f in recent) _FoodTile(food: f, onTap: () => _pick(f)),
                      ],
                      if (_category == null && recent.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Text(
                            'Search ${foodDb.length}+ vegetarian foods, or pick a category.',
                            textAlign: TextAlign.center,
                            style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                    ],
                    for (final f in results) _FoodTile(food: f, onTap: () => _pick(f)),
                    if (_q.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Panel(
                        padding: EdgeInsets.zero,
                        child: Column(children: [
                          ListTile(
                            leading: _asking
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2.5))
                                : Icon(Icons.auto_awesome_outlined, color: cs.primary),
                            title: Text(results.isEmpty
                                ? 'Not in the list. Estimate "${_q.trim()}" with Gemini'
                                : 'Estimate "${_q.trim()}" with Gemini'),
                            subtitle: Text(s.geminiKey.isEmpty
                                ? 'Needs your free Gemini API key (Settings)'
                                : 'Tip: include the amount, e.g. "2 rotis with ghee"'),
                            onTap: _asking ? null : _askGemini,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(Icons.edit_outlined, color: cs.primary),
                            title: const Text('Enter calories yourself'),
                            onTap: _customFood,
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onTap;
  const _FoodTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(food.name),
      subtitle: Text(
          '${food.serving} · ${fmtNum(food.protein, 1)} g protein${food.custom ? ' · My food' : ''}'),
      trailing: Text('${food.kcal.round()} kcal',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontFeatures: tabular, color: cs.onSurface)),
      onTap: onTap,
    );
  }
}

/// Bottom sheet to choose servings and meal.
Future<void> showQuantitySheet(
  BuildContext context, {
  required String name,
  required String serving,
  required double kcal,
  required double protein,
  required double initialQty,
  required String initialMeal,
  required String confirmLabel,
  required Future<void> Function(double qty, String meal) onConfirm,
  VoidCallback? onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) {
      var qty = initialQty;
      var meal = initialMeal;
      return StatefulBuilder(builder: (c, setS) {
        final t = Theme.of(c).textTheme;
        final cs = Theme.of(c).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: t.titleLarge),
                Text('1 serving = $serving',
                    style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 20),
                Row(children: [
                  IconButton.outlined(
                    onPressed: qty > 0.25
                        ? () => setS(() => qty = qty <= 0.5 ? 0.25 : qty - 0.5)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Column(children: [
                      Text(fmtNum(qty, 2),
                          style: t.displaySmall?.copyWith(
                              fontWeight: FontWeight.w600, fontFeatures: tabular)),
                      Text(qty == 1 ? 'serving' : 'servings', style: t.bodySmall),
                    ]),
                  ),
                  IconButton.outlined(
                    onPressed: () =>
                        setS(() => qty = qty < 0.5 ? 0.5 : qty + 0.5),
                    icon: const Icon(Icons.add),
                  ),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  for (final v in [0.5, 1.0, 1.5, 2.0, 3.0])
                    ChoiceChip(
                      label: Text(fmtNum(v, 1)),
                      selected: qty == v,
                      onSelected: (_) => setS(() => qty = v),
                    ),
                ]),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    for (final m in meals)
                      ButtonSegment(
                          value: m,
                          label: Text(m == 'Breakfast' ? 'Bfast' : m)),
                  ],
                  selected: {meal},
                  onSelectionChanged: (s) => setS(() => meal = s.first),
                ),
                const SizedBox(height: 16),
                Panel(
                  child: Row(children: [
                    Expanded(child: Stat(value: '${(kcal * qty).round()}', unit: 'kcal', label: 'Calories')),
                    Expanded(child: Stat(value: fmtNum(protein * qty, 1), unit: 'g', label: 'Protein')),
                  ]),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  if (onDelete != null) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          foregroundColor: cs.error),
                      onPressed: () {
                        onDelete();
                        Navigator.pop(c);
                      },
                      child: const Text('Remove'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      onPressed: () async {
                        Navigator.pop(c);
                        await onConfirm(qty, meal);
                      },
                      child: Text(confirmLabel),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      });
    },
  );
}

class _EditableAi {
  bool include;
  final TextEditingController name, serving, kcal, protein;
  final bool vegetarian;
  _EditableAi(AiFood f)
      : include = f.vegetarian,
        vegetarian = f.vegetarian,
        name = TextEditingController(text: f.name),
        serving = TextEditingController(text: f.serving),
        kcal = TextEditingController(text: f.kcal.round().toString()),
        protein = TextEditingController(text: fmtNum(f.protein, 1));
}

class AiPick {
  final String name, serving;
  final double kcal, protein;
  AiPick(this.name, this.serving, this.kcal, this.protein);
}

class _AiResultSheet extends StatefulWidget {
  final List<AiFood> foods;
  final String meal;
  final Future<void> Function(List<AiPick> items, String meal) onAdd;
  const _AiResultSheet(
      {required this.foods, required this.meal, required this.onAdd});

  @override
  State<_AiResultSheet> createState() => _AiResultSheetState();
}

class _AiResultSheetState extends State<_AiResultSheet> {
  late final items = widget.foods.map(_EditableAi.new).toList();
  late String meal = widget.meal;

  @override
  void dispose() {
    for (final i in items) {
      i.name.dispose();
      i.serving.dispose();
      i.kcal.dispose();
      i.protein.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final total = items
        .where((i) => i.include)
        .fold(0.0, (s, i) => s + (parseNum(i.kcal.text) ?? 0));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gemini estimate', style: t.titleLarge),
              Text('Check and correct the numbers before adding. Saved to My foods for next time.',
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                    child: Column(children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: i.include,
                        onChanged: (v) => setState(() => i.include = v ?? false),
                        title: TextField(
                          controller: i.name,
                          decoration: const InputDecoration(
                              isDense: true, border: InputBorder.none),
                          style: t.titleMedium,
                        ),
                        subtitle: i.vegetarian
                            ? null
                            : Text('Not vegetarian (contains egg/meat/fish)',
                                style: TextStyle(color: cs.error)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Column(children: [
                          TextField(
                            controller: i.serving,
                            decoration: fieldDeco(context, 'Amount'),
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: i.kcal,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: fieldDeco(context, 'Calories', suffix: 'kcal'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: i.protein,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: fieldDeco(context, 'Protein', suffix: 'g'),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  for (final m in meals)
                    ButtonSegment(value: m, label: Text(m == 'Breakfast' ? 'Bfast' : m)),
                ],
                selected: {meal},
                onSelectionChanged: (s) => setState(() => meal = s.first),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: total <= 0
                    ? null
                    : () async {
                        final picks = [
                          for (final i in items)
                            if (i.include && (parseNum(i.kcal.text) ?? 0) > 0)
                              AiPick(
                                i.name.text.trim().isEmpty ? 'Food' : i.name.text.trim(),
                                i.serving.text.trim().isEmpty ? '1 serving' : i.serving.text.trim(),
                                parseNum(i.kcal.text)!,
                                parseNum(i.protein.text) ?? 0,
                              ),
                        ];
                        Navigator.pop(context);
                        await widget.onAdd(picks, meal);
                      },
                child: Text('Add ${total.round()} kcal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomFoodDialog extends StatefulWidget {
  final String initialName;
  const _CustomFoodDialog({required this.initialName});

  @override
  State<_CustomFoodDialog> createState() => _CustomFoodDialogState();
}

class _CustomFoodDialogState extends State<_CustomFoodDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  final _serving = TextEditingController(text: '1 serving');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _serving.dispose();
    _kcal.dispose();
    _protein.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New food'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _name,
              decoration: fieldDeco(context, 'Name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _serving, decoration: fieldDeco(context, 'Serving')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kcal,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: fieldDeco(context, 'Calories per serving', suffix: 'kcal'),
              validator: (v) {
                final n = parseNum(v ?? '');
                return n == null || n <= 0 || n > 5000 ? 'Enter calories' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _protein,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: fieldDeco(context, 'Protein (optional)', suffix: 'g'),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              FoodItem('', _name.text.trim(),
                  _serving.text.trim().isEmpty ? '1 serving' : _serving.text.trim(),
                  parseNum(_kcal.text)!, parseNum(_protein.text) ?? 0, 'My foods',
                  custom: true),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
