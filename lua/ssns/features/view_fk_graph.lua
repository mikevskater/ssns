---@class ViewFKGraph
---View FK relationship graph in a floating window
---Shows FK relationships from tables in current scope
---@module ssns.features.view_fk_graph
local ViewFKGraph = {}

local UiFloat = require('ssns.ui.float')
local JsonUtils = require('ssns.utils.json')
local FKGraph = require('ssns.completion.fk_graph')
local StatementContext = require('ssns.completion.statement_context')
local Resolver = require('ssns.completion.metadata.resolver')

-- Store reference to current floating window for cleanup
local current_float = nil

---Close the current floating window
function ViewFKGraph.close_current_float()
  if current_float then
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
end

---Get current connection context
---@return table? connection
local function get_connection()
  local Cache = require('ssns.cache')
  local bufnr = vim.api.nvim_get_current_buf()
  return Cache.get_buffer_connection(bufnr)
end

---Get FK constraints from a table
---@param table_obj table
---@return table[] constraints
local function get_fk_constraints(table_obj)
  if not table_obj then return {} end

  local success, result = pcall(function()
    if table_obj.get_constraints then
      return table_obj:get_constraints() or {}
    end
    return table_obj.constraints or {}
  end)

  if not success or not result then
    return {}
  end

  -- Filter for FK constraints
  local fks = {}
  for _, constraint in ipairs(result) do
    local is_fk = false
    if constraint.constraint_type then
      local ctype = constraint.constraint_type:upper()
      is_fk = ctype:find("FOREIGN") ~= nil or ctype == "FK"
    end
    if is_fk then
      table.insert(fks, constraint)
    end
  end

  return fks
end

