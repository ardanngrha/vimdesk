# Using the workbench

## Your first five minutes

Open a folder containing sibling Git repositories. Click Files, Search, or Git at the top of the left sidebar. Drag its right edge to resize it. File tabs are buffers; duplicate filenames get a parent-directory label.

Neovim starts in Normal mode. Press `i` to type and `Esc` to return to Normal mode. Leader shortcuts are sequential: press `Space`, release it, then the remaining keys. A capital `G` means `Shift+g` for that key only.

| Task | Keys in Normal mode |
| --- | --- |
| Save / Save all | `Space w` / `Space wa` |
| Quit with unsaved-change confirmation | `Space qq` or `:qa` then Enter |
| Undo / redo | `u` / `Ctrl+r` |
| Select characters / lines | `v` / `Shift+v`, then move |
| Copy selection / paste | `y` / `p` |
| Copy current line | `yy` |
| Quick file search | `Space ff` (includes hidden and ignored files) |
| Previous / next buffer | `Shift+h` / `Shift+l` |
| Show commands | `Space p` |
| Show shortcuts | `Space ?` |

Clipboard copying uses the system clipboard when your OS has a Neovim clipboard provider. Run `:Tutor` to learn the basic editing motions.

## Files and folders

Open Files (`Space e`). Right-click a file/folder to open its actions, or click More above the tree. New File, New Folder and Paste also have visible buttons there. `g.` opens the actions menu from the keyboard; `?` shows the explorer's bindings.

| Action, with focus in the file tree | Key |
| --- | --- |
| New file or folder | `a` (end a folder name with `/`) |
| Rename / move | `r`, `F2`, or `m` |
| Copy file/folder | `c` or `Ctrl+c` |
| Paste into the selected folder | `p` or `Ctrl+v` |
| Duplicate alongside the original | `Shift+d` |
| Copy workspace-relative path | `y` |
| Copy absolute path | `Shift+y` |
| Delete, with confirmation | `d` or `Delete` |
| Refresh | `u` |

Select a destination directory before Paste; when a file is selected, Paste uses its containing directory. A name collision creates a `name copy.ext` (or numbered copy) rather than replacing the destination. Folder copies preserve symlinks, and a folder cannot be pasted into itself. File-copy state is separate from the text clipboard, so copying a path does not replace the files waiting to be pasted.

Rename and delete refuse items with unsaved buffers, including files inside a selected directory. Save first. Renames notify attached language servers and update open file/child-buffer paths. The explorer root itself cannot be renamed or deleted.

Delete moves items to this profile's VimDesk trash under `stdpath('state')/workbench/trash/files`, with a manifest of original paths. More → Restore last deleted restores the most recent deletion, including after a restart, and refuses to overwrite an existing destination. It is separate from the OS trash. A failed move (for example across different filesystems) leaves that source in place. Older saved deletions remain in their timestamped directories; no automatic purge runs.

### File icons

The Files toolbar uses six icon buttons, in order: New File, New Folder, More, Collapse All, Reveal Active File, and Paste. The ellipsis opens the named actions menu. These static glyphs use the terminal's Nerd Font and do not load an extra icon provider or run a hover timer. In the header, move the cursor onto an icon and press `K` to show its name; Enter activates it. Button spacing compacts when the sidebar is narrow.

Files uses mini.icons for language/file symbols and open/closed folder symbols. The provider loads on the first Files opening. Other picker views and file tabs keep their existing icon settings.

Choose a Nerd Font in your terminal, such as Hack Nerd Font Mono. On Warp, set it under Settings → Appearance → Text; a newly installed font may need a Warp restart before appearing. Font size can stay unchanged. No icon font is bundled with the configuration.

`Space ui` toggles Files icons in Normal mode, including while the explorer is focused. The command palette also has Explorer: toggle file icons. To start without glyph icons, add `vim.g.workbench_file_icons = false` near the top of your profile's `init.lua`. This keeps the plain tree usable without a Nerd Font.

