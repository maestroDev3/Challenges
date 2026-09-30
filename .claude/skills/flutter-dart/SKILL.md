---
name: flutter-dart
description: Verbindliche Flutter/Dart-Konventionen für die Challenges-App (Architektur, State, Dart-Stil, Widgets, Tests, Definition of Done). Verwenden bei jedem Anlegen oder Ändern von .dart-Dateien, Tests, pubspec.yaml oder Android-Konfiguration in diesem Repo.
---

# Flutter/Dart – Konventionen für Challenges

Quellen: letztes offizielles Flutter-`rules.md` (Flutter 3.38), Effective Dart,
Flutter App Architecture Guide, VGV-Skills. Hier steht nur, was für dieses
Projekt gilt oder bewusst abweicht. Bei Konflikt gilt: Nutzer > CLAUDE.md > dieser Skill.

## 1. Architektur (Schichten)

| Ordner | Inhalt | Darf importieren |
|---|---|---|
| `lib/domain` | Modelle, reine Logik, Repository-**Interfaces** | nur `dart:` und `lib/domain` – **kein** `package:flutter` |
| `lib/data` | Repository-Implementierungen, Plattform-Services (Speicher, Benachrichtigungen, Widget) | `lib/domain`, Pakete |
| `lib/ui` | Screens und Widgets | `lib/domain`, `package:flutter` – **nie** `lib/data` direkt |
| `lib/main.dart` | Verdrahtung: Instanzen erzeugen, per Konstruktor übergeben | alles |

- Repositories sind die einzige Datenquelle; sie liefern `Future`/`Stream` und kennen sich nicht gegenseitig.
- Plattform-APIs (Plugins) nur hinter einem Interface in `lib/domain` (z. B. `ReminderScheduler`), Implementierung in `lib/data`.
- Zeit kommt immer über `Clock` (`typedef Clock = DateTime Function()`) bzw. einen `today`/`now`-Parameter. Kein `DateTime.now()` in `lib/domain` oder in Widgets außer als Default-Argument `clock = DateTime.now`.
- Tage werden mit `dayOf()` normalisiert (UTC-Mitternacht), damit Sommerzeit keine Tage verschiebt.

## 2. State

