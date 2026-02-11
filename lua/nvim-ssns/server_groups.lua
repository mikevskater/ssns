---@class ServerGroupData
---@field name string Group display name
---@field order number Sort order (for custom sort)
---@field servers string[] Server names in this group (ordered)
---@field sub_groups ServerGroupData[] Nested child groups (ordered)

---@class ServerGroupsState
---@field version number File format version (1)
---@field sort_mode "alpha"|"last_connection"|"custom"
---@field groups ServerGroupData[] Top-level groups (ordered)
---@field ungrouped_order string[] Server names not in any group (ordered)
---@field expanded_groups string[] Dot-separated paths of expanded groups
---@field last_connected table<string, number> server_name -> epoch timestamp

---@class ServerGroupRenderItem
---@field type "group"|"server"
---@field name string? Server name (when type == "server")
---@field group_data ServerGroupData? Group data (when type == "group")
---@field path string? Dot-separated group path (when type == "group")

---@class ServerGroups
---Server groups management for SSNS tree UI
---Pure organizational layer — does NOT inherit from BaseDbObject
local ServerGroups = {}

local JsonUtils = require('nvim-ssns.utils.json')

-- File format version
local FILE_VERSION = 1

-- Module state (loaded lazily)
---@type ServerGroupsState?
local state = nil

-- Debounce timer for save
local save_timer = nil
local SAVE_DEBOUNCE_MS = 500

-- ============================================================================
-- File Path & Directory
-- ============================================================================

---Get the path to the server_groups JSON file
---@return string path
function ServerGroups.get_file_path()
  local data_path = vim.fn.stdpath("data")
  return data_path .. "/nvim-ssns/server_groups.json"
end

---Ensure the data directory exists
local function ensure_directory()
  local data_path = vim.fn.stdpath("data")
  vim.fn.mkdir(data_path .. "/nvim-ssns", "p")
end

-- ============================================================================
-- Load / Save / State
-- ============================================================================

---Create default state
---@return ServerGroupsState
local function create_default_state()
  return {
    version = FILE_VERSION,
    sort_mode = "custom",
    groups = {},
    ungrouped_order = {},
    expanded_groups = {},
    last_connected = {},
  }
end

---Load state from disk (or create default)
---@return ServerGroupsState
function ServerGroups.load()
  if state then
    return state
  end

  local path = ServerGroups.get_file_path()

  if vim.fn.filereadable(path) ~= 1 then
    state = create_default_state()
    return state
  end

  local lines = vim.fn.readfile(path)
  if #lines == 0 then
    state = create_default_state()
    return state
  end

  local content = table.concat(lines, "\n")
  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then
    vim.notify("SSNS: Failed to parse server_groups.json, using defaults", vim.log.levels.WARN)
    state = create_default_state()
    return state
  end

  -- Ensure all fields exist
  state = {
    version = data.version or FILE_VERSION,
    sort_mode = data.sort_mode or "custom",
    groups = data.groups or {},
    ungrouped_order = data.ungrouped_order or {},
    expanded_groups = data.expanded_groups or {},
    last_connected = data.last_connected or {},
  }

  return state
end

---Save state to disk (immediate)
---@return boolean success
function ServerGroups.save_now()
  if not state then
    return false
  end

  ensure_directory()
  local path = ServerGroups.get_file_path()
  local lines = JsonUtils.prettify_lines(state)
  local ok = pcall(vim.fn.writefile, lines, path)
  if not ok then
    vim.notify("SSNS: Failed to write server_groups.json", vim.log.levels.ERROR)
    return false
  end
  return true
end

---Save state to disk (debounced for rapid operations)
function ServerGroups.save()
  if save_timer then
    save_timer:stop()
  end
  save_timer = vim.loop.new_timer()
  save_timer:start(SAVE_DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    ServerGroups.save_now()
    if save_timer then
      save_timer:stop()
      save_timer:close()
      save_timer = nil
    end
  end))
end

---Get current state (loading if needed)
---@return ServerGroupsState
function ServerGroups.get_state()
  return ServerGroups.load()
