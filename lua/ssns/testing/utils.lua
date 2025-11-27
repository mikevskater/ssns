--- Testing utilities module
--- Helper functions for testing framework
local M = {}

--- Load test data from a .lua file
--- Supports both single test format and multi-test array format
--- @param filepath string Absolute path to test file
--- @return table? test_data The test data table (or array of tests) or nil on error
--- @return string? error Error message if loading failed
function M.load_test_file(filepath)
  -- Verify file exists
  local stat = vim.loop.fs_stat(filepath)
  if not stat then
    return nil, string.format("Test file not found: %s", filepath)
  end

  -- Load the file as a Lua module
  local success, test_data = pcall(dofile, filepath)
  if not success then
    return nil, string.format("Failed to load test file %s: %s", filepath, test_data)
  end

  -- Validate test data structure
  if type(test_data) ~= "table" then
    return nil, string.format("Test file %s did not return a table", filepath)
  end

  -- Check if this is an array of tests (new format) or single test (old format)
  if test_data[1] ~= nil and type(test_data[1]) == "table" then
    -- Array format - validate each test
    for i, test in ipairs(test_data) do
      local valid, err = M._validate_single_test(test, filepath, i)
      if not valid then
        return nil, err
      end
    end
    return test_data, nil
  else
    -- Single test format - validate and return
    local valid, err = M._validate_single_test(test_data, filepath, nil)
    if not valid then
      return nil, err
    end
    return test_data, nil
  end
end

--- Validate a single test's structure
--- @param test_data table Test data to validate
--- @param filepath string File path for error messages
--- @param index number? Index in array (nil for single test files)
--- @return boolean valid True if valid
--- @return string? error Error message if invalid
function M._validate_single_test(test_data, filepath, index)
  local prefix = index and string.format("Test %d in %s", index, filepath) or filepath

  -- Validate required fields
  local required_fields = { "number", "description", "database", "query", "cursor", "expected" }
  for _, field in ipairs(required_fields) do
    if test_data[field] == nil then
      return false, string.format("%s missing required field: %s", prefix, field)
    end
  end

  -- Validate cursor structure
  if type(test_data.cursor) ~= "table" or test_data.cursor.line == nil or test_data.cursor.col == nil then
    return false, string.format("%s has invalid cursor structure", prefix)
  end

  -- Validate expected structure
  if type(test_data.expected) ~= "table" or not test_data.expected.type then
    return false, string.format("%s has invalid expected structure (missing type)", prefix)
  end

  -- items can be an array or an object with includes/excludes/count
  if test_data.expected.items == nil then
    return false, string.format("%s has invalid expected structure (missing items)", prefix)
  end

  return true, nil
end

--- Recursively scan test folders and return all test files
--- Handles both direct structure (tests/sqlserver/category/) and integration structure (tests/integration/sqlserver/category/)
--- @param base_path string? Base path to scan (defaults to testing/tests)
--- @return table test_files Array of {path: string, category: string, database_type: string, name: string, is_integration: boolean}
function M.scan_test_folders(base_path)
  base_path = base_path or (vim.fn.stdpath("data") .. "/ssns/lua/ssns/testing/tests")

  -- Ensure path exists
  local stat = vim.loop.fs_stat(base_path)
  if not stat or stat.type ~= "directory" then
    return {}
  end

  local test_files = {}

  -- Scan directory recursively with flexible depth handling
  -- Structure can be:
  --   tests/sqlserver/01_category/test.lua (legacy)
  --   tests/integration/sqlserver/08_category/test.lua (new integration)
  --   tests/unit/providers/test.lua (unit tests)
  local function scan_dir(dir_path, context)
    context = context or { depth = 0 }
    local handle = vim.loop.fs_scandir(dir_path)
    if not handle then
      return
    end

    while true do
      local name, entry_type = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end

      local full_path = dir_path .. "/" .. name

      if entry_type == "directory" then
        local new_context = vim.tbl_extend("force", {}, context)
        new_context.depth = context.depth + 1

        -- Determine what level we're at
        if name == "integration" or name == "unit" then
          -- tests/integration/ or tests/unit/ - mark type and continue
          new_context.test_type = name
          scan_dir(full_path, new_context)
        elseif not context.database_type and (name == "sqlserver" or name == "postgres" or name == "mysql" or name == "sqlite") then
          -- Database type folder
          new_context.database_type = name
          scan_dir(full_path, new_context)
        elseif context.database_type and not context.category then
          -- Category folder (e.g., "08_table_completion")
          new_context.category = name
          scan_dir(full_path, new_context)
        else
          -- Other subfolder - continue scanning
          scan_dir(full_path, new_context)
        end
      elseif entry_type == "file" and name:match("%.lua$") then
        -- Found a test file
        table.insert(test_files, {
          path = full_path,
          category = context.category or "uncategorized",
          database_type = context.database_type or "sqlserver",
          name = name:gsub("%.lua$", ""),
          is_integration = context.test_type == "integration",
          is_unit = context.test_type == "unit",
        })
      end
    end
  end

  scan_dir(base_path, nil)

  -- Sort by path for consistent ordering
  table.sort(test_files, function(a, b)
    return a.path < b.path
  end)

  return test_files
