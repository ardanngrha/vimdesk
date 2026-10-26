-- Small path/option snapshots, captured on close/save, never on scroll.
local M={explorers={}}
local api=vim.api
local function root() return vim.fn.getcwd(-1,0) end
local function inside(path,parent) return path==parent or vim.startswith(path,parent..'/') end
local function text(value) return type(value)=='string' and value:sub(1,4096) or '' end
function M.capture(p)
  if not p or p.closed then return end
  local cwd=root();local tree=require('snacks.explorer.tree');local expanded={}
  for path,node in pairs(tree.nodes) do
    if node.open and inside(path,cwd) and #expanded<256 then expanded[#expanded+1]=path end
  end
  table.sort(expanded)
  local item=p:current();local top=p.list:get(p.list.top)
  M.explorers[cwd]={expanded=expanded,target=item and item.file,top=top and top.file,
    pattern=text(p.input.filter.pattern),search=text(p.input.filter.search),hidden=p.opts.hidden,ignored=p.opts.ignored}
  if vim.tbl_count(M.explorers)>8 then for path in pairs(M.explorers) do if path~=cwd then M.explorers[path]=nil;break end end end
end
function M.prepare()
  local state=M.explorers[root()];if not state then return {} end
  local tree=require('snacks.explorer.tree');local cwd=root()
  for path,node in pairs(tree.nodes) do if node.dir and inside(path,cwd) then node.open=false end end
  for _,path in ipairs(state.expanded or {}) do if type(path)=='string' and inside(path,cwd) and vim.fn.isdirectory(path)==1 then tree:open(path) end end
  return {hidden=state.hidden,ignored=state.ignored,follow_file=false}
end
function M.restore(p)
  local state=M.explorers[root()];if not state then return end
  M.prepare()
  p.input:set(text(state.pattern),text(state.search))
  p:find({on_done=function()
    if p.closed then return end
    local cursor,top
    for item,index in p:iter() do
      if item.file==state.target then cursor=index end
      if item.file==state.top then top=index end
      if cursor and top then break end
    end
    if cursor then p.list:move(cursor,true,true) end
    if top then p.list:scroll(top,true) end
  end})
end
function M.search_snapshot()
  require('search_box').flush()
  local s=require('workspace_search');local result={}
  for _,key in ipairs({'query','replacement','include','exclude','scope'}) do result[key]=text(s[key]) end
  for _,key in ipairs({'case','word','ignored','hidden','regex','filters'}) do result[key]=s[key]==true end
  return result
end
function M.restore_search(state)
  if type(state)~='table' then return end
  local s=require('workspace_search');if s.job then s.job.cancel();s.job=nil end
  s.generation=s.generation+1;s.pending=(s.pending or 0)+1;s.running=false;s.results={};s.preview=nil
  for _,key in ipairs({'query','replacement','include','exclude'}) do s[key]=text(state[key]) end
  s.scope=state.scope=='repo' and 'repo' or 'all'
  for _,key in ipairs({'case','word','ignored','hidden','regex','filters'}) do if type(state[key])=='boolean' then s[key]=state[key] end end
  require('search_box').sync()
end
function M.viewport(mode)
  local w=require('workbench');local side=w.side_win()
  if not side or w.mode~=mode or mode=='explorer' then return end
  return api.nvim_win_call(side,vim.fn.winsaveview)
end
function M.restore_view(view)
  local side=require('workbench').side_win();if type(view)~='table' or not side then return end
  api.nvim_win_call(side,function()
    vim.fn.winrestview({topline=tonumber(view.topline) or 1,lnum=math.min(api.nvim_buf_line_count(0),tonumber(view.lnum) or 1),col=0})
  end)
  require('sidebar_ui').clamp(side);require('sidebar_ui').update_fields(side)
end
return M
