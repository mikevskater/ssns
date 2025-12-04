---@class AdapterFactory
local AdapterFactory = {}

---Supported database types
---@type table<string, boolean>
local SUPPORTED_TYPES = {
  sqlserver = true,
  postgres = true,
  mysql = true,
  sqlite = true,
}

---Create an adapter instance for a specific database type
---@param db_type string The database type (sqlserver, mysql, postgres, sqlite)
---@param connection_config ConnectionData The connection configuration
---@return BaseAdapter? adapter The created adapter instance or nil if type unknown
---@return string? error_message Error message if adapter creation failed
function AdapterFactory.create_adapter_for_type(db_type, connection_config)
  if not db_type or db_type == "" then
    return nil, "Database type is empty"
  end

  if not SUPPORTED_TYPES[db_type] then
    return nil, string.format("Unsupported database type: %s", db_type)
  end

  -- Load the appropriate adapter module
  local adapter_module_name = string.format("ssns.adapters.%s", db_type)
  local ok, adapter_module = pcall(require, adapter_module_name)

  if not ok then
    return nil, string.format("Failed to load adapter for %s: %s", db_type, adapter_module)
  end

  -- Create and return the adapter instance with connection config
  local adapter = adapter_module.new(connection_config)
  return adapter, nil
end

---Get list of supported database types
---@return string[] db_types Array of supported database type identifiers
function AdapterFactory.get_supported_types()
  local types = {}

  for db_type, _ in pairs(SUPPORTED_TYPES) do
    table.insert(types, db_type)
  end

  table.sort(types)
  return types
end

---Check if a database type is supported
---@param db_type string
---@return boolean
function AdapterFactory.is_supported(db_type)
  return SUPPORTED_TYPES[db_type] == true
end

---Validate that an adapter module exists for a database type
---@param db_type string
---@return boolean exists
function AdapterFactory.adapter_exists(db_type)
  local adapter_module_name = string.format("ssns.adapters.%s", db_type)
  local ok, _ = pcall(require, adapter_module_name)
  return ok
end

---Register a custom database type
---Allows users to add support for custom database types
---@param db_type string The database type identifier
function AdapterFactory.register_type(db_type)
  SUPPORTED_TYPES[db_type] = true
end

return AdapterFactory
