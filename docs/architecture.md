# Architecture

`file_preview.lua` owns at most one disposable unedited buffer; edited or multiply displayed buffers become permanent. `explorer_panel.lua` renders a bounded Open Editors header from existing buffer metadata and updates on buffer/layout events. `workspace_state.lua` captures paths/options on close/save rather than scroll, without serializing directory contents or search results. `performance.lua` controls Light mode and releases directory watchers that no remaining explorer uses. The existing shared sidebar and Snacks tree continue to own their window/scroll state.

The original goal was a practical handoff: let an agentic editor make changes across sibling projects, then use one Neovim instance to inspect, commit and merge them. A repository picker alone required too much switching; the solution is a persistent Git sidebar alongside native editor windows.

```text
config/nvim/init.lua              Plugin specs, editor options, LSP
config/nvim/lua/
  workbench.lua                  Sidebar, bottom panel, palette, mouse events
  sidebar_ui.lua                 Shared field geometry and styles
  explorer_actions.lua           Files menu, copy state, safe rename/trash/restore
  workbench_theme.lua            TokyoNight surface and semantic colors
  multi_repo.lua                 Buffer roots and bounded repository discovery
  repo_panel.lua / repo_list.lua  Repository state, fetch queue, LazyGit sessions
  scm.lua / commit_box.lua        Git actions, drafts, staged-snapshot guards
  git_graph.lua                  Cached commit graph and expanded file lists
  git_diff.lua                   Reusable native file/history review windows
  git_review.lua                 Diffview overview and three-pane merge controls
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

- **Reusable splits for file review.** Git supplies index/commit blobs asynchronously; ordinary and historical file review swap buffers in the same Before/After windows. Stale results cannot replace a newer selection. The editable working side uses the actual file buffer. Diffview supplies the repository overview and three-pane conflict actions.
- **Stable sidebar geometry.** Files, Search and Git share a native sidebar split. Explorer floats inside it. Input floats anchor to buffer rows and hide outside the viewport. Viewport events update only that sidebar's fields; unchanged content does not rewrite its buffer. Tab metadata is cached on buffer events rather than recomputed during scrolling.
- **Stable workspace directory.** Repository state is keyed by the global workspace cwd; file/LSP roots and Git subprocess cwd are resolved separately. Switching repos does not change the parent workspace.
- **One state per workspace, drafts per repo.** Async AI results return to the originating repo and cannot overwrite a subsequently edited message. Git's staged tree is checked again before using a generated subject.
- **Bounded work.** Discovery yields between chunks, skips dependency directories, and caps depth/directory count. Fetch/status subprocess concurrency is limited to three. Graph initially requests 30 commits, caps expanded history at 200 and displays up to 200 changed files per expanded commit; immutable file lists are cached by hash. Inline file review caps blob size at 2 MB. Search caps its output and rejects unsafe partial replacement previews.
- **Independent installation.** `NVIM_APPNAME` keeps the trial profile away from the default config. Config and launcher updates are staged first, and existing copies are moved to timestamped backups. Plugin cache/state remain separate from source control.
- **Small dependencies at the application layer.** Custom behavior is Lua; the installer and AI adapter use Python's standard library. Third-party plugins are referenced and locked, not vendored.

## Tradeoffs

This remains a terminal application. Command-key shortcuts and mouse behavior depend on the terminal, so visible controls also have Space shortcuts. Language servers and repository terminals can consume resources independently; the workbench is not a resource monitor. Large generated/dependency trees should use narrower scopes and exclusions.

The config is distributed as a complete profile rather than a plugin for arbitrary Neovim setups. Supporting every possible competing sidebar, session manager, or mouse mapping would complicate the UI substantially. Fork the profile to customize it, and retest when changing plugin revisions.
