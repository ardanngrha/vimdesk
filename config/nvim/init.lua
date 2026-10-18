if vim.fn.has('nvim-0.12') == 0 then error('vimdesk requires Neovim 0.12 or newer') end
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Keep editor tools available even when launched from a GUI terminal.
local tool_paths = {
  vim.fn.stdpath('data') .. '/tools/node_modules/.bin',
  vim.fn.expand('~/go/bin'), vim.fn.expand('~/.cargo/bin'), '/opt/homebrew/bin', '/usr/local/bin', vim.fn.expand('~/.local/bin'),
}
vim.env.PATH = table.concat(tool_paths, ':') .. ':' .. (vim.env.PATH or '')
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.termguicolors = true
vim.opt.signcolumn = 'yes'
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartcase = true
vim.opt.ignorecase = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.splitkeep = 'screen'
vim.opt.sessionoptions = { 'buffers', 'curdir', 'tabpages', 'winsize', 'folds' }
vim.opt.updatetime = 250
vim.opt.scrolloff = 5
vim.opt.clipboard = 'unnamedplus'
vim.opt.undofile = true
vim.opt.confirm = true
vim.opt.autochdir = false -- workspace stays at the parent; LSP/Git use file roots.
vim.api.nvim_create_autocmd('FileType', { pattern = { 'rust', 'python' },
  callback = function() vim.opt_local.shiftwidth = 4; vim.opt_local.tabstop = 4 end })
vim.opt.laststatus = 3
vim.opt.cursorline = true
vim.opt.showmode = false
vim.opt.winborder = 'rounded'
vim.opt.pumheight = 12
vim.opt.timeoutlen = 500
vim.opt.fillchars:append({ eob = ' ' })
vim.diagnostic.config({ virtual_text = false, severity_sort = true, underline = true,
  float = { border = 'rounded' }, signs = { text = {
    [vim.diagnostic.severity.ERROR] = 'E', [vim.diagnostic.severity.WARN] = 'W',
    [vim.diagnostic.severity.INFO] = 'I', [vim.diagnostic.severity.HINT] = 'H',
  } } })
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', { desc = 'Save file' })
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<cr>')
vim.keymap.set('t', '<C-\\><C-n>', '<C-\\><C-n>', { desc = 'Terminal normal mode' })

local lazy_path = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazy_path) then
  local result = vim.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazy_path }, { text = true }):wait()
  if result.code ~= 0 then error('Could not install lazy.nvim: ' .. (result.stderr or '')) end
  local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath('config') .. '/lazy-lock.json'), '\n'))
  local checkout = vim.system({ 'git', '-C', lazy_path, 'checkout', lock['lazy.nvim'].commit }, { text = true }):wait()
  if checkout.code ~= 0 then error('Could not pin lazy.nvim: ' .. (checkout.stderr or '')) end
