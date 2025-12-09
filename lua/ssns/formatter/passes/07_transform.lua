---@class TransformPass
---Pass 7: Token transformations (insert/remove tokens)
---
---This pass handles features that require adding or removing tokens:
---  - join_keyword_style: full/short (add/remove INNER/OUTER)
---  - insert_into_keyword: add INTO after INSERT
---  - delete_from_keyword: add FROM after DELETE
---  - use_as_keyword: add AS before aliases
---
---Annotations added:
---  token.remove        - true if token should be removed from output
---  token.insert_before - table of tokens to insert before this token
---  token.insert_after  - table of tokens to insert after this token
local TransformPass = {}

-- =============================================================================
-- Helper Functions
-- =============================================================================

---Apply casing to keyword text
---@param text string The keyword text
---@param config table Formatter configuration
---@return string Cased text
local function apply_keyword_case(text, config)
  local case_style = config.keyword_case or "upper"
  if case_style == "lower" then
    return string.lower(text)
  elseif case_style == "upper" then
    return string.upper(text)
  else
    return text  -- preserve
  end
end

---Create a new token for insertion
---@param type string Token type
---@param text string Token text
---@param config table|nil Formatter configuration (for applying casing)
---@return table
local function make_token(type, text, config)
  -- Apply casing to keywords
  if type == "keyword" and config then
    text = apply_keyword_case(text, config)
  end
  return {
    type = type,
    text = text,
    is_inserted = true,
    space_before = true,
  }
end

---Check if token is a JOIN keyword
---@param token table
---@return boolean
local function is_join_keyword(token)
  if token.type ~= "keyword" then return false end
  return string.upper(token.text) == "JOIN"
end

---Check if token is a JOIN modifier (INNER, LEFT, RIGHT, FULL, OUTER, CROSS, NATURAL)
---@param token table
---@return string|nil The modifier name, or nil if not a modifier
local function get_join_modifier(token)
  if token.type ~= "keyword" then return nil end
  local upper = string.upper(token.text)
  if upper == "INNER" or upper == "LEFT" or upper == "RIGHT" or
     upper == "FULL" or upper == "OUTER" or upper == "CROSS" or upper == "NATURAL" then
    return upper
  end
  return nil
end

-- =============================================================================
-- JOIN Keyword Style Transformations
-- =============================================================================

---Apply join_keyword_style transformations
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
local function transform_join_keywords(tokens, config)
  local style = config.join_keyword_style
  if not style or style == "preserve" then return end

  local i = 1
  while i <= #tokens do
    local token = tokens[i]
    local modifier = get_join_modifier(token)

    if modifier then
      -- Look ahead to find what kind of join this is
      local j = i + 1
      -- Skip whitespace and comments
      while j <= #tokens and (tokens[j].type == "whitespace" or
            tokens[j].type == "newline" or tokens[j].type == "comment") do
        j = j + 1
      end

      if j <= #tokens then
        local next_token = tokens[j]
        local next_modifier = get_join_modifier(next_token)
        local is_join_next = is_join_keyword(next_token)
        local is_outer_next = next_modifier == "OUTER"

        if style == "full" then
          -- "full" style: expand short forms
          -- JOIN -> INNER JOIN
          -- LEFT JOIN -> LEFT OUTER JOIN
          -- RIGHT JOIN -> RIGHT OUTER JOIN
          -- FULL JOIN -> FULL OUTER JOIN

          if modifier == "LEFT" or modifier == "RIGHT" or modifier == "FULL" then
            -- Check if next is JOIN directly (missing OUTER)
            if is_join_next then
              -- Need to insert OUTER between LEFT/RIGHT/FULL and JOIN
              token.insert_after = token.insert_after or {}
              table.insert(token.insert_after, make_token("keyword", "OUTER", config))
            end
          end

        elseif style == "short" then
          -- "short" style: use minimal forms
          -- INNER JOIN -> JOIN
          -- LEFT OUTER JOIN -> LEFT JOIN
          -- RIGHT OUTER JOIN -> RIGHT JOIN
          -- FULL OUTER JOIN -> FULL JOIN

          if modifier == "INNER" then
            -- INNER is redundant, remove it
            token.remove = true
          elseif modifier == "OUTER" then
            -- OUTER after LEFT/RIGHT/FULL is redundant, remove it
            -- Check if previous was LEFT/RIGHT/FULL
            local k = i - 1
            while k >= 1 and (tokens[k].type == "whitespace" or tokens[k].type == "newline") do
              k = k - 1
            end
            if k >= 1 then
              local prev_modifier = get_join_modifier(tokens[k])
              if prev_modifier == "LEFT" or prev_modifier == "RIGHT" or prev_modifier == "FULL" then
                token.remove = true
              end
            end
          end
        end
      elseif is_join_keyword(token) and style == "full" then
        -- Standalone JOIN -> INNER JOIN
        -- Insert INNER before JOIN
        token.insert_before = token.insert_before or {}
        table.insert(token.insert_before, make_token("keyword", "INNER", config))
      end
    elseif is_join_keyword(token) and style == "full" then
      -- Standalone JOIN with no modifier - add INNER
      -- Check previous token
      local k = i - 1
      while k >= 1 and (tokens[k].type == "whitespace" or tokens[k].type == "newline") do
        k = k - 1
      end
      if k >= 1 then
        local prev_modifier = get_join_modifier(tokens[k])
        -- Only add INNER if there's no modifier before
        if not prev_modifier then
          token.insert_before = token.insert_before or {}
          table.insert(token.insert_before, make_token("keyword", "INNER", config))
        end
      else
        -- First token is JOIN, add INNER
        token.insert_before = token.insert_before or {}
        table.insert(token.insert_before, make_token("keyword", "INNER", config))
      end
    end

    i = i + 1
  end
