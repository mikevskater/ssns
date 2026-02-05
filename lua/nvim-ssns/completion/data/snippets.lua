---SQL snippet definitions for completion
---@class SnippetData
local Snippets = {}

---Cached user snippets (loaded asynchronously at init)
---@type table[]?
Snippets._user_snippets_cache = nil

---Whether async loading is in progress
Snippets._loading = false

---Common SQL snippets (all databases)
Snippets.common = {
  {
    label = "select",
    description = "SELECT statement",
    insertText = "SELECT ${1:columns}\nFROM ${2:table}\nWHERE ${3:condition}",
  },
  {
    label = "insert",
    description = "INSERT statement",
    insertText = "INSERT INTO ${1:table} (${2:columns})\nVALUES (${3:values})",
  },
  {
    label = "update",
    description = "UPDATE statement",
    insertText = "UPDATE ${1:table}\nSET ${2:column} = ${3:value}\nWHERE ${4:condition}",
  },
  {
    label = "delete",
    description = "DELETE statement",
    insertText = "DELETE FROM ${1:table}\nWHERE ${2:condition}",
  },
  {
    label = "join",
    description = "INNER JOIN",
    insertText = "INNER JOIN ${1:table} ON ${2:condition}",
  },
  {
    label = "leftjoin",
    description = "LEFT JOIN",
    insertText = "LEFT JOIN ${1:table} ON ${2:condition}",
  },
  {
    label = "case",
    description = "CASE expression",
    insertText = "CASE\n\tWHEN ${1:condition} THEN ${2:result}\n\tELSE ${3:default}\nEND",
  },
  {
    label = "createtable",
    description = "CREATE TABLE statement",
    insertText = "CREATE TABLE ${1:table_name} (\n\t${2:column_name} ${3:data_type}\n)",
  },
}

---SQL Server specific snippets
Snippets.sqlserver = {
  {
    label = "selecttop",
    description = "SELECT TOP N",
    insertText = "SELECT TOP ${1:10} ${2:columns}\nFROM ${3:table}",
  },
  {
    label = "trycatch",
    description = "TRY...CATCH block",
    insertText = "BEGIN TRY\n\t${1:-- code}\nEND TRY\nBEGIN CATCH\n\t${2:-- error handling}\nEND CATCH",
  },
  {
    label = "ifexists",
    description = "IF EXISTS statement",
    insertText = "IF EXISTS (SELECT 1 FROM ${1:table} WHERE ${2:condition})\nBEGIN\n\t${3:-- code}\nEND",
  },
}

---PostgreSQL specific snippets
Snippets.postgres = {
  {
    label = "selectlimit",
    description = "SELECT with LIMIT",
    insertText = "SELECT ${1:columns}\nFROM ${2:table}\nLIMIT ${3:10}",
  },
  {
    label = "returning",
    description = "INSERT with RETURNING",
    insertText = "INSERT INTO ${1:table} (${2:columns})\nVALUES (${3:values})\nRETURNING ${4:id}",
  },
}

---MySQL specific snippets
Snippets.mysql = {
  {
    label = "selectlimit",
    description = "SELECT with LIMIT",
    insertText = "SELECT ${1:columns}\nFROM ${2:table}\nLIMIT ${3:10}",
  },
}

---SQLite specific snippets
Snippets.sqlite = {
  {
    label = "selectlimit",
    description = "SELECT with LIMIT",
    insertText = "SELECT ${1:columns}\nFROM ${2:table}\nLIMIT ${3:10}",
  },
}

---Get snippets for specific database type
---@param db_type string Database type
---@return table[] snippets Combined snippet list
function Snippets.get_for_database(db_type)
  local result = vim.deepcopy(Snippets.common)

  if db_type == "sqlserver" then
    vim.list_extend(result, Snippets.sqlserver)
  elseif db_type == "postgres" or db_type == "postgresql" then
    vim.list_extend(result, Snippets.postgres)
  elseif db_type == "mysql" then
    vim.list_extend(result, Snippets.mysql)
  elseif db_type == "sqlite" then
    vim.list_extend(result, Snippets.sqlite)
  end

  return result
end

---Load user-defined snippets from file
---Returns cached version if available (async-loaded at init)
---Call Snippets.init_async() at plugin startup to populate cache
---@return table[] snippets User snippet list (empty if not yet loaded)
function Snippets.load_user_snippets()
  -- Return cached snippets if available (async-loaded at startup)
  -- If cache is not populated, return empty array
  -- The async init should be called at plugin startup
  return Snippets._user_snippets_cache or {}
end

---Initialize user snippets cache asynchronously
---Should be called at plugin startup
---@param callback fun(success: boolean, error: string?)? Optional callback
function Snippets.init_async(callback)
  -- Don't reload if already loaded or loading
  if Snippets._user_snippets_cache or Snippets._loading then
    if callback then callback(true, nil) end
    return
  end

  Snippets._loading = true

  Snippets.load_user_snippets_async(function(snippets, err)
    Snippets._loading = false

    if err then
      Snippets._user_snippets_cache = {} -- Empty cache on error
      if callback then callback(false, err) end
      return
    end

    Snippets._user_snippets_cache = snippets or {}
    if callback then callback(true, nil) end
  end)
end

---Reload user snippets (clears cache and reloads)
---@param callback fun(success: boolean, error: string?)? Optional callback
function Snippets.reload_async(callback)
  Snippets._user_snippets_cache = nil
  Snippets._loading = false
  Snippets.init_async(callback)
end

-- ============================================================================
-- Async Methods
-- ============================================================================

---Load user-defined snippets from file asynchronously
---@param callback fun(snippets: table[], error: string?)
function Snippets.load_user_snippets_async(callback)
  local FileIO = require('nvim-ssns.async.file_io')

  local data_path = vim.fn.stdpath('data')
  local snippets_file = data_path .. '/ssns/snippets.json'

  -- Check if file exists
  FileIO.exists_async(snippets_file, function(exists, _)
    if not exists then
      callback({}, nil)
      return
    end

    FileIO.read_json_async(snippets_file, function(data, err)
      if err then
        callback({}, err)
        return
      end

      callback(data or {}, nil)
    end)
  end)
end

return Snippets
