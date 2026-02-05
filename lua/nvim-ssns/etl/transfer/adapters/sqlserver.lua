---@class SqlServerTransferAdapter
---SQL Server specific transfer operations
local SqlServerAdapter = {}

local TypeMapper = require("nvim-ssns.etl.transfer.type_mapper")
local BulkInsert = require("nvim-ssns.etl.transfer.bulk_insert")
local Connection = require("nvim-ssns.connection")

---Database type identifier
SqlServerAdapter.db_type = "sqlserver"

---Generate temp table name
---@param block_name string Source block name
---@return string temp_table_name
function SqlServerAdapter.get_temp_table_name(block_name)
  -- SQL Server temp tables start with #
  -- Use a sanitized block name
  local safe_name = block_name:gsub("[^%w_]", "_")
  return "#ssns_input_" .. safe_name
end

---Create temp table on target server
---@param connection_config table Connection configuration
---@param table_name string Temp table name
---@param columns InferredColumn[] Column definitions
---@return boolean success
---@return string? error
function SqlServerAdapter.create_temp_table(connection_config, table_name, columns)
  -- Apply SQL Server type mapping
  columns = TypeMapper.apply_mapping(columns, "sqlserver")

  -- Generate CREATE TABLE
  local ddl = BulkInsert.generate_create_table(table_name, columns, "sqlserver", true)

  -- Execute
  local result = Connection.execute(connection_config, ddl, { use_cache = false })

  if not result.success then
    return false, result.error and result.error.message or "Failed to create temp table"
  end

  return true, nil
end

---Drop temp table
---@param connection_config table Connection configuration
---@param table_name string Temp table name
---@return boolean success
---@return string? error
function SqlServerAdapter.drop_temp_table(connection_config, table_name)
  local ddl = BulkInsert.generate_drop_table(table_name, "sqlserver")

  local result = Connection.execute(connection_config, ddl, { use_cache = false })

  if not result.success then
    return false, result.error and result.error.message or "Failed to drop temp table"
  end

  return true, nil
end

---Bulk insert data into temp table
---@param connection_config table Connection configuration
---@param table_name string Temp table name
---@param columns InferredColumn[] Column definitions
---@param rows table[] Data rows
---@param batch_size number? Batch size
---@return number rows_inserted
---@return string? error
function SqlServerAdapter.bulk_insert(connection_config, table_name, columns, rows, batch_size)
  return BulkInsert.execute(connection_config, table_name, columns, rows, "sqlserver", batch_size)
end

---Get placeholder for @input in SQL
---Returns the temp table name to substitute
---@param table_name string Temp table name
---@return string placeholder
function SqlServerAdapter.get_input_placeholder(table_name)
  return table_name
end

return SqlServerAdapter
