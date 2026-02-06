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
--             local ok, ssns = pcall(require, 'lualine.components.nvim-ssns')
--             if ok then
--               return ssns.ssns()
--             end
--             return ''
--           end,
--           icon = '\u{f1c0}',  --  (database icon)
--           color = function()
--             local ok, ssns = pcall(require, 'lualine.components.nvim-ssns')
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
--   require('nvim-ssns').setup({
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

-- Load saved colors from cache (uses lualine_colors module's async-populated cache)
-- This function NEVER blocks on file I/O - it only reads from memory cache
-- The cache is populated asynchronously at startup via LualineColors.init_async()
local function load_colors_from_file()
  -- Use the lualine_colors module which has async-populated cache
  local ok, lualine_colors = pcall(require, 'nvim-ssns.lualine_colors')
  if ok and lualine_colors._get_cache then
    -- Get from cache only (never block on file I/O)
    -- Returns empty table if cache not yet populated
    return lualine_colors._get_cache() or {}
  end

  -- Module not available - return empty (colors will be available after SSNS setup)
  return {}
end

-- Save colors to JSON file
local function save_colors_to_file(colors)
  local save_location = vim.fn.stdpath('data') .. '/nvim-ssns'

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
    local Config = require('nvim-ssns.config')
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

  local Config = require('nvim-ssns.config')
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
  local Config = require('nvim-ssns.config')
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

-- Build server/database display parts from a server object and optional database
-- @param server: ServerClass - Server object
-- @param database: DatabaseClass? - Database object
-- @param last_database: string? - Last used database name (overrides database object)
-- @return: string - Formatted "ICON SERVER | DATABASE" or empty string
local function build_connection_display(server, database, last_database)
  local db_icon = get_db_type_icon(server)
  local conn_config = server.connection_config
  local parts = {}

  -- Add server/file display
  if conn_config and conn_config.type == "sqlite" then
    local server_info = conn_config.server or {}
    local file_display = server_info.database and server_info.database:gsub("\\", "/") or ":memory:"
    table.insert(parts, db_icon .. ' ' .. file_display)
  elseif conn_config and conn_config.server then
    local server_info = conn_config.server
    local server_display = server_info.host or "unknown"
    if server_info.instance then
      server_display = server_display .. "\\" .. server_info.instance
    end
    table.insert(parts, db_icon .. ' ' .. server_display)
  end

  -- Determine current database context
  local current_db = last_database
  if not current_db and database then
    current_db = database.db_name
  end

  if current_db and current_db ~= '' then
    table.insert(parts, current_db)
  end

  if #parts > 0 then
    return table.concat(parts, ' | ')
  end

  return ''
end

-- Get ETL block info for the current cursor position
-- @return: string - Formatted ETL status or empty string
local function get_etl_status(bufnr)
  local ok, EtlHighlighting = pcall(require, 'nvim-ssns.etl.highlighting')
  if not ok or not EtlHighlighting.is_enabled(bufnr) then
    return ''
  end

  local block = EtlHighlighting.get_block_at_cursor(bufnr)
  if not block then
    return ''
  end

  -- For SQL blocks, try to get connection context
  if block.type == "sql" then
    local connection = EtlHighlighting.get_connection_at_cursor(bufnr)
    if connection and connection.server then
      local display = build_connection_display(connection.server, connection.database)
      if display ~= '' then
        return display .. ' | [' .. block.name .. ']'
      end
    end
    -- SQL block without resolved connection — show block name with server/db directives
    local parts = {}
    if block.server then table.insert(parts, block.server) end
    if block.database then table.insert(parts, block.database) end
    table.insert(parts, '[' .. block.name .. ']')
    return table.concat(parts, ' | ')
  end

  -- Lua block — just show block name with type indicator
  return '[' .. block.name .. '] (lua)'
end

-- Get ETL color for the current cursor position
-- @return: table? - Color spec or nil
local function get_etl_color(bufnr)
  local ok, EtlHighlighting = pcall(require, 'nvim-ssns.etl.highlighting')
  if not ok or not EtlHighlighting.is_enabled(bufnr) then
    return nil
  end

  local connection = EtlHighlighting.get_connection_at_cursor(bufnr)
  if not connection or not connection.server then
    return nil
  end

  -- Reuse the same color lookup logic as query buffers
  local conn_config = connection.server.connection_config
  local lookup_name = nil

  if conn_config and conn_config.type == "sqlite" then
    local server_info = conn_config.server or {}
    lookup_name = server_info.database and server_info.database:gsub("\\", "/") or ":memory:"
  elseif conn_config and conn_config.server then
    local server_info = conn_config.server
    if server_info.database and server_info.database ~= '' then
      if connection.database then
        lookup_name = connection.database.db_name
      else
        lookup_name = server_info.database
      end
    elseif server_info.host then
      lookup_name = server_info.host
      if server_info.instance then
        lookup_name = lookup_name .. "\\" .. server_info.instance
      end
    end
  end

  if not lookup_name then
    return nil
  end

  return get_connection_color(lookup_name)
end

-- Main component function - returns the statusline text
-- Format: "ICON SERVER" or "ICON SERVER | DATABASE" or "ICON SERVER | DATABASE | [BLOCK]"
-- @return: String - Formatted database connection info
function M.ssns()
  local bufnr = vim.api.nvim_get_current_buf()

  -- ETL files: show current block with connection context
  if vim.bo[bufnr].filetype == "ssns" then
    return get_etl_status(bufnr)
  end

  -- Query buffers: show connection info
  local UiQuery = require('nvim-ssns.ui.core.query')

  if not UiQuery.is_query_buffer(bufnr) then
    return ''
  end

  -- Check if buffer is connecting (show spinner)
  local connecting_info = UiQuery.get_connecting_info(bufnr)
  if connecting_info and connecting_info.connecting then
    local spinner = connecting_info.spinner_frame or "⠋"
    local target = connecting_info.server_name or "server"
    if connecting_info.database_name then
      target = target .. " | " .. connecting_info.database_name
    end
    return spinner .. " Connecting to " .. target .. "..."
  end

  -- Get server and database from buffer
  local server = UiQuery.get_server(bufnr)
  if not server then
    return ''
  end

  local database = UiQuery.get_database(bufnr)
  local buffer_info = UiQuery.query_buffers[bufnr]
  local last_database = buffer_info and buffer_info.last_database

  return build_connection_display(server, database, last_database)
end

-- Color function for the component - returns dynamic color based on connection
-- Uses server name for server-level connections, database name for database-level connections
-- @return: Table - Color spec or nil for default
function M.ssns_color()
  local bufnr = vim.api.nvim_get_current_buf()

  -- ETL files: color based on block's connection
  if vim.bo[bufnr].filetype == "ssns" then
    return get_etl_color(bufnr)
  end

  -- Query buffers
  local UiQuery = require('nvim-ssns.ui.core.query')

  if not UiQuery.is_query_buffer(bufnr) then
    return nil
  end

  -- Check if buffer is connecting (show connecting color)
  local connecting_info = UiQuery.get_connecting_info(bufnr)
  if connecting_info and connecting_info.connecting then
    -- Orange/amber color for connecting state
    return { fg = '#000000', bg = '#ff9900', gui = 'bold' }
  end

  -- Get server and database from buffer
  local server = UiQuery.get_server(bufnr)
  if not server then
    return nil
  end

  -- Use connection_config directly
  local conn_config = server.connection_config

  -- Determine what to use for color lookup
  local lookup_name = nil

  -- SQLite always uses file path for color lookup (not database name)
  if conn_config and conn_config.type == "sqlite" then
    local server_info = conn_config.server or {}
    if server_info.database then
      lookup_name = server_info.database:gsub("\\", "/")
    else
      lookup_name = ":memory:"
    end
  elseif conn_config and conn_config.server then
    local server_info = conn_config.server
    if server_info.database and server_info.database ~= '' then
      local database = UiQuery.get_database(bufnr)
      if database then
        lookup_name = database.db_name
      else
        lookup_name = server_info.database
      end
    elseif server_info.host then
      lookup_name = server_info.host
      if server_info.instance then
        lookup_name = lookup_name .. "\\" .. server_info.instance
      end
    end
  end

  if not lookup_name then
    return nil
  end

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
  local Config = require('nvim-ssns.config')
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
  local Config = require('nvim-ssns.config')
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
