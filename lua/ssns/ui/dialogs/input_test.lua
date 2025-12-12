--- Input Field Test Dialog
--- Tests the new ContentBuilder input system
local UiFloat = require("ssns.ui.core.float")
local ContentBuilder = require("ssns.ui.core.content_builder")

local M = {}

-- Store reference for keymap callbacks
local current_float = nil

--- Show a test panel with input fields
function M.show()
  local cb = ContentBuilder.new()
  
  -- Title
  cb:blank()
  cb:styled("  INPUT FIELD TEST", "header")
  cb:blank()
  cb:styled("  ───────────────────────────────────────", "muted")
  cb:blank()
  
  -- Input fields with values
  cb:labeled_input("name", "  Name", {
    value = "Test Connection",
    width = 30,
  })
  cb:blank()
  
  cb:labeled_input("server", "  Server", {
    value = "localhost",
    width = 30,
  })
  cb:blank()
  
  cb:labeled_input("port", "  Port", {
    value = "1433",
    width = 10,
  })
  cb:blank()
  
  cb:labeled_input("database", "  Database", {
    value = "",
    placeholder = "(optional)",
    width = 25,
  })
  cb:blank()
  
  cb:labeled_input("username", "  Username", {
    value = "",
    placeholder = "(not set)",
    width = 20,
  })
  cb:blank()
  
  cb:labeled_input("password", "  Password", {
    value = "",
    placeholder = "(not set)",
    width = 20,
  })
  cb:blank()
  
  cb:styled("  ───────────────────────────────────────", "muted")
  cb:blank()
  cb:spans({
    { text = "  ", style = "text" },
    { text = "j/k", style = "key" },
    { text = " or ", style = "muted" },
    { text = "↑/↓", style = "key" },
    { text = " Navigate fields", style = "muted" },
  })
  cb:spans({
    { text = "  ", style = "text" },
    { text = "Enter", style = "key" },
    { text = " Edit/Confirm   ", style = "muted" },
    { text = "Esc", style = "key" },
    { text = " Cancel", style = "muted" },
  })
  cb:spans({
    { text = "  ", style = "text" },
    { text = "s", style = "key" },
    { text = " Submit form    ", style = "muted" },
    { text = "q", style = "key" },
    { text = " Close", style = "muted" },
  })
  cb:blank()

  current_float = UiFloat.create(nil, {
    title = " Input Test ",
    width = 50,
    height = 28,
    content_builder = cb,
    enable_inputs = true,  -- Enable input field mode
    keymaps = {
      ["s"] = function()
        -- Get all input values
        if current_float then
          local values = current_float:get_all_input_values()
          vim.notify(vim.inspect(values), vim.log.levels.INFO)
        end
      end,
    },
  })
  
  return current_float
end

return M
