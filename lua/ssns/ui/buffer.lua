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

  -- Setup cursor positioning autocmd
  UiBuffer.setup_cursor_positioning()

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

  -- Filter
  vim.api.nvim_buf_set_keymap(bufnr, "n", "f", "<Cmd>lua require('ssns.ui.tree').open_filter()<CR>", {
    noremap = true,
    silent = true,
    desc = "Filter group",
  })

  vim.api.nvim_buf_set_keymap(bufnr, "n", "F", "<Cmd>lua require('ssns.ui.tree').clear_filter()<CR>", {
    noremap = true,
    silent = true,
    desc = "Clear filter",
  })

  -- Connect/disconnect
  vim.api.nvim_buf_set_keymap(bufnr, "n", "d", "<Cmd>lua require('ssns.ui.tree').toggle_connection()<CR>", {
    noremap = true,
    silent = true,
    desc = "Toggle connection",
  })

  -- Set lualine color
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<Leader>c", "<Cmd>lua require('ssns.ui.tree').set_lualine_color()<CR>", {
    noremap = true,
    silent = true,
    desc = "Set lualine color",
  })

  -- Help
  vim.api.nvim_buf_set_keymap(bufnr, "n", "?", "<Cmd>lua require('ssns.ui.buffer').show_help()<CR>", {
    noremap = true,
    silent = true,
    desc = "Show help",
  })

  -- Override j/k for smart cursor positioning with count support (if enabled)
  local Config = require('ssns.config')
  if Config.get_ui().smart_cursor_positioning then
    vim.keymap.set("n", "j", function()
      local count = vim.v.count1  -- Gets count or 1 if no count given
      require('ssns.ui.buffer').move_cursor_down(count)
    end, {
      buffer = bufnr,
      noremap = true,
      silent = true,
      desc = "Move down with smart positioning",
    })

    vim.keymap.set("n", "k", function()
      local count = vim.v.count1  -- Gets count or 1 if no count given
      require('ssns.ui.buffer').move_cursor_up(count)
    end, {
      buffer = bufnr,
      noremap = true,
      silent = true,
      desc = "Move up with smart positioning",
    })
  end
end

---Setup cursor positioning behavior
function UiBuffer.setup_cursor_positioning()
  if not UiBuffer.exists() then
    return
  end

  -- Store last indent info for smart positioning
  UiBuffer.last_indent_info = {
    line = nil,
    indent_level = nil,
    column = nil,
  }
end

---Get the indent level of a line (number of leading spaces)
---@param line_number number
---@return number indent_level Number of leading spaces
function UiBuffer.get_indent_level(line_number)
  if not UiBuffer.exists() then
    return 0
  end

  local line = vim.api.nvim_buf_get_lines(UiBuffer.bufnr, line_number - 1, line_number, false)[1]

  if not line or line == "" then
    return 0
  end

  -- Count leading spaces
  local indent = 0
  for i = 1, #line do
    local char = line:sub(i, i)
    if char == " " then
      indent = indent + 1
    elseif char == "\t" then
      indent = indent + 2  -- Count tabs as 2 spaces
    else
      break
    end
  end

  return indent
end

---Move cursor down with smart positioning
---@param count number? Number of lines to move (default 1)
function UiBuffer.move_cursor_down(count)
  if not UiBuffer.is_open() then
    return
  end

  count = count or 1
  local current_line = UiBuffer.get_current_line()
  local current_cursor = vim.api.nvim_win_get_cursor(UiBuffer.winid)
  local current_col = current_cursor[2]
  local total_lines = vim.api.nvim_buf_line_count(UiBuffer.bufnr)

  -- Move down by count
  local new_line = math.min(current_line + count, total_lines)

  if new_line == current_line then
    return  -- Can't move down
  end

  -- Get indent levels
  local current_indent = UiBuffer.get_indent_level(current_line)
  local new_indent = UiBuffer.get_indent_level(new_line)

  local new_col
  if current_indent == new_indent and UiBuffer.last_indent_info.indent_level == current_indent then
    -- Same indent level - keep cursor in same column
    new_col = current_col
  else
    -- Different indent level - move to name start
    new_col = UiBuffer.get_name_column(new_line)
  end

  -- Update tracking info
  UiBuffer.last_indent_info.line = new_line
  UiBuffer.last_indent_info.indent_level = new_indent
  UiBuffer.last_indent_info.column = new_col

  UiBuffer.set_cursor(new_line, new_col)
end

