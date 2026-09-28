import 'package:home_widget/home_widget.dart';

import '../domain/active_challenge.dart';
import '../domain/widget_data.dart';

/// Schreibt die Widget-Daten und stößt das Neuzeichnen des Android-Widgets an.
class HomeWidgetUpdater implements WidgetUpdater {
  const HomeWidgetUpdater();

  static const _provider = 'de.maestrodev.challenges.RitualWidgetProvider';

  @override
  Future<void> update(List<ActiveChallenge> active, DateTime today) async {
    final entries = widgetEntries(active, today);
    await HomeWidget.saveWidgetData<int>('count', entries.length);
    for (final (i, e) in entries.indexed) {
      await HomeWidget.saveWidgetData<String>('id_$i', e.id);
      await HomeWidget.saveWidgetData<String>('title_$i', e.title);
      await HomeWidget.saveWidgetData<String>('streak_$i', e.streak);
      await HomeWidget.saveWidgetData<bool>('done_$i', e.doneToday);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
  }
}
