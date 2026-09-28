import 'package:flutter/material.dart';

import '../domain/challenge_repository.dart';
import '../domain/reminders.dart';
import 'home_shell.dart';
import 'theme.dart';

class ChallengesApp extends StatelessWidget {
  const ChallengesApp({super.key, required this.repository, this.scheduler});

  final ChallengeRepository repository;
  final ReminderScheduler? scheduler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Challenges',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeShell(repository: repository, scheduler: scheduler),
    );
  }
}
