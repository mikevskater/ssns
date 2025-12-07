---@class FormatterState
---@field indent_level number Current indentation depth
---@field line_length number Characters on current line
---@field paren_depth number Parenthesis nesting depth
---@field in_subquery boolean Currently inside subquery
---@field clause_stack string[] Stack of active clauses
---@field last_token Token? Previous token processed
---@field current_clause string? Current clause being processed

---@class FormatterEngine
---Core formatting engine that processes token streams and applies transformation rules.
local Engine = {}

local Tokenizer = require('ssns.completion.tokenizer')
local Output = require('ssns.formatter.output')

---Create a new formatter state
---@return FormatterState
local function create_state()
  return {
    indent_level = 0,
    line_length = 0,
    paren_depth = 0,
    in_subquery = false,
    clause_stack = {},
    last_token = nil,
    current_clause = nil,
  }
end

---Apply keyword casing transformation
---@param token Token
---@param keyword_case string "upper"|"lower"|"preserve"
---@return string
local function apply_keyword_case(token, keyword_case)
  if token.type ~= "keyword" then
    return token.text
  end

  if keyword_case == "upper" then
    return string.upper(token.text)
  elseif keyword_case == "lower" then
    return string.lower(token.text)
  else
    return token.text
  end
end

---Check if a keyword is a major clause that should start on a new line
---@param text string
---@return boolean
local function is_major_clause(text)
  local upper = string.upper(text)
  local major_clauses = {
    SELECT = true,
    FROM = true,
    WHERE = true,
    JOIN = true,
    ["INNER JOIN"] = true,
    ["LEFT JOIN"] = true,
    ["RIGHT JOIN"] = true,
    ["FULL JOIN"] = true,
    ["CROSS JOIN"] = true,
    ["LEFT OUTER JOIN"] = true,
    ["RIGHT OUTER JOIN"] = true,
    ["FULL OUTER JOIN"] = true,
    ["GROUP BY"] = true,
    ["ORDER BY"] = true,
    HAVING = true,
    UNION = true,
    INTERSECT = true,
    EXCEPT = true,
    INSERT = true,
    UPDATE = true,
    DELETE = true,
    SET = true,
    VALUES = true,
    ON = true,
  }
  return major_clauses[upper] == true
end

---Check if a keyword starts a join
---@param text string
---@return boolean
local function is_join_keyword(text)
  local upper = string.upper(text)
  local join_keywords = {
    JOIN = true,
    INNER = true,
    LEFT = true,
    RIGHT = true,
    FULL = true,
    CROSS = true,
    OUTER = true,
    NATURAL = true,
  }
  return join_keywords[upper] == true
end

---Check if token is AND or OR
---@param token Token
---@return boolean
local function is_and_or(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  return upper == "AND" or upper == "OR"
end

---Format SQL text
---@param sql string The SQL text to format
---@param config FormatterConfig The formatter configuration
---@param opts? {dialect?: string} Optional formatting options
---@return string formatted The formatted SQL text
function Engine.format(sql, config, opts)
  opts = opts or {}

  -- Tokenize the input
  local tokens = Tokenizer.tokenize(sql)
  if not tokens or #tokens == 0 then
    return sql
  end

  -- Create formatter state
  local state = create_state()

  -- Process tokens
  local processed_tokens = {}
  for i, token in ipairs(tokens) do
    local processed = {
      type = token.type,
      text = token.text,
      line = token.line,
      col = token.col,
      original = token,
      keyword_category = token.keyword_category,
    }

    -- Apply keyword casing
    if token.type == "keyword" or token.type == "go" then
      processed.text = apply_keyword_case(token, config.keyword_case)
    end

    -- Track clause context
    if token.type == "keyword" and is_major_clause(token.text) then
      state.current_clause = string.upper(token.text)
    end

    -- Track parenthesis depth
    if token.type == "paren_open" then
      state.paren_depth = state.paren_depth + 1
      -- Check if this might be a subquery (next significant token is SELECT)
      local next_idx = i + 1
      while next_idx <= #tokens and (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
        next_idx = next_idx + 1
      end
      if next_idx <= #tokens and tokens[next_idx].type == "keyword" and string.upper(tokens[next_idx].text) == "SELECT" then
        state.in_subquery = true
        state.indent_level = state.indent_level + config.subquery_indent
      end
    elseif token.type == "paren_close" then
      state.paren_depth = math.max(0, state.paren_depth - 1)
      if state.in_subquery and state.paren_depth == 0 then
        state.in_subquery = false
        state.indent_level = math.max(0, state.indent_level - config.subquery_indent)
      end
    end

    processed.indent_level = state.indent_level
    processed.paren_depth = state.paren_depth
    processed.current_clause = state.current_clause

    table.insert(processed_tokens, processed)
    state.last_token = token
  end

  -- Generate output
  return Output.generate(processed_tokens, config)
end

return Engine
