---Temp table detection and column inference for SQL IntelliSense
---Detects temp table creation (#temp and ##temp) and infers column schemas
---@class TempTableTracker
local TempTableTracker = {}

---Detect temp table creation statements in query
---Handles both SELECT INTO and CREATE TABLE patterns
---@param query_text string SQL query text
---@param bufnr number Buffer number
---@return table[] temp_tables Array of detected temp tables with inferred columns
function TempTableTracker.detect_temp_tables(query_text, bufnr)
  -- Step 1: Parse query with Tree-sitter
  local Treesitter = require('ssns.completion.metadata.treesitter')
  local root = Treesitter.parse_sql(query_text)

  if not root then
    -- Fallback: Try regex-based detection
    return TempTableTracker._detect_temp_tables_regex(query_text)
  end

  -- Step 2: Find temp table creation patterns
  local temp_tables = {}

  -- Pattern 1: SELECT INTO #temp
  local select_into_tables = TempTableTracker._find_select_into(root, query_text, bufnr)
  for _, tbl in ipairs(select_into_tables) do
    table.insert(temp_tables, tbl)
  end

  -- Pattern 2: CREATE TABLE #temp (...)
  local create_tables = TempTableTracker._find_create_table(root, query_text)
  for _, tbl in ipairs(create_tables) do
    table.insert(temp_tables, tbl)
  end

  return temp_tables
end

---Find SELECT INTO #temp statements using Tree-sitter
---@param root table Tree-sitter AST root
---@param query_text string SQL query text
---@param bufnr number Buffer number
---@return table[] temp_tables Array of temp tables with inferred columns
function TempTableTracker._find_select_into(root, query_text, bufnr)
  local temp_tables = {}

  -- Walk the AST to find SELECT INTO patterns
  local function walk_tree(node, depth)
    if depth > 50 then return end -- Prevent infinite recursion

    local node_type = node:type()

    -- Look for INTO clause (SQL Server specific)
    if node_type == "into_clause" or node_type:match("into") then
      -- Extract temp table name from INTO clause
      for child in node:iter_children() do
        if child:type() == "identifier" or child:type() == "object_reference" then
          local table_name = vim.treesitter.get_node_text(child, query_text)

          -- Clean up brackets/quotes
          table_name = table_name:gsub("^%[(.-)%]$", "%1")
          table_name = table_name:gsub('^"(.-)"$', "%1")
          table_name = table_name:gsub("^`(.-)`$", "%1")

          -- Check if it's a temp table (starts with # or ##)
          if table_name:match("^#") then
            -- Find parent SELECT statement to infer columns
            local select_node = node:parent()
            while select_node and not select_node:type():match("select") do
              select_node = select_node:parent()
            end

            -- Infer columns from SELECT list
            local columns = {}
            if select_node then
              columns = TempTableTracker._infer_columns_from_select(select_node, query_text, bufnr)
            end

            -- Determine temp table type (local # or global ##)
            local temp_type = table_name:match("^##") and "global" or "local"

            -- Get line number
            local start_row, _ = node:range()

            -- Create temp table object
            table.insert(temp_tables, {
              name = table_name,
              type = temp_type,
              columns = columns,
              created_at_line = start_row + 1, -- Convert to 1-indexed
              chunk_index = 1, -- Will be updated by caller based on GO position
              is_temp = true,
              object_type = 'temp_table',
            })
          end
        end
      end
    end

    -- Recurse to children
    for child in node:iter_children() do
      walk_tree(child, depth + 1)
    end
  end

  -- Start walking from root
  walk_tree(root, 0)

  return temp_tables
end

---Find CREATE TABLE #temp statements
---@param root table Tree-sitter AST root
---@param query_text string SQL query text
---@return table[] temp_tables Array of temp tables with columns
function TempTableTracker._find_create_table(root, query_text)
  local temp_tables = {}

  -- Walk the AST to find CREATE TABLE patterns
  local function walk_tree(node, depth)
    if depth > 50 then return end

    local node_type = node:type()

    -- Look for CREATE TABLE statement
    if node_type == "create_table_statement" or node_type == "create_table" then
      -- Extract table name
      local table_name = nil
      local columns = {}
      local start_row = 0

      for child in node:iter_children() do
        local child_type = child:type()

        -- Get table name
        if child_type == "identifier" or child_type == "object_reference" then
          if not table_name then -- First identifier is table name
            table_name = vim.treesitter.get_node_text(child, query_text)

            -- Clean up brackets/quotes
            table_name = table_name:gsub("^%[(.-)%]$", "%1")
            table_name = table_name:gsub('^"(.-)"$', "%1")
            table_name = table_name:gsub("^`(.-)`$", "%1")

            start_row, _ = child:range()
          end
        end

        -- Get column definitions
        if child_type == "column_definitions" or child_type:match("column") then
          columns = TempTableTracker._parse_column_definitions(child, query_text)
        end
      end

      -- Check if it's a temp table
      if table_name and table_name:match("^#") then
        local temp_type = table_name:match("^##") and "global" or "local"

        table.insert(temp_tables, {
          name = table_name,
          type = temp_type,
          columns = columns,
          created_at_line = start_row + 1,
          chunk_index = 1,
          is_temp = true,
          object_type = 'temp_table',
        })
      end
    end

    -- Recurse to children
    for child in node:iter_children() do
      walk_tree(child, depth + 1)
    end
  end

  walk_tree(root, 0)

  return temp_tables
end

---Parse column definitions from CREATE TABLE statement
---@param column_defs_node table Tree-sitter node for column definitions
---@param query_text string SQL query text
---@return table[] columns Array of column objects
function TempTableTracker._parse_column_definitions(column_defs_node, query_text)
  local columns = {}
  local ordinal = 1

  -- Walk through column definition nodes
  for child in column_defs_node:iter_children() do
    local child_type = child:type()

    if child_type == "column_definition" or child_type:match("column") then
      local col_name = nil
      local col_type = "varchar(max)" -- Default
      local nullable = true -- Default
      local is_pk = false

      -- Extract column info from child nodes
      local identifier_count = 0
      for col_child in child:iter_children() do
        local col_child_type = col_child:type()

        -- First identifier is column name
        if col_child_type == "identifier" and identifier_count == 0 then
          col_name = vim.treesitter.get_node_text(col_child, query_text)
          col_name = col_name:gsub("^%[(.-)%]$", "%1")
          col_name = col_name:gsub('^"(.-)"$', "%1")
          col_name = col_name:gsub("^`(.-)`$", "%1")
          identifier_count = identifier_count + 1
        end

        -- Data type
        if col_child_type:match("type") or col_child_type == "int" or col_child_type == "varchar" then
          col_type = vim.treesitter.get_node_text(col_child, query_text)
        end

        -- NOT NULL constraint
        if col_child_type:match("not_null") then
          nullable = false
        end

        -- PRIMARY KEY constraint
        if col_child_type:match("primary") or col_child_type:match("key") then
          is_pk = true
          nullable = false -- PKs are always NOT NULL
        end
      end

      -- Add column if we found a name
      if col_name then
        table.insert(columns, {
          name = col_name,
          column_name = col_name,
          data_type = col_type,
          nullable = nullable,
          is_primary_key = is_pk,
          ordinal_position = ordinal,
        })
        ordinal = ordinal + 1
      end
    end
  end

  return columns
end

---Infer column schema from SELECT list
---@param select_node table Tree-sitter SELECT statement node
---@param query_text string SQL query text
---@param bufnr number Buffer number
---@return table[] columns Array of inferred column objects
function TempTableTracker._infer_columns_from_select(select_node, query_text, bufnr)
  local columns = {}
  local ordinal = 1

  -- Find SELECT list (field list)
  local function find_select_list(node)
    for child in node:iter_children() do
      local child_type = child:type()

      -- Look for select list / field list
      if child_type == "select_clause" or child_type == "field_list" or child_type:match("list") then
        return child
      end

      -- Recurse if not found
      local result = find_select_list(child)
      if result then return result end
    end
    return nil
  end

  local select_list = find_select_list(select_node)
  if not select_list then
    return columns
  end

  -- Parse each item in SELECT list
  for item in select_list:iter_children() do
    local item_type = item:type()

    -- Skip commas and other separators
    if item_type ~= "," and item_type ~= "(" and item_type ~= ")" then
      local col_name = nil
      local col_type = "varchar(max)" -- Default type
      local nullable = true

      -- Check if there's an alias (AS clause)
      local has_alias = false
      for child in item:iter_children() do
        if child:type():match("alias") or child:type() == "identifier" then
          -- This might be an alias
          local text = vim.treesitter.get_node_text(child, query_text)
          if text:upper() ~= "AS" then
            col_name = text
            col_name = col_name:gsub("^%[(.-)%]$", "%1")
            col_name = col_name:gsub('^"(.-)"$', "%1")
            col_name = col_name:gsub("^`(.-)`$", "%1")
            has_alias = true
          end
        end
      end

      -- If no alias, try to extract column name from expression
      if not col_name then
        local item_text = vim.treesitter.get_node_text(item, query_text)

        -- Try to resolve column reference (e.g., e.EmployeeID)
        local resolved_col = TempTableTracker._resolve_column_source(item_text, bufnr)
        if resolved_col then
          col_name = resolved_col.name or resolved_col.column_name
          col_type = resolved_col.data_type or col_type
          nullable = resolved_col.nullable == nil and true or resolved_col.nullable
        else
          -- Extract column name from expression (last identifier)
          -- e.EmployeeID -> EmployeeID
          col_name = item_text:match("%.([%w_]+)%s*$") or item_text:match("([%w_]+)%s*$") or item_text

          -- Infer type from expression
          col_type = TempTableTracker._infer_expression_type(item_text)
        end

        -- Clean up column name
        col_name = col_name:gsub("^%[(.-)%]$", "%1")
        col_name = col_name:gsub('^"(.-)"$', "%1")
        col_name = col_name:gsub("^`(.-)`$", "%1")
      end

      -- Add column if we have a name
      if col_name and col_name ~= "" and col_name ~= "*" then
        table.insert(columns, {
          name = col_name,
          column_name = col_name,
          data_type = col_type,
          nullable = nullable,
          ordinal_position = ordinal,
        })
        ordinal = ordinal + 1
      end
    end
  end

  return columns
end

---Helper: Resolve column source to get metadata
---@param column_ref string Column reference (e.g., "e.EmployeeID" or "EmployeeID")
---@param bufnr number Buffer number
---@return table? column_metadata Column info or nil
function TempTableTracker._resolve_column_source(column_ref, bufnr)
  -- Try to use Resolver to resolve the column
  local success, result = pcall(function()
    local Resolver = require('ssns.completion.metadata.resolver')
    local Context = require('ssns.completion.statement_context')

    -- Get connection for buffer
    local Source = require('ssns.completion.source')
    local source = Source.new()
    local connection = source:get_connection(bufnr)

    if not connection then
      return nil
    end

    -- Parse column reference: table.column or just column
    local table_ref, col_name = column_ref:match("^([^%.]+)%.(.+)$")

    if not table_ref then
      -- Just a column name, can't resolve without table context
      return nil
    end

    -- Resolve table
    local table_obj = Resolver.resolve_table(table_ref, connection, bufnr)
    if not table_obj then
      return nil
    end

    -- Get columns from table
    local columns = Resolver.get_columns(table_obj, connection)

    -- Find matching column
    for _, col in ipairs(columns) do
      local col_name_check = col.name or col.column_name
      if col_name_check and col_name_check:lower() == col_name:lower() then
        return col
      end
    end

    return nil
  end)

  if success and result then
    return result
  end

  return nil
end

---Helper: Infer data type from SQL expression
---Uses simple heuristics for common SQL functions and expressions
---@param expression string SQL expression (e.g., "COUNT(*)", "GETDATE()")
---@return string data_type Inferred data type
function TempTableTracker._infer_expression_type(expression)
  if not expression then
    return "varchar(max)"
  end

  -- Normalize expression (trim and uppercase for matching)
  local expr = expression:gsub("^%s+", ""):gsub("%s+$", "")
  local expr_upper = expr:upper()

  -- Aggregate functions
  if expr_upper:match("^COUNT%s*%(") then
    return "int"
  end

  if expr_upper:match("^SUM%s*%(") or expr_upper:match("^AVG%s*%(") then
    return "numeric"
  end

  if expr_upper:match("^MAX%s*%(") or expr_upper:match("^MIN%s*%(") then
    -- Type depends on argument, default to varchar
    return "varchar(max)"
  end

  -- Date/time functions
  if expr_upper:match("^GETDATE%s*%(") or expr_upper:match("^CURRENT_TIMESTAMP") then
    return "datetime"
  end

  if expr_upper:match("^SYSDATETIME%s*%(") then
    return "datetime2"
  end

  if expr_upper:match("^GETUTCDATE%s*%(") then
    return "datetime"
  end

  -- String functions
  if expr_upper:match("^CONCAT%s*%(") or expr_upper:match("^SUBSTRING%s*%(") or
     expr_upper:match("^UPPER%s*%(") or expr_upper:match("^LOWER%s*%(") or
     expr_upper:match("^TRIM%s*%(") or expr_upper:match("^LTRIM%s*%(") or
     expr_upper:match("^RTRIM%s*%(") then
    return "varchar(max)"
  end

  -- Type conversion functions
  if expr_upper:match("^CAST%s*%(") then
    -- Extract target type: CAST(x AS type)
    local cast_type = expr_upper:match("AS%s+([%w%(%)%d,]+)%s*%)$")
    if cast_type then
      return cast_type:lower()
    end
  end

  if expr_upper:match("^CONVERT%s*%(") then
    -- Extract target type: CONVERT(type, x)
    local convert_type = expr_upper:match("CONVERT%s*%(%s*([%w%(%)%d,]+)%s*,")
    if convert_type then
      return convert_type:lower()
    end
  end

  -- Literals
  if expr:match("^'") then
    -- String literal
    return "varchar(max)"
  end

  if expr:match("^%d+$") then
    -- Integer literal
    return "int"
  end

  if expr:match("^%d+%.%d+$") then
    -- Decimal literal
    return "numeric"
  end

  -- Default: Unknown type
  return "varchar(max)"
end

---Fallback: Regex-based temp table detection (when Tree-sitter unavailable)
---@param query_text string SQL query text
---@return table[] temp_tables Array of temp table objects (columns may be empty)
function TempTableTracker._detect_temp_tables_regex(query_text)
  local temp_tables = {}

  -- Pattern 1: SELECT ... INTO #temp
  for table_name in query_text:gmatch("INTO%s+(##?%w+)") do
    local temp_type = table_name:match("^##") and "global" or "local"

    table.insert(temp_tables, {
      name = table_name,
      type = temp_type,
      columns = {}, -- Can't infer columns without Tree-sitter
      created_at_line = 0,
      chunk_index = 1,
      is_temp = true,
      object_type = 'temp_table',
    })
  end

  -- Pattern 2: CREATE TABLE #temp
  for table_name in query_text:gmatch("CREATE%s+TABLE%s+(##?%w+)") do
    local temp_type = table_name:match("^##") and "global" or "local"

    table.insert(temp_tables, {
      name = table_name,
      type = temp_type,
      columns = {}, -- Can't parse columns without Tree-sitter
      created_at_line = 0,
      chunk_index = 1,
      is_temp = true,
      object_type = 'temp_table',
    })
  end

  return temp_tables
end

return TempTableTracker
