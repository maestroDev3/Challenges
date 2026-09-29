import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';

/// Auswahl der Regel für Fehltage mit kurzer Erklärung.
class RuleSelector extends StatelessWidget {
  const RuleSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowed = const {StreakRule.relaxed, StreakRule.joker, StreakRule.strict},
  });

  final StreakRule value;
  final ValueChanged<StreakRule> onChanged;

  /// Nur diese Regeln werden angeboten (siehe `allowedRules`).
  final Set<StreakRule> allowed;

  static String explain(StreakRule rule) => switch (rule) {
        StreakRule.relaxed => 'Ein Fehltag setzt nur die Streak auf 0.',
        StreakRule.joker =>
          'Alle 7 Tage am Stück gibt es einen Joker 🛡️ (max. 2). Er rettet die Streak bei einem Fehltag.',
        StreakRule.strict =>
          'Ein Fehltag bedeutet Neustart bei Tag 1 – wie bei 75 Hard.',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<StreakRule>(
          segments: [
            for (final (rule, label) in const [
              (StreakRule.relaxed, 'Locker'),
              (StreakRule.joker, 'Joker'),
              (StreakRule.strict, 'Hart'),
            ])
              if (allowed.contains(rule))
                ButtonSegment(value: rule, label: Text(label)),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: 8),
        Text(
          explain(value),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
