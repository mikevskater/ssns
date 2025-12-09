---@class AlignPass
---Pass 8: Handle alignment features
---This pass runs after structure/spacing passes and adds padding for alignment.
---
---Handles:
---  from_alias_align: true   - Align table aliases in FROM/JOIN clauses
---  update_set_align: true   - Align equals signs in SET clause
---
---Annotations added:
---  token.align_padding      - Number of spaces to add before token for alignment
local AlignPass = {}

-- =============================================================================
-- Helper Functions
-- =============================================================================

---Get visible text length (excluding special chars)
---@param text string
---@return number
local function text_length(text)
  return #text
end

---Check if token starts a new line context (FROM, JOIN, or SET column)
---@param token table
---@param config table
---@return boolean
local function is_from_table_start(token)
  -- Token following FROM or JOIN keywords
  return token.in_from_clause and token.type == "identifier" and token.is_table_name
end

---Find all table names and their aliases in a FROM/JOIN context
---@param tokens table[] Array of tokens
---@param config table Formatter config
---@return table[] Array of {table_idx, alias_idx, table_len, line_start}
local function find_from_aliases(tokens, config)
  local aliases = {}
  local i = 1

  while i <= #tokens do
    local token = tokens[i]

    -- Look for FROM or JOIN followed by table name
    if token.type == "keyword" then
      local upper = string.upper(token.text)
      if upper == "FROM" or upper == "JOIN" then
        -- Find table name (skip whitespace)
        local table_idx = i + 1
        while table_idx <= #tokens and tokens[table_idx].type == "whitespace" do
          table_idx = table_idx + 1
        end

        if table_idx <= #tokens then
          local table_token = tokens[table_idx]

          -- Handle schema.table (dbo.users)
          local table_end_idx = table_idx
          local table_text = table_token.text

          -- Check for dot (schema qualifier)
          local next_idx = table_end_idx + 1
          while next_idx <= #tokens and tokens[next_idx].type == "whitespace" do
            next_idx = next_idx + 1
          end
          -- Dot can be tokenized as "operator", "dot", or "punctuation"
          local is_dot = next_idx <= #tokens and tokens[next_idx].text == "." and
                        (tokens[next_idx].type == "operator" or tokens[next_idx].type == "dot" or tokens[next_idx].type == "punctuation")
          if is_dot then
            -- Skip dot
            next_idx = next_idx + 1
            while next_idx <= #tokens and tokens[next_idx].type == "whitespace" do
              next_idx = next_idx + 1
            end
            if next_idx <= #tokens then
              table_text = table_text .. "." .. tokens[next_idx].text
              table_end_idx = next_idx
            end
          end

          -- Look for alias (skip whitespace, optional AS)
          local alias_idx = table_end_idx + 1
          while alias_idx <= #tokens and tokens[alias_idx].type == "whitespace" do
            alias_idx = alias_idx + 1
          end

          -- Check for AS keyword
          local has_as = false
          if alias_idx <= #tokens and tokens[alias_idx].type == "keyword" and
             string.upper(tokens[alias_idx].text) == "AS" then
            has_as = true
            alias_idx = alias_idx + 1
            while alias_idx <= #tokens and tokens[alias_idx].type == "whitespace" do
              alias_idx = alias_idx + 1
            end
          end

          -- Check if next token is an identifier (alias)
          if alias_idx <= #tokens and tokens[alias_idx].type == "identifier" then
            local alias_token = tokens[alias_idx]
            -- Don't count if it's actually ON or another keyword
            if not (alias_token.type == "keyword") then
              table.insert(aliases, {
                table_idx = table_idx,
                table_end_idx = table_end_idx,
                alias_idx = alias_idx,
                table_len = text_length(table_text),
                has_as = has_as,
              })
            end
          end
        end
      end
    end

    i = i + 1
  end

  return aliases
end