---Move cursor up with smart positioning
---@param count number? Number of lines to move (default 1)
function UiBuffer.move_cursor_up(count)
  if not UiBuffer.is_open() then
    return
  end

  count = count or 1
  local current_line = UiBuffer.get_current_line()
  local current_cursor = vim.api.nvim_win_get_cursor(UiBuffer.winid)
  local current_col = current_cursor[2]

  -- Move up by count
  local new_line = math.max(current_line - count, 1)

  if new_line == current_line then
    return  -- Can't move up
  end

  -- Get indent levels
  local current_indent = UiBuffer.get_indent_level(current_line)
  local new_indent = UiBuffer.get_indent_level(new_line)

  local new_col
  if current_indent == new_indent and UiBuffer.last_indent_info.indent_level == current_indent then
    -- Same indent level - keep cursor in same column
    new_col = current_col
  else
    -- Different indent level - move to name start
    new_col = UiBuffer.get_name_column(new_line)
  end

  -- Update tracking info
  UiBuffer.last_indent_info.line = new_line
  UiBuffer.last_indent_info.indent_level = new_indent
  UiBuffer.last_indent_info.column = new_col

  UiBuffer.set_cursor(new_line, new_col)
end

---Show help in floating window
function UiBuffer.show_help()
  local UiFloat = require('ssns.ui.float')

  local help_lines = {
    "SSNS - SQL Server NeoVim Studio",
    "",
    "Navigation:",
    "  <CR>, o      - Expand/collapse node",
    "  j, k         - Move cursor up/down",
    "  q            - Close SSNS window",
    "",
    "Actions:",
    "  r            - Refresh current node",
    "  R            - Refresh all servers",
    "  d            - Toggle connection",
    "  <Leader>c    - Set lualine color (server/database)",
    "",
    "Filtering:",
    "  f            - Open filter UI for group",
    "  F            - Clear all filters on group",
    "",
    "Query History:",
    "  <Leader>h    - Open query history panel",
    "",
    "Help:",
    "  ?            - Show this help",
  }

  UiFloat.create(help_lines, {
    title = "SSNS Help",
    footer = "Press any key to close",
    width = 50,
    keymaps = {
      ['<CR>'] = function()
        vim.cmd('close')
      end,
    }
  })
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

---Set cursor to specific line and column
---@param line_number number
---@param column number? Optional column (0-indexed), defaults to 0
function UiBuffer.set_cursor(line_number, column)
  if not UiBuffer.is_open() then
    return
  end

  column = column or 0
  vim.api.nvim_win_set_cursor(UiBuffer.winid, { line_number, column })
end

---Get the column position where the name starts on a line
---This skips indent, arrow icons (▸/▾), and any other icons
---@param line_number number
---@return number column 0-indexed column position
function UiBuffer.get_name_column(line_number)
  if not UiBuffer.exists() then
    return 0
  end

  -- Get the line content
  local line = vim.api.nvim_buf_get_lines(UiBuffer.bufnr, line_number - 1, line_number, false)[1]

  if not line or line == "" then
    return 0
  end

  -- Find where the actual name starts
  -- Pattern: skip whitespace, then expand/collapse icon if present, then object icon, then the name
  -- Example: "  ▸  server_name" or "    ▾  dbo.Employees"
  local i = 1

  -- Skip leading whitespace (indent)
  while i <= #line do
    local char = line:sub(i, i)
    if char ~= " " and char ~= "\t" then
      break
    end
    i = i + 1
  end

  -- Skip all icons and spaces until we reach the actual text name
  -- Icons are UTF-8 characters (multi-byte, > 127)
  -- We need to skip: expand icon + space + object icon + space
  while i <= #line do
    local byte = line:byte(i)

    -- Skip UTF-8 icon characters (multi-byte characters)
    if byte and byte > 127 then
      -- Skip the multi-byte icon character
      -- UTF-8 icons can be 1-4 bytes
      local bytes_to_skip = 1
      if byte >= 240 then bytes_to_skip = 4
      elseif byte >= 224 then bytes_to_skip = 3
      elseif byte >= 192 then bytes_to_skip = 2
      end
      i = i + bytes_to_skip
    -- Skip spaces between icons
    elseif byte and (line:sub(i, i) == " " or line:sub(i, i) == "\t") then
      i = i + 1
    else
      -- We've reached the start of the actual name
      break
    end
  end

  -- Return 0-indexed column (Neovim uses 0-indexed columns)
  return i - 1
end

---Clear the buffer
function UiBuffer.clear()
  UiBuffer.set_lines({})
end

return UiBuffer