end

--- Create mock context object from test data
--- Mimics what blink.cmp passes to source.get_completions()
--- @param test_data table Test data from test file
--- @param bufnr number? Buffer number (defaults to fake bufnr)
--- @return table context Mock context object
function M.create_mock_context(test_data, bufnr)
  bufnr = bufnr or 999999 -- Fake buffer number

  -- Split query into lines
  local lines = vim.split(test_data.query, "\n", { plain = true })

  -- Get cursor position (convert 0-indexed to 1-indexed for Lua)
  local cursor_line = test_data.cursor.line + 1 -- Convert to 1-indexed
  local cursor_col = test_data.cursor.col -- Already byte offset

  -- Get current line
  local line = lines[cursor_line] or ""

  return {
    bufnr = bufnr,
    cursor = { cursor_line, cursor_col },
    line = line,
    bounds = {
      start_col = 1,
      end_col = #line,
    },
    filetype = "sql",
  }
end

--- Create mock buffer with test data
--- Sets up a real buffer with the query text and database context
--- @param test_data table Test data from test file
--- @param connection_info table? Connection info { server, database, connection_string }
--- @return number bufnr The created buffer number
function M.create_mock_buffer(test_data, connection_info)
  -- Create a new buffer
  local bufnr = vim.api.nvim_create_buf(false, true) -- Not listed, scratch buffer

  -- Set buffer filetype
  vim.api.nvim_buf_set_option(bufnr, "filetype", "sql")

  -- Set buffer lines
  local lines = vim.split(test_data.query, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Set database context using REAL connection
  if connection_info then
    local db_key = string.format("%s:%s", connection_info.server.name, connection_info.database.db_name)
    vim.api.nvim_buf_set_var(bufnr, "ssns_db_key", db_key)
  else
    -- Fallback to fake server name if no connection info provided
    local db_key = string.format("test_server:%s", test_data.database)
    vim.api.nvim_buf_set_var(bufnr, "ssns_db_key", db_key)
  end

  return bufnr
end

--- Compare actual completion items with expected items
--- Supports multiple validation modes:
--- - Simple array: expected.items = {"A", "B"} - exact match
--- - Includes: expected.items.includes = {"A"} - must contain these
--- - Excludes: expected.items.excludes = {"X"} - must NOT contain these
--- - Includes_any: expected.items.includes_any = {"A", "B"} - must contain at least one
--- - Count: expected.items.count = 5 - exact count match
--- @param actual table[] Array of completion items from provider
--- @param expected table Expected results with type and items
--- @return table result { passed: boolean, missing: string[], unexpected: string[], details: string }
function M.compare_results(actual, expected)
  -- Extract labels from actual items
  local actual_labels = {}
  local actual_set = {}
  for _, item in ipairs(actual) do
    local label = item.label
    table.insert(actual_labels, label)
    actual_set[label] = true
    -- Also add lowercase for case-insensitive matching
    actual_set[label:lower()] = label
  end

  local result = {
    passed = true,
    missing = {},
    unexpected = {},
    details_parts = {},
    expected_count = nil,
    actual_count = #actual_labels,
  }

  local items = expected.items

  -- Handle simple array format (backward compatibility)
  if items[1] ~= nil and type(items[1]) == "string" then
    return M._compare_exact(actual_labels, actual_set, items)
  end

  -- Handle flexible format with includes/excludes/count
  table.insert(result.details_parts, string.format("Got %d items", #actual_labels))

  -- Check count constraint
  if items.count ~= nil then
    if #actual_labels ~= items.count then
      result.passed = false
      table.insert(result.details_parts, string.format("Count mismatch: expected %d, got %d", items.count, #actual_labels))
    else
      table.insert(result.details_parts, string.format("Count matches: %d", items.count))
    end
  end

  -- Check includes constraint (all must be present)
  if items.includes then
    for _, label in ipairs(items.includes) do
      if not actual_set[label] and not actual_set[label:lower()] then
        result.passed = false
        table.insert(result.missing, label)
      end
    end
    if #result.missing > 0 then
      table.insert(result.details_parts, string.format("Missing required: %s", table.concat(result.missing, ", ")))
    else
      table.insert(result.details_parts, string.format("All %d required items found", #items.includes))
    end
  end

  -- Check excludes constraint (none should be present)
  if items.excludes then
    for _, label in ipairs(items.excludes) do
      local found = actual_set[label] or actual_set[label:lower()]
      if found then
        result.passed = false
        table.insert(result.unexpected, type(found) == "string" and found or label)
      end
    end
    if #result.unexpected > 0 then
      table.insert(result.details_parts, string.format("Found excluded items: %s", table.concat(result.unexpected, ", ")))
    end
  end

  -- Check includes_any constraint (at least one must be present)
  if items.includes_any then
    local found_any = false
    local found_item = nil
    for _, label in ipairs(items.includes_any) do
      local match = actual_set[label] or actual_set[label:lower()]
      if match then
        found_any = true
        found_item = type(match) == "string" and match or label
        break
      end
    end
    if not found_any then
      result.passed = false
      table.insert(result.details_parts, string.format("Missing at least one of: %s", table.concat(items.includes_any, ", ")))
    else
      table.insert(result.details_parts, string.format("Found required item: %s", found_item))
    end
  end

  -- Check has_on_clause constraint (for JOIN suggestions)
  if items.has_on_clause then
    local found_on_clause = false
    for _, item in ipairs(actual) do
      if item.insertText and item.insertText:find(" ON ") then
        found_on_clause = true
        break
      end
    end
    if not found_on_clause then
      result.passed = false
      table.insert(result.details_parts, "Expected ON clause in insertText but not found")
    else
      table.insert(result.details_parts, "Found ON clause in suggestion")
    end
  end

  result.details = table.concat(result.details_parts, "\n")
  return result
end

--- Internal: Compare with exact match (old format)
--- @param actual_labels string[] Array of actual labels
--- @param actual_set table Set of actual labels
--- @param expected_items string[] Array of expected labels
--- @return table result Comparison result
function M._compare_exact(actual_labels, actual_set, expected_items)
  local expected_set = {}
  for _, label in ipairs(expected_items) do
    expected_set[label] = true
  end

  -- Find missing items (expected but not in actual)
  local missing = {}
  for _, label in ipairs(expected_items) do
    if not actual_set[label] then
      table.insert(missing, label)
    end
  end

  -- Find unexpected items (in actual but not expected)
  local unexpected = {}
  for _, label in ipairs(actual_labels) do
    if not expected_set[label] then
      table.insert(unexpected, label)
    end
  end

  -- Sort for consistent output
  table.sort(missing)
  table.sort(unexpected)

  -- Determine if test passed
  local passed = #missing == 0 and #unexpected == 0

  -- Build details string
  local details_parts = {}
  table.insert(details_parts, string.format("Expected %d items, got %d items", #expected_items, #actual_labels))

  if #missing > 0 then
    table.insert(details_parts, string.format("Missing: %s", table.concat(missing, ", ")))
  end

  if #unexpected > 0 then
    table.insert(details_parts, string.format("Unexpected: %s", table.concat(unexpected, ", ")))
  end

  if passed then
    table.insert(details_parts, "All expected items found")
  end

  return {
    passed = passed,
    missing = missing,
    unexpected = unexpected,
    details = table.concat(details_parts, "\n"),
    expected_count = #expected_items,
    actual_count = #actual_labels,
  }
end

--- Format a list of items for display
--- @param items string[] Array of item labels
--- @param max_items number? Maximum items to display (default: 10)
--- @return string formatted Formatted string
function M.format_item_list(items, max_items)
  max_items = max_items or 10

  if #items == 0 then
    return "(none)"
  end

  if #items <= max_items then
    return table.concat(items, ", ")
  end

  -- Show first max_items and indicate there are more
  local visible = vim.list_slice(items, 1, max_items)
  return string.format("%s ... (%d more)", table.concat(visible, ", "), #items - max_items)
end

--- Extract category name from file path
--- @param filepath string Full path to test file
--- @return string category Category name (e.g., "schema_table_qualification")
function M.extract_category(filepath)
  -- Extract category from path like .../tests/01_schema_table_qualification/test.lua
  local category = filepath:match("/tests/(%d+_[^/]+)/")
  if category then
    -- Remove numeric prefix (e.g., "01_")
    category = category:gsub("^%d+_", "")
    return category
  end
  return "uncategorized"
end

--- Clean category name for display
--- @param category string Raw category name
--- @return string cleaned Cleaned category name
function M.clean_category_name(category)
  -- Convert underscores to spaces and capitalize words
  local cleaned = category:gsub("_", " ")
  cleaned = cleaned:gsub("(%a)([%w]*)", function(first, rest)
    return first:upper() .. rest:lower()
  end)
  return cleaned
end

return M
