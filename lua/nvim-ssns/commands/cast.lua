---@class SsnsCastCommands
---Cast command module for wrapping SQL selections in CAST statements
---Provides visual mode keymaps for quick type conversions
local M = {}

local KeymapManager = require('nvim-ssns.keymap_manager')

-- ==========================================================================
-- Data Type Definitions
-- ==========================================================================

---@class CastTypeInfo
---@field type string SQL data type name
---@field sized boolean Whether the type accepts a size parameter
---@field default_size number? Default size for sized types

---Type definitions with their properties
---@type table<string, CastTypeInfo>
local CAST_TYPES = {
  -- Integer types
  i = { type = "INT", sized = false },
  bi = { type = "BIGINT", sized = false },
  si = { type = "SMALLINT", sized = false },
  ti = { type = "TINYINT", sized = false },

  -- Decimal/Numeric types
  de = { type = "DECIMAL", sized = true, default_size = 18 },
  nu = { type = "NUMERIC", sized = true, default_size = 18 },
  fl = { type = "FLOAT", sized = false },
  re = { type = "REAL", sized = false },
  mo = { type = "MONEY", sized = false },

  -- String types
  v = { type = "VARCHAR", sized = true, default_size = 255 },
  nv = { type = "NVARCHAR", sized = true, default_size = 255 },
  c = { type = "CHAR", sized = true, default_size = 1 },
  nc = { type = "NCHAR", sized = true, default_size = 1 },
  vm = { type = "VARCHAR(MAX)", sized = false },
  nvm = { type = "NVARCHAR(MAX)", sized = false },

  -- Date/Time types
  d = { type = "DATE", sized = false },
  t = { type = "TIME", sized = false },
  dt = { type = "DATETIME", sized = false },
  dt2 = { type = "DATETIME2", sized = false },
  dto = { type = "DATETIMEOFFSET", sized = false },

  -- Binary types
  vb = { type = "VARBINARY", sized = true, default_size = 255 },
  vbm = { type = "VARBINARY(MAX)", sized = false },

  -- Other types
  bt = { type = "BIT", sized = false },
  ui = { type = "UNIQUEIDENTIFIER", sized = false },
  x = { type = "XML", sized = false },
}

-- ==========================================================================
-- Cast Functions
-- ==========================================================================

---Get the visual selection text
---@return string text Selected text
---@return number start_line Start line (1-indexed)
---@return number start_col Start column (0-indexed)
---@return number end_line End line (1-indexed)
---@return number end_col End column (0-indexed, exclusive)
local function get_visual_selection()
  -- Get visual selection marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local start_col = start_pos[3] - 1  -- Convert to 0-indexed
  local end_line = end_pos[2]
  local end_col = end_pos[3]  -- Keep as is (exclusive)

  -- Get the selected text
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  if #lines == 0 then
    return "", start_line, start_col, end_line, end_col
  end

  if #lines == 1 then
    local text = lines[1]:sub(start_col + 1, end_col)
    return text, start_line, start_col, end_line, end_col
  end

  -- Multi-line selection
  lines[1] = lines[1]:sub(start_col + 1)
  lines[#lines] = lines[#lines]:sub(1, end_col)
  local text = table.concat(lines, "\n")

  return text, start_line, start_col, end_line, end_col
end

---Wrap text in CAST statement
---@param text string The text to wrap
---@param sql_type string The SQL type to cast to
---@return string wrapped The wrapped text
local function wrap_in_cast(text, sql_type)
  return string.format("CAST(%s AS %s)", text, sql_type)
end

---Apply cast to visual selection
---@param type_key string The type shortcut key
---@param count number? Optional count for sized types
local function apply_cast(type_key, count)
  local type_info = CAST_TYPES[type_key]
  if not type_info then
    vim.notify("SSNS: Unknown cast type: " .. type_key, vim.log.levels.ERROR)
    return
  end

  local text, start_line, start_col, end_line, end_col = get_visual_selection()

  if text == "" then
    vim.notify("SSNS: No text selected", vim.log.levels.WARN)
    return
  end

  -- Build the SQL type string
  local sql_type = type_info.type
  if type_info.sized then
    local size = count or type_info.default_size
    if size then
      sql_type = string.format("%s(%d)", type_info.type, size)
    end
  end

  local wrapped = wrap_in_cast(text, sql_type)

  -- Replace the selection
  if start_line == end_line then
    -- Single line selection
    local line = vim.api.nvim_buf_get_lines(0, start_line - 1, start_line, false)[1]
    local new_line = line:sub(1, start_col) .. wrapped .. line:sub(end_col + 1)
    vim.api.nvim_buf_set_lines(0, start_line - 1, start_line, false, { new_line })
  else
    -- Multi-line selection - replace entire range
    local first_line = vim.api.nvim_buf_get_lines(0, start_line - 1, start_line, false)[1]
    local last_line = vim.api.nvim_buf_get_lines(0, end_line - 1, end_line, false)[1]

    local new_text = first_line:sub(1, start_col) .. wrapped .. last_line:sub(end_col + 1)
    local new_lines = vim.split(new_text, "\n")

    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, new_lines)
  end

  -- Exit visual mode
  vim.cmd("normal! ")
