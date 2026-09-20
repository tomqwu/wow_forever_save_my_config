# Forever - Save My Config

Standalone WoW Forever addon. Runtime: addons/ForeverSaveMyConfig, Interface 16001,
SavedVariables ForeverSaveMyConfigDB, /fconfig and /fsmc. Do not reuse Hunter's
Friend's saved database, install folder, release prefix, or CurseForge project.

Verify client APIs against the Forever source when available. Preserve existing
profiles; never read or commit private WTF data. Imports must remain data-only,
bounded, versioned, and validated. Imported variable names cannot expand the
local registry. Restore only out of combat, after a complete recovery capture
for each affected value. Report partial results and missing coverage honestly.

For runtime changes, update TOC and displayed version, both READMEs, and the exact
version changelog. Run python3 scripts/check.py, git diff --check, and python3
scripts/package.py. Verify a single ForeverSaveMyConfig/ ZIP root and matching
source bytes. Test PowerShell changes on synthetic data with
tests/test_powershell.ps1. Distinguish mocks from live client testing.

Install using scripts/install.py, preserving unexpected files/edits. Never write
live SavedVariables or restart the game. First addon discovery needs a user
restart; updates use /reload. Keep build products and install manifests ignored.

Deliver scoped changes to this repository's main branch and verify CI. Releases
use ForeverSaveMyConfig-vX.Y.Z, never overwrite releases. Initial releases remain
prereleases until live acceptance is complete. CurseForge project ID: 1704390
(user supplied). GitHub variable CURSEFORGE_PUBLISH_ENABLED stays false during
the publication hold.

## Current publication hold

The user explicitly put CurseForge publishing on hold on 2026-09-20 while
completing project information. Preparing copy, artwork, source commits, and tests
is authorized. Do not upload files or submit the CurseForge project until the user
explicitly resumes publishing. Do not infer approval from creation of a project ID.
