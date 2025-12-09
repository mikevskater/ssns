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
local Stats = require('ssns.formatter.stats')

-- High-resolution timer
local hrtime = vim.loop.hrtime

---@class TokenCache
---@field entries table<string, {tokens: Token[], timestamp: number}>
---@field max_entries number Maximum cache entries
---@field ttl_ns number Time-to-live in nanoseconds
local TokenCache = {
  entries = {},
  max_entries = 100,
  ttl_ns = 60 * 1000000000, -- 60 seconds
}

---Simple hash function for cache key
---@param sql string
---@return string
local function hash_sql(sql)
  -- Use a combination of length and sampled characters for fast hashing
  local len = #sql
  if len <= 64 then
    return sql
  end
  -- Sample characters at regular intervals + length
  local parts = { tostring(len) }
  local step = math.floor(len / 8)
  for i = 1, len, step do
    table.insert(parts, sql:sub(i, i))
  end
  table.insert(parts, sql:sub(-16))
  return table.concat(parts)
end

---Get cached tokens or nil
---@param sql string
---@return Token[]|nil
function TokenCache.get(sql)
  local key = hash_sql(sql)
  local entry = TokenCache.entries[key]
  if entry then
    local now = hrtime()
    if now - entry.timestamp < TokenCache.ttl_ns then
      return entry.tokens
    end
    -- Expired
    TokenCache.entries[key] = nil
  end
  return nil
end

---Cache tokens
---@param sql string
---@param tokens Token[]
function TokenCache.set(sql, tokens)
  local key = hash_sql(sql)
  TokenCache.entries[key] = {
    tokens = tokens,
    timestamp = hrtime(),
  }

  -- Evict old entries if over limit
  local count = 0
  for _ in pairs(TokenCache.entries) do
    count = count + 1
  end

  if count > TokenCache.max_entries then
    -- Remove oldest entries
    local oldest_key, oldest_time = nil, math.huge
    for k, v in pairs(TokenCache.entries) do
      if v.timestamp < oldest_time then
        oldest_key = k
        oldest_time = v.timestamp
      end
    end
    if oldest_key then
      TokenCache.entries[oldest_key] = nil
    end
  end
end

---Clear the token cache
function TokenCache.clear()
  TokenCache.entries = {}
end

-- Export cache for external use
Engine.cache = TokenCache

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
---Default formatter configuration values
---These are applied when config values are nil
local DEFAULT_CONFIG = {
  -- Basic formatting
  enabled = true,
  indent_style = "space",
  indent_size = 4,
  keyword_case = "upper",
  max_line_length = 120,
  newline_before_clause = true,
  align_aliases = false,
  align_columns = false,
  comma_position = "trailing",
  and_or_position = "leading",
  operator_spacing = true,
  parenthesis_spacing = false,
  join_on_same_line = false,
  -- Phase 1: SELECT/FROM/WHERE/JOIN
  select_distinct_newline = false,
  select_top_newline = false,
  select_into_newline = false,
  empty_line_before_join = false,
  on_and_position = "leading",
  where_and_or_indent = 1,
  -- Phase 2: DML/Grouping
  update_set_style = "stacked",
  group_by_style = "inline",
  order_by_style = "inline",
  insert_columns_style = "inline",
  insert_values_style = "inline",
  insert_multi_row_style = "stacked",
  insert_into_keyword = false,  -- Enforce INTO keyword in INSERT (default: false for backward compat)
  output_clause_newline = true,
  merge_when_newline = true,
  -- Phase 2: CTE
  cte_as_position = "same_line",
  cte_parenthesis_style = "same_line",
  cte_separator_newline = true,
  cte_indent = 1,
  -- Phase 3: Casing
  function_case = "upper",
  datatype_case = "upper",
  identifier_case = "preserve",
  alias_case = "preserve",
  use_as_keyword = false,  -- Always use AS for column/table aliases (default: false for backward compat)
  -- Phase 3: Spacing
  comma_spacing = "after",
  semicolon_spacing = false,
  bracket_spacing = false,
  equals_spacing = true,
  comparison_spacing = true,
  concatenation_spacing = true,
  -- Phase 3: Blank lines
  blank_line_before_clause = false,
  blank_line_between_statements = 1,
  blank_line_after_go = 1,
  collapse_blank_lines = true,
  max_consecutive_blank_lines = 2,
  blank_line_before_comment = false,
  -- Phase 4: Expressions
  case_style = "stacked",
  case_then_position = "same_line",
  boolean_operator_newline = false,
  -- Phase 5: Advanced
  union_indent = 0,
  continuation_indent = 1,
  -- Indentation
  subquery_indent = 1,
  case_indent = 1,
  -- DELETE formatting
  delete_from_newline = true,    -- FROM on new line after DELETE (default: true)
  delete_alias_newline = false,  -- Alias on own line after DELETE (default: false, keeps DELETE s together)
  delete_from_keyword = false,   -- Enforce FROM keyword in DELETE (default: false for backward compat)
}