### Preview tabs and Open Editors

Single-click a file in Files to open a temporary tab, marked `~`. Clicking another file replaces that preview and releases its unedited buffer. Double-click, press Enter in the tree, click its editor tab, or use `Space bp` to keep it. Editing or saving a preview keeps it automatically. A modified buffer or one still visible in another split is never discarded when changing previews. Files that are already open permanently stay permanent.

Open Editors above the tree lists the same file buffers, with `●` for unsaved changes, `~` for a preview, and `×` to close. Closing a modified file asks before saving/closing; Cancel preserves it. The visible list is capped at six rows, keeps the active editor visible, and offers Show all for longer lists. Click the heading to collapse the list. The picker opened by Show all also uses existing buffers; it does not copy their contents.

The icon toolbar exposes **New File**, **New Folder**, **More**, **Collapse**, **Reveal**, and **Paste**, with one blank row above and below it. Reveal selects the active editor file in the tree without changing the workspace root. Files outside the workspace are left alone. Automatic following is disabled so switching files does not continually expand/reposition the tree; use Reveal when needed. Right-click and the existing file-operation keys remain available.

### Light mode

`Space up` toggles Light mode; the command palette has Performance: toggle Light mode. A Light label appears in the status line. In this mode Files skips icons, Git badges, diagnostic badges and directory watchers. Breadcrumbs keep the path but skip tree-sitter symbol lookup. The Git sidebar skips automatic focus refresh and uses its cached status after the initial scan. Refresh explicitly with `u` in Files or `r` in Git; Git commands still refresh status when they finish. Normal mode also reuses Git status for two seconds when rapidly switching views.

Light mode also hides the change overview strips in review panes; full-row and intraline diff colors remain. Turning Light mode off restores normal explorer options and the previous icon preference. The toggle rebuilds the current Files view once, keeping its selection, filter and expanded folders. Other already-open Neovim tabpages retain their existing explorer options until reopened. Watchers still needed by another tabpage are preserved. There is no new periodic refresh timer. Existing language servers and opened files stay attached; this mode does not impose a RAM limit on LSPs or unload their buffers.

## Git across repositories

`Space gG` opens/focuses the Git sidebar. Click a repository's name to select it and display its Changes. Click its branch badge, such as `[staging ↑2 ↓1]`, to open the branch picker for that repository. The arrows show commits ahead of / behind its upstream. Save and commit or stash outstanding changes before switching branches. `Space gP` provides a searchable repo picker; `Space gn` / `Space gp` cycle repositories. Opening a single repository displays its directory name, not `.`.

`Space gg` resolves the current buffer's repository, so it may differ from a previously selected repo. The workspace's parent directory stays unchanged. `:GitRepo` prints the detected root.

1. Review changed files in the Git sidebar. Clicking one opens Before / After.
2. Save your intended file edits. Click `[+]` in the Changes header to stage all, or `[+]` beside one file to stage it. `[−]` unstages files. Stage All includes untracked files except ignored ones; review the list first. Use LazyGit or Gitsigns for individual hunks.
3. Type a subject in the commit textbox, or Generate a draft. Click Commit when ready.
4. Push sends the selected repository's current branch to its remote. When the branch has no upstream, it asks which remote to publish to. Pull updates the selected repository with a fast-forward-only pull. Neither action applies to every repo.
5. Fetch updates the selected repository's remote refs. Fetch All (`Space gF`) fetches each repository's remotes, grouping linked worktrees by shared Git directory. Neither action checks out, merges, or pushes branches.

The second button row is `[Push] [Pull] [Fetch] [Fetch All] [More]`. At narrow widths the remaining buttons wrap onto another row. More includes Open LazyGit, refresh, and other repository actions.

### Graph

Graph appears below Changes for the selected repository. It shows branch lanes, commit subjects and branch labels across local and fetched remote refs. Click a commit to expand its hash, author, refs and changed files; click one of those files to open the historical Before / After comparison. Merge commits compare against their first parent. Root commits compare against an empty Before.

