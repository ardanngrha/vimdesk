local M = {}
local api = vim.api
local function current()
  local lib=package.loaded['diffview.lib']
  return lib and lib.get_current_view()
end
function M.active() local view=current(); return require('git_diff').active() or view and view.workbench_review end
function M.close_merge()
  local view=current()
  if view and view.workbench_review then require('diffview').close(); return true end
end
function M.close()
  require('git_diff').close()
  return M.close_merge()
end

function M.labels(view)
  view=view or current()
  if not view or not view.cur_layout then return end
  local merge=view.cur_entry and view.cur_entry.kind=='conflicting'
  for _,win in ipairs(view.cur_layout.windows) do
    if win:is_valid() and win.file then
      local label=merge and ({a='Current',b='Result',c='Incoming'})[win.file.symbol]
        or ({a='Before',b='After'})[win.file.symbol]
      if label then
        local path=(win.file.path or ''):gsub('%%','%%%%'):gsub('[\r\n\t]',' ')
        local group='Review'..label
        win.file.winbar='%#'..group..'# '..label..' %#ReviewPath#  %< '..path
        if merge and win.file.symbol=='b' then
          win.file.winbar=win.file.winbar..'%='
          local short=api.nvim_win_get_width(win.id)<108
          for i,text in ipairs({'Accept Incoming','Accept Current','Accept Both','Save','Stage'}) do
            if short then text=text:gsub('Accept ','') end
            win.file.winbar=win.file.winbar..' %'..i..'@v:lua.GitReview.accept_click@%#'
              ..(i==5 and 'WorkbenchPrimary' or 'WorkbenchButton')..'#['..text..']%T%#ReviewPath# '
          end
        end
        vim.wo[win.id].winbar=win.file.winbar
        vim.wo[win.id].winfixwidth=false; vim.wo[win.id].winfixheight=false
        if not merge then
          local line=win.file.symbol=='a' and 'ReviewBeforeLine' or 'ReviewAfterLine'
          local text=win.file.symbol=='a' and 'ReviewBeforeText' or 'ReviewAfterText'
          vim.wo[win.id].winhighlight='DiffAdd:'..line..',DiffDelete:'..line..',DiffChange:'..line..',DiffText:'..text
        end
        if win.file.bufnr and api.nvim_buf_is_valid(win.file.bufnr) then
          local RevType=require('diffview.vcs.rev').RevType
          vim.bo[win.file.bufnr].modifiable=win.file.rev.type==RevType.LOCAL
        end
      end
    end
  end
end

function M.accept_click(index,_,button)
  if button~='l' then return end
  vim.schedule(function()
    local view=current()
    if not view or not view.cur_entry or view.cur_entry.kind~='conflicting' then return end
    local main=view.cur_layout:get_main_win(); if not main:is_valid() then return end
    api.nvim_set_current_win(main.id)
    if index<=3 then require('diffview.actions').conflict_choose(({'theirs','ours','all'})[index])()
    elseif index==4 then vim.cmd.write()
    elseif index==5 then
      local s=require('repo_panel').state()
      for _,file in ipairs((s.info[view.adapter.ctx.toplevel] or {}).files or {}) do
        if file.path==view.cur_entry.path then require('scm').stage({root=view.adapter.ctx.toplevel,file=file},true); break end
      end
    end
  end)
end

local function attach(view)
  if not view.workbench_review or not view:is_cur_tabpage() then return end
  if not view.cur_entry or not view.cur_layout:get_main_win():is_valid() then return end
  view.panel:close()
  local w=require('workbench')
  w.mode='git'; w.editor=view.cur_layout:get_main_win().id
  if not w.side_win() then w.sidebar('git',false) end
  w.sidebar_open=w.side_win()~=nil
  local side=w.side_win()
  if side and api.nvim_win_get_position(side)[2]~=0 then
    api.nvim_win_call(side,function() vim.cmd('wincmd H') end)
    api.nvim_win_set_width(side,view.review_width or w.width)
  end
  if view.review_layout~=view.cur_layout.name then
    if side then
      api.nvim_win_set_width(side,view.review_width or w.width)
      local left=view.cur_layout.c or view.cur_layout.a
      if left and left:is_valid() then
        api.nvim_win_set_width(left.id,math.floor((vim.o.columns-api.nvim_win_get_width(side)-2)/2))
      end
    end
    view.review_layout=view.cur_layout.name
  end
  M.labels(view)
end

local function select_file(view,path,staged)
  for _,file in view.files:iter() do
    if (not path or file.path==path) and (staged and file.kind=='staged' or not staged and file.kind~='staged') then
      local side=require('workbench').side_win()
      if side then view.review_width=api.nvim_win_get_width(side) end
      view:set_file(file,true); M.labels(view); return true
    end
  end
end

