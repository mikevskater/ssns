---@class ThemeManager
---Manages color themes for SSNS plugin
local ThemeManager = {}

---@class ThemeColors
---@field server_sqlserver table SQL Server color
---@field server_postgres table PostgreSQL color
---@field server_mysql table MySQL color
---@field server_sqlite table SQLite color
---@field server_bigquery table BigQuery color
---@field server table Default server color
---@field database table Database color
---@field schema table Schema color
---@field table table Table color
---@field view table View color
---@field procedure table Procedure color
---@field ["function"] table Function color
---@field column table Column color
---@field index table Index color
---@field key table Key color
---@field parameter table Parameter color
---@field sequence table Sequence color
---@field synonym table Synonym color
---@field action table Action color
---@field group table Group color
---@field status_connected table Connected status color
---@field status_disconnected table Disconnected status color
---@field status_connecting table Connecting status color
---@field status_error table Error status color
---@field expanded table Expanded indicator color
---@field collapsed table Collapsed indicator color
---@field keyword table Legacy keyword color
---@field keyword_statement table Statement keyword color (SELECT, INSERT, etc.)
---@field keyword_clause table Clause keyword color (FROM, WHERE, etc.)
---@field keyword_function table Function keyword color (COUNT, SUM, etc.)
---@field keyword_datatype table Datatype keyword color (INT, VARCHAR, etc.)
---@field keyword_operator table Operator keyword color (AND, OR, etc.)
---@field keyword_constraint table Constraint keyword color (PRIMARY, KEY, etc.)
---@field keyword_modifier table Modifier keyword color (ASC, DESC, etc.)
---@field keyword_misc table Misc keyword color
---@field keyword_global_variable table Global variable keyword color (@@ROWCOUNT, @@VERSION, etc.)
---@field keyword_system_procedure table System procedure keyword color (sp_*, xp_*)
---@field operator table Operator color
---@field string table String literal color
---@field number table Number literal color
---@field alias table Alias color
---@field unresolved table Unresolved identifier color
---@field comment table Comment color
---@field ui_border table? UI border color (optional)
---@field ui_title table? UI title color (optional)
---@field ui_selected table? Selected item color (optional)
---@field ui_hint table? Hint text color (optional)

---@class Theme
---@field name string Theme display name
---@field description string? Theme description
---@field author string? Theme author
---@field colors ThemeColors Theme color definitions

-- Current active theme name (nil = default/config)
---@type string?
local current_theme = nil

-- Cached loaded themes
---@type table<string, Theme>
local loaded_themes = {}

-- Theme persistence file path
local persistence_file = vim.fn.stdpath("data") .. "/ssns_theme.txt"

-- Themes directory paths
local themes_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/themes"
local user_themes_dir = themes_dir .. "/user_themes"

-- ============================================================================
-- Internal Helpers
-- ============================================================================

---Get list of lua files in a directory
---@param dir string Directory path
---@return string[] files List of theme names (without .lua extension)
local function get_theme_files(dir)
  local files = {}
  local handle = vim.loop.fs_scandir(dir)
  if not handle then
    return files
  end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end

    if type == "file" and name:match("%.lua$") then
      -- Skip init.lua, base.lua, and theme_manager.lua
      if name ~= "init.lua" and name ~= "base.lua" and name ~= "theme_manager.lua" then
        local theme_name = name:gsub("%.lua$", "")
        table.insert(files, theme_name)
      end
    end
  end

  return files
end

---Load a theme from file
---@param name string Theme name
---@param is_user boolean Whether this is a user theme
---@return Theme? theme The loaded theme or nil
local function load_theme_file(name, is_user)
  local dir = is_user and user_themes_dir or themes_dir
  local filepath = dir .. "/" .. name .. ".lua"

  -- Check if file exists
  local stat = vim.loop.fs_stat(filepath)
  if not stat then
    return nil
  end

  -- Load the theme file
  local ok, theme = pcall(dofile, filepath)
  if not ok or type(theme) ~= "table" then
    vim.notify(string.format("SSNS: Failed to load theme '%s': %s", name, tostring(theme)), vim.log.levels.WARN)
    return nil
  end

  -- Validate theme has required fields
  if not theme.name or not theme.colors then
    vim.notify(string.format("SSNS: Invalid theme '%s': missing name or colors", name), vim.log.levels.WARN)
    return nil
  end

  return theme
