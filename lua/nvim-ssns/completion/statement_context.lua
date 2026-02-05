---Statement-based context detection for SQL completion
---
---Architecture:
---  - Uses StatementCache/StatementChunk for clause position tracking
---  - Uses TokenContext for all token-based detection (no regex patterns)
---  - Supports multi-line SQL statements with accurate cursor position detection
---
---Detection Flow:
---  1. _detect_special_cases() - OUTPUT, EXEC, INSERT columns, ON clause
---  2. _detect_from_clause() - Clause-based detection if chunk available
---  3. TokenContext.detect_context() - Unified token-based fallback
---
---Key Functions:
---  - Context.detect() - Simple context detection
---  - Context.detect_full() - Full detection with should_complete flag
---@module ssns.completion.statement_context
local Debug = require('nvim-ssns.debug')
local StatementCache = require('nvim-ssns.completion.statement_cache')
local TokenContext = require('nvim-ssns.completion.token_context')
local ClauseContext = require('nvim-ssns.completion.context.clause_context')
local Subquery = require('nvim-ssns.completion.context.subquery')

local Context = {}

---Context types
Context.Type = {
  UNKNOWN = "unknown",
  KEYWORD = "keyword",
  DATABASE = "database",
  SCHEMA = "schema",
  TABLE = "table",
  COLUMN = "column",
  PROCEDURE = "procedure",
  PARAMETER = "parameter",
  ALIAS = "alias",
}

