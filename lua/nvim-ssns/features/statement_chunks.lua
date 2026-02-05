---@class StatementChunksViewer
---View parsed statement chunks in a floating window
---Displays the internal parse result for debugging and understanding
---@module ssns.features.statement_chunks
local StatementChunksViewer = {}

local UiFloat = require('nvim-float.window')
local ContentBuilder = require('nvim-float.content')
local JsonUtils = require('nvim-ssns.utils.json')
local StatementParser = require('nvim-ssns.completion.statement_parser')
local StatementCache = require('nvim-ssns.completion.statement_cache')

-- Store reference to current floating window for cleanup
local current_float = nil

---Close the current floating window
function StatementChunksViewer.close_current_float()
  if current_float then
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
end

---View statement chunks for the current buffer
---Parses the buffer content and displays parsed chunks in a floating window
function StatementChunksViewer.view_statement_chunks()
  -- Close any existing float
  StatementChunksViewer.close_current_float()

  -- Get current buffer content
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")

  if text == "" then
    vim.notify("SSNS: Buffer is empty", vim.log.levels.WARN)
    return
  end

  -- Use cached parse result from StatementCache (avoids redundant parsing)
  local cache = StatementCache.get_or_build_cache(bufnr)
  local parse_result
  if cache then
    parse_result = {
      chunks = cache.chunks,
      temp_tables = cache.temp_tables,
      tokens = cache.tokens,
    }
  else
    -- Fallback to direct parsing if cache unavailable
    parse_result = StatementParser.parse(text)
  end

  if not parse_result then
    vim.notify("SSNS: Failed to parse buffer content", vim.log.levels.ERROR)
    return
  end

  -- Build styled content
  local cb = ContentBuilder.new()

  cb:header("Statement Parser Results")
  cb:separator()
  cb:blank()

  -- Summary section
  cb:section("Summary")
  cb:label_value("  Chunks", tostring(#(parse_result.chunks or {})))
  cb:label_value("  Temp Tables", tostring(vim.tbl_count(parse_result.temp_tables or {})))
  cb:blank()

  -- Temp tables section
  if parse_result.temp_tables and vim.tbl_count(parse_result.temp_tables) > 0 then
    cb:section("Temp Tables")
    for name, info in pairs(parse_result.temp_tables) do
      cb:spans({
        { text = "  ", style = "text" },
        { text = name, style = "sql_table" },
        { text = string.format(" (batch %d):", info.created_in_batch or 0), style = "muted" },
      })
      if info.columns and #info.columns > 0 then
        for _, col in ipairs(info.columns) do
          cb:spans({
            { text = "    - ", style = "muted" },
            { text = col.name or col, style = "sql_column" },
          })
        end
      end
    end
    cb:blank()
  end

  -- Statement chunks section
  if parse_result.chunks and #parse_result.chunks > 0 then
    for i, chunk in ipairs(parse_result.chunks) do
      cb:spans({
        { text = string.format("Chunk #%d: ", i), style = "section" },
        { text = chunk.statement_type or "UNKNOWN", style = "keyword" },
      })
      cb:styled(string.rep("-", 30), "muted")

      -- Location info
      cb:spans({
        { text = "  Lines: ", style = "label" },
        { text = string.format("%d-%d", chunk.start_line or 0, chunk.end_line or 0), style = "value" },
        { text = string.format(" (batch %d)", chunk.go_batch_index or 1), style = "muted" },
      })
      cb:blank()

      -- Tables
      if chunk.tables and #chunk.tables > 0 then
        cb:styled("  Tables:", "label")
        for _, tbl in ipairs(chunk.tables) do
          local spans = {{ text = "    - ", style = "muted" }}
          if tbl.schema then
            table.insert(spans, { text = tbl.schema, style = "sql_schema" })
            table.insert(spans, { text = ".", style = "text" })
          end
          table.insert(spans, { text = tbl.name or "?", style = "sql_table" })
          if tbl.alias then
            table.insert(spans, { text = " AS ", style = "muted" })
            table.insert(spans, { text = tbl.alias, style = "alias" })
          end
          cb:spans(spans)
        end
        cb:blank()
      end

      -- Columns (for SELECT)
      if chunk.columns and #chunk.columns > 0 then
        cb:styled("  Columns:", "label")
        for _, col in ipairs(chunk.columns) do
          local spans = {{ text = "    - ", style = "muted" }}
          if col.source_table then
            table.insert(spans, { text = col.source_table, style = "sql_table" })
            table.insert(spans, { text = ".", style = "text" })
          end
          table.insert(spans, { text = col.name or "*", style = "sql_column" })
          if col.is_star then
            table.insert(spans, { text = " (star)", style = "muted" })
          end
          cb:spans(spans)
        end
        cb:blank()
      end

      -- CTEs
      if chunk.ctes and #chunk.ctes > 0 then
        cb:styled("  CTEs:", "label")
        for _, cte in ipairs(chunk.ctes) do
          cb:spans({
            { text = "    - ", style = "muted" },
            { text = cte.name or "?", style = "cte" },
          })
        end
        cb:blank()
      end

      -- Subqueries
      if chunk.subqueries and #chunk.subqueries > 0 then
        cb:styled("  Subqueries:", "label")
        for j, sq in ipairs(chunk.subqueries) do
          cb:spans({
            { text = string.format("    [%d] ", j), style = "muted" },
            { text = "alias=", style = "label" },
            { text = sq.alias or "(none)", style = sq.alias and "alias" or "muted" },
            { text = ", tables=", style = "label" },
            { text = tostring(sq.tables and #sq.tables or 0), style = "number" },
            { text = ", columns=", style = "label" },
            { text = tostring(sq.columns and #sq.columns or 0), style = "number" },
          })
        end
        cb:blank()
      end

      -- Clause positions
      if chunk.clause_positions and next(chunk.clause_positions) then
        cb:styled("  Clause Positions:", "label")
        local sorted_clauses = {}
        for clause_name in pairs(chunk.clause_positions) do
          table.insert(sorted_clauses, clause_name)
        end
        table.sort(sorted_clauses)
        for _, clause_name in ipairs(sorted_clauses) do
          local pos = chunk.clause_positions[clause_name]
          cb:spans({
            { text = "    ", style = "text" },
            { text = clause_name, style = "keyword" },
            { text = string.format(": L%d:%d - L%d:%d",
                pos.start_line or 0,
                pos.start_col or 0,
                pos.end_line or 0,
                pos.end_col or 0), style = "muted" },
          })
        end
        cb:blank()
      end

      cb:blank()
    end
  else
    cb:styled("(No statement chunks parsed)", "muted")
  end

  -- Add JSON section for full parse result
  cb:blank()
  cb:header("Full JSON Output")
  cb:separator()
  cb:blank()

  -- Prettify the full parse result
  local json_lines = JsonUtils.prettify_lines(parse_result)
  for _, line in ipairs(json_lines) do
    cb:styled(line, "text")
  end

  -- Create floating window with styled content
  current_float = UiFloat.create_styled(cb, {
    title = "Statement Chunks",
    border = "rounded",
    min_width = 60,
    max_width = 120,
    max_height = 40,
    wrap = false,
    keymaps = {
      ['r'] = function()
        -- Refresh: reparse and update content
        StatementChunksViewer.view_statement_chunks()
      end,
    },
    footer = "q/Esc: close | r: refresh",
  })
end

return StatementChunksViewer

