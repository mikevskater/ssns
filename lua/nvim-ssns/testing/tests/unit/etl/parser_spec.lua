---Unit tests for ETL parser
---@diagnostic disable: undefined-global

local EtlParser = require("nvim-ssns.etl.parser")
local Etl = require("nvim-ssns.etl")

describe("EtlParser", function()
  describe("parse", function()
    it("should parse a simple SQL block", function()
      local content = [[
--@block source_data
--@server local_mssql
--@database TestDB
--@description Extract test data
SELECT * FROM TestTable
]]
      local script = EtlParser.parse(content)

      assert.equals(1, #script.blocks)
      assert.equals("source_data", script.blocks[1].name)
      assert.equals("sql", script.blocks[1].type)
      assert.equals("local_mssql", script.blocks[1].server)
      assert.equals("TestDB", script.blocks[1].database)
      assert.equals("Extract test data", script.blocks[1].description)
      assert.equals("SELECT * FROM TestTable", script.blocks[1].content)
      assert.equals(1, script.blocks[1].start_line)
    end)

    it("should parse a Lua block", function()
      local content = [[
--@lua transform
--@description Transform the data
local rows = results.source_data.rows
return sql("SELECT " .. #rows .. " as count")
]]
      local script = EtlParser.parse(content)

      assert.equals(1, #script.blocks)
      assert.equals("transform", script.blocks[1].name)
      assert.equals("lua", script.blocks[1].type)
      assert.equals("Transform the data", script.blocks[1].description)
      assert.equals("sql", script.blocks[1].output) -- Default for Lua blocks
      assert.is_true(script.blocks[1].content:find("local rows"))
    end)

    it("should parse script-level variables", function()
      local content = [[
--@var report_date = '2026-02-01'
--@var batch_size = 1000
--@var debug = true

--@block test
SELECT * FROM Test
]]
      local script = EtlParser.parse(content)

      assert.equals("2026-02-01", script.variables.report_date)
      assert.equals(1000, script.variables.batch_size)
      assert.equals(true, script.variables.debug)
    end)

    it("should parse multiple blocks in order", function()
      local content = [[
--@var report_date = '2026-02-01'

--@block source_data
--@server local_mssql
--@database TestDB
--@description Extract test data
SELECT * FROM TestTable

--@lua transform
--@description Transform the data
local rows = results.source_data.rows
return sql("SELECT " .. #rows .. " as count")
]]
      local script = EtlParser.parse(content)

      assert.equals(2, #script.blocks)
      assert.equals("source_data", script.blocks[1].name)
      assert.equals("sql", script.blocks[1].type)
      assert.equals("transform", script.blocks[2].name)
      assert.equals("lua", script.blocks[2].type)
      assert.equals(1, vim.tbl_count(script.variables))
      assert.equals("2026-02-01", script.variables.report_date)
    end)

    it("should parse block options", function()
      local content = [[
--@block load_data
--@timeout 30000
--@skip_on_empty
--@continue_on_error
INSERT INTO Target SELECT * FROM Source
]]
      local script = EtlParser.parse(content)

      assert.equals(30000, script.blocks[1].options.timeout)
      assert.equals(true, script.blocks[1].options.skip_on_empty)
      assert.equals(true, script.blocks[1].options.continue_on_error)
    end)

    it("should parse ETL mode and target", function()
      local content = [[
--@block load_warehouse
--@input source_data
--@mode insert
--@target dbo.FactSales
INSERT INTO dbo.FactSales SELECT * FROM @input
]]
      local script = EtlParser.parse(content)

      assert.equals("source_data", script.blocks[1].input)
      assert.equals("insert", script.blocks[1].mode)
      assert.equals("dbo.FactSales", script.blocks[1].target)
    end)

    it("should track line numbers correctly", function()
      local content = [[
--@var x = 1

--@block first
SELECT 1

--@block second
SELECT 2
]]
      local script = EtlParser.parse(content)

      assert.equals(2, #script.blocks)
      -- Line 4 is --@block first
      assert.equals(4, script.blocks[1].start_line)
      -- Line 7 is --@block second
      assert.equals(7, script.blocks[2].start_line)
    end)

    it("should handle Lua output directive", function()
      local content = [[
--@lua transform_data
--@output data
local result = { {id = 1}, {id = 2} }
return data(result)
]]
      local script = EtlParser.parse(content)

      assert.equals("data", script.blocks[1].output)
    end)

    it("should preserve multiline content", function()
      local content = [[
--@block query
SELECT
  CustomerID,
  OrderDate,
  TotalAmount
FROM Orders
WHERE OrderDate >= GETDATE()
]]
      local script = EtlParser.parse(content)

      local expected_content = [[SELECT
  CustomerID,
  OrderDate,
  TotalAmount
FROM Orders
WHERE OrderDate >= GETDATE()]]

      assert.equals(expected_content, script.blocks[1].content)
    end)
  end)

  describe("validate", function()
    it("should pass for valid script", function()
      local content = [[
--@block source
SELECT * FROM Test

--@block target
--@input source
SELECT * FROM @input
]]
      local script = EtlParser.parse(content)
      local valid, errors = EtlParser.validate(script)

      assert.is_true(valid)
      assert.is_nil(errors)
    end)

    it("should detect duplicate block names", function()
      local content = [[
--@block source
SELECT 1

--@block source
SELECT 2
]]
      local script = EtlParser.parse(content)
      local valid, errors = EtlParser.validate(script)

      assert.is_false(valid)
      assert.is_true(#errors > 0)
      assert.is_true(errors[1]:find("Duplicate block name"))
    end)

    it("should detect invalid input references", function()
      local content = [[
--@block target
--@input nonexistent
SELECT * FROM @input
]]
      local script = EtlParser.parse(content)
      local valid, errors = EtlParser.validate(script)

      assert.is_false(valid)
      assert.is_true(errors[1]:find("unknown input"))
    end)

    it("should detect forward references", function()
      local content = [[
--@block first
--@input second
SELECT * FROM @input

--@block second
SELECT 1
]]
      local script = EtlParser.parse(content)
      local valid, errors = EtlParser.validate(script)

      assert.is_false(valid)
      assert.is_true(errors[1]:find("forward reference"))
    end)

    it("should detect empty blocks", function()
      local content = [[
--@block empty
]]
      local script = EtlParser.parse(content)
      local valid, errors = EtlParser.validate(script)

      assert.is_false(valid)
      assert.is_true(errors[1]:find("no content"))
    end)
  end)

  describe("resolve_dependencies", function()
    it("should return blocks in declaration order", function()
      local content = [[
--@block first
SELECT 1

--@block second
--@input first
SELECT 2

--@block third
--@input second
SELECT 3
]]
      local script = EtlParser.parse(content)
      local order = EtlParser.resolve_dependencies(script)

      assert.equals(3, #order)
      assert.equals("first", order[1])
      assert.equals("second", order[2])
      assert.equals("third", order[3])
    end)
  end)

  describe("get_block", function()
    it("should find block by name", function()
      local content = [[
--@block first
SELECT 1

--@block second
SELECT 2
]]
      local script = EtlParser.parse(content)
      local block = EtlParser.get_block(script, "second")

      assert.is_not_nil(block)
      assert.equals("second", block.name)
      assert.equals("SELECT 2", block.content)
    end)

    it("should return nil for unknown block", function()
      local content = [[
--@block first
SELECT 1
]]
      local script = EtlParser.parse(content)
      local block = EtlParser.get_block(script, "nonexistent")

      assert.is_nil(block)
    end)
  end)
end)

describe("Etl module", function()
  describe("get_summary", function()
    it("should return correct summary", function()
      local content = [[
--@var x = 1
--@var y = 2

--@block sql1
--@server server1
--@database db1
SELECT 1

--@lua lua1
--@server server2
--@database db2
return sql("SELECT 2")

--@block sql2
--@server server1
--@database db3
SELECT 3
]]
      local script = Etl.parse(content)
      local summary = Etl.get_summary(script)

      assert.equals(3, summary.total_blocks)
      assert.equals(2, summary.sql_blocks)
      assert.equals(1, summary.lua_blocks)
      assert.equals(2, summary.variables)
      assert.equals(2, #summary.servers)
      assert.equals(3, #summary.databases)
      assert.is_true(summary.has_cross_server)
    end)
  end)
end)
