---@class UiHighlights
---Syntax highlighting and icons for SSNS UI
local UiHighlights = {}

---Setup highlight groups
---Now delegates to ThemeManager for actual highlight setup
function UiHighlights.setup()
  -- Initialize and apply theme manager
  local ThemeManager = require('nvim-ssns.ui.theme_manager')
  ThemeManager.setup()
end

---Apply highlights to buffer
---@param line_map table<number, BaseDbObject>? Optional line map from tree
function UiHighlights.apply(line_map)
  local Buffer = require('nvim-ssns.ui.core.buffer')

  if not Buffer.exists() then
    return
  end

  local bufnr = Buffer.bufnr
  local ns = vim.api.nvim_create_namespace('ssns_highlights')

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- If no line_map provided, try to get it from tree
  if not line_map then
    local Tree = require('nvim-ssns.ui.core.tree')
    line_map = Tree.line_map
  end

  if not line_map then
    return
  end

  -- Apply highlights based on object types
  for line_number, obj in pairs(line_map) do
    if obj and obj.object_type then
      local hl_group = UiHighlights.get_highlight_group(obj)
      if hl_group then
        -- Highlight the entire line
        vim.api.nvim_buf_add_highlight(bufnr, ns, hl_group, line_number - 1, 0, -1)
      end
    end
  end
end

---Get highlight group for object
---@param obj BaseDbObject
---@return string?
function UiHighlights.get_highlight_group(obj)
  local object_type = obj.object_type

  -- Special handling for servers - use database-type specific colors
  if object_type == "server" then
    -- Get database type, handling cases where method might not exist
    local db_type = nil
    if obj.get_db_type then
      db_type = obj:get_db_type()
    elseif obj.adapter and obj.adapter.db_type then
      db_type = obj.adapter.db_type
    end

    if db_type == "sqlserver" then
      return "SsnsServerSqlServer"
    elseif db_type == "postgres" or db_type == "postgresql" then
      return "SsnsServerPostgres"
    elseif db_type == "mysql" then
      return "SsnsServerMysql"
    elseif db_type == "sqlite" then
      return "SsnsServerSqlite"
    elseif db_type == "bigquery" then
      return "SsnsServerBigQuery"
    else
      return "SsnsServer"  -- Default/unknown
    end
  end

  -- Special handling for object references - use the referenced object's type
  if object_type == "object_reference" and obj.referenced_object then
    object_type = obj.referenced_object.object_type
  end

  -- Standard object type mapping
  local hl_map = {
    database = "SsnsDatabase",
    schema = "SsnsSchema",
    table = "SsnsTable",
    view = "SsnsView",
    procedure = "SsnsProcedure",
    ["function"] = "SsnsFunction",
    column = "SsnsColumn",
    index = "SsnsIndex",
    key = "SsnsKey",
    parameter = "SsnsParameter",
    sequence = "SsnsSequence",
    synonym = "SsnsSynonym",
    action = "SsnsAction",
    add_server_action = "SsnsAddServerAction",
    -- Server groups
    server_group = "SsnsServerGroup",
    -- Groups
    databases_group = "SsnsGroup",
    tables_group = "SsnsGroup",
    views_group = "SsnsGroup",
    procedures_group = "SsnsGroup",
    functions_group = "SsnsGroup",
    scalar_functions_group = "SsnsGroup",
    table_functions_group = "SsnsGroup",
    sequences_group = "SsnsGroup",
    synonyms_group = "SsnsGroup",
    schemas_group = "SsnsGroup",
    system_databases_group = "SsnsGroup",
    system_schemas_group = "SsnsGroup",
    column_group = "SsnsGroup",
    index_group = "SsnsGroup",
    key_group = "SsnsGroup",
    parameter_group = "SsnsGroup",
    actions_group = "SsnsGroup",
    -- Schema nodes
    schema_view = "SsnsSchema",
  }

  return hl_map[object_type]
end

---Setup filetype detection
function UiHighlights.setup_filetype()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "ssns",
    callback = function()
      UiHighlights.setup()
      UiHighlights.apply()
    end,
  })
