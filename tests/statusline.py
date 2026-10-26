"""Check actual rendered statusline cells and sidebar bounds in disposable repos."""
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
cli.add_argument('--probe',action='store_true',help='record failures without failing the process, for before/after evidence')
args=cli.parse_args()
if args.screenshots and not args.font:cli.error('--screenshots needs --font')
fixture=Path(tempfile.mkdtemp(prefix='vimdesk-statusline-')).resolve();parent=fixture/'Workspace';parent.mkdir()
for name in ['backend','frontend','worker']:
    repo=parent/name;repo.mkdir();(repo/'note.txt').write_text('Dummy note\n')
    for command in [('init','-q','-b','main'),('config','user.name','UI QA'),('config','user.email','qa@example.invalid'),('add','.'),('commit','-qm','fixture')]:
        subprocess.run(['git','-C',str(repo),*command],check=True,capture_output=True)
for kind in ['config','data','state','cache']:
    (fixture/kind).mkdir();os.environ['XDG_'+kind.upper()+'_HOME']=str(fixture/kind)
os.environ['NVIM_APPNAME']='nvim'
shutil.copytree(args.source,fixture/'config/nvim');(fixture/'data/nvim').mkdir()
(fixture/'data/nvim/lazy').symlink_to(args.plugins_dir.resolve());(fixture/'work').mkdir()
(fixture/'work/vscode-deps').symlink_to(args.plugins_dir.resolve());(fixture/'work/vscode-config').symlink_to(fixture/'config/nvim')
nvim=None;samples=[];failures=[]
try:
    nvim=attach_child(['nvim','--embed','-n','-i','NONE','--cmd',
      'let g:workbench_test='+json.dumps(str(fixture))+' | let g:workbench_disable_startup=1',str(parent/'backend/note.txt')],timeout=110)
    ui=UIGrid(nvim,150,44);nvim.ui_attach(150,44,rgb=True,ext_linegrid=True);ui.drain(650)
    nvim.command('cd '+nvim.funcs.fnameescape(str(parent)))
    nvim.exec_lua('''_G.qa_errors={};local notify=vim.notify;vim.notify=function(msg,level,opts)
      if level==vim.log.levels.ERROR then qa_errors[#qa_errors+1]=tostring(msg) end;return notify(msg,level,opts) end
      require('repo_panel').refresh()''')
    def wait(expr):
        deadline=time.monotonic()+8
        while not nvim.exec_lua('return '+expr):
            assert time.monotonic()<deadline,expr+'\n'+nvim.command_output('messages');ui.drain(40)
    wait('require("repo_panel").state().loaded and not require("repo_panel").state().reading')
    ui.drain(1100)  # Allow the existing statusline timer its initial branch update.
    def sample(label,mode):
        ui.drain(180)
        info=nvim.exec_lua('''local w=require('workbench');local out={laststatus=vim.o.laststatus,mode=vim.fn.mode(),
          windows={},focus=vim.bo.filetype};for _,win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local c=vim.api.nvim_win_get_config(win);out.windows[#out.windows+1]={id=win,ft=vim.bo[vim.api.nvim_win_get_buf(win)].filetype,
            relative=c.relative,pos=vim.api.nvim_win_get_position(win),height=vim.api.nvim_win_get_height(win),border=c.border}
          end;return out''')
        row=ui.height-nvim.options['cmdheight']-1
        text=''.join(cell[0] for cell in ui.grid[row])
        info.update(label=label,row=row,text=text)
        samples.append(info)
        if mode not in text or 'main' not in text:failures.append({'label':label,'expected':[mode,'main'],'rendered':text})
        # Root float includes a top and bottom border. Its last screen row must
        # stay strictly above the global statusline, even when the tree grows.
        for win in info['windows']:
            if win['ft']=='snacks_layout_box' and win['relative']:
                bottom=win['pos'][0]+win['height']+1
                if bottom>=row:failures.append({'label':label,'covered_statusline':True,'bottom':bottom,'statusline_row':row})
        if args.screenshots:
            args.screenshots.mkdir(parents=True,exist_ok=True);ui.save(args.screenshots/(label+'.png'),args.font)
        print(label,repr(text[:50]),flush=True)
    nvim.exec_lua('require("workbench").focus_editor()');sample('editor-normal','NORMAL')
    nvim.input('i');sample('editor-insert','INSERT');nvim.input('<Esc>');ui.drain(50)
    nvim.exec_lua('require("workbench").sidebar("explorer",true)')
    wait('require("workbench").explorer_picker() and require("workbench").explorer_picker().list.win:valid()')
    nvim.exec_lua('require("workbench").explorer_picker():focus("list")');sample('explorer-tree','NORMAL')
    nvim.exec_lua('require("workbench").explorer_picker():focus("input")');sample('explorer-filter','INSERT')
    nvim.input('<Esc>');ui.drain(60)
    nvim.exec_lua('vim.api.nvim_set_current_win(require("explorer_panel").win)');sample('open-editors','NORMAL')
    nvim.exec_lua('require("workbench").focus_editor()');nvim.input('i');sample('editor-insert-with-explorer','INSERT')
    nvim.input('<Esc>');ui.drain(40)
    nvim.exec_lua('require("workbench").sidebar("search",true);require("search_box").focus("query")');sample('search-input','INSERT')
    nvim.input('<Esc>');ui.drain(60)
    nvim.exec_lua('require("workbench").sidebar("git",true);require("commit_box").focus(require("repo_panel").state().active)');sample('git-commit','INSERT')
    nvim.input('<Esc>');ui.drain(50)
    # Resize and collapse/expand the header to cover geometry transitions.
    for width,height in [(90,24),(180,52)]:
        nvim.ui_try_resize(width,height);ui.drain(100)
        nvim.exec_lua('require("workbench").sidebar("explorer",true)');ui.drain(150)
        nvim.exec_lua('require("workbench").explorer_picker():focus("list")');sample(f'explorer-{width}x{height}','NORMAL')
        nvim.exec_lua('local h=require("explorer_panel");h.expanded=not h.expanded;h.render()');sample(f'explorer-header-{width}x{height}','NORMAL')
    nvim.exec_lua('require("performance").toggle()');ui.drain(180)
    nvim.exec_lua('require("workbench").explorer_picker():focus("list")');sample('explorer-light','NORMAL')
    # A real PTY shell, with clean environment/history, entirely in the dummy repo.
    shell=fixture/'qa-shell';shell.write_text('#!/bin/sh\nexec /usr/bin/env -i PATH=/usr/bin:/bin TERM=xterm-256color HISTFILE=/dev/null /bin/sh\n');shell.chmod(0o755)
    nvim.exec_lua('vim.o.shell=...;require("workbench").bottom("terminal",true)',str(shell));ui.drain(250)
    wait('vim.fn.mode()=="t"');sample('terminal','TERMINAL')
    term=nvim.funcs.bufnr('%');job=nvim.exec_lua('return vim.b.terminal_job_id')
    nvim.input('echo vimdesk-terminal-qa\r');ui.drain(150)
    assert 'vimdesk-terminal-qa' in '\n'.join(nvim.api.buf_get_lines(term,0,-1,False))
    assert nvim.exec_lua('return vim.b.workbench_terminal_root')==str(parent/'backend')
    nvim.input(r'<C-\><C-n>');ui.drain(80);nvim.input(' ut');ui.drain(150)
    assert nvim.exec_lua('return require("workbench").bottom_win()==nil')
    nvim.input(' ut');ui.drain(180)
    assert nvim.exec_lua('return vim.b.terminal_job_id')==job,'Terminal toggle created another shell process'
    nvim.input(r'<C-\><C-n>');ui.drain(60);nvim.input(' ut');ui.drain(120)
    nvim.exec_lua('require("workbench").explorer_picker():focus("list")');sample('explorer-after-terminal','NORMAL')
    errors=nvim.exec_lua('return qa_errors');assert errors==[],errors
    args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps({'samples':samples,'failures':failures,'errors':errors},indent=2))
    if not args.probe:assert not failures,json.dumps(failures,indent=2)
finally:
    if nvim is not None:close_child(nvim)
    shutil.rmtree(fixture)
