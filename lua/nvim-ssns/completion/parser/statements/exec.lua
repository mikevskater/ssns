---EXEC/EXECUTE statement parsing module

local BaseStatement = require('nvim-ssns.completion.parser.statements.base')

local ExecStatement = {}

---Parse EXEC/EXECUTE statement
---@param state ParserState Parser state positioned at EXEC keyword
---@param scope ScopeContext Scope context
---@return StatementChunk
function ExecStatement.parse(state, scope)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("EXEC", start_token, state.go_batch_index, state)

  scope.statement_type = "EXEC"
  state:advance()  -- Must advance past EXEC before consume_until_statement_end
  state:consume_until_statement_end()

  -- Set token_end_idx manually since we don't call finalize_chunk
  if chunk.token_start_idx then
    chunk.token_end_idx = state.pos > 1 and state.pos - 1 or state.pos
  end

  -- Extract parameters from token range
  if chunk.token_start_idx and chunk.token_end_idx then
    state:extract_all_parameters_from_tokens(chunk.token_start_idx, chunk.token_end_idx, chunk.parameters)
  end

  return chunk
end

return ExecStatement
