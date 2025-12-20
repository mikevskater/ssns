---@class TreeNavigation
---Tree navigation functions for SSNS
---Extracted from ui/core/tree.lua
local TreeNavigation = {}

---Navigate to an object in the tree (expand parents and position cursor)
---Auto-loads unloaded objects in the path and expands them
---@param UiTree table The main UiTree module
---@param target_object BaseDbObject The object to navigate to
function TreeNavigation.navigate_to_object(UiTree, target_object)
  if not target_object then
    vim.notify("No object to navigate to", vim.log.levels.WARN)
    return
  end

  -- Collect all parents up to root (for cross-database, go to target database's tree)
  local parents = {}
  local current = target_object
  while current do
    table.insert(parents, 1, current)  -- Insert at beginning to get root-to-target order
    current = current.parent
  end

  -- Find the server and database that contain the target object
  local server = target_object:get_server()
  local database = target_object:get_database()

  if not server then
    vim.notify("Target server not found", vim.log.levels.WARN)
    return
  end

  if not database then
    vim.notify("Target database not found", vim.log.levels.WARN)
    return
  end

  -- Helper to check if object type can have children
  local function can_have_children(parent)
    return parent:has_children()
      or parent.object_type == "server"
      or parent.object_type == "database"
      or parent.object_type == "schema"
      or parent.object_type == "table"
      or parent.object_type == "view"
      or parent.object_type == "procedure"
      or parent.object_type == "function"
      or parent.object_type == "synonym"
      or parent.object_type == "databases_group"
      or parent.object_type == "tables_group"
      or parent.object_type == "views_group"
      or parent.object_type == "procedures_group"
      or parent.object_type == "functions_group"
      or parent.object_type == "scalar_functions_group"
      or parent.object_type == "table_functions_group"
      or parent.object_type == "synonyms_group"
      or parent.object_type == "schemas_group"
      or parent.object_type == "system_databases_group"
      or parent.object_type == "system_schemas_group"
  end

  -- Helper to expand a parent node
  local function expand_parent(parent)
    if not parent.ui_state.expanded and can_have_children(parent) then
      parent.ui_state.expanded = true
    end
  end

  -- Helper to load a parent async and continue to next
  local function load_parents_async(idx, on_complete)
    if idx > #parents then
      on_complete()
      return
    end

    local parent = parents[idx]

    -- Expand immediately (doesn't require load)
    expand_parent(parent)

    -- Load if needed
    if not parent.is_loaded and parent.load_async then
      parent:load_async(function(_, _)
        load_parents_async(idx + 1, on_complete)
      end)
    else
      load_parents_async(idx + 1, on_complete)
    end
  end

  -- Helper to find object in a collection by schema and name
  local function find_in_collection(collection, schema_name, object_name)
    for _, obj in ipairs(collection or {}) do
      local obj_schema = obj.schema_name
      local obj_name = obj.table_name or obj.view_name or obj.procedure_name
                       or obj.function_name or obj.synonym_name or obj.name
      if obj_schema == schema_name and obj_name == object_name then
        return obj
      end
    end
    return nil
  end

  -- Helper to continue after all async loads complete
  local function finish_navigation()
    -- Ensure expansions are set
    server.ui_state.expanded = true
    server["_ui_databases_group_expanded"] = true
    database.ui_state.expanded = true

    -- Verify object exists in cached data using typed arrays
    local group_type = nil
    local sub_group_type = nil
    local found_object = nil

    -- Get target's schema and name for comparison
    local target_schema = target_object.schema_name
    local target_name = target_object.table_name or target_object.view_name
                        or target_object.procedure_name or target_object.function_name
                        or target_object.synonym_name or target_object.name

    if target_object.object_type == "table" then
      group_type = "tables_group"
      found_object = find_in_collection(database:get_tables(), target_schema, target_name)
    elseif target_object.object_type == "view" then
      group_type = "views_group"
      found_object = find_in_collection(database:get_views(), target_schema, target_name)
    elseif target_object.object_type == "procedure" then
      group_type = "procedures_group"
      found_object = find_in_collection(database:get_procedures(), target_schema, target_name)
    elseif target_object.object_type == "function" then
      group_type = "functions_group"
      found_object = find_in_collection(database:get_functions(), target_schema, target_name)
      if found_object and found_object.is_table_valued and found_object:is_table_valued() then
        sub_group_type = "table_functions_group"
      else
        sub_group_type = "scalar_functions_group"
      end
    elseif target_object.object_type == "synonym" then
      group_type = "synonyms_group"
      found_object = find_in_collection(database:get_synonyms(), target_schema, target_name)
    end

    -- Use the found object (from current cache) instead of potentially stale target_object
    if found_object then
      target_object = found_object
    end

    -- Object doesn't exist in cached data - don't expand
    if not found_object then
      vim.notify(string.format("Object '%s.%s' not found in database (may have been dropped)", target_schema, target_name), vim.log.levels.WARN)
      return
    end

    -- Object exists - store expansion state for the ephemeral groups
    if group_type then
      database["_ui_" .. group_type .. "_expanded"] = true
      if sub_group_type then
        database["_ui_" .. sub_group_type .. "_expanded"] = true
      end
    end

    -- Re-render tree to show all expanded nodes
    UiTree.render()

    -- Find the line number for the target object
    local target_line = UiTree.object_map[target_object]
    if not target_line then
      vim.notify("Object not found in tree after expansion", vim.log.levels.WARN)
      return
    end

    -- Position cursor on the target object with smart positioning
    local Buffer = require('ssns.ui.core.buffer')
    local Config = require('ssns.config')
    local smart_positioning = Config.get_ui().smart_cursor_positioning

    local col = smart_positioning and Buffer.get_name_column(target_line) or 0
    Buffer.set_cursor(target_line, col)

    if smart_positioning then
      Buffer.last_indent_info = {
        line = target_line,
        indent_level = Buffer.get_indent_level(target_line),
        column = col,
      }
    end

    vim.notify(string.format("Navigated to %s", target_object.name), vim.log.levels.INFO)
  end

  -- Start the async loading chain
  load_parents_async(1, finish_navigation)
end

---Go to the first child in the current group
---If on a group node, goes to its first child
---If on a child within a group, goes to the first sibling
---@param UiTree table The main UiTree module
function TreeNavigation.goto_first_child(UiTree)
  local Buffer = require('ssns.ui.core.buffer')
  local Config = require('ssns.config')
  local smart_positioning = Config.get_ui().smart_cursor_positioning

  local line_number = Buffer.get_current_line()
  local obj = UiTree.line_map[line_number]

  if not obj then
    return
  end

  local target_obj = nil

  -- Check if current object is a group (has children and is expanded)
  if obj.ui_state and obj.ui_state.expanded and obj:has_children() then
    -- On a group node - go to first child
    local children = obj:get_children()
    if #children > 0 then
      -- Apply filters if this is a filterable group
      local UiFilters = require('ssns.ui.core.filters')
      local filters = UiFilters.get(obj)
      local filtered_children = UiFilters.apply(children, filters)
      if #filtered_children > 0 then
        target_obj = filtered_children[1]
      end
    end
  elseif obj.parent then
    -- On a child within a group - go to first sibling
    local parent = obj.parent
    if parent:has_children() then
      local siblings = parent:get_children()
      -- Apply filters if parent is a filterable group
      local UiFilters = require('ssns.ui.core.filters')
      local filters = UiFilters.get(parent)
      local filtered_siblings = UiFilters.apply(siblings, filters)
      if #filtered_siblings > 0 then
        target_obj = filtered_siblings[1]
      end
    end
  end

  if target_obj then
    local target_line = UiTree.object_map[target_obj]
    if target_line then
      local col = smart_positioning and Buffer.get_name_column(target_line) or 0
      Buffer.set_cursor(target_line, col)
      -- Update indent tracking
      if smart_positioning then
        Buffer.last_indent_info = {
          line = target_line,
          indent_level = Buffer.get_indent_level(target_line),
          column = col,
        }
      end
    end
  end
end

---Go to the last child in the current group
---If on a group node, goes to its last child
---If on a child within a group, goes to the last sibling
---@param UiTree table The main UiTree module
function TreeNavigation.goto_last_child(UiTree)
  local Buffer = require('ssns.ui.core.buffer')
  local Config = require('ssns.config')
  local smart_positioning = Config.get_ui().smart_cursor_positioning

  local line_number = Buffer.get_current_line()
  local obj = UiTree.line_map[line_number]

  if not obj then
    return
  end

  local target_obj = nil

  -- Check if current object is a group (has children and is expanded)
  if obj.ui_state and obj.ui_state.expanded and obj:has_children() then
    -- On a group node - go to last child
    local children = obj:get_children()
    if #children > 0 then
      -- Apply filters if this is a filterable group
      local UiFilters = require('ssns.ui.core.filters')
      local filters = UiFilters.get(obj)
      local filtered_children = UiFilters.apply(children, filters)
      if #filtered_children > 0 then
        target_obj = filtered_children[#filtered_children]
      end
    end
  elseif obj.parent then
    -- On a child within a group - go to last sibling
    local parent = obj.parent
    if parent:has_children() then
      local siblings = parent:get_children()
      -- Apply filters if parent is a filterable group
      local UiFilters = require('ssns.ui.core.filters')
      local filters = UiFilters.get(parent)
      local filtered_siblings = UiFilters.apply(siblings, filters)
      if #filtered_siblings > 0 then
        target_obj = filtered_siblings[#filtered_siblings]
      end
    end
  end

  if target_obj then
    local target_line = UiTree.object_map[target_obj]
    if target_line then
      local col = smart_positioning and Buffer.get_name_column(target_line) or 0
      Buffer.set_cursor(target_line, col)
      -- Update indent tracking
      if smart_positioning then
        Buffer.last_indent_info = {
          line = target_line,
          indent_level = Buffer.get_indent_level(target_line),
          column = col,
        }
      end
    end
  end
end

---Toggle expand/collapse of the parent group
---If on a group node, toggles that group
---If on a child within a group, toggles the parent group and moves cursor to it
---@param UiTree table The main UiTree module
function TreeNavigation.toggle_group(UiTree)
  local Buffer = require('ssns.ui.core.buffer')
  local Config = require('ssns.config')
  local smart_positioning = Config.get_ui().smart_cursor_positioning

  local line_number = Buffer.get_current_line()
  local obj = UiTree.line_map[line_number]

  if not obj then
    return
  end

  local target_group = nil

  -- Check if current object is a group (can be expanded/collapsed)
  if obj.ui_state and obj:has_children() then
    -- Current object is a group - toggle it directly
    target_group = obj
  elseif obj.parent then
    -- Find the nearest parent that is a group (can be expanded/collapsed)
    local parent = obj.parent
    while parent do
      if parent.ui_state and parent:has_children() then
        target_group = parent
        break
      end
      parent = parent.parent
    end
  end

  if target_group then
    -- Toggle the group's expansion state
    target_group:toggle_expand()

    -- Re-render tree
    UiTree.render()

    -- Find the line of the target group and position cursor there
    local target_line = UiTree.object_map[target_group]
    if target_line then
      local col = smart_positioning and Buffer.get_name_column(target_line) or 0
      Buffer.set_cursor(target_line, col)
      -- Update indent tracking
      if smart_positioning then
        Buffer.last_indent_info = {
          line = target_line,
          indent_level = Buffer.get_indent_level(target_line),
          column = col,
        }
      end
    end
  end
end

---Save current cursor position for later restoration
---Called before closing the tree buffer
---@param UiTree table The main UiTree module
function TreeNavigation.save_cursor_position(UiTree)
  local Buffer = require('ssns.ui.core.buffer')

  if not Buffer.is_open() then
    return
  end

  local line = Buffer.get_current_line()
  local obj = UiTree.line_map[line]

  if obj then
    local cursor = vim.api.nvim_win_get_cursor(Buffer.winid)
    UiTree.last_cursor_state = {
      object = obj,
      line = line,
      column = cursor[2],
    }
  end
end

---Restore cursor to a target object after tree re-render
---Handles both direct object lookup and fuzzy matching by name/type
---@param UiTree table The main UiTree module
---@param target_object table The object to restore cursor to
---@param column number? Optional column position
function TreeNavigation.restore_cursor_to_object(UiTree, target_object, column)
  local Buffer = require('ssns.ui.core.buffer')

  if not Buffer.is_open() or not target_object then
    return
  end

  -- Try direct lookup first (object identity preserved)
  local target_line = UiTree.object_map[target_object]

  -- If direct lookup fails, try fuzzy matching by name and type
  if not target_line then
    for line_num, obj in pairs(UiTree.line_map) do
      if obj.name == target_object.name and
         obj.object_type == target_object.object_type then
        -- Additional parent matching for nested objects
        if target_object.parent and obj.parent then
          if obj.parent.name == target_object.parent.name and
             obj.parent.object_type == target_object.parent.object_type then
            target_line = line_num
            break
          end
        elseif not target_object.parent and not obj.parent then
          target_line = line_num
          break
        end
      end
    end
  end

  if target_line then
    local Config = require('ssns.config')
    local smart_positioning = Config.get_ui().smart_cursor_positioning
    local col = column or (smart_positioning and Buffer.get_name_column(target_line) or 0)

    local total_lines = vim.api.nvim_buf_line_count(Buffer.bufnr)
    if target_line >= 1 and target_line <= total_lines then
      Buffer.set_cursor(target_line, col)

      -- Update indent tracking for smart positioning
      if smart_positioning then
        Buffer.last_indent_info = {
          line = target_line,
          indent_level = Buffer.get_indent_level(target_line),
          column = col,
        }
      end
    end
  end
end

return TreeNavigation
