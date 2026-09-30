import 'package:challenges/l10n/app_localizations.dart';
import 'package:challenges/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rendert [child] mit dem App-Theme und den Sprachpaketen auf einer
/// Handy-Größe; Standard ist Deutsch.
///
/// Einheitlicher Einstieg für Widget-Tests (siehe Skill flutter-dart).
extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget child, {
    Size size = const Size(900, 2400),
    Locale locale = const Locale('de'),
  }) async {
    view.physicalSize = size;
    view.devicePixelRatio = 1.0;
    addTearDown(view.reset);
    await pumpWidget(MaterialApp(
      theme: buildTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ));
    await pumpAndSettle();
  }
}
