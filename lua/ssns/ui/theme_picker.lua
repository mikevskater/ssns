---@class ThemePicker
---Theme picker UI with live preview
local ThemePicker = {}

local ThemeManager = require('ssns.ui.theme_manager')
local KeymapManager = require('ssns.keymap_manager')

---@class ThemePickerState
---@field themes_buf number Themes list buffer
---@field themes_win number Themes list window
---@field preview_buf number Preview buffer
---@field preview_win number Preview window
---@field footer_buf number Footer buffer
---@field footer_win number Footer window
---@field available_themes table[] List of available themes
---@field selected_idx number Currently selected theme index
---@field original_theme string? The theme active when picker was opened
---@field focused_panel string Which panel is focused ("themes" or "preview")

---@type ThemePickerState?
local state = nil

-- Preview SQL that showcases all highlight groups
local PREVIEW_SQL = [[
-- ============================================
-- SSNS Theme Preview
-- This query showcases all highlight groups
-- ============================================

-- Database & Schema References
USE master;
GO

-- Statement Keywords (SELECT, INSERT, CREATE, etc.)
SELECT
    -- Column References
    u.id,
    u.username,
    u.email,
    u.created_at,
    -- Alias References
    o.order_total AS total,
    -- Function Keywords (COUNT, SUM, GETDATE, etc.)
    COUNT(*) AS order_count,
    SUM(o.amount) AS total_amount,
    GETDATE() AS current_date,
    CAST(u.balance AS DECIMAL(10,2)) AS balance,
    COALESCE(u.nickname, 'N/A') AS display_name
-- Clause Keywords (FROM, WHERE, JOIN, etc.)
FROM dbo.Users u
-- Table & View References
INNER JOIN dbo.Orders o ON u.id = o.user_id
LEFT JOIN dbo.UserProfiles up ON u.id = up.user_id
-- Operator Keywords (AND, OR, NOT, IN, BETWEEN)
WHERE u.status = 'active'
    AND o.created_at BETWEEN '2024-01-01' AND '2024-12-31'
    AND u.role IN ('admin', 'user', 'moderator')
    OR NOT u.is_deleted = 1
-- Modifier Keywords (ASC, DESC, NOLOCK, etc.)
ORDER BY u.created_at DESC, u.username ASC;

-- Number Literals
SELECT 42, 3.14159, -100, 0x1F;

-- String Literals
SELECT 'Hello World', N'Unicode String', 'It''s escaped';

-- Parameter References (@params and @@system)
DECLARE @UserId INT = 1;
DECLARE @SearchTerm NVARCHAR(100) = '%test%';
SELECT @@VERSION, @@ROWCOUNT, @@IDENTITY;

-- Procedure & Function Calls
EXEC dbo.GetUserById @UserId = @UserId;
EXEC sp_help 'dbo.Users';

-- Datatype Keywords (INT, VARCHAR, DATETIME, etc.)
CREATE TABLE #TempUsers (
    id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email NVARCHAR(255) UNIQUE,
    balance DECIMAL(18,2) DEFAULT 0.00,
    created_at DATETIME DEFAULT GETDATE(),
    metadata XML NULL
);

-- Constraint Keywords (PRIMARY, KEY, FOREIGN, etc.)
ALTER TABLE dbo.Orders
ADD CONSTRAINT FK_Orders_Users
    FOREIGN KEY (user_id) REFERENCES dbo.Users(id)
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

-- Index Reference
CREATE NONCLUSTERED INDEX IX_Users_Email
ON dbo.Users (email)
INCLUDE (username, created_at);

-- CTE (Common Table Expression)
WITH ActiveUsers AS (
    SELECT id, username, email
    FROM dbo.Users
    WHERE status = 'active'
),
RecentOrders AS (
    SELECT user_id, COUNT(*) as cnt
    FROM dbo.Orders
    WHERE created_at > DATEADD(DAY, -30, GETDATE())
    GROUP BY user_id
)
SELECT * FROM ActiveUsers au
JOIN RecentOrders ro ON au.id = ro.user_id;

-- Unresolved (gray - not in database)
SELECT * FROM dbo.UnknownTable WHERE unknown_col = 1;
]]

