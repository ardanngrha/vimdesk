"""Real multi-repository UI regression for the Git sidebar, history and stable diffs.

Requires pynvim and existing plugins; installs nothing and changes no user repos.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from ui_process import attach_child, close_child
from ui_grid import UIGrid

ROOT=Path(__file__).resolve().parents[1]
cli=argparse.ArgumentParser()
cli.add_argument('--source',type=Path,default=ROOT/'config/nvim')
cli.add_argument('--plugins-dir',type=Path,required=True)
cli.add_argument('--nvim',default='nvim')
cli.add_argument('--report',type=Path)
cli.add_argument('--screenshots',type=Path)
cli.add_argument('--font',type=Path)
args=cli.parse_args()
if args.screenshots and not args.font: cli.error('--screenshots requires --font')
fixture=Path(tempfile.mkdtemp(prefix='vimdesk-git-ui-')).resolve()
parent=fixture/'Workspace';parent.mkdir()
def git(root,*options,ok=True):
    result=subprocess.run(['git','-C',str(root),*options],capture_output=True,text=True)
    if ok: assert result.returncode==0,result.stderr
    return result.stdout.strip()
def repo(name):
    root=parent/name;root.mkdir()
    git(root,'init','-b','main');git(root,'config','user.name','Git UI Test');git(root,'config','user.email','test@example.invalid')
    return root
def commit(root,message): git(root,'add','-A');git(root,'commit','-m',message)
a=repo('backend')
for name,text in [('note.txt','base\n'),('partial.txt','base\n'),('café file.txt','rename content\n'),('deleted.txt','deleted content\n')]: (a/name).write_text(text)
commit(a,'feat: initial files')
git(a,'switch','-c','feature');(a/'note.txt').write_text('feature\n');commit(a,'feat: update note')
git(a,'switch','main');(a/'other.txt').write_text('main branch\n');commit(a,'fix: update main')
git(a,'merge','--no-ff','feature','-m','feat: merge feature')
merge=git(a,'rev-parse','HEAD')
(a/'note.txt').write_text('working\n');(a/'partial.txt').write_text('index\n');git(a,'add','partial.txt');(a/'partial.txt').write_text('working partial\n')
git(a,'mv','café file.txt','renamed file.txt');(a/'deleted.txt').unlink();(a/'untracked file.txt').write_text('new text\n')
b=repo('frontend ui');(b/'app.txt').write_text('frontend old\n');commit(b,'feat: frontend');(b/'app.txt').write_text('frontend new\n')
c=repo('conflict');(c/'conflict.txt').write_text('base\n');commit(c,'feat: base')
git(c,'switch','-c','incoming');(c/'conflict.txt').write_text('INCOMING\n');commit(c,'feat: incoming')
git(c,'switch','main');(c/'conflict.txt').write_text('CURRENT\n');commit(c,'feat: current');git(c,'merge','incoming',ok=False)
empty=repo('empty')
for index in range(13):
    root=repo(f'tool-{index:02d}');(root/'note.txt').write_text('tool\n');commit(root,'feat: tool')
switch_root=parent/'tool-00';git(switch_root,'branch','staging')
for kind in ['config','data','state','cache']:
    (fixture/kind).mkdir();os.environ['XDG_'+kind.upper()+'_HOME']=str(fixture/kind)
os.environ['NVIM_APPNAME']='nvim'
shutil.copytree(args.source,fixture/'config/nvim')
(fixture/'data/nvim').mkdir();(fixture/'data/nvim/lazy').symlink_to(args.plugins_dir.expanduser().resolve())
(fixture/'work').mkdir();(fixture/'work/vscode-deps').symlink_to(args.plugins_dir.expanduser().resolve());(fixture/'work/vscode-config').symlink_to(fixture/'config/nvim')
nvim=attach_child([args.nvim,'--embed','-n','-i','NONE','--cmd',
    'let g:workbench_test='+json.dumps(str(fixture))+' | let g:workbench_disable_startup=1',str(a/'note.txt')],timeout=110)
try:
    ui=UIGrid(nvim,178,52);nvim.ui_attach(178,52,rgb=True,ext_linegrid=True);ui.drain(650)
    nvim.command('cd '+nvim.funcs.fnameescape(str(parent)))
    nvim.exec_lua('''_G.git_ui_errors={};local notify=vim.notify;vim.notify=function(msg,level,opts)
      if level==vim.log.levels.ERROR then table.insert(git_ui_errors,tostring(msg)) end;return notify(msg,level,opts) end
      _G.native=function() local result={};for _,id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(id).relative=='' then result[#result+1]=id end end;table.sort(result);return result end
      _G.diff_info=function() local d=require('git_diff');if not d.active() then return nil end
        local s=d.state;return {root=s.root,path=s.path,left=s.left,right=s.right,
        before=vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(s.left),0,-1,false),
        after=vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(s.right),0,-1,false),
        editable=vim.bo[vim.api.nvim_win_get_buf(s.right)].modifiable,revision=s.revision} end
      require('workbench').sidebar('git',false)
      vim.api.nvim_win_set_width(require('workbench').side_win(),64)
    ''')
    def wait(expression,seconds=8):
        deadline=time.monotonic()+seconds
        while not nvim.exec_lua('return '+expression):
            assert time.monotonic()<deadline, expression+'\n'+nvim.command_output('messages')
            ui.drain(40)
    wait('require("repo_panel").state().loaded and not require("repo_panel").state().reading')
    tab=nvim.api.get_current_tabpage();side=nvim.exec_lua('return require("workbench").side_win()')
    def click(kind,root=None,path=None,staged=False,sha=None,badge=False):
        row=nvim.exec_lua('''local kind,root,path,staged,sha=...;if root==vim.NIL then root=nil end;if path==vim.NIL then path=nil end;if sha==vim.NIL then sha=nil end;for row,node in pairs(require('repo_panel').state().nodes or {}) do
          if node.kind==kind and (not root or node.root==root) and (not path or (node.file and node.file.path or node.path)==path)
            and (kind~='file' or node.staged==staged) and (not sha or node.sha==sha) then return row end end''',kind,str(root) if root else None,path,staged,sha)
        assert row, (kind,root,path,nvim.command_output('messages'))
        nvim.exec_lua('''local w=require('workbench');local row=...;vim.api.nvim_set_current_win(w.side_win());vim.api.nvim_win_set_cursor(w.side_win(),{row,0})
          require('sidebar_ui').clamp(w.side_win())''',row)
        ui.drain(60)
        side_win=nvim.exec_lua('return require("workbench").side_win()')
        line=nvim.api.buf_get_lines(nvim.api.win_get_buf(side_win),row-1,row,False)[0]
        column=line.encode().index(b'[')+1 if badge else 6
        pos=nvim.funcs.screenpos(side_win,row,column)
        assert pos['row']>0,('Row not visible',row)
        nvim.api.input_mouse('left','press','',0,pos['row']-1,pos['col']-1)
        nvim.api.input_mouse('left','release','',0,pos['row']-1,pos['col']-1);ui.drain(200)
    def select(root):
        click('repo',root=root)
        wait('require("repo_panel").state().active=='+json.dumps(str(root)))
        assert nvim.exec_lua('return vim.bo.buftype~="terminal"'), 'Repo selection unexpectedly opened LazyGit'
    def diff(root,path,before,after,staged=False):
        click('file',root=root,path=path,staged=staged)
        wait('require("git_diff").active() and require("git_diff").state.root=='+json.dumps(str(root))+' and require("git_diff").state.path=='+json.dumps(path))
        data=nvim.exec_lua('return diff_info()');assert data['before']==before and data['after']==after,data
        assert nvim.api.get_current_tabpage()==tab,'Ordinary diff switched tabs'
        assert nvim.exec_lua('return require("workbench").side_win()')==side,'Sidebar window was replaced'
        return data
    select(b)
    # Use the actual popup to switch a clean, previously inactive repository.
    click('repo',root=switch_root,badge=True)
    wait('#Snacks.picker.get({source="select"})==1')
    nvim.input('staging');ui.drain(250);nvim.input('<CR>')
    wait('require("repo_panel").state().info['+json.dumps(str(switch_root))+'].head=="staging" and not require("repo_panel").state().reading')
    assert git(switch_root,'branch','--show-current')=='staging'
    assert git(b,'branch','--show-current')=='main','Branch badge targeted the wrong repository'
    click('repo',root=switch_root,badge=True)
    wait('#Snacks.picker.get({source="select"})==1')
    nvim.exec_lua('Snacks.picker.get({source="select"})[1]:close()');ui.drain(100)

    # Verify exact button hit regions at wide and narrow widths without network calls.
    nvim.exec_lua('''local p,s=require('repo_panel'),require('scm');_G.toolbar_calls={}
      _G.toolbar_original={push=s.push,pull=s.pull,fetch=p.fetch,more=p.more}
      s.push=function() table.insert(toolbar_calls,'Push') end;s.pull=function() table.insert(toolbar_calls,'Pull') end
      p.fetch=function(all) table.insert(toolbar_calls,all and 'Fetch All' or 'Fetch') end
      p.more=function() table.insert(toolbar_calls,'More') end''')
    for width in [64,36,26]:
        nvim.api.win_set_width(side,width)
        nvim.exec_lua('require("repo_list").render(require("repo_panel").state())');ui.drain(100)
        lines=nvim.api.buf_get_lines(nvim.api.win_get_buf(side),0,-1,False)
        if width==64: assert '  [Push] [Pull] [Fetch] [Fetch All] [More]' in lines,lines
        for label in ['Push','Pull','Fetch','Fetch All','More']:
            token='['+label+']';row=next(i+1 for i,line in enumerate(lines) if token in line)
            assert nvim.funcs.strdisplaywidth(lines[row-1])<=width-2,lines[row-1]
            column=lines[row-1].index(token)+2
            nvim.api.set_current_win(side);nvim.api.win_set_cursor(side,[row,0])
            nvim.exec_lua('require("sidebar_ui").clamp(...)',side);ui.drain(40)
            pos=nvim.funcs.screenpos(side,row,column);assert pos['row']>0
            for action in ['press','release']: nvim.api.input_mouse('left',action,'',0,pos['row']-1,pos['col']-1)
            ui.drain(80)
    assert nvim.exec_lua('return toolbar_calls')==['Push','Pull','Fetch','Fetch All','More']*3
    nvim.exec_lua('''local p,s=require('repo_panel'),require('scm');local o=toolbar_original
      s.push,s.pull,p.fetch,p.more=o.push,o.pull,o.fetch,o.more;toolbar_original=nil''')
    nvim.api.win_set_width(side,64);nvim.exec_lua('require("repo_list").render(require("repo_panel").state())');ui.drain(100)
    select(b);first=diff(b,'app.txt',['frontend old'],['frontend new'])
    windows=nvim.exec_lua('return native()');assert len(windows)==3,windows
    repaint={'clears':0}
    original_notification=ui.notification
    def notification(name,arguments):
        if name=='redraw':
            repaint['clears']+=sum(len(event)-1 for event in arguments if event[0]=='grid_clear')
        original_notification(name,arguments)
    ui.notification=notification
    select(a);data=diff(a,'note.txt',['feature'],['working'])
    assert data['left']==first['left'] and data['right']==first['right'],'Diff windows were recreated between repos'
    diff(a,'partial.txt',['base'],['index'],True)
    diff(a,'partial.txt',['index'],['working partial'])
    diff(a,'untracked file.txt',[''],['new text'])
    diff(a,'renamed file.txt',['rename content'],['rename content'],True)
    diff(a,'deleted.txt',['deleted content'],[''])
    # Stage from Source Control and update the existing native diff automatically.
    diff(a,'note.txt',['feature'],['working'])
    nvim.exec_lua('require("scm").stage({root=...,file={path="note.txt",x=" ",y="M"}},true)',str(a))
    wait('not require("repo_panel").state().reading and require("git_diff").state.staged==true')
    staged_view=nvim.exec_lua('return diff_info()');assert staged_view['before']==['feature'] and staged_view['after']==['working'],staged_view
    git(a,'restore','--staged','note.txt')
    nvim.exec_lua('require("repo_panel").update_status()');ui.drain(200)
    assert nvim.exec_lua('return native()')==windows,'Diff pane ids changed between files'
    wait('require("git_graph").state('+json.dumps(str(a))+').loaded')
    graph=nvim.exec_lua('return require("git_graph").state(...).entries',str(a))
    assert any('|' in e['prefix'] or '/' in e['prefix'] or '\\' in e['prefix'] for e in graph),'Missing branch/merge graph'
    rows=nvim.exec_lua('''local changes,graph={},{};for row,node in pairs(require('repo_panel').state().nodes) do
      if node.kind=='file' then changes[#changes+1]=row elseif node.kind=='commit' then graph[#graph+1]=row end end;return {changes=changes,graph=graph}''')
    assert min(rows['graph'])>max(rows['changes']),'Graph must be below Changes'
    click('commit',root=a,sha=merge)
    wait('require("git_graph").state('+json.dumps(str(a))+').files['+json.dumps(merge)+'] and not require("git_graph").state('+json.dumps(str(a))+').files['+json.dumps(merge)+'].loading')
    click('commit_file',root=a,path='note.txt',sha=merge)
    wait('require("git_diff").state.revision=='+json.dumps(merge))
    history=nvim.exec_lua('return diff_info()');assert history['before']==['base'] and history['after']==['feature'] and not history['editable'],history
    if args.screenshots:
        args.screenshots.mkdir(parents=True,exist_ok=True);ui.save(args.screenshots/'Git_graph.png',args.font)
    assert nvim.exec_lua('return native()')==windows,'History opened new diff panes'
    assert repaint['clears']==0, ('File switching cleared the full UI',repaint)
    ordinary_clears=repaint['clears']
    # Late revision reads must never overwrite a newer selection.
    nvim.exec_lua('''local d=require('git_diff');d.working(...,{path='note.txt',y='M',x=' '},false)''',str(a))
    nvim.exec_lua('''require('git_diff').working(...,{path='app.txt',y='M',x=' '},false)''',str(b))
    wait('require("git_diff").state.root=='+json.dumps(str(b)))
    ui.drain(100);assert nvim.exec_lua('return diff_info().root')==str(b)
    # Root commits have no parent; historical added files need an empty Before.
    select(a)
    initial=next(e['sha'] for e in graph if e.get('sha') and not e['parents'])
    click('commit',root=a,sha=initial)
    wait('require("git_graph").state('+json.dumps(str(a))+').files['+json.dumps(initial)+'] and not require("git_graph").state('+json.dumps(str(a))+').files['+json.dumps(initial)+'].loading')
    click('commit_file',root=a,path='café file.txt',sha=initial)
    wait('require("git_diff").state.revision=='+json.dumps(initial))
    root_diff=nvim.exec_lua('return diff_info()');assert root_diff['before']==[''] and root_diff['after']==['rename content'],root_diff
    diff(a,'note.txt',['feature'],['working'])
    dirty=nvim.exec_lua('local b=vim.api.nvim_win_get_buf(require("git_diff").state.right);vim.api.nvim_buf_set_lines(b,0,-1,false,{"unsaved draft"});return b')
    nvim.exec_lua('require("git_diff").close()');ui.drain(100)
    assert nvim.api.buf_is_valid(dirty) and nvim.api.buf_get_lines(dirty,0,-1,False)==['unsaved draft']
    assert nvim.api.get_option_value('modified',{'buf':dirty}), 'Closing diff lost unsaved edits'
    select(empty);wait('require("git_graph").state('+json.dumps(str(empty))+').loaded')
    assert not nvim.exec_lua('return require("git_graph").state(...).error',str(empty))
    select(c);click('file',root=c,path='conflict.txt')
    wait('package.loaded["diffview.lib"] and require("diffview.lib").get_current_view() and require("diffview.lib").get_current_view().cur_entry~=nil')
    ui.drain(300)
    merge_data=nvim.exec_lua('''local v=require('diffview.lib').get_current_view();local out={};for _,win in ipairs(v.cur_layout.windows) do
      if win:is_valid() then out[win.file.symbol]={pos=vim.api.nvim_win_get_position(win.id),lines=vim.api.nvim_buf_get_lines(win.file.bufnr,0,-1,false),label=vim.wo[win.id].winbar} end end;return out''')
    assert merge_data['c']['lines']==['INCOMING'] and merge_data['a']['lines']==['CURRENT'],merge_data
    assert merge_data['c']['pos'][1]<merge_data['a']['pos'][1] and merge_data['b']['pos'][0]>merge_data['a']['pos'][0],merge_data
    assert len(nvim.exec_lua('return native()'))==4,'Expected sidebar plus three merge panes'
    if args.screenshots: ui.save(args.screenshots/'Git_merge.png',args.font)
    nvim.exec_lua('local v=require("diffview.lib").get_current_view();local win=v.cur_layout:get_main_win().id;vim.api.nvim_set_current_win(win);vim.api.nvim_win_set_cursor(win,{2,0});require("git_review").accept_click(2,1,"l")')
    ui.drain(150)
    nvim.exec_lua('require("git_review").accept_click(4,1,"l")');ui.drain(150)
    assert (c/'conflict.txt').read_text()=='CURRENT\n'
    nvim.exec_lua('require("git_review").accept_click(5,1,"l")')
    deadline=time.monotonic()+8
    while git(c,'ls-files','--unmerged'):
        assert time.monotonic()<deadline,'Resolved result was not staged';ui.drain(50)
    ui.drain(200)
    assert not nvim.exec_lua('return git_ui_errors'),nvim.exec_lua('return git_ui_errors')
    assert not nvim.command_output('messages'),nvim.command_output('messages')
    result={'passed':['17 repo sidebar','repo/file mouse clicks','branch badge popup and actual checkout','toolbar mouse hit regions at 26/36/64 columns','stable tab/sidebar/diff windows','staged and working diffs','untracked/renamed/deleted files',
      'branch/merge graph','expand commit files','historical diff','stale result cancellation','empty repository','three-pane conflicts','resolve/save/stage conflict','stage refresh','root commit','unsaved edit preservation'],'ordinary_windows':windows,'history':history,'ordinary_full_screen_clears':ordinary_clears}
    if args.report: args.report.write_text(json.dumps(result,indent=2))
    print(json.dumps(result),flush=True)
finally:
    try: close_child(nvim)
    finally: shutil.rmtree(fixture)
