---Special context detection
---Detects PROCEDURE, DATABASE, SCHEMA, and OUTPUT contexts
---@module ssns.completion.context.special_contexts
local SpecialContexts = {}

local Tokens = require('ssns.completion.tokens')
local QualifiedNames = require('ssns.completion.context.common.qualified_names')

---Detect PROCEDURE/DATABASE/SCHEMA context from tokens
---Replaces regex patterns for EXEC/EXECUTE and USE
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("procedure", "database", "schema", or nil)
---@return string? mode Sub-mode for provider routing
---@return table extra Extra context info
function SpecialContexts.detect_other(tokens, line, col)
  local prev_tokens = Tokens.get_tokens_before_cursor(tokens, line, col, 5)
  if #prev_tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- Find the most recent keyword
  local keyword_token = nil
  for _, t in ipairs(prev_tokens) do
    if t.type == "keyword" then
      keyword_token = t
      break
    end
  end

  if not keyword_token then
    return nil, nil, extra
  end

  local kw = keyword_token.text:upper()

  -- EXEC/EXECUTE detection (procedure context)
  if kw == "EXEC" or kw == "EXECUTE" then
    return "procedure", "exec", extra
  end

  -- USE detection (database context)
  if kw == "USE" then
    -- Check if there's a qualified name (db.schema)
    local is_after_dot, qualified = QualifiedNames.is_dot_triggered(tokens, line, col)
    -- Use qualified info for filtering when available (even when typing partial identifier)
    if qualified and qualified.database then
      extra.database = qualified.database
      return "schema", "cross_db", extra
    end
    return "database", "use", extra
  end

  return nil, nil, extra
end

---Detect OUTPUT INTO context from tokens
---Handles pattern: OUTPUT ... INTO |table - needs TABLE completion (not COLUMN)
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("table" or nil if not OUTPUT INTO)
---@return string? mode Sub-mode ("from" for table completion)
---@return table extra Extra context info (is_output_into flag)
function SpecialContexts.detect_output_into(tokens, line, col)
  if not tokens or #tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- Find cursor position
  local _, cursor_idx = Tokens.get_token_at_position(tokens, line, col)
  if not cursor_idx then
    cursor_idx = #tokens
  end

  -- Look backwards for INTO followed by OUTPUT
  local found_into = false
  local found_output = false

  for i = cursor_idx, 1, -1 do
    local t = tokens[i]
    if t.type == "keyword" then
      local kw = t.text:upper()
      if kw == "INTO" and not found_into then
        found_into = true
      elseif kw == "OUTPUT" and found_into then
        found_output = true
        break
      elseif kw == "INSERT" or kw == "SELECT" or kw == "UPDATE" or kw == "DELETE" or kw == "MERGE" then
        -- Hit a statement keyword without finding OUTPUT - not OUTPUT INTO
        break
      end
    end
  end

  if found_output and found_into then
    extra.is_output_into = true
    return "table", "from", extra
  end

  return nil, nil, {}
end

---Detect OUTPUT inserted./deleted. pattern for column completion
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("column" or nil)
---@return string? mode Sub-mode ("output")
---@return table extra Extra context info (is_output_clause, output_pseudo_table, table_ref)
function SpecialContexts.detect_output_pseudo_table(tokens, line, col)
  if not tokens or #tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}
  local prev_tokens = Tokens.get_tokens_before_cursor(tokens, line, col, 15)
  local is_after_dot, _ = QualifiedNames.is_dot_triggered(tokens, line, col)

  if not is_after_dot then
    return nil, nil, {}
  end

  -- Check for OUTPUT inserted. or OUTPUT deleted. pattern
  local found_inserted_or_deleted = nil
  local found_output = false

  for i, t in ipairs(prev_tokens) do
    if t.type == "keyword" then
      local kw = t.text:upper()
      if (kw == "INSERTED" or kw == "DELETED") and not found_inserted_or_deleted then
        found_inserted_or_deleted = kw:lower()
      elseif kw == "OUTPUT" and found_inserted_or_deleted then
        found_output = true
        break
      elseif kw == "INSERT" or kw == "UPDATE" or kw == "DELETE" or kw == "MERGE" or kw == "SELECT" then
        break
      end
    elseif t.type == "dot" and found_inserted_or_deleted and i <= 2 then
      -- The dot we're after is right after INSERTED/DELETED
      -- Continue checking for OUTPUT
    end
  end

  if found_output and found_inserted_or_deleted then
    extra = {
      is_output_clause = true,
      output_pseudo_table = found_inserted_or_deleted,
      table_ref = found_inserted_or_deleted,
    }
    return "column", "output", extra
  end

  return nil, nil, {}
end

return SpecialContexts
