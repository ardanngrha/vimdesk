-- Working-tree discards preserve the index and keep a restart-safe recovery
-- manifest. Never run reset --hard or git clean against a repository.
local M={}
local api,uv=vim.api,vim.uv
local function notify(text) vim.notify(text,vim.log.levels.WARN,{title='Discard changes'}) end
local function state() return require('repo_panel').state() end
local function base() return vim.fn.stdpath('state')..'/workbench/discards' end
local function latest_file(root) return base()..'/latest-'..vim.fn.sha256(root):sub(1,16)..'.json' end
local function json(path,data)
  local ok,result=pcall(vim.fn.writefile,{vim.json.encode(data)},path)
  return ok and result==0
end
local function load(path)
  local ok,data=pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end)
  return ok and data or nil
end
local function stamp(path)
  local s=uv.fs_lstat(path);if not s then return 'missing' end
  return table.concat({s.type,s.size,s.mode,s.ino,s.mtime.sec,s.mtime.nsec,s.ctime.sec,s.ctime.nsec},':')
end
local function safe(root,path)
  if path=='' or path:sub(1,1)=='/' or path:find('%z') then return false end
  for part in path:gmatch('[^/]+') do if part=='..' or part=='.git' then return false end end
  local parent=uv.fs_realpath(vim.fs.dirname(root..'/'..path:gsub('/$','')))
  if not parent then
    local dir=vim.fs.dirname(root..'/'..path:gsub('/$',''))
    while dir~=vim.fs.dirname(dir) and not parent do dir=vim.fs.dirname(dir);parent=uv.fs_realpath(dir) end
  end
  local real=uv.fs_realpath(root)
  return parent and real and (parent==real or vim.startswith(parent,real..'/'))