function M.open(root,path,staged)
  local info=require('repo_panel').state().info[root] or {}
  local selected
  for _,file in ipairs(info.files or {}) do
    if (not path or file.path==path) and (not staged or file.staged) then selected=file;break end
  end
  if selected and not selected.conflict then return require('git_diff').working(root,selected,staged) end
  require('replace_review').close()
  require('lazy').load({plugins={'diffview.nvim'}})
  local view=current()
  if view and view.workbench_review and view.adapter.ctx.toplevel==root then
    if select_file(view,path,staged) then return view end
    view.emitter:once('files_updated',function() vim.schedule(function()
      if view:is_cur_tabpage() then select_file(view,path,staged) end
    end) end)
    view:update_files(); return view
  end
  M.close()
  require('repo_panel').hide_lazygit()
  require('workbench').focus_editor()
  M.pending=root
  local args={'-C='..root,'--untracked-files=all'}
  if path then args[#args+1]='--selected-file='..root..'/'..path end
  -- Include index and working-tree entries in one view. Partly staged files
  -- have two rows; clicks select the appropriate kind without opening more tabs.
  require('diffview').open(args)
  local opened=current()
  M.pending=nil
  if opened then
    opened.workbench_review=true
    opened.review_width=require('workbench').width
    opened.emitter:on('file_open_pre',function()
      local side=require('workbench').side_win()
      if side then opened.review_width=api.nvim_win_get_width(side) end
    end)
    opened.emitter:on('file_open_post',function() vim.schedule(function() attach(opened) end) end)
    opened.emitter:on('files_updated',function() vim.schedule(function()
      if opened:is_cur_tabpage() then require('repo_panel').update_status(); M.labels(opened) end
    end) end)
    if staged then
      opened.emitter:once('files_updated',function() vim.schedule(function()
        if opened:is_cur_tabpage() then select_file(opened,path,true) end
      end) end)
    end
  end
  return opened
end

function M.open_repo(root)
  require('scm').select(root)
  local info=require('repo_panel').state().info[root]
  local file=info and info.files and info.files[1]
  if file then return M.open(root,file.path,file.staged and not file.changed) end
  M.close(); require('workbench').sidebar('git',true)
end

function M.options()
  return {use_icons=false,view={
    default={layout='diff2_horizontal',winbar_info=true},
    merge_tool={layout='diff3_mixed',disable_diagnostics=true,winbar_info=true},
  },hooks={
    view_opened=function(view) if M.pending then view.workbench_review=true end end,
    diff_buf_win_enter=function() vim.schedule(function() M.labels() end) end,
    view_closed=function(view)
      if view.workbench_review then vim.schedule(function()
        if current() then return end
        local w=require('workbench')
        if w.mode=='git' then
          if not w.side_win() then w.sidebar('git',false) end
          require('repo_panel').update_status()
        end
      end) end
    end,
  }}
end

function M.setup(opts)
  _G.GitReview=M
  api.nvim_create_autocmd('WinResized',{group=api.nvim_create_augroup('GitReviewStyle',{clear=true}),callback=function() M.labels() end})
  -- Geometry only: Incoming is Git stage 3, Current stage 2, Result LOCAL.
  -- Revision semantics and Diffview's conflict actions remain intact.
  local async=require('diffview.async')
  local Window=require('diffview.scene.window').Window
  local Mixed=require('diffview.scene.layouts.diff_3_mixed').Diff3Mixed
  Mixed.create=async.void(function(self,pivot)
    self:create_pre()
    pivot=pivot or self:find_pivot()
    for _,win in ipairs(self.windows) do if win.id~=pivot then win:close(true) end end
    for _,step in ipairs({{'b','belowright split'},{'c','aboveleft vsplit'},{'a','aboveleft vsplit'}}) do
      api.nvim_win_call(pivot,function()
        vim.cmd(step[2]); local id=api.nvim_get_current_win()
        if self[step[1]] then self[step[1]]:set_id(id) else self[step[1]]=Window({id=id}) end
      end)
    end
    api.nvim_win_close(pivot,true)
    self.windows={self.a,self.b,self.c}
    async.await(self:create_post())
  end)
  require('diffview').setup(opts)
  api.nvim_create_autocmd('FileType',{pattern='DiffviewFiles',callback=function(ev)
    vim.keymap.set('n','<LeftMouse>',function()
      local mouse=vim.fn.getmousepos()
      if mouse.winid~=api.nvim_get_current_win() or mouse.line<1 then return '<LeftMouse>' end
      vim.schedule(function()
        if api.nvim_buf_is_valid(ev.buf) and api.nvim_get_current_buf()==ev.buf then
          api.nvim_win_set_cursor(0,{math.min(mouse.line,api.nvim_buf_line_count(ev.buf)),0})
          require('diffview.actions').select_entry()
        end
      end)
      return ''
    end,{buffer=ev.buf,expr=true})
  end})
end
return M
