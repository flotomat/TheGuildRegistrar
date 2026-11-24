# The Guild Registrar

**A World of Warcraft: Forever addon that compares your Discord member list with your guild roster.**
It shows who belongs to whom, how certain each match is, who is missing on which side, and whether Discord roles and guild ranks fit together. Officers can then contact exactly those people who still need to fix a nickname or a guild note.

*Deutsch: siehe [unten](#deutsch).*

---

## Features

- **Matching** of Discord display names against character names, public notes and officer notes. Handles umlauts and accents (`Hänge` = `Haenge` = `Hange`), emojis, CamelCase names and missing separators.
- **Four levels of certainty**: *certain*, *likely*, *unlikely*, *unassigned*, plus *confirmed* (manual), *guest* and *ignored*. "Certain" really means certain: if two candidates are similarly good, the match is downgraded.
- **Reasons**: the tooltip explains every match ("Wurstinator" matches character name "Wurstinator", exact, 100%) and lists alternative candidates.
- **Twinks** are recognized by guild rank (configurable) and/or note text ("Twink von Rolf", "alt of Rolf", ...) and assigned to the same Discord member as their main.
- **Optional naming rule**, e.g. `Nickname | Main`. Names breaking the rule or with swapped parts get a hint.
- **Rank check**: map Discord roles to guild ranks; the highest Discord role counts. Mismatches are shown and can be filtered.
- **Guest roles** (e.g. "Guest") are listed but hidden by default.
- **Filters & sorting**: by status, side (only in Discord / only in guild), rank mismatch, hints, online, free text search.
- **Officer actions** (right-click): confirm, reject, assign another candidate, assign by name, ignore, whisper, copy names, **write a guild note** (public and/or officer note, with preview and confirmation - never automatic).
- **Export** of the filtered list, e.g. to post "please update your nickname" in Discord.
- **Demo mode** (`/tgr demo`) to try everything without a guild.
- English and German; ready for more languages ([how to translate](docs/translating.md)).

## How it works

A game addon cannot access the internet. So there are two parts:

1. **The Guild Registrar Companion** - a small app for Windows, macOS and Linux (download from the [releases page](https://github.com/Flotomat/TheGuildRegistrar/releases/latest)). With **your own Discord bot** it reads the display names and role names of your server members and copies them to the clipboard. It runs locally in your browser; nothing is sent anywhere else.
2. **The addon** - paste the text into the Import tab (`/tgr`) and the comparison starts.

Setup takes about 10 minutes and is described step by step in the app, in the addon's Setup tab and in the **[setup guide](docs/setup-guide.md)**.

## Commands

| Command | Action |
|---|---|
| `/tgr` | open / close the window |
| `/tgr import` | open the import tab |
| `/tgr demo` / `/tgr demo off` | start / end demo mode |
| `/tgr refresh` | reload the roster and compare again |

## Privacy

Only Discord display names and role names are exported - no user IDs, no messages. The bot token is stored encrypted on your PC. All data stays on your computer and in your WoW saved variables. Details: [docs/privacy.md](docs/privacy.md).

## Development

- `TheGuildRegistrar.toc` and the Lua folders in the repository root form the addon. The matching core (`Matching/`, `Data/Import.lua`) is plain Lua 5.1 without WoW API.
- `companion/` is the Go source of the companion app (no external dependencies): `cd companion && go test ./... && go run .`
- Import format: [docs/import-format.md](docs/import-format.md)
- Releases: pushing a tag `vX.Y.Z` builds the addon zip (CurseForge + GitHub) and the companion for all platforms (see `.github/workflows/release.yml`).

## License

GPL-3.0-or-later - see [LICENSE](LICENSE).

---

## Deutsch

**The Guild Registrar** gleicht die Mitgliederliste eures Discord-Servers mit der Gildenliste in WoW: Forever ab. Das Addon zeigt, wer zu wem gehört, wie sicher die Zuordnung ist (*eindeutig*, *wahrscheinlich*, *unwahrscheinlich*, *nicht zugewiesen*), wer auf welcher Seite fehlt und ob Discord-Rollen und Gildenränge zusammenpassen.

- Vergleicht Discord-Anzeigenamen mit Charakternamen, öffentlicher Notiz und Offiziersnotiz (Umlaute, Emojis, CamelCase und fehlende Trennzeichen werden berücksichtigt).
- Erkennt Twinks über Gildenrang und/oder Notiztext und ordnet sie dem Discord-Mitglied des Mains zu.
- Optionale Namensregel (z. B. `Spitzname | Main`) mit Hinweis bei Verstößen.
- Rang-Abgleich: Discord-Rolle → Gildenrang, die höchste Rolle zählt.
- Gast-Rollen werden aufgelistet, aber standardmäßig ausgeblendet.
- Filter, Sortierung, Tooltips mit Begründung, Rechtsklick-Aktionen inkl. Gildennotiz schreiben (nur mit Bestätigung), Export.

Weil ein Addon nicht ins Internet kann, liest ein kleines **Begleitprogramm** (Download auf der [Release-Seite](https://github.com/Flotomat/TheGuildRegistrar/releases/latest)) mit **eurem eigenen Discord-Bot** die Mitgliederliste aus und legt sie in die Zwischenablage. Im Spiel fügt ihr sie mit `/tgr` → *Import* ein.

**Anleitung:** [docs/setup-guide.de.md](docs/setup-guide.de.md) · **Datenschutz:** [docs/privacy.md](docs/privacy.md)
