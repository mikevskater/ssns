---@class UiFloatForm
---Form input floating window system
---Provides field-based input with navigation, editing, and validation
local UiFloatForm = {}

local UiFloatBase = require('ssns.ui.base.float_base')
local KeymapManager = require('ssns.keymap_manager')

---@class FormField
---@field name string Field name/identifier
---@field label string Display label
---@field type string Field type: "text", "checkbox", "readonly"
---@field value any Current value
---@field validator fun(value: any): boolean, string? Optional validation function
---@field options table? Options for select fields (future)

---@class FormConfig
---@field title string Form title
---@field fields FormField[] Array of form fields
---@field width number? Form width (default: 50% of screen)
---@field height number? Form height (auto-calculated if not provided)
---@field on_submit fun(state: FormState, values: table) Called when form is submitted
---@field on_cancel fun(state: FormState)? Called when form is cancelled
---@field header_text string? Additional header text
---@field initial_data any? Initial state data

---@class FormState
---@field main_buf number Main buffer
---@field main_win number Main window
---@field footer_buf number Footer buffer
---@field footer_win number Footer window
---@field fields FormField[] Form fields
---@field selected_field_idx number Currently selected field index
---@field edit_mode boolean Whether currently in edit mode
---@field data any Custom data
---@field config FormConfig Configuration
---@field namespace number Highlight namespace

