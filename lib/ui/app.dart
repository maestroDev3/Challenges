import 'package:flutter/material.dart';

import '../domain/challenge_repository.dart';
import '../domain/reminders.dart';
import 'home_shell.dart';
import 'intro_screen.dart';
import 'theme.dart';

class ChallengesApp extends StatelessWidget {
  const ChallengesApp({super.key, required this.repository, this.scheduler});

  final ChallengeRepository repository;
  final ReminderScheduler? scheduler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ritual',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildTheme(),
      themeMode: ThemeMode.dark,
      home: _IntroGate(
        child: HomeShell(repository: repository, scheduler: scheduler),
      ),
    );
  }
}

/// Zeigt einmal pro Start das Intro und blendet dann in die App über.
class _IntroGate extends StatefulWidget {
  const _IntroGate({required this.child});

  final Widget child;

  @override
  State<_IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<_IntroGate> {
  bool _introDone = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _introDone
          ? widget.child
          : IntroScreen(onDone: () => setState(() => _introDone = true)),
    );
  }
}
