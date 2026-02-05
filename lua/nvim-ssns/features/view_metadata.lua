---@class ViewMetadata
---View SQL object metadata in a floating window
---Uses standardized get_metadata_info() method from object classes
local ViewMetadata = {}

local BaseViewer = require('nvim-ssns.features.base_viewer')
local GoTo = require('nvim-ssns.features.go_to')

-- Create viewer instance
local viewer = BaseViewer.create({
  title = "Metadata",
  min_width = 50,
  max_width = math.floor(vim.o.columns * 0.85),
  max_height = math.floor(vim.o.lines * 0.7),
  footer = " q/ESC/<CR>: close ",
})

---Close the current floating window
function ViewMetadata.close_current_float()
  -- Clean up buffer registration from UiQuery if needed
  if viewer.current_float and viewer.current_float.bufnr then
    local success, UiQuery = pcall(require, 'ssns.ui.query')
    if success then
      UiQuery.query_buffers[viewer.current_float.bufnr] = nil
    end
  end
  viewer:close()
end

---Pad string to width
---@param str string
---@param width number
---@return string
local function pad(str, width)
  str = tostring(str or "")
  if #str >= width then
    return str:sub(1, width)
  end
  return str .. string.rep(" ", width - #str)
end

---Format a metadata section into styled ContentBuilder content
---@param cb ContentBuilder
---@param section table Section with title, headers, rows
local function format_section_styled(cb, section)
  -- Title
  cb:section(section.title)
  cb:blank()

  local headers = section.headers or {}
  local rows = section.rows or {}

  if #rows == 0 then
    cb:styled("  (No data)", "muted")
    return
  end

  -- Calculate column widths
  local widths = {}
  for i, header in ipairs(headers) do
    widths[i] = #tostring(header)
  end
  for _, row in ipairs(rows) do
    for i, cell in ipairs(row) do
      widths[i] = math.max(widths[i] or 0, #tostring(cell or ""))
    end
  end

  -- Cap widths at reasonable max
  for i, w in ipairs(widths) do
    widths[i] = math.min(w, 40)
  end

  -- Build header line
  local header_parts = {}
  for i, header in ipairs(headers) do
    table.insert(header_parts, pad(header, widths[i]))
  end
  cb:styled("  " .. table.concat(header_parts, "  "), "label")

  -- Build separator line
  local sep_parts = {}
  for i, _ in ipairs(headers) do
    table.insert(sep_parts, string.rep("-", widths[i]))
  end
  cb:line("  " .. table.concat(sep_parts, "  "))

  -- Build data rows
  for _, row in ipairs(rows) do
    local row_parts = {}
    for i, _ in ipairs(headers) do
      local cell = row[i] or "-"
      table.insert(row_parts, pad(cell, widths[i]))
    end
    cb:line("  " .. table.concat(row_parts, "  "))
  end
end

---Get display name for an object
---@param obj BaseDbObject
---@return string
local function get_object_display_name(obj)
  return obj.table_name or obj.view_name or obj.procedure_name
         or obj.function_name or obj.synonym_name or obj.name or "unknown"
end

---Show metadata in a floating window
---@param target_object BaseDbObject The resolved object
---@param identifier string The original identifier string
function ViewMetadata.show_metadata_float(target_object, identifier)
  -- Get metadata from object
  local metadata = target_object:get_metadata_info()
  if not metadata or not metadata.sections or #metadata.sections == 0 then
    vim.notify("No metadata available", vim.log.levels.WARN)
    return
  end

  -- Build title
  local obj_type = (target_object.object_type or "object"):upper()
  local obj_name = get_object_display_name(target_object)
  local schema_name = target_object.schema_name
  local display_name = schema_name and (schema_name .. "." .. obj_name) or obj_name
  viewer.title = string.format(" %s: %s ", obj_type, display_name)

  -- Set keymaps for closing
  viewer:set_keymaps({
    ["<Esc>"] = function() ViewMetadata.close_current_float() end,
    ["<CR>"] = function() ViewMetadata.close_current_float() end,
  })

  -- Show content (no JSON needed for metadata viewer)
  viewer:show(function(cb)
    for i, section in ipairs(metadata.sections or {}) do
      if i > 1 then
        cb:blank()  -- Blank line between sections
      end
      format_section_styled(cb, section)
    end
  end)
end

---View the metadata of the object under cursor
function ViewMetadata.view_metadata_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  if not line then
    vim.notify("Cannot read current line", vim.log.levels.WARN)
    return
  end

  local identifier = GoTo.get_identifier_at_cursor(line, col)
  if not identifier or identifier == "" then
    vim.notify("No identifier under cursor", vim.log.levels.WARN)
    return
  end

  local database_name, schema_name, object_name = GoTo.parse_identifier(identifier)

  local target_object, error_msg = GoTo.resolve_object(bufnr, object_name, schema_name, database_name)
  if not target_object then
    vim.notify(error_msg or "Object not found", vim.log.levels.WARN)
    return
  end

  -- Check if object has get_metadata_info method
  if not target_object.get_metadata_info then
    vim.notify(string.format("'%s' does not have viewable metadata", identifier), vim.log.levels.WARN)
    return
  end

  ViewMetadata.show_metadata_float(target_object, identifier)
end

return ViewMetadata

