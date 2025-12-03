---@class UiBuffer
---Buffer management for SSNS UI
local UiBuffer = {}

---Active SSNS buffer ID
---@type number?
UiBuffer.bufnr = nil

---Active SSNS window ID
---@type number?
UiBuffer.winid = nil

---Is current window a floating window?
---@type boolean
UiBuffer._is_float = false

---Float resize augroup ID
---@type number?
UiBuffer._float_augroup = nil

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

---Create a floating window for the tree UI
---@param bufnr number The buffer to display
---@param ui_config UiConfig The UI configuration
---@return number winid The created window ID
local function create_float_window(bufnr, ui_config)
  local float_width = ui_config.width or 50
  local float_height = ui_config.height or 30

  -- Support percentage-based sizing (if width/height <= 1, treat as percentage)
  if float_width <= 1 then
    float_width = math.floor(vim.o.columns * float_width)
  end
  if float_height <= 1 then
    float_height = math.floor((vim.o.lines - 2) * float_height)  -- -2 for cmdline/statusline
  end

  -- Ensure minimum size
  float_width = math.max(float_width, 30)
  float_height = math.max(float_height, 10)

  -- Ensure doesn't exceed screen
  float_width = math.min(float_width, vim.o.columns - 4)
  float_height = math.min(float_height, vim.o.lines - 4)

  -- Center the window
  local row = math.floor((vim.o.lines - float_height) / 2) - 1
  local col = math.floor((vim.o.columns - float_width) / 2)

  local float_config = {
    relative = "editor",
    width = float_width,
    height = float_height,
    row = row,
    col = col,
    style = "minimal",
    border = ui_config.float_border or "rounded",
    focusable = true,
    zindex = ui_config.float_zindex or 50,
  }

  -- Add title if configured
  if ui_config.float_title ~= false then
    float_config.title = ui_config.float_title_text or " SSNS "
    float_config.title_pos = "center"
  end

  local winid = vim.api.nvim_open_win(bufnr, true, float_config)

  -- Set window options
  local win_opts = {
    cursorline = true,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    wrap = false,
    spell = false,
    list = false,
  }

  for opt, val in pairs(win_opts) do
    vim.api.nvim_set_option_value(opt, val, { win = winid })
  end

  return winid
end

---Setup autocmd to reposition float window on terminal resize
local function setup_float_resize_handler()
  -- Clean up existing augroup if any
  if UiBuffer._float_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, UiBuffer._float_augroup)
  end

  UiBuffer._float_augroup = vim.api.nvim_create_augroup("SsnsFloatResize", { clear = true })

  vim.api.nvim_create_autocmd("VimResized", {
    group = UiBuffer._float_augroup,
    callback = function()
      if UiBuffer._is_float and UiBuffer.is_open() then
        local Config = require('ssns.config')
        local ui_config = Config.get_ui()

        -- Recalculate dimensions
        local float_width = ui_config.width or 50
        local float_height = ui_config.height or 30

        if float_width <= 1 then
          float_width = math.floor(vim.o.columns * float_width)
        end
        if float_height <= 1 then
          float_height = math.floor((vim.o.lines - 2) * float_height)
        end

        float_width = math.max(30, math.min(float_width, vim.o.columns - 4))
        float_height = math.max(10, math.min(float_height, vim.o.lines - 4))

        local row = math.floor((vim.o.lines - float_height) / 2) - 1
        local col = math.floor((vim.o.columns - float_width) / 2)

        pcall(vim.api.nvim_win_set_config, UiBuffer.winid, {
          relative = "editor",
          width = float_width,
          height = float_height,
          row = row,
          col = col,
        })
      end
    end,
  })
end

---Clean up float resize handler
local function cleanup_float_resize_handler()
  if UiBuffer._float_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, UiBuffer._float_augroup)
    UiBuffer._float_augroup = nil
  end
end

