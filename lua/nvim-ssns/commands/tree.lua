---@class SsnsCommandsTree
---Tree UI related commands
local M = {}

---Register tree UI commands
function M.register()
  local Ssns = require('nvim-ssns')

  -- :SSNS - Toggle the tree UI
  vim.api.nvim_create_user_command("SSNS", function()
    Ssns.toggle()
  end, {
    desc = "Toggle SSNS database tree",
  })

  -- :SSNSOpen - Open the tree UI
  vim.api.nvim_create_user_command("SSNSOpen", function()
    Ssns.open()
  end, {
    desc = "Open SSNS database tree",
  })

  -- :SSNSClose - Close the tree UI
  vim.api.nvim_create_user_command("SSNSClose", function()
    Ssns.close()
  end, {
    desc = "Close SSNS database tree",
  })

  -- :SSNSFloat - Open tree UI in floating window mode
  vim.api.nvim_create_user_command("SSNSFloat", function()
    Ssns.open_float()
  end, {
    desc = "Open SSNS database tree in floating window",
  })

  -- :SSNSDocked - Open tree UI in docked/split mode
  vim.api.nvim_create_user_command("SSNSDocked", function()
    Ssns.open_docked()
  end, {
    desc = "Open SSNS database tree in docked split",
  })
end

return M
