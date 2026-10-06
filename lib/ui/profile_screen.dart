import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge_repository.dart';
import '../domain/profile.dart';
import '../domain/settings.dart';
import '../domain/week_review.dart';
import 'l10n.dart';
import 'theme.dart';
import 'week_review_screen.dart';

/// Profil mit Name und Übersicht über alle Challenges.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.settings,
    this.onOpenSettings,
    this.clock = DateTime.now,
  });

  final ChallengeRepository repository;
  final SettingsRepository settings;
  final Clock clock;

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
                      if (!stats.isEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => WeekReviewScreen(
                                repository: repository,
                                weekStart: reviewWeekFor(clock()),
                                clock: clock,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.history_outlined),
                          label: Text(context.l10n.profileLastWeek),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (stats.isEmpty)
                        Text(
                          context.l10n.profileEmpty,
                          style: text.bodyLarge,
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
