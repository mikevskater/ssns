---Clause-based context detection for SQL completion
---Handles StatementParser clause positions to determine context type
---@module ssns.completion.context.clause_context
local ClauseContext = {}

local Debug = require('nvim-ssns.debug')
local TokenContext = require('nvim-ssns.completion.token_context')

---Context type constants (shared with statement_context)
local Type = {
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
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return QualifiedName? qualified Parsed qualified name, or nil
---@return boolean is_after_dot Whether cursor is immediately after a dot
local function detect_qualified_from_tokens(tokens, line, col)
  if not tokens or #tokens == 0 then
    return nil, false
  end

  local is_after_dot, qualified = TokenContext.is_dot_triggered(tokens, line, col)

  Debug.log(string.format("[clause_context] is_after_dot=%s, parts=%s, schema=%s, database=%s",
    tostring(is_after_dot),
    qualified and table.concat(qualified.parts, ".") or "nil",
    qualified and qualified.schema or "nil",
    qualified and qualified.database or "nil"))

  return qualified, is_after_dot
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
function ClauseContext.handle_clause(bufnr, line_num, col, tokens, chunk, clause)
  local extra = {}
  local ctx_type, mode

  if clause == "select" then
    ctx_type = Type.COLUMN
    mode = "select"

  elseif clause == "from" then
    ctx_type = Type.TABLE
    mode = "from"
    -- Use token-based detection for reliable qualified name parsing
    local token_qualified, is_after_dot = detect_qualified_from_tokens(tokens, line_num, col)

    Debug.log(string.format("[handle_clause FROM] token_qualified=%s, is_after_dot=%s, schema=%s, database=%s",
      token_qualified and "yes" or "nil",
      tostring(is_after_dot),
      token_qualified and token_qualified.schema or "nil",
      token_qualified and token_qualified.database or "nil"))

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

    -- Use qualified info for filtering when available (even when typing partial identifier)
    if token_qualified and (token_qualified.database or token_qualified.schema) then
      if token_qualified.database then
        extra.database = token_qualified.database
        extra.schema = token_qualified.schema
        extra.filter_database = token_qualified.database
        extra.filter_schema = token_qualified.schema
        extra.omit_schema = is_after_dot
        mode = is_join_context and "join_cross_db_qualified" or "from_cross_db_qualified"
      elseif token_qualified.schema then
        extra.potential_database = token_qualified.schema
        extra.schema = token_qualified.schema
        extra.filter_schema = token_qualified.schema
        extra.omit_schema = is_after_dot
        mode = is_join_context and "join_qualified" or "from_qualified"
        Debug.log(string.format("[handle_clause FROM] SET filter_schema=%s, mode=%s", extra.filter_schema, mode))
      end
    else
      Debug.log("[handle_clause FROM] NO qualified info - showing all objects")
    end

  elseif clause == "join" then
    ctx_type = Type.TABLE
    mode = "join"
    local token_qualified, is_after_dot = detect_qualified_from_tokens(tokens, line_num, col)

    if token_qualified and (token_qualified.database or token_qualified.schema) then
      if token_qualified.database then
        extra.database = token_qualified.database
        extra.schema = token_qualified.schema
        extra.filter_database = token_qualified.database
        extra.filter_schema = token_qualified.schema
        extra.omit_schema = is_after_dot
        mode = "join_cross_db_qualified"
      elseif token_qualified.schema then
        extra.potential_database = token_qualified.schema
        extra.schema = token_qualified.schema
        extra.filter_schema = token_qualified.schema
        extra.omit_schema = is_after_dot
        mode = "join_qualified"
      end
    end

  elseif clause == "on" then
    ctx_type = Type.COLUMN
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
    ctx_type = Type.COLUMN
    mode = "where"
    local left_side_where = TokenContext.extract_left_side_column(tokens, line_num, col)
    if left_side_where then
      extra.left_side = left_side_where
    end

  elseif clause == "group_by" then
    ctx_type = Type.COLUMN
    mode = "group_by"

  elseif clause == "having" then
    ctx_type = Type.COLUMN
    mode = "having"

  elseif clause == "order_by" then
    ctx_type = Type.COLUMN
    mode = "order_by"

  elseif clause == "set" then
    ctx_type = Type.COLUMN
    -- Distinguish SET left-side (target column) vs right-side (value expression)
    local left_side = TokenContext.extract_left_side_column(tokens, line_num, col)
    if left_side then
      extra.left_side = left_side
      mode = "set_value"
    else
      mode = "set"
    end

  elseif clause == "into" then
    ctx_type = Type.TABLE
    mode = "into"
    local is_after_dot, qualified = TokenContext.is_dot_triggered(tokens, line_num, col)
    if qualified and (qualified.database or qualified.schema) then
      if qualified.database then
        extra.database = qualified.database
        extra.schema = qualified.schema
        extra.filter_database = qualified.database
        extra.filter_schema = qualified.schema
        extra.omit_schema = is_after_dot
        mode = "into_cross_db_qualified"
      elseif qualified.schema then
        extra.schema = qualified.schema
        extra.filter_schema = qualified.schema
        extra.omit_schema = is_after_dot
        mode = "into_qualified"
      end
    end

  elseif clause == "insert_columns" then
    ctx_type = Type.COLUMN
    mode = "insert_columns"

  elseif clause == "values" then
    ctx_type = Type.COLUMN
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
      ctx_type = Type.COLUMN
      mode = "qualified"
    end
  end

  return ctx_type, mode, extra
end

---Handle clause continuation (cursor past clause end but still in same context)
---Uses TOKEN-BASED detection for multi-line SQL support
---Replaces line-number heuristics with token analysis for reliable multi-line FROM
---@param line_num number 1-indexed line
---@param col number 1-indexed column
---@param tokens Token[] Parsed tokens
---@param chunk StatementChunk Parsed statement chunk
---@return string? ctx_type Context type or nil if no continuation match
---@return string? mode Sub-mode for provider routing
---@return table? extra Extra context info
function ClauseContext.handle_continuation(line_num, col, tokens, chunk)
  local extra = {}

  -- Token-based: check if recent tokens indicate FROM clause continuation
  -- Look at tokens before cursor and see if last meaningful token is comma, JOIN, or FROM
  local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line_num, col, 8)
  if #prev_tokens == 0 then return nil, nil, nil end

  local last_meaningful = nil
  for _, t in ipairs(prev_tokens) do
    if t.type == "comma" then
      last_meaningful = "comma"
      break
    elseif t.type == "keyword" then
      local kw = t.text:upper()
      if kw == "JOIN" or kw == "INNER" or kw == "LEFT" or kw == "RIGHT"
         or kw == "FULL" or kw == "CROSS" or kw == "OUTER" then
        last_meaningful = "join"
        break
      elseif kw == "FROM" then
        last_meaningful = "from"
        break
      else
        -- Some other keyword (WHERE, ON, etc.) → not in FROM continuation
        break
      end
    elseif t.type == "identifier" or t.type == "bracket_id" or t.type == "dot" then
      -- Could be typing partial table name after comma/join — keep looking
    else
      break
    end
  end

  if last_meaningful == "from" or last_meaningful == "comma" or last_meaningful == "join" then
    -- We're continuing a FROM or JOIN clause — use token-based qualified name detection
    local is_after_dot, qualified = TokenContext.is_dot_triggered(tokens, line_num, col)

    if qualified and (qualified.database or qualified.schema) then
      if qualified.database then
        extra.database = qualified.database
        extra.schema = qualified.schema
        extra.filter_database = qualified.database
        extra.filter_schema = qualified.schema
        extra.omit_schema = is_after_dot
        return Type.TABLE, last_meaningful == "join" and "join_cross_db_qualified" or "from_cross_db_qualified", extra
      elseif qualified.schema then
        extra.potential_database = qualified.schema
        extra.schema = qualified.schema
        extra.filter_schema = qualified.schema
        extra.omit_schema = is_after_dot
        return Type.TABLE, last_meaningful == "join" and "join_qualified" or "from_qualified", extra
      end
    end
    return Type.TABLE, last_meaningful == "join" and "join" or "from", extra
  end

  -- No continuation context found
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
---@param detect_unparsed_subquery function Callback for subquery detection
---@return string? ctx_type Context type or nil if no clause match
---@return string? mode Sub-mode for provider routing
---@return table? extra Extra context info
function ClauseContext.detect_from_clause(bufnr, line_num, col, tokens, chunk, cache_ctx, detect_unparsed_subquery)
  local StatementParser = require('nvim-ssns.completion.statement_parser')

  -- Check if we're inside a subquery with its own clause positions
  local clause_source = chunk
  if cache_ctx and cache_ctx.subquery and cache_ctx.subquery.clause_positions then
    clause_source = { clause_positions = cache_ctx.subquery.clause_positions }
  end

  local clause = StatementParser.get_clause_at_position(clause_source, line_num, col)
  Debug.log(string.format("[clause_context] get_clause_at_position returned: %s", tostring(clause)))

  -- If we're in WHERE/HAVING clause but might be inside an unparsed subquery,
  -- check using token-based analysis
  if clause == "where" or clause == "having" then
    if detect_unparsed_subquery then
      local in_unparsed_subquery, subquery_tables = detect_unparsed_subquery(tokens, line_num, col)
      if in_unparsed_subquery then
        Debug.log("[clause_context] Detected unparsed subquery, falling through to token-based detection")
        if subquery_tables and cache_ctx then
          cache_ctx._subquery_tables = subquery_tables
        end
        return nil, nil, nil
      end
    end
  end

  if clause then
    return ClauseContext.handle_clause(bufnr, line_num, col, tokens, chunk, clause)
  end

  -- Clause detection returned nil - check if we're just past a FROM or JOIN clause
  return ClauseContext.handle_continuation(line_num, col, tokens, chunk)
end

return ClauseContext
