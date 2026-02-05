---@class CommentsPass
---Pass 9: Handle comment positioning and block comment formatting
---This pass runs after alignment and handles comment-specific formatting.
---
---Handles:
---  comment_position: "preserve" | "above" | "inline"
---    - preserve: leave comments where they are (default)
---    - above: move inline comments to their own line
---    - inline: keep comments inline with code
---  blank_line_before_comment: true/false
---    - add empty line before standalone comments
---  block_comment_style: "preserve" | "reformat"
---    - preserve: keep block comments exactly as-is (default)
---    - reformat: normalize whitespace in block comments
---
---Annotations added:
---  token.newline_before      - for comments that should be on their own line
---  token.empty_line_before   - for blank line before comment
---  token.is_standalone_comment - comment that's already on its own line
local CommentsPass = {}

-- =============================================================================
-- Helper Functions
-- =============================================================================

---Check if token is a comment
---@param token table
---@return boolean
local function is_comment(token)
  return token.type == "comment" or token.type == "line_comment"
end

---Check if token is a line comment (-- style)
---@param token table
---@return boolean
local function is_line_comment(token)
  return token.type == "line_comment"
end

---Check if token is a block comment (/* */ style)
---@param token table
---@return boolean
local function is_block_comment(token)
  return token.type == "comment"
end

---Check if a block comment is a "decorative" comment (boxes, headers with asterisks/dashes)
---These should be preserved as-is even in reformat mode
---@param text string The comment text including /* */
---@return boolean
local function is_decorative_comment(text)
  -- Check for boxed comments with repeated characters at start
  -- e.g., /*****, /*-----, /******
  if text:match("^/%*[%*%-=]+") then
    return true
  end
  -- Check for boxed comments with repeated characters at end
  -- e.g., *****/, -----*/
  if text:match("[%*%-=]+%*/$") then
    return true
  end
  return false
end

---Check if a block comment is a single-line comment (no newlines)
---@param text string The comment text
---@return boolean
local function is_single_line_comment(text)
  return not text:find("\n")
end

---Reformat a single-line block comment
---Normalizes internal whitespace while preserving content
---@param text string The comment text including /* */
---@return string Reformatted comment
local function reformat_single_line(text)
  -- Extract content between /* and */
  local content = text:match("^/%*(.-)%*/$")
  if not content then
    return text  -- Malformed, return as-is
  end

  -- Handle empty comment /**/
  if content == "" then
    return text
  end

  -- Check for hint-style comments that start with + (e.g., /*+HINT*/)
  -- These should be preserved as-is
  if content:match("^%+") then
    return text
  end

  -- Normalize whitespace: trim leading/trailing, collapse internal spaces
  content = content:gsub("^%s+", "")  -- Trim leading
  content = content:gsub("%s+$", "")  -- Trim trailing

  -- Return with single space padding if there's content
  if content == "" then
    return "/**/"
  end
  return "/* " .. content .. " */"
end

