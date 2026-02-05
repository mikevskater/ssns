---Lualine color management for SSNS
---Provides interactive color setting and persistence for server/database connections
local M = {}

-- Cache for loaded colors (to avoid repeated file reads)
local colors_cache = nil
local cache_timestamp = 0
local CACHE_TTL_MS = 5000  -- 5 seconds cache TTL

-- Color presets for quick selection
local COLOR_PRESETS = {
  { key = "1", label = "Red (Production)", color = { fg = '#ffffff', bg = '#cc0000', gui = 'bold' } },
  { key = "2", label = "Green (Development)", color = { fg = '#000000', bg = '#00cc00' } },
  { key = "3", label = "Yellow (Staging)", color = { fg = '#000000', bg = '#cccc00' } },
  { key = "4", label = "Blue (QA/Testing)", color = { fg = '#ffffff', bg = '#0066cc' } },
  { key = "5", label = "Orange (UAT)", color = { fg = '#000000', bg = '#ff9900' } },
  { key = "6", label = "Purple (Backup/Reporting)", color = { fg = '#ffffff', bg = '#9933cc' } },
  { key = "7", label = "Gray (Default)", color = { fg = '#ffffff', bg = '#666666' } },
}

---Validate hex color format
---@param hex string Color string to validate
---@return boolean valid True if valid hex color
local function is_valid_hex(hex)
  if not hex or type(hex) ~= "string" then return false end
  return hex:match("^#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") ~= nil
end

---Open nvim-colorpicker to select custom color
---@param name string Server or database name
---@param current_color table? Current color if editing
---@param on_complete fun(color: table?) Callback when color is selected
local function open_colorpicker(name, current_color, on_complete)
  local has_colorpicker, colorpicker = pcall(require, 'nvim-colorpicker')
  if not has_colorpicker then
    -- Fallback to text input if colorpicker not available
    vim.notify('SSNS: nvim-colorpicker not available. Using text input.', vim.log.levels.INFO)
    local fg = vim.fn.input('Foreground color (hex, e.g., #ffffff): ')
    if not is_valid_hex(fg) then
      vim.notify('SSNS: Invalid foreground color. Must be hex format like #ffffff', vim.log.levels.ERROR)
      on_complete(nil)
      return
    end

    local bg = vim.fn.input('Background color (hex, e.g., #ff0000): ')
    if not is_valid_hex(bg) then
      vim.notify('SSNS: Invalid background color. Must be hex format like #ff0000', vim.log.levels.ERROR)
      on_complete(nil)
      return
    end

    local gui = vim.fn.input('Text style (bold/italic/underline, or leave empty): ')
    vim.cmd('redraw!')

    local color = { fg = fg, bg = bg }
    if gui ~= '' then
      color.gui = gui
    end
    on_complete(color)
    return
  end

  -- Use nvim-colorpicker for visual color selection
  -- Working copies of fg/bg colors
  local working_colors = {
    fg = current_color and current_color.fg or "#ffffff",
    bg = current_color and current_color.bg or "#0066cc",
    gui = current_color and current_color.gui or nil,
  }

  -- Track original colors for comparison in picker
  local original_colors = {
    fg = working_colors.fg,
    bg = working_colors.bg,
  }

  -- Determine initial target (bg by default for status line colors)
  local initial_target = "bg"

  colorpicker.pick({
    color = working_colors[initial_target],
    title = "Lualine Color: " .. name,

    -- Inject custom controls for fg/bg selection and style
    custom_controls = {
      {
        id = "target",
        type = "select",
        label = "Target",
        options = { "bg", "fg" },
        default = initial_target,
        key = "B",
        on_change = function(new_target, old_target)
          -- Save current picker color to the old target
          local current_color_val = colorpicker.get_color()
          if current_color_val then
            working_colors[old_target] = current_color_val
          end
          -- Load the new target's color into the picker
          local new_color_val = working_colors[new_target]
          local new_original = original_colors[new_target]
          colorpicker.set_color(new_color_val, new_original)
        end,
      },
      {
        id = "bold",
        type = "toggle",
        label = "Bold",
        default = working_colors.gui and working_colors.gui:match("bold") ~= nil or false,
        key = "b",
      },
    },

    on_select = function(result)
      -- Save the final color from picker to the active target
      local target = result.custom and result.custom.target or "bg"
      working_colors[target] = result.color

      -- Build final color spec
      local final_color = {
        fg = working_colors.fg,
        bg = working_colors.bg,
      }

      -- Add bold if enabled
      if result.custom and result.custom.bold then
        final_color.gui = "bold"
      end

      on_complete(final_color)
    end,

    on_cancel = function()
      on_complete(nil)
    end,
  })
end

