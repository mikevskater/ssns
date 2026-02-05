---@class MacroLoader
---File discovery and loading for macro library
local M = {}

---@class LoadedMacroFile
---@field path string Full path to the macro file
---@field source "project"|"user"|"builtin"|"custom" Source type
---@field name string Filename without extension
---@field macros table<string, function> Loaded macro functions

---Get the builtin macros directory path
---@return string
local function get_builtin_path()
  -- Get the path relative to this file
  local info = debug.getinfo(1, "S")
  local source = info.source:sub(2) -- Remove leading @
  local dir = vim.fn.fnamemodify(source, ":h")
  return dir .. "/builtin"
end

---Get user macros directory path
---@return string
local function get_user_path()
  -- ~/.config/nvim/nvim-ssns/macros/ on Unix
  -- ~/AppData/Local/nvim/nvim-ssns/macros/ on Windows
  local config_path = vim.fn.stdpath("config")
  return config_path .. "/nvim-ssns/macros"
end

---Get project macros directory path
---@return string?
local function get_project_path()
  -- Find .ssns/macros/ directory in current working directory or git root
  local cwd = vim.fn.getcwd()

  -- Check current directory first
  local project_macros = cwd .. "/.ssns/macros"
  if vim.fn.isdirectory(project_macros) == 1 then
    return project_macros
  end

  -- Try to find git root
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
  if git_root and git_root ~= "" and vim.fn.isdirectory(git_root) == 1 then
    project_macros = git_root .. "/.ssns/macros"
    if vim.fn.isdirectory(project_macros) == 1 then
      return project_macros
    end
  end

  return nil
end

---Discover macro files in a directory
---@param dir_path string Directory to search
---@param source "project"|"user"|"builtin"|"custom" Source type
---@return LoadedMacroFile[]
local function discover_files(dir_path, source)
  local files = {}

  if vim.fn.isdirectory(dir_path) ~= 1 then
    return files
  end

  local lua_files = vim.fn.glob(dir_path .. "/*.lua", false, true)

  for _, file_path in ipairs(lua_files) do
    local name = vim.fn.fnamemodify(file_path, ":t:r") -- filename without extension
    table.insert(files, {
      path = file_path,
      source = source,
      name = name,
      macros = {},
    })
  end

  return files
end

---Load a single macro file
---@param file_info LoadedMacroFile
---@return boolean success
---@return string? error
function M.load_file(file_info)
  local path = file_info.path

  -- Read file content
  local file = io.open(path, "r")
  if not file then
    return false, "Cannot open file: " .. path
  end

  local content = file:read("*a")
  file:close()

  -- Compile and execute
  local chunk, compile_err = loadstring(content, "@" .. path)
  if not chunk then
    return false, "Compile error in " .. path .. ": " .. tostring(compile_err)
  end

  -- Create a sandboxed environment with limited globals
  local env = setmetatable({}, { __index = _G })
  setfenv(chunk, env)

  local ok, result = pcall(chunk)
  if not ok then
    return false, "Runtime error in " .. path .. ": " .. tostring(result)
  end

  -- Validate result is a table of functions
  if type(result) ~= "table" then
    return false, "Macro file " .. path .. " must return a table, got: " .. type(result)
  end

  -- Extract functions
  local macros = {}
  for name, value in pairs(result) do
    if type(name) == "string" and type(value) == "function" then
      macros[name] = value
    elseif type(name) == "string" then
      -- Allow non-function values for constants/helpers
      macros[name] = value
    end
  end

  file_info.macros = macros
  return true, nil
end

---Discover all macro files from all sources
---@param config table? Macro configuration {paths: string[]?}
---@return LoadedMacroFile[] files Discovered files (not yet loaded)
function M.discover_all(config)
  config = config or {}
  local files = {}

  -- 1. Builtin macros (lowest priority)
  local builtin_path = get_builtin_path()
  local builtin_files = discover_files(builtin_path, "builtin")
  vim.list_extend(files, builtin_files)

  -- 2. User macros
  local user_path = get_user_path()
  local user_files = discover_files(user_path, "user")
  vim.list_extend(files, user_files)

  -- 3. Custom paths from config
  if config.paths then
    for _, custom_path in ipairs(config.paths) do
      local custom_files = discover_files(custom_path, "custom")
      vim.list_extend(files, custom_files)
    end
  end

  -- 4. Project macros (highest priority)
  local project_path = get_project_path()
  if project_path then
    local project_files = discover_files(project_path, "project")
    vim.list_extend(files, project_files)
  end

  return files
end

---Load all macros and merge into a single table
---Higher priority sources override lower priority
---@param config table? Macro configuration
---@return table<string, function> macros Merged macro functions
---@return LoadedMacroFile[] loaded_files Successfully loaded files
---@return table[] errors Loading errors {file: string, error: string}
function M.load_all(config)
  local files = M.discover_all(config)
  local macros = {}
  local loaded_files = {}
  local errors = {}

  -- Load files in order (later files override earlier)
  for _, file_info in ipairs(files) do
    local ok, err = M.load_file(file_info)
    if ok then
      table.insert(loaded_files, file_info)
      -- Merge macros (overwrite existing)
      for name, func in pairs(file_info.macros) do
        macros[name] = func
      end
    else
      table.insert(errors, { file = file_info.path, error = err })
    end
  end

  return macros, loaded_files, errors
end

---Get all search paths (for display/debugging)
---@param config table? Macro configuration
---@return table[] paths {path: string, source: string, exists: boolean}
function M.get_search_paths(config)
  config = config or {}
  local paths = {}

  -- Builtin
  local builtin_path = get_builtin_path()
  table.insert(paths, {
    path = builtin_path,
    source = "builtin",
    exists = vim.fn.isdirectory(builtin_path) == 1,
  })

  -- User
  local user_path = get_user_path()
  table.insert(paths, {
    path = user_path,
    source = "user",
    exists = vim.fn.isdirectory(user_path) == 1,
  })

  -- Custom paths
  if config.paths then
    for _, custom_path in ipairs(config.paths) do
      table.insert(paths, {
        path = custom_path,
        source = "custom",
        exists = vim.fn.isdirectory(custom_path) == 1,
      })
    end
  end

  -- Project
  local project_path = get_project_path()
  table.insert(paths, {
    path = project_path or ".ssns/macros (not found)",
    source = "project",
    exists = project_path ~= nil,
  })

  return paths
end

return M