end
local function index(root,items)
  local cmd={'git','--literal-pathspecs','-C',root,'ls-files','-s','-z','--'}
  for _,item in ipairs(items) do cmd[#cmd+1]=item.path end
  local result=vim.system(cmd,{text=false}):wait()
  return result.code==0 and result.stdout or nil
end
local function ready(root)
  if require('scm').unsaved(root) then return false end
  if state().fetching or (state().busy or {})[root] then notify('Wait for the repository operation to finish.');return false end
  return true
end
local function finish(root,dir,manifest)
  for _,item in ipairs(manifest.items) do item.after=stamp(root..'/'..item.path) end
  manifest.index=index(root,manifest.items)
  if not json(dir..'/manifest.json',manifest) or not json(latest_file(root),{dir=dir,root=root}) then
    notify('Changes were discarded; recovery files are saved in '..dir..'. Could not save the restore shortcut.')
  end
  state().busy[root]=nil;state().review_refresh=root
  require('workbench').log('Discard recovery',dir,true)
  require('repo_panel').update_status();vim.cmd.checktime()
  vim.notify('Working changes discarded · More → Restore last discard\nBackup: '..dir)
end

function M.discard(root,files)
  if not root or not ready(root) then return end
  local items={}
  for _,file in ipairs(files or {}) do
    if file.conflict then notify('Resolve conflicts before discarding.');return end
    if file.changed then
      if not safe(root,file.path) then notify('Cannot safely discard '..file.path);return end
      local stat=uv.fs_lstat(root..'/'..file.path)
      if stat and stat.type=='directory' and not file.untracked then notify('Use LazyGit for submodule changes.');return end
      items[#items+1]={path=file.path:gsub('/$',''),untracked=file.untracked or false,before=stamp(root..'/'..file.path:gsub('/$',''))}
    end
  end
  if #items==0 then return end
  local original_index=index(root,items);if not original_index then notify('Could not inspect the Git index.');return end
  local choice='Discard '..#items..' file(s)'
  vim.ui.select({'Cancel',choice},{prompt='Discard working changes? Staged changes stay. A recovery copy is saved.'},function(answer)
    if answer~=choice or not ready(root) then return end
    if index(root,items)~=original_index then notify('The index changed. Refresh and retry.');return end
    for _,item in ipairs(items) do
      if stamp(root..'/'..item.path)~=item.before then notify('Files changed while confirming. Refresh and retry.');return end
    end
    local dir=base()..'/'..os.date('%Y%m%d-%H%M%S')..'-'..uv.hrtime()
    if vim.fn.mkdir(dir,'p',448)~=1 then notify('Could not create the recovery directory.');return end
    local manifest={root=root,items=items,index=original_index}
    local size=0
    for i,item in ipairs(items) do
      item.backup=dir..'/'..i
      local path=root..'/'..item.path;local stat=uv.fs_lstat(path)
      if stat and not item.untracked then
        size=size+stat.size
        if size>16*1024*1024 then notify('Recovery exceeds 16 MB. Back up these files manually before using LazyGit.');return end
        local ok,err
        if stat.type=='link' then
          item.link=uv.fs_readlink(path);ok=item.link~=nil
        elseif stat.type=='file' then ok,err=uv.fs_copyfile(path,item.backup)
        else notify('Unsupported file type. Nothing was discarded.');return end
        if not ok then notify('Could not save recovery copy: '..tostring(err));return end
        item.mode=stat.mode
      end
    end
    if not json(dir..'/manifest.json',manifest) then notify('Could not save the manifest. Nothing was discarded.');return end
    for _,item in ipairs(items) do
      if stamp(root..'/'..item.path)~=item.before then notify('A file changed during backup. Nothing was discarded.');return end
    end
    if index(root,items)~=original_index then notify('The index changed during backup. Nothing was discarded.');return end
    state().busy[root]='Discarding working changes';require('scm').render()
    local cmd={'git','--literal-pathspecs','-C',root,'restore','--worktree','--'}
    local tracked={}
    for _,item in ipairs(items) do if not item.untracked then cmd[#cmd+1]=item.path;tracked[#tracked+1]=item end end
    local function apply(result)
      vim.schedule(function()
        if result.code~=0 then
          for _,item in ipairs(tracked) do item.applied=stamp(root..'/'..item.path)~=item.before end
          finish(root,dir,manifest)
          notify('Discard stopped. Recovery copies: '..dir..'\n'..(result.stderr or ''));return
        end
        for _,item in ipairs(tracked) do item.applied=true end
        for _,item in ipairs(items) do if item.untracked then
          -- Recheck after Git finishes. A rename is recoverable and does not
          -- traverse symlinks or remove files outside this directory.
          if stamp(root..'/'..item.path)~=item.before then notify('Kept a changed untracked file: '..item.path)
          else
            local ok,err=uv.fs_rename(root..'/'..item.path,item.backup)
            if ok then item.applied=true else notify('Kept '..item.path..': '..tostring(err)) end
          end
        end end
        finish(root,dir,manifest)
      end)
    end
    if #tracked==0 then apply({code=0})
    else vim.system(cmd,{text=true,timeout=30000},apply) end
  end)
end

function M.restore(root)
  if not root or not ready(root) then return end
  local latest=load(latest_file(root))
  if not latest or latest.root~=root or type(latest.dir)~='string' or not vim.startswith(latest.dir,base()..'/') then notify('No discard recovery for this repository.');return end
  local manifest=load(latest.dir..'/manifest.json')
  if not manifest or manifest.root~=root or manifest.restored then notify('No pending discard recovery.');return end
  local function unchanged()
    if index(root,manifest.items)~=manifest.index then notify('The index changed. Recovery copies remain in '..latest.dir);return false end
    for _,item in ipairs(manifest.items) do if item.applied and not item.restored then
      if not safe(root,item.path) or stamp(root..'/'..item.path)~=item.after then notify('Newer edits were kept. Recover manually from '..latest.dir);return false end
    end end
    return true
  end
  if not unchanged() then return end
  vim.ui.select({'Cancel','Restore discarded changes'},{prompt='Restore the saved working changes?'},function(answer)
    if answer~='Restore discarded changes' or not ready(root) or not unchanged() then return end
    for _,item in ipairs(manifest.items) do if item.applied and not item.restored then
      local path=root..'/'..item.path;local ok,err=true,nil
      vim.fn.mkdir(vim.fs.dirname(path),'p')
      if item.untracked then ok,err=uv.fs_rename(item.backup,path)
      elseif item.before=='missing' then ok,err=uv.fs_unlink(path)
      elseif item.link then
        if uv.fs_lstat(path) then ok,err=uv.fs_unlink(path) end
        if ok then ok,err=uv.fs_symlink(item.link,path) end
      else
        -- Do not follow a symlink that Git recreated in place of a regular file.
        local stat=uv.fs_lstat(path)
        if stat and stat.type=='link' then ok,err=uv.fs_unlink(path) end
        if ok then ok,err=uv.fs_copyfile(item.backup,path) end
        if ok and item.mode then uv.fs_chmod(path,item.mode) end
      end
      if not ok then notify('Restore stopped: '..tostring(err)..'\nRecovery: '..latest.dir);return end
      item.restored=true;json(latest.dir..'/manifest.json',manifest)
    end end
    manifest.restored=true;json(latest.dir..'/manifest.json',manifest)
    state().review_refresh=root;require('repo_panel').update_status();vim.cmd.checktime()
    vim.notify('Discarded working changes restored.')
  end)
end
return M
