---@class SsnsCommandsQuery
---Query buffer and history related commands
local M = {}

---Register query commands
function M.register()
  local Ssns = require('nvim-ssns')

  -- :SSNSQuery - Open a new query buffer
  vim.api.nvim_create_user_command("SSNSQuery", function()
    Ssns.new_query()
  end, {
    desc = "Open a new SSNS query buffer",
  })

  -- :SSNSHistory - Show query history
  vim.api.nvim_create_user_command("SSNSHistory", function()
    Ssns.show_history()
  end, {
    desc = "Show query execution history",
  })

  -- :SSNSHistoryClear - Clear query history
  vim.api.nvim_create_user_command("SSNSHistoryClear", function()
    Ssns.clear_history()
  end, {
    desc = "Clear all query history",
  })

  -- :SSNSHistoryExport - Export query history
  vim.api.nvim_create_user_command("SSNSHistoryExport", function(opts)
    Ssns.export_history(opts.args)
  end, {
    nargs = "?",
    desc = "Export query history to file",
    complete = "file",
  })

  -- :SSNSSearch - Search database objects
  vim.api.nvim_create_user_command("SSNSSearch", function()
    Ssns.show_object_search()
  end, {
    desc = "Search database objects (tables, views, procedures, etc.)",
  })
end

return M