---Create custom borders for unified appearance
---@return table borders Custom borders for each panel
local function create_borders()
  local chars = {
    horizontal = "─",
    vertical = "│",
    top_left = "╭",
    top_right = "╮",
    bottom_left = "╰",
    bottom_right = "╯",
    t_down = "┬",
    t_up = "┴",
  }

  return {
    themes = {
      chars.top_left,
      chars.horizontal,
      chars.t_down,
      chars.vertical,
      chars.t_up,
      chars.horizontal,
      chars.bottom_left,
      chars.vertical,
    },
    preview = {
      chars.t_down,
      chars.horizontal,
      chars.top_right,
      chars.vertical,
      chars.bottom_right,
      chars.horizontal,
      chars.t_up,
      chars.vertical,
    },
  }
end

---Calculate layout for 2-panel floating windows
---@param cols number Terminal columns
---@param lines number Terminal lines
---@return table layout Panel configurations
local function calculate_layout(cols, lines)
  -- Overall dimensions: 80% width x 85% height, centered
  local total_width = math.floor(cols * 0.8)
  local total_height = math.floor(lines * 0.85)
  local start_row = math.floor((lines - total_height) / 2)
  local start_col = math.floor((cols - total_width) / 2)

  -- Left panel (themes): 25% of total width
  -- Right panel (preview): 75% of total width
  local themes_width = math.floor(total_width * 0.25)
  local preview_width = total_width - themes_width - 1  -- -1 for shared border

  local borders = create_borders()

  return {
    themes = {
      relative = "editor",
      width = themes_width,
      height = total_height,
      row = start_row,
      col = start_col,
      style = "minimal",
      border = borders.themes,
      title = " Themes ",
      title_pos = "center",
      zindex = 50,
      focusable = true,
    },
    preview = {
      relative = "editor",
      width = preview_width,
      height = total_height,
      row = start_row,
      col = start_col + themes_width + 1,
      style = "minimal",
      border = borders.preview,
      title = " Preview ",
      title_pos = "center",
      zindex = 50,
      focusable = true,
    },
    footer = {
      text = " <Enter>=Apply  <Tab>=Switch Panel  <Esc>=Cancel  j/k=Navigate ",
      row = start_row + total_height + 2,
      col = start_col,
      width = total_width,
    }
  }
end

---Show the theme picker UI
function ThemePicker.show()
  -- Close existing picker if open
  ThemePicker.close()

  -- Get available themes
  local themes = ThemeManager.get_available_themes()

  -- Add "Default" option at the top
  table.insert(themes, 1, {
    name = nil,  -- nil means default/no theme
    display_name = "Default",
    description = "Use default colors from config",
    is_user = false,
    is_default = true,
  })

  -- Save current theme to restore on cancel
  local original_theme = ThemeManager.get_current()

  -- Find current theme index (Default is at index 1)
  local selected_idx = 1  -- Default to "Default" option
  if original_theme then
    for i, theme in ipairs(themes) do
      if theme.name == original_theme then
        selected_idx = i
        break
      end
    end
  end

  -- Initialize state
  state = {
    available_themes = themes,
    selected_idx = selected_idx,
    original_theme = original_theme,
    focused_panel = "themes",  -- Start focused on themes list
  }

  -- Create the layout
  ThemePicker._create_layout()

  -- Render content
  ThemePicker._render_themes()
  ThemePicker._render_preview()

  -- Setup keymaps
  ThemePicker._setup_keymaps()

  -- Setup autocmds for cleanup
  ThemePicker._setup_autocmds()
end

