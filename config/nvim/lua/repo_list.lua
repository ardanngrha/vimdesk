local M={}
local api=vim.api
local function clean(text) return (text or ''):gsub('[\r\n\t]',' ') end
function M.render(s)
  local w=require('workbench')
  if w.mode~='git' or not w.side_buf then return end
  if s~=require('repo_panel').state() then return end
  local width=w.side_win() and api.nvim_win_get_width(w.side_win()) or w.width
  local lines,actions,highlights={}, {}, {}
  local win=w.side_win(); local old=win and s.nodes and s.nodes[api.nvim_win_get_cursor(win)[1]]
  s.rows,s.nodes={},{}
  local function add(text,action,node,hl)
    local row=#lines+1; lines[row]=text; actions[row]=action; s.nodes[row]=node
    if node then s.rows[row]=node.root end
    if hl then highlights[#highlights+1]={row,hl} end
    return row
  end
  local function range(row,group,first,last)
    if last>first then highlights[#highlights+1]={row,group,first,last} end
  end
  local function fit(text,limit)
    local count=vim.fn.strchars(text)
    while count>0 and vim.fn.strdisplaywidth(vim.fn.strcharpart(text,0,count))>limit do count=count-1 end
    return vim.fn.strcharpart(text,0,count)
  end
  local function counted(label,count,action,group)
    local text='  '..label
    local badge=tostring(count)
    text=text..string.rep(' ',math.max(1,width-vim.fn.strdisplaywidth(text)-#badge-2))..badge
    local row=add(text,action,nil,group or 'WorkbenchHeading')
    range(row,'WorkbenchMuted',#text-#badge,#text)
    return row
  end
  local function buttons(text,action,primary)
    local row=add(text,action)
    for first,last in text:gmatch('()%[[^%]]+%]()') do
      local name=text:sub(first,last-1)
      range(row,name==primary and 'WorkbenchPrimary' or 'WorkbenchButton',first-1,last-1)
    end
    return row
  end
  local function rule() add('  '..string.rep('─',math.max(8,width-4)),nil,nil,'WorkbenchRule') end
  add('')
  add('  '..vim.fs.basename(s.parent),nil,nil,'WorkbenchMuted')
  add('')
  counted('Repositories ▾',#s.repos,function() w.choose_repo() end,'WorkbenchMuted')
  for _,root in ipairs(s.repos) do
    local name=require('sidebar_ui').repo_name(s.parent,root)
    local info=s.info[root] or {}; local branch=(info.branch or ''):gsub('%.%.%..*$','')
    local prefix='  '..(root==s.active and '› ' or '  ')..fit(clean(name),math.max(8,width-9))
    local count=tostring(info.dirty or 0)
    local text=prefix..string.rep(' ',math.max(1,width-vim.fn.strdisplaywidth(prefix)-#count-2))..count
    local row=add(text,function() require('repo_panel').open_lazygit(root) end,{root=root,kind='repo'},root==s.active and 'WorkbenchActive' or nil)
    range(row,root==s.active and 'WorkbenchAccent' or 'WorkbenchMuted',#text-#count,#text)
    local tracking='  '..(info.head or branch or 'Reading status…')
    if info.upstream and not info.gone then tracking=tracking..' · ↑'..(info.ahead or 0)..' ↓'..(info.behind or 0)
    elseif info.head then tracking=tracking..' · unpublished' end
    if (info.conflicts or 0)>0 then tracking=tracking..' · !'..info.conflicts end
    add('  '..fit(tracking,math.max(12,width-4)),function() require('repo_panel').open_lazygit(root) end,nil,
      (info.conflicts or 0)>0 and 'WorkbenchConflict' or 'WorkbenchMuted')
  end
  local selected=s.info[s.active] or {}
  local branch=(selected.branch or 'Reading status…'):gsub('%.%.%..*$','')
  add('  '..(selected.head or branch)..' ▾ · '..(selected.dirty or 0)..' changes',function() require('scm').branches(false) end,nil,'WorkbenchMuted')
  add('')
  local message_row=#lines+1
  for _=1,5 do add('') end
  local staged=0; for _,file in ipairs(selected.files or {}) do if file.staged then staged=staged+1 end end
  buttons('  [Generate]  [Commit]',function(col)
    require('commit_box').flush()
    if col<14 then require('scm').generate(s.active) else require('scm').commit(s.active) end
  end,staged>0 and not s.busy[s.active] and '[Commit]' or nil)
  add('  '..staged..' staged · '..(staged>0 and 'Generate only drafts' or 'Stage changes first'),nil,nil,'WorkbenchMuted')
  if (s.commit_notice or {})[s.active] then
    add('  '..fit(clean(s.commit_notice[s.active]),math.max(12,width-4)),nil,nil,'WorkbenchMuted')
  end
  add('')
  buttons('  [LazyGit]   [Fetch All]',function(col)
    if col<13 then require('repo_panel').open_lazygit(s.active) else require('repo_panel').fetch(true) end
  end,'[LazyGit]')
  local push=(selected.upstream and not selected.gone) and 'Push' or 'Publish'
  buttons('  ['..push..']  [Pull]',function(col)
    if col<4+#push then require('scm').push() else require('scm').pull() end
  end,(selected.ahead or 0)>0 and '['..push..']' or nil)
  buttons('  [Stage All] [Unstage All]',function(col) require('scm').stage_all(col<14) end)
  buttons(s.fetching and ('  Fetching %d/%d…'):format(s.done or 0,s.total or 0) or '  [Refresh]   [Git Log]',function(col)
    if col<14 then require('repo_panel').refresh() else w.bottom('gitlog') end
  end)
  if s.active and s.merging and s.merging[s.active] then
    buttons('  [Continue Merge]',function() require('scm').continue_merge() end,'[Continue Merge]')
  end
  add('')
  rule()
  local info=s.info[s.active] or {}; local files=info.files or {}
  for _,group in ipairs({{'Conflicts','conflict',false},{'Staged Changes','staged',true},{'Changes','changed',false}}) do
    local filtered={}; for _,file in ipairs(files) do if file[group[2]] then filtered[#filtered+1]=file end end
    if #filtered>0 then
      counted(group[1],#filtered,nil,group[2]=='conflict' and 'WorkbenchConflict' or 'WorkbenchHeading')
      for _,file in ipairs(filtered) do
        local node={root=s.active,kind='file',file=file,staged=group[3]}
        local sign=group[3] and '-' or '+'
        local status=file.conflict and '!' or (group[3] and file.x or file.untracked and '?' or file.y)
        local base=clean(vim.fs.basename(file.path)); local dir=clean(vim.fs.dirname(file.path))
        local name=base..(dir~='.' and ('  '..dir) or '')
        local prefix='  '..status..' '..fit(name,math.max(8,width-9))
        local text=prefix..string.rep(' ',math.max(1,width-vim.fn.strdisplaywidth(prefix)-4))..'['..sign..']'
        local row=add(text,function(col)
          if col>=#text-3 then require('scm').stage(node,not node.staged) else require('scm').diff(node) end
        end,node)
        local color=file.conflict and 'WorkbenchConflict' or group[3] and 'WorkbenchAdded'
          or file.untracked and 'WorkbenchAdded' or status=='D' and 'WorkbenchRemoved' or 'WorkbenchChanged'
        range(row,color,2,3)
        range(row,'WorkbenchMuted',math.min(#prefix,4+#base),#prefix)
        range(row,group[3] and 'WorkbenchButton' or 'WorkbenchAdded',#text-3,#text)
      end
      add('')
    end
  end
  if s.scanning then add('  Discovering repositories…',nil,nil,'WorkbenchMuted')
  elseif s.loaded and #s.repos==0 then add('  No repositories found.',nil,nil,'WorkbenchMuted')
  elseif #files==0 then add('  No changes in this repository.',nil,nil,'WorkbenchMuted') end
  for root,fetch in pairs(s.fetched or {}) do
    if fetch.ok==false then add('  '..vim.fs.basename(root)..': Fetch failed → Git Log',function() w.bottom('gitlog') end,nil,'DiagnosticWarn') end
  end
  if s.active and s.busy[s.active] then add('  '..s.busy[s.active],nil,nil,'WorkbenchMuted') end
  w.draw(lines,actions,highlights); s.buf=w.side_buf
  if win then require('commit_box').show(s,win,message_row) end
  if win and old then
    for row,node in pairs(s.nodes) do
      if node.root==old.root and node.kind==old.kind and ((not old.file and not node.file) or
        (old.file and node.file and old.file.path==node.file.path and old.staged==node.staged)) then
        api.nvim_win_set_cursor(win,{row,0}); break
      end
    end
  end
end
return M