---Reformat a multi-line block comment
---Normalizes internal whitespace while preserving structure
---@param text string The comment text including /* */
---@return string Reformatted comment
local function reformat_multi_line(text)
  -- Split into lines
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end

  if #lines == 0 then
    return text
  end

  -- Process each line
  local result_lines = {}
  local prev_was_blank = false

  for i, line in ipairs(lines) do
    local processed = line

    if i == 1 then
      -- First line: just the /* part, preserve it
      result_lines[#result_lines + 1] = line
      prev_was_blank = false
    elseif i == #lines then
      -- Last line: just the */ part
      -- Trim trailing whitespace but preserve leading (for alignment)
      processed = line:gsub("%s+$", "")
      result_lines[#result_lines + 1] = processed
    else
      -- Middle lines: trim trailing whitespace
      processed = line:gsub("%s+$", "")

      -- Handle blank lines - collapse multiple to single
      if processed:match("^%s*$") then
        if not prev_was_blank then
          result_lines[#result_lines + 1] = ""
          prev_was_blank = true
        end
        -- Skip additional consecutive blank lines
      else
        result_lines[#result_lines + 1] = processed
        prev_was_blank = false
      end
    end
  end

  return table.concat(result_lines, "\n")
end

---Reformat a block comment based on block_comment_style setting
---@param text string The comment text including /* */
---@return string Reformatted comment
local function reformat_block_comment(text)
  -- Decorative comments (boxes, headers) should be preserved
  if is_decorative_comment(text) then
    return text
  end

  -- Single-line vs multi-line handling
  if is_single_line_comment(text) then
    return reformat_single_line(text)
  else
    return reformat_multi_line(text)
  end
end

---Check if previous non-whitespace token is on a different line
---This determines if a comment is "standalone" (already on its own line)
---@param tokens table[] Array of tokens
---@param index number Current token index
---@return boolean
local function is_at_line_start(tokens, index)
  -- Look backwards for newline or start of input
  for i = index - 1, 1, -1 do
    local prev = tokens[i]
    if prev.type == "newline" then
      return true
    end
    if prev.type ~= "whitespace" then
      return false
    end
  end
  -- Start of input counts as line start
  return true
end

---Get the previous non-whitespace/newline token
---@param tokens table[] Array of tokens
---@param index number Current token index
---@return table|nil Previous content token
local function get_prev_content_token(tokens, index)
  for i = index - 1, 1, -1 do
    local prev = tokens[i]
    if prev.type ~= "whitespace" and prev.type ~= "newline" then
      return prev
    end
  end
  return nil
end

-- =============================================================================
-- Pass Implementation
-- =============================================================================

---Get the next non-whitespace/newline/comment token
---@param tokens table[] Array of tokens
---@param index number Current token index
---@return table|nil, number|nil Next content token and its index
local function get_next_content_token(tokens, index)
  for i = index + 1, #tokens do
    local next_tok = tokens[i]
    if next_tok.type ~= "whitespace" and next_tok.type ~= "newline" then
      return next_tok, i
    end
  end
  return nil, nil
end

---Check if the next non-comment token has newline_before (is a clause start)
---This helps identify "preceding comments" that should be on their own line
---@param tokens table[] Array of tokens
---@param index number Current token index
---@return boolean, table|nil Whether next content has newline, and the token
local function next_has_newline(tokens, index)
  for i = index + 1, #tokens do
    local next_tok = tokens[i]
    if next_tok.type ~= "whitespace" and next_tok.type ~= "newline" then
      -- Skip comments - we want the next real content
      if not is_comment(next_tok) then
        return next_tok.newline_before == true, next_tok
      end
    end
  end
  return false, nil
end

---Run the comments pass on tokens
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
---@return table[] Tokens with comment annotations
function CommentsPass.run(tokens, config)
  config = config or {}

  -- Default to "preserve" if not specified
  local comment_position = config.comment_position or "preserve"
  local blank_before = config.blank_line_before_comment
  local block_style = config.block_comment_style or "preserve"

  -- Check if we have anything to do
  local needs_position_handling = comment_position ~= "preserve" or blank_before
  local needs_block_reformat = block_style == "reformat"

  if not needs_position_handling and not needs_block_reformat then
    return tokens
  end

  for i, token in ipairs(tokens) do
    if is_comment(token) then
      -- Check if this comment is already on its own line
      -- Note: tokenizer strips newlines, so we can't reliably detect this
      -- Instead, we use heuristics based on previous token
      local standalone = is_at_line_start(tokens, i)
      token.is_standalone_comment = standalone

      -- Handle block_comment_style: reformat
      -- This modifies the token.text to normalize whitespace
      if needs_block_reformat and is_block_comment(token) then
        token.text = reformat_block_comment(token.text)
      end

      -- Handle comment_position: above
      -- Move inline comments to their own line
      if comment_position == "above" and not standalone then
        -- This comment is inline (after code on same line)
        -- Mark it to start on a new line
        token.newline_before = true
        -- Use same indent as current context
        token.indent_level = token.indent_level or 0

        -- For block comments, also ensure the next token starts on a new line
        -- so the comment is truly on its own line
        if is_block_comment(token) then
          local next_tok, next_idx = get_next_content_token(tokens, i)
          if next_tok and not next_tok.newline_before then
            next_tok.newline_before = true
            next_tok.indent_level = next_tok.indent_level or 0
          end
        end
      end

      -- Handle blank_line_before_comment
      -- A comment should have a blank line before it when:
      -- 1. blank_line_before_comment is enabled, AND
      -- 2. The next non-comment token has newline_before (meaning this comment
      --    precedes a clause keyword like WHERE, JOIN, etc.)
      -- This indicates the comment is a "section comment" before a clause
      if blank_before then
        local next_newline, next_tok = next_has_newline(tokens, i)
        if next_newline then
          -- This comment precedes a clause - put it on its own line with blank before
          local prev = get_prev_content_token(tokens, i)
          if prev and prev.type ~= "semicolon" and prev.type ~= "go" then
            token.newline_before = true
            token.indent_level = token.indent_level or 0
            token.empty_line_before = true
          end
        end
      end
    end
  end

  return tokens
end

---Get pass information
---@return table Pass metadata
function CommentsPass.info()
  return {
    name = "comments",
    order = 9,
    description = "Handle comment positioning and block comment formatting (comment_position, blank_line_before_comment, block_comment_style)",
    annotations = {
      "is_standalone_comment",
    },
  }
end

return CommentsPass