---Create the 2-panel floating window layout
function ThemePicker._create_layout()
  local layout = calculate_layout(vim.o.columns, vim.o.lines)

  -- Create buffers
  state.themes_buf = vim.api.nvim_create_buf(false, true)
  state.preview_buf = vim.api.nvim_create_buf(false, true)

  -- Configure buffer options
  for _, bufnr in ipairs({state.themes_buf, state.preview_buf}) do
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  end

  -- Set filetype for preview (SQL syntax + semantic highlighting)
  vim.api.nvim_buf_set_option(state.preview_buf, 'filetype', 'sql')

  -- Create floating windows
  state.themes_win = vim.api.nvim_open_win(state.themes_buf, true, layout.themes)
  state.preview_win = vim.api.nvim_open_win(state.preview_buf, false, layout.preview)

  -- Configure window options
  for _, winid in ipairs({state.themes_win, state.preview_win}) do
    vim.api.nvim_set_option_value('number', false, { win = winid })
    vim.api.nvim_set_option_value('relativenumber', false, { win = winid })
    vim.api.nvim_set_option_value('cursorline', true, { win = winid })
    vim.api.nvim_set_option_value('wrap', false, { win = winid })
    vim.api.nvim_set_option_value('signcolumn', 'no', { win = winid })
    vim.api.nvim_set_option_value('winhighlight', 'FloatBorder:FloatBorder,FloatTitle:FloatTitle', { win = winid })
  end

  -- Disable cursorline on preview (we're not selecting there)
  vim.api.nvim_set_option_value('cursorline', false, { win = state.preview_win })

  -- Create footer window
  state.footer_buf = vim.api.nvim_create_buf(false, true)

  local text_len = #layout.footer.text
  local padding = math.floor((layout.footer.width - text_len) / 2)
  local centered_text = string.rep(" ", math.max(0, padding)) .. layout.footer.text

  vim.api.nvim_buf_set_lines(state.footer_buf, 0, -1, false, {centered_text})
  vim.api.nvim_buf_set_option(state.footer_buf, 'modifiable', false)

  state.footer_win = vim.api.nvim_open_win(state.footer_buf, false, {
    relative = "editor",
    width = layout.footer.width,
    height = 1,
    row = layout.footer.row,
    col = layout.footer.col,
    style = "minimal",
    border = "none",
    zindex = 52,
    focusable = false,
  })

  vim.api.nvim_set_option_value('winhighlight', 'Normal:Comment', { win = state.footer_win })

  -- Focus themes list
  vim.api.nvim_set_current_win(state.themes_win)
end

---Render the themes list
function ThemePicker._render_themes()
  local lines = {}
  local ns_id = vim.api.nvim_create_namespace("ssns_theme_picker")

  -- Track line number for each theme index (0-based for nvim API)
  local theme_line_map = {}

  -- Add header
  table.insert(lines, "")

  -- Add themes
  local current = ThemeManager.get_current()
  local user_section_added = false

  for i, theme in ipairs(state.available_themes) do
    -- Add separator after Default option
    if theme.is_default then
      local prefix = i == state.selected_idx and " ▶ " or "   "
      local suffix = current == nil and " ●" or ""
      local line = string.format("%s%s%s", prefix, theme.display_name, suffix)
      theme_line_map[i] = #lines  -- Track line number (0-based)
      table.insert(lines, line)
      table.insert(lines, "")
      table.insert(lines, " ─── Built-in ───")
      table.insert(lines, "")
    -- Add user themes separator
    elseif theme.is_user and not user_section_added then
      table.insert(lines, "")
      table.insert(lines, " ─── User Themes ───")
      table.insert(lines, "")
      user_section_added = true

      local prefix = i == state.selected_idx and " ▶ " or "   "
      local suffix = theme.name == current and " ●" or ""
      local line = string.format("%s%s%s", prefix, theme.display_name, suffix)
      theme_line_map[i] = #lines  -- Track line number (0-based)
      table.insert(lines, line)
    else
      local prefix = i == state.selected_idx and " ▶ " or "   "
      local suffix = theme.name == current and " ●" or ""
      local line = string.format("%s%s%s", prefix, theme.display_name, suffix)
      theme_line_map[i] = #lines  -- Track line number (0-based)
      table.insert(lines, line)
    end
  end

  table.insert(lines, "")

  -- Store line map in state for cursor positioning
  state.theme_line_map = theme_line_map

  -- Set content
  vim.api.nvim_buf_set_option(state.themes_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.themes_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.themes_buf, 'modifiable', false)

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(state.themes_buf, ns_id, 0, -1)

  local line_idx = 0
  for _, line in ipairs(lines) do
    if line:match("─── User Themes ───") or line:match("─── Built%-in ───") then
      vim.api.nvim_buf_add_highlight(state.themes_buf, ns_id, "Comment", line_idx, 0, -1)
    elseif line:match("▶") then
      vim.api.nvim_buf_add_highlight(state.themes_buf, ns_id, "CursorLine", line_idx, 0, -1)
      vim.api.nvim_buf_add_highlight(state.themes_buf, ns_id, "Special", line_idx, 1, 4)
    elseif line:match("●") then
      vim.api.nvim_buf_add_highlight(state.themes_buf, ns_id, "DiagnosticOk", line_idx, #line - 2, -1)
    end
    line_idx = line_idx + 1
  end

  -- Position cursor using the tracked line map
  local cursor_line = theme_line_map[state.selected_idx]
  if cursor_line then
    -- nvim_win_set_cursor uses 1-based line numbers
    pcall(vim.api.nvim_win_set_cursor, state.themes_win, {cursor_line + 1, 0})
  end
end

---Render the preview pane with semantic highlighting
function ThemePicker._render_preview()
  -- Set the preview SQL content
  vim.api.nvim_buf_set_option(state.preview_buf, 'modifiable', true)
  local lines = vim.split(PREVIEW_SQL, '\n')
  vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.preview_buf, 'modifiable', false)

  -- Apply semantic highlighting to preview
  ThemePicker._apply_preview_highlights()
end

---Apply semantic highlighting to preview buffer
function ThemePicker._apply_preview_highlights()
  -- Enable semantic highlighting on the preview buffer
  local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
  if ok and SemanticHighlighter.enable then
    pcall(SemanticHighlighter.enable, state.preview_buf)
    -- Trigger update
    vim.defer_fn(function()
      if state and state.preview_buf and vim.api.nvim_buf_is_valid(state.preview_buf) then
        pcall(SemanticHighlighter.update, state.preview_buf)
      end
    end, 50)
  end
end

---Setup keymaps for theme picker
function ThemePicker._setup_keymaps()
  local km = KeymapManager.get_group("common")

  -- Keymaps for themes list panel
  local themes_keymaps = {
    -- Close/Cancel
    { lhs = km.cancel or "<Esc>", rhs = function() ThemePicker._cancel() end, desc = "Cancel" },
    { lhs = km.close or "q", rhs = function() ThemePicker._cancel() end, desc = "Close" },

    -- Apply theme
    { lhs = km.confirm or "<CR>", rhs = function() ThemePicker._apply() end, desc = "Apply theme" },

    -- Navigation
    { lhs = km.nav_down or "j", rhs = function() ThemePicker._navigate(1) end, desc = "Next theme" },
    { lhs = km.nav_up or "k", rhs = function() ThemePicker._navigate(-1) end, desc = "Previous theme" },
    { lhs = km.nav_down_alt or "<Down>", rhs = function() ThemePicker._navigate(1) end, desc = "Next theme" },
    { lhs = km.nav_up_alt or "<Up>", rhs = function() ThemePicker._navigate(-1) end, desc = "Previous theme" },

    -- Switch to preview panel
    { lhs = km.next_field or "<Tab>", rhs = function() ThemePicker._swap_focus() end, desc = "Switch to preview" },
  }

  KeymapManager.set_multiple(state.themes_buf, themes_keymaps, true)
  KeymapManager.mark_group_active(state.themes_buf, "theme_picker")

  -- Keymaps for preview panel (allow scrolling and navigation)
  local preview_keymaps = {
    -- Close/Cancel
    { lhs = km.cancel or "<Esc>", rhs = function() ThemePicker._cancel() end, desc = "Cancel" },
    { lhs = km.close or "q", rhs = function() ThemePicker._cancel() end, desc = "Close" },

    -- Switch back to themes panel
    { lhs = km.next_field or "<Tab>", rhs = function() ThemePicker._swap_focus() end, desc = "Switch to themes" },
    { lhs = km.prev_field or "<S-Tab>", rhs = function() ThemePicker._swap_focus() end, desc = "Switch to themes" },

    -- Standard vim scrolling (j/k work natively in preview for scrolling)
  }

  KeymapManager.set_multiple(state.preview_buf, preview_keymaps, true)
  KeymapManager.mark_group_active(state.preview_buf, "theme_picker")
end

---Setup autocmds for cleanup
function ThemePicker._setup_autocmds()
  local group = vim.api.nvim_create_augroup("SSNSThemePicker", { clear = true })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      if state and (
        ev.match == tostring(state.themes_win) or
        ev.match == tostring(state.preview_win)
      ) then
        ThemePicker.close()
      end
    end,
  })

  -- Handle resize
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if state then
        ThemePicker.close()
        vim.defer_fn(function()
          ThemePicker.show()
        end, 50)
      end
    end,
  })
