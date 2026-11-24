# Privacy / Datenschutz

## English

**What is read:** the companion app uses *your own* Discord bot to read, for one server you choose: the server name, role names and order, and for each member the display name and the names of their roles. Member and role IDs are used only internally to put this together and are **not exported**.

**Where data goes:** nowhere except your own computer. The companion talks only to the official Discord API (`discord.com`). The export is copied to your clipboard and saved as `last-export.txt` in your user configuration folder. In the game, the imported list, your settings and your decisions are stored in the addon's saved variables (`WTF/Account/<account>/SavedVariables/TheGuildRegistrar.lua`).

**Bot token:** stored on your PC only - encrypted with Windows DPAPI on Windows, in the keychain on macOS, as a file readable only by you on Linux. "Remove token" in the app deletes it. If you think the token leaked, reset it in the Discord Developer Portal.

**Guild notes** are only written when you choose to, after a preview and confirmation.

The project has no server, no telemetry and no analytics.

## Deutsch

**Was gelesen wird:** Das Begleitprogramm liest mit *deinem eigenen* Discord-Bot für einen von dir gewählten Server: Servername, Rollennamen und deren Reihenfolge sowie für jedes Mitglied den Anzeigenamen und die Namen seiner Rollen. Mitglieds- und Rollen-IDs werden nur intern zum Zusammenstellen genutzt und **nicht exportiert**.

**Wohin die Daten gehen:** nur auf deinen eigenen Rechner. Das Programm spricht ausschließlich mit der offiziellen Discord-API (`discord.com`). Der Export landet in der Zwischenablage und als `last-export.txt` in deinem Benutzer-Konfigurationsordner. Im Spiel liegen Importliste, Einstellungen und Entscheidungen in den gespeicherten Variablen des Addons (`WTF/Account/<Account>/SavedVariables/TheGuildRegistrar.lua`).

**Bot-Token:** wird nur auf deinem PC gespeichert - unter Windows mit DPAPI verschlüsselt, unter macOS im Schlüsselbund, unter Linux als nur für dich lesbare Datei. "Token entfernen" im Programm löscht es. Falls du glaubst, dass das Token bekannt geworden ist, setze es im Discord Developer Portal zurück.

**Gildennotizen** werden nur geschrieben, wenn du es auswählst - mit Vorschau und Bestätigung.

Das Projekt hat keinen Server, keine Telemetrie und keine Analyse.