---Open the SSNS window
---@param mode_override string? Optional mode override: "float" or "docked" (uses config's left/right for docked)
---@return number winid The window ID
function UiBuffer.open(mode_override)
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

  -- Determine window position (mode_override takes precedence)
  local position
  if mode_override == "float" then
    position = "float"
  elseif mode_override == "docked" then
    -- Use config's position for docked, but ensure it's not float
    local config_pos = ui_config.position or "left"
    position = (config_pos == "float") and "left" or config_pos
  else
    -- Use config position
    position = ui_config.position or "left"
  end
  local width = ui_config.width or 40

  -- Create window based on position
  if position == "float" then
    -- Create floating window
    UiBuffer.winid = create_float_window(UiBuffer.bufnr, ui_config)
    UiBuffer._is_float = true

    -- Setup resize handler for float mode
    setup_float_resize_handler()
  else
    -- Create split window
    if position == "left" then
      vim.cmd("topleft vsplit")
    elseif position == "right" then
      vim.cmd("botright vsplit")
    else
      vim.cmd("topleft vsplit")
    end

    -- Set window width
    vim.cmd(string.format("vertical resize %d", width))

    -- Set buffer in window
    vim.api.nvim_win_set_buf(0, UiBuffer.bufnr)
    UiBuffer.winid = vim.api.nvim_get_current_win()
    UiBuffer._is_float = false

    -- Set window options for split mode
    vim.api.nvim_win_set_option(UiBuffer.winid, "number", false)
    vim.api.nvim_win_set_option(UiBuffer.winid, "relativenumber", false)
    vim.api.nvim_win_set_option(UiBuffer.winid, "signcolumn", "no")
    vim.api.nvim_win_set_option(UiBuffer.winid, "foldcolumn", "0")
    vim.api.nvim_win_set_option(UiBuffer.winid, "wrap", false)
    vim.api.nvim_win_set_option(UiBuffer.winid, "cursorline", true)
  end

  -- Setup keymaps
  UiBuffer.setup_keymaps()

  -- Setup cursor positioning autocmd
  UiBuffer.setup_cursor_positioning()

  -- Setup autocmd to close SSNS when it becomes the last window
  UiBuffer.setup_auto_close()

  return UiBuffer.winid
end

---Setup autocmd to close SSNS tree when all other windows are closed
function UiBuffer.setup_auto_close()
  if not UiBuffer.exists() then
    return
  end

  -- Create augroup if not exists
  local augroup = vim.api.nvim_create_augroup("SSNSAutoClose", { clear = true })

  -- Listen for when a window is closed
  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    callback = function(args)
      -- Skip if SSNS window is not open
      if not UiBuffer.is_open() then
        return
      end

      -- Skip if the closed window was the SSNS window itself
      local closed_winid = tonumber(args.match)
      if closed_winid == UiBuffer.winid then
        return
      end

      -- Defer the check to after the window is actually closed
      vim.schedule(function()
        -- Check if SSNS is now the only window
        local windows = vim.api.nvim_list_wins()
        if #windows == 1 and UiBuffer.is_open() then
          -- SSNS is the last window, quit Neovim
          vim.cmd('quit')
        end
      end)
    end,
  })
end

---Close the SSNS window
---@param force boolean? If true, quit Neovim if this is the last window
function UiBuffer.close(force)
  if UiBuffer.is_open() then
    -- Check if this is the last window (only applies to split mode)
    -- Float windows don't count as "windows" for the last-window check
    if not UiBuffer._is_float then
      local windows = vim.api.nvim_list_wins()
      if #windows == 1 then
        if force then
          -- Quit Neovim if forced and this is the last window
          vim.cmd('quit')
        end
        -- Don't close if this is the last window (would cause E444)
        return
      end
    end
    vim.api.nvim_win_close(UiBuffer.winid, true)
    UiBuffer.winid = nil

    -- Clean up float state
    if UiBuffer._is_float then
      UiBuffer._is_float = false
      cleanup_float_resize_handler()
    end
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

---Check if the tree is currently in float mode
---@return boolean
function UiBuffer.is_float()
  return UiBuffer._is_float
end

---Close the tree only if it's in floating mode
---Used for auto-closing float when actions create new buffers
---@return boolean closed True if the float was closed
function UiBuffer.close_if_float()
  if UiBuffer._is_float and UiBuffer.is_open() then
    UiBuffer.close()
    return true
  end
  return false
end

