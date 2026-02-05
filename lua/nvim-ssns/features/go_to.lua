---@class GoTo
---Navigate from SQL buffer to tree object
---Allows jumping from an SQL identifier (table, view, etc.) to its location in the database tree
local GoTo = {}

---Get the identifier at cursor position
---Handles: table_name, schema.table_name, [dbo].[Users], database.schema.table
---@param line string The current line text
---@param col number 0-indexed column position
---@return string? identifier The identifier under cursor
---@return number? start_col Start column of identifier (0-indexed)
---@return number? end_col End column of identifier (0-indexed, exclusive)
function GoTo.get_identifier_at_cursor(line, col)
  if not line or #line == 0 then
    return nil
  end

  -- Expand left from cursor to find identifier start
  -- Include: alphanumeric, underscore, brackets, dots
  local start_col = col + 1  -- 1-indexed for string operations
  while start_col > 1 do
    local char = line:sub(start_col - 1, start_col - 1)
    if char:match("[%w_%[%]%.]") then
      start_col = start_col - 1
    else
      break
    end
  end

  -- Expand right from cursor to find identifier end
  local end_col = col + 1  -- 1-indexed
  while end_col <= #line do
    local char = line:sub(end_col, end_col)
    if char:match("[%w_%[%]]") then
      end_col = end_col + 1
    else
      break
    end
  end

  if start_col >= end_col then
    return nil
  end

  local identifier = line:sub(start_col, end_col - 1)

  -- Don't return empty or whitespace-only identifiers
  if not identifier or identifier:match("^%s*$") then
    return nil
  end

  -- Return 0-indexed columns for API consistency
  return identifier, start_col - 1, end_col - 1
end

