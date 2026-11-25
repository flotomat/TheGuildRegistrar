# Import format `TGR1`

Peasant (the helper app) produces this text; the addon reads it. It is simple enough to write by hand.

```
#TGR1;2026-11-24T20:15:00Z;My Server
@roles;Guild Master,Officer,Raider,Member,Guest
Jens | Wurstinator;Raider,Member
Anna | Gamblergirl;Raider
KörperKlaus;Member
Visitor Bob;Guest
```

| Line | Meaning |
|---|---|
| `#TGR1;<time>;<server>` | Header: format version, export time (UTC, ISO 8601), server name. Optional for hand-written lists. |
| `@roles;<role>,<role>,...` | All roles in Discord order, **highest first**. Used to decide which role is the "highest" one of a member. Optional. |
| `<display name>;<role>,<role>,...` | One Discord member: the display name (server nickname, else global display name, else user name) and the names of their roles. Roles are optional. |

Rules:

- `\` escapes the next character: `\;`, `\,`, `\\`.
- Empty lines and lines starting with `--` are ignored.
- Duplicate display names are kept and get an internal suffix (`Name #2`).
- No IDs are part of the format.
- New versions of the format get a new header (`#TGR2`, ...). The addon rejects unknown versions with a message asking to update.

## Assignment code `TGRD1`

The Comparison tab (**Share assignments**) turns the manual decisions of an officer into a code that other officers paste into the Import tab. The decisions are merged: shared entries replace own decisions for the same characters, everything else is kept. Same escaping as above.

```
#TGRD1;2026-11-25T12:00:00Z;My Guild
L;Wurstinator-Realm;Jens | Wurstinator
R;Jens | Wurstinator;Heilkraut-Realm
T;Wurstbrot-Realm;Wurstinator-Realm
M;Rolfine-Realm
ID;Besucher Bob
IC;Ohnediscord-Realm
```

| Line | Meaning |
|---|---|
| `#TGRD1;<created>;<guild>` | header (required) |
| `L;<character>;<Discord name>` | character fixed to a Discord member (confirmed) |
| `R;<Discord name>;<character>` | character separated from a Discord member |
| `T;<character>;<main>` | character is a twink/alt of a main |
| `M;<character>` | character is a main (never a twink) |
| `ID;<Discord name>` / `IC;<character>` | Discord member / character ignored |

Characters are full names (`Name-Realm`), Discord names the display names of the Discord export. The code contains Discord names and assignments: only share it with people who may see them.
