"""Real UI checks for preview lifetime, Open Editors, toolbar, sessions and Light mode.

Only disposable sibling repositories and isolated Neovim state are modified.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from ui_grid import UIGrid
from ui_process import attach_child, close_child

ROOT=Path(__file__).resolve().parents[1]
cli=argparse.ArgumentParser(description=__doc__)
cli.add_argument('--source',type=Path,default=ROOT/'config/nvim')
cli.add_argument('--plugins-dir',type=Path,required=True)
cli.add_argument('--report',type=Path,required=True)
cli.add_argument('--screenshots',type=Path)
cli.add_argument('--font',type=Path)
args=cli.parse_args()
fixture=Path(tempfile.mkdtemp(prefix='vimdesk-navigation-')).resolve()
workspace=fixture/'Workspace';workspace.mkdir()
for name in ['backend','frontend','worker']:
    repo=workspace/name;repo.mkdir();(repo/'src').mkdir()
    (repo/'entry.txt').write_text('Original\n')
    for i in range(140): (repo/'src'/f'file-{i:03d}.txt').write_text('Fixture text\n'*256)
    for command in [('init','-q','-b','main'),('config','user.name','UI Test'),('config','user.email','ui@example.invalid'),('add','.'),('commit','-qm','fixture')]:
        subprocess.run(['git','-C',str(repo),*command],check=True,capture_output=True)
for kind in ['config','data','state','cache']:
    (fixture/kind).mkdir();os.environ['XDG_'+kind.upper()+'_HOME']=str(fixture/kind)
os.environ['NVIM_APPNAME']='nvim'
shutil.copytree(args.source,fixture/'config/nvim')
(fixture/'data/nvim').mkdir();(fixture/'data/nvim/lazy').symlink_to(args.plugins_dir.resolve())
(fixture/'work').mkdir();(fixture/'work/vscode-deps').symlink_to(args.plugins_dir.resolve());(fixture/'work/vscode-config').symlink_to(fixture/'config/nvim')
nvim=None;checks=[]
def start():
    global nvim,ui
    nvim=attach_child(['nvim','--embed','-n','-i','NONE','--cmd',
      'let g:workbench_test='+json.dumps(str(fixture))+' | let g:workbench_disable_startup=1',str(workspace/'backend/entry.txt')],timeout=100)
    ui=UIGrid(nvim,150,44);nvim.ui_attach(150,44,rgb=True,ext_linegrid=True);ui.drain(650)
    nvim.command('cd '+nvim.funcs.fnameescape(str(workspace)))
    nvim.exec_lua('''_G.nav_errors={};local notify=vim.notify;vim.notify=function(msg,level,opts)
      if level==vim.log.levels.ERROR then nav_errors[#nav_errors+1]=tostring(msg) end;return notify(msg,level,opts) end
      _G.explorer=function() return require('workbench').explorer_picker() end
      require('workbench').sidebar('explorer',true)''')
    wait('explorer() and explorer().list.win:valid() and require("explorer_panel").win~=nil')
def wait(expr,seconds=8):
    deadline=time.monotonic()+seconds
    while not nvim.exec_lua('return '+expr):
        assert time.monotonic()<deadline,expr+'\n'+nvim.command_output('messages')
        ui.drain(30)
def passed(label): checks.append(label);print('PASS '+label,flush=True)
def target(path):
    nvim.exec_lua('local p=explorer();require("snacks.explorer.actions").update(p,{target=...,refresh=true});p:focus("list")',str(path))
    wait('explorer():current() and explorer():current().file=='+json.dumps(str(path)))
    ui.drain(40)
def click_file(path,double=False):
    target(path)
    pos=nvim.exec_lua('local p=explorer();return vim.fn.screenpos(p.list.win.win,p.list:idx2row(p.list.cursor),8)')
    for action in ['press','release']: nvim.api.input_mouse('left',action,'2' if double else '',0,pos['row']-1,pos['col']-1)
    ui.drain(120)
def toolbar(token):
    icons={'[New File]':'\uea7f','[New Folder]':'\uea80','[More]':'\uea7c','[Collapse]':'\ueac5','[Reveal]':'\uebF8','[Paste]':'\ueac0'}
    win=nvim.exec_lua('return require("explorer_panel").win');row=nvim.exec_lua('return require("explorer_panel").toolbar_row');line=nvim.api.buf_get_lines(nvim.api.win_get_buf(win),row-1,row,False)[0]
    col=len(line[:line.index(icons[token])].encode())+1
    pos=nvim.funcs.screenpos(win,row,col)
    for action in ['press','release']: nvim.api.input_mouse('left',action,'',0,pos['row']-1,pos['col']-1)
    ui.drain(100)
try:
    start();side=nvim.exec_lua('return require("workbench").side_win()');width=nvim.api.win_get_width(side)
    first=workspace/'backend/src/file-001.txt';second=workspace/'frontend/src/file-002.txt'
    click_file(first);buf1=nvim.funcs.bufnr('%')
    assert nvim.exec_lua('return require("file_preview").buf')==buf1
    click_file(second);buf2=nvim.funcs.bufnr('%')
    assert not nvim.api.buf_is_valid(buf1) and nvim.api.buf_is_valid(buf2)
    assert nvim.exec_lua('return require("file_preview").buf')==buf2
    passed('single-click replaces one unedited preview buffer')
    click_file(second,double=True)
    assert not nvim.exec_lua('return vim.b[...].workbench_preview',buf2)
    click_file(first);assert nvim.api.buf_is_valid(buf2)
    edited=nvim.funcs.bufnr('%');nvim.api.buf_set_lines(edited,0,1,False,['UNSAVED preview edit']);ui.drain(120)
    click_file(workspace/'worker/src/file-003.txt')
    assert nvim.api.buf_is_valid(edited) and nvim.api.buf_get_lines(edited,0,1,False)==['UNSAVED preview edit']
    passed('double-click keeps tabs and edited previews are never discarded')
    current=nvim.funcs.bufnr('%');nvim.command('rightbelow vsplit');other=nvim.api.get_current_win()
    click_file(workspace/'worker/src/file-004.txt')
    assert nvim.api.buf_is_valid(current),'preview visible in another split was discarded'
    nvim.api.win_close(other,True)
    passed('preview visible in another split is retained')
    # Keyboard confirmation is permanent, including in the filter input.
    path=workspace/'frontend/src/file-005.txt';target(path);nvim.input('<CR>');ui.drain(150)
    permanent=nvim.funcs.bufnr(str(path))
    assert permanent>0 and not nvim.exec_lua('return vim.b[...].workbench_preview',permanent)
    passed('Enter opens a permanent file')
    click_file(workspace/'backend/src/file-006.txt');preview=nvim.funcs.bufnr('%')
    target(workspace/'backend/src/file-006.txt');nvim.input('<CR>');ui.drain(120)
    assert not nvim.exec_lua('return vim.b[...].workbench_preview',preview)
    passed('Enter pins an existing preview')
    # Return to the intended parent for toolbar file/folder checks.
    target(path)
    toolbar('[New Folder]');wait('vim.bo.filetype=="snacks_input"')
    nvim.api.buf_set_lines(0,0,-1,False,['new folder']);nvim.input('<CR>');ui.drain(150)
    assert (path.parent/'new folder').is_dir()
    toolbar('[New File]');wait('vim.bo.filetype=="snacks_input"')
    nvim.api.buf_set_lines(0,0,-1,False,['inside.txt']);nvim.input('<CR>');ui.drain(150)
    assert (path.parent/'new folder/inside.txt').is_file()
    passed('separate clickable New File and New Folder controls')
    toolbar('[Collapse]');ui.drain(120)
    assert nvim.exec_lua('return explorer().list:count()')<=4
    active_path=nvim.exec_lua('return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(require("workbench").main()))')
    toolbar('[Reveal]');wait('explorer():current() and explorer():current().file=='+json.dumps(active_path))
    passed('Collapse All and Reveal Active File')
    # Open Editors is capped on screen, reuses existing buffers, and shows dirty state.
    assert edited in nvim.exec_lua('return require("explorer_panel").editors()')
    assert any('●' in line for line in nvim.exec_lua('return require("explorer_panel").lines'))
    assert nvim.exec_lua('return require("explorer_panel").height')<=11
    geometry=nvim.exec_lua('''local h=require('explorer_panel');local p=explorer();return {
      header=vim.api.nvim_win_get_position(h.win),height=vim.api.nvim_win_get_height(h.win),
      input=vim.api.nvim_win_get_position(p.input.win.win),root=vim.api.nvim_win_get_position(p.layout.root.win)}''')
    assert geometry['root'][0]>=geometry['header'][0]+geometry['height'],geometry
    header=nvim.exec_lua('return require("explorer_panel").win');hp=nvim.api.win_get_position(header)
    for _ in range(20):nvim.api.input_mouse('wheel','down','',0,hp[0]+3,hp[1]+6)
    ui.drain(80)
    assert nvim.funcs.line('w0',header)==1,'Open Editors toolbar scrolled out of view'
    nvim.exec_lua('require("explorer_panel").render()')
    close_target=nvim.exec_lua('local h=require("explorer_panel");for row,buf in pairs(h.rows) do if not vim.bo[buf].modified then return {row,buf} end end')
    assert close_target,'No clean editor available for the close-button test'
    header_row,clean=close_target
    for action in ['press','release']:nvim.api.input_mouse('left',action,'',0,hp[0]+header_row-1,hp[1]+width-2)
    ui.drain(120);assert nvim.exec_lua('return not vim.api.nvim_buf_is_valid(...) or not vim.bo[...].buflisted',clean),'Open Editors close button did not close a clean buffer'
    passed('bounded Open Editors list includes modified buffers')
    # Cycling 100 unopened files must retain at most one preview.
    nvim.exec_lua('''_G.preview_bytes=function() local bytes=0;for _,b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted and vim.bo[b].buftype=='' then bytes=bytes+vim.api.nvim_buf_get_offset(b,vim.api.nvim_buf_line_count(b)) end
      end;return bytes end''')
    before=nvim.exec_lua('return #require("explorer_panel").editors()');before_bytes=nvim.exec_lua('return preview_bytes()')
    nvim.exec_lua('''for i=20,119 do require('file_preview').open(string.format('%s/worker/src/file-%03d.txt',...,i),false) end''',str(workspace))
    ui.drain(200)
    after=nvim.exec_lua('return #require("explorer_panel").editors()')
    assert after<=before+1,(before,after)
    after_bytes=nvim.exec_lua('return preview_bytes()');assert after_bytes<=before_bytes+4096,(before_bytes,after_bytes)
    passed('100 preview opens retain at most one additional listed file')
    # Same-process switches and restart preserve explicit explorer/filter state.
    target(workspace/'frontend/src/file-090.txt')
    nvim.exec_lua('explorer().list:scroll(40,true)');ui.drain(100)
    snapshot=nvim.exec_lua('require("workspace_state").capture(explorer());return require("workspace_state").explorers[vim.fn.getcwd(-1,0)]')
    for mode in ['git','search','explorer']:
        nvim.exec_lua('require("workbench").sidebar(...,true)',mode);ui.drain(160)
        assert nvim.exec_lua('return require("workbench").side_win()')==side
        assert nvim.api.win_get_width(side)==width
    wait('not explorer().finder:running()')
    assert nvim.exec_lua('return explorer():current().file')==snapshot['target']
    assert nvim.exec_lua('return explorer().list:get(explorer().list.top).file')==snapshot['top']
    passed('stable width, tree selection and scroll through Files/Search/Git')
    nvim.exec_lua('local node=require("snacks.explorer.tree"):find(...);node.status=" M";node.severity=1',str(workspace/'frontend/src/file-090.txt'))
    nvim.input(' up');ui.drain(180);wait('explorer() and not explorer().finder:running()')
    assert nvim.exec_lua('return require("performance").enabled()')
    assert nvim.exec_lua('local o=explorer().opts;return not o.watch and not o.diagnostics and not o.git_status and not o.icons.files.enabled')
    assert nvim.exec_lua('for item in explorer():iter() do if item.status or item.severity then return false end end;return true'),'Light mode retained cached badges'
    ui.drain(100)
    assert nvim.exec_lua('return vim.tbl_count(require("snacks.explorer.watch")._watches)')==0
    nvim.input(' up');ui.drain(180);wait('explorer() and not explorer().finder:running()')
    assert nvim.exec_lua('local o=explorer().opts;return o.watch and o.diagnostics and o.git_status and o.icons.files.enabled')
    passed('Light toggle releases watchers, disables decorations, restores normal options')
    nvim.exec_lua('''require('workbench').sidebar('search',false)
      require('workspace_state').restore_search({query='restored query',replacement='text',include='*.txt',exclude='',scope='all'})''')
    generation=nvim.exec_lua('return require("workspace_search").generation');ui.drain(450)
    assert nvim.exec_lua('return require("workspace_search").generation')==generation
    assert nvim.exec_lua('local s=require("workspace_search");return not s.running and s.job==nil')
    nvim.exec_lua('require("workbench").sidebar("explorer",true)');ui.drain(150)
    passed('restoring search fields does not start an automatic search')
    nvim.exec_lua('''local s=require('workspace_search');s.query='fixture';s.replacement='replacement';s.include='*.txt';s.exclude='vendor/**';s.regex=true;s.scope='repo';s.filters=true
      local r=require('repo_panel').state();r.active=...;r.drafts[r.active]='feat: saved draft'
      require('search_box').sync();explorer().input:set('file-09','');explorer():find()''',str(workspace/'frontend'))
    ui.drain(180);wait('not explorer().finder:running()')
    # Clear only our deliberately modified fixture before requesting a session restore.
    nvim.api.set_option_value('modified',False,{'buf':edited})
    nvim.exec_lua('require("workbench").save_session()');ui.drain(200)
    saved_tree=nvim.exec_lua('return require("workspace_state").explorers[vim.fn.getcwd(-1,0)]')
    assert nvim.exec_lua('return vim.fn.filereadable(require("persistence").current())')==1
    if args.screenshots:
        args.screenshots.mkdir(parents=True,exist_ok=True);ui.save(args.screenshots/'navigation.png',args.font)
    errors=nvim.exec_lua('return nav_errors');assert errors==[],errors
    close_child(nvim);nvim=None
    start();nvim.exec_lua('require("workbench").restore_session()');ui.drain(500)
    wait('explorer() and not explorer().finder:running()')
    restored=nvim.exec_lua('''local s=require('workspace_search');local r=require('repo_panel').state();return {
      query=s.query,replacement=s.replacement,include=s.include,exclude=s.exclude,regex=s.regex,scope=s.scope,
      active=r.active,draft=r.drafts[r.active],pattern=explorer().input.filter.pattern}''')
    assert restored=={'query':'fixture','replacement':'replacement','include':'*.txt','exclude':'vendor/**','regex':True,'scope':'repo',
      'active':str(workspace/'frontend'),'draft':'feat: saved draft','pattern':'file-09'},restored
    assert nvim.exec_lua('return explorer():current().file')==saved_tree['target']
    assert nvim.exec_lua('return explorer().list:get(explorer().list.top).file')==saved_tree['top']
    passed('session restart restores repo, draft, search options and explorer filter')
    assert nvim.exec_lua('return nav_errors')==[],nvim.exec_lua('return nav_errors')
    args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps({'passed':checks,'errors':[],
      'preview_stress':{'opens':100,'before_listed_files':before,'after_listed_files':after,
      'before_loaded_file_bytes':before_bytes,'after_loaded_file_bytes':after_bytes}},indent=2))
finally:
    if nvim is not None: close_child(nvim)
    shutil.rmtree(fixture)
