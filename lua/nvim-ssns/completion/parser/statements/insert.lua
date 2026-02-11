--- INSERT statement handler
--- Parses INSERT statements including INSERT INTO, INSERT...VALUES, INSERT...SELECT
---
---@module ssns.completion.parser.statements.insert

require('nvim-ssns.completion.parser.types')
local BaseStatement = require('nvim-ssns.completion.parser.statements.base')
local SelectListParser = require('nvim-ssns.completion.parser.clauses.select_list')
local FromClauseParser = require('nvim-ssns.completion.parser.clauses.from_clause')
local WhereClauseParser = require('nvim-ssns.completion.parser.clauses.where_clause')
local SubqueryParser = require('nvim-ssns.completion.parser.clauses.subquery')
local TableReferenceParser = require('nvim-ssns.completion.parser.utils.table_reference')
local Helpers = require('nvim-ssns.completion.parser.utils.helpers')
local Keywords = require('nvim-ssns.completion.parser.utils.keywords')

local InsertStatement = {}

---Parse an INSERT statement
---
---@param state ParserState Token navigation state (positioned at INSERT keyword)
---@param scope ScopeContext Scope context for CTE/subquery tracking
---@param temp_tables table<string, TempTableInfo> Temp tables collection (unused for INSERT)
---@return StatementChunk chunk The parsed statement chunk
---@return boolean in_insert Flag indicating we're still parsing INSERT (for INSERT...SELECT)
function InsertStatement.parse(state, scope, temp_tables)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("INSERT", start_token, state.go_batch_index, state)
  local in_insert = true

  scope.statement_type = "INSERT"
  state:advance()  -- consume INSERT

  -- Parse INSERT INTO table
  if state:is_keyword("INTO") then
    InsertStatement._parse_into(state, chunk, scope)
  end

  -- Parse column list if present: INSERT INTO table (col1, col2, ...)
  if state:is_type("paren_open") then
    InsertStatement._parse_column_list(state, chunk)
  end

  -- Continue to find SELECT, VALUES, or EXEC
  while state:current() and not state:is_keyword("SELECT") and not state:is_keyword("VALUES") and not state:is_keyword("EXEC") and not state:is_keyword("EXECUTE") do
    state:advance()
  end

  -- Parse VALUES clause if present
  if state:is_keyword("VALUES") then
    InsertStatement._parse_values(state, chunk)
    in_insert = false  -- VALUES ends the INSERT context
  -- Parse INSERT...EXEC if present
  elseif state:is_keyword("EXEC") or state:is_keyword("EXECUTE") then
    -- INSERT INTO ... EXEC sproc - consume the EXEC and capture procedure name
    state:advance()  -- consume EXEC/EXECUTE keyword
    -- Capture procedure name (possibly schema-qualified: schema.proc_name)
    if state:current() and (state:current().type == "identifier" or state:current().type == "bracket_id") then
      local proc_parts = {}
      while state:current() do
        local t = state:current()
        if t.type == "identifier" or t.type == "bracket_id" then
          table.insert(proc_parts, Helpers.strip_brackets(t.text))
          state:advance()
          if state:is_type("dot") then
            state:advance()
          else
            break
          end
        else
          break
        end
      end
      chunk.exec_procedure = table.concat(proc_parts, ".")
    end
    -- Skip remaining parameters until we hit a statement terminator or new statement
    while state:current() do
      local token = state:current()
      -- Stop at GO batch separator
      if token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
        break
      end
      -- Stop at semicolon
      if token.type == "semicolon" then
        break
      end
      -- Stop at new statement starter (but EXEC itself is a statement starter, so skip it)
      if token.type == "keyword" and Keywords.is_statement_starter(token.text) then
        break
      end
      state:advance()
    end
    in_insert = false
  -- Parse INSERT...SELECT if present (only if we didn't already parse VALUES or EXEC)
  elseif state:is_keyword("SELECT") then
    InsertStatement._parse_select(state, chunk, scope)
  end

  -- Finalize: build aliases, resolve column parents, copy subqueries
  BaseStatement.finalize_chunk(chunk, scope, state)

  return chunk, in_insert
end

---Parse INSERT INTO clause
---@param state ParserState
---@param chunk StatementChunk
---@param scope ScopeContext
function InsertStatement._parse_into(state, chunk, scope)
  local into_token = state:current()
  state:advance()  -- consume INTO

  -- Build known_ctes for table reference parsing
  local known_ctes = scope:get_known_ctes_table()

  local table_ref = state:parse_table_reference(known_ctes)
  if table_ref then
    table.insert(chunk.tables, table_ref)
  end

  -- Track INTO clause position
  local last_token = state.pos > 1 and state.tokens[state.pos - 1] or into_token
  chunk.clause_positions["into"] = {
    start_line = into_token.line,
    start_col = into_token.col,
    end_line = last_token.line,
    end_col = last_token.col + #last_token.text - 1,
  }
end

---Parse INSERT column list: (col1, col2, ...)
---@param state ParserState
---@param chunk StatementChunk
function InsertStatement._parse_column_list(state, chunk)
  local col_start = state:current()
  local insert_columns = {}
  local last_token = col_start
  state:advance()  -- consume (

  while state:current() and not state:is_type("paren_close") do
    local tok = state:current()
    if tok.type == "identifier" or tok.type == "bracket_id" then
      -- Extract column name (strip brackets if needed)
      table.insert(insert_columns, Helpers.strip_brackets(tok.text))
    end
    last_token = tok
    state:advance()
  end

  if state:is_type("paren_close") then
    local col_end = state:current()

    -- Track column list position for context detection
    chunk.clause_positions["insert_columns"] = {
      start_line = col_start.line,
      start_col = col_start.col,
      end_line = col_end.line,
      end_col = col_end.col,
    }

    -- Store parsed columns
    chunk.insert_columns = insert_columns

    state:advance()  -- consume )
  else
    -- Incomplete column list (no closing paren yet)
    -- Still track position for context detection during typing
    -- Extend both end_line and end_col to large values to handle multiline typing
    chunk.clause_positions["insert_columns"] = {
      start_line = col_start.line,
      start_col = col_start.col,
      end_line = last_token.line + 1000,  -- Handle multiline incomplete lists
      end_col = last_token.col + #last_token.text + 1000,  -- Include cursor position
    }
    chunk.insert_columns = insert_columns
  end
end

---Parse VALUES clause: VALUES (v1, v2), (v3, v4)
---@param state ParserState
---@param chunk StatementChunk
function InsertStatement._parse_values(state, chunk)
  local values_token = state:current()
  state:advance()  -- consume VALUES

  -- VALUES can have multiple row sets: VALUES (...), (...)
  local first_values_paren = nil
  local last_values_token = values_token

  while state:current() do
    if state:is_type("paren_open") then
      if not first_values_paren then
        first_values_paren = state:current()
      end

      -- Skip this VALUES row
      local paren_depth = 1
      state:advance()  -- consume (

      while state:current() and paren_depth > 0 do
        if state:is_type("paren_open") then
          paren_depth = paren_depth + 1
        elseif state:is_type("paren_close") then
          paren_depth = paren_depth - 1
        end
        last_values_token = state:current()
        state:advance()
      end
    elseif state:is_type("comma") then
      -- Multi-row VALUES: VALUES (...), (...)
      state:advance()
    else
      break  -- Not part of VALUES clause
    end
  end

  -- Track VALUES clause position
  if first_values_paren then
    chunk.clause_positions["values"] = {
      start_line = values_token.line,
      start_col = values_token.col,
      end_line = last_values_token.line,
      end_col = last_values_token.col + #last_values_token.text - 1,
    }
  end
end

---Parse INSERT...SELECT substatement
---@param state ParserState
---@param chunk StatementChunk
---@param scope ScopeContext
function InsertStatement._parse_select(state, chunk, scope)
  local select_token = state:current()
  state:advance()  -- consume SELECT

  -- Parse SELECT list
  local select_clause_pos
  chunk.columns, select_clause_pos = SelectListParser.parse(state, scope, select_token)
  if select_clause_pos then
    chunk.clause_positions["select"] = select_clause_pos
  end

  -- Parse FROM clause if present
  if state:is_keyword("FROM") then
    local from_token = state:current()
    local result = FromClauseParser.parse(state, scope, from_token)
    BaseStatement.process_from_result(chunk, scope, result, { append_tables = true })
  end

  -- Parse WHERE clause if present
  if state:is_keyword("WHERE") then
    WhereClauseParser.parse(state, chunk, scope, SubqueryParser)
  end

  -- Parse GROUP BY if present
  if state:is_keyword("GROUP") then
    local group_token = state:current()
    state:advance()  -- consume GROUP
    if state:is_keyword("BY") then
      local by_token = state:current()
      state:advance()  -- consume BY
      local last_token = by_token
      while state:current() do
        local t = state:current()
        if t.type == "semicolon" or t.type == "go" then break end
        if t.type == "keyword" then
          local kw = t.text:upper()
          if kw == "HAVING" or kw == "ORDER" or kw == "OPTION" or kw == "FOR" then break end
          if Keywords.is_statement_starter(kw) then break end
        end
        last_token = t
        state:advance()
      end
      BaseStatement.add_clause_position(chunk, "group_by", by_token, last_token)
    end
  end

  -- Parse HAVING if present
  if state:is_keyword("HAVING") then
    local having_token = state:current()
    state:advance()  -- consume HAVING
    local last_token = having_token
    while state:current() do
      local t = state:current()
      if t.type == "semicolon" or t.type == "go" then break end
      if t.type == "keyword" then
        local kw = t.text:upper()
        if kw == "ORDER" or kw == "OPTION" or kw == "FOR" then break end
        if Keywords.is_statement_starter(kw) then break end
      end
      last_token = t
      state:advance()
    end
    BaseStatement.add_clause_position(chunk, "having", having_token, last_token)
  end

  -- Parse ORDER BY if present
  if state:is_keyword("ORDER") then
    local order_token = state:current()
    state:advance()  -- consume ORDER
    if state:is_keyword("BY") then
      local by_token = state:current()
      state:advance()  -- consume BY
      local last_token = by_token
      while state:current() do
        local t = state:current()
        if t.type == "semicolon" or t.type == "go" then break end
        if t.type == "keyword" and Keywords.is_statement_starter(t.text:upper()) then break end
        last_token = t
        state:advance()
      end
      BaseStatement.add_clause_position(chunk, "order_by", by_token, last_token)
    end
  end
end

return InsertStatement