end

---Reset in-memory state (forces reload from disk on next access)
function ServerGroups.reset()
  state = nil
end

-- ============================================================================
-- Sync with Cache
-- ============================================================================

---Synchronize server_groups state with Cache.servers
---Ensures all cached servers appear in the groups/ungrouped, removes stale entries
function ServerGroups.sync_with_cache()
  local Cache = require('nvim-ssns.cache')
  local s = ServerGroups.get_state()

  -- Build set of all server names currently in Cache
  local cache_names = {}
  for _, server in ipairs(Cache.get_all_servers()) do
    cache_names[server.name] = true
  end

  -- Build set of all server names tracked in groups
  local tracked_names = {}
  local function collect_tracked(groups)
    for _, group in ipairs(groups) do
      for _, name in ipairs(group.servers) do
        tracked_names[name] = true
      end
      collect_tracked(group.sub_groups)
    end
  end
  collect_tracked(s.groups)
  for _, name in ipairs(s.ungrouped_order) do
    tracked_names[name] = true
  end

  -- Add any new Cache servers to ungrouped (not already tracked)
  for name, _ in pairs(cache_names) do
    if not tracked_names[name] then
      table.insert(s.ungrouped_order, name)
    end
  end

  -- Remove stale servers from groups
  local function prune_groups(groups)
    for _, group in ipairs(groups) do
      local pruned = {}
      for _, name in ipairs(group.servers) do
        if cache_names[name] then
          table.insert(pruned, name)
        end
      end
      group.servers = pruned
      prune_groups(group.sub_groups)
    end
  end
  prune_groups(s.groups)

  -- Remove stale servers from ungrouped
  local pruned_ungrouped = {}
  for _, name in ipairs(s.ungrouped_order) do
    if cache_names[name] then
      table.insert(pruned_ungrouped, name)
    end
  end
  s.ungrouped_order = pruned_ungrouped
end

-- ============================================================================
-- Group Lookup
-- ============================================================================

---Find a group by dot-separated path
---@param group_path string Dot-separated group path (e.g., "Dev.Frontend")
---@return ServerGroupData? group The found group or nil
---@return ServerGroupData[]? parent_list The parent's sub_groups array (for removal)
---@return number? index Index in parent_list
function ServerGroups.find_group(group_path)
  if not group_path or group_path == "" then
    return nil, nil, nil
  end

  local s = ServerGroups.get_state()
  local parts = vim.split(group_path, ".", { plain = true })

  ---@param groups ServerGroupData[]
  ---@param depth number
  ---@return ServerGroupData?, ServerGroupData[]?, number?
  local function search(groups, depth)
    for i, group in ipairs(groups) do
      if group.name == parts[depth] then
        if depth == #parts then
          return group, groups, i
        else
          return search(group.sub_groups, depth + 1)
        end
      end
    end
    return nil, nil, nil
  end

  return search(s.groups, 1)
end

---Get the dot-separated path for a group by searching the tree
---@param target ServerGroupData The group to find
---@return string? path Dot-separated path or nil
function ServerGroups.get_group_path(target)
  local s = ServerGroups.get_state()

  local function search(groups, prefix)
    for _, group in ipairs(groups) do
      local path = prefix == "" and group.name or (prefix .. "." .. group.name)
      if group == target then
        return path
      end
      local found = search(group.sub_groups, path)
      if found then return found end
    end
    return nil
  end

  return search(s.groups, "")
end

-- ============================================================================
-- Group CRUD
-- ============================================================================

