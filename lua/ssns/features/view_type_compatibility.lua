---@class ViewTypeCompatibility
---View type compatibility rules in a floating window
---Shows type categories and compatibility matrix
---@module ssns.features.view_type_compatibility
local ViewTypeCompatibility = {}

local UiFloat = require('ssns.ui.float')
local JsonUtils = require('ssns.utils.json')
local TypeCompatibility = require('ssns.completion.type_compatibility')

-- Store reference to current floating window for cleanup
local current_float = nil

-- Test type pairs for compatibility
local test_pairs = {
  { "int", "bigint" },
  { "varchar(50)", "nvarchar(100)" },
  { "int", "varchar" },
  { "datetime", "datetime2" },
  { "bit", "int" },
  { "decimal(10,2)", "money" },
  { "varchar", "date" },
  { "uniqueidentifier", "uuid" },
}

---Close the current floating window
function ViewTypeCompatibility.close_current_float()
  if current_float then
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
end

---View type compatibility details
function ViewTypeCompatibility.view_compatibility()
  -- Close any existing float
  ViewTypeCompatibility.close_current_float()

  -- Build display content
  local display_lines = {}

  table.insert(display_lines, "Type Compatibility Rules")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Purpose
  table.insert(display_lines, "Purpose")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, "  Warn users when comparing incompatible")
  table.insert(display_lines, "  column types in WHERE/ON clauses")
  table.insert(display_lines, "")

  -- Type categories
  table.insert(display_lines, "Type Categories")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, "")

  -- Sort categories for consistent display
  local sorted_categories = {}
  for cat in pairs(TypeCompatibility.categories) do
    table.insert(sorted_categories, cat)
  end
  table.sort(sorted_categories)

  for _, category in ipairs(sorted_categories) do
    local types = TypeCompatibility.categories[category]
    table.insert(display_lines, string.format("  %s:", category:upper()))

    -- Group types into rows of 4
    local type_row = {}
    for i, t in ipairs(types) do
      table.insert(type_row, t)
      if #type_row == 4 or i == #types then
        table.insert(display_lines, "    " .. table.concat(type_row, ", "))
        type_row = {}
      end
    end
    table.insert(display_lines, "")
  end

  -- Normalization
  table.insert(display_lines, "Type Normalization")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, "  1. Convert to lowercase")
  table.insert(display_lines, "  2. Remove size parameters: varchar(50) -> varchar")
  table.insert(display_lines, "")

  local norm_examples = { "VARCHAR(50)", "DECIMAL(10,2)", "nvarchar(max)", "datetime2(7)" }
  for _, example in ipairs(norm_examples) do
    local normalized = TypeCompatibility.normalize_type(example)
    table.insert(display_lines, string.format("  %s -> %s", example, normalized))
  end
  table.insert(display_lines, "")

  -- Compatibility rules
  table.insert(display_lines, "Compatibility Rules")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, "  Same type after normalization: Compatible")
  table.insert(display_lines, "  Same category: Compatible")
  table.insert(display_lines, "  numeric <-> boolean: Warning (implicit conv)")
  table.insert(display_lines, "  string <-> numeric: Error")
  table.insert(display_lines, "  string <-> temporal: Warning (format must match)")
  table.insert(display_lines, "  Different categories: Error")
  table.insert(display_lines, "")

  -- Test comparisons
  table.insert(display_lines, "Test Comparisons")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, "")

  for _, pair in ipairs(test_pairs) do
    local t1, t2 = pair[1], pair[2]
    local info = TypeCompatibility.get_info(t1, t2)

    local cat1 = TypeCompatibility.get_category(t1) or "unknown"
    local cat2 = TypeCompatibility.get_category(t2) or "unknown"

    table.insert(display_lines, string.format("  %s %s vs %s", info.icon, t1, t2))
    table.insert(display_lines, string.format("      Categories: %s vs %s", cat1, cat2))
    if info.warning then
      table.insert(display_lines, string.format("      %s", info.warning))
    end
  end
  table.insert(display_lines, "")

  -- JSON output
  table.insert(display_lines, "")
  table.insert(display_lines, "Categories JSON")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  local json_data = {
    categories = TypeCompatibility.categories,
    test_results = {},
  }

  for _, pair in ipairs(test_pairs) do
    local t1, t2 = pair[1], pair[2]
    local compatible, warning = TypeCompatibility.are_compatible(t1, t2)
    table.insert(json_data.test_results, {
      type1 = t1,
      type2 = t2,
      category1 = TypeCompatibility.get_category(t1),
      category2 = TypeCompatibility.get_category(t2),
      compatible = compatible,
      warning = warning,
    })
  end

  local json_lines = JsonUtils.prettify_lines(json_data)
  for _, line in ipairs(json_lines) do
    table.insert(display_lines, line)
  end

  -- Create floating window
  current_float = UiFloat.create(display_lines, {
    title = "Type Compatibility",
    border = "rounded",
    filetype = "markdown",
    min_width = 60,
    max_width = 100,
    max_height = 50,
    wrap = false,
    keymaps = {
      ['r'] = function()
        ViewTypeCompatibility.view_compatibility()
      end,
      ['t'] = function()
        -- Interactive test
        vim.ui.input({ prompt = "Type 1 (e.g., int): " }, function(t1)
          if t1 and t1 ~= "" then
            vim.ui.input({ prompt = "Type 2 (e.g., varchar): " }, function(t2)
              if t2 and t2 ~= "" then
                local info = TypeCompatibility.get_info(t1, t2)
                local msg = string.format("TypeCheck: %s vs %s = %s %s",
                  t1, t2, info.icon, info.compatible and "compatible" or "INCOMPATIBLE")
                if info.warning then
                  msg = msg .. " - " .. info.warning
                end
                vim.notify(msg, info.compatible and vim.log.levels.INFO or vim.log.levels.WARN)
              end
            end)
          end
        end)
      end,
    },
    footer = "q: close | r: refresh | t: test two types",
  })
end

return ViewTypeCompatibility
