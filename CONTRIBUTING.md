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

Optional screenshot capture requires Pillow and a local monospace font:

```sh
.venv/bin/pip install Pillow
.venv/bin/python tests/runtime.py --screenshots docs/images --font /path/to/monospace.ttf
```

For visual review, check Files / Search / Git spacing at narrow and wide widths, click different repositories, drag both review dividers, inspect conflict controls, and quit with an unsaved file. Screenshots in `docs/images` come from Neovim's actual rendered UI grid using fictional demo repos; they are not concept mockups.

Keep the lockfile in changes affecting plugins. Test updates in the separate workbench profile first. Record the operating system, Neovim version, and which checks passed in a pull request. Do not claim Linux or terminal compatibility without running it.

## Website and beginner guides

The buildless website lives in `docs/` and GitHub Pages serves `main` → `/docs`. No custom Actions workflow or hosting service is required. The domain is https://ardanngrha.github.io/vimdesk/. All local assets use relative URLs for the project subpath.

Edit `docs/assets/guide.json` for installation steps. The website reads the same data used to generate English and Indonesian Markdown guides:

```sh
python3 scripts/build_guide.py
python3 scripts/build_guide.py --check
python3 -m unittest discover -s tests -v
python3 -m http.server 8766 --directory docs
```

Preview http://127.0.0.1:8766/. Check both languages, the contents disclosure, screenshot tabs, code-copy controls, keyboard navigation, and narrow/intermediate/wide layouts. Test the guide's loading, empty and error states as well as the normal page. There are no analytics, accounts, external fonts, or automatic installation actions. `scripts/demo.sh` creates a new temporary local practice workspace; it never changes global Git identity or existing repos. Website direction is recorded in `DESIGN.md`.
