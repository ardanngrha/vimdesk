-- Small, event-driven overview rulers. Scrolling reuses the cached diff map;
-- no polling, Git commands, parsers or full-buffer reads in the scroll path.
local M={panes={}}
local api=vim.api
local ns=api.nvim_create_namespace('vimdesk_diff_ruler')
local function valid(win) return win and api.nvim_win_is_valid(win) end
local function enabled() return vim.g.workbench_diff_overview~=false and vim.g.workbench_light~=true end

function M.detach(win)
  local p=M.panes[win];if not p then return end;M.panes[win]=nil
  if valid(win) and p.restore then for name,value in pairs(p.restore) do vim.wo[win][name]=value end end
  if valid(p.win) then pcall(api.nvim_win_close,p.win,true) end
  if p.buf and api.nvim_buf_is_valid(p.buf) then pcall(api.nvim_buf_delete,p.buf,{force=true}) end
end

local function scan(win,p)
  p.marks={};p.count=api.nvim_buf_line_count(p.source);p.scans=(p.scans or 0)+1
  if p.rows then
    for row,item in pairs(p.rows) do if item.kind then p.marks[row]=item.kind end end
  elseif vim.wo[win].diff then
    -- The inline viewer already caps files at 2 MB. Bound the extra ruler work
    -- for unusually many very short lines; the native diff remains available.
    if p.count>30000 then p.limited=true;return end
    p.limited=false
    local added=vim.fn.hlID('DiffAdd')
    api.nvim_win_call(win,function()
      for line=1,p.count do
        local id=vim.fn.diff_hlID(line,1)
        if id~=0 then p.marks[line]=p.role=='Before' and 'Delete' or id==added and 'Add' or 'Change' end
        if vim.fn.diff_filler(line)>0 then p.marks[math.max(1,line-1)]='Delete' end
      end
    end)
    if p.role=='Result' then
      local conflict=false
      for line,text in ipairs(api.nvim_buf_get_lines(p.source,0,-1,false)) do
        if text:match('^<<<<<<< ') then conflict=true end
        if conflict then p.marks[line]='Conflict' end
        if text:match('^>>>>>>> ') then conflict=false end
      end
    end
  end
end

local function draw(win,p)
  local height,width=api.nvim_win_get_height(win),api.nvim_win_get_width(win)
  if width<16 or height<3 then
    if valid(p.win) and not p.hidden then api.nvim_win_set_config(p.win,{hide=true});p.hidden=true end
    return
  end
  local view=api.nvim_win_call(win,function() return {vim.fn.line('w0'),vim.fn.line('w$')} end)
  local top,bottom=view[1],view[2]
  local count=math.max(1,p.count or 1)
  local first=math.min(height-1,math.floor((top-1)*height/count))
  local last=math.min(height-1,math.max(first,math.ceil(bottom*height/count)-1))
  local signature=table.concat({height,width,first,last,p.scans or 0},':')
  if p.paint==signature and valid(p.win) and not p.hidden then return end;p.paint=signature
  if not p.buf or not api.nvim_buf_is_valid(p.buf) then
    p.buf=api.nvim_create_buf(false,true);vim.bo[p.buf].bufhidden='wipe'
    vim.bo[p.buf].filetype='workbench_diff_ruler'
    p.bucket_key=nil;p.thumb={};p.geometry=nil
  end
  local config={relative='win',win=win,row=0,col=width-2,width=2,height=height,
    focusable=false,mouse=false,style='minimal',border='none',zindex=45,hide=false}
  local geometry=width..':'..height
  if valid(p.win) then
    if p.geometry~=geometry or p.hidden then api.nvim_win_set_config(p.win,config) end
  else
    p.win=api.nvim_open_win(p.buf,false,config);vim.wo[p.win].winhighlight='Normal:ReviewRulerTrack,NormalFloat:ReviewRulerTrack';vim.wo[p.win].winblend=0
  end
  p.geometry=geometry;p.hidden=false
  local bucket_key=height..':'..(p.scans or 0)
  if p.bucket_key~=bucket_key then
    p.bucket_key=bucket_key;p.buckets={}
    local lines={};for i=1,height do lines[i]='  ' end
    api.nvim_buf_set_lines(p.buf,0,-1,false,lines);api.nvim_buf_clear_namespace(p.buf,ns,0,-1);p.thumb={}
    local priority={Add=1,Change=2,Delete=3,Conflict=4}
    for line,kind in pairs(p.marks or {}) do
      local row=math.min(height-1,math.floor((line-1)*height/count))
      if not p.buckets[row] or priority[kind]>priority[p.buckets[row]] then p.buckets[row]=kind end
    end
    for row,kind in pairs(p.buckets) do api.nvim_buf_set_extmark(p.buf,ns,row,0,{end_col=1,hl_group='ReviewRuler'..kind}) end
  end
  -- A scroll only changes the ends of the viewport thumb, not the ruler's
  -- text, geometry, or static diff marks. Keep redraws to those few cells.
  for row,id in pairs(p.thumb) do if row<first or row>last then api.nvim_buf_del_extmark(p.buf,ns,id);p.thumb[row]=nil end end
  for row=first,last do if not p.thumb[row] then p.thumb[row]=api.nvim_buf_set_extmark(p.buf,ns,row,1,{end_col=2,hl_group='ReviewRulerThumb'}) end end
