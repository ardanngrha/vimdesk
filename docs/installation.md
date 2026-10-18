# Installation and maintenance

**First time?** Start with [Install from a fresh Mac](getting-started.md), [panduan Bahasa Indonesia](mulai-dari-nol.md), or the [interactive website](https://ardanngrha.github.io/vimdesk/#install). This page covers reference requirements and maintenance after the beginner walkthrough.

## Requirements

- macOS: tested with Neovim 0.12.5. Linux: installer uses POSIX paths, but the complete UI/toolchain is untested there. Windows is unsupported.
- Required: Neovim **0.12+**, Git, LazyGit, ripgrep (`rg`), fd (`fd`), Python **3.9+**.
- Syntax parsers: `tar`, `curl`, a C compiler, and tree-sitter CLI **0.26.1+**, installed through your package manager. These requirements follow the [pinned Treesitter revision](https://github.com/nvim-treesitter/nvim-treesitter/blob/910fdf6f49e9dee7e7257c7d11a76b040fdfb9de/README.md#requirements).
- Any modern terminal with true color and mouse reporting. No special font is required. On macOS the system clipboard works; Linux may need `wl-clipboard` or `xclip`.

For macOS with Homebrew already installed:

```sh
./scripts/dependencies.sh core
./install.sh doctor
./install.sh
```

The dependency helper installs missing formulae only. It does not upgrade existing versions. If Doctor reports an old Neovim, upgrade it explicitly with `brew upgrade neovim`. If a compiler is missing on macOS, install Apple's command line tools with `xcode-select --install`.

## Separate profile by default

```sh
~/.local/bin/vimdesk /path/to/parent-workspace
```

The launcher sets `NVIM_APPNAME=vimdesk` and the installed config location. Neovim therefore uses its own config, data, state, and cache profile through [NVIM_APPNAME](https://neovim.io/doc/user/starting.html#%24NVIM_APPNAME). The installer honors `XDG_CONFIG_HOME`; Neovim honors the other XDG variables at runtime.

Default paths:

| Content | Location |
| --- | --- |
| Config | `~/.config/vimdesk` |
| Launcher | `~/.local/bin/vimdesk` |
| Plugins and optional JS tools | `~/.local/share/vimdesk` |
| Sessions and state | `~/.local/state/vimdesk` |
| Backups | `~/.config/vimdesk-backups` |

The source checkout is copied, not symlinked. You can move it after installation. Add `export PATH="$HOME/.local/bin:$PATH"` to your shell configuration if needed.

On first launch, let lazy.nvim finish downloading plugins and restart. The first bootstrap pins lazy.nvim itself; the lockfile pins the remaining plugins. Run `:WorkbenchParsers` after installing the compiler and tree-sitter CLI. This downloads and compiles language parsers asynchronously. `:messages` shows parser installation errors. `:Lazy` shows plugin installation errors.

For a scripted bootstrap:

```sh
vimdesk --headless '+Lazy! restore' +qa
vimdesk --headless "+lua require('nvim-treesitter').install(require('workbench_health').parsers):wait(300000)" +qa
```

## Language servers

```sh
./scripts/dependencies.sh languages
```

| Language | Server / required project tools |
| --- | --- |
| Go | `gopls`; a Go toolchain compatible with the project |
| JavaScript, TypeScript, JSX, TSX | `typescript-language-server` + `typescript`; Node.js |
| Rust | `rust-analyzer`; Rust toolchain and Clippy for diagnostics |
| Python | `pyright`, `ruff`; project Python/venv |

The helper installs the JS/TS packages locally under the workbench data directory, avoiding global npm packages. Other servers use Homebrew. For a custom profile, run `NVIM_APPNAME=my-workbench ./scripts/dependencies.sh languages`.

You can install these tools by another method; put their executables on PATH. Config also checks the profile's `tools/node_modules/.bin`, `~/go/bin`, `~/.cargo/bin`, common Homebrew paths, and `~/.local/bin`. Python checks the project's `.venv`, `venv`, and `VIRTUAL_ENV` before falling back to `python3`. There is no automatic format-on-save; `Space cf` formats explicitly.

## AI agents

Install and authenticate either [Codex CLI](https://github.com/openai/codex) or [Claude Code](https://code.claude.com/docs/en/overview) separately. The distribution contains no credentials. The initial release was checked against Codex CLI 0.163.0 and Claude Code 2.1.302; CLI flags may change in future releases.

The Git sidebar's Generate button asks which installed agent to use. Standard LazyGit runs with your existing configuration. No global Ctrl+G binding is installed.

## Update and restore

### Earlier nvim-workbench installations

VimDesk was previously named nvim-workbench. The default installation now uses `~/.config/vimdesk` and `~/.local/bin/vimdesk`; existing profiles stay in place. Reinstall from the renamed checkout to use VimDesk.

To uninstall or restore an older separate profile, pass `--appname nvim-workbench`. The installer recognizes its previous ownership marker and backup directory. Do not delete an earlier config or backup to perform the rename.

### Current installations

Pull the source checkout, then rerun the installer:

```sh
git pull --ff-only
./install.sh
```

Every install prints a timestamped backup directory. It contains `config` and/or `launcher` if those existed before installation. The original config may be a symlink; the link itself is preserved. Keep your own changes in your fork or copy them out of the backup after upgrading. New config replaces the installed copy; upgrades do not merge local edits.

Restore a backup using the exact directory printed by the installer:

```sh
./install.sh restore --backup "$HOME/.config/vimdesk-backups/vimdesk-TIMESTAMP"
```

Restore moves the current config and launcher to another backup first. It consumes the selected backup's config/launcher by moving them back into place. Plugin data, caches, sessions, and project files are never removed or restored by these operations.

To remove the installed profile while preserving it in a backup:

```sh
./install.sh uninstall
```

Uninstall refuses configs without this installer's ownership marker. It leaves data, cache, and state directories in place.

## Replace the default config (optional)

For people who deliberately want `nvim` to use this config:

```sh
./install.sh --appname nvim --replace-default
```

Your old config is moved to a backup first. Existing default-profile plugin data and state are reused, so the separate profile is the recommended way to try the project. The launcher is still named `vimdesk`; the regular `nvim` executable is never overwritten. Use the same two flags when restoring or uninstalling this profile.

Custom locations are available with `--config-home` and `--bin-dir`. Pass the same locations to restore/uninstall. Run `./install.sh --help` for all options.

## Troubleshooting

- **Command not found:** use `~/.local/bin/vimdesk` or add that directory to PATH.
- **No colors / mouse:** check true color and mouse support in your terminal. `Space` shortcuts remain available even when macOS Command shortcuts are intercepted by the terminal.
- **Missing completion/diagnostics:** run `:WorkbenchDoctor`, open a real project with its root file (`go.mod`, `package.json`, `Cargo.toml`, etc.), then check `:checkhealth vim.lsp`.
- **Empty syntax highlighting:** install the parser tools and run `:WorkbenchParsers`. Missing parsers do not block editing.
- **Huge workspace:** open a narrower parent folder. Discovery/search are bounded; language servers and terminals are separate processes whose resource usage depends on the project.
- **Plugin regression:** keep the committed lockfile and use `:Lazy restore`. Updates through `:Lazy update` are your choice and need retesting.
