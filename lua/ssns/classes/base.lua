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
---@param opts {name: string, parent: BaseDbObject?}
---@return BaseDbObject
function BaseDbObject.new(opts)
  local self = setmetatable({}, BaseDbObject)

  self.name = opts.name or ""
  self.parent = opts.parent
  self.children = {}
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

  -- If parent is provided, add this as a child
  if self.parent then
    self.parent:add_child(self)
  end

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
function BaseDbObject:toggle_expand()
  self.ui_state.expanded = not self.ui_state.expanded

  -- Lazy load children when expanding for the first time
  if self.ui_state.expanded and not self.is_loaded then
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

return BaseDbObject