end

---Get base theme (default colors from config)
---@return ThemeColors
local function get_base_colors()
  local Config = require('nvim-ssns.config')
  local hl = Config.get_ui().highlights
  return hl
end

---Merge theme colors with base (for partial themes)
---@param theme_colors table Partial theme colors
---@return ThemeColors Full theme colors
local function merge_with_base(theme_colors)
  local base = get_base_colors()
  return vim.tbl_deep_extend("force", base, theme_colors)
end

-- ============================================================================
-- Public API
-- ============================================================================

---Initialize the theme manager
function ThemeManager.setup()
  -- Create user_themes directory if it doesn't exist
  if vim.fn.isdirectory(user_themes_dir) == 0 then
    vim.fn.mkdir(user_themes_dir, "p")
  end

  -- Load persisted theme preference
  ThemeManager.load_preference()

  -- Apply the current theme (or default)
  ThemeManager.apply_current()
end

---Get list of all available themes
---@return {name: string, display_name: string, description: string?, is_user: boolean}[]
function ThemeManager.get_available_themes()
  local themes = {}

  -- Add built-in themes
  local builtin = get_theme_files(themes_dir)
  for _, name in ipairs(builtin) do
    local theme = ThemeManager.get_theme(name)
    if theme then
      table.insert(themes, {
        name = name,
        display_name = theme.name,
        description = theme.description,
        author = theme.author,
        is_user = false,
      })
    end
  end

  -- Add user themes
  local user = get_theme_files(user_themes_dir)
  for _, name in ipairs(user) do
    local theme = ThemeManager.get_theme(name, true)
    if theme then
      table.insert(themes, {
        name = name,
        display_name = theme.name,
        description = theme.description,
        author = theme.author,
        is_user = true,
      })
    end
  end

  -- Sort by name
  table.sort(themes, function(a, b)
    -- User themes at bottom
    if a.is_user ~= b.is_user then
      return not a.is_user
    end
    return a.display_name:lower() < b.display_name:lower()
  end)

  return themes
end

---Get a theme by name
---@param name string Theme name
---@param is_user boolean? Whether to look in user themes first
---@return Theme?
function ThemeManager.get_theme(name, is_user)
  local cache_key = (is_user and "user:" or "builtin:") .. name

  -- Check cache
  if loaded_themes[cache_key] then
    return loaded_themes[cache_key]
  end

  -- Try to load
  local theme
  if is_user then
    theme = load_theme_file(name, true)
  else
    -- Try builtin first, then user
    theme = load_theme_file(name, false) or load_theme_file(name, true)
  end

  if theme then
    loaded_themes[cache_key] = theme
  end

  return theme
end

---Get colors for a theme (merged with base)
---@param name string? Theme name (nil for base/default)
---@return ThemeColors
function ThemeManager.get_colors(name)
  if not name then
    return get_base_colors()
  end

  local theme = ThemeManager.get_theme(name)
  if not theme then
    return get_base_colors()
  end

  return merge_with_base(theme.colors)
end

---Get current active theme name
---@return string? name Current theme name (nil = default)
function ThemeManager.get_current()
  return current_theme
end

---Set the current theme
---@param name string? Theme name (nil to clear/use default)
---@param save boolean? Save preference (default: true)
function ThemeManager.set_theme(name, save)
  if save == nil then save = true end

  current_theme = name

  -- Apply the theme
  ThemeManager.apply_current()

  -- Save preference
  if save then
    ThemeManager.save_preference()
  end

  -- Notify
  if name then
    local theme = ThemeManager.get_theme(name)
    local display = theme and theme.name or name
    vim.notify(string.format("SSNS: Theme set to '%s'", display), vim.log.levels.INFO)
  else
    vim.notify("SSNS: Theme cleared (using defaults)", vim.log.levels.INFO)
  end
