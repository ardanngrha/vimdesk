local M = {}
local api = vim.api
local function safe(text) return text:gsub('%%', '%%%%'):gsub('[\r\n]', ' ') end
function M.switch_buffer(buf)
  if not api.nvim_buf_is_valid(buf) then return end
  require('repo_panel').hide_lazygit()
  require('replace_review').close()
  require('git_review').close()
  require('workbench').focus_editor()
  api.nvim_set_current_buf(buf)
end
function M.close_buffer(buf)
  if not api.nvim_buf_is_valid(buf) then return end
  if vim.bo[buf].modified then
    vim.ui.select({ 'Cancel', 'Save and close' }, { prompt='Save ' .. vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ':t') .. '?' }, function(choice)
      if choice == 'Save and close' then
        api.nvim_buf_call(buf, function() vim.cmd.write() end)
        Snacks.bufdelete(buf)
      end
    end)
  else Snacks.bufdelete(buf) end
end
local tabs, names = {}, {}
local function refresh_tab(buf)
  local old=tabs[buf]
  if old and old.counted then names[old.base]=math.max(0,(names[old.base] or 1)-1) end
  tabs[buf]=nil
  if not api.nvim_buf_is_valid(buf) then return end
  local path=api.nvim_buf_get_name(buf)
  local meta={path=path,base=vim.fs.basename(path),editable=vim.bo[buf].buftype=='',modified=vim.bo[buf].modified,listed=vim.bo[buf].buflisted}
  meta.editable=meta.editable and (path=='' or vim.fn.isdirectory(path)~=1)
  meta.counted=meta.editable and meta.listed and path~=''
  if meta.counted then names[meta.base]=(names[meta.base] or 0)+1 end
  tabs[buf]=meta
end
local function tab_info(buf)
  if not tabs[buf] then refresh_tab(buf) end
  return tabs[buf]
end
function M.tab_name(buffer)
  local meta=tab_info(buffer.bufnr or buffer.id)
  if not meta or meta.path=='' then return '[Untitled]' end
  if (names[meta.base] or 0)>1 then return vim.fs.relpath(vim.fn.getcwd(-1,0),meta.path) or vim.fn.fnamemodify(meta.path,':~') end
  return meta.base
end
function M.filter_tab(buf)
  local meta=tab_info(buf)
  return meta and meta.editable and (meta.path~='' or meta.modified or vim.b[buf].workbench_explicit_blank) or false
end
function M.setup_tabs()
  -- Buffer metadata belongs to buffer events, not the tabline's redraw loop.
  tabs,names={},{}
  local group=api.nvim_create_augroup('WorkbenchTabMetadata',{clear=true})
  api.nvim_create_autocmd({'BufAdd','BufEnter','BufFilePost','BufModifiedSet','FileType'},{group=group,callback=function(event) refresh_tab(event.buf) end})
  api.nvim_create_autocmd('OptionSet',{group=group,pattern={'buftype','buflisted'},callback=function(event) refresh_tab(event.buf) end})
  api.nvim_create_autocmd('BufDelete',{group=group,callback=function(event)
    local old=tabs[event.buf]
    if old and old.counted then names[old.base]=math.max(0,(names[old.base] or 1)-1) end
    tabs[event.buf]=nil
  end})
  for _,buf in ipairs(api.nvim_list_bufs()) do refresh_tab(buf) end
  require('bufferline').setup({ options={
    name_formatter=M.tab_name,show_duplicate_prefix=false,max_name_length=32,tab_size=24,
    mode='buffers', show_buffer_icons=false, show_close_icon=false, buffer_close_icon='×', modified_icon='●',
    separator_style='thin', always_show_bufferline=true, diagnostics='nvim_lsp',
    show_tab_indicators=false, left_trunc_marker='‹', right_trunc_marker='›',
    diagnostics_indicator=function(count) return ' ' .. count end,
    close_command=M.close_buffer, right_mouse_command=M.close_buffer, left_mouse_command=M.switch_buffer,
    offsets={ { filetype='workbench_sidebar', text=function() return require('workbench').nav_text() end,
      text_align='left', padding=2, separator=true },
      { filetype='snacks_layout_box', text=function() return require('workbench').nav_text() end, text_align='left', padding=2, separator=true } },
    custom_filter=M.filter_tab,
  }, highlights=require('workbench_theme').tabs() })
