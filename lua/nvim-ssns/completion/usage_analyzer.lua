---@class UsageAnalyzer
---Query analysis to extract and record table/column usage
local UsageAnalyzer = {}

-- Lazy-loaded modules
local UsageTracker = nil
local Debug = nil
local Config = nil

---Debug logging helper
---@param message string
local function debug_log(message)
  if not Debug then
    Debug = require('nvim-ssns.debug')
  end

  if not Config then
    Config = require('nvim-ssns.config')
  end

  local config = Config.get()
  if config.completion and config.completion.debug then
    Debug.log("[ANALYZER] " .. message)
  end
end

---Clean identifier (remove brackets, trim)
---@param identifier string Identifier to clean
---@return string cleaned Cleaned identifier
local function clean_identifier(identifier)
  if not identifier then return "" end

  -- Remove brackets: [dbo] → dbo
  identifier = identifier:gsub("%[", ""):gsub("%]", "")

  -- Trim whitespace
  identifier = vim.trim(identifier)

  -- Remove AS keyword if present
  identifier = identifier:gsub("%s+AS%s+", " ")

  return identifier
end

---Normalize query (remove comments, uppercase keywords)
---@param query string SQL query
---@return string normalized Normalized query
local function normalize_query(query)
  -- Remove single-line comments
  query = query:gsub("%-%-%[^\n]*\n", " ")

  -- Remove multi-line comments
  query = query:gsub("/%*.-%*/", " ")

  -- Convert keywords to uppercase (for pattern matching)
  query = query:gsub("%f[%a]([Ff][Rr][Oo][Mm])%f[%A]", "FROM")
  query = query:gsub("%f[%a]([Jj][Oo][Ii][Nn])%f[%A]", "JOIN")
  query = query:gsub("%f[%a]([Ss][Ee][Ll][Ee][Cc][Tt])%f[%A]", "SELECT")
  query = query:gsub("%f[%a]([Ww][Hh][Ee][Rr][Ee])%f[%A]", "WHERE")
  query = query:gsub("%f[%a]([Oo][Rr][Dd][Ee][Rr])%f[%A]", "ORDER")
  query = query:gsub("%f[%a]([Bb][Yy])%f[%A]", "BY")
  query = query:gsub("%f[%a]([Uu][Pp][Dd][Aa][Tt][Ee])%f[%A]", "UPDATE")
  query = query:gsub("%f[%a]([Dd][Ee][Ll][Ee][Tt][Ee])%f[%A]", "DELETE")
  query = query:gsub("%f[%a]([Ii][Nn][Ss][Ee][Rr][Tt])%f[%A]", "INSERT")
  query = query:gsub("%f[%a]([Ii][Nn][Tt][Oo])%f[%A]", "INTO")
  query = query:gsub("%f[%a]([Ee][Xx][Ee][Cc][Uu]?[Tt]?[Ee]?)%f[%A]", "EXEC")

  return query
end

