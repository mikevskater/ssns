---@class UiFilterInput
---Filter input UI for database object filtering
local UiFilterInput = {}

local UiFloatForm = require('nvim-float.float.form')

---@type table? Current UiFloatForm state
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

  -- Check if this group supports system schema filtering
  local supports_sys_schema_filter = group.object_type == "tables_group"
    or group.object_type == "views_group"
    or group.object_type == "procedures_group"
    or group.object_type == "functions_group"
    or group.object_type == "scalar_functions_group"
    or group.object_type == "table_functions_group"
    or group.object_type == "synonyms_group"
    or group.object_type == "schemas_group"
    or group.object_type == "system_databases_group"
    or group.object_type == "system_schemas_group"
    or group.object_type == "schema"
    or group.object_type == "schema_view"

  -- Get default for hide_system_schemas from config
  local Config = require('nvim-ssns.config')
  local filter_config = Config.get_filters()
  local default_hide_system = filter_config and filter_config.hide_system_schemas or false

  -- Build field list
  local fields = {
    { name = "name_include", label = "Include Name (regex)", type = "text", value = current_filters.name_include or "" },
    { name = "name_exclude", label = "Exclude Name (regex)", type = "text", value = current_filters.name_exclude or "" },
    { name = "schema_include", label = "Include Schema (regex)", type = "text", value = current_filters.schema_include or "" },
    { name = "schema_exclude", label = "Exclude Schema (regex)", type = "text", value = current_filters.schema_exclude or "" },
  }

  -- Add "Hide System Schemas" checkbox for supported groups (before Case Sensitive)
  if supports_sys_schema_filter then
    local hide_sys_value = current_filters.hide_system_schemas
    if hide_sys_value == nil then
      hide_sys_value = default_hide_system
    end
    table.insert(fields, {
      name = "hide_system_schemas",
      label = "Hide System Schemas",
      type = "checkbox",
      value = hide_sys_value,
    })
  end

  -- Add Case Sensitive checkbox
  table.insert(fields, {
    name = "case_sensitive",
    label = "Case Sensitive",
    type = "checkbox",
    value = current_filters.case_sensitive or false,
  })

  -- Add object type checkboxes for schema nodes
  if is_schema_node then
    local object_types_map = current_filters.object_types or {}
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

  -- Create header text
  local header = {
    string.format("Filter: %s (%s)", group.name or "N/A", group.object_type or "unknown"),
    string.rep("─", 50),
  }

  -- Create the form
  state = UiFloatForm.create({
    title = " Filter Settings ",
    header = header,
    fields = fields,
    width = 60,
    height = nil,  -- Auto-calculate
    on_submit = function(values)
      -- Reconstruct filter structure with object types
      local filters = {
        name_include = values.name_include ~= "" and values.name_include or nil,
        name_exclude = values.name_exclude ~= "" and values.name_exclude or nil,
        schema_include = values.schema_include ~= "" and values.schema_include or nil,
        schema_exclude = values.schema_exclude ~= "" and values.schema_exclude or nil,
        case_sensitive = values.case_sensitive,
      }

      -- Add hide_system_schemas if applicable
      if supports_sys_schema_filter then
        filters.hide_system_schemas = values.hide_system_schemas
      end

      -- Rebuild object_types map for schema nodes
      if is_schema_node then
        filters.object_types = {}
        for _, otype in ipairs(OBJECT_TYPES) do
          local field_name = "type_" .. otype.key
          filters.object_types[otype.key] = values[field_name]
        end
      end

      callback(filters)
      state = nil
    end,
    on_cancel = function()
      state = nil
    end,
  })

  -- Render the form
  if state then
    UiFloatForm.render(state)
  end
end

---Check if filter input is open
---@return boolean
function UiFilterInput.is_open()
  return state ~= nil
end