---Find all SET column = value pairs
---@param tokens table[] Array of tokens
---@param config table Formatter config
---@return table[] Array of {col_idx, eq_idx, col_len}
local function find_set_columns(tokens, config)
  local columns = {}
  local in_set = false
  local i = 1

  while i <= #tokens do
    local token = tokens[i]

    -- Track SET clause
    if token.type == "keyword" and string.upper(token.text) == "SET" then
      in_set = true
    elseif token.type == "keyword" then
      local upper = string.upper(token.text)
      if upper == "WHERE" or upper == "FROM" or upper == "OUTPUT" then
        in_set = false
      end
    end

    -- Look for column = value pattern in SET clause
    if in_set and (token.type == "identifier" or
       (token.type == "keyword" and string.upper(token.text) ~= "SET")) then
      -- Find equals sign
      local col_idx = i
      local col_text = token.text

      -- Handle qualified names (u.name)
      local next_idx = i + 1
      while next_idx <= #tokens and tokens[next_idx].type == "whitespace" do
        next_idx = next_idx + 1
      end
      if next_idx <= #tokens and tokens[next_idx].type == "operator" and tokens[next_idx].text == "." then
        next_idx = next_idx + 1
        while next_idx <= #tokens and tokens[next_idx].type == "whitespace" do
          next_idx = next_idx + 1
        end
        if next_idx <= #tokens then
          col_text = col_text .. "." .. tokens[next_idx].text
          next_idx = next_idx + 1
        end
      end

      -- Skip whitespace
      while next_idx <= #tokens and tokens[next_idx].type == "whitespace" do
        next_idx = next_idx + 1
      end

      -- Check for equals
      if next_idx <= #tokens and tokens[next_idx].type == "operator" and tokens[next_idx].text == "=" then
        table.insert(columns, {
          col_idx = col_idx,
          eq_idx = next_idx,
          col_len = text_length(col_text),
        })

        -- Skip past the value to find next column
        i = next_idx
      end
    end

    i = i + 1
  end

  return columns
end

-- =============================================================================
-- Pass Implementation
-- =============================================================================

---Run the alignment pass on tokens
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
---@return table[] Tokens with alignment annotations
function AlignPass.run(tokens, config)
  -- FROM alias alignment
  if config.from_alias_align then
    local aliases = find_from_aliases(tokens, config)

    if #aliases > 0 then
      -- Find max table name length
      local max_len = 0
      for _, info in ipairs(aliases) do
        if info.table_len > max_len then
          max_len = info.table_len
        end
      end

      -- Apply padding to alias tokens (or AS keyword if present)
      for _, info in ipairs(aliases) do
        local padding = max_len - info.table_len
        if padding > 0 then
          -- Add padding to the token AFTER the table name
          local target_idx = info.table_end_idx + 1
          -- Skip any existing whitespace
          while target_idx <= #tokens and tokens[target_idx].type == "whitespace" do
            target_idx = target_idx + 1
          end
          if target_idx <= #tokens then
            tokens[target_idx].align_padding = (tokens[target_idx].align_padding or 0) + padding
          end
        end
      end
    end
  end

  -- UPDATE SET alignment
  if config.update_set_align then
    local columns = find_set_columns(tokens, config)

    if #columns > 0 then
      -- Find max column name length
      local max_len = 0
      for _, info in ipairs(columns) do
        if info.col_len > max_len then
          max_len = info.col_len
        end
      end

      -- Apply padding to equals tokens
      for _, info in ipairs(columns) do
        local padding = max_len - info.col_len
        if padding > 0 then
          tokens[info.eq_idx].align_padding = (tokens[info.eq_idx].align_padding or 0) + padding
        end
      end
    end
  end

  return tokens
end

---Get pass information
---@return table Pass metadata
function AlignPass.info()
  return {
    name = "align",
    order = 8,
    description = "Handle alignment features (from_alias_align, update_set_align)",
    annotations = {
      "align_padding",
    },
  }
end

return AlignPass
