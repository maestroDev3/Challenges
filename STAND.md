# Stand

Aktueller Projektstand für Planung und Claude-Projekte. Wird von Claude
nach jeder Statusänderung gepflegt (siehe CLAUDE.md, Abschnitt „Stand pflegen“).
Maßgeblich sind die GitHub-Issues; diese Datei ist die Kurzfassung.

**Zuletzt aktualisiert:** 2026-10-01

## In Arbeit

- #103 Startdatum planen (Epic #104) – Branch `epic/planen`, alle Tasks erledigt
  (#126, #127, #128). Wartet auf: Test der APK (Release „test“) durch den Nutzer,
  dann Merge nach `main`.
  Entscheidungen: „geplant“ = `startedOn` in der Zukunft (kein neuer Status);
  eigener Abschnitt „Geplant“ auf „Heute“.

## Als Nächstes

- Nach Merge von #103: #124 Wenn-Dann-Plan (Epic #104) oder Story nach Wahl des Nutzers

## Backlog nach Initiative → Epic

**#139 Dranbleiben**

| Epic | Stand | Stories (Reihenfolge) |
|---|---|---|
| #104 Planen und Vorbereiten | 0 von 2 zu | #103 Startdatum planen (in Arbeit) → #124 Wenn-Dann-Plan |
| #36 Motivation und Dranbleiben | 1 von 5 zu | #33 Fortschrittsfotos → #82 Dashboard und Kennzahlen → #134 Wochenrückblick → #135 Warnung vor dem Serienende |

**#138 Challenges gestalten**

| Epic | Stand | Stories (Reihenfolge) |
|---|---|---|
| #137 Programme | 0 von 1 zu | #136 Challenge-Programme (z. B. 75 Hard) |

**#141 Gemeinsam**

| Epic | Stand | Stories (Reihenfolge) |
|---|---|---|
| #38 Gemeinsam | 0 von 1 zu | #34 Challenges mit Partnerin/Freunden – erst nach Backend-Entscheidung |

**Ruht**

- #140 App und Daten – alle Epics erledigt (#49 Marke, #37 Daten sichern, #80 Profil und Einstellungen)

## Zuletzt erledigt

- #79 Sprache wählbar – Deutsch, Englisch, Russisch (PR #123)
- #78 Profil und Einstellungen – Tab „Profil“, Einstellungen, Daten sichern umgezogen (PR #109)
- #32 Backup und Export – Sichern, CSV, Wiederherstellen, Seite „Daten sichern“ (PR #98)
- #94 Startabsturz der Release-APK behoben (R8-Regel für WorkManager) +
  Emulator-Starttest „Smoke“ in der CI (PR #95)
- #25 Dranbleiben – Detailansicht, Timer, Countdown, Checkliste, Widget, Meilensteine

## Offene Entscheidungen (nur der Nutzer)

- #140 App und Daten: alle Epics erledigt, „Fertig, wenn“ erfüllt – schließen oder ruhen lassen?
- Backend für „Gemeinsam“ (z. B. Firebase, Supabase)
