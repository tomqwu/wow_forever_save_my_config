# Development and validation

## API reference

Compatibility target: WoW Forever **1.60.1.69893**, Interface **16001**. Checked against Blizzard's exported UI source in the [Gethe mirror, forever branch](https://github.com/Gethe/wow-ui-source/tree/forever), local revision `4d5d706b8e01c5ebe01c8dd9b7a07151d8d37069`.

Relevant client source:

- `Blizzard_Settings_Shared/Blizzard_Keybindings.lua`: `GetBinding` returns action, category, and keys.
- `Blizzard_Settings_Shared/Blizzard_Settings.lua`: binding selection uses both `LoadBindings` and `SaveBindings`; the final saved set determines the persisted active selection.
- `Blizzard_MacroUI/Blizzard_MacroUI.lua` and `Blizzard_MacroIconSelector.lua`: macro scope, indices, and creation.
- `Blizzard_APIDocumentationGenerated/MacroConstantsDocumentation.lua`: `Constants.MacroConsts` has 120 account and 30 character slots. Runtime constants are preferred to fallbacks.
- `Blizzard_APIDocumentationGenerated/SpellDocumentation.lua`: `C_Spell.PickupSpell`.
- `Blizzard_ActionBar/Shared/ActionButton.lua`: action cursor and placement APIs.
- `Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua`: addon enumeration and loaded status.
- Installed Interface 16001 TOCs: saved-variable names and scopes. No player saved values were read during development.

Runtime checks still handle missing APIs and report unsupported settings. Source compatibility is not equivalent to live-game validation.

## Data flow

`Registry.lua` defines trusted local addon-to-global mappings. `Codec.lua` encodes primitive data and plain tables using a bounded length-prefixed format, an Adler-32 checksum, and Base64. The checksum detects accidental corruption, not the trustworthiness of the sender. `Providers.lua` reads/restores each category. `Profiles.lua` validates imports, owns the database, and requires a recovery snapshot. `UI.lua` provides the profile manager; `Core.lua` initializes storage and handles the slash commands and pending logout writes.

An import never changes player settings. Restore uses only the explicitly selected sections and still requires registered, loaded addons. Generic addon restore mutates existing tables to preserve AceDB references; a final logout pass mitigates later in-session cache writes, but does not guarantee event ordering against another addon's logout handler.

## Validation

`python3 scripts/check.py` checks Lua 5.1 syntax and runs mocked Lua and Python tests. Lua tests cover serialization, malformed imports, resource limits, both binding scopes, active-set persistence, rollback, combat rejection, macro merge/capacity, action-bar restoration, missing actions, safe addon globals, preserved table references, recovery snapshots, profile limits, and GUI construction/callbacks. The mocked renderer cannot verify actual layout, font clipping, client taint, or protected API behavior.

`tests/test_powershell.ps1` runs Windows backup/restore and registry integration tests using synthetic fixtures. It shadows the process query only inside the test so a running real game does not block fake-data tests; a separate test proves the production running-game guard rejects a WoW process. No real WTF file is read or changed.

CI checks Linux tests and ZIP construction. Tags `ForeverSaveMyConfig-vX.Y.Z` must match the TOC. Release creation fails rather than overwriting an existing release. The initial release is marked as a prerelease until live acceptance is complete.

## Live acceptance checklist (pending)

1. Restart the client for first discovery; check the addon list and open `/fconfig` on a test character. Check scaling at the user's resolution and that all dialogs, text areas, and scrolling work.
2. Save a small profile. Reload and verify persistence. Export, import, and compare its source, section counts, and macro text.
3. Back up the full WTF folder with WoW closed before deliberately changing real settings. Keep that archive outside the addon folder.
4. Change a known key and verify binding restore in both account and character mode, including multiple keys for one action. Check that the original active scope persists through reload.
5. Test unique macro updates and creation in each scope. Check full macro capacity, duplicate names, non-ASCII bodies, and action slots referring to macros after IDs reorder.
6. Change one registered setting in Hunter's Friend and Leatrix. Restore addon data, reload, and check both the UI and persistence across a second reload. Exercise load-on-demand addon coverage. Do not claim universal compatibility from these samples.
7. Test known spell/item/macro slots, saved empty slots, and unavailable spells on a different character. Check cursor preservation and protected-action errors.
8. Enter combat and verify saves/restores are blocked before mutation. Leave combat and test recovery and restore error reporting.
9. Test the full offline backup and restore on a disposable copy of a client directory, not the only copy of real settings.

## CurseForge publishing

The repository secret `CURSE_FORGE` is consumed only inside GitHub Actions.
Repository variable `CURSEFORGE_PROJECT_ID` is set to **1704390**, supplied by
the owner. Hunter's Friend project 1700438 is explicitly rejected.
`CURSEFORGE_PUBLISH_ENABLED=false` enforces the current publication hold.
Both tag-triggered and manual uploads are disabled unless this variable is
explicitly set to `true`; manual dry runs remain available. Only enable publishing
after the owner explicitly resumes it.

Run **Publish Save My Config to CurseForge** with an existing GitHub release tag.
The manual workflow defaults to a dry run: it verifies the released ZIP, token,
and exact game-version lookup without uploading. A dry run can run before the
project ID is configured; it does not verify project-specific upload permission.
Set `dry_run=false` only for a configured destination after publishing is enabled.
Future tag releases call the publisher automatically after the GitHub release
succeeds when `CURSEFORGE_PUBLISH_ENABLED=true`.

Uploads use the official [CurseForge upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-api)
and the existing GitHub ZIP, not a rebuilt artifact. The API must expose the
exact Forever game version. Preview files are uploaded as beta. Success writes a
receipt containing file ID, project ID, game-version ID, tag, and ZIP SHA-256 to
the GitHub release and workflow artifacts. Existing matching receipts skip repeat
uploads. A failed or uncertain POST must not be retried without checking the
project's Files page; the API does not offer an idempotency key. File acceptance
does not imply moderation approval or an update to project-page metadata.
