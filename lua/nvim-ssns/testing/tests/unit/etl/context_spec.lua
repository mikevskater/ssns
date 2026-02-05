---Unit tests for ETL execution context
---@diagnostic disable: undefined-global

local EtlContext = require("nvim-ssns.etl.context")
local Etl = require("nvim-ssns.etl")

describe("EtlContext", function()
  describe("new", function()
    it("should create empty context", function()
      local ctx = EtlContext.new()

      assert.equals("pending", ctx.status)
      assert.is_nil(ctx.current_block)
      assert.same({}, ctx.results)
      assert.same({}, ctx.variables)
      assert.same({}, ctx.errors)
    end)

    it("should initialize with script variables", function()
      local script = Etl.parse([[
--@var x = 1
--@var y = 'hello'

--@block test
SELECT 1
]])
      local ctx = EtlContext.new(script)

      assert.equals(1, ctx.variables.x)
      assert.equals("hello", ctx.variables.y)
    end)
  end)

  describe("status management", function()
    it("should track status transitions", function()
      local ctx = EtlContext.new()

      assert.equals("pending", ctx.status)

      ctx:start()
      assert.equals("running", ctx.status)

      ctx:finish(true)
      assert.equals("success", ctx.status)
    end)

    it("should track failed status", function()
      local ctx = EtlContext.new()
      ctx:start()
      ctx:finish(false)

      assert.equals("error", ctx.status)
    end)

    it("should track cancelled status", function()
      local ctx = EtlContext.new()
      ctx:start()
      ctx:cancel()

      assert.equals("cancelled", ctx.status)
    end)
  end)

  describe("result storage", function()
    it("should store and retrieve results", function()
      local ctx = EtlContext.new()

      local result = {
        rows = { { id = 1 }, { id = 2 } },
        columns = { id = { name = "id", type = "INT", index = 1 } },
        row_count = 2,
        execution_time_ms = 100,
        block_type = "sql",
        output_type = "sql",
      }

      ctx:set_result("source_data", result)

      local retrieved = ctx:get_result("source_data")
      assert.is_not_nil(retrieved)
      assert.equals(2, retrieved.row_count)
      assert.equals("source_data", retrieved.block_name)
    end)

    it("should return nil for unknown block", function()
      local ctx = EtlContext.new()
      assert.is_nil(ctx:get_result("nonexistent"))
    end)

    it("should get input rows", function()
      local ctx = EtlContext.new()

      ctx:set_result("source", {
        rows = { { a = 1 }, { a = 2 }, { a = 3 } },
        columns = {},
        row_count = 3,
        execution_time_ms = 50,
        block_type = "sql",
        output_type = "sql",
      })

      local rows = ctx:get_input_rows("source")
      assert.equals(3, #rows)
      assert.equals(1, rows[1].a)
    end)

    it("should get input columns", function()
      local ctx = EtlContext.new()

      ctx:set_result("source", {
        rows = {},
        columns = {
          col1 = { name = "col1", type = "INT", index = 1 },
          col2 = { name = "col2", type = "VARCHAR", index = 2 },
        },
        row_count = 0,
        execution_time_ms = 50,
        block_type = "sql",
        output_type = "sql",
      })

      local columns = ctx:get_input_columns("source")
      assert.is_not_nil(columns.col1)
      assert.equals("INT", columns.col1.type)
    end)
  end)

  describe("error handling", function()
    it("should store and retrieve errors", function()
      local ctx = EtlContext.new()

      ctx:set_error("bad_block", {
        message = "Syntax error near 'SELCT'",
        line = 5,
        sql = "SELCT * FROM Test",
      })

      local err = ctx:get_error("bad_block")
      assert.is_not_nil(err)
      assert.equals("Syntax error near 'SELCT'", err.message)
      assert.equals(5, err.line)
    end)

    it("should check for errors", function()
      local ctx = EtlContext.new()

      assert.is_false(ctx:has_error("block1"))
      assert.is_false(ctx:has_any_error())

      ctx:set_error("block1", { message = "Error" })

      assert.is_true(ctx:has_error("block1"))
      assert.is_true(ctx:has_any_error())
      assert.is_false(ctx:has_error("block2"))
    end)
  end)

  describe("variable management", function()
    it("should set and get variables", function()
      local ctx = EtlContext.new()

      ctx:set_variable("report_date", "2026-02-01")
      ctx:set_variable("batch_size", 1000)

      assert.equals("2026-02-01", ctx:get_variable("report_date"))
      assert.equals(1000, ctx:get_variable("batch_size"))
    end)

    it("should return default for missing variable", function()
      local ctx = EtlContext.new()

      assert.is_nil(ctx:get_variable("missing"))
      assert.equals("default", ctx:get_variable("missing", "default"))
    end)
  end)

  describe("timing", function()
    it("should track block timings", function()
      local ctx = EtlContext.new()

      ctx:set_block_timing("block1", 150)
      ctx:set_block_timing("block2", 200)

      assert.equals(150, ctx:get_block_timing("block1"))
      assert.equals(200, ctx:get_block_timing("block2"))
    end)

    it("should calculate total time", function()
      local ctx = EtlContext.new()
      ctx:start()

      -- Give it a tiny bit of time
      local start = os.clock()
      while os.clock() - start < 0.001 do end

      local total = ctx:get_total_time()
      assert.is_true(total > 0)
    end)
  end)

  describe("results proxy", function()
    it("should create read-only results proxy", function()
      local ctx = EtlContext.new()

      ctx:set_result("source", {
        rows = { { x = 1 } },
        columns = { x = { name = "x", index = 1 } },
        row_count = 1,
        execution_time_ms = 10,
        block_type = "sql",
        output_type = "sql",
      })

      local proxy = ctx:create_results_proxy()

      -- Can read
      assert.equals(1, proxy.source.row_count)
      assert.equals(1, proxy.source.rows[1].x)

      -- Cannot write
      assert.has_error(function()
        proxy.source = { rows = {} }
      end)
    end)

    it("should return nil for missing blocks in proxy", function()
      local ctx = EtlContext.new()
      local proxy = ctx:create_results_proxy()

      assert.is_nil(proxy.nonexistent)
    end)
  end)

  describe("vars proxy", function()
    it("should create read-write vars proxy", function()
      local ctx = EtlContext.new()
      ctx:set_variable("x", 1)

      local proxy = ctx:create_vars_proxy()

      -- Can read
      assert.equals(1, proxy.x)

      -- Can write
      proxy.y = 2
      assert.equals(2, ctx:get_variable("y"))
    end)
  end)

  describe("result_from_node", function()
    it("should convert Node.js result to EtlResult", function()
      local node_result = {
        success = true,
        resultSets = {
          {
            rows = { { id = 1, name = "Alice" }, { id = 2, name = "Bob" } },
            columns = {
              id = { type = "INT" },
              name = { type = "VARCHAR" },
            },
          },
        },
        metadata = {
          rowsAffected = { 2 },
        },
      }

      local result = EtlContext.result_from_node(node_result, "test_block", "sql", 150, nil)

      assert.equals("test_block", result.block_name)
      assert.equals("sql", result.block_type)
      assert.equals(2, result.row_count)
      assert.equals(150, result.execution_time_ms)
      assert.equals("Alice", result.rows[1].name)
      assert.is_not_nil(result.columns.id)
    end)
  end)

  describe("result_from_data", function()
    it("should create EtlResult from Lua data", function()
      local data = {
        { id = 1, value = 100 },
        { id = 2, value = 200 },
      }

      local result = EtlContext.result_from_data(data, "transform", 25)

      assert.equals("transform", result.block_name)
      assert.equals("lua", result.block_type)
      assert.equals("data", result.output_type)
      assert.equals(2, result.row_count)
      assert.is_not_nil(result.columns.id)
      assert.is_not_nil(result.columns.value)
    end)
  end)

  describe("get_summary", function()
    it("should return execution summary", function()
      local script = Etl.parse([[
--@block block1
SELECT 1

--@block block2
SELECT 2

--@block block3
SELECT 3
]])

      local ctx = EtlContext.new(script)
      ctx:start()

      -- Simulate block1 success
      ctx:set_result("block1", {
        rows = { {}, {}, {} },
        columns = {},
        row_count = 3,
        execution_time_ms = 100,
        block_type = "sql",
        output_type = "sql",
      })

      -- Simulate block2 failure
      ctx:set_error("block2", { message = "Error" })

      -- block3 is skipped

      ctx:finish(false)

      local summary = ctx:get_summary()

      assert.equals("error", summary.status)
      assert.equals(3, summary.total_blocks)
      assert.equals(1, summary.completed_blocks)
      assert.equals(1, summary.failed_blocks)
      assert.equals(1, summary.skipped_blocks)
      assert.equals(3, summary.total_rows)
    end)
  end)
end)

describe("Etl.create_context", function()
  it("should create context via module function", function()
    local ctx = Etl.create_context()

    assert.equals("pending", ctx.status)
  end)

  it("should create context with script", function()
    local script = Etl.parse([[
--@var x = 42
--@block test
SELECT 1
]])

    local ctx = Etl.create_context(script)

    assert.equals(42, ctx.variables.x)
  end)
end)
