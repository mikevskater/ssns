---@class ThemePickerActions
---Action handlers for the theme picker and theme editor
local M = {}

local ThemeManager = require('nvim-ssns.ui.theme_manager')

-- ============================================================================
-- Helpers
-- ============================================================================

---Get selected theme index from state (handles both picker and editor state)
---@param state table
---@return number
local function get_selected_idx(state)
  return state.selected_theme_idx or state.selected_idx or 1
end

---Set selected theme index in state (handles both picker and editor state)
---@param state table
---@param idx number
local function set_selected_idx(state, idx)
  if state.selected_theme_idx ~= nil then
    state.selected_theme_idx = idx
  else
    state.selected_idx = idx
  end
end

-- ============================================================================
-- Copy Theme
-- ============================================================================

---Copy a theme to user directory
---@param state table UI state with available_themes and selected_idx/selected_theme_idx
---@param multi_panel MultiPanelWindow? The multi-panel window
---@param on_complete function? Callback after completion
function M.copy_theme(state, multi_panel, on_complete)
  if not state then return end

  local theme = state.available_themes[get_selected_idx(state)]
  if not theme or theme.is_default then
    vim.notify("Cannot copy default theme option", vim.log.levels.WARN)
    return
  end

  local UiFloat = require('nvim-float.window')

  local default_name = theme.display_name .. " - COPY"

  local copy_win = UiFloat.create({
    title = "Copy Theme",
    width = 55,
    height = 8,
    center = true,
    content_builder = true,
    enable_inputs = true,
    zindex = UiFloat.ZINDEX.MODAL,
  })

  if copy_win then
    local cb = copy_win:get_content_builder()
    cb:line("")
    cb:styled(string.format("  Copy theme '%s':", theme.display_name), "NvimFloatTitle")
    cb:line("")
    cb:labeled_input("name", "  New name", {
      value = default_name,
      placeholder = "(enter theme name)",
      width = 35,
    })
    cb:line("")
    cb:styled("  <Enter>=Copy | <Esc>=Cancel", "NvimFloatHint")
    copy_win:render()

    local function do_copy()
      local new_name = copy_win:get_input_value("name")
      copy_win:close()

      if not new_name or new_name == "" then return end

      local ok, err = ThemeManager.copy(theme.name, new_name)
      if ok then
        -- Clear cache and reload
        ThemeManager.clear_cache()

        -- Reload available themes
        local themes = ThemeManager.get_available_themes()
        table.insert(themes, 1, {
          name = nil,
          display_name = "Default",
          description = "Use default colors from config",
          is_user = false,
          is_default = true,
        })
        state.available_themes = themes

        -- Find and select the new theme
        local file_name = new_name:gsub("[^%w_%-]", "_")
        for i, t in ipairs(state.available_themes) do
          if t.name == file_name or t.display_name == new_name then
            set_selected_idx(state, i)
            break
          end
        end

        if multi_panel then
          multi_panel:render_panel("themes")
        end

        vim.notify("Theme copied: " .. new_name, vim.log.levels.INFO)

        if on_complete then
          on_complete(true)
        end
      else
        vim.notify("Failed to copy: " .. (err or "unknown"), vim.log.levels.ERROR)
        if on_complete then
          on_complete(false)
        end
      end
    end

    vim.keymap.set("n", "<CR>", function()
      copy_win:enter_input()
    end, { buffer = copy_win.buf, nowait = true })

    vim.keymap.set("n", "<Esc>", function()
      copy_win:close()
    end, { buffer = copy_win.buf, nowait = true })

    vim.keymap.set("n", "q", function()
      copy_win:close()
    end, { buffer = copy_win.buf, nowait = true })

    copy_win:on_input_submit(do_copy)
  end
end

-- ============================================================================
-- Delete Theme
-- ============================================================================

