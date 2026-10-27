"""Mouse/UI regression for combined Changes, overview rulers and recoverable discard.

Only temporary sibling repos and a disposable Neovim profile are mutated.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import tempfile
import time
from ui_grid import UIGrid
from ui_process import attach_child, close_child

ROOT = Path(__file__).resolve().parents[1]
cli = argparse.ArgumentParser(description=__doc__)
cli.add_argument('--source', type=Path, default=ROOT/'config/nvim')
cli.add_argument('--plugins-dir', type=Path, required=True)
cli.add_argument('--screenshots', type=Path)
cli.add_argument('--font', type=Path)
cli.add_argument('--report', type=Path)
cli.add_argument('--benchmark', action='store_true', help='paired ruler scroll CPU/wall samples; no terminal/GPU claim')
args = cli.parse_args()
if args.screenshots and not args.font:
    cli.error('--screenshots requires --font')
fixture = Path(tempfile.mkdtemp(prefix='vimdesk-changes-')).resolve()
parent = fixture/'Workspace'; parent.mkdir()

def git(root, *options, ok=True):
    result = subprocess.run(['git', '-C', str(root), *options], capture_output=True, text=True)
    if ok: assert result.returncode == 0, result.stderr
    return result.stdout

def repo(name):
    root = parent/name; root.mkdir()
    git(root, 'init', '-b', 'main'); git(root, 'config', 'user.name', 'Demo')
    git(root, 'config', 'user.email', 'demo@example.invalid')
    return root

def commit(root):
    git(root, 'add', '-A'); git(root, 'commit', '-m', 'feat: fixture')

a, b, c = repo('backend'), repo('frontend'), repo('conflict')
before = ['package main', '', 'func example() {'] + [f'  value{i} := {i}' for i in range(140)] + ['}']
after = before[:]; after[12] = '  value9 := -9 // changed'; after[80:80] = ['  added := true', '  _ = added']
after[125] = '  longValue := "'+'long text '*35+'"'
(a/'main.go').write_text('\n'.join(before)+'\n')
(a/'other.go').write_text('package main\n\nvar retries = 1\n')
(a/'partial.txt').write_text('base\n'); (a/'literal[1].txt').write_text('literal base\n')
(a/'literal1.txt').write_text('must stay\n'); (a/'deleted.txt').write_text('recover deletion\n')
(a/'rename me.txt').write_text('rename text\n'); commit(a)
(a/'main.go').write_text('\n'.join(after)+'\n'); (a/'other.go').write_text('package main\n\nvar retries = 3\n')
(a/'partial.txt').write_text('index\n'); git(a,'add','partial.txt'); (a/'partial.txt').write_text('working\n')
(a/'literal[1].txt').write_text('literal working\n'); (a/'literal1.txt').write_text('must stay modified\n')
(a/'deleted.txt').unlink(); git(a,'mv','rename me.txt','renamed.txt')
(a/'new dir').mkdir(); (a/'new dir/note.txt').write_text('untracked recovery\n')
(b/'app.tsx').write_text('export const value = 1\n'); commit(b); (b/'app.tsx').write_text('export const value = 2\n')
(c/'conflict.txt').write_text('base\n'); commit(c); git(c,'switch','-c','incoming')
(c/'conflict.txt').write_text('INCOMING\n'); commit(c); git(c,'switch','main')
(c/'conflict.txt').write_text('CURRENT\n'); commit(c); git(c,'merge','incoming',ok=False)
for kind in ['config','data','state','cache']:
    (fixture/kind).mkdir(); os.environ['XDG_'+kind.upper()+'_HOME'] = str(fixture/kind)
os.environ['NVIM_APPNAME']='nvim'
shutil.copytree(args.source,fixture/'config/nvim')
(fixture/'data/nvim').mkdir(); (fixture/'data/nvim/lazy').symlink_to(args.plugins_dir.expanduser().resolve())
(fixture/'work').mkdir(); (fixture/'work/vscode-deps').symlink_to(args.plugins_dir.expanduser().resolve())
(fixture/'work/vscode-config').symlink_to(fixture/'config/nvim')
nvim=attach_child(['nvim','--embed','-n','-i','NONE','--cmd',
    'let g:workbench_test='+json.dumps(str(fixture))+' | let g:workbench_disable_startup=1',
    '--cmd','lua vim.lsp.enable=function() end',str(a/'main.go')],timeout=170)
passed=[]
try:
    ui=UIGrid(nvim,180,52); nvim.ui_attach(180,52,rgb=True,ext_linegrid=True); ui.drain(600)
    assert not nvim.exec_lua('return vim.lsp.get_clients()')
    nvim.command('cd '+nvim.funcs.fnameescape(str(parent)))
    nvim.exec_lua('''_G.changes_errors={};local original=vim.notify;vim.notify=function(msg,level,opts)
      if level==vim.log.levels.ERROR then changes_errors[#changes_errors+1]=tostring(msg) end;return original(msg,level,opts) end
      _G.native=function() local out={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(w).relative=='' then out[#out+1]=w end end;return out end
      require('workbench').sidebar('git',false)
    ''')
    def wait(expression, seconds=10):
        deadline=time.monotonic()+seconds
        while not nvim.exec_lua('return '+expression):
            assert time.monotonic()<deadline, expression+'\n'+nvim.command_output('messages')
            ui.drain(35)
    wait('require("repo_panel").state().loaded and not require("repo_panel").state().reading')
    nvim.exec_lua('require("repo_panel").select(...)',str(a));ui.drain(100)
    side=nvim.exec_lua('return require("workbench").side_win()')
    original=nvim.api.win_get_buf(nvim.exec_lua('return require("workbench").main()'))
    def sidebar_button(label, group='changed', path=None, cancel=False):
        row=nvim.exec_lua('''local group,path=...;if path==vim.NIL then path=nil end
          for row,node in pairs(require('repo_panel').state().nodes) do
            if (not path and node.kind=='changes_header' and node.group==group)
              or (path and node.kind=='file' and node.file.path==path and not node.staged) then return row end end''',group,path)
        assert row,(label,group,path)
        nvim.exec_lua('local win,row=...;vim.api.nvim_set_current_win(win);vim.api.nvim_win_set_cursor(win,{row,0});require("sidebar_ui").clamp(win)',side,row)
        ui.drain(60)
        line=nvim.api.buf_get_lines(nvim.api.win_get_buf(side),row-1,row,False)[0]
        index=line.index('['+label+']')
        byte=len(line[:index].encode())+2
        pos=nvim.funcs.screenpos(side,row,byte)
        assert pos['row']>0,(row,line)
        nvim.api.input_mouse('left','press','',0,pos['row']-1,pos['col']-1)
        nvim.api.input_mouse('left','release','',0,pos['row']-1,pos['col']-1);ui.drain(180)
    # Exact header targets remain usable at three sidebar widths.
    for width in [26,36,64]:
        nvim.api.win_set_width(side,width); ui.drain(100)
        sidebar_button('Open All' if width>=64 else 'Open')
        wait('require("git_changes").active()'); ui.drain(100)
        assert len(nvim.exec_lua('return native()'))==3
        assert nvim.exec_lua('return #require("git_changes").state.data.files')>=7
        assert nvim.exec_lua('return require("workbench").side_win()')==side
        nvim.exec_lua('require("git_changes").close()');ui.drain(50)
    passed.append('Open All header mouse targets at 26/36/64 columns')
    nvim.api.win_set_width(side,38);ui.drain(100);sidebar_button('Open')
    wait('require("git_changes").active()');ui.drain(200)
    data=nvim.exec_lua('''local s=require('git_changes').state;return {left=s.left,right=s.right,rows=#s.data.left,files=s.data.files,
      before=s.data.left,after=s.data.right,folds=s.data.folds,buffers=s.buffers}''')
    assert len(data['before'])==len(data['after'])
    assert 'working' in data['after'] and 'index' in data['before']
    assert 'recover deletion' in data['before'] and 'recover deletion' not in data['after']
    assert any('untracked recovery' in text for text in data['after']),data['after']
    assert len(data['folds'])>=2
    for win in [data['left'],data['right']]:
        assert not nvim.api.get_option_value('wrap',{'win':win})
        assert nvim.api.get_option_value('scrollbind',{'win':win})
        assert not nvim.api.get_option_value('modifiable',{'buf':nvim.api.win_get_buf(win)})
    passed.append('aligned combined rows, context folds, deletion and partially staged snapshots')
    main_file=next(f for f in data['files'] if f['path']=='main.go')
    for win in [data['left'],data['right']]:
        nvim.api.win_set_cursor(win,[main_file['header'],0])
        nvim.exec_lua('vim.api.nvim_win_call(...,function() vim.cmd("normal! zt") end)',win)
    ui.drain(180)
    if args.screenshots:
        args.screenshots.mkdir(parents=True,exist_ok=True);ui.save(args.screenshots/'Changes_all.png',args.font)
    # Clicking the per-file header folds BOTH panes; Open and Stage are separate.
    row=main_file['header'];pos=nvim.funcs.screenpos(data['right'],row,2)
    nvim.api.input_mouse('left','press','',0,pos['row']-1,pos['col']-1);nvim.api.input_mouse('left','release','',0,pos['row']-1,pos['col']-1);ui.drain(100)
    for win in [data['left'],data['right']]:
        assert nvim.exec_lua('return vim.api.nvim_win_call(...,function() return vim.fn.foldclosed('+str(row)+') end)',win)==row
    nvim.exec_lua('require("git_changes").file_action("fold")');ui.drain(100)
    passed.append('file header mouse collapse and synchronized folds')
    def combined_button(path,label):
        state=nvim.exec_lua('''local s=require('git_changes').state;for _,f in ipairs(s.data.files) do
          if f.path==... then return {win=s.right,row=f.header} end end''',path)
        assert state,(path,label)
        nvim.api.set_current_win(state['win']);nvim.api.win_set_cursor(state['win'],[state['row'],0])
        nvim.exec_lua('vim.cmd("normal! zt")');ui.drain(60)
        text=nvim.api.buf_get_lines(nvim.api.win_get_buf(state['win']),state['row']-1,state['row'],False)[0]
        byte=len(text[:text.index('['+label+']')].encode())+2
        pos=nvim.funcs.screenpos(state['win'],state['row'],byte)
        nvim.api.input_mouse('left','press','',0,pos['row']-1,pos['col']-1)
        nvim.api.input_mouse('left','release','',0,pos['row']-1,pos['col']-1);ui.drain(160)
    combined_button('other.go','Open')
    assert nvim.api.buf_get_name(0)==str(a/'other.go') and not nvim.exec_lua('return require("git_changes").active()')
    nvim.exec_lua('require("git_changes").open(...,false)',str(a));wait('require("git_changes").active()');ui.drain(150)
    combined_button('other.go','Stage')
    wait('not require("repo_panel").state().reading and not require("repo_panel").state().busy['+json.dumps(str(a))+']')
    wait('require("git_changes").active() and #require("git_changes").state.data.files==6')
    assert git(a,'show',':other.go')=='package main\n\nvar retries = 3\n'
    data.update(nvim.exec_lua('local s=require("git_changes").state;return {left=s.left,right=s.right,buffers=s.buffers}'))
    passed.append('combined file header Open and Stage mouse targets; stage refreshes the same two panels')
    nvim.exec_lua('require("performance").toggle()');ui.drain(80)
    assert nvim.exec_lua('for _,p in pairs(require("diff_ui").panes) do if p.win and not vim.api.nvim_win_get_config(p.win).hide then return false end end;return true')
    nvim.exec_lua('require("performance").toggle()');ui.drain(80)
    assert nvim.exec_lua('for _,p in pairs(require("diff_ui").panes) do if not p.win or vim.api.nvim_win_get_config(p.win).hide then return false end end;return true')
    passed.append('Light mode hides rulers and normal mode restores them')
    nvim.exec_lua('Snacks.notifier.hide()');ui.drain(100)
    # The ruler keeps its diff map on scroll; no new Git subprocesses.
    nvim.exec_lua('''_G.review_system=vim.system;_G.review_calls=0;vim.system=function(...) review_calls=review_calls+1;return review_system(...) end''')
    scans=nvim.exec_lua('local out={};for win,p in pairs(require("diff_ui").panes) do out[tostring(win)]=p.scans end;return out')
    pos=nvim.api.win_get_position(data['right'])
    for direction in ['down','up']:
        for _ in range(80):
            nvim.api.input_mouse('wheel',direction,'',0,pos[0]+5,pos[1]+12);ui.drain(1)
    ui.drain(100)
    assert nvim.exec_lua('return review_calls')==0
    assert nvim.exec_lua('local out={};for win,p in pairs(require("diff_ui").panes) do out[tostring(win)]=p.scans end;return out')==scans
    nvim.exec_lua('vim.system=review_system')
    passed.append('160 wheel events reuse ruler maps with zero Git subprocesses')
    # Close releases both overview scratch buffers, restores editor options.
    nvim.exec_lua('require("git_changes").close()');ui.drain(100)
    assert not nvim.exec_lua('return next(require("diff_ui").panes)~=nil')
    assert nvim.api.buf_is_valid(original)
    assert all(not nvim.api.buf_is_valid(buf) for buf in data['buffers'])
    passed.append('close restores original editor and releases scratch buffers/rulers')
    # A normal diff uses native full-row and intraline highlighting + ruler.
    nvim.exec_lua('require("git_diff").working(...,{path="main.go",x=" ",y="M"},false)',str(a))
    wait('require("git_diff").active()');ui.drain(150)
    normal=nvim.exec_lua('local s=require("git_diff").state;return {s.left,s.right}')
    for win in normal:
        assert not nvim.api.get_option_value('wrap',{'win':win})
        assert 'DiffTextAdd:Review' in nvim.api.get_option_value('winhighlight',{'win':win})
        nvim.exec_lua('vim.api.nvim_win_call(...,function() vim.cmd("normal! zR");vim.api.nvim_win_set_cursor(0,{13,0});vim.cmd("normal! zt") end)',win)
    ui.drain(120)
    # Read actual RGB cells far beyond EOL, and the changed token itself.
    colors=nvim.exec_lua('''return {before=vim.api.nvim_get_hl(0,{name='ReviewBeforeLine'}).bg,
      after=vim.api.nvim_get_hl(0,{name='ReviewAfterLine'}).bg,
      before_text=vim.api.nvim_get_hl(0,{name='ReviewBeforeText'}).bg}''')
    for win,kind in zip(normal,['before','after']):
        cell=nvim.funcs.screenpos(win,13,1)
        origin=nvim.api.win_get_position(win);width=nvim.api.win_get_width(win)
        attrs=ui.highlights[ui.grid[cell['row']-1][origin[1]+width-4][1]]
        if attrs.get('background')!=colors[kind]:
            if args.screenshots: ui.save(args.screenshots/'Failed_native.png',args.font)
            raise AssertionError((kind,attrs,colors,nvim.exec_lua('local w=...;return vim.api.nvim_win_call(w,function() return {buf=vim.api.nvim_buf_get_name(0),line=vim.api.nvim_buf_get_lines(0,12,13,false),diff=vim.wo.diff,hl=vim.fn.diff_hlID(13,1),view=vim.fn.winsaveview()} end)',win)))
    token=nvim.funcs.screenpos(normal[0],13,len(before[12].encode()))
    assert ui.highlights[ui.grid[token['row']-1][token['col']-1][1]].get('background')==colors['before_text']
    if args.screenshots:ui.save(args.screenshots/'Changes_single.png',args.font)
    passed.append('single-file native row and intraline highlights with no wrapping')
    benchmark=None
    if args.benchmark:
        samples={'off':[],'on':[]}
        for pair in range(4):
            for enabled in ([False,True] if pair%2==0 else [True,False]):
                nvim.exec_lua('''local enabled=...;local s=require('git_diff').state
                  for i,w in ipairs({s.left,s.right}) do
                    if enabled then require('diff_ui').attach(w,{role=i==1 and 'Before' or 'After'})
                    else require('diff_ui').detach(w);vim.wo[w].wrap=false;vim.wo[w].cursorlineopt='number' end
                    vim.api.nvim_win_call(w,function() vim.cmd('normal! zRggzt') end)
                  end''',enabled)
                ui.drain(120)
                def cpu():return nvim.exec_lua('local r=vim.uv.getrusage();return (r.utime.sec+r.stime.sec)*1000+(r.utime.usec+r.stime.usec)/1000')
                start_cpu=cpu();start=time.perf_counter();pos=nvim.api.win_get_position(normal[1])
                for direction in ['down','up']:
                    for _ in range(120):
                        nvim.api.input_mouse('wheel',direction,'',0,pos[0]+4,pos[1]+12);ui.drain(1)
                ui.drain(80)
                wall=(time.perf_counter()-start)*1000;used=cpu()-start_cpu
                samples['on' if enabled else 'off'].append({'cpu_ms':used,'wall_ms':wall})
        benchmark={'method':'4 alternating same-process pairs, 240 wheel events, 180x52 embedded RGB UI, no LSP; wall includes RPC/drain; no terminal/GPU measurement',
            'samples':samples,'medians':{mode:{metric:statistics.median(row[metric] for row in values) for metric in ['cpu_ms','wall_ms']} for mode,values in samples.items()}}
    nvim.exec_lua('require("git_diff").close()');ui.drain(80)
    # Repeated combined reviews keep the same number of retained buffers.
    def footprint():
        return nvim.exec_lua('''collectgarbage('collect');local count=0;for _,b in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(b) then count=count+1 end end
          return {buffers=count,lua_kib=collectgarbage('count')}''')
    settled=footprint()
    for _ in range(10):
        nvim.exec_lua('require("git_changes").open(...,false)',str(a));wait('require("git_changes").active()')
        nvim.exec_lua('require("git_changes").close()');ui.drain(30)
    repeated=footprint();assert repeated['buffers']==settled['buffers'],(settled,repeated)
    assert repeated['lua_kib']-settled['lua_kib']<1024,(settled,repeated)
    passed.append('10 Open All/close cycles retain no extra loaded buffers; settled Lua growth under 1 MiB')
    # Discard tests substitute only the user's modal choice, not file/Git I/O.
    index_before=git(a,'ls-files','-s')
    nvim.exec_lua('_G.review_select=vim.ui.select;vim.ui.select=function(items,opts,done) done(items[1]) end')
    sidebar_button('↶',path='literal[1].txt')
    assert (a/'literal[1].txt').read_text()=='literal working\n'
    passed.append('per-file discard cancellation')
    ui.drain(550)  # Two deliberate clicks, outside Neovim's double-click interval.
    nvim.exec_lua('vim.ui.select=function(items,opts,done) done(items[2]) end')
    sidebar_button('↶',path='literal[1].txt')
    wait('not require("repo_panel").state().busy['+json.dumps(str(a))+'] and not require("repo_panel").state().reading')
    assert (a/'literal[1].txt').read_text()=='literal base\n', (nvim.command_output('messages'), nvim.exec_lua('return require("repo_panel").state().busy'))
    assert (a/'literal1.txt').read_text()=='must stay modified\n'
    assert git(a,'ls-files','-s')==index_before
    # Another repo has its own recovery pointer; newer work is never replaced.
    nvim.exec_lua('require("git_discard").discard(...,require("repo_panel").state().info[...].files)',str(b))
    wait('not require("repo_panel").state().busy['+json.dumps(str(b))+'] and not require("repo_panel").state().reading')
    assert (b/'app.tsx').read_text()=='export const value = 1\n'
    (b/'app.tsx').write_text('export const value = 2\n')
    nvim.exec_lua('require("git_discard").restore(...)',str(b));ui.drain(100)
    assert (b/'app.tsx').read_text()=='export const value = 2\n'
    nvim.exec_lua('require("git_discard").restore(...)',str(a));ui.drain(220)
    wait('not require("repo_panel").state().reading')
    assert (a/'literal[1].txt').read_text()=='literal working\n'
    passed.append('literal path discard and recovery preserve similarly named files/index')
    passed.append('per-repo recovery pointers; recovery refuses newer disk edits')
    # An unsaved working buffer blocks discard without losing its draft.
    dirty=nvim.exec_lua('''local b=vim.fn.bufadd(...);vim.fn.bufload(b);vim.api.nvim_buf_set_lines(b,0,-1,false,{'unsaved'});return b''',str(a/'literal[1].txt'))
    sidebar_button('↶',path='literal[1].txt');ui.drain(100)
    assert (a/'literal[1].txt').read_text()=='literal working\n'
    assert nvim.api.buf_get_lines(dirty,0,-1,False)==['unsaved']
    nvim.api.buf_set_lines(dirty,0,-1,False,['literal working']);nvim.api.set_option_value('modified',False,{'buf':dirty})
    passed.append('discard refuses unsaved buffers')
    # Discard All is limited to the chosen repo's UNSTAGED changes.
    sidebar_button('↶')
    wait('not require("repo_panel").state().busy['+json.dumps(str(a))+'] and not require("repo_panel").state().reading')
    assert (a/'partial.txt').read_text()=='index\n'
    assert (a/'deleted.txt').read_text()=='recover deletion\n'
    assert not (a/'new dir').exists()
    assert (b/'app.tsx').read_text()=='export const value = 2\n'
    assert git(a,'ls-files','-s')==index_before
    # This recovery remains usable after reloading the module (disk manifest).
    nvim.exec_lua('package.loaded.git_discard=nil;require("git_discard").restore(...)',str(a));ui.drain(200)
    wait('not require("repo_panel").state().reading')
    assert (a/'partial.txt').read_text()=='working\n'
    assert not (a/'deleted.txt').exists()
    assert (a/'new dir/note.txt').read_text()=='untracked recovery\n'
    assert (a/'main.go').read_text()=='\n'.join(after)+'\n'
    assert git(a,'ls-files','-s')==index_before
    passed.append('Discard All/recovery handle partial staging, deleted files and untracked directories')
    # Stage per file, then Stage All via actual header hit region.
    sidebar_button('+',path='literal[1].txt')
    wait('not require("repo_panel").state().busy['+json.dumps(str(a))+'] and not require("repo_panel").state().reading')
    assert git(a,'show',':literal[1].txt')=='literal working\n'
    sidebar_button('+')
    wait('not require("repo_panel").state().busy['+json.dumps(str(a))+'] and not require("repo_panel").state().reading')
    assert not git(a,'diff','--name-only')
    assert 'working' in git(a,'show',':partial.txt')
    passed.append('per-file Stage and Stage All mouse actions')
    sidebar_button('Open',group='staged');wait('require("git_changes").active()');ui.drain(80)
    assert nvim.exec_lua('return require("git_changes").state.staged')
    assert 'base' in nvim.exec_lua('return require("git_changes").state.data.left')
    nvim.exec_lua('require("git_changes").close();vim.ui.select=review_select')
    passed.append('Open All staged uses HEAD/index snapshots')
    # Merge keeps its existing resizeable Incoming/Current/Result layout.
    nvim.exec_lua('require("repo_panel").select(...);require("git_review").open(...,"conflict.txt",false)',str(c))
    wait('package.loaded["diffview.lib"] and require("diffview.lib").get_current_view() and require("diffview.lib").get_current_view().cur_entry~=nil')
    ui.drain(250)
    panes=nvim.exec_lua('''local v=require('diffview.lib').get_current_view();local out={};for _,w in ipairs(v.cur_layout.windows) do
      out[w.file.symbol]={win=w.id,pos=vim.api.nvim_win_get_position(w.id),wrap=vim.wo[w.id].wrap,ruler=require('diff_ui').panes[w.id]~=nil} end;return out''')
    assert len(nvim.exec_lua('return native()'))==4
    assert panes['c']['pos'][1]<panes['a']['pos'][1] and panes['b']['pos'][0]>panes['a']['pos'][0]
    assert all(not p['wrap'] and p['ruler'] for p in panes.values())
    if args.screenshots:ui.save(args.screenshots/'Changes_merge.png',args.font)
    nvim.exec_lua('require("git_review").close()');ui.drain(200)
    assert not nvim.exec_lua('return next(require("diff_ui").panes)~=nil')
    passed.append('three-way merge overview rulers and cleanup')
    assert not nvim.exec_lua('return changes_errors'),nvim.exec_lua('return changes_errors')
    report={'passed':passed,'combined_rows':data['rows'],'combined_files':len(data['files']),'scroll_git_processes':0,
        'retention':{'before':settled,'after':repeated},'ruler_benchmark':benchmark}
    if args.report:args.report.write_text(json.dumps(report,indent=2))
    print(json.dumps(report),flush=True)
finally:
    try:close_child(nvim)
    finally:shutil.rmtree(fixture)