end

function M.refresh()
  for win,p in pairs(M.panes) do
    if not valid(win) or api.nvim_win_get_buf(win)~=p.source or not (p.rows or vim.wo[win].diff) then M.detach(win)
    elseif not enabled() then
      if valid(p.win) and not p.hidden then api.nvim_win_set_config(p.win,{hide=true});p.hidden=true end
    elseif api.nvim_win_get_tabpage(win)==api.nvim_get_current_tabpage() then
      if p.dirty then p.dirty=nil;scan(win,p) end
      draw(win,p)
    end
  end
end
function M.toggle()
  vim.g.workbench_diff_overview=vim.g.workbench_diff_overview==false
  M.refresh()
  vim.notify('Change overview ruler '..(enabled() and 'on' or vim.g.workbench_light and 'hidden in Light mode' or 'off'))
end

local function queue(dirty)
  if not next(M.panes) then return end
  if dirty then for _,p in pairs(M.panes) do p.dirty=true end end
  if M.pending then return end;M.pending=true
  -- Coalesce DiffUpdated bursts, and at most one redraw per event-loop turn.
  vim.schedule(function() M.pending=nil;M.refresh() end)
end

function M.attach(win,opts)
  opts=opts or {};if not valid(win) then return end
  if not M.setup_done then
    M.setup_done=true
    local group=api.nvim_create_augroup('VimDeskDiffOverview',{clear=true})
    api.nvim_create_autocmd({'DiffUpdated','TextChanged','TextChangedI','BufWritePost'},{group=group,callback=function(ev)
      for _,p in pairs(M.panes) do if ev.event=='DiffUpdated' or p.source==ev.buf then queue(true);return end end
    end})
    api.nvim_create_autocmd({'WinScrolled','WinResized','WinClosed','TabEnter','BufWinEnter'},
      {group=group,callback=function() queue(false) end})
    api.nvim_create_autocmd('ColorScheme',{group=group,callback=function()
      for _,p in pairs(M.panes) do p.paint=nil end;queue(false)
    end})
  end
  local p=M.panes[win] or {};M.panes[win]=p
  p.restore=p.restore or {wrap=vim.wo[win].wrap,cursorlineopt=vim.wo[win].cursorlineopt}
  local source=api.nvim_win_get_buf(win)
  if p.source~=source or p.role~=opts.role or p.rows~=opts.rows then p.dirty=true;p.paint=nil end
  p.source=source;p.role=opts.role;p.rows=opts.rows
  vim.wo[win].wrap=false
  vim.wo[win].cursorlineopt='number'
  if not opts.rows then
    local role=opts.role or 'After'
    vim.wo[win].winhighlight='DiffAdd:Review'..role..'Line,DiffDelete:Review'..role..'Line,DiffChange:Review'..role..'Line,DiffText:Review'..role..'Text,DiffTextAdd:Review'..role..'Text'
  end
  queue(false)
end
return M
