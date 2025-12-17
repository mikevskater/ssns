---Smart JOIN completion provider with FK-based suggestions
---Suggests tables with auto-generated ON clauses based on foreign key relationships
---@class JoinsProvider
local JoinsProvider = {}

local BaseProvider = require('ssns.completion.providers.base_provider')
local FKGraph = require('ssns.completion.fk_graph')
local TokenContext = require('ssns.completion.token_context')

-- Use BaseProvider.create_safe_wrapper for standardized error handling
JoinsProvider.get_completions = BaseProvider.create_safe_wrapper(JoinsProvider, "Joins", true)

---Internal implementation of JOIN completion retrieval
---@param ctx table Context from source
---@return table[] items Array of CompletionItems
function JoinsProvider._get_completions_impl(ctx)
  local Utils = require('ssns.completion.utils')
  local Resolver = require('ssns.completion.metadata.resolver')
  local Context = require('ssns.completion.statement_context')

  -- Get connection information from context
  local connection_info = ctx.connection
  if not connection_info then
    return {}
  end

  local sql_context = ctx.sql_context
  if not sql_context then
    return {}
  end

  -- Get existing tables in query using pre-built context
  local existing_tables = Resolver.resolve_all_tables_in_query(connection_info, sql_context)

  if not existing_tables or #existing_tables == 0 then
    -- No tables in query - fall back to general table list
    return JoinsProvider._get_fallback_tables(connection_info, {})
  end

  -- Use pre-built aliases from context
  local alias_map = sql_context.aliases or {}

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

  -- Build FK chain suggestions (1-2 hops)
  local fk_suggestions = {}
  local suggested_tables = {}

  if #existing_tables > 0 then
    local success, chain_results = pcall(function()
      return FKGraph.build_chains(existing_tables, connection_info, 2)
    end)

    if success and chain_results then
      fk_suggestions, suggested_tables = JoinsProvider._build_fk_chain_suggestions(
        chain_results,
        existing_aliases,
        sql_context,
        connection_info
      )
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
  -- Use TokenContext.get_last_name_part for consistent qualified name handling
  local base_name = TokenContext.get_last_name_part(table_name)

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

---Find the alias used for a table in the current query
---@param table_obj table TableClass
---@param sql_context table SQL context
---@return string|nil alias The alias if found
function JoinsProvider._find_alias_for_table(table_obj, sql_context)
  local table_name = (table_obj.name or table_obj.table_name or ""):lower()

  if sql_context.tables_in_scope then
    for _, tinfo in ipairs(sql_context.tables_in_scope) do
      local t_name = (tinfo.table or tinfo.name or ""):lower()
      if t_name == table_name or t_name:find(table_name, 1, true) then
        return tinfo.alias or tinfo.table or tinfo.name
      end
    end
  end

  return table_name:sub(1, 1)
end

---Build completion items from FK chain results
---@param chain_results table Results from FKGraph.build_chains
---@param existing_aliases table<string, boolean> Aliases already used in query
---@param sql_context table SQL context with query info
---@param connection table Connection info
---@return table[] items CompletionItems
---@return table<string, boolean> suggested_tables Tables that were suggested
function JoinsProvider._build_fk_chain_suggestions(chain_results, existing_aliases, sql_context, connection)
  local items = {}
  local suggested_tables = {}

  local flat_results = FKGraph.flatten_and_sort(chain_results)

  for _, result in ipairs(flat_results) do
    local table_obj = result.table_obj
    if not table_obj then
      goto continue
    end

    local table_name = table_obj.name or table_obj.table_name
    if not table_name then
      goto continue
    end

    local table_key = table_name:lower()
    if table_obj.schema then
      table_key = table_obj.schema:lower() .. "." .. table_key
    end

    -- Skip if already suggested
    if suggested_tables[table_key] then
      goto continue
    end
    suggested_tables[table_key] = true
    suggested_tables[table_name:lower()] = true

    -- Generate alias
    local alias = JoinsProvider._generate_alias(table_name, existing_aliases)
    existing_aliases[alias:lower()] = true

    -- Build label and detail using FKGraph helpers
    local label = FKGraph.build_label(result)
    local detail = FKGraph.build_detail(result)

    -- Build insert text with ON clause for direct FKs (1 hop)
    local insert_text = table_name .. " " .. alias

    if result.hop_count == 1 and result.constraint and result.source_table then
      local source_alias = JoinsProvider._find_alias_for_table(result.source_table, sql_context)
      local constraint = result.constraint

      if source_alias and constraint.columns and constraint.referenced_columns then
        local on_parts = {}
        for i, fk_col in ipairs(constraint.columns) do
          local ref_col = constraint.referenced_columns[i]
          if fk_col and ref_col then
            table.insert(on_parts, string.format("%s.%s = %s.%s",
              source_alias, fk_col, alias, ref_col))
          end
        end

        if #on_parts > 0 then
          insert_text = table_name .. " " .. alias .. " ON " .. table.concat(on_parts, " AND ")
        end
      end
    end

    -- Priority based on hop count: 1 hop = 100, 2 hops = 200, etc.
    local priority = result.hop_count * 100

    local item = {
      label = label,
      kind = vim.lsp.protocol.CompletionItemKind.Class,
      detail = detail,
      insertText = insert_text,
      sortText = string.format("%04d_%s", priority, table_name),
      documentation = {
        kind = "markdown",
        value = FKGraph.build_documentation(result),
      },
      data = {
        table_name = table_name,
        hop_count = result.hop_count,
        is_fk_suggestion = true,
      },
    }

    table.insert(items, item)
    ::continue::
  end

  return items, suggested_tables
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

  -- Get show_schema_prefix option from config
  local show_schema_prefix = Config.ui and Config.ui.show_schema_prefix
  if show_schema_prefix == nil then
    show_schema_prefix = true -- Default to true
  end

  local items = {}

  -- Use database accessor method (handles schema-based vs non-schema servers)
  local tables = database:get_tables()

  for _, table_obj in ipairs(tables) do
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

  -- Also include views if supported
  local adapter = database:get_adapter()
  if adapter.features and adapter.features.views then
    local views = database:get_views()

    for _, view_obj in ipairs(views) do
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

  return items
end

return JoinsProvider
