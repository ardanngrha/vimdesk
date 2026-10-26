# Contributing

Please keep the workflow understandable with visible controls and keyboard alternatives. Preserve the three-pane conflict layout: Incoming left, Current right, editable Result below. Keep project paths, accounts, sessions and credentials out of commits and screenshots.

Use disposable sibling repositories for Git testing. Never run checkout/merge/stage test scenarios against a real project.

## Checks

```sh
python3 -m unittest discover -s tests -v
./install.sh doctor
```

The standard-library suite tests installation backups/restore, quoted paths, profile isolation, default-config safeguards, and both AI providers using fake executables. It needs Git; it does not call real AI providers or require provider credentials.

The runtime smoke test requires core tools and plugins downloaded into a temporary profile:

```sh
python3 -m venv .venv
.venv/bin/pip install pynvim
.venv/bin/python tests/runtime.py
```

It creates and deletes its own temporary Git fixtures, local remotes and isolated Neovim profile. It downloads pinned plugins if absent. It checks multi-repo detection, LazyGit startup, AI draft routing with a mocked provider, Before/After review, Incoming/Current/Result resolution, Fetch All, search, and replacement. It never calls a real AI provider. Neovim children have a bounded lifetime and are closed on failure.

To reuse an existing plugin cache without downloading or updating it, pass `--plugins-dir /path/to/lazy` to the runtime test. Use the committed plugin revisions when validating a release.

The Git sidebar and scroll regressions also require an existing plugin directory:

```sh
.venv/bin/python tests/git_sidebar.py --plugins-dir /path/to/lazy
.venv/bin/python tests/scrolling.py --plugins-dir /path/to/lazy
.venv/bin/python tests/explorer.py --plugins-dir /path/to/lazy
.venv/bin/python tests/navigation.py --plugins-dir /path/to/lazy --report /tmp/navigation.json
.venv/bin/python tests/statusline.py --plugins-dir /path/to/lazy --report /tmp/statusline.json
```

The Git and scroll tests create 17 disposable sibling repositories and an isolated profile. The Git test exercises actual branch-popup checkout, toolbar mouse regions at narrow/wide widths, graph expansion, staged/working/history snapshots, stable window identities and conflict resolution. Push/Pull/Fetch toolbar routing is checked with mocked actions; the runtime test above separately exercises Fetch All against local remotes. The scroll test checks bounded viewports, anchored input fields, preserved drafts and redraw isolation. Neither test downloads plugins or accesses real project repositories. Pass `--source /path/to/config` to verify a copied installation instead of the checkout.

The explorer test creates two disposable sibling repositories. It exercises the right-click menu, visible controls, real create/copy/duplicate/rename/trash/restore operations, path copying, collisions, symlinks and open/unsaved buffers. Its clipboard provider stays in memory, leaving the system clipboard alone. Copy operations use the system `cp` command on macOS/Linux/WSL.

For an icon performance comparison, keep a copy of the previous config and use `tests/benchmark_icons.py --before /path/to/old-config --after /path/to/new-config --plugins-dir /path/to/lazy --report /path/to/results.json`. It measures 17 disposable repositories with 4,097 files, alternates fresh processes, discards warmups and includes same-process icon on/off scroll pairs. Run it without other tests in parallel. The result is Neovim process CPU/RSS and embedded UI timing, not a terminal/WindowServer GPU benchmark. No plugins are installed during timed runs.

Use `--comparison navigation --within-pairs 0` when both configs already enable file icons. Use `--comparison light --within-pairs 0` to compare an icon-enabled baseline with a new config starting in Light mode. Compare the same terminal dimensions and report the actual tree row counts: Open Editors occupies part of the viewport, so these measurements compare the whole UI at a fixed screen size rather than identical tree heights.

For a same-process comparison of the new UI's normal/Light rendering, use `--comparison light --pairs 0 --within-pairs 8`. The harness rebuilds the explorer between modes, waits for finding to settle and alternates their order. mini.icons stays loaded once normal mode has used it, so this comparison does not measure the fresh-start memory savings of avoiding that provider.

The navigation test sends real single/double clicks and Enter, verifies preview retention for edits/splits, checks 100 preview opens do not accumulate listed file buffers, exercises the file/folder toolbar and bounded Open Editors, checks watcher release/restoration, and saves/restores a session across separate Neovim processes. All fixtures and profile state are disposable.

The statusline test asserts actual rendered mode/branch cells while focusing the editor, Files tree/filter/Open Editors, Search, Git commit input and terminal. It checks float bounds during resize/header changes and Light mode, plus terminal I/O and reuse across panel toggles. This catches blank borders covering a correct statusline string. Optional screenshots use the same RGB grid. Computer Use access to Warp can be unavailable; embedded Neovim QA is not proof of Warp's native rendering or GPU behavior.

Optional screenshot capture requires Pillow and a local monospace font:

```sh
.venv/bin/pip install Pillow
.venv/bin/python tests/runtime.py --screenshots docs/images --font /path/to/monospace.ttf
```

For visual review, check Files / Search / Git spacing at narrow and wide widths, click different repositories, drag both review dividers, inspect conflict controls, and quit with an unsaved file. Screenshots in `docs/images` come from Neovim's actual rendered UI grid using fictional demo repos; they are not concept mockups.

Keep the lockfile in changes affecting plugins. Test updates in the separate workbench profile first. Record the operating system, Neovim version, and which checks passed in a pull request. Do not claim Linux or terminal compatibility without running it.

## Website and beginner guides

The buildless website lives in `docs/` and GitHub Pages serves `main` → `/docs`. No custom Actions workflow or hosting service is required. The domain is https://ardanngrha.github.io/vimdesk/. All local assets use relative URLs for the project subpath.

Edit `docs/assets/guide.json` for shared installation steps and `docs/assets/platform-guides.json` for OS metadata, Linux/WSL steps, and their order. The website reads the same data used to generate six Markdown guides: macOS, Linux, and Windows via WSL 2, each in English and Indonesian. Terminal blocks are shell syntax-checked without executing installs; PowerShell blocks are checked as WSL commands, not executed on macOS.

```sh
python3 scripts/build_guide.py
python3 scripts/build_guide.py --check
python3 -m unittest discover -s tests -v
python3 -m http.server 8766 --directory docs
```

Preview http://127.0.0.1:8766/. Check both languages, the contents disclosure, screenshot tabs, code-copy controls, keyboard navigation, and narrow/intermediate/wide layouts. Test the guide's loading, empty and error states as well as the normal page. There are no analytics, accounts, external fonts, or automatic installation actions. `scripts/demo.sh` creates a new temporary local practice workspace; it never changes global Git identity or existing repos. Website direction is recorded in `DESIGN.md`.
