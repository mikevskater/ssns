---@class FormatterPreset
---@field name string Display name
---@field description string? Description of the preset style
---@field config FormatterConfig Formatter configuration overrides

---@class FormatterPresets
---Manages formatter style presets (built-in and user-defined)
local Presets = {}

-- Presets directory paths
local current_file = debug.getinfo(1, "S").source:sub(2)
local presets_dir = vim.fn.fnamemodify(current_file, ":h")
local builtin_dir = presets_dir .. "/builtin"
local user_dir = presets_dir .. "/user"

-- Cache of loaded presets
---@type table<string, FormatterPreset>
local loaded_presets = {}

-- ============================================================================
-- Internal Helpers
-- ============================================================================

---Ensure user presets directory exists
local function ensure_user_dir()
  local stat = vim.loop.fs_stat(user_dir)
  if not stat then
    vim.fn.mkdir(user_dir, "p")
  end
end

---Get list of lua files in a directory
---@param dir string Directory path
---@return string[] files List of preset names (without .lua extension)
local function get_preset_files(dir)
  local files = {}
  local handle = vim.loop.fs_scandir(dir)
  if not handle then
    return files
  end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end

    if type == "file" and name:match("%.lua$") then
      -- Skip init.lua
      if name ~= "init.lua" then
        local preset_name = name:gsub("%.lua$", "")
        table.insert(files, preset_name)
      end
    end
  end

  table.sort(files)
  return files
end

---Load a preset from file
---@param name string Preset name
---@param is_user boolean Whether this is a user preset
---@return FormatterPreset? preset The loaded preset or nil
local function load_preset_file(name, is_user)
  local dir = is_user and user_dir or builtin_dir
  local filepath = dir .. "/" .. name .. ".lua"

  -- Check if file exists
  local stat = vim.loop.fs_stat(filepath)
  if not stat then
    return nil
  end

  -- Load the preset file
  local ok, preset = pcall(dofile, filepath)
  if not ok or type(preset) ~= "table" then
    vim.notify(string.format("SSNS Formatter: Failed to load preset '%s': %s", name, tostring(preset)), vim.log.levels.WARN)
    return nil
  end

  -- Validate preset has required fields
  if not preset.name or not preset.config then
    vim.notify(string.format("SSNS Formatter: Invalid preset '%s': missing name or config", name), vim.log.levels.WARN)
    return nil
  end

  -- Mark as user preset if applicable
  preset.is_user = is_user
  preset.file_name = name

  return preset
end

---Serialize a table to Lua code
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
    if type(k) == "string" and k:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
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

-- ============================================================================
-- Public API
-- ============================================================================

---List all available presets (built-in and user)
---@return FormatterPreset[] presets List of all presets
function Presets.list()
  local all_presets = {}

  -- Load built-in presets first
  local builtin_files = get_preset_files(builtin_dir)
  for _, name in ipairs(builtin_files) do
    local cache_key = "builtin:" .. name
    if not loaded_presets[cache_key] then
      loaded_presets[cache_key] = load_preset_file(name, false)
    end
    if loaded_presets[cache_key] then
      table.insert(all_presets, loaded_presets[cache_key])
    end
  end

  -- Then load user presets
  ensure_user_dir()
  local user_files = get_preset_files(user_dir)
  for _, name in ipairs(user_files) do
    local cache_key = "user:" .. name
    if not loaded_presets[cache_key] then
      loaded_presets[cache_key] = load_preset_file(name, true)
    end
    if loaded_presets[cache_key] then
      table.insert(all_presets, loaded_presets[cache_key])
    end
  end

  return all_presets
end

---Get list of built-in preset names
---@return string[] names
function Presets.list_builtin()
  return get_preset_files(builtin_dir)
end

---Get list of user preset names
---@return string[] names
function Presets.list_user()
  ensure_user_dir()
  return get_preset_files(user_dir)
end

---Load a preset by name
---@param name string Preset name (display name or file name)
---@return FormatterPreset? preset The preset or nil if not found
function Presets.load(name)
  -- First check cache by file name
  local cache_key_builtin = "builtin:" .. name
  local cache_key_user = "user:" .. name

  if loaded_presets[cache_key_builtin] then
    return loaded_presets[cache_key_builtin]
  end
  if loaded_presets[cache_key_user] then
    return loaded_presets[cache_key_user]
  end

  -- Try to load from user directory first (user presets take precedence)
  local user_preset = load_preset_file(name, true)
  if user_preset then
    loaded_presets[cache_key_user] = user_preset
    return user_preset
  end

  -- Then try built-in
  local builtin_preset = load_preset_file(name, false)
  if builtin_preset then
    loaded_presets[cache_key_builtin] = builtin_preset
    return builtin_preset
  end

  -- Search by display name in cache
  for _, preset in pairs(loaded_presets) do
    if preset.name == name then
      return preset
    end
  end

  return nil
end

