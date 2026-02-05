---@class ThemeEditorData
---Color definitions and categories for the theme editor
local M = {}

---@class ColorDefinition
---@field key string The color key in theme.colors
---@field name string Display name
---@field category string Category name
---@field description string? Optional description

---All color definitions organized by category
---@type ColorDefinition[]
M.COLOR_DEFINITIONS = {
  -- Server Types
  { key = "server_sqlserver", name = "SQL Server", category = "Servers", description = "SQL Server icon/text" },
  { key = "server_postgres", name = "PostgreSQL", category = "Servers", description = "PostgreSQL icon/text" },
  { key = "server_mysql", name = "MySQL", category = "Servers", description = "MySQL icon/text" },
  { key = "server_sqlite", name = "SQLite", category = "Servers", description = "SQLite icon/text" },
  { key = "server_bigquery", name = "BigQuery", category = "Servers", description = "BigQuery icon/text" },
  { key = "server", name = "Default Server", category = "Servers", description = "Fallback server color" },

  -- Database Objects
  { key = "database", name = "Database", category = "Objects", description = "Database nodes" },
  { key = "schema", name = "Schema", category = "Objects", description = "Schema nodes" },
  { key = "table", name = "Table", category = "Objects", description = "Table nodes" },
  { key = "temp_table", name = "Temp Table", category = "Objects", description = "#temp and ##global tables" },
  { key = "view", name = "View", category = "Objects", description = "View nodes" },
  { key = "procedure", name = "Procedure", category = "Objects", description = "Stored procedures" },
  { key = "function", name = "Function", category = "Objects", description = "Functions" },
  { key = "column", name = "Column", category = "Objects", description = "Column nodes" },
  { key = "index", name = "Index", category = "Objects", description = "Index nodes" },
  { key = "key", name = "Key", category = "Objects", description = "Primary/foreign keys" },
  { key = "parameter", name = "Parameter", category = "Objects", description = "Procedure parameters" },
  { key = "sequence", name = "Sequence", category = "Objects", description = "Sequences" },
  { key = "synonym", name = "Synonym", category = "Objects", description = "Synonyms" },
  { key = "action", name = "Action", category = "Objects", description = "Action items" },
  { key = "group", name = "Group", category = "Objects", description = "Group headers" },

  -- Status
  { key = "status_connected", name = "Connected", category = "Status", description = "Connected state" },
  { key = "status_disconnected", name = "Disconnected", category = "Status", description = "Disconnected state" },
  { key = "status_connecting", name = "Connecting", category = "Status", description = "Connecting state" },
  { key = "status_error", name = "Error", category = "Status", description = "Error state" },

  -- Tree UI
  { key = "expanded", name = "Expanded", category = "Tree", description = "Expanded indicator" },
  { key = "collapsed", name = "Collapsed", category = "Tree", description = "Collapsed indicator" },

  -- SQL Keywords
  { key = "keyword", name = "Keyword", category = "Keywords", description = "Generic SQL keyword" },
  { key = "keyword_statement", name = "Statement", category = "Keywords", description = "SELECT, INSERT, UPDATE, DELETE" },
  { key = "keyword_clause", name = "Clause", category = "Keywords", description = "FROM, WHERE, JOIN, ORDER BY" },
  { key = "keyword_function", name = "Function", category = "Keywords", description = "COUNT, SUM, AVG, etc." },
  { key = "keyword_datatype", name = "Datatype", category = "Keywords", description = "INT, VARCHAR, etc." },
  { key = "keyword_operator", name = "Operator", category = "Keywords", description = "AND, OR, NOT, IN" },
  { key = "keyword_constraint", name = "Constraint", category = "Keywords", description = "PRIMARY, FOREIGN, KEY" },
  { key = "keyword_modifier", name = "Modifier", category = "Keywords", description = "ASC, DESC, DISTINCT" },
  { key = "keyword_misc", name = "Misc", category = "Keywords", description = "Other keywords" },
  { key = "keyword_global_variable", name = "Global Variable", category = "Keywords", description = "@@ROWCOUNT, @@VERSION" },
  { key = "keyword_system_procedure", name = "System Procedure", category = "Keywords", description = "sp_*, xp_*" },

  -- Semantic Highlighting
  { key = "operator", name = "Operator", category = "Semantic", description = "=, <, >, +, -, etc." },
  { key = "string", name = "String", category = "Semantic", description = "String literals" },
  { key = "number", name = "Number", category = "Semantic", description = "Numeric literals" },
  { key = "alias", name = "Alias", category = "Semantic", description = "Table/column aliases" },
  { key = "unresolved", name = "Unresolved", category = "Semantic", description = "Unresolved identifiers" },
  { key = "comment", name = "Comment", category = "Semantic", description = "SQL comments" },

  -- UI Elements
  { key = "ui_border", name = "Border", category = "UI", description = "Window borders" },
  { key = "ui_title", name = "Title", category = "UI", description = "Window titles" },
  { key = "ui_selected", name = "Selected", category = "UI", description = "Selected item background" },
  { key = "ui_hint", name = "Hint", category = "UI", description = "Hint text" },

  -- Result Buffer (optional advanced colors)
  { key = "result_header", name = "Result Header", category = "Results", description = "Column headers" },
  { key = "result_border", name = "Result Border", category = "Results", description = "Grid lines" },
  { key = "result_null", name = "Result NULL", category = "Results", description = "NULL values" },
  { key = "result_message", name = "Result Message", category = "Results", description = "Info messages" },
  { key = "result_date", name = "Result Date", category = "Results", description = "Date/time values" },
  { key = "result_bool", name = "Result Boolean", category = "Results", description = "Boolean values" },
  { key = "result_binary", name = "Result Binary", category = "Results", description = "Binary data" },
  { key = "result_guid", name = "Result GUID", category = "Results", description = "GUID/UUID values" },

  -- Scrollbar (optional)
  { key = "scrollbar", name = "Scrollbar", category = "Scrollbar", description = "Scrollbar background" },
  { key = "scrollbar_thumb", name = "Scrollbar Thumb", category = "Scrollbar", description = "Draggable thumb" },
  { key = "scrollbar_track", name = "Scrollbar Track", category = "Scrollbar", description = "Track background" },
  { key = "scrollbar_arrow", name = "Scrollbar Arrow", category = "Scrollbar", description = "Arrow buttons" },
}

---Get all unique categories in order
---@return string[]
function M.get_categories()
  local seen = {}
  local categories = {}
  for _, def in ipairs(M.COLOR_DEFINITIONS) do
    if not seen[def.category] then
      seen[def.category] = true
      table.insert(categories, def.category)
    end
  end
  return categories
end

---Get color definitions for a specific category
---@param category string
---@return ColorDefinition[]
function M.get_by_category(category)
  local result = {}
  for _, def in ipairs(M.COLOR_DEFINITIONS) do
    if def.category == category then
      table.insert(result, def)
    end
  end
  return result
end

---Find a color definition by key
---@param key string
---@return ColorDefinition?
function M.find_by_key(key)
  for _, def in ipairs(M.COLOR_DEFINITIONS) do
    if def.key == key then
      return def
    end
  end
  return nil
end

return M
