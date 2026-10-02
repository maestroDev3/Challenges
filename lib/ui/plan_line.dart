import 'package:flutter/material.dart';

/// Zeigt den Wenn-Dann-Plan einer Challenge als eine Zeile
/// („Nach dem Aufstehen, im Bad“).
class PlanLine extends StatelessWidget {
  const PlanLine(this.plan, {super.key = const Key('plan-line'), this.style});

  final String plan;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 6),
          child: Icon(Icons.place_outlined, size: 16, color: scheme.primary),
        ),
        Expanded(
          child: Text(
            plan,
            style: (style ?? Theme.of(context).textTheme.bodyMedium)
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
