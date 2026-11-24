# Changelog

## v0.2.0 (2026-11-24)

- Addon: new buttons **Delete imported data** (current guild) and **Delete data of all guilds** (every guild on the account, also guilds you have left) in the Import tab, plus `/tgr wipe`. They remove the Discord lists and all decisions; settings are kept. The Import tab shows for which guilds data is stored.
- Addon: privacy notice in the Setup tab
- Companion: the export is no longer saved as `last-export.txt`; it only stays on the app's page until the app is closed. An old `last-export.txt` is deleted on start.
- Companion: privacy notice, trademark and warranty notice in the interface
- Documentation: complete privacy notice (what is read and stored, how to delete it, your responsibility as an officer), trademark and warranty notice

## v0.1.0 (2026-11-24)

First test version. Please report problems on GitHub.

- Matching of Discord display names with character names, public and officer notes
- Classification: certain / likely / unlikely / unassigned, plus confirmed, guest, ignored
- Twink detection by guild rank and note patterns
- Optional naming rule for Discord names
- Rank check Discord role -> guild rank
- Filterable, sortable result list with tooltips and right-click actions
- Writing guild notes on request (with preview and confirmation)
- Export of the filtered list
- Demo mode (`/tgr demo`)
- Companion app (Windows, macOS, Linux) with setup assistant for your own Discord bot
- English and German
