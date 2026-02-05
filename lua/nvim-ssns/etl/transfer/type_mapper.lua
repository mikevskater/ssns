---@class TypeMapper
---Infers SQL column types from Lua/JavaScript data
local TypeMapper = {}

---@class InferredColumn
---@field name string Column name
---@field lua_type string Lua type (string, number, boolean, nil)
---@field sql_type string Database-specific SQL type
---@field max_length number? Maximum string length observed
---@field has_decimal boolean? Whether numbers have decimals
---@field nullable boolean Whether NULL values were observed
---@field index number Column index (1-based)

---Analyze a value and return its type info
---@param value any
---@return string lua_type
---@return number? max_length For strings
---@return boolean? has_decimal For numbers
local function analyze_value(value)
  if value == nil then
    return "nil", nil, nil
  end

  local t = type(value)

  if t == "string" then
    return "string", #value, nil
  elseif t == "number" then
    -- Check if it has a decimal part
    local has_decimal = (value % 1) ~= 0
    return "number", nil, has_decimal
  elseif t == "boolean" then
    return "boolean", nil, nil
  else
    -- Tables, functions, etc. - treat as string
    return "string", #tostring(value), nil
  end
end

---Infer column types from result data
---@param rows table[] Array of row objects
---@param existing_columns table<string, ColumnMeta>? Existing column metadata (if available)
---@return InferredColumn[] columns
function TypeMapper.infer_columns(rows, existing_columns)
  if #rows == 0 then
    -- No data - use existing columns or return empty
    if existing_columns then
      local columns = {}
      for name, meta in pairs(existing_columns) do
        table.insert(columns, {
          name = name,
          lua_type = "nil",
          sql_type = meta.type or "NVARCHAR(255)",
          max_length = 255,
          has_decimal = false,
          nullable = true,
          index = meta.index or #columns + 1,
        })
      end
      table.sort(columns, function(a, b)
        return a.index < b.index
      end)
      return columns
    end
    return {}
  end

  -- Collect all column names from all rows
  local column_info = {} ---@type table<string, {types: table<string, number>, max_len: number, has_decimal: boolean, has_null: boolean, index: number}>
  local column_order = {}
  local seen_columns = {}

  for _, row in ipairs(rows) do
    for col_name, value in pairs(row) do
      if not seen_columns[col_name] then
        seen_columns[col_name] = true
        table.insert(column_order, col_name)
        column_info[col_name] = {
          types = {},
          max_len = 0,
          has_decimal = false,
          has_null = false,
          index = #column_order,
        }
      end

      local info = column_info[col_name]
      local lua_type, max_len, has_decimal = analyze_value(value)

      info.types[lua_type] = (info.types[lua_type] or 0) + 1

      if lua_type == "nil" then
        info.has_null = true
      end

      if max_len and max_len > info.max_len then
        info.max_len = max_len
      end

      if has_decimal then
        info.has_decimal = true
      end
    end
  end

  -- Check for columns that are missing in some rows (nullable)
  for col_name, info in pairs(column_info) do
    local total_occurrences = 0
    for _, count in pairs(info.types) do
      total_occurrences = total_occurrences + count
    end
    if total_occurrences < #rows then
      info.has_null = true
    end
  end

  -- Build result
  local result = {}
  for _, col_name in ipairs(column_order) do
    local info = column_info[col_name]

    -- Determine dominant type (excluding nil)
    local dominant_type = "nil"
    local max_count = 0
    for t, count in pairs(info.types) do
      if t ~= "nil" and count > max_count then
        dominant_type = t
        max_count = count
      end
    end

    -- If all values were nil, default to string
    if dominant_type == "nil" then
      dominant_type = "string"
      info.max_len = 255
    end

    -- Use existing column type if available
    local sql_type = nil
    if existing_columns and existing_columns[col_name] and existing_columns[col_name].type then
      sql_type = existing_columns[col_name].type
    end

    table.insert(result, {
      name = col_name,
      lua_type = dominant_type,
      sql_type = sql_type, -- Will be filled by database adapter
      max_length = info.max_len,
      has_decimal = info.has_decimal,
      nullable = info.has_null,
      index = info.index,
    })
  end

  return result
