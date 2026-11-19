import 'dart:math' as math;

import 'package:flutter/material.dart';

const tabular = [FontFeature.tabularFigures()];

TextStyle numStyle(BuildContext context, double size,
        {FontWeight weight = FontWeight.w700, Color? color}) =>
    TextStyle(
      fontFamily: 'InterDisplay',
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -size * 0.03,
      height: 1.0,
      fontFeatures: tabular,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

/// Flat rounded card (no border, no shadow).
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: color ?? cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small uppercase heading above a group.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                    color: cs.onSurfaceVariant)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Label extends StatelessWidget {
  final String text;
  const Label(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.9,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
}

/// Big number + unit, small uppercase label under it.
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
    final cs = Theme.of(context).colorScheme;
    final size = large ? 40.0 : 24.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: value, style: numStyle(context, size)),
              if (unit != null)
                TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                        fontSize: large ? 16 : 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant)),
            ]),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 6),
        Label(label),
      ],
    );
  }
}

/// "Label            120 / 300 kcal" + thin progress bar.
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
    final color = over ? cs.error : cs.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
                child: Text(label,
                    style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w500))),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: value.round().toString(),
                  style: numStyle(context, 18, color: over ? cs.error : null)),
              TextSpan(
                  text: ' / ${goal.round()} $unit',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontFeatures: tabular)),
            ])),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: frac.clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            color: color,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note!,
              style: t.bodySmall?.copyWith(
                  color: over ? cs.error : cs.onSurfaceVariant)),
        ],
      ],
    );
  }
}

/// Thin circular progress ring with content in the middle.
class Ring extends StatelessWidget {
  final double progress; // 0..1+
  final double size;
  final double stroke;
  final Widget child;
  final bool warn;
  const Ring(
      {super.key,
      required this.progress,
      required this.child,
      this.size = 150,
      this.stroke = 10,
      this.warn = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          stroke: stroke,
          track: cs.surfaceContainerHighest,
          fill: warn ? cs.error : cs.onSurface,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress, stroke;
  final Color track, fill;
  _RingPainter(
      {required this.progress,
      required this.stroke,
      required this.track,
      required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, p..color = track);
    final sweep = progress.clamp(0.0, 1.0) * math.pi * 2;
    if (sweep > 0) {
      canvas.drawArc(rect, -math.pi / 2, sweep, false, p..color = fill);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.fill != fill || old.track != track;
}

InputDecoration fieldDeco(BuildContext context, String label,
    {String? suffix, String? hint}) {
  final cs = Theme.of(context).colorScheme;
  OutlineInputBorder b(Color c, [double w = 1.5]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    labelText: label,
    suffixText: suffix,
    hintText: hint,
    filled: true,
    fillColor: cs.surfaceContainerLow,
    floatingLabelStyle: TextStyle(color: cs.onSurface),
    border: b(Colors.transparent),
    enabledBorder: b(Colors.transparent),
    focusedBorder: b(cs.onSurface),
    errorBorder: b(cs.error),
    focusedErrorBorder: b(cs.error),
  );
}

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
      backgroundColor: Theme.of(c).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: Theme.of(c).textTheme.titleLarge),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 44),
            backgroundColor: destructive ? Theme.of(c).colorScheme.error : null,
            foregroundColor: destructive ? Theme.of(c).colorScheme.onError : null,
          ),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
