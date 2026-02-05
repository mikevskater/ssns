---@class SsnsCommandsTesting
---Testing framework commands
local M = {}

---Register testing commands
function M.register()
  local Ssns = require('nvim-ssns')

  -- :SSNSRunTests - Run all IntelliSense tests
  vim.api.nvim_create_user_command("SSNSRunTests", function()
    Ssns.run_all_tests()
  end, {
    nargs = 0,
    desc = "Run all SSNS IntelliSense tests",
  })

  -- :SSNSRunTest <number> - Run a specific test by number
  vim.api.nvim_create_user_command("SSNSRunTest", function(opts)
    local test_number = tonumber(opts.args)
    if not test_number then
      vim.notify("Invalid test number. Usage: :SSNSRunTest <number>", vim.log.levels.ERROR)
      return
    end
    Ssns.run_test(test_number)
  end, {
    nargs = 1,
    desc = "Run a specific SSNS test by number (1-40)",
  })

  -- :SSNSRunTestCategory <category> - Run tests in a specific category
  vim.api.nvim_create_user_command("SSNSRunTestCategory", function(opts)
    Ssns.run_category_tests(opts.args)
  end, {
    nargs = 1,
    desc = "Run tests in a specific category folder",
    complete = function()
      -- Get list of category folders from the tests directory
      local tests_path = vim.fn.stdpath("config") .. "/lua/ssns/testing/tests"
      local categories = {}

      local handle = vim.loop.fs_scandir(tests_path)
      if handle then
        while true do
          local name, type = vim.loop.fs_scandir_next(handle)
          if not name then break end
          if type == "directory" then
            table.insert(categories, name)
          end
        end
      end

      table.sort(categories)
      return categories
    end,
  })

  -- :SSNSRunTestsByType <type> - Run tests by completion type
  vim.api.nvim_create_user_command("SSNSRunTestsByType", function(opts)
    Ssns.run_tests_by_type(opts.args)
  end, {
    nargs = 1,
    desc = "Run tests by completion type (table, column, schema, etc.)",
    complete = function()
      -- Return common completion types
      return {
        "table",
        "column",
        "schema",
        "object",
        "database",
        "function",
        "procedure",
        "view",
      }
    end,
  })

  -- :SSNSViewTestResults - Open test results markdown file
  vim.api.nvim_create_user_command("SSNSViewTestResults", function()
    Ssns.view_test_results()
  end, {
    nargs = 0,
    desc = "Open the test results markdown file",
  })

  -- :SSNSRunAsyncTests - Run all async integration tests
  vim.api.nvim_create_user_command("SSNSRunAsyncTests", function()
    local testing = require("nvim-ssns.testing")
    testing.run_async_integration_tests()
  end, {
    nargs = 0,
    desc = "Run all SSNS async integration tests",
  })

  -- :SSNSRunAsyncTest <number> - Run a specific async integration test by ID
  vim.api.nvim_create_user_command("SSNSRunAsyncTest", function(opts)
    local test_id = tonumber(opts.args)
    if not test_id then
      vim.notify("Invalid test ID. Usage: :SSNSRunAsyncTest <id>", vim.log.levels.ERROR)
      return
    end
    local testing = require("nvim-ssns.testing")
    testing.run_async_integration_test(test_id)
  end, {
    nargs = 1,
    desc = "Run a specific async integration test by ID (10001-10999)",
  })
end

return M
