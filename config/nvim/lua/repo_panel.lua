local M = {}
local spaces, terminals = {}, {}
local api, uv = vim.api, vim.uv
function M.state()
  -- Workspace identity ignores window-local cwd used internally by pickers.
  local cwd=vim.fn.getcwd(-1,0)
  local parent = uv.fs_realpath(cwd) or cwd
  if not spaces[parent] then spaces[parent] = { parent=parent, repos={}, rows={}, info={}, fetched={}, loaded=false, drafts={}, busy={} } end
  return spaces[parent]
end
function M.render(s) require('scm').render(s or M.state()); vim.cmd('redraw!') end
function M.selected_root() return require('scm').selected() end
function M.visible() return require('workbench').mode == 'git' and require('workbench').side_win() ~= nil end
function M.show(focus) return require('workbench').sidebar('git', focus) end
function M.hide() require('workbench').hide_sidebar() end
function M.toggle() if M.visible() then M.hide() else M.show(true) end end
function M.mouse() return require('workbench').mouse() end

local function parallel(items, run, finished)
  local next_item, running, completed = 1, 0, 0
  local pump
  pump = function()
    while running < 3 and next_item <= #items do
      local item = items[next_item]; next_item, running = next_item + 1, running + 1
      run(item, function()
        running, completed = running - 1, completed + 1
        if completed == #items then finished() else pump() end
      end)
    end
    if #items == 0 then finished() end
  end
  pump()
end

function M.update_status(s)
  s = s or M.state()
  if s.reading then s.pending_status = true; return end
  s.reading = true
  parallel(vim.deepcopy(s.repos), function(root, done)
    vim.system({ 'git', '-C', root, 'status', '--porcelain=v1', '-z', '--branch' },
      { text=true, timeout=10000, env={ GIT_OPTIONAL_LOCKS='0' } }, function(result)
        vim.schedule(function()
          s.info[root] = require('scm').parse(result.stdout)
          s.merging = s.merging or {}
          s.merging[root] = vim.system({ 'git', '-C', root, 'rev-parse', '-q', '--verify', 'MERGE_HEAD' }):wait().code == 0
          M.render(s); done()
        end)
      end)
  end, function()
    s.reading = false
    if s.pending_status then s.pending_status = nil; M.update_status(s) end
  end)
end

function M.refresh(s)
  s = s or M.state()
  if s.scanning or s.fetching then return end
  s.scanning = true; M.render(s)
  require('multi_repo').discover(s.parent, function(repos, truncated)
    s.repos, s.loaded, s.scanning = repos, true, false
    if not vim.tbl_contains(repos, s.active) then s.active = repos[1] end
    M.render(s); M.update_status(s)
    if truncated then vim.notify('Repo scan reached its limit; use a narrower workspace.', vim.log.levels.WARN) end
    if s.after_scan then local fn=s.after_scan; s.after_scan=nil; fn() end
  end)
end

