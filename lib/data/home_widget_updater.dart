import 'package:home_widget/home_widget.dart';

import '../domain/active_challenge.dart';
import '../domain/widget_data.dart';
import '../l10n/app_localizations.dart';
import '../l10n/template_text.dart';

/// Schreibt die Widget-Daten und stößt das Neuzeichnen des Android-Widgets an.
class HomeWidgetUpdater implements WidgetUpdater {
  const HomeWidgetUpdater(this._texts);

  /// Sprachpakete in der gewählten Sprache (Titel der Katalog-Vorlagen).
  final Future<AppLocalizations> Function() _texts;

  static const _provider = 'de.maestrodev.challenges.RitualWidgetProvider';

  @override
  Future<void> update(List<ActiveChallenge> active, DateTime today) async {
    final l10n = await _texts();
    final entries =
        widgetEntries(active, today, titleOf: (t) => t.titleIn(l10n));
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
