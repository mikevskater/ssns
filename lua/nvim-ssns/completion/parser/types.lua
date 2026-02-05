--- Type definitions for the statement parser
--- This file contains LuaLS @class annotations for type checking.
--- It should be required at the top of files that need these type definitions.

---@class TableReference
---@field server string? Linked server name (four-part name)
---@field database string? Database name (cross-db reference)
---@field schema string? Schema name
---@field name string Table/view/synonym name
---@field alias string? Alias if any
---@field is_temp boolean Whether it's a temp table (#temp or ##temp)
---@field is_global_temp boolean Whether it's a global temp table (##temp)
---@field is_table_variable boolean Whether it's a table variable (@TableVar)
---@field is_cte boolean Whether it references a CTE

---@class ParameterInfo
---@field name string Parameter name (without @)
---@field full_name string Full parameter name (with @)
---@field line number Line where parameter appears
---@field col number Column where parameter appears
---@field is_system boolean Whether it's a system variable (@@)

---@class ColumnInfo
---@field name string Column name or alias
---@field source_table string? Table/alias prefix used in the query
---@field parent_table string? Actual base table name (resolved from alias)
---@field parent_schema string? Schema of the parent table
---@field is_star boolean Whether this is a * or alias.*

---@class ClausePosition
---@field start_line number 1-indexed start line
---@field start_col number 1-indexed start column
---@field end_line number 1-indexed end line
---@field end_col number 1-indexed end column

---@class SubqueryInfo
---@field alias string? The alias after closing paren
---@field columns ColumnInfo[] Columns from SELECT list
---@field tables TableReference[] Tables in FROM clause
---@field subqueries SubqueryInfo[] Nested subqueries (recursive)
---@field parameters ParameterInfo[] Parameters used in this subquery
---@field start_pos {line: number, col: number}
---@field end_pos {line: number, col: number}
---@field clause_positions table<string, ClausePosition>? Clause positions within subquery

---@class CTEInfo
---@field name string CTE name
---@field columns ColumnInfo[] Columns from SELECT list
---@field tables TableReference[] Tables referenced
---@field subqueries SubqueryInfo[] Any nested subqueries
---@field parameters ParameterInfo[] Parameters used in this CTE
---@field aliases table<string, TableReference>? Alias -> table mapping within CTE
---@field start_pos {line: number, col: number}? Start position of CTE body (after AS keyword)
---@field end_pos {line: number, col: number}? End position of CTE body (closing paren)

---@class StatementChunk
---@field statement_type string "SELECT"|"SELECT_INTO"|"INSERT"|"UPDATE"|"DELETE"|"WITH"|"EXEC"|"OTHER"
---@field tables TableReference[] Tables from FROM/JOIN clauses
---@field aliases table<string, TableReference> Alias -> table mapping
---@field columns ColumnInfo[]? For SELECT - columns in SELECT list
---@field subqueries SubqueryInfo[] Subqueries with aliases (recursive)
---@field ctes CTEInfo[] CTEs defined in WITH clause
---@field parameters ParameterInfo[] Parameters/variables used in this chunk
---@field temp_table_name string? For SELECT INTO / CREATE TABLE #temp
---@field is_global_temp boolean? Whether temp_table_name is a global temp (##)
---@field insert_columns string[]? Column names in INSERT INTO table (col1, col2, ...)
---@field start_line number 1-indexed start line
---@field end_line number 1-indexed end line
---@field start_col number 1-indexed start column (only relevant on start_line)
---@field end_col number 1-indexed end column (only relevant on end_line)
---@field go_batch_index number Which GO batch this belongs to (1-indexed)
---@field clause_positions table<string, ClausePosition>? Positions of each clause (select, from, where, values, insert_columns, etc.)

---@class TempTableInfo
---@field name string Temp table name
---@field columns ColumnInfo[] Columns in the temp table
---@field created_in_batch number GO batch index where it was created
---@field is_global boolean Whether it's a global temp table (##)
---@field dropped_at_line number? Line number where dropped (nil if not dropped)

-- Export nothing - this file is for LuaLS type annotations only
-- Requiring this file loads the type definitions into the Lua Language Server
return {}
