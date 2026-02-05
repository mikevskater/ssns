---Schema qualification module for SSNS
---Adds schema prefixes to unqualified table names using database metadata
---Used by formatter when from_schema_qualify = "always"
---@class SchemaQualify
local SchemaQualify = {}

local Resolver = require('nvim-ssns.completion.metadata.resolver')
local StatementCache = require('nvim-ssns.completion.statement_cache')
local BufferConnection = require('nvim-ssns.utils.buffer_connection')
local Debug = require('nvim-ssns.debug')

-- Helper: Conditional debug logging based on config
local function debug_log(message)
  local Config = require('nvim-ssns.config')
  local config = Config.get()
  if config.completion and config.completion.debug then
    Debug.log("[SCHEMA_QUALIFY] " .. message)
  end
end

-- Keywords that indicate we're in a table reference context
local TABLE_CONTEXT_KEYWORDS = {
  FROM = true,
  JOIN = true,
  INTO = true,
  UPDATE = true,
  TABLE = true,
  MERGE = true,
  USING = true,
}

-- Keywords that end a table reference context
local TABLE_CONTEXT_END_KEYWORDS = {
  WHERE = true,
  SET = true,
  ON = true,
  VALUES = true,
  SELECT = true,
  ORDER = true,
  GROUP = true,
  HAVING = true,
  UNION = true,
  EXCEPT = true,
  INTERSECT = true,
  OUTPUT = true,
}

