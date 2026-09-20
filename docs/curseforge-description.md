# Forever - Save My Config

**Keep your setup. Bring it back when you need it.**

Forever - Save My Config is a standalone profile manager for **WoW Forever 1.60.1**. Save named profiles of your player settings, export a copy to keep outside the game, and import or restore selected sections through one simple window.

Click the draggable minimap icon or open **`/fconfig`** or **`/fsmc`** to get started. The profile window and import/export dialog are movable and remember their positions. The interface includes English, Simplified Chinese, and Traditional Chinese with English fallback for other client locales.

## Your settings, in one place

- **Keybindings:** save both account and current-character binding sets.
- **Macros:** preserve account and character macros, including their text and icons. Restore merges by name and scope while keeping unrelated macros.
- **Addon settings:** capture declared saved variables from loaded, registered addons. Coverage and capture notes show what was included or skipped.
- **Game preferences:** save supported interface, nameplate, camera, auto-loot, chat display, and sound settings.
- **Action bars:** save spells, items, macros, and empty slots across 120 standard action slots.

## Save, share, and restore

Create up to **20 named profiles**, inspect selectable readable details for every saved section, and choose which sections to restore. After login or `/reload`, the newest profile saved by the current character is selected automatically without silently applying it. **Export** produces checksummed text you can keep in a file; **Import** verifies the Adler-32 checksum and adds a profile without applying it. The checksum detects damaged copy/paste text and is not an authenticity signature. A **recovery snapshot** is created before each restore, and a report identifies skipped settings or errors.

The included addon registry covers **Auctionator, Baganator, Forever - Hunter's Friend, Leatrix Maps, Leatrix Plus, SilverDragon, and Syndicator**. A Windows registry scanner lets you add other installed addons' saved-variable declarations. Hunter's Friend is not required.

## Quick start

1. Install the addon and restart WoW for first-time discovery.
2. Type `/fconfig`, select sections, enter a profile name, and choose **Save new**.
3. Review **Addon coverage**, then **Export** a copy somewhere safe.
4. Select a saved or imported profile, choose sections, and use **Review restore**.
5. Read **Last restore report** and `/reload` after restoring addon settings.

Save and restore while out of combat. New profiles reach disk on `/reload` or normal logout.

## Full-folder backup included

For settings outside the in-game API, the package includes a separate **Windows PowerShell backup and restore tool** for the entire **WTF folder**. Run it with WoW closed to include all characters' file-backed settings. It creates a ZIP with a checksum and preserves the previous settings during a restore. Instructions are included in the README.

## Preview status and coverage

This is an **early preview** with automated tests; live-game validation is still pending.

In-game profiles capture the current character and loaded account data. They do not clone every character, graphics configuration, talent setup, pet bar, or chat-window layout. Generic addon restoration can be overwritten by an addon's own save behavior, so check settings after reloading. Some addons need a dedicated adapter or an offline WTF restore. Moving profiles between characters does not rewrite addon-specific character associations, and unavailable spells or items are reported.

Recovery restores captured settings but does not delete newly created macros. Exports can contain character names, macro text, and addon data, so review what you share.

## Feedback and support

[Report a problem](https://github.com/tomqwu/wow_forever_save_my_config/issues) · [Source and documentation](https://github.com/tomqwu/wow_forever_save_my_config)

When reporting an issue, include your addon version, client version, the affected setting or addon, and the relevant restore-report message. Avoid posting full profiles or WTF backups that contain private data.
