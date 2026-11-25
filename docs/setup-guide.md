# Setup guide

*Deutsche Version: [setup-guide.de.md](setup-guide.de.md)*

One-time setup takes about 10 minutes. You need:

- the addon **The Guild Registrar** (CurseForge),
- a PC with Windows, macOS or Linux,
- on your Discord server: the permission **Manage Server** - or someone who has it and opens one link for you.

> **You are an officer and your guild master already set up the bot?** Then you do not need your own bot: do step 1, then go straight to [Other officers](#7-other-officers).

## 1. Download and start Peasant (helper app)

1. Open the [latest release](https://github.com/Flotomat/TheGuildRegistrar/releases/latest) and download the file for your system:
   - Windows: `TheGuildRegistrar-Peasant-windows-x64.zip`
   - Mac with Apple chip (M1 and newer): `TheGuildRegistrar-Peasant-macos-apple-silicon.zip`
   - Mac with Intel chip: `TheGuildRegistrar-Peasant-macos-intel.zip`
   - Linux: `TheGuildRegistrar-Peasant-linux-x64.tar.gz`
2. Unpack it into a folder of your choice and start `TheGuildRegistrar-Peasant`.
3. **Security warning:** the app is not signed with a paid certificate, so your system warns you the first time.
   - **Windows SmartScreen** ("Windows protected your PC"): click **More info** → **Run anyway**.
   - **macOS** ("cannot be opened because the developer cannot be verified"): right-click the file → **Open** → **Open**. Alternatively, in Terminal: `xattr -d com.apple.quarantine TheGuildRegistrar-Peasant`.
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
2. In WoW, type `/tgr` (or open it via **Options → AddOns → The Guild Registrar**), open the **Import** tab, click into the text field, press **Ctrl+V** (Mac: **Cmd+V**) and click **Import**.
3. The **Comparison** tab shows the result.

The export is **not saved to a file**: it is only in your clipboard and on the app's page and is gone when you close the app.

To update the list later: start the app → **Export to clipboard** → paste in the game. Steps 2-4 are not needed again.

## 6. Configure the addon

**The goal: everything is assigned automatically.** A Discord account can own several characters - one main and its alts. The addon finds them by itself when the guild data follows a few rules:

- the **Discord name is in the officer note** (or the public note) of the main, e.g. `DC: Jens`,
- **alts** hold an alt rank or have a note like `Twink Wurstinator` / `alt of Wurstinator` (an alt whose note names the Discord account is found as well),
- optionally the Discord names follow a **naming rule** such as `Nickname | Main`.

Which notes are read is shown above the list in the Comparison tab (*Assignment by character names and: ...*) and can be switched there or in the Options tab. Notes that are not used are shown in grey. Manual assignments are the **fallback** for single cases (see below) and can be shared with other officers.

- **Ranks tab**: assign each Discord role to the guild rank it stands for, mark guest roles (e.g. *Guest*) and twink/alt ranks.
- **Options tab**: naming rule (e.g. `Nickname | Main`), which notes to use, whether alts are called "Twinks" or "Alts", alt patterns, note templates and the optional note check, ignored words, thresholds.
- In the **Comparison** tab, the column *To change* (and the tooltip) tells you what to fix: guild rank, alt status, guild note, assignment, Discord name. Click **+** to show the alts of a player.
- **Right-click** an entry (or an alt below it) for all actions. Actions that do not fit the entry are greyed out; the tooltip says why.
  - **Confirm assignment (fix it)**: the assignment no longer changes automatically.
  - **Remove confirmation**: back to automatic assignment.
  - **Separate from this Discord member**: the character (with its alts, if it is a main) is no longer assigned to this Discord account. For a confirmed assignment a window asks first. Undo with *Reset manual decisions*.
  - **Add character by name** / **Assign to Discord member by name**, **Assign other candidate**, **Assign as alt of** / **Mark as main**, ignore, whisper, copy a note suggestion.
- **Share assignments** (Comparison tab) creates a code with your manual decisions. Give it to other officers, e.g. as a text file in Discord; they paste it into their **Import** tab and confirm. Shared entries replace their own decisions for the same characters. The code contains Discord names and assignments - only share it with people who may see them.
- Writing guild notes and changing guild ranks is reserved for the Blizzard UI in WoW: Forever, so do this in the guild window. The addon shows these menu entries greyed out.

## 7. Other officers

So that not every officer needs their own bot, the guild master (or whoever set up the bot) can share it with an **invite code**. The code contains the bot token, encrypted with a password; the token itself is never shown.

**Guild master - create a code (once per officer, or one for all):**

1. Start Peasant and choose the kind of password in the **Other officers** section:
   - **Generate a strong password (recommended)** - e.g. `K7QF-2MXP-...`, easy to copy.
   - **Choose my own password** - e.g. if you want to say it in voice chat. Peasant gives a rough rating of its strength (length, upper/lower case, digits, special characters, variety). How strong it has to be is your decision; for a weak password Peasant asks you to confirm.
2. Click **Create invite code**.
3. Give code and password **by different ways**, e.g. the code as a Discord direct message and the password by voice or an in-game whisper. Never post them in a channel. Peasant saves neither the code nor the password.

**Officer - redeem the code:**

1. Download and start Peasant (step 1).
2. In the section **Officer with an invite code?**, paste code and password and click **Redeem**.
3. Done - continue with step 5 (export). The server is already selected. The token is stored protected on your PC as in step 3.

**Take access away** (e.g. when an officer leaves the guild): reset the token in the Developer Portal (step 2.6), paste the new token into Peasant and give new codes to the remaining officers. Old codes stop working.

Good to know: whoever has a code can fully use the bot - read the member list and do everything the `@everyone` role may do on your server. Only give codes to people you would also give the token to.

## Privacy

All data stays on your PC; the project has no server and no telemetry. **You decide what happens with your members' data and are responsible for it** (e.g. under the GDPR):

- Tell your members that their Discord names and roles are compared with the guild roster - and who has access (e.g. which officers have an invite code).
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
| "This is not a valid invite code" | Copy the whole code - it starts with `TGRK1-`. |
| "Wrong password" | Check the password (own passwords are case sensitive) or ask for a new code. |
| Officer: "The token from your invite code is no longer valid" | The guild master reset the token - ask them for a new code. |
| Pasting in WoW does nothing | Click into the big text field first. The app also shows the text in a field to copy manually. |
| Many members "unassigned" | Check the naming rule and the rank mapping; add twink ranks; confirm matches manually. |
| I want to remove everything | In the addon: Import tab → **Delete data of all guilds** or `/tgr wipe` (to remove the settings too, delete `WTF/Account/<account>/SavedVariables/TheGuildRegistrar.lua` with the game closed). In the app click **Remove token** and delete the config folder ([privacy.md](privacy.md)); in the Developer Portal delete the application; kick the bot from your server. |
