---@class BaseDbObject
---@field name string The display name of this database object
---@field parent BaseDbObject? Parent object in the hierarchy (nil for root/server)
---@field children BaseDbObject[] Child objects in the hierarchy
---@field is_loaded boolean Whether this object's children have been loaded
---@field ui_state UiState UI-specific state (separate from data)
local BaseDbObject = {}
BaseDbObject.__index = BaseDbObject

---@class UiState
---@field expanded boolean Whether the node is expanded in the tree UI
---@field visible boolean Whether the node is visible in the tree UI
---@field icon string? Icon to display in the tree
---@field highlight string? Highlight group for the node
---@field loading boolean Whether the node is currently loading data
---@field error string? Error message if loading failed

---Create a new BaseDbObject instance
---@param opts {name: string, parent: BaseDbObject?, skip_auto_add: boolean?}
---@return BaseDbObject
function BaseDbObject.new(opts)
  local self = setmetatable({}, BaseDbObject)

  self.name = opts.name or ""
  self.parent = opts.parent
  self.children = {}  -- Used for ephemeral UI groups only, not for data storage
  self.is_loaded = false

  -- UI state separate from data
  self.ui_state = {
    expanded = false,
    visible = true,
    icon = nil,
    highlight = nil,
    loading = false,
    error = nil,
  }

  -- NOTE: Removed auto-add to parent.children
  -- Data classes now use typed arrays (databases[], tables[], etc.)
  -- The children[] array is only used for ephemeral UI groups

  return self
end

---Add a child object to this object
---Maintains bidirectional parent/child relationship
---@param child BaseDbObject
function BaseDbObject:add_child(child)
  child.parent = self
  table.insert(self.children, child)
end

---Remove a child object from this object
---@param child BaseDbObject
---@return boolean success True if child was found and removed
function BaseDbObject:remove_child(child)
  for i, c in ipairs(self.children) do
    if c == child then
      table.remove(self.children, i)
      child.parent = nil
      return true
    end
  end
  return false
end

---Get all children of this object
---@return BaseDbObject[]
function BaseDbObject:get_children()
  return self.children
end

---Get the parent object
---@return BaseDbObject?
function BaseDbObject:get_parent()
  return self.parent
end

---Get the root server object by traversing up the hierarchy
---@return BaseDbObject
function BaseDbObject:get_server()
  local current = self
  while current.parent do
    current = current.parent
  end
  return current
end

---Get the database object by traversing up the hierarchy
---@return BaseDbObject? database object or nil if not found
function BaseDbObject:get_database()
  local current = self
  while current do
    if current.object_type == "database" then
      return current
    end
    current = current.parent
  end
  return nil
end

---Get the adapter for this object's database type
---Traverses up to the server and returns its adapter
---@return BaseAdapter
function BaseDbObject:get_adapter()
  local server = self:get_server()
  -- Server class will have an adapter field
  return server.adapter
end

---Get icon from config for this object type
---@return string
function BaseDbObject:get_icon()
  local Config = require('ssns.config')
  local icons = Config.get_ui().icons

  -- Return the icon for this object type, or fallback to stored icon
  return icons[self.object_type] or self.ui_state.icon or ""
end

---Get the full hierarchical path of this object
---@param separator string? Path separator (default: " > ")
---@return string
function BaseDbObject:get_full_path(separator)
  separator = separator or " > "

  local parts = {}
  local current = self

  while current do
    table.insert(parts, 1, current.name)
    current = current.parent
  end

  return table.concat(parts, separator)
end

---Get the depth level of this object in the hierarchy
---@return number depth 0 for root, 1 for first level, etc.
function BaseDbObject:get_depth()
  local depth = 0
  local current = self.parent

  while current do
    depth = depth + 1
    current = current.parent
  end

  return depth
end

---Check if this object has any children
---@return boolean
function BaseDbObject:has_children()
  return #self.children > 0
end

---Clear all children from this object
function BaseDbObject:clear_children()
  for _, child in ipairs(self.children) do
    child.parent = nil
  end
  self.children = {}
  self.is_loaded = false
end

---Reload this object's children
---Subclasses should override this to implement actual loading logic
---@return boolean success
function BaseDbObject:reload()
  self:clear_children()
  return self:load()
end

---Load this object's children (lazy loading)
---Subclasses should override this to implement actual loading logic
---@return boolean success
function BaseDbObject:load()
  -- Default implementation - subclasses override
  self.is_loaded = true
  return true
end

---Toggle the expanded state in the UI
---@param opts { skip_load: boolean? }? Options - skip_load prevents sync loading (for async loading by caller)
function BaseDbObject:toggle_expand(opts)
  opts = opts or {}
  self.ui_state.expanded = not self.ui_state.expanded

  -- Lazy load children when expanding for the first time
  -- Skip if caller will handle loading asynchronously
  if self.ui_state.expanded and not self.is_loaded and not opts.skip_load then
    self:load()
  end
end

---Expand this node in the UI
function BaseDbObject:expand()
  if not self.ui_state.expanded then
    self:toggle_expand()
  end
