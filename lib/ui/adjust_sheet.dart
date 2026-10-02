import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge_repository.dart';
import '../l10n/template_text.dart';
import 'editor_screen.dart';
import 'l10n.dart';
import 'plan_fields.dart';
import 'rule_selector.dart';

/// Uhrzeitauswahl – im Test ersetzbar.
typedef TimePick = Future<TimeOfDay?> Function(
    BuildContext context, TimeOfDay initial);

Future<TimeOfDay?> pickTimeDefault(BuildContext context, TimeOfDay initial) =>
    showTimePicker(context: context, initialTime: initial);

/// Datumsauswahl – im Test ersetzbar.
typedef DatePick = Future<DateTime?> Function(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
});

Future<DateTime?> pickDateDefault(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) =>
    showDatePicker(
        context: context, initialDate: initial, firstDate: first, lastDate: last);

/// Einstellungen einer laufenden Challenge ändern, ohne den Verlauf zu
/// verlieren. Liefert die geänderte Challenge (oder null bei Abbruch).
Future<ActiveChallenge?> showAdjustSheet(
  BuildContext context, {
  required ActiveChallenge challenge,
  required ChallengeRepository repository,
  required Clock clock,
  TimePick pickTime = pickTimeDefault,
}) {
  return showModalBottomSheet<ActiveChallenge>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _AdjustSheet(
      challenge: challenge,
      pickTime: pickTime,
      onEditDetails: challenge.template.isCustom
          ? () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ChallengeEditorScreen(
                  repository: repository,
                  initial: challenge.template,
                  clock: clock,
                ),
              ));
            }
          : null,
    ),
  );
}

class _AdjustSheet extends StatefulWidget {
  const _AdjustSheet({
    required this.challenge,
    required this.pickTime,
    this.onEditDetails,
  });

  final ActiveChallenge challenge;
  final TimePick pickTime;
  final VoidCallback? onEditDetails;

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  late ReminderTime _reminder = widget.challenge.reminder;
  late StreakRule _rule = widget.challenge.rule;
  late final _planWhen = TextEditingController(text: widget.challenge.planWhen);
  late final _planWhere =
      TextEditingController(text: widget.challenge.planWhere);

  @override
  void dispose() {
    _planWhen.dispose();
    _planWhere.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await widget.pickTime(
        context, TimeOfDay(hour: _reminder.hour, minute: _reminder.minute));
    if (picked != null && mounted) {
      setState(() => _reminder = ReminderTime(picked.hour, picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final text = Theme.of(context).textTheme;
    final allowed = allowedRules(c.kind);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${c.template.emoji} ${c.template.titleIn(context.l10n)}',
                style: text.titleLarge),
            const SizedBox(height: 4),
            Text(context.l10n.adjustKeepsHistory,
                style: text.bodyMedium),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(context.l10n.reminderLabel),
              trailing: Text(_reminder.toString(), style: text.titleMedium),
              onTap: _pick,
            ),
            if (allowed.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(context.l10n.ruleOnMissedDays, style: text.titleSmall),
              const SizedBox(height: 8),
              RuleSelector(
                value: _rule,
                allowed: allowed,
                onChanged: (r) => setState(() => _rule = r),
              ),
              const SizedBox(height: 4),
              Text(context.l10n.ruleAppliesToHistory,
                  style: text.bodySmall),
            ],
            if (widget.onEditDetails case final edit?) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: edit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(context.l10n.adjustEditDetails),
              ),
            ],
            const SizedBox(height: 16),
            PlanFields(when: _planWhen, where: _planWhere),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(c
                  .copyWith(reminder: _reminder, rule: ruleFor(c.kind, _rule))
                  .withPlan(when: _planWhen.text, where: _planWhere.text)),
              child: Text(context.l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
