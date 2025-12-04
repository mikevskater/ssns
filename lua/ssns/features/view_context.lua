---@class ViewContext
---View statement context in a floating window
---Displays the IntelliSense context at cursor position for debugging
---@module ssns.features.view_context
local ViewContext = {}

local UiFloat = require('ssns.ui.float')
local JsonUtils = require('ssns.utils.json')
local StatementContext = require('ssns.completion.statement_context')

-- Store reference to current floating window for cleanup
local current_float = nil

---Close the current floating window
function ViewContext.close_current_float()
  if current_float then
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
end

---View statement context at cursor position
---Detects context and displays in a floating window
function ViewContext.view_context()
  -- Close any existing float
  ViewContext.close_current_float()

  -- Get current buffer and cursor position
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]  -- 1-indexed
  local col = cursor[2] + 1   -- Convert to 1-indexed

  -- Get line text for display
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  local line_text = lines[1] or ""

  -- Detect context at cursor
  local context = StatementContext.detect(bufnr, line_num, col)

  if not context then
    vim.notify("SSNS: Failed to detect context", vim.log.levels.ERROR)
    return
  end

  -- Build display content
  local display_lines = {}

  table.insert(display_lines, "Statement Context (IntelliSense)")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Cursor position info
  table.insert(display_lines, "Cursor Position")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, string.format("  Line: %d, Column: %d", line_num, col))
  table.insert(display_lines, string.format("  Line text: %s", line_text))
  table.insert(display_lines, string.format("  Before cursor: %s|", line_text:sub(1, col - 1)))
  table.insert(display_lines, "")

  -- Main context info
  table.insert(display_lines, "Context Detection")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, string.format("  Type: %s", context.type or "unknown"))
  table.insert(display_lines, string.format("  Mode: %s", context.mode or "unknown"))
  table.insert(display_lines, string.format("  Prefix: \"%s\"", context.prefix or ""))
  table.insert(display_lines, string.format("  Trigger: %s", context.trigger and ("\"" .. context.trigger .. "\"") or "nil"))
  table.insert(display_lines, "")

  -- Extra context fields
  local extra_fields = {
    "table_ref", "schema", "database", "filter_schema", "filter_database",
    "filter_table", "potential_database", "omit_schema", "omit_table",
    "value_position", "insert_table", "insert_schema"
  }
  local has_extra = false
  for _, field in ipairs(extra_fields) do
    if context[field] then
      if not has_extra then
        table.insert(display_lines, "Extra Context")
        table.insert(display_lines, string.rep("-", 30))
        has_extra = true
      end
      local value = context[field]
      if type(value) == "table" then
        table.insert(display_lines, string.format("  %s:", field))
        for k, v in pairs(value) do
          table.insert(display_lines, string.format("    %s: %s", k, tostring(v)))
        end
      else
        table.insert(display_lines, string.format("  %s: %s", field, tostring(value)))
      end
    end
  end
  if has_extra then
    table.insert(display_lines, "")
  end

  -- Tables in scope
  if context.tables_in_scope and #context.tables_in_scope > 0 then
    table.insert(display_lines, "Tables in Scope")
    table.insert(display_lines, string.rep("-", 30))
    for i, t in ipairs(context.tables_in_scope) do
      local desc
      if t.is_cte then
        local col_count = t.columns and #t.columns or 0
        desc = string.format("[CTE] %s (%d columns)", t.name, col_count)
      elseif t.is_subquery then
        local col_count = t.columns and #t.columns or 0
        desc = string.format("[Subquery] %s AS %s (%d columns)", t.name or "?", t.alias or t.name, col_count)
      elseif t.is_temp_table then
        local col_count = t.columns and #t.columns or 0
        desc = string.format("[Temp] %s%s (%d columns)", t.name, t.alias and (" AS " .. t.alias) or "", col_count)
      elseif t.is_tvf then
        desc = string.format("[TVF] %s.%s AS %s", t.schema or "dbo", t.function_name or t.name, t.alias or t.name)
      else
        desc = string.format("%s AS %s", t.table or t.name or "?", t.alias or "-")
      end
      table.insert(display_lines, string.format("  %d. %s", i, desc))
    end
    table.insert(display_lines, "")
  end

  -- Aliases map
  if context.aliases and next(context.aliases) then
    table.insert(display_lines, "Alias Map")
    table.insert(display_lines, string.rep("-", 30))
    local sorted_aliases = {}
    for alias in pairs(context.aliases) do
      table.insert(sorted_aliases, alias)
    end
    table.sort(sorted_aliases)
    for _, alias in ipairs(sorted_aliases) do
      table.insert(display_lines, string.format("  %s -> %s", alias, context.aliases[alias]))
    end
    table.insert(display_lines, "")
  end

  -- CTEs
  if context.ctes and next(context.ctes) then
    table.insert(display_lines, "CTEs")
    table.insert(display_lines, string.rep("-", 30))
    for name, cte in pairs(context.ctes) do
      local col_count = cte.columns and #cte.columns or 0
      table.insert(display_lines, string.format("  %s (%d columns)", name, col_count))
    end
    table.insert(display_lines, "")
  end

  -- Temp tables
  if context.temp_tables and next(context.temp_tables) then
    table.insert(display_lines, "Temp Tables")
    table.insert(display_lines, string.rep("-", 30))
    for name, temp in pairs(context.temp_tables) do
      local col_count = temp.columns and #temp.columns or 0
      local global = temp.is_global and " (global)" or ""
      table.insert(display_lines, string.format("  %s%s (%d columns)", name, global, col_count))
    end
    table.insert(display_lines, "")
  end

  -- Statement chunk info (brief)
  if context.chunk then
    table.insert(display_lines, "Statement Chunk")
    table.insert(display_lines, string.rep("-", 30))
    table.insert(display_lines, string.format("  Type: %s", context.chunk.statement_type or "?"))
    table.insert(display_lines, string.format("  Lines: %d-%d", context.chunk.start_line or 0, context.chunk.end_line or 0))
    table.insert(display_lines, string.format("  Tables: %d", context.chunk.tables and #context.chunk.tables or 0))
    table.insert(display_lines, string.format("  Columns: %d", context.chunk.columns and #context.chunk.columns or 0))
    table.insert(display_lines, "")
  end

  -- Add JSON section for full context
  table.insert(display_lines, "")
  table.insert(display_lines, "Full JSON Output")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Create a cleaned context for JSON output (remove large nested objects)
  local json_context = {
    type = context.type,
    mode = context.mode,
    prefix = context.prefix,
    trigger = context.trigger,
    table_ref = context.table_ref,
    schema = context.schema,
    database = context.database,
    filter_schema = context.filter_schema,
    filter_database = context.filter_database,
    filter_table = context.filter_table,
    insert_table = context.insert_table,
    insert_schema = context.insert_schema,
    tables_in_scope = context.tables_in_scope,
    aliases = context.aliases,
  }

  local json_lines = JsonUtils.prettify_lines(json_context)
  for _, line in ipairs(json_lines) do
    table.insert(display_lines, line)
  end

  -- Create floating window
  current_float = UiFloat.create(display_lines, {
    title = "Statement Context",
    border = "rounded",
    filetype = "json",
    min_width = 60,
    max_width = 100,
    max_height = 40,
    wrap = false,
    keymaps = {
      ['r'] = function()
        -- Refresh: re-detect context at current cursor position
        ViewContext.view_context()
      end,
    },
    footer = "q/Esc: close | r: refresh",
  })
end

return ViewContext
