---@class FormatterPasses
---Pipeline passes for SQL formatting
---
---Pass order:
---  01_clauses.lua    - Mark clause boundaries and track clause state
---  02_subqueries.lua - Detect subqueries and set indent levels
---  03_expressions.lua - Mark BETWEEN, CASE, IN, function boundaries
---  04_structure.lua  - Determine newlines and indentation for each token
---  05_spacing.lua    - Determine spacing between tokens
---  06_casing.lua     - Apply keyword/identifier casing
---
---After all passes, output.lua just reads annotations and builds strings.
local Passes = {}

-- Lazy load passes
local passes_cache = {}

---Pass name to file mapping
local PASS_FILES = {
  clauses = "01_clauses",
  subqueries = "02_subqueries",
  expressions = "03_expressions",
  structure = "04_structure",
  spacing = "05_spacing",
  casing = "06_casing",
  transform = "07_transform",
  align = "08_align",
  comments = "09_comments",
}

---Get a pass module by name
---@param name string Pass name
---@return table|nil Pass module
local function get_pass(name)
  if passes_cache[name] then
    return passes_cache[name]
  end

  local file_name = PASS_FILES[name]
  if not file_name then
    return nil
  end

  local ok, pass = pcall(require, "ssns.formatter.passes." .. file_name)
  if ok then
    passes_cache[name] = pass
    return pass
  end

  return nil
end

---Run a pass with graceful degradation
---@param name string Pass name
---@param tokens table[] Tokens
---@param config table|nil Config or context
---@return table[] Tokens (possibly annotated)
local function run_pass(name, tokens, config)
  local pass = get_pass(name)
  if pass and pass.run then
    local ok, result = pcall(pass.run, tokens, config)
    if ok then
      return result
    end
  end
  return tokens
end

---Run all passes in order
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
---@return table[] Fully annotated tokens
function Passes.run_all(tokens, config)
  -- Pass 1: Clauses - mark clause boundaries
  tokens = run_pass("clauses", tokens, config)

  -- Pass 2: Subqueries - detect subqueries, set indent levels
  tokens = run_pass("subqueries", tokens, config)

  -- Pass 3: Expressions - mark BETWEEN, CASE, IN, functions
  tokens = run_pass("expressions", tokens, nil)

  -- Pass 4: Structure - determine newlines and indentation
  tokens = run_pass("structure", tokens, config)

  -- Pass 5: Spacing - determine space before each token
  tokens = run_pass("spacing", tokens, config)

  -- Pass 6: Casing - apply casing to token.text
  tokens = run_pass("casing", tokens, config)

  -- Pass 7: Transform - insert/remove tokens (join_keyword_style, insert_into, delete_from)
  tokens = run_pass("transform", tokens, config)

  -- Pass 8: Align - handle alignment features (from_alias_align, update_set_align)
  tokens = run_pass("align", tokens, config)

  -- Pass 9: Comments - handle comment positioning (comment_position, blank_line_before_comment)
  tokens = run_pass("comments", tokens, config)

  return tokens
end

-- Individual pass runners for backward compatibility
function Passes.run_clauses(tokens, config)
  return run_pass("clauses", tokens, config)
end

function Passes.run_subqueries(tokens, config)
  return run_pass("subqueries", tokens, config)
end

function Passes.run_expressions(tokens, context)
  return run_pass("expressions", tokens, context)
end

function Passes.run_structure(tokens, config)
  return run_pass("structure", tokens, config)
end

function Passes.run_spacing(tokens, config)
  return run_pass("spacing", tokens, config)
end

function Passes.run_casing(tokens, config)
  return run_pass("casing", tokens, config)
end

---Get all available passes in order
---@return table[] Array of pass modules
function Passes.get_all()
  return {
    get_pass("clauses"),
    get_pass("subqueries"),
    get_pass("expressions"),
    get_pass("structure"),
    get_pass("spacing"),
    get_pass("casing"),
  }
end

---Get pass information
---@return table[] Array of pass info
function Passes.info()
  local result = {}
  for _, name in ipairs({ "clauses", "subqueries", "expressions", "structure", "spacing", "casing" }) do
    local pass = get_pass(name)
    if pass and pass.info then
      table.insert(result, pass.info())
    end
  end
  return result
end

---@class RunAllAsyncOpts
---@field on_progress fun(pass_name: string, pass_index: number, total_passes: number)? Progress callback
---@field on_complete fun(tokens: table[])? Completion callback (required)

---Active async state
---@type { timer: number?, cancelled: boolean }?
Passes._async_state = nil

---Pass order for run_all_async
local PASS_ORDER = {
  { name = "clauses", config_arg = true },
  { name = "subqueries", config_arg = true },
  { name = "expressions", config_arg = false },
  { name = "structure", config_arg = true },
  { name = "spacing", config_arg = true },
  { name = "casing", config_arg = true },
  { name = "transform", config_arg = true },
  { name = "align", config_arg = true },
  { name = "comments", config_arg = true },
}

---Run all passes asynchronously with yields between each pass
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
---@param opts RunAllAsyncOpts Options for async execution
function Passes.run_all_async(tokens, config, opts)
  opts = opts or {}
  local on_progress = opts.on_progress
  local on_complete = opts.on_complete

  local total_passes = #PASS_ORDER

  -- Cancel any existing async execution
  Passes.cancel_async()

  -- For very small token counts, just run synchronously
  if #tokens <= 100 then
    local result = Passes.run_all(tokens, config)
    if on_progress then
      for i, pass_info in ipairs(PASS_ORDER) do
        on_progress(pass_info.name, i, total_passes)
      end
    end
    if on_complete then on_complete(result) end
    return
  end

  -- Initialize async state
  Passes._async_state = {
    timer = nil,
    cancelled = false,
  }

  local async_state = Passes._async_state
  local current_tokens = tokens
  local current_pass_idx = 1

  ---Run the next pass
  local function run_next_pass()
    if async_state.cancelled then
      Passes._async_state = nil
      return
    end

    if current_pass_idx > total_passes then
      -- All passes complete
      Passes._async_state = nil
      if on_complete then
        on_complete(current_tokens)
      end
      return
    end

    local pass_info = PASS_ORDER[current_pass_idx]
    local pass_arg = pass_info.config_arg and config or nil

    -- Run the current pass
    current_tokens = run_pass(pass_info.name, current_tokens, pass_arg)

    -- Report progress
    if on_progress then
      on_progress(pass_info.name, current_pass_idx, total_passes)
    end

    current_pass_idx = current_pass_idx + 1

    if current_pass_idx <= total_passes then
      -- Schedule next pass
      async_state.timer = vim.fn.timer_start(0, function()
        async_state.timer = nil
        vim.schedule(run_next_pass)
      end)
    else
      -- All passes complete
      Passes._async_state = nil
      if on_complete then
        on_complete(current_tokens)
      end
    end
  end

  -- Start running passes
  run_next_pass()
end

---Cancel any in-progress async pass execution
function Passes.cancel_async()
  if Passes._async_state then
    Passes._async_state.cancelled = true
    if Passes._async_state.timer then
      vim.fn.timer_stop(Passes._async_state.timer)
      Passes._async_state.timer = nil
    end
    Passes._async_state = nil
  end
end

---Check if async pass execution is currently in progress
---@return boolean
function Passes.is_async_active()
  return Passes._async_state ~= nil and not Passes._async_state.cancelled
end

return Passes
