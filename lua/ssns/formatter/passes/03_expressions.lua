---@class ExpressionsPass
---Pass 3: Mark expression contexts (BETWEEN, CASE, IN, functions)
---This pass annotates tokens with expression context so later passes don't need to track state.
---
---Annotations added:
---  token.in_between        - true if inside BETWEEN...AND expression
---  token.is_between_and    - true if this AND belongs to BETWEEN (not boolean AND)
---  token.is_boolean_and    - true if this AND is a boolean operator
---  token.in_case           - true if inside CASE...END expression
---  token.case_depth        - nesting depth of CASE expressions
---  token.in_in_list        - true if inside IN(...) list
---  token.in_function_call  - true if inside function arguments
---  token.function_depth    - nesting depth of function calls
local ExpressionsPass = {}

-- =============================================================================
-- Helper Functions
-- =============================================================================

---Check if token is a keyword with given text
---@param token table
---@param keyword string
---@return boolean
local function is_keyword(token, keyword)
  return token.type == "keyword" and string.upper(token.text) == keyword
end

---Check if token is BETWEEN keyword
---@param token table
---@return boolean
local function is_between_keyword(token)
  return token.is_between_keyword or is_keyword(token, "BETWEEN")
end

---Check if token is AND keyword
---@param token table
---@return boolean
local function is_and_keyword(token)
  return is_keyword(token, "AND")
end

---Check if token is OR keyword
---@param token table
---@return boolean
local function is_or_keyword(token)
  return is_keyword(token, "OR")
end

---Check if token is CASE keyword
---@param token table
---@return boolean
local function is_case_keyword(token)
  return is_keyword(token, "CASE")
end

---Check if token is END keyword
---@param token table
---@return boolean
local function is_end_keyword(token)
  return is_keyword(token, "END")
end

---Check if token is IN keyword
---@param token table
---@return boolean
local function is_in_keyword(token)
  return is_keyword(token, "IN")
end

---Check if token is a clause boundary keyword
---@param token table
---@return boolean
local function is_clause_boundary(token)
  if token.type ~= "keyword" then return false end
  local upper = string.upper(token.text)
  local boundaries = {
    WHERE = true, FROM = true, GROUP = true, ORDER = true,
    HAVING = true, UNION = true, EXCEPT = true, INTERSECT = true,
    JOIN = true, ON = true, SET = true, SELECT = true,
    INSERT = true, UPDATE = true, DELETE = true, VALUES = true,
  }
  return boundaries[upper] == true
end

---Check if token is a SQL function
---@param token table
---@return boolean
local function is_function_keyword(token)
  -- Check keyword_category from tokenizer (primary source)
  -- or is_function flag if set by earlier pass
  return token.keyword_category == "function" or token.is_function or false
end

-- =============================================================================
-- Pass Implementation
-- =============================================================================

