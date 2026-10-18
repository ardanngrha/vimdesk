local function plugin(repo, opts)
  opts=opts or {}; opts[1]=repo
  return opts
end
return {
  plugin('akinsho/bufferline.nvim', { lazy=false, dependencies={ 'folke/tokyonight.nvim' },
    config=function() require('editor_ui').setup_tabs() end }),
  plugin('folke/edgy.nvim', { lazy=false, dependencies={ 'folke/snacks.nvim' },
    config=function() require('workbench').setup_layout() end }),
  plugin('folke/trouble.nvim', { cmd='Trouble', opts={ focus=true, auto_preview=false,
    icons={indent={top='│ ',middle='├ ',last='└ ',fold_open='v ',fold_closed='> ',ws='  '},
      folder_closed='> ',folder_open='v ',kinds={},},
    open_no_results=true, warn_no_results=false, win={ position='bottom', size=11 },
    modes={ diagnostics={ format='{severity} {message} {item.source} {code} {pos}',
      groups={{'directory'},{'filename',format='{basename} {count}'}},
      filter={function(item)
      return item.filename and vim.startswith(item.filename, vim.fn.getcwd() .. '/')
    end} } },
  } }),
  plugin('folke/persistence.nvim', { lazy=false, opts={ branch=false, need=1 } }),
}