---Show color picker menu using a floating window
---@param name string Server or database name
---@param is_server boolean True if setting color for server, false for database
---@param current_color table? Current saved color if any
---@param inherited_tree_open boolean? Optional: was tree open (inherited from parent dialog)
---@param inherited_tree_float boolean? Optional: was tree in float mode (inherited from parent dialog)
---@param on_complete fun()? Optional callback when menu closes
function M.show_color_picker_menu(name, is_server, current_color, inherited_tree_open, inherited_tree_float, on_complete)
  local has_float, UiFloat = pcall(require, 'nvim-float.window')
  if not has_float then
    -- Fallback to simpler UI
    M._show_color_picker_menu_simple(name, is_server, current_color)
    if on_complete then on_complete() end
    return
  end

  -- Track if tree was open in float mode (to restore after menu closes)
  -- Use inherited state if provided, otherwise check current state
  local UiBuffer = require('nvim-ssns.ui.core.buffer')
  local tree_was_open = inherited_tree_open ~= nil and inherited_tree_open or UiBuffer.is_open()
  local tree_was_float = inherited_tree_float ~= nil and inherited_tree_float or UiBuffer.is_float()

  -- Flag to skip tree restoration when on_complete callback is provided (caller handles restoration)
  local skip_tree_restore = on_complete ~= nil

  -- Function to restore tree and call on_complete after any close
  local function on_close_handler()
    -- Call on_complete callback first (e.g., to reopen edit form)
    if on_complete then
      vim.schedule(on_complete)
    end

    -- Restore tree only if no on_complete callback (caller handles their own restoration)
    if not skip_tree_restore and tree_was_float and tree_was_open then
      vim.schedule(function()
        if not UiBuffer.is_open() then
          UiBuffer.open("float")
          local UiTree = require('nvim-ssns.ui.core.tree')
          UiTree.render()
        end
      end)
    end
  end

  local type_str = is_server and "server" or "database"

  -- Build menu content
  local menu_float = UiFloat.create({
    title = " Set Lualine Color ",
    width = 45,
    height = 14,
    center = true,
    content_builder = true,
    on_close = on_close_handler,
  })

  if not menu_float then
    M._show_color_picker_menu_simple(name, is_server, current_color)
    return
  end

  local cb = menu_float:get_content_builder()

  -- Header
  cb:line("")
  cb:styled("  " .. type_str:gsub("^%l", string.upper) .. ": ", "NvimFloatLabel")
  cb:styled(name, "NvimFloatTitle")
  cb:line("")
  cb:line("")

  -- Presets
  cb:styled("  Color Presets:", "NvimFloatTitle")
  cb:line("")

  for _, preset in ipairs(COLOR_PRESETS) do
    -- Create highlight for this preset's color swatch
    local hl_name = "SSNSColorPreset" .. preset.key
    vim.api.nvim_set_hl(0, hl_name, { fg = preset.color.fg, bg = preset.color.bg, bold = preset.color.gui == "bold" })

    cb:text("  ")
    cb:styled(preset.key, "NvimFloatKeyHint")
    cb:text(". ")
    cb:styled("  ", hl_name) -- Color swatch
    cb:text(" " .. preset.label)
    cb:line("")
  end

  cb:line("")
  cb:text("  ")
  cb:styled("c", "NvimFloatKeyHint")
  cb:text(". Custom (color picker)")
  cb:line("")
  cb:text("  ")
  cb:styled("r", "NvimFloatKeyHint")
  cb:text(". Remove color (use default)")
  cb:line("")

  -- Footer
  cb:line("")
  cb:styled("  Press key to select, ", "NvimFloatHint")
  cb:styled("Esc", "NvimFloatKeyHint")
  cb:styled(" to cancel", "NvimFloatHint")

  menu_float:render()

  -- Setup keymaps
  local bufnr = menu_float.buf

  -- Close handler
  local function close()
    menu_float:close()
  end

  -- Apply color and close
  local function apply_color(color)
    menu_float:close()
    if color then
      M.set_color(name, color)
      vim.notify(string.format('SSNS: Color set for %s', name), vim.log.levels.INFO)
      if vim.fn.exists(':LualineRefresh') == 2 then
        vim.cmd('LualineRefresh')
      end
    end
  end

  -- Preset keymaps
  for _, preset in ipairs(COLOR_PRESETS) do
    vim.keymap.set("n", preset.key, function()
      apply_color(preset.color)
    end, { buffer = bufnr, nowait = true })
  end

  -- Custom color
  vim.keymap.set("n", "c", function()
    -- Colorpicker will handle its own completion
    local saved_on_complete = on_complete
    local saved_skip = skip_tree_restore
    skip_tree_restore = true  -- Prevent on_close from running on_complete
    menu_float:close()
    open_colorpicker(name, current_color, function(color)
      if color then
        M.set_color(name, color)
        vim.notify(string.format('SSNS: Custom color set for %s', name), vim.log.levels.INFO)
        if vim.fn.exists(':LualineRefresh') == 2 then
          vim.cmd('LualineRefresh')
        end
      end
      -- Call on_complete callback or restore tree
      if saved_on_complete then
        vim.schedule(saved_on_complete)
      elseif not saved_skip and tree_was_float and tree_was_open then
        vim.schedule(function()
          if not UiBuffer.is_open() then
            UiBuffer.open("float")
            local UiTree = require('nvim-ssns.ui.core.tree')
            UiTree.render()
          end
        end)
      end
    end)
  end, { buffer = bufnr, nowait = true })

  -- Remove color
  vim.keymap.set("n", "r", function()
    menu_float:close()
    M.remove_color(name)
  end, { buffer = bufnr, nowait = true })

  -- Cancel
  vim.keymap.set("n", "<Esc>", close, { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "q", close, { buffer = bufnr, nowait = true })
end

---Fallback simple menu when nvim-float is not available
---@param name string Server or database name
---@param is_server boolean True if setting color for server, false for database
---@param current_color table? Current saved color if any
function M._show_color_picker_menu_simple(name, is_server, current_color)
  local type_str = is_server and 'server' or 'database'

  -- Build menu message
  local lines = {
    string.format('Set color for %s: %s', type_str, name),
    '',
    '1. Red (Production)',
    '2. Green (Development)',
    '3. Yellow (Staging)',
    '4. Blue (QA/Testing)',
    '5. Orange (UAT)',
    '6. Purple (Backup/Reporting)',
    '7. Gray (Default)',
    'c. Custom (color picker)',
    'r. Remove color',
  }

  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)

  local choice = vim.fn.input('Enter choice (1-7, c, or r): ')
  vim.cmd('redraw!')

  local color = nil

  -- Check presets
  for _, preset in ipairs(COLOR_PRESETS) do
    if choice == preset.key then
      color = preset.color
      break
    end
  end

  if color then
    M.set_color(name, color)
    vim.notify(string.format('SSNS: Color set for %s', name), vim.log.levels.INFO)
    if vim.fn.exists(':LualineRefresh') == 2 then
      vim.cmd('LualineRefresh')
    end
    return
  end

  if choice == 'c' then
    open_colorpicker(name, current_color, function(custom_color)
      if custom_color then
        M.set_color(name, custom_color)
        vim.notify(string.format('SSNS: Custom color set for %s', name), vim.log.levels.INFO)
        if vim.fn.exists(':LualineRefresh') == 2 then
          vim.cmd('LualineRefresh')
        end
      end
    end)
  elseif choice == 'r' then
    M.remove_color(name)
  else
    vim.notify('SSNS: Invalid choice', vim.log.levels.WARN)
  end
