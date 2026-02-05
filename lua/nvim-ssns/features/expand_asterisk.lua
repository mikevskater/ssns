---Asterisk expansion module for SSNS
---Expands SELECT * or alias.* into explicit column lists
---Used by: user command (<leader>ce), CTE tracking, temp table tracking
---@class ExpandAsterisk
local ExpandAsterisk = {}

local Resolver = require('nvim-ssns.completion.metadata.resolver')
local StatementCache = require('nvim-ssns.completion.statement_cache')
local BufferConnection = require('nvim-ssns.utils.buffer_connection')
local Debug = require('nvim-ssns.debug')

-- Helper: Conditional debug logging based on config
local function debug_log(message)
  local Config = require('nvim-ssns.config')
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
---@param bufnr number Buffer number
---@param cursor_pos table {row, col} Cursor position (1-indexed row, 0-indexed col)
---@return table[] tables Array of {alias: string?, table_name: string, schema: string?, is_cte: boolean?, is_temp: boolean?, order: number}
---@return table? context The StatementCache context
function ExpandAsterisk.get_tables_in_select(bufnr, cursor_pos)
  debug_log(string.format("get_tables_in_select: cursor at {%d,%d}", cursor_pos[1], cursor_pos[2]))

  local context = StatementCache.get_context_at_position(bufnr, cursor_pos[1], cursor_pos[2])
  if not context then
    debug_log("No context found at cursor position")
    return {}, nil
  end

  if not context.tables or #context.tables == 0 then
    debug_log("No tables found in context")
    return {}, context
  end

  debug_log(string.format("Found %d tables in context", #context.tables))

  -- Convert TableReference objects to expected format
  -- Tables are already in FROM/JOIN order from the parser
  local tables = {}
  for i, table_ref in ipairs(context.tables) do
    table.insert(tables, {
      alias = table_ref.alias,
      table_name = table_ref.name,
      schema = table_ref.schema,
      database = table_ref.database,
      is_cte = table_ref.is_cte,
      is_temp = table_ref.is_temp or table_ref.is_table_variable,
      is_subquery = table_ref.is_subquery,
      subquery_columns = table_ref.columns,  -- Columns for CTEs, subqueries, and temp tables
      order = i,
    })
    debug_log(string.format("  Table %d: %s (alias: %s, is_cte: %s, is_temp: %s, is_subquery: %s)",
      i, table_ref.name, table_ref.alias or "none",
      tostring(table_ref.is_cte), tostring(table_ref.is_temp), tostring(table_ref.is_subquery)))
  end

  return tables, context
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
---@param connection table Connection context {server: ServerClass, database: DbClass, connection_config: ConnectionData}
---@param cursor_pos table {row, col} Cursor position (1-indexed row, 0-indexed col)
---@param query_text string? Optional query text (defaults to buffer content)
---@return table result {success: boolean, columns: table[]?, replacement_text: string?, start_col: number?, end_col: number?, error: string?}
function ExpandAsterisk.expand_asterisk_in_context(bufnr, connection, cursor_pos, query_text)
  debug_log(string.format("expand_asterisk_in_context: bufnr=%d, cursor={%d,%d}",
    bufnr, cursor_pos[1], cursor_pos[2]))

  -- Validate inputs
  if not bufnr or not connection then
    return {
      success = false,
      error = "Invalid parameters: bufnr and connection required"
    }
  end

  if not connection.connection_config then
    return {
      success = false,
      error = "No database connection available"
    }
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

  -- Get context from StatementCache
  local context = StatementCache.get_context_at_position(bufnr, cursor_pos[1], cursor_pos[2])
  if not context then
    return {
      success = false,
      error = "Could not parse query context"
    }
  end

  -- Determine which table(s) to expand
  local tables_to_expand = {}

  if asterisk_info.table_prefix then
    -- Qualified asterisk: alias.* or schema.table.*
    debug_log(string.format("Expanding qualified asterisk: %s.*", asterisk_info.table_prefix))

    local prefix_lower = asterisk_info.table_prefix:lower()
    local table_ref = nil

    -- Check aliases first (most common case)
    if context.aliases and context.aliases[prefix_lower] then
      table_ref = context.aliases[prefix_lower]
      debug_log(string.format("Found alias '%s' -> table '%s'", asterisk_info.table_prefix, table_ref.name or table_ref))
    else
      -- Check direct table name match
      if context.tables then
        for _, tbl in ipairs(context.tables) do
          if tbl.name and tbl.name:lower() == prefix_lower then
            table_ref = tbl
            break
          end
          -- Also check if prefix matches alias
          if tbl.alias and tbl.alias:lower() == prefix_lower then
            table_ref = tbl
            break
          end
        end
      end
    end

    if not table_ref then
      return {
        success = false,
        error = string.format("Table or alias not found: %s", asterisk_info.table_prefix)
      }
    end

    -- Handle the case where aliases stores just the table name string
    local tbl_name = type(table_ref) == "string" and table_ref or table_ref.name
    local tbl_schema = type(table_ref) == "table" and table_ref.schema or nil
    local is_cte = type(table_ref) == "table" and table_ref.is_cte or false
    local is_temp = type(table_ref) == "table" and (table_ref.is_temp or table_ref.is_table_variable) or false
    local is_subquery = type(table_ref) == "table" and table_ref.is_subquery or false
    local subquery_columns = type(table_ref) == "table" and table_ref.columns or nil

    tables_to_expand = {{
      alias = asterisk_info.table_prefix,
      table_name = tbl_name,
      schema = tbl_schema,
      is_cte = is_cte,
      is_temp = is_temp,
      is_subquery = is_subquery,
      subquery_columns = subquery_columns,
      order = 1,
    }}
  else
    -- Bare asterisk: expand all tables in SELECT
    debug_log("Expanding bare asterisk (all tables in SELECT)")

    local table_refs, _ = ExpandAsterisk.get_tables_in_select(bufnr, cursor_pos)

    if #table_refs == 0 then
      return {
        success = false,
        error = "No tables found in SELECT statement"
      }
    end

    tables_to_expand = table_refs
  end

  -- Get columns for each table
  local all_columns = {}

  for _, tbl in ipairs(tables_to_expand) do
    debug_log(string.format("Getting columns for table: %s (alias: %s, is_cte: %s, is_temp: %s, is_subquery: %s)",
      tbl.table_name, tbl.alias or "none", tostring(tbl.is_cte), tostring(tbl.is_temp), tostring(tbl.is_subquery)))

    local columns = nil

    -- Try CTE columns first
    if tbl.is_cte and context.ctes then
      local cte = context.ctes[tbl.table_name] or context.ctes[tbl.table_name:lower()]
      if cte and cte.columns and #cte.columns > 0 then
        debug_log(string.format("Using CTE columns for %s: %d columns", tbl.table_name, #cte.columns))
        columns = {}
        for i, col in ipairs(cte.columns) do
          table.insert(columns, {
            name = col.name or col.alias or ("col" .. i),
            ordinal_position = i,
          })
        end
      end
    end

    -- Try temp table columns
    if not columns and tbl.is_temp and context.temp_tables then
      local temp = context.temp_tables[tbl.table_name] or context.temp_tables[tbl.table_name:lower()]
      if temp and temp.columns and #temp.columns > 0 then
        debug_log(string.format("Using temp table columns for %s: %d columns", tbl.table_name, #temp.columns))
        columns = {}
        for i, col in ipairs(temp.columns) do
          table.insert(columns, {
            name = col.name or ("col" .. i),
            ordinal_position = i,
          })
        end
      end
    end

    -- Try subquery columns (from parsed SELECT list)
    if not columns and tbl.is_subquery then
      -- Check if columns were passed directly from the table reference
      local subquery_cols = tbl.subquery_columns
      -- Also check in context.aliases for the subquery
      if not subquery_cols and context.aliases then
        local alias_entry = context.aliases[tbl.table_name] or context.aliases[tbl.table_name:lower()]
        if alias_entry and alias_entry.is_subquery and alias_entry.columns then
          subquery_cols = alias_entry.columns
        end
      end
      if subquery_cols and #subquery_cols > 0 then
        debug_log(string.format("Using subquery columns for %s: %d columns", tbl.table_name, #subquery_cols))
        columns = {}
        for i, col in ipairs(subquery_cols) do
          table.insert(columns, {
            name = col.name or col.alias or ("col" .. i),
            ordinal_position = i,
          })
        end
      end
    end

    -- Fall back to database resolution
    if not columns then
      local resolved_table = nil
      local success, result = pcall(function()
        -- Build a reference object for the resolver
        local ref = {
          name = tbl.table_name,
          schema = tbl.schema,
          database = tbl.database,
        }
        return Resolver.resolve_table(ref, connection, context)
      end)

      if success and result then
        resolved_table = result
        local col_success, col_result = pcall(function()
          return Resolver.get_columns(resolved_table, connection)
        end)

        if col_success and col_result and #col_result > 0 then
          columns = col_result
          debug_log(string.format("Resolved %d columns from database for %s", #columns, tbl.table_name))
        end
      end

      if not columns then
        debug_log(string.format("Warning: Could not resolve columns for table %s", tbl.table_name))
        -- Continue with other tables instead of failing completely
      end
    end

    if columns and #columns > 0 then
      -- Sort columns by ordinal_position
      table.sort(columns, function(a, b)
        local a_pos = a.ordinal_position or 999999
        local b_pos = b.ordinal_position or 999999
        return a_pos < b_pos
      end)

      -- Determine prefix: use alias if available, otherwise table name
      local prefix = tbl.alias or tbl.table_name

      -- Add columns with table alias/name prefix
      for _, col in ipairs(columns) do
        table.insert(all_columns, {
          name = col.name or col.column_name,
          table_alias = prefix,
          table_name = tbl.table_name,
          ordinal_position = col.ordinal_position,
        })
      end
    end
  end

  if #all_columns == 0 then
    return {
      success = false,
      error = "No columns found for any table"
    }
  end

  -- Format replacement text (always include table prefix per requirements)
  local replacement_text = ExpandAsterisk.format_column_list(all_columns, true)

  -- Calculate replacement range for buffer update
  local asterisk_col = asterisk_info.asterisk_col
  local table_prefix = asterisk_info.table_prefix
  local start_col, end_col

  if table_prefix then
    -- Replace "table.*" or "alias.*"
    start_col = asterisk_col - #table_prefix  -- Include the table name and dot
    end_col = asterisk_col + 1  -- Include the asterisk
  else
    -- Replace just "*"
    start_col = asterisk_col
    end_col = asterisk_col + 1
  end

  debug_log(string.format("Expansion successful: %d columns, replacing cols %d-%d", #all_columns, start_col, end_col))

  return {
    success = true,
    columns = all_columns,
    replacement_text = replacement_text,
    start_col = start_col,
    end_col = end_col,
  }
end

---Find all expandable asterisks in a buffer range using token cache
---Uses the StatementCache to properly identify asterisks in SELECT lists
---@param bufnr number Buffer number
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return table[] Array of {line: number, col: number, table_prefix: string?} for each expandable asterisk
local function find_expandable_asterisks_via_tokens(bufnr, start_line, end_line)
  local asterisks = {}

  -- Get the statement cache
  local cache = StatementCache.get_or_build_cache(bufnr)
  if not cache or not cache.chunks then
    debug_log("No statement cache available")
    return asterisks
  end

  -- Find chunks that overlap with our line range
  for _, chunk in ipairs(cache.chunks) do
    -- Check if chunk overlaps with our range
    if chunk.end_line >= start_line and chunk.start_line <= end_line then
      -- Check if this chunk has star columns
      if chunk.columns then
        local star_count = 0
        for _, col in ipairs(chunk.columns) do
          if col.is_star then
            star_count = star_count + 1
          end
        end

        if star_count > 0 then
          debug_log(string.format("Chunk has %d star columns, getting tokens", star_count))

          -- Get tokens for this chunk
          local tokens = StatementCache.get_chunk_tokens(bufnr, chunk)
          if tokens and #tokens > 0 then
            -- Walk through tokens to find asterisks in SELECT list context
            local in_select_list = false
            local paren_depth = 0
            local prev_identifier = nil  -- Track for alias.* pattern

            for i, token in ipairs(tokens) do
              local upper_text = token.text:upper()

              -- Track SELECT list context
              if token.type == "keyword" then
                if upper_text == "SELECT" then
                  in_select_list = true
                  paren_depth = 0  -- Reset paren depth for this SELECT
                elseif upper_text == "FROM" or upper_text == "INTO" or upper_text == "WHERE" then
                  if paren_depth == 0 then
                    in_select_list = false
                  end
                end
              end

              -- Track parentheses
              if token.type == "paren_open" or token.text == "(" then
                paren_depth = paren_depth + 1
              elseif token.type == "paren_close" or token.text == ")" then
                paren_depth = math.max(0, paren_depth - 1)
              end

              -- Track identifier before dot for alias.* pattern
              if token.type == "identifier" or token.type == "bracket_id" then
                prev_identifier = token.text:gsub("%[", ""):gsub("%]", "")
              elseif token.type ~= "dot" and token.type ~= "whitespace" and token.type ~= "newline" then
                -- Reset on non-dot, non-whitespace tokens (except asterisk which we handle)
                if token.text ~= "*" then
                  prev_identifier = nil
                end
              end

              -- Check for expandable asterisk
              if token.text == "*" and token.type == "operator" then
                if in_select_list and paren_depth == 0 then
                  -- Check if within our line range
                  if token.line >= start_line and token.line <= end_line then
                    -- Check previous token for dot (alias.* pattern)
                    local table_prefix = nil
                    if i > 1 then
                      local prev_token = tokens[i - 1]
                      if prev_token.type == "dot" and prev_identifier then
                        table_prefix = prev_identifier
                      end
                    end

                    table.insert(asterisks, {
                      line = token.line,
                      col = token.col - 1,  -- Convert to 0-indexed for consistency
                      table_prefix = table_prefix,
                    })
                    debug_log(string.format("Found expandable asterisk at line %d, col %d, prefix: %s",
                      token.line, token.col, table_prefix or "none"))
                  end
                end
                prev_identifier = nil  -- Reset after asterisk
              end
            end
          end
        end
      end

      -- Also check subqueries recursively
      if chunk.subqueries then
        for _, subquery in ipairs(chunk.subqueries) do
          if subquery.columns then
            for _, col in ipairs(subquery.columns) do
              if col.is_star then
                -- Subqueries have start_pos and end_pos
                if subquery.start_pos and subquery.end_pos then
                  if subquery.end_pos.line >= start_line and subquery.start_pos.line <= end_line then
                    -- We need tokens for this subquery - use chunk tokens and filter by position
                    -- For now, log that we found one (the main SELECT expansion should handle nested)
                    debug_log(string.format("Found star in subquery at lines %d-%d",
                      subquery.start_pos.line, subquery.end_pos.line))
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  return asterisks
end

---Expand all asterisks in a buffer range
---Used by formatter when select_star_expand is enabled
---@param bufnr number Buffer number
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return table result {success: boolean, expanded_count: number, error: string?}
function ExpandAsterisk.expand_all_asterisks_in_range(bufnr, start_line, end_line)
  debug_log(string.format("expand_all_asterisks_in_range: bufnr=%d, lines %d-%d", bufnr, start_line, end_line))

  -- Get connection context
  local connection = BufferConnection.get_connection(bufnr)
  if not connection then
    return {
      success = false,
      expanded_count = 0,
      error = "No database connection available"
    }
  end

  -- Find all expandable asterisks using the token cache
  local all_asterisks = find_expandable_asterisks_via_tokens(bufnr, start_line, end_line)

  if #all_asterisks == 0 then
    debug_log("No expandable asterisks found in range")
    return {
      success = true,
      expanded_count = 0,
    }
  end

  debug_log(string.format("Found %d expandable asterisks", #all_asterisks))

  -- Sort by line (descending), then by column (descending)
  -- This ensures we process from end to start, preserving positions
  table.sort(all_asterisks, function(a, b)
    if a.line ~= b.line then
      return a.line > b.line
    end
    return a.col > b.col
  end)

  -- Expand each asterisk
  local expanded_count = 0
  local errors = {}

  for _, ast in ipairs(all_asterisks) do
    local cursor_pos = { ast.line, ast.col }
    local result = ExpandAsterisk.expand_asterisk_in_context(bufnr, connection, cursor_pos, nil)

    if result.success and result.replacement_text then
      -- Get current line (may have been modified by previous expansions)
      local line = vim.api.nvim_buf_get_lines(bufnr, ast.line - 1, ast.line, false)[1]
      if line then
        -- Build new line with replacement
        local new_line = line:sub(1, result.start_col) .. result.replacement_text .. line:sub(result.end_col + 1)
        vim.api.nvim_buf_set_lines(bufnr, ast.line - 1, ast.line, false, { new_line })
        expanded_count = expanded_count + 1
        debug_log(string.format("Expanded asterisk at line %d col %d: %d columns",
          ast.line, ast.col, #result.columns))
      end
    else
      -- Log error but continue with other asterisks
      local err_msg = result.error or "Unknown error"
      debug_log(string.format("Failed to expand asterisk at line %d col %d: %s",
        ast.line, ast.col, err_msg))
      table.insert(errors, string.format("Line %d: %s", ast.line, err_msg))
    end
  end

  local success = expanded_count > 0 or #errors == 0
  local error_msg = #errors > 0 and table.concat(errors, "; ") or nil

  debug_log(string.format("Expansion complete: %d expanded, %d errors", expanded_count, #errors))

  return {
    success = success,
    expanded_count = expanded_count,
    error = error_msg,
  }
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

  -- Get connection context
  local connection = BufferConnection.get_connection(bufnr)
  if not connection then
    vim.notify("No database connection found for buffer", vim.log.levels.ERROR)
    return
  end

  -- Expand asterisk using StatementCache context
  local result = ExpandAsterisk.expand_asterisk_in_context(
    bufnr,
    connection,
    cursor_pos,
    nil  -- query_text not needed, will read from buffer
  )

  if not result.success then
    vim.notify(result.error or "Failed to expand asterisk", vim.log.levels.ERROR)
    return
  end

  if not result.replacement_text or result.replacement_text == "" then
    vim.notify("No columns found to expand", vim.log.levels.WARN)
    return
  end

  -- Build new line with replacement
  local new_line = line:sub(1, result.start_col) .. result.replacement_text .. line:sub(result.end_col + 1)

  debug_log(string.format("Replacing '%s' with '%s'",
    line:sub(result.start_col + 1, result.end_col),
    result.replacement_text))

  -- Set modified line in buffer
  vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})

  -- Move cursor to end of replacement
  local new_col = result.start_col + #result.replacement_text
  vim.api.nvim_win_set_cursor(0, {line_num, new_col})

  -- Notify user
  local col_count = #result.columns
  vim.notify(string.format("Expanded to %d column(s)", col_count), vim.log.levels.INFO)

  debug_log(string.format("Expansion complete: %d columns", col_count))
end

return ExpandAsterisk

