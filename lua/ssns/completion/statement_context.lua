---Statement-based context detection for SQL completion
---
---Architecture:
---  - Uses StatementCache/StatementChunk for clause position tracking
---  - Uses TokenContext for all token-based detection (no regex patterns)
---  - Supports multi-line SQL statements with accurate cursor position detection
---
---Detection Flow:
---  1. _detect_special_cases() - OUTPUT, EXEC, INSERT columns, ON clause
---  2. _detect_from_clause() - Clause-based detection if chunk available
---  3. TokenContext.detect_context() - Unified token-based fallback
---
---Key Functions:
---  - Context.detect() - Simple context detection
---  - Context.detect_full() - Full detection with should_complete flag
---  - _handle_clause_context() - Per-clause handling
---  - _handle_clause_continuation() - Cursor past clause end detection
local Debug = require('ssns.debug')
local StatementCache = require('ssns.completion.statement_cache')
local TokenContext = require('ssns.completion.token_context')

local Context = {}

---Context types
Context.Type = {
  UNKNOWN = "unknown",
  KEYWORD = "keyword",
  DATABASE = "database",
  SCHEMA = "schema",
  TABLE = "table",
  COLUMN = "column",
  PROCEDURE = "procedure",
  PARAMETER = "parameter",
  ALIAS = "alias",
}

---Detect qualified name using token-based analysis
---This is more reliable than regex because tokens have accurate positions
---@param bufnr number Buffer number
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return QualifiedName? qualified Parsed qualified name, or nil
---@return boolean is_after_dot Whether cursor is immediately after a dot
local function detect_qualified_from_tokens(bufnr, line, col)
  -- Get tokens for the buffer
  local tokens = TokenContext.get_buffer_tokens(bufnr)
  if not tokens or #tokens == 0 then
    return nil, false
  end

  -- Check if we're after a dot
  local is_after_dot, qualified = TokenContext.is_dot_triggered(tokens, line, col)

  Debug.log(string.format("[token_context] is_after_dot=%s, parts=%s, schema=%s, database=%s",
    tostring(is_after_dot),
    qualified and table.concat(qualified.parts, ".") or "nil",
    qualified and qualified.schema or "nil",
    qualified and qualified.database or "nil"))

  return qualified, is_after_dot
end

