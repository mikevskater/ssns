---Tree-sitter utility module for SQL parsing with graceful fallback
---Provides robust SQL AST parsing for alias resolution and context detection
---Falls back silently to regex-based parsing if tree-sitter-sql is unavailable
---@class Treesitter
local Treesitter = {}

-- Cache tree-sitter availability check (computed once on first use)
local _availability_cache = nil

---Check if tree-sitter-sql parser is available
---@return boolean available True if tree-sitter-sql is installed and functional
function Treesitter.is_available()
  local Debug = require('ssns.debug')

  -- Return cached result if already checked
  if _availability_cache ~= nil then
    Debug.log(string.format("[TREESITTER] Returning cached availability: %s", tostring(_availability_cache)))
    return _availability_cache
  end

  -- Check if vim.treesitter API is available (Neovim >= 0.9)
  local has_ts_api = vim.treesitter and vim.treesitter.get_parser
  Debug.log(string.format("[TREESITTER] vim.treesitter API available: %s", tostring(has_ts_api)))

  if not has_ts_api then
    _availability_cache = false
    return false
  end

  -- Try to create a SQL parser (pcall for safety)
  local success = pcall(function()
    local parser = vim.treesitter.get_string_parser("SELECT 1", "sql")
    if not parser then
      return false
    end
    -- Try to parse a simple query
    local tree = parser:parse()[1]
    if not tree then
      return false
    end
    return true
  end)

  Debug.log(string.format("[TREESITTER] SQL parser available: %s", tostring(success)))

  _availability_cache = success
  return success
end

---Parse SQL text into AST (returns nil if tree-sitter unavailable)
---@param sql_text string SQL query text
---@return table? root_node Root AST node or nil if unavailable/error
function Treesitter.parse_sql(sql_text)
  -- Check availability first
  if not Treesitter.is_available() then
    return nil
  end

  -- Try to parse SQL text (silent error handling)
  local success, result = pcall(function()
    local parser = vim.treesitter.get_string_parser(sql_text, "sql")
    if not parser then
      return nil
    end

    local tree = parser:parse()[1]
    if not tree then
      return nil
    end

    return tree:root()
  end)

  if not success then
    return nil
  end

  return result
end

---Check if AST has parsing errors
---@param root_node table AST root node
---@return boolean has_errors True if ERROR nodes found
function Treesitter.has_errors(root_node)
  if not root_node then
    return true
  end

  -- Query pattern to find ERROR nodes in the AST
  local error_pattern = [[(ERROR) @error]]

  local success, result = pcall(function()
    local query = vim.treesitter.query.parse("sql", error_pattern)
    if not query then
      return false
    end

    -- Check if any ERROR nodes exist
    for _ in query:iter_captures(root_node, 0) do
      return true -- Found at least one error
    end

    return false -- No errors found
  end)

  if not success then
    return true -- Treat query errors as parse errors
  end

  return result
end

---Extract database name from USE statement
---@param query_text string SQL query text
---@return string? database Database name or nil if not found
function Treesitter.extract_use_database(query_text)
  -- Parse SQL into AST
  local root = Treesitter.parse_sql(query_text)
  if not root then
    return nil -- Silent fallback
  end

  -- Don't check for errors here - USE statements might be in partial/malformed queries
  -- We want to extract what we can even if the rest of the query has issues

  -- Tree-sitter query pattern for USE statement
  -- Note: This pattern is grammar-dependent and may need adjustment
  -- For now, use a simple pattern that works with most SQL parsers
  local use_pattern = [[
    (use_statement
      (identifier) @database)
  ]]

  local success, result = pcall(function()
    local query = vim.treesitter.query.parse("sql", use_pattern)
    if not query then
      return nil
    end

    -- Find first USE statement
    for _, node in query:iter_captures(root, query_text) do
      local db_name = vim.treesitter.get_node_text(node, query_text)
      if db_name then
        -- Clean up brackets if present: [MyDatabase] -> MyDatabase
        db_name = db_name:gsub("^%[(.-)%]$", "%1")
        db_name = db_name:gsub('^"(.-)"$', "%1") -- PostgreSQL quotes
        db_name = db_name:gsub("^`(.-)`$", "%1") -- MySQL backticks
        return db_name
      end
    end

    return nil
  end)

  if not success then
    return nil -- Silent fallback
  end

  return result
end