The initial graph contains up to 30 commits. Load more adds 30 at a time, up to 200. Use the refresh button beside Graph to reload history. Expanded commit files are cached by commit hash. Scrolling does not request more Git history.

LazyGit remains available for branches, history, rebase, stash and other Git tasks. Its default keys include `Space` to stage a file, `a` to stage/unstage all in the files panel, `P` to push, and `p` to pull. Panel focus matters; use `?` to inspect the bindings of your installed LazyGit version.

For a branch merge, check out the target branch, pull it, select the source branch, and use LazyGit's merge action (`M` in its branches panel). Confirm the branch direction before proceeding. Conflict resolution is described below.

## Review and resolve conflicts

Click a changed file to review it in the same two resizable Before / After windows, without opening another tab. For unstaged changes, Before is the index and After is the editable working file; staged changes compare HEAD against the index. Historical and staged snapshots are read-only. Inline text review accepts files up to 2 MB; open binary or larger files in another viewer or LazyGit.

Changed rows have a background across the pane and a stronger highlight on the changed text. Lines do not wrap in reviews. A two-column strip on the right shows change locations and the visible part of the file; merge Result also marks unresolved conflict blocks. Light mode hides these strips. Use the command palette's **Git: toggle change overview ruler** to toggle them independently, or set `vim.g.workbench_diff_overview = false` in your config. Native diff highlights remain available when the strip is hidden. Files over 30,000 lines omit the native overview map.

The Changes heading has **Open All**, **Discard All**, and **Stage All**. Narrow sidebars abbreviate these to **[Open] [↶] [+]**. Each working file has **[↶]** to discard and **[+]** to stage. Staged Changes offers Open All and **[−]** to unstage. Conflicts must be resolved and saved before staging.

**Open All** shows the selected repository's working files in one read-only Before / After review, one file after another. Unchanged context is folded; click a file heading to collapse/expand that file. Its Stage / Unstage button updates the index; Open opens the real file, and Enter opens that file's individual diff. Use `[f` / `]f`, or the **↑ / ↓** header buttons, to jump between files. **↻** refreshes the snapshots; **×**, `q`, or `Space gc` closes the combined review. Individual working diffs remain editable; combined snapshots are read-only and need Refresh after editing a real file elsewhere.

The combined review reuses two windows and two content buffers. It shows at most 100 files, 4 MB of snapshot text and 20,000 aligned rows; oversized/binary entries offer individual opening. Untracked folders are expanded into their non-ignored files. In a review containing one language, Vim syntax highlighting is used; mixed-language snapshots retain diff colors without language-specific syntax. No Git process or diff-map scan runs for scrolling.

**Discard** requires confirmation, preserves the index, and saves a recovery copy before changing tracked files. Untracked files/folders move into the recovery directory. The safety backup is limited to 16 MB of tracked content per operation; larger discards are refused. Unsaved buffers block discarding. Use **More → Restore last discard** in the same repo to restore its last saved batch, including after restarting. Restore refuses to overwrite newer disk edits or a changed index; the saved path remains in Git Log for manual recovery. Recovery copies stay in your local state directory until you remove them.

`Space gd` opens the current repo's working-change overview. `Space gD` opens the staged overview. `Space gc` closes either the native file review or a Diffview overview/merge. The explicit commands `:DiffviewOpen`, `:DiffviewOpen --cached` and `:DiffviewClose` control Diffview views only.

Conflicted files open in this layout:

```text
┌───────────────────┬───────────────────┐
│ Incoming (theirs) │ Current (ours)    │
├───────────────────┴───────────────────┤
│ Result — editable                     │
└───────────────────────────────────────┘
```

Drag the vertical and horizontal dividers to resize. Move the cursor to a conflict in Result and use its visible Incoming / Current / Both buttons. Edit Result directly when a combination needs adjustment. Save, review the result, then Stage it. When all conflicts are resolved and staged, the sidebar offers Continue merge.

