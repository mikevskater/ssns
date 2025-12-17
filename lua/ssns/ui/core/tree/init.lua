---@class UiTree
---Tree rendering and interaction for SSNS
---Main entry point that delegates to submodules
local UiTree = {}

-- Import submodules
local TreeRender = require('ssns.ui.core.tree.render')
local TreeActions = require('ssns.ui.core.tree.actions')
local TreeNavigation = require('ssns.ui.core.tree.navigation')
local TreeFeatures = require('ssns.ui.core.tree.features')

---Line to object mapping (line_number -> object)
---@type table<number, BaseDbObject>
UiTree.line_map = {}

---Object to line mapping (object -> line_number)
---@type table<BaseDbObject, number>
UiTree.object_map = {}

---Last cursor position tracking for restoring position after close/reopen
---@type {object: BaseDbObject?, line: number?, column: number?}
UiTree.last_cursor_state = { object = nil, line = nil, column = nil }

-- Re-export helpers from TreeRender for external use
UiTree.get_object_icon = TreeRender.get_object_icon

---Render the entire tree
function UiTree.render()
  TreeRender.render(UiTree)
end

---Render a server and its children
---@param server ServerClass
---@param lines string[]
---@param line_number number
---@param indent_level number
function UiTree.render_server(server, lines, line_number, indent_level)
  TreeRender.render_server(UiTree, server, lines, line_number, indent_level)
end

---Render a database and its children
---@param db DbClass
---@param lines string[]
---@param indent_level number
function UiTree.render_database(db, lines, indent_level)
  TreeRender.render_database(UiTree, db, lines, indent_level)
end

---Render a schema and its children
---@param schema SchemaClass
---@param lines string[]
---@param indent_level number
function UiTree.render_schema(schema, lines, indent_level)
  TreeRender.render_schema(UiTree, schema, lines, indent_level)
end

---Render an object group
---@param group BaseDbObject
---@param lines string[]
---@param indent_level number
function UiTree.render_object_group(group, lines, indent_level)
  TreeRender.render_object_group(UiTree, group, lines, indent_level)
end

---Render a database object
---@param obj BaseDbObject
---@param lines string[]
---@param indent_level number
function UiTree.render_object(obj, lines, indent_level)
  TreeRender.render_object(UiTree, obj, lines, indent_level)
end

---Render a structural group with aligned columns
---@param group BaseDbObject
---@param lines string[]
---@param indent_level number
function UiTree.render_aligned_group(group, lines, indent_level)
  TreeRender.render_aligned_group(UiTree, group, lines, indent_level)
end

---Format a detail row for alignment
---@param obj BaseDbObject
---@param group_type string
---@return string[]?
function UiTree.format_detail_row(obj, group_type)
  return TreeRender.format_detail_row(obj, group_type)
end

-- Action functions

---Toggle node expansion at current cursor
function UiTree.toggle_node()
  TreeActions.toggle_node(UiTree)
end

---Load a node asynchronously
---@param obj BaseDbObject
---@param line_number number
function UiTree.load_node_async(obj, line_number)
  TreeActions.load_node_async(UiTree, obj, line_number)
end

---Execute an action node
---@param action BaseDbObject
function UiTree.execute_action(action)
  TreeActions.execute_action(UiTree, action)
end

---Refresh node at current cursor
function UiTree.refresh_node()
  TreeActions.refresh_node(UiTree)
end

---Refresh all servers
function UiTree.refresh_all()
  TreeActions.refresh_all(UiTree)
end

---Toggle connection for server/database at current cursor
function UiTree.toggle_connection()
  TreeActions.toggle_connection(UiTree)
end

---Toggle favorite status for server at current cursor
function UiTree.toggle_favorite()
  TreeActions.toggle_favorite(UiTree)
end

---Set lualine color for current server or database
function UiTree.set_lualine_color()
  TreeActions.set_lualine_color(UiTree)
end

---Handle mouse click on tree
---@param double_click boolean? Whether this is a double-click
function UiTree.handle_mouse_click(double_click)
  TreeActions.handle_mouse_click(UiTree, double_click)
end

---Handle double-click on tree (expand/collapse)
function UiTree.handle_double_click()
  TreeActions.handle_double_click(UiTree)
end

-- Navigation functions

---Navigate to an object in the tree
---@param target_object BaseDbObject The object to navigate to
function UiTree.navigate_to_object(target_object)
  TreeNavigation.navigate_to_object(UiTree, target_object)
end

---Go to the first child in the current group
function UiTree.goto_first_child()
  TreeNavigation.goto_first_child(UiTree)
end

---Go to the last child in the current group
function UiTree.goto_last_child()
  TreeNavigation.goto_last_child(UiTree)
end

---Toggle expand/collapse of the parent group
function UiTree.toggle_group()
  TreeNavigation.toggle_group(UiTree)
end

---Save current cursor position for later restoration
function UiTree.save_cursor_position()
  TreeNavigation.save_cursor_position(UiTree)
end

---Restore cursor to a target object after tree re-render
---@param target_object table The object to restore cursor to
---@param column number? Optional column position
function UiTree.restore_cursor_to_object(target_object, column)
  TreeNavigation.restore_cursor_to_object(UiTree, target_object, column)
end

-- Feature functions

---Show object dependencies in a floating window
---@param obj BaseDbObject
function UiTree.show_dependencies(obj)
  TreeFeatures.show_dependencies(obj)
end

---Open filter editor for the current group
function UiTree.open_filter()
  TreeFeatures.open_filter(UiTree)
end

---Clear filters for the current group
function UiTree.clear_filter()
  TreeFeatures.clear_filter(UiTree)
end

---Create a new query buffer using the database context from the current tree node
function UiTree.new_query_from_context()
  TreeFeatures.new_query_from_context(UiTree)
end

---Show history for the server of the current node
function UiTree.show_history_from_context()
  TreeFeatures.show_history_from_context(UiTree)
end

---View definition (ALTER script) for the object under cursor
function UiTree.view_definition()
  TreeFeatures.view_definition(UiTree)
end

---View metadata for the object under cursor
function UiTree.view_metadata()
  TreeFeatures.view_metadata(UiTree)
end

return UiTree
