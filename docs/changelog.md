# Changelog

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
