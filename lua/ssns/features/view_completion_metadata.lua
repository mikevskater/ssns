---@class ViewCompletionMetadata
---View completion metadata resolution in a floating window
---Displays resolved aliases, tables, columns, CTEs, and FK relationships
---@module ssns.features.view_completion_metadata
local ViewCompletionMetadata = {}

local UiFloat = require('ssns.ui.float')
local JsonUtils = require('ssns.utils.json')
local StatementContext = require('ssns.completion.statement_context')
local StatementCache = require('ssns.completion.statement_cache')
local Resolver = require('ssns.completion.metadata.resolver')

-- Store reference to current floating window for cleanup
local current_float = nil

---Close the current floating window
function ViewCompletionMetadata.close_current_float()
  if current_float then
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
end

---Get current connection context (if available)
---@return table? connection
local function get_connection()
  local Cache = require('ssns.cache')
  local bufnr = vim.api.nvim_get_current_buf()
  return Cache.get_buffer_connection(bufnr)
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
  -- Close any existing float
  ViewCompletionMetadata.close_current_float()

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local col = cursor[2] + 1  -- Convert 0-indexed to 1-indexed

  -- Build display content
  local display_lines = {}

  table.insert(display_lines, "Completion Metadata Resolution")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Cursor position info
  table.insert(display_lines, "Cursor Position")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, string.format("  Buffer: %d", bufnr))
  table.insert(display_lines, string.format("  Line: %d, Column: %d", line_num, col))
  table.insert(display_lines, "")

  -- Get connection early (needed before goto)
  local connection = get_connection()

  -- Get statement context
  local context = StatementContext.detect_full(bufnr, line_num, col)
  if not context then
    table.insert(display_lines, "(No context detected at cursor)")
    goto show_window
  end

  -- Connection info
  table.insert(display_lines, "Connection")
  table.insert(display_lines, string.rep("-", 30))
  if connection then
    local server_name = connection.server and connection.server.name or "unknown"
    local db_name = connection.database and (connection.database.db_name or connection.database.name) or "unknown"
    table.insert(display_lines, string.format("  Server: %s", server_name))
    table.insert(display_lines, string.format("  Database: %s", db_name))
  else
    table.insert(display_lines, "  (No active connection)")
  end
  table.insert(display_lines, "")

  -- Aliases in scope
  table.insert(display_lines, "Aliases in Scope")
  table.insert(display_lines, string.rep("-", 30))
  if context.aliases and next(context.aliases) then
    local sorted_aliases = {}
    for alias in pairs(context.aliases) do
      table.insert(sorted_aliases, alias)
    end
    table.sort(sorted_aliases)

    for _, alias in ipairs(sorted_aliases) do
      local target = context.aliases[alias]
      local resolved_status = ""

      -- Try to resolve if we have connection
      if connection then
        local resolved_table = Resolver.resolve_table(target, connection, context)
        if resolved_table then
          resolved_status = " ✓ resolved"
        else
          resolved_status = " ✗ not found"
        end
      end

      table.insert(display_lines, string.format("  %s -> %s%s", alias, target, resolved_status))
    end
  else
    table.insert(display_lines, "  (No aliases)")
  end
  table.insert(display_lines, "")

  -- Tables in scope with columns
  table.insert(display_lines, "Tables in Scope (with columns)")
  table.insert(display_lines, string.rep("-", 30))
  if context.tables_in_scope and #context.tables_in_scope > 0 then
    for _, table_info in ipairs(context.tables_in_scope) do
      local table_name = table_info.table or table_info.name or table_info.alias or "?"
      local alias_str = table_info.alias and (" AS " .. table_info.alias) or ""
      local scope_str = table_info.scope and (" [" .. table_info.scope .. "]") or ""

      -- Special handling for CTEs, temp tables, subqueries
      if table_info.is_cte then
        table.insert(display_lines, string.format("  CTE: %s%s", table_name, scope_str))
        if table_info.columns and #table_info.columns > 0 then
          for i, col in ipairs(table_info.columns) do
            if i > 5 then
              table.insert(display_lines, string.format("    ... and %d more", #table_info.columns - 5))
              break
            end
            local col_name = type(col) == "table" and col.name or col
            table.insert(display_lines, string.format("    - %s", col_name))
          end
        end
      elseif table_info.is_temp_table then
        local temp_type = table_info.is_global and "##global" or "#local"
        table.insert(display_lines, string.format("  Temp (%s): %s%s", temp_type, table_name, alias_str))
        if table_info.columns and #table_info.columns > 0 then
          for i, col in ipairs(table_info.columns) do
            if i > 5 then
              table.insert(display_lines, string.format("    ... and %d more", #table_info.columns - 5))
              break
            end
            local col_name = type(col) == "table" and col.name or col
            table.insert(display_lines, string.format("    - %s", col_name))
          end
        end
      elseif table_info.is_subquery then
        table.insert(display_lines, string.format("  Subquery: %s%s", table_name, scope_str))
        if table_info.columns and #table_info.columns > 0 then
          for i, col in ipairs(table_info.columns) do
            if i > 5 then
              table.insert(display_lines, string.format("    ... and %d more", #table_info.columns - 5))
              break
            end
            local col_name = type(col) == "table" and col.name or col
            table.insert(display_lines, string.format("    - %s", col_name))
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
        table.insert(display_lines, string.format("  %s %s%s%s", status, table_name, alias_str, scope_str))

        if #columns > 0 then
          for i, col in ipairs(columns) do
            if i > 5 then
              table.insert(display_lines, string.format("    ... and %d more columns", #columns - 5))
              break
            end
            local col_name = col.name or col.column_name or "?"
            local col_type = col.data_type or ""
            table.insert(display_lines, string.format("    - %s %s", col_name, col_type ~= "" and ("(" .. col_type .. ")") or ""))
          end
        elseif not resolved then
          table.insert(display_lines, "    (not resolved)")
        end
      end
      table.insert(display_lines, "")
    end
  else
    table.insert(display_lines, "  (No tables in scope)")
    table.insert(display_lines, "")
  end

  -- CTE definitions
  table.insert(display_lines, "CTE Definitions")
  table.insert(display_lines, string.rep("-", 30))
  if context.ctes and #context.ctes > 0 then
    for _, cte in ipairs(context.ctes) do
      local col_count = cte.columns and #cte.columns or 0
      local table_count = cte.tables and #cte.tables or 0
      table.insert(display_lines, string.format("  %s:", cte.name or "?"))
      table.insert(display_lines, string.format("    Columns: %d", col_count))
      table.insert(display_lines, string.format("    Source tables: %d", table_count))

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
        table.insert(display_lines, string.format("    [%s]", table.concat(col_names, ", ")))
      end
    end
  else
    table.insert(display_lines, "  (No CTEs)")
  end
  table.insert(display_lines, "")

  -- FK Relationships (if connection available)
  table.insert(display_lines, "FK Relationships (from tables in scope)")
  table.insert(display_lines, string.rep("-", 30))
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

          table.insert(display_lines, string.format("  %s.%s -> %s.%s",
            table_name, from_col, to_table, to_col))
        end
      end

      ::continue::
    end

    if fk_count == 0 then
      table.insert(display_lines, "  (No FK relationships found)")
    end
  else
    table.insert(display_lines, "  (Requires active connection)")
  end
  table.insert(display_lines, "")

  -- Pre-resolved scope (if available)
  if connection then
    local resolved_scope = Resolver.pre_resolve_scope(context, connection)
    table.insert(display_lines, "Pre-Resolved Scope")
    table.insert(display_lines, string.rep("-", 30))
    table.insert(display_lines, string.format("  Resolved aliases: %d", vim.tbl_count(resolved_scope.resolved_aliases or {})))
    table.insert(display_lines, string.format("  Resolved tables: %d", vim.tbl_count(resolved_scope.resolved_tables or {})))
    table.insert(display_lines, "")
  end

  -- JSON output
  ::show_window::
  table.insert(display_lines, "")
  table.insert(display_lines, "Context JSON")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  if context then
    -- Create cleaned version for JSON (avoid circular refs)
    local json_context = {
      type = context.type,
      mode = context.mode,
      prefix = context.prefix,
      trigger = context.trigger,
      statement_type = context.statement_type,
      clause = context.clause,
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

    local json_lines = JsonUtils.prettify_lines(json_context)
    for _, line in ipairs(json_lines) do
      table.insert(display_lines, line)
    end
  else
    table.insert(display_lines, "(No context)")
  end

  -- Create floating window
  current_float = UiFloat.create(display_lines, {
    title = "Completion Metadata",
    border = "rounded",
    filetype = "json",
    min_width = 70,
    max_width = 120,
    max_height = 50,
    wrap = false,
    keymaps = {
      ['r'] = function()
        ViewCompletionMetadata.view_metadata()
      end,
    },
    footer = "q: close | r: refresh",
  })
end

return ViewCompletionMetadata
