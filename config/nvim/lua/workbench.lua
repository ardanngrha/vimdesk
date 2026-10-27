local M = { mode = 'explorer', width = 36, sidebar_open = false, sidebar_epoch = 0, output = {}, gitlog = {}, terminals = {} }
local api = vim.api
local modes = { { 'Files', 'explorer' }, { 'Search', 'search' }, { 'Git', 'git' } }
local explorer, explorer_tab

local function explorer_picker()
  -- A picker still finding its first results has no visible window yet, so
  -- Snacks' current-tab lookup cannot see it. Track it until close as well.
  if explorer and not explorer.closed and explorer_tab==api.nvim_get_current_tabpage() then return explorer end
  return Snacks.picker.get({source='explorer'})[1]
end
M.explorer_picker=explorer_picker

function M.main()
  local all=package.loaded.git_changes
  if all and all.active() then M.editor=all.state.right;return M.editor end
  local diff=package.loaded.git_diff
  if diff and diff.active() then M.editor=diff.state.right;return M.editor end
  local preview=package.loaded.replace_review
  if preview and preview.state and api.nvim_win_is_valid(preview.state.right) then M.editor=preview.state.right;return M.editor end
  local lib=package.loaded['diffview.lib']; local view=lib and lib.get_current_view()
  if view and view.workbench_review and view.cur_layout then
    local win=view.cur_layout:get_main_win()
    if win:is_valid() then M.editor=win.id; return win.id end
  end
  if M.editor and api.nvim_win_is_valid(M.editor) and api.nvim_win_get_tabpage(M.editor)==api.nvim_get_current_tabpage() and api.nvim_win_get_config(M.editor).relative == ''
    and (vim.bo[api.nvim_win_get_buf(M.editor)].buftype == '' or vim.bo[api.nvim_win_get_buf(M.editor)].filetype=='workbench_welcome') then return M.editor end
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_get_config(win).relative == '' and (vim.bo[api.nvim_win_get_buf(win)].buftype == '' or vim.bo[api.nvim_win_get_buf(win)].filetype=='workbench_welcome') then
      M.editor = win; return win
    end
  end
  local current = api.nvim_get_current_win()
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_get_config(win).relative=='' and vim.bo[api.nvim_win_get_buf(win)].filetype=='snacks_dashboard' then
      api.nvim_set_current_win(win); vim.cmd.enew(); M.editor=win; return win
    end
  end
  vim.cmd('rightbelow vnew')
  M.editor = api.nvim_get_current_win()
  if api.nvim_win_is_valid(current) then api.nvim_set_current_win(current) end
  return M.editor
end

function M.focus_editor() vim.cmd.stopinsert(); api.nvim_set_current_win(M.main()) end

function M.side_win()
  local explorer
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    local buf = api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'workbench_sidebar' then return win end
    if vim.bo[buf].filetype == 'snacks_layout_box' and api.nvim_win_get_config(win).relative==''
      and vim.w[win].snacks_win and vim.w[win].snacks_win.position=='left' then explorer=win end
  end
  return explorer
end

function M.rail()
  vim.cmd.redrawtabline()
end

