# Privacy / Datenschutz

*Deutsche Version: [unten](#deutsch).*

## English

### Summary

The Guild Registrar has no server, no telemetry and no analytics. The developer never receives, stores or sees any data. Everything happens on your own computer and in your own WoW installation. **You** decide what happens with the data of your members - please read [Your responsibility](#your-responsibility).

### What Peasant (the helper app) reads

Peasant, the helper app, uses *your own* Discord bot to read, for one server you choose:

- the server name,
- the role names and their order,
- the member list.

For the member list Discord sends the bot the **complete member data** (among others user ID, user name, global display name, server nickname, avatar, join date and role IDs). Peasant processes this **only in memory** and takes from it only:

- the **display name** of each member - the server nickname, otherwise the global display name, otherwise the Discord **user name** (which is unique and can be found on Discord),
- the **names of the member's roles**.

Member and role IDs are used only internally to put this together and are **not exported**. Bot accounts are left out unless you choose "Include bot accounts".

### Where data goes

- **Network:** Peasant talks only to the official Discord API (`discord.com`). Its user interface runs in your browser but is only reachable from your own PC (`127.0.0.1`, protected by a random key).
- **Export:** the list is copied to your clipboard and shown on the app's page. It is **not saved to a file** and is gone when you close the app. (Version 0.1.0 saved it as `last-export.txt`; newer versions delete that file on start.) Only if you use the command line yourself (`export -out FILE`) is a file written - where you say.
- **Clipboard:** Windows clipboard history (Win+V) or clipboard sync between devices (Windows cloud clipboard, Apple Universal Clipboard, clipboard managers) can capture the copied list. If you use such features, clear the clipboard after the import or turn them off for this.
- **In the game:** the imported list, your settings and your decisions (which Discord name belongs to which character, rejected matches, ignored entries, which character is an alt/twink of which main) are stored in the addon's saved variables (`WTF/Account/<account>/SavedVariables/TheGuildRegistrar.lua`), separately for each guild. They belong to your WoW account on the PC you play on and are shared by all characters of that account - so data of a guild you have left, or of a guild only another character of yours is in, stays there until you delete it. Saved variables stay on your PC; the addon does not send any addon messages to other players. Other guild members only have such data if they import a list themselves.
- **Guild notes and ranks:** the addon does not change guild notes or ranks - WoW: Forever reserves this for the Blizzard UI. It can show a note suggestion that you copy and paste in the guild window yourself. A **public note** can be read by **every guild member**, an officer note only by those whose rank may see officer notes.
- **Exported result list:** the export in the Comparison tab contains statuses, Discord names, mains, alts, rank mismatches and hints. Where it goes is up to you.
- **Shared assignments:** *Share assignments* in the Comparison tab creates a code with your manual decisions (Discord names, character names, which character belongs to which Discord account, alts, ignored entries). The addon does not send it anywhere; it is shown for copying. Whoever pastes it into their Import tab stores these decisions in their own saved variables.

### What is stored, and how to delete it

| What | Where | How to delete |
|---|---|---|
| Bot token | Windows: encrypted with DPAPI in the config folder; macOS: keychain; Linux: file readable only by you in the config folder | "Remove token" in the app. If the token may have leaked, reset it in the Discord Developer Portal. |
| Settings (selected server ID, bot option, whether the token came from an invite code) | `config.json` in the config folder | Delete the config folder. |
| Invite codes for other officers | not stored by Peasant - code and password are only shown once; where they go is up to you | Reset the token in the Discord Developer Portal: every code given out stops working. |
| Imported Discord list and decisions | WoW saved variables, per guild | Import tab → **Delete imported data** (current guild) or **Delete data of all guilds** / `/tgr wipe` (every guild on this WoW account, also guilds you have left). The Import tab shows for which guilds data is stored. To remove the settings too: with the game closed, delete `WTF/Account/<account>/SavedVariables/TheGuildRegistrar.lua`. |
| Assignments taken over from another officer's code | WoW saved variables, per guild, together with your own decisions | Like your own decisions (see above). |
| Guild notes you entered (e.g. from a suggestion) | in the game, visible to the guild | Edit or delete them in the guild window. |

The config folder is `%AppData%\TheGuildRegistrar` on Windows, `~/Library/Application Support/TheGuildRegistrar` on macOS and `~/.config/TheGuildRegistrar` on Linux.

To remove everything: "Remove token" in the app, delete the config folder and the saved variables file, delete the application in the Discord Developer Portal and remove the bot from your server.

### Your responsibility

The Guild Registrar is a tool. Whoever uses it for a guild decides about purpose and scope - and may therefore be the **controller** within the meaning of the GDPR or similar laws. Discord names are personal data, and linking them to characters (main and alts) creates new information about your members.

Recommendations:

- **Inform your members**, e.g. in a rules or info channel: that Discord names and roles are compared with the guild roster, why (guild management) and who has access (including the officers you gave an invite code).
- **Only as much as needed:** prefer the *officer note* for Discord names. A public note is visible to all guild members.
- **Share the bot with care:** an invite code gives another officer the same bot token (encrypted with a password; after redeeming it is stored protected on their PC like your own). Whoever has it can read the member list and do what `@everyone` may do on your server. Only give codes to officers who need them, send code and password by different ways, and reset the token when someone should no longer have access. The developer is not involved; the code never passes through any server of the project.
- **Share assignment codes with care:** they contain Discord names and assignments including alts. Only give them to officers who need them.
- **Share exports with care:** the exported list contains assignments and alts. Only post what the people concerned really need (e.g. just the names, without alts).
- **Delete when no longer needed**, e.g. when you are no longer an officer or leave the guild.
- Follow the [Discord Developer Terms of Service](https://discord.com/developers/docs/policies-and-agreements/developer-terms-of-service) and the [Discord Developer Policy](https://discord.com/developers/docs/policies-and-agreements/developer-policy), which also apply to your own bot.

### Notice

The Guild Registrar is an independent fan project and is not affiliated with, endorsed or sponsored by Blizzard Entertainment, Inc. or Discord Inc. World of Warcraft and Blizzard Entertainment are trademarks or registered trademarks of Blizzard Entertainment, Inc.; Discord is a trademark of Discord Inc. The software is provided without any warranty and without liability to the extent permitted by law (see [GPL-3.0](../LICENSE), sections 15-16). This text is not legal advice.

---

## Deutsch

### Zusammenfassung

The Guild Registrar hat keinen Server, keine Telemetrie und keine Analyse. Der Entwickler erhält, speichert oder sieht keine Daten. Alles geschieht auf deinem eigenen Rechner und in deiner eigenen WoW-Installation. **Du** entscheidest, was mit den Daten deiner Mitglieder geschieht - bitte lies [Deine Verantwortung](#deine-verantwortung).

### Was das Hilfsprogramm Peasant liest

Das Hilfsprogramm Peasant liest mit *deinem eigenen* Discord-Bot für einen von dir gewählten Server:

- den Servernamen,
- die Rollennamen und deren Reihenfolge,
- die Mitgliederliste.

Für die Mitgliederliste liefert Discord dem Bot **vollständige Mitgliedsdaten** (u. a. Benutzer-ID, Benutzername, globaler Anzeigename, Server-Spitzname, Avatar, Beitrittsdatum und Rollen-IDs). Das Programm verarbeitet diese **nur im Arbeitsspeicher** und übernimmt daraus ausschließlich:

- den **Anzeigenamen** jedes Mitglieds - den Server-Spitznamen, sonst den globalen Anzeigenamen, sonst den Discord-**Benutzernamen** (der eindeutig ist und sich auf Discord finden lässt),
- die **Namen der Rollen** des Mitglieds.

Mitglieds- und Rollen-IDs werden nur intern zum Zusammenstellen genutzt und **nicht exportiert**. Bot-Konten werden weggelassen, außer du wählst "Bot-Konten mit exportieren".

### Wohin die Daten gehen

- **Netzwerk:** Das Programm spricht ausschließlich mit der offiziellen Discord-API (`discord.com`). Die Oberfläche läuft im Browser, ist aber nur von deinem eigenen PC aus erreichbar (`127.0.0.1`, geschützt durch einen Zufallsschlüssel).
- **Export:** Die Liste wird in die Zwischenablage kopiert und auf der Seite des Programms angezeigt. Sie wird **nicht in einer Datei gespeichert** und ist nach dem Beenden des Programms weg. (Version 0.1.0 hat sie als `last-export.txt` gespeichert; neuere Versionen löschen diese Datei beim Start.) Nur wenn du selbst die Kommandozeile nutzt (`export -out DATEI`), wird eine Datei geschrieben - dort, wo du es angibst.
- **Zwischenablage:** Der Windows-Zwischenablageverlauf (Win+V) oder eine geräteübergreifende Synchronisierung der Zwischenablage (Windows-Cloud-Zwischenablage, Apple Universal Clipboard, Zwischenablage-Manager) können die kopierte Liste erfassen. Wenn du solche Funktionen nutzt, leere die Zwischenablage nach dem Import oder schalte sie dafür ab.
- **Im Spiel:** Importliste, Einstellungen und deine Entscheidungen (welcher Discord-Name zu welchem Charakter gehört, abgelehnte Zuordnungen, ignorierte Einträge, welcher Charakter Twink/Alt welches Mains ist) liegen in den gespeicherten Variablen des Addons (`WTF/Account/<Account>/SavedVariables/TheGuildRegistrar.lua`), getrennt nach Gilde. Sie gehören zu deinem WoW-Account auf dem PC, auf dem du spielst, und gelten für alle Charaktere dieses Accounts - Daten einer Gilde, die du verlassen hast oder in der nur ein anderer deiner Charaktere ist, bleiben also erhalten, bis du sie löschst. Die gespeicherten Variablen bleiben auf deinem PC; das Addon sendet keine Addon-Nachrichten an andere Spieler. Andere Gildenmitglieder haben solche Daten nur, wenn sie selbst eine Liste importieren.
- **Gildennotizen und Ränge:** Das Addon ändert keine Gildennotizen und keine Ränge - WoW: Forever behält das dem Blizzard-Interface vor. Es kann einen Notiz-Vorschlag anzeigen, den du selbst kopierst und im Gildenfenster einfügst. Eine **öffentliche Notiz** kann **jedes Gildenmitglied** lesen, eine Offiziersnotiz nur, wessen Rang Offiziersnotizen sehen darf.
- **Exportierte Ergebnisliste:** Der Export im Tab Abgleich enthält Status, Discord-Namen, Mains, Twinks, Rangabweichungen und Hinweise. Wohin er geht, entscheidest du.
- **Geteilte Zuweisungen:** *Zuweisungen teilen* im Tab Abgleich erzeugt einen Code mit deinen manuellen Entscheidungen (Discord-Namen, Charakternamen, welcher Charakter zu welchem Discord-Account gehört, Twinks, ignorierte Einträge). Das Addon versendet ihn nicht; er wird zum Kopieren angezeigt. Wer ihn in seinem Tab Import einfügt, speichert diese Entscheidungen in seinen eigenen gespeicherten Variablen.

### Was gespeichert wird und wie du es löschst

| Was | Wo | Löschen |
|---|---|---|
| Bot-Token | Windows: mit DPAPI verschlüsselt im Konfigurationsordner; macOS: Schlüsselbund; Linux: nur für dich lesbare Datei im Konfigurationsordner | Im Programm "Token entfernen". Falls das Token bekannt geworden sein könnte, im Discord Developer Portal zurücksetzen. |
| Einstellungen (gewählte Server-ID, Bot-Option, ob das Token aus einem Einladungscode stammt) | `config.json` im Konfigurationsordner | Konfigurationsordner löschen. |
| Einladungscodes für weitere Offiziere | von Peasant nicht gespeichert - Code und Passwort werden nur einmal angezeigt; wohin sie gehen, entscheidest du | Token im Discord Developer Portal zurücksetzen: Alle ausgegebenen Codes funktionieren dann nicht mehr. |
| Importierte Discord-Liste und Entscheidungen | Gespeicherte Variablen von WoW, je Gilde | Tab Import → **Importierte Daten löschen** (aktuelle Gilde) oder **Daten aller Gilden löschen** / `/tgr wipe` (alle Gilden dieses WoW-Accounts, auch verlassene). Der Tab Import zeigt, für welche Gilden Daten gespeichert sind. Auch die Einstellungen entfernen: bei beendetem Spiel `WTF/Account/<Account>/SavedVariables/TheGuildRegistrar.lua` löschen. |
| Aus dem Code eines anderen Offiziers übernommene Zuweisungen | Gespeicherte Variablen von WoW, je Gilde, zusammen mit deinen eigenen Entscheidungen | Wie deine eigenen Entscheidungen (siehe oben). |
| Von dir eingetragene Gildennotizen (z. B. aus einem Vorschlag) | im Spiel, für die Gilde sichtbar | Im Gildenfenster bearbeiten oder löschen. |

Der Konfigurationsordner ist unter Windows `%AppData%\TheGuildRegistrar`, unter macOS `~/Library/Application Support/TheGuildRegistrar` und unter Linux `~/.config/TheGuildRegistrar`.

Alles entfernen: im Programm "Token entfernen", Konfigurationsordner und die Datei der gespeicherten Variablen löschen, die Anwendung im Discord Developer Portal löschen und den Bot vom Server entfernen.

### Deine Verantwortung

The Guild Registrar ist ein Werkzeug. Wer das Tool für eine Gilde einsetzt, entscheidet selbst über Zweck und Umfang - und ist damit gegebenenfalls **Verantwortlicher** im Sinne der DSGVO bzw. vergleichbarer Gesetze. Discord-Namen sind personenbezogene Daten, und ihre Verknüpfung mit Charakteren (Main und Twinks) erzeugt neue Informationen über deine Mitglieder.

Empfehlungen:

- **Informiere deine Mitglieder**, z. B. im Regel- oder Info-Kanal: dass Discord-Namen und Rollen mit der Gildenliste abgeglichen werden, wozu (Gildenverwaltung) und wer Zugriff hat (auch die Offiziere, denen du einen Einladungscode gegeben hast).
- **Nur so viel wie nötig:** Schreibe Discord-Namen bevorzugt in die *Offiziersnotiz*. Eine öffentliche Notiz ist für alle Gildenmitglieder sichtbar.
- **Bot bedacht teilen:** Ein Einladungscode gibt einem anderen Offizier dasselbe Bot-Token (verschlüsselt mit einem Passwort; nach dem Einlösen wie dein eigenes geschützt auf seinem PC gespeichert). Wer es hat, kann die Mitgliederliste lesen und tun, was `@everyone` auf eurem Server darf. Gib Codes nur an Offiziere, die sie brauchen, gib Code und Passwort auf verschiedenen Wegen weiter und setze das Token zurück, wenn jemand keinen Zugriff mehr haben soll. Der Entwickler ist nicht beteiligt; der Code läuft über keinen Server des Projekts.
- **Zuweisungs-Codes bedacht teilen:** Sie enthalten Discord-Namen und Zuordnungen inklusive Twinks. Gib sie nur an Offiziere, die sie brauchen.
- **Exporte bedacht teilen:** Die exportierte Liste enthält Zuordnungen und Twinks. Poste nur, was die Betroffenen wirklich brauchen (z. B. nur die Namen ohne Twinks).
- **Löschen, wenn nicht mehr nötig**, etwa wenn du kein Offizier mehr bist oder die Gilde verlässt.
- Halte dich an die [Discord Developer Terms of Service](https://discord.com/developers/docs/policies-and-agreements/developer-terms-of-service) und die [Discord Developer Policy](https://discord.com/developers/docs/policies-and-agreements/developer-policy), die auch für deinen eigenen Bot gelten.

### Hinweis

The Guild Registrar ist ein unabhängiges Fan-Projekt und steht in keiner Verbindung zu Blizzard Entertainment, Inc. oder Discord Inc.; es wird von diesen weder unterstützt noch gesponsert. World of Warcraft und Blizzard Entertainment sind Marken oder eingetragene Marken von Blizzard Entertainment, Inc.; Discord ist eine Marke von Discord Inc. Die Software wird ohne Gewährleistung und, soweit gesetzlich zulässig, ohne Haftung bereitgestellt (siehe [GPL-3.0](../LICENSE), Abschnitte 15-16). Dieser Text ist keine Rechtsberatung.