---Detect special cases that have highest priority (before clause-based routing)
---These patterns need to be checked first because they override normal clause detection
---Uses TOKEN-BASED detection for multi-line SQL support
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type or nil if no special case
---@return string? mode Sub-mode for provider routing
---@return table? extra Extra context info
function Context._detect_special_cases(tokens, line, col)
  local ctx_type, mode, extra

  -- 1. OUTPUT inserted./deleted. detection (highest priority for OUTPUT qualified columns)
  -- Check if we're after a dot following INSERTED or DELETED in an OUTPUT context
  local is_after_dot, _ = TokenContext.is_dot_triggered(tokens, line, col)
  if is_after_dot then
    local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line, col, 15)
    local found_inserted_or_deleted = nil
    local found_output = false

    for _, t in ipairs(prev_tokens) do
      local upper_text = t.text:upper()
      -- INSERTED/DELETED may be tokenized as identifiers or keywords
      if (t.type == "keyword" or t.type == "identifier") and
         (upper_text == "INSERTED" or upper_text == "DELETED") and not found_inserted_or_deleted then
        found_inserted_or_deleted = upper_text:lower()
      elseif t.type == "keyword" then
        if upper_text == "OUTPUT" and found_inserted_or_deleted then
          found_output = true
          break
        elseif upper_text == "INSERT" or upper_text == "UPDATE" or upper_text == "DELETE" or
               upper_text == "MERGE" or upper_text == "SELECT" then
          break
        end
      end
    end

    if found_output and found_inserted_or_deleted then
      return Context.Type.COLUMN, "output", {
        is_output_clause = true,
        output_pseudo_table = found_inserted_or_deleted,
        table_ref = found_inserted_or_deleted,
      }
    end
  end

  -- 2. OUTPUT INTO table detection (needs TABLE completion, not COLUMN)
  ctx_type, mode, extra = TokenContext.detect_output_into_from_tokens(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 3. EXEC/EXECUTE detection (procedure context)
  ctx_type, mode, extra = TokenContext.detect_other_context_from_tokens(tokens, line, col)
  if ctx_type == "procedure" then
    return ctx_type, mode, extra
  end

  -- 4. INSERT column list detection
  ctx_type, mode, extra = TokenContext.detect_insert_columns_from_tokens(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 5. MERGE INSERT column list detection (WHEN NOT MATCHED THEN INSERT (columns))
  ctx_type, mode, extra = TokenContext.detect_merge_insert_from_tokens(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 6. ON clause detection (JOIN conditions)
  ctx_type, mode, extra = TokenContext.detect_on_clause_from_tokens(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  return nil, nil, nil
end

---Detect context from StatementParser clause positions
---Uses TOKEN-BASED detection for multi-line SQL support
---@param bufnr number Buffer number
---@param line_num number 1-indexed line
---@param col number 1-indexed column
---@param tokens Token[] Parsed tokens
---@param chunk StatementChunk Parsed statement chunk
---@param cache_ctx table StatementCache context
---@return string? ctx_type Context type or nil if no clause match
---@return string? mode Sub-mode for provider routing
---@return table? extra Extra context info
function Context._detect_from_clause(bufnr, line_num, col, tokens, chunk, cache_ctx)
  local StatementParser = require('ssns.completion.statement_parser')

  -- Check if we're inside a subquery with its own clause positions
  local clause_source = chunk
  if cache_ctx and cache_ctx.subquery and cache_ctx.subquery.clause_positions then
    clause_source = { clause_positions = cache_ctx.subquery.clause_positions }
  end

  local clause = StatementParser.get_clause_at_position(clause_source, line_num, col)
  Debug.log(string.format("[statement_context] get_clause_at_position returned: %s", tostring(clause)))

  -- If we're in WHERE/HAVING clause but might be inside an unparsed subquery,
  -- check using token-based analysis
  if clause == "where" or clause == "having" then
    -- Look for SELECT keyword inside parentheses before cursor
    local in_unparsed_subquery, subquery_tables = Context._detect_unparsed_subquery(tokens, line_num, col)
    print(string.format("[SUBQ DEBUG] clause=%s, in_subquery=%s, tables=%s", tostring(clause), tostring(in_unparsed_subquery), subquery_tables and #subquery_tables or "nil"))
    if in_unparsed_subquery then
      Debug.log("[statement_context] Detected unparsed subquery, falling through to token-based detection")
      -- Store subquery tables in cache_ctx for later use
      if subquery_tables and cache_ctx then
        cache_ctx._subquery_tables = subquery_tables
        print(string.format("[SUBQ DEBUG] Stored %d subquery tables", #subquery_tables))
        for _, t in ipairs(subquery_tables) do
          print(string.format("[SUBQ DEBUG]   - %s (alias: %s)", t.table, t.alias))
        end
      end
      return nil, nil, nil  -- Fall through to token-based detection
    end
  end

  if clause then
    return Context._handle_clause_context(bufnr, line_num, col, tokens, chunk, clause)
  end

  -- Clause detection returned nil - check if we're just past a FROM or JOIN clause
  return Context._handle_clause_continuation(line_num, col, tokens, chunk)
end

---Detect if cursor is inside an unparsed subquery (SELECT inside parentheses in WHERE/HAVING)
---Also extracts the subquery's FROM clause tables when detected
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return boolean is_in_unparsed_subquery True if we're inside a subquery that wasn't parsed
---@return table[]? subquery_tables Array of table references from the subquery's FROM clause
function Context._detect_unparsed_subquery(tokens, line, col)
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
        -- This means cursor is after FROM
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
  -- Walk forward from cursor to find "FROM tablename" within the subquery
  local subquery_tables = Context._extract_subquery_tables(tokens, line, col)

  return true, subquery_tables
end

---Extract table references by walking backwards from cursor
---Finds FROM clause tables when cursor is in WHERE/HAVING of subquery
---@param tokens Token[] Parsed tokens
---@param cursor_idx number Token index at cursor position
---@return table[]? tables Array of table references
function Context._extract_subquery_tables_backward(tokens, cursor_idx)
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
function Context._extract_subquery_tables(tokens, line, col)
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
  -- This handles cases like: SELECT ... FROM Table WHERE █
  local backward_tables = Context._extract_subquery_tables_backward(tokens, cursor_idx)
  if backward_tables and #backward_tables > 0 then
    return backward_tables
  end

  -- If not found backwards, walk forward from cursor looking for "FROM tablename"
  -- This handles cases like: SELECT █ FROM Table
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

---Handle known clause context
---Uses TOKEN-BASED detection for multi-line SQL support
---@param bufnr number Buffer number
---@param line_num number 1-indexed line
---@param col number 1-indexed column
---@param tokens Token[] Parsed tokens
---@param chunk StatementChunk Parsed statement chunk
---@param clause string Clause name from StatementParser
---@return string ctx_type Context type
---@return string mode Sub-mode for provider routing
---@return table extra Extra context info
function Context._handle_clause_context(bufnr, line_num, col, tokens, chunk, clause)
  local extra = {}
  local ctx_type, mode

  if clause == "select" then
    ctx_type = Context.Type.COLUMN
    mode = "select"

  elseif clause == "from" then
    ctx_type = Context.Type.TABLE
    mode = "from"
    -- Use token-based detection for reliable qualified name parsing
    local token_qualified, is_after_dot = detect_qualified_from_tokens(bufnr, line_num, col)

    -- Check if we're in a JOIN context using tokens (look for recent JOIN keyword)
    local is_join_context = false
    local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line_num, col, 5)
    for _, t in ipairs(prev_tokens) do
      if t.type == "keyword" and t.text:upper() == "JOIN" then
        is_join_context = true
        break
      end
    end
    if is_join_context then
      mode = "join"
    end

    -- Use qualified info when cursor is after a dot OR typing partial identifier after dot
    if token_qualified and (token_qualified.database or token_qualified.schema) then
      if token_qualified.database then
        extra.database = token_qualified.database
        extra.schema = token_qualified.schema
        extra.filter_database = token_qualified.database
        extra.filter_schema = token_qualified.schema
        extra.omit_schema = is_after_dot  -- Only omit schema if cursor is directly after dot
        mode = is_join_context and "join_cross_db_qualified" or "from_cross_db_qualified"
      elseif token_qualified.schema then
        extra.potential_database = token_qualified.schema
        extra.schema = token_qualified.schema
        extra.filter_schema = token_qualified.schema
        extra.omit_schema = is_after_dot  -- Only omit schema if cursor is directly after dot
        mode = is_join_context and "join_qualified" or "from_qualified"
      end
    end

  elseif clause == "join" then
    ctx_type = Context.Type.TABLE
    mode = "join"
    local token_qualified, is_after_dot = detect_qualified_from_tokens(bufnr, line_num, col)

    -- Use qualified info when cursor is after a dot OR typing partial identifier after dot
    if token_qualified and (token_qualified.database or token_qualified.schema) then
      if token_qualified.database then
        extra.database = token_qualified.database
        extra.schema = token_qualified.schema
        extra.filter_database = token_qualified.database
        extra.filter_schema = token_qualified.schema
        extra.omit_schema = is_after_dot  -- Only omit schema if cursor is directly after dot
        mode = "join_cross_db_qualified"
      elseif token_qualified.schema then
        extra.potential_database = token_qualified.schema
        extra.schema = token_qualified.schema
        extra.filter_schema = token_qualified.schema
        extra.omit_schema = is_after_dot  -- Only omit schema if cursor is directly after dot
        mode = "join_qualified"
      end
    end

  elseif clause == "on" then
    ctx_type = Context.Type.COLUMN
    mode = "on"
    local left_side_on = TokenContext.extract_left_side_column(tokens, line_num, col)
    if left_side_on then
      extra.left_side = left_side_on
    end
    local is_after_dot_on, _ = TokenContext.is_dot_triggered(tokens, line_num, col)
    if is_after_dot_on then
      local ref = TokenContext.get_reference_before_dot(tokens, line_num, col)
      if ref then
        extra.table_ref = ref
        mode = "qualified"
      end
    end

  elseif clause == "where" then
    ctx_type = Context.Type.COLUMN
    mode = "where"
    local left_side_where = TokenContext.extract_left_side_column(tokens, line_num, col)
    if left_side_where then
      extra.left_side = left_side_where
    end

  elseif clause == "group_by" then
    ctx_type = Context.Type.COLUMN
    mode = "group_by"

  elseif clause == "having" then
    ctx_type = Context.Type.COLUMN
    mode = "having"

  elseif clause == "order_by" then
    ctx_type = Context.Type.COLUMN
    mode = "order_by"

  elseif clause == "set" then
    ctx_type = Context.Type.COLUMN
    mode = "set"

  elseif clause == "into" then
    ctx_type = Context.Type.TABLE
    mode = "into"
    -- Use token-based qualified name detection for cross-database support
    local is_after_dot, qualified = TokenContext.is_dot_triggered(tokens, line_num, col)
    if is_after_dot and qualified then
      if qualified.database then
        extra.database = qualified.database
        extra.schema = qualified.schema
        extra.filter_database = qualified.database
        extra.filter_schema = qualified.schema
        extra.omit_schema = true
        mode = "into_cross_db_qualified"
      elseif qualified.schema then
        extra.schema = qualified.schema
        extra.filter_schema = qualified.schema
        extra.omit_schema = true
        mode = "into_qualified"
      end
    end

  elseif clause == "insert_columns" then
    ctx_type = Context.Type.COLUMN
    mode = "insert_columns"

  elseif clause == "values" then
    ctx_type = Context.Type.COLUMN
    mode = "values"

  else
    -- Unknown clause - return nil to fall through to token-based detection
    return nil, nil, nil
  end

  -- Check for qualified column reference (alias.column, table.column)
  -- Don't override TABLE context clauses
  local is_after_dot_qual, _ = TokenContext.is_dot_triggered(tokens, line_num, col)
  if is_after_dot_qual and
     clause ~= "from" and clause ~= "join" and clause ~= "into" and
     clause ~= "update" and clause ~= "delete" and clause ~= "merge" then
    local ref = TokenContext.get_reference_before_dot(tokens, line_num, col)
    if ref then
      extra.table_ref = ref
      extra.filter_table = ref
      extra.omit_table = true
      ctx_type = Context.Type.COLUMN
      mode = "qualified"
    end
  end

  return ctx_type, mode, extra
end

---Handle clause continuation (cursor past clause end but still in same context)
---Uses TOKEN-BASED detection for multi-line SQL support
---@param line_num number 1-indexed line
---@param col number 1-indexed column
---@param tokens Token[] Parsed tokens
---@param chunk StatementChunk Parsed statement chunk
---@return string? ctx_type Context type or nil if no continuation match
---@return string? mode Sub-mode for provider routing
---@return table? extra Extra context info
function Context._handle_clause_continuation(line_num, col, tokens, chunk)
  local extra = {}
  local from_pos = chunk.clause_positions and chunk.clause_positions["from"]
  local join_pos = nil
  local where_pos = chunk.clause_positions and chunk.clause_positions["where"]
  local group_by_pos = chunk.clause_positions and chunk.clause_positions["group_by"]
  local having_pos = chunk.clause_positions and chunk.clause_positions["having"]
  local order_by_pos = chunk.clause_positions and chunk.clause_positions["order_by"]

  if chunk.clause_positions then
    -- Find most recent join clause
    for k, v in pairs(chunk.clause_positions) do
      if k:match("^join_%d+$") or k == "join" then
        if not join_pos or v.end_line > join_pos.end_line or
           (v.end_line == join_pos.end_line and v.end_col > join_pos.end_col) then
          join_pos = v
        end
      end
    end
  end

  -- Helper to check if cursor is past a clause start
  local function cursor_past_clause_start(clause_pos)
    if not clause_pos then return false end
    return line_num > clause_pos.start_line or
           (line_num == clause_pos.start_line and col > clause_pos.start_col)
  end

  -- Don't consider FROM/JOIN context if cursor is past WHERE/GROUP BY/HAVING/ORDER BY
  local past_where = cursor_past_clause_start(where_pos)
  local past_group_by = cursor_past_clause_start(group_by_pos)
  local past_having = cursor_past_clause_start(having_pos)
  local past_order_by = cursor_past_clause_start(order_by_pos)
  local in_later_clause = past_where or past_group_by or past_having or past_order_by

  -- Check if cursor is on the same line as FROM/JOIN clause end or immediately after
  local in_from_context = from_pos and not in_later_clause and
    (line_num == from_pos.end_line or
     (line_num == from_pos.end_line + 1 and col <= 50))
  local in_join_context = join_pos and not in_later_clause and
    (line_num == join_pos.end_line or
     (line_num == join_pos.end_line + 1 and col <= 50))

  if in_from_context or in_join_context then
    -- We're continuing a FROM or JOIN clause - use token-based qualified name detection
    local is_after_dot, qualified = TokenContext.is_dot_triggered(tokens, line_num, col)

    if is_after_dot and qualified then
      if qualified.database then
        extra.database = qualified.database
        extra.schema = qualified.schema
        extra.filter_database = qualified.database
        extra.filter_schema = qualified.schema
        extra.omit_schema = true
        return Context.Type.TABLE, in_join_context and "join_cross_db_qualified" or "from_cross_db_qualified", extra
      elseif qualified.schema then
        extra.potential_database = qualified.schema
        extra.schema = qualified.schema
        extra.filter_schema = qualified.schema
        extra.omit_schema = true
        return Context.Type.TABLE, in_join_context and "join_qualified" or "from_qualified", extra
      end
    end
    return Context.Type.TABLE, in_join_context and "join" or "from", extra
  end

  -- No continuation context found
  return nil, nil, nil
end

---Main context detection (simple version without full checks)
---@param bufnr number Buffer number
---@param line_num number 1-indexed line number
---@param col number 1-indexed column
---@return table context Context information
function Context.detect(bufnr, line_num, col)
  Debug.log(string.format("[statement_context] detect: bufnr=%d, line=%d, col=%d", bufnr, line_num, col))

  -- Get line text
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if #lines == 0 then
    return {
      type = Context.Type.UNKNOWN,
      mode = "unknown",
      prefix = "",
      trigger = nil,
      chunk = nil,
      tables = {},
      aliases = {},
      ctes = {},
      temp_tables = {},
      subquery = nil,
    }
  end

  local line = lines[1]
  local before_cursor = line:sub(1, col - 1)

  -- Get tokens for buffer (used for token-based detection throughout)
  local tokens = TokenContext.get_buffer_tokens(bufnr)

  -- Get StatementCache context
  local cache_ctx = StatementCache.get_context_at_position(bufnr, line_num, col)

  -- Extract prefix and trigger using token-based detection
  local prefix, trigger = TokenContext.extract_prefix_and_trigger(tokens, line_num, col)

  -- Detect type using clause positions first, fallback to unified token-based detection
  local ctx_type, mode, extra
  local chunk = cache_ctx and cache_ctx.chunk

  -- Try unified token-based detection for special cases first
  -- These have highest priority and override clause-based routing
  ctx_type, mode, extra = Context._detect_special_cases(tokens, line_num, col)

  if not ctx_type and chunk then
    -- Use clause-based detection if chunk is available
    ctx_type, mode, extra = Context._detect_from_clause(bufnr, line_num, col, tokens, chunk, cache_ctx)
  end

  if not ctx_type then
    -- Final fallback: unified token-based detection
    ctx_type, mode, extra = TokenContext.detect_context(tokens, line_num, col)
  end

  -- Ensure extra is initialized
  extra = extra or {}

  -- Build tables_in_scope array from cache_ctx.tables
  -- Format: {alias = "e", table = "dbo.EMPLOYEES", scope = "main"}
  -- or for CTEs: {name = "CTE_Name", is_cte = true, columns = {...}}
  -- or for subqueries: {name = "sub", is_subquery = true, columns = {...}}
  local tables_in_scope = {}
  local seen_ctes = {} -- Track which CTEs have been added to avoid duplicates
  local seen_subqueries = {} -- Track which subqueries have been added to avoid duplicates
  local seen_temp_tables = {} -- Track which temp tables have been added to avoid duplicates

  -- If we detected subquery tables, use those instead of outer query tables
  if cache_ctx and cache_ctx._subquery_tables then
    Debug.log(string.format("[statement_context] Using %d subquery tables", #cache_ctx._subquery_tables))
    for _, sq_table in ipairs(cache_ctx._subquery_tables) do
      table.insert(tables_in_scope, {
        alias = sq_table.alias,
        table = sq_table.table,
        name = sq_table.name,
        schema = sq_table.schema,
        scope = "subquery",
      })
    end
    -- Don't process outer query tables when we're in a subquery
  elseif cache_ctx and cache_ctx.tables then
    for _, table_ref in ipairs(cache_ctx.tables) do
      -- Preserve CTE entries with their columns
      if table_ref.is_cte then
        local cte_name = table_ref.name
        if not seen_ctes[cte_name:lower()] then
          seen_ctes[cte_name:lower()] = true
          -- Look up columns from the CTE definition if not present on table_ref
          local cte_columns = table_ref.columns
          if (not cte_columns or #cte_columns == 0) and cache_ctx.ctes then
            local cte_def = cache_ctx.ctes[cte_name] or cache_ctx.ctes[cte_name:lower()]
            if cte_def then
              cte_columns = cte_def.columns
            end
          end
          table.insert(tables_in_scope, {
            name = cte_name,
            is_cte = true,
            columns = cte_columns,
          })
        end
      elseif table_ref.is_temp_table then
        -- Preserve temp table entries with their columns
        local temp_name = table_ref.name
        if temp_name and not seen_temp_tables[temp_name:lower()] then
          seen_temp_tables[temp_name:lower()] = true
          -- Look up columns from temp_tables dict if not present on table_ref
          local temp_columns = table_ref.columns
          if (not temp_columns or #temp_columns == 0) and cache_ctx.temp_tables then
            local temp_def = cache_ctx.temp_tables[temp_name] or cache_ctx.temp_tables[temp_name:lower()]
            if temp_def then
              temp_columns = temp_def.columns
            end
          end
          table.insert(tables_in_scope, {
            name = temp_name,
            alias = table_ref.alias,
            is_temp_table = true,
            is_global = table_ref.is_global,
            columns = temp_columns,
          })
        end
      elseif table_ref.is_subquery then
        -- Preserve subquery/derived table entries with their columns
        local sq_name = table_ref.name or table_ref.alias
        if sq_name and not seen_subqueries[sq_name:lower()] then
          seen_subqueries[sq_name:lower()] = true
          table.insert(tables_in_scope, {
            name = sq_name,
            alias = table_ref.alias,
            is_subquery = true,
            columns = table_ref.columns,
          })
        end
      elseif table_ref.is_tvf then
        -- Preserve table-valued function (TVF) entries
        -- Columns will be looked up from database metadata when needed
        local tvf_name = table_ref.alias or table_ref.name
        if tvf_name then
          table.insert(tables_in_scope, {
            name = table_ref.name,
            alias = table_ref.alias,
            schema = table_ref.schema,
            is_tvf = true,
            function_name = table_ref.function_name or table_ref.name,
          })
        end
      else
        local table_name = table_ref.name
        -- Build qualified table name if schema is present
        if table_ref.schema then
          table_name = table_ref.schema .. "." .. table_ref.name
        end
        if table_ref.database then
          table_name = table_ref.database .. "." .. table_name
        end

        table.insert(tables_in_scope, {
          alias = table_ref.alias,
          table = table_name,
          scope = "main",  -- Could be "main" or "subquery" in the future
        })
      end
    end
  end

  -- Convert aliases from {alias_lower -> TableReference} to {alias_lower -> table_name_string}
  local aliases_map = {}
  if cache_ctx and cache_ctx.aliases then
    for alias_lower, table_ref in pairs(cache_ctx.aliases) do
      local table_name = table_ref.name
      -- Build qualified table name if schema is present
      if table_ref.schema then
        table_name = table_ref.schema .. "." .. table_ref.name
      end
      if table_ref.database then
        table_name = table_ref.database .. "." .. table_name
      end
      aliases_map[alias_lower] = table_name
    end
  end

  -- Build context result
  local context = {
    type = ctx_type,
    mode = mode,
    prefix = prefix,
    trigger = trigger,

    -- Pass through StatementCache data
    chunk = cache_ctx and cache_ctx.chunk,
    tables = cache_ctx and cache_ctx.tables or {},
    aliases = aliases_map,  -- Converted format: alias_lower -> table_name_string
    ctes = cache_ctx and cache_ctx.ctes or {},
    temp_tables = cache_ctx and cache_ctx.temp_tables or {},
    subquery = cache_ctx and cache_ctx.subquery,
    tables_in_scope = tables_in_scope,  -- New field for Resolver

    -- Extra context from type detection
    table_ref = extra.table_ref,
    schema = extra.schema,
    database = extra.database,
    filter_schema = extra.filter_schema,
    filter_database = extra.filter_database,
    filter_table = extra.filter_table,
    potential_database = extra.potential_database,
    omit_schema = extra.omit_schema,
    omit_table = extra.omit_table,
    value_position = extra.value_position,
    left_side = extra.left_side,
    -- INSERT column list context
    insert_table = extra.insert_table,
    insert_schema = extra.insert_schema,
    table = extra.table,
  }

  Debug.log(string.format("[statement_context] detected type=%s, mode=%s, prefix=%s", ctx_type, mode, prefix))

  return context
end

---Full context detection with all checks (entry point for blink.cmp)
---@param bufnr number Buffer number
---@param line_num number 1-indexed line number
---@param col number 1-indexed column
---@return table context Full context with should_complete flag
function Context.detect_full(bufnr, line_num, col)
  Debug.log(string.format("[statement_context] detect_full: bufnr=%d, line=%d, col=%d", bufnr, line_num, col))

  -- Get line text
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if #lines == 0 then
    return {
      type = Context.Type.UNKNOWN,
      mode = "unknown",
      prefix = "",
      trigger = nil,
      should_complete = false,
      line = "",
      line_num = line_num,
      col = col,
      chunk = nil,
      tables = {},
      aliases = {},
      ctes = {},
      temp_tables = {},
      subquery = nil,
    }
  end

  local line = lines[1]

  -- Check if in comment or string using token-based detection
  -- This is more reliable than regex-based line parsing, especially for multi-line comments
  local tokens = TokenContext.get_buffer_tokens(bufnr)
  if TokenContext.is_in_string_or_comment(tokens, line_num, col) then
    -- Determine if it's a comment or string for the mode field
    local token_at = TokenContext.get_token_at_position(tokens, line_num, col)
    local mode = "string_or_comment"
    if token_at then
      if token_at.type == "comment" or token_at.type == "line_comment" then
        mode = "comment"
        Debug.log("[statement_context] Inside comment (token-based), skipping completion")
      elseif token_at.type == "string" then
        mode = "string"
        Debug.log("[statement_context] Inside string (token-based), skipping completion")
      end
    end
    return {
      type = Context.Type.UNKNOWN,
      mode = mode,
      prefix = "",
      trigger = nil,
      should_complete = false,
      line = line,
      line_num = line_num,
      col = col,
      chunk = nil,
      tables = {},
      aliases = {},
      ctes = {},
      temp_tables = {},
      subquery = nil,
    }
  end

  -- Get basic context
  local context = Context.detect(bufnr, line_num, col)

  -- Add full check fields
  context.should_complete = context.type ~= Context.Type.UNKNOWN
  context.line = line
  context.line_num = line_num
  context.col = col

  Debug.log(string.format("[statement_context] detect_full result: should_complete=%s, type=%s, mode=%s",
    tostring(context.should_complete), context.type, context.mode))

  return context
end

return Context
