---Buffer connection utilities for SSNS
---Provides a centralized way to get database connection context for a buffer
---Eliminates duplicated connection-fetching logic across features
---@module ssns.utils.buffer_connection

local M = {}

local Debug = require('nvim-ssns.debug')

---Connection context returned by all get_* functions
---@class ConnectionContext
---@field server ServerClass The server object
---@field database DbClass The database object
---@field connection_config table The connection configuration

---Get connection context from buffer-local ssns_db_key variable
---This is the primary method for query buffers with explicit database context
---@param bufnr number Buffer number
---@return ConnectionContext? connection Connection context or nil
local function get_from_db_key(bufnr)
  local Cache = require('nvim-ssns.cache')

  local db_key = vim.b[bufnr].ssns_db_key
  if not db_key then
    return nil
  end

  -- Parse db_key format: "server_name:database_name"
  local server_name, db_name = db_key:match("^([^:]+):(.+)$")
  if not server_name or not db_name then
    Debug.log(string.format("[BUFFER_CONNECTION] Invalid db_key format: %s", db_key))
    return nil
  end

  -- Find server in cache
  local server = Cache.find_server(server_name)
  if not server then
    Debug.log(string.format("[BUFFER_CONNECTION] Server not found: %s", server_name))
    return nil
  end

  -- Find database on server
  local database = server:find_database(db_name)
  if not database then
    Debug.log(string.format("[BUFFER_CONNECTION] Database not found: %s on %s", db_name, server_name))
    return nil
  end

  return {
    server = server,
    database = database,
    connection_config = server.connection_config,
  }
end

---Get connection context from global active database
---Fallback method when no buffer-specific connection is set
---@return ConnectionContext? connection Connection context or nil
local function get_from_active_database()
  local Cache = require('nvim-ssns.cache')

  local active_db = Cache.get_active_database()
  if not active_db then
    return nil
  end

  local server = active_db.parent
  if not server then
    Debug.log("[BUFFER_CONNECTION] Active database has no parent server")
    return nil
  end

  return {
    server = server,
    database = active_db,
    connection_config = server.connection_config,
  }
end

---Get connection context for a buffer
---Tries buffer-local connection first, then falls back to global active database
---@param bufnr number? Buffer number (defaults to current buffer)
---@return ConnectionContext? connection Connection context or nil if no connection available
function M.get_connection(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Try buffer-local connection first (explicit database context)
  local connection = get_from_db_key(bufnr)
  if connection then
    Debug.log(string.format("[BUFFER_CONNECTION] Got connection from db_key for buffer %d", bufnr))
    return connection
  end

  -- Fall back to global active database
  connection = get_from_active_database()
  if connection then
    Debug.log(string.format("[BUFFER_CONNECTION] Got connection from active database for buffer %d", bufnr))
    return connection
  end

  Debug.log(string.format("[BUFFER_CONNECTION] No connection found for buffer %d", bufnr))
  return nil
end

---Get connection context using only the buffer-local db_key
---Use this when you need the explicit buffer connection only
---@param bufnr number? Buffer number (defaults to current buffer)
---@return ConnectionContext? connection Connection context or nil
function M.get_buffer_connection(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return get_from_db_key(bufnr)
end

---Get connection context from the global active database only
---Use this when you want the tree-selected database regardless of buffer
---@return ConnectionContext? connection Connection context or nil
function M.get_active_connection()
  return get_from_active_database()
end

---Check if a buffer has an associated database connection
---@param bufnr number? Buffer number (defaults to current buffer)
---@return boolean has_connection True if buffer has a connection
function M.has_connection(bufnr)
  return M.get_connection(bufnr) ~= nil
end

---Get the database key string for a buffer
---@param bufnr number? Buffer number (defaults to current buffer)
---@return string? db_key The db_key in "server:database" format, or nil
function M.get_db_key(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.b[bufnr].ssns_db_key
end

---Set the database key for a buffer
---@param bufnr number Buffer number
---@param server_name string Server name
---@param database_name string Database name
function M.set_db_key(bufnr, server_name, database_name)
  vim.b[bufnr].ssns_db_key = string.format("%s:%s", server_name, database_name)
end

---Get connection info as a formatted string (for display)
---@param bufnr number? Buffer number (defaults to current buffer)
---@return string info Connection info string or "No connection"
function M.get_connection_info(bufnr)
  local connection = M.get_connection(bufnr)
  if not connection then
    return "No connection"
  end

  local server_name = connection.server and connection.server.name or "unknown"
  local db_name = connection.database and (connection.database.db_name or connection.database.name) or "unknown"

  return string.format("%s:%s", server_name, db_name)
end

return M
