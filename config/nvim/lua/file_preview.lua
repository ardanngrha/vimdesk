-- One disposable, unedited buffer. Open Editors references these same buffers.
local M={}
local api=vim.api
function M.pin(buf)
  buf=buf or M.buf
  if not buf or not api.nvim_buf_is_valid(buf) then return end
  vim.b[buf].workbench_preview=nil
  if M.buf==buf then M.buf=nil end
  vim.cmd.redrawtabline()
  local panel=package.loaded.explorer_panel;if panel then panel.queue() end
end
function M.open(path,permanent)
  local old=M.buf
  if old and api.nvim_buf_is_valid(old) and vim.bo[old].modified then M.pin(old);old=nil end
  local existing=vim.fn.bufnr(path)
  local listed=existing>=0 and api.nvim_buf_is_valid(existing) and vim.bo[existing].buflisted
  require('repo_panel').hide_lazygit();require('git_review').close();require('replace_review').close()
  require('workbench').focus_editor()
  local ok,err=pcall(vim.cmd.edit,vim.fn.fnameescape(path))
  if not ok then vim.notify(tostring(err),vim.log.levels.ERROR);return end
  local buf=api.nvim_get_current_buf()
  if permanent or (listed and existing~=old) then M.pin(buf)
  else M.buf=buf;vim.b[buf].workbench_preview=true end
  if old and old~=buf and api.nvim_buf_is_valid(old) then
    if not vim.bo[old].modified and #vim.fn.win_findbuf(old)==0 then
      local deleted=pcall(api.nvim_buf_delete,old,{force=false})
      if not deleted then M.pin(old) end
    else M.pin(old) end
  end
  local panel=package.loaded.explorer_panel;if panel then panel.queue() end
end
function M.setup()
  local group=api.nvim_create_augroup('WorkbenchFilePreview',{clear=true})
  api.nvim_create_autocmd({'BufModifiedSet','TextChanged','TextChangedI','BufWritePost'},{group=group,callback=function(e)
    if M.buf==e.buf and (vim.bo[e.buf].modified or e.event=='BufWritePost') then M.pin(e.buf) end
  end})
  api.nvim_create_autocmd({'BufDelete','BufWipeout'},{group=group,callback=function(e) if M.buf==e.buf then M.buf=nil end end})
end
return M
