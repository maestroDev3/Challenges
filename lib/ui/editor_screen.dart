import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge.dart';
import '../domain/challenge_repository.dart';
import 'catalog_screen.dart';
import 'format.dart';
import 'rule_selector.dart';

/// Auswahl für eigene Challenges – bewusst kurz gehalten.
const editorEmojis = [
  '⭐', '🔥', '🏃', '💪', '🧘', '📖', '💧', '🥗', '🚫', '🍬', '🍷', '📵',
  '😴', '⏰', '🌅', '🧊', '🚶', '🚴', '🏊', '✍️', '🎸', '🧹', '💰', '❤️',
];

enum _KindChoice { ongoing, days, weekly, oneTime }

/// Formular zum Anlegen oder Bearbeiten einer eigenen Challenge.
class ChallengeEditorScreen extends StatefulWidget {
  const ChallengeEditorScreen({
    super.key,
    required this.repository,
    this.initial,
    this.clock = DateTime.now,
    this.onStarted,
  });

  final ChallengeRepository repository;

  /// Vorhandene eigene Vorlage (Bearbeiten) oder null (neu).
  final ChallengeTemplate? initial;
  final Clock clock;
  final ChallengeStarted? onStarted;

  @override
  State<ChallengeEditorScreen> createState() => _ChallengeEditorScreenState();
}

