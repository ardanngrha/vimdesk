local M = {}

-- Keep the custom workbench surfaces in the active TokyoNight palette.
function M.highlights(hl, c)
  local blend = require('tokyonight.util').blend_bg
  local groups = {
    WorkbenchSidebar={bg=c.bg_sidebar,fg=c.fg},
    WorkbenchRail={bg=c.bg_dark1,fg=c.fg},
    WorkbenchHeading={bg=c.bg_sidebar,fg=c.fg,bold=true},
    WorkbenchMuted={fg=c.fg_dark},
    WorkbenchActive={bg=c.bg_visual,fg=c.fg,bold=true},
    WorkbenchSelected={bg=c.bg_highlight},
    WorkbenchAccent={fg=c.blue,bold=true},
    WorkbenchGraph1={fg=c.blue},
    WorkbenchGraph2={fg=c.purple},
    WorkbenchGraph3={fg=c.green},
    WorkbenchGraph4={fg=c.orange},
    WorkbenchRule={fg=c.border},
    WorkbenchAdded={fg=c.git.add},
    WorkbenchChanged={fg=c.git.change},
    WorkbenchRemoved={fg=c.git.delete},
    WorkbenchConflict={fg=c.yellow,bold=true},
    WorkbenchButton={bg=c.bg_highlight,fg=c.fg},
    WorkbenchPrimary={bg=c.blue,fg=c.bg_dark,bold=true},
    WorkbenchCommitInput={bg=c.bg,fg=c.fg},
    WorkbenchInputBorder={fg=c.border,bg=c.bg_sidebar},
    WorkbenchInputTitle={fg=c.fg_dark,bg=c.bg_sidebar},
    ReviewIncoming={bg=blend(c.teal,0.15),fg=c.teal,bold=true},
    ReviewCurrent={bg=c.bg_visual,fg=c.blue,bold=true},
    ReviewResult={bg=blend(c.yellow,0.12),fg=c.yellow,bold=true},
    ReviewBefore={bg=c.diff.delete,fg=c.red,bold=true},
    ReviewAfter={bg=c.diff.add,fg=c.green,bold=true},
    ReviewPath={bg=c.bg_sidebar,fg=c.fg_dark},
    ReviewBeforeLine={bg=c.diff.delete},
    ReviewBeforeText={bg=blend(c.red1,0.4),bold=true},
    ReviewAfterLine={bg=c.diff.add},
    ReviewAfterText={bg=blend(c.green2,0.4),bold=true},
    DiffviewDiffAdd={bg=c.diff.add},
    DiffviewDiffDelete={bg=c.diff.delete,fg=c.git.delete},
    DiffviewDiffChange={bg=c.diff.change},
    DiffviewDiffText={bg=c.diff.text,bold=true},
    WinSeparator={fg=c.border,bg=c.bg},
  }
  for name, value in pairs(groups) do hl[name] = value end
end

function M.tabs()
  local c = require('tokyonight.colors').setup()
  return {
    fill={bg=c.bg_dark1}, background={bg=c.bg_dark,fg=c.fg_dark},
    buffer_selected={bg=c.bg,fg=c.fg,bold=true},
    close_button={bg=c.bg_dark,fg=c.comment},
    close_button_selected={bg=c.bg,fg=c.fg_dark},
    indicator_selected={bg=c.bg,fg=c.blue},
    separator={bg=c.bg_dark,fg=c.bg_dark1},
    separator_selected={bg=c.bg,fg=c.bg_dark1},
  }
end

return M
