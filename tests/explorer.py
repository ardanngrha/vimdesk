"""Exercise Files menus and actual file operations in disposable sibling repos.

Reuses existing plugins read-only; the system clipboard is replaced in this test.
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
cli.add_argument('--report',type=Path)
cli.add_argument('--screenshots',type=Path)
cli.add_argument('--font',type=Path)
cli.add_argument('--expect-icons',action='store_true',help='require the icon provider and check the real toggle mapping')
args=cli.parse_args()
if args.screenshots and not args.font: cli.error('--screenshots requires --font')
fixture=Path(tempfile.mkdtemp(prefix='vimdesk-files-ui-')).resolve()
workspace=fixture/'Workspace';workspace.mkdir()
for name in ['backend','frontend']:
    repo=workspace/name;repo.mkdir()
    for command in [('init','-b','main'),('config','user.name','Files Test'),('config','user.email','files@example.invalid')]:
        subprocess.run(['git','-C',str(repo),*command],check=True,capture_output=True)
a=workspace/'backend';b=workspace/'frontend'
(a/'café notes.txt').write_text('original content\n')
(a/'folder with spaces').mkdir();(a/'folder with spaces/child.txt').write_text('child content\n')
(a/'folder with spaces/loop').symlink_to('.',target_is_directory=True)
(a/'folder with spaces/nested').mkdir()
(b/'café notes.txt').write_text('existing destination\n')
for kind in ['config','data','state','cache']:
    (fixture/kind).mkdir();os.environ['XDG_'+kind.upper()+'_HOME']=str(fixture/kind)
os.environ['NVIM_APPNAME']='nvim'
shutil.copytree(args.source,fixture/'config/nvim')
(fixture/'data/nvim').mkdir();(fixture/'data/nvim/lazy').symlink_to(args.plugins_dir.resolve())
(fixture/'work').mkdir();(fixture/'work/vscode-deps').symlink_to(args.plugins_dir.resolve());(fixture/'work/vscode-config').symlink_to(fixture/'config/nvim')
nvim=attach_child(['nvim','--embed','-n','-i','NONE','--cmd',
    'let g:workbench_test='+json.dumps(str(fixture))+' | let g:workbench_disable_startup=1',str(a/'café notes.txt')],timeout=130)
try:
    ui=UIGrid(nvim,150,44);nvim.ui_attach(150,44,rgb=True,ext_linegrid=True);ui.drain(650)
    nvim.command('cd '+nvim.funcs.fnameescape(str(workspace)))
    nvim.exec_lua('''_G.file_errors={};_G.file_notices={};local notify=vim.notify;vim.notify=function(msg,level,opts)
      table.insert(file_notices,tostring(msg));if level==vim.log.levels.ERROR then table.insert(file_errors,tostring(msg)) end
      return notify(msg,level,opts) end
      _G.test_clip={};vim.g.clipboard={name='Files test clipboard',copy={
        ['+']=function(lines,kind) test_clip={lines,kind} end,['*']=function(lines,kind) test_clip={lines,kind} end},
        paste={['+']=function() return test_clip end,['*']=function() return test_clip end},cache_enabled=0}
      _G.explorer=function() return Snacks.picker.get({source='explorer'})[1] end
      require('workbench').sidebar('explorer',true)
    ''')
    def wait(expression,seconds=8):
        deadline=time.monotonic()+seconds
        while not nvim.exec_lua('return '+expression):
            assert time.monotonic()<deadline,expression+'\n'+nvim.command_output('messages')
            ui.drain(40)
    wait('explorer() and explorer().list.win:valid()')
    side=nvim.exec_lua('return require("workbench").side_win()')
    width=nvim.api.win_get_width(side)
    if args.expect_icons: assert nvim.exec_lua('return MiniIcons~=nil'),'Files did not load mini.icons'
    icons_checked=False
    if nvim.exec_lua('return MiniIcons~=nil'):
        assert nvim.exec_lua('return explorer().opts.icons.files.enabled')
        nvim.input(' ui');ui.drain(100)
        assert not nvim.exec_lua('return explorer().opts.icons.files.enabled')
        nvim.input(' ui');ui.drain(100)
        assert nvim.exec_lua('return explorer().opts.icons.files.enabled')
        icons=nvim.exec_lua('''local result={};for _,ext in ipairs({'go','rs','py','tsx','js','lua'}) do
          local glyph,hl=MiniIcons.get('file','example.'..ext);result[ext]={glyph,hl} end;return result''')
        assert len({value[0] for value in icons.values()})>=5,icons
        icons_checked=True
        print('PASS distinct language icons and Space ui toggle',flush=True)
    def target(path):
        nvim.exec_lua('''local p=explorer();require('snacks.explorer.actions').update(p,{target=...,refresh=true});p:focus('list')''',str(path))
        wait('explorer():current() and explorer():current().file=='+json.dumps(str(path),ensure_ascii=False))
        ui.drain(70)
    def input_text(value):
        wait('vim.bo.filetype=="snacks_input"')
        nvim.api.buf_set_lines(0,0,-1,False,[value]);nvim.input('<CR>');ui.drain(180)
    def select_menu(label):
        wait('#Snacks.picker.get({source="select"})==1')
        nvim.input(label);ui.drain(160);nvim.input('<CR>');ui.drain(170)
    def popup(path):
        target(path)
        pos=nvim.exec_lua('''local p=explorer();return vim.fn.screenpos(p.list.win.win,p.list:idx2row(p.list.cursor),6)''')
        assert pos['row']>0,pos
        for action in ['press','release']: nvim.api.input_mouse('right',action,'',0,pos['row']-1,pos['col']-1)
        wait('#Snacks.picker.get({source="select"})==1')
    def toolbar(label):
        header=nvim.exec_lua('return package.loaded.explorer_panel and require("explorer_panel").win')
        if header:
            text=nvim.api.buf_get_lines(nvim.api.win_get_buf(header),0,2,False)
            token='['+('New File' if label=='New' else label)+']'
            row=next(i for i,line in enumerate(text) if token in line)
            pos=nvim.api.win_get_position(header)
            col=text[row].index(token)+2
            for action in ['press','release']: nvim.api.input_mouse('left',action,'',0,pos[0]+row,pos[1]+col-1)
            ui.drain(180)
            return
        win=nvim.exec_lua('return explorer().list.win.win')
        pos=nvim.api.win_get_position(win)
        text=nvim.api.eval_statusline(nvim.api.get_option_value('winbar',{'win':win}),{'winid':win})['str']
        col=text.index('['+label+']')+2
        # Window position starts at the winbar when present.
        for action in ['press','release']: nvim.api.input_mouse('left',action,'',0,pos[0],pos[1]+col-1)
        ui.drain(180)
    # Real right-click selection and visible action menu.
    popup(a/'café notes.txt')
    print('PASS right-click opens actions',flush=True)
    if args.screenshots:
        args.screenshots.mkdir(parents=True,exist_ok=True);ui.save(args.screenshots/'explorer-menu.png',args.font)
    select_menu('Copy relative path')
    print('Selected copy relative path',flush=True)
    assert nvim.funcs.getreg('+')=='backend/café notes.txt'
    target(a/'café notes.txt');nvim.input('Y');ui.drain(100)
    assert nvim.funcs.getreg('+')==str(a/'café notes.txt')
    print('PASS relative and absolute clipboard paths',flush=True)
    # Clipboard file copy is separate from copied text paths; paste never replaces a collision.
    nvim.input('c');ui.drain(100)
    nvim.input('y');ui.drain(70)
    target(b);toolbar('Paste')
    wait('not require("explorer_actions").copying')
    assert (b/'café notes copy.txt').read_text()=='original content\n'
    assert (b/'café notes.txt').read_text()=='existing destination\n'
    print('PASS file clipboard and non-destructive paste',flush=True)
    # Recursive folders and symlinks are copied without following the symlink loop.
    target(a/'folder with spaces');nvim.input('c');ui.drain(60)
    target(b);nvim.input('p');ui.drain(90);wait('not require("explorer_actions").copying')
    copied=b/'folder with spaces'
    assert (copied/'child.txt').read_text()=='child content\n'
    assert (copied/'loop').is_symlink() and os.readlink(copied/'loop')=='.'
    print('PASS directory and symlink copy',flush=True)
    # Reject recursive self-copy, then duplicate alongside the original.
    target(a/'folder with spaces');nvim.input('c');ui.drain(60)
    target(a/'folder with spaces/nested');nvim.input('p');ui.drain(120)
    assert not (a/'folder with spaces/nested/folder with spaces').exists()
    target(a/'café notes.txt');nvim.input('D');ui.drain(90);wait('not require("explorer_actions").copying')
    assert (a/'café notes copy.txt').read_text()=='original content\n'
    # New file/folder prompt from the visible toolbar.
    target(b);toolbar('New');input_text('new file.txt')
    assert (b/'new file.txt').is_file()
    target(b);nvim.input('a');input_text('new folder/')
    assert (b/'new folder').is_dir()
    print('PASS duplicate and toolbar create file/folder',flush=True)
    # Rename updates an open file buffer; folder rename also updates child buffers.
    original_buffer=nvim.exec_lua('return vim.fn.bufnr(...)',str(a/'café notes.txt'))
    target(a/'café notes.txt');nvim.input('<F2>');input_text('renamed notes.txt')
    assert not (a/'café notes.txt').exists() and (a/'renamed notes.txt').read_text()=='original content\n'
    assert nvim.api.buf_get_name(original_buffer)==str(a/'renamed notes.txt')
    assert nvim.api.buf_get_lines(original_buffer,0,-1,False)==['original content']
    nvim.exec_lua('require("workbench").open_file(...)',str(copied/'child.txt'))
    child_buffer=nvim.exec_lua('return vim.fn.bufnr(...)',str(copied/'child.txt'))
    target(copied);nvim.input('r');input_text('renamed folder')
    assert not copied.exists() and (b/'renamed folder/child.txt').is_file()
    assert nvim.api.buf_get_name(child_buffer)==str(b/'renamed folder/child.txt')
    assert nvim.api.buf_get_lines(child_buffer,0,-1,False)==['child content']
    print('PASS file/folder rename and buffer paths',flush=True)
    # Rename collision and unsaved-delete safeguards leave disk and buffers intact.
    target(b/'new file.txt');nvim.input('r');input_text('café notes.txt')
    assert (b/'new file.txt').exists() and (b/'café notes.txt').read_text()=='existing destination\n'
    dirty=nvim.exec_lua('''local b=vim.fn.bufadd(...);vim.fn.bufload(b);vim.api.nvim_buf_set_lines(b,0,-1,false,{'unsaved'});return b''',str(b/'new file.txt'))
    target(b/'new file.txt');nvim.input('d');ui.drain(120)
    assert (b/'new file.txt').exists() and nvim.api.buf_get_lines(dirty,0,-1,False)==['unsaved']
    assert nvim.exec_lua('return #Snacks.picker.get({source="select"})')==0
    nvim.api.set_option_value('modified',False,{'buf':dirty})
    # Cancel and confirm deletion; restore real contents through the menu.
    target(b/'renamed folder');nvim.input('<Del>');select_menu('Cancel')
    assert (b/'renamed folder/child.txt').exists()
    target(b/'renamed folder');nvim.input('d');select_menu('Move to VimDesk trash')
    assert not (b/'renamed folder').exists()
    latest=json.loads((fixture/'state/nvim/workbench/trash/files/latest.json').read_text())
    manifest=json.loads((Path(latest['dir'])/'manifest.json').read_text())
    assert (Path(manifest['items'][0]['to'])/'child.txt').read_text()=='child content\n'
    (b/'renamed folder').mkdir();(b/'renamed folder/sentinel.txt').write_text('keep this\n')
    popup(b);select_menu('Restore last deleted')
    assert (b/'renamed folder/sentinel.txt').read_text()=='keep this\n'
    assert (Path(manifest['items'][0]['to'])/'child.txt').exists()
    shutil.rmtree(b/'renamed folder')
    popup(b);select_menu('Restore last deleted')
    assert (b/'renamed folder/child.txt').read_text()=='child content\n'
    assert (b/'renamed folder/loop').is_symlink()
    # New controls survive Files/Search/Git switching without changing sidebar width.
    for mode in ['search','git','explorer']:
        nvim.exec_lua('require("workbench").sidebar(...,true)',mode);ui.drain(200)
        assert nvim.exec_lua('return require("workbench").side_win()')==side
        assert nvim.api.win_get_width(side)==width
    wait('explorer() and explorer().list.win:valid()')
    assert nvim.exec_lua('''return package.loaded.explorer_panel and require('explorer_panel').win
      or vim.wo[explorer().list.win.win].winbar:find('[More]',1,true)''')
    assert nvim.exec_lua('return file_errors')==[],nvim.exec_lua('return file_errors')
    if args.screenshots: ui.save(args.screenshots/'explorer.png',args.font)
    # Trash metadata persists across Neovim processes; no live session state is required.
    target(b/'new file.txt');nvim.input('d');select_menu('Move to VimDesk trash')
    assert not (b/'new file.txt').exists()
    close_child(nvim);nvim=None
    nvim=attach_child(['nvim','--embed','-n','-i','NONE','--cmd',
      'let g:workbench_test='+json.dumps(str(fixture))+' | let g:workbench_disable_startup=1',str(a/'renamed notes.txt')],timeout=30)
    ui=UIGrid(nvim,150,44);nvim.ui_attach(150,44,rgb=True,ext_linegrid=True);ui.drain(650)
    nvim.command('cd '+nvim.funcs.fnameescape(str(workspace)))
    nvim.exec_lua('''_G.explorer=function() return Snacks.picker.get({source='explorer'})[1] end
      require('workbench').sidebar('explorer',true)''')
    wait('explorer() and explorer().list.win:valid()')
    popup(b);select_menu('Restore last deleted')
    assert (b/'new file.txt').read_text()==''
    result={'passed':['real right-click menu','relative/absolute clipboard paths','file copy/paste and collision preservation',
      'folder and symlink copy','self-copy rejection','duplicate','toolbar New/Paste','create file and folder','rename file and open buffers',
      'rename folder and child buffers','rename collision rejection','unsaved delete protection','cancel deletion','recoverable delete and restore',
      'restore collision preservation','restore after restarting Neovim','stable sidebar across Files/Search/Git'],'errors':[]}
    if icons_checked: result['passed'].append('distinct language icons and real Space ui on/off mapping')
    if args.report: args.report.write_text(json.dumps(result,indent=2))
    print(json.dumps(result),flush=True)
finally:
    try:
        if nvim is not None: close_child(nvim)
    finally: shutil.rmtree(fixture)