end
vim.opt.rtp:prepend(lazy_path)
local plugins = {
  {
    'folke/tokyonight.nvim', lazy = false, priority = 1200,
    opts = { style = 'moon', transparent = false, terminal_colors = true,
      styles = { comments = { italic = true }, keywords = { italic = false },
        sidebars = 'dark', floats = 'dark' },
      on_colors = function(colors) colors.border = '#414868' end,
      on_highlights = function(highlights, colors) require('workbench_theme').highlights(highlights, colors) end },
    config = function(_, opts)
      require('tokyonight').setup(opts)
      vim.cmd.colorscheme('tokyonight-moon')
    end,
  },
  { 'nvim-lualine/lualine.nvim', lazy = false, dependencies = { 'folke/tokyonight.nvim' },
    config = function() require('editor_ui').setup() end },
  {
    'folke/which-key.nvim', event = 'VeryLazy',
    opts = { preset = 'modern', delay = 300, icons = { mappings = false, separator = '→',
        keys = { Up = '↑', Down = '↓', Left = '←', Right = '→',
          C = 'Ctrl+', M = 'Alt+', D = 'Cmd+', S = 'Shift+', CR = 'Enter',
          Esc = 'Esc', BS = 'Backspace', Space = 'Space', Tab = 'Tab', NL = 'Enter',
          ScrollWheelDown = 'Scroll ↓', ScrollWheelUp = 'Scroll ↑',
          F1 = 'F1', F2 = 'F2', F3 = 'F3', F4 = 'F4', F5 = 'F5', F6 = 'F6',
          F7 = 'F7', F8 = 'F8', F9 = 'F9', F10 = 'F10', F11 = 'F11', F12 = 'F12' } },
      win = { border = 'rounded' },
      spec = {
        { '<leader>f', group = 'Find' }, { '<leader>g', group = 'Git' },
        { '<leader>c', group = 'Code / conflicts' }, { '<leader>b', group = 'Buffers' },
        { '<leader>r', group = 'Refactor' }, { '<leader>u', group = 'View' },
      } },
    keys = { { '<leader>?', function() require('which-key').show({ global = true }) end,
      desc = 'Show shortcut guide' } },
  },
  {
    'folke/snacks.nvim', lazy = false, priority = 1000,
    opts = {
      bigfile = { enabled = true },
      input = { enabled = true },
      explorer = { enabled = true, replace_netrw = false },
      indent = { enabled = true, animate = { enabled = false } },
      notifier = { enabled = true, timeout = 2500, style = 'compact',
        icons = { error = 'E ', warn = 'W ', info = 'i ', debug = 'D ', trace = 'T ' } },
      dashboard = { enabled = true, width = 52,
        preset = { header = 'NEOVIM\n\nA quiet workspace for code & Git', keys = {
          { key = 'f', desc = 'Find a file', action = '<leader>ff', icon = '' },
          { key = 'e', desc = 'Explore workspace', action = '<leader>e', icon = '' },
          { key = 'g', desc = 'Choose a Git repository', action = '<leader>gG', icon = '' },
          { key = 'r', desc = 'Recent files', action = function() Snacks.picker.recent() end, icon = '' },
          { key = '?', desc = 'Shortcut guide', action = '<leader>?', icon = '' },
          { key = 'q', desc = 'Quit', action = ':qa', icon = '' },
        } }, sections = { { section = 'header', padding = 2 }, { section = 'keys', gap = 1, padding = 1 } } },
      picker = { enabled = true, prompt = '> ', layout = { preset = 'default' },
        icons = {
          files = { enabled = false, dir = '> ', dir_open = 'v ', file = '  ' },
          ui = { live = '* ', selected = '+ ', unselected = '  ' },
          git = { added = '+', deleted = '-', renamed = '>', unmerged = '!', commit = 'git ', ignored = '-' },
          diagnostics = { Error = 'E ', Warn = 'W ', Hint = 'H ', Info = 'I ' },
        }, sources = { explorer = { layout = { preset = 'sidebar', preview = false,
          layout = { width = 42, min_width = 42 } } } } },
      terminal = { enabled = true },
      lazygit = { enabled = true, config = { gui = { nerdFontsVersion = '' } },
        win = { width = 0.96, height = 0.94, border = 'rounded' } },
    },
    config = function(_, opts)
      require('snacks').setup(opts)
      require('multi_repo').setup()
      require('workbench').setup()
      vim.keymap.set('n', '<leader>ff', function() Snacks.picker.files({ cwd = vim.fn.getcwd(), hidden = true, ignored = true }) end,
        { desc = 'Find files in parent workspace' })
      vim.keymap.set('n', '<leader>fb', function() Snacks.picker.buffers() end, { desc = 'Buffers' })
      vim.keymap.set('n', '<leader>bd', function() Snacks.bufdelete() end, { desc = 'Close buffer' })
      vim.keymap.set('n', '<leader>uh', function() Snacks.notifier.show_history() end, { desc = 'Notification history' })
      vim.keymap.set('n', '<S-h>', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })
      vim.keymap.set('n', '<S-l>', '<cmd>bnext<cr>', { desc = 'Next buffer' })
    end,
  },
  {
    'saghen/blink.cmp', version = '1.*', lazy = false,
    opts = {
      keymap = { preset = 'default' },
      fuzzy = { implementation = 'lua' },
      completion = {
        list = { selection = { preselect = false, auto_insert = false } },
        documentation = { auto_show = true, window = { border = 'rounded' } },
        menu = { border = 'rounded', draw = { columns = { { 'label', 'label_description', gap = 1 }, { 'kind' } } } },
      },
      signature = { enabled = true, window = { border = 'rounded' } },
    },
  },
  {
    'neovim/nvim-lspconfig', lazy = false, dependencies = { 'saghen/blink.cmp' },
    config = function()
      local capabilities = require('blink.cmp').get_lsp_capabilities()
      vim.lsp.config('gopls', { capabilities = capabilities,
        settings = { gopls = { gofumpt = true, staticcheck = true, usePlaceholders = true } } })
      vim.lsp.config('ts_ls', { capabilities = capabilities,
        cmd = { 'typescript-language-server', '--stdio' },
        -- Nearest project config wins, so sibling apps never share an accidental parent root.
        root_dir = function(buf, on_dir)
          local root = vim.fs.root(buf, { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' })
          if root then on_dir(root) end
        end,
      })
      vim.lsp.config('rust_analyzer', { capabilities = capabilities,
        settings = { ['rust-analyzer'] = { check = { command = 'clippy' } } } })
      vim.lsp.config('pyright', { capabilities = capabilities,
        root_dir = function(buf, on_dir)
          local root = vim.fs.root(buf, { 'pyproject.toml', 'pyrightconfig.json', 'setup.py',
            'setup.cfg', 'requirements.txt', 'Pipfile', '.git' })
          if root then on_dir(root) else on_dir(vim.fs.dirname(vim.api.nvim_buf_get_name(buf))) end
        end,
        before_init = function(_, config)
          local root = config.root_dir or vim.fn.getcwd()
          local candidates = { root .. '/.venv/bin/python', root .. '/venv/bin/python' }
          if vim.env.VIRTUAL_ENV then table.insert(candidates, vim.env.VIRTUAL_ENV .. '/bin/python') end
          for _, candidate in ipairs(candidates) do
            if vim.fn.executable(candidate) == 1 then
              config.settings.python.pythonPath = candidate
              return
            end
          end
          config.settings.python.pythonPath = vim.fn.exepath('python3')
        end,
        settings = { python = { analysis = { typeCheckingMode = 'basic',
          autoImportCompletions = true, diagnosticMode = 'openFilesOnly' } } },
      })
      vim.lsp.config('ruff', { capabilities = capabilities,
        root_dir = function(buf, on_dir)
          on_dir(vim.fs.root(buf, { 'pyproject.toml', 'ruff.toml', '.ruff.toml', '.git' })
            or vim.fs.dirname(vim.api.nvim_buf_get_name(buf)))
        end,
        on_attach = function(client) client.server_capabilities.hoverProvider = false end,
      })
      vim.lsp.enable({ 'gopls', 'ts_ls', 'rust_analyzer', 'pyright', 'ruff' })
      vim.api.nvim_create_autocmd('LspAttach', { callback = function(ev)
        local function map(key, action, desc) vim.keymap.set('n', key, action, { buffer = ev.buf, desc = desc }) end
        map('gd', vim.lsp.buf.definition, 'Definition')
        map('grr', vim.lsp.buf.references, 'References')
        map('K', vim.lsp.buf.hover, 'Documentation')
        map('<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
        map('<leader>ca', vim.lsp.buf.code_action, 'Code action')
        map('<leader>cf', function() vim.lsp.buf.format({ async = false, timeout_ms = 5000,
          filter = function(client) return vim.bo.filetype ~= 'python' or client.name == 'ruff' end }) end, 'Format file')
        map('<leader>cd', vim.diagnostic.open_float, 'Diagnostics')
      end })
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter', branch = 'main', lazy = false, build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').setup({})
      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'rust', 'python', 'go', 'gomod', 'gowork', 'javascript', 'javascriptreact', 'typescript',
          'typescriptreact', 'tsx', 'json', 'jsonc', 'html', 'css', 'lua', 'markdown', 'yaml', 'sh' },
        callback = function(ev) pcall(vim.treesitter.start, ev.buf) end,
      })
    end,
  },
  { 'lewis6991/gitsigns.nvim', lazy = false,
    opts = { signs = { add = { text = '+' }, change = { text = '~' }, delete = { text = '_' } },
      on_attach = function(buf)
        local gs = require('gitsigns')
        vim.keymap.set('n', '<leader>gh', gs.preview_hunk, { buffer = buf, desc = 'Preview Git hunk' })
        vim.keymap.set('n', '<leader>gs', gs.stage_hunk, { buffer = buf, desc = 'Stage Git hunk' })
      end },
  },
  {
    'sindrets/diffview.nvim', dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewRefresh' },
    opts = function() return require('git_review').options() end,
    config = function(_,opts) require('git_review').setup(opts) end,
  },
}
vim.list_extend(plugins, require('workbench_plugins'))
require('lazy').setup(plugins, { lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json',
  checker = { enabled = false }, change_detection = { notify = false },
  ui = { icons = { loaded = '+', not_loaded = '-', cmd = ':', event = '@', ft = 'FT',
    init = 'I', keys = 'K', plugin = 'P', runtime = 'R', source = 'S', start = '>', task = 'T', lazy = 'Z' } } })

require('workbench_health').setup()
