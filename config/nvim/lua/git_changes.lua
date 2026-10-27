-- A bounded, read-only multi-file review. Two native windows, two scratch
-- buffers, aligned rows and manual context folds; never one window per file.
local M={generation=0}
local api,uv=vim.api,vim.uv
local ns=api.nvim_create_namespace('vimdesk_changes')
local header_ns=api.nvim_create_namespace('vimdesk_changes_headers')
local function valid(win) return win and api.nvim_win_is_valid(win) end
local function clean(text) return text:gsub('[%c]',' ') end
local function escape(text) return clean(text):gsub('%%','%%%%') end
local function heading(file,width,closed)
  local suffix=file.staged and '[Unstage] [Open]' or '[Stage] [Open]'
  local path=clean(file.path);local limit=math.max(1,width-vim.fn.strdisplaywidth(suffix)-6)
  if vim.fn.strdisplaywidth(path)>limit then
    local low,high=0,vim.fn.strchars(path)
    while low<high do
      local mid=math.ceil((low+high)/2)
      if vim.fn.strdisplaywidth(vim.fn.strcharpart(path,0,mid))<limit then low=mid else high=mid-1 end
    end
    path=vim.fn.strcharpart(path,0,low)..'…'
  end
  local text=(closed and '▸  ' or '▾  ')..path
  text=text..string.rep(' ',math.max(1,width-vim.fn.strdisplaywidth(text..suffix)-1))
  local first=#text+1;text=text..suffix
  return text,{stage=first,open=first+#suffix-#'[Open]'}
end
function M.active()
  local s=M.state;return s and valid(s.left) and valid(s.right) and api.nvim_win_get_tabpage(s.right)==api.nvim_get_current_tabpage()
end
local option_names={'winbar','winhighlight','wrap','scrollbind','cursorbind','foldmethod','foldenable','foldlevel','foldtext','foldcolumn','statuscolumn','number','relativenumber','signcolumn','cursorlineopt'}
function M.close()
  M.generation=M.generation+1
  local s=M.state;if not s then return end;M.state=nil
  for _,win in ipairs({s.left,s.right}) do require('diff_ui').detach(win) end
  local restore=valid(s.left) and s.left or s.right
  if valid(s.left) and valid(s.right) then pcall(api.nvim_win_close,s.right,true) end
  if valid(restore) then
    if api.nvim_buf_is_valid(s.original) then api.nvim_win_set_buf(restore,s.original) end
    for name,value in pairs(s.options) do vim.wo[restore][name]=value end
    require('workbench').editor=restore;pcall(api.nvim_win_set_cursor,restore,s.cursor)
  end
  for _,buf in ipairs(s.buffers or {}) do if api.nvim_buf_is_valid(buf) then pcall(api.nvim_buf_delete,buf,{force=true}) end end
end

local function lines(text)
  local result=vim.split(text or '','\n',{plain=true})
  if result[#result]=='' then table.remove(result) end
  for i,line in ipairs(result) do result[i]=line:gsub('\r$','') end
  return result
end
local function inline(a,b)
  local first,last=0,0;local limit=math.min(#a,#b)
  while first<limit and a:byte(first+1)==b:byte(first+1) do first=first+1 end
  while last<limit-first and a:byte(#a-last)==b:byte(#b-last) do last=last+1 end
  -- Extmark columns are bytes, but cannot start inside a UTF-8 character.
  while first>0 and a:byte(first+1) and a:byte(first+1)>=128 and a:byte(first+1)<192 do first=first-1 end
  while last>0 and a:byte(#a-last+1) and a:byte(#a-last+1)>=128 and a:byte(#a-last+1)<192 do last=last-1 end
  return first,#a-last,#b-last
end

local function build(entries)
  local out={left={},right={},rows={{},{}},files={},folds={}}
  local function row(a,b,ma,mb)
    local n=#out.left+1;out.left[n]=a or '';out.right[n]=b or '';out.rows[1][n]=ma or {};out.rows[2][n]=mb or {};return n
  end
  for _,entry in ipairs(entries) do
    local file={file=entry.file,header=#out.left+1,path=entry.file.path,staged=entry.staged}
    out.files[#out.files+1]=file
    local heading='▾  '..clean(file.path)..(entry.staged and '  [Unstage] [Open]' or '  [Stage] [Open]')
    row(heading,heading,{header=file},{header=file})
    if entry.error then
      row('  '..entry.error,'  '..entry.error,{file=file},{file=file})
    else
      local a,b=lines(entry.before),lines(entry.after)
      if #out.left+#a+#b>19500 then
        row('  Combined review row limit · Open individually','  Combined review row limit · Open individually',{file=file},{file=file})
        file.finish=#out.left;row('','');goto continue
      end
      local hunks=vim.diff(table.concat(a,'\n')..(#a>0 and '\n' or ''),table.concat(b,'\n')..(#b>0 and '\n' or ''),
        {result_type='indices',algorithm='histogram',ctxlen=0})
      local ai,bi=1,1
      local function same(until_a)
        local start=#out.left+1
        while ai<until_a do
          row(a[ai],b[bi],{line=ai,file=file},{line=bi,file=file});ai=ai+1;bi=bi+1
        end
        local finish=#out.left
        -- Context folds keep three visible lines at either end.
        if finish-start+1>9 then out.folds[#out.folds+1]={start+3,finish-3} end
      end
      for _,h in ipairs(hunks) do
        local sa,ca,sb,cb=h[1],h[2],h[3],h[4]
        if ca==0 then sa=sa+1 end;if cb==0 then sb=sb+1 end
        same(sa)
        for offset=0,math.max(ca,cb)-1 do
          local an=offset<ca and sa+offset or nil;local bn=offset<cb and sb+offset or nil
          local ma={line=an,file=file,kind=an and 'Delete' or nil,filler=not an}
          local mb={line=bn,file=file,kind=bn and 'Add' or nil,filler=not bn}
          if an and bn then
            local start,ae,be=inline(a[an],b[bn]);ma.inline={start,ae};mb.inline={start,be}
          end
          row(an and a[an] or '╱',bn and b[bn] or '╱',ma,mb)
        end
        ai=sa+ca;bi=sb+cb
      end
      same(#a+1)
      if #a==0 and #b==0 then row('  Empty file','  Empty file',{file=file},{file=file}) end
    end
    file.finish=#out.left
    row('','')
    ::continue::
  end
  return out
end

function M.number()
  local s=M.state;if not s then return '' end
  local pane=api.nvim_get_current_buf()==s.buffers[1] and 1 or 2
  local item=s.data.rows[pane][vim.v.lnum]
  return string.format('%5s',item and item.line or '')
end
function M.foldtext()
  local s=M.state;if not s then return '' end
  local item=s.data.rows[1][vim.v.foldstart]
  if item and item.header then return (heading(item.header,api.nvim_win_get_width(0)-9,true)) end
  return ('  ⋯ %d unchanged lines'):format(vim.v.foldend-vim.v.foldstart+1)
end
function M.headers()
  local s=M.state;if not s then return end
  s.header_width=s.header_width or {}
  for pane,win in ipairs({s.left,s.right}) do if valid(win) and s.buffers[pane] then
    local width=api.nvim_win_get_width(win)-9 -- line numbers, fold column, ruler
    if s.header_width[pane]~=width then
      s.header_width[pane]=width;local buf=s.buffers[pane]
      vim.bo[buf].modifiable=true
      for _,file in ipairs(s.data.files) do
        local text,buttons=heading(file,width,false)
        file.buttons=file.buttons or {};file.buttons[pane]=buttons
        api.nvim_buf_set_lines(buf,file.header-1,file.header,false,{text})
      end
      api.nvim_buf_clear_namespace(buf,header_ns,0,-1)
      for _,file in ipairs(s.data.files) do api.nvim_buf_set_extmark(buf,header_ns,file.header-1,0,{line_hl_group='ReviewFileHeader',priority=110}) end
      vim.bo[buf].modifiable=false;vim.bo[buf].modified=false
    end
  end end
end
local function selected(row)
  local s=M.state;if not s then return end
  row=row or api.nvim_win_get_cursor(0)[1]
  return s.data.rows[1][row] and (s.data.rows[1][row].header or s.data.rows[1][row].file)
end
function M.file_action(action,file)
  local s=M.state;file=file or selected();if not s or not file then return end
  if action=='stage' then require('scm').stage({root=s.root,file=file.file,staged=s.staged},not s.staged)
  elseif action=='open' then
    local path=s.root..'/'..file.path;local row=api.nvim_win_get_cursor(0)[1]
    local pane=api.nvim_get_current_buf()==s.buffers[1] and 1 or 2
    local line=(s.data.rows[pane][row] or {}).line or 1
    if vim.fn.filereadable(path)~=1 then
      require('git_diff').working(s.root,file.file,s.staged);return
    end
    M.close();require('workbench').open_file(path,line,0)
  elseif action=='diff' then require('git_diff').working(s.root,file.file,s.staged)
  elseif action=='fold' then
    for _,win in ipairs({s.left,s.right}) do api.nvim_win_call(win,function()
      api.nvim_win_set_cursor(win,{file.header,0})
      if vim.fn.foldclosed(file.header)==file.header then vim.cmd('normal! zo')
      else vim.cmd(file.header..','..file.finish..'fold') end
    end) end
  end
end
function M.jump(direction)
  local s=M.state;if not s then return end
  local row=api.nvim_win_get_cursor(0)[1];local target
  if direction>0 then for _,file in ipairs(s.data.files) do if file.header>row then target=file.header;break end end
  else for i=#s.data.files,1,-1 do if s.data.files[i].header<row then target=s.data.files[i].header;break end end end
  if target then for _,win in ipairs({s.left,s.right}) do api.nvim_win_set_cursor(win,{target,0});api.nvim_win_call(win,function() vim.cmd('normal! zt') end) end end
end
function M.click(index,_,button)
  if button~='l' then return end
  vim.schedule(function()
    local s=M.state;if not s then return end
    if index==1 then M.jump(-1) elseif index==2 then M.jump(1)
    elseif index==3 then M.open(s.root,s.staged) else M.close() end
  end)
end
function M.mouse(mouse)
  local s=M.state;if not s or (mouse.winid~=s.left and mouse.winid~=s.right) or mouse.line<1 or mouse.column<1 then return false end
  local item=s.data.rows[1][mouse.line];if not item or not item.header then return false end
  local pane=mouse.winid==s.left and 1 or 2
  local buttons=item.header.buttons and item.header.buttons[pane]
  if not buttons then return false end
  local action=mouse.column>=buttons.open and 'open' or mouse.column>=buttons.stage and 'stage' or 'fold'
  vim.schedule(function() if M.state==s and valid(mouse.winid) then api.nvim_set_current_win(mouse.winid);M.file_action(action,item.header) end end)
  return true
end

local function display(root,staged,entries,generation)
  if M.generation~=generation then return end
  local focused=api.nvim_get_current_win()
  local keep_focus=vim.bo.filetype=='workbench_commit'
  local data=build(entries)
  if #data.left>20000 then vim.notify('Combined review exceeds 20,000 rows. Review a smaller set with individual file diffs.',vim.log.levels.WARN);return end
  if not M.active() then
    require('git_review').close();require('replace_review').close();require('repo_panel').hide_lazygit()
    -- Closing another review can advance this module's cancellation token.
    M.generation=generation
    local w=require('workbench');w.focus_editor();local left=w.main()
    local options={};for _,name in ipairs(option_names) do options[name]=vim.wo[left][name] end
    M.state={left=left,original=api.nvim_win_get_buf(left),cursor=api.nvim_win_get_cursor(left),options=options,buffers={}}
    api.nvim_set_current_win(left);vim.cmd('rightbelow vsplit');M.state.right=api.nvim_get_current_win()
    local width=api.nvim_win_get_width(left)+api.nvim_win_get_width(M.state.right)
    api.nvim_win_set_width(M.state.right,math.floor(width/2))
  end
  local s=M.state;local old=s.buffers;s.data=data;s.root=root;s.staged=staged;s.buffers={}
  s.header_width={}
  local syntax
  for _,entry in ipairs(entries) do local ft=vim.filetype.match({filename=entry.file.path});if syntax==nil then syntax=ft or false elseif syntax~=ft then syntax=false end end
  for pane,win in ipairs({s.left,s.right}) do
    require('diff_ui').detach(win)
    local buf=api.nvim_create_buf(false,true);s.buffers[pane]=buf
    api.nvim_buf_set_name(buf,'vimdesk-changes://'..buf..'/'..(pane==1 and 'Before' or 'After'))
    api.nvim_buf_set_lines(buf,0,-1,false,pane==1 and data.left or data.right)
    vim.bo[buf].bufhidden='hide';vim.bo[buf].swapfile=false;vim.bo[buf].filetype='workbench_changes'
    if syntax then vim.bo[buf].syntax=syntax end
    vim.bo[buf].modifiable=false;vim.bo[buf].modified=false
    api.nvim_win_set_buf(win,buf)
    for _,item in ipairs({{'wrap',false},{'scrollbind',true},{'cursorbind',true},{'foldmethod','manual'},
      {'foldenable',true},{'foldlevel',0},{'foldtext','v:lua.GitChanges.foldtext()'},{'foldcolumn','1'},
      {'number',true},{'relativenumber',false},{'signcolumn','no'},
      {'statuscolumn','%C%{v:lua.GitChanges.number()} '}}) do vim.wo[win][item[1]]=item[2] end
    local role=pane==1 and 'Before' or 'After'
    vim.wo[win].winbar='%#Review'..role..'# '..role..' %#ReviewPath# %<Git: '..(staged and 'Staged' or 'Changes')..' ('..#entries..' files)'
      ..(pane==1 and ' · '..escape(vim.fs.basename(root)) or '%= %1@v:lua.GitChanges.click@[↑]%T %2@v:lua.GitChanges.click@[↓]%T %3@v:lua.GitChanges.click@[↻]%T %4@v:lua.GitChanges.click@[×]%T ')
    for row,item in ipairs(data.rows[pane]) do
      local group=item.header and 'ReviewFileHeader' or item.filler and 'ReviewFiller' or item.kind and ('Review'..role..'Line')
      if group then api.nvim_buf_set_extmark(buf,item.header and header_ns or ns,row-1,0,{line_hl_group=group,priority=110}) end
      if item.inline and item.inline[2]>item.inline[1] then api.nvim_buf_set_extmark(buf,ns,row-1,item.inline[1],{end_col=item.inline[2],hl_group='Review'..role..'Text',priority=120}) end
    end
    api.nvim_win_call(win,function()
      vim.cmd('normal! zE')
      for _,fold in ipairs(data.folds) do vim.cmd(fold[1]..','..fold[2]..'fold') end
      vim.cmd('normal! ggzt')
    end)
    require('diff_ui').attach(win,{role=role,rows=data.rows[pane]})
    for key,action in pairs({['<CR>']='diff',o='open',['+']='stage',za='fold'}) do
      vim.keymap.set('n',key,function() M.file_action(action) end,{buffer=buf,desc='Changes: '..action})
    end
    vim.keymap.set('n',']f',function() M.jump(1) end,{buffer=buf})
    vim.keymap.set('n','[f',function() M.jump(-1) end,{buffer=buf})
    vim.keymap.set('n','q',M.close,{buffer=buf})
  end
  M.headers()
  for _,buf in ipairs(old) do if api.nvim_buf_is_valid(buf) then pcall(api.nvim_buf_delete,buf,{force=true}) end end
  require('workbench').editor=s.right
  if keep_focus and valid(focused) then api.nvim_set_current_win(focused) else api.nvim_set_current_win(s.right) end
end

function M.open(root,staged,expanded)
  if not root then return end
  M.generation=M.generation+1;local generation=M.generation
  local files=expanded or {};for _,file in ipairs(expanded and {} or (require('repo_panel').state().info[root] or {}).files or {}) do
    if not file.conflict and file[staged and 'staged' or 'changed'] then files[#files+1]=vim.deepcopy(file) end
  end
  local directories={};for _,file in ipairs(files) do if file.untracked and file.path:sub(-1)=='/' then directories[#directories+1]=file.path end end
  if #directories>0 then
    local cmd={'git','--literal-pathspecs','-C',root,'ls-files','--others','--exclude-standard','-z','--'};vim.list_extend(cmd,directories)
    vim.system(cmd,{text=false,timeout=10000},function(result)
      vim.schedule(function()
        if generation~=M.generation then return end
        if result.code~=0 then vim.notify('Could not list untracked files.',vim.log.levels.WARN);return end
        local list={};for _,file in ipairs(files) do if not (file.untracked and file.path:sub(-1)=='/') then list[#list+1]=file end end
        for path in (result.stdout or ''):gmatch('([^%z]+)%z') do
          if #list<101 then list[#list+1]={path=path,untracked=true,changed=true,x='?',y='?'} end
        end
        M.open(root,staged,list)
      end)
    end)
    return
  end
  if #files==0 then if M.active() then M.close() end;vim.notify('No '..(staged and 'staged' or 'working')..' changes.');return end
  if #files>100 then vim.notify('Showing the first 100 changed files. Use individual diffs for the remaining files.');while #files>100 do table.remove(files) end end
  local entries={};local next_item,running,done,total=1,0,0,0
  local pump
  local function blob(spec,optional,callback)
    vim.system({'git','-C',root,'cat-file','-s',spec},{text=true,timeout=10000},function(size)
      vim.schedule(function()
        if generation~=M.generation then return end
        if size.code~=0 then callback(optional and '' or nil,optional and nil or 'Could not read Git snapshot');return end
        if (tonumber(size.stdout) or math.huge)>2*1024*1024 then callback(nil,'File exceeds 2 MB · Open individually');return end
        vim.system({'git','-C',root,'cat-file','blob',spec},{text=false,timeout=10000},function(result)
          vim.schedule(function() if generation==M.generation then callback(result.code==0 and result.stdout or nil,'Could not read Git snapshot') end end)
        end)
      end)
    end)
  end
  pump=function()
    while running<3 and next_item<=#files do
      local i=next_item;local file=files[i];next_item=next_item+1;running=running+1
      local entry={file=file,staged=staged};entries[i]=entry
      local function finish(before,after,err)
        entry.before,entry.after=before,after
        if not before or not after then entry.error=err or 'Cannot review this file'
        elseif before:find('\0',1,true) or after:find('\0',1,true) then entry.error='Binary file · Open individually'
        elseif total+#before+#after>4*1024*1024 then entry.error='Combined review reached 4 MB · Open individually'
        else total=total+#before+#after end
        if entry.error then entry.before=nil;entry.after=nil end
        running=running-1;done=done+1
        if done==#files then display(root,staged,entries,generation) else pump() end
      end
      local spec=(staged and 'HEAD:' or ':')..(staged and file.old or file.path)
      blob(spec,file.untracked or staged and file.x=='A',function(before,err)
        if not before then finish(nil,nil,err);return end
        if staged then blob(':'..file.path,file.x=='D',function(after,error) finish(before,after,error) end)
        else
          local path=root..'/'..file.path;local stat=uv.fs_lstat(path)
          if stat and stat.type=='link' then finish(before,uv.fs_readlink(path));return end
          if stat and (stat.type~='file' or stat.size>2*1024*1024) then finish(nil,nil,'Directory or file over 2 MB · Open individually');return end
          local buf=vim.fn.bufnr(path)
          if buf>0 and api.nvim_buf_is_loaded(buf) and (stat or vim.bo[buf].modified) then finish(before,table.concat(api.nvim_buf_get_lines(buf,0,-1,false),'\n')..(vim.bo[buf].endofline and '\n' or ''))
          elseif not stat then finish(before,'')
          else
            local fd=uv.fs_open(path,'r',438)
            local text=fd and uv.fs_read(fd,stat.size,0);if fd then uv.fs_close(fd) end
            finish(before,text,text and nil or 'Could not read working file')
          end
        end
      end)
    end
  end
  pump()
end
function M.refresh(root)
  if M.active() and M.state.root==root then M.open(root,M.state.staged) end
end
_G.GitChanges=M
api.nvim_create_autocmd('WinClosed',{group=api.nvim_create_augroup('VimDeskChangesLifecycle',{clear=true}),callback=function(ev)
  local s=M.state;local win=tonumber(ev.match)
  if s and (s.left==win or s.right==win) then vim.schedule(function()
    if M.state==s and (not valid(s.left) or not valid(s.right)) then M.close() end
  end) end
end})
api.nvim_create_autocmd('WinResized',{group='VimDeskChangesLifecycle',callback=M.headers})
return M
