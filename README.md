# Forever - Save My Config

A standalone profile manager for **WoW Forever 1.60.x** (Interface **16001**), built using the compatibility and delivery workflow from [Forever - Hunter's Friend](https://github.com/tomqwu/wow_forever_hunters_friend).

Open **`/fconfig`** or **`/fsmc`** to save named profiles, inspect their contents, restore selected sections, and copy/paste exports. Version **0.8.0** redesigns the window around the Forever art set (your class crest in the header, each profile's class crest in the list), keeps the last five recovery snapshots, previews every change before a restore, and leaves large addon caches out unless you opt in. It remains a preview pending full restore validation and is tested with mocked client APIs and synthetic Windows backup data. Click the draggable minimap icon, Forever's addon menu, or `/fconfig` to open the GUI; `/fconfig minimap` or the **Minimap button** checkbox hides or shows the icon. Profile details and dialogs use selectable text fields; **Inspect** shows readable bindings, macros, addon variables, game settings, action slots, and capture notes. The branded profile window and import/export dialog are movable and remember their positions; **Reset layout** returns the windows and minimap icon to their defaults. Section choices are remembered between sessions. The GUI detects the WoW locale and includes English, Simplified Chinese, and Traditional Chinese; unsupported locales fall back to complete English text.

## What it saves

| Section | Coverage | Restore behavior |
| --- | --- | --- |
| Keybindings | Account and current character binding sets: every listed command, keys bound straight to a spell, macro, item or button click, and gamepad-mode (binding context) keys | Replaces both sets, each key in its own context, and restores which set is active |
| Macros | Account and current character macros, bodies, icons, and scope | Updates a unique matching name, adds missing macros, preserves unrelated macros; ambiguous duplicate names are reported. `#showtooltip` macros keep their dynamic "?" icon |
| Addon data | Declared account and character saved variables from loaded, registered addons. Price, history and bag caches are left out unless **Include addon caches** is ticked | Restores registered globals in place, then again as each addon loads after the reload |
| Game settings | The options Forever's own Settings menu exposes (interface, nameplates, raid/PvP frames, camera, mouse, chat, accessibility, sound) | Applies supported values; reports missing or rejected settings |
| Action bars | 120 standard slots containing spells, items, macros, or no action | Resolves macros by name/body/scope; clears saved empty slots; reports unsupported/unavailable actions |

The bundled registry includes Auctionator, Baganator, Forever Classmate (ForeverUtilities), Leatrix Maps, Leatrix Plus, Questie, SilverDragon, and Syndicator, plus components without separate saved variables. Registry entries contain TOC declarations only, never a player's settings.

`Caches.lua` marks the known cache variables: Auctionator's price database, posting history, recent searches and vendor price cache, Baganator's item data, and Syndicator's item data and summaries. These can be megabytes, and restoring an old copy replaces newer prices and bag contents, so they are skipped on save, restore and verification unless you tick **Include addon caches**. Other addon data can still include histories and profiles for other characters; there is no universal API that separates settings from the rest of an addon's database.

## First use

1. Install `ForeverSaveMyConfig/` in your client's `Interface/AddOns/` folder. **Restart WoW once for first addon discovery.** Existing installations need only `/reload`.
2. Click the minimap icon or open `/fconfig`, select sections, enter a name, and click **Save new**. Save while out of combat. Both binding sets are read; the original active bindings, including unsaved edits, are preserved.
3. Check the selectable profile details, use **Inspect** to review the exact saved sections in readable form, and check **Addon coverage**. Unloaded, unregistered, and unserializable data is explicitly reported.
4. Click **Export**, **Select all**, then Ctrl+C. Store the entire `FSMC1:...` text in a file outside WoW. The window shows the export's Adler-32 checksum. Click **Reload** to flush the saved profile database to disk.
5. On the destination, click **Import**, paste, and **Import as new**. The checksum is verified before a profile is created; importing does not apply settings. Inspect **Macros** and the source character, choose sections, then **Review restore**. The review lists every binding set, macro, setting, action slot and addon value that would change before you click **Apply selected**.
6. Read the pre-load and post-load validation lines printed in chat and retained in **Last restore report**. Unloaded addons, unregistered variables, and values that did not apply exactly are identified. Reload immediately after restoring addon data, then check your settings in game.

After each login or `/reload`, the GUI automatically selects the newest saved profile whose source character and realm match the current character. It never applies that profile silently; restoration still requires **Review restore → Apply selected**.

If one selected section is unavailable on the current client, the remaining sections are saved and the skipped section appears in **Capture notes**. There are up to 20 named profiles. Every restore first saves a **recovery snapshot**; the **Snapshots** tab keeps the last five, and restoring one saves a new snapshot without deleting the one you restore. If any section fails, every section already changed is rolled back from that snapshot and the report says so. Macro merge cannot delete macros newly created by an earlier restore. Export a snapshot if you need it beyond the last five restores.

## Full backup for every character

An in-game addon cannot read arbitrary files or access every other character's settings. For a complete copy of everything **stored in WTF**, close WoW normally and run the included Windows PowerShell tool:

```powershell
& 'F:\World of Warcraft\_forever_\Interface\AddOns\ForeverSaveMyConfig\Tools\Backup-WoWConfig.ps1'
```

It creates a ZIP and SHA-256 file in `F:\World of Warcraft\WoWConfigBackups`. It refuses to run while WoW is running from that client folder; a WoW client running from another folder does not block it. The full directory includes saved addon data, other characters, bindings, macros, chat layout, and client configuration files. It does not include the addon program files themselves, screenshots, external addon-manager settings, or settings held only on the server.

To restore a full backup, keep WoW closed and explicitly supply the archive:

```powershell
& 'F:\World of Warcraft\_forever_\Interface\AddOns\ForeverSaveMyConfig\Tools\Backup-WoWConfig.ps1' `
  -RestoreFrom 'F:\World of Warcraft\WoWConfigBackups\WTF-YYYYMMDD-HHMMSS-fff.zip'
```

The tool validates paths and the accompanying `.sha256` checksum, extracts before replacing anything, and retains the existing WTF directory plus a second backup. An archive without its `.sha256` file is refused unless you add `-SkipChecksum`. `-ClientPath` and `-BackupDirectory` support other installations. If Windows blocks a downloaded script, inspect it first and use PowerShell's `Unblock-File` for that file.

## Adding or updating addons

After installing addons with new saved-variable declarations, run:

```powershell
& 'F:\World of Warcraft\_forever_\Interface\AddOns\ForeverSaveMyConfig\Tools\Update-AddonRegistry.ps1'
```

Then `/reload` and inspect **Addon coverage**. The scanner reads only Interface 16001 TOC declarations. Ambiguous declarations stop the scan rather than guessing. Updating Save My Config can replace the registry; rescan afterward. An in-game import can only write locally registered globals belonging to a loaded addon, never arbitrary global variables supplied by an export.

## Limits to understand

- This is a portable profile of the exposed settings, **not a complete clone of your account**. Graphics/hardware configuration, modified-click assignments, transient override bindings, server settings, talents, pet bars, equipment-set/flyout actions, and full chat-window layout are not restored by the in-game profile. Use the offline backup for file-backed settings.
- Other characters' per-character saved-variable files are not loaded into the current character. The in-game profile can only capture the current character plus loaded account data.
- Saved-variable capture does not automatically load disabled or load-on-demand addons. Open those addons' UI first if needed and resave. A registry entry with zero variables is not an error.
- Addon restore preserves table references, reapplies the restored data at logout, and after the reload writes it again as each addon loads, before that addon reads its own data. This second write reaches only addons that load after Save My Config (alphabetical load order); the restore report names any that loaded earlier. An addon can still overwrite restored values during its own logout. Check after reload; such addons need a dedicated adapter or the offline restore tool. Do not assume generic saved-variable restoration is universally reliable.
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
