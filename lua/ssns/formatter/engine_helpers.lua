---@class FormatterEngineHelpers
---Helper functions for the formatter engine
local M = {}

---Create a new formatter state
---@return FormatterState
function M.create_state()
  return {
    indent_level = 0,
    line_length = 0,
    paren_depth = 0,
    in_subquery = false,
    subquery_stack = {},  -- Stack of {paren_depth, indent_level} for nested subqueries
    clause_stack = {},
    last_token = nil,
    current_clause = nil,
    join_modifier = nil,
    -- CTE tracking
    in_cte = false,            -- Currently inside WITH clause
    cte_name_expected = false, -- Expecting CTE name
    cte_as_expected = false,   -- Expecting AS keyword
    cte_body_start = false,    -- Next paren starts CTE body
    cte_stack = {},            -- Stack for CTE body tracking
    -- CASE expression tracking
    case_stack = {},           -- Stack for nested CASE expressions {indent_level}
    in_case = false,           -- Currently inside CASE expression
    -- Window function (OVER clause) tracking
    in_over = false,           -- Currently inside OVER clause
    over_paren_depth = 0,      -- Paren depth when entering OVER
    -- DML statement tracking
    in_merge = false,          -- Currently inside MERGE statement
    in_insert = false,         -- Currently inside INSERT statement
    insert_expecting_table = false,  -- Expecting table name after INSERT INTO
    insert_has_into = false,   -- INSERT has INTO keyword
    in_values = false,         -- Currently inside VALUES clause
    in_update = false,         -- Currently inside UPDATE statement
    in_delete = false,         -- Currently inside DELETE statement
    delete_expecting_alias_or_from = false,  -- After DELETE, expecting alias or FROM
    delete_has_from = false,   -- DELETE has FROM keyword
    delete_expecting_table = false,  -- Expecting table name after DELETE [FROM]
    -- Alias detection tracking (for use_as_keyword)
    in_select_clause = false,  -- Currently in SELECT column list
    in_from_clause = false,    -- Currently in FROM clause
    in_join_clause = false,    -- Currently in JOIN clause (until ON or next clause)
    expecting_alias = false,   -- Next identifier might be an alias (no AS keyword seen)
    last_was_as = false,       -- Previous keyword was AS
  }
end

---Apply keyword casing transformation
---@param text string
---@param keyword_case string "upper"|"lower"|"preserve"
---@return string
function M.apply_keyword_case(text, keyword_case)
  if keyword_case == "upper" then
    return string.upper(text)
  elseif keyword_case == "lower" then
    return string.lower(text)
  else
    return text
  end
end

-- Join modifier keywords
local JOIN_MODIFIERS = {
  INNER = true,
  LEFT = true,
  RIGHT = true,
  FULL = true,
  CROSS = true,
  OUTER = true,
  NATURAL = true,
}

---Check if a keyword is a join modifier (INNER, LEFT, RIGHT, etc.)
---@param text string
---@return boolean
function M.is_join_modifier(text)
  local upper = string.upper(text)
  return JOIN_MODIFIERS[upper] == true
end

-- Major clause keywords
local MAJOR_CLAUSES = {
  SELECT = true,
  FROM = true,
  WHERE = true,
  JOIN = true,
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
  WITH = true,  -- CTE clause
}

---Check if a keyword is a major clause that should start on a new line
---@param text string
---@return boolean
function M.is_major_clause(text)
  local upper = string.upper(text)
  return MAJOR_CLAUSES[upper] == true
end

---Check if token is AND or OR
---@param token table
---@return boolean
function M.is_and_or(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  return upper == "AND" or upper == "OR"
end

---Safe tokenization with error recovery
---@param tokenizer table The tokenizer module
---@param sql string
---@return Token[]|nil tokens
---@return string|nil error_message
function M.safe_tokenize(tokenizer, sql)
  local ok, result = pcall(tokenizer.tokenize, sql)
  if ok then
    return result, nil
  else
    return nil, tostring(result)
  end
end

return M
