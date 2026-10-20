local M={repos={}}
local function render(root)
  local w=require('workbench');local s=require('repo_panel').state()
  if w.mode=='git' and s.active==root and w.side_win() then require('repo_panel').render(s) end
end
function M.state(root)
  if not root then return {entries={},expanded={},files={}} end
  if not M.repos[root] then M.repos[root]={entries={},expanded={},files={},limit=30,generation=0} end
  return M.repos[root]
end
local function clean(text) return (text or ''):gsub('[%c]',' ') end
function M.parse(output)
  local entries={}
  for _,line in ipairs(vim.split(output or '','\n',{plain=true,trimempty=true})) do
    local prefix,payload=line:match('^(.-)\31(.*)$')
    if payload then
      local fields=vim.split(payload,'\0',{plain=true})
      if fields[1] and fields[1]:match('^%x+$') then
        entries[#entries+1]={prefix=prefix,sha=fields[1],parents=vim.split(fields[2] or '',' ',{plain=true,trimempty=true}),
          subject=clean(fields[3]),author=clean(fields[4]),refs=clean(fields[5])}
      end
    else entries[#entries+1]={prefix=line} end
  end
  return entries
end
function M.load(root,force)
  if not root then return end
  local g=M.state(root)
  if g.loading or (g.loaded and not force) then return end
  g.loading=true;g.generation=g.generation+1;local generation=g.generation
  vim.system({'git','-C',root,'log','--no-color','--graph','--topo-order','--all','--max-count='..g.limit,
    '--format=%x1f%H%x00%P%x00%s%x00%an%x00%D'}, {text=true,timeout=10000,env={GIT_OPTIONAL_LOCKS='0'}},function(result)
    vim.schedule(function()
      if generation~=g.generation then return end
      g.loading=false;g.loaded=true
      if result.code~=0 then
        g.entries={}
        if (result.stderr or ''):find('does not have any commits',1,true) then g.error=nil
        else g.error='History unavailable · Refresh to retry' end
      else g.entries=M.parse(result.stdout);g.error=nil end
      render(root)
    end)
  end)
end
function M.refresh(root)
  if not root then return end
  local g=M.state(root)
  if g.loading then g.generation=g.generation+1;g.loading=false end
  -- File lists are immutable per commit SHA; retain expanded commits on refresh.
  for sha,files in pairs(g.files) do if files.error then g.files[sha]=nil;g.expanded[sha]=false end end
  M.load(root,true)
end
function M.invalidate(root)
  if not root then return end
  local g=M.state(root);g.generation=g.generation+1;g.loading=false;g.loaded=false
end
function M.toggle(root,entry)
  local g=M.state(root);g.expanded[entry.sha]=not g.expanded[entry.sha]
  if g.expanded[entry.sha] and not g.files[entry.sha] then
    local result={loading=true,items={}};g.files[entry.sha]=result
    local args={'git','-C',root,'diff-tree','--no-commit-id','--name-status','--no-renames','-z','-r'}
    if entry.parents[1] then args[#args+1]=entry.parents[1] else args[#args+1]='--root' end
    args[#args+1]=entry.sha
    vim.system(args,{text=false,timeout=10000,env={GIT_OPTIONAL_LOCKS='0'}},function(output)
      vim.schedule(function()
        if g.files[entry.sha]~=result then return end
        result.loading=false;result.error=output.code~=0 and 'Could not load changed files' or nil
        local tokens=vim.split(output.stdout or '','\0',{plain=true,trimempty=true})
        result.total=math.floor(#tokens/2)
        for i=1,math.min(#tokens,400),2 do
          result.items[#result.items+1]={status=tokens[i],path=tokens[i+1]}
        end
        render(root)
      end)
    end)
  end
  render(root)
end
function M.more(root)
  local g=M.state(root);g.limit=math.min(200,g.limit+30);M.load(root,true)
end
return M
