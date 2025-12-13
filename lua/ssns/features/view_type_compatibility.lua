---@class ViewTypeCompatibility
---View type compatibility rules in a floating window
---Shows type categories and compatibility matrix
---@module ssns.features.view_type_compatibility
local ViewTypeCompatibility = {}

local UiFloat = require('ssns.ui.core.float')
local ContentBuilder = require('ssns.ui.core.content_builder')
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

  -- Build styled content
  local cb = ContentBuilder.new()
  
  cb:header("Type Compatibility Rules")
  cb:separator("=", 50)
  cb:blank()

  -- Purpose
  cb:section("Purpose")
  cb:separator("-", 30)
  cb:indent("Warn users when comparing incompatible", 1, "muted")
  cb:indent("column types in WHERE/ON clauses", 1, "muted")
  cb:blank()

  -- Type categories
  cb:section("Type Categories")
  cb:separator("-", 30)
  cb:blank()

  -- Sort categories for consistent display
  local sorted_categories = {}
  for cat in pairs(TypeCompatibility.categories) do
    table.insert(sorted_categories, cat)
  end
  table.sort(sorted_categories)

  for _, category in ipairs(sorted_categories) do
    local types = TypeCompatibility.categories[category]
    cb:spans({
      { text = "  " },
      { text = category:upper(), style = "emphasis" },
      { text = ":" },
    })

    -- Group types into rows of 4
    local type_row = {}
    for i, t in ipairs(types) do
      table.insert(type_row, t)
      if #type_row == 4 or i == #types then
        cb:indent(table.concat(type_row, ", "), 2, "value")
        type_row = {}
      end
    end
    cb:blank()
  end

  -- Normalization
  cb:section("Type Normalization")
  cb:separator("-", 30)
  cb:indent("1. Convert to lowercase", 1)
  cb:indent("2. Remove size parameters: varchar(50) -> varchar", 1)
  cb:blank()

  local norm_examples = { "VARCHAR(50)", "DECIMAL(10,2)", "nvarchar(max)", "datetime2(7)" }
  for _, example in ipairs(norm_examples) do
    local normalized = TypeCompatibility.normalize_type(example)
    cb:spans({
      { text = "  " },
      { text = example, style = "label" },
      { text = " -> " },
      { text = normalized, style = "value" },
    })
  end
  cb:blank()

  -- Compatibility rules
  cb:section("Compatibility Rules")
  cb:separator("-", 30)
  cb:spans({ { text = "  Same type after normalization: " }, { text = "Compatible", style = "success" } })
  cb:spans({ { text = "  Same category: " }, { text = "Compatible", style = "success" } })
  cb:spans({ { text = "  numeric <-> boolean: " }, { text = "Warning (implicit conv)", style = "warning" } })
  cb:spans({ { text = "  string <-> numeric: " }, { text = "Error", style = "error" } })
  cb:spans({ { text = "  string <-> temporal: " }, { text = "Warning (format must match)", style = "warning" } })
  cb:spans({ { text = "  Different categories: " }, { text = "Error", style = "error" } })
  cb:blank()

  -- Test comparisons
  cb:section("Test Comparisons")
  cb:separator("-", 30)
  cb:blank()

  for _, pair in ipairs(test_pairs) do
    local t1, t2 = pair[1], pair[2]
    local info = TypeCompatibility.get_info(t1, t2)

    local cat1 = TypeCompatibility.get_category(t1) or "unknown"
    local cat2 = TypeCompatibility.get_category(t2) or "unknown"

    -- Result line with icon
    local status_style = info.compatible and "success" or "error"
    if info.warning then status_style = "warning" end
    
    cb:spans({
      { text = "  " },
      { text = info.icon .. " ", style = status_style },
      { text = t1, style = "label" },
      { text = " vs " },
      { text = t2, style = "label" },
    })
    cb:spans({
      { text = "      Categories: " },
      { text = cat1, style = "muted" },
      { text = " vs ", style = "muted" },
      { text = cat2, style = "muted" },
    })
    if info.warning then
      cb:indent(info.warning, 3, "warning")
    end
  end
  cb:blank()

  -- JSON output
  cb:blank()
  cb:header("Categories JSON")
  cb:separator("=", 50)
  cb:blank()

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
    cb:line(line)
  end

  -- Create styled floating window
  current_float = UiFloat.create_styled(cb, {
    title = "Type Compatibility",
    border = "rounded",
    filetype = "markdown",
    min_width = 60,
    max_width = 100,
    wrap = false,
    keymaps = {
      ['r'] = function()
        ViewTypeCompatibility.view_compatibility()
      end,
      ['t'] = function()
        -- Interactive test - show dialog with two inputs
        local test_win = UiFloat.create({
          title = "Test Type Compatibility",
          width = 55,
          height = 10,
          center = true,
          content_builder = true,
          enable_inputs = true,
          zindex = UiFloat.ZINDEX.OVERLAY,
        })

        if test_win then
          local cb = test_win:get_content_builder()
          cb:line("")
          cb:line("  Compare two SQL types:", "SsnsUiTitle")
          cb:line("")
          cb:labeled_input("  Type 1: ", "type1", "", 35)
          cb:labeled_input("  Type 2: ", "type2", "", 35)
          cb:line("")
          cb:line("  <Enter>=Check | Tab=Next | <Esc>=Cancel", "SsnsUiHint")
          test_win:render()

          local function do_check()
            local t1 = test_win:get_input_value("type1")
            local t2 = test_win:get_input_value("type2")
            test_win:close()

            if t1 and t1 ~= "" and t2 and t2 ~= "" then
              local info = TypeCompatibility.get_info(t1, t2)
              local msg = string.format("TypeCheck: %s vs %s = %s %s",
                t1, t2, info.icon, info.compatible and "compatible" or "INCOMPATIBLE")
              if info.warning then
                msg = msg .. " - " .. info.warning
              end
              vim.notify(msg, info.compatible and vim.log.levels.INFO or vim.log.levels.WARN)
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

          test_win:on_input_submit(do_check)
        end
      end,
    },
    footer = "q: close | r: refresh | t: test two types",
  })
end

return ViewTypeCompatibility

