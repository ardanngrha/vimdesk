-- Ordinary and historical diffs share native windows in the current editor tab.
-- Conflict resolution remains with Diffview's three-pane merge layout.
local M={generation=0}
local api=vim.api
local function valid(win) return win and api.nvim_win_is_valid(win) end
function M.active()
  return M.state and valid(M.state.left) and valid(M.state.right) and api.nvim_win_get_tabpage(M.state.right)==api.nvim_get_current_tabpage()
end
local function label(text) return text:gsub('%%','%%%%'):gsub('[%c]',' ') end
local function scratch(name,content,ft)
  local buf=api.nvim_create_buf(false,true)
  api.nvim_buf_set_name(buf,'vimdesk-diff://'..buf..'/'..name)
  vim.bo[buf].bufhidden='hide';vim.bo[buf].swapfile=false
  local lines=vim.split(content or '','\n',{plain=true})
  if #lines>1 and lines[#lines]=='' then table.remove(lines) end
  api.nvim_buf_set_lines(buf,0,-1,false,lines);vim.bo[buf].modified=false
  if ft then vim.bo[buf].filetype=ft end
  vim.bo[buf].modifiable=false
  return buf
end
function M.close()
  M.generation=M.generation+1
  local s=M.state;if not s then return end;M.state=nil
  for _,win in ipairs({s.left,s.right}) do require('diff_ui').detach(win) end
  for _,win in ipairs({s.left,s.right}) do if valid(win) then pcall(api.nvim_win_call,win,function() vim.cmd('diffoff') end) end end
  local restore=valid(s.left) and s.left or s.right
  if valid(s.left) and valid(s.right) then pcall(api.nvim_win_close,s.right,true) end
  if valid(restore) then
    if api.nvim_buf_is_valid(s.original) then api.nvim_win_set_buf(restore,s.original) end
    vim.wo[restore].winbar=s.winbar
    vim.wo[restore].winhighlight=s.highlight
    require('workbench').editor=restore
    pcall(api.nvim_win_set_cursor,restore,s.cursor)
  end
  for _,buf in ipairs(s.scratch or {}) do if api.nvim_buf_is_valid(buf) then pcall(api.nvim_buf_delete,buf,{force=true}) end end