---Build display content for FK graph
---@param bufnr number
---@param line_num number
---@param col number
---@return string[] display_lines
---@return table json_data
local function build_display_content(bufnr, line_num, col)
  local display_lines = {}
  local json_data = { tables_in_scope = {}, fk_constraints = {} }

  table.insert(display_lines, "Foreign Key Relationship Graph")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Get connection
  local connection = get_connection()
  if not connection then
    table.insert(display_lines, "(No active connection)")
    table.insert(display_lines, "")
    table.insert(display_lines, "Connect to a database to view FK relationships")
    return display_lines, json_data
  end

  -- Get context
  local context = StatementContext.detect_full(bufnr, line_num, col)
  if not context then
    table.insert(display_lines, "(No SQL context detected)")
    return display_lines, json_data
  end

  -- Connection info
  table.insert(display_lines, "Connection")
  table.insert(display_lines, string.rep("-", 30))
  local server_name = connection.server and connection.server.name or "unknown"
  local db_name = connection.database and (connection.database.db_name or connection.database.name) or "unknown"
  table.insert(display_lines, string.format("  Server: %s", server_name))
  table.insert(display_lines, string.format("  Database: %s", db_name))
  table.insert(display_lines, "")

  -- Get tables in scope
  local tables_in_scope = context.tables_in_scope or {}
  table.insert(display_lines, "Tables in Scope")
  table.insert(display_lines, string.rep("-", 30))

  if #tables_in_scope == 0 then
    table.insert(display_lines, "  (No tables in current scope)")
    table.insert(display_lines, "")
  else
    for _, table_info in ipairs(tables_in_scope) do
      local name = table_info.table or table_info.name or "?"
      local alias = table_info.alias and (" AS " .. table_info.alias) or ""
      local type_str = ""
      if table_info.is_cte then type_str = " [CTE]"
      elseif table_info.is_temp_table then type_str = " [Temp]"
      elseif table_info.is_subquery then type_str = " [Subquery]"
      end
      table.insert(display_lines, string.format("  - %s%s%s", name, alias, type_str))

      -- Add to JSON
      table.insert(json_data.tables_in_scope, {
        table = table_info.table,
        alias = table_info.alias,
        is_cte = table_info.is_cte,
        is_temp_table = table_info.is_temp_table,
      })
    end
    table.insert(display_lines, "")
  end

  -- Resolve tables and get FK constraints
  local resolved_tables = {}
  local all_fk_constraints = {}

  for _, table_info in ipairs(tables_in_scope) do
    -- Skip non-database tables
    if not (table_info.is_cte or table_info.is_temp_table or table_info.is_subquery) then
      local table_name = table_info.table or table_info.name
      if table_name then
        local resolved = Resolver.resolve_table(table_name, connection, context)
        if resolved then
          table.insert(resolved_tables, resolved)

          -- Get FK constraints
          local fks = get_fk_constraints(resolved)
          for _, fk in ipairs(fks) do
            fk._source_table = table_name
            table.insert(all_fk_constraints, fk)
          end
        end
      end
    end
  end

  -- FK Constraints from tables in scope
  table.insert(display_lines, "FK Constraints (from tables in scope)")
  table.insert(display_lines, string.rep("-", 30))

  if #all_fk_constraints == 0 then
    table.insert(display_lines, "  (No FK constraints found)")
    table.insert(display_lines, "")
  else
    for _, fk in ipairs(all_fk_constraints) do
      local source = fk._source_table or "?"
      local source_col = fk.column_name or fk.columns or "?"
      if type(source_col) == "table" then
        source_col = table.concat(source_col, ", ")
      end

      local target = fk.referenced_table or "?"
      if fk.referenced_schema then
        target = fk.referenced_schema .. "." .. target
      end
      local target_col = fk.referenced_column or fk.referenced_columns or "?"
      if type(target_col) == "table" then
        target_col = table.concat(target_col, ", ")
      end

      local constraint_name = fk.constraint_name or fk.name or ""

      table.insert(display_lines, string.format("  %s.%s -> %s.%s",
        source, source_col, target, target_col))
      if constraint_name ~= "" then
        table.insert(display_lines, string.format("    Constraint: %s", constraint_name))
      end

      -- Add to JSON
      table.insert(json_data.fk_constraints, {
        source_table = fk._source_table,
        source_column = fk.column_name or fk.columns,
        target_table = fk.referenced_table,
        target_schema = fk.referenced_schema,
        target_column = fk.referenced_column or fk.referenced_columns,
        constraint_name = fk.constraint_name or fk.name,
      })
    end
    table.insert(display_lines, "")
  end

  -- Build FK chain graph (if we have resolved tables)
  if #resolved_tables > 0 then
    table.insert(display_lines, "FK Chain Graph (BFS traversal)")
    table.insert(display_lines, string.rep("-", 30))
    table.insert(display_lines, "  Max depth: 2 hops")
    table.insert(display_lines, "")

    local chain_results = FKGraph.build_chains(resolved_tables, connection, 2)

    local has_results = false
    for hop = 1, 2 do
      local hop_results = chain_results[hop] or {}
      if #hop_results > 0 then
        has_results = true
        table.insert(display_lines, string.format("  Hop %d:", hop))
        for _, result in ipairs(hop_results) do
          local label = FKGraph.build_label(result)
          local detail = FKGraph.build_detail(result)
          table.insert(display_lines, string.format("    -> %s", label))
          table.insert(display_lines, string.format("       %s", detail))
        end
        table.insert(display_lines, "")
      end
    end

    if not has_results then
      table.insert(display_lines, "  (No related tables found via FK chain)")
      table.insert(display_lines, "")
    end
  end

  return display_lines, json_data
end

---View FK graph
function ViewFKGraph.view_graph()
  -- Close any existing float
  ViewFKGraph.close_current_float()

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local col = cursor[2] + 1

  -- Build display content
  local display_lines, json_data = build_display_content(bufnr, line_num, col)

  -- Add JSON output
  table.insert(display_lines, "")
  table.insert(display_lines, "FK Data JSON")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  local json_lines = JsonUtils.prettify_lines(json_data)
  for _, line in ipairs(json_lines) do
    table.insert(display_lines, line)
  end

  -- Create floating window
  current_float = UiFloat.create(display_lines, {
    title = "FK Graph",
    border = "rounded",
    filetype = "json",
    min_width = 60,
    max_width = 110,
    max_height = 50,
    wrap = false,
    keymaps = {
      ['r'] = function()
        ViewFKGraph.view_graph()
      end,
    },
    footer = "q: close | r: refresh",
  })
end

return ViewFKGraph
