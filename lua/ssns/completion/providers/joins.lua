---Smart JOIN completion provider with FK-based suggestions
---Suggests tables with auto-generated ON clauses based on foreign key relationships
---@class JoinsProvider
local JoinsProvider = {}

---Get JOIN completions for the given context
---@param ctx table Context from source (has bufnr, connection info, sql_context)
---@param callback function Callback(items)
function JoinsProvider.get_completions(ctx, callback)
  -- Wrap in pcall for error handling
  local success, result = pcall(function()
    return JoinsProvider._get_completions_impl(ctx)
  end)

  -- Schedule callback with results or empty array on error
  vim.schedule(function()
    if success then
      callback(result or {})
    else
      -- Log error in debug mode if available
      if vim.g.ssns_debug then
        vim.notify(
          string.format("[SSNS Completion] Joins provider error: %s", tostring(result)),
          vim.log.levels.ERROR
        )
      end
      callback({})
    end
  end)
end

---Internal implementation of JOIN completion retrieval
---@param ctx table Context from source
---@return table[] items Array of CompletionItems
function JoinsProvider._get_completions_impl(ctx)
  local Utils = require('ssns.completion.utils')
  local Resolver = require('ssns.completion.metadata.resolver')
  local Context = require('ssns.completion.context')

  -- Get connection information from context
  local connection_info = ctx.connection
  if not connection_info then
    return {}
  end

  local bufnr = ctx.bufnr
  if not bufnr then
    return {}
  end

  -- Get existing tables in query using Resolver
  local existing_tables = Resolver.resolve_all_tables_in_query(bufnr, connection_info)

  if not existing_tables or #existing_tables == 0 then
    -- No tables in query - fall back to general table list
    return JoinsProvider._get_fallback_tables(connection_info, {})
  end

  -- Extract existing aliases from query
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local query_text = table.concat(lines, "\n")
  local alias_map = Context.parse_aliases(query_text)

  -- Build reverse map: table_name -> alias
  local existing_aliases = {}
  for alias, table_name in pairs(alias_map) do
    existing_aliases[table_name:lower()] = alias
  end

  -- Also add table names without aliases
  for _, table_obj in ipairs(existing_tables) do
    local table_name = table_obj.name or table_obj.table_name
    if table_name and not existing_aliases[table_name:lower()] then
      existing_aliases[table_name:lower()] = table_name
    end
  end

  -- Collect FK-based suggestions
  local fk_suggestions = {}
  local suggested_tables = {} -- Track tables we've already suggested via FK

  for _, table_obj in ipairs(existing_tables) do
    -- Get constraints for this table
    local success, constraints = pcall(function()
      return table_obj:get_constraints()
    end)

    if success and constraints then
      for _, constraint in ipairs(constraints) do
        if constraint:is_foreign_key() then
          -- Build FK suggestion
          local suggestion = JoinsProvider._build_fk_suggestion(
            constraint,
            table_obj,
            existing_aliases,
            connection_info
          )

          if suggestion then
            table.insert(fk_suggestions, suggestion)
            -- Track this table as suggested
            local target_table = constraint.referenced_table
            if target_table then
              suggested_tables[target_table:lower()] = true
            end
          end
        end
      end
    end
  end

  -- Get fallback tables (general table list)
  local fallback_tables = JoinsProvider._get_fallback_tables(connection_info, existing_aliases)

  -- Filter out tables already suggested via FK
  local filtered_fallback = {}
  for _, item in ipairs(fallback_tables) do
    local table_name = item.data.name
    if table_name and not suggested_tables[table_name:lower()] then
      table.insert(filtered_fallback, item)
    end
  end

  -- Merge FK suggestions (priority 1) + fallback tables (priority 9)
  local items = {}

  for _, item in ipairs(fk_suggestions) do
    table.insert(items, item)
  end

  for _, item in ipairs(filtered_fallback) do
    table.insert(items, item)
  end

  return items
end

---Build FK-based join suggestion with auto-generated ON clause
---@param constraint ConstraintClass Foreign key constraint
---@param source_table TableClass Source table with the FK
---@param existing_aliases table<string, string> Map of table names to aliases
---@param connection table Connection info
---@return table? completion_item LSP CompletionItem or nil if failed
function JoinsProvider._build_fk_suggestion(constraint, source_table, existing_aliases, connection)
  if not constraint or not source_table then
    return nil
  end

  -- Extract FK info
  local target_table_name = constraint.referenced_table
  local target_schema = constraint.referenced_schema
  local fk_columns = constraint.columns or {}
  local referenced_columns = constraint.referenced_columns or {}

  if not target_table_name or #fk_columns == 0 or #referenced_columns == 0 then
    return nil
  end

  -- Get source table name and alias
  local source_table_name = source_table.name or source_table.table_name
  local source_alias = existing_aliases[source_table_name:lower()]

  if not source_alias then
    -- Try to find by schema.table
    if source_table.schema then
      local qualified_name = source_table.schema .. "." .. source_table_name
      source_alias = existing_aliases[qualified_name:lower()]
    end

    -- Fallback to table name itself
    if not source_alias then
      source_alias = source_table_name
    end
  end

  -- Generate alias for target table
  local target_alias = JoinsProvider._generate_alias(target_table_name, existing_aliases)

  -- Generate ON clause
  local on_parts = {}
  for i, fk_col in ipairs(fk_columns) do
    local ref_col = referenced_columns[i]
    if fk_col and ref_col then
      table.insert(on_parts, string.format("%s.%s = %s.%s", source_alias, fk_col, target_alias, ref_col))
    end
  end

  if #on_parts == 0 then
    return nil
  end

  local on_clause = table.concat(on_parts, " AND ")

  -- Build insertText with schema if present
  local table_reference = target_table_name
  if target_schema then
    table_reference = target_schema .. "." .. target_table_name
  end

  local insertText = string.format("%s %s ON %s", table_reference, target_alias, on_clause)

  -- Build documentation
  local fk_info = string.format("%s.%s → %s.%s",
    source_table_name,
    table.concat(fk_columns, ", "),
    target_table_name,
    table.concat(referenced_columns, ", "))

  local Utils = require('ssns.completion.utils')

  return {
    label = target_table_name,
    kind = Utils.CompletionItemKind.Class,
    detail = string.format("JOIN suggestion (FK: %s)", table.concat(fk_columns, ", ")),
    documentation = {
      kind = "markdown",
      value = string.format("**Foreign Key:** %s", fk_info)
    },
    insertText = insertText,
    filterText = target_table_name,
    sortText = Utils.generate_sort_text(1, target_table_name),
    data = {
      type = "join_suggestion",
      table_name = target_table_name,
      fk_columns = fk_columns,
      has_fk = true,
    }
  }