end

---@class DbTypeMapper
---@field map_type fun(col: InferredColumn): string

---SQL Server type mapper
---@type DbTypeMapper
TypeMapper.sqlserver = {
  map_type = function(col)
    if col.sql_type then
      return col.sql_type
    end

    if col.lua_type == "string" then
      local len = col.max_length or 255
      if len == 0 then
        len = 255
      end
      if len > 4000 then
        return "NVARCHAR(MAX)"
      end
      -- Round up to reasonable sizes
      if len <= 50 then
        return "NVARCHAR(50)"
      elseif len <= 255 then
        return "NVARCHAR(255)"
      elseif len <= 1000 then
        return "NVARCHAR(1000)"
      else
        return "NVARCHAR(4000)"
      end
    elseif col.lua_type == "number" then
      if col.has_decimal then
        return "DECIMAL(18,6)"
      else
        return "BIGINT"
      end
    elseif col.lua_type == "boolean" then
      return "BIT"
    else
      return "NVARCHAR(255)"
    end
  end,
}

---PostgreSQL type mapper
---@type DbTypeMapper
TypeMapper.postgres = {
  map_type = function(col)
    if col.sql_type then
      return col.sql_type
    end

    if col.lua_type == "string" then
      local len = col.max_length or 255
      if len == 0 then
        len = 255
      end
      if len > 10000 then
        return "TEXT"
      end
      return string.format("VARCHAR(%d)", math.max(len * 2, 255)) -- Give some buffer
    elseif col.lua_type == "number" then
      if col.has_decimal then
        return "NUMERIC(18,6)"
      else
        return "BIGINT"
      end
    elseif col.lua_type == "boolean" then
      return "BOOLEAN"
    else
      return "VARCHAR(255)"
    end
  end,
}

---MySQL type mapper
---@type DbTypeMapper
TypeMapper.mysql = {
  map_type = function(col)
    if col.sql_type then
      return col.sql_type
    end

    if col.lua_type == "string" then
      local len = col.max_length or 255
      if len == 0 then
        len = 255
      end
      if len > 16000 then
        return "TEXT"
      end
      return string.format("VARCHAR(%d)", math.max(len * 2, 255))
    elseif col.lua_type == "number" then
      if col.has_decimal then
        return "DECIMAL(18,6)"
      else
        return "BIGINT"
      end
    elseif col.lua_type == "boolean" then
      return "TINYINT(1)"
    else
      return "VARCHAR(255)"
    end
  end,
}

---SQLite type mapper
---@type DbTypeMapper
TypeMapper.sqlite = {
  map_type = function(col)
    -- SQLite has dynamic typing, but we'll use affinity hints
    if col.lua_type == "string" then
      return "TEXT"
    elseif col.lua_type == "number" then
      if col.has_decimal then
        return "REAL"
      else
        return "INTEGER"
      end
    elseif col.lua_type == "boolean" then
      return "INTEGER"
    else
      return "TEXT"
    end
  end,
}

---Get type mapper for database type
---@param db_type string Database type (sqlserver, postgres, mysql, sqlite)
---@return DbTypeMapper
function TypeMapper.get_mapper(db_type)
  local mappers = {
    sqlserver = TypeMapper.sqlserver,
    postgres = TypeMapper.postgres,
    postgresql = TypeMapper.postgres,
    mysql = TypeMapper.mysql,
    sqlite = TypeMapper.sqlite,
  }

  return mappers[db_type] or TypeMapper.sqlserver
end

---Apply type mapping to columns
---@param columns InferredColumn[]
---@param db_type string Database type
---@return InferredColumn[] columns with sql_type filled
function TypeMapper.apply_mapping(columns, db_type)
  local mapper = TypeMapper.get_mapper(db_type)

  for _, col in ipairs(columns) do
    if not col.sql_type then
      col.sql_type = mapper.map_type(col)
    end
  end

  return columns
end

return TypeMapper
