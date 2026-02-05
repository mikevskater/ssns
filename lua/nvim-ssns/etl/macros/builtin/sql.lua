---Built-in SQL helper macros for ETL scripts
---@module ssns.etl.macros.builtin.sql

return {
  ---Quote a SQL identifier (table, column name) with brackets
  ---@param identifier string Identifier to quote
  ---@return string quoted
  quote_ident = function(identifier)
    if identifier == nil then
      return "NULL"
    end
    -- Remove existing brackets and re-add
    local clean = tostring(identifier):gsub("^%[", ""):gsub("%]$", "")
    return "[" .. clean:gsub("%]", "]]") .. "]"
  end,

  ---Quote a string value for SQL (with single quotes, escape internal quotes)
  ---@param value string|nil Value to quote
  ---@return string quoted
  quote_string = function(value)
    if value == nil then
      return "NULL"
    end
    return "'" .. tostring(value):gsub("'", "''") .. "'"
  end,

  ---Quote a value based on its type (auto-detect)
  ---@param value any Value to quote
  ---@return string quoted
  quote_value = function(value)
    if value == nil then
      return "NULL"
    elseif type(value) == "number" then
      return tostring(value)
    elseif type(value) == "boolean" then
      return value and "1" or "0"
    else
      return "'" .. tostring(value):gsub("'", "''") .. "'"
    end
  end,

  ---Build a WHERE clause from conditions table
  ---@param conditions table<string, any> Column-value pairs
  ---@param operator string? Logical operator ("AND" or "OR", default: "AND")
  ---@return string where_clause Without "WHERE" keyword
  build_where = function(conditions, operator)
    operator = operator or "AND"
    local parts = {}

    for column, value in pairs(conditions) do
      local condition
      if value == nil then
        condition = "[" .. column .. "] IS NULL"
      elseif type(value) == "table" then
        -- IN clause
        local values = {}
        for _, v in ipairs(value) do
          if v == nil then
            table.insert(values, "NULL")
          elseif type(v) == "number" then
            table.insert(values, tostring(v))
          else
            table.insert(values, "'" .. tostring(v):gsub("'", "''") .. "'")
          end
        end
        condition = "[" .. column .. "] IN (" .. table.concat(values, ", ") .. ")"
      elseif type(value) == "number" then
        condition = "[" .. column .. "] = " .. tostring(value)
      elseif type(value) == "boolean" then
        condition = "[" .. column .. "] = " .. (value and "1" or "0")
      else
        condition = "[" .. column .. "] = '" .. tostring(value):gsub("'", "''") .. "'"
      end
      table.insert(parts, condition)
    end

    return table.concat(parts, " " .. operator .. " ")
  end,

  ---Build a UNION ALL statement from multiple tables
  ---@param tables string[] Array of table names
  ---@param columns string Column list (e.g., "id, name, amount")
  ---@param where string? Optional WHERE clause (without WHERE keyword)
  ---@return string union_sql
  union_all = function(tables, columns, where)
    local parts = {}
    local where_clause = where and (" WHERE " .. where) or ""

    for _, tbl in ipairs(tables) do
      table.insert(parts, "SELECT " .. columns .. " FROM " .. tbl .. where_clause)
    end

    return table.concat(parts, "\nUNION ALL\n")
  end,

  ---Build a UNION statement (distinct) from multiple tables
  ---@param tables string[] Array of table names
  ---@param columns string Column list
  ---@param where string? Optional WHERE clause
  ---@return string union_sql
  union = function(tables, columns, where)
    local parts = {}
    local where_clause = where and (" WHERE " .. where) or ""

    for _, tbl in ipairs(tables) do
      table.insert(parts, "SELECT " .. columns .. " FROM " .. tbl .. where_clause)
    end

    return table.concat(parts, "\nUNION\n")
  end,

  ---Build an INSERT statement with VALUES
  ---@param table_name string Target table
  ---@param columns string[] Column names
  ---@param rows table[] Array of row data (each row is a table)
  ---@return string insert_sql
  build_insert = function(table_name, columns, rows)
    if #rows == 0 then
      return ""
    end

    local col_list = "[" .. table.concat(columns, "], [") .. "]"
    local value_rows = {}

    for _, row in ipairs(rows) do
      local values = {}
      for _, col in ipairs(columns) do
        local val = row[col]
        if val == nil then
          table.insert(values, "NULL")
        elseif type(val) == "number" then
          table.insert(values, tostring(val))
        elseif type(val) == "boolean" then
          table.insert(values, val and "1" or "0")
        else
          table.insert(values, "'" .. tostring(val):gsub("'", "''") .. "'")
        end
      end
      table.insert(value_rows, "(" .. table.concat(values, ", ") .. ")")
    end

    return "INSERT INTO " .. table_name .. " (" .. col_list .. ")\nVALUES " ..
      table.concat(value_rows, ",\n       ")
  end,

  ---Build an UPDATE statement
  ---@param table_name string Target table
  ---@param set_values table<string, any> Column-value pairs to set
  ---@param where_conditions table<string, any> WHERE conditions
  ---@return string update_sql
  build_update = function(table_name, set_values, where_conditions)
    local set_parts = {}

    for column, value in pairs(set_values) do
      local val_str
      if value == nil then
        val_str = "NULL"
      elseif type(value) == "number" then
        val_str = tostring(value)
      elseif type(value) == "boolean" then
        val_str = value and "1" or "0"
      else
        val_str = "'" .. tostring(value):gsub("'", "''") .. "'"
      end
      table.insert(set_parts, "[" .. column .. "] = " .. val_str)
    end

    local sql = "UPDATE " .. table_name .. "\nSET " .. table.concat(set_parts, ", ")

    if where_conditions and next(where_conditions) then
      -- Use the build_where function
      local conditions = {}
      for column, value in pairs(where_conditions) do
        local condition
        if value == nil then
          condition = "[" .. column .. "] IS NULL"
        elseif type(value) == "number" then
          condition = "[" .. column .. "] = " .. tostring(value)
        elseif type(value) == "boolean" then
          condition = "[" .. column .. "] = " .. (value and "1" or "0")
        else
          condition = "[" .. column .. "] = '" .. tostring(value):gsub("'", "''") .. "'"
        end
        table.insert(conditions, condition)
      end
      sql = sql .. "\nWHERE " .. table.concat(conditions, " AND ")
    end

    return sql
  end,

  ---Build a DELETE statement
  ---@param table_name string Target table
  ---@param where_conditions table<string, any>? WHERE conditions
  ---@return string delete_sql
  build_delete = function(table_name, where_conditions)
    local sql = "DELETE FROM " .. table_name

    if where_conditions and next(where_conditions) then
      local conditions = {}
      for column, value in pairs(where_conditions) do
        local condition
        if value == nil then
          condition = "[" .. column .. "] IS NULL"
        elseif type(value) == "number" then
          condition = "[" .. column .. "] = " .. tostring(value)
        elseif type(value) == "boolean" then
          condition = "[" .. column .. "] = " .. (value and "1" or "0")
        else
          condition = "[" .. column .. "] = '" .. tostring(value):gsub("'", "''") .. "'"
        end
        table.insert(conditions, condition)
      end
      sql = sql .. "\nWHERE " .. table.concat(conditions, " AND ")
    end

    return sql
  end,

  ---Build an IN clause from values
  ---@param values table Array of values
  ---@return string in_clause Just the parenthesized list
  in_clause = function(values)
    local parts = {}
    for _, v in ipairs(values) do
      if v == nil then
        table.insert(parts, "NULL")
      elseif type(v) == "number" then
        table.insert(parts, tostring(v))
      elseif type(v) == "boolean" then
        table.insert(parts, v and "1" or "0")
      else
        table.insert(parts, "'" .. tostring(v):gsub("'", "''") .. "'")
      end
    end
    return "(" .. table.concat(parts, ", ") .. ")"
  end,

  ---Build a SELECT statement
  ---@param columns string|string[] Column(s) to select
  ---@param from_table string Table name
  ---@param opts table? {where: table?, order_by: string?, limit: number?, distinct: boolean?}
  ---@return string select_sql
  build_select = function(columns, from_table, opts)
    opts = opts or {}

    local col_str = type(columns) == "table" and table.concat(columns, ", ") or columns
    local sql = "SELECT "

    if opts.distinct then
      sql = sql .. "DISTINCT "
    end

    if opts.limit then
      sql = sql .. "TOP " .. opts.limit .. " "
    end

    sql = sql .. col_str .. " FROM " .. from_table

    if opts.where and next(opts.where) then
      local conditions = {}
      for column, value in pairs(opts.where) do
        local condition
        if value == nil then
          condition = "[" .. column .. "] IS NULL"
        elseif type(value) == "number" then
          condition = "[" .. column .. "] = " .. tostring(value)
        elseif type(value) == "boolean" then
          condition = "[" .. column .. "] = " .. (value and "1" or "0")
        else
          condition = "[" .. column .. "] = '" .. tostring(value):gsub("'", "''") .. "'"
        end
        table.insert(conditions, condition)
      end
      sql = sql .. "\nWHERE " .. table.concat(conditions, " AND ")
    end

    if opts.order_by then
      sql = sql .. "\nORDER BY " .. opts.order_by
    end

    return sql
  end,

  ---Build a fully qualified table name [schema].[table]
  ---@param schema string? Schema name (nil for dbo)
  ---@param table_name string Table name
  ---@return string qualified_name
  qualified_name = function(schema, table_name)
    schema = schema or "dbo"
    return "[" .. schema .. "].[" .. table_name .. "]"
  end,

  ---Build a CASE expression
  ---@param when_thens table[] Array of {when: string, then: any}
  ---@param else_value any? ELSE value
  ---@return string case_expr
  build_case = function(when_thens, else_value)
    local parts = { "CASE" }

    for _, wt in ipairs(when_thens) do
      local then_str
      if wt.then_value == nil then
        then_str = "NULL"
      elseif type(wt.then_value) == "number" then
        then_str = tostring(wt.then_value)
      elseif type(wt.then_value) == "boolean" then
        then_str = wt.then_value and "1" or "0"
      else
        then_str = "'" .. tostring(wt.then_value):gsub("'", "''") .. "'"
      end
      table.insert(parts, "  WHEN " .. wt.when_cond .. " THEN " .. then_str)
    end

    if else_value ~= nil then
      local else_str
      if type(else_value) == "number" then
        else_str = tostring(else_value)
      elseif type(else_value) == "boolean" then
        else_str = else_value and "1" or "0"
      else
        else_str = "'" .. tostring(else_value):gsub("'", "''") .. "'"
      end
      table.insert(parts, "  ELSE " .. else_str)
    end

    table.insert(parts, "END")
    return table.concat(parts, "\n")
  end,

  ---Build a MERGE statement
  ---@param target string Target table name
  ---@param source string Source table/subquery
  ---@param on_condition string Join condition
  ---@param when_matched table? {update: table<string, string>?} SET assignments
  ---@param when_not_matched table? {insert: {columns: string[], values: string[]}}
  ---@return string merge_sql
  build_merge = function(target, source, on_condition, when_matched, when_not_matched)
    local parts = {
      "MERGE INTO " .. target .. " AS target",
      "USING " .. source .. " AS source",
      "ON " .. on_condition,
    }

    if when_matched and when_matched.update then
      local updates = {}
      for col, val in pairs(when_matched.update) do
        table.insert(updates, "[" .. col .. "] = " .. val)
      end
      table.insert(parts, "WHEN MATCHED THEN UPDATE SET")
      table.insert(parts, "  " .. table.concat(updates, ", "))
    end

    if when_not_matched and when_not_matched.insert then
      local ins = when_not_matched.insert
      table.insert(parts, "WHEN NOT MATCHED THEN INSERT (" .. table.concat(ins.columns, ", ") .. ")")
      table.insert(parts, "VALUES (" .. table.concat(ins.values, ", ") .. ")")
    end

    table.insert(parts, ";")
    return table.concat(parts, "\n")
  end,

  ---Escape LIKE pattern special characters
  ---@param pattern string Pattern to escape
  ---@return string escaped
  escape_like = function(pattern)
    return pattern:gsub("([%%_%[])", "[%1]")
  end,

  ---Build a LIKE pattern
  ---@param value string Value to search
  ---@param position string? "start", "end", "contains", "exact" (default: "contains")
  ---@return string pattern
  like_pattern = function(value, position)
    position = position or "contains"
    local escaped = value:gsub("([%%_%[])", "[%1]")

    if position == "start" then
      return escaped .. "%"
    elseif position == "end" then
      return "%" .. escaped
    elseif position == "exact" then
      return escaped
    else -- contains
      return "%" .. escaped .. "%"
    end
  end,
}
