--- UPDATE statement handler
--- Parses UPDATE statements including simple UPDATE and extended UPDATE with FROM
---
--- Note: The extended UPDATE syntax (UPDATE alias SET ... FROM table alias)
--- requires the FROM clause to be parsed after SET, which is handled by the
--- main parse loop. This module handles the initial UPDATE parsing.
---
---@module ssns.completion.parser.statements.update

require('ssns.completion.parser.types')
local BaseStatement = require('ssns.completion.parser.statements.base')
local FromClauseParser = require('ssns.completion.parser.clauses.from_clause')

local UpdateStatement = {}

---Parse an UPDATE statement (initial parsing)
---
---@param state ParserState Token navigation state (positioned at UPDATE keyword)
---@param scope ScopeContext Scope context for CTE/subquery tracking
---@param temp_tables table<string, TempTableInfo> Temp tables collection (unused)
---@return StatementChunk chunk The parsed statement chunk
function UpdateStatement.parse(state, scope, temp_tables)
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("UPDATE", start_token, state.go_batch_index)

  scope.statement_type = "UPDATE"
  state:advance()  -- consume UPDATE

  -- Handle UPDATE TOP (n) [PERCENT] clause
  UpdateStatement._skip_top_clause(state)

  -- Build known_ctes for table reference parsing
  local known_ctes = {}
  if scope then
    for name, _ in pairs(scope.ctes) do
      known_ctes[name] = true
    end
  end

  -- Extract UPDATE target (could be table in simple UPDATE, or alias in extended UPDATE with FROM)
  -- We store it temporarily - if there's a FROM clause later, this might be an alias
  local update_target = state:parse_table_reference(known_ctes)
  chunk.update_target = update_target

  -- Note: FROM clause for extended UPDATE is parsed by the main loop after SET clause
  -- The main loop will call UpdateStatement.parse_from() when it encounters FROM

  return chunk
end

---Skip TOP (n) [PERCENT] clause if present
---@param state ParserState
function UpdateStatement._skip_top_clause(state)
  if not state:is_keyword("TOP") then
    return
  end

  state:advance()  -- consume TOP

  -- Skip the (n) or (n) PERCENT
  if state:is_type("paren_open") then
    local depth = 1
    state:advance()
    while state:current() and depth > 0 do
      if state:is_type("paren_open") then
        depth = depth + 1
      elseif state:is_type("paren_close") then
        depth = depth - 1
      end
      state:advance()
    end
  end

  -- Skip optional PERCENT keyword
  if state:is_keyword("PERCENT") then
    state:advance()
  end
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

  -- Copy tables from result (replace any existing)
  chunk.tables = result.tables

  -- Store clause positions
  if result.clause_position then
    chunk.clause_positions["from"] = result.clause_position
  end

  -- Store individual JOIN positions
  if result.join_positions then
    for i, pos in ipairs(result.join_positions) do
      chunk.clause_positions["join_" .. i] = pos
    end
  end

  -- Store individual ON positions
  if result.on_positions then
    for i, pos in ipairs(result.on_positions) do
      chunk.clause_positions["on_" .. i] = pos
    end
  end

  -- Mark that we found a FROM clause
  chunk.has_from_clause = true

  -- Add tables to scope
  for _, table_ref in ipairs(result.tables) do
    scope:add_table(table_ref)
  end
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
