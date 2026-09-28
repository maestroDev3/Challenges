# Challenges – Arbeitsweise für Claude

Flutter-App (Android) für persönliche Challenges, später mit Freunden.
Claude arbeitet in diesem Repo **autonom**. Diese Datei ist verbindlich.

## Struktur: Epic → Story → Task

Alles lebt in GitHub-Issues, verknüpft über Sub-Issues:

| Ebene | Label | Inhalt |
|---|---|---|
| Epic | `epic` | Großes Ziel; Stories als Sub-Issues, Reihenfolge in der Beschreibung |
| Story | `story` | Für den Nutzer sichtbares Feature; Tasks als Sub-Issues |
| Task | `task` | Genau ein PR, TDD, testbare Akzeptanzkriterien |

Status einer Story (Label, genau eins; erledigt = geschlossen):
- `backlog` – Idee, grob beschrieben, **noch keine Tasks**
- `ready` – verfeinert, Tasks mit Akzeptanzkriterien stehen
- `in-progress` – wird gerade umgesetzt (immer nur eine Story gleichzeitig)

Regeln:
- Tasks werden erst geschrieben, wenn eine Story von `backlog` nach `ready` wechselt.
- Neue Ideen des Nutzers landen als `backlog`-Story im passenden Epic.
- Welche Story als Nächstes umgesetzt wird, entscheidet der Nutzer; ohne Vorgabe die
  nächste `ready`-Story laut Reihenfolge im Epic.

## Workflow: Story → Sub-Issues

1. Jede fachliche Anforderung ist eine **Story** (Issue mit Label `story`).
2. Die Story wird in **Sub-Issues** (Label `task`) zerlegt, verknüpft über die
   GitHub-Sub-Issue-Funktion. Jedes Sub-Issue ist klein genug für einen PR und
   enthält **Akzeptanzkriterien als testbare Aussagen**.
3. Unabhängige Sub-Issues dürfen parallel (Subagents) bearbeitet werden.
   Abhängigkeiten stehen im Issue unter „Abhängig von“.
4. Die Story wird geschlossen, wenn alle Sub-Issues geschlossen sind.

## TDD pro Sub-Issue (Pflicht)

1. Branch `task/<issue-nr>-<kurzname>` von aktuellem `main`.
2. **Rot:** Zuerst Tests für die Akzeptanzkriterien schreiben, committen
   (`test: … (#nr)`), pushen. Die CI muss wegen dieser Tests fehlschlagen.
3. **Grün:** Minimalen Code schreiben, bis `flutter test` grün ist (`feat: … (#nr)`).
4. **Refactor:** Aufräumen, Tests bleiben grün (`refactor: … (#nr)`).
5. PR mit `Closes #nr` im Text. Beschreibung: was, warum, welche Tests.

## Mergen

- Claude darf PRs **selbst per Squash nach `main` mergen**, sobald die CI
  (analyze + test) grün ist. Nie mit roter oder laufender CI mergen.
- Kein direkter Push auf `main` außer für Repo-Infrastruktur (CI, diese Datei).
- Nach dem Merge Branch löschen.

## Technik

**Verbindlich:** Vor jeder Arbeit an `.dart`-Dateien, Tests, `pubspec.yaml` oder
Android-Konfiguration den Skill `.claude/skills/flutter-dart/SKILL.md` laden und
befolgen (Architektur, State, Stil, Widgets, Tests, Definition of Done).

- Flutter (stable), Dart, nur Android als Zielplattform.
- Struktur: `lib/domain` (reine Dart-Logik, keine Flutter-Imports),
  `lib/data` (Repositories, Persistenz), `lib/ui` (Screens, Widgets).
- Domänenlogik ist reines Dart und wird mit Unit-Tests abgedeckt;
  UI mit Widget-Tests. Zeit wird immer über eine injizierbare `Clock`
  übergeben, nie `DateTime.now()` direkt in der Logik.
- Datenzugriff nur über Repository-Interfaces, damit später ein Backend
  (Freunde-Funktion) angedockt werden kann.
- `flutter analyze` muss ohne Befund laufen.

## Umgebungshinweis

In Claudes Cloud-Umgebung ist Flutter nicht installierbar (Download-Server
gesperrt). Tests laufen daher über **GitHub Actions** (`.github/workflows/ci.yml`);
Ergebnisse werden über die GitHub-API abgefragt.

## Offene Entscheidungen (nur der Nutzer entscheidet)

- Backend für „Challenges mit Freunden“ (z. B. Firebase, Supabase).