---Find all unqualified table references in a buffer range
---@param bufnr number Buffer number
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return table[] Array of {line: number, col: number, table_name: string, end_col: number}
local function find_unqualified_tables(bufnr, start_line, end_line)
  local tables = {}

  -- Get the statement cache
  local cache = StatementCache.get_or_build_cache(bufnr)
  if not cache or not cache.chunks then
    debug_log("No statement cache available")
    return tables
  end

  -- Find chunks that overlap with our line range
  for _, chunk in ipairs(cache.chunks) do
    -- Check if chunk overlaps with our range
    if chunk.end_line >= start_line and chunk.start_line <= end_line then
      -- Check tables in this chunk
      if chunk.tables then
        for _, tbl in ipairs(chunk.tables) do
          -- Only process tables without schema prefix
          if tbl.name and not tbl.schema then
            -- Skip temp tables (#table, ##table)
            if not tbl.name:match("^#") then
              -- Skip CTEs and subqueries (they don't have real schemas)
              if not tbl.is_cte and not tbl.is_subquery then
                debug_log(string.format("Found unqualified table: %s", tbl.name))
                table.insert(tables, {
                  name = tbl.name,
                  alias = tbl.alias,
                  chunk = chunk,
                })
              end
            end
          end
        end
      end
    end
  end

  return tables
end

---Find table reference positions in buffer text using tokens
---@param bufnr number Buffer number
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@param table_names table<string, string> Map of table_name -> schema to add
---@return table[] Array of {line: number, start_col: number, end_col: number, table_name: string, schema: string}
local function find_table_positions(bufnr, start_line, end_line, table_names)
  local positions = {}

  -- Get the statement cache for tokens
  local cache = StatementCache.get_or_build_cache(bufnr)
  if not cache or not cache.tokens then
    debug_log("No token cache available")
    return positions
  end

  local tokens = cache.tokens
  local in_table_context = false
  local paren_depth = 0

  for i, token in ipairs(tokens) do
    -- Skip tokens outside our line range
    if token.line and (token.line < start_line or token.line > end_line) then
      goto continue
    end

    -- Track parentheses
    if token.type == "paren_open" or token.text == "(" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" or token.text == ")" then
      paren_depth = math.max(0, paren_depth - 1)
    end

    -- Track table context
    if token.type == "keyword" then
      local upper = token.text:upper()
      if TABLE_CONTEXT_KEYWORDS[upper] then
        in_table_context = true
      elseif TABLE_CONTEXT_END_KEYWORDS[upper] and paren_depth == 0 then
        in_table_context = false
      end
    end

    -- Look for identifiers in table context
    if in_table_context and (token.type == "identifier" or token.type == "quoted_identifier") then
      local table_name = token.text
      -- Remove quotes if quoted identifier
      if token.type == "quoted_identifier" then
        table_name = table_name:gsub("^%[", ""):gsub("%]$", "")
      end

      -- Check if this table needs schema qualification
      local schema = table_names[table_name:lower()]
      if schema then
        -- Make sure it's not already qualified (check for preceding dot)
        local prev_idx = i - 1
        while prev_idx >= 1 and tokens[prev_idx].type == "whitespace" do
          prev_idx = prev_idx - 1
        end

        local is_qualified = false
        if prev_idx >= 1 then
          local prev_token = tokens[prev_idx]
          if prev_token.type == "dot" or (prev_token.type == "operator" and prev_token.text == ".") then
            is_qualified = true
          end
        end

        if not is_qualified and token.line and token.col then
          debug_log(string.format("Found unqualified table at line %d col %d: %s -> %s.%s",
            token.line, token.col, table_name, schema, table_name))
          table.insert(positions, {
            line = token.line,
            start_col = token.col,
            end_col = token.col + #token.text - 1,
            table_name = table_name,
            original_text = token.text,
            schema = schema,
          })
        end
      end
    end

    -- Reset context after comma (multiple tables in FROM)
    if token.type == "comma" or token.text == "," then
      -- Stay in table context after comma in FROM clause
    end

    ::continue::
  end

  return positions
end

---Look up schema for a table using the Resolver
---@param table_name string Table name to look up
---@param connection table Connection context
---@return string? schema The schema name or nil if not found
local function lookup_table_schema(table_name, connection)
  if not connection or not connection.database then
    return nil
  end

  -- Try to resolve the table
  local success, table_obj = pcall(function()
    return Resolver.resolve_table(table_name, connection, {})
  end)

  if success and table_obj then
    -- Get schema from the resolved table object
    local schema = table_obj.schema or table_obj.schema_name
    if schema then
      debug_log(string.format("Resolved table '%s' to schema '%s'", table_name, schema))
      return schema
    end
  end

  debug_log(string.format("Could not resolve schema for table '%s'", table_name))
  return nil
end

---Qualify all unqualified tables in a buffer range
---Used by formatter when from_schema_qualify = "always"
---@param bufnr number Buffer number
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return table result {success: boolean, qualified_count: number, error: string?}
function SchemaQualify.qualify_tables_in_range(bufnr, start_line, end_line)
  debug_log(string.format("qualify_tables_in_range: bufnr=%d, lines %d-%d", bufnr, start_line, end_line))

  -- Get connection context
  local connection = BufferConnection.get_connection(bufnr)
  if not connection then
    return {
      success = false,
      qualified_count = 0,
      error = "No database connection available"
    }
  end

  -- Find all unqualified tables from statement cache
  local unqualified_tables = find_unqualified_tables(bufnr, start_line, end_line)

  if #unqualified_tables == 0 then
    debug_log("No unqualified tables found in range")
    return {
      success = true,
      qualified_count = 0,
    }
  end

  debug_log(string.format("Found %d unqualified tables", #unqualified_tables))

  -- Look up schemas for each table
  local table_schemas = {}  -- table_name (lowercase) -> schema
  for _, tbl in ipairs(unqualified_tables) do
    local name_lower = tbl.name:lower()
    if not table_schemas[name_lower] then
      local schema = lookup_table_schema(tbl.name, connection)
      if schema then
        table_schemas[name_lower] = schema
      end
    end
  end

  -- If no schemas found, nothing to do
  local schema_count = 0
  for _ in pairs(table_schemas) do
    schema_count = schema_count + 1
  end

  if schema_count == 0 then
    debug_log("No schemas found for any tables")
    return {
      success = true,
      qualified_count = 0,
    }
  end

  debug_log(string.format("Found schemas for %d tables", schema_count))

  -- Find actual positions in buffer using tokens
  local positions = find_table_positions(bufnr, start_line, end_line, table_schemas)

  if #positions == 0 then
    debug_log("No table positions found to qualify")
    return {
      success = true,
      qualified_count = 0,
    }
  end

  -- Sort by line (descending), then by column (descending)
  -- This ensures we process from end to start, preserving positions
  table.sort(positions, function(a, b)
    if a.line ~= b.line then
      return a.line > b.line
    end
    return a.start_col > b.start_col
  end)

  -- Apply schema prefixes
  local qualified_count = 0

  for _, pos in ipairs(positions) do
    -- Get current line
    local line = vim.api.nvim_buf_get_lines(bufnr, pos.line - 1, pos.line, false)[1]
    if line then
      -- Build replacement: schema.table_name
      local replacement = pos.schema .. "." .. pos.original_text

      -- Build new line with replacement
      local new_line = line:sub(1, pos.start_col - 1) .. replacement .. line:sub(pos.end_col + 1)
      vim.api.nvim_buf_set_lines(bufnr, pos.line - 1, pos.line, false, { new_line })
      qualified_count = qualified_count + 1

      debug_log(string.format("Qualified table at line %d: %s -> %s",
        pos.line, pos.original_text, replacement))
    end
  end

  debug_log(string.format("Qualification complete: %d tables qualified", qualified_count))

  return {
    success = true,
    qualified_count = qualified_count,
  }
end

return SchemaQualify

