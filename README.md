# The Guild Registrar

**A World of Warcraft: Forever addon that compares your Discord member list with your guild roster.**
It shows who belongs to whom, how certain each match is, who is missing on which side, and whether Discord roles and guild ranks fit together. For every entry it says what should probably be changed - guild rank, alt/twink status, guild note, Discord name or assignment - so officers know exactly what to fix.

*Deutsch: siehe [unten](#deutsch).*

---

## The idea

**Assignments should happen automatically.** Every Discord account can own several characters: one main and any number of alts. The addon finds them by itself if the guild keeps a few simple rules:

1. Write the **Discord name into the officer note** (or the public note) of the main, e.g. `DC: Jens`.
2. Mark **alts** by an alt rank or a note such as `alt of Wurstinator` / `Twink Wurstinator`. An alt without such a note is still found if its note names the Discord account.
3. Optional: a **naming rule** for Discord names, e.g. `Nickname | Main`.

Which notes are read is shown above the list and can be switched there (public note, officer note, both or none).

**Manual assignment is the fallback** for the few cases the rules cannot cover: right-click an entry to confirm it, separate it, or add a character to a Discord account. Confirmed assignments stay fixed until you remove them. With **Share assignments** you turn your manual decisions into a code that other officers paste into their Import tab - e.g. as a text file in Discord.

## Features

- **Matching** of Discord display names against character names, public notes and officer notes. Handles umlauts and accents (`Hänge` = `Haenge` = `Hange`), emojis, CamelCase names and missing separators.
- **One Discord account, several characters**: the main and all alts of a person are listed under one Discord account. Characters that only the Discord name connects (no alt rank or note) are shown as alts with a hint to mark them in the game.
- **Four levels of certainty**: *certain*, *likely*, *unlikely*, *unassigned*, plus *confirmed* (fixed by an officer), *guest* and *ignored*. "Certain" really means certain: if two candidates are similarly good, the match is downgraded. Results do not change by themselves when the roster is refreshed.
- **Reasons**: the tooltip explains every match ("Wurstinator" matches character name "Wurstinator", exact, 100%) and lists alternative candidates.
- **Alts** are recognized by guild rank (configurable) and/or note text ("alt of Rolf", "Twink von Rolf", ...) and assigned to the same Discord member as their main. Officers can also assign a character as alt of a main by hand or mark it as main. Alts are shown as a tree below their main (click **+**). They are called "Alts" in English and "Twinks" in German; this can be changed in the options.
- **Hints what to change** for each player and character: different guild rank, mark as alt in the game, assign to a player, missing in Discord or in the guild, wrong or missing guild note (optional note check against a template), Discord name not following the naming rule.
- **Optional naming rule**, e.g. `Nickname | Main`. Names breaking the rule or with swapped parts get a hint.
- **Rank check**: map Discord roles to guild ranks; the highest Discord role counts. Mismatches are shown and can be filtered.
- **Guest roles** (e.g. "Guest") are listed but hidden by default.
- **Filters & sorting**: by status, side (only in Discord / only in guild), rank mismatch, hints, online, and a **fuzzy search** over all columns (several words, umlauts/accents/apostrophes ignored, parts of words, one typo tolerated).
- **Officer actions** (right-click): confirm (fix), remove the confirmation, **separate** a character from a Discord account (fixed ones only after a confirmation), assign another candidate, add a character or a Discord member by name, assign as alt of / mark as main, ignore, whisper, copy names, **copy a note suggestion** to paste into the guild window. The menu always shows every action; actions that do not fit an entry are greyed out and say why.
- **Share assignments** with other officers as a code (Comparison tab), taken over in the Import tab.
- **Writing guild notes and changing guild ranks** from the addon is not possible: WoW: Forever reserves both for the Blizzard UI. The menu entries are shown greyed out; the hints tell you what to change in the guild window.
- **Export** of the filtered list, e.g. to post "please update your nickname" in Discord.
- **Demo mode** (`/tgr demo`) to try everything without a guild.
- English and German; ready for more languages ([how to translate](docs/translating.md)).

## How it works

A game addon cannot access the internet. So there are two parts:

1. **Peasant** - the small helper app for Windows, macOS and Linux (download from the [releases page](https://github.com/Flotomat/TheGuildRegistrar/releases/latest)). With **your own Discord bot** it reads the display names and role names of your server members and copies them to the clipboard. It runs locally in your browser; nothing is sent anywhere else. Other officers do not need their own bot: the guild master creates an **invite code** in Peasant (the bot token, encrypted with a password) and the officers simply redeem it.
2. **The addon** - paste the text into the Import tab (`/tgr`) and the comparison starts.

Setup takes about 10 minutes and is described step by step in the app, in the addon's Setup tab and in the **[setup guide](docs/setup-guide.md)**.

## Commands

| Command | Action |
|---|---|
| `/tgr` | open / close the window |
| `/tgr import` | open the import tab |
| `/tgr demo` / `/tgr demo off` | start / end demo mode |
| `/tgr refresh` | reload the roster and compare again |
| `/tgr wipe` | delete the Discord data of all guilds on this account (with confirmation) |

The addon is also listed in the game under **Options → AddOns**; from there you can open its window or its options.

## Privacy

Only Discord display names and role names are exported - no user IDs, no messages. The export is not saved to a file; it is gone when you close Peasant. The bot token is stored protected on your PC. All data stays on your computer and in your WoW saved variables; the project has no server and no telemetry. The imported data can be deleted at any time - for the current guild or for all guilds on your account, including guilds you have left (Import tab, or `/tgr wipe`).

**You decide what happens with your members' data and are responsible for it** (e.g. under the GDPR). Please tell your members that their Discord names and roles are compared with the guild roster. Details, storage locations and recommendations: [docs/privacy.md](docs/privacy.md).

## Development

- `TheGuildRegistrar.toc` and the Lua folders in the repository root form the addon. The matching core (`Matching/`, `Data/Import.lua`) is plain Lua 5.1 without WoW API.
- `peasant/` is the Go source of Peasant, the helper app (no external dependencies): `cd peasant && go test ./... && go run .`
- Import format: [docs/import-format.md](docs/import-format.md)
- Releases are automatic: every push to `main` runs the checks, derives the next version from the commit messages since the last tag, tags it and builds the addon zip (CurseForge + GitHub) and Peasant for all platforms. The release notes are generated from the same commit messages.
  - `feat!: ...` or `BREAKING CHANGE:` in the body - new major version (`A`.0.0)
  - `feat: ...` - new feature (x.`B`.0)
  - `fix:`, `docs:`, `ui:`, `style:`, `perf:`, `refactor:`, `l10n:` or no prefix - fix / small change (x.x.`C`)
  - `ci:`, `build:`, `chore:`, `test:` - no release on their own
  - A scope is optional: `feat(peasant): ...`. One push = one release, the highest level wins. Pushing a tag `vX.Y.Z` by hand still works (see `.github/workflows/version.yml` and `release.yml`).

## License and notice

GPL-3.0-or-later - see [LICENSE](LICENSE). Provided without warranty and without liability to the extent permitted by law.

The Guild Registrar is an independent fan project and is not affiliated with, endorsed or sponsored by Blizzard Entertainment, Inc. or Discord Inc. World of Warcraft and Blizzard Entertainment are trademarks or registered trademarks of Blizzard Entertainment, Inc.; Discord is a trademark of Discord Inc.

---

## Deutsch

**The Guild Registrar** gleicht die Mitgliederliste eures Discord-Servers mit der Gildenliste in WoW: Forever ab. Das Addon zeigt, wer zu wem gehört, wie sicher die Zuordnung ist (*eindeutig*, *wahrscheinlich*, *unwahrscheinlich*, *nicht zugewiesen*), wer auf welcher Seite fehlt und ob Discord-Rollen und Gildenränge zusammenpassen.

**Die Idee:** Zuordnungen sollen automatisch passieren. Ein Discord-Account kann mehrere Charaktere haben - einen Main und beliebig viele Twinks/Alts. Das Addon findet sie selbst, wenn die Gilde ein paar einfache Regeln einhält: **Discord-Name in die Offiziersnotiz** (oder öffentliche Notiz) des Mains, z. B. `DC: Jens`; **Twinks** per Twink-Rang oder Notiz wie `Twink Wurstinator` kennzeichnen (ein Twink, dessen Notiz den Discord-Namen nennt, wird ebenfalls gefunden); optional eine **Namensregel** wie `Spitzname | Main`. Welche Notizen gelesen werden, steht über der Liste und lässt sich dort umschalten. **Die manuelle Zuweisung ist der Ausweichweg** für Einzelfälle: per Rechtsklick bestätigen (fest), lösen oder einen Charakter einem Discord-Account hinzufügen. Mit **Zuweisungen teilen** wird daraus ein Code, den andere Offiziere in ihrem Tab Import einfügen - z. B. als Textdatei in Discord.

- Vergleicht Discord-Anzeigenamen mit Charakternamen, öffentlicher Notiz und Offiziersnotiz (Umlaute, Emojis, CamelCase und fehlende Trennzeichen werden berücksichtigt). Die Ergebnisse ändern sich beim Aktualisieren der Gildenliste nicht von selbst.
- Erkennt Twinks über Gildenrang und/oder Notiztext und ordnet sie dem Discord-Mitglied des Mains zu. Charaktere lassen sich auch von Hand als Twink eines Mains zuordnen oder als Main markieren. Twinks werden als Baum unter ihrem Main angezeigt (Klick auf **+**); ob sie „Twinks“ oder „Alts“ heißen, ist einstellbar.
- Hinweise, was angepasst werden sollte: anderer Gildenrang, im Spiel als Twink kennzeichnen, Zuordnung zu einem Spieler, fehlt im Discord oder in der Gilde, falsche oder fehlende Gildennotiz (optionale Prüfung gegen eine Vorlage), Discord-Name entspricht nicht der Namensregel.
- Optionale Namensregel (z. B. `Spitzname | Main`) mit Hinweis bei Verstößen.
- Rang-Abgleich: Discord-Rolle → Gildenrang, die höchste Rolle zählt.
- Gast-Rollen werden aufgelistet, aber standardmäßig ausgeblendet.
- Filter, Sortierung, Tooltips mit Begründung, Export.
- Rechtsklick-Aktionen: bestätigen (fest), Bestätigung aufheben, **Verbindung lösen** (bei festen Zuweisungen erst nach Rückfrage), anderen Kandidaten oder per Name zuweisen, als Twink zuordnen / als Main markieren, ignorieren, Notiz-Vorschlag kopieren. Das Menü zeigt immer alle Aktionen; was für einen Eintrag nicht passt, ist ausgegraut und sagt, warum.
- Manuelle Zuweisungen als Code mit anderen Offizieren teilen.
- Gildennotizen schreiben und Gildenränge ändern ist per Addon nicht möglich: WoW: Forever behält beides dem Blizzard-Interface vor. Die Menüpunkte sind ausgegraut; die Hinweise sagen, was im Gildenfenster zu ändern ist.

Weil ein Addon nicht ins Internet kann, liest das kleine Hilfsprogramm **Peasant** (Download auf der [Release-Seite](https://github.com/Flotomat/TheGuildRegistrar/releases/latest)) mit **eurem eigenen Discord-Bot** die Mitgliederliste aus und legt sie in die Zwischenablage. Im Spiel fügt ihr sie mit `/tgr` → *Import* ein (das Fenster lässt sich auch über **Optionen → AddOns** öffnen). Weitere Offiziere brauchen keinen eigenen Bot: Der Gildenmeister erzeugt in Peasant einen **Einladungscode** (das mit einem Passwort verschlüsselte Bot-Token), den die Offiziere einlösen.

**Datenschutz:** Exportiert werden nur Anzeigenamen und Rollennamen, keine IDs. Der Export wird nicht in einer Datei gespeichert, alle Daten bleiben auf deinem PC, es gibt keinen Server und keine Telemetrie. Importierte Daten lassen sich jederzeit löschen - für die aktuelle Gilde oder für alle Gilden deines Accounts, auch verlassene (Tab Import oder `/tgr wipe`). **Du entscheidest, was mit den Daten deiner Mitglieder geschieht, und bist dafür verantwortlich** (z. B. nach der DSGVO) - bitte informiere deine Mitglieder über den Abgleich. Details: [docs/privacy.md](docs/privacy.md#deutsch).

**Anleitung:** [docs/setup-guide.de.md](docs/setup-guide.de.md)

**Hinweis:** The Guild Registrar ist ein unabhängiges Fan-Projekt und steht in keiner Verbindung zu Blizzard Entertainment, Inc. oder Discord Inc. World of Warcraft und Blizzard Entertainment sind Marken oder eingetragene Marken von Blizzard Entertainment, Inc.; Discord ist eine Marke von Discord Inc. Lizenz: GPL-3.0-or-later, ohne Gewährleistung und, soweit gesetzlich zulässig, ohne Haftung.
