local M={clipboard={}}
local api,uv=vim.api,vim.uv
local function notify(text,level) vim.notify(text,level or vim.log.levels.INFO,{title='Files'}) end
local function inside(path,parent) return path==parent or vim.startswith(path,parent..'/') end
local function picker_or_current(picker)
  return picker or Snacks.picker.get({source='explorer'})[1]
end
local function paths(picker)
  local result={}
  for _,item in ipairs(picker:selected({fallback=true})) do if item.file then result[#result+1]=vim.fs.normalize(item.file) end end
  table.sort(result)
  local unique={}
  for _,path in ipairs(result) do
    local covered=false
    for _,parent in ipairs(unique) do if inside(path,parent) then covered=true;break end end
    if not covered then unique[#unique+1]=path end
  end
  return unique
end
local function guard(picker,files)
  for _,path in ipairs(files) do
    if inside(picker:cwd(),path) then notify('The explorer root cannot be renamed or deleted.',vim.log.levels.WARN);return false end
    for _,buf in ipairs(api.nvim_list_bufs()) do
      if vim.bo[buf].modified and inside(api.nvim_buf_get_name(buf),path) then
        notify('Save unsaved edits before renaming or deleting '..vim.fs.basename(path)..'.',vim.log.levels.WARN);return false
      end
    end
  end
  return true
end
local function update(picker,target,changed)
  local tree=require('snacks.explorer.tree')
  for _,path in ipairs(changed or {}) do tree:refresh(vim.fs.dirname(path)) end
  if picker and not picker.closed then
    tree:refresh(picker:cwd())
    require('snacks.explorer.actions').update(picker,{target=target,refresh=true})
  end
  local p=package.loaded.repo_panel
  if p and p.state().loaded then p.refresh() end
end
function M.copy(picker)
  picker=picker_or_current(picker);if not picker then return end
  M.clipboard=paths(picker)
  picker.list:set_selected()
  notify(('Copied %d item%s · select a destination folder and Paste'):format(#M.clipboard,#M.clipboard==1 and '' or 's'))
end
function M.copy_path(picker,relative)
  picker=picker_or_current(picker);if not picker then return end
  local values=paths(picker)
  if relative then for i,path in ipairs(values) do values[i]=vim.fs.relpath(picker:cwd(),path) or path end end
  local value=table.concat(values,'\n')
  vim.fn.setreg('"',value,'v');vim.fn.setreg('+',value,'v')
  notify(relative and 'Copied workspace-relative path' or 'Copied absolute path')
end
local function destination(dir,source,reserved)
  local name=vim.fs.basename(source);local stem,extension=name:match('^(.+)(%.[^%.]+)$')
  stem,extension=stem or name,extension or ''
  local path=dir..'/'..name;local index=0
  while uv.fs_lstat(path) or reserved[path] do
    index=index+1;path=dir..'/'..stem..' copy'..(index>1 and ' '..index or '')..extension
  end
  reserved[path]=true;return path
end
function M.paste(picker,files,dir)
  picker=picker_or_current(picker);if not picker then return end
  if M.copying then notify('A file copy is still running.',vim.log.levels.WARN);return end
  files=files or vim.deepcopy(M.clipboard)
  if #files==0 then notify('Copy a file or folder first (c).',vim.log.levels.WARN);return end
  if vim.fn.executable('cp')~=1 then notify('File copy requires the system cp command.',vim.log.levels.WARN);return end
  dir=dir or picker:dir();local realdir=uv.fs_realpath(dir)
  if not realdir then notify('The destination folder no longer exists.',vim.log.levels.WARN);return end
  local jobs,reserved={},{}
  for _,from in ipairs(files) do
    local stat=uv.fs_lstat(from)
    if not stat then notify('The copied item no longer exists: '..from,vim.log.levels.WARN);return end
    local realfrom=uv.fs_realpath(from)
    if stat.type=='directory' and realfrom and inside(realdir,realfrom) then
      notify('Choose a destination outside the copied folder.',vim.log.levels.WARN);return
    end
    jobs[#jobs+1]={from=from,to=destination(dir,from,reserved)}
  end
  M.copying=true
  local next_job
  next_job=function(index)
    local job=jobs[index]
    if not job then
      M.copying=false;update(picker,jobs[#jobs].to,{dir..'/.'});notify('Copied '..#jobs..' item(s)');return
    end
    -- Preserve symlinks and never overwrite a destination; do not block the UI.
    vim.system({'cp','-R','-P','-n','--',job.from,job.to},{text=true,timeout=120000},function(result)
      vim.schedule(function()
        if result.code~=0 then
          M.copying=false;update(picker,dir,{dir..'/.'})
          notify('Copy did not finish: '..vim.trim(result.stderr or '')..'\nInspect '..job.to..' before retrying.',vim.log.levels.ERROR);return
        end
        next_job(index+1)
      end)
    end)
  end
  next_job(1)
end
function M.duplicate(picker)
  picker=picker_or_current(picker);local item=picker and picker:current()
  if item and item.file then M.paste(picker,{item.file},vim.fs.dirname(item.file)) end
end
function M.rename(picker)
  picker=picker_or_current(picker);local item=picker and picker:current()
  if not item or not item.file or not guard(picker,{item.file}) then return end
  local from=item.file
  vim.ui.input({prompt='Rename file or folder',default=vim.fs.basename(from)},function(value)
    if not value or value=='' or not guard(picker,{from}) then return end
    local to=vim.fs.normalize(vim.fs.dirname(from)..'/'..value)
    if to==from then return end
    if uv.fs_lstat(to) then notify('That name already exists. Nothing was replaced.',vim.log.levels.WARN);return end
    if inside(to,from) then notify('A folder cannot be moved inside itself.',vim.log.levels.WARN);return end
    for _,buf in ipairs(api.nvim_list_bufs()) do
      if inside(api.nvim_buf_get_name(buf),to) then notify('An open buffer already uses that name.',vim.log.levels.WARN);return end
    end
    -- Keep buffers in place. The upstream file helper uses a fuzzy bufnr lookup,
    -- which can match a child file when the renamed item is a directory.
    Snacks.rename.on_rename_file(from,to,function()
      if uv.fs_lstat(to) then notify('That name now exists. Nothing was replaced.',vim.log.levels.WARN);return end
      vim.fn.mkdir(vim.fs.dirname(to),'p')
      local moved,err=uv.fs_rename(from,to)
      if not moved then notify('Rename failed: '..tostring(err),vim.log.levels.ERROR);return end
      for _,buf in ipairs(api.nvim_list_bufs()) do
        local name=api.nvim_buf_get_name(buf)
        if inside(name,from) then api.nvim_buf_set_name(buf,to..name:sub(#from+1)) end
      end
      update(picker,to,{from,to})
    end)
  end)
end
local function trash_dir() return vim.fn.stdpath('state')..'/workbench/trash/files' end
local function write_json(path,value)
  local ok,result=pcall(vim.fn.writefile,{vim.json.encode(value)},path)
  return ok and result==0
end
function M.delete(picker)
  picker=picker_or_current(picker);if not picker then return end
  local files=paths(picker);if #files==0 or not guard(picker,files) then return end
  local label=#files==1 and vim.fs.basename(files[1]) or #files..' items'
  vim.ui.select({'Cancel','Move to VimDesk trash'},{prompt='Delete '..label..'?'},function(choice)
    if choice~='Move to VimDesk trash' or not guard(picker,files) then return end
    local dir=trash_dir()..'/'..os.date('%Y%m%d-%H%M%S')..'-'..uv.hrtime()
    vim.fn.mkdir(dir,'p',448)
    local manifest={items={}}
    for i,path in ipairs(files) do manifest.items[i]={from=path,to=dir..'/'..i..'-'..vim.fs.basename(path)} end
    if not write_json(dir..'/manifest.json',manifest) then
      notify('Could not save the trash manifest. Nothing was deleted.',vim.log.levels.ERROR);return
    end
    local moved=0
    for _,item in ipairs(manifest.items) do
      local ok,err=uv.fs_rename(item.from,item.to)
      if not ok then
        notify('Could not move '..item.from..' to trash: '..tostring(err)..'\nThe source was left in place.',vim.log.levels.ERROR);break
      end
      moved=moved+1
      for _,buf in ipairs(api.nvim_list_bufs()) do
        if inside(api.nvim_buf_get_name(buf),item.from) then Snacks.bufdelete(buf) end
      end
    end
    picker.list:set_selected();update(picker,vim.fs.dirname(files[1]),files)
    if moved>0 then
      if not write_json(trash_dir()..'/latest.json',{dir=dir}) then
        notify('Saved deleted items in '..dir..', but could not update the restore shortcut.',vim.log.levels.ERROR);return
      end
      notify(('Moved %d item(s) to VimDesk trash · More → Restore last deleted'):format(moved))
    end
  end)
end
function M.restore(picker)
  picker=picker_or_current(picker)
  local ok,latest=pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(trash_dir()..'/latest.json'),'\n')) end)
  if not ok or not latest.dir or not inside(latest.dir,trash_dir()) then notify('No saved deletion to restore.',vim.log.levels.WARN);return end
  local loaded,manifest=pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(latest.dir..'/manifest.json'),'\n')) end)
  if not loaded or type(manifest)~='table' or type(manifest.items)~='table' then notify('Could not read the trash manifest.',vim.log.levels.WARN);return end
  local pending={}
  for _,item in ipairs(manifest.items) do
    if type(item.from)~='string' or type(item.to)~='string' or not inside(item.to,latest.dir) then
      notify('Invalid path in the trash manifest.',vim.log.levels.WARN);return
    end
    if uv.fs_lstat(item.to) then
    if uv.fs_lstat(item.from) then notify('Restore stopped: '..item.from..' already exists. Nothing was replaced.',vim.log.levels.WARN);return end
    pending[#pending+1]=item
  end end
  if #pending==0 then notify('The last deletion has already been restored.');return end
  local changed={}
  for _,item in ipairs(pending) do
    vim.fn.mkdir(vim.fs.dirname(item.from),'p')
    local moved,err=uv.fs_rename(item.to,item.from)
    if not moved then notify('Restore failed: '..tostring(err),vim.log.levels.ERROR);break end
    changed[#changed+1]=item.from
  end
  update(picker,changed[1],changed);notify('Restored '..#changed..' item(s)')
end
function M.menu(picker)
  picker=picker_or_current(picker);if not picker or picker.closed then return end
  local item=picker:current();local label=item and item.file and vim.fs.basename(item.file) or 'Files'
  local items={
    {'New file…','',function() M.create(false,picker) end},
    {'New folder…','',function() M.create(true,picker) end},
    {'New file / folder…','a',function() picker:action('explorer_add') end},
    {'Rename…','r / F2',function() M.rename(picker) end},
    {'Copy','c',function() M.copy(picker) end},
    {'Paste','p',function() M.paste(picker) end},
    {'Duplicate','D',function() M.duplicate(picker) end},
    {'Copy relative path','y',function() M.copy_path(picker,true) end},
    {'Copy absolute path','Y',function() M.copy_path(picker,false) end},
    {'Delete…','d / Delete',function() M.delete(picker) end},
    {'Restore last deleted','',function() M.restore(picker) end},
    {'Refresh','u',function() picker:action('explorer_update') end},
    {'Show / hide ignored files','I',function() picker:action('toggle_ignored') end},
    {'Collapse all folders','Z',function() require('explorer_panel').collapse() end},
    {'Reveal active file','',function() require('explorer_panel').reveal() end},
    {'All open editors','',function() require('explorer_panel').choose() end},
  }
  vim.ui.select(items,{prompt='File actions · '..label,format_item=function(value) return value[1]..(value[2]~='' and '    '..value[2] or '') end},function(choice)
    if choice and not picker.closed then choice[3]() end
  end)
end
function M.create(folder,picker)
  picker=picker_or_current(picker);if not picker or picker.closed then return end
  local parent=picker:dir()
  vim.ui.input({prompt=folder and 'New folder' or 'New file'},function(value)
    if not value or vim.trim(value)=='' or picker.closed then return end
    local path=vim.fs.normalize(parent..'/'..value)
    if uv.fs_lstat(path) then notify('Already exists: '..path,vim.log.levels.WARN);return end
    if folder then
      if vim.fn.mkdir(path,'p')~=1 then notify('Could not create folder.',vim.log.levels.ERROR);return end
    else
      vim.fn.mkdir(vim.fs.dirname(path),'p')
      local fd,err=uv.fs_open(path,'wx',420)
      if not fd then notify(tostring(err),vim.log.levels.ERROR);return end
      uv.fs_close(fd)
    end
    local tree=require('snacks.explorer.tree');tree:open(folder and path or vim.fs.dirname(path));tree:refresh(parent)
    require('snacks.explorer.actions').update(picker,{target=path,refresh=true})
  end)
end
function M.mouse()
  local mouse=vim.fn.getmousepos()
  for _,picker in ipairs(Snacks.picker.get({source='explorer'})) do
    local list=picker.list
    if list and list.win.win==mouse.winid then
      if mouse.line<1 then return true end
      local index=list:row2idx(mouse.line);local item=list:get(index);if not item then return true end
      vim.schedule(function()
        if picker.closed or not list.win:valid() or list:get(index)~=item then return end
        vim.cmd.stopinsert();api.nvim_set_current_win(list.win.win);list:move(index,true,true);M.menu(picker)
      end)
      return true
    end
  end
  local w=require('workbench')
  return w.mode=='explorer' and w.side_win()==mouse.winid
end
function M.bar()
  return '%#WorkbenchButton#%1@v:lua.ExplorerActions.click@[New]%T %2@v:lua.ExplorerActions.click@[Paste]%T %3@v:lua.ExplorerActions.click@[More]%T'
end
function M.click(index,_,button)
  if button~='l' then return end
  vim.schedule(function()
    local picker=picker_or_current();if not picker then return end
    if index==1 then picker:action('explorer_add') elseif index==2 then M.paste(picker) else M.menu(picker) end
  end)
end
function M.keys()
  return {
    ['r']={function() M.rename() end,desc='Rename file / folder'},
    ['<F2>']={function() M.rename() end,desc='Rename file / folder'},
    ['d']={function() M.delete() end,desc='Move to VimDesk trash'},
    ['<Del>']={function() M.delete() end,desc='Move to VimDesk trash'},
    ['c']={function() M.copy() end,desc='Copy file / folder'},
    ['<C-c>']={function() M.copy() end,desc='Copy file / folder'},
    ['p']={function() M.paste() end,desc='Paste file / folder'},
    ['<C-v>']={function() M.paste() end,desc='Paste file / folder'},
    ['D']={function() M.duplicate() end,desc='Duplicate file / folder'},
    ['y']={function() M.copy_path(nil,true) end,desc='Copy relative path'},
    ['Y']={function() M.copy_path(nil,false) end,desc='Copy absolute path'},
    ['g.']={function() M.menu() end,desc='File actions menu'},
    ['<Menu>']={function() M.menu() end,desc='File actions menu'},
    ['m']={function() M.rename() end,desc='Move / rename file or folder'},
  }
end
_G.ExplorerActions=M
return M
