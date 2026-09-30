# Stand

Aktueller Projektstand für Planung und Claude-Projekte. Wird von Claude
nach jeder Statusänderung gepflegt (siehe CLAUDE.md, Abschnitt „Stand pflegen“).
Maßgeblich sind die GitHub-Issues; diese Datei ist die Kurzfassung.

**Zuletzt aktualisiert:** 2026-09-30

## In Arbeit

- #79 Sprache wählbar – Deutsch, Englisch, Russisch (Epic #80) – Branch `epic/sprache`,
  alle Tasks erledigt (#111–#116). Wartet auf: Test der APK (Release „test“) durch den
  Nutzer, dann Merge nach `main`.
  Entscheidung: ARB-Sprachpakete mit Flutters `gen-l10n` (einzige erlaubte Codegen).

## Als Nächstes

- Nach Merge von #79: nächste Story nach Wahl des Nutzers

## Backlog nach Epic

| Epic | Stories (Reihenfolge) |
|---|---|
| #36 Motivation und Dranbleiben | #33 Fortschrittsfotos → #82 Dashboard und Kennzahlen |
| #80 Profil und Einstellungen | #79 Sprache wählbar (DE/EN/RU) (in Arbeit) |
| #104 Planen und Vorbereiten | #103 Startdatum planen |
| #38 Gemeinsam | #34 Challenges mit Partnerin/Freunden – erst nach Backend-Entscheidung |

## Zuletzt erledigt

- #78 Profil und Einstellungen – Tab „Profil“, Einstellungen, Daten sichern umgezogen (PR #109)
- #32 Backup und Export – Sichern, CSV, Wiederherstellen, Seite „Daten sichern“ (PR #98)
- #94 Startabsturz der Release-APK behoben (R8-Regel für WorkManager) +
  Emulator-Starttest „Smoke“ in der CI (PR #95)
- #25 Dranbleiben – Detailansicht, Timer, Countdown, Checkliste, Widget, Meilensteine
- #76 Laufende Challenge anpassen (PR #81)

## Offene Entscheidungen (nur der Nutzer)

- Backend für „Gemeinsam“ (z. B. Firebase, Supabase)
