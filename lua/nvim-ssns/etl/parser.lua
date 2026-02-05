---@class EtlParser
---Parses .ssns ETL script files into executable blocks
local EtlParser = {}

local Directives = require("nvim-ssns.etl.directives")

---@class EtlBlock
---@field name string Unique block identifier
---@field type "sql"|"lua" Block type
---@field server string? Server nickname
---@field database string? Database name
---@field description string? Block description
---@field input string? Input block reference
---@field output string? Lua output type: "sql" or "data"
---@field mode string? ETL mode
---@field target string? Target table
---@field options EtlBlockOptions Additional options
---@field content string Block content (SQL or Lua code)
---@field start_line number Line number in source file
---@field end_line number End line number

---@class EtlBlockOptions
---@field timeout number? Block-specific timeout in ms
---@field skip_on_empty boolean? Skip if input is empty
---@field continue_on_error boolean? Continue pipeline on error

---@class EtlScript
---@field blocks EtlBlock[] Ordered array of blocks
---@field variables table<string, any> Script-level variables
---@field metadata EtlScriptMetadata Script metadata

---@class EtlScriptMetadata
---@field source_file string? Source file path if known
---@field parse_errors string[]? Any non-fatal parse warnings

---@class ParseState
---@field in_string boolean
---@field string_delimiter string?
---@field in_bracket boolean
---@field in_line_comment boolean
---@field in_block_comment boolean
---@field block_comment_depth number

---Create a fresh parse state
---@return ParseState
local function create_parse_state()
  return {
    in_string = false,
    string_delimiter = nil,
    in_bracket = false,
    in_line_comment = false,
    in_block_comment = false,
    block_comment_depth = 0,
  }
end

---Parse a single line for directives
---Returns directive info if line is a directive comment, nil otherwise
---@param line string The line to parse
---@return string? directive_name, string? directive_value
local function parse_directive_line(line)
  -- Match: --@directive or --@directive value
  -- Directive name: alphanumeric + underscore
  -- Value: everything after whitespace
  local name, value = line:match("^%s*%-%-@([%w_]+)%s*(.*)$")
  if name then
    -- Trim trailing whitespace from value
    value = value:match("^(.-)%s*$") or ""
    return name, value
  end
  return nil, nil
end

---Check if a line is a directive comment
---@param line string
---@return boolean
local function is_directive_line(line)
  return line:match("^%s*%-%-@[%w_]+") ~= nil
end

---Check if a line is any kind of comment (for content extraction)
---@param line string
---@return boolean
local function is_comment_line(line)
  return line:match("^%s*%-%-") ~= nil
end

