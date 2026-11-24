# Translating The Guild Registrar

1. Copy `Locales/enUS.lua` to a new file named after the WoW locale code, e.g. `Locales/frFR.lua`.
2. Change the first call to `ns.RegisterLocale("frFR", {` and translate the texts on the right side. Keep the keys (left side), `%s` / `%d` placeholders and `|cff......|r` color codes.
3. Add the file to `TheGuildRegistrar.toc` **after** `Locales\deDE.lua` and **before** `Locales\Apply.lua`.
4. Missing keys automatically fall back to English, so partial translations work.

WoW locale codes: `enUS`, `deDE`, `frFR`, `esES`, `esMX`, `itIT`, `ptBR`, `ruRU`, `koKR`, `zhCN`, `zhTW`.

The companion app's texts are in `companion/web/index.html` (object `T`).
