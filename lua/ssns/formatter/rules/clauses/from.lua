---@class FromRule
---@field name string Rule name
---FROM clause formatting rules.
---Handles table references, table aliases, derived tables.
---Note: JOIN logic is in clauses/join.lua
local From = {
  name = "from",
}

local Join = require('ssns.formatter.rules.clauses.join')

-- =============================================================================
-- FROM Clause Detection
-- =============================================================================

---Check if token is FROM keyword
---@param token table
---@return boolean
function From.is_from(token)
  return token.type == "keyword" and string.upper(token.text) == "FROM"
end

---Check if token is AS keyword
---@param token table
---@return boolean
function From.is_as(token)
  return token.type == "keyword" and string.upper(token.text) == "AS"
end

---Check if token ends the FROM clause
---@param token table
---@return boolean
function From.is_from_terminator(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  local terminators = {
    WHERE = true,
    GROUP = true,
    ORDER = true,
    HAVING = true,
    UNION = true,
    INTERSECT = true,
    EXCEPT = true,
    FOR = true,  -- FOR UPDATE, etc.
  }
  return terminators[upper] == true
end

---Check if token is a table hint keyword (WITH, NOLOCK, etc.)
---@param token table
---@return boolean
function From.is_table_hint(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  local hints = {
    NOLOCK = true,
    ROWLOCK = true,
    UPDLOCK = true,
    XLOCK = true,
    HOLDLOCK = true,
    READUNCOMMITTED = true,
    READCOMMITTED = true,
    REPEATABLEREAD = true,
    SERIALIZABLE = true,
    TABLOCK = true,
    TABLOCKX = true,
    PAGLOCK = true,
    READPAST = true,
    NOWAIT = true,
  }
  return hints[upper] == true
end

-- =============================================================================
-- Table Reference Parsing
-- =============================================================================

---Parse a table reference (table name with optional alias)
---@param tokens table[] All tokens
---@param start_idx number Index to start parsing
---@return table table_ref {name_tokens: table[], alias: string?, has_as: boolean, end_idx: number}
function From.parse_table_reference(tokens, start_idx)
  local ref = {
    name_tokens = {},
    alias = nil,
    has_as = false,
    end_idx = start_idx,
  }

  local idx = start_idx
  local paren_depth = 0

  -- First, collect the table name (may be schema.table or just table)
  while idx <= #tokens do
    local token = tokens[idx]

    -- Track parenthesis for subqueries/derived tables
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth == 0 then
        -- End of subquery/derived table
        table.insert(ref.name_tokens, token)
        idx = idx + 1
        break
      end
    end

    -- End conditions (only at paren_depth 0)
    if paren_depth == 0 then
      if token.type == "comma" then
        break
      elseif Join.is_join_type(token) or From.is_from_terminator(token) or Join.is_on(token) then
        break
      elseif token.type == "semicolon" then
        break
      end
    end

    -- AS keyword starts alias
    if paren_depth == 0 and From.is_as(token) then
      ref.has_as = true
      idx = idx + 1
      -- Next token is the alias
      if idx <= #tokens then
        local alias_token = tokens[idx]
        if alias_token.type == "identifier" or alias_token.type == "bracket_id" then
          ref.alias = alias_token.text
          idx = idx + 1
        end
      end
      break
    end

    -- If we hit an identifier after the table name (no AS), it's an alias
    if paren_depth == 0 and #ref.name_tokens > 0 and
       (token.type == "identifier" or token.type == "bracket_id") then
      local prev = ref.name_tokens[#ref.name_tokens]
      if prev.type ~= "dot" then
        ref.alias = token.text
        idx = idx + 1
        break
      end
    end

    table.insert(ref.name_tokens, token)
    idx = idx + 1
  end

  ref.end_idx = idx - 1
  return ref
end

---Find all JOINs in the FROM clause
---@param tokens table[] All tokens
---@param from_idx number Index of FROM keyword
---@return table[] joins Array of {type: string, table_ref: table, on_tokens: table[]}
function From.find_joins(tokens, from_idx)
  local joins = {}
  local idx = from_idx + 1

  while idx <= #tokens do
    local token = tokens[idx]

    -- End of FROM clause
    if From.is_from_terminator(token) then
      break
    end
    if token.type == "semicolon" then
      break
    end

    -- Found a JOIN
    if Join.is_join_type(token) and (Join.is_join(token) or Join.is_join_modifier(token)) then
      local join = {
        type = nil,
        table_ref = nil,
        on_tokens = {},
        start_idx = idx,
      }

      -- Get full JOIN type
      join.type, idx = Join.get_join_type(tokens, idx)
      idx = idx + 1

      -- Parse table reference
      if idx <= #tokens then
        join.table_ref = From.parse_table_reference(tokens, idx)
        idx = join.table_ref.end_idx + 1
      end

      -- Look for ON clause
      if idx <= #tokens and Join.is_on(tokens[idx]) then
        idx = idx + 1 -- Skip ON
        local paren_depth = 0
        while idx <= #tokens do
          local t = tokens[idx]
          if t.type == "paren_open" then
            paren_depth = paren_depth + 1
          elseif t.type == "paren_close" then
            paren_depth = paren_depth - 1
          end

          -- End ON clause at next JOIN or terminator (at depth 0)
          if paren_depth == 0 then
            if Join.is_join_type(t) or From.is_from_terminator(t) or t.type == "semicolon" then
              break
            end
          end

          table.insert(join.on_tokens, t)
          idx = idx + 1
        end
      end

      table.insert(joins, join)
    else
      idx = idx + 1
    end
  end

  return joins
end

-- =============================================================================
-- Configuration
-- =============================================================================

---Get configuration for FROM clause formatting
---@param config FormatterConfig
---@return table from_config
function From.get_config(config)
  return {
    -- Phase 1 config options
    from_newline = config.from_newline ~= false,               -- default true
    table_style = config.from_table_style or "stacked",        -- "inline"|"stacked"
    alias_align = config.from_alias_align or false,            -- align table aliases
    schema_qualify = config.from_schema_qualify or "preserve", -- "always"|"never"|"preserve"
    table_hints_newline = config.from_table_hints_newline or false,
    derived_table_style = config.derived_table_style or "newline", -- "inline"|"newline"
  }
end

-- =============================================================================
-- Application
-- =============================================================================

---Apply formatting to FROM clause tokens
---@param token table Current token
---@param context table Formatting context
---@param config FormatterConfig
---@return table token Modified token with formatting hints
function From.apply(token, context, config)
  local from_config = From.get_config(config)

  -- Add formatting metadata for FROM clause handling
  if context.current_clause == "FROM" then
    token.in_from_clause = true
    token.from_table_style = from_config.table_style
    token.from_alias_align = from_config.alias_align
  end

  -- Mark FROM keyword
  if From.is_from(token) then
    token.is_from_keyword = true
    token.from_newline = from_config.from_newline
  end

  -- Mark table hints
  if From.is_table_hint(token) then
    token.is_table_hint = true
    token.table_hints_newline = from_config.table_hints_newline
  end

  -- Mark derived table parentheses
  if token.type == "paren_open" and context.derived_table_start then
    token.starts_derived_table = true
    token.derived_table_style = from_config.derived_table_style
  end

  return token
end

return From
