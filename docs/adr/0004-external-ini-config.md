# External INI configuration

User-facing defaults now live in `config.ahk`, while an optional
`paper-vim.ini` beside `paper-vim.ahk` overrides only the values it contains.
INI was chosen because AutoHotkey has native `IniRead` support and the settings
are mostly flat key/value pairs. Runtime state such as window handles, GUI
controls, caches, and timers stays in the script and is not configurable.

Settings are grouped by section. Keybindings use stable action names under
`[Keys.<context>]`; only keys that differ from the defaults are rebound. Invalid
values or duplicate keys stop startup with an error. Changing the file requires
a restart.
