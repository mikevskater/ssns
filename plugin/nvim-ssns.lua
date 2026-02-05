-- SSNS plugin entry point
-- This file is automatically loaded by Neovim

-- Prevent loading twice
if vim.g.loaded_ssns then
  return
end
vim.g.loaded_ssns = 1

-- Commands will be registered when user calls setup()
-- But we can provide a basic command to check if plugin is loaded
vim.api.nvim_create_user_command("SSNSVersion", function()
  local ssns = require('nvim-ssns')
  vim.notify(string.format("SSNS version: %s", ssns.get_version()), vim.log.levels.INFO)
end, {
  desc = "Show SSNS version",
})

-- Development test command for input fields
vim.api.nvim_create_user_command("SSNSInputTest", function()
  local input_test = require('nvim-ssns.ui.dialogs.input_test')
  input_test.show()
end, {
  desc = "Test input fields in floating window (dev)",
})

-- Register .ssns filetype for ETL scripts
vim.filetype.add({
  extension = {
    ssns = "ssns",
  },
  pattern = {
    [".*%.etl%.sql"] = "ssns",  -- Alternative: .etl.sql files
  },
})
