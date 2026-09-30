import 'package:flutter/material.dart';

import '../domain/challenge_repository.dart';
import '../domain/profile.dart';
import '../domain/settings.dart';
import 'l10n.dart';
import 'theme.dart';

/// Profil mit Name und Übersicht über alle Challenges.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.settings,
    this.onOpenSettings,
  });

  final ChallengeRepository repository;
  final SettingsRepository settings;

  /// Öffnet die Einstellungen; ohne Callback gibt es kein Zahnrad.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            actions: [
              if (onOpenSettings case final open?)
                IconButton(
                  tooltip: context.l10n.settingsTitle,
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: open,
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder<AppSettings>(
                stream: settings.watch(),
                builder: (context, snapshot) {
                  final name = snapshot.data?.name.trim() ?? '';
                  return Text(
                    name.isEmpty ? context.l10n.profileDefaultName : name,
                    style: text.displaySmall,
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder<ChallengeStore>(
                stream: repository.watchStore(),
                builder: (context, snapshot) {
                  final store = snapshot.data;
                  if (store == null) return const SizedBox.shrink();
                  final stats = profileStats(store);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sacrifice the moment. Evolve the future.',
                        style: text.titleMedium?.copyWith(
                          fontFamily: ritualSerif,
                          fontStyle: FontStyle.italic,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (stats.isEmpty)
                        Text(
                          context.l10n.profileEmpty,
                          style: text.bodyLarge,
                        )
                      else
                        _StatGrid(
                          children: [
                            _Stat(
                                label: context.l10n.statRunning,
                                value: stats.running),
                            _Stat(
                                label: context.l10n.statCompleted,
                                value: stats.completed),
                            _Stat(
                                label: context.l10n.statDaysDone,
                                value: stats.doneDays),
                            _Stat(
                                label: context.l10n.statLongestStreak,
                                value: stats.longestStreak),
                            _Stat(
                                label: context.l10n.badgesTitle,
                                value: stats.badges),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kacheln in Reihen zu je drei; alle gleich breit, eine Reihe gleich hoch.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});

  static const _columns = 3;
  static const _gap = 12.0;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (var i = 0; i < children.length; i += _columns)
        children.sublist(i, (i + _columns).clamp(0, children.length)),
    ];
    return Column(
      children: [
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) const SizedBox(height: _gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < _columns; c++) ...[
                  if (c > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: c < row.length ? row[c] : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('stat-tile'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value',
              style: text.headlineSmall?.copyWith(color: scheme.primary)),
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
