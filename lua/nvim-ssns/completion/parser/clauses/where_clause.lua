---WHERE clause parsing module
---Handles parsing of WHERE clauses with subquery detection

local Keywords = require('nvim-ssns.completion.parser.utils.keywords')

local WhereClauseParser = {}

---Parse WHERE clause and track its position
---@param state ParserState Parser state positioned at WHERE keyword
---@param chunk StatementChunk Chunk to update with clause position
---@param scope ScopeContext Scope context
---@param SubqueryParser table Subquery parser module (passed to avoid circular dependency)
function WhereClauseParser.parse(state, chunk, scope, SubqueryParser)
  local where_token = state:current()
  state:advance()  -- consume WHERE

  local paren_depth = 0
  local last_token = where_token

  -- Build known_ctes for subquery parsing
  local known_ctes = scope and scope:get_known_ctes_table() or {}

  -- Parse until we hit ORDER BY, statement end, or next statement
  while state:current() do
    local token = state:current()

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      last_token = token
      state:advance()
      -- Check for subquery: (SELECT ...
      if state:is_keyword("SELECT") and SubqueryParser then
        local subquery = SubqueryParser.parse(state, known_ctes)
        if subquery then
          -- After parse, parser is AT the closing ) - consume it
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
    elseif token.type == "semicolon" then
      break
    elseif paren_depth == 0 and token.type == "keyword" then
      local upper_text = token.text:upper()
      if upper_text == "ORDER" or upper_text == "OPTION" or upper_text == "FOR" then
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

return WhereClauseParser
