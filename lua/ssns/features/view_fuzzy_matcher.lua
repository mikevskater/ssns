---@class ViewFuzzyMatcher
---View fuzzy matcher algorithm details in a floating window
---Shows normalization rules, thresholds, and allows interactive testing
---@module ssns.features.view_fuzzy_matcher
local ViewFuzzyMatcher = {}

local UiFloat = require('ssns.ui.float')
local JsonUtils = require('ssns.utils.json')
local FuzzyMatcher = require('ssns.completion.fuzzy_matcher')

-- Store reference to current floating window for cleanup
local current_float = nil

-- Test pairs for demonstration
local test_pairs = {
  { "Employee_ID", "EmployeeId" },
  { "CustomerID", "customer_id" },
  { "FK_OrderID", "OrderID" },
  { "FirstName", "first_name" },
  { "ProductCode", "ProductID" },
  { "Status", "OrderStatus" },
  { "ID", "Id" },
  { "DateCreated", "created_at" },
}

---Close the current floating window
function ViewFuzzyMatcher.close_current_float()
  if current_float then
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
end

---View fuzzy matcher details
function ViewFuzzyMatcher.view_matcher()
  -- Close any existing float
  ViewFuzzyMatcher.close_current_float()

  -- Build display content
  local display_lines = {}

  table.insert(display_lines, "Fuzzy Matcher Algorithm")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Algorithm description
  table.insert(display_lines, "Algorithm")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, "  Type: Levenshtein Distance")
  table.insert(display_lines, "  Score: 1.0 - (distance / max_length)")
  table.insert(display_lines, "  Default threshold: 0.85 (85% similarity)")
  table.insert(display_lines, "")

  -- Normalization rules
  table.insert(display_lines, "Normalization Rules")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, "  1. Convert to lowercase")
  table.insert(display_lines, "  2. Remove underscores (_)")
  table.insert(display_lines, "  3. Strip 'fk' prefix (foreign key)")
  table.insert(display_lines, "  4. Strip 'pk' prefix (primary key)")
  table.insert(display_lines, "")

  -- Normalization examples
  table.insert(display_lines, "Normalization Examples")
  table.insert(display_lines, string.rep("-", 30))
  local norm_examples = {
    "Employee_ID",
    "customer_id",
    "FK_OrderID",
    "PK_ProductId",
    "firstName",
  }
  for _, example in ipairs(norm_examples) do
    local normalized = FuzzyMatcher.normalize(example)
    table.insert(display_lines, string.format("  %s -> %s", example, normalized))
  end
  table.insert(display_lines, "")

  -- Test comparisons
  table.insert(display_lines, "Test Comparisons")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, "  Threshold: 0.85")
  table.insert(display_lines, "")

  for _, pair in ipairs(test_pairs) do
    local s1, s2 = pair[1], pair[2]
    local is_match, score = FuzzyMatcher.is_match(s1, s2, 0.85)
    local match_str = is_match and "MATCH" or "no match"
    local icon = is_match and "+" or "-"

    table.insert(display_lines, string.format("  [%s] %s vs %s", icon, s1, s2))
    table.insert(display_lines, string.format("      Score: %.2f (%s)", score, match_str))
  end
  table.insert(display_lines, "")

  -- Column matching info
  table.insert(display_lines, "Column Matching Strategy")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, "  1. Exact match (case-insensitive)")
  table.insert(display_lines, "  2. Normalized match (after removing _, fk, pk)")
  table.insert(display_lines, "  3. Fuzzy match (Levenshtein with threshold)")
  table.insert(display_lines, "")
  table.insert(display_lines, "  Used for: JOIN suggestions, FK matching")
  table.insert(display_lines, "")

  -- JSON output for algorithm parameters
  table.insert(display_lines, "")
  table.insert(display_lines, "Algorithm Parameters JSON")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  local json_data = {
    algorithm = "Levenshtein Distance",
    default_threshold = 0.85,
    normalization_rules = {
      "lowercase",
      "remove_underscores",
      "strip_fk_prefix",
      "strip_pk_prefix",
    },
    test_results = {},
  }

  for _, pair in ipairs(test_pairs) do
    local s1, s2 = pair[1], pair[2]
    local is_match, score = FuzzyMatcher.is_match(s1, s2, 0.85)
    table.insert(json_data.test_results, {
      string1 = s1,
      string2 = s2,
      score = score,
      is_match = is_match,
    })
  end

  local json_lines = JsonUtils.prettify_lines(json_data)
  for _, line in ipairs(json_lines) do
    table.insert(display_lines, line)
  end

  -- Create floating window
  current_float = UiFloat.create(display_lines, {
    title = "Fuzzy Matcher",
    border = "rounded",
    filetype = "markdown",
    min_width = 60,
    max_width = 100,
    max_height = 50,
    wrap = false,
    keymaps = {
      ['r'] = function()
        ViewFuzzyMatcher.view_matcher()
      end,
      ['t'] = function()
        -- Interactive test
        vim.ui.input({ prompt = "String 1: " }, function(s1)
          if s1 and s1 ~= "" then
            vim.ui.input({ prompt = "String 2: " }, function(s2)
              if s2 and s2 ~= "" then
                local is_match, score = FuzzyMatcher.is_match(s1, s2, 0.85)
                local match_str = is_match and "MATCH" or "no match"
                vim.notify(string.format("FuzzyMatch: '%s' vs '%s' = %.2f (%s)",
                  s1, s2, score, match_str), vim.log.levels.INFO)
              end
            end)
          end
        end)
      end,
    },
    footer = "q: close | r: refresh | t: test two strings",
  })
end

return ViewFuzzyMatcher
