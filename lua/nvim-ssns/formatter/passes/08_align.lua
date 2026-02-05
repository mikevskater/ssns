---@class AlignPass
---Pass 8: Handle alignment features
---This pass runs after structure/spacing passes and adds padding for alignment.
---
---Handles:
---  from_alias_align: true      - Align table aliases in FROM/JOIN clauses
---  update_set_align: true      - Align equals signs in SET clause
---  inline_comment_align: true  - Align inline comments (-- style) to same column
---  select_column_align: "keyword" - Align SELECT columns to keyword position
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

---Check if token is a line comment (-- style)
---@param token table
---@return boolean
local function is_line_comment(token)
  return token.type == "line_comment"
end

---Find SELECT list column tokens that start on a new line
---These are tokens in the SELECT list that have newline_before = true
---@param tokens table[] Array of tokens
---@param config table Formatter config
---@return table[] Array of {idx, base_indent} - token index and base indent level
local function find_select_columns(tokens, config)
  local columns = {}
  local select_list_style = config.select_list_style or "inline"

  -- Only applies to stacked or stacked_indent styles
  if select_list_style == "inline" then
    return columns
  end

  for i, token in ipairs(tokens) do
    -- Look for tokens in SELECT list that start on a new line
    -- Skip the SELECT keyword itself and modifiers (DISTINCT, TOP, etc.)
    if token.in_select_list and token.newline_before then
      local upper = token.type == "keyword" and string.upper(token.text) or ""
      -- Skip SELECT modifiers
      if upper ~= "SELECT" and upper ~= "DISTINCT" and upper ~= "TOP" and
         upper ~= "ALL" and upper ~= "PERCENT" and upper ~= "TIES" and
         upper ~= "WITH" and upper ~= "INTO" and token.type ~= "number" then
        table.insert(columns, {
          idx = i,
          base_indent = token.base_indent or token.subquery_depth or 0,
          indent_level = token.indent_level or 0,
        })
      end
    end
  end

  return columns
end

-- Keywords that should be right-aligned for river style
local RIVER_KEYWORDS = {
  SELECT = true,
  FROM = true,
  WHERE = true,
  JOIN = true,
  ON = true,
  SET = true,
  VALUES = true,
  OUTPUT = true,
  HAVING = true,
  UNION = true,
  EXCEPT = true,
  INTERSECT = true,
  -- Multi-word keywords tracked by first word
  INNER = true,
  LEFT = true,
  RIGHT = true,
  FULL = true,
  CROSS = true,
  OUTER = true,
  GROUP = true,
  ORDER = true,
  INSERT = true,
  UPDATE = true,
  DELETE = true,
  MERGE = true,
}

---Get the full keyword text for multi-word keywords (e.g., "INNER JOIN", "ORDER BY")
---@param tokens table[] Array of tokens
---@param idx number Starting token index
---@return string Full keyword text
---@return number End index of the keyword
local function get_full_keyword(tokens, idx)
  local token = tokens[idx]
  local upper = string.upper(token.text)
  local text = token.text
  local end_idx = idx

  -- Check for multi-word keywords
  -- Look ahead for next keyword/identifier
  local next_idx = idx + 1
  while next_idx <= #tokens and tokens[next_idx].type == "whitespace" do
    next_idx = next_idx + 1
  end

  if next_idx <= #tokens and tokens[next_idx].type == "keyword" then
    local next_upper = string.upper(tokens[next_idx].text)

    -- JOIN modifiers: INNER JOIN, LEFT JOIN, RIGHT JOIN, FULL JOIN, CROSS JOIN
    -- Also: LEFT OUTER JOIN, RIGHT OUTER JOIN, FULL OUTER JOIN
    if upper == "INNER" or upper == "LEFT" or upper == "RIGHT" or upper == "FULL" or upper == "CROSS" then
      if next_upper == "JOIN" then
        text = text .. " " .. tokens[next_idx].text
        end_idx = next_idx
      elseif next_upper == "OUTER" then
        -- Look for JOIN after OUTER
        local join_idx = next_idx + 1
        while join_idx <= #tokens and tokens[join_idx].type == "whitespace" do
          join_idx = join_idx + 1
        end
        if join_idx <= #tokens and tokens[join_idx].type == "keyword" and
           string.upper(tokens[join_idx].text) == "JOIN" then
          text = text .. " " .. tokens[next_idx].text .. " " .. tokens[join_idx].text
          end_idx = join_idx
        else
          text = text .. " " .. tokens[next_idx].text
          end_idx = next_idx
        end
      end
    -- GROUP BY, ORDER BY
    elseif upper == "GROUP" or upper == "ORDER" then
      if next_upper == "BY" then
        text = text .. " " .. tokens[next_idx].text
        end_idx = next_idx
      end
    -- INSERT INTO
    elseif upper == "INSERT" then
      if next_upper == "INTO" then
        text = text .. " " .. tokens[next_idx].text
        end_idx = next_idx
      end
    -- DELETE FROM (when FROM follows DELETE)
    elseif upper == "DELETE" then
      if next_upper == "FROM" then
        text = text .. " " .. tokens[next_idx].text
        end_idx = next_idx
      end
    -- CROSS APPLY, OUTER APPLY
    elseif upper == "CROSS" or upper == "OUTER" then
      if next_upper == "APPLY" then
        text = text .. " " .. tokens[next_idx].text
        end_idx = next_idx
      end
    end
  end

  return text, end_idx
