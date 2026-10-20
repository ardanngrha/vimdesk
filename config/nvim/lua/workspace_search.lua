local M={query='',replacement='',include='',exclude='',scope='all',case=false,word=false,ignored=false,hidden=true,regex=false,
  results={},generation=0,selected_files={},filters=false}
local api=vim.api
local function wb() return require('workbench') end
function M.root()
  if M.scope=='repo' then
    return require('repo_panel').state().active or require('multi_repo').current_root()
  end
  return vim.fn.getcwd(-1,0)
end
local function signature()
  return vim.json.encode({M.root(),M.query,M.include,M.exclude,M.case,M.word,M.ignored,M.hidden,M.regex})
end
function M.invalidate_preview()
  M.preview=nil;require('replace_review').close()
end
function M.render()
  if wb().mode~='search' then return end
  local root=M.root()
  if M.parent and root~=M.parent then
    M.generation=M.generation+1;M.results={};M.running=false;M.parent=root;M.invalidate_preview();M.changed()
  end
  local lines,actions,hl={}, {}, {}
  local function add(text,fn,group)
    lines[#lines+1]=text;actions[#lines]=fn
    if group=='WorkbenchButton' or group=='WorkbenchPrimary' then
      for first,last in text:gmatch('()%[[^%]]+%]()') do
        local token=text:sub(first,last-1)
        hl[#hl+1]={#lines,token=='[Cancel]' and 'WorkbenchButton' or group,first-1,last-1}
      end
    elseif group then hl[#hl+1]={#lines,group} end
    return #lines
  end
  for _=1,9 do add('') end
  add('  '..(M.scope=='all' and '[x] All repos  [ ] Active repo' or '[ ] All repos  [x] Active repo'),function(col)
    M.scope=col<17 and 'all' or 'repo';M.run()
  end,'WorkbenchMuted')
  add('  '..(root and require('sidebar_ui').repo_name(vim.fn.getcwd(-1,0),root) or 'Choose a repository'),nil,'WorkbenchMuted')
  add('  ['..(M.filters and '▾' or '▸')..' File filters]',function() M.filters=not M.filters;M.render() end,'WorkbenchButton')
  local fields={query=2,replacement=6}
  if M.filters then
    fields.include=#lines+1;for _=1,4 do add('') end
    fields.exclude=#lines+1;for _=1,4 do add('') end
  else add('') end
  add('  [Search]  [Preview]',function(col) if col<12 then M.run() else M.preview_replace() end end,'WorkbenchButton')
  if M.preview then
    add('  [Apply selected]  [Cancel]',function(col) if col<20 then M.apply_preview() else M.invalidate_preview();M.render() end end,'WorkbenchPrimary')
    add('  '..#M.preview.plans..' files · edits stay unsaved',nil,'WorkbenchMuted')
  else add('') end
  for _,option in ipairs({{'case','Match case'},{'word','Whole word'},{'regex','Regular expression'},{'ignored','Include gitignored'},{'hidden','Include hidden'}}) do
    local key=option[1];add('  ['..(M[key] and 'x' or ' ')..'] '..option[2],function() M[key]=not M[key];M.run() end,'WorkbenchMuted')
  end
  add('')
  local count,files=0,{}
  for _,m in ipairs(M.results) do count=count+#m.matches;files[m.path]=true end
  add('  '..(M.running and 'Searching…' or count..' matches · '..vim.tbl_count(files)..' files'..(M.truncated and ' (limit reached)' or '')),nil,'WorkbenchMuted')
  if M.notice then add('  '..M.notice,nil,'WorkbenchAccent') end
  if M.error then add('  '..vim.fn.strcharpart(M.error,0,120),nil,'DiagnosticError') end
  add('')
  local previous
  for _,match in ipairs(M.results) do
    if match.path~=previous then
      local path,first=match.path,match;previous=path
      local label='  ['..(M.selected_files[path]==false and ' ' or 'x')..'] '..vim.fn.strcharpart(path,0,math.max(8,wb().width-13))..(match.buf and ' *' or '')..' [>]'
      add(label,function(col)
        if col<6 then M.selected_files[path]=M.selected_files[path]==false;M.invalidate_preview();M.render()
        elseif col>=vim.fn.strdisplaywidth(label)-4 then M.preview_replace(path)
        else wb().open_file(M.parent..'/'..path,first.line,first.col) end
      end,'WorkbenchHeading')
    end
    add('    '..match.line..': '..vim.fn.strcharpart(match.text:gsub('[\r\n\t]',' '),0,math.max(12,wb().width-9)),
      function() wb().open_file(M.parent..'/'..match.path,match.line,match.col) end)
  end
  M.ui_rows={fields=fields}
  wb().draw(lines,actions,hl);require('search_box').show(wb().side_win(),fields)
end
function M.prompt()
  if wb().mode~='search' or not wb().side_win() then wb().sidebar('search',true) end
  local epoch=wb().sidebar_epoch
  vim.defer_fn(function()
    if not wb().sidebar_open or wb().mode~='search' or wb().sidebar_epoch~=epoch then return end
    local side=wb().side_win()
    if side then api.nvim_win_call(side,function() vim.cmd('normal! ggzt') end);M.render() end
    require('search_box').focus('query')
  end,50)
end
function M.changed()
  M.pending=(M.pending or 0)+1;local pending=M.pending
  M.invalidate_preview()
  vim.defer_fn(function() if pending==M.pending and wb().mode=='search' then M.run() end end,300)
end
function M.run()
  require('search_box').flush();M.invalidate_preview();M.pending=(M.pending or 0)+1;M.generation=M.generation+1
  if M.job then M.job.cancel() end
  local generation=M.generation;M.parent=M.root()
  M.results,M.selected_files,M.error,M.notice,M.truncated={}, {},nil,nil,false
  M.running=M.query~='' and M.parent~=nil
  if not M.parent then M.notice='Choose a repository first';M.render();return end
  if M.query=='' then M.render();return end
  local key=signature();M.render()
  M.job=require('search_engine').run({root=M.parent,query=M.query,include=M.include,exclude=M.exclude,case=M.case,
    word=M.word,regex=M.regex,hidden=M.hidden,ignored=M.ignored},function(result)
    if generation~=M.generation then return end
    M.job=nil;M.running=false;M.completed=key;M.results=result.results;M.truncated=result.truncated;M.error=result.error
    M.render()
  end)
end
function M.preview_replace(only_path)
  require('search_box').flush()
  if M.running or #M.results==0 or M.query=='' then return end
  if M.completed~=signature() or M.error or M.truncated then M.notice='Run a complete search first';M.render();return end
  if only_path then for _,m in ipairs(M.results) do M.selected_files[m.path]=m.path==only_path end end
  local bypath,plans,total={}, {},0
  for _,match in ipairs(M.results) do if M.selected_files[match.path]~=false then
    local plan=bypath[match.path]
    if not plan then
      local buf=match.buf or vim.fn.bufadd(M.parent..'/'..match.path)
      if not api.nvim_buf_is_valid(buf) then M.error='File closed since search; search again';M.render();return end
      vim.fn.bufload(buf)
      if not vim.bo[buf].modifiable or vim.bo[buf].readonly then M.error='File cannot be edited: '..match.path;M.render();return end
      plan={buf=buf,path=match.path,before=api.nvim_buf_get_lines(buf,0,-1,false)};plan.after=vim.deepcopy(plan.before)
      bypath[match.path]=plan;plans[#plans+1]=plan
    end
    local original=match.text:gsub('\r?\n$','')
    if plan.before[match.line]~=original then M.error='Changed since search: '..match.path..' · search again';M.render();return end
    local replaced=original
    for i=#match.matches,1,-1 do local span=match.matches[i]
      replaced=replaced:sub(1,span.start)..M.replacement..replaced:sub(span['end']+1);total=total+1
    end
    plan.after[match.line]=replaced
  end end
  if #plans==0 then M.notice='Select at least one file';M.render();return end
  for _,plan in ipairs(plans) do
    local expanded={};for _,line in ipairs(plan.after) do vim.list_extend(expanded,vim.split(line,'\n',{plain=true})) end;plan.after=expanded
  end
  M.preview={plans=plans,total=total,key=signature(),replacement=M.replacement}
  M.notice='Preview ready · Apply selected';M.render();require('replace_review').open(plans[1])
end
function M.apply_preview()
  require('search_box').flush();local preview=M.preview
  if not preview or preview.key~=signature() or preview.replacement~=M.replacement then
    M.notice='Preview the current replacement first';M.render();return
  end
  for _,plan in ipairs(preview.plans) do
    if not api.nvim_buf_is_valid(plan.buf) or not vim.bo[plan.buf].modifiable or vim.bo[plan.buf].readonly
      or not vim.deep_equal(plan.before,api.nvim_buf_get_lines(plan.buf,0,-1,false)) then
      M.error='File changed after preview; preview again';M.render();return
    end
  end
  require('replace_review').close()
  for _,plan in ipairs(preview.plans) do api.nvim_buf_set_lines(plan.buf,0,-1,false,plan.after);vim.bo[plan.buf].buflisted=true end
  M.preview=nil;M.results={};M.notice='Replaced '..preview.total..' · save files to keep'
  wb().log('Replace',preview.total..' matches replaced in '..#preview.plans..' selected files. Review buffers; save to keep. Undo is available per file.')
  M.render()
end
-- Keep a command-compatible entry point, with review required before applying.
M.replace_all=M.preview_replace
return M