---Delete a user theme
---@param state table UI state with available_themes and selected_idx/selected_theme_idx
---@param multi_panel MultiPanelWindow? The multi-panel window
---@param on_complete function? Callback after completion
function M.delete_theme(state, multi_panel, on_complete)
  if not state then return end

  local theme = state.available_themes[get_selected_idx(state)]
  if not theme or theme.is_default then
    vim.notify("Cannot delete default theme option", vim.log.levels.WARN)
    return
  end

  if not theme.is_user then
    vim.notify("Can only delete user themes", vim.log.levels.WARN)
    return
  end

  vim.ui.select({ "Yes", "No" }, {
    prompt = string.format("Delete theme '%s'?", theme.display_name),
  }, function(choice)
    if choice ~= "Yes" then return end

    local ok, err = ThemeManager.delete(theme.name)
    if ok then
      ThemeManager.clear_cache()

      -- Reload available themes
      local themes = ThemeManager.get_available_themes()
      table.insert(themes, 1, {
        name = nil,
        display_name = "Default",
        description = "Use default colors from config",
        is_user = false,
        is_default = true,
      })
      state.available_themes = themes

      -- Adjust selection if needed
      set_selected_idx(state, math.min(get_selected_idx(state), #state.available_themes))

      if multi_panel then
        multi_panel:render_panel("themes")
      end

      vim.notify("Theme deleted", vim.log.levels.INFO)

      if on_complete then
        on_complete(true)
      end
    else
      vim.notify("Failed to delete: " .. (err or "unknown"), vim.log.levels.ERROR)
      if on_complete then
        on_complete(false)
      end
    end
  end)
end

-- ============================================================================
-- Rename Theme
-- ============================================================================

---Rename a user theme
---@param state table UI state with available_themes and selected_idx/selected_theme_idx
---@param multi_panel MultiPanelWindow? The multi-panel window
---@param on_complete function? Callback after completion
function M.rename_theme(state, multi_panel, on_complete)
  if not state then return end

  local UiFloat = require('nvim-float.window')

  local theme = state.available_themes[get_selected_idx(state)]
  if not theme or theme.is_default then
    vim.notify("Cannot rename default theme option", vim.log.levels.WARN)
    return
  end

  if not theme.is_user then
    vim.notify("Can only rename user themes. Use copy to create a user theme first.", vim.log.levels.WARN)
    return
  end

  local rename_win = UiFloat.create({
    title = "Rename Theme",
    width = 55,
    height = 8,
    center = true,
    content_builder = true,
    enable_inputs = true,
    zindex = UiFloat.ZINDEX.MODAL,
  })

  if rename_win then
    local cb = rename_win:get_content_builder()
    cb:line("")
    cb:styled(string.format("  Rename theme '%s':", theme.display_name), "NvimFloatTitle")
    cb:line("")
    cb:labeled_input("name", "  New name", {
      value = theme.display_name,
      placeholder = "(enter new name)",
      width = 32,
    })
    cb:line("")
    cb:styled("  <Enter>=Rename | <Esc>=Cancel", "NvimFloatHint")
    rename_win:render()

    local function do_rename()
      local new_name = rename_win:get_input_value("name")
      rename_win:close()

      if not new_name or new_name == "" then return end

      local ok, err = ThemeManager.rename(theme.name, new_name)
      if ok then
        ThemeManager.clear_cache()

        -- Reload available themes
        local themes = ThemeManager.get_available_themes()
        table.insert(themes, 1, {
          name = nil,
          display_name = "Default",
          description = "Use default colors from config",
          is_user = false,
          is_default = true,
        })
        state.available_themes = themes

        -- Find the renamed theme
        local new_file_name = new_name:gsub("[^%w_%-]", "_")
        for i, t in ipairs(state.available_themes) do
          if t.name == new_file_name or t.display_name == new_name then
            set_selected_idx(state, i)
            break
          end
        end

        if multi_panel then
          multi_panel:render_panel("themes")
        end

        vim.notify("Theme renamed", vim.log.levels.INFO)

        if on_complete then
          on_complete(true)
        end
      else
        vim.notify("Failed to rename: " .. (err or "unknown"), vim.log.levels.ERROR)
        if on_complete then
          on_complete(false)
        end
      end
    end

    vim.keymap.set("n", "<CR>", function()
      rename_win:enter_input()
    end, { buffer = rename_win.buf, nowait = true })

    vim.keymap.set("n", "<Esc>", function()
      rename_win:close()
    end, { buffer = rename_win.buf, nowait = true })

    vim.keymap.set("n", "q", function()
      rename_win:close()
    end, { buffer = rename_win.buf, nowait = true })

    rename_win:on_input_submit(do_rename)
  end
end

-- ============================================================================
-- Save Theme (for future color editing support)
-- ============================================================================

---Save current theme colors as a new user theme
---@param colors table Theme colors to save
---@param source_theme table? Source theme for defaults (name, description, author)
---@param multi_panel MultiPanelWindow? The multi-panel window
---@param on_complete function? Callback after completion (receives new theme name)
function M.save_theme(colors, source_theme, multi_panel, on_complete)
  if not colors then return end

  local UiFloat = require('nvim-float.window')

  local default_name = source_theme and source_theme.is_user
    and source_theme.display_name
    or ThemeManager.generate_unique_name("Custom Theme")

  local save_win = UiFloat.create({
    title = "Save Theme",
    width = 55,
    height = 8,
    center = true,
    content_builder = true,
    enable_inputs = true,
    zindex = UiFloat.ZINDEX.MODAL,
  })

  if save_win then
    local cb = save_win:get_content_builder()
    cb:line("")
    cb:styled("  Save current colors as theme:", "NvimFloatTitle")
    cb:line("")
    cb:labeled_input("name", "  Name", {
      value = default_name,
      placeholder = "(enter theme name)",
      width = 35,
    })
    cb:line("")
    cb:styled("  <Enter>=Save | <Esc>=Cancel", "NvimFloatHint")
    save_win:render()

    local function do_save()
      local name = save_win:get_input_value("name")
      save_win:close()

      if not name or name == "" then return end

      local file_name = name:gsub("[^%w_%-]", "_")
      local description = source_theme and source_theme.description or ""
      local author = source_theme and source_theme.author or "User"

      local ok, err = ThemeManager.save(file_name, name, colors, description, author)

      if ok then
        ThemeManager.clear_cache()
        vim.notify("Theme saved: " .. name, vim.log.levels.INFO)

        if on_complete then
          on_complete(file_name)
        end
      else
        vim.notify("Failed to save: " .. (err or "unknown"), vim.log.levels.ERROR)
        if on_complete then
          on_complete(nil)
        end
      end
    end

    vim.keymap.set("n", "<CR>", function()
      save_win:enter_input()
    end, { buffer = save_win.buf, nowait = true })

    vim.keymap.set("n", "<Esc>", function()
      save_win:close()
    end, { buffer = save_win.buf, nowait = true })

    vim.keymap.set("n", "q", function()
      save_win:close()
    end, { buffer = save_win.buf, nowait = true })

    save_win:on_input_submit(do_save)
  end
end

-- ============================================================================
-- Auto-copy on edit (for future color editing support)
-- ============================================================================

---Auto-create a user copy when editing a built-in or default theme
---Used when color editing is introduced - creates a copy before allowing edits
---@param state table UI state
---@param multi_panel MultiPanelWindow? The multi-panel window
---@return boolean success Whether a copy was created (or already editing user theme)
---@return string? new_name New theme file name if copy was created
function M.ensure_user_copy(state, multi_panel)
  if not state then return false end

  local theme = state.available_themes[get_selected_idx(state)]
  if not theme then return false end

  -- Already a user theme
  if theme.is_user then
    return true
  end

  local copy_name, file_name, colors, description, author

  if theme.is_default then
    -- For default theme, create a new custom theme from current colors
    copy_name = "Custom Theme"
    file_name = ThemeManager.generate_unique_name("custom_theme", true)
    -- Use current colors from state (already loaded default colors)
    colors = state.current_colors or ThemeManager.get_colors(nil)
    description = "Custom theme based on default colors"
    author = "User"
  else
    -- For built-in themes, copy from the theme file
    copy_name = theme.display_name .. " - COPY"
    file_name = (theme.name or theme.display_name:lower():gsub("%s+", "_")) .. "_copy"
    file_name = ThemeManager.generate_unique_name(file_name, true)

    local source = ThemeManager.get_theme(theme.name, false)
    if not source then
      vim.notify("Failed to load source theme", vim.log.levels.ERROR)
      return false
    end
    colors = source.colors
    description = source.description
    author = source.author
  end

  local ok, err = ThemeManager.save(file_name, copy_name, colors, description, author)
  if ok then
    -- Reload themes
    ThemeManager.clear_cache()
    local themes = ThemeManager.get_available_themes()
    table.insert(themes, 1, {
      name = nil,
      display_name = "Default",
      description = "Use default colors from config",
      is_user = false,
      is_default = true,
    })
    state.available_themes = themes

    -- Find the new copy
    for i, t in ipairs(state.available_themes) do
      if t.name == file_name then
        set_selected_idx(state, i)
        break
      end
    end

    if multi_panel then
      multi_panel:render_panel("themes")
    end

    vim.notify("Created user copy: " .. copy_name, vim.log.levels.INFO)
    return true, file_name
  else
    vim.notify("Failed to create copy: " .. (err or "unknown"), vim.log.levels.ERROR)
    return false
  end
end

return M
