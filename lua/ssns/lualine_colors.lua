---Lualine color management for SSNS
---Provides interactive color setting and persistence for server/database connections
local M = {}

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

  local type_str = is_server and 'server' or 'database'

  -- Display color presets
  local lines = {
    string.format('Set color for %s: %s', type_str, name),
    '',
    'Select a color preset or choose custom:',
    '  1. Red (Production)',
    '  2. Green (Development)',
    '  3. Yellow (Staging)',
    '  4. Blue (QA/Testing)',
    '  5. Orange (UAT)',
    '  6. Purple (Backup/Reporting)',
    '  7. Gray (Default)',
    '  8. Custom (enter hex codes)',
    '  9. Remove color (use lualine default)',
    '',
  }

  -- Print all lines
  for _, line in ipairs(lines) do
    print(line)
  end

  local choice = vim.fn.input('Enter choice (1-9): ')
  vim.cmd('redraw!')

  local color = nil

  if choice == '1' then
    color = { fg = '#ffffff', bg = '#cc0000', gui = 'bold' }
  elseif choice == '2' then
    color = { fg = '#000000', bg = '#00cc00' }
  elseif choice == '3' then
    color = { fg = '#000000', bg = '#cccc00' }
  elseif choice == '4' then
    color = { fg = '#ffffff', bg = '#0066cc' }
  elseif choice == '5' then
    color = { fg = '#000000', bg = '#ff9900' }
  elseif choice == '6' then
    color = { fg = '#ffffff', bg = '#9933cc' }
  elseif choice == '7' then
    color = { fg = '#ffffff', bg = '#666666' }
  elseif choice == '8' then
    -- Custom color entry
    print('')
    local fg = vim.fn.input('Foreground color (hex, e.g., #ffffff): ')
    if not fg:match('^#[0-9a-fA-F]\\{6\\}$') then
      vim.notify('SSNS: Invalid foreground color. Must be hex format like #ffffff', vim.log.levels.ERROR)
      return
    end

    local bg = vim.fn.input('Background color (hex, e.g., #ff0000): ')
    if not bg:match('^#[0-9a-fA-F]\\{6\\}$') then
      vim.notify('SSNS: Invalid background color. Must be hex format like #ff0000', vim.log.levels.ERROR)
      return
    end

    local gui = vim.fn.input('Text style (bold/italic/underline, or leave empty): ')

    color = { fg = fg, bg = bg }
    if gui ~= '' then
      color.gui = gui
    end
    vim.cmd('redraw!')
  elseif choice == '9' then
    -- Remove color
    M.remove_color(name)
    return
  else
    vim.notify('SSNS: Invalid choice', vim.log.levels.WARN)
    return
  end

  -- Save the color
  M.set_color(name, color)

  vim.notify(string.format('SSNS: Color set for %s: %s', name, vim.inspect(color)), vim.log.levels.INFO)

  -- Refresh lualine if available
  if vim.fn.exists(':LualineRefresh') == 2 then
    vim.cmd('LualineRefresh')
  end
end

---Set color for a connection (uses lualine component's set_color)
---@param name string Server or database name
---@param color table Color spec { fg, bg, gui }
function M.set_color(name, color)
  local ok, ssns_component = pcall(require, 'lualine.components.ssns')
  if ok and ssns_component.set_color then
    ssns_component.set_color(name, color)
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

    -- Refresh lualine if available
    if vim.fn.exists(':LualineRefresh') == 2 then
      vim.cmd('LualineRefresh')
    end
  else
    vim.notify('SSNS: Could not access lualine component', vim.log.levels.ERROR)
  end
end

---Get color for a connection (from lualine component)
---@param name string Server or database name
---@return table|nil color Color spec or nil
function M.get_color(name)
  -- Load colors from file
  local save_location = vim.fn.stdpath('data') .. '/ssns'
  local colors_file = save_location .. '/lualine_colors.json'

  if vim.fn.filereadable(colors_file) == 0 then
    return nil
  end

  local ok, content = pcall(vim.fn.readfile, colors_file)
  if not ok then
    return nil
  end

  local json_str = table.concat(content, '\n')
  ok, colors = pcall(vim.json.decode, json_str)
  if not ok then
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
function M.list_colors()
  local save_location = vim.fn.stdpath('data') .. '/ssns'
  local colors_file = save_location .. '/lualine_colors.json'

  if vim.fn.filereadable(colors_file) == 0 then
    vim.notify('SSNS: No saved connection colors', vim.log.levels.INFO)
    return
  end

  local ok, content = pcall(vim.fn.readfile, colors_file)
  if not ok then
    vim.notify('SSNS: Failed to read colors file', vim.log.levels.ERROR)
    return
  end

  local json_str = table.concat(content, '\n')
  ok, colors = pcall(vim.json.decode, json_str)
  if not ok then
    vim.notify('SSNS: Failed to parse colors file', vim.log.levels.ERROR)
    return
  end

  if vim.tbl_isempty(colors) then
    vim.notify('SSNS: No saved connection colors', vim.log.levels.INFO)
    return
  end

  print('Saved connection colors:')
  print('')
  for conn, color in pairs(colors) do
    print(string.format('  %s: %s', conn, vim.inspect(color)))
  end
end

return M