end

-- =============================================================================
-- INSERT INTO / DELETE FROM Keyword Transformations
-- =============================================================================

---Apply insert_into_keyword transformation
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
local function transform_insert_into(tokens, config)
  if not config.insert_into_keyword then return end

  for i, token in ipairs(tokens) do
    if token.type == "keyword" and string.upper(token.text) == "INSERT" then
      -- Check if next non-whitespace token is INTO
      local j = i + 1
      while j <= #tokens and (tokens[j].type == "whitespace" or tokens[j].type == "newline") do
        j = j + 1
      end

      if j <= #tokens then
        local next_token = tokens[j]
        if next_token.type ~= "keyword" or string.upper(next_token.text) ~= "INTO" then
          -- INTO is missing, insert it after INSERT
          token.insert_after = token.insert_after or {}
          table.insert(token.insert_after, make_token("keyword", "INTO", config))
        end
      end
    end
  end
end

---Apply delete_from_keyword transformation
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
local function transform_delete_from(tokens, config)
  if not config.delete_from_keyword then return end

  -- delete_from_newline defaults to true
  local from_newline = config.delete_from_newline ~= false

  for i, token in ipairs(tokens) do
    if token.type == "keyword" and string.upper(token.text) == "DELETE" then
      -- Look for FROM before WHERE/JOIN/ORDER/GROUP/semicolon
      -- Pattern: DELETE [alias] FROM table - if FROM exists, don't insert
      -- Pattern: DELETE table WHERE - need to insert FROM
      local found_from = false
      local insert_pos = i  -- Position to insert FROM (after DELETE or after alias)

      local j = i + 1
      while j <= #tokens do
        local t = tokens[j]
        if t.type == "whitespace" or t.type == "newline" then
          j = j + 1
        elseif t.type == "keyword" then
          local upper = string.upper(t.text)
          if upper == "FROM" then
            found_from = true
            break
          elseif upper == "WHERE" or upper == "JOIN" or upper == "ORDER" or
                 upper == "GROUP" or upper == "HAVING" or upper == "OUTPUT" then
            -- Reached a clause without finding FROM - need to insert
            break
          else
            -- Could be an alias or other keyword, continue looking
            insert_pos = j
            j = j + 1
          end
        elseif t.type == "semicolon" or t.type == "go" then
          -- End of statement without FROM
          break
        else
          -- Identifier or other - could be table name or alias
          insert_pos = j
          j = j + 1
        end
      end

      if not found_from then
        -- FROM is missing, insert it after DELETE (will go before first non-keyword token)
        local from_token = make_token("keyword", "FROM", config)
        if from_newline then
          from_token.newline_before = true
          from_token.indent_level = token.indent_level or 0
          from_token.space_before = false
        end
        token.insert_after = token.insert_after or {}
        table.insert(token.insert_after, from_token)
      end
    end
  end
end

-- =============================================================================
-- AS Keyword Transformation
-- =============================================================================

---Check if we're in a position where an alias would follow
---@param tokens table[] Array of tokens
---@param pos number Current position
---@return boolean True if current token could be followed by an alias
local function is_alias_context(tokens, pos)
  -- Look back to find clause context
  local in_select = false
  local in_from = false
  local paren_depth = 0

  for i = pos, 1, -1 do
    local t = tokens[i]
    if t.type == "paren_close" then
      paren_depth = paren_depth + 1
    elseif t.type == "paren_open" then
      paren_depth = paren_depth - 1
    elseif t.type == "keyword" and paren_depth == 0 then
      local upper = string.upper(t.text)
      if upper == "SELECT" then
        in_select = true
        break
      elseif upper == "FROM" or upper == "JOIN" then
        in_from = true
        break
      elseif upper == "WHERE" or upper == "ORDER" or upper == "GROUP" or
             upper == "HAVING" or upper == "ON" or upper == "SET" then
        break
      end
    end
  end

  return in_select or in_from
end

---Apply use_as_keyword transformation
---Inserts AS keyword before aliases that don't have it
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
local function transform_use_as_keyword(tokens, config)
  if not config.use_as_keyword then return end

  local i = 1
  while i <= #tokens do
    local token = tokens[i]

    -- Look for identifier followed by identifier (alias pattern)
    if token.type == "identifier" then
      -- Skip whitespace to find next token
      local j = i + 1
      while j <= #tokens and (tokens[j].type == "whitespace" or tokens[j].type == "newline") do
        j = j + 1
      end

      if j <= #tokens then
        local next_token = tokens[j]

        -- Check if next is an identifier (potential alias) or AS keyword
        if next_token.type == "identifier" then
          -- This could be an alias without AS
          -- Check context - are we in SELECT or FROM clause?
          if is_alias_context(tokens, i) then
            -- Insert AS before the alias
            local as_token = make_token("keyword", "AS", config)
            token.insert_after = token.insert_after or {}
            table.insert(token.insert_after, as_token)
          end
        end
        -- If next is already AS keyword, do nothing (alias already has AS)
      end
    end

    i = i + 1
  end
end

-- =============================================================================
-- Main Pass
-- =============================================================================

---Run the transformation pass on tokens
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
---@return table[] Tokens with transformation annotations
function TransformPass.run(tokens, config)
  config = config or {}

  -- Apply various transformations
  transform_join_keywords(tokens, config)
  transform_insert_into(tokens, config)
  transform_delete_from(tokens, config)
  transform_use_as_keyword(tokens, config)

  return tokens
end

---Get pass information
---@return table Pass metadata
function TransformPass.info()
  return {
    name = "transform",
    order = 7,
    description = "Token transformations (insert/remove tokens)",
    annotations = {
      "remove", "insert_before", "insert_after", "is_inserted",
    },
  }
end

return TransformPass
