# Forever - Save My Config

A standalone profile manager for **WoW Forever 1.60.x** (Interface **16001**), built using the compatibility and delivery workflow from [Forever - Hunter's Friend](https://github.com/tomqwu/wow_forever_hunters_friend).

Open **`/fconfig`** or **`/fsmc`** to save named profiles, inspect their contents, restore selected sections, and copy/paste exports. Version **0.2.1** is an initial preview: tested with mocked client APIs and synthetic Windows backup data, not yet validated inside a running game. The branded profile window and import/export dialog are movable and remember their positions; **Reset layout** returns both to the center. Section choices are remembered between sessions.

## What it saves

| Section | Coverage | Restore behavior |
| --- | --- | --- |
| Keybindings | Account and current character binding sets, including every key returned by the binding API | Replaces both sets and restores which set is active |
| Macros | Account and current character macros, bodies, icons, and scope | Updates a unique matching name, adds missing macros, preserves unrelated macros; ambiguous duplicate names are reported |
| Addon data | Declared account and character saved variables from loaded, registered addons | Restores registered globals in place; reload immediately afterward |
| Game settings | Available values from a defined list of common UI, nameplate, camera, auto-loot, chat display, and sound CVars | Applies supported values; reports missing or rejected settings |
| Action bars | 120 standard slots containing spells, items, macros, or no action | Resolves macros by name/body/scope; clears saved empty slots; reports unsupported/unavailable actions |

The bundled registry includes Auctionator, Baganator, Hunter's Friend, Leatrix Maps, Leatrix Plus, SilverDragon, and Syndicator, plus SilverDragon components without separate saved variables. Registry entries contain TOC declarations only, never a player's settings. Addon data can include caches, histories, and profiles for other characters; there is no universal API that separates settings from the rest of an addon's database.

## First use

1. Install `ForeverSaveMyConfig/` in your client's `Interface/AddOns/` folder. **Restart WoW once for first addon discovery.** Existing installations need only `/reload`.
2. Open `/fconfig`, select sections, enter a name, and click **Save new**. Save while out of combat. Both binding sets are read; the original active bindings, including unsaved edits, are preserved.
3. Check the profile details and **Addon coverage**. Unloaded, unregistered, and unserializable data is explicitly reported.
4. Click **Export**, **Select all**, then Ctrl+C. Store the entire `FSMC1:...` text in a file outside WoW. The window shows the export's Adler-32 checksum. Click **Reload** to flush the saved profile database to disk.
5. On the destination, click **Import**, paste, and **Import as new**. The checksum is verified before a profile is created; importing does not apply settings. Inspect **Macros** and the source character, choose sections, then **Review restore → Apply selected**.
6. Read **Last restore report**. Reload immediately after restoring addon data, then check your settings in game.

There are up to 20 named profiles and one automatically replaced **Recovery snapshot**. A recovery snapshot is required before restoration. Binding errors trigger a rollback; other errors stop remaining sections and leave a report. Earlier sections may already have changed. Recovery is another selectable profile; it restores captured values, but macro merge does not delete macros newly created by an earlier restore. Export a recovery snapshot if you need to retain it beyond the next restore.

## Full backup for every character

An in-game addon cannot read arbitrary files or access every other character's settings. For a complete copy of everything **stored in WTF**, close WoW normally and run the included Windows PowerShell tool:

```powershell
& 'F:\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverSaveMyConfig\Tools\Backup-WoWConfig.ps1'
```

It creates a ZIP and SHA-256 file in `F:\World of Warcraft\WoWConfigBackups`. The full directory includes saved addon data, other characters, bindings, macros, chat layout, and client configuration files. It does not include the addon program files themselves, screenshots, external addon-manager settings, or settings held only on the server.

To restore a full backup, keep WoW closed and explicitly supply the archive:

```powershell
& 'F:\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverSaveMyConfig\Tools\Backup-WoWConfig.ps1' `
  -RestoreFrom 'F:\World of Warcraft\WoWConfigBackups\WTF-YYYYMMDD-HHMMSS-fff.zip'
```

The tool validates paths and an accompanying checksum, extracts before replacing anything, and retains the existing WTF directory plus a second backup. `-ClientPath` and `-BackupDirectory` support other installations. If Windows blocks a downloaded script, inspect it first and use PowerShell's `Unblock-File` for that file.

## Adding or updating addons

After installing addons with new saved-variable declarations, run:

```powershell
& 'F:\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverSaveMyConfig\Tools\Update-AddonRegistry.ps1'
```

Then `/reload` and inspect **Addon coverage**. The scanner reads only Interface 16001 TOC declarations. Ambiguous declarations stop the scan rather than guessing. Updating Save My Config can replace the registry; rescan afterward. An in-game import can only write locally registered globals belonging to a loaded addon, never arbitrary global variables supplied by an export.

## Limits to understand

- This is a portable profile of the exposed settings, **not a complete clone of your account**. Graphics/hardware configuration, modified-click assignments, transient override bindings, server settings, talents, pet bars, equipment-set/flyout actions, and full chat-window layout are not restored by the in-game profile. Use the offline backup for file-backed settings.
- Other characters' per-character saved-variable files are not loaded into the current character. The in-game profile can only capture the current character plus loaded account data.
- Saved-variable capture does not automatically load disabled or load-on-demand addons. Open those addons' UI first if needed and resave. A registry entry with zero variables is not an error.
- Addon restore preserves table references and reapplies staged data at logout. An addon that writes its own cached state later in logout can still overwrite it. Check after reload; such addons need a dedicated adapter or the offline restore tool. Do not assume generic saved-variable restoration is universally reliable.
- Copying to a different character/class does not rewrite embedded character names or AceDB profile associations. Missing spells/items and ambiguous macros are reported. Some addon profiles require selecting the imported profile in the owning addon's UI.
- Imports use an Adler-32 checksum and a data-only parser. The checksum catches incomplete or damaged copy/paste text; it is not a cryptographic signature and does not prove who created an export. No `loadstring`, executable import code, or decompression is used. Limits: 8 MiB serialized data, 400,000 nodes, and 64 nesting levels. Cycles, protected values, functions, and unsupported keys are reported/skipped at the saved-variable boundary. Larger profiles must use fewer sections or the offline backup.
- Profiles are written to disk only on reload or normal logout. A crash before that can lose a new profile. Exports and WTF backups can contain private character/account identifiers, macros, and addon data; share only what you intend.

## Development

Lua 5.1 and Python 3 are required. The Windows integration test additionally uses PowerShell.

```bash
python3 scripts/check.py
python3 scripts/package.py
python3 scripts/registry.py '/path/to/client/Interface/AddOns'
python3 scripts/install.py '/path/to/client/Interface/AddOns'
git diff --check
```

The installer compares source bytes and preserves unexpected local edits. It never writes live SavedVariables. ZIPs contain exactly one `ForeverSaveMyConfig/` root. The Windows tests use synthetic data and do not touch real WTF files:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_powershell.ps1
```

API provenance and the live-game acceptance checklist are in [development notes](https://github.com/tomqwu/wow_forever_save_my_config/blob/main/docs/development.md). Release changes are in the [changelog](https://github.com/tomqwu/wow_forever_save_my_config/blob/main/docs/changelog.md).
