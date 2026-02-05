---@class ViewDefinition
---View SQL object definitions in a floating window
---Supports views, procedures, functions, and tables that have get_definition() method
local ViewDefinition = {}

local GoTo = require('nvim-ssns.features.go_to')
local UiFloat = require('nvim-float.window')

-- Store reference to current floating window for cleanup
local current_float = nil
-- Store reference to target object for edit action
local current_object = nil

---Check if an object supports viewing its definition
---@param obj BaseDbObject
---@return boolean
function ViewDefinition.has_definition(obj)
  return obj and type(obj.get_definition) == "function"
end

---Get display name for an object
---@param obj BaseDbObject
---@return string
local function get_object_display_name(obj)
  return obj.table_name or obj.view_name or obj.procedure_name
         or obj.function_name or obj.synonym_name or obj.name or "unknown"
end

---Get object type label for title
---@param obj BaseDbObject
---@return string
local function get_object_type_label(obj)
  local obj_type = obj.object_type or "object"
  return obj_type:upper()
end

---Close the current floating window
function ViewDefinition.close_current_float()
  if current_float then
    -- Clean up buffer registration from UiQuery
    if current_float.bufnr then
      local success, UiQuery = pcall(require, 'ssns.ui.query')
      if success then
        UiQuery.query_buffers[current_float.bufnr] = nil
      end
    end
    -- Close the window
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
  current_object = nil
end

---Open definition in editable query buffer (like ALTER action)
function ViewDefinition.edit_definition()
  local target_object = current_object
  if not target_object then
    vim.notify("No object to edit", vim.log.levels.WARN)
    return
  end

  -- Close the float first
  ViewDefinition.close_current_float()

  -- Get definition
  local definition = target_object:get_definition()
  if not definition then
    vim.notify("No definition to edit", vim.log.levels.WARN)
    return
  end

  -- Get server and database context
  local server = target_object:get_server()
  local database = target_object:get_database()

  if not server then
    vim.notify("Cannot determine server context", vim.log.levels.WARN)
    return
  end

  -- Create query buffer with definition (same as ALTER action)
  local Query = require('nvim-ssns.ui.core.query')
  local obj_name = get_object_display_name(target_object)
  Query.create_query_buffer(server, database, definition, obj_name)
end

---Show definition in a floating window
---@param definition string The SQL definition text
---@param target_object BaseDbObject The resolved object
---@param identifier string The original identifier string
function ViewDefinition.show_definition_float(definition, target_object, identifier)
  -- Close existing float if any
  ViewDefinition.close_current_float()

  -- Store object reference for edit action
  current_object = target_object

  -- Split definition into lines
  local lines = vim.split(definition, "\n")

  -- Build title
  local obj_type = get_object_type_label(target_object)
  local obj_name = get_object_display_name(target_object)
  local schema_name = target_object.schema_name
  local display_name = schema_name and (schema_name .. "." .. obj_name) or obj_name
  local title = string.format(" %s: %s ", obj_type, display_name)

  -- Create floating window
  current_float = UiFloat.create(lines, {
    title = title,
    title_pos = "center",
    footer = " q/ESC/<CR>: close | e: edit in buffer ",
    footer_pos = "center",
    border = "rounded",
    filetype = "sql",
    readonly = true,
    modifiable = false,
    cursorline = true,
    wrap = false,
    centered = true,
    max_width = math.floor(vim.o.columns * 0.85),
    max_height = math.floor(vim.o.lines * 0.85),
    min_width = 60,
    min_height = 10,
    default_keymaps = false,  -- We'll set our own
    keymaps = {
      ["q"] = function() ViewDefinition.close_current_float() end,
      ["<Esc>"] = function() ViewDefinition.close_current_float() end,
      ["<CR>"] = function() ViewDefinition.close_current_float() end,
      ["e"] = function() ViewDefinition.edit_definition() end,
    },
  })

  -- Setup semantic highlighting for the floating buffer
  if current_float and current_float.bufnr then
    local bufnr = current_float.bufnr
    local server = target_object:get_server()
    local database = target_object:get_database()

    -- Register buffer with UiQuery for connection context
    local UiQuery = require('nvim-ssns.ui.core.query')
    UiQuery.query_buffers[bufnr] = {
      server = server,
      database = database,
      last_database = database and database.db_name or nil,
    }

    -- Enable semantic highlighting
    local SemanticHighlighter = require('nvim-ssns.highlighting.semantic')
    SemanticHighlighter.setup_buffer(bufnr)
  end
end

---View the definition of the object under cursor
function ViewDefinition.view_definition_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]

  -- Get current line
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  if not line then
    vim.notify("Cannot read current line", vim.log.levels.WARN)
    return
  end

  -- Reuse go_to identifier detection
  local identifier = GoTo.get_identifier_at_cursor(line, col)
  if not identifier or identifier == "" then
    vim.notify("No identifier under cursor", vim.log.levels.WARN)
    return
  end

  -- Parse identifier
  local database_name, schema_name, object_name = GoTo.parse_identifier(identifier)

  -- Resolve to database object
  local target_object, error_msg = GoTo.resolve_object(bufnr, object_name, schema_name, database_name)
  if not target_object then
    vim.notify(error_msg or "Object not found", vim.log.levels.WARN)
    return
  end

  -- Check if object has definition
  if not ViewDefinition.has_definition(target_object) then
    vim.notify(string.format("'%s' does not have a viewable definition", identifier), vim.log.levels.WARN)
    return
  end

  -- Get the definition (uses cached value if available)
  local definition = target_object:get_definition()
  if not definition or definition == "" then
    vim.notify(string.format("No definition found for '%s'", identifier), vim.log.levels.WARN)
    return
  end

  -- Show in floating window
  ViewDefinition.show_definition_float(definition, target_object, identifier)
end

return ViewDefinition

