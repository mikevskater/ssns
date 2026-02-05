---@class EtlMacros
---Global macro library system for ETL scripts
---Provides caching, loading orchestration, and reload API
local M = {}

local Loader = require("nvim-ssns.etl.macros.loader")

---@class MacroCache
---@field macros table<string, function> Merged macro functions
---@field loaded_files LoadedMacroFile[] Successfully loaded files
---@field errors table[] Loading errors
---@field last_load number Timestamp of last load
---@field initialized boolean Whether initial load has occurred

---@type MacroCache
local cache = {
  macros = {},
  loaded_files = {},
  errors = {},
  last_load = 0,
  initialized = false,
}

---@type number? Auto-reload autocmd ID
local reload_autocmd_id = nil

---Get macro configuration from main config
---@return table config
local function get_config()
  local ok, Config = pcall(require, "ssns.config")
  if not ok then
    return { enabled = true, paths = {}, reload_on_save = true }
  end

  local cfg = Config.get()
  if cfg and cfg.etl and cfg.etl.macros then
    return cfg.etl.macros
  end

  return { enabled = true, paths = {}, reload_on_save = true }
end

---Initialize or reload macros
---@param force boolean? Force reload even if already initialized
---@return boolean success
function M.reload(force)
  local config = get_config()

  if not config.enabled then
    cache.macros = {}
    cache.loaded_files = {}
    cache.errors = {}
    cache.initialized = true
    return true
  end

  -- Load all macros
  local macros, loaded_files, errors = Loader.load_all(config)

  -- Update cache
  cache.macros = macros
  cache.loaded_files = loaded_files
  cache.errors = errors
  cache.last_load = os.time()
  cache.initialized = true

  -- Log errors if any
  if #errors > 0 then
    for _, err in ipairs(errors) do
      vim.schedule(function()
        vim.notify(string.format("Macro load error: %s\n%s", err.file, err.error), vim.log.levels.WARN)
      end)
    end
    return false
  end

  return true
end

---Get all loaded macros
---@return table<string, function> macros
function M.get_all()
  if not cache.initialized then
    M.reload()
  end
  return cache.macros
end

---Get a specific macro by name
---@param name string Macro name
---@return function? macro
function M.get(name)
  if not cache.initialized then
    M.reload()
  end
  return cache.macros[name]
end

---Get cache statistics
---@return table stats
function M.get_stats()
  return {
    macro_count = vim.tbl_count(cache.macros),
    file_count = #cache.loaded_files,
    error_count = #cache.errors,
    last_load = cache.last_load,
    initialized = cache.initialized,
  }
end

---Get list of loaded macro names
---@return string[] names
function M.list_macros()
  if not cache.initialized then
    M.reload()
  end

  local names = vim.tbl_keys(cache.macros)
  table.sort(names)
  return names
end

---Get detailed info about loaded macros
---@return table[] info {name: string, source: string, file: string}
function M.get_detailed_info()
  if not cache.initialized then
    M.reload()
  end

  local info = {}

  -- Build reverse lookup: macro name -> file info
  for _, file_info in ipairs(cache.loaded_files) do
    for name, _ in pairs(file_info.macros) do
      table.insert(info, {
        name = name,
        source = file_info.source,
        file = file_info.path,
      })
    end
  end

  -- Sort by name
  table.sort(info, function(a, b)
    return a.name < b.name
  end)

  return info
end

---Get loading errors
---@return table[] errors
function M.get_errors()
  return cache.errors
end

---Get search paths info
---@return table[] paths
function M.get_search_paths()
  local config = get_config()
  return Loader.get_search_paths(config)
end

---Check if a macro exists
---@param name string Macro name
---@return boolean exists
function M.has(name)
  if not cache.initialized then
    M.reload()
  end
  return cache.macros[name] ~= nil
end

---Setup auto-reload autocmd for macro files
function M.setup_auto_reload()
  local config = get_config()

  -- Clear existing autocmd
  if reload_autocmd_id then
    pcall(vim.api.nvim_del_autocmd, reload_autocmd_id)
    reload_autocmd_id = nil
  end

  if not config.enabled or not config.reload_on_save then
    return
  end

  -- Create autocmd group
  local group = vim.api.nvim_create_augroup("SSNSMacrosAutoReload", { clear = true })

  -- Watch for saves in macro directories
  reload_autocmd_id = vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = {
      "*/.nvim-ssns/macros/*.lua",
      "*/nvim-ssns/macros/*.lua",
    },
    callback = function(args)
      vim.schedule(function()
        local success = M.reload(true)
        if success then
          local stats = M.get_stats()
          vim.notify(string.format("Macros reloaded: %d macros from %d files",
            stats.macro_count, stats.file_count), vim.log.levels.INFO)
        end
      end)
    end,
    desc = "Auto-reload SSNS macros on file save",
  })
end

---Initialize the macro system
---Called during plugin setup
function M.setup()
  local config = get_config()

  if config.enabled then
    -- Initial load
    M.reload()

    -- Setup auto-reload
    M.setup_auto_reload()
  end
end

---Cleanup (for testing/reloading plugin)
function M.cleanup()
  if reload_autocmd_id then
    pcall(vim.api.nvim_del_autocmd, reload_autocmd_id)
    reload_autocmd_id = nil
  end

  cache = {
    macros = {},
    loaded_files = {},
    errors = {},
    last_load = 0,
    initialized = false,
  }
end

return M
