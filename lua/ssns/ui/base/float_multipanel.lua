---@class UiFloatMultiPanel
---Multi-panel floating window system
---Provides coordinated management of multiple floating windows (e.g., list + preview)
local UiFloatMultiPanel = {}

local UiFloatBase = require('ssns.ui.base.float_base')
local KeymapManager = require('ssns.keymap_manager')

---@class PanelConfig
---@field name string Panel name (e.g., "list", "preview")
---@field width_ratio number Width ratio (0.0 to 1.0)
---@field title string? Panel title
---@field on_render fun(state: MultiPanelState): string[] Rendering callback
---@field on_focus fun(state: MultiPanelState)? Called when panel gains focus
---@field on_blur fun(state: MultiPanelState)? Called when panel loses focus
---@field readonly boolean? If true, panel is not focusable (default: false)
---@field filetype string? Filetype for syntax highlighting
---@field keymaps table[]? Panel-specific keymaps

---@class MultiPanelConfig
---@field panels PanelConfig[] Array of panel configurations
---@field total_width number? Total width (default: 80% of screen)
---@field total_height number? Total height (default: 85% of screen)
---@field footer string? Footer text
---@field on_close fun(state: MultiPanelState)? Called when closed
---@field on_selection_change fun(state: MultiPanelState)? Called when selection changes
---@field initial_data any? Initial state data
---@field initial_focus string? Initial focused panel name (default: first panel)

---@class MultiPanelState
---@field buffers table<string, number> Map of panel name -> buffer number
---@field windows table<string, number> Map of panel name -> window ID
---@field footer_buf number? Footer buffer
---@field footer_win number? Footer window
---@field focused_panel string Currently focused panel name
---@field selected_idx number Selected item index
---@field data any Custom data
---@field config MultiPanelConfig Configuration
---@field namespaces table<string, number> Map of panel name -> namespace ID

---Create multi-panel floating UI
---@param config MultiPanelConfig Configuration
---@return MultiPanelState? state The state object (nil if creation failed)
function UiFloatMultiPanel.create(config)
  -- Validate config
  if not config.panels or #config.panels == 0 then
    vim.notify("SSNS: At least one panel is required", vim.log.levels.ERROR)
    return nil
  end

  -- Calculate dimensions
  local ui = vim.api.nvim_list_uis()[1]
  local total_width = config.total_width or math.floor(ui.width * 0.8)
  local total_height = config.total_height or math.floor(ui.height * 0.85)

  -- Extract width ratios
  local ratios = {}
  for _, panel in ipairs(config.panels) do
    table.insert(ratios, panel.width_ratio)
  end

  -- Calculate layouts for each panel
  local layouts = UiFloatBase.calculate_split_layout(total_width, total_height, ratios)

  -- Create state
  local state = {
    buffers = {},
    windows = {},
    focused_panel = config.initial_focus or config.panels[1].name,
    selected_idx = 1,
    data = config.initial_data,
    config = config,
    namespaces = {},
  }

  -- Create panels
  for i, panel in ipairs(config.panels) do
    -- Create buffer
    local bufnr = UiFloatBase.create_buffer({})
    state.buffers[panel.name] = bufnr

    if panel.filetype then
      vim.api.nvim_buf_set_option(bufnr, 'filetype', panel.filetype)
    end

    -- Create window with split border
    local is_first = i == 1
    local is_last = i == #config.panels
    local border = UiFloatBase.create_split_border(is_first, is_last)

    local layout = layouts[i]
    local winid = vim.api.nvim_open_win(bufnr, false, {
      relative = 'editor',
      width = layout.width,
      height = layout.height,
      row = layout.row,
      col = layout.col,
      style = 'minimal',
      border = border,
      title = panel.title and string.format(" %s ", panel.title) or nil,
      title_pos = 'center',
      zindex = 50,
      focusable = not panel.readonly,
    })

    state.windows[panel.name] = winid

    -- Create namespace for highlights
    state.namespaces[panel.name] = UiFloatBase.create_namespace("ssns_panel_" .. panel.name)

    -- Set window options
    UiFloatBase.set_window_options(winid, {
      number = false,
      relativenumber = false,
      cursorline = not panel.readonly,
      wrap = false,
      signcolumn = 'no',
    })
  end

  -- Create footer if specified
  if config.footer then
    state.footer_buf = UiFloatBase.create_buffer({})
    local start_row = layouts[1].row
    local start_col = layouts[1].col

    local text_len = #config.footer
    local padding = math.floor((total_width - text_len) / 2)
    local centered_text = string.rep(" ", math.max(0, padding)) .. config.footer

    UiFloatBase.set_buffer_lines(state.footer_buf, {centered_text})

    state.footer_win = vim.api.nvim_open_win(state.footer_buf, false, {
      relative = "editor",
      width = total_width,
      height = 1,
      row = start_row + total_height + 2,
      col = start_col,
      style = "minimal",
      border = "none",
      zindex = 52,
      focusable = false,
    })

    UiFloatBase.set_window_options(state.footer_win, {
      winhighlight = 'Normal:SsnsFloatHint',
    })
  end

  -- Focus initial panel
  local initial_panel = config.initial_focus or config.panels[1].name
  vim.api.nvim_set_current_win(state.windows[initial_panel])
  state.focused_panel = initial_panel

  -- Render all panels
  UiFloatMultiPanel.render_all(state)

  -- Setup keymaps
  UiFloatMultiPanel.setup_keymaps(state)

  -- Setup cleanup
  UiFloatMultiPanel.setup_cleanup(state)

  return state
