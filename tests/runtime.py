"""Real Neovim UI regression in disposable sibling repos; no remote services except plugin downloads."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import pynvim

ROOT = Path(__file__).resolve().parents[1]


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--data-home', type=Path, help='optional reusable TEST plugin data directory')
    cli.add_argument('--screenshots', type=Path, help='PNG directory; requires Pillow')
    cli.add_argument('--font', type=Path, help='monospace TTF for screenshots')
    args = cli.parse_args()
    if args.screenshots and not args.font:
        cli.error('--screenshots requires --font /path/to/monospace.ttf')
    with tempfile.TemporaryDirectory(prefix='vimdesk-demo-') as temporary:
        temp = Path(temporary).resolve()
        parent = temp / 'Workspace'; parent.mkdir()
        env = dict(os.environ)
        for kind in ['config', 'data', 'state', 'cache']:
            env['XDG_' + kind.upper() + '_HOME'] = str(temp / kind)
        if args.data_home:
            env['XDG_DATA_HOME'] = str(args.data_home.resolve())
        env.update(NVIM_APPNAME='vimdesk', GOTOOLCHAIN='local', GOPROXY='off')
        subprocess.run([sys.executable, str(ROOT/'scripts/install.py'), '--config-home', str(temp/'config'),
                        '--bin-dir', str(temp/'bin')], capture_output=True, check=True)
        launcher = str(temp/'bin/vimdesk')
        result = subprocess.run([launcher, '--headless', '+Lazy! restore', '+qa'], env=env,
                                capture_output=True, text=True, timeout=300)
        assert result.returncode == 0, result.stderr[-3000:]

        def git(path, *options, check=True):
            return subprocess.run(['git','-C',str(path),*options], check=check, capture_output=True, text=True).stdout.strip()

        def commit(path, message):
            git(path,'add','-A'); git(path,'commit','-m',message)

        def repository(name):
            path = parent/name; path.mkdir()
            git(path,'init','-b','main'); git(path,'config','user.name','Workbench Demo')
            git(path,'config','user.email','demo@example.invalid')
            return path

        backend, frontend, tools = [repository(name) for name in ['backend','frontend','tools']]
        before = '''package main

import "fmt"

type Service struct {
  Name string
  Retries int
}

func NewService(name string) Service {
  return Service{
    Name: name,
    Retries: 1,
  }
}

func (s Service) Status() string {
  return fmt.Sprintf("%s: ready", s.Name)
}

func main() {
  service := NewService("api")
  fmt.Println(service.Status())
}
'''
        (backend/'main.go').write_text(before)
        (backend/'go.mod').write_text('module example.invalid/demo\n\ngo 1.22\n')
        (backend/'note.txt').write_text('retry one\n')
        (backend/'.gitignore').write_text('ignored.txt\n')
        (backend/'ignored.txt').write_text('retry ignored\n')
        commit(backend,'feat: add service example')
        (backend/'main.go').write_text(before.replace('Retries: 1','Retries: 3').replace('%s: ready','%s: healthy'))
        (frontend/'app.tsx').write_text('export function App() {\n  return <main>Workbench</main>;\n}\n')
        (frontend/'note.txt').write_text('retry two\n'); commit(frontend,'feat: add frontend')
        (frontend/'app.tsx').write_text('export function App() {\n  return <main>Welcome to Workbench</main>;\n}\n')
        (tools/'release.txt').write_text('Release checklist\nStatus: draft\nReview before publishing\n')
        commit(tools,'docs: add checklist'); git(tools,'switch','-c','incoming')
        (tools/'release.txt').write_text('Release checklist\nStatus: ready for review\nReview before publishing\n')
        commit(tools,'docs: prepare review'); git(tools,'switch','main')
        (tools/'release.txt').write_text('Release checklist\nStatus: checks passing\nReview before publishing\n')
        commit(tools,'docs: record checks'); git(tools,'merge','incoming',check=False)
        for path in [backend,frontend]:
            origin = temp/(path.name+'-origin.git')
            subprocess.run(['git','init','--bare','-q',str(origin)],check=True)
            git(path,'remote','add','origin',str(origin)); git(path,'push','-u','origin','main')

        os.environ.update(env)  # Only affects this test process and its children.
        nvim = pynvim.attach('child',argv=[launcher,'--embed','-n','-i','NONE',str(parent)])
        loop = nvim._session._async_session._msgpack_stream.loop
        child = next(t.get_extra_info('subprocess') for t in loop._to_close if t.get_extra_info('subprocess') is not None)
        timer = threading.Timer(150,child.kill); timer.daemon=True; timer.start()
        from ui_grid import UIGrid
        ui = UIGrid(nvim,168,46)

        def wait(expression):
            deadline=time.monotonic()+12
            while not nvim.exec_lua('return '+expression):
                assert time.monotonic()<deadline,expression+'\n'+nvim.command_output('messages')
                ui.drain(100)

        def screenshot(name):
            if args.screenshots:
                args.screenshots.mkdir(parents=True,exist_ok=True)
                ui.save(args.screenshots/name,args.font)

        def view():
            return nvim.exec_lua('''local v=require('diffview.lib').get_current_view();if not v or not v.cur_entry then return nil end
              local out={root=v.adapter.ctx.toplevel,path=v.cur_entry.path,panes={}}
              for _,w in ipairs(v.cur_layout.windows) do if w:is_valid() then
                out.panes[w.file.symbol]={id=w.id,pos=vim.api.nvim_win_get_position(w.id),label=vim.wo[w.id].winbar,
                  lines=vim.api.nvim_buf_get_lines(w.file.bufnr,0,-1,false)} end end;return out''')

        def click(kind,root,path=''):
            node=nvim.exec_lua('''local kind,root,path=...;local w=require('workbench')
              for row,node in pairs(require('repo_panel').state().nodes or {}) do
                if node.kind==kind and node.root==root and (path=='' or node.file and node.file.path==path) then
                  return {win=w.side_win(),row=row} end end''',kind,str(root),path)
            assert node,kind+' '+path
            nvim.api.win_set_cursor(node['win'],[node['row'],0]);ui.drain(50)
            pos=nvim.funcs.screenpos(node['win'],node['row'],6)
            for action in ['press','release']:
                nvim.api.input_mouse('left',action,'',0,pos['row']-1,pos['col']-1)
            ui.drain(900)

        try:
            nvim.ui_attach(ui.width,ui.height,rgb=True,ext_linegrid=True);ui.drain(1800)
            nvim.exec_lua('''_G.test_errors={};local notify=vim.notify;vim.notify=function(msg,level,opts)
              if level==vim.log.levels.ERROR then table.insert(_G.test_errors,tostring(msg)) end;return notify(msg,level,opts) end''')
            nvim.exec_lua('require("workbench").open_file(...);require("workbench").open_git()',str(backend/'main.go'))
            wait('#require("repo_panel").state().repos==3 and not require("repo_panel").state().reading')
            assert nvim.exec_lua('return require("multi_repo").root(...)',str(frontend/'app.tsx'))==str(frontend)
            nvim.exec_lua('require("workbench").open_file(...)',str(frontend/'app.tsx'))
            assert nvim.exec_lua('return require("multi_repo").current_root()')==str(frontend)
            click('repo',backend)
            wait('vim.bo.filetype=="snacks_terminal"')
            assert nvim.exec_lua('return vim.b.workspace_repo_root')==str(backend)
            wait('table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false)," "):find("Files")~=nil')
            print('PASS multi-repo discovery, buffer detection and click → running LazyGit',flush=True)
            click('file',backend,'main.go');wait('require("git_review").active()~=nil')
            v=view();assert v['root']==str(backend)
            assert 'Retries: 1,' in '\n'.join(v['panes']['a']['lines']) and 'Retries: 3,' in '\n'.join(v['panes']['b']['lines'])
            assert v['panes']['a']['pos'][1]<v['panes']['b']['pos'][1]
            screenshot('review.png')
            git(backend,'add','main.go')
            original_head=git(backend,'rev-parse','HEAD')
            # Exercise the relocated profile's AI adapter without an account or network call.
            nvim.exec_lua('''local root=...;local system,select,executable=vim.system,vim.ui.select,vim.fn.executable
              vim.fn.executable=function(name) if name=='codex' then return 1 end;return executable(name) end
              vim.ui.select=function(items,opts,callback) callback(items[1]) end
              vim.system=function(cmd,opts,callback)
                if cmd[2]==vim.fn.stdpath('config')..'/scripts/ai_commit.py' then
                  assert(cmd[1]==vim.fn.exepath('python3') and cmd[4]=='codex' and opts.cwd==root)
                  vim.defer_fn(function() callback({code=0,stdout='fix: refresh service status',stderr=''}) end,50)
                  return {}
                end
                return system(cmd,opts,callback)
              end
              require('scm').generate()
              vim.system,vim.ui.select,vim.fn.executable=system,select,executable''',str(backend))
            wait('require("repo_panel").state().drafts['+repr(str(backend))+']=="fix: refresh service status"')
            assert git(backend,'rev-parse','HEAD')==original_head
            git(backend,'reset','HEAD','--','main.go')
            print('PASS AI draft routing through relocated config with a mocked provider; no automatic commit',flush=True)
            side=nvim.exec_lua('return require("workbench").side_win()');old=nvim.api.win_get_width(side)
            for action,col in [('press',old),('drag',old+4),('release',old+4)]:
                nvim.api.input_mouse('left',action,'',0,8,col);ui.drain(80)
            assert nvim.api.win_get_width(side)==old+4
            click('repo',tools);click('file',tools,'release.txt')
            v=view();a,b,c=(v['panes'][k] for k in ['a','b','c'])
            assert c['pos'][1]<a['pos'][1] and b['pos'][0]>a['pos'][0]
            assert 'Incoming' in c['label'] and 'Current' in a['label'] and 'Result' in b['label']
            screenshot('conflicts.png')
            nvim.api.set_current_win(b['id']);nvim.api.win_set_cursor(b['id'],[3,0])
            nvim.exec_lua('require("diffview.actions").conflict_choose("theirs")()');ui.drain(300)
            assert 'Status: ready for review' in nvim.current.buffer[:]
            nvim.command('write');nvim.exec_lua('require("git_review").accept_click(5,1,"l")');ui.drain(400)
            assert git(tools,'ls-files','--unmerged')==''
            nvim.exec_lua('require("scm").continue_merge()');ui.drain(800)
            assert len(git(tools,'rev-list','--parents','-n','1','HEAD').split())==3
            print('PASS Before/After, sidebar resize, three-pane conflict and accept/save/stage/continue merge',flush=True)
            nvim.exec_lua('require("git_review").close();require("repo_panel").fetch(true)')
            wait('not require("repo_panel").state().fetching')
            assert nvim.exec_lua('local s=require("repo_panel").state();for _,r in ipairs(s.repos) do if not s.fetched[r].ok then return false end end;return true')
            nvim.exec_lua('require("workbench").sidebar("search",true)');ui.drain(500)
            nvim.exec_lua('local s=require("workspace_search");vim.api.nvim_buf_set_lines(require("search_box").fields.query.buf,0,-1,false,{"retry"});s.scope="all";s.run()')
            wait('not require("workspace_search").running')
            assert nvim.exec_lua('return #require("workspace_search").results')==2
            nvim.exec_lua('local s=require("workspace_search");vim.api.nvim_buf_set_lines(require("search_box").fields.replacement.buf,0,-1,false,{"attempt"});s.preview_replace(...)','backend/note.txt');ui.drain(400)
            assert nvim.exec_lua('return require("replace_review").state~=nil')
            screenshot('search.png')
            nvim.exec_lua('require("workspace_search").apply_preview()');ui.drain(250)
            assert (backend/'note.txt').read_text()=='retry one\n'
            buf=nvim.funcs.bufnr(str(backend/'note.txt'));assert nvim.api.buf_get_lines(buf,0,-1,False)==['attempt one']
            assert not nvim.exec_lua('return require("workspace_search").error')
            assert nvim.exec_lua('return #_G.test_errors')==0,nvim.exec_lua('return _G.test_errors')
            print('PASS local Fetch All, workspace search, selected replacement without disk write',flush=True)
            print('PASS '+nvim.command_output('version').splitlines()[0],flush=True)
        finally:
            try:
                nvim.command('qa!',async_=True);child.wait(timeout=3)
            except (EOFError,OSError,subprocess.TimeoutExpired):
                if child.poll() is None:
                    child.kill();child.wait(timeout=3)
            finally:
                timer.cancel();nvim.close()


if __name__=='__main__':
    main()
