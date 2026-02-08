---@class BulkInsert
---Handles batched data insertion for cross-server transfers
local BulkInsert = {}

local Connection = require("nvim-ssns.connection")

---Default batch size for INSERT statements
BulkInsert.DEFAULT_BATCH_SIZE = 1000

---Escape a value for SQL insertion
---@param value any
---@param db_type string Database type
---@return string
local function escape_value(value, db_type)
  if value == nil or value == vim.NIL then
    return "NULL"
  end

  local t = type(value)

  if t == "string" then
    -- Escape single quotes by doubling them
    local escaped = value:gsub("'", "''")
    return "'" .. escaped .. "'"
  elseif t == "number" then
    return tostring(value)
  elseif t == "boolean" then
    if db_type == "postgres" or db_type == "postgresql" then
      return value and "TRUE" or "FALSE"
    else
      return value and "1" or "0"
    end
  else
    -- Convert to string and escape
    local str = tostring(value)
    local escaped = str:gsub("'", "''")
    return "'" .. escaped .. "'"
  end
end

---Generate INSERT statement for a batch of rows
---@param table_name string Target table name
---@param columns InferredColumn[] Column definitions
---@param rows table[] Rows to insert
---@param db_type string Database type
---@return string sql INSERT statement
function BulkInsert.generate_insert(table_name, columns, rows, db_type)
  if #rows == 0 then
    return ""
  end

  -- Build column list
  local col_names = {}
  for _, col in ipairs(columns) do
    if db_type == "sqlserver" then
      table.insert(col_names, "[" .. col.name .. "]")
    elseif db_type == "postgres" or db_type == "postgresql" then
      table.insert(col_names, '"' .. col.name .. '"')
    elseif db_type == "mysql" then
      table.insert(col_names, "`" .. col.name .. "`")
    else
      table.insert(col_names, col.name)
    end
  end

  local col_list = table.concat(col_names, ", ")

  -- Build VALUES rows
  local value_rows = {}
  for _, row in ipairs(rows) do
    local values = {}
    for _, col in ipairs(columns) do
      local value = row[col.name]
      table.insert(values, escape_value(value, db_type))
    end
    table.insert(value_rows, "(" .. table.concat(values, ", ") .. ")")
  end

  return string.format("INSERT INTO %s (%s) VALUES\n%s", table_name, col_list, table.concat(value_rows, ",\n"))
end

---Execute bulk insert in batches
---@param connection_config table Connection configuration
---@param table_name string Target table name
---@param columns InferredColumn[] Column definitions
---@param rows table[] All rows to insert
---@param db_type string Database type
---@param batch_size number? Batch size (default 1000)
---@return number rows_inserted Total rows inserted
---@return string? error Error message if failed
function BulkInsert.execute(connection_config, table_name, columns, rows, db_type, batch_size)
  batch_size = batch_size or BulkInsert.DEFAULT_BATCH_SIZE

  if #rows == 0 then
    return 0, nil
  end

  local total_inserted = 0
  local num_batches = math.ceil(#rows / batch_size)

  for batch_num = 1, num_batches do
    local start_idx = (batch_num - 1) * batch_size + 1
    local end_idx = math.min(batch_num * batch_size, #rows)

    -- Extract batch
    local batch_rows = {}
    for i = start_idx, end_idx do
      table.insert(batch_rows, rows[i])
    end

    -- Generate and execute INSERT
    local insert_sql = BulkInsert.generate_insert(table_name, columns, batch_rows, db_type)

    local result = Connection.execute(connection_config, insert_sql, { use_cache = false })

    if not result.success then
      local err_msg = result.error and result.error.message or "Bulk insert failed"
      return total_inserted,
        string.format("Batch %d/%d failed: %s", batch_num, num_batches, err_msg)
    end

    total_inserted = total_inserted + #batch_rows
  end

  return total_inserted, nil
end

---Generate CREATE TABLE statement
---@param table_name string Table name
---@param columns InferredColumn[] Column definitions
---@param db_type string Database type
---@param is_temp boolean Whether to create a temp table
---@return string ddl CREATE TABLE statement
function BulkInsert.generate_create_table(table_name, columns, db_type, is_temp)
  local col_defs = {}

  for _, col in ipairs(columns) do
    local col_name
    if db_type == "sqlserver" then
      col_name = "[" .. col.name .. "]"
    elseif db_type == "postgres" or db_type == "postgresql" then
      col_name = '"' .. col.name .. '"'
    elseif db_type == "mysql" then
      col_name = "`" .. col.name .. "`"
    else
      col_name = col.name
    end

    local null_clause = col.nullable and "NULL" or "NOT NULL"
    table.insert(col_defs, string.format("  %s %s %s", col_name, col.sql_type, null_clause))
  end

  local col_list = table.concat(col_defs, ",\n")

  -- Database-specific CREATE TABLE syntax
  if db_type == "sqlserver" then
    -- SQL Server temp tables start with #
    return string.format("CREATE TABLE %s (\n%s\n)", table_name, col_list)
  elseif db_type == "postgres" or db_type == "postgresql" then
    local temp_keyword = is_temp and "TEMP " or ""
    return string.format("CREATE %sTABLE %s (\n%s\n)", temp_keyword, table_name, col_list)
  elseif db_type == "mysql" then
    local temp_keyword = is_temp and "TEMPORARY " or ""
    return string.format("CREATE %sTABLE %s (\n%s\n)", temp_keyword, table_name, col_list)
  else
    -- SQLite
    local temp_keyword = is_temp and "TEMP " or ""
    return string.format("CREATE %sTABLE %s (\n%s\n)", temp_keyword, table_name, col_list)
  end
end

---Generate DROP TABLE statement
---@param table_name string Table name
---@param db_type string Database type
---@return string ddl DROP TABLE statement
function BulkInsert.generate_drop_table(table_name, db_type)
  if db_type == "sqlserver" then
    -- SQL Server: Check if exists before dropping
    return string.format(
      "IF OBJECT_ID('tempdb..%s') IS NOT NULL DROP TABLE %s",
      table_name,
      table_name
    )
  elseif db_type == "postgres" or db_type == "postgresql" then
    return string.format("DROP TABLE IF EXISTS %s", table_name)
  elseif db_type == "mysql" then
    return string.format("DROP TEMPORARY TABLE IF EXISTS %s", table_name)
  else
    return string.format("DROP TABLE IF EXISTS %s", table_name)
  end
end

return BulkInsert
