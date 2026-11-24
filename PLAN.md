# Plan & Stand: „The Guild Registrar“

Stand: 2026-11-24 · Status: **v0.3.1 veröffentlicht (GitHub), bereit für Tests**

## Ziel

Öffentlich verteilbares Addon für **WoW: Forever** (CurseForge + GitHub), das die Discord-Mitgliederliste (Anzeigenamen + Rollen) mit der Gildenliste (Charaktername, öffentliche Notiz, Offiziersnotiz) abgleicht, die Zuordnungen in Stufen einteilt (eindeutig / wahrscheinlich / unwahrscheinlich / nicht zugewiesen), fehlende Mitglieder auf beiden Seiten zeigt und Discord-Rollen gegen Gildenränge prüft. Filterbare Liste, damit Offiziere gezielt Leute ansprechen können.

## Getroffene Entscheidungen

| # | Thema | Entscheidung |
|---|---|---|
| 1 | Discord-Namen | Optionale Namensregel (Trennzeichen + Reihenfolge `Spitzname \| Main`, `Main \| Spitzname`, beliebig). Ohne Regel funktioniert alles. Verstöße/vertauschte Teile → Hinweis. |
| 2 | Notizen | Inhalte wie Name, Rolle, Klasse, Beruf → umfangreiche, editierbare Liste ignorierter Wörter (DE+EN). |
| 3 | Notizquellen | Öffentliche Notiz und Offiziersnotiz, einzeln abschaltbar. |
| 4 | Notizen schreiben | Nur lesen; Schreiben nur per Klick + Bestätigung, öffentliche und/oder Offiziersnotiz wählbar, Anhängen/Ersetzen, Vorschau. |
| 5 | Twinks | Erkennung über Twink-Ränge (einstellbar) und/oder Notiz-Muster (einstellbar); werden dem Discord-Mitglied des Mains zugeordnet. |
| 6 | Twinks & Ränge | Werden wie der Main geprüft; Option „Twink-Ränge sind für Twinks in Ordnung“ (Standard an). |
| 7 | Rang-Abgleich | Mapping Discord-Rolle → Gildenrang; höchste Rolle nach Discord-Reihenfolge zählt. |
| 8 | Gäste | Gast-Rollen einstellbar (Standard: Gast, Gäste, Guest, Guests, Besucher, Visitor); werden gelistet, aber standardmäßig ausgefiltert. |
| 9 | Hilfsprogramm „Peasant“ (früher „Companion“) | Go, keine Fremdabhängigkeiten, lokale Weboberfläche im Browser. |
| 10 | VS-Projekt | Entfernt (`.vs/` war noch von Visual Studio gesperrt → manuell löschen). |
| 11 | GitHub | Konto `Flotomat`, Repository `TheGuildRegistrar`. |
| 12 | Lizenz | GPL-3.0-or-later. |
| 13 | Signierung | Keine; Hinweise für SmartScreen/Gatekeeper in Anleitung + README im Download. |
| 14 | Name | „The Guild Registrar“ (Ordner/TOC `TheGuildRegistrar`, Befehl `/tgr`). |
| 15 | Plattformen | CurseForge + GitHub. |
| 16 | Sprachen | Englisch (Basis) + Deutsch, Locale-System für weitere Sprachen. |

## Architektur

```
Discord-Server ──(eigener Bot, REST, nur lesen)──> Peasant (lokal, Browser-UI)
                                                      │ Text im Format TGR1 → Zwischenablage
                                                      ▼
WoW: Forever ── /tgr → Import ── Abgleich ── Ergebnisliste / Ränge / Notizen
```

- **Addon (Repository-Wurzel)**: `Locales/`, `Core/` (Defaults, DB, Engine, Demo, Init), `Data/` (Import-Parser, Roster, Notizen), `Matching/` (Text-Normalisierung, Ähnlichkeit, Twink-Gruppierung, Matcher, Rang-Check – reines Lua 5.1), `UI/` (eigene Widgets ohne veraltete Dropdown-APIs).
- **Peasant (`peasant/`)**: Discord-REST-Client, Export, Token-Speicherung (Windows DPAPI / macOS Keychain / Linux 0600-Datei), lokaler Webserver auf 127.0.0.1 mit Zufallsschlüssel und Host-Prüfung.
- **Releases**: automatisch bei jedem Push auf `main` – Version aus den Commit-Präfixen (`feat!:` → A, `feat:` → B, `fix:`/`docs:`/`ui:`/ohne Präfix → C, `ci:`/`build:`/`chore:`/`test:` → kein Release), Tag `vX.Y.Z` → GitHub Actions: Addon-Zip via BigWigsMods/packager (CurseForge + GitHub Release), Peasant-Builds für Windows/macOS/Linux werden an dasselbe Release gehängt.

## Abgleich (Kurzfassung)

Normalisierung (Umlaute doppelt: ä→a und ä→ae, Emojis/Symbole weg, CamelCase- und Bindestrich-Teile als Nebenwörter) → Vergleich nur innerhalb gleicher Anfangsbuchstaben (Performance) → Signale: exakt / Wortanfang / Jaro-Winkler, gewichtet nach Quelle (Charaktername > Notiz, Main-Teil der Namensregel > Spitzname, Twink leicht abgewertet) → Kombination Name+Notiz → gierige Zuordnung → Einstufung mit Vorsprung gegenüber dem nächsten Kandidaten. Schwellwerte einstellbar (Standard 90 / 70 / 45, Vorsprung 15).

## Getestet (außerhalb des Spiels)

- Kernlogik mit Demo-Daten (Beispiele aus dem Chat) in einem Lua-5.1-Interpreter.
- Komplettes Addon mit nachgebauter WoW-API: alle Tabs, Filter, Sortierung, Suche, Tooltips, Kontextmenüs, Bestätigen/Ablehnen/Ignorieren, Notiz-Dialog, Import, Ränge, Einstellungen; Sprachen enUS/deDE/Fallback.
- Performance: 1000 Charaktere × 1500 Discord-Mitglieder ≈ 5 s im langsamen Test-Interpreter, im Spiel über Frames verteilt.
- Peasant: `go vet`, Unit-Tests (Export-Format, DPAPI), Builds für 4 Plattformen, Live-Test der Web-API (Schlüssel, Host-Prüfung, ungültiges Token, Beenden).

## Offen / beim Testen im Spiel prüfen

1. TOC-Interface `16001` mit `/dump (select(4, GetBuildInfo()))` verifizieren.
2. Optik der Fenster (Positionen, Schriftgrößen) im echten Client.
3. Schreiben von Notizen (`C_GuildInfo.SetNote` bzw. Fallback) mit echter Gilde.
4. Echte Discord-Daten des eigenen Servers; danach ggf. Gewichte/Schwellwerte nachjustieren.
5. CurseForge-Projekt anlegen, `## X-Curse-Project-ID` in die TOC eintragen, API-Token als GitHub-Secret `CF_API_KEY` hinterlegen.

## Ideen für später

- Mehrere Discord-Server pro Gilde, Verlauf/Änderungen zwischen zwei Importen.
- Massenaktion „Notizen für alle eindeutigen Zuordnungen vorschlagen“.
- Weitere Sprachen.
