---SET statement parsing module (variable assignment)

local BaseStatement = require('nvim-ssns.completion.parser.statements.base')
local Keywords = require('nvim-ssns.completion.parser.utils.keywords')

local SetStatement = {}

---Parse SET statement (variable assignment)
---@param state ParserState Parser state positioned at SET keyword
---@param scope ScopeContext Scope context
---@param SubqueryParser table Subquery parser module (passed to avoid circular dependency)
---@return StatementChunk
function SetStatement.parse(state, scope, SubqueryParser)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("SET", start_token, state.go_batch_index, state)

  scope.statement_type = "SET"
  state:advance()  -- Advance past SET

  -- Build known_ctes for subquery parsing
  local known_ctes = scope and scope:get_known_ctes_table() or {}

  -- Parse SET statement content, looking for subqueries
  local paren_depth = 0

  while state:current() do
    local token = state:current()

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      state:advance()
      -- Check for subquery: (SELECT ...
      if state:is_keyword("SELECT") and SubqueryParser then
        local subquery = SubqueryParser.parse(state, known_ctes)
        if subquery then
          -- After parse, parser is AT the closing ) - consume it
          if state:is_type("paren_close") then
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
      state:advance()
    elseif token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      -- Stop at GO batch separator
      break
    elseif token.type == "semicolon" then
      -- Stop at semicolon
      break
    elseif paren_depth == 0 and token.type == "keyword" then
      -- Check for new statement starter at top level
      if Keywords.is_statement_starter(token.text:upper()) then
        break
      else
        state:advance()
      end
    else
      state:advance()
    end
  end

  -- Finalize chunk (copies subqueries from scope, sets token_end_idx)
  BaseStatement.finalize_chunk(chunk, scope, state)

  -- Extract parameters from token range
  if chunk.token_start_idx and chunk.token_end_idx then
    state:extract_all_parameters_from_tokens(chunk.token_start_idx, chunk.token_end_idx, chunk.parameters)
  end

  return chunk
end

return SetStatement
