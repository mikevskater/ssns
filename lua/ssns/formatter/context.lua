---@class FormatterContext
---@field clause_stack string[] Stack of clause names for tracking nested contexts
---@field in_clauses table<string, boolean> Quick lookup for clause membership
---@field between_stack boolean[] Stack for BETWEEN...AND tracking (supports nesting)
---@field case_stack table[] Stack for CASE...END tracking with indent info
---@field subquery_stack table[] Stack for subquery tracking with context info
---@field function_call_stack table[] Stack of {paren_depth, arg_count} for nested functions
---@field in_list_stack table[] Stack for IN list tracking
---@field cte_stack table[] Stack for CTE tracking
---@field paren_depths table<string, number> Parenthesis depth counters by context
---@field pending table<string, boolean> Pending newline/state flags
---@field state table<string, any> General state variables
local FormatterContext = {}
FormatterContext.__index = FormatterContext

---Create a new FormatterContext
---@return FormatterContext
function FormatterContext:new()
  local ctx = setmetatable({}, FormatterContext)

  -- Clause tracking using stack (supports nesting)
  ctx.clause_stack = {}
  ctx.in_clauses = {}  -- Quick lookup: {SELECT=true, WHERE=true, ...}

  -- Expression stacks (for nested contexts)
  ctx.between_stack = {}  -- BETWEEN...AND tracking
  ctx.case_stack = {}     -- CASE...END with indent info
  ctx.subquery_stack = {} -- Subquery tracking
  ctx.function_call_stack = {} -- {paren_depth, arg_count} for nested functions
  ctx.in_list_stack = {}  -- IN (...) list tracking
  ctx.cte_stack = {}      -- CTE tracking

  -- Parenthesis depth counters by context
  ctx.paren_depths = {
    insert_columns = 0,
    values = 0,
    cte_columns = 0,
    in_clause = 0,
    create_table = 0,
    function_call = 0,
  }

  -- Pending newline/state flags
  ctx.pending = {
    -- SELECT clause
    stacked_indent = false,           -- newline after SELECT for stacked_indent

    -- WHERE clause
    where_stacked_indent = false,     -- newline after WHERE for stacked_indent
    between_stacked_indent = false,   -- newline after BETWEEN for stacked_indent

    -- FROM clause
    from_stacked_indent = false,      -- newline after FROM for stacked_indent

    -- JOIN/ON clause
    on_stacked_indent = false,        -- newline after ON for stacked_indent
    join = false,                     -- building compound JOIN keyword
    apply = false,                    -- building CROSS/OUTER APPLY

    -- INSERT clause
    insert_columns_stacked_indent = false, -- newline after INSERT ( for stacked_indent
    values_stacked_indent = false,    -- newline after VALUES ( for stacked_indent

    -- CTE
    cte_columns_stacked_indent = false, -- newline after CTE name ( for stacked_indent

    -- IN clause
    in_keyword = false,               -- saw IN, waiting for open paren
    in_stacked_indent = false,        -- newline after IN ( for stacked_indent

    -- CREATE
    create = false,                   -- saw CREATE, waiting for TABLE/VIEW/etc

    -- Function calls
    function_call = false,            -- just saw a function keyword
    function_stacked_indent = false,  -- newline after function ( for stacked_indent
  }

  -- Boolean flags for clause membership (simpler cases without nesting)
  ctx.in_flags = {
    select_list = false,
    from_clause = false,
    where_clause = false,
    join_clause = false,
    on_clause = false,
    group_by_clause = false,
    order_by_clause = false,
    having_clause = false,
    set_clause = false,
    values_clause = false,
    insert_columns = false,
    insert_columns_paren = false,
    values_paren = false,
    merge_statement = false,
    cte = false,
    cte_columns = false,
    cte_columns_paren = false,
    between_clause = false,
    create_table = false,
    in_clause = false,
    update_statement = false,
  }

  -- General state variables
  ctx.state = {
    between_value_count = 0,          -- values seen in BETWEEN (0=none, 1=first, 2=after AND)
    join_modifiers = {},              -- accumulated JOIN modifiers (LEFT, RIGHT, etc.)
    line_just_started = false,        -- just started new line with indent
    skip_token = false,               -- skip outputting current token

    -- SET align buffering (for update_set_align)
    set_align_buffer = {},            -- buffer for SET assignments
    set_align_current = nil,          -- current assignment being built
    set_align_active = false,         -- whether buffering SET assignments
    set_align_max_col_width = 0,      -- max column width in SET clause

    -- Function call tracking
    function_paren_depth = 0,         -- current paren depth within functions

    -- Blank line tracking
    last_line_was_blank = false,
    consecutive_blank_lines = 0,
  }

  return ctx
end

-- ============================================================================
-- Clause Stack Operations
-- ============================================================================

---Push a clause onto the stack
---@param name string Clause name (SELECT, FROM, WHERE, etc.)
function FormatterContext:push_clause(name)
  table.insert(self.clause_stack, name)
  self.in_clauses[name] = true
end

---Pop a clause from the stack
---@return string|nil The popped clause name
function FormatterContext:pop_clause()
  local name = table.remove(self.clause_stack)
  if name then
    -- Recompute in_clauses (name might still exist deeper in stack)
    self.in_clauses[name] = false
    for _, clause in ipairs(self.clause_stack) do
      if clause == name then
        self.in_clauses[name] = true
        break
      end
    end
  end
  return name
end

---Get the current (topmost) clause
---@return string|nil The current clause name
function FormatterContext:current_clause()
  return self.clause_stack[#self.clause_stack]
end

---Check if currently in a specific clause (anywhere in stack)
---@param name string Clause name to check
---@return boolean
function FormatterContext:in_clause(name)
  return self.in_clauses[name] == true
end

---Get clause stack depth
---@return number
function FormatterContext:clause_depth()
  return #self.clause_stack
end

-- ============================================================================
-- BETWEEN Stack Operations
-- ============================================================================

---Push onto BETWEEN stack (entering BETWEEN context)
function FormatterContext:push_between()
  table.insert(self.between_stack, true)
  self.in_flags.between_clause = true
end

---Pop from BETWEEN stack (exiting BETWEEN context after AND)
---@return boolean|nil
function FormatterContext:pop_between()
  local val = table.remove(self.between_stack)
  self.in_flags.between_clause = #self.between_stack > 0
  return val
end

---Check if currently in BETWEEN context
---@return boolean
function FormatterContext:in_between()
  return #self.between_stack > 0
end

-- ============================================================================
-- CASE Stack Operations
-- ============================================================================

---Push onto CASE stack with indent info
---@param indent number Current indent level
function FormatterContext:push_case(indent)
  table.insert(self.case_stack, { indent = indent })
end

---Pop from CASE stack
---@return table|nil The case context {indent}
function FormatterContext:pop_case()
  return table.remove(self.case_stack)
end

---Check if currently in CASE context
---@return boolean
function FormatterContext:in_case()
  return #self.case_stack > 0
end

---Get current CASE depth (for nested CASEs)
---@return number
function FormatterContext:case_depth()
  return #self.case_stack
end

-- ============================================================================
-- Subquery Stack Operations
-- ============================================================================

---Push onto subquery stack
---@param context_info table Optional context info {context="IN"|"FROM"|etc, indent=n}
function FormatterContext:push_subquery(context_info)
  table.insert(self.subquery_stack, context_info or {})
end

---Pop from subquery stack
---@return table|nil
function FormatterContext:pop_subquery()
  return table.remove(self.subquery_stack)
end

---Check if currently in subquery
---@return boolean
function FormatterContext:in_subquery()
  return #self.subquery_stack > 0
end

---Get subquery depth
---@return number
function FormatterContext:subquery_depth()
  return #self.subquery_stack
end

-- ============================================================================
-- Function Call Stack Operations
-- ============================================================================

---Push onto function call stack
---@param info table {paren_depth, arg_count}
function FormatterContext:push_function(info)
  table.insert(self.function_call_stack, info or { paren_depth = 0, arg_count = 0 })
end

---Pop from function call stack
---@return table|nil
function FormatterContext:pop_function()
  return table.remove(self.function_call_stack)
end

---Check if currently in function call
---@return boolean
function FormatterContext:in_function()
  return #self.function_call_stack > 0
end

---Get current function info
---@return table|nil
function FormatterContext:current_function()
  return self.function_call_stack[#self.function_call_stack]
end

-- ============================================================================
-- IN List Stack Operations
-- ============================================================================

---Push onto IN list stack
---@param info table Optional info
function FormatterContext:push_in_list(info)
  table.insert(self.in_list_stack, info or {})
  self.in_flags.in_clause = true
end

---Pop from IN list stack
---@return table|nil
function FormatterContext:pop_in_list()
  local val = table.remove(self.in_list_stack)
  self.in_flags.in_clause = #self.in_list_stack > 0
  return val
end

---Check if currently in IN list
---@return boolean
function FormatterContext:in_in_list()
  return #self.in_list_stack > 0
end

-- ============================================================================
-- Reset Operations
-- ============================================================================

---Reset clause-level state (called at statement boundaries like semicolon)
function FormatterContext:reset_clause_state()
  -- Clear all clause-related flags
  for k in pairs(self.in_flags) do
    self.in_flags[k] = false
  end

  -- Clear pending flags
  for k in pairs(self.pending) do
    self.pending[k] = false
  end

  -- Clear stacks
  self.clause_stack = {}
  self.in_clauses = {}
  self.between_stack = {}
  self.case_stack = {}
  self.function_call_stack = {}
  self.in_list_stack = {}

  -- Reset paren depths
  for k in pairs(self.paren_depths) do
    self.paren_depths[k] = 0
  end

  -- Reset state counters
  self.state.between_value_count = 0
  self.state.join_modifiers = {}
  self.state.function_paren_depth = 0

  -- Reset SET align state
  self.state.set_align_buffer = {}
  self.state.set_align_current = nil
  self.state.set_align_active = false
  self.state.set_align_max_col_width = 0
end

---Reset all state (called at batch boundaries like GO)
function FormatterContext:reset_all()
  self:reset_clause_state()

  -- Also reset subquery and CTE stacks
  self.subquery_stack = {}
  self.cte_stack = {}

  -- Reset line state
  self.state.line_just_started = false
  self.state.skip_token = false
  self.state.last_line_was_blank = false
  self.state.consecutive_blank_lines = 0
end

-- ============================================================================
-- Convenience Getters/Setters for Common Patterns
-- ============================================================================

---Set an in_flag
---@param name string Flag name (e.g., "select_list", "from_clause")
---@param value boolean
function FormatterContext:set_in(name, value)
  self.in_flags[name] = value
end

---Get an in_flag
---@param name string Flag name
---@return boolean
function FormatterContext:get_in(name)
  return self.in_flags[name] == true
end

---Set a pending flag
---@param name string Flag name
---@param value boolean
function FormatterContext:set_pending(name, value)
  self.pending[name] = value
end

---Get a pending flag
---@param name string Flag name
---@return boolean
function FormatterContext:get_pending(name)
  return self.pending[name] == true
end

---Set a paren depth
---@param name string Context name
---@param value number
function FormatterContext:set_paren_depth(name, value)
  self.paren_depths[name] = value
end

---Get a paren depth
---@param name string Context name
---@return number
function FormatterContext:get_paren_depth(name)
  return self.paren_depths[name] or 0
end

---Increment a paren depth
---@param name string Context name
function FormatterContext:inc_paren_depth(name)
  self.paren_depths[name] = (self.paren_depths[name] or 0) + 1
end

---Decrement a paren depth
---@param name string Context name
function FormatterContext:dec_paren_depth(name)
  self.paren_depths[name] = math.max(0, (self.paren_depths[name] or 0) - 1)
end

return FormatterContext