end

---Prompt user to set color for a server or database
---@param name string Server or database name
---@param is_server boolean True if setting color for server, false for database
function M.prompt_set_color(name, is_server)
  -- Check if lualine is available
  local has_lualine = pcall(require, 'lualine')
  if not has_lualine then
    vim.notify('SSNS: Lualine is not installed or not available', vim.log.levels.WARN)
    return
  end

  -- Get current color if any
  local current_color = M.get_color(name)

  -- Show the color picker menu
  M.show_color_picker_menu(name, is_server, current_color)
end

---Prompt user to set color with inherited tree state
---Used when opening from another dialog that already closed the tree
---@param name string Server or database name
---@param is_server boolean True if setting color for server, false for database
---@param tree_was_open boolean Was tree open before parent dialog opened
---@param tree_was_float boolean Was tree in float mode
---@param on_complete fun()? Optional callback when color picker closes
function M.prompt_set_color_with_tree_state(name, is_server, tree_was_open, tree_was_float, on_complete)
  -- Check if lualine is available
  local has_lualine = pcall(require, 'lualine')
  if not has_lualine then
    vim.notify('SSNS: Lualine is not installed or not available', vim.log.levels.WARN)
    if on_complete then on_complete() end
    return
  end

  -- Get current color if any
  local current_color = M.get_color(name)

  -- Show the color picker menu with inherited tree state
  M.show_color_picker_menu(name, is_server, current_color, tree_was_open, tree_was_float, on_complete)
end

