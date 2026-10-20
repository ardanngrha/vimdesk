local M={}
local api=vim.api
M.input_highlight='Normal:WorkbenchCommitInput,NormalNC:WorkbenchCommitInput,NormalFloat:WorkbenchCommitInput,FloatBorder:WorkbenchInputBorder,FloatTitle:WorkbenchInputTitle'
function M.repo_name(parent,root)
  local relative=vim.fs.relpath(parent,root)
  if not relative or relative=='.' or relative=='' then return vim.fs.basename(root) end
  return relative
end
function M.field_config(side,row,height,title)
  if not side or not api.nvim_win_is_valid(side) then return end
  local buf=api.nvim_win_get_buf(side)
  -- Explorer owns a different buffer while its layout is closing. Async repo
  -- discovery must wait for the native sidebar before positioning fields.
  if vim.bo[buf].filetype~='workbench_sidebar' or row<1 or row+height+1>api.nvim_buf_line_count(buf) then return end
  local top=vim.fn.line('w0',side)
  local visible=row>=top and row+height+1<top+api.nvim_win_get_height(side)
  -- Let Neovim move inputs with the text, rather than chasing screenpos from
  -- scheduled scroll callbacks. Keep offscreen inputs hidden, with drafts intact.
  return {relative='win',win=side,bufpos={row-1,0},row=0,col=1,fixed=true,hide=not visible,
    width=math.max(1,api.nvim_win_get_width(side)-4),height=height,style='minimal',border='rounded',
    focusable=true,zindex=35,title=' '..title..' ',title_pos='left',noautocmd=true}
end
function M.place_field(win,config)
  local current=api.nvim_win_get_config(win)
  if current.width~=config.width or current.height~=config.height or current.hide~=config.hide
    or current.win~=config.win or not vim.deep_equal(current.bufpos,config.bufpos) then
    if config.hide and api.nvim_get_current_win()==win then
      vim.cmd.stopinsert();api.nvim_set_current_win(config.win)
    end
    config.noautocmd=nil;api.nvim_win_set_config(win,config)
  end
end
function M.clamp(side,delta)
  if not side or not api.nvim_win_is_valid(side) then return false end
  return api.nvim_win_call(side,function()
    local view=vim.fn.winsaveview()
    local height=api.nvim_win_get_height(side)
    local maximum=math.max(1,api.nvim_buf_line_count(api.nvim_win_get_buf(side))-height+1)
    local top=math.max(1,math.min(maximum,view.topline+(delta or 0)))
    if view.topline==top and view.leftcol==0 then return false end
    view.topline=top;view.leftcol=0;view.skipcol=0;view.topfill=0
    view.lnum=math.max(top,math.min(view.lnum,top+height-1))
    vim.fn.winrestview(view)
    return true
  end)
end
function M.update_fields(side)
  local w=require('workbench')
  if w.mode=='git' then
    local box=require('commit_box')
    if box.field then box.reposition(side) end
  elseif w.mode=='search' then
    local box=require('search_box')
    if box.rows then box.reposition(side) end
  end
end
local scroll_pending={}
function M.queue_scroll(side,delta)
  local w=require('workbench')
  local pending=scroll_pending[side]
  if pending and pending.epoch==w.sidebar_epoch then pending.delta=pending.delta+delta;return end
  pending={delta=delta,epoch=w.sidebar_epoch};scroll_pending[side]=pending
  vim.schedule(function()
    if scroll_pending[side]~=pending then return end
    scroll_pending[side]=nil
    if w.sidebar_epoch~=pending.epoch or w.side_win()~=side then return end
    if M.clamp(side,pending.delta) then M.update_fields(side) end
  end)
end
function M.setup()
  api.nvim_create_autocmd({'WinScrolled','WinResized'},{group=api.nvim_create_augroup('WorkbenchSidebarViewport',{clear=true}),callback=function(event)
    local w=require('workbench');local side=w.side_win()
    if not side or w.mode=='explorer' then return end
    local changes=vim.v.event
    if not changes[tostring(side)] and not vim.tbl_contains(changes.windows or {},side) and tonumber(event.match)~=side then return end
    M.clamp(side);M.update_fields(side)
  end})
end
function M.field_style(win)
  if not win or not api.nvim_win_is_valid(win) then return end
  vim.wo[win].winhighlight=M.input_highlight
  vim.wo[win].cursorline=false;vim.wo[win].scrolloff=0
end
function M.explorer_layout(side)
  return {preview=false,layout={box='vertical',position='float',relative='win',win=side,row=0,col=0,backdrop=false,height=0,
    width=0,min_width=1,border={' ',' ',' ',' ',' ',' ',' ',' '},
    wo={winhighlight='Normal:WorkbenchSidebar,NormalNC:WorkbenchSidebar,FloatBorder:WorkbenchSidebar'},
    {win='input',height=1,border='rounded',title=' Filter files ',title_pos='left',
      wo={winhighlight=M.input_highlight}},
    {win='list',border='hpad',wo={winhighlight='Normal:WorkbenchSidebar,NormalNC:WorkbenchSidebar,NormalFloat:WorkbenchSidebar,CursorLine:WorkbenchSelected'}},
    {win='preview',height=0.4,border='top',title='{preview}'},
  }}
end
return M
