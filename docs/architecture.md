# Architecture

The original goal was a practical handoff: let an agentic editor make changes across sibling projects, then use one Neovim instance to inspect, commit and merge them. A repository picker alone required too much switching; the solution is a persistent Git sidebar alongside native editor windows.

```text
config/nvim/init.lua              Plugin specs, editor options, LSP
config/nvim/lua/
  workbench.lua                  Sidebar, bottom panel, palette, mouse events
  sidebar_ui.lua                 Shared field geometry and styles
  workbench_theme.lua            TokyoNight surface and semantic colors
  multi_repo.lua                 Buffer roots and bounded repository discovery
  repo_panel.lua / repo_list.lua  Repository state, fetch queue, LazyGit sessions
  scm.lua / commit_box.lua        Git actions, drafts, staged-snapshot guards
  git_review.lua                 Diffview integration and conflict controls
  workspace_search.lua           Search UI state, scope and filters
  search_engine.lua              Bounded ripgrep search and buffer overlays
  search_box.lua                 Persistent search/replace inputs
  replace_review.lua             Native Before/After preview and selected apply
  repo_terminals.lua             Terminal buffer per repository
  editor_ui.lua / editor_tools.lua Tabs, statusline, Save All, LSP outline
  workbench_plugins.lua          Bufferline, Edgy, Trouble, persistence
  workbench_health.lua           Dependency report and parser installation
config/nvim/scripts/ai_commit.py  Read-only staged-patch → subject adapter
scripts/install.py               Profile installation, backups, restore
```

## Decisions

- **Native splits for review.** Diffview supplies Git snapshots and conflict actions. Native windows provide drag resizing and an editable merge result without rebuilding a Git engine.
- **Stable workspace directory.** Repository state is keyed by the global workspace cwd; file/LSP roots and Git subprocess cwd are resolved separately. Switching repos does not change the parent workspace.
- **One state per workspace, drafts per repo.** Async AI results return to the originating repo and cannot overwrite a subsequently edited message. Git's staged tree is checked again before using a generated subject.
- **Bounded work.** Discovery yields between chunks, skips dependency directories, and caps depth/directory count. Fetch/status subprocess concurrency is limited to three. Search caps its output and rejects unsafe partial replacement previews.
- **Independent installation.** `NVIM_APPNAME` keeps the trial profile away from the default config. Config and launcher updates are staged first, and existing copies are moved to timestamped backups. Plugin cache/state remain separate from source control.
- **Small dependencies at the application layer.** Custom behavior is Lua; the installer and AI adapter use Python's standard library. Third-party plugins are referenced and locked, not vendored.

## Tradeoffs

This remains a terminal application. Command-key shortcuts and mouse behavior depend on the terminal, so visible controls also have Space shortcuts. Language servers and repository terminals can consume resources independently; the workbench is not a resource monitor. Large generated/dependency trees should use narrower scopes and exclusions.

The config is distributed as a complete profile rather than a plugin for arbitrary Neovim setups. Supporting every possible competing sidebar, session manager, or mouse mapping would complicate the UI substantially. Fork the profile to customize it, and retest when changing plugin revisions.
