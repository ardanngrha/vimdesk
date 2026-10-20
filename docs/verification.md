# Verification

## Git sidebar update — 20 October 2026

Verified on macOS with Neovim 0.12.5. All 15 plugin revisions in the public lockfile matched the existing cache used for the UI checks; the checks did not update that cache.

- All 11 standard-library tests passed: AI draft adapters with fake providers, installer/profile backup and restore safeguards, the disposable practice workspace, and synchronized English/Indonesian installation guides.
- The Git sidebar UI test passed with 17 disposable sibling repositories. Actual mouse clicks opened the branch popup and checked out a branch in the selected repository. All five toolbar controls routed correctly at 26-, 36- and 64-column sidebar widths; those button actions were mocked to avoid remote writes.
- Working, staged, untracked, renamed and deleted file reviews passed. Graph expansion, root/merge-commit comparisons, empty repositories, stale-result cancellation, stage refresh and unsaved-buffer preservation passed. Ordinary file/history switching retained the same tab/sidebar/diff windows and produced zero full-screen grid clears in that scenario.
- The scrolling regression passed with 17 repositories and enough commit history to overflow the sidebar. Scrolling stopped at the content boundary; inputs moved with the content, hid outside the viewport, and preserved drafts. Editor-only scrolling caused zero sidebar renders, line writes or input-window reconfiguration in the measured scenario.
- The separate runtime test passed: explicit LazyGit startup, AI draft routing with a mocked provider, resizing, three-pane accept/save/stage/continue merge, Fetch All against local bare remotes, workspace search and replacement preview/apply.
- Lua and JavaScript syntax checks, generated-guide checks and `git diff --check` passed. Public screenshots were regenerated from actual Neovim UI grids using only fictional repositories.

These are bounded regressions, not a peak CPU/GPU benchmark or an end-to-end Linux/WSL validation. No real AI provider was called. Native Windows remains unsupported. Inline text review has a 2 MB file limit; historical merge-file review uses the first parent.

Reproduction commands and dependencies are in [Contributing](../CONTRIBUTING.md).

## Initial release — 18 October 2026

Verified on macOS, 18 October 2026, with Neovim 0.12.5 and tree-sitter CLI 0.27.0. These are bounded checks, not a claim that every terminal or operating system is supported.

- A fresh, isolated Neovim profile downloaded the committed plugin revisions using `Lazy! restore`. All 21 configured syntax parsers compiled and installed.
- Eight standard-library tests passed: both AI CLI adapters with fake executables; invalid subjects; changed staged snapshots; empty staging; unresolved conflicts; separate profile installation; quoted paths; backup, restore and symlink preservation; explicit default-profile replacement; uninstall ownership; unsafe paths; and rollback after a simulated failed config swap.
- The native runtime smoke test passed with three sibling repositories. It exercised file-root detection, a real mouse click opening the selected repo's LazyGit, Before/After snapshots, sidebar drag resizing, Incoming/Current/Result geometry, accepting/saving/staging a conflict and continuing its merge, Fetch All against local bare remotes, workspace search, and applying selected replacement edits without writing them to disk.
- The new profile's AI integration used a mocked provider callback to verify the Python executable and script path, draft placement, and unchanged HEAD. The standalone adapter tests invoked both fake CLI executables. No paid provider request was needed for release verification.
- Screenshots show the native rendered Neovim UI from fictional demo repositories. No project source, sessions, credentials, or personal filesystem paths were included.

Linux, Windows, GUI Neovim frontends, and every Go/Rust/Python/Node toolchain combination were not tested for this release. The language server configuration is included; install the relevant server and project runtime before using it. Provider CLI versions can change; the documented versions are the ones used when preparing this adapter.
