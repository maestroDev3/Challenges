import 'package:flutter/material.dart';

import '../domain/challenge_repository.dart';
import 'catalog_screen.dart';
import 'theme.dart';

class ChallengesApp extends StatelessWidget {
  const ChallengesApp({super.key, required this.repository, this.onStarted});

  final ChallengeRepository repository;
  final ChallengeStarted? onStarted;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Challenges',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: CatalogScreen(repository: repository, onStarted: onStarted),
    );
  }
}