- Kein State-Management-Paket (kein provider/riverpod/bloc/get_it), keine Code-Generierung (kein freezed/build_runner), Navigation mit `Navigator` (kein go_router).
  **Einzige Ausnahme:** Flutters eingebautes `gen-l10n` für die Sprachpakete (Entscheidung Nutzer, #79).
- Daten anzeigen: `StreamBuilder` über Repository-Streams. Lokaler UI-Zustand: `StatefulWidget` oder `ValueNotifier`.
- Wächst Logik in einem Widget über ein paar Zeilen, gehört sie als reine Funktion/Klasse nach `lib/domain` (testbar ohne Widget).
- Nach jedem `await` in einem `State` vor `setState`/`context` auf `mounted` prüfen.

## 3. Dart-Stil

- Namen: Typen `UpperCamelCase`, Dateien `lower_snake_case.dart`, sonst `lowerCamelCase` (auch Konstanten). Keine Abkürzungen.
- **Bezeichner Englisch, Kommentare Deutsch.** UI-Texte stehen in den Sprachpaketen (siehe Abschnitt 4a), Deutsch ist die Vorlage. Doc-Kommentare `///` beginnen mit einem Satz, der das *Warum*/den Zweck nennt.
- Domänenmodelle sind unveränderlich: `final`-Felder, `const`-Konstruktor wo möglich, Änderungen über `copyWith`/Methoden, die eine neue Instanz liefern.
- Varianten als `sealed class` + exhaustives `switch` (Beispiel: `ChallengeKind`). Mehrere Rückgabewerte als Record.
- Kein `!` auf Werten, die null sein können – Pattern (`case final x?`) oder frühes `return`.
- Keine positionalen `bool`-Parameter; benannte Parameter.
- Ungültige Eingaben in der Domäne: `ArgumentError`; Zustandsfehler: `StateError`. Nie still schlucken.
- Imports: `dart:` → `package:` → relativ; innerhalb von `lib/` relative Imports, in Tests `package:challenges/...`.
- Formatierung entscheidet `dart format`; `flutter analyze` (flutter_lints) muss ohne Befund sein.

## 4. Widgets und Design

- Teil-UIs als kleine private Widget-Klassen (`_WeekRow`), keine Methoden, die Widgets zurückgeben (Ausnahme: kurze `switch`-Ausdrücke).
- `const` wo möglich; nichts Teures in `build()`; Listen mit `ListView.builder`/`SliverList.builder`.
- Farben und Textstile nur aus `Theme.of(context)` (`colorScheme`, `textTheme`) – keine Hex-Werte in Widgets. Theme in `lib/ui/theme.dart`.
- Material 3; Muster der App wiederverwenden: Karten (`Card`), `SliverAppBar.large`, Bottom Sheets mit `showDragHandle`, `FilledButton`/`OutlinedButton`, Emoji-Badges (`EmojiBadge`).
- Icon-Buttons bekommen `tooltip` (dient auch als Semantics-Label).
- Texte müssen bei großer Systemschrift umbrechen dürfen (kein festes `height` für Textcontainer).

## 4a. Sprachen (DE/EN/RU)

- Jeder sichtbare Text kommt aus `lib/l10n/app_de.arb` (Vorlage) plus `app_en.arb` und `app_ru.arb`; Zugriff im Widget über `context.l10n.<schlüssel>` (`lib/ui/l10n.dart`).
- Neuer Text = Schlüssel in **allen drei** ARB-Dateien, deutsche Datei mit `@schlüssel.description`. Schlüssel `lowerCamelCase` nach Ort (`settingsLanguage`, `todayEmpty`).
- Mehrzahl immer als ICU-Plural (`{count, plural, one{…} few{…} many{…} other{…}}`) – Russisch braucht `one/few/many`.
- `lib/domain` bleibt ohne Übersetzung: Domänentexte (Katalog, Arten) werden in der UI über ID/Typ übersetzt.
- Erzeugte Dateien (`lib/l10n/app_localizations*.dart`) sind nicht eingecheckt; die CI ruft `flutter gen-l10n` auf.
- Ausnahme: der Leitsatz „Sacrifice the moment. Evolve the future.“ bleibt in allen Sprachen Englisch.

## 5. Tests (TDD ist Pflicht, siehe CLAUDE.md)

- Struktur spiegelt `lib/`: `test/domain`, `test/data`, `test/ui`. Test-Hilfen in `test/support/` (kein `_test.dart`-Suffix).
- Fakes statt Mocks (kein mockito/mocktail): `FakeChallengeRepository`, `FakeReminderScheduler`. Neue Interfaces bekommen einen Fake in `test/support/`.
- Feste Zeiten: Tests definieren `today`/`now` als Konstante und übergeben sie; nie von der echten Uhr abhängen.
- Aufbau: `group` pro Klasse/Funktion bzw. Verhalten, `test`-Beschreibung als deutscher Satz („Joker hält die Streak“). Arrange – Act – Assert.
- Widget-Tests: `pumpApp` aus `test/support/pump_app.dart` (setzt Theme, Handy-Größe und Sprache – Standard Deutsch, `locale:` für EN/RU); Tests der ganzen App rufen vorher `useGermanDevice(tester)`; Finder über sichtbaren Text oder `Key`, nicht über Widget-Hierarchie.
- Jedes Akzeptanzkriterium des Issues hat mindestens einen Test. Plattform-Code, der nur auf dem Gerät prüfbar ist, bekommt einen Hinweis „manuell testen“ im PR.

## 6. Abhängigkeiten und Android

- Neue Pakete nur mit Begründung im PR; Version vorher prüfen (`git ls-remote --tags` des Paket-Repos, pub.dev ist in Claudes Umgebung gesperrt).
- Android-Änderungen (Manifest, Gradle, Plugins mit nativem Code) im Commit mit `[apk]` markieren, damit die CI die APK auf dem Branch baut.
- Keine Berechtigung ohne Nutzen; jede neue Berechtigung im PR begründen. Kein `INTERNET`, solange es kein Backend gibt.

## 7. Definition of Done (pro Task)

- [ ] Test-Commit rot in der CI, danach grün
- [ ] `flutter analyze` ohne Befund, `dart format`-konform
- [ ] Domäne ohne Flutter-Import, Zeit über Clock/Parameter
- [ ] Gespeicherte Daten abwärtskompatibel (alte Daten laden weiter – Migrationstest)
- [ ] UI-Texte Deutsch, Theme-Farben, Tooltips an Icon-Buttons
- [ ] PR mit `Closes #nr`, Was/Warum/Tests

## 8. Typische Fehler

| Nicht so | Sondern so |
|---|---|
| `DateTime.now()` in Logik | `clock()` / `today`-Parameter |
| Logik in `build()` oder `onPressed` | reine Funktion in `lib/domain` |
| `setState` nach `await` ohne `mounted` | `if (!mounted) return;` |
| Widget importiert `lib/data/...` | Interface aus `lib/domain` per Konstruktor |
| `print` zum Debuggen | Test schreiben; Fehler als Exception |
| Neues Speicherformat ohne Migration | Schlüssel versionieren, alten lesen, Test dafür |
| `Color(0xFF…)` im Widget | `Theme.of(context).colorScheme…` |