end
function M.breadcrumb()
  local win=tonumber(vim.g.statusline_winid) or api.nvim_get_current_win()
  local buf=api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) or api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= '' then return '' end
  local path=vim.fs.relpath(vim.fn.getcwd(), api.nvim_buf_get_name(buf)) or vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ':~')
  if path=='' then path='New file' end
  local pieces=vim.split(path, '/', { plain=true, trimempty=true })
  local cursor=api.nvim_win_get_cursor(win)
  local ok, node=pcall(vim.treesitter.get_node,{bufnr=buf,pos={cursor[1]-1,cursor[2]}})
  local symbols={}
  if ok then
    while node and #symbols<3 do
      if node:type():match('function') or node:type():match('method') or node:type():match('class') then
        local name=node:field('name')[1]
        if name then table.insert(symbols, 1, vim.treesitter.get_node_text(name, buf)) end
      end
      node=node:parent()
    end
  end
  vim.list_extend(pieces, symbols)
  local s=require('repo_panel').state()
  local name=s.active and require('sidebar_ui').repo_name(s.parent,s.active) or 'Choose repo'
  local branch=s.active and s.info[s.active] and s.info[s.active].branch or ''
  branch=branch:gsub('%.%.%..*$','')
  return '%#Function#%1@v:lua.WorkspaceUI.repo_click@ Git: '..safe(name)..(branch~='' and ' · '..safe(branch) or '')..' ▾ %T'
    ..'%#WorkbenchMuted# │ '..safe(table.concat(pieces,' › '))
end
function M.repo_click(_,_,button) if button=='l' then vim.schedule(function() require('workbench').choose_repo() end) end end
local function branch()
  local gs=vim.b.gitsigns_status_dict
  if gs and gs.head then return gs.head end
  local p=package.loaded.repo_panel
  if p then local s=p.state();local info=s.active and s.info[s.active];return info and (info.head or info.branch:gsub('%.%.%..*$','')) or '' end
  return ''
end
local function servers()
  local editor=require('workbench').editor
  local buf=vim.bo.buftype=='' and api.nvim_get_current_buf() or (editor and api.nvim_win_is_valid(editor) and api.nvim_win_get_buf(editor))
  if not buf then return '' end
  local names={}; for _, client in ipairs(vim.lsp.get_clients({ bufnr=buf })) do
    names[#names+1]=({ rust_analyzer='Rust', ts_ls='JS/TS', gopls='Go', pyright='Python', ruff='Ruff' })[client.name] or client.name
  end
  return table.concat(names, ' + ')
end
function M.setup()
  _G.WorkspaceUI=M
  vim.opt.showtabline=2
  require('lualine').setup({ options={ theme='tokyonight', icons_enabled=false, globalstatus=true,
    component_separators='', section_separators='', disabled_filetypes={ statusline={} } },
    sections={ lualine_a={ 'mode' }, lualine_b={ branch, { 'diff', symbols={ added='+', modified='~', removed='-' } } },
      lualine_c={ { 'diagnostics', sources={'nvim_workspace_diagnostic'}, symbols={ error='E ', warn='W ', info='I ', hint='H ' } } },
      lualine_x={ servers, 'encoding', 'filetype' }, lualine_y={ {function() return #require('editor_tools').dirty()..' unsaved' end,cond=function() return #require('editor_tools').dirty()>0 end,on_click=function() require('workbench').bottom('editors',true) end},
        {function() return '[Save All]' end,cond=function() return #require('editor_tools').dirty()>0 end,on_click=function() require('editor_tools').save_all() end},'progress' }, lualine_z={ 'location' } },
  })
  api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter' }, { callback=function()
    if vim.bo.buftype~='' then return end
    local lib=package.loaded['diffview.lib']
    if lib and lib.get_current_view() then return end
    vim.wo.winbar='%!v:lua.WorkspaceUI.breadcrumb()'
  end })
end
return M
