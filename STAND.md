# Stand

Aktueller Projektstand für Planung und Claude-Projekte. Wird von Claude
nach jeder Statusänderung gepflegt (siehe CLAUDE.md, Abschnitt „Stand pflegen“).
Maßgeblich sind die GitHub-Issues; diese Datei ist die Kurzfassung.

**Zuletzt aktualisiert:** 2026-09-29

## In Arbeit

- **Dringend:** App stürzt nach dem Dranbleiben-Merge beim Start ab. `main` ist
  vorläufig auf den Stand vor #64 zurückgesetzt; Ursache wird per
  Emulator-Starttest in der CI gesucht, danach kommt Dranbleiben (#25) wieder.
- #32 Backup und Export (Epic #37) – pausiert bis zur Absturz-Behebung;
  Branch `epic/daten-sichern`, Tasks #83–#88

## Als Nächstes

- #25 Dranbleiben erneut mergen, sobald der Absturz behoben und auf dem Handy getestet ist

## Backlog nach Epic

| Epic | Stories (Reihenfolge) |
|---|---|
| #36 Motivation und Dranbleiben | #33 Fortschrittsfotos → #82 Dashboard und Kennzahlen |
| #37 Daten sichern | #32 Backup und Export (in Arbeit) |
| #80 Profil und Einstellungen | #78 Profil und Einstellungen → #79 Sprache wählbar (DE/EN/RU) |
| #38 Gemeinsam | #34 Challenges mit Partnerin/Freunden – erst nach Backend-Entscheidung |

## Zuletzt erledigt

- #76 Laufende Challenge anpassen (PR #81)
- #65 Feinschliff – Wochentage, passende Regeln, Archiv-Menü
- #45 Marke „Ritual“ – App-Icon, Startbildschirm, Farbwelt

## Offene Entscheidungen (nur der Nutzer)

- Backend für „Gemeinsam“ (z. B. Firebase, Supabase)
- Epic #35 „Challenges selbst gestalten“: alle Stories erledigt – schließen
  oder um neue Stories erweitern?
