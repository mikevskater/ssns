---@class ViewFuzzyMatcher
---View fuzzy matcher algorithm details in a floating window
---Shows normalization rules, thresholds, and allows interactive testing
---@module ssns.features.view_fuzzy_matcher
local ViewFuzzyMatcher = {}

local BaseViewer = require('nvim-ssns.features.base_viewer')
local UiFloat = require('nvim-float.window')
local FuzzyMatcher = require('nvim-ssns.completion.fuzzy_matcher')

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

-- Create viewer instance
local viewer = BaseViewer.create({
  title = "Fuzzy Matcher",
  min_width = 60,
  max_width = 100,
  footer = "q: close | r: refresh | t: test two strings",
})

---Close the current floating window
function ViewFuzzyMatcher.close_current_float()
  viewer:close()
end

---View fuzzy matcher details
function ViewFuzzyMatcher.view_matcher()
  -- Set refresh callback and custom keymaps
  viewer.on_refresh = ViewFuzzyMatcher.view_matcher
  viewer:set_keymaps({
    ['t'] = function()
      -- Interactive test - show dialog with two inputs
      local test_win = UiFloat.create({
        title = "Test Fuzzy Match",
        width = 55,
        height = 10,
        center = true,
        content_builder = true,
        enable_inputs = true,
        zindex = UiFloat.ZINDEX.OVERLAY,
      })

      if test_win then
        local tcb = test_win:get_content_builder()
        tcb:line("")
        tcb:styled("  Compare two strings:", "NvimFloatTitle")
        tcb:blank()
        tcb:labeled_input("  String 1: ", "str1", "", 35)
        tcb:labeled_input("  String 2: ", "str2", "", 35)
        tcb:blank()
        tcb:styled("  <Enter>=Compare | Tab=Next | <Esc>=Cancel", "NvimFloatHint")
        test_win:render()

        local function do_compare()
          local s1 = test_win:get_input_value("str1")
          local s2 = test_win:get_input_value("str2")
          test_win:close()

          if s1 and s1 ~= "" and s2 and s2 ~= "" then
            local is_match, score = FuzzyMatcher.is_match(s1, s2, 0.85)
            local match_str = is_match and "MATCH" or "no match"
            vim.notify(string.format("FuzzyMatch: '%s' vs '%s' = %.2f (%s)",
              s1, s2, score, match_str), vim.log.levels.INFO)
          end
        end

        vim.keymap.set("n", "<CR>", function()
          test_win:enter_input()
        end, { buffer = test_win.buf, nowait = true })

        vim.keymap.set("n", "<Esc>", function()
          test_win:close()
        end, { buffer = test_win.buf, nowait = true })

        vim.keymap.set("n", "q", function()
          test_win:close()
        end, { buffer = test_win.buf, nowait = true })

        test_win:on_input_submit(do_compare)
      end
    end,
  })

  -- Show with JSON output
  viewer:show_with_json(function(cb)
    BaseViewer.add_header(cb, "Fuzzy Matcher Algorithm")

    -- Algorithm description
    cb:section("Algorithm")
    cb:separator("-", 30)
    cb:spans({
      { text = "  Type: ", style = "label" },
      { text = "Levenshtein Distance", style = "value" },
    })
    cb:spans({
      { text = "  Score: ", style = "label" },
      { text = "1.0 - (distance / max_length)", style = "muted" },
    })
    cb:spans({
      { text = "  Default threshold: ", style = "label" },
      { text = "0.85", style = "number" },
      { text = " (85% similarity)", style = "muted" },
    })
    cb:blank()

    -- Normalization rules
    cb:section("Normalization Rules")
    cb:separator("-", 30)
    cb:styled("  1. Convert to lowercase", "value")
    cb:styled("  2. Remove underscores (_)", "value")
    cb:styled("  3. Strip 'fk' prefix (foreign key)", "value")
    cb:styled("  4. Strip 'pk' prefix (primary key)", "value")
    cb:blank()

    -- Normalization examples
    cb:section("Normalization Examples")
    cb:separator("-", 30)
    local norm_examples = {
      "Employee_ID",
      "customer_id",
      "FK_OrderID",
      "PK_ProductId",
      "firstName",
    }
    for _, example in ipairs(norm_examples) do
      local normalized = FuzzyMatcher.normalize(example)
      cb:spans({
        { text = "  " },
        { text = example, style = "sql_column" },
        { text = " -> " },
        { text = normalized, style = "success" },
      })
    end
    cb:blank()

    -- Test comparisons
    cb:section("Test Comparisons")
    cb:separator("-", 30)
    cb:spans({
      { text = "  Threshold: ", style = "label" },
      { text = "0.85", style = "number" },
    })
    cb:blank()

    for _, pair in ipairs(test_pairs) do
      local s1, s2 = pair[1], pair[2]
      local is_match, score = FuzzyMatcher.is_match(s1, s2, 0.85)
      local icon = is_match and "+" or "-"
      local status_style = is_match and "success" or "error"

      cb:spans({
        { text = "  [" },
        { text = icon, style = status_style },
        { text = "] " },
        { text = s1, style = "sql_column" },
        { text = " vs " },
        { text = s2, style = "sql_column" },
      })
      cb:spans({
        { text = "      Score: ", style = "label" },
        { text = string.format("%.2f", score), style = "number" },
        { text = " (" },
        { text = is_match and "MATCH" or "no match", style = status_style },
        { text = ")" },
      })
    end
    cb:blank()

    -- Column matching info
    cb:section("Column Matching Strategy")
    cb:separator("-", 30)
    cb:styled("  1. Exact match (case-insensitive)", "value")
    cb:styled("  2. Normalized match (after removing _, fk, pk)", "value")
    cb:styled("  3. Fuzzy match (Levenshtein with threshold)", "value")
    cb:blank()
    cb:styled("  Used for: JOIN suggestions, FK matching", "muted")
    cb:blank()

    -- Return JSON data for algorithm parameters
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

    return json_data
  end, "Algorithm Parameters JSON")
end

return ViewFuzzyMatcher

