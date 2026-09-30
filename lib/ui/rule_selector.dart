import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../l10n/app_localizations.dart';
import 'l10n.dart';

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

  static String explain(AppLocalizations l10n, StreakRule rule) =>
      switch (rule) {
        StreakRule.relaxed => l10n.ruleRelaxedExplain,
        StreakRule.joker => l10n.ruleJokerExplain,
        StreakRule.strict => l10n.ruleStrictExplain,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<StreakRule>(
          segments: [
            for (final (rule, label) in [
              (StreakRule.relaxed, context.l10n.ruleRelaxed),
              (StreakRule.joker, context.l10n.joker),
              (StreakRule.strict, context.l10n.ruleStrict),
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
          explain(context.l10n, value),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
