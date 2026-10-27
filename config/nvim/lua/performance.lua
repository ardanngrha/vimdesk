local M={}
function M.enabled() return vim.g.workbench_light==true end
function M.explorer_options()
  local live=not M.enabled()
  return {watch=live,diagnostics=live,git_status=live,follow_file=false,
    -- Snacks retains node badges when updates are disabled. Clear only the
    -- emitted items, once during finding, without copying or mutating its tree.
    transform=not live and function(item) item.status=nil;item.severity=nil;item.dir_status=nil;return item end or nil}
end
function M.release_watches()
  local watch=package.loaded['snacks.explorer.watch'];if not watch then return end
  for _,p in ipairs(Snacks.picker.get({source='explorer',tab=false})) do if p.opts.watch then return end end
  watch.abort()
end
function M.toggle()
  vim.g.workbench_light=not M.enabled()
  local w=require('workbench')
  if w.mode=='explorer' and w.side_win() then
    local current=vim.api.nvim_get_current_win()
    local p=w.explorer_picker();local focused=p and p:is_focused()
    w.rebuild_explorer(focused)
    if not focused and vim.api.nvim_win_is_valid(current) then vim.api.nvim_set_current_win(current) end
  end
  vim.schedule(M.release_watches)
  local diff=package.loaded.diff_ui;if diff then diff.refresh() end
  vim.cmd.redrawstatus();vim.cmd.redrawtabline()
  vim.notify('Light mode '..(M.enabled() and 'on · explorer refresh: u' or 'off'))
end
return M
