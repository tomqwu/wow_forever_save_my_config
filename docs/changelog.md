# Changelog

## 0.1.1

- Restore changed macro icons even when the macro name and body already match.
- Verify the action ID after placement so rejected same-type replacements are reported.
- Add regression tests for both cases. The release remains a preview pending live-game validation.

## 0.1.0

Initial preview for WoW Forever Interface 16001.

- Movable profile GUI with `/fconfig` and `/fsmc`, named saves, import/export, selectable restore sections, macro inspection, coverage, and restore reports.
- Capture both binding sets, account/character macros, registered addon saved variables, common game CVars, and 120 standard action slots.
- Require a recovery snapshot before restoration, reject combat changes, check macro capacity, preserve unknown globals, and report incomplete operations.
- Versioned, bounded data-only import format with checksum; no execution of imported Lua.
- Include a Windows full-WTF backup/restore tool and saved-variable registry scanner.
- Mocked Lua, Python packaging/install, and synthetic Windows integration tests. Live-game acceptance is still pending.

Install the ZIP's `ForeverSaveMyConfig` folder under `Interface/AddOns`. Restart WoW for initial discovery, then open `/fconfig`. Read the packaged README for coverage and restore limitations. Full-WTF backup and restore require WoW to be closed.
