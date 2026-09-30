import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// Kurzer Zugriff auf die Sprachpakete: `context.l10n.navToday`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
