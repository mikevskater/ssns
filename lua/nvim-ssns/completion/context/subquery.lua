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
  local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line, col, 50)
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

---Extract table references from a subquery's FROM clause
---Looks both backwards and forwards from cursor position to find FROM tablename pattern
---Handles multiple tables (JOINs, commas) within the subquery
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return table[]? tables Array of table references
function Subquery.extract_tables(tokens, line, col)
  local tables = {}

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

  -- First, try walking BACKWARDS from cursor to find FROM clause that's already parsed
  -- This handles cases like: SELECT ... FROM Table WHERE |cursor|
  local backward_tables = Subquery.extract_tables_backward(tokens, cursor_idx)
  if backward_tables and #backward_tables > 0 then
    return backward_tables
  end

  -- If not found backwards, walk forward from cursor looking for "FROM tablename"
  -- This handles cases like: SELECT |cursor| FROM Table
  local in_from_clause = false
  local paren_depth = 0
  local i = cursor_idx

  while i <= #tokens do
    local t = tokens[i]

    -- Track parentheses to stay within the subquery
    if t.type == "paren_open" then
      paren_depth = paren_depth + 1
      i = i + 1
    elseif t.type == "paren_close" then
      if paren_depth == 0 then
        -- Hit the closing paren of our subquery - stop
        break
      end
      paren_depth = paren_depth - 1
      i = i + 1
    elseif t.type == "keyword" then
      local kw = t.text:upper()
      if kw == "FROM" and paren_depth == 0 then
        in_from_clause = true
        i = i + 1
      elseif in_from_clause and paren_depth == 0 and (kw == "WHERE" or kw == "GROUP" or kw == "HAVING" or kw == "ORDER" or kw == "UNION") then
        -- Hit end of FROM clause
        break
      elseif in_from_clause and paren_depth == 0 and (kw == "JOIN" or kw == "INNER" or kw == "LEFT" or kw == "RIGHT" or kw == "FULL" or kw == "CROSS" or kw == "OUTER") then
        -- JOIN keyword - continue parsing for more tables
        i = i + 1
      elseif in_from_clause and paren_depth == 0 and kw == "ON" then
        -- Skip ON clause until we hit another JOIN or end of FROM
        i = i + 1
        while i <= #tokens do
          local on_t = tokens[i]
          if on_t.type == "paren_close" and paren_depth == 0 then
            break
          elseif on_t.type == "paren_open" then
            paren_depth = paren_depth + 1
          elseif on_t.type == "paren_close" then
            paren_depth = paren_depth - 1
          elseif on_t.type == "keyword" then
            local on_kw = on_t.text:upper()
            if on_kw == "JOIN" or on_kw == "INNER" or on_kw == "LEFT" or on_kw == "RIGHT" or on_kw == "FULL" or on_kw == "CROSS" or on_kw == "WHERE" or on_kw == "GROUP" or on_kw == "HAVING" or on_kw == "ORDER" then
              break
            end
          end
          i = i + 1
        end
      else
        i = i + 1
      end
    elseif in_from_clause and paren_depth == 0 then
      -- After FROM, look for table name
      if t.type == "identifier" or t.type == "bracket_id" then
        -- Build qualified name
        local table_name = t.text
        local schema = nil
        local alias = nil
        local skip_count = 1

        -- Check for schema.table or db.schema.table pattern
        local next_t = tokens[i + 1]
        if next_t and next_t.type == "dot" then
          local name_t = tokens[i + 2]
          if name_t and (name_t.type == "identifier" or name_t.type == "bracket_id") then
            -- Check if there's another dot (db.schema.table)
            local next_next_t = tokens[i + 3]
            if next_next_t and next_next_t.type == "dot" then
              local final_name_t = tokens[i + 4]
              if final_name_t and (final_name_t.type == "identifier" or final_name_t.type == "bracket_id") then
                -- db.schema.table
                schema = name_t.text
                table_name = final_name_t.text
                skip_count = 5
              end
            else
              -- schema.table
              schema = table_name
              table_name = name_t.text
              skip_count = 3
            end
          end
        end

        -- Check for alias after table name
        local alias_idx = i + skip_count
        local alias_t = tokens[alias_idx]
        if alias_t then
          if alias_t.type == "keyword" and alias_t.text:upper() == "AS" then
            -- Explicit AS alias
            local actual_alias_t = tokens[alias_idx + 1]
            if actual_alias_t and (actual_alias_t.type == "identifier" or actual_alias_t.type == "bracket_id") then
              alias = actual_alias_t.text
              skip_count = skip_count + 2
            end
          elseif alias_t.type == "identifier" or alias_t.type == "bracket_id" then
            -- Implicit alias (no AS keyword)
            alias = alias_t.text
            skip_count = skip_count + 1
          end
        end

        -- Clean up bracket identifiers
        table_name = table_name:gsub("^%[", ""):gsub("%]$", "")
        if schema then
          schema = schema:gsub("^%[", ""):gsub("%]$", "")
        end
        if alias then
          alias = alias:gsub("^%[", ""):gsub("%]$", "")
        end

        -- Build full table reference
        local full_name = table_name
        if schema then
          full_name = schema .. "." .. table_name
        end

        table.insert(tables, {
          table = full_name,
          name = table_name,
          schema = schema,
          alias = alias or table_name,
        })

        i = i + skip_count
      elseif t.type == "comma" then
        -- Multiple tables with comma
        i = i + 1
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end

  return #tables > 0 and tables or nil
end

return Subquery
