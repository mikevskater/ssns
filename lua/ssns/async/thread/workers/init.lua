-- Workers Module
-- Loads and registers all worker scripts with the coordinator
-- Workers are pure Lua files that run in separate threads

local Workers = {}

---Get the directory path of this module
---@return string
local function get_workers_dir()
  local info = debug.getinfo(1, "S")
  local path = info.source:sub(2) -- Remove leading @
  -- Handle Windows paths
  path = path:gsub("\\", "/")
  -- Get directory
  return path:match("(.*/)")
end

---Read a worker file and return its contents
---@param filename string Worker filename (e.g., "search.lua")
---@return string? content File contents or nil if failed
---@return string? error Error message if failed
local function read_worker_file(filename)
  local dir = get_workers_dir()
  local filepath = dir .. filename

  -- Try to read file
  local ok, lines = pcall(vim.fn.readfile, filepath)
  if not ok or not lines then
    return nil, "Failed to read worker file: " .. filepath
  end

  return table.concat(lines, "\n"), nil
end

---Register all built-in workers with the coordinator
---@param coordinator table The coordinator module
function Workers.register_all(coordinator)
  local worker_files = {
    { name = "search", file = "search.lua" },
    { name = "sort", file = "sort.lua" },
    { name = "dedupe_sort", file = "dedupe_sort.lua" },
    { name = "fk_graph", file = "fk_graph.lua" },
    { name = "history_search", file = "history_search.lua" },
    { name = "sql_highlighting", file = "sql_highlighting.lua" },
  }

  for _, worker in ipairs(worker_files) do
    local code, err = read_worker_file(worker.file)
    if code then
      coordinator.register_worker(worker.name, code)
    else
      vim.notify(
        string.format("[SSNS Thread] Failed to load worker '%s': %s", worker.name, err or "unknown"),
        vim.log.levels.WARN
      )
    end
  end
end

---Get a list of available worker names
---@return string[]
function Workers.get_available()
  return { "search", "sort", "dedupe_sort", "fk_graph", "history_search", "sql_highlighting" }
end

return Workers
