import 'package:challenges/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rendert [child] mit dem App-Theme auf einer Handy-Größe.
///
/// Einheitlicher Einstieg für Widget-Tests (siehe Skill flutter-dart).
extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget child, {
    Size size = const Size(900, 2400),
    Brightness brightness = Brightness.light,
  }) async {
    view.physicalSize = size;
    view.devicePixelRatio = 1.0;
    addTearDown(view.reset);
    await pumpWidget(MaterialApp(
      theme: buildTheme(brightness),
      home: child,
    ));
    await pumpAndSettle();
  }
}