---Parse table reference into path and alias
---@param table_ref string Table reference string
---@return table? info {path, alias} or nil
local function parse_table_reference(table_ref)
  table_ref = vim.trim(table_ref)

  -- Remove brackets: [dbo].[Employees] → dbo.Employees
  local cleaned = clean_identifier(table_ref)

  -- Split by whitespace to separate table and alias
  -- "dbo.Employees e" → path="dbo.Employees", alias="e"
  -- "dbo.Employees AS e" → path="dbo.Employees", alias="e"
  local parts = vim.split(cleaned, "%s+")

  if #parts == 0 then
    return nil
  end

  local path = parts[1]
  local alias = nil

  -- Check for alias (last part, skip "AS" keyword)
  if #parts >= 2 then
    if parts[#parts]:upper() ~= "AS" then
      alias = parts[#parts]
    elseif #parts >= 3 then
      alias = parts[#parts - 1]
    end
  end

  return {
    path = path,
    alias = alias
  }
end

---Parse column reference
---@param col_expr string Column expression
---@param alias_map table Alias -> table path map
---@param table_refs table[] All table references
---@return table? info {path, table} or nil
local function parse_column_reference(col_expr, alias_map, table_refs)
  col_expr = vim.trim(col_expr)

  -- Skip non-column expressions
  if col_expr:match("^%d+$") then return nil end  -- Numeric literal
  if col_expr:match("^'") then return nil end      -- String literal
  if col_expr:match("^%(") then return nil end     -- Subquery
  if col_expr:upper():match("^COUNT") then return nil end  -- Aggregate function
  if col_expr:upper():match("^SUM") then return nil end
  if col_expr:upper():match("^AVG") then return nil end
  if col_expr:upper():match("^MAX") then return nil end
  if col_expr:upper():match("^MIN") then return nil end
  if col_expr == "*" then return nil end           -- SELECT *

  -- Clean identifier
  local cleaned = clean_identifier(col_expr)

  -- Check for qualified column: e.EmployeeID
  if cleaned:match("%.") then
    local parts = vim.split(cleaned, "%.", { plain = true })
    if #parts >= 2 then
      local alias_or_table = parts[1]:lower()
      local column_name = parts[#parts]

      -- Resolve alias to table
      local table_path = alias_map[alias_or_table]
      if table_path then
        return {
          path = string.format("%s.%s", table_path, column_name),
          table = table_path
        }
      else
        -- Might be schema.table.column or just table.column
        return {
          path = cleaned,
          table = parts[1]
        }
      end
    end
  end

  -- Unqualified column - associate with first table
  if #table_refs > 0 then
    return {
      path = string.format("%s.%s", table_refs[1].path, cleaned),
      table = table_refs[1].path
    }
  end

  return nil
end

---Extract table references from query
---@param query_text string SQL query
---@return table[] references Array of {path, alias} objects
local function extract_table_references(query_text)
  local tables = {}
  local seen = {}

  -- Normalize query (remove comments, normalize whitespace)
  local normalized = normalize_query(query_text)

  -- Pattern 1: FROM clause
  -- FROM dbo.Employees
  -- FROM dbo.Employees e
  -- FROM [dbo].[Employees] AS e
  for table_ref in normalized:gmatch("FROM%s+([^%s,;%(%)]+[^,;%(%)]*%s*)") do
    -- Stop at WHERE, JOIN, ORDER, etc.
    table_ref = table_ref:gsub("%s+WHERE.*", "")
    table_ref = table_ref:gsub("%s+JOIN.*", "")
    table_ref = table_ref:gsub("%s+ORDER.*", "")
    table_ref = table_ref:gsub("%s+GROUP.*", "")
    table_ref = table_ref:gsub("%s+HAVING.*", "")

    local table_info = parse_table_reference(table_ref)
    if table_info and not seen[table_info.path] then
      table.insert(tables, table_info)
      seen[table_info.path] = true
      debug_log(string.format("Extracted FROM table: %s (alias: %s)", table_info.path, table_info.alias or "none"))
    end
  end

  -- Pattern 2: JOIN clauses
  -- INNER JOIN dbo.Departments d
  -- LEFT JOIN [dbo].[Departments] AS d ON e.DeptID = d.ID
  for table_ref in normalized:gmatch("JOIN%s+([^%s,;%(%)]+[^,;%(%)ON]*%s*)") do
    -- Stop at ON
    table_ref = table_ref:gsub("%s+ON.*", "")

    local table_info = parse_table_reference(table_ref)
    if table_info and not seen[table_info.path] then
      table.insert(tables, table_info)
      seen[table_info.path] = true
      debug_log(string.format("Extracted JOIN table: %s (alias: %s)", table_info.path, table_info.alias or "none"))
    end
  end

  -- Pattern 3: UPDATE statements
  -- UPDATE dbo.Employees SET ...
  for table_ref in normalized:gmatch("UPDATE%s+([^%s,;%(%)]+)") do
    local table_info = parse_table_reference(table_ref)
    if table_info and not seen[table_info.path] then
      table.insert(tables, table_info)
      seen[table_info.path] = true
      debug_log(string.format("Extracted UPDATE table: %s", table_info.path))
    end
  end

  -- Pattern 4: DELETE statements
  -- DELETE FROM dbo.Employees
  for table_ref in normalized:gmatch("DELETE%s+FROM%s+([^%s,;%(%)]+)") do
    local table_info = parse_table_reference(table_ref)
    if table_info and not seen[table_info.path] then
      table.insert(tables, table_info)
      seen[table_info.path] = true
      debug_log(string.format("Extracted DELETE table: %s", table_info.path))
    end
  end

  -- Pattern 5: INSERT INTO statements
  -- INSERT INTO dbo.Employees (...)
  for table_ref in normalized:gmatch("INSERT%s+INTO%s+([^%s,;%(%)]+)") do
    local table_info = parse_table_reference(table_ref)
    if table_info and not seen[table_info.path] then
      table.insert(tables, table_info)
      seen[table_info.path] = true
      debug_log(string.format("Extracted INSERT table: %s", table_info.path))
    end
  end

  return tables
end

---Extract column references from query
---@param query_text string SQL query
---@param table_refs table[] Table references with aliases
---@return table[] references Array of {path, table} objects
local function extract_column_references(query_text, table_refs)
  local columns = {}
  local seen = {}
  local normalized = normalize_query(query_text)

  -- Build alias map for resolving qualified columns
  local alias_map = {}
  for _, table_ref in ipairs(table_refs) do
    if table_ref.alias then
      alias_map[table_ref.alias:lower()] = table_ref.path
    end
  end

  -- Pattern 1: SELECT clause columns
  -- SELECT e.EmployeeID, e.FirstName
  -- SELECT EmployeeID, FirstName
  local select_clause = normalized:match("SELECT%s+(.-)%s+FROM")
  if select_clause then
    -- Split by comma
    for col_expr in select_clause:gmatch("[^,]+") do
      local column_info = parse_column_reference(col_expr, alias_map, table_refs)
      if column_info and not seen[column_info.path] then
        table.insert(columns, column_info)
        seen[column_info.path] = true
        debug_log(string.format("Extracted SELECT column: %s (table: %s)", column_info.path, column_info.table))
      end
    end
  end

  -- Pattern 2: WHERE clause columns
  -- WHERE e.DepartmentID = 5
  local where_clause = normalized:match("WHERE%s+(.-)%s*[;GO]") or normalized:match("WHERE%s+(.-)%s+ORDER") or normalized:match("WHERE%s+(.-)%s+GROUP") or normalized:match("WHERE%s+(.-)$")
  if where_clause then
    for col_expr in where_clause:gmatch("([%w_%.%[%]]+)%s*[=<>!]") do
      local column_info = parse_column_reference(col_expr, alias_map, table_refs)
      if column_info and not seen[column_info.path] then
        table.insert(columns, column_info)
        seen[column_info.path] = true
        debug_log(string.format("Extracted WHERE column: %s (table: %s)", column_info.path, column_info.table))
      end
    end
  end

  -- Pattern 3: ORDER BY clause
  local order_by_clause = normalized:match("ORDER%s+BY%s+(.-)%s*[;GO]") or normalized:match("ORDER%s+BY%s+(.-)$")
  if order_by_clause then
    for col_expr in order_by_clause:gmatch("[^,]+") do
      -- Remove ASC/DESC
      col_expr = col_expr:gsub("%s+ASC%s*$", ""):gsub("%s+DESC%s*$", "")
      local column_info = parse_column_reference(col_expr, alias_map, table_refs)
      if column_info and not seen[column_info.path] then
        table.insert(columns, column_info)
        seen[column_info.path] = true
        debug_log(string.format("Extracted ORDER BY column: %s (table: %s)", column_info.path, column_info.table))
      end
    end
  end

  -- Pattern 4: SET clause (UPDATE statements)
  -- UPDATE ... SET EmployeeID = 5, FirstName = 'John'
  local set_clause = normalized:match("SET%s+(.-)%s+WHERE") or normalized:match("SET%s+(.-)%s*[;GO]") or normalized:match("SET%s+(.-)$")
  if set_clause then
    for col_expr in set_clause:gmatch("([%w_%.%[%]]+)%s*=") do
      local column_info = parse_column_reference(col_expr, alias_map, table_refs)
      if column_info and not seen[column_info.path] then
        table.insert(columns, column_info)
        seen[column_info.path] = true
        debug_log(string.format("Extracted SET column: %s (table: %s)", column_info.path, column_info.table))
      end
    end
  end

  return columns
end

---Extract procedure references from query
---@param query_text string SQL query
---@return table[] references Array of {path} objects
local function extract_procedure_references(query_text)
  local procedures = {}
  local seen = {}
  local normalized = normalize_query(query_text)

  -- Pattern: EXEC dbo.usp_GetEmployees
  -- Pattern: EXECUTE dbo.usp_GetEmployees
  for proc_ref in normalized:gmatch("EXEC[UTE]*%s+([%w_%[%]%.]+)") do
    local proc_name = clean_identifier(proc_ref)
    if proc_name and not seen[proc_name] then
      table.insert(procedures, {path = proc_name})
      seen[proc_name] = true
      debug_log(string.format("Extracted procedure: %s", proc_name))
    end
  end

  return procedures
end

---Analyze query and record object usage
---@param query_text string SQL query to analyze
---@param connection table Connection context
function UsageAnalyzer.analyze_and_record(query_text, connection)
  if not query_text or query_text == "" then
    return
  end

  if not connection or not connection.connection_config then
    return
  end

  -- Lazy load UsageTracker
  if not UsageTracker then
    UsageTracker = require('nvim-ssns.completion.usage_tracker')
  end

  -- Extract tables from FROM/JOIN clauses
  local tables = extract_table_references(query_text)

  -- Extract columns from SELECT/WHERE/ORDER BY clauses
  local columns = extract_column_references(query_text, tables)

  -- Extract procedures/functions
  local procedures = extract_procedure_references(query_text)

  debug_log(string.format("Extracted %d tables, %d columns, %d procedures",
    #tables, #columns, #procedures))

  -- Record in UsageTracker
  for _, table_ref in ipairs(tables) do
    UsageTracker.record_selection(connection, "table", table_ref.path)
  end

  for _, column_ref in ipairs(columns) do
    UsageTracker.record_selection(connection, "column", column_ref.path)
  end

  for _, proc_ref in ipairs(procedures) do
    UsageTracker.record_selection(connection, "procedure", proc_ref.path)
  end
end

return UsageAnalyzer
