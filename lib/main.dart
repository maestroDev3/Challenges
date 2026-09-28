import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local_challenge_repository.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ChallengesApp(repository: LocalChallengeRepository(prefs)));
}