end

---Render all panels
---@param state MultiPanelState
function UiFloatMultiPanel.render_all(state)
  for _, panel in ipairs(state.config.panels) do
    UiFloatMultiPanel.render_panel(state, panel.name)
  end
end

---Render a specific panel
---@param state MultiPanelState
---@param panel_name string Panel name
function UiFloatMultiPanel.render_panel(state, panel_name)
  local bufnr = state.buffers[panel_name]
  if not bufnr then return end

  -- Find panel config
  local panel_config = nil
  for _, panel in ipairs(state.config.panels) do
    if panel.name == panel_name then
      panel_config = panel
      break
    end
  end

  if not panel_config or not panel_config.on_render then
    return
  end

  -- Get lines from render callback
  local lines = panel_config.on_render(state)

  -- Set buffer lines
  UiFloatBase.set_buffer_lines(bufnr, lines)
end

---Switch focus to another panel
---@param state MultiPanelState
---@param panel_name string Target panel name
function UiFloatMultiPanel.focus_panel(state, panel_name)
  if not state.windows[panel_name] then
    return
  end

  -- Find panel config
  local target_panel = nil
  for _, panel in ipairs(state.config.panels) do
    if panel.name == panel_name then
      target_panel = panel
      break
    end
  end

  if not target_panel or target_panel.readonly then
    return
  end

  -- Call blur callback on current panel
  local current_panel = nil
  for _, panel in ipairs(state.config.panels) do
    if panel.name == state.focused_panel then
      current_panel = panel
      break
    end
  end

  if current_panel and current_panel.on_blur then
    current_panel.on_blur(state)
  end

  -- Switch focus
  state.focused_panel = panel_name
  vim.api.nvim_set_current_win(state.windows[panel_name])

  -- Call focus callback
  if target_panel.on_focus then
    target_panel.on_focus(state)
  end
end

---Navigate in the focused panel
---@param state MultiPanelState
---@param direction number 1 for down, -1 for up
function UiFloatMultiPanel.navigate(state, direction)
  -- This is typically overridden per use case
  -- Default implementation: simple index navigation
  state.selected_idx = state.selected_idx + direction

  -- Clamp to valid range (assuming items exist)
  if state.selected_idx < 1 then
    state.selected_idx = 1
  end

  -- Re-render focused panel
  UiFloatMultiPanel.render_panel(state, state.focused_panel)

  -- Call selection change callback
  if state.config.on_selection_change then
    state.config.on_selection_change(state)
  end
end

---Setup keymaps for all panels
---@param state MultiPanelState
function UiFloatMultiPanel.setup_keymaps(state)
  for _, panel in ipairs(state.config.panels) do
    local bufnr = state.buffers[panel.name]

    if panel.keymaps then
      UiFloatBase.set_keymaps(bufnr, panel.keymaps, 'multipanel_' .. panel.name)
    end
  end
end

---Setup cleanup autocmds
---@param state MultiPanelState
function UiFloatMultiPanel.setup_cleanup(state)
  -- Close all windows when any window is closed
  for panel_name, winid in pairs(state.windows) do
    UiFloatBase.setup_cleanup_autocmd(winid, function()
      UiFloatMultiPanel.close(state)
    end)
  end
end

---Close the multi-panel UI
---@param state MultiPanelState
function UiFloatMultiPanel.close(state)
  if not state then return end

  -- Call close callback
  if state.config.on_close then
    state.config.on_close(state)
  end

  -- Close footer
  if state.footer_win then
    UiFloatBase.close_window(state.footer_win)
    UiFloatBase.delete_buffer(state.footer_buf)
  end

  -- Close all panels
  for _, winid in pairs(state.windows) do
    UiFloatBase.close_window(winid)
  end

  for _, bufnr in pairs(state.buffers) do
    UiFloatBase.delete_buffer(bufnr)
  end
end

return UiFloatMultiPanel
