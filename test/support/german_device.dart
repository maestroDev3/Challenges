import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simuliert ein Handy mit deutscher Systemsprache. Die Testumgebung meldet
/// sonst Englisch, und die App folgt ohne gewählte Sprache dem System.
void useGermanDevice(WidgetTester tester) {
  tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
  tester.platformDispatcher.localeTestValue = const Locale('de', 'DE');
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
}