end

---Find keywords at line starts that should be right-aligned
---@param tokens table[] Array of tokens
---@param config table Formatter config
---@return table[] Array of {idx, keyword_text, keyword_len, indent_level}
local function find_river_keywords(tokens, config)
  local keywords = {}
  local is_first_significant = true  -- Track if we're looking at first keyword of statement

  for i, token in ipairs(tokens) do
    -- Skip whitespace for first-token detection
    if token.type == "whitespace" or token.type == "newline" then
      goto continue
    end

    -- Consider keywords that either:
    -- 1. Start a new line (newline_before = true)
    -- 2. Are the first significant token in the statement
    if token.type == "keyword" then
      local upper = string.upper(token.text)

      -- Check if this is a keyword we want to right-align
      if RIVER_KEYWORDS[upper] then
        local starts_line = token.newline_before or is_first_significant

        if starts_line then
          local full_text, end_idx = get_full_keyword(tokens, i)
          table.insert(keywords, {
            idx = i,
            end_idx = end_idx,
            keyword_text = full_text,
            keyword_len = #full_text,
            indent_level = token.indent_level or 0,
          })
        end
      end
    end

    -- Reset first_significant after semicolon or GO (start of new statement)
    if token.type == "semicolon" or token.type == "go" then
      is_first_significant = true
    else
      is_first_significant = false
    end

    ::continue::
  end

  return keywords
end

---Find inline line comments and calculate content length before each
---An inline comment is a line comment that follows code on the same line.
---We detect this by checking if there's no newline_before annotation on the comment.
---@param tokens table[] Array of tokens
---@param config table Formatter config
---@return table[] Array of {comment_idx, content_len} - comment index and length of content before it
local function find_inline_comments(tokens, config)
  local comments = {}

  -- Track content length on current line
  local current_line_len = 0
  local last_newline_idx = 0

  for i, token in ipairs(tokens) do
    -- Skip whitespace tokens (we handle spacing via annotations)
    if token.type == "whitespace" or token.type == "newline" then
      goto continue
    end

    -- Check for newline_before - resets line tracking
    if token.newline_before then
      current_line_len = 0
      last_newline_idx = i

      -- Add indent to line length
      if token.indent_level and token.indent_level > 0 then
        local indent_size = config.indent_size or 4
        current_line_len = token.indent_level * indent_size
      end
    end

    -- Check if this is an inline line comment
    if is_line_comment(token) then
      -- A comment is inline if it doesn't start on a new line
      -- and there was content before it on this line
      if not token.newline_before and current_line_len > 0 then
        table.insert(comments, {
          comment_idx = i,
          content_len = current_line_len,
        })
      end
    else
      -- Add token length to current line
      -- Include space_before if present
      if token.space_before and current_line_len > 0 then
        current_line_len = current_line_len + 1
      end
      -- Add align_padding if already set by other alignment
      if token.align_padding then
        current_line_len = current_line_len + token.align_padding
      end
      current_line_len = current_line_len + text_length(token.text)
    end

    ::continue::
  end

  return comments
