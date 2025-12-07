---@class FormatterState
---@field indent_level number Current indentation depth
---@field line_length number Characters on current line
---@field paren_depth number Parenthesis nesting depth
---@field in_subquery boolean Currently inside subquery
---@field clause_stack string[] Stack of active clauses
---@field last_token Token? Previous token processed
---@field current_clause string? Current clause being processed
---@field join_modifier string? Pending join modifier (INNER, LEFT, RIGHT, etc.)

---@class FormatterEngine
---Core formatting engine that processes token streams and applies transformation rules.
---Uses best-effort error handling - formats what it can, preserves the rest.
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
  }
end

---Apply keyword casing transformation
---@param text string
---@param keyword_case string "upper"|"lower"|"preserve"
---@return string
local function apply_keyword_case(text, keyword_case)
  if keyword_case == "upper" then
    return string.upper(text)
  elseif keyword_case == "lower" then
    return string.lower(text)
  else
    return text
  end
end

---Check if a keyword is a join modifier (INNER, LEFT, RIGHT, etc.)
---@param text string
---@return boolean
local function is_join_modifier(text)
  local upper = string.upper(text)
  local modifiers = {
    INNER = true,
    LEFT = true,
    RIGHT = true,
    FULL = true,
    CROSS = true,
    OUTER = true,
    NATURAL = true,
  }
  return modifiers[upper] == true
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
  return major_clauses[upper] == true
end

