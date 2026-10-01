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
- Welche Story als Nächstes umgesetzt wird, entscheidet der Nutzer; ohne Vorgabe die
  nächste `ready`-Story laut Reihenfolge im Epic.

## Epics: Konvention (Entscheidung Nutzer, 30.09./01.10.)

Grundlage: Recherche zu Jira, Azure DevOps, Linear, SAFe, Shape Up und GitHub –
überall gilt: Ein Epic ist ein **endliches Vorhaben**, dauerhafte Themen liegen
eine Ebene darüber.

- **Epics sind endlich.** Ein Epic beschreibt ein Ergebnis (Titel ergebnisbezogen,
  nie „… II“ oder Nummern) und wird geschlossen, sobald alle Stories geschlossen sind.
  Im Abschlusskommentar stehen ggf. Folge-Epics zum selben Thema.
- **Geschlossen bleibt geschlossen.** Claude öffnet **nie** ein geschlossenes Issue
  wieder – weder Epic noch Story noch Task. Neue Arbeit zu etwas Erledigtem wird ein
  **neues** Issue mit „Bezug: #nr“.
- **Neue Ideen** werden `backlog`-Story in einem **offenen** Epic, das genau dieses Ziel
  verfolgt. Gibt es keins, legt Claude **sofort ein neues Epic** an (ohne Rückfrage, um
  nicht zu blockieren) und trägt es in `STAND.md` unter „Offene Entscheidungen“ als
  „neu angelegt – bitte bestätigen oder umsortieren“ ein.
- **Keine Stories ohne Epic** – jede Story hat genau ein Epic als Parent.
- **Themen-Ebene darüber:** Gibt es mehr als 10 offene Epics oder überschneiden sich
  zwei Epics inhaltlich deutlich, schlägt Claude dem Nutzer eine Themen-Ebene vor;
  eingeführt wird sie nur mit seiner Zustimmung.

## Stand pflegen (`STAND.md`)

`STAND.md` ist die Kurzfassung des Projektstands. Der Nutzer liest sie in einem
Claude-Projekt als Kontext. Sie muss immer zu den Issues passen.

- Claude aktualisiert `STAND.md`, sobald sich etwas davon ändert: Story wechselt
  den Status (`backlog`/`ready`/`in-progress`) oder wird geschlossen, neue Story
  oder neues Epic, Reihenfolge ändert sich, Entscheidung getroffen.
- Inhalt: In Arbeit · Als Nächstes · Backlog nach Epic · Zuletzt erledigt
  (höchstens 5, neueste oben) · Offene Entscheidungen · Datum „Zuletzt aktualisiert“.
- Beim Schließen einer Story gehört die Änderung in den letzten PR der Story.
  Reine Statusänderungen ohne PR: direkter Commit auf `main`
  (`docs: Stand aktualisieren`).
- Kurz halten: Nummer + Titel, keine Task-Details.

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
- Läuft für den PR der Workflow **Smoke** (Release-APK auf Android-Emulator
  starten, frisch und als Update), muss auch er grün sein. Epic-Branches
  werden erst nach grünem Smoke und Test durch den Nutzer nach `main` gemergt.
- Kein direkter Push auf `main` außer für Repo-Infrastruktur (CI, diese Datei,
  `STAND.md`).
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
- UI-Texte in drei Sprachen (DE/EN/RU) über ARB-Sprachpakete und Flutters `gen-l10n`
  (einzige erlaubte Code-Generierung, siehe Skill Abschnitt 4a).

## Umgebungshinweis

In Claudes Cloud-Umgebung ist Flutter nicht installierbar (Download-Server
gesperrt). Tests laufen daher über **GitHub Actions** (`.github/workflows/ci.yml`);
Ergebnisse werden über die GitHub-API abgefragt.

## Offene Entscheidungen (nur der Nutzer entscheidet)

- Backend für „Challenges mit Freunden“ (z. B. Firebase, Supabase).
