# Stand

Aktueller Projektstand für Planung und Claude-Projekte. Wird von Claude
nach jeder Statusänderung gepflegt (siehe CLAUDE.md, Abschnitt „Stand pflegen“).
Maßgeblich sind die GitHub-Issues; diese Datei ist die Kurzfassung.

**Zuletzt aktualisiert:** 2026-09-29

## In Arbeit

- #32 Backup und Export (Epic #37) – Branch `epic/daten-sichern`, alle Tasks erledigt
  (#83, #84, #85, #86, #87, #88), `main` ist eingemergt.
  Wartet auf: grünen Smoke, Test der APK durch den Nutzer, dann Merge nach `main`.
  Entscheidungen: Wiederherstellen ersetzt alles; vorläufig ⋮ auf „Heute“, zieht mit #78 um.

## Als Nächstes

- Nach Merge von #32: nächste Story nach Wahl des Nutzers (Vorschlag: #78 Profil und Einstellungen)

## Backlog nach Epic

| Epic | Stories (Reihenfolge) |
|---|---|
| #36 Motivation und Dranbleiben | #33 Fortschrittsfotos → #82 Dashboard und Kennzahlen |
| #37 Daten sichern | #32 Backup und Export (in Arbeit) |
| #80 Profil und Einstellungen | #78 Profil und Einstellungen → #79 Sprache wählbar (DE/EN/RU) |
| #38 Gemeinsam | #34 Challenges mit Partnerin/Freunden – erst nach Backend-Entscheidung |

## Zuletzt erledigt

- #94 Startabsturz der Release-APK behoben (R8-Regel für WorkManager) +
  Emulator-Starttest „Smoke“ in der CI (PR #95)
- #25 Dranbleiben – Detailansicht, Timer, Countdown, Checkliste, Widget, Meilensteine
- #76 Laufende Challenge anpassen (PR #81)
- #65 Feinschliff – Wochentage, passende Regeln, Archiv-Menü
- #45 Marke „Ritual“ – App-Icon, Startbildschirm, Farbwelt

## Offene Entscheidungen (nur der Nutzer)

- Backend für „Gemeinsam“ (z. B. Firebase, Supabase)
- Epic #35 „Challenges selbst gestalten“: alle Stories erledigt – schließen
  oder um neue Stories erweitern?
