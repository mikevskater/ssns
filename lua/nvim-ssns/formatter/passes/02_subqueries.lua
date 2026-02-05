---@class SubqueriesPass
---Pass 2: Detect subqueries and set indent levels
---
---This pass annotates tokens with subquery information:
---  token.subquery_depth   - nesting level (0 = top level, 1 = first subquery, etc.)
---  token.base_indent      - base indentation level for this token
---  token.is_subquery_open - true if this paren opens a subquery
---  token.is_subquery_close - true if this paren closes a subquery
---  token.in_subquery      - true if inside a subquery
local SubqueriesPass = {}

---Check if next non-whitespace token is SELECT
---@param tokens table[] Tokens
---@param start_index number Starting index
---@return boolean
local function next_is_select(tokens, start_index)
  for i = start_index, #tokens do
    local t = tokens[i]
    if t.type == "whitespace" or t.type == "newline" then
      -- skip
    elseif t.type == "keyword" and string.upper(t.text) == "SELECT" then
      return true
    else
      return false
    end
  end
  return false
end

---Run the subqueries pass
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
---@return table[] Annotated tokens
function SubqueriesPass.run(tokens, config)
  config = config or {}

  local subquery_stack = {}  -- Stack of subquery start indices
  local current_depth = 0
  local base_indent = 0

  for i, token in ipairs(tokens) do
    -- Default annotations
    token.subquery_depth = current_depth
    token.base_indent = base_indent
    token.is_subquery_open = false
    token.is_subquery_close = false
    token.in_subquery = current_depth > 0

    -- Check for subquery opening
    if token.type == "paren_open" then
      -- Check if this opens a subquery (next token is SELECT)
      if next_is_select(tokens, i + 1) then
        token.is_subquery_open = true
        current_depth = current_depth + 1
        base_indent = base_indent + 1
        table.insert(subquery_stack, {
          index = i,
          depth = current_depth,
        })
      end
    end

    -- Check for subquery closing
    if token.type == "paren_close" then
      if #subquery_stack > 0 then
        -- Check if we're closing a subquery
        local top = subquery_stack[#subquery_stack]
        if top then
          token.is_subquery_close = true
          table.remove(subquery_stack)
          current_depth = current_depth - 1
          if current_depth < 0 then current_depth = 0 end
          base_indent = base_indent - 1
          if base_indent < 0 then base_indent = 0 end
        end
      end
    end

    -- Update depth after processing
    token.subquery_depth = current_depth
    token.base_indent = base_indent

    -- Reset on semicolon or GO
    if token.type == "semicolon" or token.type == "go" then
      subquery_stack = {}
      current_depth = 0
      base_indent = 0
    end
  end

  return tokens
end

---Get pass information
---@return table Pass metadata
function SubqueriesPass.info()
  return {
    name = "subqueries",
    order = 2,
    description = "Detect subqueries and set indent levels",
    annotations = {
      "subquery_depth", "base_indent",
      "is_subquery_open", "is_subquery_close", "in_subquery",
    },
  }
end

return SubqueriesPass
