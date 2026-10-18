local M={}
local api=vim.api
local function patterns(value)
  local ret={};for p in (value or ''):gmatch('[^;]+') do p=vim.trim(p);if p~='' then ret[#ret+1]=p end end;return ret
end
function M.file_args(opts)
  local args={'--glob=!.git/**','--glob=!**/.git/**'}
  if opts.ignored then args[#args+1]='--no-ignore' end
  if opts.hidden then args[#args+1]='--hidden' end
  for _,p in ipairs(patterns(opts.include)) do vim.list_extend(args,{'--glob',p}) end
  for _,p in ipairs(patterns(opts.exclude)) do vim.list_extend(args,{'--glob','!'..p}) end
  return args
end
function M.query_args(opts)
  local args={'rg','--json','--line-number','--color=never','--no-config','--encoding=utf-8'}
  if not opts.case then args[#args+1]='--ignore-case' end
  if opts.word then args[#args+1]='--word-regexp' end
  if not opts.regex then args[#args+1]='--fixed-strings' end
  return args
end
function M.run(opts,done)
  local token={jobs={},cancelled=false,bytes=0,truncated=false}
  function token.cancel()
    token.cancelled=true;for _,job in ipairs(token.jobs) do pcall(function() job:kill(15) end) end
  end
  local function run(args,input,callback)
    local chunks,job={},nil
    job=vim.system(args,{cwd=opts.root,text=true,stdin=input,timeout=15000,stdout=function(_,data)
      if data and not token.truncated and not token.cancelled then
        token.bytes=token.bytes+#data
        if token.bytes>5*1024*1024 then token.truncated=true;if job then job:kill(15) end
        else chunks[#chunks+1]=data end
      end
    end},function(result) vim.schedule(function()
      if not token.cancelled then callback(result,table.concat(chunks)) end
    end) end)
    token.jobs[#token.jobs+1]=job
  end
  local results,error_text={},nil
  local function parse(text,buf,path)
    for line in text:gmatch('[^\n]+') do
      local ok,record=pcall(vim.json.decode,line)
      if ok and record.type=='match' and record.data.path.text and record.data.lines.text then
        local d=record.data
        if #results>=6000 then token.truncated=true;break end
        results[#results+1]={path=path or d.path.text:gsub('^%./',''),line=d.line_number,
          col=d.submatches[1] and d.submatches[1].start or 0,text=d.lines.text,matches=d.submatches,buf=buf}
      end
    end
  end
  local function finish()
    table.sort(results,function(a,b) return a.path==b.path and a.line<b.line or a.path<b.path end)
    if #results>1500 then token.truncated=true;for i=#results,1501,-1 do results[i]=nil end end
    token.jobs={}
    done({results=results,truncated=token.truncated,error=error_text})
  end
  local function check(result)
    if result.code>1 and not token.truncated then error_text=vim.trim(result.stderr or 'Search failed') end
  end
  local args=M.query_args(opts);vim.list_extend(args,M.file_args(opts));vim.list_extend(args,{'--',opts.query,'.'})
  run(args,nil,function(result,text)
    check(result);parse(text)
    local candidates={}
    for _,buf in ipairs(api.nvim_list_bufs()) do
      if api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype=='' and vim.bo[buf].modified then
        local name=api.nvim_buf_get_name(buf);local path=vim.fs.relpath(opts.root,name)
        if path and path~='' and path~='.' and not path:match('^%.%./') then
          candidates[#candidates+1]={buf=buf,path=path,content=table.concat(api.nvim_buf_get_lines(buf,0,-1,false),'\n')..(vim.bo[buf].endofline and '\n' or '')}
        end
      end
    end
    if error_text or token.truncated or (#candidates==0 and opts.include=='') then finish();return end
    local function overlay(eligible)
      local queue,override={},{}
      for _,candidate in ipairs(candidates) do if eligible[candidate.path] then
        queue[#queue+1]=candidate;override[candidate.path]=true
      end end
      results=vim.tbl_filter(function(m) return eligible[m.path] and not override[m.path] end,results)
      local next_index,running,completed=1,0,0
      local pump
      pump=function()
        while running<3 and next_index<=#queue do
          local candidate=queue[next_index];next_index=next_index+1;running=running+1
          local command=M.query_args(opts);vim.list_extend(command,{'--',opts.query,'-'})
          run(command,candidate.content,function(r,t)
            check(r);parse(t,candidate.buf,candidate.path);running=running-1;completed=completed+1
            if completed==#queue then finish() else pump() end
          end)
        end
        if #queue==0 then finish() end
      end
      pump()
    end
    local files={'rg','--files','--null','--no-config'};vim.list_extend(files,M.file_args(opts));files[#files+1]='.'
    run(files,nil,function(file_result,file_text)
      check(file_result);local eligible={}
      for path in file_text:gmatch('[^%z]+') do eligible[path:gsub('^%./','')]=true end
      if opts.include~='' and not opts.ignored then
        -- Positive rg globs override ignore rules. Intersect with the normal
        -- file list so the UI's Include gitignored toggle stays authoritative.
        local baseline=vim.tbl_extend('force',opts,{include=''})
        local command={'rg','--files','--null','--no-config'};vim.list_extend(command,M.file_args(baseline));command[#command+1]='.'
        run(command,nil,function(base_result,base_text)
          check(base_result);local allowed={}
          for path in base_text:gmatch('[^%z]+') do path=path:gsub('^%./','');if eligible[path] then allowed[path]=true end end
          overlay(allowed)
        end)
      else overlay(eligible) end
    end)
  end)
  return token
end
return M
