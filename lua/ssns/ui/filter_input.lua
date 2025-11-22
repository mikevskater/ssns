---@class UiFilterInput
---Filter input UI for database object filtering
local UiFilterInput = {}

---@class FilterInputState
---@field main_buf number Main window buffer
---@field main_win number Main window
---@field footer_buf number Footer buffer
---@field footer_win number Footer window
---@field group BaseDbObject The group being filtered
---@field filters table Current filter values
---@field fields table[] List of filter fields
---@field selected_field_idx number Currently selected field index
---@field callback function Callback function with filter values
---@field object_types table? Available object types for schema nodes

---@type FilterInputState?
local state = nil

---Object type options for schema filtering
---Keys must match actual object_type values from the class definitions
local OBJECT_TYPES = {
  { key = "table", label = "Tables" },
  { key = "view", label = "Views" },
  { key = "procedure", label = "Procedures" },
  { key = "function", label = "Functions" },
  { key = "synonym", label = "Synonyms" },
  { key = "sequence", label = "Sequences" },
}

---Show filter input form
---@param group BaseDbObject The group to filter
---@param current_filters table? Current filter state
---@param callback function Callback function(filters: table)
function UiFilterInput.show_input(group, current_filters, callback)
  current_filters = current_filters or {}

  -- Determine if this is a schema node (needs object type filters)
  local is_schema_node = group.object_type == "schema" or group.object_type == "schema_view"

  -- Build field list
  local fields = {
    { name = "name_include", label = "Include Name (regex)", type = "text", value = current_filters.name_include or "" },
    { name = "name_exclude", label = "Exclude Name (regex)", type = "text", value = current_filters.name_exclude or "" },
    { name = "schema_include", label = "Include Schema (regex)", type = "text", value = current_filters.schema_include or "" },
    { name = "schema_exclude", label = "Exclude Schema (regex)", type = "text", value = current_filters.schema_exclude or "" },
    { name = "case_sensitive", label = "Case Sensitive", type = "checkbox", value = current_filters.case_sensitive or false },
  }

  -- Add object type checkboxes for schema nodes
  local object_types_map = nil
  if is_schema_node then
    object_types_map = current_filters.object_types or {}
    for _, otype in ipairs(OBJECT_TYPES) do
      table.insert(fields, {
        name = "type_" .. otype.key,
        label = otype.label,
        type = "checkbox",
        value = object_types_map[otype.key] ~= false,  -- Default to true unless explicitly false
        object_type_key = otype.key,
      })
    end
  end

  -- Initialize state
  state = {
    group = group,
    filters = current_filters,
    fields = fields,
    selected_field_idx = 1,
    callback = callback,
    object_types = object_types_map,
  }

  -- Create the layout
  UiFilterInput._create_layout()

  -- Render content
  UiFilterInput._render()

  -- Setup keymaps
  UiFilterInput._setup_keymaps()
end

