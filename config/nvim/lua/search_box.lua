local M={fields={}}
local api=vim.api
local ns=api.nvim_create_namespace('workbench_search_placeholder')
local function value(field) return table.concat(api.nvim_buf_get_lines(field.buf,0,-1,false),'\n') end
local function placeholder(field)
  api.nvim_buf_clear_namespace(field.buf,ns,0,-1)
  if value(field)=='' then api.nvim_buf_set_extmark(field.buf,ns,0,0,
    {virt_text={{({query='Search workspace…',replacement='Replace with…',include='*.ts; src/**',exclude='dist/**; *.lock'})[field.key],'WorkbenchMuted'}},virt_text_pos='overlay'}) end
end
function M.flush()
  local s=require('workspace_search')
  for key,field in pairs(M.fields) do if api.nvim_buf_is_valid(field.buf) then
    s[key]=value(field);vim.bo[field.buf].modified=false;placeholder(field)
  end end
end
function M.hide()
  M.flush()
  for _,field in pairs(M.fields) do
    if field.win and api.nvim_win_is_valid(field.win) then pcall(api.nvim_win_close,field.win,true) end
    field.win=nil
  end
end
function M.focus(key)
  local field=M.fields[key or 'query']
  if field and field.win and api.nvim_win_is_valid(field.win) and not api.nvim_win_get_config(field.win).hide then
    api.nvim_set_current_win(field.win);vim.cmd.startinsert();return true
  end
end
local function finish()
  M.flush();vim.cmd.stopinsert()
  local side=require('workbench').side_win();if side then api.nvim_set_current_win(side) end
end
local function get(key)
  if M.fields[key] and api.nvim_buf_is_valid(M.fields[key].buf) then return M.fields[key] end
  local s=require('workspace_search');local field={key=key,buf=api.nvim_create_buf(false,true)};M.fields[key]=field
  api.nvim_buf_set_name(field.buf,'Workspace '..key)
  vim.bo[field.buf].filetype='workbench_search_input';vim.bo[field.buf].bufhidden='hide';vim.bo[field.buf].swapfile=false
  api.nvim_buf_set_lines(field.buf,0,-1,false,vim.split(s[key] or '','\n',{plain=true}));vim.bo[field.buf].modified=false
  local group=api.nvim_create_augroup('WorkbenchSearchInput'..field.buf,{clear=true})
  api.nvim_create_autocmd({'TextChanged','TextChangedI'},{group=group,buffer=field.buf,callback=function()
    if field.updating then return end
    s[key]=value(field);vim.bo[field.buf].modified=false;placeholder(field)
    if key~='replacement' then s.changed() else s.invalidate_preview();s.render() end
  end})
  api.nvim_create_autocmd('BufEnter',{group=group,buffer=field.buf,callback=function()
    vim.schedule(function() if field.win and api.nvim_get_current_win()==field.win then vim.cmd.startinsert() end end)
  end})
  vim.keymap.set({'n','i'},'<Esc>',finish,{buffer=field.buf,desc='Leave search input'})
  local function next_field(step)
    M.flush();local order={};for name,row in pairs(M.rows or {}) do order[#order+1]={key=name,row=row} end
    table.sort(order,function(a,b) return a.row<b.row end)
    for i,item in ipairs(order) do if item.key==key then M.focus(order[((i-1+step)%#order)+1].key);return end end
  end
  vim.keymap.set({'n','i'},'<Tab>',function() next_field(1) end,{buffer=field.buf,desc='Next search field'})
  vim.keymap.set({'n','i'},'<S-Tab>',function() next_field(-1) end,{buffer=field.buf,desc='Previous search field'})
  vim.keymap.set('i','<CR>',function() M.flush();s.run() end,{buffer=field.buf,desc='Search workspace'})
  placeholder(field);return field
end
function M.show(side,rows)
  local w=require('workbench')
  if w.mode~='search' or not side or not api.nvim_win_is_valid(side) then M.hide();return end
  M.rows=rows
  for key,field in pairs(M.fields) do if not rows[key] and field.win and api.nvim_win_is_valid(field.win) then api.nvim_win_close(field.win,true);field.win=nil end end
  for key,row in pairs(rows) do
    local field=get(key)
    local config=require('sidebar_ui').field_config(side,row,1,({query='Search',replacement='Replace',include='Files to include',exclude='Files to exclude'})[key])
    if not config then
      if field.win and api.nvim_win_is_valid(field.win) then api.nvim_win_close(field.win,true) end
      field.win=nil
    else
      if field.win and api.nvim_win_is_valid(field.win) then require('sidebar_ui').place_field(field.win,config)
      else
        field.win=api.nvim_open_win(field.buf,false,config)
        vim.wo[field.win].wrap=false
        require('sidebar_ui').field_style(field.win)
      end
    end
  end
end
function M.reposition(side)
  for key,row in pairs(M.rows or {}) do
    local field=M.fields[key]
    if field and field.win and api.nvim_win_is_valid(field.win) then
      local config=require('sidebar_ui').field_config(side,row,1,({query='Search',replacement='Replace',include='Files to include',exclude='Files to exclude'})[key])
      if config then require('sidebar_ui').place_field(field.win,config) end
    end
  end
end
function M.setup()
  api.nvim_create_augroup('WorkbenchSearchFields',{clear=true})
end
return M
