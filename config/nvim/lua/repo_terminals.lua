local M={buffers={},order={}}
local api=vim.api
function M.default_root()
  return require('repo_panel').state().active or require('multi_repo').current_root() or vim.fn.getcwd(-1,0)
end
function M.get(root)
  root=root or M.default_root();root=vim.uv.fs_realpath(root) or root
  if vim.fn.isdirectory(root)~=1 then vim.notify('Terminal directory is no longer available.',vim.log.levels.WARN);return end
  local buf=M.buffers[root]
  if not buf or not api.nvim_buf_is_valid(buf) or vim.fn.jobwait({vim.b[buf].terminal_job_id or -1},0)[1]~=-1 then
    buf=api.nvim_create_buf(false,true);M.buffers[root]=buf
    if not vim.tbl_contains(M.order,root) then M.order[#M.order+1]=root end
    api.nvim_buf_call(buf,function() vim.fn.jobstart(vim.o.shell,{term=true,cwd=root}) end)
    vim.bo[buf].filetype='terminal';vim.bo[buf].bufhidden='hide';vim.b[buf].workspace_repo_root=root
    vim.b[buf].workbench_terminal_root=root
  end
  M.active=root;return buf
end
function M.open(root,focus) require('workbench').bottom('terminal',focus,root or M.default_root()) end
function M.choose()
  local s=require('repo_panel').state();local roots=vim.deepcopy(s.repos)
  if #roots==0 then roots={s.parent} end
  vim.ui.select(roots,{prompt='Open repository terminal',format_item=function(root)
    return require('sidebar_ui').repo_name(s.parent,root)
  end},function(root) if root then M.open(root,true) end end)
end
function M.bar()
  local s=require('repo_panel').state();local pieces={}
  for i,root in ipairs(M.order) do
    local buf=M.buffers[root]
    if buf and api.nvim_buf_is_valid(buf) then
      local name=require('sidebar_ui').repo_name(s.parent,root):gsub('%%','%%%%')
      pieces[#pieces+1]='%'..(20+i)..'@v:lua.Workbench.bottom_click@'
        ..(M.active==root and '%#WorkbenchActive#' or '%#WorkbenchMuted#')..' '..name..' %T'
    end
  end
  pieces[#pieces+1]='%20@v:lua.Workbench.bottom_click@%#WorkbenchButton# [+] %T'
  return table.concat(pieces)
end
function M.click(index)
  if index==20 then M.choose() elseif M.order[index-20] then M.open(M.order[index-20],true) end
end
return M