end

---Generate alias for table name
---Avoids conflicts with existing aliases in query
---@param table_name string Table name
---@param existing_aliases table<string, string> Map of existing table names to their aliases
---@return string alias Generated alias
function JoinsProvider._generate_alias(table_name, existing_aliases)
  -- Remove schema prefix if present (e.g., "dbo.Employees" -> "Employees")
  local base_name = table_name:match("%.([^%.]+)$") or table_name

  -- Build set of used aliases (values in existing_aliases map)
  local used_aliases = {}
  for _, alias in pairs(existing_aliases) do
    used_aliases[alias:lower()] = true
  end

  -- Try first letter
  local alias = base_name:sub(1, 1):lower()
  if not used_aliases[alias] then
    return alias
  end

  -- Try first 2 letters
  if #base_name >= 2 then
    alias = base_name:sub(1, 2):lower()
    if not used_aliases[alias] then
      return alias
    end
  end

  -- Try first 3 letters
  if #base_name >= 3 then
    alias = base_name:sub(1, 3):lower()
    if not used_aliases[alias] then
      return alias
    end
  end

  -- Fallback: use full name lowercased
  return base_name:lower()
end

---Get all tables as fallback suggestions
---Used when no FK relationships found or as general table list
---@param connection table Connection info
---@param existing_aliases table<string, string> Aliases already in use
---@return table[] items Array of CompletionItems
function JoinsProvider._get_fallback_tables(connection, existing_aliases)
  local Utils = require('ssns.completion.utils')
  local Config = require('ssns.config').get()

  if not connection or not connection.database then
    return {}
  end

  local database = connection.database

  -- Ensure database is loaded
  if not database.is_loaded then
    local success = pcall(function()
      database:load()
    end)
    if not success then
      return {}
    end
  end

  -- Get show_schema_prefix option from config
  local show_schema_prefix = Config.ui and Config.ui.show_schema_prefix
  if show_schema_prefix == nil then
    show_schema_prefix = true -- Default to true
  end

  local items = {}

  -- Find TABLES group
  local tables_group = nil
  for _, child in ipairs(database.children) do
    if child.object_type == "tables_group" then
      tables_group = child
      break
    end
  end

  if tables_group then
    for _, table_obj in ipairs(tables_group.children) do
      local table_name = table_obj.name or table_obj.table_name

      -- Generate alias for this table
      local alias = JoinsProvider._generate_alias(table_name, existing_aliases)

      -- Build insert text: "TableName alias"
      local table_reference = table_name
      if show_schema_prefix and table_obj.schema then
        table_reference = table_obj.schema .. "." .. table_name
      end

      local insertText = string.format("%s %s", table_reference, alias)

      -- Format as completion item
      local detail
      if show_schema_prefix and table_obj.schema then
        detail = string.format("%s.%s (TABLE)", table_obj.schema, table_name)
      else
        detail = string.format("%s (TABLE)", table_name)
      end

      table.insert(items, {
        label = table_name,
        kind = Utils.CompletionItemKind.Class,
        detail = detail,
        documentation = nil,
        insertText = insertText,
        filterText = table_name,
        sortText = Utils.generate_sort_text(9, table_name), -- Low priority
        data = {
          type = "join_fallback",
          name = table_name,
          schema = table_obj.schema,
          has_fk = false,
        }
      })
    end
  end

  -- Also include views if supported
  local adapter = database:get_adapter()
  if adapter.features and adapter.features.views then
    local views_group = nil
    for _, child in ipairs(database.children) do
      if child.object_type == "views_group" then
        views_group = child
        break
      end
    end

    if views_group then
      for _, view_obj in ipairs(views_group.children) do
        local view_name = view_obj.name or view_obj.view_name

        -- Generate alias for this view
        local alias = JoinsProvider._generate_alias(view_name, existing_aliases)

        -- Build insert text: "ViewName alias"
        local view_reference = view_name
        if show_schema_prefix and view_obj.schema then
          view_reference = view_obj.schema .. "." .. view_name
        end

        local insertText = string.format("%s %s", view_reference, alias)

        -- Format as completion item
        local detail
        if show_schema_prefix and view_obj.schema then
          detail = string.format("%s.%s (VIEW)", view_obj.schema, view_name)
        else
          detail = string.format("%s (VIEW)", view_name)
        end

        table.insert(items, {
          label = view_name,
          kind = Utils.CompletionItemKind.Class,
          detail = detail,
          documentation = nil,
          insertText = insertText,
          filterText = view_name,
          sortText = Utils.generate_sort_text(9, view_name), -- Low priority
          data = {
            type = "join_fallback",
            name = view_name,
            schema = view_obj.schema,
            has_fk = false,
          }
        })
      end
    end
  end

  return items
end

return JoinsProvider
