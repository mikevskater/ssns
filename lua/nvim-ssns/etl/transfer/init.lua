---@class Transfer
---Coordinates cross-server data transfer for ETL scripts
local Transfer = {}

local TypeMapper = require("nvim-ssns.etl.transfer.type_mapper")
local BulkInsert = require("nvim-ssns.etl.transfer.bulk_insert")

-- Lazy-load adapters
local adapters = {}
local function get_adapter(db_type)
  if not adapters[db_type] then
    local adapter_map = {
      sqlserver = "ssns.etl.transfer.adapters.sqlserver",
      postgres = "ssns.etl.transfer.adapters.postgres",
      postgresql = "ssns.etl.transfer.adapters.postgres",
      mysql = "ssns.etl.transfer.adapters.mysql",
      sqlite = "ssns.etl.transfer.adapters.sqlite",
    }

    local module_name = adapter_map[db_type]
    if not module_name then
      -- Default to SQL Server
      module_name = "ssns.etl.transfer.adapters.sqlserver"
    end

    adapters[db_type] = require(module_name)
  end

  return adapters[db_type]
end

---@class TransferResult
---@field success boolean
---@field temp_table_name string? Name of created temp table
---@field rows_transferred number Rows inserted
---@field error string? Error message if failed

---@class TransferOptions
---@field batch_size number? Batch size for bulk insert (default 1000)
---@field source_server string? Source server name (for logging)
---@field target_server string? Target server name (for logging)

---Prepare input data on target server by creating a temp table
---@param context EtlContext Execution context with results
---@param source_block_name string Name of the source block
---@param target_connection_config table Target server connection config
---@param target_db_type string Target database type
---@param opts TransferOptions? Options
---@return TransferResult
function Transfer.prepare_input(context, source_block_name, target_connection_config, target_db_type, opts)
  opts = opts or {}

  -- Get source result
  local source_result = context:get_result(source_block_name)
  if not source_result then
    return {
      success = false,
      temp_table_name = nil,
      rows_transferred = 0,
      error = string.format("Source block '%s' has no result", source_block_name),
    }
  end

  local rows = source_result.rows
  if not rows or #rows == 0 then
    -- Empty result - create empty temp table anyway (for schema)
    rows = {}
  end

  -- Get adapter for target database
  local adapter = get_adapter(target_db_type)

  -- Generate temp table name
  local temp_table_name = adapter.get_temp_table_name(source_block_name)

  -- Infer column types from data
  local columns = TypeMapper.infer_columns(rows, source_result.columns)
  columns = TypeMapper.apply_mapping(columns, target_db_type)

  -- Create temp table
  local success, err = adapter.create_temp_table(target_connection_config, temp_table_name, columns)
  if not success then
    return {
      success = false,
      temp_table_name = nil,
      rows_transferred = 0,
      error = string.format("Failed to create temp table: %s", err),
    }
  end

  -- Register temp table in context for cleanup
  context:register_temp_table({
    name = temp_table_name,
    server = opts.target_server or "unknown",
    source_block = source_block_name,
    columns = columns,
    row_count = #rows,
    connection_config = target_connection_config,
    db_type = target_db_type,
  })

  -- Bulk insert data (if any)
  if #rows > 0 then
    local rows_inserted, insert_err = adapter.bulk_insert(
      target_connection_config,
      temp_table_name,
      columns,
      rows,
      opts.batch_size
    )

    if insert_err then
      -- Try to clean up the temp table
      pcall(function()
        adapter.drop_temp_table(target_connection_config, temp_table_name)
      end)

      return {
        success = false,
        temp_table_name = nil,
        rows_transferred = rows_inserted,
        error = string.format("Bulk insert failed: %s", insert_err),
      }
    end

    return {
      success = true,
      temp_table_name = temp_table_name,
      rows_transferred = rows_inserted,
      error = nil,
    }
  end

  return {
    success = true,
    temp_table_name = temp_table_name,
    rows_transferred = 0,
    error = nil,
  }
end

---Clean up all temp tables created during execution
---@param context EtlContext Execution context
---@return number cleaned Number of tables dropped
---@return string[] errors Errors encountered during cleanup
function Transfer.cleanup(context)
  local cleaned = 0
  local errors = {}

  for _, temp_info in ipairs(context:get_temp_tables()) do
    local adapter = get_adapter(temp_info.db_type)

    local success, err = adapter.drop_temp_table(temp_info.connection_config, temp_info.name)

    if success then
      cleaned = cleaned + 1
    else
      table.insert(errors, string.format("Failed to drop %s: %s", temp_info.name, err))
    end
  end

  return cleaned, errors
end

---Check if transfer is needed (different servers)
---@param source_server string Source server name
---@param target_server string Target server name
---@return boolean needs_transfer
function Transfer.needs_transfer(source_server, target_server)
  return source_server ~= target_server
end

---Get the input placeholder to substitute in SQL
---@param temp_table_name string Temp table name
---@param db_type string Database type
---@return string placeholder
function Transfer.get_input_placeholder(temp_table_name, db_type)
  local adapter = get_adapter(db_type)
  return adapter.get_input_placeholder(temp_table_name)
end

-- Re-export utilities
Transfer.TypeMapper = TypeMapper
Transfer.BulkInsert = BulkInsert

return Transfer
