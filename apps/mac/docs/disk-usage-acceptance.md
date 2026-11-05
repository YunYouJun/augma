# Read-only storage analysis: native App acceptance

Date: 2026-11-05. The arm64 Release candidate passed the real native App workflow and was installed over the existing daily-use Augma after validation. The stable local development signing identity was preserved.

## Observed workflow

- Open **System Monitor → Storage analysis** in a separately identified `.app` with an isolated Cocoa home. The daily profile was not used for candidate testing.
- Choose a deterministic fixture through the native directory picker. The App reports four files and 3,801,088 logical bytes, rounded to 3.6 MB by the current formatter. The three directory blocks agree with the fixture: project 3 MiB, downloads 512 KiB, documents 128 KiB.
- Click the project block. Its path becomes the active scope and the treemap shows `node_modules` at 2 MiB and `build` at 1 MiB. The local suggestions explain inspection and rebuilding rather than offering deletion.
- Switch from allocated to logical size, then use **Up one level** to return to the scan root. The root navigation action becomes disabled there.
- Explicitly refresh an isolated Craft Hub read grant and scan the actual registered Craft Hub checkout. The large checkout reaches the entry budget; the App shows an incomplete result, a lower-bound marker and unknown unmeasured usage.
- Click **Maintain project in Craft Hub**. The installed Electron Craft Hub opens its existing Craft Hub project, with the correct checkout path and **Space and maintenance** section visible. No project command is selected or run.

The UI was operated through the native accessibility tree and the treemap was visually checked in the running App. This is additional evidence beyond the earlier `NSHostingView` render tests.

## Read-only and lifecycle checks

The fixture's directory and file identities, modification times, lengths and content hashes match before and after the session. The temporary runtime records no executions and its project remains untrusted. The read grant is revoked at the end. A session guard closes the temporary App and server with `finally` and signal handlers, checks the recorded PID/executable/start-time identity, and verifies exit. The existing installed Craft Hub is retained.

Ignored local evidence is under `.temp/disk-ui-20261105/`: the session runner, fixture fingerprints, `ui-acceptance.json`, `cleanup.json`, candidate identity and installation report. The loopback credential is removed by cleanup. Screenshots and accessibility observations are also retained in the acceptance chat.

## Daily installation

The final accepted candidate and installed executable have the same Mach-O build UUID, `E2C8C365-A467-3921-92DD-921E1385DC4D`. The installed bundle is `~/Applications/Augma.app`; rollback bundles are retained at `~/Applications/.augma-backups/20261105-before-combined-release/Augma.app` and the earlier `20261105-before-space-analysis/Augma.app`.

The daily App was quit normally, replaced with the accepted Release code, signed and verified, then reopened. Its **Storage analysis** sheet opens successfully. The temporary connection is absent from the daily profile. Top-level Augma JSON data hashes match before installation and after relaunch; preferences and draft storage were not migrated or replaced.

Concurrent chats initially replaced the shared installation during acceptance. After explicit authorization to coordinate, both chats handed over their completed animation and sound changes. The final build uses a frozen snapshot of 601 source/resource files; subsequent source work cannot change this artifact. Its full native suite executed 430 tests with 11 skipped and zero failures; lint and Release build passed. The final native candidate repeated fixture scanning, treemap drilldown/return, partial checkout accounting and the actual Craft Hub project jump. Its read-only fingerprints and cleanup checks passed again.

The final package includes the completed sound module's read-only `NowPlaying` helper resources. The installed App displayed current playback information before the final storage-entry check. Temporary candidates use distinct bundle identifiers and the final candidate omits authentication URL handlers to avoid claiming the daily App's sign-in callback. Production installation restores the existing callback declaration and preserves the stable signing identity.

Final records are `final-source-manifest.json`, `final-native-tests.log`, `final-release-build.log`, `final-ui/cleanup.json`, `final-ui/ui-acceptance.json`, `final-installation.json`, and the before/after profile hashes inside the local evidence directory. The temporary snapshot's compilation cache is removed after installation; the source snapshot and accepted App remain.

This acceptance does not enable automatic cleanup. Removal of old build outputs during this chat is a separate, explicitly requested terminal operation with its own bounded manifest.

## Old build cleanup

The separate cleanup removed 25 verified generated directories and surplus candidate bundles, totaling 4,296,560,640 allocated bytes. Available capacity on the same volume increased by 4,147,744,768 bytes during the operation; concurrent applications can also affect that reading.

The manifest covers the obsolete native Swift build layout, rebuildable intermediate/module/index caches, one copied build cache in a historical diagnostic export, old acceptance application copies and superseded native rollback bundles. Installed applications, the current native build products, the latest Augma rollback, the two most recent native rollback bundles, user profiles, drafts, fixture data, screenshots, logs and `.xcresult` evidence remain. The before/after receipts and per-path identities are in the ignored local evidence directory.
