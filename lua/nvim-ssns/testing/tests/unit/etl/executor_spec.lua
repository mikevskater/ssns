---Unit tests for ETL executor
---@diagnostic disable: undefined-global

local EtlExecutor = require("nvim-ssns.etl.executor")
local Etl = require("nvim-ssns.etl")

describe("EtlExecutor", function()
  describe("new", function()
    it("should create executor with script", function()
      local script = Etl.parse([[
--@var x = 1
--@block test
SELECT 1
]])
      local executor = EtlExecutor.new(script)

      assert.is_not_nil(executor)
      assert.is_not_nil(executor.context)
      assert.equals(1, executor.context:get_variable("x"))
    end)

    it("should merge additional variables", function()
      local script = Etl.parse([[
--@var x = 1
--@block test
SELECT 1
]])
      local executor = EtlExecutor.new(script, {
        variables = { y = 2, z = "hello" },
      })

      assert.equals(1, executor.context:get_variable("x"))
      assert.equals(2, executor.context:get_variable("y"))
      assert.equals("hello", executor.context:get_variable("z"))
    end)

    it("should set default server from options", function()
      local script = Etl.parse([[
--@block test
SELECT 1
]])
      local executor = EtlExecutor.new(script, {
        server = "my_server",
        database = "my_db",
      })

      assert.equals("my_server", executor.current_server)
      assert.equals("my_db", executor.current_database)
    end)
  end)

  describe("_create_values_clause", function()
    it("should create VALUES clause from rows", function()
      local rows = {
        { id = 1, name = "Alice" },
        { id = 2, name = "Bob" },
      }
      local columns = {
        id = { name = "id", type = "INT", index = 1 },
        name = { name = "name", type = "VARCHAR", index = 2 },
      }

      local sql = EtlExecutor._create_values_clause(rows, columns)

      assert.is_not_nil(sql)
      assert.is_true(sql:find("Alice") ~= nil)
      assert.is_true(sql:find("Bob") ~= nil)
      assert.is_true(sql:find("UNION ALL") ~= nil)
    end)

    it("should handle NULL values", function()
      local rows = {
        { id = 1, name = nil },
      }
      local columns = {}

      local sql = EtlExecutor._create_values_clause(rows, columns)

      assert.is_true(sql:find("NULL") ~= nil)
    end)

    it("should escape single quotes", function()
      local rows = {
        { name = "O'Brien" },
      }
      local columns = {}

      local sql = EtlExecutor._create_values_clause(rows, columns)

      assert.is_true(sql:find("O''Brien") ~= nil)
    end)

    it("should handle boolean values", function()
      local rows = {
        { active = true, deleted = false },
      }
      local columns = {}

      local sql = EtlExecutor._create_values_clause(rows, columns)

      -- Booleans become 1 and 0
      assert.is_true(sql:find("1") ~= nil)
      assert.is_true(sql:find("0") ~= nil)
    end)

    it("should return nil for empty rows", function()
      local sql = EtlExecutor._create_values_clause({}, {})
      assert.is_nil(sql)
    end)
  end)

  describe("environment", function()
    local function run_lua_in_env(code, context)
      -- Create a mock executor to test environment
      local script = Etl.parse([[
--@lua test
]] .. code)

      local executor = EtlExecutor.new(script)

      -- Copy context data if provided
      if context then
        if context.variables then
          for k, v in pairs(context.variables) do
            executor.context:set_variable(k, v)
          end
        end
        if context.results then
          for k, v in pairs(context.results) do
            executor.context:set_result(k, v)
          end
        end
      end

      local env = executor:_create_environment(script.blocks[1])

      -- Compile and run
      local chunk, err = loadstring(code, "test")
      if not chunk then
        return nil, err
      end

      setfenv(chunk, env)
      local ok, result = pcall(chunk)
      if not ok then
        return nil, result
      end

      return result, nil
    end

    it("should provide sql() helper", function()
      local result = run_lua_in_env([[
return sql("SELECT 1")
]])
      assert.is_not_nil(result)
      assert.equals("sql", result._etl_type)
      assert.equals("SELECT 1", result.sql)
    end)

    it("should provide data() helper", function()
      local result = run_lua_in_env([[
return data({ {id = 1}, {id = 2} })
]])
      assert.is_not_nil(result)
      assert.equals("data", result._etl_type)
      assert.equals(2, #result.data)
    end)

    it("should provide var() helper", function()
      local result = run_lua_in_env([[
return var("x", 999)
]], { variables = { x = 42 } })

      assert.equals(42, result)
    end)

    it("should return default from var() if not set", function()
      local result = run_lua_in_env([[
return var("missing", "default_value")
]])
      assert.equals("default_value", result)
    end)

    it("should provide results proxy", function()
      local result = run_lua_in_env([[
return results.source.row_count
]], {
        results = {
          source = {
            rows = { {}, {}, {} },
            columns = {},
            row_count = 3,
            execution_time_ms = 10,
            block_type = "sql",
            output_type = "sql",
          },
        },
      })

      assert.equals(3, result)
    end)

    it("should provide vars proxy with read-write access", function()
      local result = run_lua_in_env([[
vars.new_var = "set from lua"
return vars.new_var
]])
      assert.equals("set from lua", result)
    end)

    it("should allow string manipulation", function()
      local result = run_lua_in_env([[
return string.upper("hello")
]])
      assert.equals("HELLO", result)
    end)

    it("should allow table manipulation", function()
      local result = run_lua_in_env([[
local t = {1, 2, 3}
table.insert(t, 4)
return #t
]])
      assert.equals(4, result)
    end)

    it("should allow math functions", function()
      local result = run_lua_in_env([[
return math.floor(3.7)
]])
      assert.equals(3, result)
    end)

    it("should allow os.date and os.time", function()
      local result = run_lua_in_env([[
return os.date("%Y")
]])
      -- Should return current year as string
      assert.is_true(tonumber(result) >= 2024)
    end)

    it("should provide print function", function()
      local result, err = run_lua_in_env([[
print("hello", "world")
return 42
]])
      assert.is_nil(err)
      assert.equals(42, result)
    end)

    it("should error on sql() with non-string", function()
      local result, err = run_lua_in_env([[
return sql(123)
]])
      assert.is_not_nil(err)
      assert.is_true(err:find("string") ~= nil)
    end)

    it("should error on data() with non-table", function()
      local result, err = run_lua_in_env([[
return data("not a table")
]])
      assert.is_not_nil(err)
      assert.is_true(err:find("table") ~= nil)
    end)

    -- Full Lua access tests (sandbox removed)
    it("should allow require() for installed modules", function()
      local result, err = run_lua_in_env([[
-- require should work (will error if module not found, but function exists)
return type(require) == "function"
]])
      assert.is_nil(err)
      assert.is_true(result)
    end)

    it("should allow vim.fn access", function()
      local result, err = run_lua_in_env([[
return vim.fn.expand("%")
]])
      -- Should not error, even if result is empty
      assert.is_nil(err)
    end)

    it("should allow vim.api access", function()
      local result, err = run_lua_in_env([[
return type(vim.api.nvim_get_current_buf) == "function"
]])
      assert.is_nil(err)
      assert.is_true(result)
    end)

    it("should allow io operations", function()
      local result, err = run_lua_in_env([[
return type(io.open) == "function"
]])
      assert.is_nil(err)
      assert.is_true(result)
    end)

    it("should allow full os module access", function()
      local result, err = run_lua_in_env([[
-- os.getenv should now be available (not just date/time)
return type(os.getenv) == "function"
]])
      assert.is_nil(err)
      assert.is_true(result)
    end)

    it("should allow vim.json for JSON operations", function()
      local result, err = run_lua_in_env([[
local encoded = vim.json.encode({foo = "bar"})
local decoded = vim.json.decode(encoded)
return decoded.foo
]])
      assert.is_nil(err)
      assert.equals("bar", result)
    end)

    it("ETL helpers should override global functions", function()
      -- Ensure our custom print goes to log, not global print
      local result, err = run_lua_in_env([[
-- print should be our custom version that logs
print("test message")
-- But we should still have access to _G.print if needed
return type(_G.print) == "function"
]])
      assert.is_nil(err)
      assert.is_true(result)
    end)
  end)

  describe("progress callback", function()
    it("should call progress callback for events", function()
      local events = {}
      local script = Etl.parse([[
--@block test
SELECT 1
]])

      -- We can't actually execute without a server, but we can check
      -- that the executor is set up correctly
      local executor = EtlExecutor.new(script, {
        progress_callback = function(event)
          table.insert(events, event.type)
        end,
      })

      assert.is_not_nil(executor.progress_callback)
    end)
  end)

  describe("cancellation", function()
    it("should set cancelled flag", function()
      local script = Etl.parse([[
--@block test
SELECT 1
]])
      local executor = EtlExecutor.new(script)

      assert.is_false(executor.cancelled)
      executor:cancel()
      assert.is_true(executor.cancelled)
    end)
  end)
end)

describe("Etl.execute", function()
  it("should be exported from module", function()
    assert.is_function(Etl.execute)
  end)

  it("should be exported from module", function()
    assert.is_function(Etl.create_executor)
  end)
end)