end

---@class BatchedHighlightOpts
---@field batch_size number? Lines per batch (default 100)
---@field on_progress fun(processed: number, total: number)? Progress callback
---@field on_complete fun()? Completion callback

---Active batched highlight state (only one can be active at a time)
---@type { timer: number?, cancelled: boolean }?
UiHighlights._batched_state = nil

---Apply highlights to buffer in batches to avoid blocking UI
---For large line counts, this applies highlights in batches with vim.schedule() between each
---@param line_map table<number, BaseDbObject>? Line map from tree
---@param opts BatchedHighlightOpts? Options for batched highlighting
function UiHighlights.apply_batched(line_map, opts)
  local Buffer = require('nvim-ssns.ui.core.buffer')

  if not Buffer.exists() then
    if opts and opts.on_complete then opts.on_complete() end
    return
  end

  -- If no line_map provided, try to get it from tree
  if not line_map then
    local Tree = require('nvim-ssns.ui.core.tree')
    line_map = Tree.line_map
  end

  if not line_map then
    if opts and opts.on_complete then opts.on_complete() end
    return
  end

  opts = opts or {}
  local batch_size = opts.batch_size or 100
  local on_progress = opts.on_progress
  local on_complete = opts.on_complete

  -- Convert line_map to sorted array of line numbers for ordered processing
  local line_numbers = {}
  for line_number, _ in pairs(line_map) do
    table.insert(line_numbers, line_number)
  end
  table.sort(line_numbers)

  local total_lines = #line_numbers

  -- Cancel any existing batched highlight operation
  UiHighlights.cancel_batched()

  -- For small line counts, use sync apply
  if total_lines <= batch_size then
    UiHighlights.apply(line_map)
    if on_progress then on_progress(total_lines, total_lines) end
    if on_complete then on_complete() end
    return
  end

  -- Initialize batched state
  UiHighlights._batched_state = {
    timer = nil,
    cancelled = false,
  }

  local state = UiHighlights._batched_state
  local bufnr = Buffer.bufnr
  local ns = vim.api.nvim_create_namespace('ssns_highlights')
  local current_idx = 1

  -- Clear existing highlights first
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local function apply_next_batch()
    -- Check if cancelled or buffer no longer valid
    if state.cancelled or not Buffer.exists() then
      UiHighlights._batched_state = nil
      return
    end

    local end_idx = math.min(current_idx + batch_size - 1, total_lines)

    -- Apply highlights for this batch
    for i = current_idx, end_idx do
      local line_number = line_numbers[i]
      local obj = line_map[line_number]
      if obj and obj.object_type then
        local hl_group = UiHighlights.get_highlight_group(obj)
        if hl_group then
          vim.api.nvim_buf_add_highlight(bufnr, ns, hl_group, line_number - 1, 0, -1)
        end
      end
    end

    -- Report progress
    if on_progress then
      on_progress(end_idx, total_lines)
    end

    current_idx = end_idx + 1

    if current_idx <= total_lines then
      -- Schedule next batch
      state.timer = vim.fn.timer_start(0, function()
        state.timer = nil
        vim.schedule(apply_next_batch)
      end)
    else
      -- All batches applied
      UiHighlights._batched_state = nil
      if on_complete then
        on_complete()
      end
    end
  end

  -- Start applying first batch
  apply_next_batch()
end

---Cancel any in-progress batched highlight operation
function UiHighlights.cancel_batched()
  if UiHighlights._batched_state then
    UiHighlights._batched_state.cancelled = true
    if UiHighlights._batched_state.timer then
      vim.fn.timer_stop(UiHighlights._batched_state.timer)
      UiHighlights._batched_state.timer = nil
    end
    UiHighlights._batched_state = nil
  end
end

---Check if a batched highlight operation is currently in progress
---@return boolean
function UiHighlights.is_batched_active()
  return UiHighlights._batched_state ~= nil and not UiHighlights._batched_state.cancelled
end

return UiHighlights
