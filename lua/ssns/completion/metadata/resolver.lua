---Metadata resolver for table/view/synonym references
---Resolves aliases, schema-qualified names, and synonym chains to actual database objects
---@class MetadataResolver
local Resolver = {}

---Resolve table/view/synonym reference to actual object
---Handles aliases, schema-qualified names, and synonym chains
---@param reference string Table reference (could be alias, table name, or synonym)
---@param connection table Connection context { server: ServerClass, database: DbClass, connection_string: string }
---@param bufnr number Buffer number (for alias resolution)
---@return table? table_obj Resolved TableClass/ViewClass or nil if not found
function Resolver.resolve_table(reference, connection, bufnr)
  if not reference or not connection or not connection.database then
    return nil
  end

  -- Step 1: Try to resolve as alias first
  local Context = require('ssns.completion.context')
  local resolved_name = Context.resolve_alias(reference, bufnr)

  if resolved_name then
    -- Alias was resolved, use the resolved table name
    reference = resolved_name
  end

  -- Step 2: Parse schema-qualified name if present
  local schema, table_name = Resolver._parse_qualified_name(reference)

  -- Step 3: Search for table in database
  local database = connection.database

  -- Ensure database is loaded
  if not database.is_loaded then
    local success = pcall(function()
      database:load()
    end)
    if not success then
      return nil
    end
  end

  -- Get default schema if no schema specified
  local default_schema = Resolver._get_default_schema(connection.server)
  local search_schemas = {}

  if schema then
    -- Search only specified schema
    table.insert(search_schemas, schema)
  else
    -- Search default schema first, then all others
    if default_schema then
      table.insert(search_schemas, default_schema)
    end
  end

  -- Search in tables, views, and synonyms groups
  local groups_to_search = { 'tables_group', 'views_group', 'synonyms_group' }

  for _, group_type in ipairs(groups_to_search) do
    -- Find the group in database children
    local group = nil
    for _, child in ipairs(database.children) do
      if child.object_type == group_type then
        group = child
        break
      end
    end

    if group then
      -- Search in this group
      for _, obj in ipairs(group.children) do
        local obj_name = obj.name or obj.table_name or obj.view_name or obj.synonym_name
        local obj_schema = obj.schema or obj.schema_name

        -- Match table name
        if obj_name:lower() == table_name:lower() then
          -- If schema specified, must match
          if schema then
            if obj_schema and obj_schema:lower() == schema:lower() then
              -- If synonym, resolve to base object
              if obj.object_type == 'synonym' then
                return Resolver._resolve_synonym(obj, 10) -- Max depth 10
              end
              return obj
            end
          else
            -- No schema specified - match any schema, prefer default
            if default_schema and obj_schema and obj_schema:lower() == default_schema:lower() then
              -- Prefer default schema match
              if obj.object_type == 'synonym' then
                return Resolver._resolve_synonym(obj, 10)
              end
              return obj
            elseif not default_schema then
              -- No default schema, accept first match
              if obj.object_type == 'synonym' then
                return Resolver._resolve_synonym(obj, 10)
              end
              return obj
            end
          end
        end
      end

      -- If no default schema match found and no schema specified, accept any match
      if not schema then
        for _, obj in ipairs(group.children) do
          local obj_name = obj.name or obj.table_name or obj.view_name or obj.synonym_name
          if obj_name:lower() == table_name:lower() then
            if obj.object_type == 'synonym' then
              return Resolver._resolve_synonym(obj, 10)
            end
            return obj
          end
        end
      end
    end
  end

  return nil
end

