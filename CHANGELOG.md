# Changelog

## v0.3.0 (2026-11-24)

- Writing guild notes is disabled: WoW: Forever reserves it for the Blizzard UI (addons are blocked even on a direct click). The menu entry is shown greyed out; instead a note suggestion can be copied and pasted in the guild window.
- New menu entry **Change guild rank** - also shown greyed out, because Forever reserves rank changes for the Blizzard UI. The code is kept for clients that allow it.
- Alts can be assigned by hand: **Assign as twink/alt of** (with suggestions from the Discord matching, or by name), **Mark as main**, **Reset**.
- Tree view: players with alts get a **+/-** at the left; their alts are shown as indented rows with their own notes, rank, hints and menu. When the window opens, all alts are shown - fold the players you have checked. The **+** in the header folds/unfolds all.
- Options: alternative characters can be called **Twinks** or **Alts**; **note check** (on by default for the officer note, switchable to public note or off; explained on mouse-over): the note must contain the template text.
- Hints (column *To change*): what should probably be changed per player and character - guild rank, mark as alt in the game, wrong main in the note, assign to a player / probably an alt of, missing in Discord / not in the guild, note names another Discord member, expected note text, naming rule, guest role.

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
