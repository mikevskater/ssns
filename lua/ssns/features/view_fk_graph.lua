---@class ViewFKGraph
---View FK relationship graph in a floating window
---Shows FK relationships from tables in current scope
---@module ssns.features.view_fk_graph
local ViewFKGraph = {}

local UiFloat = require('ssns.ui.core.float')
local ContentBuilder = require('ssns.ui.core.content_builder')
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

  -- Try to get buffer-local database connection
  local db_key = vim.b[bufnr].ssns_db_key
  if not db_key then
    return nil
  end

  -- Parse db_key format: "server_name:database_name"
  local server_name, db_name = db_key:match("^([^:]+):(.+)$")
  if not server_name or not db_name then
    return nil
  end

  -- Find server and database in cache
  local server = Cache.find_server(server_name)
  if not server then
    return nil
  end

  local database = server:find_database(db_name)
  if not database then
    return nil
  end

  return {
    server = server,
    database = database,
    connection_config = server.connection_config,
  }
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

---Build styled content for FK graph
---@param bufnr number
---@param line_num number
---@param col number
---@return ContentBuilder cb
---@return table json_data
local function build_styled_content(bufnr, line_num, col)
  local cb = ContentBuilder.new()
  local json_data = { tables_in_scope = {}, fk_constraints = {} }

  cb:header("Foreign Key Relationship Graph")
  cb:separator("=", 50)
  cb:blank()

  -- Get connection
  local connection = get_connection()
  if not connection then
    cb:styled("(No active connection)", "error")
    cb:blank()
    cb:styled("Connect to a database to view FK relationships", "muted")
    return cb, json_data
  end

  -- Get context
  local context = StatementContext.detect_full(bufnr, line_num, col)
  if not context then
    cb:styled("(No SQL context detected)", "muted")
    return cb, json_data
  end

  -- Connection info
  cb:section("Connection")
  cb:separator("-", 30)
  local server_name = connection.server and connection.server.name or "unknown"
  local db_name = connection.database and (connection.database.db_name or connection.database.name) or "unknown"
  cb:spans({
    { text = "  Server: ", style = "label" },
    { text = server_name, style = "server" },
  })
  cb:spans({
    { text = "  Database: ", style = "label" },
    { text = db_name, style = "database" },
  })
  cb:blank()

  -- Get tables in scope
  local tables_in_scope = context.tables_in_scope or {}
  cb:section("Tables in Scope")
  cb:separator("-", 30)

  if #tables_in_scope == 0 then
    cb:styled("  (No tables in current scope)", "muted")
    cb:blank()
  else
    for _, table_info in ipairs(tables_in_scope) do
      local name = table_info.table or table_info.name or "?"
      local alias = table_info.alias and (" AS " .. table_info.alias) or ""
      local type_str = ""
      local style = "table"
      if table_info.is_cte then
        type_str = " [CTE]"
        style = "view"
      elseif table_info.is_temp_table then
        type_str = " [Temp]"
        style = "warning"
      elseif table_info.is_subquery then
        type_str = " [Subquery]"
        style = "muted"
      end
      cb:spans({
        { text = "  - " },
        { text = name .. alias, style = style },
        { text = type_str, style = "muted" },
      })

      -- Add to JSON
      table.insert(json_data.tables_in_scope, {
        table = table_info.table,
        alias = table_info.alias,
        is_cte = table_info.is_cte,
        is_temp_table = table_info.is_temp_table,
      })
    end
    cb:blank()
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
  cb:section("FK Constraints (from tables in scope)")
  cb:separator("-", 30)

  if #all_fk_constraints == 0 then
    cb:styled("  (No FK constraints found)", "muted")
    cb:blank()
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

      cb:spans({
        { text = "  " },
        { text = source, style = "table" },
        { text = "." },
        { text = source_col, style = "column" },
        { text = " -> " },
        { text = target, style = "table" },
        { text = "." },
        { text = target_col, style = "column" },
      })
      if constraint_name ~= "" then
        cb:spans({
          { text = "    Constraint: ", style = "label" },
          { text = constraint_name, style = "key" },
        })
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
    cb:blank()
  end

  -- Build FK chain graph (if we have resolved tables)
  if #resolved_tables > 0 then
    cb:section("FK Chain Graph (BFS traversal)")
    cb:separator("-", 30)
    cb:spans({
      { text = "  Max depth: ", style = "label" },
      { text = "2", style = "number" },
      { text = " hops" },
    })
    cb:blank()

    local chain_results = FKGraph.build_chains(resolved_tables, connection, 2)

    local has_results = false
    for hop = 1, 2 do
      local hop_results = chain_results[hop] or {}
      if #hop_results > 0 then
        has_results = true
        cb:spans({
          { text = "  Hop " },
          { text = tostring(hop), style = "number" },
          { text = ":" },
        })
        for _, result in ipairs(hop_results) do
          local label = FKGraph.build_label(result)
          local detail = FKGraph.build_detail(result)
          cb:spans({
            { text = "    -> " },
            { text = label, style = "table" },
          })
          cb:spans({
            { text = "       " },
            { text = detail, style = "muted" },
          })
        end
        cb:blank()
      end
    end

    if not has_results then
      cb:styled("  (No related tables found via FK chain)", "muted")
      cb:blank()
    end
  end

  return cb, json_data
end

---View FK graph
function ViewFKGraph.view_graph()
  -- Close any existing float
  ViewFKGraph.close_current_float()

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local col = cursor[2] + 1

  -- Build styled content
  local cb, json_data = build_styled_content(bufnr, line_num, col)

  -- Add JSON output
  cb:blank()
  cb:header("FK Data JSON")
  cb:separator("=", 50)
  cb:blank()

  local json_lines = JsonUtils.prettify_lines(json_data)
  for _, line in ipairs(json_lines) do
    cb:line(line)
  end

  -- Create floating window
  current_float = UiFloat.create_styled(cb, {
    title = "FK Graph",
    border = "rounded",
    min_width = 60,
    max_width = 110,
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