---Extract table references from FROM/JOIN clauses using simpler regex-like tree-sitter approach
---@param query_text string SQL query text
---@return table[] references Array of { table: string, alias?: string, schema?: string }
function Treesitter.extract_table_references(query_text)
  -- Parse SQL into AST
  local root = Treesitter.parse_sql(query_text)
  if not root then
    return {} -- Silent fallback (caller will use regex)
  end

  -- Don't fail on parse errors - try to extract what we can
  -- This is useful for incomplete queries during typing

  -- Use a simpler approach: walk the tree and look for identifier patterns
  -- This is more robust than complex query patterns that depend on exact grammar
  local success, references = pcall(function()
    local refs = {}

    -- Helper to recursively walk tree nodes
    local function walk_tree(node, depth)
      if depth > 50 then return end -- Prevent infinite recursion

      local node_type = node:type()

      -- Look for FROM clauses
      if node_type == "from_clause" or node_type == "from" then
        -- Extract table reference from FROM clause
        local ref = Treesitter._extract_table_from_node(node, query_text)
        if ref then
          table.insert(refs, ref)
        end
      end

      -- Look for JOIN clauses
      if node_type:match("join") then -- Matches: join_clause, inner_join, left_join, etc.
        -- Extract table reference from JOIN clause
        local ref = Treesitter._extract_table_from_node(node, query_text)
        if ref then
          table.insert(refs, ref)
        end
      end

      -- Recurse to children
      for child in node:iter_children() do
        walk_tree(child, depth + 1)
      end
    end

    -- Start walking from root
    walk_tree(root, 0)

    return refs
  end)

  if not success then
    return {} -- Silent fallback
  end

  return references or {}
end

---Extract table references from a specific AST node (scope-aware)
---Only processes FROM/JOIN clauses within this node's subtree
---This is more accurate than extract_table_references for complex queries with subqueries/CTEs
---@param node table Tree-sitter node (e.g., select_statement)
---@param query_text string The SQL query text for this node
---@return table[] refs Array of {table, alias?, schema?}
function Treesitter.extract_table_references_in_scope(node, query_text)
  local refs = {}

  -- Safety check
  if not node or not query_text then
    return refs
  end

  -- Walk only this node's subtree
  local function walk(n, depth)
    if depth > 50 then return end -- Prevent infinite recursion

    local node_type = n:type()

    -- Only process FROM and JOIN clauses within this scope
    if node_type == "from_clause" or
       node_type == "from" or
       node_type == "join_clause" or
       node_type == "inner_join" or
       node_type == "left_join" or
       node_type == "right_join" or
       node_type == "full_join" or
       node_type == "cross_join" or
       node_type:match("join") then -- Catch any other join variants

      -- Extract table reference from this node
      -- Reuse existing _extract_table_from_node helper
      local ref = Treesitter._extract_table_from_node(n, query_text)
      if ref then
        table.insert(refs, ref)
      end
    end

    -- Recurse into children (but NOT into nested SELECT statements)
    -- This prevents extracting tables from subqueries/CTEs
    for child in n:iter_children() do
      local child_type = child:type()

      -- Skip nested SELECT statements (they have their own scope)
      if child_type ~= "select_statement" and
         child_type ~= "subquery" and
         child_type ~= "cte" then
        walk(child, depth + 1)
      end
    end
  end

  -- Wrap in pcall for safety
  local success = pcall(function()
    walk(node, 0)
  end)

  if not success then
    return {} -- Silent fallback
  end

  return refs
end

---Helper: Extract table name and alias from a tree node
---@param node table Tree-sitter node
---@param query_text string Original query text
---@return table? reference { table: string, alias?: string, schema?: string }
function Treesitter._extract_table_from_node(node, query_text)
  local ref = {}
  local identifiers = {}

  -- Collect all identifiers in this node (table name, schema, alias)
  for child in node:iter_children() do
    local child_type = child:type()

    if child_type == "identifier" or child_type == "object_reference" then
      local text = vim.treesitter.get_node_text(child, query_text)
      -- Clean up brackets/quotes
      text = text:gsub("^%[(.-)%]$", "%1")
      text = text:gsub('^"(.-)"$', "%1")
      text = text:gsub("^`(.-)`$", "%1")
      table.insert(identifiers, text)
    elseif child_type == "dotted_name" or child_type == "field_reference" then
      -- Handle schema.table pattern
      local parts = {}
      for subchild in child:iter_children() do
        if subchild:type() == "identifier" then
          local text = vim.treesitter.get_node_text(subchild, query_text)
          text = text:gsub("^%[(.-)%]$", "%1")
          text = text:gsub('^"(.-)"$', "%1")
          text = text:gsub("^`(.-)`$", "%1")
          table.insert(parts, text)
        end
      end

      if #parts == 2 then
        ref.schema = parts[1]
        ref.table = parts[2]
      elseif #parts == 1 then
        table.insert(identifiers, parts[1])
      end
    end
  end

  -- Parse identifiers: first is table, last is alias (if multiple)
  if #identifiers == 1 and not ref.table then
    ref.table = identifiers[1]
  elseif #identifiers == 2 and not ref.table then
    ref.table = identifiers[1]
    ref.alias = identifiers[2]
  elseif #identifiers >= 2 and not ref.table then
    -- Could be schema.table alias
    ref.schema = identifiers[1]
    ref.table = identifiers[2]
    if #identifiers > 2 then
      ref.alias = identifiers[#identifiers] -- Last one is alias
    end
  end

  -- Only return if we found a table name
  if ref.table then
    return ref
  end

  return nil
end

return Treesitter
