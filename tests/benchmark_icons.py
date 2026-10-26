"""Paired Neovim UI benchmark for Files icons, navigation and Light mode.

Measures Neovim process CPU/RSS and embedded UI response time, not terminal GPU.
No plugin downloads or real project mutations are performed by this script.
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

cli=argparse.ArgumentParser(description=__doc__)
cli.add_argument('--before',type=Path,required=True)
cli.add_argument('--after',type=Path,required=True)
cli.add_argument('--plugins-dir',type=Path,required=True)
cli.add_argument('--pairs',type=int,default=7)
cli.add_argument('--within-pairs',type=int,default=8)
cli.add_argument('--report',type=Path,required=True)
cli.add_argument('--screenshots',type=Path)
cli.add_argument('--font',type=Path)
cli.add_argument('--comparison',choices=['icons','navigation','light'],default='icons',help='expected icon state for old/new configs')
args=cli.parse_args()
if args.pairs<0 or args.within_pairs<0 or args.pairs+args.within_pairs==0: cli.error('at least one non-negative sample group is required')
if args.screenshots and not args.font: cli.error('--screenshots requires --font')
fixture=Path(tempfile.mkdtemp(prefix='vimdesk-icons-bench-')).resolve()
workspace=fixture/'Workspace';workspace.mkdir()
extensions=['go','rs','py','tsx','jsx','js','ts','lua','json','md','yaml','toml']
repos=[]
for number in range(17):
    repo=workspace/f'repo-{number:02d}';repo.mkdir();repos.append(repo)
    (repo/'note.txt').write_text('Benchmark entry file\n')
    (repo/'src').mkdir();(repo/'tests').mkdir()
    for index in range(240):
        (repo/f'file-{index:03d}.{extensions[index%len(extensions)]}').write_text('Fixture only\n')
    for command in [('init','-q','-b','main'),('config','user.name','Icon Benchmark'),('config','user.email','benchmark@example.invalid'),('add','.'),('commit','-qm','feat: benchmark fixture')]:
        subprocess.run(['git','-C',str(repo),*command],check=True,capture_output=True)
for label,source in [('before',args.before),('after',args.after)]:
    profile=fixture/label;profile.mkdir()
    for kind in ['config','data','state','cache']: (profile/kind).mkdir()
    shutil.copytree(source,profile/'config/nvim')
    # Never install/update plugins during a timed run.
    init=profile/'config/nvim/init.lua';text=init.read_text()
    marker='checker = { enabled = false }';assert marker in text
    init.write_text(text.replace(marker,'install = { missing = false }, '+marker))
    (profile/'data/nvim').mkdir();(profile/'data/nvim/lazy').symlink_to(args.plugins_dir.resolve())
    (profile/'work').mkdir();(profile/'work/vscode-deps').symlink_to(args.plugins_dir.resolve());(profile/'work/vscode-config').symlink_to(profile/'config/nvim')
print('Fixture ready: 17 repos / 4097 files',flush=True)

def run(label,warmup=False,within=False):
    profile=fixture/label
    for kind in ['config','data','state','cache']: os.environ['XDG_'+kind.upper()+'_HOME']=str(profile/kind)
    os.environ['NVIM_APPNAME']='nvim'
    startup_log=profile/'cache/startup.log';startup_log.write_text('')
    nvim=attach_child(['nvim','--embed','-n','-i','NONE','--startuptime',str(startup_log),'--cmd',
      'let g:workbench_test='+json.dumps(str(profile))+' | let g:workbench_disable_startup=1',str(repos[0]/'note.txt')],timeout=45)
    try:
        ui=UIGrid(nvim,160,44);nvim.ui_attach(160,44,rgb=True,ext_linegrid=True)
        def wait(expression,seconds=12):
            deadline=time.monotonic()+seconds
            while not nvim.exec_lua('return '+expression):
                assert time.monotonic()<deadline,expression+'\n'+nvim.command_output('messages')
                ui.drain(5)
        ui.drain(650)
        startup=nvim.exec_lua('return {cpu=require("lazy").stats().startuptime,mini=MiniIcons~=nil}')
        assert startup['cpu']>0,'No UI startup CPU sample'
        markers=[float(line.split()[0]) for line in startup_log.read_text().splitlines() if 'NVIM STARTED' in line]
        assert markers,startup_log.read_text()
        startup_wall=markers[-1]
        print(json.dumps({'phase':'editor ready','variant':label,'startup_ms':startup_wall}),flush=True)
        assert not startup['mini'],'Icons provider was loaded before opening Files'
        nvim.command('cd '+nvim.funcs.fnameescape(str(workspace)))
        nvim.exec_lua('''_G.icon_bench_errors={};local notify=vim.notify;vim.notify=function(msg,level,opts)
          if level==vim.log.levels.ERROR then table.insert(icon_bench_errors,tostring(msg)) end;return notify(msg,level,opts) end
          _G.bench_sample=function() local r=vim.uv.getrusage();return {cpu=(r.utime.sec+r.utime.usec/1e6+r.stime.sec+r.stime.usec/1e6)*1000,
            rss=vim.uv.resident_set_memory()/1048576,heap=collectgarbage('count')/1024} end
          vim.o.mousescroll='ver:10,hor:6'
        ''')
        initial=nvim.exec_lua('return bench_sample()');opened=time.perf_counter()
        nvim.exec_lua('''local paths=...;local tree=require('snacks.explorer.tree');for _,path in ipairs(paths) do tree:open(path) end
          require('workbench').sidebar('explorer',true)''',[str(p) for p in repos])
        wait('''(function() local p=Snacks.picker.get({source='explorer'})[1];return p and not p.finder:running() and p.list:count()>=4097 end)()''')
        ui.drain(120)
        files_open_wall=(time.perf_counter()-opened)*1000
        files_sample=nvim.exec_lua('return bench_sample()')
        nvim.exec_lua('collectgarbage("collect")')
        settled=nvim.exec_lua('return bench_sample()')
        enabled=nvim.exec_lua('local p=Snacks.picker.get({source="explorer"})[1];return p.opts.icons.files.enabled')
        expected=(label=='after') if args.comparison=='icons' else (label=='before' or args.comparison=='navigation')
        assert enabled==expected,(label,enabled)
        assert nvim.exec_lua('return MiniIcons~=nil')==expected
        def scroll():
            nvim.exec_lua('local p=Snacks.picker.get({source="explorer"})[1];p:focus("list");p.list:move(1,true,true)');ui.drain(60)
            pos=nvim.exec_lua('local p=Snacks.picker.get({source="explorer"})[1];return vim.fn.screenpos(p.list.win.win,10,8)')
            before=nvim.exec_lua('return bench_sample()');clock=time.perf_counter()
            for direction in ['down','up']:
                for _ in range(120):
                    nvim.api.input_mouse('wheel',direction,'',0,pos['row']-1,pos['col']-1);ui.drain(2)
            ui.drain(80)
            elapsed=(time.perf_counter()-clock)*1000;after=nvim.exec_lua('return bench_sample()')
            return {'cpu_ms':after['cpu']-before['cpu'],'wall_ms':elapsed,'rss_mib':after['rss']}
        cold=scroll();warm=scroll()
        nvim.exec_lua('collectgarbage("collect")');final=nvim.exec_lua('return bench_sample()')
        ui.drain(300)
        idle_begin=nvim.exec_lua('return bench_sample()');ui.drain(1000);idle_end=nvim.exec_lua('return bench_sample()')
        assert nvim.exec_lua('return icon_bench_errors')==[],nvim.exec_lua('return icon_bench_errors')
        assert not nvim.command_output('messages'),nvim.command_output('messages')
        glyphs={}
        if expected:
            glyphs=nvim.exec_lua('''local result={};for _,extension in ipairs({'go','rs','py','tsx','js','lua','json'}) do
              local glyph,hl=MiniIcons.get('file','example.'..extension);result[extension]={glyph=glyph,highlight=hl,width=vim.fn.strdisplaywidth(glyph)} end;return result''')
            assert len({v['glyph'] for v in glyphs.values()})>=5,glyphs
        if warmup and args.screenshots:
            nvim.exec_lua('local p=Snacks.picker.get({source="explorer"})[1];p.list:move(1,true,true)');ui.drain(80)
            args.screenshots.mkdir(parents=True,exist_ok=True);ui.save(args.screenshots/(label+'.png'),args.font)
        result={'variant':label,'startup_cpu_ms':startup['cpu'],'startup_wall_ms':startup_wall,'files_open_cpu_ms':files_sample['cpu']-initial['cpu'],
          'files_open_wall_ms':files_open_wall,'files_rss_mib':settled['rss'],'files_heap_mib':settled['heap'],
          'idle_cpu_ms_per_second':idle_end['cpu']-idle_begin['cpu'],'cold_scroll_cpu_ms':cold['cpu_ms'],'cold_scroll_wall_ms':cold['wall_ms'],
          'warm_scroll_cpu_ms':warm['cpu_ms'],'warm_scroll_wall_ms':warm['wall_ms'],'after_scroll_rss_mib':final['rss'],'after_scroll_heap_mib':final['heap'],
          'glyphs':glyphs,'items':nvim.exec_lua('return Snacks.picker.get({source="explorer"})[1].list:count()'),
          'tree_visible_rows':nvim.exec_lua('return Snacks.picker.get({source="explorer"})[1].list:height()'),
          'watchers':nvim.exec_lua('return vim.tbl_count(require("snacks.explorer.watch")._watches)')}
        if within:
            if args.comparison=='light':
                nvim.exec_lua('vim.notify=function(msg,level) if level==vim.log.levels.ERROR then table.insert(icon_bench_errors,tostring(msg)) end end')
            samples=[]
            for pair in range(args.within_pairs):
                for enabled in ([False,True] if pair%2==0 else [True,False]):
                    if args.comparison=='light':
                        nvim.exec_lua('if require("performance").enabled()~=(...) then require("performance").toggle() end',enabled)
                        ui.drain(180)
                        wait('''(function() local p=Snacks.picker.get({source='explorer'})[1];return p and not p.finder:running() and p.list:count()>=4097 end)()''')
                    else:
                        nvim.exec_lua('''local enabled=...;local p=Snacks.picker.get({source='explorer'})[1]
                          if p.opts.icons.files.enabled~=enabled then require('workbench').toggle_file_icons() end''',enabled)
                        ui.drain(80)
                    samples.append({'pair':pair+1,'light' if args.comparison=='light' else 'icons':enabled,**scroll()})
            assert nvim.exec_lua('return icon_bench_errors')==[],nvim.exec_lua('return icon_bench_errors')
            result['within_process']=samples
        print(json.dumps({'warmup':warmup,**{k:v for k,v in result.items() if k!='glyphs'}}),flush=True)
        return result
    finally: close_child(nvim)

try:
    warmups=[run('before',True),run('after',True)]
    runs=[]
    for pair in range(args.pairs):
        for label in (['before','after'] if pair%2==0 else ['after','before']):
            runs.append({'pair':pair+1,**run(label)})
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps({'runs':runs,'warmups':warmups},indent=2))
    controlled=run('after',within=True)['within_process'] if args.within_pairs else []
    toggle='light' if args.comparison=='light' else 'icons'
    controlled_summary={}
    for metric in ['cpu_ms','wall_ms']:
        off=[r[metric] for r in controlled if not r[toggle]];on=[r[metric] for r in controlled if r[toggle]]
        if not off: continue
        a,b=statistics.median(off),statistics.median(on)
        differences=[next(r[metric] for r in controlled if r['pair']==pair and r[toggle])-
          next(r[metric] for r in controlled if r['pair']==pair and not r[toggle]) for pair in range(1,args.within_pairs+1)]
        controlled_summary[metric]={'off_median':a,'on_median':b,'delta':b-a,'delta_pct':(b-a)/a*100 if a else None,
          'paired_delta_median':statistics.median(differences),'off_range':[min(off),max(off)],'on_range':[min(on),max(on)]}
    metrics=[k for k in runs[0] if k.endswith(('_ms','_mib','_second'))] if runs else []
    summary={}
    for metric in metrics:
        before=[r[metric] for r in runs if r['variant']=='before'];after=[r[metric] for r in runs if r['variant']=='after']
        a,b=statistics.median(before),statistics.median(after)
        summary[metric]={'before_median':a,'after_median':b,'delta':b-a,'delta_pct':(b-a)/a*100 if a else None,
          'before_range':[min(before),max(before)],'after_range':[min(after),max(after)]}
    report={'method':{'comparison':args.comparison,'paired_repetitions':args.pairs,'within_process_pairs':args.within_pairs,'warmups_discarded':2,'repos':17,'regular_files':17*241,'mixed_extensions':extensions,
      'ui_cells':[160,44],'scroll_events_each_phase':240,'rows_per_wheel':10,'idle_seconds':1,'startup':'new process, filesystem/code caches primed',
      'memory':'Neovim current resident memory; full Lua GC before steady samples','cpu':'Neovim user+system time; child Git processes excluded',
      'limits':['Embedded RGB UI; Warp/WindowServer GPU not measured','LSP inactive on the plain text entry file','Synthetic expanded sibling repositories, not every real workload']},
      'summary':summary,'warmups':warmups,'runs':runs,'within_process_scroll':controlled,'within_process_summary':controlled_summary}
    args.report.write_text(json.dumps(report,indent=2));print(json.dumps({'summary':summary}),flush=True)
finally: shutil.rmtree(fixture)