end

-- =============================================================================
-- Pass Implementation
-- =============================================================================

---Run the alignment pass on tokens
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
---@return table[] Tokens with alignment annotations
function AlignPass.run(tokens, config)
  -- SELECT column alignment to keyword position
  -- select_column_align: "left" (default) uses standard indent
  -- select_column_align: "keyword" aligns columns to position after "SELECT "
  if config.select_column_align == "keyword" then
    local columns = find_select_columns(tokens, config)
    local indent_size = config.indent_size or 4
    -- "SELECT " is 7 characters, standard indent is indent_size
    -- We need to add extra padding: 7 - indent_size (if positive)
    local keyword_offset = 7  -- length of "SELECT "

    for _, info in ipairs(columns) do
      -- Current indent position = base_indent * indent_size + indent_size (for the +1 level)
      -- But we actually have indent_level already calculated
      -- Current position = indent_level * indent_size
      -- Target position = base_indent * indent_size + keyword_offset
      -- Padding needed = target - current
      local current_pos = info.indent_level * indent_size
      local target_pos = info.base_indent * indent_size + keyword_offset
      local padding = target_pos - current_pos

      if padding > 0 then
        tokens[info.idx].align_padding = (tokens[info.idx].align_padding or 0) + padding
      elseif padding < 0 then
        -- Need to reduce indent - we can't do that with align_padding
        -- Instead, we need to set indent_level to 0 and use align_padding for full indent
        tokens[info.idx].indent_level = 0
        tokens[info.idx].align_padding = (tokens[info.idx].align_padding or 0) + target_pos
      end
    end
  end

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

  -- Inline comment alignment
  -- Aligns line comments (-- style) that appear after code on the same line
  if config.inline_comment_align then
    local comments = find_inline_comments(tokens, config)

    if #comments > 1 then
      -- Find max content length before comments
      local max_len = 0
      for _, info in ipairs(comments) do
        if info.content_len > max_len then
          max_len = info.content_len
        end
      end

      -- Apply padding to comment tokens
      for _, info in ipairs(comments) do
        local padding = max_len - info.content_len
        if padding > 0 then
          tokens[info.comment_idx].align_padding = (tokens[info.comment_idx].align_padding or 0) + padding
        end
      end
    end
  end

  -- Keyword right alignment (river style)
  -- Right-aligns SQL keywords like SELECT, FROM, WHERE, JOIN, etc.
  -- to create a "river" of whitespace down the left side
  if config.keyword_right_align then
    local keywords = find_river_keywords(tokens, config)

    if #keywords > 0 then
      -- Find the global max keyword length at the base indent level (level 0)
      -- This becomes the alignment target for all keywords at base level
      local base_max_len = 0
      for _, info in ipairs(keywords) do
        if info.indent_level == 0 and info.keyword_len > base_max_len then
          base_max_len = info.keyword_len
        end
      end

      -- Apply right-alignment padding to all keywords at base level
      for _, info in ipairs(keywords) do
        if info.indent_level == 0 then
          local padding = base_max_len - info.keyword_len
          if padding > 0 then
            -- Add padding before the first token of the keyword
            tokens[info.idx].align_padding = (tokens[info.idx].align_padding or 0) + padding
          end
        end
      end

      -- For keywords at deeper indent levels (subqueries, etc.),
      -- align within their own group
      local by_indent = {}
      for _, info in ipairs(keywords) do
        if info.indent_level > 0 then
          local level = info.indent_level
          if not by_indent[level] then
            by_indent[level] = {}
          end
          table.insert(by_indent[level], info)
        end
      end

      for _, group in pairs(by_indent) do
        local max_len = 0
        for _, info in ipairs(group) do
          if info.keyword_len > max_len then
            max_len = info.keyword_len
          end
        end

        for _, info in ipairs(group) do
          local padding = max_len - info.keyword_len
          if padding > 0 then
            tokens[info.idx].align_padding = (tokens[info.idx].align_padding or 0) + padding
          end
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
    description = "Handle alignment features (select_column_align, from_alias_align, update_set_align, inline_comment_align, keyword_right_align)",
    annotations = {
      "align_padding",
    },
  }
end

return AlignPass