function M.nav_text()
  local labels={}
  for _,item in ipairs(modes) do labels[#labels+1]=M.mode==item[2] and '['..item[1]..']' or item[1] end
  return table.concat(labels,'  ')..'  ×'
end

function M.sidebar_bar()
  local text={}
  for index,item in ipairs(modes) do
    text[#text+1]=(M.mode==item[2] and '%#WorkbenchActive#' or '%#WorkbenchMuted#')
      ..'%'..index..'@v:lua.Workbench.sidebar_click@ '..item[1]..' %T'
  end
  text[#text+1]='%#WorkbenchMuted#%= %4@v:lua.Workbench.sidebar_click@ × %T'
  return table.concat(text)
end

function M.sidebar_click(index,_,button)
  if button~='l' then return end
  M.sidebar_click_epoch=(M.sidebar_click_epoch or 0)+1
  local epoch=M.sidebar_click_epoch
  vim.schedule(function()
    if epoch~=M.sidebar_click_epoch then return end
    if index==4 then M.hide_sidebar()
    elseif index==3 then M.open_git()
    else
      require('repo_panel').hide_lazygit(); require('git_review').close(); M.sidebar(modes[index][2],true)
      if index==2 then require('workspace_search').prompt() end
    end
  end)
end

function M.choose_repo()
  local p=require('repo_panel'); local s=p.state()
  if not s.loaded or s.scanning then
    s.after_scan=M.choose_repo; if not s.scanning then p.refresh() end; return
  end
  Snacks.picker.select(s.repos,{prompt='Choose Git repository',format_item=function(root)
    local info=s.info[root] or {}
    return require('sidebar_ui').repo_name(s.parent,root)..'  ·  '..(info.branch or '')
  end},function(root)
    if root then p.select(root);vim.cmd.redrawstatus() end
  end)
end

function M.open_git()
  require('replace_review').close()
  if M.bottom_win() then M.close_bottom() end
  M.sidebar('git',true)
end

function M.toggle_file_icons()
  vim.g.workbench_file_icons=vim.g.workbench_file_icons==false
  local picker=explorer_picker()
  if picker then
    if vim.g.workbench_file_icons then require('mini.icons') end
    picker.opts.icons.files.enabled=vim.g.workbench_file_icons and not require('performance').enabled()
    picker.list:update()
  end
end

local function close_explorer()
  local pending=explorer_picker()
  if pending then require('workspace_state').capture(pending) end
  require('explorer_panel').hide()
  if pending then pending:close() end
  for _, picker in ipairs(Snacks.picker.get({ source = 'explorer' })) do picker:close() end
end
function M.rebuild_explorer(focus) close_explorer();return M.sidebar('explorer',focus) end

function M.hide_sidebar()
  M.sidebar_epoch=M.sidebar_epoch+1
  M.sidebar_click_epoch=(M.sidebar_click_epoch or 0)+1
  M.sidebar_open = false
  require('search_box').hide()
  require('commit_box').hide()
  require('repo_panel').hide_lazygit()
  M.focus_editor()
  close_explorer()
  local win = M.side_win()
  if win and vim.bo[api.nvim_win_get_buf(win)].filetype=='workbench_sidebar' then pcall(api.nvim_win_close, win, true) end
  M.rail()
end

local function sidebar_buffer()
  if not M.side_buf or not api.nvim_buf_is_valid(M.side_buf) then
    M.side_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(M.side_buf, 'Workbench Sidebar')
    vim.bo[M.side_buf].filetype = 'workbench_sidebar'
    vim.bo[M.side_buf].bufhidden = 'hide'
    vim.bo[M.side_buf].swapfile = false
    local function map(key, fn, desc) vim.keymap.set('n', key, fn, { buffer = M.side_buf, desc = desc }) end
    map('<CR>', function() M.activate(api.nvim_win_get_cursor(0)[1], api.nvim_win_get_cursor(0)[2]) end, 'Activate item')
    map('q', M.hide_sidebar, 'Hide sidebar')
    map('<Esc>', M.focus_editor, 'Return to editor')
    for _, key in ipairs({ 'F', 'f', 'r', 'd', 'D', 'l', '+', '-', 'a', 'A' }) do
      map(key, function()
        if M.mode == 'git' then require('scm').key(key)
        elseif M.mode == 'search' and key == 'r' then require('workspace_search').prompt() end
      end, 'Source Control: ' .. key)
    end
  end
  return M.side_buf
end

function M.sidebar(mode, focus)
  vim.cmd.stopinsert()
  mode = mode or M.mode
  M.sidebar_epoch=M.sidebar_epoch+1
  if mode~='git' then require('commit_box').hide() end
  if mode~='search' then require('search_box').hide();require('replace_review').close() end
  local previous = api.nvim_get_current_win()
  local win = M.side_win()
  if not win then
    api.nvim_set_current_win(M.main())
    vim.cmd('topleft ' .. M.width .. 'vsplit')
    win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, sidebar_buffer())
  end
  -- All views share this split. Explorer renders inside it, so closing its
  -- asynchronous picker layout cannot collapse or resize the editing surface.
  for key, value in pairs({ number = false, relativenumber = false, signcolumn = 'no', wrap = false,
    cursorline = false, winfixwidth = true, foldcolumn = '0', winbar = '', scrolloff=0,sidescrolloff=0,
    winhighlight = 'Normal:WorkbenchSidebar,NormalNC:WorkbenchSidebar,CursorLine:WorkbenchSelected' }) do vim.wo[win][key] = value end
  if mode~='explorer' then close_explorer() end
  M.mode, M.sidebar_open = mode, true
  if mode == 'explorer' then
    local picker=explorer_picker()
    if not picker then
      local light=require('performance').enabled()
      if vim.g.workbench_file_icons~=false and not light then require('mini.icons') end
      M.draw({})
      api.nvim_set_current_win(M.main())
      local opts=vim.tbl_extend('force',{hidden=true},require('performance').explorer_options(),require('workspace_state').prepare())
      opts=vim.tbl_extend('force',opts,{ cwd = vim.fn.getcwd(-1,0), exclude={'.git','**/.git/**'},
        icons={files={enabled=vim.g.workbench_file_icons~=false and not light,dir='󰉋 ',dir_open='󰝰 ',file='󰈔 '}},
        config=function(options) options.actions=options.actions or {};options.actions.confirm=function(p,item,action)
          if not item or item.dir then return require('snacks.explorer.actions').actions.confirm(p,item,action) end
          if p.input.filter.meta.searching then require('snacks.explorer.actions').update(p,{target=item.file}) end
          require('file_preview').open(item.file,true)
        end end,
        on_show=function(p)
          require('explorer_panel').attach(p);require('workspace_state').restore(p)
          if not p.opts.watch then vim.schedule(require('performance').release_watches) end
        end,
        on_close=function(p) require('workspace_state').capture(p);require('explorer_panel').hide() end,
        prompt='', focus=focus and 'list' or false,
        layout = require('sidebar_ui').explorer_layout(win),
        win = { list = { on_buf=function(self) vim.b[self.buf].workbench_explorer=true end,
          keys=require('explorer_actions').keys(),
          on_win=function() vim.defer_fn(M.rail, 50) end, wo = { foldcolumn = '0', foldenable = false,
            winbar='',
            winhighlight='Normal:WorkbenchSidebar,NormalNC:WorkbenchSidebar,CursorLine:WorkbenchSelected' },
        } } })
      picker=Snacks.explorer(opts)
      explorer, explorer_tab=picker,api.nvim_get_current_tabpage()
    elseif focus then picker:focus() end
    if picker and picker.list and picker.list.win.buf then vim.b[picker.list.win.buf].workbench_explorer = true end
  else
    if mode == 'git' then
      local p = require('repo_panel'); local s = p.state(); s.buf = M.side_buf
      require('scm').render(s)
      if not s.loaded then p.refresh(s) else p.ensure_status(s) end
    elseif mode == 'search' then require('workspace_search').render()
    else M.tools() end
    if focus then api.nvim_set_current_win(win) end
  end
  if not focus and api.nvim_win_is_valid(previous) and api.nvim_win_get_config(previous).relative == '' then
    api.nvim_set_current_win(previous)
  elseif not focus then M.focus_editor() end
  vim.defer_fn(M.rail, 40)
  return M.side_win()
end

function M.draw(lines, actions, highlights)
  local buf = sidebar_buffer()
  M.actions = actions or {}
  local compact={}; for _,line in ipairs(lines) do compact[#compact+1]=line:gsub('^      ','  ') end
  local old=api.nvim_buf_get_lines(buf,0,-1,false)
  if vim.deep_equal(old,compact) and vim.deep_equal(M.drawn_highlights,highlights or {}) then return end
  local first=0
  while first<math.min(#old,#compact) and old[first+1]==compact[first+1] do first=first+1 end
  local tail=0
  while tail<math.min(#old,#compact)-first and old[#old-tail]==compact[#compact-tail] do tail=tail+1 end
  local replacement={}
  for i=first+1,#compact-tail do replacement[#replacement+1]=compact[i] end
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf,first,#old-tail,false,replacement)
  vim.bo[buf].modifiable = false
  M.drawn_highlights=vim.deepcopy(highlights or {})
  require('sidebar_ui').clamp(M.side_win())
  local ns = api.nvim_create_namespace('workbench_sidebar')
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(highlights or {}) do
    if h[3] then
      api.nvim_buf_set_extmark(buf,ns,h[1]-1,h[3],{end_col=h[4],hl_group=h[2],hl_mode='combine',priority=120})
    else api.nvim_buf_set_extmark(buf, ns, h[1] - 1, 0, { line_hl_group = h[2] }) end
  end
end

function M.activate(row, col)
  local action = M.actions and M.actions[row]
  if action then action(col or 0) end
end

function M.mouse(permanent)
  local mouse = vim.fn.getmousepos()
  if require('explorer_panel').mouse(mouse,permanent) then return true end
  local side=M.side_win()
  if side and mouse.screenrow==1 and mouse.screencol<=api.nvim_win_get_width(side)+1 then
    local text=api.nvim_eval_statusline(vim.o.tabline,{use_tabline=true,maxwidth=vim.o.columns}).str
    for i,item in ipairs(modes) do
      local start=text:find(item[1],1,true)
      if start then
        local col=vim.fn.strdisplaywidth(text:sub(1,start-1))+1
        if mouse.screencol>=col and mouse.screencol<col+#item[1] then M.sidebar_click(i,1,'l'); return true end
      end
    end
    local close=text:find('×',1,true)
    if close and mouse.screencol==vim.fn.strdisplaywidth(text:sub(1,close-1))+1 then M.sidebar_click(4,1,'l'); return true end
    return false
  end
  if mouse.winid == 0 or not api.nvim_win_is_valid(mouse.winid) then return false end
  -- Tabline/winbar/statusline clicks can retain the previous window id while
  -- reporting line/column zero. Leave those events to Neovim and bufferline.
  if mouse.line<1 or mouse.column<1 then return false end
  local buf = api.nvim_win_get_buf(mouse.winid)
  local all=package.loaded.git_changes
  if all and all.mouse(mouse) then return true end
  if buf == M.side_buf then
    if mouse.line>api.nvim_buf_line_count(buf) then return false end
    local mode, actions, action=M.mode, M.actions, M.actions and M.actions[mouse.line]
    vim.schedule(function()
      -- A queued click must not target a replaced buffer or newly drawn view.
      if not api.nvim_win_is_valid(mouse.winid) or not api.nvim_buf_is_valid(buf)
        or api.nvim_win_get_buf(mouse.winid)~=buf or M.mode~=mode or M.actions~=actions
        or mouse.line>api.nvim_buf_line_count(buf) then return end
      vim.cmd.stopinsert(); api.nvim_set_current_win(mouse.winid)
      api.nvim_win_set_cursor(mouse.winid, { mouse.line, 0 })
      if action then action(mouse.column - 1) end
    end)
    return true
  end
  local panel_action=M.panel_actions and M.panel_actions[buf] and M.panel_actions[buf][mouse.line]
  if panel_action then
    vim.schedule(function() if api.nvim_win_is_valid(mouse.winid) and api.nvim_win_get_buf(mouse.winid)==buf then panel_action() end end)
    return true
  end
  -- Explorer shares the observer too, so its buffer-local mouse mapping cannot
  -- swallow clicks on editor tabs while the file tree has focus.
  for _, picker in ipairs(Snacks.picker.get({source='explorer'})) do
    local list=picker.list
    if list and list.win.win==mouse.winid and mouse.line<=api.nvim_buf_line_count(buf) then
      local index=list:row2idx(mouse.line)
      local item=list:get(index)
      if not item then return false end
      vim.schedule(function()
        if picker.closed or M.mode~='explorer' or not list.win:valid()
          or list.win.buf~=buf or list:get(index)~=item then return end
        vim.cmd.stopinsert(); api.nvim_set_current_win(list.win.win)
        list:move(index,true,true)
        if item.dir then if not permanent then picker:action('confirm') end
        elseif picker.input.filter.meta.searching then
          require('snacks.explorer.actions').update(picker,{target=item.file})
          require('file_preview').open(item.file,permanent)
        else require('file_preview').open(item.file,permanent) end
      end)
      return true
    end
  end
  return false
end

function M.open_file(path, line, col)
  local preview=require('file_preview');if preview.buf and api.nvim_buf_get_name(preview.buf)==path then preview.pin() end
  require('replace_review').close()
  M.focus_editor()
  vim.cmd.edit(vim.fn.fnameescape(path))
  if line then api.nvim_win_set_cursor(0, { math.min(line, api.nvim_buf_line_count(0)), math.max(0, col or 0) }) end
end

function M.tools()
  local items = {
    { 'Plugins and updates', function() vim.cmd.Lazy() end },
    { 'LSP status', function() vim.cmd('checkhealth vim.lsp') end },
    { 'Restore workspace session', M.restore_session },
    { 'Save workspace session', M.save_session },
    { 'Keyboard shortcuts', function() require('which-key').show({ global = true }) end },
  }
  local lines, actions = { '      TOOLS', '', '      Local editor tools', '' }, {}
  for _, item in ipairs(items) do lines[#lines + 1] = '      ' .. item[1]; actions[#lines] = item[2]; lines[#lines + 1] = '' end
  M.draw(lines, actions, { { 1, 'WorkbenchHeading' }, { 3, 'WorkbenchMuted' } })
end

local bottom_types = { problems=true,output=true,terminal=true,gitlog=true,outline=true,editors=true }
function M.bottom_win()
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    local buf = api.nvim_win_get_buf(win)
    if vim.b[buf].workbench_bottom or vim.bo[buf].filetype == 'trouble' then return win end
  end
end

function M.close_bottom()
  local win=M.bottom_win()
  local focused=win and api.nvim_get_current_win()==win
  local ok, trouble = pcall(require, 'trouble'); if ok then trouble.close() end
  if win and api.nvim_win_is_valid(win) then pcall(api.nvim_win_close, win, true) end
  if focused then M.focus_editor() end
end

function M.bottom_bar()
  local chunks = {}
  for i, item in ipairs({ { 'problems', 'Problems' }, { 'output', 'Output' }, { 'terminal', 'Terminal' }, { 'gitlog', 'Git Log' }, {'outline','Outline'}, {'editors','Unsaved'} }) do
    chunks[#chunks + 1] = (M.bottom_mode == item[1] and '%#WorkbenchActive#' or '%#WorkbenchMuted#')
      .. '%' .. i .. '@v:lua.Workbench.bottom_click@ ' .. item[2] .. ' %T'
  end
  if M.bottom_mode=='terminal' then chunks[#chunks+1]='%#WorkbenchMuted# │ '..require('repo_terminals').bar() end
  chunks[#chunks + 1] = '%#WorkbenchMuted#%= %9@v:lua.Workbench.bottom_click@ × %T '
  return table.concat(chunks)
end
function M.bottom_click(index, _, button)
  if button ~= 'l' then return end
  vim.schedule(function()
    if index>=20 then require('repo_terminals').click(index)
    elseif index==9 then M.close_bottom() else M.bottom(({ 'problems','output','terminal','gitlog','outline','editors' })[index]) end
  end)
end

function M.bottom(mode, focus, terminal_root)
  mode = mode or M.bottom_mode or 'terminal'
  assert(bottom_types[mode], mode)
  local previous = api.nvim_get_current_win()
  local source=api.nvim_win_get_buf(M.main())
  M.close_bottom(); M.bottom_mode = mode
  local win, buf
  if mode == 'problems' then
    require('lazy').load({ plugins = { 'trouble.nvim' } })
    require('trouble').open({ mode = 'diagnostics', focus = focus ~= false, open_no_results = true })
    vim.defer_fn(function()
      local bottom = M.bottom_win()
      if bottom then vim.wo[bottom].winbar = '%!v:lua.Workbench.bottom_bar()' end
    end, 60)
  else
    if mode == 'terminal' then
      buf=require('repo_terminals').get(terminal_root)
      if not buf then return end
    else
      local key = mode .. '_buf'
      if not M[key] or not api.nvim_buf_is_valid(M[key]) then
        M[key] = api.nvim_create_buf(false, true); vim.bo[M[key]].bufhidden = 'hide'
      end
      buf = M[key]
      vim.bo[buf].modifiable = true
      if mode=='editors' then require('editor_tools').render_dirty(buf)
      elseif mode=='outline' then require('editor_tools').render_outline(buf,source)
      else
        local lines = mode == 'output' and M.output or M.gitlog
        api.nvim_buf_set_lines(buf, 0, -1, false, #lines > 0 and lines or { 'No output yet.' })
        vim.bo[buf].modifiable = false
      end
    end
    api.nvim_set_current_win(M.main())
    vim.cmd('botright 11split')
    win = api.nvim_get_current_win(); api.nvim_win_set_buf(win, buf)
    vim.b[buf].workbench_bottom = true
    if mode ~= 'terminal' then vim.bo[buf].filetype = 'workbench_output' end
    vim.wo[win].number, vim.wo[win].relativenumber = false, false
    vim.wo[win].signcolumn = 'no'; vim.wo[win].winbar = '%!v:lua.Workbench.bottom_bar()'
    vim.keymap.set('n', 'q', M.close_bottom, { buffer = buf, desc = 'Close panel' })
    if mode == 'terminal' and focus ~= false then vim.cmd.startinsert() end
  end
  if focus == false and api.nvim_win_is_valid(previous) then api.nvim_set_current_win(previous) end
  vim.defer_fn(M.rail, 60)
end

function M.log(label, value, git)
  local lines = git and M.gitlog or M.output
  lines[#lines + 1] = os.date('%H:%M:%S') .. '  ' .. label
  for _, line in ipairs(vim.split(value or '', '\n', { trimempty = true })) do lines[#lines + 1] = '  ' .. line end
  while #lines > 2000 do table.remove(lines, 1) end
  local buf = git and M.gitlog_buf or M.output_buf
  if buf and api.nvim_buf_is_valid(buf) then
    vim.bo[buf].modifiable = true; api.nvim_buf_set_lines(buf, 0, -1, false, lines); vim.bo[buf].modifiable = false
  end
end

function M.palette()
  local entries = {
    { 'Tabs: move file tab left', function() vim.cmd.BufferLineMovePrev() end },
    { 'Tabs: move file tab right', function() vim.cmd.BufferLineMoveNext() end },
    { 'Tabs: pin/unpin file', function() vim.cmd.BufferLineTogglePin() end },
    { 'Explorer: show files', function() M.sidebar('explorer', true) end },
    { 'Explorer: file actions', function() M.sidebar('explorer',true);require('explorer_actions').menu() end },
    { 'Explorer: toggle file icons',M.toggle_file_icons },
    { 'Explorer: new file',function() M.sidebar('explorer',true);require('explorer_actions').create(false) end },
    { 'Explorer: new folder',function() M.sidebar('explorer',true);require('explorer_actions').create(true) end },
    { 'Explorer: collapse folders',function() require('explorer_panel').collapse() end },
    { 'Explorer: reveal active file',function() M.sidebar('explorer',false);require('explorer_panel').reveal() end },
    { 'Editor: Open Editors',function() require('explorer_panel').choose() end },
    { 'Tabs: keep preview',function() require('file_preview').pin() end },
    { 'Performance: toggle Light mode',function() require('performance').toggle() end },
    { 'Git: toggle change overview ruler',function() require('diff_ui').toggle() end },
    { 'Search: workspace text', function() M.sidebar('search', true); require('workspace_search').prompt() end },
    { 'Git: review selected repository', M.open_git },
    { 'Git: choose repository', M.choose_repo },
    { 'Git: Fetch All repositories', function() require('repo_panel').fetch(true) end },
    { 'Git: open LazyGit', function() require('multi_repo').open(require('multi_repo').current_root()) end },
    { 'Git: AI commit in LazyGit (Files → Ctrl+A)', M.open_git },
    { 'Git: branch selector', function() require('scm').branches(false) end },
    { 'Git: merge branch', function() require('scm').branches(true) end },
    { 'Git: continue merge', function() require('scm').continue_merge() end },
    { 'Editor: Save All',require('editor_tools').save_all },
    { 'Editor: unsaved files',function() M.bottom('editors',true) end },
    { 'Editor: document outline',require('editor_tools').outline },
    { 'Terminal: choose repository',require('repo_terminals').choose },
    { 'Problems: show diagnostics', function() M.bottom('problems') end },
    { 'Output: show log', function() M.bottom('output') end },
    { 'Terminal: toggle panel', function() if M.bottom_win() then M.close_bottom() else M.bottom('terminal') end end },
    { 'Session: save workspace', M.save_session }, { 'Session: restore workspace', M.restore_session },
    { 'Editor: split right', function() M.focus_editor(); vim.cmd.vsplit() end },
    { 'Editor: format file', function()
      M.focus_editor(); local callback=vim.fn.maparg('<leader>cf','n',false,true).callback
      if callback then callback() else vim.lsp.buf.format({async=false}) end
    end },
    { 'Plugins: manage/update', function() vim.cmd.Lazy() end },
  }
  for name in pairs(api.nvim_get_commands({ builtin = false })) do entries[#entries + 1] = { name, function() vim.cmd(name) end } end
  Snacks.picker.select(entries, { prompt = 'Command Palette', format_item = function(item) return item[1] end },
    function(item) if item then item[2]() end end)
end

function M.setup_layout()
  require('edgy').setup({ animate = { enabled = false }, wo = { winbar = false },
    options = { left = { size = M.width }, bottom = { size = 11 } },
    left = {}, -- Native sidebars own their widths; Edgy must not undo mouse drags.
    bottom = { { ft = 'workbench_output', size = { height = 11 }, wo = { winbar = '%!v:lua.Workbench.bottom_bar()' } },
      { ft = 'terminal', filter = function(buf) return vim.b[buf].workbench_bottom == true end, size = { height = 11 } },
      { ft = 'trouble', size = { height = 11 } } },
    keys = { ['q'] = false, ['Q'] = false }, exit_when_last = false,
  })
end

local function metadata_path()
  return vim.fn.stdpath('state') .. '/workbench/' .. vim.fn.sha256(vim.fn.getcwd(-1,0)) .. '.json'
end
function M.save_metadata()
  require('commit_box').flush()
  local snapshot=require('workspace_state');snapshot.capture(explorer_picker())
  vim.fn.mkdir(vim.fn.stdpath('state') .. '/workbench', 'p')
  local s = require('repo_panel').state()
  vim.fn.writefile({ vim.json.encode({ mode = M.mode, sidebar_open = M.side_win()~=nil,
    bottom = M.bottom_win() and M.bottom_mode or nil, active = s.active, drafts=s.drafts, ai_tree=s.ai_tree, width = M.width,
    version=2,explorer=snapshot.explorers[vim.fn.getcwd(-1,0)],search=snapshot.search_snapshot(),
    viewport=snapshot.viewport(M.mode),light=require('performance').enabled(),file_icons=vim.g.workbench_file_icons,
    open_editors=require('explorer_panel').expanded }) }, metadata_path())
end
function M.detach_panels()
  require('replace_review').close()
  require('git_review').close()
  M.hide_sidebar(); M.close_bottom()
  for _, term in ipairs(Snacks.terminal.list()) do if term:win_valid() then term:hide() end end
end
function M.restore_metadata()
  if vim.fn.filereadable(metadata_path()) == 0 then return end
  local ok, state = pcall(vim.json.decode, table.concat(vim.fn.readfile(metadata_path()), '\n'))
  if not ok then return end
  if type(state)~='table' then return end
  require('repo_panel').state().active = state.active
  require('repo_panel').state().drafts = state.drafts or {}
  require('repo_panel').state().ai_tree = state.ai_tree or {}
  local snapshot=require('workspace_state')
  if type(state.explorer)=='table' then snapshot.explorers[vim.fn.getcwd(-1,0)]=state.explorer end
  snapshot.restore_search(state.search)
  if type(state.light)=='boolean' then vim.g.workbench_light=state.light end
  if type(state.file_icons)=='boolean' then vim.g.workbench_file_icons=state.file_icons end
  if type(state.open_editors)=='boolean' then require('explorer_panel').expanded=state.open_editors end
  M.width = math.max(20, math.min(math.floor(vim.o.columns*0.6), tonumber(state.width) or 36))
  if state.sidebar_open and vim.tbl_contains({'explorer','search','git'},state.mode) then M.sidebar(state.mode, false);snapshot.restore_view(state.viewport) end
  -- Keep the editing surface clear on startup; reopen the lower panel explicitly.
end
function M.save_session()
  local ui = { mode = M.mode, side = M.side_win()~=nil, bottom = M.bottom_win() and M.bottom_mode or nil }
  M.save_metadata();M.saving_session=true;M.detach_panels()
  local ok,err=pcall(function() require('persistence').save() end);M.saving_session=nil
  if ui.side then M.sidebar(ui.mode, false) end
  if ui.bottom then M.bottom(ui.bottom, false) end
  if ok then vim.notify('Workspace session saved.') else vim.notify('Could not save session: '..tostring(err),vim.log.levels.ERROR) end
end
function M.clean_startup_args()
  -- Old sessions can contain `$argadd ,`, which creates a phantom file tab
  -- when a workspace is reopened. Keep real files, links and all buffer edits.
  local path=vim.fs.normalize(vim.fn.getcwd(-1,0)..'/,')
  if vim.uv.fs_lstat(path) then return end
  local buffers={}
  for _,buf in ipairs(api.nvim_list_bufs()) do
    if vim.bo[buf].buftype=='' and vim.fs.normalize(api.nvim_buf_get_name(buf))==path then
      if vim.bo[buf].modified then return end
      if api.nvim_buf_is_loaded(buf) then
        local content=api.nvim_buf_get_lines(buf,0,-1,false)
        if #content~=1 or content[1]~='' then return end
      end
      buffers[#buffers+1]=buf
    end
  end
  local args=vim.fn.argv()
  for index=#args,1,-1 do
    if vim.fs.normalize(vim.fn.fnamemodify(args[index],':p'))==path then vim.cmd(index..'argdelete') end
  end
  for _,buf in ipairs(buffers) do if api.nvim_buf_is_valid(buf) then api.nvim_buf_delete(buf,{force=false}) end end
end

function M.restore_session()
  for _, buf in ipairs(api.nvim_list_bufs()) do if vim.bo[buf].modified then
    vim.notify('Save modified files before restoring a session.', vim.log.levels.WARN); return
  end end
  M.detach_panels(); require('persistence').load()
end

function M.setup()
  _G.Workbench = M
  require('file_preview').setup();require('explorer_panel').setup()
  require('commit_box').setup()
  require('search_box').setup()
  require('sidebar_ui').setup()
  require('editor_tools').setup()
  local function map(key, action, desc, modes_) vim.keymap.set(modes_ or 'n', key, action, { desc = desc }) end
  map('<leader>e', function() M.sidebar('explorer', true) end, 'Explorer')
  map('<leader>fn',function() M.focus_editor(); vim.cmd.enew(); vim.b.workbench_explicit_blank=true; vim.cmd.redrawtabline() end,'New file')
  map('<leader>fg', function() M.sidebar('search', true); require('workspace_search').prompt() end, 'Search workspace')
  map('<leader>p', M.palette, 'Command Palette')
  map('<leader>ue', function() if M.side_win() then M.hide_sidebar() else M.sidebar(M.mode, false) end end, 'Toggle sidebar')
  map('<leader>ut', function() if M.bottom_win() then M.close_bottom() else M.bottom('terminal') end end, 'Toggle terminal/panel')
  map('<leader>ui',M.toggle_file_icons,'Toggle file icons')
  map('<leader>up',function() require('performance').toggle() end,'Toggle Light mode')
  map('<leader>bp',function() require('file_preview').pin() end,'Keep preview tab')
  map('<leader>wa',require('editor_tools').save_all,'Save all files')
  map('<leader>so',require('editor_tools').outline,'Document outline')
  map('<leader>bu',function() M.bottom('editors',true) end,'Unsaved files')
  map('<leader>xx', function() M.bottom('problems') end, 'Problems')
  map('<leader>uo', function() M.bottom('output') end, 'Output')
  map('<leader>ul', function() M.bottom('gitlog') end, 'Git log')
  map('<leader>|', function() M.focus_editor(); vim.cmd.vsplit() end, 'Split editor right')
  map('<leader>-', function() M.focus_editor(); vim.cmd.split() end, 'Split editor below')
  map('<leader>qs', M.save_session, 'Save workspace session'); map('<leader>qr', M.restore_session, 'Restore workspace session')
  map('<leader>qq', function() vim.cmd('confirm qall') end, 'Quit Neovim (confirm unsaved changes)')
  map('<C-s>', function() if vim.bo.buftype == '' then vim.cmd.write() end end, 'Save file', { 'n', 'i', 'v' })
  map('<D-s>', function() if vim.bo.buftype == '' then vim.cmd.write() end end, 'Save file', { 'n', 'i', 'v' })
  map('<D-p>', function() Snacks.picker.files({ cwd = vim.fn.getcwd(), hidden = true, ignored = true }) end, 'Quick Open', { 'n', 'i' })
  map('<D-S-p>', M.palette, 'Command Palette', { 'n', 'i' })
  for key, action in pairs({ h = 'h', j = 'j', k = 'k', l = 'l' }) do map('<C-' .. key .. '>', '<C-w>' .. action, 'Focus editor window') end
  -- Observe the original event instead of replaying <LeftMouse> from a mapping:
  -- replay loses native tabline click handling. Consume only our own controls.
  local mouse_ns=api.nvim_create_namespace('workbench_mouse')
  local left_mouse=vim.keycode('<LeftMouse>')
  local double_left=vim.keycode('<2-LeftMouse>')
  local left_drag=vim.keycode('<LeftDrag>')
  local left_release=vim.keycode('<LeftRelease>')
  local right_mouse,right_release={},{}
  for _,prefix in ipairs({'','2-','3-','4-'}) do
    right_mouse[vim.keycode('<'..prefix..'RightMouse>')]=true
    right_release[vim.keycode('<'..prefix..'RightRelease>')]=true
  end
  local right_consumed=false
  local wheel_up,wheel_down=vim.keycode('<ScrollWheelUp>'),vim.keycode('<ScrollWheelDown>')
  local wheel_left,wheel_right=vim.keycode('<ScrollWheelLeft>'),vim.keycode('<ScrollWheelRight>')
  vim.on_key(function(key,typed)
    local event=typed or key
    if event==wheel_up or event==wheel_down or event==wheel_left or event==wheel_right then
      local mouse=vim.fn.getmousepos();local side=M.side_win()
      if mouse.winid==require('explorer_panel').win then return '' end
      if side and api.nvim_win_is_valid(mouse.winid) then
        local ft=vim.bo[api.nvim_win_get_buf(mouse.winid)].filetype
        if M.mode~='explorer' and (mouse.winid==side or ft=='workbench_commit' or ft=='workbench_search_input') then
          if event==wheel_up or event==wheel_down then
            local step=tonumber(vim.o.mousescroll:match('ver:(%d+)')) or 3
            require('sidebar_ui').queue_scroll(side,(event==wheel_up and -1 or 1)*step)
          end
          return ''
        end
      end
    elseif right_mouse[event] then
      right_consumed=require('explorer_actions').mouse()
      if right_consumed then return '' end
    elseif right_release[event] and right_consumed then
      right_consumed=false;return ''
    elseif event==left_mouse or event==double_left then
      if event==double_left and M.mode~='explorer' then return end
      local mouse=vim.fn.getmousepos(); local side=M.side_win()
      M.dragging_sidebar=side and mouse.screenrow>1 and mouse.screencol==api.nvim_win_get_width(side)+1
      if M.mouse(event==double_left) then return '' end
    elseif event==left_drag and M.dragging_sidebar then
      local side=M.side_win()
      local width=math.max(20,math.min(math.floor(vim.o.columns*0.6),vim.fn.getmousepos().screencol-1))
      -- Resize the shared split; Explorer's floating layout follows its anchor.
      M.width=width
      vim.schedule(function()
        if side and api.nvim_win_is_valid(side) and M.side_win()==side then
          api.nvim_win_set_width(side,width)
          for _,picker in ipairs(Snacks.picker.get({source='explorer'})) do
            if picker.layout and not picker.closed then picker.layout:update() end
          end
        end
      end)
      if M.mode=='explorer' then return '' end
    elseif event==left_release then M.dragging_sidebar=nil end
  end,mouse_ns)
  local group = api.nvim_create_augroup('Workbench', { clear = true })
  api.nvim_create_autocmd('WinEnter', { group = group, callback = function()
    if vim.bo.buftype == '' then M.editor = api.nvim_get_current_win() end
  end })
  api.nvim_create_autocmd('TabEnter', { group = group, callback = M.rail })
  api.nvim_create_autocmd('WinResized',{group=group,callback=function()
    local win=M.side_win()
    if win and vim.tbl_contains(vim.v.event.windows or {},win) then
      local width=api.nvim_win_get_width(win)
      if width~=M.width then
        M.width=width
      end
      local state=require('repo_panel').state()
      if M.mode=='git' and state.render_width~=width then require('repo_list').render(state) end
      M.rail()
    end
  end})
  api.nvim_create_autocmd('User', { group = group, pattern = 'PersistenceSavePre', callback = function() if not M.saving_session then M.save_metadata(); M.detach_panels() end end })
  api.nvim_create_autocmd('User', { group = group, pattern = 'PersistenceLoadPost', callback = function() vim.defer_fn(M.restore_metadata, 100) end })
  api.nvim_create_autocmd('VimEnter', { group = group, callback = function()
    if #vim.api.nvim_list_uis() == 0 or vim.g.workbench_disable_startup then return end
    vim.defer_fn(function()
      local directory=vim.fn.argc()==1 and vim.fn.argv(0) or nil
      local workspace=vim.fn.argc()==0 or directory and vim.fn.isdirectory(directory)==1
      if directory and vim.fn.isdirectory(directory)==1 then
        vim.cmd.cd(vim.fn.fnamemodify(directory,':p'))
        if vim.fn.isdirectory(api.nvim_buf_get_name(0))==1 then vim.cmd.enew() end
      end
      if workspace then
        if vim.fn.filereadable(require('persistence').current()) == 1 then M.restore_session()
        else M.sidebar('explorer', false) end
      else M.sidebar('explorer', false) end
      if workspace then M.clean_startup_args() end
      local p=require('repo_panel'); if not p.state().loaded then p.refresh() end
    end, 150)
  end })
  api.nvim_create_autocmd('DirChanged', { group = group, callback = function()
    if M.sidebar_open then vim.schedule(function() M.hide_sidebar(); M.sidebar(M.mode, false) end) end
  end })
end

return M
