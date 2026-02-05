---@class EtlDirectives
---Defines all ETL directives and their validators
local M = {}

---@alias DirectiveType "string"|"boolean"|"number"|"enum"

---@class DirectiveDefinition
---@field name string Directive name without @ prefix
---@field type DirectiveType Value type
---@field required boolean Whether directive is required
---@field block_start boolean Whether this directive starts a new block
---@field enum_values string[]? Allowed values for enum type
---@field default any? Default value if not specified
---@field description string Human-readable description

---All supported directives
---@type table<string, DirectiveDefinition>
M.definitions = {
  -- Block starters (these create new blocks)
  block = {
    name = "block",
    type = "string",
    required = true,
    block_start = true,
    description = "SQL block identifier (must be unique within script)",
  },
  lua = {
    name = "lua",
    type = "string",
    required = true,
    block_start = true,
    description = "Lua block identifier (must be unique within script)",
  },

  -- Connection directives
  server = {
    name = "server",
    type = "string",
    required = false,
    block_start = false,
    description = "Server nickname from SSNS config/tree",
  },
  database = {
    name = "database",
    type = "string",
    required = false,
    block_start = false,
    description = "Database name",
  },

  -- Documentation
  description = {
    name = "description",
    type = "string",
    required = false,
    block_start = false,
    description = "Human-readable block description",
  },

  -- Data flow
  input = {
    name = "input",
    type = "string",
    required = false,
    block_start = false,
    description = "Reference to previous block's results",
  },
  output = {
    name = "output",
    type = "enum",
    required = false,
    block_start = false,
    enum_values = { "sql", "data" },
    default = "sql",
    description = "Lua output type: sql (execute SQL) or data (pass data)",
  },

  -- ETL operations
  mode = {
    name = "mode",
    type = "enum",
    required = false,
    block_start = false,
    enum_values = { "select", "insert", "upsert", "truncate_insert", "incremental" },
    default = "select",
    description = "ETL mode for data operations",
  },
  target = {
    name = "target",
    type = "string",
    required = false,
    block_start = false,
    description = "Target table for ETL operations",
  },

  -- Execution options
  skip_on_empty = {
    name = "skip_on_empty",
    type = "boolean",
    required = false,
    block_start = false,
    default = false,
    description = "Skip block if input is empty",
  },
  continue_on_error = {
    name = "continue_on_error",
    type = "boolean",
    required = false,
    block_start = false,
    default = false,
    description = "Continue pipeline even if this block fails",
  },
  timeout = {
    name = "timeout",
    type = "number",
    required = false,
    block_start = false,
    description = "Block-specific timeout in milliseconds",
  },

  -- Script-level directives
  var = {
    name = "var",
    type = "string", -- Parsed specially: name = value
    required = false,
    block_start = false,
    description = "Define script variable (name = value)",
  },
}

---Names of directives that start new blocks
---@type string[]
M.block_starters = { "block", "lua" }

---Check if a directive name starts a new block
---@param name string Directive name
---@return boolean
function M.is_block_starter(name)
  return name == "block" or name == "lua"
end

---Get the block type for a directive
---@param name string Directive name
---@return "sql"|"lua"|nil
function M.get_block_type(name)
  if name == "block" then
    return "sql"
  elseif name == "lua" then
    return "lua"
  end
  return nil
end

---Parse a directive value based on its type
---@param directive_name string Name of the directive
---@param raw_value string Raw string value
---@return any parsed_value, string? error
function M.parse_value(directive_name, raw_value)
  local def = M.definitions[directive_name]
  if not def then
    return raw_value, nil -- Unknown directive, return as-is
  end

  if def.type == "string" then
    return raw_value, nil
  elseif def.type == "boolean" then
    -- Boolean directives can be flag-only (presence = true) or have explicit value
    if raw_value == "" or raw_value == nil then
      return true, nil
    end
    local lower = raw_value:lower()
    if lower == "true" or lower == "1" or lower == "yes" then
      return true, nil
    elseif lower == "false" or lower == "0" or lower == "no" then
      return false, nil
    end
    return true, nil -- Default to true if directive is present
  elseif def.type == "number" then
    local num = tonumber(raw_value)
    if not num then
      return nil, string.format("Invalid number value for @%s: '%s'", directive_name, raw_value)
    end
    return num, nil
  elseif def.type == "enum" then
    if not def.enum_values then
      return raw_value, nil
    end
    local lower = raw_value:lower()
    for _, allowed in ipairs(def.enum_values) do
      if lower == allowed:lower() then
        return allowed, nil
      end
    end
    return nil,
      string.format(
        "Invalid value for @%s: '%s'. Allowed: %s",
        directive_name,
        raw_value,
        table.concat(def.enum_values, ", ")
      )
  end

  return raw_value, nil
end

---Parse a --@var directive
---Format: --@var name = value
---@param value string The value after --@var
---@return string? var_name, any var_value, string? error
function M.parse_var_directive(value)
  -- Match: name = value (with optional quotes)
  local name, raw_val = value:match("^%s*([%w_]+)%s*=%s*(.+)%s*$")
  if not name then
    return nil, nil, "Invalid @var syntax. Expected: @var name = value"
  end

  -- Parse the value (handle quotes, numbers, booleans)
  local parsed_value = M.parse_var_value(raw_val)
  return name, parsed_value, nil
end

---Parse a variable value (handles quotes, numbers, booleans)
---@param raw string Raw value string
---@return any
function M.parse_var_value(raw)
  -- Remove leading/trailing whitespace
  raw = raw:match("^%s*(.-)%s*$")

  -- Check for quoted string (single or double)
  local quoted = raw:match("^'(.*)'$") or raw:match('^"(.*)"$')
  if quoted then
    return quoted
  end

  -- Check for number
  local num = tonumber(raw)
  if num then
    return num
  end

  -- Check for boolean
  local lower = raw:lower()
  if lower == "true" then
    return true
  elseif lower == "false" then
    return false
  elseif lower == "nil" or lower == "null" then
    return nil
  end

  -- Return as string
  return raw
end

---Validate a block's directives
---@param block_type "sql"|"lua" Block type
---@param directives table<string, any> Parsed directives
---@return boolean valid, string[]? errors
function M.validate_block(block_type, directives)
  local errors = {}

  -- Check required directives
  if not directives.name or directives.name == "" then
    table.insert(errors, "Block must have a name")
  end

  -- Validate enum values
  for name, value in pairs(directives) do
    local def = M.definitions[name]
    if def and def.type == "enum" and def.enum_values then
      local valid = false
      for _, allowed in ipairs(def.enum_values) do
        if value == allowed then
          valid = true
          break
        end
      end
      if not valid then
        table.insert(
          errors,
          string.format("Invalid @%s value: '%s'. Allowed: %s", name, value, table.concat(def.enum_values, ", "))
        )
      end
    end
  end

  -- Lua-specific validation
  if block_type == "lua" then
    if directives.mode and directives.mode ~= "select" then
      table.insert(errors, "Lua blocks cannot have @mode (mode is determined by return value)")
    end
  end

  -- @target requires @mode
  if directives.target and not directives.mode then
    table.insert(errors, "@target requires @mode to be specified")
  end

  -- @mode insert/upsert/truncate_insert requires @target
  if directives.mode and directives.mode ~= "select" and not directives.target then
    if directives.mode == "insert" or directives.mode == "upsert" or directives.mode == "truncate_insert" then
      table.insert(errors, string.format("@mode %s requires @target", directives.mode))
    end
  end

  if #errors > 0 then
    return false, errors
  end
  return true, nil
end

return M
