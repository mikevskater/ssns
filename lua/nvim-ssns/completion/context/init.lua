---Context detection module
---Entry point dispatcher for all context detection types
---@module ssns.completion.context
local Context = {}

local Tokens = require('nvim-ssns.completion.tokens')
local QualifiedNames = require('nvim-ssns.completion.context.common.qualified_names')
local TableContext = require('nvim-ssns.completion.context.table_context')
local ColumnContext = require('nvim-ssns.completion.context.column_context')
local SpecialContexts = require('nvim-ssns.completion.context.special_contexts')

-- Re-export sub-modules
Context.Table = TableContext
Context.Column = ColumnContext
Context.Special = SpecialContexts
Context.QualifiedNames = QualifiedNames

---Unified context detection from tokens
---Handles all detection in priority order, replacing multiple separate calls
---Priority: OUTPUT patterns > EXEC > INSERT columns > VALUES > MERGE INSERT > ON clause >
---         ALIAS disambiguation > TABLE contexts > COLUMN contexts > DATABASE/SCHEMA > KEYWORD fallback
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@param chunk StatementChunk? Optional parsed statement chunk for alias disambiguation
---@return string ctx_type Context type
---@return string mode Sub-mode for provider routing
---@return table extra Extra context info
function Context.detect(tokens, line, col, chunk)
  if not tokens or #tokens == 0 then
    return "keyword", "start", {}
  end

  local ctx_type, mode, extra

  -- 1. OUTPUT inserted./deleted. detection (highest priority for OUTPUT qualified columns)
  ctx_type, mode, extra = SpecialContexts.detect_output_pseudo_table(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 2. OUTPUT INTO detection (needs TABLE completion)
  ctx_type, mode, extra = SpecialContexts.detect_output_into(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 3. EXEC/EXECUTE detection (procedure context)
  ctx_type, mode, extra = SpecialContexts.detect_other(tokens, line, col)
  if ctx_type == "procedure" then
    return ctx_type, mode, extra
  end

  -- 4. INSERT column list detection
  ctx_type, mode, extra = ColumnContext.detect_insert_columns(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 5. VALUES clause detection
  ctx_type, mode, extra = ColumnContext.detect_values(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 6. MERGE INSERT column list detection
  ctx_type, mode, extra = ColumnContext.detect_merge_insert(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 7. ON clause detection (JOIN conditions)
  ctx_type, mode, extra = ColumnContext.detect_on_clause(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 7b. Chunk-aware alias disambiguation for dot-triggered qualified names
  -- When cursor is after "alias.", check if the qualifier is a known alias from the chunk.
  -- If it is, route to column/qualified instead of letting table context claim it.
  if chunk and chunk.aliases then
    local is_after_dot, qualified = QualifiedNames.is_dot_triggered(tokens, line, col)
    if is_after_dot and qualified and qualified.alias then
      local alias_lower = qualified.alias:lower()
      if chunk.aliases[alias_lower] then
        local ref = QualifiedNames.get_reference_before_dot(tokens, line, col)
        if ref then
          return "column", "qualified", { table_ref = ref, filter_table = ref, omit_table = true }
        end
      end
    end
  end

  -- 8. TABLE context detection (FROM, JOIN, UPDATE, DELETE, INSERT INTO, etc.)
  ctx_type, mode, extra = TableContext.detect(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 9. COLUMN context detection (SELECT, WHERE, SET, ORDER BY, GROUP BY, HAVING)
  ctx_type, mode, extra = ColumnContext.detect(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 10. DATABASE/SCHEMA context detection (USE)
  ctx_type, mode, extra = SpecialContexts.detect_other(tokens, line, col)
  if ctx_type then
    return ctx_type, mode, extra
  end

  -- 11. Check if line is empty or at statement start -> KEYWORD context
  local token_at = Tokens.get_token_at_position(tokens, line, col)
  if not token_at then
    return "keyword", "start", {}
  end

  -- Check for semicolon or GO (statement end)
  local prev_tokens = Tokens.get_tokens_before_cursor(tokens, line, col, 1)
  if #prev_tokens > 0 then
    local last_token = prev_tokens[1]
    if last_token.type == "semicolon" then
      return "keyword", "start", {}
    end
    if last_token.type == "keyword" and last_token.text:upper() == "GO" then
      return "keyword", "start", {}
    end
  end

  -- Default: KEYWORD fallback
  return "keyword", "general", {}
end

---Debug: Print tokens around cursor
---@param tokens Token[] Tokens
---@param line number Cursor line
---@param col number Cursor column
function Context.debug_print(tokens, line, col)
  local token_at, idx = Tokens.get_token_at_position(tokens, line, col)
  local prev_tokens = Tokens.get_tokens_before_cursor(tokens, line, col, 5)

  print(string.format("=== Token Context at line %d, col %d ===", line, col))

  if token_at then
    print(string.format("Token at cursor: [%d] type=%s text='%s' pos=%d:%d",
      idx or 0, token_at.type, token_at.text, token_at.line, token_at.col))
  else
    print("Token at cursor: nil")
  end

  print("Previous tokens (most recent first):")
  for i, t in ipairs(prev_tokens) do
    print(string.format("  [%d] type=%s text='%s' pos=%d:%d",
      i, t.type, t.text, t.line, t.col))
  end

  local is_dot, qualified = QualifiedNames.is_dot_triggered(tokens, line, col)
  print(string.format("Is dot triggered: %s", tostring(is_dot)))
  if qualified then
    print(string.format("Qualified name: parts=%s, has_trailing_dot=%s",
      table.concat(qualified.parts, "."),
      tostring(qualified.has_trailing_dot)))
    print(string.format("  database=%s, schema=%s, table=%s, alias=%s",
      qualified.database or "nil",
      qualified.schema or "nil",
      qualified.table or "nil",
      qualified.alias or "nil"))
  end
end

return Context
