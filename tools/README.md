# Headless checks

Run from PowerShell 7:

```powershell
./tools/run_tests.ps1
./tools/run_tests.ps1 -NoImport -Filter license_audit
```

The runner verifies Godot 4.7.2 stable, GUT 9.7.1 and netfox 1.35.3, imports the project, runs GUT (including scene/resource smoke tests), validates game data, and checks both licence ledgers. Exit code 0 means every selected check passed; exit code 1 means a failed check, engine error, missing/empty GUT report, or timed-out process. A filtered GUT run is a focused check, not evidence that the whole suite passed. Use `-NoImport` only after importing new scripts and resources.

Each engine process has a timeout (180 seconds by default, configurable with `-TimeoutSeconds`). Logs and the latest JUnit XML are under ignored `tools/out/`; individual reports, generated runner configuration and isolated editor/user data are under `tools/out/runtime/<run ID>/`. Tests do not use real campaign saves. The runner does not change the caller's environment or the shared `.gutconfig.json`.

In a restricted Windows environment, Godot may emit exactly `ERROR: Failed to read the root certificate store.` before tests run. `-AllowUnavailableCertificateStore` explicitly permits that diagnostic for a local test run while retaining it in the log. All other engine errors still fail the run. This option does not validate TLS or repair certificate access; leave it off for normal verification.

The scene smoke tests load authored resources under `game`, `data`, and `assets` using the engine's recognized extensions and import sidecars, including scenes, definitions, shaders and imported art/audio. They instantiate scenes off-tree, compile all game scripts, verify the configured main scene, and check that data CSV importers are `keep`. Scene initialization, GPU shader compilation and networking still need separate rendered boot/two-instance playtests. Import settings must be changed in the Godot editor.

Every file under `assets` needs its own row and stable `asset_id` in `docs/license_ledger.csv`, including `.import`, `.uid`, README and hidden files. Paths use exact `res://` spelling; wildcards, traversal, duplicate IDs/paths, and stale entries fail. Original work may leave the external source and edition blank. CC0 entries require a source URL and the downloaded edition. Other licences additionally need an `approval` column pointing to an existing written owner approval under `res://docs/`; the checker verifies the reference, and the human reviewer verifies the approval itself. Do not invent an approval to satisfy the check.

Software remains in `docs/software_licenses.csv`. The gate checks required metadata, pinned version rows, and the bundled GUT/netfox licence files.
