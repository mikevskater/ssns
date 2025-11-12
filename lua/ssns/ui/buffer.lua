---@class UiBuffer
---Buffer management for SSNS UI
local UiBuffer = {}

---Active SSNS buffer ID
---@type number?
UiBuffer.bufnr = nil

---Active SSNS window ID
---@type number?
UiBuffer.winid = nil

---Buffer name
UiBuffer.name = "SSNS"

---Check if SSNS buffer exists
---@return boolean
function UiBuffer.exists()
  return UiBuffer.bufnr ~= nil and vim.api.nvim_buf_is_valid(UiBuffer.bufnr)
end

---Check if SSNS window is open
---@return boolean
function UiBuffer.is_open()
  return UiBuffer.winid ~= nil and vim.api.nvim_win_is_valid(UiBuffer.winid)
end

---Create the SSNS buffer
---@return number bufnr The buffer number
function UiBuffer.create()
  -- Create a new buffer
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "filetype", "ssns")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- Set buffer name
  vim.api.nvim_buf_set_name(bufnr, "SSNS")

  UiBuffer.bufnr = bufnr
  return bufnr
end

---Open the SSNS window
---@return number winid The window ID
function UiBuffer.open()
  local Config = require('ssns.config')
  local ui_config = Config.get_ui()

  -- Create buffer if it doesn't exist
  if not UiBuffer.exists() then
    UiBuffer.create()
  end

  -- Check if already open
  if UiBuffer.is_open() then
    vim.api.nvim_set_current_win(UiBuffer.winid)
    return UiBuffer.winid
  end

  -- Determine window position
  local position = ui_config.position or "left"
  local width = ui_config.width or 40

  -- Create split based on position
  if position == "left" then
    vim.cmd("topleft vsplit")
  elseif position == "right" then
    vim.cmd("botright vsplit")
  elseif position == "float" then
    -- TODO: Implement floating window
    vim.cmd("topleft vsplit")
  else
    vim.cmd("topleft vsplit")
  end

  -- Set window width
  vim.cmd(string.format("vertical resize %d", width))

  -- Set buffer in window
  vim.api.nvim_win_set_buf(0, UiBuffer.bufnr)
  UiBuffer.winid = vim.api.nvim_get_current_win()

  -- Set window options
  vim.api.nvim_win_set_option(UiBuffer.winid, "number", false)
  vim.api.nvim_win_set_option(UiBuffer.winid, "relativenumber", false)
  vim.api.nvim_win_set_option(UiBuffer.winid, "signcolumn", "no")
  vim.api.nvim_win_set_option(UiBuffer.winid, "foldcolumn", "0")
  vim.api.nvim_win_set_option(UiBuffer.winid, "wrap", false)
  vim.api.nvim_win_set_option(UiBuffer.winid, "cursorline", true)

  -- Setup keymaps
  UiBuffer.setup_keymaps()

  return UiBuffer.winid
end

---Close the SSNS window
function UiBuffer.close()
  if UiBuffer.is_open() then
    vim.api.nvim_win_close(UiBuffer.winid, true)
    UiBuffer.winid = nil
  end
end

---Toggle the SSNS window
function UiBuffer.toggle()
  if UiBuffer.is_open() then
    UiBuffer.close()
  else
    UiBuffer.open()
  end
end

---Setup buffer keymaps
function UiBuffer.setup_keymaps()
  if not UiBuffer.exists() then
    return
  end

  local bufnr = UiBuffer.bufnr

  -- Close window
  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "<Cmd>lua require('ssns.ui.buffer').close()<CR>", {
    noremap = true,
    silent = true,
    desc = "Close SSNS",
  })

  -- Expand/collapse node
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "<Cmd>lua require('ssns.ui.tree').toggle_node()<CR>", {
    noremap = true,
    silent = true,
    desc = "Expand/collapse node",
  })

  vim.api.nvim_buf_set_keymap(bufnr, "n", "o", "<Cmd>lua require('ssns.ui.tree').toggle_node()<CR>", {
    noremap = true,
    silent = true,
    desc = "Expand/collapse node",
  })

  -- Refresh
  vim.api.nvim_buf_set_keymap(bufnr, "n", "r", "<Cmd>lua require('ssns.ui.tree').refresh_node()<CR>", {
    noremap = true,
    silent = true,
    desc = "Refresh node",
  })

  vim.api.nvim_buf_set_keymap(bufnr, "n", "R", "<Cmd>lua require('ssns.ui.tree').refresh_all()<CR>", {
    noremap = true,
    silent = true,
    desc = "Refresh all",
  })

  -- Connect/disconnect
  vim.api.nvim_buf_set_keymap(bufnr, "n", "d", "<Cmd>lua require('ssns.ui.tree').toggle_connection()<CR>", {
    noremap = true,
    silent = true,
    desc = "Toggle connection",
  })

  -- Help
  vim.api.nvim_buf_set_keymap(bufnr, "n", "?", "<Cmd>lua require('ssns.ui.buffer').show_help()<CR>", {
    noremap = true,
    silent = true,
    desc = "Show help",
  })
end

---Show help in floating window
function UiBuffer.show_help()
  local help_lines = {
    "SSNS - SQL Server NeoVim Studio",
    "",
    "Navigation:",
    "  <CR>, o  - Expand/collapse node",
    "  q        - Close SSNS",
    "",
    "Actions:",
    "  r        - Refresh current node",
    "  R        - Refresh all servers",
    "  d        - Toggle connection",
    "",
    "Help:",
    "  ?        - Show this help",
  }

  -- Create floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)

  local width = 40
  local height = #help_lines
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  -- Close on any key
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>close<CR>", { noremap = true, silent = true })
end

---Write lines to buffer
---@param lines string[] Array of lines to write
function UiBuffer.set_lines(lines)
  if not UiBuffer.exists() then
    return
  end

  -- Make buffer modifiable temporarily
  vim.api.nvim_buf_set_option(UiBuffer.bufnr, "modifiable", true)

  -- Set lines
  vim.api.nvim_buf_set_lines(UiBuffer.bufnr, 0, -1, false, lines)

  -- Make buffer read-only again
  vim.api.nvim_buf_set_option(UiBuffer.bufnr, "modifiable", false)
end

---Get current line number
---@return number line_number
function UiBuffer.get_current_line()
  if not UiBuffer.is_open() then
    return 0
  end

  local cursor = vim.api.nvim_win_get_cursor(UiBuffer.winid)
  return cursor[1]
end

---Set cursor to specific line
---@param line_number number
function UiBuffer.set_cursor(line_number)
  if not UiBuffer.is_open() then
    return
  end

  vim.api.nvim_win_set_cursor(UiBuffer.winid, { line_number, 0 })
end

---Clear the buffer
function UiBuffer.clear()
  UiBuffer.set_lines({})
end

return UiBuffer
