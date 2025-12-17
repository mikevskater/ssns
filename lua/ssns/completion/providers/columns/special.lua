---Special column completion handlers
---Handles ON clause, INSERT columns, VALUES, and OUTPUT pseudo-tables
---@class ColumnsSpecial
local M = {}

local BaseProvider = require('ssns.completion.providers.base_provider')
local FuzzyMatcher = require('ssns.completion.fuzzy_matcher')
local TypeCompatibility = require('ssns.completion.type_compatibility')

---Get columns for ON clause with fuzzy matching
---Shows fully qualified column names (alias.column) prioritized by name match
---@param connection table Connection context
---@param context table SQL context with left_side info
---@return table[] items CompletionItems
function M.get_on_clause_columns(connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')

  local items = {}
  local FUZZY_THRESHOLD = 0.85

  -- Get left-side column info
  local left_col_name = context.left_side and context.left_side.column_name
  local left_table_ref = context.left_side and context.left_side.table_ref

  -- Try to resolve left-side column type
  local left_col_type = nil
  if left_table_ref and left_col_name and context.resolved_scope then
    local left_table = Resolver.get_resolved(context.resolved_scope, left_table_ref)
    if left_table then
      local left_cols = Resolver.get_columns(left_table, connection)
      for _, col in ipairs(left_cols or {}) do
        local col_name = col.name or col.column_name
        if col_name and col_name:lower() == left_col_name:lower() then
          left_col_type = col.data_type
          break
        end
      end
    end
  end

  -- Get all tables in the query
  local tables_in_scope = context.tables_in_scope or {}

  for _, table_info in ipairs(tables_in_scope) do
    local alias = table_info.alias
    local table_name = table_info.table or table_info.name
    local display_ref = alias or table_name

    -- Check if this is the left-side table (for deprioritizing same-table suggestions)
    local is_left_table = left_table_ref and display_ref and display_ref:lower() == left_table_ref:lower()

    -- Resolve table to get columns
    local table_obj = nil
    if context.resolved_scope then
      table_obj = Resolver.get_resolved(context.resolved_scope, table_name)
      if not table_obj and alias then
        table_obj = Resolver.get_resolved(context.resolved_scope, alias)
      end
    end
    if not table_obj then
      table_obj = Resolver.resolve_table(table_name or alias, connection, context)
    end

    if not table_obj then
      goto continue_table
    end

    -- Build table path for usage weight lookup
    local schema = table_obj.schema or table_obj.schema_name
    local tbl_name = table_obj.name or table_obj.table_name or table_obj.view_name
    local table_path = nil
    if schema and tbl_name then
      table_path = string.format("%s.%s", schema, tbl_name)
    elseif tbl_name then
      table_path = tbl_name
    end

    -- Get columns for this table
    local columns = Resolver.get_columns(table_obj, connection)
    if not columns then
      goto continue_table
    end

    for _, col in ipairs(columns) do
      local col_name = col.name or col.column_name
      if not col_name then
        goto continue_col
      end

      -- Build qualified name
      local qualified_name = display_ref and (display_ref .. "." .. col_name) or col_name

      -- Calculate fuzzy match score and base priority
      local priority = 5000  -- Default priority
      local match_indicator = ""

      if left_col_name then
        local is_match, score = FuzzyMatcher.match_columns(left_col_name, col_name, FUZZY_THRESHOLD)

        if is_match then
          if score >= 1.0 then
            priority = 100
            match_indicator = " ★"
          elseif score >= 0.95 then
            priority = 200
            match_indicator = string.format(" ~%.0f%%", score * 100)
          elseif score >= 0.85 then
            priority = 300 + math.floor((1 - score) * 1000)
            match_indicator = string.format(" ~%.0f%%", score * 100)
          end
        end
      end

      -- Deprioritize same-table columns (e.g., e.col = e.col) but still show them
      if is_left_table then
        priority = priority + 1000
      end

      -- Apply usage weight adjustment
      local weight = 0
      if table_path then
        local column_path = string.format("%s.%s", table_path, col_name)
        weight = BaseProvider.get_usage_weight(connection, "column", column_path)
        -- Adjust priority based on usage (lower number = higher priority)
        if weight > 0 and priority >= 1000 then
          -- For non-fuzzy-matched columns, usage can boost priority
          priority = priority - math.min(weight, 500)
        end
      end

      -- Build detail string
      local type_str = col.data_type or "unknown"
      local detail = type_str .. match_indicator

      -- Check type compatibility
      if left_col_type and col.data_type then
        local type_info = TypeCompatibility.get_info(left_col_type, col.data_type)
        if not type_info.compatible then
          priority = priority + 2000
          detail = detail .. " " .. type_info.icon
        elseif type_info.warning then
          detail = detail .. " " .. type_info.icon
        end
      end

      -- Create completion item
      local item = {
        label = qualified_name,
        kind = vim.lsp.protocol.CompletionItemKind.Field,
        detail = detail,
        insertText = qualified_name,
        sortText = string.format("%05d_%s", priority, qualified_name),
        data = {
          table_ref = display_ref,
          column_name = col_name,
          data_type = col.data_type,
          weight = weight,
          table_path = table_path,
        },
      }

      -- Add documentation with column info
      local doc_parts = {}
      table.insert(doc_parts, string.format("**%s.%s**", display_ref, col_name))
      table.insert(doc_parts, "")
      table.insert(doc_parts, string.format("Type: %s", col.data_type or "unknown"))
      if col.is_nullable ~= nil then
        table.insert(doc_parts, string.format("Nullable: %s", col.is_nullable and "Yes" or "No"))
      end
      if col.is_primary_key or col.is_pk then
        table.insert(doc_parts, "Primary Key: Yes")
      end

      -- Add type warning to docs
      if left_col_type and col.data_type then
        local type_info = TypeCompatibility.get_info(left_col_type, col.data_type)
        if type_info.warning then
          table.insert(doc_parts, "")
          table.insert(doc_parts, type_info.icon .. " " .. type_info.warning)
        end
      end

      item.documentation = {
        kind = "markdown",
        value = table.concat(doc_parts, "\n"),
      }

      table.insert(items, item)

      ::continue_col::
    end

    ::continue_table::
  end

  -- Sort by priority
  table.sort(items, function(a, b)
    return a.sortText < b.sortText
  end)

  return items
end

---Get columns for INSERT column list: INSERT INTO table (|col1, col2)
---@param connection table Connection context
---@param context table SQL context with chunk and resolved_scope
---@return table[] items CompletionItems
function M.get_insert_columns(connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')

  -- Get INSERT target table from chunk.tables (first table in INSERT statement)
  if not context.chunk or not context.chunk.tables or #context.chunk.tables == 0 then
    return {}
  end

  local target_table = context.chunk.tables[1]  -- INSERT target is always first
  local table_name = target_table.name or target_table

  -- Check if INSERT target is a temp table
  if context.temp_tables and table_name and table_name:sub(1, 1) == "#" then
    local temp_info = context.temp_tables[table_name] or context.temp_tables[table_name:lower()]
    if temp_info and temp_info.columns and #temp_info.columns > 0 then
      local StatementCache = require('ssns.completion.statement_cache')
      local expanded_columns = StatementCache.expand_star_columns(temp_info.columns, connection)
      local items = {}
      for _, col_info in ipairs(expanded_columns) do
        local col_name = type(col_info) == "table" and col_info.name or col_info
        local data_type = type(col_info) == "table" and col_info.data_type or nil
        if col_name and col_name ~= "*" then
          local detail = data_type and ("Temp table column - " .. data_type) or "Temp table column"
          table.insert(items, {
            label = col_name,
            kind = vim.lsp.protocol.CompletionItemKind.Field,
            detail = detail,
            insertText = col_name,
            data = {
              type = "column",
              name = col_name,
              data_type = data_type,
              is_temp_table = true,
            },
          })
        end
      end
      return items
    end
  end

  -- Resolve to actual table object
  local table_obj = nil
  if context.resolved_scope then
    table_obj = Resolver.get_resolved(context.resolved_scope, table_name)
  end
  if not table_obj then
    table_obj = Resolver.resolve_table(table_name, connection, context)
  end

  if not table_obj then
    return {}
  end

  -- Get columns
  local columns = Resolver.get_columns(table_obj, connection)
  if not columns or #columns == 0 then
    return {}
  end

  -- Format as CompletionItems
  local items = {}

  for _, col in ipairs(columns) do
    local item = Utils.format_column(col, {
      show_type = true,
      show_nullable = true,
    })

    -- Mark identity/computed columns with warning
    if col.is_identity then
      item.detail = (item.detail or "") .. " [IDENTITY]"
    end
    if col.is_computed then
      item.detail = (item.detail or "") .. " [COMPUTED]"
    end

    table.insert(items, item)
  end

  return items
end

---Get completion hints for VALUES clause: INSERT INTO table (col1, col2) VALUES (|
---Shows the column name, type, and nullable info for the current position
---@param connection table Connection context
---@param context table SQL context with value_position and chunk.insert_columns
---@return table[] items CompletionItems
function M.get_values_completions(connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')

  -- Get INSERT target table and column list
  if not context.chunk or not context.chunk.tables or #context.chunk.tables == 0 then
    return {}
  end

  local insert_columns = context.chunk.insert_columns
  if not insert_columns or #insert_columns == 0 then
    return {}
  end

  -- Get the column at current value position (0-indexed)
  local value_position = context.value_position or 0
  local target_column_name = insert_columns[value_position + 1]  -- Lua is 1-indexed

  if not target_column_name then
    -- Position beyond column list
    return {}
  end

  -- Resolve INSERT target table to get column metadata
  local target_table = context.chunk.tables[1]
  local table_name = target_table.name or target_table

  local table_obj = nil
  if context.resolved_scope then
    table_obj = Resolver.get_resolved(context.resolved_scope, table_name)
  end
  if not table_obj then
    table_obj = Resolver.resolve_table(table_name, connection, context)
  end

  if not table_obj then
    -- Can't resolve table, return column name as basic hint
    return {{
      label = target_column_name,
      kind = vim.lsp.protocol.CompletionItemKind.Field,
      detail = string.format("Column %d of %d", value_position + 1, #insert_columns),
      insertText = "",  -- Don't insert anything, just show hint
      sortText = "0001_" .. target_column_name,
    }}
  end

  -- Get column metadata
  local columns = Resolver.get_columns(table_obj, connection)
  if not columns or #columns == 0 then
    return {{
      label = target_column_name,
      kind = vim.lsp.protocol.CompletionItemKind.Field,
      detail = string.format("Column %d of %d", value_position + 1, #insert_columns),
      insertText = "",
      sortText = "0001_" .. target_column_name,
    }}
  end

  -- Find the target column in metadata
  local target_col = nil
  for _, col in ipairs(columns) do
    if col.name:lower() == target_column_name:lower() then
      target_col = col
      break
    end
  end

  local items = {}

  if target_col then
    -- Build detailed column hint
    local type_info = target_col.data_type or "unknown"
    local nullable_info = target_col.is_nullable and "nullable" or "NOT NULL"
    local pk_info = (target_col.is_primary_key or target_col.is_pk) and " [PK]" or ""
    local identity_info = target_col.is_identity and " [IDENTITY]" or ""
    local computed_info = target_col.is_computed and " [COMPUTED]" or ""

    -- Build documentation
    local doc_lines = {
      string.format("**%s** - Column %d of %d", target_column_name, value_position + 1, #insert_columns),
      "",
      string.format("Type: %s", type_info),
      string.format("Nullable: %s", nullable_info),
    }

    if target_col.column_default then
      table.insert(doc_lines, string.format("Default: %s", target_col.column_default))
    end

    if target_col.is_identity then
      table.insert(doc_lines, "")
      table.insert(doc_lines, "⚠️ IDENTITY column - value auto-generated")
    end

    if target_col.is_computed then
      table.insert(doc_lines, "")
      table.insert(doc_lines, "⚠️ COMPUTED column - cannot insert directly")
    end

    -- Primary hint: column name with full details
    table.insert(items, {
      label = target_column_name,
      kind = vim.lsp.protocol.CompletionItemKind.Field,
      detail = string.format("%s (%s)%s%s%s", type_info, nullable_info, pk_info, identity_info, computed_info),
      documentation = {
        kind = "markdown",
        value = table.concat(doc_lines, "\n"),
      },
      insertText = "",  -- Don't insert column name, user is entering value
      sortText = "0001_" .. target_column_name,
    })

    -- If nullable, suggest NULL
    if target_col.is_nullable then
      table.insert(items, {
        label = "NULL",
        kind = vim.lsp.protocol.CompletionItemKind.Keyword,
        detail = "NULL value (column is nullable)",
        insertText = "NULL",
        sortText = "0002_NULL",
      })
    end

    -- If has default, suggest DEFAULT
    if target_col.column_default then
      table.insert(items, {
        label = "DEFAULT",
        kind = vim.lsp.protocol.CompletionItemKind.Keyword,
        detail = string.format("Use default: %s", target_col.column_default),
        insertText = "DEFAULT",
        sortText = "0003_DEFAULT",
      })
    end
  else
    -- Column not found in metadata, return basic hint
    table.insert(items, {
      label = target_column_name,
      kind = vim.lsp.protocol.CompletionItemKind.Field,
      detail = string.format("Column %d of %d", value_position + 1, #insert_columns),
      insertText = "",
      sortText = "0001_" .. target_column_name,
    })
  end

  return items
end

---Get columns for OUTPUT clause inserted/deleted pseudo-tables
---@param connection table Connection context
---@param context table SQL context with chunk info
---@return table[] items CompletionItems
function M.get_output_pseudo_table_columns(connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')

  -- Get the DML target table from chunk
  -- For INSERT/UPDATE/DELETE/MERGE, the target is usually the first table or update_target
  local target_table = nil
  if context.chunk then
    if context.chunk.statement_type == "INSERT" then
      -- INSERT INTO table - target is first in tables array
      target_table = context.chunk.tables and context.chunk.tables[1]
    elseif context.chunk.statement_type == "UPDATE" then
      -- UPDATE table or UPDATE alias SET ... FROM table alias
      target_table = context.chunk.update_target or (context.chunk.tables and context.chunk.tables[1])
    elseif context.chunk.statement_type == "DELETE" then
      -- DELETE FROM table
      target_table = context.chunk.tables and context.chunk.tables[1]
    elseif context.chunk.statement_type == "MERGE" then
      -- MERGE INTO target - first table is target
      target_table = context.chunk.tables and context.chunk.tables[1]
    end
  end

  if not target_table then
    return {}
  end

  -- Build qualified table name including schema if present
  local table_name = target_table.name or target_table
  if type(target_table) == "table" then
    if target_table.schema then
      table_name = target_table.schema .. "." .. target_table.name
    end
    if target_table.database then
      table_name = target_table.database .. "." .. table_name
    end
  end

  -- Resolve to actual table object
  local table_obj = nil
  if context.resolved_scope then
    table_obj = Resolver.get_resolved(context.resolved_scope, table_name)
  end
  if not table_obj then
    table_obj = Resolver.resolve_table(table_name, connection, context)
  end

  if not table_obj then
    return {}
  end

  -- Get columns
  local columns = Resolver.get_columns(table_obj, connection)
  if not columns or #columns == 0 then
    return {}
  end

  -- Build pseudo-table name for detail
  local pseudo_name = context.table_ref or "inserted"  -- Default to inserted if no ref

  -- Format as CompletionItems
  local items = {}
  for _, col in ipairs(columns) do
    local item = Utils.format_column(col, {
      show_type = true,
      show_nullable = true,
    })

    -- Override detail to show it's from pseudo-table
    item.detail = string.format("%s.%s", pseudo_name, col.data_type or "column")

    table.insert(items, item)
  end

  return items
end

return M
