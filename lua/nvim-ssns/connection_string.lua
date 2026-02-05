---@class ConnectionString
---ODBC driver detection utilities for SQL Server connections
local ConnectionString = {}

---Cached ODBC driver (so we don't query every time)
---@type string?
local cached_odbc_driver = nil

---List of SQL Server ODBC drivers in preferred order
---Newer drivers first as they typically have better performance and features
local PREFERRED_ODBC_DRIVERS = {
  "ODBC Driver 18 for SQL Server",
  "ODBC Driver 17 for SQL Server",
  "ODBC Driver 13 for SQL Server",
  "ODBC Driver 13.1 for SQL Server",
  "ODBC Driver 11 for SQL Server",
  "SQL Server Native Client 11.0",
  "SQL Server Native Client 10.0",
  "SQL Server",
}

---Detect the best available ODBC driver for SQL Server on Windows
---Uses PowerShell to query the system for installed drivers
---@return string driver The name of the best available ODBC driver
function ConnectionString.get_best_odbc_driver()
  -- Return cached value if available
  if cached_odbc_driver then
    return cached_odbc_driver
  end

  -- Only works on Windows
  if vim.fn.has("win32") ~= 1 and vim.fn.has("win64") ~= 1 then
    -- On non-Windows, return a sensible default
    cached_odbc_driver = "ODBC Driver 18 for SQL Server"
    return cached_odbc_driver
  end

  -- Query available drivers using PowerShell
  local powershell_cmd = [[powershell -NoProfile -Command "Get-OdbcDriver | Where-Object {$_.Name -like '*SQL Server*'} | Select-Object -ExpandProperty Name"]]

  local handle = io.popen(powershell_cmd)
  if not handle then
    -- Fallback to default if PowerShell fails
    cached_odbc_driver = "ODBC Driver 17 for SQL Server"
    return cached_odbc_driver
  end

  local available_drivers = {}
  for line in handle:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")  -- Trim whitespace
    if trimmed and trimmed ~= "" then
      table.insert(available_drivers, trimmed)
    end
  end
  handle:close()

  -- Find the best match from preferred list
  for _, preferred in ipairs(PREFERRED_ODBC_DRIVERS) do
    for _, available in ipairs(available_drivers) do
      if available == preferred then
        cached_odbc_driver = preferred
        return cached_odbc_driver
      end
    end
  end

  -- If no preferred driver found, use the first available one
  if #available_drivers > 0 then
    cached_odbc_driver = available_drivers[1]
    return cached_odbc_driver
  end

  -- No drivers found, use default fallback
  cached_odbc_driver = "ODBC Driver 17 for SQL Server"
  return cached_odbc_driver
end

---Clear the cached ODBC driver (useful for testing)
function ConnectionString.clear_cache()
  cached_odbc_driver = nil
end

---Check if a specific ODBC driver is available
---@param driver_name string The driver name to check
---@return boolean available True if the driver is installed
function ConnectionString.is_driver_available(driver_name)
  if vim.fn.has("win32") ~= 1 and vim.fn.has("win64") ~= 1 then
    return false  -- Can't check on non-Windows
  end

  local cmd = string.format(
    [[powershell -NoProfile -Command "Get-OdbcDriver | Where-Object {$_.Name -eq '%s'} | Measure-Object | Select-Object -ExpandProperty Count"]],
    driver_name
  )

  local handle = io.popen(cmd)
  if not handle then
    return false
  end

  local result = handle:read("*a")
  handle:close()

  local count = tonumber(vim.trim(result or "0"))
  return count ~= nil and count > 0
end

---Get a list of all installed SQL Server ODBC drivers
---@return string[] drivers Array of installed driver names
function ConnectionString.get_installed_drivers()
  local drivers = {}

  if vim.fn.has("win32") ~= 1 and vim.fn.has("win64") ~= 1 then
    return drivers  -- Return empty on non-Windows
  end

  local powershell_cmd = [[powershell -NoProfile -Command "Get-OdbcDriver | Where-Object {$_.Name -like '*SQL Server*'} | Select-Object -ExpandProperty Name"]]

  local handle = io.popen(powershell_cmd)
  if not handle then
    return drivers
  end

  for line in handle:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed and trimmed ~= "" then
      table.insert(drivers, trimmed)
    end
  end
  handle:close()

  return drivers
end

return ConnectionString
