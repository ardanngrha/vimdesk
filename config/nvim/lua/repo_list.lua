local M={}
local api=vim.api
local function clean(text) return (text or ''):gsub('[%c]',' ') end
local function fit(text,limit)
  if vim.fn.strdisplaywidth(text)<=limit then return text end
  local low,high=0,vim.fn.strchars(text)
  while low<high do
    local mid=math.ceil((low+high)/2)
    if vim.fn.strdisplaywidth(vim.fn.strcharpart(text,0,mid))<=math.max(0,limit-1) then low=mid else high=mid-1 end
  end
  return vim.fn.strcharpart(text,0,low)..'…'
end
function M.render(s)
  local w=require('workbench')
  if w.mode~='git' or not w.side_buf or s~=require('repo_panel').state() then return end
  local win=w.side_win();local width=win and api.nvim_win_get_width(win) or w.width;s.render_width=width
  local old=win and s.nodes and s.nodes[api.nvim_win_get_cursor(win)[1]]
  local lines,actions,highlights={}, {}, {};s.rows,s.nodes={},{}
  s.collapsed=s.collapsed or {}
  local function add(text,action,node,group)
    local row=#lines+1;lines[row]=text;actions[row]=action;s.nodes[row]=node
    if node then s.rows[row]=node.root end
    if group then highlights[#highlights+1]={row,group} end
    return row
  end
  local function range(row,group,first,last)
    if last>first then highlights[#highlights+1]={row,group,first,last} end
  end
  local function buttons(text,action,primary)
    local row=add(text,action)
    for first,last in text:gmatch('()%[[^%]]+%]()') do
      range(row,text:sub(first,last-1)==primary and 'WorkbenchPrimary' or 'WorkbenchButton',first-1,last-1)
    end
    return row
  end
  local function toolbar(items,primary)
    local text,targets='  ',{}
    local function flush()
      local hits=targets
      buttons(text,function(col)
        for _,hit in ipairs(hits) do if col>=hit.first and col<hit.last then hit.run();return end end
      end,primary)
      text,targets='  ',{}
    end
    for _,item in ipairs(items) do
      local label='['..item[1]..']'
      local gap=#targets>0 and ' ' or ''
      if #targets>0 and vim.fn.strdisplaywidth(text..gap..label)>width-2 then flush();gap='' end
      text=text..gap;local first=#text;text=text..label
      targets[#targets+1]={first=first,last=#text,run=item[2]}
    end
    if #targets>0 then flush() end
  end
  local function toggle(key) s.collapsed[key]=not s.collapsed[key];M.render(s) end
  local function heading(title,count,key,right,act,group)
    local prefix=' '..(s.collapsed[key] and '▸ ' or '▾ ')..title..(count and ('  '..count) or '')
    local text=prefix..string.rep(' ',math.max(1,width-vim.fn.strdisplaywidth(prefix)-(right and vim.fn.strdisplaywidth(right) or 0)-2))..(right or '')
    local rightcol=right and vim.fn.strdisplaywidth(text)-vim.fn.strdisplaywidth(right) or width
    local row=add(text,function(col) if right and col>=rightcol then act() else toggle(key) end end,nil,group or 'WorkbenchHeading')
    if right then range(row,'WorkbenchMuted',#text-#right,#text) end
    return row
  end
  heading('Repositories',#s.repos,'repos',nil,nil,'WorkbenchMuted')
  if not s.collapsed.repos then
    for _,root in ipairs(s.repos) do
      local info=s.info[root] or {};local name=require('sidebar_ui').repo_name(s.parent,root)
      local count=tostring(info.dirty or 0)
      local branch=clean(info.head or (info.branch or '…'):gsub('%.%.%..*$',''))
      local sync=info.upstream and (' ↑'..(info.ahead or 0)..' ↓'..(info.behind or 0)) or ''
      local available=math.max(1,width-#count-6)
      local name_min=math.min(8,math.max(1,math.floor(available/3)))
      local badge='['..fit(branch,math.max(1,available-name_min-3-vim.fn.strdisplaywidth(sync)))..sync..']'
      local prefix=' '..(root==s.active and '› ' or '  ')..fit(clean(name),math.max(1,available-vim.fn.strdisplaywidth(badge)-1))..' '..badge
      local text=prefix..string.rep(' ',math.max(1,width-vim.fn.strdisplaywidth(prefix)-#count-2))..count
      local badge_first,badge_last=#prefix-#badge,#prefix
      local row=add(text,function(col)
        require('repo_panel').select(root)
        if col and col>=badge_first and col<badge_last then require('scm').branches(false,root) end
      end,{root=root,kind='repo',key='repo:'..root},root==s.active and 'WorkbenchActive' or nil)
      range(row,root==s.active and 'WorkbenchAccent' or 'WorkbenchMuted',#prefix-#badge,#prefix)
      range(row,root==s.active and 'WorkbenchAccent' or 'WorkbenchMuted',#text-#count,#text)
    end
  end
  if not s.active then
    add(s.scanning and '  Discovering repositories…' or '  No repositories found.',nil,nil,'WorkbenchMuted')
    w.draw(lines,actions,highlights);return
  end
  local root=s.active;local info=s.info[root] or {};local files=info.files or {}
  add('')
  local message_row=#lines+1
  for _=1,5 do add('') end
  local staged=0;for _,file in ipairs(files) do if file.staged then staged=staged+1 end end
  buttons('  [Generate]  [Commit]',function(col)
    require('commit_box').flush()
    if col<14 then require('scm').generate(root) else require('scm').commit(root) end
  end,staged>0 and not s.busy[root] and '[Commit]' or nil)
  toolbar({
    {'Push',function() require('scm').push() end},
    {'Pull',function() require('scm').pull() end},
    {'Fetch',function() require('repo_panel').fetch(false) end},
    {'Fetch All',function() require('repo_panel').fetch(true) end},
    {'More',function() require('repo_panel').more() end},
  },(info.ahead or 0)>0 and '[Push]' or nil)
  if (s.commit_notice or {})[root] then add('  '..fit(clean(s.commit_notice[root]),width-4),nil,nil,'WorkbenchMuted') end
  if s.busy[root] then add('  '..fit(s.busy[root],width-4),nil,nil,'WorkbenchMuted') end
  if s.merging and s.merging[root] then buttons('  [Continue Merge]',function() require('scm').continue_merge() end,'[Continue Merge]') end
  add('')
  local any=false
  for _,group in ipairs({{'Conflicts','conflict',false},{'Staged Changes','staged',true},{'Changes','changed',false}}) do
    local filtered={};for _,file in ipairs(files) do if file[group[2]] then filtered[#filtered+1]=file end end
    if #filtered>0 then
      any=true
      heading(group[1],#filtered,group[2],group[3] and '[−]' or '[+]',function() require('scm').stage_all(not group[3]) end,
        group[2]=='conflict' and 'WorkbenchConflict' or nil)
      if not s.collapsed[group[2]] then
        for _,file in ipairs(filtered) do
          local node={root=root,kind='file',file=file,staged=group[3],key='file:'..root..':'..group[2]..':'..file.path}
          local status=file.conflict and '!' or group[3] and file.x or file.untracked and '?' or file.y
          local base=clean(vim.fs.basename(file.path));local dir=clean(vim.fs.dirname(file.path))
          local name=base..(dir~='.' and ('  '..dir) or '')
          local prefix='  '..status..' '..fit(name,math.max(8,width-10))
          local text=prefix..string.rep(' ',math.max(1,width-vim.fn.strdisplaywidth(prefix)-5))..(group[3] and '[−]' or '[+]')
          local row=add(text,function(col)
            if col>=vim.fn.strdisplaywidth(text)-3 then require('scm').stage(node,not node.staged) else require('scm').diff(node) end
          end,node)
          range(row,file.conflict and 'WorkbenchConflict' or group[3] and 'WorkbenchAdded' or status=='D' and 'WorkbenchRemoved' or 'WorkbenchChanged',2,3)
          range(row,'WorkbenchMuted',math.min(#prefix,4+#base),#prefix)
          range(row,'WorkbenchMuted',#text-3,#text)
        end
      end
    end
  end
  if not any then add('  No changes',nil,nil,'WorkbenchMuted') end
  add('')
  heading('Graph',nil,'graph','[↻]',function() require('git_graph').refresh(root) end)
  if not s.collapsed.graph then
    local graph=require('git_graph');local g=graph.state(root);graph.load(root)
    if g.loading and not g.loaded then add('  Loading history…',nil,nil,'WorkbenchMuted') end
    if g.error then add('  '..g.error,nil,nil,'DiagnosticWarn') end
    if g.loaded and #g.entries==0 and not g.error then add('  No commits yet',nil,nil,'WorkbenchMuted') end
    local count=0
    for _,entry in ipairs(g.entries) do
      local prefix=entry.prefix:gsub('%*','●'):gsub('|','│'):gsub('/','╱'):gsub('\\','╲'):gsub('_','─')
      if entry.sha then
        count=count+1
        local expanded=g.expanded[entry.sha]
        local lead=' '..(expanded and '▾ ' or '▸ ')..prefix
        local ref=entry.refs:match('HEAD %-> ([^,]+)') or entry.refs:match('^([^,]+)')
        local badge=ref and (' ['..fit(ref,math.max(6,math.floor(width/3)-3))..']') or ''
        local text=lead..fit(entry.subject,math.max(6,width-vim.fn.strdisplaywidth(lead..badge)-2))..badge
        local row=add(text,function() graph.toggle(root,entry) end,
          {root=root,kind='commit',sha=entry.sha,key='commit:'..root..':'..entry.sha})
        local lane=(entry.prefix:find('*',1,true) or 1)
        range(row,'WorkbenchGraph'..((math.floor((lane-1)/2)%4)+1),4,#lead)
        if badge~='' then range(row,'WorkbenchAccent',#text-#badge,#text) end
        if expanded then
          local stem='   '..prefix:gsub('●','│')..' '
          add(stem..fit(entry.sha:sub(1,7)..' · '..entry.author,width-vim.fn.strdisplaywidth(stem)-2),nil,nil,'WorkbenchMuted')
          if entry.refs~='' then add(stem..fit(entry.refs,width-vim.fn.strdisplaywidth(stem)-2),nil,nil,'WorkbenchAccent') end
          local changed=g.files[entry.sha]
          if changed and changed.loading then add('    Loading files…',nil,nil,'WorkbenchMuted')
          elseif changed and changed.error then add('    '..changed.error,nil,nil,'DiagnosticWarn')
          elseif changed then
            for _,file in ipairs(changed.items) do
              local base=clean(vim.fs.basename(file.path));local dir=clean(vim.fs.dirname(file.path))
              local text=stem..fit(base..(dir~='.' and '  '..dir or ''),math.max(6,width-vim.fn.strdisplaywidth(stem)-5))
              text=text..string.rep(' ',math.max(1,width-vim.fn.strdisplaywidth(text)-3))..file.status
              local row=add(text,function() require('git_diff').commit(root,entry,file) end,
                {root=root,kind='commit_file',sha=entry.sha,path=file.path,key='commitfile:'..root..':'..entry.sha..':'..file.path})
              range(row,'WorkbenchGraph1',3,#stem)
              range(row,'WorkbenchMuted',#stem+math.min(#base,#text-#stem),#text-1)
              range(row,file.status=='A' and 'WorkbenchAdded' or file.status=='D' and 'WorkbenchRemoved' or 'WorkbenchChanged',#text-1,#text)
            end
            if (changed.total or 0)>#changed.items then add('    Showing first '..#changed.items..' files',nil,nil,'WorkbenchMuted') end
            if #changed.items==0 then add('    No file changes against first parent',nil,nil,'WorkbenchMuted') end
          end
        end
      else add('   '..prefix,nil,nil,'WorkbenchGraph1') end
    end
    if count>=g.limit and g.limit<200 then add('  [Load more commits]',function() graph.more(root) end,nil,'WorkbenchMuted') end
  end
  if s.fetching then add(('  Fetching %d/%d…'):format(s.done or 0,s.total or 0),nil,nil,'WorkbenchMuted') end
  for failed,fetch in pairs(s.fetched or {}) do if fetch.ok==false then add('  '..vim.fs.basename(failed)..': Fetch failed · More → Git Log',function() w.bottom('gitlog') end,nil,'DiagnosticWarn') end end
  w.draw(lines,actions,highlights);s.buf=w.side_buf
  if win then
    if old and old.key then for row,node in pairs(s.nodes) do if node.key==old.key then api.nvim_win_set_cursor(win,{row,0});break end end end
    require('sidebar_ui').clamp(win)
    require('commit_box').show(s,win,message_row)
  end
end
return M
