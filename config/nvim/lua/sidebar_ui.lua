local M={}
local api=vim.api
M.input_highlight='Normal:WorkbenchCommitInput,NormalNC:WorkbenchCommitInput,NormalFloat:WorkbenchCommitInput,FloatBorder:WorkbenchInputBorder,FloatTitle:WorkbenchInputTitle'
function M.repo_name(parent,root)
  local relative=vim.fs.relpath(parent,root)
  if not relative or relative=='.' or relative=='' then return vim.fs.basename(root) end
  return relative
end
function M.field_config(side,row,height,title)
  if not side or not api.nvim_win_is_valid(side) then return end
  local buf=api.nvim_win_get_buf(side)
  -- Explorer owns a different buffer while its layout is closing. Async repo
  -- discovery must wait for the native sidebar before positioning fields.
  if vim.bo[buf].filetype~='workbench_sidebar' or row<1 or row+height+1>api.nvim_buf_line_count(buf) then return end
  local ok,pos=pcall(vim.fn.screenpos,side,row,1)
  if not ok then return end
  if pos.row==0 or row+height+1>vim.fn.line('w$',side) then return end
  return {relative='win',win=side,row=pos.row-1-api.nvim_win_get_position(side)[1],col=1,
    width=math.max(1,api.nvim_win_get_width(side)-4),height=height,style='minimal',border='rounded',
    focusable=true,zindex=35,title=' '..title..' ',title_pos='left',noautocmd=true}
end
function M.field_style(win)
  if not win or not api.nvim_win_is_valid(win) then return end
  vim.wo[win].winhighlight=M.input_highlight
  vim.wo[win].cursorline=false;vim.wo[win].scrolloff=0
end
function M.explorer_layout(width)
  return {preview=false,layout={box='vertical',position='left',backdrop=false,height=0,
    width=width,min_width=20,border={' ',' ',' ',' ',' ',' ',' ',' '},
    wo={winhighlight='Normal:WorkbenchSidebar,NormalNC:WorkbenchSidebar,FloatBorder:WorkbenchSidebar'},
    {win='input',height=1,border='rounded',title=' Filter files ',title_pos='left',
      wo={winhighlight=M.input_highlight}},
    {win='list',border='hpad',wo={winhighlight='Normal:WorkbenchSidebar,NormalNC:WorkbenchSidebar,NormalFloat:WorkbenchSidebar,CursorLine:WorkbenchSelected'}},
    {win='preview',height=0.4,border='top',title='{preview}'},
  }}
end
return M
