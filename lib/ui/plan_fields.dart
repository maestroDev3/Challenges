import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import 'l10n.dart';

/// Eingabe des Wenn-Dann-Plans: „Wann?“ mit Vorschlägen und „Wo?“.
/// Die Controller gehören dem aufrufenden State.
class PlanFields extends StatelessWidget {
  const PlanFields({super.key, required this.when, required this.where});

  final TextEditingController when;
  final TextEditingController where;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final suggestions = [
      l10n.planSuggestWakeUp,
      l10n.planSuggestBreakfast,
      l10n.planSuggestWork,
      l10n.planSuggestBed,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.planHeading, style: text.titleSmall),
        const SizedBox(height: 4),
        Text(l10n.planExplain, style: text.bodySmall),
        const SizedBox(height: 12),
        TextField(
          key: const Key('plan-when'),
          controller: when,
          maxLength: maxPlanLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.planWhenLabel,
            prefixIcon: const Icon(Icons.schedule_outlined),
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in suggestions)
              ActionChip(
                label: Text(s),
                onPressed: () => when.text = s,
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('plan-where'),
          controller: where,
          maxLength: maxPlanLength,
          decoration: InputDecoration(
            labelText: l10n.planWhereLabel,
            hintText: l10n.planWhereHint,
            prefixIcon: const Icon(Icons.place_outlined),
            counterText: '',
          ),
        ),
      ],
    );
  }
}