---Create a form floating UI
---@param config FormConfig Configuration
---@return FormState? state The state object (nil if creation failed)
function UiFloatForm.create(config)
  -- Validate config
  if not config.fields or #config.fields == 0 then
    vim.notify("SSNS: Form must have at least one field", vim.log.levels.ERROR)
    return nil
  end

  if not config.on_submit then
    vim.notify("SSNS: Form must have on_submit callback", vim.log.levels.ERROR)
    return nil
  end

  -- Calculate dimensions
  local ui = vim.api.nvim_list_uis()[1]
  local width = config.width or math.floor(ui.width * 0.5)
  local height = config.height or math.min(5 + (#config.fields * 3), math.floor(ui.height * 0.7))

  -- Create state
  local state = {
    fields = vim.deepcopy(config.fields),
    selected_field_idx = 1,
    edit_mode = false,
    data = config.initial_data,
    config = config,
    namespace = UiFloatBase.create_namespace("ssns_form"),
  }

  -- Create main buffer and window
  state.main_buf = UiFloatBase.create_buffer({})
  state.main_win = UiFloatBase.create_window(state.main_buf, {
    width = width,
    height = height,
    title = config.title,
    border = 'rounded',
    enter = true,
    zindex = 50,
  })

  UiFloatBase.set_window_options(state.main_win, {
    number = false,
    relativenumber = false,
    cursorline = false,
    wrap = false,
    signcolumn = 'no',
  })

  -- Create footer
  local row, col = UiFloatBase.calculate_centered_position(width, height)
  state.footer_buf = UiFloatBase.create_buffer({})

  local footer_text = " <Enter>=Submit | <Esc>=Cancel | <Tab>=Next | j/k=Navigate | i=Edit "
  local padding = math.floor((width - #footer_text) / 2)
  local centered_footer = string.rep(" ", math.max(0, padding)) .. footer_text

  UiFloatBase.set_buffer_lines(state.footer_buf, {centered_footer})

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

  UiFloatBase.set_window_options(state.footer_win, {
    winhighlight = 'Normal:SsnsFloatHint',
  })

  -- Render
  UiFloatForm.render(state)

  -- Setup keymaps
  UiFloatForm.setup_keymaps(state)

  -- Setup cleanup
  UiFloatBase.setup_cleanup_autocmd(state.main_win, function()
    UiFloatForm.close(state)
  end)

  return state
end

---Render the form
---@param state FormState
function UiFloatForm.render(state)
  local lines = {}

  -- Header
  if state.config.header_text then
    table.insert(lines, state.config.header_text)
    table.insert(lines, string.rep("─", 50))
    table.insert(lines, "")
  end

  -- Fields
  for i, field in ipairs(state.fields) do
    local prefix = i == state.selected_field_idx and "▶ " or "  "
    local value_str = UiFloatForm.format_field_value(field)

    table.insert(lines, string.format("%s%s", prefix, field.label))
    table.insert(lines, string.format("  %s", value_str))
    table.insert(lines, "")
  end

  -- Set buffer lines
  UiFloatBase.set_buffer_lines(state.main_buf, lines)

  -- Apply highlights
  UiFloatBase.clear_highlights(state.main_buf, state.namespace)

  local line_idx = 0
  if state.config.header_text then
    UiFloatBase.add_highlight(state.main_buf, state.namespace, "Comment", 0, 0, -1)
    UiFloatBase.add_highlight(state.main_buf, state.namespace, "Comment", 1, 0, -1)
    line_idx = 3
  end

  for i, field in ipairs(state.fields) do
    if i == state.selected_field_idx then
      UiFloatBase.add_highlight(state.main_buf, state.namespace, "Title", line_idx, 0, -1)
      UiFloatBase.add_highlight(state.main_buf, state.namespace, "String", line_idx + 1, 0, -1)
    end
    line_idx = line_idx + 3
  end

  -- Position cursor
  local cursor_line = state.config.header_text and 3 or 0
  cursor_line = cursor_line + ((state.selected_field_idx - 1) * 3) + 2
  UiFloatBase.set_cursor(state.main_win, cursor_line, 2)
end

---Format field value for display
---@param field FormField
---@return string formatted Formatted value
function UiFloatForm.format_field_value(field)
  if field.type == "checkbox" then
    return field.value and "[x]" or "[ ]"
  elseif field.type == "text" then
    return tostring(field.value or "")
  elseif field.type == "readonly" then
    return tostring(field.value or "")
  else
    return tostring(field.value or "")
  end
end

---Navigate to next field
---@param state FormState
function UiFloatForm.navigate_down(state)
  if state.selected_field_idx < #state.fields then
    state.selected_field_idx = state.selected_field_idx + 1
    UiFloatForm.render(state)
  end
end

---Navigate to previous field
---@param state FormState
function UiFloatForm.navigate_up(state)
  if state.selected_field_idx > 1 then
    state.selected_field_idx = state.selected_field_idx - 1
    UiFloatForm.render(state)
  end
end

---Toggle checkbox field
---@param state FormState
function UiFloatForm.toggle_checkbox(state)
  local field = state.fields[state.selected_field_idx]
  if field.type == "checkbox" then
    field.value = not field.value
    UiFloatForm.render(state)
  end
end

---Enter edit mode for text field
---@param state FormState
function UiFloatForm.enter_edit_mode(state)
  local field = state.fields[state.selected_field_idx]

  if field.type == "text" then
    state.edit_mode = true

    -- Prompt for input
    vim.ui.input({
      prompt = field.label .. ": ",
      default = tostring(field.value or ""),
    }, function(input)
      state.edit_mode = false

      if input ~= nil then
        -- Validate if validator exists
        if field.validator then
          local valid, err = field.validator(input)
          if not valid then
            vim.notify(string.format("SSNS: Invalid value: %s", err or "Validation failed"), vim.log.levels.WARN)
            return
          end
        end

        field.value = input
        UiFloatForm.render(state)
      end
    end)
  elseif field.type == "checkbox" then
    UiFloatForm.toggle_checkbox(state)
  end
end

---Submit the form
---@param state FormState
function UiFloatForm.submit(state)
  -- Collect values
  local values = {}
  for _, field in ipairs(state.fields) do
    values[field.name] = field.value
  end

  -- Validate all fields
  for _, field in ipairs(state.fields) do
    if field.validator then
      local valid, err = field.validator(field.value)
      if not valid then
        vim.notify(string.format("SSNS: %s - %s", field.label, err or "Invalid value"), vim.log.levels.WARN)
        return
      end
    end
  end

  -- Call submit callback
  state.config.on_submit(state, values)
end

---Cancel the form
---@param state FormState
function UiFloatForm.cancel(state)
  if state.config.on_cancel then
    state.config.on_cancel(state)
  else
    UiFloatForm.close(state)
  end
end

---Setup keymaps
---@param state FormState
function UiFloatForm.setup_keymaps(state)
  local keymaps = {
    -- Navigation
    { mode = "n", lhs = "j", rhs = function() UiFloatForm.navigate_down(state) end, desc = "Next field" },
    { mode = "n", lhs = "k", rhs = function() UiFloatForm.navigate_up(state) end, desc = "Previous field" },
    { mode = "n", lhs = "<Tab>", rhs = function() UiFloatForm.navigate_down(state) end, desc = "Next field" },
    { mode = "n", lhs = "<S-Tab>", rhs = function() UiFloatForm.navigate_up(state) end, desc = "Previous field" },

    -- Edit
    { mode = "n", lhs = "i", rhs = function() UiFloatForm.enter_edit_mode(state) end, desc = "Edit field" },
    { mode = "n", lhs = "<Space>", rhs = function() UiFloatForm.toggle_checkbox(state) end, desc = "Toggle checkbox" },

    -- Submit/Cancel
    { mode = "n", lhs = "<CR>", rhs = function() UiFloatForm.submit(state) end, desc = "Submit" },
    { mode = "n", lhs = "<Esc>", rhs = function() UiFloatForm.cancel(state) end, desc = "Cancel" },
    { mode = "n", lhs = "q", rhs = function() UiFloatForm.cancel(state) end, desc = "Close" },
  }

  UiFloatBase.set_keymaps(state.main_buf, keymaps, 'form')
end

---Close the form
---@param state FormState
function UiFloatForm.close(state)
  if not state then return end

  -- Close footer
  UiFloatBase.close_window(state.footer_win)
  UiFloatBase.delete_buffer(state.footer_buf)

  -- Close main window
  UiFloatBase.close_window(state.main_win)
  UiFloatBase.delete_buffer(state.main_buf)
end

return UiFloatForm
