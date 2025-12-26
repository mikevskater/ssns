---@class ViewContext
---View statement context in a floating window
---Displays the IntelliSense context at cursor position for debugging
---@module ssns.features.view_context
local ViewContext = {}

local BaseViewer = require('ssns.features.base_viewer')
local StatementContext = require('ssns.completion.statement_context')

-- Create viewer instance
local viewer = BaseViewer.create({
  title = "Statement Context",
  min_width = 60,
  max_width = 100,
  footer = "q/Esc: close | r: refresh",
})

---Close the current floating window
function ViewContext.close_current_float()
  viewer:close()
end

---View statement context at cursor position
---Detects context and displays in a floating window
function ViewContext.view_context()
  -- Get buffer info
  local info = BaseViewer.get_buffer_info()

  -- Detect context at cursor
  local context = StatementContext.detect(info.bufnr, info.line_num, info.col)

  if not context then
    vim.notify("SSNS: Failed to detect context", vim.log.levels.ERROR)
    return
  end

  -- Set refresh callback
  viewer.on_refresh = ViewContext.view_context

  -- Show with JSON output
  viewer:show_with_json(function(cb)
    BaseViewer.add_header(cb, "Statement Context (IntelliSense)")

    -- Cursor position info
    cb:section("Cursor Position")
    cb:separator("-", 30)
    cb:spans({
      { text = "  Line: ", style = "label" },
      { text = tostring(info.line_num), style = "number" },
      { text = ", Column: " },
      { text = tostring(info.col), style = "number" },
    })
    cb:spans({
      { text = "  Line text: ", style = "label" },
      { text = info.line_text, style = "muted" },
    })
    cb:spans({
      { text = "  Before cursor: ", style = "label" },
      { text = info.line_text:sub(1, info.col - 1), style = "muted" },
      { text = "|", style = "warning" },
    })
    cb:blank()

    -- Main context info
    cb:section("Context Detection")
    cb:separator("-", 30)
    BaseViewer.add_field(cb, "Type", context.type or "unknown", "emphasis")
    BaseViewer.add_field(cb, "Mode", context.mode or "unknown", "emphasis")
    cb:spans({
      { text = "  Prefix: ", style = "label" },
      { text = "\"" .. (context.prefix or "") .. "\"", style = "string" },
    })
    cb:spans({
      { text = "  Trigger: ", style = "label" },
      { text = context.trigger and ("\"" .. context.trigger .. "\"") or "nil", style = context.trigger and "string" or "muted" },
    })
    cb:blank()

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
          cb:section("Extra Context")
          cb:separator("-", 30)
          has_extra = true
        end
        local value = context[field]
        if type(value) == "table" then
          cb:spans({
            { text = "  " },
            { text = field, style = "label" },
            { text = ":" },
          })
          for k, v in pairs(value) do
            cb:spans({
              { text = "    " },
              { text = tostring(k), style = "key" },
              { text = ": " },
              { text = tostring(v), style = "value" },
            })
          end
        else
          BaseViewer.add_field(cb, field, value)
        end
      end
    end
    if has_extra then
      cb:blank()
    end

    -- Tables in scope
    if context.tables_in_scope and #context.tables_in_scope > 0 then
      cb:section("Tables in Scope")
      cb:separator("-", 30)
      for i, t in ipairs(context.tables_in_scope) do
        local desc
        local style = "sql_table"
        if t.is_cte then
          local col_count = t.columns and #t.columns or 0
          desc = string.format("[CTE] %s (%d columns)", t.name, col_count)
          style = "sql_view"
        elseif t.is_subquery then
          local col_count = t.columns and #t.columns or 0
          desc = string.format("[Subquery] %s AS %s (%d columns)", t.name or "?", t.alias or t.name, col_count)
          style = "muted"
        elseif t.is_temp_table then
          local col_count = t.columns and #t.columns or 0
          desc = string.format("[Temp] %s%s (%d columns)", t.name, t.alias and (" AS " .. t.alias) or "", col_count)
          style = "warning"
        elseif t.is_tvf then
          desc = string.format("[TVF] %s.%s AS %s", t.schema or "dbo", t.function_name or t.name, t.alias or t.name)
          style = "func"
        else
          desc = string.format("%s AS %s", t.table or t.name or "?", t.alias or "-")
        end
        cb:spans({
          { text = string.format("  %d. ", i), style = "muted" },
          { text = desc, style = style },
        })
      end
      cb:blank()
    end

    -- Aliases map
    if context.aliases and next(context.aliases) then
      cb:section("Alias Map")
      cb:separator("-", 30)
      local sorted_aliases = {}
      for alias in pairs(context.aliases) do
        table.insert(sorted_aliases, alias)
      end
      table.sort(sorted_aliases)
      for _, alias in ipairs(sorted_aliases) do
        cb:spans({
          { text = "  " },
          { text = alias, style = "emphasis" },
          { text = " -> " },
          { text = context.aliases[alias], style = "sql_table" },
        })
      end
      cb:blank()
    end

    -- CTEs
    if context.ctes and next(context.ctes) then
      cb:section("CTEs")
      cb:separator("-", 30)
      for name, cte in pairs(context.ctes) do
        local col_count = cte.columns and #cte.columns or 0
        cb:spans({
          { text = "  " },
          { text = name, style = "sql_view" },
          { text = " (" },
          { text = tostring(col_count), style = "number" },
          { text = " columns)" },
        })
      end
      cb:blank()
    end

    -- Temp tables
    if context.temp_tables and next(context.temp_tables) then
      cb:section("Temp Tables")
      cb:separator("-", 30)
      for name, temp in pairs(context.temp_tables) do
        local col_count = temp.columns and #temp.columns or 0
        local global = temp.is_global and " (global)" or ""
        cb:spans({
          { text = "  " },
          { text = name, style = "warning" },
          { text = global, style = "muted" },
          { text = " (" },
          { text = tostring(col_count), style = "number" },
          { text = " columns)" },
        })
      end
      cb:blank()
    end

    -- Statement chunk info (brief)
    if context.chunk then
      cb:section("Statement Chunk")
      cb:separator("-", 30)
      BaseViewer.add_field(cb, "Type", context.chunk.statement_type or "?", "keyword")
      cb:spans({
        { text = "  Lines: ", style = "label" },
        { text = tostring(context.chunk.start_line or 0), style = "number" },
        { text = "-" },
        { text = tostring(context.chunk.end_line or 0), style = "number" },
      })
      BaseViewer.add_count(cb, "Tables", context.chunk.tables and #context.chunk.tables or 0)
      BaseViewer.add_count(cb, "Columns", context.chunk.columns and #context.chunk.columns or 0)
      cb:blank()
    end

    -- Return cleaned context for JSON output
    return {
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
  end, "Full JSON Output")
end

return ViewContext