---Parse a potentially qualified identifier into parts
---@param identifier string e.g., "dbo.Users" or "[schema].[table]"
---@return string? database_name Database name (for 3-part names)
---@return string? schema_name Schema name
---@return string object_name Object name
function GoTo.parse_identifier(identifier)
  if not identifier then
    return nil, nil, ""
  end

  -- Remove brackets: [dbo].[Users] -> dbo.Users
  local clean = identifier:gsub("%[", ""):gsub("%]", "")

  -- Split by dot
  local parts = {}
  for part in clean:gmatch("[^%.]+") do
    if part and #part > 0 then
      table.insert(parts, part)
    end
  end

  if #parts == 1 then
    return nil, nil, parts[1]  -- No schema qualifier
  elseif #parts == 2 then
    return nil, parts[1], parts[2]  -- schema.object
  elseif #parts >= 3 then
    -- database.schema.object - use last three parts
    return parts[#parts - 2], parts[#parts - 1], parts[#parts]
  end

  return nil, nil, identifier
end

---Find an object in a collection by name (case-insensitive)
---@param collection table[] Array of database objects
---@param object_name string The name to search for
---@return BaseDbObject? The found object or nil
local function find_in_collection(collection, object_name)
  if not collection then
    return nil
  end

  local lower_name = object_name:lower()
  for _, obj in ipairs(collection) do
    local obj_name = obj.table_name or obj.view_name or obj.procedure_name
                     or obj.function_name or obj.synonym_name or obj.name
    if obj_name and obj_name:lower() == lower_name then
      return obj
    end
  end
  return nil
end

---Resolve identifier to a database object
---@param bufnr number Buffer number
---@param object_name string The SQL object name
---@param schema_name string? Optional schema name
---@param database_name string? Optional database name
---@return BaseDbObject? object The resolved database object
---@return string? error_msg Error message if not found
function GoTo.resolve_object(bufnr, object_name, schema_name, database_name)
  -- Get connection context for this buffer
  local SemanticHighlighter = require('nvim-ssns.highlighting.semantic')
  local connection = SemanticHighlighter._get_connection(bufnr)

  if not connection then
    return nil, "No database connection for this buffer"
  end

  local database = connection.database

  if not database then
    return nil, "No database selected"
  end

  -- Check if this is an alias first (before looking up in database)
  -- Only check if it's a single-part name (no schema/database qualifier)
  if not schema_name and not database_name then
    local StatementCache = require('nvim-ssns.completion.statement_cache')
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line, col = cursor[1], cursor[2]

    local context = StatementCache.get_context_at_position(bufnr, line, col + 1, connection)
    if context and context.aliases then
      local alias_ref = context.aliases[object_name:lower()]
      if alias_ref then
        -- Found an alias - resolve it to the underlying object
        if type(alias_ref) == "table" then
          -- alias_ref is a table reference with name, schema, database
          if alias_ref.is_subquery then
            return nil, string.format("'%s' is a subquery alias (derived table) - no metadata available", object_name)
          end
          -- Use the alias's underlying table/view name
          object_name = alias_ref.name or object_name
          schema_name = alias_ref.schema
          database_name = alias_ref.database
        elseif type(alias_ref) == "string" then
          -- alias_ref is a string like "tablename" or "schema.tablename"
          if alias_ref == "(subquery)" then
            return nil, string.format("'%s' is a subquery alias (derived table) - no metadata available", object_name)
          end
          -- Parse the reference
          local parts = {}
          for part in alias_ref:gmatch("[^%.]+") do
            table.insert(parts, part)
          end
          if #parts == 1 then
            object_name = parts[1]
          elseif #parts == 2 then
            schema_name = parts[1]
            object_name = parts[2]
          elseif #parts >= 3 then
            database_name = parts[1]
            schema_name = parts[2]
            object_name = parts[3]
          end
        end
      end
    end
  end

  -- Handle cross-database references if database_name is provided
  if database_name then
    local server = connection.server or (database and database.parent)
    if server then
      local target_db = server:get_database(database_name)
      if target_db then
        database = target_db
        -- Load the database if needed
        if not target_db.is_loaded then
          target_db:load()
        end
      else
        return nil, string.format("Database '%s' not found", database_name)
      end
    end
  end

  -- Get adapter to check for schema support
  local adapter = database:get_adapter()
  local has_schemas = adapter and adapter.features and adapter.features.schemas

  -- Use default schema if not specified (SQL Server default is dbo)
  local target_schema = schema_name
  if has_schemas and not target_schema then
    target_schema = "dbo"
  end

  -- For schema-based servers (SQL Server, PostgreSQL)
  if has_schemas and target_schema then
    -- Find the schema
    local schema = database:find_schema(target_schema)
    if not schema then
      return nil, string.format("Schema '%s' not found", target_schema)
    end

    -- Ensure schema objects are loaded
    if not schema.is_loaded then
      schema:load()
    end

    -- Search in order: tables, views, procedures, functions, synonyms
    local search_collections = {
      { getter = schema.get_tables, collection = schema.tables },
      { getter = schema.get_views, collection = schema.views },
      { getter = schema.get_procedures, collection = schema.procedures },
      { getter = schema.get_functions, collection = schema.functions },
      { getter = schema.get_synonyms, collection = schema.synonyms },
    }

    for _, search in ipairs(search_collections) do
      -- Try getter if available, else use collection directly
      local collection = search.getter and search.getter(schema) or search.collection
      local found = find_in_collection(collection, object_name)
      if found then
        return found
      end
    end

    return nil, string.format("Object '%s.%s' not found", target_schema, object_name)
  end

  -- For non-schema servers (MySQL, SQLite)
  -- Search directly on database
  local search_collections = {
    database:get_tables(),
    database:get_views(),
    database:get_procedures(),
    database:get_functions(),
  }

  for _, collection in ipairs(search_collections) do
    local found = find_in_collection(collection, object_name)
    if found then
      return found
    end
  end

  return nil, string.format("Object '%s' not found", object_name)
end

---Main entry point: go to the object under cursor
function GoTo.go_to_object_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]

  -- Get current line
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  if not line then
    vim.notify("Cannot read current line", vim.log.levels.WARN)
    return
  end

  -- Get identifier at cursor
  local identifier = GoTo.get_identifier_at_cursor(line, col)
  if not identifier or identifier == "" then
    vim.notify("No identifier under cursor", vim.log.levels.WARN)
    return
  end

  -- Parse into database, schema, and object name
  local database_name, schema_name, object_name = GoTo.parse_identifier(identifier)

  -- Resolve to database object
  local target_object, error_msg = GoTo.resolve_object(bufnr, object_name, schema_name, database_name)
  if not target_object then
    vim.notify(error_msg or "Object not found", vim.log.levels.WARN)
    return
  end

  -- Open tree if needed
  local Ssns = require('nvim-ssns')
  Ssns.open()

  -- Navigate to object
  local UiTree = require('nvim-ssns.ui.core.tree')
  UiTree.navigate_to_object(target_object)
end

return GoTo

