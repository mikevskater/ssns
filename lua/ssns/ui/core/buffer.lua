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
  -- First, wipe any stale buffer with this name to avoid E95 error
  local stale_bufnr = vim.fn.bufnr("SSNS")
  if stale_bufnr ~= -1 then
    pcall(vim.api.nvim_buf_delete, stale_bufnr, { force = true })
  end

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
    winhighlight = 'Normal:Normal,FloatBorder:SsnsFloatBorder,FloatTitle:SsnsFloatTitle,CursorLine:SsnsFloatSelected',
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

---Setup autocmd to close float when it loses focus
local function setup_float_focus_handler()
  -- Create augroup for focus handling
  local augroup = vim.api.nvim_create_augroup("SsnsFloatFocus", { clear = true })

  vim.api.nvim_create_autocmd("WinLeave", {
    group = augroup,
    buffer = UiBuffer.bufnr,
    callback = function()
      -- Schedule the close to avoid issues during window transition
      vim.schedule(function()
        if UiBuffer._is_float and UiBuffer.is_open() then
          UiBuffer.close()
        end
      end)
    end,
  })
end

---Clean up float focus handler
local function cleanup_float_focus_handler()
  pcall(vim.api.nvim_del_augroup_by_name, "SsnsFloatFocus")
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

    -- Setup focus loss handler (auto-close when losing focus)
    setup_float_focus_handler()
  else
    -- Create split window
    if position == "left" then
      vim.cmd("topleft vsplit")
    elseif position == "right" then
      vim.cmd("botright vsplit")
    else
      vim.cmd("topleft vsplit")
    end

    -- Calculate width (support percentage-based sizing if <= 1)
    local split_width = width
    if split_width <= 1 then
      split_width = math.floor(vim.o.columns * split_width)
    end
    -- Ensure minimum width
    split_width = math.max(split_width, 20)

    -- Set window width
    vim.cmd(string.format("vertical resize %d", split_width))

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
  -- Save cursor position before closing
  local Tree = require('ssns.ui.core.tree')
  Tree.save_cursor_position()

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
      cleanup_float_focus_handler()
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