end

---Clear the current theme (use defaults)
function ThemeManager.clear_theme()
  ThemeManager.set_theme(nil, true)
end

---Apply the current theme to all highlight groups
function ThemeManager.apply_current()
  local colors = ThemeManager.get_colors(current_theme)
  ThemeManager.apply_colors(colors)
end

---Apply a set of colors to highlight groups
---@param colors ThemeColors
function ThemeManager.apply_colors(colors)
  -- Server type-specific highlights
  vim.api.nvim_set_hl(0, "SsnsServerSqlServer", colors.server_sqlserver or {})
  vim.api.nvim_set_hl(0, "SsnsServerPostgres", colors.server_postgres or {})
  vim.api.nvim_set_hl(0, "SsnsServerMysql", colors.server_mysql or {})
  vim.api.nvim_set_hl(0, "SsnsServerSqlite", colors.server_sqlite or {})
  vim.api.nvim_set_hl(0, "SsnsServerBigQuery", colors.server_bigquery or {})
  vim.api.nvim_set_hl(0, "SsnsServer", colors.server or {})

  -- Object type highlights
  vim.api.nvim_set_hl(0, "SsnsDatabase", colors.database or {})
  vim.api.nvim_set_hl(0, "SsnsSchema", colors.schema or {})
  vim.api.nvim_set_hl(0, "SsnsTable", colors.table or {})
  vim.api.nvim_set_hl(0, "SsnsTempTable", colors.temp_table or { fg = "#CE9178", italic = true })
  vim.api.nvim_set_hl(0, "SsnsView", colors.view or {})
  vim.api.nvim_set_hl(0, "SsnsProcedure", colors.procedure or {})
  vim.api.nvim_set_hl(0, "SsnsFunction", colors["function"] or {})
  vim.api.nvim_set_hl(0, "SsnsColumn", colors.column or {})
  vim.api.nvim_set_hl(0, "SsnsIndex", colors.index or {})
  vim.api.nvim_set_hl(0, "SsnsKey", colors.key or {})
  vim.api.nvim_set_hl(0, "SsnsParameter", colors.parameter or {})
  vim.api.nvim_set_hl(0, "SsnsSequence", colors.sequence or {})
  vim.api.nvim_set_hl(0, "SsnsSynonym", colors.synonym or {})
  vim.api.nvim_set_hl(0, "SsnsAction", colors.action or {})
  vim.api.nvim_set_hl(0, "SsnsGroup", colors.group or {})

  -- Add server action (green)
  vim.api.nvim_set_hl(0, "SsnsAddServerAction", { fg = "#4EC9B0", bold = true })

  -- Icon highlights
  vim.api.nvim_set_hl(0, "SsnsIcon", { link = "SpecialChar", default = true })
  vim.api.nvim_set_hl(0, "SsnsIconServer", vim.tbl_extend("force", colors.server or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconDatabase", vim.tbl_extend("force", colors.database or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconSchema", vim.tbl_extend("force", colors.schema or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconTable", vim.tbl_extend("force", colors.table or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconView", vim.tbl_extend("force", colors.view or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconProcedure", vim.tbl_extend("force", colors.procedure or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconFunction", vim.tbl_extend("force", colors["function"] or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconColumn", vim.tbl_extend("force", colors.column or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconIndex", vim.tbl_extend("force", colors.index or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconKey", vim.tbl_extend("force", colors.key or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconParameter", vim.tbl_extend("force", colors.parameter or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconSequence", vim.tbl_extend("force", colors.sequence or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconSynonym", vim.tbl_extend("force", colors.synonym or {}, { default = true }))

  -- Status highlights
  vim.api.nvim_set_hl(0, "SsnsStatusConnected", vim.tbl_extend("force", colors.status_connected or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsStatusDisconnected", vim.tbl_extend("force", colors.status_disconnected or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsStatusConnecting", vim.tbl_extend("force", colors.status_connecting or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsStatusError", vim.tbl_extend("force", colors.status_error or {}, { default = true }))

  -- Tree expand/collapse indicators
  vim.api.nvim_set_hl(0, "SsnsExpanded", vim.tbl_extend("force", colors.expanded or {}, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsCollapsed", vim.tbl_extend("force", colors.collapsed or {}, { default = true }))

  -- Semantic highlighting for query buffers
  vim.api.nvim_set_hl(0, "SsnsKeyword", colors.keyword or { fg = "#569CD6", bold = true })
  vim.api.nvim_set_hl(0, "SsnsKeywordStatement", colors.keyword_statement or { fg = "#C586C0", bold = true })
  vim.api.nvim_set_hl(0, "SsnsKeywordClause", colors.keyword_clause or { fg = "#569CD6", bold = true })
  vim.api.nvim_set_hl(0, "SsnsKeywordFunction", colors.keyword_function or { fg = "#DCDCAA" })
  vim.api.nvim_set_hl(0, "SsnsKeywordDatatype", colors.keyword_datatype or { fg = "#4EC9B0" })
  vim.api.nvim_set_hl(0, "SsnsKeywordOperator", colors.keyword_operator or { fg = "#569CD6" })
  vim.api.nvim_set_hl(0, "SsnsKeywordConstraint", colors.keyword_constraint or { fg = "#CE9178" })
  vim.api.nvim_set_hl(0, "SsnsKeywordModifier", colors.keyword_modifier or { fg = "#9CDCFE" })
  vim.api.nvim_set_hl(0, "SsnsKeywordMisc", colors.keyword_misc or { fg = "#808080" })
  vim.api.nvim_set_hl(0, "SsnsKeywordGlobalVariable", colors.keyword_global_variable or { fg = "#FF6B6B" })
  vim.api.nvim_set_hl(0, "SsnsKeywordSystemProcedure", colors.keyword_system_procedure or { fg = "#D7BA7D" })

  -- Other semantic highlights
  vim.api.nvim_set_hl(0, "SsnsOperator", colors.operator or { fg = "#D4D4D4" })
  vim.api.nvim_set_hl(0, "SsnsString", colors.string or { fg = "#CE9178" })
  vim.api.nvim_set_hl(0, "SsnsNumber", colors.number or { fg = "#B5CEA8" })
  vim.api.nvim_set_hl(0, "SsnsAlias", colors.alias or { fg = "#4EC9B0", italic = true })
  vim.api.nvim_set_hl(0, "SsnsUnresolved", colors.unresolved or { fg = "#808080" })
  vim.api.nvim_set_hl(0, "SsnsComment", colors.comment or { fg = "#6A9955", italic = true })

  -- nvim-float UI highlights (generic floating window styling)
  vim.api.nvim_set_hl(0, "NvimFloatBorder", colors.ui_border or { link = "FloatBorder" })
  vim.api.nvim_set_hl(0, "NvimFloatTitle", colors.ui_title or { link = "FloatTitle" })
  vim.api.nvim_set_hl(0, "NvimFloatSelected", colors.ui_selected or { link = "PmenuSel" })
  vim.api.nvim_set_hl(0, "NvimFloatHint", colors.ui_hint or { link = "Comment" })

  -- nvim-float input field highlights
  vim.api.nvim_set_hl(0, "NvimFloatInput", colors.ui_input or { bg = "#2D2D2D", fg = "#CCCCCC" })
  vim.api.nvim_set_hl(0, "NvimFloatInputActive", colors.ui_input_active or { bg = "#3C3C3C", fg = "#FFFFFF", bold = true })
  vim.api.nvim_set_hl(0, "NvimFloatInputPlaceholder", colors.ui_input_placeholder or { bg = "#2D2D2D", fg = "#666666", italic = true })

  -- nvim-float scrollbar highlights
  vim.api.nvim_set_hl(0, "NvimFloatScrollbar", colors.scrollbar or { bg = "NONE" })
  vim.api.nvim_set_hl(0, "NvimFloatScrollbarThumb", colors.scrollbar_thumb or { link = "NvimFloatTitle" })
  vim.api.nvim_set_hl(0, "NvimFloatScrollbarTrack", colors.scrollbar_track or { link = "NvimFloatBorder" })
  vim.api.nvim_set_hl(0, "NvimFloatScrollbarArrow", colors.scrollbar_arrow or { link = "NvimFloatHint" })

  -- nvim-float content style highlights (ContentBuilder uses these)
  vim.api.nvim_set_hl(0, "NvimFloatComment", colors.comment or { fg = "#6A9955", italic = true })
  vim.api.nvim_set_hl(0, "NvimFloatString", colors.string or { fg = "#CE9178" })
  vim.api.nvim_set_hl(0, "NvimFloatNumber", colors.number or { fg = "#B5CEA8" })
  vim.api.nvim_set_hl(0, "NvimFloatKeyword", colors.keyword or { fg = "#569CD6", bold = true })
  vim.api.nvim_set_hl(0, "NvimFloatOperator", colors.operator or { fg = "#D4D4D4" })
  vim.api.nvim_set_hl(0, "NvimFloatMuted", colors.ui_hint or { fg = "#6A6A6A" })
  vim.api.nvim_set_hl(0, "NvimFloatSection", colors.ui_title or { link = "NvimFloatTitle" })
  vim.api.nvim_set_hl(0, "NvimFloatHeader", colors.ui_title or { link = "NvimFloatTitle" })
  vim.api.nvim_set_hl(0, "NvimFloatSubheader", colors.ui_title or { link = "NvimFloatTitle" })
  vim.api.nvim_set_hl(0, "NvimFloatHighlight", colors.search_match or { link = "Search" })
  vim.api.nvim_set_hl(0, "NvimFloatLabel", colors.ui_hint or { link = "Label" })
  vim.api.nvim_set_hl(0, "NvimFloatEmphasis", { fg = "#4EC9B0" })
  vim.api.nvim_set_hl(0, "NvimFloatStrong", { fg = "#569CD6", bold = true })

  -- Search match highlight (overlay with background for use on syntax-highlighted content)
  vim.api.nvim_set_hl(0, "SsnsSearchMatch", colors.search_match or { bg = "#515C6A", bold = true })

  -- Result buffer highlights (foreground only - no background colors)
  vim.api.nvim_set_hl(0, "SsnsResultHeader", colors.result_header or { fg = "#9CDCFE", bold = true })
  vim.api.nvim_set_hl(0, "SsnsResultBorder", colors.result_border or { fg = "#4A4A4A" })
  vim.api.nvim_set_hl(0, "SsnsResultNull", colors.result_null or { fg = "#6A6A6A", italic = true })
  vim.api.nvim_set_hl(0, "SsnsResultMessage", colors.result_message or { fg = "#6A9955", italic = true })

  -- Datatype-specific result value colors (foreground only)
  vim.api.nvim_set_hl(0, "SsnsResultString", { link = "SsnsString" })
  vim.api.nvim_set_hl(0, "SsnsResultNumber", { link = "SsnsNumber" })
  vim.api.nvim_set_hl(0, "SsnsResultDate", colors.result_date or { fg = "#D7BA7D" })
  vim.api.nvim_set_hl(0, "SsnsResultBool", colors.result_bool or { fg = "#569CD6" })
  vim.api.nvim_set_hl(0, "SsnsResultBinary", colors.result_binary or { fg = "#808080" })
  vim.api.nvim_set_hl(0, "SsnsResultGuid", colors.result_guid or { fg = "#CE9178" })

  -- Trigger re-highlight of any open SSNS buffers
  ThemeManager.refresh_open_buffers()
end

---Preview a theme without saving
---@param name string? Theme name (nil for default)
function ThemeManager.preview(name)
  local colors = ThemeManager.get_colors(name)
  ThemeManager.apply_colors(colors)
end

---Save theme preference to file
function ThemeManager.save_preference()
  local content = current_theme or ""
  local ok = pcall(vim.fn.writefile, { content }, persistence_file)
  if not ok then
    vim.notify("SSNS: Failed to save theme preference", vim.log.levels.WARN)
  end
end

---Load theme preference from file
function ThemeManager.load_preference()
  if vim.fn.filereadable(persistence_file) == 1 then
    local lines = vim.fn.readfile(persistence_file)
    if lines and #lines > 0 and lines[1] ~= "" then
      current_theme = lines[1]
    end
  end
end

---Save theme preference asynchronously
---@param callback fun(success: boolean)? Optional callback
function ThemeManager.save_preference_async(callback)
  local FileIO = require('nvim-ssns.async.file_io')
  local content = current_theme or ""

  FileIO.write_async(persistence_file, content, function(result)
    if not result.success then
      vim.notify("SSNS: Failed to save theme preference", vim.log.levels.WARN)
    end
    if callback then
      callback(result.success)
    end
  end)
end

---Load theme preference from file asynchronously
---@param callback fun(theme: string?) Callback with loaded theme name
function ThemeManager.load_preference_async(callback)
  local FileIO = require('nvim-ssns.async.file_io')

  FileIO.exists_async(persistence_file, function(exists)
    if not exists then
      callback(nil)
      return
    end

    FileIO.read_async(persistence_file, function(result)
      if result.success and result.data and result.data ~= "" then
        -- Trim whitespace/newlines
        local theme = result.data:match("^%s*(.-)%s*$")
        if theme and theme ~= "" then
          current_theme = theme
          callback(theme)
          return
        end
      end
      callback(nil)
    end)
  end)
end

---Refresh all open SSNS buffers to use current theme
function ThemeManager.refresh_open_buffers()
  -- Refresh tree buffer if open
  local ok, Buffer = pcall(require, 'ssns.ui.buffer')
  if ok and Buffer.exists and Buffer.exists() then
    local Tree = require('nvim-ssns.ui.core.tree')
    if Tree.render then
      pcall(Tree.render)
    end
  end

  -- Re-apply semantic highlighting to query buffers
  local ok2, UiQuery = pcall(require, 'ssns.ui.query')
  if ok2 and UiQuery.query_buffers then
    local SemanticHighlighter = require('nvim-ssns.highlighting.semantic')
    for bufnr, _ in pairs(UiQuery.query_buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(SemanticHighlighter.update, bufnr)
      end
    end
  end
end

---Clear theme cache (force reload from files)
function ThemeManager.clear_cache()
  loaded_themes = {}
end

---Get the themes directory path
---@return string
function ThemeManager.get_themes_dir()
  return themes_dir
end

---Get the user themes directory path
---@return string
function ThemeManager.get_user_themes_dir()
  return user_themes_dir
end

-- ============================================================================
-- User Theme Management API (similar to Formatter Presets)
-- ============================================================================

-- Lua reserved keywords that cannot be used as bare identifiers
local LUA_KEYWORDS = {
  ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
  ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
  ["function"] = true, ["goto"] = true, ["if"] = true, ["in"] = true,
  ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
  ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
  ["until"] = true, ["while"] = true,
}

---Serialize a table to Lua code for saving themes
---@param tbl table The table to serialize
---@param indent number Current indentation level
---@return string lua_code
local function serialize_table(tbl, indent)
  indent = indent or 0
  local spaces = string.rep("  ", indent)
  local inner_spaces = string.rep("  ", indent + 1)
  local parts = {}

  table.insert(parts, "{\n")

  -- Get sorted keys for consistent output
  local keys = {}
  for k in pairs(tbl) do
    table.insert(keys, k)
  end
  table.sort(keys, function(a, b)
    -- Sort by type first (strings before numbers), then by value
    local ta, tb = type(a), type(b)
    if ta ~= tb then
      return ta < tb
    end
    return a < b
  end)

  for _, k in ipairs(keys) do
    local v = tbl[k]
    local key_str
    -- Check if key is a valid identifier AND not a reserved keyword
    if type(k) == "string" and k:match("^[a-zA-Z_][a-zA-Z0-9_]*$") and not LUA_KEYWORDS[k] then
      key_str = k
    else
      key_str = string.format("[%q]", k)
    end

    local value_str
    if type(v) == "table" then
      value_str = serialize_table(v, indent + 1)
    elseif type(v) == "string" then
      value_str = string.format("%q", v)
    elseif type(v) == "boolean" then
      value_str = v and "true" or "false"
    else
      value_str = tostring(v)
    end

    table.insert(parts, string.format("%s%s = %s,\n", inner_spaces, key_str, value_str))
  end

  table.insert(parts, spaces .. "}")
  return table.concat(parts)
end

---Ensure user themes directory exists
local function ensure_user_themes_dir()
  local stat = vim.loop.fs_stat(user_themes_dir)
  if not stat then
    vim.fn.mkdir(user_themes_dir, "p")
  end
end

---Get list of built-in theme names
---@return string[] names
function ThemeManager.list_builtin()
  return get_theme_files(themes_dir)
end

---Get list of user theme names
---@return string[] names
function ThemeManager.list_user()
  ensure_user_themes_dir()
  return get_theme_files(user_themes_dir)
end

---Check if a theme exists
---@param name string Theme name
---@return boolean exists
function ThemeManager.exists(name)
  return ThemeManager.get_theme(name) ~= nil or ThemeManager.get_theme(name, true) ~= nil
end

---Check if a name is a built-in theme
---@param name string Theme name
---@return boolean is_builtin
function ThemeManager.is_builtin(name)
  local filepath = themes_dir .. "/" .. name .. ".lua"
  local stat = vim.loop.fs_stat(filepath)
  return stat ~= nil
end

---Generate a unique theme name
---@param base string Base name
---@param is_file_name? boolean If true, generates file name; otherwise display name
---@return string unique_name
function ThemeManager.generate_unique_name(base, is_file_name)
  ensure_user_themes_dir()

  local existing_files = get_theme_files(user_themes_dir)
  local existing_set = {}
  for _, f in ipairs(existing_files) do
    existing_set[f] = true
  end

  -- Also check builtin themes
  local builtin_files = get_theme_files(themes_dir)
  for _, f in ipairs(builtin_files) do
    existing_set[f] = true
  end

  if is_file_name then
    -- For file names
    if not existing_set[base] then
      return base
    end

    local counter = 1
    while existing_set[base .. "_" .. counter] do
      counter = counter + 1
    end
    return base .. "_" .. counter
  else
    -- For display names, use "Custom 1", "Custom 2", etc.
    base = base or "Custom"
    local counter = 1
    local candidate = base .. " " .. counter

    -- Check against display names of existing themes
    local all_themes = ThemeManager.get_available_themes()
    local display_names = {}
    for _, t in ipairs(all_themes) do
      display_names[t.display_name] = true
    end

    while display_names[candidate] do
      counter = counter + 1
      candidate = base .. " " .. counter
    end
    return candidate
  end
end

---Save a theme to the user directory
---@param name string File name (without .lua extension)
---@param display_name string Display name for the theme
---@param colors table Theme colors
---@param description? string Optional description
---@param author? string Optional author
---@return boolean success
---@return string? error_message
function ThemeManager.save(name, display_name, colors, description, author)
  ensure_user_themes_dir()

  -- Sanitize file name
  local safe_name = name:gsub("[^%w_%-]", "_")
  local filepath = user_themes_dir .. "/" .. safe_name .. ".lua"

  -- Build theme content
  local content = string.format([[-- SSNS Theme: %s
-- Auto-generated by SSNS Theme Editor

return {
  name = %q,
  description = %q,
  author = %q,
  is_user = true,

  colors = %s,
}
]], display_name, display_name, description or "", author or "User", serialize_table(colors, 1))

  -- Write file
  local file, err = io.open(filepath, "w")
  if not file then
    return false, "Failed to open file: " .. (err or "unknown error")
  end

  file:write(content)
  file:close()

  -- Clear cache for this theme
  local cache_key = "user:" .. safe_name
  loaded_themes[cache_key] = nil

  return true
end

---Copy a theme to user directory
---@param source_name string Source theme name
---@param dest_name? string Destination name (default: source + " - COPY")
---@return boolean success
---@return string? error_message
function ThemeManager.copy(source_name, dest_name)
  -- Try to load from builtin first, then user
  local source = ThemeManager.get_theme(source_name, false) or ThemeManager.get_theme(source_name, true)
  if not source then
    return false, "Source theme not found: " .. source_name
  end

  -- Generate destination name
  local new_display_name = dest_name or (source.name .. " - COPY")
  local new_file_name = dest_name and dest_name:gsub("[^%w_%-]", "_") or (source_name .. "_copy")

  -- Ensure unique file name
  new_file_name = ThemeManager.generate_unique_name(new_file_name, true)

  -- Copy colors (deep copy)
  local new_colors = vim.deepcopy(source.colors)

  return ThemeManager.save(new_file_name, new_display_name, new_colors, source.description, source.author)
end

---Rename a user theme
---@param old_name string Current file name
---@param new_name string New display name (file name will be derived)
---@return boolean success
---@return string? error_message
function ThemeManager.rename(old_name, new_name)
  -- Only user themes can be renamed
  local theme = ThemeManager.get_theme(old_name, true)
  if not theme then
    return false, "Theme not found: " .. old_name
  end

  -- Check if it's a builtin theme
  if ThemeManager.is_builtin(old_name) then
    return false, "Cannot rename built-in theme. Use copy instead."
  end

  local old_filepath = user_themes_dir .. "/" .. old_name .. ".lua"
  local new_file_name = new_name:gsub("[^%w_%-]", "_")
  local new_filepath = user_themes_dir .. "/" .. new_file_name .. ".lua"

  -- Check if new name already exists
  if vim.loop.fs_stat(new_filepath) then
    return false, "A theme with this name already exists"
  end

  -- Save with new name first
  local ok, err = ThemeManager.save(new_file_name, new_name, theme.colors, theme.description, theme.author)
  if not ok then
    return false, err
  end

  -- Delete old file
  local delete_ok = os.remove(old_filepath)
  if not delete_ok then
    vim.notify("SSNS: Could not delete old theme file", vim.log.levels.WARN)
  end

  -- Clear cache
  loaded_themes["user:" .. old_name] = nil

  -- Update current theme reference if needed
  if current_theme == old_name then
    current_theme = new_file_name
    ThemeManager.save_preference()
  end

  return true
end

---Delete a user theme
---@param name string Theme file name
---@return boolean success
---@return string? error_message
function ThemeManager.delete(name)
  -- Check if it's a builtin theme
  if ThemeManager.is_builtin(name) then
    return false, "Cannot delete built-in theme"
  end

  local filepath = user_themes_dir .. "/" .. name .. ".lua"

  -- Check if file exists
  if not vim.loop.fs_stat(filepath) then
    return false, "Theme not found: " .. name
  end

  local ok = os.remove(filepath)
  if not ok then
    return false, "Failed to delete theme file"
  end

  -- Clear cache
  loaded_themes["user:" .. name] = nil

  -- Clear current theme if it was deleted
  if current_theme == name then
    current_theme = nil
    ThemeManager.save_preference()
    ThemeManager.apply_current()
  end

  return true
end

---Get the default theme name
---@return string name The default theme name
function ThemeManager.get_default()
  return "dark"
end

return ThemeManager
