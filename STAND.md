# Stand

Aktueller Projektstand für Planung und Claude-Projekte. Wird von Claude
nach jeder Statusänderung gepflegt (siehe CLAUDE.md, Abschnitt „Stand pflegen“).
Maßgeblich sind die GitHub-Issues; diese Datei ist die Kurzfassung.

**Zuletzt aktualisiert:** 2026-10-06

## In Arbeit

- #135 Abendliche Warnung vor dem Serienende (Epic #36) – Branch
  `epic/warnung` (von `epic/statistik`). Entscheidungen 06.10.: nur ab
  Serie ≥ 3, keine Zeile auf Heute, Regel Hart ohne eigenen Text.
- Warten auf Merge durch den Nutzer: PR #150 (#124 Wenn-Dann-Plan, getestet)
  und PR #170 (#134 Wochenrückblick + #82 Dashboard, Test-APK „test“).
  Reihenfolge: #150 → #170 → danach `epic/warnung`.

## Als Nächstes

- #33 Fortschrittsfotos (Epic #36) oder Story nach Wahl des Nutzers

## Backlog nach Initiative → Epic

**#139 Dranbleiben**

| Epic | Stand | Stories (Reihenfolge) |
|---|---|---|
| #104 Planen und Vorbereiten | 1 von 2 zu | #124 Wenn-Dann-Plan (in Arbeit) |
| #36 Motivation und Dranbleiben | 1 von 7 zu | #134 Wochenrückblick (in Arbeit) → #82 Dashboard und Kennzahlen (in Arbeit) → #135 Warnung vor dem Serienende (in Arbeit) → #33 Fortschrittsfotos → #160 Check-in-Uhrzeit |

**#138 Challenges gestalten**

| Epic | Stand | Stories (Reihenfolge) |
|---|---|---|
| #137 Programme | 0 von 1 zu | #136 Challenge-Programme (z. B. 75 Hard) |
| #161 Fehltag-Regeln für alle Arten | 0 von 1 zu | #162 Regel „Hart“ für fortlaufende Challenges |

**#140 App und Daten**

| Epic | Stand | Stories (Reihenfolge) |
|---|---|---|
| #142 App startet immer | 0 von 1 zu | #143 Start übersteht unerwartete Daten und Fehler |
| #151 Technik und Qualität | 0 von 1 zu | #152 Smoke-Test prüft bis zum Heute-Screen |

**#141 Gemeinsam**

| Epic | Stand | Stories (Reihenfolge) |
|---|---|---|
| #38 Gemeinsam | 0 von 1 zu | #34 Challenges mit Partnerin/Freunden – erst nach Backend-Entscheidung |

## Zuletzt erledigt

- #103 Startdatum planen – Starttag in der Zukunft, Abschnitt „Geplant“ (PR #133)
- #79 Sprache wählbar – Deutsch, Englisch, Russisch (PR #123)
- #78 Profil und Einstellungen – Tab „Profil“, Einstellungen, Daten sichern umgezogen (PR #109)
- #32 Backup und Export – Sichern, CSV, Wiederherstellen, Seite „Daten sichern“ (PR #98)
- #94 Startabsturz der Release-APK behoben (R8-Regel für WorkManager) +
  Emulator-Starttest „Smoke“ in der CI (PR #95)

## Offene Entscheidungen (nur der Nutzer)

- #161 Fehltag-Regeln für alle Arten (Epic in #138): neu angelegt – bitte bestätigen oder umsortieren
- #142 App startet immer (Epic in #140): neu angelegt – bitte bestätigen oder umsortieren
- #151 Technik und Qualität (Epic in #140): neu angelegt – bitte bestätigen oder
  umsortieren. Der Nutzer wünscht ein dauerhaftes Sammelbecken für Technik-Themen;
  laut Konvention sind Epics endlich. Alternative: eigene Initiative „Technik und
  Qualität“ mit Epics je Vorhaben.
- Backend für „Gemeinsam“ (z. B. Firebase, Supabase)