---Detect special cases that have highest priority (before clause-based routing)
---These patterns need to be checked first because they override normal clause detection
---Uses TOKEN-BASED detection for multi-line SQL support
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type or nil if no special case
---@return string? mode Sub-mode for provider routing
---@return table? extra Extra context info
function Context._detect_special_cases(tokens, line, col)
  local ctx_type, mode, extra

  -- 1. OUTPUT inserted./deleted. detection (highest priority for OUTPUT qualified columns)
  local is_after_dot, _ = TokenContext.is_dot_triggered(tokens, line, col)
  if is_after_dot then
    local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line, col, 15)
    local found_inserted_or_deleted = nil
    local found_output = false

    for _, t in ipairs(prev_tokens) do
      local upper_text = t.text:upper()
      if (t.type == "keyword" or t.type == "identifier") and
         (upper_text == "INSERTED" or upper_text == "DELETED") and not found_inserted_or_deleted then
        found_inserted_or_deleted = upper_text:lower()
      elseif t.type == "keyword" then
        if upper_text == "OUTPUT" and found_inserted_or_deleted then
          found_output = true
          break
        elseif upper_text == "INSERT" or upper_text == "UPDATE" or upper_text == "DELETE" or
               upper_text == "MERGE" or upper_text == "SELECT" then
          break
        end
      end
    end

    if found_output and found_inserted_or_deleted then
      return Context.Type.COLUMN, "output", {
        is_output_clause = true,
        output_pseudo_table = found_inserted_or_deleted,
        table_ref = found_inserted_or_deleted,
      }
    end
  end

  -- 2. OUTPUT INTO table detection (needs TABLE completion, not COLUMN)
  ctx_type, mode, extra = TokenContext.detect_output_into_from_tokens(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 3. EXEC/EXECUTE detection (procedure context)
  ctx_type, mode, extra = TokenContext.detect_other_context_from_tokens(tokens, line, col)
  if ctx_type == "procedure" then
    return ctx_type, mode, extra
  end

  -- 4. INSERT column list detection
  ctx_type, mode, extra = TokenContext.detect_insert_columns_from_tokens(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 5. MERGE INSERT column list detection (WHEN NOT MATCHED THEN INSERT (columns))
  ctx_type, mode, extra = TokenContext.detect_merge_insert_from_tokens(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 6. ON clause detection (JOIN conditions)
  ctx_type, mode, extra = TokenContext.detect_on_clause_from_tokens(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  return nil, nil, nil
end

---Build tables_in_scope array from cache_ctx.tables
---@param cache_ctx table StatementCache context
---@return table[] tables_in_scope Array of table references
local function build_tables_in_scope(cache_ctx)
  local tables_in_scope = {}
  local seen_ctes = {}
  local seen_subqueries = {}
  local seen_temp_tables = {}

  -- If we detected subquery tables, use those instead of outer query tables
  if cache_ctx and cache_ctx._subquery_tables then
    Debug.log(string.format("[statement_context] Using %d subquery tables", #cache_ctx._subquery_tables))
    for _, sq_table in ipairs(cache_ctx._subquery_tables) do
      table.insert(tables_in_scope, {
        alias = sq_table.alias,
        table = sq_table.table,
        name = sq_table.name,
        schema = sq_table.schema,
        scope = "subquery",
      })
    end
    return tables_in_scope
  end

  if not cache_ctx or not cache_ctx.tables then
    return tables_in_scope
  end

  for _, table_ref in ipairs(cache_ctx.tables) do
    -- Preserve CTE entries with their columns
    if table_ref.is_cte then
      local cte_name = table_ref.name
      if not seen_ctes[cte_name:lower()] then
        seen_ctes[cte_name:lower()] = true
        local cte_columns = table_ref.columns
        if (not cte_columns or #cte_columns == 0) and cache_ctx.ctes then
          local cte_def = cache_ctx.ctes[cte_name] or cache_ctx.ctes[cte_name:lower()]
          if cte_def then
            cte_columns = cte_def.columns
          end
        end
        table.insert(tables_in_scope, {
          name = cte_name,
          is_cte = true,
          columns = cte_columns,
        })
      end
    elseif table_ref.is_temp_table then
      local temp_name = table_ref.name
      if temp_name and not seen_temp_tables[temp_name:lower()] then
        seen_temp_tables[temp_name:lower()] = true
        local temp_columns = table_ref.columns
        if (not temp_columns or #temp_columns == 0) and cache_ctx.temp_tables then
          local temp_def = cache_ctx.temp_tables[temp_name] or cache_ctx.temp_tables[temp_name:lower()]
          if temp_def then
            temp_columns = temp_def.columns
          end
        end
        table.insert(tables_in_scope, {
          name = temp_name,
          alias = table_ref.alias,
          is_temp_table = true,
          is_global = table_ref.is_global,
          columns = temp_columns,
        })
      end
    elseif table_ref.is_subquery then
      local sq_name = table_ref.name or table_ref.alias
      if sq_name and not seen_subqueries[sq_name:lower()] then
        seen_subqueries[sq_name:lower()] = true
        table.insert(tables_in_scope, {
          name = sq_name,
          alias = table_ref.alias,
          is_subquery = true,
          columns = table_ref.columns,
        })
      end
    elseif table_ref.is_tvf then
      local tvf_name = table_ref.alias or table_ref.name
      if tvf_name then
        table.insert(tables_in_scope, {
          name = table_ref.name,
          alias = table_ref.alias,
          schema = table_ref.schema,
          is_tvf = true,
          function_name = table_ref.function_name or table_ref.name,
        })
      end
    else
      local table_name = table_ref.name
      if table_ref.schema then
        table_name = table_ref.schema .. "." .. table_ref.name
      end
      if table_ref.database then
        table_name = table_ref.database .. "." .. table_name
      end
      table.insert(tables_in_scope, {
        alias = table_ref.alias,
        table = table_name,
        scope = "main",
      })
    end
  end

  return tables_in_scope
end

---Convert aliases from {alias_lower -> TableReference} to {alias_lower -> table_name_string}
---@param cache_ctx table StatementCache context
---@return table aliases_map Converted alias map
local function build_aliases_map(cache_ctx)
  local aliases_map = {}
  if not cache_ctx or not cache_ctx.aliases then
    return aliases_map
  end

  for alias_lower, table_ref in pairs(cache_ctx.aliases) do
    local table_name = table_ref.name
    if table_ref.schema then
      table_name = table_ref.schema .. "." .. table_ref.name
    end
    if table_ref.database then
      table_name = table_ref.database .. "." .. table_name
    end
    aliases_map[alias_lower] = table_name
  end

  return aliases_map
end

---Main context detection (simple version without full checks)
---@param bufnr number Buffer number
---@param line_num number 1-indexed line number
---@param col number 1-indexed column
---@param tokens? Token[] Optional pre-fetched tokens (avoids redundant cache lookup)
---@return table context Context information
function Context.detect(bufnr, line_num, col, tokens)
  Debug.log(string.format("[statement_context] detect: bufnr=%d, line=%d, col=%d", bufnr, line_num, col))

  -- Get line text
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if #lines == 0 then
    return {
      type = Context.Type.UNKNOWN,
      mode = "unknown",
      prefix = "",
      trigger = nil,
      chunk = nil,
      tables = {},
      aliases = {},
      ctes = {},
      temp_tables = {},
      subquery = nil,
    }
  end

  -- Get tokens for buffer
  tokens = tokens or TokenContext.get_buffer_tokens(bufnr)

  -- Get StatementCache context
  local cache_ctx = StatementCache.get_context_at_position(bufnr, line_num, col)

  -- Extract prefix and trigger using token-based detection
  local prefix, trigger = TokenContext.extract_prefix_and_trigger(tokens, line_num, col)

  -- Detect type using clause positions first, fallback to unified token-based detection
  local ctx_type, mode, extra
  local chunk = cache_ctx and cache_ctx.chunk

  -- Try special cases first (highest priority)
  ctx_type, mode, extra = Context._detect_special_cases(tokens, line_num, col)

  if not ctx_type and chunk then
    -- Use clause-based detection if chunk is available
    ctx_type, mode, extra = ClauseContext.detect_from_clause(
      bufnr, line_num, col, tokens, chunk, cache_ctx,
      Subquery.detect_unparsed
    )
  end

  if not ctx_type then
    -- Final fallback: unified token-based detection
    ctx_type, mode, extra = TokenContext.detect_context(tokens, line_num, col)
  end

  extra = extra or {}

  -- Build context result
  local context = {
    type = ctx_type,
    mode = mode,
    prefix = prefix,
    trigger = trigger,

    -- Pass through StatementCache data
    chunk = cache_ctx and cache_ctx.chunk,
    tables = cache_ctx and cache_ctx.tables or {},
    aliases = build_aliases_map(cache_ctx),
    ctes = cache_ctx and cache_ctx.ctes or {},
    temp_tables = cache_ctx and cache_ctx.temp_tables or {},
    subquery = cache_ctx and cache_ctx.subquery,
    tables_in_scope = build_tables_in_scope(cache_ctx),

    -- Extra context from type detection
    table_ref = extra.table_ref,
    schema = extra.schema,
    database = extra.database,
    filter_schema = extra.filter_schema,
    filter_database = extra.filter_database,
    filter_table = extra.filter_table,
    potential_database = extra.potential_database,
    omit_schema = extra.omit_schema,
    omit_table = extra.omit_table,
    value_position = extra.value_position,
    left_side = extra.left_side,
    insert_table = extra.insert_table,
    insert_schema = extra.insert_schema,
    table = extra.table,
  }

  Debug.log(string.format("[statement_context] detected type=%s, mode=%s, prefix=%s", ctx_type, mode, prefix))

  return context
end

---Full context detection with all checks (entry point for blink.cmp)
---@param bufnr number Buffer number
---@param line_num number 1-indexed line number
---@param col number 1-indexed column
---@return table context Full context with should_complete flag
function Context.detect_full(bufnr, line_num, col)
  Debug.log(string.format("[statement_context] detect_full: bufnr=%d, line=%d, col=%d", bufnr, line_num, col))

  -- Get line text
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if #lines == 0 then
    return {
      type = Context.Type.UNKNOWN,
      mode = "unknown",
      prefix = "",
      trigger = nil,
      should_complete = false,
      line = "",
      line_num = line_num,
      col = col,
      chunk = nil,
      tables = {},
      aliases = {},
      ctes = {},
      temp_tables = {},
      subquery = nil,
    }
  end

  local line = lines[1]

  -- Check if in comment or string using token-based detection
  local tokens = TokenContext.get_buffer_tokens(bufnr)
  if TokenContext.is_in_string_or_comment(tokens, line_num, col) then
    local token_at = TokenContext.get_token_at_position(tokens, line_num, col)
    local mode = "string_or_comment"
    if token_at then
      if token_at.type == "comment" or token_at.type == "line_comment" then
        mode = "comment"
        Debug.log("[statement_context] Inside comment (token-based), skipping completion")
      elseif token_at.type == "string" then
        mode = "string"
        Debug.log("[statement_context] Inside string (token-based), skipping completion")
      end
    end
    return {
      type = Context.Type.UNKNOWN,
      mode = mode,
      prefix = "",
      trigger = nil,
      should_complete = false,
      line = line,
      line_num = line_num,
      col = col,
      chunk = nil,
      tables = {},
      aliases = {},
      ctes = {},
      temp_tables = {},
      subquery = nil,
    }
  end

  -- Get basic context (pass tokens to avoid redundant cache lookup)
  local context = Context.detect(bufnr, line_num, col, tokens)

  -- Add full check fields
  context.should_complete = context.type ~= Context.Type.UNKNOWN
  context.line = line
  context.line_num = line_num
  context.col = col

  Debug.log(string.format("[statement_context] detect_full result: should_complete=%s, type=%s, mode=%s",
    tostring(context.should_complete), context.type, context.mode))

  return context
end

return Context
