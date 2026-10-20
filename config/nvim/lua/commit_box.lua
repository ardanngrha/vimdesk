local M={}
local api=vim.api
local fields={}
local ns=api.nvim_create_namespace('workbench_commit_placeholder')
local function text(buf) return table.concat(api.nvim_buf_get_lines(buf,0,-1,false),'\n') end
local function placeholder(field)
  api.nvim_buf_clear_namespace(field.buf,ns,0,-1)
  if text(field.buf)=='' then
    api.nvim_buf_set_extmark(field.buf,ns,0,0,{virt_text={{'Message, or click Generate…','WorkbenchMuted'}},virt_text_pos='overlay'})
  end
end
function M.flush()
  local field=M.field
  if not field or not api.nvim_buf_is_valid(field.buf) then return end
  field.state.drafts=field.state.drafts or {}
  field.state.drafts[field.root]=text(field.buf)
  vim.bo[field.buf].modified=false
  placeholder(field)
end
function M.hide()
  M.flush()
  if M.win and api.nvim_win_is_valid(M.win) then pcall(api.nvim_win_close,M.win,true) end
  M.win=nil; M.field=nil
end
local function finish()
  M.flush(); vim.cmd.stopinsert()
  local side=require('workbench').side_win()
  if side then api.nvim_set_current_win(side) end
end
local function field_for(root,s)
  local field=fields[root]
  if field and api.nvim_buf_is_valid(field.buf) then field.state=s; return field end
  field={root=root,state=s,buf=api.nvim_create_buf(false,true)}; fields[root]=field
  api.nvim_buf_set_name(field.buf,'Commit message: '..root)
  vim.bo[field.buf].filetype='workbench_commit'
  vim.bo[field.buf].bufhidden='hide'; vim.bo[field.buf].swapfile=false
  vim.b[field.buf].workspace_repo_root=root
  api.nvim_buf_set_lines(field.buf,0,-1,false,vim.split((s.drafts or {})[root] or '','\n',{plain=true}))
  vim.bo[field.buf].modified=false
  local group=api.nvim_create_augroup('WorkbenchCommit'..field.buf,{clear=true})
  api.nvim_create_autocmd({'TextChanged','TextChangedI'},{group=group,buffer=field.buf,callback=function()
    if field.updating then return end
    field.state.drafts=field.state.drafts or {}; field.state.drafts[root]=text(field.buf)
    vim.bo[field.buf].modified=false; placeholder(field)
  end})
  api.nvim_create_autocmd('BufEnter',{group=group,buffer=field.buf,callback=function()
    vim.schedule(function()
      if M.field==field and M.win and api.nvim_get_current_win()==M.win then vim.cmd.startinsert() end
    end)
  end})
  vim.keymap.set({'n','i'},'<Esc>',finish,{buffer=field.buf,desc='Finish editing commit message'})
  vim.keymap.set('i','<CR>',finish,{buffer=field.buf,desc='Review message (does not commit)'})
  placeholder(field)
  return field
end
function M.show(s,side,row)
  if not s.active or not side or not api.nvim_win_is_valid(side) then M.hide(); return end
  if M.field and M.field.root~=s.active then M.hide() end
  local field=field_for(s.active,s)
  local draft=(s.drafts or {})[s.active] or ''
  if text(field.buf)~=draft then
    field.updating=true
    api.nvim_buf_set_lines(field.buf,0,-1,false,vim.split(draft,'\n',{plain=true}))
    vim.bo[field.buf].modified=false; field.updating=false; placeholder(field)
  end
  M.field=field; M.side=side; M.row=row
  local config=require('sidebar_ui').field_config(side,row,3,'Commit message')
  if not config then
    if M.win and api.nvim_win_is_valid(M.win) then api.nvim_win_close(M.win,true) end
    M.win=nil;return
  end
  if M.win and api.nvim_win_is_valid(M.win) then
    require('sidebar_ui').place_field(M.win,config)
    if api.nvim_win_get_buf(M.win)~=field.buf then api.nvim_win_set_buf(M.win,field.buf) end
  else
    M.win=api.nvim_open_win(field.buf,false,config)
    vim.wo[M.win].wrap=true;vim.wo[M.win].linebreak=true
    require('sidebar_ui').field_style(M.win)
  end
end
function M.reposition(side)
  if not M.win or not api.nvim_win_is_valid(M.win) then return end
  local config=require('sidebar_ui').field_config(side,M.row,3,'Commit message')
  if config then require('sidebar_ui').place_field(M.win,config) end
end
function M.focus(root)
  if M.field and M.field.root==root and M.win and api.nvim_win_is_valid(M.win) and not api.nvim_win_get_config(M.win).hide then
    api.nvim_set_current_win(M.win); vim.cmd.startinsert(); return true
  end
end
function M.setup()
  api.nvim_create_augroup('WorkbenchCommitScroll',{clear=true})
end
return M
