local M = {}
local uv = vim.uv

local function existing_dir(path)
  path = vim.fs.normalize(path)
  local stat = uv.fs_stat(path)
  if not stat or stat.type ~= 'directory' then path = vim.fs.dirname(path) end
  while path and not uv.fs_stat(path) do path = vim.fs.dirname(path) end
  return path
end

function M.root(path)
  local dir = existing_dir(path)
  if not dir then return nil end
  local result = vim.system({ 'git', '-C', dir, 'rev-parse', '--show-toplevel' }, { text = true }):wait()
  if result.code ~= 0 then return nil end
  return uv.fs_realpath(vim.trim(result.stdout)) or vim.trim(result.stdout)
end

function M.current_root()
  if vim.b.workspace_repo_root then return vim.b.workspace_repo_root end
  if vim.bo.filetype == 'workbench_sidebar' then return require('repo_panel').selected_root() end
  local name = vim.api.nvim_buf_get_name(0)
  -- Index snapshots can look like normal buffers but have virtual paths.
  -- Resolve the active review's repo before interpreting those buffer names.
  local lib = package.loaded['diffview.lib']
  if lib then
    local view = lib.get_current_view()
    if view and view.adapter and view.adapter.ctx then return view.adapter.ctx.toplevel end
  end
  if vim.bo.buftype == '' and name ~= '' then return M.root(name) end
  if name ~= '' and uv.fs_stat(name) then return M.root(name) end
  return M.root(vim.fn.getcwd())
end

local skip = { ['.git'] = true, node_modules = true, vendor = true, dist = true, build = true,
  target = true, ['.next'] = true, ['.cache'] = true, ['.venv'] = true, coverage = true }

-- Incremental scan recognizes both .git directories and worktree .git files.
function M.discover(parent, callback)
  parent = uv.fs_realpath(parent) or vim.fs.normalize(parent)
  local queue, repos, seen, index = { { parent, 0 } }, {}, {}, 1
  local truncated = false
  local function step()
    local stop = math.min(index + 99, #queue)
    while index <= stop do
      local item = queue[index]
      index = index + 1
      local dir, depth = item[1], item[2]
      if uv.fs_stat(dir .. '/.git') then
        local root = M.root(dir)
        if root and not seen[root] then seen[root] = true; repos[#repos + 1] = root end
      end
      if depth < 6 then
        local handle = uv.fs_scandir(dir)
        if handle then
          while true do
            local name, kind = uv.fs_scandir_next(handle)
            if not name then break end
            if kind == 'directory' and not skip[name] and name:sub(1, 1) ~= '.' then
              if #queue < 20000 then queue[#queue + 1] = { dir .. '/' .. name, depth + 1 }
              else truncated = true end
            end
          end
        end
      end
    end
    if index <= #queue then vim.schedule(step)
    else table.sort(repos); callback(repos, truncated) end
  end
  vim.schedule(step)
end

function M.open(root)
  if not root then
    vim.notify('This buffer is outside a Git repo. Use <Space>gG to pick a child repo.', vim.log.levels.WARN)
    return
  end
  require('git_review').close()
  if require('repo_panel').visible() then return require('repo_panel').open_lazygit(root) end
  return Snacks.lazygit({ cwd = root, win = {
    on_buf = function(self) vim.b[self.buf].workspace_repo_root = root end,
  } })
end

function M.quick_pick()
  local parent = vim.fn.getcwd()
  vim.notify('Finding Git repos in ' .. parent)
  M.discover(parent, function(repos, truncated)
    if truncated then vim.notify('Repo scan reached its directory limit; open a narrower parent folder.', vim.log.levels.WARN) end
    if #repos == 0 then vim.notify('No Git repos found within 6 levels of this workspace.', vim.log.levels.WARN); return end
    Snacks.picker.select(repos, {
      prompt = 'Git repos in ' .. parent,
      format_item = function(repo) return vim.fs.relpath(parent, repo) or repo end,
    }, function(repo) if repo then M.open(repo) end end)
  end)
end

function M.pick() return require('workbench').open_git() end

function M.diff(staged, root, path)
  root = root or M.current_root()
  if not root then vim.notify('Open a file inside a Git repo first.', vim.log.levels.WARN); return end
  return require('git_review').open(root,path,staged)
end

function M.setup()
  vim.keymap.set('n', '<leader>gg', function() M.open(M.current_root()) end, { desc = 'LazyGit: current buffer repo' })
  vim.keymap.set('n', '<leader>gG', M.pick, { desc = 'Repositories: focus sidebar' })
  vim.keymap.set('n', '<leader>gP', M.quick_pick, { desc = 'Repositories: search child repo' })
  vim.keymap.set('n', '<leader>gd', function() M.diff(false) end, { desc = 'Diffview: changes / conflicts' })
  vim.keymap.set('n', '<leader>gD', function() M.diff(true) end, { desc = 'Diffview: staged changes' })
  vim.keymap.set('n', '<leader>gc', function() require('git_review').close() end, { desc = 'Close Git review' })
  vim.api.nvim_create_user_command('GitRepo', function() print(M.current_root() or 'No Git repo for this buffer') end, {})
  vim.api.nvim_create_user_command('GitRepos', M.pick, {})
  require('repo_panel').setup()
end

return M