---Setup buffer keymaps
function UiBuffer.setup_keymaps()
  if not UiBuffer.exists() then
    return
  end

  local bufnr = UiBuffer.bufnr
  local Config = require('ssns.config')
  local keymaps = Config.get_keymaps()

  -- Close window
  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.close or "q", "<Cmd>lua require('ssns.ui.buffer').close()<CR>", {
    noremap = true,
    silent = true,
    desc = "Close SSNS",
  })

  -- Close with Escape (only in float mode to not interfere with normal navigation)
  if UiBuffer._is_float then
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", "<Cmd>lua require('ssns.ui.buffer').close()<CR>", {
      noremap = true,
      silent = true,
      desc = "Close SSNS float",
    })
  end

  -- Expand/collapse node
  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.toggle or "<CR>", "<Cmd>lua require('ssns.ui.tree').toggle_node()<CR>", {
    noremap = true,
    silent = true,
    desc = "Expand/collapse node",
  })

  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.toggle_alt or "o", "<Cmd>lua require('ssns.ui.tree').toggle_node()<CR>", {
    noremap = true,
    silent = true,
    desc = "Expand/collapse node",
  })

  -- Refresh
  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.refresh or "r", "<Cmd>lua require('ssns.ui.tree').refresh_node()<CR>", {
    noremap = true,
    silent = true,
    desc = "Refresh node",
  })

  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.refresh_all or "R", "<Cmd>lua require('ssns.ui.tree').refresh_all()<CR>", {
    noremap = true,
    silent = true,
    desc = "Refresh all",
  })

  -- Filter
  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.filter or "f", "<Cmd>lua require('ssns.ui.tree').open_filter()<CR>", {
    noremap = true,
    silent = true,
    desc = "Filter group",
  })

  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.filter_clear or "F", "<Cmd>lua require('ssns.ui.tree').clear_filter()<CR>", {
    noremap = true,
    silent = true,
    desc = "Clear filter",
  })

  -- Connect/disconnect
  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.toggle_connection or "d", "<Cmd>lua require('ssns.ui.tree').toggle_connection()<CR>", {
    noremap = true,
    silent = true,
    desc = "Toggle connection",
  })

  -- Set lualine color
  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.set_lualine_color or "<Leader>c", "<Cmd>lua require('ssns.ui.tree').set_lualine_color()<CR>", {
    noremap = true,
    silent = true,
    desc = "Set lualine color",
  })

  -- Help
  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.help or "?", "<Cmd>lua require('ssns.ui.buffer').show_help()<CR>", {
    noremap = true,
    silent = true,
    desc = "Show help",
  })

  -- New query buffer with database context
  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.new_query or "<C-n>", "<Cmd>lua require('ssns.ui.tree').new_query_from_context()<CR>", {
    noremap = true,
    silent = true,
    desc = "New query buffer with USE statement",
  })

  -- Go to first child in group
  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.goto_first_child or "<C-[>", "<Cmd>lua require('ssns.ui.tree').goto_first_child()<CR>", {
    noremap = true,
    silent = true,
    desc = "Go to first child in group",
  })

  -- Go to last child in group
  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.goto_last_child or "<C-]>", "<Cmd>lua require('ssns.ui.tree').goto_last_child()<CR>", {
    noremap = true,
    silent = true,
    desc = "Go to last child in group",
  })

  -- Toggle parent group expand/collapse
  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.toggle_group or "g", "<Cmd>lua require('ssns.ui.tree').toggle_group()<CR>", {
    noremap = true,
    silent = true,
    desc = "Toggle parent group",
  })

  -- Show query history for current server
  vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.show_history or "<Leader>@", "<Cmd>lua require('ssns.ui.tree').show_history_from_context()<CR>", {
    noremap = true,
    silent = true,
    desc = "Show query history for server",
  })

  -- Override j/k for smart cursor positioning with count support (if enabled)
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
    "  g            - Toggle parent group (collapse from child)",
    "  j, k         - Move cursor up/down",
    "  <C-[>        - Go to first child in group",
    "  <C-]>        - Go to last child in group",
    "  q            - Close SSNS window",
    "",
    "Actions:",
    "  r            - Refresh current node",
    "  R            - Refresh all servers",
    "  d            - Toggle connection",
    "  <C-n>        - New query buffer with USE statement",
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
