---EXEC/EXECUTE statement parsing module

local BaseStatement = require('nvim-ssns.completion.parser.statements.base')
local Helpers = require('nvim-ssns.completion.parser.utils.helpers')

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
  state:advance()  -- consume EXEC/EXECUTE

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

  -- Consume remaining parameters until statement end
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
