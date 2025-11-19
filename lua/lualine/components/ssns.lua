-- ==============================================================================
-- Lualine Component for SSNS (SQL Server NeoVim Studio)
-- ==============================================================================
-- Displays current database connection information in lualine with customizable
-- colors per connection (similar to Redgate's SSMS color-coding feature)
--
-- Usage:
--   require('lualine').setup {
--     sections = {
--       lualine_c = {
--         {
--           function()
--             local ok, ssns = pcall(require, 'lualine.components.ssns')
--             if ok then
--               return ssns.ssns()
--             end
--             return ''
--           end,
--           icon = '\u{f1c0}',  --  (database icon)
--           color = function()
--             local ok, ssns = pcall(require, 'lualine.components.ssns')
--             if ok then
--               return ssns.ssns_color()
--             end
--             return nil
--           end
--         }
--       }
--     }
--   }
--
-- Configuration (set in setup):
--   require('ssns').setup({
--     lualine = {
--       enabled = true,
--       colors = {
--         ['ProductionDB'] = { fg = '#ffffff', bg = '#ff0000' },  -- Red for production
--         ['DevDB'] = { fg = '#000000', bg = '#00ff00' },         -- Green for dev
--       },
--       default_color = { fg = '#ffffff', bg = '#0000ff' },  -- Blue default
--       save_colors = true,  -- Save colors to file
--     }
--   })
-- ==============================================================================

local M = {}

-- Load saved colors from JSON file
local function load_colors_from_file()
  -- Get save location from config
  local Config = require('ssns.config')
  local config = Config.get()

  local save_location = vim.fn.stdpath('data') .. '/ssns'
  local colors_file = save_location .. '/lualine_colors.json'

  -- Check if file exists
  if vim.fn.filereadable(colors_file) == 0 then
    return {}
  end

  -- Read and decode JSON
  local ok, content = pcall(vim.fn.readfile, colors_file)
  if not ok then
    return {}
  end

  local json_str = table.concat(content, '\n')
  ok, saved_colors = pcall(vim.json.decode, json_str)
  if not ok then
    return {}
  end

  return saved_colors
end

-- Save colors to JSON file
local function save_colors_to_file(colors)
  local save_location = vim.fn.stdpath('data') .. '/ssns'

  -- Create directory if it doesn't exist
  vim.fn.mkdir(save_location, 'p')

  local colors_file = save_location .. '/lualine_colors.json'

  -- Encode and write JSON
  local ok, json_str = pcall(vim.json.encode, colors)
  if not ok then
    return false
  end

  ok = pcall(vim.fn.writefile, { json_str }, colors_file)
  return ok
end

-- Load saved colors on first use
local colors_loaded = false
local merged_colors = {}

local function ensure_colors_loaded()
  if not colors_loaded then
    local Config = require('ssns.config')
    local config = Config.get()

    -- Get colors from config
    local config_colors = {}
    if config.lualine and config.lualine.colors then
      config_colors = config.lualine.colors
    end

    -- Load saved colors from file
    local saved_colors = load_colors_from_file()

    -- Merge: saved colors take precedence over config colors
    merged_colors = vim.tbl_extend('force', config_colors, saved_colors)

    colors_loaded = true
  end
end

-- Get color configuration for a server or database connection
-- @param lookup_name: String - Server or database name for color lookup
-- @return: Table - Color spec { fg = '#rrggbb', bg = '#rrggbb', gui = 'style' }
local function get_connection_color(lookup_name)
  -- Ensure saved colors are loaded
  ensure_colors_loaded()

  local Config = require('ssns.config')
  local config = Config.get()

  -- Get default color from config
  local default_color = nil
  if config.lualine and config.lualine.default_color then
    default_color = config.lualine.default_color
  end

  -- If no colors configured, return nil to use lualine's default
  if vim.tbl_isempty(merged_colors) and not default_color then
    return nil
  end

  -- Look for exact match first
  if merged_colors[lookup_name] then
    return merged_colors[lookup_name]
  end

  -- Look for pattern matches (e.g., 'prod*', '*production*')
  for pattern, color in pairs(merged_colors) do
    -- Convert glob pattern to lua pattern
    local lua_pattern = pattern:gsub('%*', '.*'):gsub('%?', '.')
    if lookup_name:match(lua_pattern) then
      return color
    end
  end

  -- Return default color or nil
  return default_color
end

-- Get database type icon
-- @param server: ServerClass - Server object
-- @return: String - Database type icon
local function get_db_type_icon(server)
  local Config = require('ssns.config')
  local icons = Config.get_ui().icons

  -- Get database type from server
  local db_type = nil
  if server.get_db_type then
    db_type = server:get_db_type()
  elseif server.adapter and server.adapter.db_type then
    db_type = server.adapter.db_type
  end

  -- Map database type to icon
  if db_type == "sqlserver" then
    return icons.server_sqlserver or icons.server
  elseif db_type == "postgres" or db_type == "postgresql" then
    return icons.server_postgres or icons.server
  elseif db_type == "mysql" then
    return icons.server_mysql or icons.server
  elseif db_type == "sqlite" then
    return icons.server_sqlite or icons.server
  elseif db_type == "bigquery" then
    return icons.server_bigquery or icons.server
  else
    return icons.server
  end
end

-- Main component function - returns the statusline text
-- Format: "ICON SERVER" or "ICON SERVER | DATABASE"
-- @return: String - Formatted database connection info
function M.ssns()
  -- Check if we're in an SSNS query buffer
  local UiQuery = require('ssns.ui.query')
  local bufnr = vim.api.nvim_get_current_buf()

  if not UiQuery.is_query_buffer(bufnr) then
    return ''
  end

  -- Get server and database from buffer
  local server = UiQuery.get_server(bufnr)
  local database = UiQuery.get_database(bufnr)

  if not server then
    return ''
  end

  -- Get database type icon
  local db_icon = get_db_type_icon(server)

  -- Get buffer info for last_database
  local buffer_info = UiQuery.query_buffers[bufnr]
  local last_database = buffer_info and buffer_info.last_database

  -- Parse connection string
  local ConnectionString = require('ssns.connection_string')
  local parsed = ConnectionString.parse(server.connection_string)

  -- Build the status string
  local parts = {}

  -- Add server/file display
  if parsed.scheme == "sqlite" then
    -- For SQLite, show the full file path
    -- Note: The parser incorrectly splits Windows paths, treating drive letter as host
    -- and the rest as instance. We need to reconstruct the full path.
    local file_display = ":memory:"
    if parsed.host then
      file_display = parsed.host
      if parsed.instance then
        -- Reconstruct: host is "C:", instance is "Users/.../master", path is "/master.mdb"
        file_display = file_display .. "/" .. parsed.instance
      end
      if parsed.path then
        file_display = file_display .. parsed.path
      end
    elseif parsed.path then
      -- Just path (remove leading slash)
      file_display = parsed.path:match("^/(.*)") or parsed.path
    end
    table.insert(parts, db_icon .. ' ' .. file_display)
  elseif parsed.host then
    -- For other databases, show host[\instance]
    local server_display = parsed.host
    if parsed.instance then
      server_display = server_display .. "\\" .. parsed.instance
    end
    table.insert(parts, db_icon .. ' ' .. server_display)
  end

  -- Determine current database context
  -- Priority: last_database (from USE) > database.db_name (from tree) > parsed.database (from connection string)
  local current_db = last_database
  if not current_db and database then
    current_db = database.db_name
  end
  if not current_db and parsed.database and parsed.database ~= '' then
    current_db = parsed.database
  end

  -- Add database if we have one
  if current_db and current_db ~= '' then
    table.insert(parts, current_db)
  end

  -- Format: "ICON SERVER" or "ICON SERVER | DATABASE"
  if #parts > 0 then
    return table.concat(parts, ' | ')
  end

  return ''
end

-- Color function for the component - returns dynamic color based on connection
-- Uses server name for server-level connections, database name for database-level connections
-- @return: Table - Color spec or nil for default
function M.ssns_color()
  local UiQuery = require('ssns.ui.query')
  local bufnr = vim.api.nvim_get_current_buf()

  if not UiQuery.is_query_buffer(bufnr) then
    return nil
  end

  -- Get server and database from buffer
  local server = UiQuery.get_server(bufnr)
  if not server then
    return nil
  end

  -- Parse connection string to check if database was specified
  local ConnectionString = require('ssns.connection_string')
  local parsed = ConnectionString.parse(server.connection_string)

  -- Determine what to use for color lookup
  local lookup_name = nil

  -- SQLite always uses file path for color lookup (not database name)
  if parsed.scheme == "sqlite" then
      -- For SQLite, use the full file path for color lookup
      -- Note: The parser incorrectly splits Windows paths into host/instance/path
      if parsed.host then
        lookup_name = parsed.host
        if parsed.instance then
          -- Reconstruct full path from split parts
          lookup_name = lookup_name .. "/" .. parsed.instance
        end
        if parsed.path then
          lookup_name = lookup_name .. parsed.path
        end
        -- Normalize backslashes to forward slashes for consistency
        lookup_name = lookup_name:gsub("\\", "/")
      elseif parsed.path then
        -- Just path (remove leading slash)
        lookup_name = parsed.path:match("^/(.*)") or parsed.path
        lookup_name = lookup_name:gsub("\\", "/")
      else
        lookup_name = ":memory:"
      end
  elseif parsed.database and parsed.database ~= '' then
    -- Database-level connection: use database name for color
    local database = UiQuery.get_database(bufnr)
    if database then
      lookup_name = database.db_name
    else
      lookup_name = parsed.database
    end
  else
    -- Server-level connection: use server name for color
    if parsed.host then
      -- Build server name: host[\instance]
      lookup_name = parsed.host
      if parsed.instance then
        lookup_name = lookup_name .. "\\" .. parsed.instance
      end
    end
  end

  if not lookup_name then
    return nil
  end

  -- Get color for this connection
  return get_connection_color(lookup_name)
end

-- Set custom color for a server or database connection
-- @param name: String - Server or database name
-- @param color: Table - Color spec { fg = '#rrggbb', bg = '#rrggbb', gui = 'style' }
function M.set_color(name, color)
  ensure_colors_loaded()

  -- Update color in merged colors
  merged_colors[name] = color

  -- Save to file if enabled
  local Config = require('ssns.config')
  local config = Config.get()

  if config.lualine and config.lualine.save_colors then
    save_colors_to_file(merged_colors)
  end
end

-- Remove custom color for a server or database connection
-- @param name: String - Server or database name
function M.remove_color(name)
  ensure_colors_loaded()

  -- Remove color
  merged_colors[name] = nil

  -- Save to file if enabled
  local Config = require('ssns.config')
  local config = Config.get()

  if config.lualine and config.lualine.save_colors then
    save_colors_to_file(merged_colors)
  end
end

-- Lualine component init function
-- This is called by lualine when the component is loaded
function M:init(options)
  -- Store component options
  self.options = vim.tbl_extend('keep', options or {}, {
    icon = '\u{f1c0}',  -- Database icon (Nerd Font)
  })
end

-- Lualine component update_status function
-- This is called by lualine to get the current status text
function M:update_status()
  return M.ssns()
end

-- Make the module callable (alternative interface)
setmetatable(M, {
  __call = function()
    return M.ssns()
  end
})

return M