---Create a new group
---@param parent_path string? Parent group path (nil/empty for root level)
---@param name string Group name
---@return boolean success
---@return string? error
function ServerGroups.create_group(parent_path, name)
  local s = ServerGroups.get_state()

  if not name or name == "" then
    return false, "Group name is required"
  end

  local new_group = {
    name = name,
    order = 0,
    servers = {},
    sub_groups = {},
  }

  if not parent_path or parent_path == "" then
    -- Root level
    -- Check for duplicate name
    for _, g in ipairs(s.groups) do
      if g.name == name then
        return false, string.format("Group '%s' already exists at root level", name)
      end
    end
    new_group.order = #s.groups + 1
    table.insert(s.groups, new_group)
  else
    -- Nested under parent
    local parent = ServerGroups.find_group(parent_path)
    if not parent then
      return false, string.format("Parent group '%s' not found", parent_path)
    end
    for _, g in ipairs(parent.sub_groups) do
      if g.name == name then
        return false, string.format("Group '%s' already exists in '%s'", name, parent_path)
      end
    end
    new_group.order = #parent.sub_groups + 1
    table.insert(parent.sub_groups, new_group)
  end

  ServerGroups.save()
  return true, nil
end

---Rename a group
---@param group_path string Current dot-separated path
---@param new_name string New name
---@return boolean success
---@return string? error
function ServerGroups.rename_group(group_path, new_name)
  if not new_name or new_name == "" then
    return false, "New name is required"
  end

  local group, parent_list, _ = ServerGroups.find_group(group_path)
  if not group then
    return false, string.format("Group '%s' not found", group_path)
  end

  -- Check for duplicate name among siblings
  for _, g in ipairs(parent_list) do
    if g ~= group and g.name == new_name then
      return false, string.format("Group '%s' already exists at this level", new_name)
    end
  end

  local old_name = group.name

  -- Update expanded_groups paths
  local s = ServerGroups.get_state()
  local old_prefix = group_path
  local parts = vim.split(group_path, ".", { plain = true })
  parts[#parts] = new_name
  local new_prefix = table.concat(parts, ".")

  local updated_expanded = {}
  for _, path in ipairs(s.expanded_groups) do
    if path == old_prefix then
      table.insert(updated_expanded, new_prefix)
    elseif vim.startswith(path, old_prefix .. ".") then
      table.insert(updated_expanded, new_prefix .. path:sub(#old_prefix + 1))
    else
      table.insert(updated_expanded, path)
    end
  end
  s.expanded_groups = updated_expanded

  group.name = new_name

  ServerGroups.save()
  return true, nil
end

---Delete a group — children (servers + sub-groups) adopted by parent level
---@param group_path string Dot-separated path of group to delete
---@return boolean success
---@return string? error
function ServerGroups.delete_group(group_path)
  local group, parent_list, idx = ServerGroups.find_group(group_path)
  if not group or not parent_list or not idx then
    return false, string.format("Group '%s' not found", group_path)
  end

  local s = ServerGroups.get_state()

  -- Determine where orphaned children go
  local parts = vim.split(group_path, ".", { plain = true })
  local is_root = #parts == 1

  -- Adopt servers
  if is_root then
    -- Move servers to ungrouped
    for _, name in ipairs(group.servers) do
      table.insert(s.ungrouped_order, name)
    end
    -- Move sub-groups to root
    for _, sub in ipairs(group.sub_groups) do
      sub.order = #s.groups + 1
      table.insert(s.groups, sub)
    end
  else
    -- Move to parent group
    local parent_path = table.concat(vim.list_slice(parts, 1, #parts - 1), ".")
    local parent_group = ServerGroups.find_group(parent_path)
    if parent_group then
      for _, name in ipairs(group.servers) do
        table.insert(parent_group.servers, name)
      end
      for _, sub in ipairs(group.sub_groups) do
        sub.order = #parent_group.sub_groups + 1
        table.insert(parent_group.sub_groups, sub)
      end
    end
  end

  -- Remove the group itself
  table.remove(parent_list, idx)

  -- Clean up expanded_groups
  local cleaned = {}
  for _, path in ipairs(s.expanded_groups) do
    if path ~= group_path and not vim.startswith(path, group_path .. ".") then
      table.insert(cleaned, path)
    end
  end
  s.expanded_groups = cleaned

  ServerGroups.save()
  return true, nil
end

-- ============================================================================
-- Server Assignment
-- ============================================================================

---Find which group/ungrouped a server belongs to
---@param server_name string
---@return string? group_path Path of containing group (nil if ungrouped)
---@return ServerGroupData? group The containing group (nil if ungrouped)
local function find_server_location(server_name)
  local s = ServerGroups.get_state()

  local function search(groups, prefix)
    for _, group in ipairs(groups) do
      local path = prefix == "" and group.name or (prefix .. "." .. group.name)
      for _, name in ipairs(group.servers) do
        if name == server_name then
          return path, group
        end
      end
      local found_path, found_group = search(group.sub_groups, path)
      if found_path then return found_path, found_group end
    end
    return nil, nil
  end

  return search(s.groups, "")
end

---Remove server from wherever it currently is (group or ungrouped)
---@param server_name string
local function remove_server_everywhere(server_name)
  local s = ServerGroups.get_state()

  -- Remove from ungrouped
  for i, name in ipairs(s.ungrouped_order) do
    if name == server_name then
      table.remove(s.ungrouped_order, i)
      break
    end
  end

  -- Remove from groups
  local function remove_from(groups)
    for _, group in ipairs(groups) do
      for i, name in ipairs(group.servers) do
        if name == server_name then
          table.remove(group.servers, i)
          return true
        end
      end
      if remove_from(group.sub_groups) then return true end
    end
    return false
  end
  remove_from(s.groups)
end

---Add a server to a group
---@param server_name string
---@param group_path string Dot-separated group path
---@return boolean success
---@return string? error
function ServerGroups.add_server_to_group(server_name, group_path)
  local group = ServerGroups.find_group(group_path)
  if not group then
    return false, string.format("Group '%s' not found", group_path)
  end

  -- Remove from current location first
  remove_server_everywhere(server_name)

  -- Add to target group
  table.insert(group.servers, server_name)

  ServerGroups.save()
  return true, nil
end

---Remove a server from its group to ungrouped
---@param server_name string
---@return boolean success
function ServerGroups.remove_server_from_group(server_name)
  local s = ServerGroups.get_state()
  remove_server_everywhere(server_name)
  table.insert(s.ungrouped_order, server_name)
  ServerGroups.save()
  return true
end

---Move a server between groups (or to ungrouped)
---@param server_name string
---@param target_group_path string? Target group path (nil for ungrouped)
---@return boolean success
---@return string? error
function ServerGroups.move_server(server_name, target_group_path)
  if not target_group_path or target_group_path == "" then
    return ServerGroups.remove_server_from_group(server_name), nil
  end
  return ServerGroups.add_server_to_group(server_name, target_group_path)
end

-- ============================================================================
-- Move Group
-- ============================================================================

---Move a group to a new parent (or root level)
---@param group_path string Current path of the group
---@param new_parent_path string? New parent path (nil/empty for root level)
---@return boolean success
---@return string? error
function ServerGroups.move_group(group_path, new_parent_path)
  -- Prevent moving to self or descendant
  if new_parent_path and (new_parent_path == group_path or vim.startswith(new_parent_path, group_path .. ".")) then
    return false, "Cannot move a group into itself or its descendants"
  end

  local group, source_list, source_idx = ServerGroups.find_group(group_path)
  if not group or not source_list or not source_idx then
    return false, string.format("Group '%s' not found", group_path)
  end

  local s = ServerGroups.get_state()

  -- Determine target list
  local target_list
  if not new_parent_path or new_parent_path == "" then
    target_list = s.groups
  else
    local target_parent = ServerGroups.find_group(new_parent_path)
    if not target_parent then
      return false, string.format("Target group '%s' not found", new_parent_path)
    end
    target_list = target_parent.sub_groups
  end

  -- Check for duplicate name in target
  for _, g in ipairs(target_list) do
    if g.name == group.name then
      return false, string.format("Group '%s' already exists at target level", group.name)
    end
  end

  -- Remove from source
  table.remove(source_list, source_idx)

  -- Add to target
  group.order = #target_list + 1
  table.insert(target_list, group)

  -- Update expanded_groups paths
  local old_prefix = group_path
  local new_prefix = (new_parent_path and new_parent_path ~= "") and (new_parent_path .. "." .. group.name) or group.name

  local updated_expanded = {}
  for _, path in ipairs(s.expanded_groups) do
    if path == old_prefix then
      table.insert(updated_expanded, new_prefix)
    elseif vim.startswith(path, old_prefix .. ".") then
      table.insert(updated_expanded, new_prefix .. path:sub(#old_prefix + 1))
    else
      table.insert(updated_expanded, path)
    end
  end
  s.expanded_groups = updated_expanded

  ServerGroups.save()
  return true, nil
end

---Move item (server or group) to parent level
---@param item_type "server"|"group"
---@param item_identifier string Server name or group path
---@return boolean success
---@return string? error
function ServerGroups.move_to_parent(item_type, item_identifier)
  local s = ServerGroups.get_state()

  if item_type == "server" then
    local group_path, group = find_server_location(item_identifier)
    if not group_path then
      -- Already ungrouped
      return false, "Server is already at root level"
    end

    -- Remove from current group
    for i, name in ipairs(group.servers) do
      if name == item_identifier then
        table.remove(group.servers, i)
        break
      end
    end

    -- Determine parent level
    local parts = vim.split(group_path, ".", { plain = true })
    if #parts == 1 then
      -- Parent is root -> move to ungrouped
      table.insert(s.ungrouped_order, item_identifier)
    else
      -- Parent is another group
      local parent_path = table.concat(vim.list_slice(parts, 1, #parts - 1), ".")
      local parent_group = ServerGroups.find_group(parent_path)
      if parent_group then
        table.insert(parent_group.servers, item_identifier)
      else
        table.insert(s.ungrouped_order, item_identifier)
      end
    end

    ServerGroups.save()
    return true, nil

  elseif item_type == "group" then
    local parts = vim.split(item_identifier, ".", { plain = true })
    if #parts == 1 then
      return false, "Group is already at root level"
    end

    -- Grandparent path (or root if parent is root)
    local grandparent_path = #parts >= 3 and table.concat(vim.list_slice(parts, 1, #parts - 2), ".") or nil
    return ServerGroups.move_group(item_identifier, grandparent_path)
  end

  return false, "Invalid item type"
end

-- ============================================================================
-- Expansion State
-- ============================================================================

---Check if a group is expanded
---@param group_path string
---@return boolean
function ServerGroups.is_expanded(group_path)
  local s = ServerGroups.get_state()
  return vim.tbl_contains(s.expanded_groups, group_path)
end

---Toggle a group's expansion state
---@param group_path string
---@return boolean new_state
function ServerGroups.toggle_expanded(group_path)
  local s = ServerGroups.get_state()

  for i, path in ipairs(s.expanded_groups) do
    if path == group_path then
      table.remove(s.expanded_groups, i)
      ServerGroups.save()
      return false
    end
  end

  table.insert(s.expanded_groups, group_path)
  ServerGroups.save()
  return true
end

---Set expansion state
---@param group_path string
---@param expanded boolean
function ServerGroups.set_expanded(group_path, expanded)
  local s = ServerGroups.get_state()

  for i, path in ipairs(s.expanded_groups) do
    if path == group_path then
      if not expanded then
        table.remove(s.expanded_groups, i)
        ServerGroups.save()
      end
      return
    end
  end

  if expanded then
    table.insert(s.expanded_groups, group_path)
    ServerGroups.save()
  end
end

-- ============================================================================
-- Last Connected Tracking
-- ============================================================================

---Record a server connection timestamp
---@param server_name string
function ServerGroups.record_connection(server_name)
  local s = ServerGroups.get_state()
  s.last_connected[server_name] = os.time()
  ServerGroups.save()
end

---Get last connection time for a server
---@param server_name string
---@return number? timestamp Epoch timestamp or nil
function ServerGroups.get_last_connected(server_name)
  local s = ServerGroups.get_state()
  return s.last_connected[server_name]
end

---Get max last_connected for a group (recursively includes all contained servers)
---@param group ServerGroupData
---@return number timestamp Max epoch timestamp (0 if none)
local function get_group_max_timestamp(group)
  local s = ServerGroups.get_state()
  local max_ts = 0

  for _, name in ipairs(group.servers) do
    local ts = s.last_connected[name] or 0
    if ts > max_ts then max_ts = ts end
  end

  for _, sub in ipairs(group.sub_groups) do
    local ts = get_group_max_timestamp(sub)
    if ts > max_ts then max_ts = ts end
  end

  return max_ts
end

-- ============================================================================
-- Sorting
-- ============================================================================

---Get current sort mode
---@return "alpha"|"last_connection"|"custom"
function ServerGroups.get_sort_mode()
  local s = ServerGroups.get_state()
  return s.sort_mode
end

---Set sort mode
---@param mode "alpha"|"last_connection"|"custom"
function ServerGroups.set_sort_mode(mode)
  local s = ServerGroups.get_state()
  s.sort_mode = mode
  ServerGroups.save()
end

---Cycle sort mode: custom -> alpha -> last_connection -> custom
---@return string new_mode
function ServerGroups.cycle_sort()
  local s = ServerGroups.get_state()
  if s.sort_mode == "custom" then
    s.sort_mode = "alpha"
  elseif s.sort_mode == "alpha" then
    s.sort_mode = "last_connection"
  else
    s.sort_mode = "custom"
  end
  ServerGroups.save()
  return s.sort_mode
end

---Freeze current display order into custom order values
---Used when reordering while in non-custom mode
function ServerGroups.freeze_current_order()
  local s = ServerGroups.get_state()
  local items = ServerGroups.get_render_order()

  -- Rebuild groups and ungrouped from current display order
  local new_groups = {}
  local new_ungrouped = {}

  for _, item in ipairs(items) do
    if item.type == "group" and item.group_data then
      table.insert(new_groups, item.group_data)
      item.group_data.order = #new_groups
    elseif item.type == "server" and item.name then
      -- Check if server is ungrouped
      local in_group = false
      local function check_groups(groups)
        for _, g in ipairs(groups) do
          for _, name in ipairs(g.servers) do
            if name == item.name then in_group = true; return end
          end
          check_groups(g.sub_groups)
        end
      end
      check_groups(s.groups)
      if not in_group then
        table.insert(new_ungrouped, item.name)
      end
    end
  end

  -- Only update ungrouped ordering (group ordering preserved in groups array)
  s.ungrouped_order = new_ungrouped
  s.sort_mode = "custom"
  ServerGroups.save()
end

---Reorder an item up within its container
---@param item_type "server"|"group"
---@param item_identifier string Server name or group path
---@return boolean moved
function ServerGroups.reorder_up(item_type, item_identifier)
  local s = ServerGroups.get_state()

  -- Auto-freeze if not in custom mode
  if s.sort_mode ~= "custom" then
    ServerGroups.freeze_current_order()
  end

  if item_type == "server" then
    -- Find in group or ungrouped
    local _, group = find_server_location(item_identifier)
    local list = group and group.servers or s.ungrouped_order

    for i, name in ipairs(list) do
      if name == item_identifier then
        if i > 1 then
          list[i], list[i - 1] = list[i - 1], list[i]
          ServerGroups.save()
          return true
        end
        return false
      end
    end

  elseif item_type == "group" then
    local parts = vim.split(item_identifier, ".", { plain = true })
    local list
    if #parts == 1 then
      list = s.groups
    else
      local parent_path = table.concat(vim.list_slice(parts, 1, #parts - 1), ".")
      local parent = ServerGroups.find_group(parent_path)
      list = parent and parent.sub_groups or s.groups
    end

    local target_name = parts[#parts]
    for i, g in ipairs(list) do
      if g.name == target_name then
        if i > 1 then
          list[i], list[i - 1] = list[i - 1], list[i]
          ServerGroups.save()
          return true
        end
        return false
      end
    end
  end

  return false
end

---Reorder an item down within its container
---@param item_type "server"|"group"
---@param item_identifier string Server name or group path
---@return boolean moved
function ServerGroups.reorder_down(item_type, item_identifier)
  local s = ServerGroups.get_state()

  -- Auto-freeze if not in custom mode
  if s.sort_mode ~= "custom" then
    ServerGroups.freeze_current_order()
  end

  if item_type == "server" then
    local _, group = find_server_location(item_identifier)
    local list = group and group.servers or s.ungrouped_order

    for i, name in ipairs(list) do
      if name == item_identifier then
        if i < #list then
          list[i], list[i + 1] = list[i + 1], list[i]
          ServerGroups.save()
          return true
        end
        return false
      end
    end

  elseif item_type == "group" then
    local parts = vim.split(item_identifier, ".", { plain = true })
    local list
    if #parts == 1 then
      list = s.groups
    else
      local parent_path = table.concat(vim.list_slice(parts, 1, #parts - 1), ".")
      local parent = ServerGroups.find_group(parent_path)
      list = parent and parent.sub_groups or s.groups
    end

    local target_name = parts[#parts]
    for i, g in ipairs(list) do
      if g.name == target_name then
        if i < #list then
          list[i], list[i + 1] = list[i + 1], list[i]
          ServerGroups.save()
          return true
        end
        return false
      end
    end
  end

  return false
end

-- ============================================================================
-- Render Order
-- ============================================================================

---Get the ordered list of items for rendering
---Merges groups and ungrouped servers, sorted according to current mode
---@return ServerGroupRenderItem[]
function ServerGroups.get_render_order()
  local s = ServerGroups.get_state()

  -- Build flat list of top-level items (groups + ungrouped servers)
  ---@type ServerGroupRenderItem[]
  local items = {}

  local function add_group(group, prefix)
    local path = prefix == "" and group.name or (prefix .. "." .. group.name)
    table.insert(items, {
      type = "group",
      name = group.name,
      group_data = group,
      path = path,
    })
  end

  local function add_server(name)
    table.insert(items, {
      type = "server",
      name = name,
    })
  end

  if s.sort_mode == "custom" then
    -- Custom: groups first (in array order), then ungrouped servers (in array order)
    for _, group in ipairs(s.groups) do
      add_group(group, "")
    end
    for _, name in ipairs(s.ungrouped_order) do
      add_server(name)
    end

  elseif s.sort_mode == "alpha" then
    -- Alpha: merge all, sort by name (case-insensitive)
    for _, group in ipairs(s.groups) do
      add_group(group, "")
    end
    for _, name in ipairs(s.ungrouped_order) do
      add_server(name)
    end
    table.sort(items, function(a, b)
      return (a.name or ""):lower() < (b.name or ""):lower()
    end)

  elseif s.sort_mode == "last_connection" then
    -- Last connection: merge all, sort by most recent timestamp (descending)
    for _, group in ipairs(s.groups) do
      add_group(group, "")
    end
    for _, name in ipairs(s.ungrouped_order) do
      add_server(name)
    end
    table.sort(items, function(a, b)
      local ts_a, ts_b
      if a.type == "group" then
        ts_a = get_group_max_timestamp(a.group_data)
      else
        ts_a = s.last_connected[a.name] or 0
      end
      if b.type == "group" then
        ts_b = get_group_max_timestamp(b.group_data)
      else
        ts_b = s.last_connected[b.name] or 0
      end
      return ts_a > ts_b
    end)
  end

  return items
end

---Get sorted servers within a group
---@param group ServerGroupData
---@return string[] server_names Ordered server names
function ServerGroups.get_group_servers_sorted(group)
  local s = ServerGroups.get_state()

  -- Shallow copy for sorting
  local names = {}
  for _, name in ipairs(group.servers) do
    table.insert(names, name)
  end

  if s.sort_mode == "alpha" then
    table.sort(names, function(a, b)
      return a:lower() < b:lower()
    end)
  elseif s.sort_mode == "last_connection" then
    table.sort(names, function(a, b)
      local ts_a = s.last_connected[a] or 0
      local ts_b = s.last_connected[b] or 0
      return ts_a > ts_b
    end)
  end
  -- custom: return in array order

  return names
end

---Get sorted sub-groups within a group
---@param group ServerGroupData
---@return ServerGroupData[] Ordered sub-groups
function ServerGroups.get_group_subgroups_sorted(group)
  local s = ServerGroups.get_state()

  -- Shallow copy the array (references, not deep copy) for sorting
  local subs = {}
  for _, sub in ipairs(group.sub_groups) do
    table.insert(subs, sub)
  end

  if s.sort_mode == "alpha" then
    table.sort(subs, function(a, b)
      return a.name:lower() < b.name:lower()
    end)
  elseif s.sort_mode == "last_connection" then
    table.sort(subs, function(a, b)
      return get_group_max_timestamp(a) > get_group_max_timestamp(b)
    end)
  end

  return subs
end

-- ============================================================================
-- Utilities for UI
-- ============================================================================

---Get all valid move destinations for a server (list of group paths + "(Root Level)")
---@param server_name string? Server name to exclude current location
---@return table[] destinations Array of { label, path } where path is group_path or ""
function ServerGroups.get_move_destinations_for_server(server_name)
  local destinations = {}
  local current_path = server_name and find_server_location(server_name) or nil

  local function collect(groups, prefix)
    for _, group in ipairs(groups) do
      local path = prefix == "" and group.name or (prefix .. "." .. group.name)
      if path ~= current_path then
        -- Show depth via indentation
        local depth = select(2, path:gsub("%.", ""))
        local label = string.rep("  ", depth) .. group.name
        table.insert(destinations, { label = label, path = path })
      end
      collect(group.sub_groups, path)
    end
  end

  local s = ServerGroups.get_state()
  collect(s.groups, "")

  -- Add "(Root Level)" if server is not already ungrouped
  if current_path then
    table.insert(destinations, 1, { label = "(Root Level)", path = "" })
  end

  return destinations
end

---Get all valid move destinations for a group
---Excludes self, children of self, and current parent
---@param group_path string
---@return table[] destinations Array of { label, path }
function ServerGroups.get_move_destinations_for_group(group_path)
  local destinations = {}
  local parts = vim.split(group_path, ".", { plain = true })
  local current_parent = #parts > 1 and table.concat(vim.list_slice(parts, 1, #parts - 1), ".") or ""

  local function collect(groups, prefix)
    for _, group in ipairs(groups) do
      local path = prefix == "" and group.name or (prefix .. "." .. group.name)
      -- Skip self, descendants of self, and current parent
      if path ~= group_path
        and not vim.startswith(path, group_path .. ".")
        and path ~= current_parent then
        local depth = select(2, path:gsub("%.", ""))
        local label = string.rep("  ", depth) .. group.name
        table.insert(destinations, { label = label, path = path })
      end
      collect(group.sub_groups, path)
    end
  end

  local s = ServerGroups.get_state()
  collect(s.groups, "")

  -- Add "(Root Level)" if not already at root
  if #parts > 1 then
    table.insert(destinations, 1, { label = "(Root Level)", path = "" })
  end

  return destinations
end

---Get sort mode display label for tree header
---@return string label
function ServerGroups.get_sort_label()
  local s = ServerGroups.get_state()
  if s.sort_mode == "alpha" then
    return "[A-Z]"
  elseif s.sort_mode == "last_connection" then
    return "[Recent]"
  else
    return "[Custom]"
  end
end

---Check if there are any groups defined
---@return boolean
function ServerGroups.has_groups()
  local s = ServerGroups.get_state()
  return #s.groups > 0
end

-- ============================================================================
-- Setup (VimLeavePre flush)
-- ============================================================================

---Setup autocmd for flushing pending saves on exit
function ServerGroups.setup()
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      -- Flush any pending debounced save
      if save_timer then
        save_timer:stop()
        save_timer:close()
        save_timer = nil
      end
      if state then
        ServerGroups.save_now()
      end
    end,
  })
end

return ServerGroups
