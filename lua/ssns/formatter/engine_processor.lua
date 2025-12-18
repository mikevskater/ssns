---@class FormatterEngineProcessor
---Token processing for the formatter engine.
---Transforms raw tokens into annotated tokens with formatting metadata.
local M = {}

local Helpers = require('ssns.formatter.engine_helpers')

-- Local aliases
local is_join_modifier = Helpers.is_join_modifier
local is_major_clause = Helpers.is_major_clause

---Process tokens and annotate them with formatting metadata
---@param tokens Token[] Input tokens from tokenizer
---@param config table Formatter configuration
---@param state FormatterState Formatter state
---@return table[] Processed tokens with annotations
function M.process_tokens(tokens, config, state)
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

      -- Handle BETWEEN keyword (for BETWEEN ... AND expressions)
      if upper == "BETWEEN" then
        processed.is_between_keyword = true
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
end

---@class ProcessTokensAsyncOpts
---@field batch_size number? Tokens to process per batch (default 500)
---@field on_progress fun(processed: number, total: number)? Progress callback
---@field on_complete fun(processed_tokens: table[])? Completion callback (required)

---Active async processing state
---@type { timer: number?, cancelled: boolean }?
M._async_state = nil

---Process tokens asynchronously in batches to avoid blocking UI for large files
---@param tokens Token[] Input tokens from tokenizer
---@param config table Formatter configuration
---@param state FormatterState Formatter state
---@param opts ProcessTokensAsyncOpts Options for async processing
function M.process_tokens_async(tokens, config, state, opts)
  opts = opts or {}
  local batch_size = opts.batch_size or 500
  local on_progress = opts.on_progress
  local on_complete = opts.on_complete

  local total_tokens = #tokens

  -- Cancel any existing async processing
  M.cancel_async_processing()

  -- For small token counts, use sync processing
  if total_tokens <= batch_size then
    local processed = M.process_tokens(tokens, config, state)
    if on_progress then on_progress(total_tokens, total_tokens) end
    if on_complete then on_complete(processed) end
    return
  end

  -- Initialize async state
  M._async_state = {
    timer = nil,
    cancelled = false,
  }

  local async_state = M._async_state
  local processed_tokens = {}
  local current_idx = 1

  ---Process one batch of tokens
  ---@return boolean done True if processing is complete
  local function process_batch()
    local batch_end = math.min(current_idx + batch_size - 1, total_tokens)

    for i = current_idx, batch_end do
      if async_state.cancelled then
        return true
      end

      local token = tokens[i]
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
          local next_idx = i + 1
          while next_idx <= total_tokens and
                (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end

          if next_idx <= total_tokens and tokens[next_idx].type == "keyword" then
            local next_upper = string.upper(tokens[next_idx].text)
            if next_upper == "JOIN" or next_upper == "OUTER" then
              processed.is_join_modifier = true
              state.join_modifier = upper
            end
          end
        end

        -- Handle OUTER keyword
        if upper == "OUTER" then
          local next_idx = i + 1
          while next_idx <= total_tokens and
                (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end

          if next_idx <= total_tokens and tokens[next_idx].type == "keyword" and
             string.upper(tokens[next_idx].text) == "JOIN" then
            processed.is_join_modifier = true
          end
        end

        -- Handle JOIN keyword
        if upper == "JOIN" and state.join_modifier then
          processed.combined_keyword = state.join_modifier .. " " .. upper
          state.join_modifier = nil
        end

        -- Handle GROUP and ORDER keywords
        if upper == "GROUP" or upper == "ORDER" then
          local next_idx = i + 1
          while next_idx <= total_tokens and
                (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end

          if next_idx <= total_tokens and tokens[next_idx].type == "keyword" and
             string.upper(tokens[next_idx].text) == "BY" then
            processed.has_by_following = true
          end
        end

        -- Handle BY keyword
        if upper == "BY" then
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

        -- Handle BETWEEN keyword
        if upper == "BETWEEN" then
          processed.is_between_keyword = true
        end

        -- Handle CTE tracking
        if upper == "WITH" then
          state.in_cte = true
          state.cte_name_expected = true
          processed.is_cte_start = true
        elseif upper == "RECURSIVE" and state.in_cte and state.cte_name_expected then
          processed.is_cte_recursive = true
        elseif upper == "AS" and state.cte_as_expected then
          processed.is_cte_as = true
          state.cte_as_expected = false
          state.cte_body_start = true
        elseif (upper == "SELECT" or upper == "INSERT" or upper == "UPDATE" or upper == "DELETE") and state.in_cte and not state.cte_body_start and state.paren_depth == 0 then
          state.in_cte = false
        end

        -- Handle OVER clause tracking
        if upper == "OVER" then
          state.in_over = true
          processed.is_over_start = true
        elseif upper == "PARTITION" and state.in_over then
          processed.is_over_partition = true
          processed.in_over_clause = true
        elseif upper == "ORDER" and state.in_over then
          processed.is_over_order = true
          processed.in_over_clause = true
        elseif upper == "BY" and state.in_over then
          processed.in_over_clause = true
        elseif upper == "ROWS" or upper == "RANGE" then
          if state.in_over then
            processed.in_over_clause = true
          end
        end

        -- Handle OUTPUT clause
        if upper == "OUTPUT" then
          processed.is_output_clause = true
          local next_idx = i + 1
          while next_idx <= total_tokens and
                (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end
          if next_idx <= total_tokens and tokens[next_idx].type == "keyword" then
            local next_upper = string.upper(tokens[next_idx].text)
            if next_upper == "INSERTED" or next_upper == "DELETED" then
              processed.output_target = next_upper
            end
          end
        elseif upper == "INSERTED" or upper == "DELETED" then
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

        -- Handle MERGE statement
        if upper == "MERGE" then
          state.in_merge = true
          processed.is_merge_start = true
        elseif upper == "USING" and state.in_merge then
          processed.is_merge_using = true
        elseif upper == "WHEN" and state.in_merge then
          processed.is_merge_when = true
          local next_idx = i + 1
          while next_idx <= total_tokens and
                (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end
          if next_idx <= total_tokens and tokens[next_idx].type == "keyword" then
            local next_upper = string.upper(tokens[next_idx].text)
            if next_upper == "MATCHED" or next_upper == "NOT" then
              processed.merge_when_type = next_upper == "NOT" and "not_matched" or "matched"
            end
          end
        elseif upper == "MATCHED" and state.in_merge then
          processed.is_merge_matched = true
        end

        -- Handle INSERT statement
        if upper == "INSERT" then
          state.in_insert = true
          state.insert_expecting_table = true
          state.insert_has_into = false
          processed.is_insert_start = true
        elseif upper == "INTO" and state.in_insert then
          state.insert_has_into = true
          state.insert_expecting_table = true
          processed.is_insert_into = true
        elseif upper == "VALUES" then
          state.in_values = true
          state.insert_expecting_table = false
          processed.is_values_keyword = true
          if state.in_insert then
            state.in_insert = false
          end
        end

        -- Handle UPDATE statement
        if upper == "UPDATE" then
          state.in_update = true
          processed.is_update_start = true
        elseif upper == "SET" and state.in_update then
          processed.is_update_set = true
        elseif upper == "FROM" and state.in_update then
          processed.is_update_from = true
        end

        -- Handle DELETE statement
        if upper == "DELETE" then
          state.in_delete = true
          state.delete_expecting_alias_or_from = true
          state.delete_has_from = false
          state.delete_expecting_table = true
          processed.is_delete_start = true
        elseif upper == "FROM" and state.in_delete then
          state.delete_has_from = true
          state.delete_expecting_table = true
          processed.is_delete_from = true
          state.delete_expecting_alias_or_from = false
          state.in_delete = false
        end

        -- Handle CASE expression
        if upper == "CASE" then
          table.insert(state.case_stack, {
            indent_level = state.indent_level,
          })
          state.in_case = true
          processed.is_case_start = true
          processed.case_indent = state.indent_level
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
          if #state.case_stack > 0 then
            local case_info = table.remove(state.case_stack)
            state.indent_level = case_info.indent_level
            processed.is_case_end = true
            processed.case_indent = case_info.indent_level
            state.in_case = #state.case_stack > 0
          end
        end

        processed.text = token.text
      elseif token.type == "go" then
        processed.text = token.text
      end

      -- Track clause context
      if token.type == "keyword" and is_major_clause(token.text) then
        state.current_clause = string.upper(token.text)
      end

      -- Track clause state for alias detection
      if token.type == "keyword" then
        local upper = string.upper(token.text)
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
          state.last_was_as = true
          state.expecting_alias = false
        end
      end

      -- Detect aliases that need AS keyword
      if config.use_as_keyword and (token.type == "identifier" or token.type == "bracket_id") then
        if state.expecting_alias and not state.last_was_as then
          processed.needs_as_keyword = true
        end
        state.last_was_as = false

        if state.in_from_clause or state.in_join_clause then
          local next_idx = i + 1
          while next_idx <= total_tokens and tokens[next_idx].type == "whitespace" do
            next_idx = next_idx + 1
          end
          if next_idx <= total_tokens and tokens[next_idx].type == "dot" then
            state.expecting_alias = false
          else
            state.expecting_alias = true
          end
        elseif state.in_select_clause then
          state.expecting_alias = true
        else
          state.expecting_alias = false
        end
      elseif token.type == "comma" then
        state.expecting_alias = false
        state.last_was_as = false
      elseif token.type == "dot" then
        state.expecting_alias = false
        state.last_was_as = false
      elseif token.type ~= "whitespace" and token.type ~= "comment" and token.type ~= "line_comment" then
        state.last_was_as = false
      end

      -- Handle CTE name identifier
      if (token.type == "identifier" or token.type == "bracket_id") and state.cte_name_expected then
        processed.is_cte_name = true
        state.cte_name_expected = false
        state.cte_as_expected = true
      end

      -- Handle DELETE alias
      if (token.type == "identifier" or token.type == "bracket_id") and state.delete_expecting_alias_or_from then
        processed.is_delete_alias = true
        state.delete_expecting_alias_or_from = false
      end

      -- Handle INSERT table name
      if (token.type == "identifier" or token.type == "bracket_id") and state.in_insert and state.insert_expecting_table then
        if not state.insert_has_into then
          processed.needs_into_keyword = true
        end
        state.insert_expecting_table = false
      end

      -- Handle DELETE table name
      if (token.type == "identifier" or token.type == "bracket_id") and state.in_delete and state.delete_expecting_table then
        if not state.delete_has_from then
          local next_idx = i + 1
          while next_idx <= total_tokens and
                (tokens[next_idx].type == "whitespace" or tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end

          local from_follows = false
          if next_idx <= total_tokens and tokens[next_idx].type == "keyword" and
             string.upper(tokens[next_idx].text) == "FROM" then
            from_follows = true
          end

          if not from_follows then
            processed.needs_from_keyword = true
          end
        end
        state.delete_expecting_table = false
      end

      -- Preserve comments
      if token.type == "comment" or token.type == "line_comment" then
        processed.is_comment = true
        if state.last_token and state.last_token.line == token.line then
          processed.is_inline_comment = true
        else
          processed.is_standalone_comment = true
        end
      end

      -- Track parenthesis depth and subqueries/CTEs
      if token.type == "paren_open" then
        state.paren_depth = state.paren_depth + 1

        if state.in_over and state.over_paren_depth == 0 then
          state.over_paren_depth = state.paren_depth
          processed.starts_over_body = true
        end

        if state.cte_body_start then
          table.insert(state.cte_stack, {
            paren_depth = state.paren_depth,
            indent_level = state.indent_level,
          })
          state.indent_level = state.indent_level + config.subquery_indent
          processed.starts_cte_body = true
          state.cte_body_start = false
        else
          local next_idx = i + 1
          while next_idx <= total_tokens and
                (tokens[next_idx].type == "comment" or tokens[next_idx].type == "line_comment") do
            next_idx = next_idx + 1
          end
          if next_idx <= total_tokens and tokens[next_idx].type == "keyword" and
             string.upper(tokens[next_idx].text) == "SELECT" then
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
            table.insert(state.subquery_stack, {
              paren_depth = state.paren_depth,
              indent_level = state.indent_level,
              context = subquery_context,
            })
            state.in_subquery = true
            state.indent_level = state.indent_level + config.subquery_indent
            processed.starts_subquery = true
            processed.subquery_context = subquery_context
          end
        end
      elseif token.type == "paren_close" then
        if state.in_over and state.paren_depth == state.over_paren_depth then
          state.in_over = false
          state.over_paren_depth = 0
          processed.ends_over_body = true
        end
        if #state.cte_stack > 0 then
          local top = state.cte_stack[#state.cte_stack]
          if state.paren_depth == top.paren_depth then
            table.remove(state.cte_stack)
            state.indent_level = top.indent_level
            processed.ends_cte_body = true
          end
        end
        if #state.subquery_stack > 0 then
          local top = state.subquery_stack[#state.subquery_stack]
          if state.paren_depth == top.paren_depth then
            table.remove(state.subquery_stack)
            state.indent_level = top.indent_level
            state.in_subquery = #state.subquery_stack > 0
            processed.ends_subquery = true
          end
        end
        state.paren_depth = math.max(0, state.paren_depth - 1)
      elseif token.type == "comma" and state.in_cte and state.paren_depth == 0 then
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

    current_idx = batch_end + 1
    return current_idx > total_tokens
  end

  ---Process next batch with yield
  local function process_next()
    if async_state.cancelled then
      M._async_state = nil
      return
    end

    local done = process_batch()

    if on_progress then
      on_progress(math.min(current_idx - 1, total_tokens), total_tokens)
    end

    if done then
      M._async_state = nil
      if on_complete then
        on_complete(processed_tokens)
      end
    else
      -- Schedule next batch
      async_state.timer = vim.fn.timer_start(0, function()
        async_state.timer = nil
        vim.schedule(process_next)
      end)
    end
  end

  -- Start processing
  process_next()
end

---Cancel any in-progress async processing
function M.cancel_async_processing()
  if M._async_state then
    M._async_state.cancelled = true
    if M._async_state.timer then
      vim.fn.timer_stop(M._async_state.timer)
      M._async_state.timer = nil
    end
    M._async_state = nil
  end
end

---Check if async processing is currently in progress
---@return boolean
function M.is_async_processing_active()
  return M._async_state ~= nil and not M._async_state.cancelled
end

return M
