--- SELECT statement handler
--- Parses SELECT statements including SELECT INTO and SELECT...FROM
---
---@module ssns.completion.parser.statements.select

require('ssns.completion.parser.types')
local BaseStatement = require('ssns.completion.parser.statements.base')
local SelectListParser = require('ssns.completion.parser.clauses.select_list')
local FromClauseParser = require('ssns.completion.parser.clauses.from_clause')
local Helpers = require('ssns.completion.parser.utils.helpers')
local QualifiedName = require('ssns.completion.parser.utils.qualified_name')

local SelectStatement = {}

---Parse a SELECT statement
---
---@param state ParserState Token navigation state (positioned at SELECT keyword)
---@param scope ScopeContext Scope context for CTE/subquery tracking
---@param temp_tables table<string, TempTableInfo> Temp tables collection to update
---@return StatementChunk chunk The parsed statement chunk
function SelectStatement.parse(state, scope, temp_tables)
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("SELECT", start_token, state.go_batch_index)

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

  -- Finalize: build aliases, resolve column parents, copy subqueries
  BaseStatement.finalize_chunk(chunk, scope)

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

return SelectStatement