---Create the floating window layout
function UiFilterInput._create_layout()
  local cols = vim.o.columns
  local lines = vim.o.lines

  -- Calculate dimensions: 50% width, auto height based on field count
  local width = math.floor(cols * 0.5)
  local height = math.min(5 + (#state.fields * 2) + 2, math.floor(lines * 0.7))  -- 2 lines per field + header + footer
  local row = math.floor((lines - height) / 2) - 2  -- -2 for footer
  local col = math.floor((cols - width) / 2)

  -- Create main buffer
  state.main_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.main_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(state.main_buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(state.main_buf, 'bufhidden', 'wipe')

  -- Create main window
  state.main_win = vim.api.nvim_open_win(state.main_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = string.format(" Filter: %s ", state.group.name),
    title_pos = "center",
    zindex = 50,
  })

  -- Configure window options
  vim.api.nvim_set_option_value('number', false, { win = state.main_win })
  vim.api.nvim_set_option_value('relativenumber', false, { win = state.main_win })
  vim.api.nvim_set_option_value('cursorline', false, { win = state.main_win })
  vim.api.nvim_set_option_value('wrap', false, { win = state.main_win })
  vim.api.nvim_set_option_value('signcolumn', 'no', { win = state.main_win })

  -- Create footer
  state.footer_buf = vim.api.nvim_create_buf(false, true)
  local footer_text = " <Enter>=Apply | <Esc>=Cancel | F=Clear | j/k=Navigate | i=Edit | <Space>=Toggle "
  local footer_padding = math.floor((width - #footer_text) / 2)
  local centered_footer = string.rep(" ", footer_padding) .. footer_text

  vim.api.nvim_buf_set_lines(state.footer_buf, 0, -1, false, {centered_footer})
  vim.api.nvim_buf_set_option(state.footer_buf, 'modifiable', false)

  state.footer_win = vim.api.nvim_open_win(state.footer_buf, false, {
    relative = "editor",
    width = width,
    height = 1,
    row = row + height + 2,
    col = col,
    style = "minimal",
    border = "none",
    zindex = 51,
    focusable = false,
  })

  vim.api.nvim_set_option_value('winhighlight', 'Normal:Comment', { win = state.footer_win })
end

---Render filter form
function UiFilterInput._render()
  local lines = {}

  -- Calculate filtered count if filters are applied
  local filter_info = ""
  local has_any_filter = false
  for _, field in ipairs(state.fields) do
    if field.type == "text" and field.value ~= "" then
      has_any_filter = true
      break
    elseif field.type == "checkbox" and field.name == "case_sensitive" and field.value then
      has_any_filter = true
      break
    end
  end

  if has_any_filter then
    local UiFilters = require('ssns.ui.filters')
    local all_children = state.group:get_children() or {}
    local filtered, total = UiFilters.apply(all_children, UiFilterInput._build_filter_state())
    filter_info = string.format(" (%d/%d matches)", #filtered, total)
  end

  -- Header
  table.insert(lines, string.format("Filtering: %s%s", state.group.name, filter_info))
  table.insert(lines, string.rep("─", 50))
  table.insert(lines, "")

  -- Group text fields
  local text_fields_end = 0
  for i, field in ipairs(state.fields) do
    if field.type == "text" then
      text_fields_end = i
    else
      break
    end
  end

  -- Render text fields
  for i = 1, text_fields_end do
    local field = state.fields[i]
    local prefix = i == state.selected_field_idx and "▶ " or "  "
    table.insert(lines, string.format("%s%s", prefix, field.label))
    table.insert(lines, string.format("  Pattern: %s", field.value or ""))
    if i < text_fields_end then
      table.insert(lines, "")
    end
  end

  -- Render checkboxes
  if text_fields_end < #state.fields then
    -- Check if we have object type checkboxes (not just Case Sensitive)
    local has_object_types = false
    for i = text_fields_end + 1, #state.fields do
      if state.fields[i].object_type_key then
        has_object_types = true
        break
      end
    end

    -- Only show "Options:" header if we have multiple checkboxes
    if has_object_types then
      table.insert(lines, "")
      table.insert(lines, "Options:")
      table.insert(lines, "")
    else
      table.insert(lines, "")
    end

    for i = text_fields_end + 1, #state.fields do
      local field = state.fields[i]
      local prefix = i == state.selected_field_idx and "▶ " or "  "
      local checkbox = field.value and "[x]" or "[ ]"
      table.insert(lines, string.format("%s%s %s", prefix, checkbox, field.label))
    end
  end

  -- Update buffer
  vim.api.nvim_buf_set_option(state.main_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.main_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.main_buf, 'modifiable', false)

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace("ssns_filter_input")
  vim.api.nvim_buf_clear_namespace(state.main_buf, ns_id, 0, -1)

  -- Highlight header
  vim.api.nvim_buf_add_highlight(state.main_buf, ns_id, "Comment", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(state.main_buf, ns_id, "Comment", 1, 0, -1)

  -- Find and highlight selected field
  local line_idx = 3
  for i, field in ipairs(state.fields) do
    local is_selected = i == state.selected_field_idx

    if field.type == "text" then
      if is_selected then
        vim.api.nvim_buf_add_highlight(state.main_buf, ns_id, "Title", line_idx, 0, -1)
        vim.api.nvim_buf_add_highlight(state.main_buf, ns_id, "String", line_idx + 1, 0, -1)
      end
      line_idx = line_idx + 2
      if i < text_fields_end then
        line_idx = line_idx + 1  -- Empty line between text fields
      end
    else
      if i == text_fields_end + 1 then
        line_idx = line_idx + 3  -- Skip blank line and "Options:" header
      end
      if is_selected then
        vim.api.nvim_buf_add_highlight(state.main_buf, ns_id, "Title", line_idx, 0, -1)
      end
      line_idx = line_idx + 1
    end
  end
end

---Setup keymaps
function UiFilterInput._setup_keymaps()
  -- Cancel
  vim.keymap.set('n', '<Esc>', function()
    UiFilterInput._close(false)
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Cancel" })

  vim.keymap.set('n', 'q', function()
    UiFilterInput._close(false)
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Cancel" })

  -- Apply
  vim.keymap.set('n', '<CR>', function()
    UiFilterInput._apply()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Apply filters" })

  -- Clear all filters
  vim.keymap.set('n', 'F', function()
    UiFilterInput._clear_all()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Clear all filters" })

  -- Navigation
  vim.keymap.set('n', 'j', function()
    UiFilterInput._move_down()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Next field" })

  vim.keymap.set('n', 'k', function()
    UiFilterInput._move_up()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Previous field" })

  vim.keymap.set('n', '<Tab>', function()
    UiFilterInput._move_down()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Next field" })

  vim.keymap.set('n', '<S-Tab>', function()
    UiFilterInput._move_up()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Previous field" })

  -- Edit text field
  vim.keymap.set('n', 'i', function()
    UiFilterInput._edit_field()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Edit field" })

  -- Toggle checkbox
  vim.keymap.set('n', '<Space>', function()
    UiFilterInput._toggle_checkbox()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Toggle checkbox" })
end

---Move to next field
function UiFilterInput._move_down()
  if state.selected_field_idx < #state.fields then
    state.selected_field_idx = state.selected_field_idx + 1
    UiFilterInput._render()
  end
end

---Move to previous field
function UiFilterInput._move_up()
  if state.selected_field_idx > 1 then
    state.selected_field_idx = state.selected_field_idx - 1
    UiFilterInput._render()
  end
end

---Edit current text field
function UiFilterInput._edit_field()
  local field = state.fields[state.selected_field_idx]
  if field.type ~= "text" then
    vim.notify("Use <Space> to toggle checkboxes", vim.log.levels.INFO)
    return
  end

  local current_value = field.value or ""

  -- Prompt for new value
  vim.ui.input({
    prompt = string.format("%s: ", field.label),
    default = current_value,
  }, function(input)
    if input ~= nil then
      field.value = input
      UiFilterInput._render()
    end
  end)
end

---Toggle current checkbox field
function UiFilterInput._toggle_checkbox()
  local field = state.fields[state.selected_field_idx]
  if field.type ~= "checkbox" then
    vim.notify("Use 'i' to edit text fields", vim.log.levels.INFO)
    return
  end

  field.value = not field.value
  UiFilterInput._render()
end

---Clear all filter values
function UiFilterInput._clear_all()
  for _, field in ipairs(state.fields) do
    if field.type == "text" then
      field.value = ""
    elseif field.type == "checkbox" then
      if field.name == "case_sensitive" then
        field.value = false
      else
        field.value = true  -- Object types default to true
      end
    end
  end
  UiFilterInput._render()
end

---Build filter state from current field values
---@return table filter_state
function UiFilterInput._build_filter_state()
  local filter_state = {}
  local object_type_fields = {}

  -- Collect text fields and checkboxes
  for _, field in ipairs(state.fields) do
    if field.type == "text" and field.value ~= "" then
      filter_state[field.name] = field.value
    elseif field.type == "checkbox" and field.name == "case_sensitive" then
      filter_state.case_sensitive = field.value
    elseif field.type == "checkbox" and field.object_type_key then
      table.insert(object_type_fields, field)
    end
  end

  -- Only set object_types if not all are checked (i.e., filtering is active)
  if #object_type_fields > 0 then
    local all_checked = true
    local any_unchecked = false

    for _, field in ipairs(object_type_fields) do
      if not field.value then
        any_unchecked = true
        all_checked = false
        break
      end
    end

    -- Only create object_types filter if some (but not all) are checked
    -- If all are checked, don't filter (show everything)
    -- If none are checked, also don't filter (debatable, but safer)
    if any_unchecked and not all_checked then
      filter_state.object_types = {}
      for _, field in ipairs(object_type_fields) do
        filter_state.object_types[field.object_type_key] = field.value
      end
    end
  end

  return filter_state
end

---Apply filters
function UiFilterInput._apply()
  local filter_state = UiFilterInput._build_filter_state()
  UiFilterInput._close(true, filter_state)
end

---Close filter input form
---@param apply boolean Whether to apply filters
---@param filter_state table? Filter state if applying
function UiFilterInput._close(apply, filter_state)
  if not state then
    return
  end

  -- Close windows
  if state.main_win and vim.api.nvim_win_is_valid(state.main_win) then
    pcall(vim.api.nvim_win_close, state.main_win, true)
  end
  if state.footer_win and vim.api.nvim_win_is_valid(state.footer_win) then
    pcall(vim.api.nvim_win_close, state.footer_win, true)
  end

  -- Call callback if applying
  if apply and filter_state and state.callback then
    state.callback(filter_state)
  end

  state = nil
end

return UiFilterInput
