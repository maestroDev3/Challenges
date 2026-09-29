import 'package:flutter/material.dart';

import '../domain/challenge_repository.dart';
import '../domain/profile.dart';
import '../domain/settings.dart';
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
                  tooltip: 'Einstellungen',
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
                    name.isEmpty ? 'Dein Profil' : name,
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
                          'Noch keine Challenges – starte deine erste unter '
                          '„Entdecken“. Hier siehst du dann, was du schon '
                          'geschafft hast.',
                          style: text.bodyLarge,
                        )
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _Stat(label: 'Laufend', value: stats.running),
                            _Stat(label: 'Geschafft', value: stats.completed),
                            _Stat(
                                label: 'Tage erledigt', value: stats.doneDays),
                            _Stat(
                                label: 'Längste Streak',
                                value: stats.longestStreak),
                            _Stat(label: 'Abzeichen', value: stats.badges),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
