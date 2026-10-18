local M = {}
M.parsers = { 'lua', 'vim', 'vimdoc', 'query', 'go', 'gomod', 'gowork', 'rust',
  'python', 'javascript', 'typescript', 'tsx', 'json', 'jsonc', 'html', 'css',
  'markdown', 'markdown_inline', 'yaml', 'bash' }

function M.setup()
  vim.api.nvim_create_user_command('WorkbenchDoctor', function()
    local lines = { 'Workbench · dependencies', '' }
    for _, tool in ipairs({ 'git', 'lazygit', 'rg', 'fd', 'python3', 'tree-sitter',
      'cc', 'gopls', 'typescript-language-server', 'rust-analyzer', 'pyright', 'ruff', 'codex', 'claude' }) do
      lines[#lines + 1] = (vim.fn.executable(tool) == 1 and '[ok] ' or '[--] ') .. tool
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Language servers and AI agents are optional; see docs/installation.md.'
    require('workbench').log('Doctor', table.concat(lines, '\n'))
    require('workbench').bottom('output', true)
  end, { desc = 'Show installed workbench dependencies' })
  vim.api.nvim_create_user_command('WorkbenchParsers', function()
    if vim.fn.executable('tree-sitter') == 0 or vim.fn.executable('cc') == 0 then
      vim.notify('Install tree-sitter CLI >=0.26.1 and a C compiler first.', vim.log.levels.ERROR)
      return
    end
    require('nvim-treesitter').install(M.parsers)
  end, { desc = 'Install syntax parsers for the supported languages' })
end

return M
