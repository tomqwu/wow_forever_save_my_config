# Changelog

## 0.8.0

- **Redesigned window.** It uses art from the Forever HUD set: your class crest in the header, each profile's source class crest in the list, a framed crest on the detail card, gold dividers and trim, and flat gold-outlined buttons. **Profiles** and **Snapshots** tabs replace the single recovery button. The window re-fits on every open, so a resolution or UI-scale change never clips it.
- **Addon caches are excluded by default.** Auctionator's price database, posting history, recent searches and vendor price cache, Baganator's item data, and Syndicator's item data and summaries are listed in the new hand-maintained `Caches.lua`. They are skipped on save, restore, recovery and verification unless **Include addon caches** is ticked. Previously they could push a profile past the 8 MiB limit, failing the whole save or restore, and restoring them replaced newer prices and bag contents.
- **Five recovery snapshots.** Every restore adds one instead of replacing the last. Restoring a snapshot never deletes it. The existing snapshot migrates automatically.
- **Full rollback.** If any section fails, every section already changed (not only keybindings) is restored from the snapshot, and post-load validation is skipped with a clear note.
- **Restore preview.** **Review restore** now lists each binding set, macro, game setting, action slot and addon value that differs, without changing anything.
- **Keybindings** now include keys bound straight to SPELL, MACRO, ITEM and CLICK actions, and keep gamepad-mode keys in their own binding context. Older profiles restore with their original behavior, so keys they never captured are not cleared.
- **Dynamic macro icons.** `#showtooltip`/`#show` macros keep their dynamic "?" icon. Updates change only the body, as Blizzard's macro window does, and missing ones are created with the "?" icon.
- **Addon data after reload.** Restored values are written again as each addon loads after the reload, before that addon reads them. Only addons that load after Save My Config are reached; the report names the rest. Data staged for another character is discarded.
- **Game settings** now cover the options exposed by Forever's Settings menu (1.60.1.70888), including raid/PvP frames, soft targeting, mouse, accessibility and toasts.
- **Addon menu and minimap.** The addon is listed in Forever's addon compartment menu. The minimap button can be hidden with a checkbox or `/fconfig minimap`.
- **Translations.** Every validation, error and report message is now translated to Simplified and Traditional Chinese.
- **Offline backup tool.** It only refuses to run while WoW is running from that client folder, and it refuses to restore an archive without its `.sha256` file unless `-SkipChecksum` is given.
- **CI** uses Node 24 actions (`checkout@v7`, `upload-artifact@v7`, `download-artifact@v8`) on pinned `ubuntu-24.04` and `windows-2025` runners.
- README tool paths now point at the active `_forever_` product folder.

## 0.7.3

- Re-verified the runtime API against Forever **1.60.1.70888**, Interface **16001**, exported UI source commit `4cd0ab752a77164f654ccbca9d0c1fe8dafceebe`. No addon code changes were required: binding, macro, action-bar, cursor, addon-enumeration, and CVar APIs, `Constants.MacroConsts` (120/30), and the UI templates used are unchanged.
- Updated the documented compatibility baseline from 1.60.1.70707.

## 0.7.2

- Verified the runtime API against Forever **1.60.1.70707**, Interface **16001**, exported UI source commit `aff0d8cd53bf4d9ef1c1dd2786b94461a276fb16`.
- Add Questie's current account and character saved-variable declarations while retaining the existing supported-addon registry.
- Record `_forever_` as the active product folder and `_classic_beta_` as historical so future installs reach the running client.

## 0.7.1

- Fixed live Forever profile creation by calling `GetBinding` with the supported single-argument signature.
- A failure in one selected section now records a capture warning and preserves every other successfully captured section instead of discarding the entire profile.
- Recovery snapshots remain strict: restoration is cancelled before mutation if any selected section cannot be backed up completely.
- Reattach the live profile database during both `PLAYER_LOGOUT` and `ADDONS_UNLOADING` so reload and client shutdown use the current table.

Open `/fconfig`, click **Save new**, and then `/reload`. The named profile should remain selected after reload; inspect Capture notes for any skipped section.

## 0.7.0

- Validate selected profile data before restoration and identify unloaded addons or no-longer-registered variables before changing settings.
- Verify processed bindings, macros, addon values, CVars, and action slots against live values immediately after restoration.
- Print the bounded validation report line by line in WoW chat and retain it in **Last restore report**.

## 0.6.0

- Load the current character's default profile during addon initialization.
- Define the default as the newest named profile saved from the exact character and realm, ignoring newer profiles from other characters.
- Open the GUI with that profile selected and focused on its list page after every login or `/reload`; applying settings still requires explicit review and confirmation.

## 0.5.0

- Add locale detection with a complete English fallback.
- Translate the minimap tooltip, profile window, dialogs, summaries, selectable inspector, and primary status text into Simplified Chinese and Traditional Chinese.
- Add localized addon-list title/notes while keeping profile section keys and export data language-neutral.

## 0.4.0

- Add a selectable **Inspect saved data** view for keybindings, macros, addon variables, game settings, action bars, source metadata, and capture notes.
- Render nested addon values as deterministic readable text while retaining Export as the complete exact machine-readable profile.
- Label the main profile details as selectable and retain **Select all** in generated-text and import/export dialogs.

## 0.3.0

- Add a visible minimap icon that opens and closes the profile GUI.
- Let players drag the icon around the minimap and remember its position.
- Include the minimap icon in **Reset layout** and document GUI access.

## 0.2.1

- Enable automatic CurseForge beta publication for project 1704390 after each successful `main` release.
- Publish the same tested ZIP attached to the matching GitHub release and preserve its upload receipt.

## 0.2.0

- Put the Save My Config artwork in the window header and addon metadata.
- Remember the movable main-window and import/export-dialog positions, remember section choices, and add **All**, **None**, and **Reset layout** controls.
- Show the Adler-32 checksum on export and confirm it on import while clearly describing its integrity-only purpose.
- Optimize checksum calculation for large profiles and reject non-canonical Base64 padding.
- Preserve safe capture notes through import and reject unsafe imported display metadata.

## 0.1.2

- Release every successful merge or direct push to `main` from the tested CI package.
- Derive the release tag from the addon's TOC version and target the exact main commit.
- Reject pull requests and main releases that reuse an existing version, preventing release replacement.
- Keep CurseForge publishing behind the explicit publication-hold variable.

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
