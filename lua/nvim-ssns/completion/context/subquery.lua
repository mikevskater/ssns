---Subquery detection and table extraction for SQL completion
---Handles unparsed subqueries within WHERE/HAVING clauses
---@module ssns.completion.context.subquery
local Subquery = {}

local TokenContext = require('nvim-ssns.completion.token_context')

---Detect if cursor is inside an unparsed subquery (SELECT inside parentheses in WHERE/HAVING)
---Also extracts the subquery's FROM clause tables when detected
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return boolean is_in_unparsed_subquery True if we're inside a subquery that wasn't parsed
---@return table[]? subquery_tables Array of table references from the subquery's FROM clause
function Subquery.detect_unparsed(tokens, line, col)
  -- Walk backwards from cursor looking for pattern: ( SELECT
  -- If we find this pattern with unclosed parens, we're in an unparsed subquery
  local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line, col, 100)
  if not prev_tokens or #prev_tokens == 0 then
    return false, nil
  end

  -- When walking backwards from cursor INSIDE a subquery like "(SELECT |cursor| FROM ...)":
  -- - The closing ) is AFTER cursor, so we haven't seen it yet
  -- - We look for pattern: SELECT followed by ( (in reverse walk order)
  -- - This handles both:
  --   - Cursor AFTER FROM: "(SELECT ... FROM ... |cursor|)" - we see FROM, then SELECT, then (
  --   - Cursor BEFORE FROM: "(SELECT |cursor| FROM ...)" - we see SELECT, then (
  --
  -- Track: ) increments paren_depth (entering closed group)
  --        ( decrements paren_depth (exiting group, or entering unclosed if goes negative)
  local paren_depth = 0
  local found_select = false
  local found_from_before_select = false
  local subquery_detected = false

  for i, t in ipairs(prev_tokens) do
    if t.type == "paren_close" then
      paren_depth = paren_depth + 1
    elseif t.type == "paren_open" then
      paren_depth = paren_depth - 1
      -- If paren_depth goes negative AND we've seen SELECT, we're in a subquery
      -- BUT skip if this ( is preceded by an identifier (function call) or AS keyword (CTE definition)
      if paren_depth <= 0 and found_select then
        -- Check what precedes this ( - look at NEXT token in walk (= token BEFORE ( in query)
        local next_token = prev_tokens[i + 1]
        local is_function_or_cte = next_token and
          (next_token.type == "identifier" or
           (next_token.type == "keyword" and next_token.text:upper() == "AS"))
        if not is_function_or_cte then
          subquery_detected = true
          break
        end
      end
    elseif t.type == "keyword" then
      local kw = t.text:upper()
      if kw == "SELECT" and paren_depth == 0 then
        -- Found SELECT at current paren level
        found_select = true
      elseif kw == "FROM" and found_select then
        -- Found FROM after SELECT (in reverse order = before SELECT in query order)
        found_from_before_select = true
      elseif (kw == "INSERT" or kw == "UPDATE" or kw == "DELETE" or kw == "MERGE") and paren_depth >= 0 then
        -- Hit a statement starter outside our subquery context - stop searching
        break
      elseif kw == "WITH" then
        -- Hit WITH keyword - don't cross into CTE definitions
        break
      end
    end
  end

  if not subquery_detected then
    return false, nil
  end

  -- We're in an unparsed subquery - now extract its tables
  local subquery_tables = Subquery.extract_tables(tokens, line, col)

  return true, subquery_tables
end

---Extract table references by walking backwards from cursor
---Finds FROM clause tables when cursor is in WHERE/HAVING of subquery
---@param tokens Token[] Parsed tokens
---@param cursor_idx number Token index at cursor position
---@return table[]? tables Array of table references
function Subquery.extract_tables_backward(tokens, cursor_idx)
  local tables = {}

  -- Walk backwards from cursor looking for FROM ... table pattern
  -- Stop at ( which marks the start of subquery, or SELECT which starts the subquery
  local paren_depth = 0
  local found_from = false
  local after_from_tokens = {}

  for i = cursor_idx - 1, 1, -1 do
    local t = tokens[i]

    if t.type == "paren_close" then
      paren_depth = paren_depth + 1
    elseif t.type == "paren_open" then
      if paren_depth == 0 then
        -- Hit the opening paren of our subquery - stop
        break
      end
      paren_depth = paren_depth - 1
    elseif paren_depth == 0 then
      if t.type == "keyword" then
        local kw = t.text:upper()
        if kw == "FROM" then
          found_from = true
          break
        elseif kw == "SELECT" then
          -- Hit SELECT without finding FROM - no tables yet
          break
        elseif kw == "WHERE" or kw == "GROUP" or kw == "HAVING" or kw == "ORDER" then
          -- These come after FROM, continue backwards
        elseif kw == "ON" or kw == "JOIN" or kw == "INNER" or kw == "LEFT" or kw == "RIGHT" or kw == "FULL" or kw == "CROSS" or kw == "OUTER" then
          -- Part of FROM clause, continue backwards
        end
      end
      -- Collect tokens between cursor and FROM
      table.insert(after_from_tokens, 1, t)
    end
  end

  if not found_from then
    return nil
  end

  -- Now parse the collected tokens to extract table references
  -- Format: table1 alias1, table2 alias2 JOIN table3 alias3 ON ... WHERE
  local i = 1
  while i <= #after_from_tokens do
    local t = after_from_tokens[i]

    if t.type == "keyword" then
      local kw = t.text:upper()
      if kw == "WHERE" or kw == "GROUP" or kw == "HAVING" or kw == "ORDER" then
        -- End of table references
        break
      elseif kw == "ON" then
        -- Skip ON clause
        i = i + 1
        while i <= #after_from_tokens do
          local on_t = after_from_tokens[i]
          if on_t.type == "keyword" then
            local on_kw = on_t.text:upper()
            if on_kw == "JOIN" or on_kw == "INNER" or on_kw == "LEFT" or on_kw == "RIGHT" or on_kw == "FULL" or on_kw == "CROSS" or on_kw == "WHERE" or on_kw == "GROUP" then
              break
            end
          end
          i = i + 1
        end
      else
        i = i + 1
      end
    elseif t.type == "identifier" or t.type == "bracket_id" then
      -- Found a table name
      local table_name = t.text
      local schema = nil
      local alias = nil
      local skip_count = 1

      -- Check for schema.table pattern
      if i + 1 <= #after_from_tokens and after_from_tokens[i + 1].type == "dot" then
        if i + 2 <= #after_from_tokens then
          local name_t = after_from_tokens[i + 2]
          if name_t.type == "identifier" or name_t.type == "bracket_id" then
            schema = table_name
            table_name = name_t.text
            skip_count = 3
          end
        end
      end

      -- Check for alias
      local alias_idx = i + skip_count
      if alias_idx <= #after_from_tokens then
        local alias_t = after_from_tokens[alias_idx]
        if alias_t.type == "keyword" and alias_t.text:upper() == "AS" then
          if alias_idx + 1 <= #after_from_tokens then
            local actual_alias = after_from_tokens[alias_idx + 1]
            if actual_alias.type == "identifier" or actual_alias.type == "bracket_id" then
              alias = actual_alias.text
              skip_count = skip_count + 2
            end
          end
        elseif alias_t.type == "identifier" or alias_t.type == "bracket_id" then
          alias = alias_t.text
          skip_count = skip_count + 1
        end
      end

      -- Clean up bracket identifiers
      table_name = table_name:gsub("^%[", ""):gsub("%]$", "")
      if schema then schema = schema:gsub("^%[", ""):gsub("%]$", "") end
      if alias then alias = alias:gsub("^%[", ""):gsub("%]$", "") end

      local full_name = schema and (schema .. "." .. table_name) or table_name

      table.insert(tables, {
        table = full_name,
        name = table_name,
        schema = schema,
        alias = alias or table_name,
      })

      i = i + skip_count
    else
      i = i + 1
    end
  end

  return #tables > 0 and tables or nil
end

---Find the boundaries of the subquery containing the cursor in the token stream
---Walks backward to find `( SELECT` and forward to find matching `)`
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return number? start_idx Token index of the SELECT keyword (inclusive)
---@return number? end_idx Token index of the closing paren (exclusive - the token before `)`)
function Subquery._find_subquery_bounds(tokens, line, col)
  -- Find cursor position in token stream
  local cursor_idx = nil
  for i, t in ipairs(tokens) do
    if t.line > line or (t.line == line and t.col >= col) then
      cursor_idx = i
      break
    end
  end
  if not cursor_idx then
    cursor_idx = #tokens + 1
  end

  -- Walk backwards to find ( SELECT pattern
  local select_idx = nil
  local paren_depth = 0
  for i = cursor_idx - 1, 1, -1 do
    local t = tokens[i]
    if t.type == "paren_close" then
      paren_depth = paren_depth + 1
    elseif t.type == "paren_open" then
      if paren_depth == 0 then
        -- This is the opening paren of our subquery
        -- Check if next token is SELECT
        if i + 1 <= #tokens and tokens[i + 1].type == "keyword" and tokens[i + 1].text:upper() == "SELECT" then
          select_idx = i + 1
        end
        break
      end
      paren_depth = paren_depth - 1
    end
  end

  if not select_idx then return nil, nil end

  -- Walk forward from cursor to find matching )
  local end_idx = nil
  paren_depth = 0
  for i = cursor_idx, #tokens do
    local t = tokens[i]
    if t.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif t.type == "paren_close" then
      if paren_depth == 0 then
        end_idx = i - 1
        break
      end
      paren_depth = paren_depth - 1
    end
  end

  if not end_idx then
    -- No closing paren found — use last token
    end_idx = #tokens
  end

  return select_idx, end_idx
end

---Extract table references from a subquery using the full StatementParser
---Finds the subquery boundaries and parses the extracted text for complete table extraction
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return table[]? tables Array of table references
function Subquery.extract_tables(tokens, line, col)
  local start_idx, end_idx = Subquery._find_subquery_bounds(tokens, line, col)
  if not start_idx or not end_idx or end_idx < start_idx then
    return nil
  end

  -- Extract subquery text from tokens
  local parts = {}
  for i = start_idx, end_idx do
    parts[#parts + 1] = tokens[i].text
  end
  local subquery_text = table.concat(parts, " ")

  -- Parse using full StatementParser for complete table extraction
  local StatementParser = require('nvim-ssns.completion.statement_parser')
  local chunks = StatementParser.parse(subquery_text)

  if chunks and #chunks > 0 then
    local chunk = chunks[1]
    local tables = {}
    for _, t in ipairs(chunk.tables or {}) do
      local full_name = t.name
      if t.schema then full_name = t.schema .. "." .. t.name end
      if t.database then full_name = t.database .. "." .. full_name end
      table.insert(tables, {
        table = full_name,
        name = t.name,
        schema = t.schema,
        alias = t.alias or t.name,
      })
    end
    return #tables > 0 and tables or nil
  end

  return nil
end

return Subquery
