---Asterisk expansion module for SSNS
---Expands SELECT * or alias.* into explicit column lists
---Used by: user command (<leader>ce), CTE tracking, temp table tracking
---@class ExpandAsterisk
local ExpandAsterisk = {}

local Resolver = require('ssns.completion.metadata.resolver')
local ScopeTracker = require('ssns.completion.metadata.scope_tracker')
local Context = require('ssns.completion.statement_context')
local Debug = require('ssns.debug')

-- Helper: Conditional debug logging based on config
local function debug_log(message)
  local Config = require('ssns.config')
  local config = Config.get()
  if config.completion and config.completion.debug then
    Debug.log("[EXPAND_ASTERISK] " .. message)
  end
end

---Detect if cursor is on/near an asterisk token
---@param line string The line of text to analyze
---@param col number Column position (0-indexed)
---@return table result { is_asterisk: boolean, asterisk_col: number?, table_prefix: string?, is_in_function: boolean, is_in_quotes: boolean }
function ExpandAsterisk.detect_asterisk_at_cursor(line, col)
  debug_log(string.format("detect_asterisk_at_cursor: col=%d, line=%s", col, line))

  local result = {
    is_asterisk = false,
    asterisk_col = nil,
    table_prefix = nil,
    is_in_function = false,
    is_in_quotes = false,
  }

  -- Check if cursor is in quotes
  local before_cursor = line:sub(1, col + 1)
  local single_quotes = 0
  local double_quotes = 0
  for _ in before_cursor:gmatch("'") do
    single_quotes = single_quotes + 1
  end
  for _ in before_cursor:gmatch('"') do
    double_quotes = double_quotes + 1
  end

  if (single_quotes % 2) == 1 or (double_quotes % 2) == 1 then
    result.is_in_quotes = true
    debug_log("Asterisk is inside quotes, skipping")
    return result
  end

  -- Find asterisk at or near cursor
  -- Check: exact position, or within same whitespace-separated token
  local asterisk_col = nil

  -- Check exact position
  if line:sub(col + 1, col + 1) == '*' then
    asterisk_col = col
  -- Check one character before
  elseif col > 0 and line:sub(col, col) == '*' then
    asterisk_col = col - 1
  -- Check one character after
  elseif col < #line and line:sub(col + 2, col + 2) == '*' then
    asterisk_col = col + 1
  else
    -- Search backward/forward in same token (no whitespace between)
    local start_pos = col
    while start_pos > 0 and not line:sub(start_pos, start_pos):match("%s") do
      if line:sub(start_pos, start_pos) == '*' then
        asterisk_col = start_pos - 1
        break
      end
      start_pos = start_pos - 1
    end

    if not asterisk_col then
      local end_pos = col + 1
      while end_pos <= #line and not line:sub(end_pos, end_pos):match("%s") do
        if line:sub(end_pos, end_pos) == '*' then
          asterisk_col = end_pos - 1
          break
        end
        end_pos = end_pos + 1
      end
    end
  end

  if not asterisk_col then
    debug_log("No asterisk found near cursor")
    return result
  end

  debug_log(string.format("Found asterisk at col=%d", asterisk_col))
  result.is_asterisk = true
  result.asterisk_col = asterisk_col

  -- Check if asterisk is inside parentheses (function call like COUNT(*))
  -- Count unmatched opening parens before asterisk
  local before_asterisk = line:sub(1, asterisk_col)
  local open_parens = 0
  local close_parens = 0

  for i = 1, #before_asterisk do
    local char = before_asterisk:sub(i, i)
    if char == '(' then
      open_parens = open_parens + 1
    elseif char == ')' then
      close_parens = close_parens + 1
    end
  end

  if open_parens > close_parens then
    result.is_in_function = true
    debug_log("Asterisk is inside parentheses (function call), skipping")
    return result
  end

  -- Check for table_prefix.* pattern (e.g., "e.*" or "dbo.Employees.*")
  -- Look backward from asterisk for identifier followed by dot
  local prefix_match = before_asterisk:match("([%w_%.%[%]]+)%.$")
  if prefix_match then
    -- Clean up brackets if present
    prefix_match = prefix_match:gsub("%[", ""):gsub("%]", "")
    result.table_prefix = prefix_match
    debug_log(string.format("Found table prefix: %s", prefix_match))
  else
    debug_log("No table prefix found (bare asterisk)")
  end

  return result