class _ChallengeEditorScreenState extends State<ChallengeEditorScreen> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _description =
      TextEditingController(text: widget.initial?.description);
  final _days = TextEditingController(text: '30');
  final _weeklyTimes = TextEditingController(text: '3');
  final _weeklyMinutes = TextEditingController(text: '120');
  late String _emoji = widget.initial?.emoji ?? editorEmojis.first;
  _KindChoice _kind = _KindChoice.ongoing;
  WeeklyUnit _unit = WeeklyUnit.times;
  late DateTime _date = dayOf(widget.clock()).add(const Duration(days: 1));
  ReminderTime _reminder = const ReminderTime(9, 0);
  StreakRule _rule = StreakRule.relaxed;
  final Set<int> _weekdays = {};
  bool _busy = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    switch (widget.initial?.kind) {
      case DailyKind(days: final d?):
        _kind = _KindChoice.days;
        _days.text = '$d';
      case WeeklyGoalKind(target: final n, unit: final u):
        _kind = _KindChoice.weekly;
        _unit = u;
        (u == WeeklyUnit.times ? _weeklyTimes : _weeklyMinutes).text = '$n';
        if (widget.initial?.kind case WeeklyGoalKind(weekdays: final w)) {
          _weekdays.addAll(w);
        }
      case OneTimeKind(date: final d):
        _kind = _KindChoice.oneTime;
        if (d != null) _date = d;
      default:
        break;
    }
    for (final c in [_title, _days, _weeklyTimes, _weeklyMinutes]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _days, _weeklyTimes, _weeklyMinutes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Baut die Vorlage aus dem Formular; null, wenn Eingaben ungültig sind.
  ChallengeTemplate? _buildTemplate() {
    final ChallengeKind kind;
    switch (_kind) {
      case _KindChoice.ongoing:
        kind = widget.initial?.kind is JournalKind
            ? const JournalKind()
            : const DailyKind();
      case _KindChoice.days:
        final d = int.tryParse(_days.text);
        if (d == null) return null;
        kind = DailyKind(days: d);
      case _KindChoice.weekly:
        final controller =
            _unit == WeeklyUnit.times ? _weeklyTimes : _weeklyMinutes;
        final n = int.tryParse(controller.text);
        if (n == null) return null;
        kind = WeeklyGoalKind(n,
            unit: _unit,
            weekdays: _unit == WeeklyUnit.times ? {..._weekdays} : const {});
      case _KindChoice.oneTime:
        kind = OneTimeKind(const Duration(hours: 24), date: _date);
    }
    try {
      return ChallengeTemplate.custom(
        id: widget.initial?.id,
        title: _title.text,
        emoji: _emoji,
        description: _description.text,
        kind: kind,
      );
    } on ArgumentError {
      return null;
    }
  }

  /// Die Art laut Formular (für die passenden Regeln).
  ChallengeKind get _currentKind => switch (_kind) {
        _KindChoice.ongoing => const DailyKind(),
        _KindChoice.days => const DailyKind(days: 1),
        _KindChoice.weekly => WeeklyGoalKind(1, unit: _unit),
        _KindChoice.oneTime => const OneTimeKind(Duration(hours: 24)),
      };

  void _setKind(_KindChoice choice) => setState(() {
        _kind = choice;
        _rule = ruleFor(_currentKind, _rule);
      });

  void _toggleWeekday(int day) => setState(() {
        if (!_weekdays.remove(day)) _weekdays.add(day);
        if (_weekdays.isNotEmpty) _weeklyTimes.text = '${_weekdays.length}';
      });

  Future<void> _save() async {
    final template = _buildTemplate();
    if (template == null) return;
    setState(() => _busy = true);
    await widget.repository.saveTemplate(template);
    if (!_isEdit) {
      final c =
          await widget.repository.start(template, _reminder, rule: _rule);
      await widget.onStarted?.call(c);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final today = dayOf(widget.clock());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminder.hour, minute: _reminder.minute),
    );
    if (picked != null && mounted) {
      setState(() => _reminder = ReminderTime(picked.hour, picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final valid = _buildTemplate() != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Challenge bearbeiten' : 'Eigene Challenge'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Titel',
                hintText: 'z. B. 3× pro Woche Sport',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Symbol', style: text.titleSmall),
            const SizedBox(height: 8),
            _EmojiPicker(
              selected: _emoji,
              onSelected: (e) => setState(() => _emoji = e),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _description,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Beschreibung (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text('Art', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (choice, label) in const [
                  (_KindChoice.ongoing, 'Fortlaufend'),
                  (_KindChoice.days, 'X Tage'),
                  (_KindChoice.weekly, 'Wöchentlich'),
                  (_KindChoice.oneTime, 'Einmalig'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _kind == choice,
                    onSelected: (_) => _setKind(choice),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ..._kindFields(text),
            const SizedBox(height: 8),
            if (!_isEdit && allowedRules(_currentKind).isNotEmpty) ...[
              Text('Regel bei Fehltagen', style: text.titleSmall),
              const SizedBox(height: 8),
              RuleSelector(
                value: _rule,
                allowed: allowedRules(_currentKind),
                onChanged: (r) => setState(() => _rule = r),
              ),
              const SizedBox(height: 8),
            ],
            if (!_isEdit)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Erinnerung'),
                trailing: Text(_reminder.toString(), style: text.titleMedium),
                onTap: _pickTime,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: valid && !_busy ? _save : null,
              child: Text(_isEdit ? 'Speichern' : 'Speichern & starten'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _kindFields(TextTheme text) => switch (_kind) {
        _KindChoice.ongoing => [
            Text('Jeden Tag, ohne Enddatum.', style: text.bodyMedium),
          ],
        _KindChoice.days => [
            _NumberField(controller: _days, label: 'Anzahl Tage', hint: '1–365'),
          ],
        _KindChoice.weekly => [
            SegmentedButton<WeeklyUnit>(
              segments: const [
                ButtonSegment(value: WeeklyUnit.times, label: Text('Mal')),
                ButtonSegment(value: WeeklyUnit.minutes, label: Text('Minuten')),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => setState(() => _unit = s.first),
            ),
            const SizedBox(height: 12),
            if (_unit == WeeklyUnit.times) ...[
              Text('An festen Tagen? (optional)', style: text.bodyMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (i, name) in const [
                    'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So',
                  ].indexed)
                    FilterChip(
                      label: Text(name),
                      selected: _weekdays.contains(i + 1),
                      showCheckmark: false,
                      onSelected: (_) => _toggleWeekday(i + 1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_unit == WeeklyUnit.times)
              _NumberField(
                controller: _weeklyTimes,
                label: 'Mal pro Woche',
                hint: _weekdays.isEmpty
                    ? '1–7 · flexibel, wann du willst'
                    : 'ergibt sich aus den gewählten Tagen',
                enabled: _weekdays.isEmpty,
              )
            else
              _NumberField(
                  controller: _weeklyMinutes,
                  label: 'Minuten pro Woche',
                  hint: 'z. B. 120'),
          ],
        _KindChoice.oneTime => [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Datum'),
              trailing: Text(formatDate(_date, withYear: true),
                  style: text.titleMedium),
              onTap: _pickDate,
            ),
          ],
      };
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.hint,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          border: const OutlineInputBorder(),
        ),
      );
}

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in editorEmojis)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelected(e),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: e == selected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: e == selected
                    ? Border.all(color: scheme.primary, width: 2)
                    : null,
              ),
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          ),
      ],
    );
  }
}
