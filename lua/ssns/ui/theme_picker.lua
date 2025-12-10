---@class ThemePicker
---Theme picker UI with live preview
local ThemePicker = {}

local UiFloatMultiPanel = require('ssns.ui.float_multipanel')
local UiFloatBase = require('ssns.ui.float_base')
local ThemeManager = require('ssns.ui.theme_manager')
local KeymapManager = require('ssns.keymap_manager')

---@type table? Current state
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

---Render themes list panel
---@param mp_state table MultiPanel state
---@return string[] lines Lines to render
local function render_themes_list(mp_state)
  local lines = {}
  local themes = mp_state.data.available_themes
  local current = ThemeManager.get_current()

  table.insert(lines, "")

  local user_section_added = false
  local theme_line_map = {}

  for i, theme in ipairs(themes) do
    -- Add separator after Default option
    if theme.is_default then
      local prefix = i == mp_state.selected_idx and " ▶ " or "   "
      local suffix = current == nil and " ●" or ""
      local line = string.format("%s%s%s", prefix, theme.display_name, suffix)
      theme_line_map[i] = #lines
      table.insert(lines, line)
      table.insert(lines, "")
      table.insert(lines, " ─── Built-in ───")
      table.insert(lines, "")
    elseif theme.is_user and not user_section_added then
      table.insert(lines, "")
      table.insert(lines, " ─── User Themes ───")
      table.insert(lines, "")
      user_section_added = true

      local prefix = i == mp_state.selected_idx and " ▶ " or "   "
      local suffix = theme.name == current and " ●" or ""
      local line = string.format("%s%s%s", prefix, theme.display_name, suffix)
      theme_line_map[i] = #lines
      table.insert(lines, line)
    else
      local prefix = i == mp_state.selected_idx and " ▶ " or "   "
      local suffix = theme.name == current and " ●" or ""
      local line = string.format("%s%s%s", prefix, theme.display_name, suffix)
      theme_line_map[i] = #lines
      table.insert(lines, line)
    end
  end

  table.insert(lines, "")

  -- Store line map for mouse click support
  mp_state.data.theme_line_map = theme_line_map

  -- Apply highlights in next tick
  vim.schedule(function()
    local bufnr = mp_state.buffers.themes
    local ns_id = mp_state.namespaces.themes
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    UiFloatBase.clear_highlights(bufnr, ns_id)

    for line_idx, line in ipairs(lines) do
      if line:match("───") then
        UiFloatBase.add_highlight(bufnr, ns_id, "Comment", line_idx - 1, 0, -1)
      elseif line:match("▶") then
        UiFloatBase.add_highlight(bufnr, ns_id, "CursorLine", line_idx - 1, 0, -1)
        UiFloatBase.add_highlight(bufnr, ns_id, "Special", line_idx - 1, 1, 4)
      elseif line:match("●") then
        UiFloatBase.add_highlight(bufnr, ns_id, "DiagnosticOk", line_idx - 1, #line - 2, -1)
      end
    end

    -- Position cursor
    local cursor_line = theme_line_map[mp_state.selected_idx]
    if cursor_line then
      UiFloatBase.set_cursor(mp_state.windows.themes, cursor_line + 1, 0)
    end
  end)

  return lines
end

---Render preview panel
---@param mp_state table MultiPanel state
---@return string[] lines Lines to render
local function render_preview(mp_state)
  local lines = vim.split(PREVIEW_SQL, "\n")

  -- Apply semantic highlighting in next tick
  vim.schedule(function()
    local bufnr = mp_state.buffers.preview
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
    if ok and SemanticHighlighter.apply_to_buffer then
      pcall(SemanticHighlighter.apply_to_buffer, bufnr)
    end
  end)

  return lines
end

---Handle theme selection change
---@param mp_state table MultiPanel state
local function on_selection_change(mp_state)
  local theme = mp_state.data.available_themes[mp_state.selected_idx]
  if theme then
    ThemeManager.preview(theme.name)

    -- Re-render both panels to update highlighting and current marker
    UiFloatMultiPanel.render_panel(mp_state, "themes")
    UiFloatMultiPanel.render_panel(mp_state, "preview")
  end
end

---Show the theme picker UI
function ThemePicker.show()
  -- Close existing picker if open
  ThemePicker.close()

  -- Get available themes
  local themes = ThemeManager.get_available_themes()

  -- Add "Default" option at the top
  table.insert(themes, 1, {
    name = nil,
    display_name = "Default",
    description = "Use default colors from config",
    is_user = false,
    is_default = true,
  })

  -- Save current theme to restore on cancel
  local original_theme = ThemeManager.get_current()

  -- Find current theme index
  local selected_idx = 1
  if original_theme then
    for i, theme in ipairs(themes) do
      if theme.name == original_theme then
        selected_idx = i
        break
      end
    end
  end

  -- Create multi-panel UI
  state = UiFloatMultiPanel.create({
    panels = {
      {
        name = "themes",
        width_ratio = 0.25,
        title = "Themes",
        on_render = render_themes_list,
        keymaps = {
          { mode = "n", lhs = "<CR>", rhs = function() ThemePicker._apply() end, desc = "Apply theme" },
          { mode = "n", lhs = "<Esc>", rhs = function() ThemePicker._cancel() end, desc = "Cancel" },
          { mode = "n", lhs = "q", rhs = function() ThemePicker._cancel() end, desc = "Close" },
          { mode = "n", lhs = "j", rhs = function() ThemePicker._navigate(1) end, desc = "Next theme" },
          { mode = "n", lhs = "k", rhs = function() ThemePicker._navigate(-1) end, desc = "Previous theme" },
          { mode = "n", lhs = "<Down>", rhs = function() ThemePicker._navigate(1) end, desc = "Next theme" },
          { mode = "n", lhs = "<Up>", rhs = function() ThemePicker._navigate(-1) end, desc = "Previous theme" },
          { mode = "n", lhs = "<Tab>", rhs = function() ThemePicker._swap_focus() end, desc = "Switch to preview" },
          { mode = "n", lhs = "<LeftMouse>", rhs = function() ThemePicker._handle_mouse_click() end, desc = "Select theme with mouse" },
        },
      },
      {
        name = "preview",
        width_ratio = 0.75,
        title = "Preview",
        on_render = render_preview,
        filetype = "sql",
        keymaps = {
          { mode = "n", lhs = "<CR>", rhs = function() ThemePicker._apply() end, desc = "Apply theme" },
          { mode = "n", lhs = "<Esc>", rhs = function() ThemePicker._cancel() end, desc = "Cancel" },
          { mode = "n", lhs = "q", rhs = function() ThemePicker._cancel() end, desc = "Close" },
          { mode = "n", lhs = "<Tab>", rhs = function() ThemePicker._swap_focus() end, desc = "Switch to themes" },
          { mode = "n", lhs = "<S-Tab>", rhs = function() ThemePicker._swap_focus() end, desc = "Switch to themes" },
        },
      },
    },
    footer = " <Enter>=Apply  <Tab>=Switch Panel  <Esc>=Cancel  j/k=Navigate  Click=Select ",
    on_selection_change = on_selection_change,
    on_close = function()
      -- Disable semantic highlighting on preview buffer
      if state and state.buffers and state.buffers.preview then
        local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
        if ok and SemanticHighlighter.disable then
          pcall(SemanticHighlighter.disable, state.buffers.preview)
        end
      end
    end,
    initial_data = {
      available_themes = themes,
      original_theme = original_theme,
      theme_line_map = {},
    },
  })

  if state then
    state.selected_idx = selected_idx
    
    -- Preview selected theme
    on_selection_change(state)
  end
end

---Navigate theme list
---@param direction number 1 for down, -1 for up
function ThemePicker._navigate(direction)
  if not state then return end

  state.selected_idx = state.selected_idx + direction

  -- Wrap around
  if state.selected_idx < 1 then
    state.selected_idx = #state.data.available_themes
  elseif state.selected_idx > #state.data.available_themes then
    state.selected_idx = 1
  end

  -- Re-render and preview
  UiFloatMultiPanel.render_panel(state, "themes")
  on_selection_change(state)
end

---Switch focus between panels
function ThemePicker._swap_focus()
  if not state then return end

  local target = state.focused_panel == "themes" and "preview" or "themes"
  UiFloatMultiPanel.focus_panel(state, target)
end

---Handle mouse click on theme list
function ThemePicker._handle_mouse_click()
  if not state then return end

  local mouse = vim.fn.getmousepos()
  if mouse.winid ~= state.windows.themes then
    return
  end

  -- Check if this line corresponds to a theme
  local line = mouse.line - 1
  local theme_line_map = state.data.theme_line_map or {}

  -- Build reverse map
  local line_to_theme = {}
  for theme_idx, line_num in pairs(theme_line_map) do
    line_to_theme[line_num] = theme_idx
  end

  local theme_idx = line_to_theme[line]
  if theme_idx and theme_idx >= 1 and theme_idx <= #state.data.available_themes then
    state.selected_idx = theme_idx
    UiFloatMultiPanel.render_panel(state, "themes")
    on_selection_change(state)
  end
end

---Apply selected theme
function ThemePicker._apply()
  if not state then return end

  local theme = state.data.available_themes[state.selected_idx]
  if theme then
    ThemeManager.set_theme(theme.name, true)
  end

  ThemePicker.close()
end

---Cancel and restore original theme
function ThemePicker._cancel()
  if not state then return end

  -- Restore original theme
  ThemeManager.preview(state.data.original_theme)

  ThemePicker.close()
end

---Close the theme picker
function ThemePicker.close()
  if not state then return end

  UiFloatMultiPanel.close(state)
  state = nil
end

---Check if theme picker is open
---@return boolean
function ThemePicker.is_open()
  return state ~= nil
end

return ThemePicker
