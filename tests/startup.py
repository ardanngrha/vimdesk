"""Workspace startup regression using only disposable repos, profiles and sessions."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from ui_grid import UIGrid
from ui_process import attach_child, close_child

ROOT=Path(__file__).resolve().parents[1]
cli=argparse.ArgumentParser(description=__doc__)
cli.add_argument('--source',type=Path,default=ROOT/'config/nvim')
cli.add_argument('--plugins-dir',type=Path,required=True)
cli.add_argument('--report',type=Path)
args=cli.parse_args()
passed=[]
with tempfile.TemporaryDirectory(prefix='vimdesk-startup-') as temporary:
    fixture=Path(temporary).resolve()
    for case in ['no-session','stale-session','no-args','existing-comma','explicit-comma','modified-comma','nonempty-comma']:
        home=fixture/case;root=home/'Workspace';root.mkdir(parents=True)
        (root/'note.txt').write_text('keep this file\n')
        subprocess.run(['git','init','-q','-b','main',str(root)],check=True)
        for kind in ['config','data','state','cache']:
            (home/kind).mkdir();os.environ['XDG_'+kind.upper()+'_HOME']=str(home/kind)
        os.environ['NVIM_APPNAME']='nvim'
        shutil.copytree(args.source,home/'config/nvim')
        (home/'data/nvim').mkdir();(home/'data/nvim/lazy').symlink_to(args.plugins_dir.expanduser().resolve())
        if case not in ['no-session','explicit-comma']:
            sessions=home/'state/nvim/sessions';sessions.mkdir(parents=True)
            session=sessions/(str(root).replace('/','%')+'.vim')
            session.write_text('argglobal\n%argdelete\n$argadd ,\nedit note.txt\n')
            metadata=home/'state/nvim/workbench';metadata.mkdir(parents=True)
            (metadata/(hashlib.sha256(str(root).encode()).hexdigest()+'.json')).write_text(json.dumps({
                'mode':'explorer','sidebar_open':True,'width':36}))
        if case=='existing-comma':(root/',').write_text('a real comma file\n')
        launch=['nvim','--embed','-n','-i','NONE','--cmd','lua vim.lsp.enable=function() end']
        if case=='explicit-comma':launch += [str(root/',')]
        elif case!='no-args':launch += [str(root)]
        previous=os.getcwd();os.chdir(root)
        try:nvim=attach_child(launch,timeout=30)
        finally:os.chdir(previous)
        try:
            ui=UIGrid(nvim,120,36);nvim.ui_attach(120,36,rgb=True,ext_linegrid=True);ui.drain(1200)
            current=nvim.exec_lua('''local b={};for _,buf in ipairs(vim.api.nvim_list_bufs()) do
              if vim.bo[buf].buflisted then b[#b+1]=vim.api.nvim_buf_get_name(buf) end end
              return {args=vim.fn.argv(),buffers=b,side=require('workbench').side_win()~=nil,session=vim.v.this_session}''')
            assert current['side'],(case,current,'startup sidebar did not open')
            if case in ['no-session','stale-session','no-args']:
                assert ',' not in current['args'],(case,current)
                assert str(root/',') not in current['buffers'],(case,current)
                if case!='no-session':assert str(root/'note.txt') in current['buffers'],current
            elif case=='existing-comma':
                assert ',' in current['args'] and (root/',').read_text()=='a real comma file\n',current
            elif case=='explicit-comma':
                assert str(root/',') in [str((root/path).resolve()) for path in current['args']] and str(root/',') in current['buffers'],current
            else:
                # Guard against erasing drafts even when a missing placeholder
                # was edited by another startup callback before cleanup.
                result=nvim.exec_lua('''local path,modified=...;vim.cmd('argadd '..vim.fn.fnameescape(path))
                  local b=vim.fn.bufadd(path);vim.fn.bufload(b);vim.api.nvim_buf_set_lines(b,0,-1,false,{'draft'})
                  vim.bo[b].modified=modified;require('workbench').clean_startup_args()
                  return {valid=vim.api.nvim_buf_is_valid(b),content=vim.api.nvim_buf_get_lines(b,0,-1,false),args=vim.fn.argv()}''',str(root/','),case=='modified-comma')
                assert result['valid'] and result['content']==['draft'] and str(root/',') in [str((root/path).resolve()) for path in result['args']],result
            passed.append(case)
        finally:close_child(nvim)
report={'passed':passed}
if args.report:args.report.write_text(json.dumps(report,indent=2))
print(json.dumps(report),flush=True)
