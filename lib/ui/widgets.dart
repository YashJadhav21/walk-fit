import 'package:flutter/material.dart';

const tabular = [FontFeature.tabularFigures()];

/// Flat outlined panel used for every grouped block.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Big number with a small label under it.
class Stat extends StatelessWidget {
  final String value;
  final String label;
  final String? unit;
  final bool large;
  const Stat(
      {super.key,
      required this.value,
      required this.label,
      this.unit,
      this.large = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final style = (large ? t.displaySmall : t.titleLarge)?.copyWith(
        fontWeight: FontWeight.w600, fontFeatures: tabular, height: 1.1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: value, style: style),
            if (unit != null)
              TextSpan(
                  text: ' $unit',
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(label,
            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

/// "Label            120 / 300 kcal" + progress bar.
class GoalBar extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final String unit;
  final String? note;
  final bool overIsBad;
  const GoalBar({
    super.key,
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    this.note,
    this.overIsBad = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final frac = goal > 0 ? (value / goal) : 0.0;
    final over = overIsBad && value > goal;
    final color = over ? cs.error : cs.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(label, style: t.bodyLarge)),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: value.round().toString(),
                  style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: tabular,
                      color: over ? cs.error : null)),
              TextSpan(
                  text: ' / ${goal.round()} $unit',
                  style: t.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant, fontFeatures: tabular)),
            ])),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            color: color,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(note!,
              style: t.bodySmall?.copyWith(
                  color: over ? cs.error : cs.onSurfaceVariant)),
        ],
      ],
    );
  }
}

InputDecoration fieldDeco(String label, {String? suffix, String? hint}) =>
    InputDecoration(
      labelText: label,
      suffixText: suffix,
      hintText: hint,
      border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
    );

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirm(BuildContext context, String title, String body,
    {String ok = 'OK', bool destructive = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(c).colorScheme.error,
                  foregroundColor: Theme.of(c).colorScheme.onError)
              : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
