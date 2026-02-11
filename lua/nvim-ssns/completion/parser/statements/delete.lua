--- DELETE statement handler
--- Parses DELETE statements including simple DELETE and extended DELETE with FROM
---
--- Syntax variants:
--- 1. DELETE FROM table WHERE ... (simple)
--- 2. DELETE alias FROM table alias WHERE ... (extended with alias)
--- 3. DELETE table FROM table alias WHERE ... (table name as target)
---
---@module ssns.completion.parser.statements.delete

require('nvim-ssns.completion.parser.types')
local BaseStatement = require('nvim-ssns.completion.parser.statements.base')
local FromClauseParser = require('nvim-ssns.completion.parser.clauses.from_clause')

local DeleteStatement = {}

---Parse a DELETE statement
---
---@param state ParserState Token navigation state (positioned at DELETE keyword)
---@param scope ScopeContext Scope context for CTE/subquery tracking
---@param temp_tables table<string, TempTableInfo> Temp tables collection (unused)
---@return StatementChunk chunk The parsed statement chunk
function DeleteStatement.parse(state, scope, temp_tables)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("DELETE", start_token, state.go_batch_index, state)

  scope.statement_type = "DELETE"
  state:advance()  -- consume DELETE

  -- Handle DELETE TOP (n) [PERCENT] clause
  state:skip_top_clause()

  -- Build known_ctes for table reference parsing
  local known_ctes = scope:get_known_ctes_table()

  -- Handle DELETE syntax variants
  if state:is_keyword("FROM") then
    -- Simple DELETE FROM table
    local from_token = state:current()
    state:advance()  -- consume FROM
    local table_ref = state:parse_table_reference(known_ctes)
    if table_ref then
      table.insert(chunk.tables, table_ref)
      scope:add_table(table_ref)
    end
    -- Track delete_target clause position (FROM keyword to end of table ref)
    local last = state.pos > 1 and state.tokens[state.pos - 1] or from_token
    BaseStatement.add_clause_position(chunk, "delete_target", from_token, last)
  elseif state:current() and (state:current().type == "identifier" or state:current().type == "bracket_id") then
    -- Extended DELETE: DELETE alias/table FROM table alias
    -- Parse the delete target (could be alias or table name)
    local delete_target = state:parse_table_reference(known_ctes)
    chunk.delete_target = delete_target

    -- Track delete_target clause position for context detection
    if delete_target then
      local last = state.pos > 1 and state.tokens[state.pos - 1] or start_token
      BaseStatement.add_clause_position(chunk, "delete_target", start_token, last)
    end
    -- The FROM clause will be parsed later in the main loop
  end

  return chunk
end

---Parse FROM clause for extended DELETE syntax
---Called by the main loop when FROM is encountered after DELETE alias
---
---@param state ParserState Token navigation state (positioned at FROM keyword)
---@param chunk StatementChunk The DELETE chunk being built
---@param scope ScopeContext Scope context
function DeleteStatement.parse_from(state, chunk, scope)
  local from_token = state:current()
  local result = FromClauseParser.parse(state, scope, from_token)
  BaseStatement.process_from_result(chunk, scope, result, { set_has_from = true })
end

return DeleteStatement
