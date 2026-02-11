---Column context detection
---Detects COLUMN completion contexts (SELECT, WHERE, ON, SET, VALUES, INSERT columns, etc.)
---@module ssns.completion.context.column_context
local ColumnContext = {}

local Tokens = require('nvim-ssns.completion.tokens')
local QualifiedNames = require('nvim-ssns.completion.context.common.qualified_names')

---Detect COLUMN context from tokens
---Replaces regex patterns for SELECT, WHERE, ON, SET, OUTPUT, ORDER BY, GROUP BY, HAVING
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("column" or nil if not column context)
---@return string? mode Sub-mode for provider routing (select, where, on, set, etc.)
---@return table extra Extra context info (table_ref, left_side, etc.)
function ColumnContext.detect(tokens, line, col)
  local prev_tokens = Tokens.get_tokens_before_cursor(tokens, line, col, 15)
  if #prev_tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- First check for qualified column reference (alias.column pattern)
  local is_after_dot, qualified = QualifiedNames.is_dot_triggered(tokens, line, col)
  -- Use qualified info for filtering when available (even when typing partial identifier)
  if qualified then
    -- Check if this is a table qualifier (for column completion)
    -- vs a schema qualifier (for table completion) - handled by TABLE detection
    local ref = QualifiedNames.get_reference_before_dot(tokens, line, col)
    if ref then
      extra.table_ref = ref
      extra.filter_table = ref
      extra.omit_table = is_after_dot  -- Only omit table if cursor is directly after dot
      return "column", "qualified", extra
    end
  end

  -- Find the most recent keywords in the token stream (paren-depth aware)
  -- Only consider keywords at the same paren depth as cursor (depth 0)
  local keyword_token = nil
  local keyword_idx = nil
  local second_keyword_token = nil

  local paren_depth = 0
  for i, t in ipairs(prev_tokens) do
    if t.type == "paren_close" then
      paren_depth = paren_depth + 1
    elseif t.type == "paren_open" then
      paren_depth = paren_depth - 1
    end
    -- Only consider keywords at same paren depth as cursor
    if t.type == "keyword" and paren_depth == 0 then
      if not keyword_token then
        keyword_token = t
        keyword_idx = i
      elseif not second_keyword_token then
        second_keyword_token = t
        break
      end
    end
  end

  if not keyword_token then
    return nil, nil, extra
  end

  local kw = keyword_token.text:upper()
  local second_kw = second_keyword_token and second_keyword_token.text:upper() or nil

  -- SELECT detection (check that there's no FROM after SELECT)
  if kw == "SELECT" then
    -- Check if there's a FROM keyword between SELECT and cursor
    for i = keyword_idx - 1, 1, -1 do
      local t = prev_tokens[i]
      if t.type == "keyword" and t.text:upper() == "FROM" then
        -- There's a FROM, so we're not in SELECT clause
        break
      end
    end
    return "column", "select", extra
  end

  -- Subquery SELECT detection: (SELECT ...
  -- Look for paren_open before SELECT
  if kw == "SELECT" then
    -- Check for opening paren indicating subquery
    for i = keyword_idx + 1, #prev_tokens do
      local t = prev_tokens[i]
      if t.type == "paren_open" then
        -- This is a subquery SELECT
        return "column", "select", extra
      elseif t.type == "keyword" then
        break
      end
    end
  end

  -- WHERE detection
  if kw == "WHERE" then
    -- Check for left-side of comparison (type-aware completion)
    local left_side = QualifiedNames.extract_left_side_column(tokens, line, col)
    if left_side then
      extra.left_side = left_side
    end
    return "column", "where", extra
  end

  -- AND/OR detection — walk further back to find enclosing clause keyword
  if kw == "AND" or kw == "OR" then
    local walk_paren_depth = 0
    for j = keyword_idx + 1, #prev_tokens do
      local pt = prev_tokens[j]
      if pt.type == "paren_close" then
        walk_paren_depth = walk_paren_depth + 1
      elseif pt.type == "paren_open" then
        walk_paren_depth = walk_paren_depth - 1
      elseif pt.type == "keyword" and walk_paren_depth == 0 then
        local pk = pt.text:upper()
        if pk == "WHERE" then
          return "column", "where", extra
        elseif pk == "ON" then
          local left_side = QualifiedNames.extract_left_side_column(tokens, line, col)
          if left_side then extra.left_side = left_side end
          return "column", "on", extra
        elseif pk == "HAVING" then
          return "column", "having", extra
        elseif pk == "WHEN" or pk == "CASE" then
          return "column", "case_expression", extra
        elseif pk == "BETWEEN" then
          return "column", "where", extra
        elseif pk == "SELECT" or pk == "FROM" or pk == "SET" then
          break
        end
      end
    end
    return "column", "where", extra  -- default fallback
  end

  -- ON detection (JOIN condition)
  if kw == "ON" then
    local left_side = QualifiedNames.extract_left_side_column(tokens, line, col)
    if left_side then
      extra.left_side = left_side
    end
    return "column", "on", extra
  end

  -- SET detection (UPDATE SET clause)
  if kw == "SET" then
    return "column", "set", extra
  end

  -- ORDER BY detection
  if kw == "BY" and second_kw == "ORDER" then
    return "column", "order_by", extra
  end

  -- GROUP BY detection
  if kw == "BY" and second_kw == "GROUP" then
    return "column", "group_by", extra
  end

  -- HAVING detection
  if kw == "HAVING" then
    return "column", "having", extra
  end

  -- CASE/WHEN/THEN/ELSE detection (column-context within CASE expressions)
  if kw == "CASE" or kw == "WHEN" or kw == "THEN" or kw == "ELSE" then
    return "column", "case_expression", extra
  end

  -- OUTPUT detection
  if kw == "OUTPUT" then
    extra.is_output_clause = true
    return "column", "output", extra
  end

  -- Check for OUTPUT inserted./deleted. pattern
  if kw == "INSERTED" or kw == "DELETED" then
    -- Check if previous keyword is OUTPUT (or if there's OUTPUT before)
    for i = keyword_idx + 1, #prev_tokens do
      local t = prev_tokens[i]
      if t.type == "keyword" and t.text:upper() == "OUTPUT" then
        extra.is_output_clause = true
        extra.output_pseudo_table = kw:lower()
        extra.table_ref = kw:lower()
        return "column", "output", extra
      end
    end
  end

  return nil, nil, extra
end

---Detect VALUES clause context from tokens
---Handles patterns like: VALUES (val1, |val2) with position tracking for type-aware completion
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("column" or nil if not in VALUES)
---@return string? mode Sub-mode for provider routing ("values" or nil)
---@return table extra Extra context info (value_position for column position)
function ColumnContext.detect_values(tokens, line, col)
  if not tokens or #tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- We need to find the pattern: VALUES ( ... cursor ... )
  -- Walk through tokens to find VALUES keyword, then track parens and commas

  -- Find cursor position in token stream
  local _, cursor_idx = Tokens.get_token_at_position(tokens, line, col)
  if not cursor_idx then
    -- Cursor might be after last token, try to find nearby tokens
    cursor_idx = #tokens
  end

  -- Look backwards for VALUES keyword
  local values_idx = nil
  for i = cursor_idx, 1, -1 do
    local t = tokens[i]
    if t.type == "keyword" and t.text:upper() == "VALUES" then
      values_idx = i
      break
    end
    -- Stop if we hit SELECT/INSERT/UPDATE/DELETE (past the VALUES clause)
    if t.type == "keyword" then
      local kw = t.text:upper()
      if kw == "SELECT" or kw == "INSERT" or kw == "UPDATE" or kw == "DELETE" or kw == "MERGE" then
        break
      end
    end
  end

  if not values_idx then
    return nil, nil, {}
  end

  -- Now verify cursor is inside a VALUES paren group
  -- Track paren depth from VALUES to cursor
  local paren_depth = 0
  local value_position = 0
  local found_values_paren = false
  local in_current_row = false

  for i = values_idx + 1, #tokens do
    local t = tokens[i]

    -- Check if we've passed the cursor position
    if t.line > line or (t.line == line and t.col >= col) then
      -- Cursor is before this token
      if in_current_row then
        extra.value_position = value_position
        -- Check for qualified column reference (e.g., source.█ in VALUES)
        local is_after_dot, _ = QualifiedNames.is_dot_triggered(tokens, line, col)
        if is_after_dot then
          local ref = QualifiedNames.get_reference_before_dot(tokens, line, col)
          if ref then
            extra.table_ref = ref
            extra.filter_table = ref
            extra.omit_table = true
            return "column", "qualified", extra
          end
        end
        return "column", "values", extra
      end
      break
    end

    if t.type == "paren_open" then
      paren_depth = paren_depth + 1
      if paren_depth == 1 then
        found_values_paren = true
        in_current_row = true
        value_position = 0  -- Reset for new row (multi-row VALUES)
      end
    elseif t.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth == 0 then
        in_current_row = false
      end
    elseif t.type == "comma" and paren_depth == 1 then
      -- Comma at depth 1 = separator between values in row
      value_position = value_position + 1
    end
  end

  -- If we're still inside VALUES parens at cursor position
  if found_values_paren and in_current_row then
    extra.value_position = value_position
    -- Check for qualified column reference (e.g., source.█ in VALUES)
    local is_after_dot, _ = QualifiedNames.is_dot_triggered(tokens, line, col)
    if is_after_dot then
      local ref = QualifiedNames.get_reference_before_dot(tokens, line, col)
      if ref then
        extra.table_ref = ref
        extra.filter_table = ref
        extra.omit_table = true
        return "column", "qualified", extra
      end
    end
    return "column", "values", extra
  end

  return nil, nil, {}
end

---Detect INSERT column list context from tokens
---Handles patterns like: INSERT INTO table (col1, |col2) for column completion
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("column" or nil if not in INSERT column list)
---@return string? mode Sub-mode for provider routing ("insert_columns" or nil)
---@return table extra Extra context info (insert_table, insert_schema)
function ColumnContext.detect_insert_columns(tokens, line, col)
  if not tokens or #tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- We need to find: INSERT INTO table_name ( ... cursor ... ) VALUES
  -- The column list is between the first ( after table name and VALUES keyword

  -- Find cursor position in token stream
  local _, cursor_idx = Tokens.get_token_at_position(tokens, line, col)
  if not cursor_idx then
    cursor_idx = #tokens
  end

  -- Look backwards for INSERT keyword
  local insert_idx = nil
  local into_idx = nil
  local table_tokens = {}
  local paren_open_idx = nil

  for i = cursor_idx, 1, -1 do
    local t = tokens[i]
    if t.type == "keyword" then
      local kw = t.text:upper()
      if kw == "VALUES" then
        -- VALUES keyword found - we might be in column list before it
        -- Don't break, continue looking for INSERT
      elseif kw == "INTO" and not into_idx then
        into_idx = i
      elseif kw == "INSERT" and into_idx then
        insert_idx = i
        break
      elseif kw == "SELECT" or kw == "UPDATE" or kw == "DELETE" or kw == "MERGE" then
        -- Different statement type
        break
      end
    end
  end

  if not insert_idx or not into_idx then
    return nil, nil, {}
  end

  -- Now collect table name tokens after INTO
  -- Pattern: INTO [identifier] [dot identifier]* [paren_open]
  local i = into_idx + 1
  while i <= #tokens do
    local t = tokens[i]
    if t.type == "identifier" or t.type == "bracket_id" then
      table.insert(table_tokens, t)
      i = i + 1
    elseif t.type == "dot" then
      -- Part of qualified name
      i = i + 1
    elseif t.type == "paren_open" then
      paren_open_idx = i
      break
    elseif t.type == "keyword" then
      -- Unexpected keyword - no column list paren
      break
    else
      i = i + 1
    end
  end

  if not paren_open_idx or #table_tokens == 0 then
    return nil, nil, {}
  end

  -- Check if cursor is between paren_open and VALUES (or paren_close)
  -- Find the matching paren_close or VALUES keyword after paren_open
  local paren_close_idx = nil
  local values_idx = nil
  local paren_depth = 1

  for j = paren_open_idx + 1, #tokens do
    local t = tokens[j]
    if t.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif t.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth == 0 then
        paren_close_idx = j
        break
      end
    elseif t.type == "keyword" and t.text:upper() == "VALUES" then
      values_idx = j
      break
    end
  end

  -- Check if cursor is within the column list
  local paren_open_token = tokens[paren_open_idx]
  local cursor_after_paren_open = line > paren_open_token.line or
    (line == paren_open_token.line and col > paren_open_token.col)

  local cursor_before_end = true
  if paren_close_idx then
    local paren_close_token = tokens[paren_close_idx]
    cursor_before_end = line < paren_close_token.line or
      (line == paren_close_token.line and col <= paren_close_token.col)
  elseif values_idx then
    local values_token = tokens[values_idx]
    cursor_before_end = line < values_token.line or
      (line == values_token.line and col < values_token.col)
  end

  if cursor_after_paren_open and cursor_before_end then
    -- We're in the INSERT column list! Extract table info
    local parts = {}
    for _, t in ipairs(table_tokens) do
      local name = t.text
      if t.type == "bracket_id" then
        name = name:sub(2, -2)  -- Remove [ and ]
      end
      table.insert(parts, name)
    end

    if #parts >= 2 then
      extra.insert_schema = parts[#parts - 1]
      extra.insert_table = parts[#parts]
      extra.schema = extra.insert_schema
      extra.table = extra.insert_table
    elseif #parts == 1 then
      extra.insert_table = parts[1]
      extra.table = extra.insert_table
    end

    return "column", "insert_columns", extra
  end

  return nil, nil, {}
end

---Detect MERGE INSERT column list context from tokens
---Handles patterns like: WHEN NOT MATCHED THEN INSERT (col1, |col2)
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("column" or nil if not in MERGE INSERT)
---@return string? mode Sub-mode for provider routing ("merge_insert_columns" or nil)
---@return table extra Extra context info (is_merge_insert flag)
function ColumnContext.detect_merge_insert(tokens, line, col)
  if not tokens or #tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- Pattern: WHEN NOT MATCHED THEN INSERT ( ... cursor ... )
  -- Find cursor position
  local _, cursor_idx = Tokens.get_token_at_position(tokens, line, col)
  if not cursor_idx then
    cursor_idx = #tokens
  end

  -- Look backwards for pattern: WHEN NOT MATCHED THEN INSERT (
  local found_paren_open = false
  local found_insert = false
  local found_then = false
  local found_matched = false
  local found_not = false
  local found_when = false
  local paren_open_idx = nil

  -- Track paren depth to handle nested structures like USING (SELECT ...)
  -- We're looking for: WHEN NOT MATCHED THEN INSERT ( ... cursor ... )
  -- The paren_close check should only apply to the INSERT's column list paren,
  -- not to parens from earlier clauses like USING (subquery)
  local paren_depth = 0  -- Track balance of parens AFTER our INSERT paren

  for i = cursor_idx, 1, -1 do
    local t = tokens[i]
    if t.type == "paren_open" then
      if not found_paren_open then
        -- This is the INSERT's opening paren
        found_paren_open = true
        paren_open_idx = i
      else
        -- This is a nested paren (e.g., from USING subquery) - adjust depth
        paren_depth = paren_depth - 1
      end
    elseif t.type == "paren_close" then
      if found_paren_open then
        -- We're inside our INSERT paren context
        paren_depth = paren_depth + 1
      end
    elseif t.type == "keyword" then
      local kw = t.text:upper()
      -- Only process keywords when we're at the same paren depth (not inside nested parens)
      if paren_depth == 0 then
        if kw == "INSERT" and found_paren_open and not found_insert then
          found_insert = true
        elseif kw == "THEN" and found_insert and not found_then then
          found_then = true
        elseif kw == "MATCHED" and found_then and not found_matched then
          found_matched = true
        elseif kw == "NOT" and found_matched and not found_not then
          found_not = true
        elseif kw == "WHEN" and found_not and not found_when then
          found_when = true
          break
        elseif kw == "MERGE" then
          -- Found MERGE before completing the pattern - stop
          break
        elseif kw == "VALUES" then
          -- We've hit VALUES - we're past the column list
          return nil, nil, {}
        end
      end
    end
  end

  if found_when and found_not and found_matched and found_then and found_insert and paren_open_idx then
    -- Verify cursor is after the paren_open
    local paren_open_token = tokens[paren_open_idx]
    if line > paren_open_token.line or (line == paren_open_token.line and col > paren_open_token.col) then
      extra.is_merge_insert = true
      return "column", "merge_insert_columns", extra
    end
  end

  return nil, nil, {}
end

---Detect ON clause context from tokens (for JOIN conditions)
---Handles patterns like: ON alias.col = |, ON col = other AND |
---More precise than general COLUMN detection for ON-specific features
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("column" or nil if not in ON clause)
---@return string? mode Sub-mode ("on" or "qualified")
---@return table extra Extra context info (table_ref, left_side)
function ColumnContext.detect_on_clause(tokens, line, col)
  if not tokens or #tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- Find cursor position
  local _, cursor_idx = Tokens.get_token_at_position(tokens, line, col)
  if not cursor_idx then
    cursor_idx = #tokens
  end

  -- Look backwards for ON keyword that's part of a JOIN
  local on_idx = nil
  local join_verified = false
  -- Track if we've seen a clause-terminating keyword before finding ON
  -- If we see WHERE/GROUP/ORDER/HAVING/JOIN before ON, cursor is past the ON clause
  local saw_terminating_keyword = false

  for i = cursor_idx, 1, -1 do
    local t = tokens[i]
    if t.type == "keyword" then
      local kw = t.text:upper()
      if kw == "ON" and not on_idx then
        if saw_terminating_keyword then
          -- We saw WHERE/GROUP/ORDER/HAVING/JOIN before finding ON
          -- This means cursor is past the ON clause
          return nil, nil, {}
        end
        on_idx = i
      elseif kw == "JOIN" then
        if on_idx then
          -- Verified: ON is part of a JOIN clause
          join_verified = true
          break
        else
          -- We saw a JOIN keyword before finding ON
          -- This means cursor is at a subsequent JOIN, past the previous ON clause
          saw_terminating_keyword = true
        end
      elseif kw == "WHERE" or kw == "GROUP" or kw == "ORDER" or kw == "HAVING" then
        if on_idx then
          -- Passed the expected JOIN position - not a JOIN ON clause
          break
        else
          -- Track that we saw a terminating keyword before ON
          -- Cursor is NOT in the ON clause
          saw_terminating_keyword = true
        end
      elseif kw == "FROM" or kw == "SELECT" or kw == "INSERT" or kw == "UPDATE" or
             kw == "DELETE" or kw == "MERGE" then
        if on_idx then
          -- Passed the expected JOIN position - not a JOIN ON clause
          break
        else
          -- We've reached a statement boundary without finding ON
          -- This means we're NOT in an ON clause context
          -- (Could be in outer SELECT after a CTE, or in a different statement)
          return nil, nil, {}
        end
      end
    end
  end

  if not on_idx or not join_verified then
    return nil, nil, {}
  end

  -- We're in a JOIN ON clause! Check for qualified column reference
  local is_after_dot, _ = QualifiedNames.is_dot_triggered(tokens, line, col)
  if is_after_dot then
    local ref = QualifiedNames.get_reference_before_dot(tokens, line, col)
    if ref then
      extra.table_ref = ref
      return "column", "qualified", extra
    end
  end

  -- Check for left-side column (type-aware completion)
  local left_side = QualifiedNames.extract_left_side_column(tokens, line, col)
  if left_side then
    extra.left_side = left_side
  end

  return "column", "on", extra
end

---Detect if cursor is inside a subquery SELECT clause
---Handles patterns like: WHERE col IN (SELECT |column FROM table)
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return boolean in_subquery_select True if in subquery SELECT clause
---@return table extra Extra context info
function ColumnContext.is_in_subquery_select(tokens, line, col)
  if not tokens or #tokens == 0 then
    return false, {}
  end

  -- Find cursor position
  local _, cursor_idx = Tokens.get_token_at_position(tokens, line, col)
  if not cursor_idx then
    cursor_idx = #tokens
  end

  -- Look backwards tracking paren depth
  -- We're in a subquery SELECT if:
  -- 1. There's a ( before us
  -- 2. Followed by SELECT
  -- 3. No FROM after the SELECT (between SELECT and cursor)
  local paren_depth = 0
  local found_select_in_subquery = false
  local select_idx = nil

  for i = cursor_idx, 1, -1 do
    local t = tokens[i]
    if t.type == "paren_close" then
      paren_depth = paren_depth + 1
    elseif t.type == "paren_open" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        -- We're inside a paren group - look for SELECT after this
        for j = i + 1, cursor_idx do
          local t2 = tokens[j]
          if t2.type == "keyword" then
            local kw = t2.text:upper()
            if kw == "SELECT" then
              found_select_in_subquery = true
              select_idx = j
            elseif kw == "FROM" and found_select_in_subquery then
              -- There's a FROM after SELECT - not in SELECT clause
              found_select_in_subquery = false
            end
          end
        end
        break
      end
    end
  end

  return found_select_in_subquery, {}
end

return ColumnContext