---Get columns from a resolved table/view
---Handles lazy loading and caching
---@param table_obj table TableClass or ViewClass object
---@param connection table Connection context
---@return table[] columns Array of ColumnClass objects
function Resolver.get_columns(table_obj, connection)
  if not table_obj then
    return {}
  end

  -- Try: table_obj:get_columns() (may lazy-load)
  local success, columns = pcall(function()
    if table_obj.get_columns then
      return table_obj:get_columns()
    end
    return nil
  end)

  if success and columns and #columns > 0 then
    return columns
  end

  -- Fallback: If get_columns() fails, try direct RPC
  if connection and connection.connection_string then
    local obj_name = table_obj.name or table_obj.table_name or table_obj.view_name
    local obj_schema = table_obj.schema or table_obj.schema_name

    -- Try SSNSGetMetadata RPC
    local rpc_success, metadata = pcall(function()
      return vim.fn.SSNSGetMetadata(
        connection.connection_string,
        'columns',
        obj_name,
        obj_schema
      )
    end)

    if rpc_success and metadata and type(metadata) == 'table' then
      -- Parse metadata into ColumnClass-like objects
      local cols = {}
      for _, col_data in ipairs(metadata) do
        table.insert(cols, {
          name = col_data.name or col_data.column_name,
          column_name = col_data.name or col_data.column_name,
          data_type = col_data.data_type or col_data.type,
          nullable = col_data.nullable or col_data.is_nullable,
          is_primary_key = col_data.is_primary_key or col_data.is_pk,
          is_foreign_key = col_data.is_foreign_key or col_data.is_fk,
          ordinal_position = col_data.ordinal_position,
          default_value = col_data.default_value,
        })
      end
      return cols
    end
  end

  -- Return empty array on error (don't crash)
  return {}
end

---Resolve multiple table references from query context
---Used for SELECT/WHERE/ORDER BY (columns from all tables in query)
---@param bufnr number Buffer number
---@param connection table Connection context
---@return table[] tables Array of resolved TableClass/ViewClass objects
function Resolver.resolve_all_tables_in_query(bufnr, connection)
  if not bufnr or not connection then
    return {}
  end

  -- Get full buffer text
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local query_text = table.concat(lines, "\n")

  -- Use Treesitter or Context to extract table references
  local Treesitter = require('ssns.completion.metadata.treesitter')
  local refs = {}

  if Treesitter.is_available() then
    refs = Treesitter.extract_table_references(query_text)
  end

  -- Fallback to Context.parse_aliases if tree-sitter didn't return results
  if not refs or #refs == 0 then
    local Context = require('ssns.completion.context')
    local aliases = Context.parse_aliases(query_text)

    -- Convert aliases map to refs array
    for alias, table_name in pairs(aliases) do
      table.insert(refs, { table = table_name, alias = alias })
    end
  end

  -- Resolve each table reference
  local resolved_tables = {}
  local seen = {} -- Deduplicate by table name

  for _, ref in ipairs(refs) do
    local table_name = ref.table
    if table_name and not seen[table_name:lower()] then
      local table_obj = Resolver.resolve_table(table_name, connection, bufnr)
      if table_obj then
        table.insert(resolved_tables, table_obj)
        seen[table_name:lower()] = true
      end
    end
  end

  return resolved_tables
end

---Helper: Strip brackets/quotes from identifier
---@param identifier string Identifier with possible brackets/quotes
---@return string clean Cleaned identifier
function Resolver._clean_identifier(identifier)
  if not identifier then
    return ""
  end

  -- Remove: [brackets], "quotes", `backticks`
  local cleaned = identifier
  cleaned = cleaned:gsub("^%[(.-)%]$", "%1")
  cleaned = cleaned:gsub('^"(.-)"$', "%1")
  cleaned = cleaned:gsub("^`(.-)`$", "%1")

  return cleaned
end

---Helper: Parse schema-qualified name
---@param reference string Could be "schema.table" or just "table"
---@return string? schema Schema name or nil
---@return string table Table name
function Resolver._parse_qualified_name(reference)
  if not reference then
    return nil, ""
  end

  -- Handle: dbo.Employees -> ("dbo", "Employees")
  -- Handle: [dbo].[Employees] -> ("dbo", "Employees")
  -- Handle: Employees -> (nil, "Employees")

  local parts = {}
  for part in reference:gmatch("[^%.]+") do
    local cleaned = Resolver._clean_identifier(part)
    table.insert(parts, cleaned)
  end

  if #parts == 1 then
    -- Just table name
    return nil, parts[1]
  elseif #parts == 2 then
    -- schema.table
    return parts[1], parts[2]
  elseif #parts >= 3 then
    -- database.schema.table or server.database.schema.table
    -- Return last two parts (schema, table)
    return parts[#parts - 1], parts[#parts]
  end

  return nil, reference
end

---Helper: Get default schema for database type
---@param server table ServerClass
---@return string? default_schema Default schema name
function Resolver._get_default_schema(server)
  if not server or not server.get_db_type then
    return nil
  end

  local db_type = server:get_db_type()

  -- Default schemas by database type
  local defaults = {
    sqlserver = "dbo",
    postgres = "public",
    mysql = nil, -- MySQL doesn't use schemas
    sqlite = nil, -- SQLite doesn't use schemas
  }

  return defaults[db_type]
end

---Helper: Resolve synonym to base table/view (handles chains)
---@param synonym_obj table SynonymClass object
---@param max_depth number Maximum recursion depth
---@return table? base_obj Resolved base object or nil
function Resolver._resolve_synonym(synonym_obj, max_depth)
  if not synonym_obj or max_depth <= 0 then
    return nil
  end

  -- Use SynonymClass:resolve() method if available
  if synonym_obj.resolve then
    local success, base_obj, error_msg = pcall(function()
      return synonym_obj:resolve()
    end)

    if success and base_obj then
      return base_obj
    end
  end

  -- Fallback: return the synonym itself if resolution fails
  -- (caller can still try to get columns from it)
  return nil
end

return Resolver
