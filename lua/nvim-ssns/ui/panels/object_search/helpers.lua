---@class ObjectSearchHelpers
---Utility functions for the object search module
local M = {}

local State = require('nvim-ssns.ui.panels.object_search.state')

-- ============================================================================
-- Object Type Helpers
-- ============================================================================

---Check if a searchable object is a system object
---@param searchable SearchableObject
---@return boolean
function M.is_system_object(searchable)
  -- Check if this is a schema object with a system schema name
  if searchable.object_type == "schema" and searchable.name and State.SYSTEM_SCHEMAS[searchable.name] then
    return true
  end
  -- Check if object belongs to a system schema
  if searchable.schema_name and State.SYSTEM_SCHEMAS[searchable.schema_name] then
    return true
  end
  -- Check if database is a system database
  if searchable.database_name and State.SYSTEM_DATABASES[searchable.database_name] then
    return true
  end
  return false
end

---Get object type icon
---@param object_type string
---@return string icon
function M.get_object_icon(object_type)
  local icons = {
    table = "T",
    view = "V",
    procedure = "P",
    ["function"] = "F",
    synonym = "S",
    schema = "σ",
  }
  return icons[object_type] or "?"
end

---Check if an object should be shown based on its object type filter
---@param searchable SearchableObject
---@return boolean
function M.should_show_object_type(searchable)
  local ui_state = State.get_ui_state()
  local obj_type = searchable.object_type
  if obj_type == "table" then return ui_state.show_tables
  elseif obj_type == "view" then return ui_state.show_views
  elseif obj_type == "procedure" then return ui_state.show_procedures
  elseif obj_type == "function" then return ui_state.show_functions
  elseif obj_type == "synonym" then return ui_state.show_synonyms
  elseif obj_type == "schema" then return ui_state.show_schemas
  end
  return true  -- Show unknown types by default
end

-- ============================================================================
-- ID and Display Helpers
-- ============================================================================

---Generate unique ID for an object
---@param server_name string
---@param database_name string
---@param schema_name string?
---@param object_type string
---@param name string
---@return string
function M.generate_unique_id(server_name, database_name, schema_name, object_type, name)
  return string.format("%s:%s:%s:%s:%s",
    server_name,
    database_name,
    schema_name or "",
    object_type,
    name
  )
end

---Build display name for an object
---@param searchable SearchableObject
---@return string
function M.build_display_name(searchable)
  if searchable.schema_name then
    return string.format("[%s].[%s]", searchable.schema_name, searchable.name)
  else
    return string.format("[%s]", searchable.name)
  end
end

-- ============================================================================
-- String Matching Helpers
-- ============================================================================

---Check if character is a word character
---@param char string
---@return boolean
function M.is_word_char(char)
  if not char or char == "" then return false end
  return char:match("[%w_]") ~= nil
end

---Check if match is a whole word
---@param text string
---@param match_start number
---@param match_end number
---@return boolean
function M.is_whole_word_match(text, match_start, match_end)
  if match_start > 1 then
    local char_before = text:sub(match_start - 1, match_start - 1)
    if M.is_word_char(char_before) then
      return false
    end
  end
  if match_end < #text then
    local char_after = text:sub(match_end + 1, match_end + 1)
    if M.is_word_char(char_after) then
      return false
    end
  end
  return true
end

return M
