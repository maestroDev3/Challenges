# Stand

Aktueller Projektstand für Planung und Claude-Projekte. Wird von Claude
nach jeder Statusänderung gepflegt (siehe CLAUDE.md, Abschnitt „Stand pflegen“).
Maßgeblich sind die GitHub-Issues; diese Datei ist die Kurzfassung.

**Zuletzt aktualisiert:** 2026-09-29

## In Arbeit

- #32 Backup und Export (Epic #37) – Branch `epic/daten-sichern` (basiert noch auf
  dem Stand vor der Absturz-Behebung → vor dem Weiterarbeiten `main` hineinmergen).
  Erledigt im Branch: #83 Codec/Backup-Format, #84 CSV, #86 Datei-Kanal, #88 Auto-Backup.
  Offen: #85 Wiederherstellen (Branch `task/85-restore`, grün, PR fehlt),
  #87 Seite „Daten sichern“ (Branch `task/87-backup-screen`, nur rote Tests).
  Entscheidungen: Wiederherstellen ersetzt alles; vorläufig ⋮ auf „Heute“, zieht mit #78 um.

## Als Nächstes

- #32 fertigstellen, APK vom Epic-Branch bauen, Nutzer testet, dann Merge nach `main`

## Backlog nach Epic

| Epic | Stories (Reihenfolge) |
|---|---|
| #36 Motivation und Dranbleiben | #33 Fortschrittsfotos → #82 Dashboard und Kennzahlen |
| #37 Daten sichern | #32 Backup und Export (in Arbeit) |
| #80 Profil und Einstellungen | #78 Profil und Einstellungen → #79 Sprache wählbar (DE/EN/RU) |
| #104 Planen und Vorbereiten | #103 Startdatum planen |
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