end

---Collapse this node in the UI
function BaseDbObject:collapse()
  if self.ui_state.expanded then
    self:toggle_expand()
  end
end

---Recursively expand all descendants
---@param max_depth number? Maximum depth to expand (nil for unlimited)
function BaseDbObject:expand_all(max_depth)
  local current_depth = self:get_depth()

  if not self.ui_state.expanded then
    self:expand()
  end

  for _, child in ipairs(self.children) do
    if not max_depth or child:get_depth() - current_depth < max_depth then
      child:expand_all(max_depth)
    end
  end
end

---Recursively collapse all descendants
function BaseDbObject:collapse_all()
  for _, child in ipairs(self.children) do
    child:collapse_all()
  end

  if self.ui_state.expanded then
    self:collapse()
  end
end

---Find a child by name
---@param name string
---@return BaseDbObject?
function BaseDbObject:find_child(name)
  for _, child in ipairs(self.children) do
    if child.name == name then
      return child
    end
  end
  return nil
end

---Find a descendant by path
---@param path string[] Array of names representing the path
---@return BaseDbObject?
function BaseDbObject:find_by_path(path)
  if #path == 0 then
    return self
  end

  local child = self:find_child(path[1])
  if not child then
    return nil
  end

  if #path == 1 then
    return child
  end

  -- Remove first element and continue recursively
  local remaining = {}
  for i = 2, #path do
    table.insert(remaining, path[i])
  end

  return child:find_by_path(remaining)
end

---Check if this object is an ancestor of another object
---@param obj BaseDbObject
---@return boolean
function BaseDbObject:is_ancestor_of(obj)
  local current = obj.parent
  while current do
    if current == self then
      return true
    end
    current = current.parent
  end
  return false
end

---Check if this object is a descendant of another object
---@param obj BaseDbObject
---@return boolean
function BaseDbObject:is_descendant_of(obj)
  return obj:is_ancestor_of(self)
end

---Get a string representation for debugging
---@return string
function BaseDbObject:to_string()
  return string.format(
    "BaseDbObject{name=%s, children=%d, loaded=%s, expanded=%s}",
    self.name,
    #self.children,
    tostring(self.is_loaded),
    tostring(self.ui_state.expanded)
  )
end

-- ============================================================================
-- Action Node Helpers (for create_action_nodes consolidation)
-- ============================================================================

---Create an action node and add it to children
---@param name string Display name (e.g., "SELECT", "DROP")
---@param action_type string Action type identifier (e.g., "select", "drop")
---@return BaseDbObject action The created action node
function BaseDbObject:add_action(name, action_type)
  local action = BaseDbObject.new({
    name = name,
    parent = self,
  })
  action.object_type = "action"
  action.action_type = action_type
  action.is_loaded = true
  table.insert(self.children, action)
  return action
end

---Create a lazy-loaded group node and add it to children
---@param name string Display name (e.g., "Columns", "Parameters")
---@param group_type string Group type identifier (e.g., "column_group", "parameter_group")
---@param load_fn fun(): any[] Function that returns items to populate the group
---@return BaseDbObject group The created group node
function BaseDbObject:add_lazy_group(name, group_type, load_fn)
  local group = BaseDbObject.new({
    name = name,
    parent = self,
  })
  group.object_type = group_type

  -- Override load for lazy loading
  group.load = function(grp)
    if grp.is_loaded then
      return true
    end
    local items = load_fn()
    grp:clear_children()
    for _, item in ipairs(items or {}) do
      table.insert(grp.children, item)
    end
    grp.is_loaded = true
    return true
  end

  table.insert(self.children, group)
  return group
end

---Create an info node and add it to children
---@param text string Display text
---@return BaseDbObject info The created info node
function BaseDbObject:add_info(text)
  local info = BaseDbObject.new({
    name = text,
    parent = self,
  })
  info.object_type = "info"
  info.is_loaded = true
  table.insert(self.children, info)
  return info
end

---Create an error node and add it to children
---@param text string Error message
---@return BaseDbObject error_node The created error node
function BaseDbObject:add_error(text)
  local error_node = BaseDbObject.new({
    name = string.format("⚠ %s", text),
    parent = self,
  })
  error_node.object_type = "error"
  error_node.is_loaded = true
  table.insert(self.children, error_node)
  return error_node
end

---Create an actions group with sub-actions and add it to children
---@param actions table[] Array of {name, action_type} pairs
---@return BaseDbObject group The created actions group
function BaseDbObject:add_actions_group(actions)
  local group = BaseDbObject.new({
    name = "Actions",
    parent = self,
  })
  group.object_type = "actions_group"
  group.is_loaded = true

  for _, action_def in ipairs(actions) do
    local action = BaseDbObject.new({
      name = action_def.name or action_def[1],
      parent = group,
    })
    action.object_type = "action"
    action.action_type = action_def.action_type or action_def[2]
    action.is_loaded = true
    table.insert(group.children, action)
  end

  table.insert(self.children, group)
  return group
end

return BaseDbObject
