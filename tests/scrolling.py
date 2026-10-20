"""Real UI regression: bounded sidebar scrolling, anchored inputs, and isolated redraws.

Requires pynvim. Reuses existing plugins without installing or updating them.
Example: python tests/scrolling.py --plugins-dir ~/.local/share/nvim/lazy
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
from ui_grid import UIGrid

import threading
import pynvim


def attach_child(argv, timeout=90):
    nvim = pynvim.attach('child', argv=argv)
    loop = nvim._session._async_session._msgpack_stream.loop
    process = next((transport.get_extra_info('subprocess')
                    for transport in loop._to_close
                    if transport.get_extra_info('subprocess') is not None), None)
    if process is None:
        nvim.close()
        raise RuntimeError('Cannot establish ownership of the test child process')
    expired = threading.Event()

    def watchdog():
        if process.poll() is None:
            expired.set()
            try:
                process.kill()
            except ProcessLookupError:
                pass

    timer = threading.Timer(timeout, watchdog)
    timer.daemon = True
    timer.start()
    nvim._test_process = (process, timer, expired)
    return nvim


def close_child(nvim):
    process, timer, expired = nvim._test_process
    try:
        if process.poll() is None:
            try:
                nvim.command('qa!', async_=True)
            except (EOFError, OSError):
                pass
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.terminate()
                try:
                    process.wait(timeout=0.5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
    finally:
        timer.cancel()
        nvim.close()
    if expired.is_set():
        raise TimeoutError('Neovim UI test timed out; its owned child was killed')


parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, default=ROOT / 'config/nvim')
parser.add_argument('--label', default='scrolling')
parser.add_argument('--plugins-dir', type=Path, required=True, help='existing plugin directory, used read-only')
parser.add_argument('--nvim', default='nvim')
parser.add_argument('--report', type=Path)
args = parser.parse_args()
if not (args.plugins_dir/'snacks.nvim').is_dir() or not (args.plugins_dir/'lazy.nvim').is_dir():
    parser.error('--plugins-dir must contain the installed Snacks and lazy.nvim plugins')
fixture = Path(tempfile.mkdtemp(prefix='vimdesk-switch-')).resolve()
parent = fixture / 'Workspace'
parent.mkdir()
(parent/'large.txt').write_text(''.join(f'line {i}\n' for i in range(1200)))
for name in ['repo-%02d'%i for i in range(17)]:
    repo = parent / name
    repo.mkdir()
    (repo / 'note.txt').write_text('Review the sidebar\n')
    if name=='repo-00':
        for i in range(90): (repo/f'file-{i:02d}.txt').write_text('Explorer fixture\n')
    for command in [('init', '-b', 'main'), ('config', 'user.name', 'Sidebar Test'),
                    ('config', 'user.email', 'sidebar@example.invalid'), ('add', '.'), ('commit', '-m', 'initial')]:
        subprocess.run(['git', '-C', str(repo), *command], check=True, capture_output=True)
    if name=='repo-00':
        for revision in range(35):
            (repo/'history.txt').write_text(str(revision)+'\n')
            subprocess.run(['git','-C',str(repo),'add','history.txt'],check=True,capture_output=True)
            subprocess.run(['git','-C',str(repo),'commit','-m',f'feat: history {revision}'],check=True,capture_output=True)
    (repo / 'note.txt').write_text('Review the sidebar changes\n')
for kind in ['config', 'data', 'state', 'cache']:
    (fixture / kind).mkdir()
    os.environ['XDG_' + kind.upper() + '_HOME'] = str(fixture / kind)
os.environ['NVIM_APPNAME'] = 'nvim'
shutil.copytree(args.source, fixture / 'config/nvim')
(fixture / 'data/nvim').mkdir()
(fixture / 'data/nvim/lazy').symlink_to(args.plugins_dir.expanduser().resolve())
# The personal config also supports its original test profile paths.
(fixture/'work').mkdir()
(fixture/'work/vscode-deps').symlink_to(args.plugins_dir.expanduser().resolve())
(fixture/'work/vscode-config').symlink_to(fixture/'config/nvim')
nvim = attach_child([args.nvim, '--embed', '-n', '-i', 'NONE',
    '--cmd', 'let g:workbench_test='+json.dumps(str(fixture))+' | let g:workbench_disable_startup=1', str(parent / 'repo-00/note.txt')], timeout=100)
try:
    ui = UIGrid(nvim, 150, 42)
    nvim.ui_attach(150, 42, rgb=True, ext_linegrid=True)
    ui.drain(700)
    nvim.command('cd ' + nvim.funcs.fnameescape(str(parent)))
    nvim.exec_lua('''_G.switch_trace={};_G.switch_errors={}; local api=vim.api
      local notify=vim.notify;vim.notify=function(msg,level,opts)
        if level==vim.log.levels.ERROR then table.insert(switch_errors,tostring(msg)) end
        return notify(msg,level,opts) end
      _G.side_snapshot=function()
        local w=require('workbench');local win=w.side_win();local normal={}
        for _,id in ipairs(api.nvim_tabpage_list_wins(0)) do if api.nvim_win_get_config(id).relative=='' then
          normal[#normal+1]={id=id,width=api.nvim_win_get_width(id),type=vim.bo[api.nvim_win_get_buf(id)].filetype} end end
        return {mode=w.mode,stored=w.width,side=win,width=win and api.nvim_win_get_width(win),normal=normal}
      end
      api.nvim_create_autocmd({'WinNew','WinClosed','WinResized'}, {callback=function(event)
        local ok,frame=pcall(side_snapshot);if ok then frame.event=event.event;switch_trace[#switch_trace+1]=frame end end})
    ''')
    nvim.exec_lua('require("workbench").sidebar("git",false)')
    ui.drain(1000)
    nvim.exec_lua("""_G.scroll_counts={config=0,clear=0,lines=0,render=0,scrolled=0,resized=0}
      for key,name in pairs({config='nvim_win_set_config',clear='nvim_buf_clear_namespace',lines='nvim_buf_set_lines'}) do
        local original=vim.api[name];vim.api[name]=function(...) scroll_counts[key]=scroll_counts[key]+1;return original(...) end
      end
      local list=require('repo_list');local original=list.render;list.render=function(...) scroll_counts.render=scroll_counts.render+1;return original(...) end
      vim.api.nvim_create_autocmd('WinScrolled',{callback=function() scroll_counts.scrolled=scroll_counts.scrolled+1 end})
      vim.api.nvim_create_autocmd('WinResized',{callback=function() scroll_counts.resized=scroll_counts.resized+1 end})
      _G.scroll_view=function()
        local w=require('workbench');local side=w.side_win();local box=require('commit_box');local a=vim.api
        local view=a.nvim_win_call(side,vim.fn.winsaveview)
        return {top=view.topline,lines=a.nvim_buf_line_count(w.side_buf),height=a.nvim_win_get_height(side),
          side=side,commit=box.win and a.nvim_win_is_valid(box.win) and a.nvim_win_get_config(box.win) or nil,
          position=box.win and a.nvim_win_is_valid(box.win) and a.nvim_win_get_position(box.win) or nil,side_position=a.nvim_win_get_position(side),message_row=box.row,search=require('search_box').fields}
      end
      _G.cpu=function() local r=vim.uv.getrusage();return r.utime.sec+r.utime.usec/1e6+r.stime.sec+r.stime.usec/1e6 end
    """)
    frames=[]
    nvim.exec_lua('local w=require("workbench");vim.api.nvim_set_current_win(w.side_win());vim.cmd("normal! ggzt")')
    ui.drain(100)
    start=nvim.exec_lua('return cpu()')
    for step in range(35):
        nvim.api.input_mouse('wheel','down','',0,10,20);ui.drain(15)
        frame=nvim.exec_lua('return scroll_view()');frame.pop('search',None);frames.append(frame)
    for step in range(35):
        nvim.api.input_mouse('wheel','up','',0,10,20);ui.drain(15)
        frame=nvim.exec_lua('return scroll_view()');frame.pop('search',None);frames.append(frame)
    cpu=nvim.exec_lua('return cpu()')-start
    counts=nvim.exec_lua('return scroll_counts')
    idle_before=nvim.exec_lua('return vim.deepcopy(scroll_counts)');ui.drain(500)
    idle_after=nvim.exec_lua('return scroll_counts')
    nvim.exec_lua('require("workbench").sidebar("search",true)');ui.drain(200)
    search=[]
    for _ in range(20):
        nvim.api.input_mouse('wheel','down','',0,20,20);ui.drain(10)
        frame=nvim.exec_lua('return scroll_view()');frame.pop('search',None);search.append(frame)
    # Scrolling the editor must not reposition or rewrite sidebar inputs.
    nvim.exec_lua('require("workbench").sidebar("git",false);require("workbench").open_file(...,1,0)',str(parent/'large.txt'))
    ui.drain(300)
    isolated_before=nvim.exec_lua('return vim.deepcopy(scroll_counts)')
    for _ in range(20):
        nvim.api.input_mouse('wheel','down','',0,12,90);ui.drain(10)
    isolated_after=nvim.exec_lua('return scroll_counts')
    nvim.exec_lua("""local w=require('workbench');local a=vim.api;local side=w.side_win();local v=a.nvim_win_call(side,vim.fn.winsaveview)
      v.topline=12;v.lnum=12;a.nvim_win_call(side,function() vim.fn.winrestview(v) end)""")
    ui.drain(80)
    nvim.exec_lua("""local box=require('commit_box');vim.api.nvim_buf_set_lines(box.field.buf,0,-1,false,{'feat: preserve scroll draft'});box.flush();box.focus(box.field.root)""")
    draft_before=nvim.exec_lua('return vim.deepcopy(scroll_counts)')
    draft_frames=[]
    for _ in range(6):
        f=nvim.exec_lua('return scroll_view()');f.pop('search',None)
        pos=f.get('position');c=f.get('commit')
        row=int(pos[0]+1) if pos and c and not c.get('hide',False) else 10
        nvim.api.input_mouse('wheel','down','',0,row,4);ui.drain(30)
        f=nvim.exec_lua('return scroll_view()');f.pop('search',None);draft_frames.append(f)
    draft=nvim.exec_lua('local box=require("commit_box");return {text=vim.api.nvim_buf_get_lines(box.field.buf,0,-1,false),draft=box.field.state.drafts[box.field.root]}')
    draft_after=nvim.exec_lua('return scroll_counts')
    # Native buffer anchors must follow their rows on every visible frame.
    for frame in frames+draft_frames:
        maximum=max(1,frame['lines']-frame['height']+1)
        assert 1<=frame['top']<=maximum, ('Overscrolled sidebar',frame)
        config=frame.get('commit')
        if config and not config.get('hide',False):
            expected=frame['side_position'][0]+frame['message_row']-frame['top']
            assert frame['position'][0]==expected, ('Textbox detached from row',frame)
    assert all(f['top']==1 for f in search), 'Empty search sidebar scrolled beyond its content'
    assert isolated_after['config']==isolated_before['config'], 'Editor scroll repositioned sidebar inputs'
    assert isolated_after['lines']==isolated_before['lines'], 'Editor scroll rewrote a sidebar buffer'
    assert isolated_after['render']==isolated_before['render'], 'Editor scroll re-rendered Git'
    assert draft['text']==['feat: preserve scroll draft'] and draft['draft']==draft['text'][0]
    assert len({f['top'] for f in draft_frames})>1, 'Wheel over commit textbox did not scroll sidebar'
    boundary_before=nvim.exec_lua('return vim.deepcopy(scroll_counts)')
    for _ in range(20):
        nvim.api.input_mouse('wheel','down','',0,10,20);ui.drain(5)
    boundary_after=nvim.exec_lua('return scroll_counts')
    assert boundary_after['config']==boundary_before['config'], 'Repeated redraw work at bottom boundary'
    # Changing the native width must update the textbox once, without a resize loop.
    nvim.exec_lua('vim.api.nvim_win_set_width(require("workbench").side_win(),52)');ui.drain(150)
    assert nvim.exec_lua('return vim.api.nvim_win_get_config(require("commit_box").win).width')==48
    # A viewport taller than the complete Git view cannot scroll down at all.
    nvim.ui_try_resize(150,70);ui.drain(150)
    for _ in range(15): nvim.api.input_mouse('wheel','down','',0,10,20)
    ui.drain(150)
    assert nvim.exec_lua('return scroll_view().top')==1, 'Short Git view overscrolled'
    # Focused input becomes safely unfocused if it moves offscreen.
    nvim.ui_try_resize(150,42);ui.drain(150)
    nvim.exec_lua('local w=require("workbench");local v=scroll_view();require("sidebar_ui").clamp(w.side_win(),math.max(1,v.message_row-4)-v.top);require("sidebar_ui").update_fields(w.side_win());local b=require("commit_box");b.focus(b.field.root)')
    ui.drain(50)
    hidden_direction=nvim.exec_lua('local v=scroll_view();return v.lines-v.height+1>v.message_row and "down" or "up"')
    for _ in range(15): nvim.api.input_mouse('wheel',hidden_direction,'',0,10,20)
    ui.drain(150)
    focus_state=nvim.exec_lua('return {hidden=vim.api.nvim_win_get_config(require("commit_box").win).hide,current=vim.api.nvim_get_current_win(),side=require("workbench").side_win(),view=scroll_view(),ft=vim.bo.filetype,mode=vim.fn.mode()}')
    assert focus_state['hidden'] and focus_state['current']==focus_state['side'], ('Hidden input kept keyboard focus',focus_state)
    # Explorer uses Snacks' own bounded list scrolling.
    nvim.exec_lua('require("workbench").sidebar("explorer",true)');ui.drain(400)
    files=[]
    for direction in ['down','up']:
        for _ in range(45):
            nvim.api.input_mouse('wheel',direction,'',0,15,12);ui.drain(5)
            files.append(nvim.exec_lua('local p=Snacks.picker.get({source="explorer"})[1];return {top=p.list.top,count=p.list:count(),height=p.list:height()}'))
    assert all(1<=f['top']<=max(1,f['count']-f['height']+1) for f in files), 'Explorer list overscrolled'
    nvim.exec_lua('require("workbench").focus_editor()')
    # Duplicate tab labels and changed buffer metadata must stay correct while cached.
    tab_checks=nvim.exec_lua("""local a=vim.api;local ui=require('editor_ui');local root=...;local ids={}
      for i=1,2 do local b=a.nvim_create_buf(true,false);a.nvim_buf_set_name(b,root..'/repo-0'..i..'/shared.txt');ids[i]=b end
      local duplicate=ui.tab_name({bufnr=ids[1]}):find('repo-01/',1,true)~=nil
      a.nvim_buf_delete(ids[2],{force=true})
      local unique=ui.tab_name({bufnr=ids[1]})=='shared.txt'
      local blank=a.nvim_create_buf(true,false);vim.b[blank].workbench_explicit_blank=true
      local visible=ui.filter_tab(blank)
      a.nvim_buf_set_lines(blank,0,-1,false,{'draft'});a.nvim_exec_autocmds('BufModifiedSet',{buffer=blank})
      local modified=ui.filter_tab(blank)
      a.nvim_buf_delete(blank,{force=true});a.nvim_buf_delete(ids[1],{force=true})
      return {duplicate=duplicate,unique=unique,blank=visible,modified=modified}""",str(parent))
    assert all(tab_checks.values()), ('Cached tab metadata became stale',tab_checks)
    assert not nvim.exec_lua('return switch_errors'), 'Neovim reported an error'
    assert not nvim.command_output('messages'), 'Unexpected Neovim messages'

    result={'frames':frames,'search':search,'counts':counts,'cpu_seconds':cpu,'idle_before':idle_before,'idle_after':idle_after,
      'editor_scroll':{k:isolated_after[k]-v for k,v in isolated_before.items()},'draft_frames':draft_frames,'draft':draft,
      'input_scroll':{k:draft_after[k]-v for k,v in draft_before.items()},
      'errors':nvim.exec_lua('return switch_errors'),'messages':nvim.command_output('messages'),'fixture':str(fixture)}
    if args.report: args.report.write_text(json.dumps(result,indent=2))
    print(json.dumps({'counts':counts,'cpu_seconds':cpu,'idle':{k:idle_after[k]-v for k,v in idle_before.items()},
       'git_top_range':[min(f['top'] for f in frames),max(f['top'] for f in frames)],
       'git_max_top':max(1,frames[0]['lines']-frames[0]['height']+1),
       'search_top':max(f['top'] for f in search),'editor_scroll':result['editor_scroll'],'input_scroll':result['input_scroll'],
       'draft':draft,'errors':result['errors'],'messages':result['messages']}),flush=True)

finally:
    try: close_child(nvim)
    finally: shutil.rmtree(fixture)
