local M={generation=0}
local api=vim.api
local function wb() return require('workbench') end
function M.dirty()
  local ret={};for _,buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype=='' and vim.bo[buf].modified then ret[#ret+1]=buf end
  end
  table.sort(ret,function(a,b) return api.nvim_buf_get_name(a)<api.nvim_buf_get_name(b) end);return ret
end
function M.save_all()
  local saved,unnamed,failed=0,0,{}
  for _,buf in ipairs(M.dirty()) do
    if api.nvim_buf_get_name(buf)=='' then unnamed=unnamed+1
    else
      local ok,err=pcall(api.nvim_buf_call,buf,function() vim.cmd.write() end)
      if ok then saved=saved+1 else failed[#failed+1]=api.nvim_buf_get_name(buf)..': '..tostring(err) end
    end
  end
  if #failed>0 then wb().log('Save All',table.concat(failed,'\n'));vim.notify('Some files could not be saved; check Output.',vim.log.levels.WARN)
  else vim.notify('Saved '..saved..' files'..(unnamed>0 and (' · '..unnamed..' unnamed buffers need :saveas') or '')) end
  M.refresh_dirty();vim.cmd.redrawstatus()
end
local function draw(buf,lines,actions)
  if not api.nvim_buf_is_valid(buf) then return end
  wb().panel_actions=wb().panel_actions or {};wb().panel_actions[buf]=actions or {}
  vim.bo[buf].modifiable=true;api.nvim_buf_set_lines(buf,0,-1,false,lines);vim.bo[buf].modified=false;vim.bo[buf].modifiable=false
  vim.keymap.set('n','<CR>',function()
    local action=(wb().panel_actions[buf] or {})[api.nvim_win_get_cursor(0)[1]];if action then action() end
  end,{buffer=buf,desc='Open item'})
end
function M.render_dirty(buf)
  local lines={'  Unsaved files','  [Save All]',''};local actions={[2]=M.save_all}
  for _,file in ipairs(M.dirty()) do
    local name=api.nvim_buf_get_name(file);local label=name~='' and (vim.fs.relpath(vim.fn.getcwd(-1,0),name) or vim.fn.fnamemodify(name,':~')) or '[Untitled]'
    lines[#lines+1]='  ● '..label;actions[#lines]=function() require('editor_ui').switch_buffer(file) end
  end
  if #lines==3 then lines[#lines+1]='  No unsaved files.' end
  draw(buf,lines,actions)
end
function M.refresh_dirty()
  local w=wb();if w.bottom_mode=='editors' and w.editors_buf and api.nvim_buf_is_valid(w.editors_buf) then M.render_dirty(w.editors_buf) end
end
function M.render_outline(buf,source)
  M.generation=M.generation+1;local generation=M.generation
  if M.cancel then pcall(M.cancel);M.cancel=nil end
  if not source or not api.nvim_buf_is_valid(source) or vim.bo[source].buftype~='' then draw(buf,{'  Open a source file to show its outline.'});return end
  M.source=source
  local label=vim.fs.relpath(vim.fn.getcwd(-1,0),api.nvim_buf_get_name(source)) or vim.fn.fnamemodify(api.nvim_buf_get_name(source),':t')
  local header={'  Outline · '..label,'  [Refresh]',''}
  local function display(lines,actions)
    if generation~=M.generation or not api.nvim_buf_is_valid(buf) then return end
    local rows=vim.deepcopy(header);vim.list_extend(rows,lines)
    local click={[2]=function() M.render_outline(buf,source) end}
    for row,action in pairs(actions or {}) do click[row+#header]=action end
    draw(buf,rows,click)
  end
  local clients=vim.lsp.get_clients({bufnr=source,method='textDocument/documentSymbol'})
  if #clients==0 then display({'  No symbol-capable LSP attached to this file.'});return end
  display({'  Loading symbols…'})
  local uri=vim.uri_from_bufnr(source)
  M.cancel=vim.lsp.buf_request_all(source,'textDocument/documentSymbol',{textDocument={uri=uri}},function(responses)
    if generation~=M.generation then return end
    M.cancel=nil
    local rows,actions,seen={}, {},{}
    local function visit(symbols,depth,encoding)
      for _,symbol in ipairs(symbols or {}) do
        if #rows>=1000 then return end
        local range=symbol.selectionRange or symbol.range or (symbol.location and symbol.location.range)
        local location=symbol.location or (range and {uri=uri,range=range})
        if range and location then
          local identity=location.uri..':'..range.start.line..':'..range.start.character..':'..symbol.name
          if not seen[identity] then
            seen[identity]=true
            local kind=vim.lsp.protocol.SymbolKind[symbol.kind] or 'Symbol'
            rows[#rows+1]='  '..string.rep('  ',depth)..symbol.name..' · '..kind..'  :'..(range.start.line+1)
            actions[#rows]=function() wb().focus_editor();vim.lsp.util.show_document(location,encoding,{focus=true,reuse_win=true}) end
          end
        end
        if symbol.children then visit(symbol.children,depth+1,encoding) end
      end
    end
    for id,response in pairs(responses) do
      local client=vim.lsp.get_client_by_id(id)
      if response.result then visit(response.result,0,client and client.offset_encoding or 'utf-16') end
    end
    display(#rows>0 and rows or {'  No symbols in this file.'},actions)
  end)
  vim.defer_fn(function()
    if generation==M.generation and M.cancel then
      pcall(M.cancel);M.cancel=nil;M.generation=M.generation+1
      if wb().bottom_mode=='outline' then draw(buf,{'  Outline request timed out. Reopen Outline to retry.'}) end
    end
  end,7000)
end
function M.outline()
  require('replace_review').close();wb().bottom('outline',true)
end
function M.setup()
  _G.EditorTools=M
  api.nvim_create_user_command('WorkspaceSaveAll',M.save_all,{})
  api.nvim_create_user_command('WorkspaceUnsaved',function() wb().bottom('editors',true) end,{})
  api.nvim_create_user_command('WorkspaceOutline',M.outline,{})
  local group=api.nvim_create_augroup('WorkbenchEditorTools',{clear=true})
  api.nvim_create_autocmd({'BufModifiedSet','BufWritePost','BufDelete'},{group=group,callback=function(ev)
    if not api.nvim_buf_is_valid(ev.buf) or vim.bo[ev.buf].buftype~='' then return end
    vim.schedule(function() M.refresh_dirty();vim.cmd.redrawstatus() end)
  end})
  api.nvim_create_autocmd({'TextChanged','TextChangedI'},{group=group,callback=function(ev)
    if vim.bo[ev.buf].buftype=='' and wb().mode=='search' and wb().side_win() then require('workspace_search').changed() end
  end})
  api.nvim_create_autocmd({'BufEnter','LspAttach','BufWritePost'},{group=group,callback=function(ev)
    if vim.bo[ev.buf].buftype~='' then return end
    local w=wb()
    if w.bottom_mode=='outline' and w.bottom_win() and w.outline_buf then
      vim.defer_fn(function() if w.bottom_mode=='outline' and api.nvim_buf_is_valid(ev.buf) then M.render_outline(w.outline_buf,ev.buf) end end,250)
    end
    if ev.event=='BufWritePost' and w.mode=='search' and w.side_win() then require('workspace_search').changed() end
  end})
end
return M