function M.fetch(all)
  local s = M.state()
  if s.fetching then vim.notify('Fetch is already running.'); return end
  if not s.loaded or s.scanning then
    s.after_scan = function() M.fetch(all) end
    if not s.scanning then M.refresh(s) end
    return
  end
  local roots = all and s.repos or { M.selected_root() }
  if #roots == 0 then vim.notify('No repositories to fetch.'); return end
  local groups, order = {}, {}
  for _, root in ipairs(roots) do
    if s.busy[root] then vim.notify('Wait for the current Git operation before fetching.'); return end
    local result = vim.system({ 'git', '-C', root, 'rev-parse', '--git-common-dir' }, { text=true }):wait()
    local common = result.code == 0 and vim.trim(result.stdout) or root
    if not vim.startswith(common, '/') then common = root .. '/' .. common end
    common = uv.fs_realpath(common) or common
    if not groups[common] then groups[common]={}; order[#order+1]=groups[common] end
    table.insert(groups[common], root); s.fetched[root]={ label='Queued' }
  end
  s.fetching, s.done, s.total = true, 0, #roots; M.render(s)
  parallel(order, function(group, done)
    for _, root in ipairs(group) do s.fetched[root]={ label='Fetching…' } end
    M.render(s)
    vim.system({ 'git', '-C', group[1], 'fetch', '--all', '--no-recurse-submodules' },
      { text=true, timeout=60000, env={ GIT_TERMINAL_PROMPT='0' } }, function(result)
        vim.schedule(function()
          for _, root in ipairs(group) do
            s.fetched[root]={ ok=result.code==0, label=result.code==0 and '✓ Fetched' or '✗ Fetch failed · Git Log',
              output=vim.trim((result.stderr or '') .. '\n' .. (result.stdout or '')) }
            s.done=s.done+1
            require('workbench').log(vim.fs.basename(root) .. ': Fetch', s.fetched[root].output, true)
          end
          M.render(s); done()
        end)
      end)
  end, function()
    s.fetching=false
    local failed=0; for _, root in ipairs(roots) do if not s.fetched[root].ok then failed=failed+1 end end
    M.render(s); M.update_status(s)
    vim.notify(('Fetch complete: %d succeeded, %d failed.'):format(#roots-failed, failed), failed>0 and vim.log.levels.WARN or vim.log.levels.INFO)
  end)
end
function M.log() require('workbench').bottom('gitlog') end
function M.hide_lazygit()
  M.transitioning=true
  for _, terminal in pairs(terminals) do if terminal:win_valid() then terminal:hide() end end
  M.transitioning=false
end
function M.open_lazygit(root)
  if not root then return end
  require('commit_box').flush()
  require('git_review').close()
  local s=M.state(); s.active=root
  local w=require('workbench')
  if not w.side_win() or w.mode~='git' then w.sidebar('git',false) end
  M.transitioning=true
  for other, terminal in pairs(terminals) do if other~=root and terminal:win_valid() then terminal:hide() end end
  M.render(s)
  local terminal=terminals[root]
  if terminal and terminal:valid() then terminal:focus(); vim.cmd.startinsert(); M.transitioning=false; return terminal end
  w.focus_editor()
  local function editor() return w.main() end
  local function pos() return api.nvim_win_get_position(editor()) end
  local branch=(s.info[root] and s.info[root].branch or ''):gsub('%.%.%..*$','')
  terminal=Snacks.lazygit({ cwd=root, win={ position='float', relative='editor',
    col=function() return pos()[2] end,row=function() return pos()[1]+1 end,
    width=function() return math.max(20,api.nvim_win_get_width(editor())-2) end,
    height=function() return math.max(8,api.nvim_win_get_height(editor())-2) end,
    border='single', backdrop=false, title=' '..vim.fs.basename(root)..' · '..branch..' ',
    on_buf=function(self) vim.b[self.buf].workspace_repo_root=root end,
    on_close=function(self)
      local restore=not M.transitioning and api.nvim_get_current_win()==self.win
      vim.schedule(function() M.update_status(); if restore then w.focus_editor() end end)
    end,
    keys={ repo_panel={ '<C-\\><C-r>', function() M.hide_lazygit(); M.show(true) end, mode={'n','t'} },
      repo_mouse={ '<LeftMouse>', function(self)
        local mouse=vim.fn.getmousepos()
        -- Resume terminal input before forwarding clicks after double Escape.
        -- Leave clicks on the sidebar, editor tabs and borders to Neovim.
        if mouse.winid==self.win and mouse.line>0 and mouse.column>0 then return 'i<LeftMouse>' end
        return '<LeftMouse>'
      end, mode='n', expr=true, desc='Focus and click LazyGit' },
    },
  } })
  terminals[root]=terminal; M.transitioning=false; vim.cmd.redrawstatus(); return terminal
end
function M.diff(staged) require('multi_repo').diff(staged, M.selected_root()) end
function M.cycle(direction)
  local s=M.state(); M.show(false)
  if not s.loaded or s.scanning then s.after_scan=function() M.cycle(direction) end; return end
  if #s.repos==0 then return end
  local index=1; for i, root in ipairs(s.repos) do if root==s.active then index=i; break end end
  M.open_lazygit(s.repos[((index-1+direction)%#s.repos)+1])
end
function M.setup()
  vim.keymap.set('n', '<leader>gR', M.toggle, { desc='Toggle Source Control' })
  vim.keymap.set('n', '<leader>gF', function() M.show(false); M.fetch(true) end, { desc='Fetch All repositories' })
  vim.keymap.set('n', '<leader>gn', function() M.cycle(1) end, { desc='Next repository' })
  vim.keymap.set('n', '<leader>gp', function() M.cycle(-1) end, { desc='Previous repository' })
  api.nvim_create_user_command('GitFetchAll', function() M.show(false); M.fetch(true) end, {})
  api.nvim_create_autocmd('FocusGained', { callback=function() if M.visible() then M.update_status() end end })
end
return M
