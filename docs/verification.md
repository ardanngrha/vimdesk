# Initial release verification

Verified on macOS, 18 October 2026, with Neovim 0.12.5 and tree-sitter CLI 0.27.0. These are bounded checks, not a claim that every terminal or operating system is supported.

- A fresh, isolated Neovim profile downloaded the committed plugin revisions using `Lazy! restore`. All 21 configured syntax parsers compiled and installed.
- Eight standard-library tests passed: both AI CLI adapters with fake executables; invalid subjects; changed staged snapshots; empty staging; unresolved conflicts; separate profile installation; quoted paths; backup, restore and symlink preservation; explicit default-profile replacement; uninstall ownership; unsafe paths; and rollback after a simulated failed config swap.
- The native runtime smoke test passed with three sibling repositories. It exercised file-root detection, a real mouse click opening the selected repo's LazyGit, Before/After snapshots, sidebar drag resizing, Incoming/Current/Result geometry, accepting/saving/staging a conflict and continuing its merge, Fetch All against local bare remotes, workspace search, and applying selected replacement edits without writing them to disk.
- The new profile's AI integration used a mocked provider callback to verify the Python executable and script path, draft placement, and unchanged HEAD. The standalone adapter tests invoked both fake CLI executables. No paid provider request was needed for release verification.
- Screenshots show the native rendered Neovim UI from fictional demo repositories. No project source, sessions, credentials, or personal filesystem paths were included.

Linux, Windows, GUI Neovim frontends, and every Go/Rust/Python/Node toolchain combination were not tested for this release. The language server configuration is included; install the relevant server and project runtime before using it. Provider CLI versions can change; the documented versions are the ones used when preparing this adapter.