---Parse script content into blocks
---@param content string The .ssns file content
---@param source_file string? Optional source file path for error messages
---@return EtlScript script Parsed script
function EtlParser.parse(content, source_file)
  local lines = {}
  local current_line = 1

  -- Split content into lines (handle \r\n and \n)
  for line in (content .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    table.insert(lines, { text = line, line_num = current_line })
    current_line = current_line + 1
  end

  -- Result containers
  local blocks = {} ---@type EtlBlock[]
  local variables = {} ---@type table<string, any>
  local parse_errors = {} ---@type string[]

  -- Current block being built
  local current_block = nil ---@type EtlBlock?
  local content_lines = {} ---@type string[]
  local block_start_line = nil ---@type number?
  local collecting_content = false

  -- First pass: collect all script-level variables (--@var before any block)
  local first_block_line = nil
  for _, line_info in ipairs(lines) do
    local name, value = parse_directive_line(line_info.text)
    if name then
      if Directives.is_block_starter(name) then
        first_block_line = line_info.line_num
        break
      elseif name == "var" then
        local var_name, var_value, err = Directives.parse_var_directive(value)
        if err then
          table.insert(parse_errors, string.format("Line %d: %s", line_info.line_num, err))
        elseif var_name then
          variables[var_name] = var_value
        end
      end
    end
  end

  -- Second pass: parse blocks
  for i, line_info in ipairs(lines) do
    local line = line_info.text
    local line_num = line_info.line_num

    -- Skip lines before first block that are variables (already processed)
    if first_block_line and line_num < first_block_line then
      local name = parse_directive_line(line)
      if name == "var" then
        goto continue
      end
    end

    local directive_name, directive_value = parse_directive_line(line)

    if directive_name and Directives.is_block_starter(directive_name) then
      -- Save previous block if exists
      if current_block then
        current_block.content = EtlParser._finalize_content(content_lines)
        current_block.end_line = line_num - 1
        table.insert(blocks, current_block)
      end

      -- Start new block
      local block_type = Directives.get_block_type(directive_name)
      current_block = {
        name = directive_value,
        type = block_type,
        server = nil,
        database = nil,
        description = nil,
        input = nil,
        output = block_type == "lua" and "sql" or nil, -- Default for Lua blocks
        mode = nil,
        target = nil,
        options = {},
        content = "",
        start_line = line_num,
        end_line = 0,
      }
      content_lines = {}
      block_start_line = line_num
      collecting_content = true
    elseif directive_name and current_block then
      -- Process directive for current block
      local parsed_value, err = Directives.parse_value(directive_name, directive_value)
      if err then
        table.insert(parse_errors, string.format("Line %d: %s", line_num, err))
      else
        EtlParser._apply_directive(current_block, directive_name, parsed_value)
      end
    elseif collecting_content then
      -- Content line (non-directive)
      -- Include even empty lines to preserve line numbers
      table.insert(content_lines, line)
    end

    ::continue::
  end

  -- Finalize last block
  if current_block then
    current_block.content = EtlParser._finalize_content(content_lines)
    current_block.end_line = #lines
    table.insert(blocks, current_block)
  end

  -- Validate all blocks
  for _, block in ipairs(blocks) do
    local valid, errors = Directives.validate_block(block.type, {
      name = block.name,
      server = block.server,
      database = block.database,
      input = block.input,
      output = block.output,
      mode = block.mode,
      target = block.target,
    })
    if not valid and errors then
      for _, err in ipairs(errors) do
        table.insert(parse_errors, string.format("Block '%s' (line %d): %s", block.name, block.start_line, err))
      end
    end
  end

  return {
    blocks = blocks,
    variables = variables,
    metadata = {
      source_file = source_file,
      parse_errors = #parse_errors > 0 and parse_errors or nil,
    },
  }
end

---Apply a directive to a block
---@param block EtlBlock
---@param directive string Directive name
---@param value any Parsed value
function EtlParser._apply_directive(block, directive, value)
  if directive == "server" then
    block.server = value
  elseif directive == "database" then
    block.database = value
  elseif directive == "description" then
    block.description = value
  elseif directive == "input" then
    block.input = value
  elseif directive == "output" then
    block.output = value
  elseif directive == "mode" then
    block.mode = value
  elseif directive == "target" then
    block.target = value
  elseif directive == "timeout" then
    block.options.timeout = value
  elseif directive == "skip_on_empty" then
    block.options.skip_on_empty = value
  elseif directive == "continue_on_error" then
    block.options.continue_on_error = value
  end
  -- Ignore unknown directives (they're already in parse_errors if invalid)
end

---Finalize block content by trimming leading/trailing empty lines
---but preserving internal structure for line number accuracy
---@param lines string[]
---@return string
function EtlParser._finalize_content(lines)
  -- Remove leading empty lines
  local start_idx = 1
  while start_idx <= #lines and lines[start_idx]:match("^%s*$") do
    start_idx = start_idx + 1
  end

  -- Remove trailing empty lines
  local end_idx = #lines
  while end_idx >= start_idx and lines[end_idx]:match("^%s*$") do
    end_idx = end_idx - 1
  end

  -- If all empty, return empty string
  if start_idx > end_idx then
    return ""
  end

  -- Join remaining lines
  local result = {}
  for i = start_idx, end_idx do
    table.insert(result, lines[i])
  end

  return table.concat(result, "\n")
end

---Validate script for execution readiness
---Checks block name uniqueness, input references, etc.
---@param script EtlScript
---@return boolean valid, string[]? errors
function EtlParser.validate(script)
  local errors = {}

  -- Check for duplicate block names
  local seen_names = {}
  for _, block in ipairs(script.blocks) do
    if seen_names[block.name] then
      table.insert(errors, string.format("Duplicate block name: '%s'", block.name))
    end
    seen_names[block.name] = true
  end

  -- Check input references exist
  for _, block in ipairs(script.blocks) do
    if block.input then
      if not seen_names[block.input] then
        table.insert(
          errors,
          string.format("Block '%s' references unknown input: '%s'", block.name, block.input)
        )
      end
    end
  end

  -- Check input references don't create cycles and are to earlier blocks
  local block_order = {}
  for i, block in ipairs(script.blocks) do
    block_order[block.name] = i
  end

  for _, block in ipairs(script.blocks) do
    if block.input then
      local input_order = block_order[block.input]
      local block_idx = block_order[block.name]
      if input_order and input_order >= block_idx then
        table.insert(
          errors,
          string.format(
            "Block '%s' references input '%s' which comes at or after it (forward reference)",
            block.name,
            block.input
          )
        )
      end
    end
  end

  -- Check blocks have content
  for _, block in ipairs(script.blocks) do
    if not block.content or block.content == "" then
      table.insert(errors, string.format("Block '%s' has no content", block.name))
    end
  end

  -- Include any parse errors from metadata
  if script.metadata.parse_errors then
    for _, err in ipairs(script.metadata.parse_errors) do
      table.insert(errors, err)
    end
  end

  if #errors > 0 then
    return false, errors
  end
  return true, nil
end

---Build execution order for blocks (currently just sequential order)
---In the future, this could support parallel execution based on dependencies
---@param script EtlScript
---@return string[] block_names Ordered block names for execution
function EtlParser.resolve_dependencies(script)
  -- For now, blocks execute in declaration order
  -- Dependencies (@input) are validated to be earlier blocks
  local order = {}
  for _, block in ipairs(script.blocks) do
    table.insert(order, block.name)
  end
  return order
end

---Get a block by name
---@param script EtlScript
---@param name string Block name
---@return EtlBlock?
function EtlParser.get_block(script, name)
  for _, block in ipairs(script.blocks) do
    if block.name == name then
      return block
    end
  end
  return nil
end

---Pretty print a script for debugging
---@param script EtlScript
---@return string
function EtlParser.dump(script)
  local lines = { "=== ETL Script ===" }

  if next(script.variables) then
    table.insert(lines, "\nVariables:")
    for name, value in pairs(script.variables) do
      table.insert(lines, string.format("  %s = %s (%s)", name, tostring(value), type(value)))
    end
  end

  table.insert(lines, string.format("\nBlocks (%d):", #script.blocks))
  for i, block in ipairs(script.blocks) do
    table.insert(lines, string.format("\n[%d] %s (%s) - lines %d-%d", i, block.name, block.type, block.start_line, block.end_line))
    if block.server then
      table.insert(lines, string.format("    server: %s", block.server))
    end
    if block.database then
      table.insert(lines, string.format("    database: %s", block.database))
    end
    if block.description then
      table.insert(lines, string.format("    description: %s", block.description))
    end
    if block.input then
      table.insert(lines, string.format("    input: %s", block.input))
    end
    if block.mode then
      table.insert(lines, string.format("    mode: %s", block.mode))
    end
    if block.target then
      table.insert(lines, string.format("    target: %s", block.target))
    end
    table.insert(lines, string.format("    content: %d chars", #block.content))
    -- Show first 100 chars of content
    local preview = block.content:sub(1, 100):gsub("\n", "\\n")
    if #block.content > 100 then
      preview = preview .. "..."
    end
    table.insert(lines, string.format("    preview: %s", preview))
  end

  if script.metadata.parse_errors then
    table.insert(lines, "\nParse Errors:")
    for _, err in ipairs(script.metadata.parse_errors) do
      table.insert(lines, "  - " .. err)
    end
  end

  return table.concat(lines, "\n")
end

return EtlParser
