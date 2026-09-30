# Stand

Aktueller Projektstand für Planung und Claude-Projekte. Wird von Claude
nach jeder Statusänderung gepflegt (siehe CLAUDE.md, Abschnitt „Stand pflegen“).
Maßgeblich sind die GitHub-Issues; diese Datei ist die Kurzfassung.

**Zuletzt aktualisiert:** 2026-09-30

## In Arbeit

- #78 Profil und Einstellungen (Epic #80) – Branch `epic/profil-einstellungen`, alle Tasks
  erledigt (#99, #100, #101, #102). Wartet auf: Test der APK (Release „test“) durch den
  Nutzer, dann Merge nach `main`.
  Entscheidungen: eigener Tab „Profil“, Einstellungen über Zahnrad; „Daten sichern“ nur
  noch in den Einstellungen.

## Als Nächstes

- Nach Merge von #78: #79 Sprache wählbar (DE/EN/RU) – Entscheidung zu gen-l10n nötig

## Backlog nach Epic

| Epic | Stories (Reihenfolge) |
|---|---|
| #36 Motivation und Dranbleiben | #33 Fortschrittsfotos → #82 Dashboard und Kennzahlen |
| #80 Profil und Einstellungen | #78 Profil und Einstellungen (in Arbeit) → #79 Sprache wählbar (DE/EN/RU) |
| #104 Planen und Vorbereiten | #103 Startdatum planen |
| #38 Gemeinsam | #34 Challenges mit Partnerin/Freunden – erst nach Backend-Entscheidung |

## Zuletzt erledigt

- #32 Backup und Export – Sichern, CSV, Wiederherstellen, Seite „Daten sichern“ (PR #98)
- #94 Startabsturz der Release-APK behoben (R8-Regel für WorkManager) +
  Emulator-Starttest „Smoke“ in der CI (PR #95)
- #25 Dranbleiben – Detailansicht, Timer, Countdown, Checkliste, Widget, Meilensteine
- #76 Laufende Challenge anpassen (PR #81)
- #65 Feinschliff – Wochentage, passende Regeln, Archiv-Menü

## Offene Entscheidungen (nur der Nutzer)

- Backend für „Gemeinsam“ (z. B. Firebase, Supabase)