The labels use Git's ours/theirs semantics. During a rebase, those roles can differ from an ordinary merge; inspect each side's contents before accepting. No button should replace reviewing the result.

## Search and replace

`Space fg` opens Search. Type the search expression and press Enter. Search and Replace are persistent fields; Tab / Shift+Tab moves between fields, Esc leaves field editing.

- Choose All repos or Active repo scope. The active scope uses the selected Git repository.
- Expand Filters for include/exclude patterns separated by `;`.
- Toggle ignored files explicitly for workspace search. Quick file search (`Space ff`) includes ignored files by default.
- Search overlays modified, already-existing file buffers, so unsaved edits are searchable. Save a brand-new file once before expecting it in workspace search.
- Enter a replacement, open its Before / After preview, choose the files to apply, then Apply selected. Applying changes buffers; `Space wa` saves them. Use `u` in an affected file to undo.
- If the source changed while previewing, generate a new preview. Incomplete/truncated search results are not accepted for replacement.

![Replacement preview](images/search.png)

## Terminals, sessions, and code

The bottom panel includes Terminal, Problems, Output, Git Log, Outline and unsaved files. `Space ut` toggles the panel; choose a repository terminal from its tabs/picker. Each terminal keeps a separate working directory and environment for the lifetime of this Neovim process. Restarting Neovim does not preserve running terminal processes.

In a terminal, `Ctrl+\` then `Ctrl+n` returns to Normal mode. A shell may intercept `Ctrl+h/j/k/l`, so use that escape first when needed.

`Space so` requests the current document's LSP outline. Click a symbol to navigate. `gd` goes to definition, `grr` finds references, `K` shows docs, `Space rn` renames a symbol, `Space ca` opens code actions, and `Space cf` formats explicitly. These features require an attached language server.

`Space qs` saves the workspace session and `Space qr` restores it. Sessions remember editing layout/files, not shell processes. Save All (`Space wa`) handles unsaved file buffers; `Space bu` lists them first.

Workspace metadata also remembers the selected repo, commit drafts, sidebar width/mode, expanded folders, explorer filter and scroll position, search/replace fields and search options, Open Editors visibility, and Light/icon preferences. Up to 256 expanded paths are saved per workspace. Search results and directory contents are not serialized; restoring fields does not launch a background search. Missing folders are skipped. Metadata is captured on sidebar close or session save/exit, not on every scroll. An edited buffer must be saved before restoring a session.

When reopening a workspace, VimDesk removes an old session's missing, empty `,` placeholder from the argument list and buffers. Existing files, symlinks, nonempty/modified buffers and an explicit `nvim ,` launch are preserved.

## AI commit drafts

Save the intended edits, stage them, then click Generate in Git. Choose Codex or Claude Code. The result fills the commit textbox for review; it never commits or pushes automatically.

The generator reads the staged patch and stat only, caps the patch at 100 KB, and asks for one English Conventional Commit subject of at most 72 characters. It rejects invalid output, unresolved conflicts, and staged changes made during generation. A user-edited draft is preserved if an earlier generation completes late.

The chosen CLI receives the staged diff through stdin in a temporary working directory. The subprocess disables repository instructions, tools, hooks, and MCP configuration using that CLI's supported flags. The provider still receives the diff and uses your account; stage only content you are comfortable sending. Normal provider usage limits and costs apply.

CLI invocation flags were checked with Codex 0.163.0 and Claude Code 2.1.302. If a newer CLI rejects them, write the subject manually and check Output. The generator only reads Git state and prints a draft. For terminal use:

```sh
python3 "$HOME/.config/vimdesk/scripts/ai_commit.py" --agent codex
```

There is no default AI binding inside standalone LazyGit. This avoids overriding existing custom commands; the persistent sidebar supplies the agent picker, textbox, and review step.