---Merge provided config with defaults
---@param config table? Provided config
---@return table Merged config with defaults applied
local function merge_config_with_defaults(config)
  if not config then
    return DEFAULT_CONFIG
  end

  local merged = {}
  for k, v in pairs(DEFAULT_CONFIG) do
    if config[k] ~= nil then
      merged[k] = config[k]
    else
      merged[k] = v
    end
  end
  -- Also copy any additional keys from config that aren't in defaults
  for k, v in pairs(config) do
    if merged[k] == nil then
      merged[k] = v
    end
  end
  return merged
end

---@param opts? {dialect?: string, skip_stats?: boolean} Optional formatting options
---@return string formatted The formatted SQL text
function Engine.format(sql, config, opts)
  opts = opts or {}
  local skip_stats = opts.skip_stats

  -- Merge config with defaults to ensure all values are present
  config = merge_config_with_defaults(config)

  -- Handle empty input
  if not sql or sql == "" then
    return sql
  end

  local total_start = hrtime()
  local tokenization_time = 0
  local processing_time = 0
  local output_time = 0
  local cache_hit = false
  local token_count = 0

  -- Try cache first
  local tokens = TokenCache.get(sql)
  if tokens then
    cache_hit = true
  else
    -- Safe tokenization - return original on failure
    local tokenize_start = hrtime()
    local err
    tokens, err = safe_tokenize(sql)
    tokenization_time = hrtime() - tokenize_start

    if not tokens or #tokens == 0 then
      -- Best effort: return original SQL if tokenization fails
      if not skip_stats then
        Stats.record({
          total_ns = hrtime() - total_start,
          input_size = #sql,
          cache_hit = false,
        })
      end
      return sql
    end

    -- Cache the tokens
    TokenCache.set(sql, tokens)
  end

  token_count = #tokens

  -- Create formatter state
  local state = create_state()

  -- Process tokens with error recovery
  local process_start = hrtime()
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

        -- Handle OVER clause (window function) tracking
        if upper == "OVER" then
          state.in_over = true
          processed.is_over_start = true
        elseif upper == "PARTITION" and state.in_over then
          processed.is_over_partition = true
          processed.in_over_clause = true
        elseif upper == "ORDER" and state.in_over then
          -- ORDER BY inside OVER clause
          processed.is_over_order = true
          processed.in_over_clause = true
        elseif upper == "BY" and state.in_over then
          processed.in_over_clause = true
        elseif upper == "ROWS" or upper == "RANGE" then
          if state.in_over then
            processed.in_over_clause = true
          end
        end

        -- Handle OUTPUT clause (SQL Server INSERT/UPDATE/DELETE OUTPUT)
        if upper == "OUTPUT" then
          processed.is_output_clause = true
          -- Check if INSERTED or DELETED follows
          local next_idx = i + 1
          while next_idx <= #tokens and
                (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end
          if next_idx <= #tokens and tokens[next_idx].type == "keyword" then
            local next_upper = string.upper(tokens[next_idx].text)
            if next_upper == "INSERTED" or next_upper == "DELETED" then
              processed.output_target = next_upper
            end
          end
        elseif upper == "INSERTED" or upper == "DELETED" then
          -- Check if preceded by OUTPUT
          local prev_idx = i - 1
          while prev_idx >= 1 and
                (tokens[prev_idx].type == "comment" or tokens[prev_idx].type == "line_comment") do
            prev_idx = prev_idx - 1
          end
          if prev_idx >= 1 and tokens[prev_idx].type == "keyword" and
             string.upper(tokens[prev_idx].text) == "OUTPUT" then
            processed.is_output_target = true
          end
        end

        -- Handle MERGE statement tracking
        if upper == "MERGE" then
          state.in_merge = true
          processed.is_merge_start = true
        elseif upper == "USING" and state.in_merge then
          processed.is_merge_using = true
        elseif upper == "WHEN" and state.in_merge then
          processed.is_merge_when = true
          -- Check for MATCHED/NOT MATCHED
          local next_idx = i + 1
          while next_idx <= #tokens and
                (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end
          if next_idx <= #tokens and tokens[next_idx].type == "keyword" then
            local next_upper = string.upper(tokens[next_idx].text)
            if next_upper == "MATCHED" or next_upper == "NOT" then
              processed.merge_when_type = next_upper == "NOT" and "not_matched" or "matched"
            end
          end
        elseif upper == "MATCHED" and state.in_merge then
          processed.is_merge_matched = true
        end

        -- Handle INSERT statement tracking
        if upper == "INSERT" then
          state.in_insert = true
          state.insert_expecting_table = true
          state.insert_has_into = false  -- Track if INTO keyword is present
          processed.is_insert_start = true
        elseif upper == "INTO" and state.in_insert then
          -- INTO after INSERT
          state.insert_has_into = true
          state.insert_expecting_table = true  -- Now expecting table name
          processed.is_insert_into = true
        elseif upper == "VALUES" then
          state.in_values = true
          state.insert_expecting_table = false
          processed.is_values_keyword = true
          if state.in_insert then
            state.in_insert = false
          end
        end

        -- Handle UPDATE statement tracking
        if upper == "UPDATE" then
          state.in_update = true
          processed.is_update_start = true
        elseif upper == "SET" and state.in_update then
          processed.is_update_set = true
        elseif upper == "FROM" and state.in_update then
          -- SQL Server UPDATE...FROM syntax
          processed.is_update_from = true
        end

        -- Handle DELETE statement tracking
        if upper == "DELETE" then
          state.in_delete = true
          state.delete_expecting_alias_or_from = true
          state.delete_has_from = false  -- Track if FROM keyword is present
          state.delete_expecting_table = true  -- Expecting table name after DELETE [FROM]
          processed.is_delete_start = true
        elseif upper == "FROM" and state.in_delete then
          state.delete_has_from = true
          state.delete_expecting_table = true  -- Now expecting table name
          processed.is_delete_from = true
          state.delete_expecting_alias_or_from = false
          state.in_delete = false  -- FROM ends the DELETE-specific tracking
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

        -- Casing is handled by output.lua's apply_token_casing()
        -- which supports keyword_case, function_case, datatype_case, identifier_case, alias_case
        processed.text = token.text
      elseif token.type == "go" then
        -- Casing handled by output.lua
        processed.text = token.text
      end

      -- Track clause context
      if token.type == "keyword" and is_major_clause(token.text) then
        state.current_clause = string.upper(token.text)
      end

      -- Track clause state for alias detection (use_as_keyword)
      if token.type == "keyword" then
        local upper = string.upper(token.text)
        -- Track when entering/exiting clauses
        if upper == "SELECT" then
          state.in_select_clause = true
          state.in_from_clause = false
          state.in_join_clause = false
          state.expecting_alias = false
        elseif upper == "FROM" then
          state.in_select_clause = false
          state.in_from_clause = true
          state.in_join_clause = false
          state.expecting_alias = false
        elseif upper == "JOIN" then
          state.in_select_clause = false
          state.in_from_clause = false
          state.in_join_clause = true
          state.expecting_alias = false
        elseif upper == "ON" or upper == "WHERE" or upper == "GROUP" or upper == "ORDER" or
               upper == "HAVING" or upper == "UNION" or upper == "EXCEPT" or upper == "INTERSECT" or
               upper == "INTO" or upper == "SET" or upper == "VALUES" then
          state.in_select_clause = false
          state.in_from_clause = false
          state.in_join_clause = false
          state.expecting_alias = false
        elseif upper == "AS" then
          -- AS keyword seen - next identifier is an alias but doesn't need AS inserted
          state.last_was_as = true
          state.expecting_alias = false
        end
      end

      -- Detect aliases that need AS keyword inserted
      if config.use_as_keyword and (token.type == "identifier" or token.type == "bracket_id") then
        -- Check if this identifier might be an alias (no AS before it)
        if state.expecting_alias and not state.last_was_as then
          -- This looks like an alias without AS - mark it for AS insertion
          processed.needs_as_keyword = true
        end
        state.last_was_as = false

        -- After seeing an identifier in FROM/JOIN, the next identifier might be an alias
        if state.in_from_clause or state.in_join_clause then
          -- After table name, next identifier could be alias
          -- But not if this is part of a dotted name (schema.table)
          local next_idx = i + 1
          while next_idx <= #tokens and tokens[next_idx].type == "whitespace" do
            next_idx = next_idx + 1
          end
          -- If next token is a dot, this is part of a qualified name, not followed by alias
          if next_idx <= #tokens and tokens[next_idx].type == "dot" then
            state.expecting_alias = false
          else
            state.expecting_alias = true
          end
        elseif state.in_select_clause then
          -- In SELECT, after identifier/expression, next identifier could be alias
          -- This is tricky - need to check if followed by comma or keyword
          state.expecting_alias = true
        else
          state.expecting_alias = false
        end
      elseif token.type == "comma" then
        -- Comma resets alias expectation - next item is a new column/table
        state.expecting_alias = false
        state.last_was_as = false
      elseif token.type == "dot" then
        -- Dot means we're in qualified name - don't expect alias right after
        state.expecting_alias = false
        state.last_was_as = false
      elseif token.type ~= "whitespace" and token.type ~= "comment" and token.type ~= "line_comment" then
        -- Other tokens reset AS tracking
        state.last_was_as = false
      end

      -- Handle CTE name identifier
      if (token.type == "identifier" or token.type == "bracket_id") and state.cte_name_expected then
        processed.is_cte_name = true
        state.cte_name_expected = false
        state.cte_as_expected = true
      end

      -- Handle DELETE alias (e.g., DELETE s FROM dbo.Table s)
      if (token.type == "identifier" or token.type == "bracket_id") and state.delete_expecting_alias_or_from then
        processed.is_delete_alias = true
        state.delete_expecting_alias_or_from = false
        -- Still in_delete, waiting for FROM
      end

      -- Handle INSERT table name (detect if INTO is missing)
      -- Pattern: INSERT tablename ... (without INTO)
      if (token.type == "identifier" or token.type == "bracket_id") and state.in_insert and state.insert_expecting_table then
        if not state.insert_has_into then
          -- Table name directly after INSERT without INTO - mark for INTO insertion
          processed.needs_into_keyword = true
        end
        state.insert_expecting_table = false
      end

      -- Handle DELETE table name (detect if FROM is missing)
      -- Pattern: DELETE tablename ... (without FROM)
      -- Note: SQL Server allows DELETE alias FROM table alias syntax, so we need to be careful
      -- We only mark the first identifier after DELETE as needing FROM if:
      -- 1. FROM hasn't been seen yet, AND
      -- 2. FROM doesn't follow this identifier (look ahead)
      if (token.type == "identifier" or token.type == "bracket_id") and state.in_delete and state.delete_expecting_table then
        if not state.delete_has_from then
          -- Look ahead to see if FROM follows (skip whitespace/comments)
          local next_idx = i + 1
          while next_idx <= #tokens and
                (tokens[next_idx].type == "whitespace" or tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end

          -- Check if next significant token is FROM
          local from_follows = false
          if next_idx <= #tokens and tokens[next_idx].type == "keyword" and
             string.upper(tokens[next_idx].text) == "FROM" then
            from_follows = true
          end

          if not from_follows then
            -- Table name directly after DELETE without FROM following - mark for FROM insertion
            processed.needs_from_keyword = true
          end
          -- If FROM follows, this is the alias in "DELETE alias FROM table" syntax - don't add FROM
        end
        state.delete_expecting_table = false
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

        -- Check if this starts an OVER clause body
        if state.in_over and state.over_paren_depth == 0 then
          state.over_paren_depth = state.paren_depth
          processed.starts_over_body = true
        end

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
            -- Check for subquery context (EXISTS, IN, NOT IN, etc.)
            local subquery_context = nil
            local prev_idx = i - 1
            while prev_idx >= 1 and
                  (tokens[prev_idx].type == "comment" or tokens[prev_idx].type == "line_comment") do
              prev_idx = prev_idx - 1
            end
            if prev_idx >= 1 and tokens[prev_idx].type == "keyword" then
              local prev_upper = string.upper(tokens[prev_idx].text)
              if prev_upper == "EXISTS" or prev_upper == "IN" or prev_upper == "ANY" or
                 prev_upper == "ALL" or prev_upper == "SOME" then
                subquery_context = prev_upper
              end
            end
            -- Push current state onto subquery stack before entering subquery
            table.insert(state.subquery_stack, {
              paren_depth = state.paren_depth,
              indent_level = state.indent_level,
              context = subquery_context,  -- Track subquery context (EXISTS, IN, etc.)
            })
            state.in_subquery = true
            state.indent_level = state.indent_level + config.subquery_indent
            processed.starts_subquery = true
            processed.subquery_context = subquery_context
          end
        end
      elseif token.type == "paren_close" then
        -- Check if we're closing an OVER clause body
        if state.in_over and state.paren_depth == state.over_paren_depth then
          state.in_over = false
          state.over_paren_depth = 0
          processed.ends_over_body = true
        end
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
  processing_time = hrtime() - process_start

  if not ok then
    -- Error during token processing - return original
    if not skip_stats then
      Stats.record({
        tokenization_ns = tokenization_time,
        processing_ns = processing_time,
        total_ns = hrtime() - total_start,
        input_size = #sql,
        token_count = token_count,
        cache_hit = cache_hit,
      })
    end
    return sql
  end

  -- Generate output with error recovery
  local output_start = hrtime()
  local output_ok, output_or_error = pcall(Output.generate, processed_or_error, config)
  output_time = hrtime() - output_start

  -- Record stats
  if not skip_stats then
    Stats.record({
      tokenization_ns = tokenization_time,
      processing_ns = processing_time,
      output_ns = output_time,
      total_ns = hrtime() - total_start,
      input_size = #sql,
      token_count = token_count,
      cache_hit = cache_hit,
    })
  end

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