end

---Navigate theme list
---@param direction number 1 for down, -1 for up
function ThemePicker._navigate(direction)
  if not state then return end

  state.selected_idx = state.selected_idx + direction

  -- Wrap around
  if state.selected_idx < 1 then
    state.selected_idx = #state.available_themes
  elseif state.selected_idx > #state.available_themes then
    state.selected_idx = 1
  end

  -- Re-render themes list
  ThemePicker._render_themes()

  -- Preview selected theme
  local theme = state.available_themes[state.selected_idx]
  if theme then
    ThemeManager.preview(theme.name)
    -- Re-apply semantic highlighting after theme change
    ThemePicker._apply_preview_highlights()
  end
end

---Swap focus between themes list and preview panel
function ThemePicker._swap_focus()
  if not state then return end

  if state.focused_panel == "themes" then
    -- Switch to preview
    state.focused_panel = "preview"
    if vim.api.nvim_win_is_valid(state.preview_win) then
      vim.api.nvim_set_current_win(state.preview_win)
      -- Enable cursorline on preview, disable on themes
      vim.api.nvim_set_option_value('cursorline', true, { win = state.preview_win })
      vim.api.nvim_set_option_value('cursorline', false, { win = state.themes_win })
    end
  else
    -- Switch back to themes
    state.focused_panel = "themes"
    if vim.api.nvim_win_is_valid(state.themes_win) then
      vim.api.nvim_set_current_win(state.themes_win)
      -- Enable cursorline on themes, disable on preview
      vim.api.nvim_set_option_value('cursorline', true, { win = state.themes_win })
      vim.api.nvim_set_option_value('cursorline', false, { win = state.preview_win })
      -- Restore cursor position on themes list
      local cursor_line = state.theme_line_map and state.theme_line_map[state.selected_idx]
      if cursor_line then
        pcall(vim.api.nvim_win_set_cursor, state.themes_win, {cursor_line + 1, 0})
      end
    end
  end
end

---Apply selected theme
function ThemePicker._apply()
  if not state then return end

  local theme = state.available_themes[state.selected_idx]
  if theme then
    ThemeManager.set_theme(theme.name, true)
  end

  ThemePicker.close()
end

---Cancel and restore original theme
function ThemePicker._cancel()
  if not state then return end

  -- Restore original theme
  ThemeManager.preview(state.original_theme)

  ThemePicker.close()
end

---Close the theme picker
function ThemePicker.close()
  if not state then return end

  -- Disable semantic highlighting on preview buffer before closing
  local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
  if ok and SemanticHighlighter.disable and state.preview_buf then
    pcall(SemanticHighlighter.disable, state.preview_buf)
  end

  -- Close windows
  local windows = { state.themes_win, state.preview_win, state.footer_win }
  for _, winid in ipairs(windows) do
    if winid and vim.api.nvim_win_is_valid(winid) then
      pcall(vim.api.nvim_win_close, winid, true)
    end
  end

  -- Clear autocmds
  pcall(vim.api.nvim_del_augroup_by_name, "SSNSThemePicker")

  state = nil
end

---Check if theme picker is open
---@return boolean
function ThemePicker.is_open()
  return state ~= nil
end

return ThemePicker