---Setup buffer keymaps using KeymapManager for conflict handling
function UiBuffer.setup_keymaps()
  if not UiBuffer.exists() then
    return
  end

  local bufnr = UiBuffer.bufnr
  local Config = require('ssns.config')
  local KeymapManager = require('ssns.keymap_manager')

  -- Get keymaps from tree group (with common as fallback)
  local km = KeymapManager.get_group("tree")

  -- Build keymap definitions
  local keymaps = {
    -- Close window
    {
      lhs = km.close or KeymapManager.get("common", "close", "q"),
      rhs = "<Cmd>lua require('ssns.ui.core.buffer').close()<CR>",
      desc = "Close SSNS",
    },
    -- Expand/collapse node
    {
      lhs = km.toggle or "<CR>",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').toggle_node()<CR>",
      desc = "Expand/collapse node",
    },
    {
      lhs = km.toggle_alt or "o",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').toggle_node()<CR>",
      desc = "Expand/collapse node (alt)",
    },
    -- Refresh
    {
      lhs = km.refresh or "r",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').refresh_node()<CR>",
      desc = "Refresh node",
    },
    {
      lhs = km.refresh_all or "R",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').refresh_all()<CR>",
      desc = "Refresh all",
    },
    -- Filter
    {
      lhs = km.filter or "f",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').open_filter()<CR>",
      desc = "Filter group",
    },
    {
      lhs = km.filter_clear or "F",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').clear_filter()<CR>",
      desc = "Clear filter",
    },
    -- Connect/disconnect
    {
      lhs = km.toggle_connection or "d",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').toggle_connection()<CR>",
      desc = "Toggle connection",
    },
    -- Set lualine color
    {
      lhs = km.set_lualine_color or "<Leader>c",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').set_lualine_color()<CR>",
      desc = "Set lualine color",
    },
    -- Help
    {
      lhs = km.help or "?",
      rhs = "<Cmd>lua require('ssns.ui.core.buffer').show_help()<CR>",
      desc = "Show help",
    },
    -- New query buffer
    {
      lhs = km.new_query or "<C-n>",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').new_query_from_context()<CR>",
      desc = "New query buffer with USE statement",
    },
    -- Go to first/last child
    {
      lhs = km.goto_first_child or "<C-[>",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').goto_first_child()<CR>",
      desc = "Go to first child in group",
    },
    {
      lhs = km.goto_last_child or "<C-]>",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').goto_last_child()<CR>",
      desc = "Go to last child in group",
    },
    -- Toggle parent group
    {
      lhs = km.toggle_group or "g",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').toggle_group()<CR>",
      desc = "Toggle parent group",
    },
    -- Add server
    {
      lhs = km.add_server or "a",
      rhs = "<Cmd>lua require('ssns.ui.dialogs.add_server').open()<CR>",
      desc = "Add server connection",
    },
    -- Toggle favorite
    {
      lhs = km.toggle_favorite or "*",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').toggle_favorite()<CR>",
      desc = "Toggle server favorite",
    },
    -- Show history
    {
      lhs = km.show_history or "<Leader>@",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').show_history_from_context()<CR>",
      desc = "Show query history for server",
    },
    -- View definition (ALTER script)
    {
      lhs = km.view_definition or "K",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').view_definition()<CR>",
      desc = "View object definition",
    },
    -- View metadata
    {
      lhs = km.view_metadata or "M",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').view_metadata()<CR>",
      desc = "View object metadata",
    },
    -- Cancel loading operation
    {
      lhs = km.cancel or "<C-c>",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').cancel_loading()<CR>",
      desc = "Cancel loading operation",
    },
    -- Mouse support
    {
      lhs = "<LeftMouse>",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').handle_mouse_click()<CR>",
      desc = "Select node with mouse",
    },
    {
      lhs = "<2-LeftMouse>",
      rhs = "<Cmd>lua require('ssns.ui.core.tree').handle_double_click()<CR>",
      desc = "Toggle expand with double-click",
    },
  }

  -- Add escape key for float mode only
  if UiBuffer._is_float then
    table.insert(keymaps, {
      lhs = KeymapManager.get("common", "cancel", "<Esc>"),
      rhs = "<Cmd>lua require('ssns.ui.core.buffer').close()<CR>",
      desc = "Close SSNS float",
    })
  end

  -- Set all keymaps with conflict handling
  KeymapManager.set_multiple(bufnr, keymaps, true)
  KeymapManager.mark_group_active(bufnr, "tree")

  -- Override j/k for smart cursor positioning with count support (if enabled)
  if Config.get_ui().smart_cursor_positioning then
    local common = KeymapManager.get_group("common")

    -- Set j/k keymaps using KeymapManager (saves conflicts automatically)
    local nav_keymaps = {
      {
        mode = "n",
        lhs = common.nav_down or "j",
        rhs = function()
          local count = vim.v.count1
          require('ssns.ui.core.buffer').move_cursor_down(count)
        end,
        desc = "Move down with smart positioning",
      },
      {
        mode = "n",
        lhs = common.nav_up or "k",
        rhs = function()
          local count = vim.v.count1
          require('ssns.ui.core.buffer').move_cursor_up(count)
        end,
        desc = "Move up with smart positioning",
      },
    }

    KeymapManager.set_multiple(bufnr, nav_keymaps, true)
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
  local UiFloat = require('ssns.ui.core.float')
  local ContentBuilder = require('ssns.ui.core.content_builder')

  local cb = ContentBuilder.new()
  
  cb:header("SSNS - SQL Server NeoVim Studio")
  cb:blank()
  
  cb:section("Navigation")
  cb:spans({ { text = "  <CR>, o      ", style = "key" }, { text = "Expand/collapse node" } })
  cb:spans({ { text = "  g            ", style = "key" }, { text = "Toggle parent group (collapse from child)" } })
  cb:spans({ { text = "  j, k         ", style = "key" }, { text = "Move cursor up/down" } })
  cb:spans({ { text = "  <C-[>        ", style = "key" }, { text = "Go to first child in group" } })
  cb:spans({ { text = "  <C-]>        ", style = "key" }, { text = "Go to last child in group" } })
  cb:spans({ { text = "  q            ", style = "key" }, { text = "Close SSNS window" } })
  cb:blank()
  
  cb:section("Mouse")
  cb:spans({ { text = "  Click        ", style = "key" }, { text = "Select node" } })
  cb:spans({ { text = "  Click icon   ", style = "key" }, { text = "Expand/collapse node" } })
  cb:spans({ { text = "  Double-click ", style = "key" }, { text = "Expand/collapse node" } })
  cb:blank()
  
  cb:section("Actions")
  cb:spans({ { text = "  a            ", style = "key" }, { text = "Add server connection" } })
  cb:spans({ { text = "  *            ", style = "key" }, { text = "Toggle favorite (server)" } })
  cb:spans({ { text = "  r            ", style = "key" }, { text = "Refresh current node" } })
  cb:spans({ { text = "  R            ", style = "key" }, { text = "Refresh all servers" } })
  cb:spans({ { text = "  d            ", style = "key" }, { text = "Toggle connection" } })
  cb:spans({ { text = "  <C-n>        ", style = "key" }, { text = "New query buffer with USE statement" } })
  cb:spans({ { text = "  <Leader>c    ", style = "key" }, { text = "Set lualine color (server/database)" } })
  cb:blank()
  
  cb:section("Filtering")
  cb:spans({ { text = "  f            ", style = "key" }, { text = "Open filter UI for group" } })
  cb:spans({ { text = "  F            ", style = "key" }, { text = "Clear all filters on group" } })
  cb:blank()
  
  cb:section("Query History")
  cb:spans({ { text = "  <Leader>h    ", style = "key" }, { text = "Open query history panel" } })
  cb:blank()
  
  cb:section("Help")
  cb:spans({ { text = "  ?            ", style = "key" }, { text = "Show this help" } })

  UiFloat.create_styled(cb, {
    title = "SSNS Help",
    footer = "Press any key to close",
    width = 55,
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

  -- Auto-expand width if enabled
  UiBuffer.auto_expand_width(lines)
end

---Auto-expand tree window width to fit content if enabled
---@param lines string[] The lines currently displayed
function UiBuffer.auto_expand_width(lines)
  if not UiBuffer.is_open() then
    return
  end

  local Config = require('ssns.config')
  local ui_config = Config.get_ui()

  -- Check if auto-expand is enabled
  if not ui_config.tree_auto_expand then
    return
  end

  -- Calculate max line width (using display width to handle unicode)
  local max_width = 0
  for _, line in ipairs(lines) do
    local line_width = vim.fn.strdisplaywidth(line)
    if line_width > max_width then
      max_width = line_width
    end
  end

  -- Add some padding (2 for border if float, 1 for scrollbar margin)
  local padding = UiBuffer._is_float and 4 or 2
  local desired_width = max_width + padding

  -- Get config width as minimum
  local config_width = ui_config.width or 40
  if config_width <= 1 then
    config_width = math.floor(vim.o.columns * config_width)
  end

  -- Use the larger of config width and content width
  local new_width = math.max(config_width, desired_width)

  -- Apply screen constraints
  local max_screen_width = vim.o.columns - 4
  new_width = math.min(new_width, max_screen_width)
  new_width = math.max(new_width, 20)  -- Minimum width

  -- Get current width
  local current_width = vim.api.nvim_win_get_width(UiBuffer.winid)

  -- Only resize if width actually changed
  if new_width ~= current_width then
    if UiBuffer._is_float then
      -- For float windows, update the window config
      local current_config = vim.api.nvim_win_get_config(UiBuffer.winid)
      local new_col = math.floor((vim.o.columns - new_width) / 2)
      vim.api.nvim_win_set_config(UiBuffer.winid, {
        relative = current_config.relative,
        width = new_width,
        height = current_config.height,
        row = current_config.row,
        col = new_col,
      })
    else
      -- For docked/split windows, just set the width
      vim.api.nvim_win_set_width(UiBuffer.winid, new_width)
    end
  end
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

---@class ChunkedWriteOpts
---@field chunk_size number? Lines per chunk (default 100)
---@field on_progress fun(written: number, total: number)? Progress callback
---@field on_complete fun()? Completion callback

---Active chunked write state (only one can be active at a time)
---@type { timer: number?, cancelled: boolean }?
UiBuffer._chunked_write_state = nil

---Write lines to buffer in chunks to avoid blocking UI
---For large line counts (>200), this writes in chunks with vim.schedule() between each
---@param lines string[] Array of lines to write
---@param opts ChunkedWriteOpts? Options for chunked writing
function UiBuffer.set_lines_chunked(lines, opts)
  if not UiBuffer.exists() then
    if opts and opts.on_complete then opts.on_complete() end
    return
  end

  opts = opts or {}
  local chunk_size = opts.chunk_size or 100
  local on_progress = opts.on_progress
  local on_complete = opts.on_complete
  local total_lines = #lines

  -- Cancel any existing chunked write
  UiBuffer.cancel_chunked_write()

  -- For small line counts, use sync write
  if total_lines <= chunk_size then
    UiBuffer.set_lines(lines)
    if on_progress then on_progress(total_lines, total_lines) end
    if on_complete then on_complete() end
    return
  end

  -- Initialize chunked write state
  UiBuffer._chunked_write_state = {
    timer = nil,
    cancelled = false,
  }

  local state = UiBuffer._chunked_write_state
  local current_idx = 1
  local is_first_chunk = true

  -- Make buffer modifiable for the duration of chunked write
  vim.api.nvim_buf_set_option(UiBuffer.bufnr, "modifiable", true)

  -- NOTE: Don't clear buffer first - causes visible flash
  -- First chunk will replace entire buffer content instead

  local function write_next_chunk()
    -- Check if cancelled or buffer no longer valid
    if state.cancelled or not UiBuffer.exists() then
      UiBuffer._chunked_write_state = nil
      return
    end

    local end_idx = math.min(current_idx + chunk_size - 1, total_lines)

    -- Extract chunk of lines
    local chunk = {}
    for i = current_idx, end_idx do
      table.insert(chunk, lines[i])
    end

    -- Write chunk to buffer
    if is_first_chunk then
      -- First chunk: replace entire buffer content (avoids flash from clearing first)
      vim.api.nvim_buf_set_lines(UiBuffer.bufnr, 0, -1, false, chunk)
      is_first_chunk = false
    else
      -- Subsequent chunks: append at the correct position
      local append_start = current_idx - 1  -- 0-indexed
      vim.api.nvim_buf_set_lines(UiBuffer.bufnr, append_start, append_start, false, chunk)
    end

    -- Report progress
    if on_progress then
      on_progress(end_idx, total_lines)
    end

    current_idx = end_idx + 1

    if current_idx <= total_lines then
      -- Schedule next chunk
      state.timer = vim.fn.timer_start(0, function()
        state.timer = nil
        vim.schedule(write_next_chunk)
      end)
    else
      -- All chunks written - finalize
      vim.api.nvim_buf_set_option(UiBuffer.bufnr, "modifiable", false)

      -- Auto-expand width if enabled
      UiBuffer.auto_expand_width(lines)

      UiBuffer._chunked_write_state = nil

      if on_complete then
        on_complete()
      end
    end
  end

  -- Start writing first chunk
  write_next_chunk()
end

---Cancel any in-progress chunked write operation
function UiBuffer.cancel_chunked_write()
  if UiBuffer._chunked_write_state then
    UiBuffer._chunked_write_state.cancelled = true
    if UiBuffer._chunked_write_state.timer then
      vim.fn.timer_stop(UiBuffer._chunked_write_state.timer)
      UiBuffer._chunked_write_state.timer = nil
    end
    -- Restore buffer to non-modifiable state if it exists
    if UiBuffer.exists() then
      pcall(vim.api.nvim_buf_set_option, UiBuffer.bufnr, "modifiable", false)
    end
    UiBuffer._chunked_write_state = nil
  end
end

---Check if a chunked write is currently in progress
---@return boolean
function UiBuffer.is_chunked_write_active()
  return UiBuffer._chunked_write_state ~= nil and not UiBuffer._chunked_write_state.cancelled
end

return UiBuffer