---Check if token is AND or OR
---@param token table
---@return boolean
local function is_and_or(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  return upper == "AND" or upper == "OR"
end

---Safe tokenization with error recovery
---@param sql string
---@return Token[]|nil tokens
---@return string|nil error_message
local function safe_tokenize(sql)
  local ok, result = pcall(Tokenizer.tokenize, sql)
  if ok then
    return result, nil
  else
    return nil, tostring(result)
  end
end

---Format SQL text with error recovery
---@param sql string The SQL text to format
---@param config FormatterConfig The formatter configuration
---@param opts? {dialect?: string} Optional formatting options
---@return string formatted The formatted SQL text
function Engine.format(sql, config, opts)
  opts = opts or {}

  -- Handle empty input
  if not sql or sql == "" then
    return sql
  end

  -- Safe tokenization - return original on failure
  local tokens, err = safe_tokenize(sql)
  if not tokens or #tokens == 0 then
    -- Best effort: return original SQL if tokenization fails
    return sql
  end

  -- Create formatter state
  local state = create_state()

  -- Process tokens with error recovery
  local ok, processed_or_error = pcall(function()
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

      -- Handle multi-word keywords (INNER JOIN, LEFT OUTER JOIN, etc.)
      if token.type == "keyword" then
        local upper = string.upper(token.text)

        -- Check for join modifiers
        if is_join_modifier(upper) then
          -- Look ahead to see if JOIN follows
          local next_idx = i + 1
          while next_idx <= #tokens and
                (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end

          if next_idx <= #tokens and tokens[next_idx].type == "keyword" then
            local next_upper = string.upper(tokens[next_idx].text)
            if next_upper == "JOIN" or next_upper == "OUTER" then
              -- This is a join modifier - mark it but don't skip newline
              -- The output generator handles keeping INNER/LEFT/etc. together with JOIN
              processed.is_join_modifier = true
              state.join_modifier = upper
            end
          end
        end

        -- Handle OUTER keyword (in LEFT OUTER JOIN)
        -- Just mark it, output generator handles newline logic
        if upper == "OUTER" then
          local next_idx = i + 1
          while next_idx <= #tokens and
                (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end

          if next_idx <= #tokens and tokens[next_idx].type == "keyword" and
             string.upper(tokens[next_idx].text) == "JOIN" then
            processed.is_join_modifier = true
          end
        end

        -- Handle JOIN keyword - check if preceded by modifier
        if upper == "JOIN" and state.join_modifier then
          processed.combined_keyword = state.join_modifier .. " " .. upper
          state.join_modifier = nil
        end

        -- Handle GROUP and ORDER keywords (for GROUP BY, ORDER BY)
        -- Mark that BY follows, but don't skip newline - ORDER/GROUP should start new line
        if upper == "GROUP" or upper == "ORDER" then
          local next_idx = i + 1
          while next_idx <= #tokens and
                (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end

          if next_idx <= #tokens and tokens[next_idx].type == "keyword" and
             string.upper(tokens[next_idx].text) == "BY" then
            processed.has_by_following = true
          end
        end

        -- Handle BY keyword after GROUP/ORDER
        if upper == "BY" then
          -- Look back to see if this follows GROUP or ORDER
          local prev_idx = i - 1
          while prev_idx >= 1 and
                (tokens[prev_idx].type == "comment" or tokens[prev_idx].type == "line_comment") do
            prev_idx = prev_idx - 1
          end

          if prev_idx >= 1 and tokens[prev_idx].type == "keyword" then
            local prev_upper = string.upper(tokens[prev_idx].text)
            if prev_upper == "GROUP" or prev_upper == "ORDER" then
              processed.part_of_compound = true
            end
          end
        end

        -- Handle CTE (WITH clause) tracking
        if upper == "WITH" then
          state.in_cte = true
          state.cte_name_expected = true
          processed.is_cte_start = true
        elseif upper == "RECURSIVE" and state.in_cte and state.cte_name_expected then
          -- RECURSIVE stays with WITH
          processed.is_cte_recursive = true
        elseif upper == "AS" and state.cte_as_expected then
          -- AS keyword in CTE context
          processed.is_cte_as = true
          state.cte_as_expected = false
          state.cte_body_start = true
        elseif (upper == "SELECT" or upper == "INSERT" or upper == "UPDATE" or upper == "DELETE") and state.in_cte and not state.cte_body_start and state.paren_depth == 0 then
          -- Main query after CTE - CTE section is done
          state.in_cte = false
        end

        -- Handle CASE expression tracking
        if upper == "CASE" then
          -- Push current indent onto case stack and start CASE expression
          table.insert(state.case_stack, {
            indent_level = state.indent_level,
          })
          state.in_case = true
          processed.is_case_start = true
          processed.case_indent = state.indent_level
          -- Increase indent for WHEN/THEN/ELSE inside CASE
          state.indent_level = state.indent_level + config.case_indent
        elseif upper == "WHEN" and state.in_case then
          processed.is_case_when = true
          processed.case_indent = state.indent_level
        elseif upper == "THEN" and state.in_case then
          processed.is_case_then = true
        elseif upper == "ELSE" and state.in_case then
          processed.is_case_else = true
          processed.case_indent = state.indent_level
        elseif upper == "END" and state.in_case then
          -- Pop from case stack and restore indent
          if #state.case_stack > 0 then
            local case_info = table.remove(state.case_stack)
            state.indent_level = case_info.indent_level
            processed.is_case_end = true
            processed.case_indent = case_info.indent_level
            state.in_case = #state.case_stack > 0
          end
        end

        -- Apply keyword casing
        processed.text = apply_keyword_case(token.text, config.keyword_case)
      elseif token.type == "go" then
        processed.text = apply_keyword_case(token.text, config.keyword_case)
      end

      -- Track clause context
      if token.type == "keyword" and is_major_clause(token.text) then
        state.current_clause = string.upper(token.text)
      end

      -- Handle CTE name identifier
      if (token.type == "identifier" or token.type == "bracket_id") and state.cte_name_expected then
        processed.is_cte_name = true
        state.cte_name_expected = false
        state.cte_as_expected = true
      end

      -- Preserve comments - pass through with metadata
      if token.type == "comment" or token.type == "line_comment" then
        processed.is_comment = true
        -- Check if comment follows code on same line (inline comment)
        if state.last_token and state.last_token.line == token.line then
          processed.is_inline_comment = true
        else
          processed.is_standalone_comment = true
        end
      end

      -- Track parenthesis depth and subqueries/CTEs
      if token.type == "paren_open" then
        state.paren_depth = state.paren_depth + 1

        -- Check if this is a CTE body start
        if state.cte_body_start then
          -- Push CTE body onto stack (similar to subquery)
          table.insert(state.cte_stack, {
            paren_depth = state.paren_depth,
            indent_level = state.indent_level,
          })
          state.indent_level = state.indent_level + config.subquery_indent
          processed.starts_cte_body = true
          state.cte_body_start = false
        else
          -- Check if this might be a subquery (next significant token is SELECT)
          local next_idx = i + 1
          while next_idx <= #tokens and
                (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end
          if next_idx <= #tokens and tokens[next_idx].type == "keyword" and
             string.upper(tokens[next_idx].text) == "SELECT" then
            -- Push current state onto subquery stack before entering subquery
            table.insert(state.subquery_stack, {
              paren_depth = state.paren_depth,
              indent_level = state.indent_level,
            })
            state.in_subquery = true
            state.indent_level = state.indent_level + config.subquery_indent
            processed.starts_subquery = true
          end
        end
      elseif token.type == "paren_close" then
        -- Check if we're closing a CTE body
        if #state.cte_stack > 0 then
          local top = state.cte_stack[#state.cte_stack]
          if state.paren_depth == top.paren_depth then
            -- Pop from CTE stack
            table.remove(state.cte_stack)
            state.indent_level = top.indent_level
            processed.ends_cte_body = true
          end
        end
        -- Check if we're closing a subquery
        if #state.subquery_stack > 0 then
          local top = state.subquery_stack[#state.subquery_stack]
          if state.paren_depth == top.paren_depth then
            -- Pop from subquery stack
            table.remove(state.subquery_stack)
            state.indent_level = top.indent_level
            state.in_subquery = #state.subquery_stack > 0
            processed.ends_subquery = true
          end
        end
        state.paren_depth = math.max(0, state.paren_depth - 1)
      elseif token.type == "comma" and state.in_cte and state.paren_depth == 0 then
        -- Comma between CTEs - expect another CTE name
        state.cte_name_expected = true
        processed.is_cte_separator = true
      end

      processed.indent_level = state.indent_level
      processed.paren_depth = state.paren_depth
      processed.current_clause = state.current_clause
      processed.in_subquery = state.in_subquery

      table.insert(processed_tokens, processed)
      state.last_token = token
    end

    return processed_tokens
  end)

  if not ok then
    -- Error during token processing - return original
    return sql
  end

  -- Generate output with error recovery
  local output_ok, output_or_error = pcall(Output.generate, processed_or_error, config)
  if not output_ok then
    -- Error during output generation - return original
    return sql
  end

  return output_or_error
end

---Format with statement-level error recovery
---Attempts to format each statement independently, preserving failed ones
---@param sql string The SQL text to format
---@param config FormatterConfig The formatter configuration
---@param opts? {dialect?: string} Optional formatting options
---@return string formatted The formatted SQL text
function Engine.format_with_recovery(sql, config, opts)
  opts = opts or {}

  -- Try to split into statements by semicolon or GO
  local statements = {}
  local current = {}
  local in_string = false
  local string_char = nil

  for i = 1, #sql do
    local char = sql:sub(i, i)

    -- Track string state
    if not in_string and (char == "'" or char == '"') then
      in_string = true
      string_char = char
    elseif in_string and char == string_char then
      in_string = false
    end

    table.insert(current, char)

    -- Check for statement separator
    if not in_string and char == ";" then
      table.insert(statements, table.concat(current))
      current = {}
    end
  end

  -- Don't forget the last statement
  if #current > 0 then
    table.insert(statements, table.concat(current))
  end

  -- Format each statement independently
  local results = {}
  for _, stmt in ipairs(statements) do
    local trimmed = stmt:match("^%s*(.-)%s*$")
    if trimmed and trimmed ~= "" then
      local formatted = Engine.format(stmt, config, opts)
      table.insert(results, formatted)
    end
  end

  return table.concat(results, "\n")
end

return Engine
