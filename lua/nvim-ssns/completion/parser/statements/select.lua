--- SELECT statement handler
--- Parses SELECT statements including SELECT INTO and SELECT...FROM
---
---@module ssns.completion.parser.statements.select

require('nvim-ssns.completion.parser.types')
local BaseStatement = require('nvim-ssns.completion.parser.statements.base')
local SelectListParser = require('nvim-ssns.completion.parser.clauses.select_list')
local FromClauseParser = require('nvim-ssns.completion.parser.clauses.from_clause')
local Helpers = require('nvim-ssns.completion.parser.utils.helpers')
local QualifiedName = require('nvim-ssns.completion.parser.utils.qualified_name')
local Keywords = require('nvim-ssns.completion.parser.utils.keywords')

local SelectStatement = {}

---Parse a SELECT statement
---
---@param state ParserState Token navigation state (positioned at SELECT keyword)
---@param scope ScopeContext Scope context for CTE/subquery tracking
---@param temp_tables table<string, TempTableInfo> Temp tables collection to update
---@return StatementChunk chunk The parsed statement chunk
function SelectStatement.parse(state, scope, temp_tables)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("SELECT", start_token, state.go_batch_index, state)

  scope.statement_type = "SELECT"
  state:advance()  -- consume SELECT

  -- Parse SELECT list (columns)
  local select_token = start_token
  local select_clause_pos
  chunk.columns, select_clause_pos = SelectListParser.parse(state, scope, select_token)
  if select_clause_pos then
    chunk.clause_positions["select"] = select_clause_pos
  end

  -- Handle INTO clause (SELECT INTO #temp FROM ...)
  if state:is_keyword("INTO") then
    SelectStatement._parse_into(state, chunk, scope, temp_tables)
  end

  -- Parse FROM clause
  if state:is_keyword("FROM") then
    SelectStatement._parse_from(state, chunk, scope)
  end

  -- Parse remaining clauses (WHERE, GROUP BY, HAVING, ORDER BY)
  SelectStatement._parse_remaining_clauses(state, chunk, scope)

  -- Finalize: build aliases, resolve column parents, copy subqueries
  BaseStatement.finalize_chunk(chunk, scope, state)

  return chunk
end

---Parse SELECT INTO clause
---@param state ParserState
---@param chunk StatementChunk
---@param scope ScopeContext
---@param temp_tables table<string, TempTableInfo>
function SelectStatement._parse_into(state, chunk, scope, temp_tables)
  local into_token = state:current()
  state:advance()  -- consume INTO

  local qualified = QualifiedName.parse(state)
  if qualified then
    -- Build full qualified name for temp_table_name
    local full_name = qualified.name
    if qualified.schema then
      full_name = qualified.schema .. "." .. full_name
    end
    if qualified.database then
      full_name = qualified.database .. "." .. full_name
    end
    chunk.temp_table_name = full_name
    chunk.is_global_temp = Helpers.is_global_temp_table(qualified.name)

    -- Store temp table info if it's a temp table (#name or ##name)
    if Helpers.is_temp_table(qualified.name) and chunk.columns then
      temp_tables[qualified.name] = {
        name = qualified.name,
        columns = chunk.columns,
        created_in_batch = state.go_batch_index,
        is_global = Helpers.is_global_temp_table(qualified.name),
      }
    end
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

---Parse SELECT FROM clause
---@param state ParserState
---@param chunk StatementChunk
---@param scope ScopeContext
function SelectStatement._parse_from(state, chunk, scope)
  local from_token = state:current()
  local result = FromClauseParser.parse(state, scope, from_token)
  BaseStatement.process_from_result(chunk, scope, result)
end

---Parse remaining clauses after FROM (WHERE, GROUP BY, HAVING, ORDER BY)
---@param state ParserState
---@param chunk StatementChunk
---@param scope ScopeContext
function SelectStatement._parse_remaining_clauses(state, chunk, scope)
  local paren_depth = 0
  local last_valid_token = nil

  while state:current() do
    local token = state:current()

    -- Check for statement terminators BEFORE updating last_valid_token
    if token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      -- GO batch separator - stop parsing
      break
    elseif paren_depth == 0 and Keywords.is_statement_starter(token.text) then
      -- New statement starting (but not WITH which could be a table hint in some contexts)
      if token.text:upper() ~= "WITH" then
        break
      end
    elseif paren_depth == 0 and (token.text:upper() == "UNION" or token.text:upper() == "INTERSECT" or token.text:upper() == "EXCEPT") then
      -- Set operations - stop parsing this SELECT
      break
    end

    -- Update last_valid_token only for tokens that belong to this statement
    last_valid_token = token

    -- Track parenthesis depth for subqueries/expressions
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      state:advance()
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        break
      end
      state:advance()
    elseif paren_depth == 0 and token.type == "keyword" then
      local upper_text = token.text:upper()

      if upper_text == "WHERE" then
        SelectStatement._parse_where_clause(state, chunk, scope)
      elseif upper_text == "GROUP" then
        SelectStatement._parse_group_by_clause(state, chunk)
      elseif upper_text == "HAVING" then
        SelectStatement._parse_having_clause(state, chunk, scope)
      elseif upper_text == "ORDER" then
        SelectStatement._parse_order_by_clause(state, chunk)
      elseif upper_text == "LIMIT" or upper_text == "OFFSET" or upper_text == "FETCH" then
        -- LIMIT/OFFSET/FETCH - track as part of ORDER BY or separate
        SelectStatement._parse_limit_offset_clause(state, chunk, upper_text)
      elseif upper_text == "FOR" or upper_text == "OPTION" then
        -- FOR XML/JSON or OPTION hints - skip but don't break
        state:advance()
      else
        state:advance()
      end
    else
      state:advance()
    end
  end

  -- Update chunk end position based on last processed token or clause positions
  if last_valid_token then
    chunk.end_line = last_valid_token.line
    chunk.end_col = last_valid_token.col + #last_valid_token.text - 1
  end
  -- Also check clause positions for the furthest end position
  for _, pos in pairs(chunk.clause_positions or {}) do
    if pos.end_line > chunk.end_line or (pos.end_line == chunk.end_line and pos.end_col > chunk.end_col) then
      chunk.end_line = pos.end_line
      chunk.end_col = pos.end_col
    end
  end
end

---Parse WHERE clause and track its position
---@param state ParserState
---@param chunk StatementChunk
---@param scope ScopeContext
function SelectStatement._parse_where_clause(state, chunk, scope)
  local where_token = state:current()
  state:advance()  -- consume WHERE

  local paren_depth = 0
  local last_token = where_token

  -- Build known_ctes for subquery parsing
  local known_ctes = scope and scope:get_known_ctes_table() or {}

  -- Parse until we hit GROUP BY, HAVING, ORDER BY, or statement end
  while state:current() do
    local token = state:current()

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      last_token = token
      state:advance()
      -- Check for subquery: (SELECT ...
      if state:is_keyword("SELECT") then
        local subquery = state:parse_subquery(known_ctes)
        if subquery then
          -- After parse_subquery, parser is AT the closing ) - consume it
          if state:is_type("paren_close") then
            last_token = state:current()
            state:advance()
          end
          paren_depth = paren_depth - 1
          -- Add to scope so it gets copied to chunk in finalize
          if scope then
            scope:add_subquery(subquery)
          end
        end
      end
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        break
      end
      last_token = token
      state:advance()
    elseif token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      break
    elseif paren_depth == 0 and token.type == "keyword" then
      local upper_text = token.text:upper()
      if upper_text == "GROUP" or upper_text == "HAVING" or upper_text == "ORDER"
         or upper_text == "UNION" or upper_text == "INTERSECT" or upper_text == "EXCEPT"
         or upper_text == "FOR" or upper_text == "OPTION" or upper_text == "LIMIT"
         or upper_text == "OFFSET" or upper_text == "FETCH" then
        break
      elseif Keywords.is_statement_starter(upper_text) and upper_text ~= "WITH" then
        break
      else
        last_token = token
        state:advance()
      end
    else
      last_token = token
      state:advance()
    end
  end

  -- Track WHERE clause position
  chunk.clause_positions["where"] = {
    start_line = where_token.line,
    start_col = where_token.col,
    end_line = last_token.line,
    end_col = last_token.col + #last_token.text - 1,
  }
end

---Parse GROUP BY clause and track its position
---@param state ParserState
---@param chunk StatementChunk
function SelectStatement._parse_group_by_clause(state, chunk)
  local group_token = state:current()
  state:advance()  -- consume GROUP

  -- Expect BY keyword
  if not state:is_keyword("BY") then
    return
  end
  state:advance()  -- consume BY

  local paren_depth = 0
  local last_token = state.tokens[state.pos - 1] or group_token

  -- Parse until we hit HAVING, ORDER BY, or statement end
  while state:current() do
    local token = state:current()

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      last_token = token
      state:advance()
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        break
      end
      last_token = token
      state:advance()
    elseif token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      break
    elseif paren_depth == 0 and token.type == "keyword" then
      local upper_text = token.text:upper()
      if upper_text == "HAVING" or upper_text == "ORDER"
         or upper_text == "UNION" or upper_text == "INTERSECT" or upper_text == "EXCEPT"
         or upper_text == "FOR" or upper_text == "OPTION" or upper_text == "LIMIT"
         or upper_text == "OFFSET" or upper_text == "FETCH" then
        break
      elseif Keywords.is_statement_starter(upper_text) and upper_text ~= "WITH" then
        break
      else
        last_token = token
        state:advance()
      end
    else
      last_token = token
      state:advance()
    end
  end

  -- Track GROUP BY clause position
  chunk.clause_positions["group_by"] = {
    start_line = group_token.line,
    start_col = group_token.col,
    end_line = last_token.line,
    end_col = last_token.col + #last_token.text - 1,
  }
end

---Parse HAVING clause and track its position
---@param state ParserState
---@param chunk StatementChunk
---@param scope ScopeContext
function SelectStatement._parse_having_clause(state, chunk, scope)
  local having_token = state:current()
  state:advance()  -- consume HAVING

  local paren_depth = 0
  local last_token = having_token

  -- Build known_ctes for subquery parsing
  local known_ctes = scope and scope:get_known_ctes_table() or {}

  -- Parse until we hit ORDER BY or statement end
  while state:current() do
    local token = state:current()

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      last_token = token
      state:advance()
      -- Check for subquery: (SELECT ...
      if state:is_keyword("SELECT") then
        local subquery = state:parse_subquery(known_ctes)
        if subquery then
          -- After parse_subquery, parser is AT the closing ) - consume it
          if state:is_type("paren_close") then
            last_token = state:current()
            state:advance()
          end
          paren_depth = paren_depth - 1
          -- Add to scope so it gets copied to chunk in finalize
          if scope then
            scope:add_subquery(subquery)
          end
        end
      end
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        break
      end
      last_token = token
      state:advance()
    elseif token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      break
    elseif paren_depth == 0 and token.type == "keyword" then
      local upper_text = token.text:upper()
      if upper_text == "ORDER"
         or upper_text == "UNION" or upper_text == "INTERSECT" or upper_text == "EXCEPT"
         or upper_text == "FOR" or upper_text == "OPTION" or upper_text == "LIMIT"
         or upper_text == "OFFSET" or upper_text == "FETCH" then
        break
      elseif Keywords.is_statement_starter(upper_text) and upper_text ~= "WITH" then
        break
      else
        last_token = token
        state:advance()
      end
    else
      last_token = token
      state:advance()
    end
  end

  -- Track HAVING clause position
  chunk.clause_positions["having"] = {
    start_line = having_token.line,
    start_col = having_token.col,
    end_line = last_token.line,
    end_col = last_token.col + #last_token.text - 1,
  }
end

---Parse ORDER BY clause and track its position
---@param state ParserState
---@param chunk StatementChunk
function SelectStatement._parse_order_by_clause(state, chunk)
  local order_token = state:current()
  state:advance()  -- consume ORDER

  -- Expect BY keyword
  if not state:is_keyword("BY") then
    return
  end
  state:advance()  -- consume BY

  local paren_depth = 0
  local last_token = state.tokens[state.pos - 1] or order_token

  -- Parse until we hit statement end or set operations
  while state:current() do
    local token = state:current()

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      last_token = token
      state:advance()
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        break
      end
      last_token = token
      state:advance()
    elseif token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      break
    elseif paren_depth == 0 and token.type == "keyword" then
      local upper_text = token.text:upper()
      -- ORDER BY terminators (but OFFSET/FETCH are part of ORDER BY in SQL Server)
      if upper_text == "UNION" or upper_text == "INTERSECT" or upper_text == "EXCEPT"
         or upper_text == "FOR" or upper_text == "OPTION" then
        break
      elseif upper_text == "OFFSET" or upper_text == "FETCH" or upper_text == "LIMIT" then
        -- These are part of ORDER BY clause, continue parsing
        last_token = token
        state:advance()
      elseif Keywords.is_statement_starter(upper_text) and upper_text ~= "WITH" then
        break
      else
        last_token = token
        state:advance()
      end
    else
      last_token = token
      state:advance()
    end
  end

  -- Track ORDER BY clause position
  chunk.clause_positions["order_by"] = {
    start_line = order_token.line,
    start_col = order_token.col,
    end_line = last_token.line,
    end_col = last_token.col + #last_token.text - 1,
  }
end

---Parse LIMIT/OFFSET/FETCH clause and track its position
---@param state ParserState
---@param chunk StatementChunk
---@param clause_type string The clause type (LIMIT, OFFSET, or FETCH)
function SelectStatement._parse_limit_offset_clause(state, chunk, clause_type)
  local start_token = state:current()
  state:advance()  -- consume LIMIT/OFFSET/FETCH

  local paren_depth = 0
  local last_token = start_token

  -- Parse until we hit statement end
  while state:current() do
    local token = state:current()

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      last_token = token
      state:advance()
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        break
      end
      last_token = token
      state:advance()
    elseif token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      break
    elseif paren_depth == 0 and token.type == "keyword" then
      local upper_text = token.text:upper()
      if upper_text == "UNION" or upper_text == "INTERSECT" or upper_text == "EXCEPT"
         or upper_text == "FOR" or upper_text == "OPTION" then
        break
      elseif upper_text == "OFFSET" or upper_text == "FETCH" or upper_text == "ROWS"
             or upper_text == "ROW" or upper_text == "NEXT" or upper_text == "ONLY" then
        -- These are part of the pagination clause, continue
        last_token = token
        state:advance()
      elseif Keywords.is_statement_starter(upper_text) and upper_text ~= "WITH" then
        break
      else
        last_token = token
        state:advance()
      end
    else
      last_token = token
      state:advance()
    end
  end

  -- Track clause position (use lowercase key)
  local key = clause_type:lower()
  chunk.clause_positions[key] = {
    start_line = start_token.line,
    start_col = start_token.col,
    end_line = last_token.line,
    end_col = last_token.col + #last_token.text - 1,
  }
end

return SelectStatement