---Set color for a connection (uses lualine component's set_color)
---@param name string Server or database name
---@param color table Color spec { fg, bg, gui }
function M.set_color(name, color)
  local ok, ssns_component = pcall(require, 'lualine.components.ssns')
  if ok and ssns_component.set_color then
    ssns_component.set_color(name, color)
    -- Invalidate and reload cache after color change
    M.invalidate_cache()
    M.init_async()
  else
    vim.notify('SSNS: Could not access lualine component', vim.log.levels.ERROR)
  end
end

---Remove color for a connection
---@param name string Server or database name
function M.remove_color(name)
  local ok, ssns_component = pcall(require, 'lualine.components.ssns')
  if ok and ssns_component.remove_color then
    ssns_component.remove_color(name)
    vim.notify(string.format('SSNS: Color removed for %s', name), vim.log.levels.INFO)

    -- Invalidate and reload cache after color removal
    M.invalidate_cache()
    M.init_async()

    -- Refresh lualine if available
    if vim.fn.exists(':LualineRefresh') == 2 then
      vim.cmd('LualineRefresh')
    end
  else
    vim.notify('SSNS: Could not access lualine component', vim.log.levels.ERROR)
  end
end

---Get color for a connection (from lualine component)
---Uses cached data only - never blocks on file I/O
---Call M.init_async() at startup to populate cache
---@param name string Server or database name
---@return table|nil color Color spec or nil
function M.get_color(name)
  -- Use cached data only (async loaded at startup)
  local colors = colors_cache
  if not colors then
    return nil
  end

  -- Check exact match first
  if colors[name] then
    return colors[name]
  end

  -- Check pattern matches
  for pattern, color in pairs(colors) do
    local lua_pattern = pattern:gsub('%*', '.*'):gsub('%?', '.')
    if name:match(lua_pattern) then
      return color
    end
  end

  return nil
end

---List all saved colors
---Uses cached data only - call M.init_async() at startup to populate cache
function M.list_colors()
  -- Use cached data only (async loaded at startup)
  local colors = colors_cache

  if not colors or vim.tbl_isempty(colors) then
    vim.notify('SSNS: No saved connection colors', vim.log.levels.INFO)
    return
  end

  print('Saved connection colors:')
  print('')
  for conn, color in pairs(colors) do
    print(string.format('  %s: %s', conn, vim.inspect(color)))
  end
end

-- ============================================================================
-- Async Methods
-- ============================================================================

---Get the colors file path
---@return string path
local function get_colors_file_path()
  return vim.fn.stdpath('data') .. '/nvim-ssns/lualine_colors.json'
end

---Check if cache is still valid
---@return boolean
local function is_cache_valid()
  if not colors_cache then return false end
  local elapsed = (vim.loop.hrtime() - cache_timestamp) / 1e6
  return elapsed < CACHE_TTL_MS
end

---Invalidate the colors cache
function M.invalidate_cache()
  colors_cache = nil
  cache_timestamp = 0
end

---Get the current cache (for sync access from lualine component)
---Returns nil if cache not yet populated
---@return table? cached_colors
function M._get_cache()
  return colors_cache
end

---Load colors from file asynchronously
---@param callback fun(colors: table?, error: string?)
function M.load_colors_async(callback)
  -- Return cached if valid
  if is_cache_valid() then
    callback(colors_cache, nil)
    return
  end

  local FileIO = require('nvim-ssns.async.file_io')
  local colors_file = get_colors_file_path()

  FileIO.exists_async(colors_file, function(exists)
    if not exists then
      colors_cache = {}
      cache_timestamp = vim.loop.hrtime()
      callback({}, nil)
      return
    end

    FileIO.read_json_async(colors_file, function(data, err)
      if err then
        callback(nil, err)
        return
      end

      colors_cache = data or {}
      cache_timestamp = vim.loop.hrtime()
      callback(colors_cache, nil)
    end)
  end)
end

---Get color for a connection asynchronously
---@param name string Server or database name
---@param callback fun(color: table?)
function M.get_color_async(name, callback)
  M.load_colors_async(function(colors, err)
    if err or not colors then
      callback(nil)
      return
    end

    -- Check exact match first
    if colors[name] then
      callback(colors[name])
      return
    end

    -- Check pattern matches
    for pattern, color in pairs(colors) do
      local lua_pattern = pattern:gsub('%*', '.*'):gsub('%?', '.')
      if name:match(lua_pattern) then
        callback(color)
        return
      end
    end

    callback(nil)
  end)
end

---List all saved colors asynchronously
---@param callback fun(colors: table?, error: string?)
function M.list_colors_async(callback)
  M.load_colors_async(function(colors, err)
    if err then
      callback(nil, err)
      return
    end
    callback(colors or {}, nil)
  end)
end

---Initialize colors cache asynchronously (call at startup)
---@param callback fun(success: boolean)?
function M.init_async(callback)
  M.load_colors_async(function(_, err)
    if callback then
      callback(not err)
    end
  end)
end

return M