end

---Extract all tables referenced in a SELECT statement at the cursor position
---@param query_text string Full query text
---@param scope_tree table Scope tree from ScopeTracker
---@param cursor_pos table {row, col} Cursor position (1-indexed row, 0-indexed col)
---@return table[] tables Array of {alias: string?, table_name: string, order: number}
function ExpandAsterisk.get_tables_in_select(query_text, scope_tree, cursor_pos)
  debug_log(string.format("get_tables_in_select: cursor at {%d,%d}", cursor_pos[1], cursor_pos[2]))

  -- Get scope at cursor position
  local scope = ScopeTracker.get_scope_at_cursor(scope_tree, cursor_pos)
  if not scope then
    debug_log("No scope found at cursor")
    return {}
  end

  debug_log(string.format("Found scope: type=%s", scope.type))
  debug_log(string.format("Scope aliases: %s", vim.inspect(scope.aliases)))

  -- Collect all aliases from this scope and parent scopes
  local available_aliases = ScopeTracker.get_available_aliases(scope_tree, cursor_pos)

  debug_log(string.format("Available aliases: %s", vim.inspect(available_aliases)))

  -- Convert aliases to table array with order preservation
  local tables = {}
  local order = 1

  -- Use scope.aliases directly to preserve order from the query
  -- (ScopeTracker preserves insertion order from FROM/JOIN parsing)
  for alias, table_name in pairs(available_aliases) do
    table.insert(tables, {
      alias = alias,
      table_name = table_name,
      order = order,
    })
    order = order + 1
  end

  -- Sort by order (should already be in order, but ensure it)
  table.sort(tables, function(a, b)
    return a.order < b.order
  end)

  debug_log(string.format("Extracted %d tables from SELECT", #tables))
  return tables
end

---Format column list into comma-separated string with table prefixes
---@param columns table[] Array of {name: string, table_alias: string?, table_name: string}
---@param include_table_prefix boolean Always true (qualify columns with alias/table)
---@return string formatted_list Formatted column list
function ExpandAsterisk.format_column_list(columns, include_table_prefix)
  debug_log(string.format("format_column_list: %d columns, include_prefix=%s",
    #columns, tostring(include_table_prefix)))

  if #columns == 0 then
    return ""
  end

  local parts = {}
  for _, col in ipairs(columns) do
    local prefix = col.table_alias or col.table_name
    if include_table_prefix and prefix then
      table.insert(parts, string.format("%s.%s", prefix, col.name))
    else
      table.insert(parts, col.name)
    end
  end

  local result = table.concat(parts, ", ")
  debug_log(string.format("Formatted result: %s", result:sub(1, 100)))
  return result
end

---Expand asterisk in context
---Main entry point for asterisk expansion
---@param bufnr number Buffer number
---@param connection table Connection context {server: ServerClass, database: DbClass, connection_string: string}
---@param cursor_pos table {row, col} Cursor position (1-indexed row, 0-indexed col)
---@param query_text string? Optional query text (defaults to buffer content)
---@param scope_tree table? Optional scope tree (will be built if not provided)
---@return table result {success: boolean, columns: table[]?, replacement_text: string?, error: string?}
function ExpandAsterisk.expand_asterisk_in_context(bufnr, connection, cursor_pos, query_text, scope_tree)
  debug_log(string.format("expand_asterisk_in_context: bufnr=%d, cursor={%d,%d}",
    bufnr, cursor_pos[1], cursor_pos[2]))

  -- Validate inputs
  if not bufnr or not connection then
    return {
      success = false,
      error = "Invalid parameters: bufnr and connection required"
    }
  end

  if not connection.connection_string then
    return {
      success = false,
      error = "No database connection available"
    }
  end

  if not connection.database then
    return {
      success = false,
      error = "No database selected"
    }
  end

  -- Get query text if not provided
  if not query_text then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    query_text = table.concat(lines, "\n")
  end

  -- Build scope tree if not provided
  if not scope_tree then
    local success, tree = pcall(function()
      return ScopeTracker.build_scope_tree(query_text, bufnr, connection)
    end)

    if not success or not tree then
      return {
        success = false,
        error = "Failed to parse query structure"
      }
    end
    scope_tree = tree
  end

  -- Get current line for asterisk detection
  local line = vim.api.nvim_buf_get_lines(bufnr, cursor_pos[1] - 1, cursor_pos[1], false)[1]
  if not line then
    return {
      success = false,
      error = "Could not read current line"
    }
  end

  -- Detect asterisk at cursor
  local asterisk_info = ExpandAsterisk.detect_asterisk_at_cursor(line, cursor_pos[2])

  if not asterisk_info.is_asterisk then
    return {
      success = false,
      error = "Cursor is not on an asterisk"
    }
  end

  if asterisk_info.is_in_function then
    return {
      success = false,
      error = "Cannot expand asterisk inside function (e.g., COUNT(*))"
    }
  end

  if asterisk_info.is_in_quotes then
    return {
      success = false,
      error = "Cannot expand asterisk inside quoted string"
    }
  end

  -- Determine which table(s) to expand
  local tables_to_expand = {}

  if asterisk_info.table_prefix then
    -- Qualified asterisk: alias.* or schema.table.*
    debug_log(string.format("Expanding qualified asterisk: %s.*", asterisk_info.table_prefix))

    -- Resolve the prefix (could be alias, table name, or schema.table)
    local resolved_table = nil
    local success, result = pcall(function()
      return Resolver.resolve_table(
        asterisk_info.table_prefix,
        connection,
        bufnr,
        cursor_pos
      )
    end)

    if success and result then
      resolved_table = result
    else
      return {
        success = false,
        error = string.format("Table not found: %s", asterisk_info.table_prefix)
      }
    end

    tables_to_expand = {{
      alias = asterisk_info.table_prefix,
      table_name = asterisk_info.table_prefix,
      table_obj = resolved_table,
      order = 1,
    }}
  else
    -- Bare asterisk: expand all tables in SELECT
    debug_log("Expanding bare asterisk (all tables in SELECT)")

    local table_refs = ExpandAsterisk.get_tables_in_select(query_text, scope_tree, cursor_pos)

    if #table_refs == 0 then
      return {
        success = false,
        error = "No tables found in SELECT statement"
      }
    end

    -- Resolve each table reference
    for _, ref in ipairs(table_refs) do
      local success, table_obj = pcall(function()
        return Resolver.resolve_table(ref.table_name, connection, bufnr, cursor_pos)
      end)

      if success and table_obj then
        table.insert(tables_to_expand, {
          alias = ref.alias,
          table_name = ref.table_name,
          table_obj = table_obj,
          order = ref.order,
        })
      else
        debug_log(string.format("Warning: Could not resolve table %s", ref.table_name))
      end
    end

    if #tables_to_expand == 0 then
      return {
        success = false,
        error = "Could not resolve any tables in query"
      }
    end
  end

  -- Get columns for each table
  local all_columns = {}

  for _, tbl in ipairs(tables_to_expand) do
    debug_log(string.format("Getting columns for table: %s (alias: %s)",
      tbl.table_name, tbl.alias or "none"))

    local success, columns = pcall(function()
      return Resolver.get_columns(tbl.table_obj, connection)
    end)

    if not success or not columns or #columns == 0 then
      return {
        success = false,
        error = string.format("No columns found for table: %s", tbl.table_name)
      }
    end

    debug_log(string.format("Found %d columns for %s", #columns, tbl.table_name))

    -- Sort columns by ordinal_position
    table.sort(columns, function(a, b)
      local a_pos = a.ordinal_position or 999999
      local b_pos = b.ordinal_position or 999999
      return a_pos < b_pos
    end)

    -- Add columns with table alias/name prefix
    for _, col in ipairs(columns) do
      table.insert(all_columns, {
        name = col.name or col.column_name,
        table_alias = tbl.alias,
        table_name = tbl.table_name,
        ordinal_position = col.ordinal_position,
      })
    end
  end

  if #all_columns == 0 then
    return {
      success = false,
      error = "No columns found"
    }
  end

  -- Format replacement text (always include table prefix per requirements)
  local replacement_text = ExpandAsterisk.format_column_list(all_columns, true)

  debug_log(string.format("Expansion successful: %d columns", #all_columns))

  return {
    success = true,
    columns = all_columns,
    replacement_text = replacement_text,
  }
end

---Helper: Get connection context for a buffer
---@param bufnr number Buffer number
---@return table? connection Connection context or nil
local function get_buffer_connection(bufnr)
  -- Try to get connection from buffer variable
  local ok, conn_string = pcall(vim.api.nvim_buf_get_var, bufnr, "ssns_connection_string")
  if ok and conn_string then
    local database = nil
    local ok_db, db = pcall(vim.api.nvim_buf_get_var, bufnr, "ssns_database")
    if ok_db then
      database = db
    end

    return {
      connection_string = conn_string,
      database = database,
    }
  end

  -- Fallback: Get active database from cache
  local Cache = require('ssns.cache')
  local active_db = Cache.get_active_database()
  if active_db then
    local server = active_db.parent
    return {
      connection_string = server.connection_string,
      database = active_db.name,
    }
  end

  return nil
end

---Expand asterisk at cursor position in buffer
---User-facing function for <leader>ce command
---@param bufnr number? Buffer number (defaults to current buffer)
function ExpandAsterisk.expand_asterisk_at_cursor(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  debug_log("expand_asterisk_at_cursor: Starting expansion")

  -- Get cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_pos = {cursor[1], cursor[2]}  -- {row (1-indexed), col (0-indexed)}
  local line_num = cursor_pos[1]
  local col = cursor_pos[2]

  debug_log(string.format("Cursor position: line=%d, col=%d", line_num, col))

  -- Get current line
  local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
  if not line then
    vim.notify("No line at cursor", vim.log.levels.ERROR)
    return
  end

  -- Get buffer text for parsing
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local query_text = table.concat(lines, "\n")

  -- Get connection context
  local connection = get_buffer_connection(bufnr)
  if not connection then
    vim.notify("No database connection found for buffer", vim.log.levels.ERROR)
    return
  end

  -- Build scope tree
  local scope_tree = ScopeTracker.build_scope_tree(query_text, bufnr, connection)

  -- Expand asterisk
  local result = ExpandAsterisk.expand_asterisk_in_context(
    bufnr,
    connection,
    cursor_pos,
    query_text,
    scope_tree
  )

  if not result.success then
    vim.notify(result.error or "Failed to expand asterisk", vim.log.levels.ERROR)
    return
  end

  if not result.replacement_text or result.replacement_text == "" then
    vim.notify("No columns found to expand", vim.log.levels.WARN)
    return
  end

  -- Replace asterisk in buffer
  local detect_result = ExpandAsterisk.detect_asterisk_at_cursor(line, col)
  if not detect_result.is_asterisk then
    vim.notify("Cursor is not on an asterisk", vim.log.levels.ERROR)
    return
  end

  local asterisk_col = detect_result.asterisk_col
  local table_prefix = detect_result.table_prefix

  -- Calculate replacement range
  local start_col, end_col
  if table_prefix then
    -- Replace "table.*" or "alias.*"
    start_col = asterisk_col - #table_prefix - 1  -- Include the table name and dot
    end_col = asterisk_col
  else
    -- Replace just "*"
    start_col = asterisk_col - 1
    end_col = asterisk_col
  end

  -- Build new line with replacement
  local new_line = line:sub(1, start_col) .. result.replacement_text .. line:sub(end_col + 1)

  debug_log(string.format("Replacing '%s' with '%s'",
    line:sub(start_col + 1, end_col),
    result.replacement_text))

  -- Set modified line in buffer
  vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})

  -- Move cursor to end of replacement
  local new_col = start_col + #result.replacement_text
  vim.api.nvim_win_set_cursor(0, {line_num, new_col})

  -- Notify user
  local col_count = #result.columns
  vim.notify(string.format("Expanded to %d column(s)", col_count), vim.log.levels.INFO)

  debug_log(string.format("Expansion complete: %d columns", col_count))
end

return ExpandAsterisk
