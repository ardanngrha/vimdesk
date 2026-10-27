-- A bounded header over the existing tree, updated only on buffer/layout events.
local M={rows={},height=5,expanded=true,toolbar_row=2,editors_row=4}
local api=vim.api
local toolbar_ns=api.nvim_create_namespace('vimdesk_explorer_toolbar')
-- Codicons already included in the user's Nerd Font; no icon provider/load.
-- https://github.com/microsoft/vscode-codicons/blob/main/src/template/mapping.json
M.tools={
  {id='new_file',label='New File',icon=vim.fn.nr2char(60031),run=function() require('explorer_actions').create(false) end},
  {id='new_folder',label='New Folder',icon=vim.fn.nr2char(60032),run=function() require('explorer_actions').create(true) end},
  {id='more',label='More',icon=vim.fn.nr2char(60028),run=function() require('explorer_actions').menu() end},
  {id='collapse',label='Collapse All',icon=vim.fn.nr2char(60101),run=function() M.collapse() end},
  {id='reveal',label='Reveal Active File',icon=vim.fn.nr2char(60408),run=function() M.reveal() end},
  {id='paste',label='Paste',icon=vim.fn.nr2char(60096),run=function() require('explorer_actions').paste() end},
}
local function valid(win) return win and api.nvim_win_is_valid(win) end
local function w() return require('workbench') end
local function clip(s,width)
  s=s:gsub('[%c]',' ')
  if vim.fn.strdisplaywidth(s)<=width then return s end
  local out='';for i=0,vim.fn.strchars(s)-1 do
    local c=vim.fn.strcharpart(s,i,1);if vim.fn.strdisplaywidth(out..c)>width-1 then break end;out=out..c
  end
  return out..'…'
end
function M.editors()
  return require('editor_ui').editors()
end
function M.choose()
  Snacks.picker.select(M.editors(),{prompt='Open Editors',format_item=function(buf)
    local path=api.nvim_buf_get_name(buf)
    return (vim.bo[buf].modified and '● ' or '')..(path=='' and '[Untitled]' or vim.fs.relpath(vim.fn.getcwd(-1,0),path) or path)
  end},function(buf) if buf then require('editor_ui').switch_buffer(buf) end end)
end
function M.act(row,col)
  if row==M.toolbar_row then
    for _,hit in ipairs(M.buttons or {}) do if col>=hit.first and col<hit.last then hit.tool.run();return end end
  elseif row==M.editors_row then M.expanded=not M.expanded;M.render()
  elseif M.rows[row] then
    if col>=api.nvim_win_get_width(M.win)-3 then require('editor_ui').close_buffer(M.rows[row])
    else require('editor_ui').switch_buffer(M.rows[row]) end
  elseif row==M.more_row then M.choose() end
end
function M.mouse(mouse,double)
  if mouse.winid~=M.win or not valid(M.win) or mouse.line<1 or mouse.column<1 then return false end
  if double then return true end
  local row,col=mouse.line,mouse.column-1;local win=M.win
  vim.schedule(function() if win==M.win and valid(win) then M.act(row,col) end end)
  return true
end
function M.reveal()
  local p=w().explorer_picker();if not p or p.closed then return end
  local editor=w().main();local path=api.nvim_buf_get_name(api.nvim_win_get_buf(editor))
  if path=='' then return end
  local root=p:cwd()
  if path~=root and not vim.startswith(path,root..'/') then vim.notify('Active file is outside this workspace.');return end
  require('snacks.explorer.actions').update(p,{target=path});p:focus('list')
end
function M.collapse()
  local p=w().explorer_picker();if p then p:action('explorer_close_all') end
end
function M.hide()
  M.picker=nil
  if valid(M.win) then pcall(api.nvim_win_close,M.win,true) end
  M.win=nil
