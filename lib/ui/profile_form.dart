import 'package:flutter/material.dart';

import '../app_state.dart';
import '../calc.dart';
import '../models.dart';
import 'widgets.dart';

/// Used for first-run setup and for editing the profile later.
class ProfileFormPage extends StatefulWidget {
  final bool firstRun;
  const ProfileFormPage({super.key, this.firstRun = false});

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _age, _height, _weight, _goal;
  String _sex = 'male';
  int _activity = 0;
  double _pace = 0.5;

  @override
  void initState() {
    super.initState();
    final p = AppState.instance.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _age = TextEditingController(text: p != null ? '${p.age}' : '');
    _height = TextEditingController(text: p != null ? fmtNum(p.heightCm, 1) : '');
    _weight = TextEditingController(text: p != null ? fmtNum(p.weightKg, 1) : '');
    _goal = TextEditingController(text: p != null ? fmtNum(p.goalKg, 1) : '');
    if (p != null) {
      _sex = p.sex;
      _activity = p.activity;
      _pace = p.paceKgPerWeek;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _age, _height, _weight, _goal]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _range(String? v, double min, double max, String what) {
    final n = parseNum(v ?? '');
    if (n == null) return 'Enter $what';
    if (n < min || n > max) return 'Between ${fmtNum(min)} and ${fmtNum(max)}';
    return null;
  }

  bool get _losing {
    final w = parseNum(_weight.text), g = parseNum(_goal.text);
    return w != null && g != null && g < w;
  }

  void _next() {
    if (!_form.currentState!.validate()) return;
    final old = AppState.instance.profile;
    final p = Profile(
      name: _name.text.trim(),
      sex: _sex,
      age: parseNum(_age.text)!.round(),
      heightCm: parseNum(_height.text)!,
      weightKg: parseNum(_weight.text)!,
      goalKg: parseNum(_goal.text)!,
      activity: _activity,
      paceKgPerWeek: _pace,
      walkGoalKcal: old?.walkGoalKcal ?? 200,
    );
    // Re-suggest the walk goal on first run or when the pace changed.
    if (old == null || old.paceKgPerWeek != p.paceKgPerWeek) {
      p.walkGoalKcal = suggestedWalkGoal(p);
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlanReviewPage(profile: p, firstRun: widget.firstRun)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.firstRun ? 'Set up WalkFit' : 'Edit profile'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (widget.firstRun) ...[
              Text('Tell us about you', style: t.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'This sets your daily calorie budget and walking goal. '
                'Everything stays on this phone.',
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
            ],
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: fieldDeco(context, 'Name (optional)'),
            ),
            const SizedBox(height: 16),
            Text('Sex', style: t.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'male', label: Text('Male')),
                ButtonSegment(value: 'female', label: Text('Female')),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: fieldDeco(context, 'Age', suffix: 'yrs'),
                  validator: (v) => _range(v, 14, 90, 'age'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _height,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: fieldDeco(context, 'Height', suffix: 'cm'),
                  validator: (v) => _range(v, 120, 220, 'height'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: fieldDeco(context, 'Current weight', suffix: 'kg'),
                  validator: (v) => _range(v, 30, 250, 'weight'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _goal,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: fieldDeco(context, 'Goal weight', suffix: 'kg'),
                  validator: (v) => _range(v, 30, 250, 'goal'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            Text('Daily activity, not counting your walks',
                style: t.labelLarge),
            const SizedBox(height: 8),
            for (var i = 0; i < activityLevels.length; i++)
              _ChoiceTile(
                title: activityLevels[i].title,
                subtitle: activityLevels[i].detail,
                selected: _activity == i,
                onTap: () => setState(() => _activity = i),
              ),
            if (_losing) ...[
              const SizedBox(height: 16),
              Text('How fast do you want to lose?', style: t.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<double>(
                showSelectedIcon: false,
                segments: [
                  for (final p in paceOptions)
                    ButtonSegment(value: p, label: Text('${fmtNum(p, 2)} kg')),
                ],
                selected: {_pace},
                onSelectionChanged: (s) => setState(() => _pace = s.first),
              ),
              const SizedBox(height: 6),
              Text(
                'per week. 0.5 kg is a steady pace you can keep up.',
                style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Text('See my plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceTile(
      {required this.title,
      required this.subtitle,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? cs.surface : cs.onSurface;
    final sub = selected ? cs.surface.withValues(alpha: 0.7) : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? cs.onSurface : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600, color: fg)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: sub)),
                  ],
                ),
              ),
              Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? cs.surface : cs.outline),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Shows the computed plan and lets the user tune the walking goal.
class PlanReviewPage extends StatefulWidget {
  final Profile profile;
  final bool firstRun;
  const PlanReviewPage({super.key, required this.profile, this.firstRun = false});

  @override
  State<PlanReviewPage> createState() => _PlanReviewPageState();
}

class _PlanReviewPageState extends State<PlanReviewPage> {
  late Profile p = widget.profile;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    try {
      final weightChanged = AppState.instance.profile?.weightKg != p.weightKg;
      await AppState.instance
          .saveProfile(p, logWeight: widget.firstRun || weightChanged);
      if (nav.canPop()) nav.popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Could not save'),
          content: Text('$e'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final plan = computePlan(p);
    final lose = wantsToLose(p);
    final mins = minutesForKcal(p.walkGoalKcal.toDouble(), p.weightKg);
    final km = mins / 60 * 5;
    final b = bmi(p);
    final goalDate =
        DateTime.now().add(Duration(days: (plan.weeksToGoal * 7).round()));

    return Scaffold(
      appBar: AppBar(title: const Text('Your daily plan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Eat about', style: t.bodyMedium),
                Stat(value: '${plan.intakeKcal}', unit: 'kcal / day', label: 'Daily food budget', large: true),
                const Divider(height: 32),
                Text('Walk to burn', style: t.bodyMedium),
                Stat(
                    value: '${p.walkGoalKcal}',
                    unit: 'kcal / day',
                    label:
                        'About ${mins.round()} min or ${km.toStringAsFixed(1)} km at a brisk 5 km/h',
                    large: true),
                Slider(
                  value: p.walkGoalKcal.toDouble().clamp(100.0, 600.0),
                  min: 100,
                  max: 600,
                  divisions: 50,
                  label: '${p.walkGoalKcal} kcal',
                  onChanged: (v) => setState(() => p.walkGoalKcal = v.round()),
                ),
                Text(
                  'Move the slider: a bigger walking goal lets you eat a bit more.',
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(children: [
              _row(context, 'Protein target', '${plan.proteinG} g / day'),
              _row(context, 'Resting burn (BMR)', '${plan.bmr.round()} kcal'),
              _row(context, 'Daily burn without walks', '${plan.tdee.round()} kcal'),
              if (lose) ...[
                _row(context, 'Daily deficit', '${plan.dailyDeficit.round()} kcal'),
                _row(context, 'Expected loss',
                    '${plan.paceUsed.toStringAsFixed(2)} kg / week'),
                _row(context, 'Reach ${fmtNum(p.goalKg, 1)} kg',
                    '~${plan.weeksToGoal.ceil()} weeks (${fmtDate(goalDate)} ${goalDate.year})'),
              ],
              _row(context, 'BMI', '${b.toStringAsFixed(1)} · ${bmiLabel(b)}'),
            ]),
          ),
          if (plan.intakeFloored) ...[
            const SizedBox(height: 12),
            Text(
              'Your food budget is kept at the safe minimum of '
              '${minIntake(p).round()} kcal. The rest of the deficit has to come from walking, '
              'so weight loss will be a little slower than the pace you picked.',
              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Estimates use the Mifflin-St Jeor formula. Your real results will tell you more: '
            'log your weight weekly, and if it is not moving after 2–3 weeks, lower the food budget a little.',
            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _saving ? null : _save,
            child: Text(widget.firstRun ? 'Start using WalkFit' : 'Save plan'),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String k, String v) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
            child: Text(k,
                style: t.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
        Text(v, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
