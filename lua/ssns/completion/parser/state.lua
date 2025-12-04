--- ParserState class for navigating token streams
--- Handles token navigation, keyword detection, and basic parsing utilities

require('ssns.completion.parser.types')

-- Statement-starting keywords (temporary - will be moved to utils/keywords.lua in Phase 1)
local STATEMENT_STARTERS = {
  SELECT = true,
  INSERT = true,
  UPDATE = true,
  DELETE = true,
  MERGE = true,
  CREATE = true,
  ALTER = true,
  DROP = true,
  TRUNCATE = true,
  WITH = true,
  EXEC = true,
  EXECUTE = true,
  DECLARE = true,
  SET = true,
}

---Check if keyword starts a new statement
---@param keyword string
---@return boolean
local function is_statement_starter(keyword)
  return STATEMENT_STARTERS[keyword:upper()] == true
end

---Parser state for navigating tokens
---@class ParserState
---@field tokens table[] Token array
---@field pos number Current token position (1-indexed)
---@field go_batch_index number Current GO batch (0-indexed)
local ParserState = {}
ParserState.__index = ParserState

---Create new parser state
---@param tokens table[]
---@return ParserState
function ParserState.new(tokens)
  local state = setmetatable({
    tokens = tokens,
    pos = 1,
    go_batch_index = 0,  -- 0-indexed: first batch is 0, incremented after GO
  }, ParserState)
  -- Skip any leading comments
  state:skip_comments()
  return state
end

---Skip over comment tokens at current position
function ParserState:skip_comments()
  while self.pos <= #self.tokens do
    local token = self.tokens[self.pos]
    if token.type == "comment" or token.type == "line_comment" then
      self.pos = self.pos + 1
    else
      break
    end
  end
end

---Get current token
---@return table?
function ParserState:current()
  if self.pos > #self.tokens then
    return nil
  end
  return self.tokens[self.pos]
end

---Peek ahead n tokens (skipping comments)
---@param offset number?
---@return table?
function ParserState:peek(offset)
  offset = offset or 1
  local new_pos = self.pos
  local skipped = 0
  -- Skip 'offset' non-comment tokens
  while skipped < offset and new_pos <= #self.tokens do
    new_pos = new_pos + 1
    if new_pos <= #self.tokens then
      local token = self.tokens[new_pos]
      if token.type ~= "comment" and token.type ~= "line_comment" then
        skipped = skipped + 1
      end
    end
  end
  if new_pos > #self.tokens then
    return nil
  end
  return self.tokens[new_pos]
end

---Advance to next token (skipping comments)
function ParserState:advance()
  self.pos = self.pos + 1
  self:skip_comments()
end

---Check if current token matches type
---@param token_type string
---@return boolean
function ParserState:is_type(token_type)
  local token = self:current()
  return token and token.type == token_type
end

---Check if current token is keyword (case-insensitive)
---@param keyword string
---@return boolean
function ParserState:is_keyword(keyword)
  local token = self:current()
  return token and token.type == "keyword" and token.text:upper() == keyword:upper()
end

---Check if current token is any of the given keywords
---@param keywords string[]
---@return boolean
function ParserState:is_any_keyword(keywords)
  for _, kw in ipairs(keywords) do
    if self:is_keyword(kw) then
      return true
    end
  end
  return false
end

---Consume token if it matches keyword
---@param keyword string
---@return boolean
function ParserState:consume_keyword(keyword)
  if self:is_keyword(keyword) then
    self:advance()
    return true
  end
  return false
end

---Skip tokens until we find a keyword or reach end
---@param keyword string
function ParserState:skip_until_keyword(keyword)
  while self:current() and not self:is_keyword(keyword) do
    self:advance()
  end
end

---Consume tokens until we hit a statement terminator (for DECLARE/SET/OTHER statements)
---@param paren_depth number? Current parenthesis depth (default 0)
function ParserState:consume_until_statement_end(paren_depth)
  paren_depth = paren_depth or 0
  while self:current() do
    local token = self:current()

    -- Stop at GO batch separator
    if token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      break
    end

    -- Stop at semicolon
    if token.type == "semicolon" then
      break
    end

    -- Track paren depth
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
    end

    -- Stop at new statement starter (only at paren_depth 0)
    if paren_depth == 0 and is_statement_starter(token.text) then
      break
    end

    self:advance()
  end
end

---Parse a parameter/variable (@name or @@system_var)
---@return ParameterInfo?
function ParserState:parse_parameter()
  if not self:is_type("at") then
    return nil
  end

  local at_token = self:current()
  local at_line = at_token.line
  local at_col = at_token.col
  local is_system = false

  self:advance()  -- consume first @

  -- Check for second @ (system variable like @@ROWCOUNT)
  if self:is_type("at") then
    is_system = true
    self:advance()  -- consume second @
  end

  -- Next should be identifier
  local token = self:current()
  if not token or token.type ~= "identifier" then
    return nil
  end

  local name = token.text
  local full_name = (is_system and "@@" or "@") .. name
  self:advance()

  return {
    name = name,
    full_name = full_name,
    line = at_line,
    col = at_col,
    is_system = is_system,
  }
end

---Post-parse parameter extraction from token range
---Scans all tokens in range for @ symbols and extracts parameter info
---@param start_idx number Starting token index (1-indexed, inclusive)
---@param end_idx number Ending token index (1-indexed, inclusive)
---@param target_array ParameterInfo[] Array to append parameters to
function ParserState:extract_all_parameters_from_tokens(start_idx, end_idx, target_array)
  local seen = {}
  local i = start_idx
  while i <= end_idx and i <= #self.tokens do
    local token = self.tokens[i]
    if token.type == "at" then
      -- Look at next token(s) to build parameter
      local is_system = false
      local name_idx = i + 1

      -- Check for @@ (system variable)
      if self.tokens[name_idx] and self.tokens[name_idx].type == "at" then
        is_system = true
        name_idx = name_idx + 1
      end

      -- Get parameter name
      if self.tokens[name_idx] and self.tokens[name_idx].type == "identifier" then
        local name = self.tokens[name_idx].text
        local full_name = (is_system and "@@" or "@") .. name
        local key = full_name:lower()

        -- Check if this is a table variable (in FROM/JOIN context)
        -- We need to skip @TableVar used as table references
        -- Simple heuristic: if previous token is FROM/JOIN or comma in FROM context, it's a table variable
        local is_table_ref = false
        if i > 1 then
          local prev_idx = i - 1
          -- Skip whitespace/comments backward if needed
          while prev_idx > 0 and self.tokens[prev_idx].type == "whitespace" do
            prev_idx = prev_idx - 1
          end
          if prev_idx > 0 then
            local prev = self.tokens[prev_idx]
            if prev.type == "keyword" then
              local kw = prev.text:upper()
              if kw == "FROM" or kw == "JOIN" or kw == "INTO" then
                is_table_ref = true
              end
            elseif prev.type == "comma" then
              -- Could be comma-separated FROM list, check further back
              -- This is a simple heuristic, may need refinement
              -- For now, we'll let table variables through and rely on existing logic
            end
          end
        end

        if not seen[key] and not is_table_ref then
          seen[key] = true
          table.insert(target_array, {
            name = name,
            full_name = full_name,
            is_system = is_system,
            line = token.line,
            col = token.col,
          })
        end

        i = name_idx + 1
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end
end

return ParserState
