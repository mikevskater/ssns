---Metadata resolver for table/view/synonym references
---Resolves aliases, schema-qualified names, and synonym chains to actual database objects
---@class MetadataResolver
local Resolver = {}

local Debug = require('ssns.debug')
local TokenContext = require('ssns.completion.token_context')

-- Helper: Conditional debug logging based on config
local function debug_log(message)
  local Config = require('ssns.config')
  local config = Config.get()
  if config.completion and config.completion.debug then
    Debug.log("[RESOLVER] " .. message)
  end
end

---Resolve table/view/synonym reference to actual object
---Handles aliases, schema-qualified names, and synonym chains
---Enhanced to check buffer cache for temp tables first
---@param reference string Table reference (could be alias, table name, temp table, or synonym)
---@param connection table Connection context { server: ServerClass, database: DbClass, connection_config: table }
---@param context table Pre-built context with aliases
---@return table? table_obj Resolved TableClass/ViewClass/TempTableClass or nil if not found
function Resolver.resolve_table(reference, connection, context)
  if not reference or not connection or not connection.database then
    return nil
  end

  -- Step 0: Check if reference is a temp table (#temp or ##temp)
  if TokenContext.is_temp_table(reference) then
    -- Temp table resolution needs bufnr and cursor_pos, which we can extract from context if available
    -- For now, we'll skip temp table cache lookup and only check tempdb
    if TokenContext.is_global_temp_table(reference) then
      return Resolver._find_in_tempdb(reference, connection)
    end
    -- Local temp tables require buffer cache, which requires bufnr
    -- We'll need to pass bufnr through context or handle this differently
    -- For now, return nil for local temp tables
    return nil
  end

  -- Step 1: Try to resolve as alias first using pre-built context
  local resolved_name = Resolver.resolve_alias_with_scope(reference, context)

  if resolved_name then
    -- Alias was resolved, use the resolved table name
    reference = resolved_name

    -- Check again if resolved name is a temp table
    if TokenContext.is_temp_table(reference) then
      if TokenContext.is_global_temp_table(reference) then
        return Resolver._find_in_tempdb(reference, connection)
      end
      return nil  -- Local temp tables not supported without buffer context
    end
  end

  -- Step 2: Parse schema-qualified name if present (now returns database, schema, table)
  local db_name, schema, table_name = Resolver._parse_qualified_name(reference)

  -- Step 3: Determine which database to search in
  local database = connection.database
  local server = connection.server

  -- If reference specifies a different database, switch to it
  if db_name and server then
    local target_db = server:get_database(db_name)
    if target_db then
      database = target_db
      debug_log(string.format("[RESOLVER] Cross-database reference: switching to database '%s'", db_name))
      -- Ensure cross-database is loaded
      if not target_db.is_loaded then
        debug_log(string.format("[RESOLVER] Loading cross-database '%s'", db_name))
        local load_success = pcall(function()
          target_db:load()
        end)
        if not load_success then
          debug_log(string.format("[RESOLVER] Failed to load cross-database '%s'", db_name))
          return nil
        end
      end
    else
      debug_log(string.format("[RESOLVER] Cross-database reference: database '%s' not found on server", db_name))
      return nil
    end
  end

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

  -- Helper function to search in a collection of objects
  local function search_in_collection(objects)
    -- First pass: try to match with schema preference
    for _, obj in ipairs(objects) do
      local obj_name = obj.name or obj.table_name or obj.view_name or obj.synonym_name
      local obj_schema = obj.schema or obj.schema_name

      -- Match table name (case-insensitive)
      if obj_name and obj_name:lower() == table_name:lower() then
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

    -- Second pass: if no default schema match found and no schema specified, accept any match
    if not schema then
      for _, obj in ipairs(objects) do
        local obj_name = obj.name or obj.table_name or obj.view_name or obj.synonym_name
        if obj_name and obj_name:lower() == table_name:lower() then
          if obj.object_type == 'synonym' then
            return Resolver._resolve_synonym(obj, 10)
          end
          return obj
        end
      end
    end

    return nil
  end

  -- Search in tables using database accessor (handles schema-based vs non-schema servers)
  local tables = database:get_tables(schema)
  local result = search_in_collection(tables)
  if result then return result end

  -- Search in views
  local views = database:get_views(schema)
  result = search_in_collection(views)
  if result then return result end

  -- Search in synonyms
  local synonyms = database:get_synonyms(schema)
  result = search_in_collection(synonyms)
  if result then return result end

  return nil
end

---Get columns from a resolved table/view
---Handles lazy loading and caching
---@param table_obj table TableClass or ViewClass object
---@param connection table Connection context
---@return table[] columns Array of ColumnClass objects
function Resolver.get_columns(table_obj, connection)
  if not table_obj then
    debug_log("[RESOLVER] get_columns: table_obj is nil")
    return {}
  end

  local table_name = table_obj.name or table_obj.table_name or table_obj.view_name or "unknown"
  debug_log(string.format("[RESOLVER] get_columns: Getting columns for table '%s'", table_name))

  -- Try: table_obj:get_columns() (may lazy-load)
  local success, columns = pcall(function()
    if table_obj.get_columns then
      return table_obj:get_columns()
    end
    return nil
  end)

  if success and columns and #columns > 0 then
    debug_log(string.format("[RESOLVER] get_columns: Got %d columns from table_obj:get_columns()", #columns))
    return columns
  else
    if not success then
      debug_log(string.format("[RESOLVER] get_columns: table_obj:get_columns() failed: %s", tostring(columns)))
    else
      debug_log("[RESOLVER] get_columns: table_obj:get_columns() returned nil or empty")
    end
  end

  -- Fallback: If get_columns() fails, try direct RPC
  if connection and connection.connection_config then
    debug_log("[RESOLVER] get_columns: Trying RPC fallback")
    local obj_name = table_obj.name or table_obj.table_name or table_obj.view_name
    local obj_schema = table_obj.schema or table_obj.schema_name

    -- Try SSNSGetMetadata RPC (pass JSON-encoded config)
    local config_json = vim.fn.json_encode(connection.connection_config)
    local rpc_success, metadata = pcall(function()
      return vim.fn.SSNSGetMetadata({
        config_json,
        'columns',
        obj_name,
        obj_schema
      })
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
      debug_log(string.format("[RESOLVER] get_columns: Got %d columns from RPC", #cols))
      return cols
    else
      if not rpc_success then
        debug_log(string.format("[RESOLVER] get_columns: RPC failed: %s", tostring(metadata)))
      else
        debug_log("[RESOLVER] get_columns: RPC returned nil or non-table")
      end
    end
  else
    debug_log("[RESOLVER] get_columns: No connection or connection_config")
  end

  -- Return empty array on error (don't crash)
  debug_log("[RESOLVER] get_columns: Returning empty array")
  return {}
end

---Resolve multiple table references from query context using pre-built scope
---Used for SELECT/WHERE/ORDER BY (columns from all tables in query)
---@param connection table Connection context
---@param context table Pre-built context with tables_in_scope and optional resolved_scope
---@return table[] tables Array of resolved TableClass/ViewClass objects
function Resolver.resolve_all_tables_in_query(connection, context)
  if not context or not context.tables_in_scope then
    debug_log("[RESOLVER] No context or tables_in_scope provided to resolve_all_tables_in_query")
    return {}
  end

  debug_log(string.format("[RESOLVER] Using pre-built tables_in_scope from context: %d tables", #context.tables_in_scope))

  local resolved_tables = {}
  local seen_tables = {}  -- Deduplicate by name (case-insensitive)

  for _, table_info in ipairs(context.tables_in_scope) do
    -- table_info structure: {alias = "e", table = "dbo.EMPLOYEES", scope = "main"}
    -- or for CTEs: {name = "CTE_Name", is_cte = true, columns = {...}}
    -- or for subqueries: {name = "sub", is_subquery = true, columns = {...}}
    local table_name = table_info.table or table_info.name or table_info.alias or table_info
    local table_name_lower = type(table_name) == "string" and table_name:lower() or ""

    if table_name and not seen_tables[table_name_lower] then
      -- Handle CTEs specially - use pre-stored columns instead of database lookup
      if table_info.is_cte then
        local cte_columns = table_info.columns or {}
        -- Expand star columns (SELECT * in CTE) to actual columns from source table
        -- Pass context.ctes for CTE-to-CTE star expansion
        local StatementCache = require('ssns.completion.statement_cache')
        local expanded_cte_columns = StatementCache.expand_star_columns(cte_columns, connection, context.ctes, table_info.tables)
        -- Create pseudo-table object with get_columns method for CTE
        local cte_table = {
          name = table_info.name or table_name,
          is_cte = true,
          get_columns = function()
            -- Convert CTE ColumnInfo objects to column format expected by completion
            local cols = {}
            for _, col_info in ipairs(expanded_cte_columns) do
              local col_name = type(col_info) == "table" and col_info.name or col_info
              if col_name and col_name ~= "*" then  -- Skip unexpanded stars
                table.insert(cols, {
                  name = col_name,
                  column_name = col_name,
                  data_type = type(col_info) == "table" and col_info.data_type or "unknown",
                })
              end
            end
            return cols
          end
        }
        table.insert(resolved_tables, cte_table)
        seen_tables[table_name_lower] = true
        debug_log(string.format("[RESOLVER] Added CTE '%s' with %d columns (expanded from %d)", table_name, #expanded_cte_columns, #cte_columns))
      elseif table_info.is_subquery then
        -- Handle subqueries/derived tables - use pre-stored columns instead of database lookup
        local sq_columns = table_info.columns or {}
        -- Expand star columns (SELECT * in subquery) to actual columns from source table
        local StatementCache = require('ssns.completion.statement_cache')
        local expanded_sq_columns = StatementCache.expand_star_columns(sq_columns, connection)
        -- Create pseudo-table object with get_columns method for subquery
        local sq_table = {
          name = table_info.name or table_name,
          is_subquery = true,
          get_columns = function()
            -- Convert subquery ColumnInfo objects to column format expected by completion
            local cols = {}
            for _, col_info in ipairs(expanded_sq_columns) do
              local col_name = type(col_info) == "table" and col_info.name or col_info
              if col_name and col_name ~= "*" then  -- Skip unexpanded stars
                table.insert(cols, {
                  name = col_name,
                  column_name = col_name,
                  data_type = type(col_info) == "table" and col_info.data_type or "unknown",
                })
              end
            end
            return cols
          end
        }
        table.insert(resolved_tables, sq_table)
        seen_tables[table_name_lower] = true
        debug_log(string.format("[RESOLVER] Added subquery '%s' with %d columns (expanded from %d)", table_name, #expanded_sq_columns, #sq_columns))
      elseif table_info.is_temp_table then
        -- Handle temp tables (#TempName, ##GlobalTemp) - use pre-stored columns instead of database lookup
        local temp_columns = table_info.columns or {}
        -- Expand star columns if present
        local StatementCache = require('ssns.completion.statement_cache')
        local expanded_temp_columns = StatementCache.expand_star_columns(temp_columns, connection)
        -- Create pseudo-table object with get_columns method for temp table
        local temp_table = {
          name = table_info.name or table_name,
          is_temp_table = true,
          is_global = table_info.is_global,
          get_columns = function()
            -- Convert temp table ColumnInfo objects to column format expected by completion
            local cols = {}
            for _, col_info in ipairs(expanded_temp_columns) do
              local col_name = type(col_info) == "table" and col_info.name or col_info
              if col_name and col_name ~= "*" then  -- Skip unexpanded stars
                table.insert(cols, {
                  name = col_name,
                  column_name = col_name,
                  data_type = type(col_info) == "table" and col_info.data_type or "unknown",
                })
              end
            end
            return cols
          end
        }
        table.insert(resolved_tables, temp_table)
        seen_tables[table_name_lower] = true
        debug_log(string.format("[RESOLVER] Added temp table '%s' with %d columns (expanded from %d)", table_name, #expanded_temp_columns, #temp_columns))
      else
        -- Try pre-resolved scope first, then on-demand resolution
        local resolved_table = nil
        if context.resolved_scope then
          resolved_table = Resolver.get_resolved(context.resolved_scope, table_name)
        end
        if not resolved_table then
          resolved_table = Resolver.resolve_table(table_name, connection, context)
        end

        if resolved_table then
          table.insert(resolved_tables, resolved_table)
          seen_tables[table_name_lower] = true
          debug_log(string.format("[RESOLVER] Resolved table '%s'", table_name))
        else
          debug_log(string.format("[RESOLVER] Failed to resolve table '%s'", table_name))
        end
      end
    end
  end

  debug_log(string.format("[RESOLVER] Resolved %d unique tables from context", #resolved_tables))
  return resolved_tables
end

---Resolve alias to table using pre-built context from completion system
---@param alias string Alias to resolve
---@param context table Pre-built context with aliases
---@return string? table_name Resolved table name or nil
function Resolver.resolve_alias_with_scope(alias, context)
  if not context or not context.aliases then
    debug_log("[RESOLVER] No context or aliases provided to resolve_alias_with_scope")
    return nil
  end

  -- Use pre-built aliases from context (already case-insensitive)
  local alias_lower = alias:lower()
  local resolved = context.aliases[alias_lower]

  if resolved then
    debug_log(string.format("[RESOLVER] Resolved alias '%s' to table '%s' via context", alias, resolved))
  else
    debug_log(string.format("[RESOLVER] Alias '%s' not found in context.aliases", alias))
  end

  return resolved
end

---Helper: Strip brackets/quotes from identifier
---Uses TokenContext.strip_identifier_quotes for consistent handling
---@param identifier string Identifier with possible brackets/quotes
---@return string clean Cleaned identifier
function Resolver._clean_identifier(identifier)
  if not identifier then
    return ""
  end

  return TokenContext.strip_identifier_quotes(identifier)
end

---Helper: Parse schema-qualified name
---@param reference string Could be "database.schema.table", "schema.table" or just "table"
---@return string? database Database name or nil
---@return string? schema Schema name or nil
---@return string table Table name
function Resolver._parse_qualified_name(reference)
  if not reference then
    return nil, nil, ""
  end

  -- Handle: TEST.dbo.Employees -> ("TEST", "dbo", "Employees")
  -- Handle: dbo.Employees -> (nil, "dbo", "Employees")
  -- Handle: [dbo].[Employees] -> (nil, "dbo", "Employees")
  -- Handle: Employees -> (nil, nil, "Employees")

  local parts = {}
  for part in reference:gmatch("[^%.]+") do
    local cleaned = Resolver._clean_identifier(part)
    table.insert(parts, cleaned)
  end

  if #parts == 1 then
    -- Just table name
    return nil, nil, parts[1]
  elseif #parts == 2 then
    -- schema.table
    return nil, parts[1], parts[2]
  elseif #parts == 3 then
    -- database.schema.table
    return parts[1], parts[2], parts[3]
  elseif #parts >= 4 then
    -- server.database.schema.table - use last 3 parts
    return parts[#parts - 2], parts[#parts - 1], parts[#parts]
  end

  return nil, nil, reference
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

---Resolve temp table reference
---Checks buffer cache for temp tables, with fallback to tempdb for global temps
---@param temp_name string Temp table name (#temp or ##temp)
---@param bufnr number Buffer number
---@param cursor_pos table? {row, col} Cursor position
---@param connection table Connection context
---@return table? temp_table TempTableClass or nil
function Resolver._resolve_temp_table(temp_name, bufnr, cursor_pos, connection)
  local Cache = require('ssns.cache')

  -- Get cursor line for chunk detection
  local cursor_line = nil
  if cursor_pos then
    cursor_line = cursor_pos[1]
  elseif bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local success, result = pcall(function()
      return vim.api.nvim_win_get_cursor(0)[1]
    end)
    if success then
      cursor_line = result
    end
  end

  -- Check buffer cache
  local temp_tables = Cache.get_buffer_temp_tables(bufnr, cursor_line)
  local temp_table = temp_tables[temp_name]

  if temp_table then
    return temp_table
  end

  -- Fallback: Check global cache (for ##globalTemp after execution)
  -- Look in tempdb.dbo for global temp tables
  if TokenContext.is_global_temp_table(temp_name) and connection then
    return Resolver._find_in_tempdb(temp_name, connection)
  end

  return nil
end

---Find global temp table in tempdb (for ##temp after execution)
---@param temp_name string Global temp table name (##temp)
---@param connection table Connection context
---@return table? table_obj TableClass from tempdb or nil
function Resolver._find_in_tempdb(temp_name, connection)
  if not connection or not connection.server then
    return nil
  end

  -- Get tempdb from server
  local server = connection.server
  local tempdb = server:find_database("tempdb")

  if not tempdb then
    return nil
  end

  -- Look for temp table in tempdb.dbo (or tempdb tree)
  -- Global temp tables appear in tempdb after execution
  local dbo_schema = tempdb:find_schema("dbo")

  if not dbo_schema then
    return nil
  end

  -- Search for temp table in tables
  local table_obj = dbo_schema:find_table(temp_name)

  return table_obj
end

---Pre-resolve all aliases and tables in scope to actual database objects
---Avoids repeated tree walks in providers by caching resolved objects
---@param sql_context table The context from statement_context
---@param connection table Connection info {server, database, connection_config}
---@return table resolved_scope {resolved_aliases = {}, resolved_tables = {}}
function Resolver.pre_resolve_scope(sql_context, connection)
  local resolved_scope = {
    resolved_aliases = {},  -- alias_name -> table_obj or nil
    resolved_tables = {},   -- table_name -> table_obj or nil
  }

  if not sql_context then
    debug_log("[RESOLVER] pre_resolve_scope: No sql_context provided")
    return resolved_scope
  end

  debug_log("[RESOLVER] pre_resolve_scope: Starting pre-resolution")

  -- Resolve aliases
  if sql_context.aliases then
    for alias_name, table_ref in pairs(sql_context.aliases) do
      -- table_ref is just a string (the table name), not a table with metadata
      -- Skip CTEs, temp tables, and subqueries (they don't resolve to database objects)
      if table_ref and type(table_ref) == "string" and not TokenContext.is_temp_table(table_ref) then
        local resolved = Resolver.resolve_table(table_ref, connection, sql_context)
        if resolved then
          resolved_scope.resolved_aliases[alias_name:lower()] = resolved
          debug_log(string.format("[RESOLVER] pre_resolve_scope: Resolved alias '%s' -> '%s'",
            alias_name, table_ref))
        else
          debug_log(string.format("[RESOLVER] pre_resolve_scope: Failed to resolve alias '%s' -> '%s'",
            alias_name, table_ref))
        end
      end
    end
  end

  -- Resolve direct table references (tables_in_scope without aliases)
  if sql_context.tables_in_scope then
    for _, table_info in ipairs(sql_context.tables_in_scope) do
      -- table_info structure: {alias = "e", table = "dbo.EMPLOYEES", scope = "main"}
      local table_name = table_info.table
      if table_name and type(table_name) == "string" and not TokenContext.is_temp_table(table_name) then
        local key = table_name:lower()
        if not resolved_scope.resolved_tables[key] then
          local resolved = Resolver.resolve_table(table_name, connection, sql_context)
          if resolved then
            resolved_scope.resolved_tables[key] = resolved
            debug_log(string.format("[RESOLVER] pre_resolve_scope: Resolved table '%s'", table_name))
          else
            debug_log(string.format("[RESOLVER] pre_resolve_scope: Failed to resolve table '%s'", table_name))
          end
        end
      end
    end
  end

  debug_log(string.format("[RESOLVER] pre_resolve_scope: Complete - %d aliases, %d tables",
    vim.tbl_count(resolved_scope.resolved_aliases),
    vim.tbl_count(resolved_scope.resolved_tables)))

  return resolved_scope
end

---Get a pre-resolved table by alias or name
---Checks both aliases and direct table lookups (case-insensitive)
---@param resolved_scope table The pre-resolved scope
---@param name string Alias or table name to look up
---@return table? resolved Table object or nil
function Resolver.get_resolved(resolved_scope, name)
  if not resolved_scope or not name then
    return nil
  end

  local key = name:lower()

  -- Try aliases first (most common case for qualified references)
  local result = resolved_scope.resolved_aliases[key]
  if result then
    debug_log(string.format("[RESOLVER] get_resolved: Found '%s' in resolved_aliases", name))
    return result
  end

  -- Try direct table lookups
  result = resolved_scope.resolved_tables[key]
  if result then
    debug_log(string.format("[RESOLVER] get_resolved: Found '%s' in resolved_tables", name))
    return result
  end

  debug_log(string.format("[RESOLVER] get_resolved: '%s' not found in pre-resolved scope", name))
  return nil
end

-- ============================================================================
-- Async Methods
-- ============================================================================

---@class ResolveTableAsyncOpts
---@field on_complete fun(table_obj: table?, error: string?)? Completion callback
---@field timeout_ms number? Timeout in milliseconds (default: 5000)

---Resolve table/view/synonym reference to actual object asynchronously
---Non-blocking version of resolve_table() that uses database:load_async()
---@param reference string Table reference (could be alias, table name, temp table, or synonym)
---@param connection table Connection context { server: ServerClass, database: DbClass, connection_config: table }
---@param context table Pre-built context with aliases
---@param opts ResolveTableAsyncOpts? Options with on_complete callback
function Resolver.resolve_table_async(reference, connection, context, opts)
  opts = opts or {}
  local on_complete = opts.on_complete or function() end

  if not reference or not connection or not connection.database then
    vim.schedule(function()
      on_complete(nil, "Invalid reference or connection")
    end)
    return
  end

  -- Step 0: Check if reference is a temp table (#temp or ##temp)
  if TokenContext.is_temp_table(reference) then
    if TokenContext.is_global_temp_table(reference) then
      local result = Resolver._find_in_tempdb(reference, connection)
      vim.schedule(function()
        on_complete(result, nil)
      end)
      return
    end
    -- Local temp tables not supported without buffer context
    vim.schedule(function()
      on_complete(nil, nil)
    end)
    return
  end

  -- Step 1: Try to resolve as alias first using pre-built context
  local resolved_name = Resolver.resolve_alias_with_scope(reference, context)

  if resolved_name then
    reference = resolved_name

    -- Check again if resolved name is a temp table
    if TokenContext.is_temp_table(reference) then
      if TokenContext.is_global_temp_table(reference) then
        local result = Resolver._find_in_tempdb(reference, connection)
        vim.schedule(function()
          on_complete(result, nil)
        end)
        return
      end
      vim.schedule(function()
        on_complete(nil, nil)
      end)
      return
    end
  end

  -- Step 2: Parse schema-qualified name if present
  local db_name, schema, table_name = Resolver._parse_qualified_name(reference)

  -- Step 3: Determine which database to search in
  local database = connection.database
  local server = connection.server

  -- Helper function to search in database once loaded
  local function search_in_database(db)
    local default_schema = Resolver._get_default_schema(connection.server)

    -- Helper function to search in a collection of objects
    local function search_in_collection(objects)
      for _, obj in ipairs(objects) do
        local obj_name = obj.name or obj.table_name or obj.view_name or obj.synonym_name
        local obj_schema = obj.schema or obj.schema_name

        if obj_name and obj_name:lower() == table_name:lower() then
          if schema then
            if obj_schema and obj_schema:lower() == schema:lower() then
              if obj.object_type == 'synonym' then
                return Resolver._resolve_synonym(obj, 10)
              end
              return obj
            end
          else
            if default_schema and obj_schema and obj_schema:lower() == default_schema:lower() then
              if obj.object_type == 'synonym' then
                return Resolver._resolve_synonym(obj, 10)
              end
              return obj
            elseif not default_schema then
              if obj.object_type == 'synonym' then
                return Resolver._resolve_synonym(obj, 10)
              end
              return obj
            end
          end
        end
      end

      -- Second pass: if no default schema match found and no schema specified
      if not schema then
        for _, obj in ipairs(objects) do
          local obj_name = obj.name or obj.table_name or obj.view_name or obj.synonym_name
          if obj_name and obj_name:lower() == table_name:lower() then
            if obj.object_type == 'synonym' then
              return Resolver._resolve_synonym(obj, 10)
            end
            return obj
          end
        end
      end

      return nil
    end

    -- Search in tables
    local tables = db:get_tables(schema)
    local result = search_in_collection(tables)
    if result then return result end

    -- Search in views
    local views = db:get_views(schema)
    result = search_in_collection(views)
    if result then return result end

    -- Search in synonyms
    local synonyms = db:get_synonyms(schema)
    result = search_in_collection(synonyms)
    if result then return result end

    return nil
  end

  -- Function to handle database loading and searching
  local function load_and_search(target_db)
    if target_db.is_loaded then
      -- Already loaded, search immediately
      local result = search_in_database(target_db)
      vim.schedule(function()
        on_complete(result, nil)
      end)
    else
      -- Need to load async
      target_db:load_async({
        timeout_ms = opts.timeout_ms or 5000,
        on_complete = function(success, err)
          if not success then
            debug_log(string.format("[RESOLVER ASYNC] Failed to load database: %s", err or "unknown"))
            on_complete(nil, err)
            return
          end
          local result = search_in_database(target_db)
          on_complete(result, nil)
        end,
      })
    end
  end

  -- If reference specifies a different database, switch to it
  if db_name and server then
    local target_db = server:get_database(db_name)
    if target_db then
      database = target_db
      debug_log(string.format("[RESOLVER ASYNC] Cross-database reference: switching to database '%s'", db_name))
      load_and_search(target_db)
    else
      debug_log(string.format("[RESOLVER ASYNC] Cross-database reference: database '%s' not found on server", db_name))
      vim.schedule(function()
        on_complete(nil, nil)
      end)
    end
    return
  end

  -- Load main database if needed and search
  load_and_search(database)
end

---@class GetColumnsAsyncOpts
---@field on_complete fun(columns: table[], error: string?)? Completion callback
---@field timeout_ms number? Timeout in milliseconds (default: 5000)

---Get columns from a resolved table/view asynchronously
---Uses RPC async for non-blocking column retrieval
---@param table_obj table TableClass or ViewClass object
---@param connection table Connection context
---@param opts GetColumnsAsyncOpts? Options with on_complete callback
function Resolver.get_columns_async(table_obj, connection, opts)
  opts = opts or {}
  local on_complete = opts.on_complete or function() end

  if not table_obj then
    debug_log("[RESOLVER ASYNC] get_columns_async: table_obj is nil")
    vim.schedule(function()
      on_complete({}, nil)
    end)
    return
  end

  local table_name = table_obj.name or table_obj.table_name or table_obj.view_name or "unknown"
  debug_log(string.format("[RESOLVER ASYNC] get_columns_async: Getting columns for table '%s'", table_name))

  -- First try: check if columns are already loaded (no async needed)
  local success, columns = pcall(function()
    if table_obj.get_columns then
      return table_obj:get_columns()
    end
    return nil
  end)

  if success and columns and #columns > 0 then
    debug_log(string.format("[RESOLVER ASYNC] get_columns_async: Got %d columns from cache", #columns))
    vim.schedule(function()
      on_complete(columns, nil)
    end)
    return
  end

  -- Second try: use RPC async with adapter query
  if connection and connection.connection_config and connection.server then
    debug_log("[RESOLVER ASYNC] get_columns_async: Using RPC async")

    local adapter = connection.server:get_adapter()
    local database = connection.database
    local obj_name = table_obj.name or table_obj.table_name or table_obj.view_name
    local obj_schema = table_obj.schema or table_obj.schema_name

    if adapter and adapter.get_columns_query and database then
      local query = adapter:get_columns_query(database.db_name, obj_schema, obj_name)

      local AsyncRPC = require('ssns.async.rpc')

      -- Check if async RPC is available
      if AsyncRPC.is_available() then
        AsyncRPC.execute_async(connection.connection_config, query, {
          timeout_ms = opts.timeout_ms or 5000,
          on_complete = function(results, err)
            if err then
              debug_log(string.format("[RESOLVER ASYNC] get_columns_async: RPC async failed: %s", err))
              on_complete({}, err)
              return
            end

            -- Parse results using adapter
            local parsed_columns = {}
            if results and adapter.parse_columns then
              local col_data_list = adapter:parse_columns(results)
              for _, col_data in ipairs(col_data_list) do
                table.insert(parsed_columns, {
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
            end

            debug_log(string.format("[RESOLVER ASYNC] get_columns_async: Got %d columns from RPC async", #parsed_columns))
            on_complete(parsed_columns, nil)
          end,
        })
        return
      end
    end
  end

  -- Fallback: use sync RPC wrapped in vim.schedule (still better than blocking main loop)
  debug_log("[RESOLVER ASYNC] get_columns_async: Falling back to scheduled sync call")
  vim.schedule(function()
    local cols = Resolver.get_columns(table_obj, connection)
    on_complete(cols, nil)
  end)
end

---@class PreResolveScopeAsyncOpts
---@field on_complete fun(resolved_scope: table, error: string?)? Completion callback
---@field timeout_ms number? Timeout in milliseconds per resolution (default: 5000)

---Pre-resolve all aliases and tables in scope asynchronously
---Parallel resolution of all tables with callback aggregation
---@param sql_context table The context from statement_context
---@param connection table Connection info {server, database, connection_config}
---@param opts PreResolveScopeAsyncOpts? Options with on_complete callback
function Resolver.pre_resolve_scope_async(sql_context, connection, opts)
  opts = opts or {}
  local on_complete = opts.on_complete or function() end

  local resolved_scope = {
    resolved_aliases = {},  -- alias_name -> table_obj or nil
    resolved_tables = {},   -- table_name -> table_obj or nil
  }

  if not sql_context then
    debug_log("[RESOLVER ASYNC] pre_resolve_scope_async: No sql_context provided")
    vim.schedule(function()
      on_complete(resolved_scope, nil)
    end)
    return
  end

  debug_log("[RESOLVER ASYNC] pre_resolve_scope_async: Starting parallel pre-resolution")

  -- Collect all items that need to be resolved
  local resolve_tasks = {}  -- { type = "alias"|"table", key = string, table_ref = string }

  -- Collect aliases
  if sql_context.aliases then
    for alias_name, table_ref in pairs(sql_context.aliases) do
      if table_ref and type(table_ref) == "string" and not TokenContext.is_temp_table(table_ref) then
        table.insert(resolve_tasks, {
          type = "alias",
          key = alias_name:lower(),
          table_ref = table_ref,
          alias_name = alias_name,
        })
      end
    end
  end

  -- Collect direct table references
  if sql_context.tables_in_scope then
    local seen_tables = {}
    for _, table_info in ipairs(sql_context.tables_in_scope) do
      local table_name = table_info.table
      if table_name and type(table_name) == "string" and not TokenContext.is_temp_table(table_name) then
        local key = table_name:lower()
        if not seen_tables[key] then
          seen_tables[key] = true
          table.insert(resolve_tasks, {
            type = "table",
            key = key,
            table_ref = table_name,
          })
        end
      end
    end
  end

  -- If nothing to resolve, return immediately
  if #resolve_tasks == 0 then
    debug_log("[RESOLVER ASYNC] pre_resolve_scope_async: No items to resolve")
    vim.schedule(function()
      on_complete(resolved_scope, nil)
    end)
    return
  end

  debug_log(string.format("[RESOLVER ASYNC] pre_resolve_scope_async: Resolving %d items in parallel", #resolve_tasks))

  -- Callback aggregation pattern: track pending count
  local pending = #resolve_tasks
  local has_completed = false

  local function check_complete()
    if has_completed then return end
    pending = pending - 1
    if pending == 0 then
      has_completed = true
      debug_log(string.format("[RESOLVER ASYNC] pre_resolve_scope_async: Complete - %d aliases, %d tables",
        vim.tbl_count(resolved_scope.resolved_aliases),
        vim.tbl_count(resolved_scope.resolved_tables)))
      on_complete(resolved_scope, nil)
    end
  end

  -- Resolve all items in parallel
  for _, task in ipairs(resolve_tasks) do
    Resolver.resolve_table_async(task.table_ref, connection, sql_context, {
      timeout_ms = opts.timeout_ms or 5000,
      on_complete = function(resolved, err)
        if resolved then
          if task.type == "alias" then
            resolved_scope.resolved_aliases[task.key] = resolved
            debug_log(string.format("[RESOLVER ASYNC] pre_resolve_scope_async: Resolved alias '%s' -> '%s'",
              task.alias_name, task.table_ref))
          else
            resolved_scope.resolved_tables[task.key] = resolved
            debug_log(string.format("[RESOLVER ASYNC] pre_resolve_scope_async: Resolved table '%s'",
              task.table_ref))
          end
        else
          if task.type == "alias" then
            debug_log(string.format("[RESOLVER ASYNC] pre_resolve_scope_async: Failed to resolve alias '%s' -> '%s'",
              task.alias_name, task.table_ref))
          else
            debug_log(string.format("[RESOLVER ASYNC] pre_resolve_scope_async: Failed to resolve table '%s'",
              task.table_ref))
          end
        end
        check_complete()
      end,
    })
  end
end

---Resolve table-valued function (TVF) columns from database metadata
---Looks up the function in the cached UI tree and returns its result columns
---@param function_name string The function name
---@param schema_name string? The schema name (defaults to "dbo")
---@param connection table Connection context
---@return table[] columns Array of column info objects
function Resolver.resolve_tvf_columns(function_name, schema_name, connection)
  if not function_name or not connection or not connection.database then
    return {}
  end

  schema_name = schema_name or "dbo"
  local database = connection.database

  -- Use database accessor method (handles schema-based vs non-schema servers)
  local functions = database:get_functions(schema_name)

  -- Search for the function (case-insensitive)
  local function_name_lower = function_name:lower()
  local schema_name_lower = schema_name:lower()

  for _, func in ipairs(functions) do
    local func_name = func.function_name or func.name
    local func_schema = func.schema_name or func.schema or "dbo"

    if func_name and func_name:lower() == function_name_lower and
       func_schema:lower() == schema_name_lower then
      -- Found the function - check if it's table-valued
      if func.is_table_valued and func:is_table_valued() then
        -- Get TVF columns - these are stored in the function's metadata
        -- For TVFs, we need to query the database for result columns
        -- The adapter has a method to get TVF columns
        local adapter = connection.server and connection.server:get_adapter()
        if adapter and adapter.get_tvf_columns_query then
          local query = adapter:get_tvf_columns_query(
            database.db_name,
            schema_name,
            function_name
          )
          if query then
            -- Use connection_config (serializable) not connection (has methods)
            local conn_config = connection.server and connection.server.connection_config
            local results = adapter:execute(conn_config, query)
            if results and results.success and results.resultSets and #results.resultSets > 0 then
              local columns = {}
              local rows = results.resultSets[1].rows or {}
              for _, row in ipairs(rows) do
                table.insert(columns, {
                  name = row.column_name or row.name,
                  data_type = row.data_type or row.type,
                  ordinal_position = row.ordinal_position or row.column_id,
                })
              end
              debug_log(string.format("[RESOLVER] resolve_tvf_columns: Found %d columns for '%s.%s'",
                #columns, schema_name, function_name))
              return columns
            end
          end
        end
        debug_log(string.format("[RESOLVER] resolve_tvf_columns: No columns found for TVF '%s.%s'",
          schema_name, function_name))
        return {}
      end
    end
  end

  debug_log(string.format("[RESOLVER] resolve_tvf_columns: Function '%s.%s' not found", schema_name, function_name))
  return {}
end

return Resolver