end
local function show(root,path,before,after,opts,generation)
  if generation~=M.generation then return end
  if (before and before:find('\0',1,true)) or (after and after:find('\0',1,true)) then
    vim.notify('Binary files cannot be shown as a text diff.',vim.log.levels.INFO);return
  end
  if (before and #before>2*1024*1024) or (after and #after>2*1024*1024) then
    vim.notify('This file exceeds the 2 MB inline diff limit. Open it in the editor or LazyGit.',vim.log.levels.INFO);return
  end
  if opts.working then
    local stat=vim.uv.fs_stat(root..'/'..path)
    if stat and stat.size>2*1024*1024 then
      vim.notify('This file exceeds the 2 MB inline diff limit. Open it in the editor or LazyGit.',vim.log.levels.INFO);return
    end
    local handle=stat and vim.uv.fs_open(root..'/'..path,'r',438)
    if handle then
      local sample=vim.uv.fs_read(handle,4096,0);vim.uv.fs_close(handle)
      if sample and sample:find('\0',1,true) then vim.notify('Binary files cannot be shown as a text diff.',vim.log.levels.INFO);return end
    end
  end
  local w=require('workbench')
  local focused=api.nvim_get_current_win()
  local keep_focus=vim.bo.filetype=='workbench_commit' or vim.bo.filetype=='workbench_sidebar'
  local ft=vim.filetype.match({filename=path})
  local leftbuf=scratch('before/'..path,before,ft)
  local rightbuf
  local owned={leftbuf}
  if opts.working and vim.fn.filereadable(root..'/'..path)==1 then
    rightbuf=vim.fn.bufadd(root..'/'..path);vim.fn.bufload(rightbuf)
  else rightbuf=scratch('after/'..path,after,ft);owned[#owned+1]=rightbuf end
  require('repo_panel').hide_lazygit()
  require('replace_review').close()
  local all=package.loaded.git_changes;if all then all.close() end
  if not M.active() then
    if M.state then M.close() end
    require('git_review').close_merge()
    w.focus_editor();local left=w.main()
    local side=w.side_win();local width=side and api.nvim_win_get_width(side)
    M.state={left=left,original=api.nvim_win_get_buf(left),cursor=api.nvim_win_get_cursor(left),winbar=vim.wo[left].winbar,highlight=vim.wo[left].winhighlight}
    api.nvim_set_current_win(left);vim.cmd('rightbelow vsplit');M.state.right=api.nvim_get_current_win()
    if side then api.nvim_win_set_width(side,width) end
    local total=api.nvim_win_get_width(left)+api.nvim_win_get_width(M.state.right)
    api.nvim_win_set_width(M.state.right,math.floor(total/2))
  end
  local s=M.state;local previous=s.scratch or {};s.scratch=owned;s.root=root;s.path=path;s.revision=opts.revision;s.staged=opts.staged
  for _,win in ipairs({s.left,s.right}) do api.nvim_win_call(win,function() vim.cmd('diffoff') end) end
  api.nvim_win_set_buf(s.left,leftbuf);api.nvim_win_set_buf(s.right,rightbuf)
  local suffix=opts.revision and (' · '..opts.revision:sub(1,7)) or opts.staged and ' · staged' or ''
  for _,pane in ipairs({{s.left,'Before'},{s.right,'After'}}) do
    local win,kind=pane[1],pane[2]
    vim.wo[win].winbar='%#Review'..kind..'# '..kind..' %#ReviewPath# '..label(path..suffix)
      ..(kind=='After' and '%= %1@v:lua.GitDiff.click@[Close]%T ' or '')
    vim.wo[win].winfixwidth=false;vim.wo[win].winfixheight=false
    vim.wo[win].winhighlight='DiffAdd:Review'..kind..'Line,DiffChange:Review'..kind..'Line,DiffText:Review'..kind..'Text'
    api.nvim_win_call(win,function() vim.cmd('diffthis') end)
    require('diff_ui').attach(win,{role=kind})
  end
  api.nvim_win_call(s.right,function() vim.cmd('diffupdate');vim.cmd('normal! ggzt') end)
  api.nvim_win_call(s.left,function() vim.cmd('normal! ggzt') end)
  w.editor=s.right
  for _,buf in ipairs(previous) do if api.nvim_buf_is_valid(buf) then pcall(api.nvim_buf_delete,buf,{force=true}) end end
  -- A slow load may finish after the user started editing a commit message.
  if keep_focus and valid(focused) then api.nvim_set_current_win(focused) else api.nvim_set_current_win(s.right) end
end
function M.open(root,path,opts)
  opts=opts or {};if not root or not path then return end
  M.generation=M.generation+1;local generation=M.generation
  local results,remaining={},opts.working and 1 or 2
  local function receive(side,result,optional)
    if generation~=M.generation then return end
    if result.code~=0 and not optional then
      M.generation=M.generation+1
      vim.notify('Could not read revision for '..path..'. Refresh Source Control and retry.',vim.log.levels.WARN);return
    end
    results[side]=result.code==0 and result.stdout or '';remaining=remaining-1
    if remaining==0 then show(root,path,results.before,results.after,opts,generation) end
  end
  local function blob(side,revision,file,optional)
    if not revision then receive(side,{code=0,stdout=''},true);return end
    vim.system({'git','-C',root,'cat-file','blob',revision..':'..file},{text=false,timeout=10000,env={GIT_OPTIONAL_LOCKS='0'}},function(result)
      vim.schedule(function() receive(side,result,optional) end)
    end)
  end
  blob('before',opts.before,opts.old_path or path,opts.empty_before)
  if not opts.working then blob('after',opts.after,path,opts.empty_after) end
end
function M.working(root,file,staged)
  local info=require('repo_panel').state().info[root] or {}
  return M.open(root,file.path,{working=not staged,staged=staged,before=staged and 'HEAD' or '',after='',
    old_path=staged and file.old or nil,empty_before=file.untracked or file.x=='A' or file.y=='A' or info.head=='No commits yet'})
end
function M.commit(root,entry,file)
  return M.open(root,file.path,{before=entry.parents[1],after=entry.sha,revision=entry.sha,
    empty_before=file.status=='A' or not entry.parents[1],empty_after=file.status=='D'})
end
function M.refresh(root)
  if not M.active() or M.state.root~=root or M.state.revision then return end
  local s=M.state
  for _,file in ipairs((require('repo_panel').state().info[root] or {}).files or {}) do
    if file.path==s.path then
      if file.conflict then return require('git_review').open(root,file.path,false) end
      return M.working(root,file,s.staged and file.staged or not file.changed and file.staged or false)
    end
  end
  M.close()
end
function M.click(_,_,button) if button=='l' then vim.schedule(M.close) end end
_G.GitDiff=M
return M
