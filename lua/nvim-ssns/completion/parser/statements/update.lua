--- UPDATE statement handler
--- Parses UPDATE statements including simple UPDATE and extended UPDATE with FROM
---
--- Note: The extended UPDATE syntax (UPDATE alias SET ... FROM table alias)
--- requires the FROM clause to be parsed after SET, which is handled by the
--- main parse loop. This module handles the initial UPDATE parsing.
---
---@module ssns.completion.parser.statements.update

require('nvim-ssns.completion.parser.types')
local BaseStatement = require('nvim-ssns.completion.parser.statements.base')
local FromClauseParser = require('nvim-ssns.completion.parser.clauses.from_clause')

local UpdateStatement = {}

---Parse an UPDATE statement (initial parsing)
---
---@param state ParserState Token navigation state (positioned at UPDATE keyword)
---@param scope ScopeContext Scope context for CTE/subquery tracking
---@param temp_tables table<string, TempTableInfo> Temp tables collection (unused)
---@return StatementChunk chunk The parsed statement chunk
function UpdateStatement.parse(state, scope, temp_tables)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("UPDATE", start_token, state.go_batch_index, state)

  scope.statement_type = "UPDATE"
  state:advance()  -- consume UPDATE

  -- Handle UPDATE TOP (n) [PERCENT] clause
  state:skip_top_clause()

  -- Build known_ctes for table reference parsing
  local known_ctes = scope:get_known_ctes_table()

  -- Extract UPDATE target (could be table in simple UPDATE, or alias in extended UPDATE with FROM)
  -- We store it temporarily - if there's a FROM clause later, this might be an alias
  local update_target = state:parse_table_reference(known_ctes)
  chunk.update_target = update_target

  -- Note: FROM clause for extended UPDATE is parsed by the main loop after SET clause
  -- The main loop will call UpdateStatement.parse_from() when it encounters FROM

  return chunk
end

---Parse FROM clause for extended UPDATE syntax
---Called by the main loop when FROM is encountered after SET in UPDATE
---
---@param state ParserState Token navigation state (positioned at FROM keyword)
---@param chunk StatementChunk The UPDATE chunk being built
---@param scope ScopeContext Scope context
function UpdateStatement.parse_from(state, chunk, scope)
  local from_token = state:current()
  local result = FromClauseParser.parse(state, scope, from_token)
  BaseStatement.process_from_result(chunk, scope, result, { set_has_from = true })
end

---Finalize UPDATE chunk after all parsing
---If no FROM clause was found, the update_target becomes the actual table
---
---@param chunk StatementChunk The UPDATE chunk to finalize
function UpdateStatement.finalize(chunk)
  if chunk.update_target and not chunk.has_from_clause then
    table.insert(chunk.tables, chunk.update_target)
  end
end

return UpdateStatement
