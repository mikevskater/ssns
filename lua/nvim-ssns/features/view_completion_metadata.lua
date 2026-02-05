---@class ViewCompletionMetadata
---View completion metadata resolution in a floating window
---Displays resolved aliases, tables, columns, CTEs, and FK relationships
---@module ssns.features.view_completion_metadata
local ViewCompletionMetadata = {}

local BaseViewer = require('nvim-ssns.features.base_viewer')
local StatementContext = require('nvim-ssns.completion.statement_context')
local Resolver = require('nvim-ssns.completion.metadata.resolver')
local BufferConnection = require('nvim-ssns.utils.buffer_connection')

-- Create viewer instance
local viewer = BaseViewer.create({
  title = "Completion Metadata",
  min_width = 70,
  max_width = 120,
  footer = "q: close | r: refresh",
})

---Close the current floating window
function ViewCompletionMetadata.close_current_float()
  viewer:close()
end

---Get columns from a resolved table
---@param table_obj table
---@return table[] columns
local function safe_get_columns(table_obj)
  if not table_obj then return {} end

  local success, result = pcall(function()
    if table_obj.get_columns then
      return table_obj:get_columns() or {}
    end
    return {}
  end)

  return success and result or {}
end

---View completion metadata
function ViewCompletionMetadata.view_metadata()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local col = cursor[2] + 1  -- Convert 0-indexed to 1-indexed

  -- Set refresh callback
  viewer.on_refresh = ViewCompletionMetadata.view_metadata

  -- Get connection early (needed before goto)
  local connection = BufferConnection.get_connection(bufnr)

  -- Get statement context
  local context = StatementContext.detect_full(bufnr, line_num, col)

  -- Show with JSON output
  viewer:show_with_json(function(cb)
    BaseViewer.add_header(cb, "Completion Metadata Resolution")

    -- Cursor position info
    cb:section("Cursor Position")
    cb:separator("-", 30)
    cb:spans({
      { text = "  Buffer: ", style = "label" },
      { text = tostring(bufnr), style = "number" },
    })
    cb:spans({
      { text = "  Line: ", style = "label" },
      { text = tostring(line_num), style = "number" },
      { text = ", Column: " },
      { text = tostring(col), style = "number" },
    })
    cb:blank()

    if not context then
      cb:styled("(No context detected at cursor)", "muted")
      return nil
    end

  -- Connection info
  cb:section("Connection")
  cb:separator("-", 30)
  if connection then
    local server_name = connection.server and connection.server.name or "unknown"
    local db_name = connection.database and (connection.database.db_name or connection.database.name) or "unknown"
    cb:spans({
      { text = "  Server: ", style = "label" },
      { text = server_name, style = "server" },
    })
    cb:spans({
      { text = "  Database: ", style = "label" },
      { text = db_name, style = "sql_database" },
    })
  else
    cb:styled("  (No active connection)", "muted")
  end
  cb:blank()

  -- Aliases in scope
  cb:section("Aliases in Scope")
  cb:separator("-", 30)
  if context.aliases and next(context.aliases) then
    local sorted_aliases = {}
    for alias in pairs(context.aliases) do
      table.insert(sorted_aliases, alias)
    end
    table.sort(sorted_aliases)

    for _, alias in ipairs(sorted_aliases) do
      local target = context.aliases[alias]
      local resolved_status = ""
      local status_style = "muted"

      -- Try to resolve if we have connection
      if connection then
        local resolved_table = Resolver.resolve_table(target, connection, context)
        if resolved_table then
          resolved_status = " ✓ resolved"
          status_style = "success"
        else
          resolved_status = " ✗ not found"
          status_style = "error"
        end
      end

      cb:spans({
        { text = "  " },
        { text = alias, style = "emphasis" },
        { text = " -> " },
        { text = target, style = "sql_table" },
        { text = resolved_status, style = status_style },
      })
    end
  else
    cb:styled("  (No aliases)", "muted")
  end
  cb:blank()

  -- Tables in scope with columns
  cb:section("Tables in Scope (with columns)")
  cb:separator("-", 30)
  if context.tables_in_scope and #context.tables_in_scope > 0 then
    for _, table_info in ipairs(context.tables_in_scope) do
      local table_name = table_info.table or table_info.name or table_info.alias or "?"
      local alias_str = table_info.alias and (" AS " .. table_info.alias) or ""
      local scope_str = table_info.scope and (" [" .. table_info.scope .. "]") or ""

      -- Special handling for CTEs, temp tables, subqueries
      if table_info.is_cte then
        cb:spans({
          { text = "  CTE: ", style = "label" },
          { text = table_name, style = "sql_view" },
          { text = scope_str, style = "muted" },
        })
        if table_info.columns and #table_info.columns > 0 then
          for i, col in ipairs(table_info.columns) do
            if i > 5 then
              cb:styled(string.format("    ... and %d more", #table_info.columns - 5), "muted")
              break
            end
            local col_name = type(col) == "table" and col.name or col
            cb:spans({
              { text = "    - " },
              { text = col_name, style = "sql_column" },
            })
          end
        end
      elseif table_info.is_temp_table then
        local temp_type = table_info.is_global and "##global" or "#local"
        cb:spans({
          { text = "  Temp (" },
          { text = temp_type, style = "warning" },
          { text = "): " },
          { text = table_name, style = "warning" },
          { text = alias_str, style = "emphasis" },
        })
        if table_info.columns and #table_info.columns > 0 then
          for i, col in ipairs(table_info.columns) do
            if i > 5 then
              cb:styled(string.format("    ... and %d more", #table_info.columns - 5), "muted")
              break
            end
            local col_name = type(col) == "table" and col.name or col
            cb:spans({
              { text = "    - " },
              { text = col_name, style = "sql_column" },
            })
          end
        end
      elseif table_info.is_subquery then
        cb:spans({
          { text = "  Subquery: ", style = "label" },
          { text = table_name, style = "muted" },
          { text = scope_str, style = "muted" },
        })
        if table_info.columns and #table_info.columns > 0 then
          for i, col in ipairs(table_info.columns) do
            if i > 5 then
              cb:styled(string.format("    ... and %d more", #table_info.columns - 5), "muted")
              break
            end
            local col_name = type(col) == "table" and col.name or col
            cb:spans({
              { text = "    - " },
              { text = col_name, style = "sql_column" },
            })
          end
        end
      else
        -- Database table - try to resolve
        local resolved = nil
        local columns = {}
        if connection then
          resolved = Resolver.resolve_table(table_name, connection, context)
          if resolved then
            columns = safe_get_columns(resolved)
          end
        end

        local status = resolved and "✓" or "✗"
        local status_style = resolved and "success" or "error"
        cb:spans({
          { text = "  " },
          { text = status, style = status_style },
          { text = " " },
          { text = table_name, style = "sql_table" },
          { text = alias_str, style = "emphasis" },
          { text = scope_str, style = "muted" },
        })

        if #columns > 0 then
          for i, col in ipairs(columns) do
            if i > 5 then
              cb:styled(string.format("    ... and %d more columns", #columns - 5), "muted")
              break
            end
            local col_name = col.name or col.column_name or "?"
            local col_type = col.data_type or ""
            cb:spans({
              { text = "    - " },
              { text = col_name, style = "sql_column" },
              { text = col_type ~= "" and (" (" .. col_type .. ")") or "", style = "muted" },
            })
          end
        elseif not resolved then
          cb:styled("    (not resolved)", "muted")
        end
      end
      cb:blank()
    end
  else
    cb:styled("  (No tables in scope)", "muted")
    cb:blank()
  end

  -- CTE definitions
  cb:section("CTE Definitions")
  cb:separator("-", 30)
  if context.ctes and #context.ctes > 0 then
    for _, cte in ipairs(context.ctes) do
      local col_count = cte.columns and #cte.columns or 0
      local table_count = cte.tables and #cte.tables or 0
      cb:spans({
        { text = "  " },
        { text = cte.name or "?", style = "sql_view" },
        { text = ":" },
      })
      cb:spans({
        { text = "    Columns: ", style = "label" },
        { text = tostring(col_count), style = "number" },
      })
      cb:spans({
        { text = "    Source tables: ", style = "label" },
        { text = tostring(table_count), style = "number" },
      })

      -- Show column names
      if cte.columns and #cte.columns > 0 then
        local col_names = {}
        for i, col in ipairs(cte.columns) do
          if i > 8 then break end
          local name = type(col) == "table" and col.name or col
          table.insert(col_names, name)
        end
        if #cte.columns > 8 then
          table.insert(col_names, "...")
        end
        cb:spans({
          { text = "    [" },
          { text = table.concat(col_names, ", "), style = "sql_column" },
          { text = "]" },
        })
      end
    end
  else
    cb:styled("  (No CTEs)", "muted")
  end
  cb:blank()

  -- FK Relationships (if connection available)
  cb:section("FK Relationships (from tables in scope)")
  cb:separator("-", 30)
  if connection and context.tables_in_scope and #context.tables_in_scope > 0 then
    local fk_count = 0
    for _, table_info in ipairs(context.tables_in_scope) do
      -- Skip non-database tables
      if table_info.is_cte or table_info.is_temp_table or table_info.is_subquery then
        goto continue
      end

      local table_name = table_info.table or table_info.name
      if not table_name then goto continue end

      local resolved = Resolver.resolve_table(table_name, connection, context)
      if not resolved then goto continue end

      -- Get constraints
      local constraints = {}
      local success, result = pcall(function()
        if resolved.get_constraints then
          return resolved:get_constraints() or {}
        end
        return resolved.constraints or {}
      end)

      if success and result then
        constraints = result
      end

      -- Filter for FK constraints
      for _, constraint in ipairs(constraints) do
        local is_fk = false
        if constraint.constraint_type then
          local ctype = constraint.constraint_type:upper()
          is_fk = ctype:find("FOREIGN") ~= nil or ctype == "FK"
        end

        if is_fk and constraint.referenced_table then
          fk_count = fk_count + 1
          local from_col = constraint.column_name or constraint.columns or "?"
          local to_col = constraint.referenced_column or "?"
          local to_table = constraint.referenced_table
          if constraint.referenced_schema then
            to_table = constraint.referenced_schema .. "." .. to_table
          end

          cb:spans({
            { text = "  " },
            { text = table_name, style = "sql_table" },
            { text = "." },
            { text = from_col, style = "sql_column" },
            { text = " -> " },
            { text = to_table, style = "sql_table" },
            { text = "." },
            { text = to_col, style = "sql_column" },
          })
        end
      end

      ::continue::
    end

    if fk_count == 0 then
      cb:styled("  (No FK relationships found)", "muted")
    end
  else
    cb:styled("  (Requires active connection)", "muted")
  end
  cb:blank()

  -- Pre-resolved scope (if available)
  if connection then
    local resolved_scope = Resolver.pre_resolve_scope(context, connection)
    cb:section("Pre-Resolved Scope")
    cb:separator("-", 30)
    cb:spans({
      { text = "  Resolved aliases: ", style = "label" },
      { text = tostring(vim.tbl_count(resolved_scope.resolved_aliases or {})), style = "number" },
    })
    cb:spans({
      { text = "  Resolved tables: ", style = "label" },
      { text = tostring(vim.tbl_count(resolved_scope.resolved_tables or {})), style = "number" },
    })
    cb:blank()
  end

    -- Return JSON data
    local json_context = {
      type = context.type,
      mode = context.mode,
      prefix = context.prefix,
      trigger = context.trigger,
      statement_type = context.statement_type,
      clause = context.clause,
      -- Filter/qualification fields (important for debugging)
      filter_schema = context.filter_schema,
      filter_database = context.filter_database,
      filter_table = context.filter_table,
      potential_database = context.potential_database,
      omit_schema = context.omit_schema,
      schema = context.schema,
      database = context.database,
      table_ref = context.table_ref,
      -- Counts
      tables_in_scope_count = context.tables_in_scope and #context.tables_in_scope or 0,
      aliases_count = context.aliases and vim.tbl_count(context.aliases) or 0,
      ctes_count = context.ctes and #context.ctes or 0,
      aliases = context.aliases,
    }

    -- Include simplified tables_in_scope
    if context.tables_in_scope then
      json_context.tables_in_scope = {}
      for _, t in ipairs(context.tables_in_scope) do
        table.insert(json_context.tables_in_scope, {
          table = t.table,
          alias = t.alias,
          scope = t.scope,
          is_cte = t.is_cte,
          is_temp_table = t.is_temp_table,
          is_subquery = t.is_subquery,
        })
      end
    end

    return json_context
  end, "Context JSON")
end

return ViewCompletionMetadata