---Save a preset to the user directory
---@param name string File name (without .lua extension)
---@param display_name string Display name for the preset
---@param config table Formatter configuration
---@param description? string Optional description
---@return boolean success
---@return string? error_message
function Presets.save(name, display_name, config, description)
  ensure_user_dir()

  -- Sanitize file name
  local safe_name = name:gsub("[^%w_%-]", "_")
  local filepath = user_dir .. "/" .. safe_name .. ".lua"

  -- Build preset content
  local content = string.format([[-- SSNS Formatter Preset: %s
-- Auto-generated by SSNS Formatter Config UI

return {
  name = %q,
  description = %q,
  is_user = true,
  config = %s,
}
]], display_name, display_name, description or "", serialize_table(config, 1))

  -- Write file
  local file, err = io.open(filepath, "w")
  if not file then
    return false, "Failed to open file: " .. (err or "unknown error")
  end

  file:write(content)
  file:close()

  -- Clear cache for this preset
  local cache_key = "user:" .. safe_name
  loaded_presets[cache_key] = nil

  return true
end

---Copy a preset to user directory
---@param source_name string Source preset name
---@param dest_name? string Destination name (default: source + " - COPY")
---@return boolean success
---@return string? error_message
function Presets.copy(source_name, dest_name)
  local source = Presets.load(source_name)
  if not source then
    return false, "Source preset not found: " .. source_name
  end

  -- Generate destination name
  local new_display_name = dest_name or (source.name .. " - COPY")
  local new_file_name = dest_name and dest_name:gsub("[^%w_%-]", "_") or (source.file_name .. "_copy")

  -- Ensure unique name
  new_file_name = Presets.generate_unique_name(new_file_name, true)

  -- Copy config (deep copy)
  local new_config = vim.deepcopy(source.config)

  return Presets.save(new_file_name, new_display_name, new_config, source.description)
end

---Rename a user preset
---@param old_name string Current file name
---@param new_name string New display name (file name will be derived)
---@return boolean success
---@return string? error_message
function Presets.rename(old_name, new_name)
  -- Only user presets can be renamed
  local preset = Presets.load(old_name)
  if not preset then
    return false, "Preset not found: " .. old_name
  end

  if not preset.is_user then
    return false, "Cannot rename built-in preset. Use copy instead."
  end

  local old_filepath = user_dir .. "/" .. old_name .. ".lua"
  local new_file_name = new_name:gsub("[^%w_%-]", "_")
  local new_filepath = user_dir .. "/" .. new_file_name .. ".lua"

  -- Check if new name already exists
  if vim.loop.fs_stat(new_filepath) then
    return false, "A preset with this name already exists"
  end

  -- Save with new name first
  local ok, err = Presets.save(new_file_name, new_name, preset.config, preset.description)
  if not ok then
    return false, err
  end

  -- Delete old file
  local delete_ok = os.remove(old_filepath)
  if not delete_ok then
    vim.notify("SSNS Formatter: Could not delete old preset file", vim.log.levels.WARN)
  end

  -- Clear cache
  loaded_presets["user:" .. old_name] = nil

  return true
end

---Delete a user preset
---@param name string Preset file name
---@return boolean success
---@return string? error_message
function Presets.delete(name)
  local preset = Presets.load(name)
  if not preset then
    return false, "Preset not found: " .. name
  end

  if not preset.is_user then
    return false, "Cannot delete built-in preset"
  end

  local filepath = user_dir .. "/" .. name .. ".lua"
  local ok = os.remove(filepath)
  if not ok then
    return false, "Failed to delete preset file"
  end

  -- Clear cache
  loaded_presets["user:" .. name] = nil

  return true
end

---Generate a unique preset name
---@param base string Base name
---@param is_file_name? boolean If true, generates file name; otherwise display name
---@return string unique_name
function Presets.generate_unique_name(base, is_file_name)
  ensure_user_dir()

  local existing_files = get_preset_files(user_dir)
  local existing_set = {}
  for _, f in ipairs(existing_files) do
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

    -- Check against display names of existing presets
    local all_presets = Presets.list()
    local display_names = {}
    for _, p in ipairs(all_presets) do
      display_names[p.name] = true
    end

    while display_names[candidate] do
      counter = counter + 1
      candidate = base .. " " .. counter
    end
    return candidate
  end
end

---Get default preset name
---@return string name The default preset name (ssms)
function Presets.get_default()
  return "ssms"
end

---Apply a preset to current config
---@param name string Preset name
---@return boolean success
---@return string? error_message
function Presets.apply(name)
  local preset = Presets.load(name)
  if not preset then
    return false, "Preset not found: " .. name
  end

  local Config = require('nvim-ssns.config')
  local current_formatter = Config.get_formatter()

  -- Merge preset config with current (preset overrides)
  local merged = vim.tbl_deep_extend("force", current_formatter, preset.config)

  -- Update config
  Config.current.formatter = merged

  return true
end

---Clear preset cache
function Presets.clear_cache()
  loaded_presets = {}
end

---Check if a preset exists
---@param name string Preset name
---@return boolean exists
function Presets.exists(name)
  return Presets.load(name) ~= nil
end

---Check if a name is a built-in preset
---@param name string Preset name
---@return boolean is_builtin
function Presets.is_builtin(name)
  local preset = Presets.load(name)
  return preset ~= nil and not preset.is_user
end

return Presets
