---Table context detection
---Detects TABLE completion contexts (FROM, JOIN, UPDATE, DELETE, INSERT INTO, etc.)
---@module ssns.completion.context.table_context
local TableContext = {}

local Tokens = require('ssns.completion.tokens')
local QualifiedNames = require('ssns.completion.context.common.qualified_names')

---Detect TABLE context from tokens
---Replaces regex patterns for FROM, JOIN, UPDATE, DELETE, INSERT INTO, TRUNCATE, ALTER, MERGE, USING
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("table" or nil if not table context)
---@return string? mode Sub-mode for provider routing (from, join, update, delete, insert, etc.)
---@return table extra Extra context info (filter_schema, filter_database, etc.)
function TableContext.detect(tokens, line, col)
  local prev_tokens = Tokens.get_tokens_before_cursor(tokens, line, col, 10)
  if #prev_tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- Find the most recent keyword in the token stream
  local keyword_token = nil
  local keyword_idx = nil
  local second_keyword_token = nil
  local second_keyword_idx = nil

  for i, t in ipairs(prev_tokens) do
    if t.type == "keyword" then
      if not keyword_token then
        keyword_token = t
        keyword_idx = i
      elseif not second_keyword_token then
        second_keyword_token = t
        second_keyword_idx = i
        break
      end
    end
  end

  if not keyword_token then
    return nil, nil, extra
  end

  local kw = keyword_token.text:upper()
  local second_kw = second_keyword_token and second_keyword_token.text:upper() or nil

  -- Check for qualified name after keyword using token-based detection
  local is_after_dot, qualified = QualifiedNames.is_dot_triggered(tokens, line, col)

  -- Helper to set qualified name extra fields
  local function set_qualified_extra(qual)
    if qual.database then
      extra.database = qual.database
      extra.schema = qual.schema
      extra.filter_database = qual.database
      extra.filter_schema = qual.schema
      extra.omit_schema = true
    elseif qual.schema then
      extra.potential_database = qual.schema
      extra.schema = qual.schema
      extra.filter_schema = qual.schema
      extra.omit_schema = true
    end
  end

  -- FROM detection
  if kw == "FROM" then
    -- Use qualified info for filtering when available (even when typing partial identifier)
    if qualified and (qualified.database or qualified.schema) then
      set_qualified_extra(qualified)
      if qualified.database then
        return "table", "from_cross_db_qualified", extra
      elseif qualified.schema then
        return "table", "from_qualified", extra
      end
    end
    return "table", "from", extra
  end

  -- JOIN detection (including modifiers)
  -- Patterns: JOIN, INNER JOIN, LEFT JOIN, LEFT OUTER JOIN, RIGHT JOIN, etc.
  if kw == "JOIN" then
    -- Use qualified info for filtering when available (even when typing partial identifier)
    if qualified and (qualified.database or qualified.schema) then
      set_qualified_extra(qualified)
      if qualified.database then
        return "table", "join_cross_db_qualified", extra
      elseif qualified.schema then
        return "table", "join_qualified", extra
      end
    end
    return "table", "join", extra
  end

  -- Check for JOIN modifiers (INNER, LEFT, RIGHT, FULL, CROSS, OUTER followed by JOIN)
  if (kw == "INNER" or kw == "LEFT" or kw == "RIGHT" or kw == "FULL" or kw == "CROSS" or kw == "OUTER") then
    -- Look for JOIN as the next keyword
    if second_kw == "JOIN" then
      return "table", "join", extra
    end
    -- Could also be "LEFT OUTER JOIN" or "RIGHT OUTER JOIN" or "FULL OUTER JOIN"
    -- In that case, kw is OUTER and we need to check if there's JOIN before it
    -- But if kw is one of LEFT/RIGHT/FULL and we didn't find JOIN, check next tokens
    -- Actually, with "LEFT OUTER JOIN", the token order would be JOIN, OUTER, LEFT
    -- So if kw is LEFT and second_kw is OUTER, we need to check if there's a JOIN
    for i = keyword_idx + 1, #prev_tokens do
      local t = prev_tokens[i]
      if t.type == "keyword" and t.text:upper() == "JOIN" then
        return "table", "join", extra
      elseif t.type == "keyword" then
        break -- Stop at any other keyword
      end
    end
  end

  -- UPDATE detection
  if kw == "UPDATE" then
    -- Use qualified info for filtering when available (even when typing partial identifier)
    if qualified and (qualified.database or qualified.schema) then
      set_qualified_extra(qualified)
    end
    return "table", "update", extra
  end

  -- DELETE detection
  -- Patterns: DELETE FROM, DELETE (without FROM)
  if kw == "DELETE" then
    return "table", "delete", extra
  end
  if kw == "FROM" and second_kw == "DELETE" then
    return "table", "delete", extra
  end

  -- TRUNCATE TABLE detection
  if kw == "TABLE" and second_kw == "TRUNCATE" then
    return "table", "truncate", extra
  end

  -- ALTER TABLE detection
  if kw == "TABLE" and second_kw == "ALTER" then
    return "table", "alter", extra
  end

  -- INSERT INTO detection
  if kw == "INTO" and second_kw == "INSERT" then
    -- Use qualified info for filtering when available (even when typing partial identifier)
    if qualified and (qualified.database or qualified.schema) then
      set_qualified_extra(qualified)
    end
    return "table", "insert", extra
  end

  -- MERGE INTO detection
  if kw == "INTO" and second_kw == "MERGE" then
    -- Use qualified info for filtering when available (even when typing partial identifier)
    if qualified and (qualified.database or qualified.schema) then
      set_qualified_extra(qualified)
    end
    return "table", "merge", extra
  end

  -- MERGE USING detection
  if kw == "USING" then
    -- Use qualified info for filtering when available (even when typing partial identifier)
    if qualified and (qualified.database or qualified.schema) then
      set_qualified_extra(qualified)
      if qualified.database then
        return "table", "merge_cross_db_qualified", extra
      elseif qualified.schema then
        return "table", "merge_qualified", extra
      end
    end
    return "table", "merge", extra
  end

  return nil, nil, extra
end

return TableContext
