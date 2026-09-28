import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';

/// Auswahl der Regel für Fehltage mit kurzer Erklärung.
class RuleSelector extends StatelessWidget {
  const RuleSelector({super.key, required this.value, required this.onChanged});

  final StreakRule value;
  final ValueChanged<StreakRule> onChanged;

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
          segments: const [
            ButtonSegment(value: StreakRule.relaxed, label: Text('Locker')),
            ButtonSegment(value: StreakRule.joker, label: Text('Joker')),
            ButtonSegment(value: StreakRule.strict, label: Text('Hart')),
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