end

---Apply cast from command with explicit type
---@param type_str string The full SQL type string (e.g., "VARCHAR(100)")
local function apply_cast_explicit(type_str)
  local text, start_line, start_col, end_line, end_col = get_visual_selection()

  if text == "" then
    vim.notify("SSNS: No text selected", vim.log.levels.WARN)
    return
  end

  local wrapped = wrap_in_cast(text, type_str)

  -- Replace the selection
  if start_line == end_line then
    local line = vim.api.nvim_buf_get_lines(0, start_line - 1, start_line, false)[1]
    local new_line = line:sub(1, start_col) .. wrapped .. line:sub(end_col + 1)
    vim.api.nvim_buf_set_lines(0, start_line - 1, start_line, false, { new_line })
  else
    local first_line = vim.api.nvim_buf_get_lines(0, start_line - 1, start_line, false)[1]
    local last_line = vim.api.nvim_buf_get_lines(0, end_line - 1, end_line, false)[1]

    local new_text = first_line:sub(1, start_col) .. wrapped .. last_line:sub(end_col + 1)
    local new_lines = vim.split(new_text, "\n")

    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, new_lines)
  end
end

-- ==========================================================================
-- Keymap Setup
-- ==========================================================================

---Setup cast keymaps for a buffer
---@param bufnr number Buffer number
function M.setup_keymaps(bufnr)
  local Config = require('nvim-ssns.config')
  local config = Config.get()
  local prefix = config.keymaps and config.keymaps.query and config.keymaps.query.cast_prefix or "<Leader>c"

  local keymaps = {}

  for key, type_info in pairs(CAST_TYPES) do
    local lhs = prefix .. key
    local desc = string.format("Cast to %s", type_info.type)

    table.insert(keymaps, {
      mode = "v",
      lhs = lhs,
      rhs = function()
        -- Get count before executing (vim.v.count is reset after visual mode)
        local count = vim.v.count > 0 and vim.v.count or nil
        -- Exit visual mode first to set '< and '> marks
        vim.cmd("normal! ")
        apply_cast(key, count)
      end,
      desc = desc,
    })
  end

  KeymapManager.set_multiple(bufnr, keymaps, true)
end

-- ==========================================================================
-- Commands
-- ==========================================================================

---Register global cast commands
function M.register()
  vim.api.nvim_create_user_command("SSNSCast", function(opts)
    if opts.args == "" then
      vim.notify("SSNS: Usage: :SSNSCast <type> (e.g., :SSNSCast VARCHAR(100))", vim.log.levels.INFO)
      return
    end

    -- Execute from visual mode
    vim.cmd("normal! gv")
    vim.schedule(function()
      vim.cmd("normal! ")
      apply_cast_explicit(opts.args)
    end)
  end, {
    nargs = "?",
    range = true,
    desc = "Wrap visual selection in CAST statement",
    complete = function(arg_lead)
      local completions = {}
      local types = {
        "INT", "BIGINT", "SMALLINT", "TINYINT",
        "DECIMAL(18,2)", "NUMERIC(18,2)", "FLOAT", "REAL", "MONEY",
        "VARCHAR(255)", "NVARCHAR(255)", "CHAR(1)", "NCHAR(1)",
        "VARCHAR(MAX)", "NVARCHAR(MAX)",
        "DATE", "TIME", "DATETIME", "DATETIME2", "DATETIMEOFFSET",
        "VARBINARY(255)", "VARBINARY(MAX)",
        "BIT", "UNIQUEIDENTIFIER", "XML",
      }

      for _, t in ipairs(types) do
        if t:lower():find(arg_lead:lower(), 1, true) then
          table.insert(completions, t)
        end
      end

      return completions
    end,
  })
end

return M
