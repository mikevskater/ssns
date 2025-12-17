---@class SsnsCommandsFeatures
---Feature-related commands (expand asterisk, go to, view definition, highlighting, themes)
local M = {}

---Register feature commands
function M.register()
  local Ssns = require('ssns')

  -- :SSNSExpandAsterisk - Expand * or alias.* to column list
  vim.api.nvim_create_user_command("SSNSExpandAsterisk", function()
    local ExpandAsterisk = require('ssns.features.expand_asterisk')
    ExpandAsterisk.expand_asterisk_at_cursor()
  end, {
    nargs = 0,
    desc = "Expand * or alias.* to column list (like SSMS RedGate)",
  })

  -- :SSNSHighlightToggle - Toggle semantic highlighting on/off for current buffer
  vim.api.nvim_create_user_command("SSNSHighlightToggle", function()
    Ssns.toggle_semantic_highlighting()
  end, {
    nargs = 0,
    desc = "Toggle semantic highlighting for current buffer",
  })

  -- :SSNSGoTo - Go to object under cursor in database tree
  vim.api.nvim_create_user_command("SSNSGoTo", function()
    local GoTo = require('ssns.features.go_to')
    GoTo.go_to_object_at_cursor()
  end, {
    nargs = 0,
    desc = "Go to object under cursor in tree",
  })

  -- :SSNSViewDefinition - View definition of object under cursor
  vim.api.nvim_create_user_command("SSNSViewDefinition", function()
    local ViewDefinition = require('ssns.features.view_definition')
    ViewDefinition.view_definition_at_cursor()
  end, {
    nargs = 0,
    desc = "View definition of object under cursor in floating window",
  })

  -- :SSNSViewMetadata - View metadata of object under cursor
  vim.api.nvim_create_user_command("SSNSViewMetadata", function()
    local ViewMetadata = require('ssns.features.view_metadata')
    ViewMetadata.view_metadata_at_cursor()
  end, {
    nargs = 0,
    desc = "View metadata of object under cursor in floating window",
  })

  -- Theme Commands

  -- :SSNSTheme - Open theme picker UI
  vim.api.nvim_create_user_command("SSNSTheme", function()
    local ThemePicker = require('ssns.ui.panels.theme_picker')
    ThemePicker.show()
  end, {
    nargs = 0,
    desc = "Open SSNS theme picker",
  })

  -- :SSNSThemeClear - Clear theme and use defaults
  vim.api.nvim_create_user_command("SSNSThemeClear", function()
    local ThemeManager = require('ssns.ui.theme_manager')
    ThemeManager.clear_theme()
  end, {
    nargs = 0,
    desc = "Clear SSNS theme (use defaults)",
  })

  -- SQL Formatter Commands (delegates to formatter module)
  local FormatterCommands = require('ssns.formatter.commands')
  FormatterCommands.register_commands()
end

return M
