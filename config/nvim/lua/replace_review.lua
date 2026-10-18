local M={}
local api=vim.api
function M.close()
  local state=M.state;if not state then return end;M.state=nil
  for _,win in ipairs({state.left,state.right}) do if api.nvim_win_is_valid(win) then pcall(api.nvim_win_call,win,function() vim.cmd.diffoff() end) end end
  if api.nvim_win_is_valid(state.right) then pcall(api.nvim_win_close,state.right,true) end
  if api.nvim_win_is_valid(state.left) and api.nvim_buf_is_valid(state.original) then
    api.nvim_win_set_buf(state.left,state.original);vim.wo[state.left].winbar=state.winbar
    require('workbench').editor=state.left
    pcall(api.nvim_win_set_cursor,state.left,state.cursor)
  end
  for _,buf in ipairs({state.before,state.after}) do if api.nvim_buf_is_valid(buf) then pcall(api.nvim_buf_delete,buf,{force=true}) end end
end
local function buffer(label,lines,ft)
  local buf=api.nvim_create_buf(false,true);api.nvim_buf_set_name(buf,'Replace preview '..label..' '..buf)
  vim.bo[buf].bufhidden='hide';vim.bo[buf].swapfile=false;vim.bo[buf].filetype=ft
  api.nvim_buf_set_lines(buf,0,-1,false,lines);vim.bo[buf].modified=false;vim.bo[buf].modifiable=false;return buf
end
function M.open(plan)
  M.close();require('git_review').close();require('repo_panel').hide_lazygit()
  local w=require('workbench');w.focus_editor()
  local side=w.side_win();local side_width=side and api.nvim_win_get_width(side)
  local left=w.main();local orig=api.nvim_win_get_buf(left)
  local state={left=left,original=orig,cursor=api.nvim_win_get_cursor(left),winbar=vim.wo[left].winbar}
  M.state=state
  local ft=vim.bo[plan.buf].filetype
  state.before=buffer('Before',plan.before,ft);state.after=buffer('After',plan.after,ft)
  api.nvim_win_set_buf(left,state.before);vim.cmd('rightbelow vsplit');state.right=api.nvim_get_current_win()
  api.nvim_win_set_buf(state.right,state.after)
  local path=plan.path:gsub('%%','%%%%')
  vim.wo[left].winbar='%#ReviewBefore# Before %#ReviewPath# '..path
  vim.wo[state.right].winbar='%#ReviewAfter# After %#ReviewPath# '..path..'%= %1@v:lua.ReplaceReview.click@[Apply selected]%T %2@v:lua.ReplaceReview.click@[Close]%T '
  for _,win in ipairs({left,state.right}) do
    vim.wo[win].winfixwidth=false;api.nvim_win_call(win,function() vim.cmd.diffthis() end)
  end
  w.editor=state.right
  if side and api.nvim_win_is_valid(side) then api.nvim_win_set_width(side,side_width) end
  api.nvim_win_set_width(state.right,math.floor((api.nvim_win_get_width(left)+api.nvim_win_get_width(state.right))/2))
end
function M.click(index,_,button)
  if button~='l' then return end
  vim.schedule(function() if index==1 then require('workspace_search').apply_preview() else M.close() end end)
end
_G.ReplaceReview=M
return M
