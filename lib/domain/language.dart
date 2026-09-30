/// Sprachen, in die die App übersetzt ist; die erste ist der Rückfall.
const supportedLanguages = ['de', 'en', 'ru'];

/// Name jeder Sprache in ihr selbst – so findet man sie auch, wenn man die
/// aktuelle Oberfläche nicht lesen kann.
const languageNames = {'de': 'Deutsch', 'en': 'English', 'ru': 'Русский'};

/// Welche Sprache die App zeigt: die gewählte, sonst die erste unterstützte
/// Systemsprache, sonst Deutsch.
String resolveLanguage(String? chosen, List<String> systemLanguages) {
  if (chosen != null && supportedLanguages.contains(chosen)) return chosen;
  for (final language in systemLanguages) {
    if (supportedLanguages.contains(language)) return language;
  }
  return supportedLanguages.first;
}
