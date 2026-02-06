-- SSNS plugin entry point
-- This file is automatically loaded by Neovim
-- For lazy.nvim: with lazy=true, this file is NOT sourced until plugin loads
-- Commands are registered in setup() - see lua/nvim-ssns/commands/

-- Prevent loading twice
if vim.g.loaded_ssns then
  return
end
vim.g.loaded_ssns = 1

-- Register .ssns filetype for ETL scripts
vim.filetype.add({
  extension = {
    ssns = "ssns",
  },
  pattern = {
    [".*%.etl%.sql"] = "ssns",  -- Alternative: .etl.sql files
  },
})

-- Commands will be registered when user calls setup()
-- But we can provide a basic command to check if plugin is loaded
vim.api.nvim_create_user_command("SSNSVersion", function()
  local ssns = require('nvim-ssns')
  vim.notify(string.format("SSNS version: %s", ssns.get_version()), vim.log.levels.INFO)
end, {
  desc = "Show SSNS version",
})