---Run the expressions pass on tokens
---@param tokens table[] Array of tokens
---@param context table FormatterContext object
---@return table[] Annotated tokens
function ExpressionsPass.run(tokens, context)
  -- State tracking (local to this pass)
  local between_stack = {}    -- Stack for nested BETWEEN (rare but possible in subqueries)
  local case_stack = {}       -- Stack for nested CASE expressions
  local in_list_stack = {}    -- Stack for nested IN lists
  local function_stack = {}   -- Stack for nested function calls

  -- Pending flags for detecting patterns
  local pending_in = false    -- Saw IN, waiting for open paren

  for i, token in ipairs(tokens) do
    -- ---------------------------------------------------------------------
    -- BETWEEN Tracking
    -- ---------------------------------------------------------------------
    -- Detect BETWEEN keyword
    if is_between_keyword(token) then
      table.insert(between_stack, {
        start_index = i,
        saw_first_value = false,
      })
    end

    -- Mark if we're inside BETWEEN context
    token.in_between = #between_stack > 0

    -- Handle AND - is it BETWEEN AND or boolean AND?
    if is_and_keyword(token) then
      if #between_stack > 0 then
        -- This AND belongs to BETWEEN
        token.is_between_and = true
        token.is_boolean_and = false
        -- Pop the BETWEEN context (BETWEEN x AND y is complete)
        table.remove(between_stack)
      else
        -- Regular boolean AND
        token.is_between_and = false
        token.is_boolean_and = true
      end
    end

    -- Handle OR - always boolean, also clears any stuck BETWEEN context
    if is_or_keyword(token) then
      token.is_boolean_or = true
      -- OR at the same level as BETWEEN means BETWEEN is done
      -- (e.g., "x BETWEEN 1 AND 2 OR y = 3" - the OR ends BETWEEN context)
      if #between_stack > 0 then
        between_stack = {}
      end
    end

    -- Clause boundaries reset BETWEEN context
    if is_clause_boundary(token) and #between_stack > 0 then
      between_stack = {}
    end

    -- ---------------------------------------------------------------------
    -- CASE Tracking
    -- ---------------------------------------------------------------------
    -- Detect CASE keyword
    if is_case_keyword(token) then
      table.insert(case_stack, {
        start_index = i,
        indent_level = token.indent_level or 0,
      })
    end

    -- Mark CASE context
    token.in_case = #case_stack > 0
    token.case_depth = #case_stack

    -- Handle END - pops CASE context
    if is_end_keyword(token) and #case_stack > 0 then
      -- Check if this END belongs to a CASE (not BEGIN...END)
      -- For now, assume END after CASE is CASE END
      -- A more robust implementation would track BEGIN separately
      table.remove(case_stack)
      token.is_case_end = true
    end

    -- ---------------------------------------------------------------------
    -- IN List Tracking
    -- ---------------------------------------------------------------------
    -- Detect IN keyword
    if is_in_keyword(token) then
      pending_in = true
    end

    -- IN followed by open paren starts IN list
    if pending_in and token.type == "paren_open" then
      pending_in = false
      table.insert(in_list_stack, {
        start_index = i,
        paren_depth = 1,
      })
    elseif pending_in and token.type ~= "whitespace" and token.type ~= "comment" then
      -- Something other than paren after IN - not an IN list
      pending_in = false
    end

    -- Track IN list state
    if #in_list_stack > 0 then
      local current = in_list_stack[#in_list_stack]

      if token.type == "paren_open" then
        current.paren_depth = current.paren_depth + 1
      elseif token.type == "paren_close" then
        current.paren_depth = current.paren_depth - 1
        if current.paren_depth <= 0 then
          -- Exit IN list
          table.remove(in_list_stack)
        end
      end
    end

    token.in_in_list = #in_list_stack > 0

    -- ---------------------------------------------------------------------
    -- Function Call Tracking
    -- ---------------------------------------------------------------------
    -- Detect function keyword followed by paren
    if is_function_keyword(token) then
      -- Look ahead for open paren
      local next_idx = i + 1
      while next_idx <= #tokens do
        local next_token = tokens[next_idx]
        if next_token.type == "paren_open" then
          -- This is a function call - mark it
          token.starts_function_call = true
          break
        elseif next_token.type ~= "whitespace" and next_token.type ~= "comment" then
          -- Something else before paren - not a function call
          break
        end
        next_idx = next_idx + 1
      end
    end

    -- Handle function call tracking via paren
    if token.starts_function_call then
      -- Will be handled when we see the paren
    end

    if token.type == "paren_open" then
      -- Check if previous non-whitespace token was a function
      local prev_idx = i - 1
      while prev_idx >= 1 do
        local prev_token = tokens[prev_idx]
        if prev_token.type ~= "whitespace" and prev_token.type ~= "comment" then
          if prev_token.starts_function_call or is_function_keyword(prev_token) then
            table.insert(function_stack, {
              start_index = i,
              paren_depth = 1,
              arg_count = 1,
            })
            token.is_function_open = true  -- Mark opening paren of function call
          end
          break
        end
        prev_idx = prev_idx - 1
      end
    end

    -- Track function call state
    if #function_stack > 0 then
      local current = function_stack[#function_stack]

      if token.type == "paren_open" and i > current.start_index then
        current.paren_depth = current.paren_depth + 1
      elseif token.type == "paren_close" then
        current.paren_depth = current.paren_depth - 1
        if current.paren_depth <= 0 then
          -- Exit function call
          table.remove(function_stack)
        end
      elseif token.type == "comma" and current.paren_depth == 1 then
        -- Comma at function's own paren depth separates arguments
        current.arg_count = current.arg_count + 1
        token.is_function_arg_separator = true
      end
    end

    token.in_function_call = #function_stack > 0
    token.function_depth = #function_stack
  end

  return tokens
end

---Get pass information
---@return table Pass metadata
function ExpressionsPass.info()
  return {
    name = "expressions",
    order = 3,
    description = "Mark expression contexts (BETWEEN, CASE, IN, functions)",
    annotations = {
      "in_between", "is_between_and", "is_boolean_and",
      "in_case", "case_depth", "is_case_end",
      "in_in_list",
      "in_function_call", "function_depth", "is_function_arg_separator",
    },
  }
end

return ExpressionsPass
