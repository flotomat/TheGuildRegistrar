# Setup guide

*Deutsche Version: [setup-guide.de.md](setup-guide.de.md)*

One-time setup takes about 10 minutes. You need:

- the addon **The Guild Registrar** (CurseForge),
- a PC with Windows, macOS or Linux,
- on your Discord server: the permission **Manage Server** - or someone who has it and opens one link for you.

## 1. Download and start the companion app

1. Open the [latest release](https://github.com/Flotomat/TheGuildRegistrar/releases/latest) and download the file for your system:
   - Windows: `TheGuildRegistrar-Companion-windows-x64.zip`
   - Mac with Apple chip (M1 and newer): `TheGuildRegistrar-Companion-macos-apple-silicon.zip`
   - Mac with Intel chip: `TheGuildRegistrar-Companion-macos-intel.zip`
   - Linux: `TheGuildRegistrar-Companion-linux-x64.tar.gz`
2. Unpack it into a folder of your choice and start `TheGuildRegistrar-Companion`.
3. **Security warning:** the app is not signed with a paid certificate, so your system warns you the first time.
   - **Windows SmartScreen** ("Windows protected your PC"): click **More info** → **Run anyway**.
   - **macOS** ("cannot be opened because the developer cannot be verified"): right-click the file → **Open** → **Open**. Alternatively, in Terminal: `xattr -d com.apple.quarantine TheGuildRegistrar-Companion`.
   - The app is open source; you can read the code in this repository.
4. A small console window opens and your browser shows the assistant. Leave the console window open while you use the app.

## 2. Create your own Discord bot

1. Open the [Discord Developer Portal](https://discord.com/developers/applications) and log in with your Discord account.
2. Click **New Application**, enter a name (e.g. *Guild Registrar*), accept the terms and click **Create**.
3. In the menu on the left, click **Bot**.
4. Under **Privileged Gateway Intents**, switch on **Server Members Intent** and click **Save Changes**.
   *(Without it the bot is not allowed to see the member list.)*
5. Optional but recommended: switch off **Public Bot**, so only you can invite it.
6. Click **Reset Token**, confirm, and **copy** the token.
   ⚠️ The token is like a password for the bot. Never post it anywhere.

## 3. Connect the app

1. Paste the token into the assistant and click **Check & save**.
2. The app checks the token with Discord and stores it protected on your PC (Windows: encrypted, macOS: keychain, Linux: file readable only by you).
3. If it says that *Server Members Intent* is off, go back to step 2.4, save, and reload the page.

## 4. Invite the bot to your server

1. Click **Open invite link** in the app.
2. Choose your server and click **Authorize**. The bot asks for **no permissions** - it can only see what every member sees in the member list.
3. If you do not have the *Manage Server* permission, send the link to someone who has it.
4. Click **I invited it - reload servers**.

## 5. Export and import

1. Choose your server and click **Export to clipboard**.
2. In WoW, type `/tgr`, open the **Import** tab, click into the text field, press **Ctrl+V** (Mac: **Cmd+V**) and click **Import**.
3. The **Comparison** tab shows the result.

The export is **not saved to a file**: it is only in your clipboard and on the app's page and is gone when you close the app.

To update the list later: start the app → **Export to clipboard** → paste in the game. Steps 2-4 are not needed again.

## 6. Configure the addon

- **Ranks tab**: assign each Discord role to the guild rank it stands for, mark guest roles (e.g. *Guest*) and twink ranks.
- **Options tab**: naming rule (e.g. `Nickname | Main`), which notes to use, twink patterns, ignored words, thresholds.
- In the **Comparison** tab, right-click entries to confirm, reject or reassign matches, whisper players or write guild notes.

## Privacy

All data stays on your PC; the project has no server and no telemetry. **You decide what happens with your members' data and are responsible for it** (e.g. under the GDPR):

- Tell your members that their Discord names and roles are compared with the guild roster.
- Prefer officer notes for Discord names - public notes are visible to the whole guild.
- If you use clipboard history or clipboard sync, clear the clipboard after the import.
- Delete the data when you no longer need it: Import tab → **Delete imported data** (current guild) or **Delete data of all guilds** (also guilds you have left; or type `/tgr wipe`).

Details: [privacy.md](privacy.md).

## Troubleshooting

| Problem | Solution |
|---|---|
| "Discord does not accept this token" | Reset the token on the Bot page and paste the new one. |
| "The bot may not read the member list" | Switch on *Server Members Intent* (step 2.4) and save. |
| No server in the list | The bot was not invited yet, or the invite went to another server. |
| Pasting in WoW does nothing | Click into the big text field first. The app also shows the text in a field to copy manually. |
| Many members "unassigned" | Check the naming rule and the rank mapping; add twink ranks; confirm matches manually. |
| I want to remove everything | In the addon: Import tab → **Delete data of all guilds** or `/tgr wipe` (to remove the settings too, delete `WTF/Account/<account>/SavedVariables/TheGuildRegistrar.lua` with the game closed). In the app click **Remove token** and delete the config folder ([privacy.md](privacy.md)); in the Developer Portal delete the application; kick the bot from your server. |
