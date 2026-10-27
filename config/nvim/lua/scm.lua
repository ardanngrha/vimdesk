local M = {}
local api = vim.api
local function state() return require('repo_panel').state() end
local function wb() return require('workbench') end
local function clean(text) return (text or ''):gsub('[\r\n\t]', ' ') end
local function trim(text, length) return vim.fn.strcharpart(clean(text), 0, length or 33) end

-- Porcelain -z preserves literal tabs/newlines, quoted paths and rename pairs.
function M.parse(text)
  local parts, index = vim.split(text or '', '\0', { plain = true, trimempty = true }), 1
  local info = { branch = 'unavailable', files = {}, dirty = 0, ahead=0, behind=0, conflicts=0 }
  while index <= #parts do
    local entry = parts[index]; index = index + 1
    if entry:sub(1, 3) == '## ' then
      info.branch = entry:sub(4)
      info.head=info.branch:match('^(.-)%.%.%.') or info.branch:gsub(' %b[]$','')
      info.head=info.head:gsub('^No commits yet on ',''):gsub('^Initial commit on ','')
      info.upstream=info.branch:match('%.%.%.([^ %[]+)')
      info.ahead=tonumber(info.branch:match('ahead (%d+)')) or 0
      info.behind=tonumber(info.branch:match('behind (%d+)')) or 0
      info.gone=info.branch:find('[gone]',1,true)~=nil
    elseif #entry >= 4 then
      local file = { x = entry:sub(1, 1), y = entry:sub(2, 2), path = entry:sub(4) }
      if file.x == 'R' or file.x == 'C' or file.y == 'R' or file.y == 'C' then file.old = parts[index]; index = index + 1 end
      local code = file.x .. file.y
      file.conflict = ({ DD=true, AU=true, UD=true, UA=true, DU=true, AA=true, UU=true })[code] or false
      file.untracked = code == '??'
      file.staged = not file.untracked and not file.conflict and file.x ~= ' ' and file.x ~= '?'
      file.changed = not file.conflict and (file.untracked or (file.y ~= ' ' and file.y ~= '?'))
      info.files[#info.files + 1] = file
    end
  end
  for _,file in ipairs(info.files) do if file.conflict then info.conflicts=info.conflicts+1 end end
  info.dirty = #info.files
  return info
end

function M.selected()
  local s = state(); local win = wb().side_win()
  return (wb().mode == 'git' and win and api.nvim_get_current_win()==win and s.rows[api.nvim_win_get_cursor(win)[1]]) or s.active
end

function M.select(root)
  local s = state();require('commit_box').flush();s.active = root
  M.render(s)
end

function M.render(s) require('repo_list').render(s or state()) end

function M.unsaved(root)
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == '' and vim.bo[buf].modified then
      local name = api.nvim_buf_get_name(buf)
      if name == root or vim.startswith(name, root .. '/') then
        vim.notify('Save modified files before this Git operation.', vim.log.levels.WARN); return true
      end
    end
  end
  return false
end

function M.run(root, args, label, done)
  if not root then vim.notify('Choose a repository first.'); return end
  local s = state(); s.busy = s.busy or {}
  if s.fetching then vim.notify('Wait for Fetch All to finish.'); return end
  if s.busy[root] then vim.notify('Another Git operation is running for this repository.'); return end
  s.busy[root] = label; M.render(s)
  local cmd = { 'git', '-C', root }; vim.list_extend(cmd, args)
  vim.system(cmd, { text = true, timeout = 60000, env = { GIT_TERMINAL_PROMPT = '0' } }, function(result)
    vim.schedule(function()
      s.busy[root] = nil
      local output = vim.trim((result.stdout or '') .. '\n' .. (result.stderr or ''))
      wb().log(vim.fs.basename(root) .. ': ' .. label, output, true)
      s.review_refresh=root
      require('repo_panel').update_status(s)
      require('git_graph').refresh(root)
      vim.cmd.checktime()
      if result.code ~= 0 then
        vim.notify(label .. ' failed; check Git Log. Conflicts appear in Source Control.', vim.log.levels.WARN)
        wb().bottom('gitlog', false)
      end
      if done then done(result) end
    end)
  end)
end

local function node()
  local s, win = state(), wb().side_win()
  return win and s.nodes and s.nodes[api.nvim_win_get_cursor(win)[1]] or nil
end

local function unresolved_markers(root, file)
  if not file.conflict then return false end
  local ok, lines=pcall(vim.fn.readfile,root..'/'..file.path)
  if not ok then return false end
  for _, line in ipairs(lines) do
    if line:match('^<<<<<<< ') or line:match('^>>>>>>> ') then
      vim.notify('Resolve conflict markers and save the result before staging.',vim.log.levels.WARN)
      return true
    end
  end
  return false
end

function M.stage(item, stage)
  item = item or node()
  if not item or not item.file then return end
  if M.unsaved(item.root) then return end
  if stage and unresolved_markers(item.root,item.file) then return end
  local args = stage and { 'add', '--' } or { 'restore', '--staged', '--' }
  if not stage then
    local head = vim.system({ 'git', '-C', item.root, 'rev-parse', '--verify', 'HEAD' }, { text=true }):wait()
    if head.code ~= 0 then args = { 'rm', '--cached', '--' } end
  end
  if item.file.old then args[#args + 1] = item.file.old end
  args[#args + 1] = item.file.path
  M.run(item.root, args, stage and 'Stage file' or 'Unstage file')
end

function M.stage_all(stage,root)
  root = root or M.selected()
  if not root or M.unsaved(root) then return end
  if stage then
    for _, file in ipairs((state().info[root] or {}).files or {}) do if unresolved_markers(root,file) then return end end
  end
  local args = stage and { 'add', '-A', '--', '.' } or { 'restore', '--staged', '--', '.' }
  if not stage then
    local head = vim.system({ 'git', '-C', root, 'rev-parse', '--verify', 'HEAD' }, { text=true }):wait()
    if head.code ~= 0 then args = { 'rm', '--cached', '-r', '--', '.' } end
  end
  M.run(root, args, stage and 'Stage all' or 'Unstage all')
end

function M.diff(item)
  item = item or node()
  local root = item and item.root or M.selected()
  if not root then return end
  require('multi_repo').diff(item and item.staged or false, root, item and item.file and item.file.path)
end

function M.message()
  local root, s = M.selected(), state()
  if not root then return end
  if require('commit_box').focus(root) then return end
  s.drafts = s.drafts or {}
  vim.ui.input({ prompt='Commit subject', default=s.drafts[root] or '' }, function(value)
    if value then s.drafts[root] = value; M.render(s) end
  end)
end

local function staged_tree(root)
  local result = vim.system({ 'git', '-C', root, 'write-tree' }, { text=true }):wait()
  return result.code == 0 and vim.trim(result.stdout) or nil
end

local function has_staged(root)
  local result=vim.system({'git','-C',root,'diff','--cached','--quiet','--'},{text=true}):wait()
  if result.code~=1 then
    vim.notify('Stage changes first using [+] or Stage All.',vim.log.levels.WARN); return false
  end
  local unresolved=vim.system({'git','-C',root,'ls-files','--unmerged'},{text=true}):wait()
  if unresolved.code~=0 or vim.trim(unresolved.stdout)~='' then
    vim.notify('Resolve and stage all conflicts before generating or committing.',vim.log.levels.WARN);return false
  end
  return true
end

local function generate_subject(root, agent)
  require('commit_box').flush()
  local s=state(); root=root or M.selected()
  if not root then return end
  s.busy, s.drafts, s.ai_tree = s.busy or {}, s.drafts or {}, s.ai_tree or {}
  if s.busy[root] or M.unsaved(root) then return end
  if not has_staged(root) then return end
  local python = vim.fn.exepath('python3')
  if python == '' then vim.notify('Install Python 3 to generate a commit subject.', vim.log.levels.WARN); return end
  local tree = staged_tree(root)
  local previous=(s.drafts or {})[root] or ''
  s.commit_notice=s.commit_notice or {}; s.commit_notice[root]='Generating · '..agent.label..'…'
  s.busy[root] = 'Generating commit subject'; M.render(s)
  wb().log(agent.label, 'Generating a subject from staged changes…')
  vim.system({ python, vim.fn.stdpath('config') .. '/scripts/ai_commit.py', '--agent', agent.id },
    { cwd=root, text=true, timeout=190000 }, function(result)
      vim.schedule(function()
        s.busy[root] = nil
        if result.code==0 and staged_tree(root)==tree and ((s.drafts or {})[root] or '')~=previous then
          s.commit_notice[root]='Kept your edit · Generate again'
          wb().log(agent.label,'The message was edited during generation; your edit was kept.')
        elseif result.code == 0 and staged_tree(root) == tree then
          s.drafts[root], s.ai_tree[root] = vim.trim(result.stdout), tree
          s.commit_notice[root]='Draft ready · review message'
          wb().log(agent.label, 'Draft ready; review/edit it, then click Commit.')
        else
          s.commit_notice[root]='Draft unchanged · check Output'
          wb().log(agent.label..' failed', result.stderr~='' and result.stderr or 'Staged changes changed while generating.')
          wb().bottom('output', false); vim.notify('Generation failed; check Output.', vim.log.levels.WARN)
        end
        M.render(s)
      end)
    end)
end


function M.generate(root)
  require('commit_box').flush()
  local s=state(); root=root or M.selected()
  if not root or (s.busy or {})[root] or s.choosing_commit_agent then return end
  if M.unsaved(root) or not has_staged(root) then return end
  local agents={ {id='codex',label='Codex'}, {id='claude',label='Claude Code'} }
  s.choosing_commit_agent=true
  vim.ui.select(agents, {
    prompt='Generate commit · '..vim.fs.basename(root),
    snacks={ win={ input={ keys={ ['<Esc>']={ 'cancel', mode={'n','i'} } } } } },
    format_item=function(agent)
      return agent.label..(vim.fn.executable(agent.id)==1 and '' or ' · CLI not installed')
    end,
  }, function(agent)
    s.choosing_commit_agent=nil
    if not agent then return end
    if vim.fn.executable(agent.id)~=1 then
      vim.notify(agent.label..' CLI is not installed or not on PATH.',vim.log.levels.WARN); return
    end
    -- The popup belongs to the repo that opened it; recheck its staged snapshot.
    generate_subject(root, agent)
  end)
end

function M.commit(root)
  require('commit_box').flush()
  local s=state(); root=root or M.selected()
  if not root or M.unsaved(root) then return end
  if s.busy[root] or not has_staged(root) then return end
  local subject = vim.trim((s.drafts or {})[root] or '')
  if subject == '' then
    if not require('commit_box').focus(root) then M.message() end
    vim.notify('Write a commit message or click Generate first.'); return
  end
  if subject:find('[\r\n%z]') then vim.notify('Use a single-line commit subject.'); return end
  if s.ai_tree and s.ai_tree[root] and s.ai_tree[root] ~= staged_tree(root) then
    vim.notify('Staged changes changed after generation. Regenerate the subject.', vim.log.levels.WARN); return
  end
  M.run(root, { 'commit', '-m', subject }, 'Commit', function(result)
    if result.code == 0 then
      s.drafts[root]=''; if s.ai_tree then s.ai_tree[root]=nil end
      s.commit_notice=s.commit_notice or {}; s.commit_notice[root]='Committed · push when ready'
      M.render(s)
    end
  end)
end

local function clean_repo(root)
  if M.unsaved(root) then return false end
  local result = vim.system({ 'git', '-C', root, 'status', '--porcelain' }, { text=true }):wait()
  if result.code ~= 0 or result.stdout ~= '' then
    vim.notify('Commit or stash changes before switching, pulling, or merging. LazyGit has stash controls.', vim.log.levels.WARN)
    return false
  end
  return true
end

function M.branches(merge,root)
  root = root or M.selected(); if not root then return end
  vim.system({ 'git', '-C', root, 'for-each-ref', '--format=%(refname:short)', 'refs/heads',
    merge and 'refs/heads' or 'refs/remotes' }, { text=true }, function(result)
      vim.schedule(function()
        local branches, seen = {}, {}
        for _, branch in ipairs(vim.split(result.stdout or '', '\n', { trimempty=true })) do
          if not seen[branch] and not branch:match('/HEAD$') then branches[#branches + 1] = branch; seen[branch] = true end
        end
        vim.ui.select(branches, { prompt=merge and 'Merge branch into current branch' or 'Switch branch' }, function(branch)
          if not branch or not clean_repo(root) then return end
          if merge then M.run(root, { 'merge', '--no-edit', '--', branch }, 'Merge ' .. branch)
          else
            local local_branch = vim.system({ 'git', '-C', root, 'show-ref', '--verify', '--quiet', 'refs/heads/' .. branch }):wait().code == 0
            M.run(root, local_branch and { 'switch', '--', branch } or { 'switch', '--track', '--', branch }, 'Switch branch')
          end
        end)
      end)
    end)
end

function M.pull(done)
  local root = M.selected(); if not root or not clean_repo(root) then return end
  M.run(root, { 'pull', '--ff-only' }, 'Pull (fast-forward only)', done)
end
function M.push()
  local root = M.selected(); if not root then return end
  local upstream = vim.system({ 'git', '-C', root, 'rev-parse', '--abbrev-ref', '@{upstream}' }, { text=true }):wait()
  if upstream.code == 0 then M.run(root, { 'push' }, 'Push')
  else
    local branch = vim.trim(vim.system({ 'git', '-C', root, 'branch', '--show-current' }, { text=true }):wait().stdout)
    if branch == '' then vim.notify('Create a branch before publishing detached HEAD.'); return end
    local remotes = vim.split(vim.system({ 'git', '-C', root, 'remote' }, { text=true }):wait().stdout, '\n', { trimempty=true })
    if #remotes==0 then vim.notify('No Git remote configured for this repository.',vim.log.levels.WARN);return end
    vim.ui.select(remotes, { prompt='Publish branch ' .. branch .. ' to remote' }, function(remote)
      if remote then M.run(root, { 'push', '--set-upstream', remote, 'HEAD:refs/heads/' .. branch }, 'Publish branch') end
    end)
  end
end
function M.sync()
  local root = M.selected()
  M.pull(function(result) if result.code == 0 then M.run(root, { 'push' }, 'Sync: push') end end)
end
function M.continue_merge()
  local root = M.selected(); if not root or M.unsaved(root) then return end
  local merge = vim.system({ 'git', '-C', root, 'rev-parse', '-q', '--verify', 'MERGE_HEAD' }):wait()
  if merge.code ~= 0 then vim.notify('No merge is in progress.'); return end
  M.run(root, { '-c', 'core.editor=true', 'merge', '--continue' }, 'Continue merge')
end
function M.discard(item)
  item = item or node(); if not item or not item.file then return end
  if item.staged then vim.notify('Unstage this file before discarding working changes.'); return end
  require('git_discard').discard(item.root,{item.file})
end
function M.discard_all(root)
  root=root or M.selected();if not root then return end
  local files={};for _,file in ipairs((state().info[root] or {}).files or {}) do if file.changed then files[#files+1]=file end end
  require('git_discard').discard(root,files)
end
function M.open_all(root,staged)
  root=root or M.selected();if root then require('git_changes').open(root,staged) end
end

function M.key(key)
  local actions = { ['+']=function() M.stage(nil, true) end, ['-']=function() M.stage(nil, false) end,
    a=function() M.stage_all(true) end, A=function() M.stage_all(false) end,
    c=M.commit, C=M.generate, d=M.diff, D=function() require('multi_repo').diff(true, M.selected()) end,
    F=function() require('repo_panel').fetch(true) end, f=function() require('repo_panel').fetch(false) end,
    r=function() require('repo_panel').refresh() end, l=function() wb().bottom('gitlog') end,
    b=function() M.branches(false) end, m=function() M.branches(true) end, p=M.pull, P=M.push, x=M.discard }
  if actions[key] then actions[key]() end
end
return M