end
function M.render()
  local p=M.picker;local side=w().side_win()
  if not p or p.closed or w().mode~='explorer' or not valid(side) then return end
  if not M.buf or not api.nvim_buf_is_valid(M.buf) then
    M.buf=api.nvim_create_buf(false,true);vim.bo[M.buf].filetype='workbench_open_editors'
    vim.bo[M.buf].bufhidden='hide';vim.bo[M.buf].swapfile=false
    vim.keymap.set('n','<CR>',function() local cursor=api.nvim_win_get_cursor(0);M.act(cursor[1],cursor[2]) end,{buffer=M.buf,desc='Open editor / action'})
    vim.keymap.set('n','K',function()
      local cursor=api.nvim_win_get_cursor(0)
      if cursor[1]==M.toolbar_row then for _,hit in ipairs(M.buttons or {}) do if cursor[2]>=hit.first and cursor[2]<hit.last then vim.notify(hit.tool.label);return end end end
    end,{buffer=M.buf,desc='Describe toolbar icon'})
    vim.keymap.set('n','x',function() local buf=M.rows[api.nvim_win_get_cursor(0)[1]];if buf then require('editor_ui').close_buffer(buf) end end,{buffer=M.buf,desc='Close editor'})
    vim.keymap.set('n','<Esc>',function() w().focus_editor() end,{buffer=M.buf})
    vim.keymap.set('n','q',function() w().focus_editor() end,{buffer=M.buf})
  end
  local editors=M.editors();local width=api.nvim_win_get_width(side);local active=valid(w().editor) and api.nvim_win_get_buf(w().editor)
  local max=math.max(0,math.min(6,math.floor(api.nvim_win_get_height(side)/3)-4))
  local toolbar=' ';M.buttons={}
  for i,tool in ipairs(M.tools) do
    if i>1 and width>=26 then toolbar=toolbar..' ' end
    if i==4 then toolbar=toolbar..' ' end
    local first=#toolbar;toolbar=toolbar..' '..tool.icon..' '
    M.buttons[#M.buttons+1]={first=first,last=#toolbar,tool=tool}
  end
  -- One blank row above and below the icon buttons.
  local lines={'',toolbar,'',
    ' '..(M.expanded and '▾' or '▸')..' Open Editors ('..#editors..')'}
  M.rows={};M.more_row=nil
  if M.expanded then
    local shown={};for i=1,math.min(#editors,max) do shown[i]=editors[i] end
    if max>0 and active and vim.tbl_contains(editors,active) and not vim.tbl_contains(shown,active) then shown[#shown]=active end
    for i=1,math.min(#editors,max) do
      local buf=shown[i];local path=api.nvim_buf_get_name(buf)
      local label=path=='' and '[Untitled]' or vim.fs.relpath(vim.fn.getcwd(-1,0),path) or vim.fn.fnamemodify(path,':~')
      local prefix=(active==buf and ' ›' or '  ')..(vim.bo[buf].modified and '● ' or vim.b[buf].workbench_preview and '~ ' or '  ')
      local text=prefix..clip(label,math.max(1,width-vim.fn.strdisplaywidth(prefix)-4))
      lines[#lines+1]=text..string.rep(' ',math.max(1,width-vim.fn.strdisplaywidth(text)-3))..'× '
      M.rows[#lines]=buf
    end
    if #editors>max then M.more_row=#lines+1;lines[#lines+1]='   Show all '..#editors..' editors…'
    elseif #editors==0 then lines[#lines+1]='   No open files' end
  end
  local height=#lines;local resized=M.height~=height;M.height=height
  local config={relative='win',win=side,row=0,col=0,width=width,height=height,style='minimal',border='none',zindex=55,noautocmd=true}
  if valid(M.win) then
    local c=api.nvim_win_get_config(M.win)
    if c.width~=width or c.height~=height or c.win~=side then config.noautocmd=nil;api.nvim_win_set_config(M.win,config) end
  else
    M.win=api.nvim_open_win(M.buf,false,config)
    for k,v in pairs({wrap=false,scrolloff=0,number=false,relativenumber=false,signcolumn='no',winhighlight='Normal:WorkbenchSidebar,NormalNC:WorkbenchSidebar,NormalFloat:WorkbenchSidebar'}) do vim.wo[M.win][k]=v end
  end
  if not vim.deep_equal(lines,M.lines) then
    vim.bo[M.buf].modifiable=true;api.nvim_buf_set_lines(M.buf,0,-1,false,lines);vim.bo[M.buf].modifiable=false;M.lines=lines
    api.nvim_buf_clear_namespace(M.buf,toolbar_ns,0,-1)
    for _,hit in ipairs(M.buttons) do
      api.nvim_buf_set_extmark(M.buf,toolbar_ns,M.toolbar_row-1,hit.first,{end_col=hit.last,hl_group='WorkbenchButton'})
      api.nvim_buf_set_extmark(M.buf,toolbar_ns,M.toolbar_row-1,hit.first+1,{end_col=hit.last-1,hl_group='WorkbenchAccent',hl_mode='combine',priority=120})
    end
  end
  if resized and p.layout and not p.layout.closed then p.layout:update() end
end
function M.queue()
  if M.pending or not M.picker then return end
  M.pending=true;vim.schedule(function() M.pending=false;M.render() end)
end
function M.attach(p) M.picker=p;M.render() end
function M.setup()
  local group=api.nvim_create_augroup('WorkbenchOpenEditors',{clear=true})
  api.nvim_create_autocmd({'BufAdd','BufDelete','BufEnter','BufFilePost','BufModifiedSet','BufWritePost'},{group=group,callback=function(e)
    if api.nvim_buf_is_valid(e.buf) and vim.bo[e.buf].buftype=='' then M.queue() end
  end})
  api.nvim_create_autocmd('OptionSet',{group=group,pattern={'buflisted'},callback=M.queue})
  api.nvim_create_autocmd({'WinResized','VimResized'},{group=group,callback=M.queue})
end
return M
