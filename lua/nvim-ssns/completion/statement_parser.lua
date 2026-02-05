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
---@field token_start_idx number? Index into token array where this chunk starts (for token caching)
---@field token_end_idx number? Index into token array where this chunk ends (for token caching)

---@class TempTableInfo
---@field name string Temp table name
---@field columns ColumnInfo[] Columns in the temp table
---@field created_in_batch number GO batch index where it was created
---@field is_global boolean Whether it's a global temp table (##)
---@field dropped_at_line number? Line number where dropped (nil if not dropped)

-- Load type annotations (for LuaLS type checking)
require('nvim-ssns.completion.parser.types')

-- Import ParserState from parser module
local ParserState = require('nvim-ssns.completion.parser.state')

-- Import utility modules
local Keywords = require('nvim-ssns.completion.parser.utils.keywords')
local Helpers = require('nvim-ssns.completion.parser.utils.helpers')
local QualifiedName = require('nvim-ssns.completion.parser.utils.qualified_name')
local AliasParser = require('nvim-ssns.completion.parser.utils.alias')
local TableReferenceParser = require('nvim-ssns.completion.parser.utils.table_reference')
local ScopeContext = require('nvim-ssns.completion.parser.scope')

-- Import clause parser modules
local SelectListParser = require('nvim-ssns.completion.parser.clauses.select_list')
local FromClauseParser = require('nvim-ssns.completion.parser.clauses.from_clause')
local CteClauseParser = require('nvim-ssns.completion.parser.clauses.cte_clause')
local SubqueryParser = require('nvim-ssns.completion.parser.clauses.subquery')
local WhereClauseParser = require('nvim-ssns.completion.parser.clauses.where_clause')

-- Import statement handler modules
local BaseStatement = require('nvim-ssns.completion.parser.statements.base')
local SelectStatement = require('nvim-ssns.completion.parser.statements.select')
local InsertStatement = require('nvim-ssns.completion.parser.statements.insert')
local UpdateStatement = require('nvim-ssns.completion.parser.statements.update')
local DeleteStatement = require('nvim-ssns.completion.parser.statements.delete')
local MergeStatement = require('nvim-ssns.completion.parser.statements.merge')
local DdlStatement = require('nvim-ssns.completion.parser.statements.ddl')
local ExecStatement = require('nvim-ssns.completion.parser.statements.exec')
local SetStatement = require('nvim-ssns.completion.parser.statements.set')

local StatementParser = {}

-- Local aliases for convenience
local resolve_column_parents = Helpers.resolve_column_parents
local is_statement_starter = Keywords.is_statement_starter

-- ParserState method wrappers that delegate to utility modules

---Parse qualified identifier (server.db.schema.table or db.schema.table or schema.table or table)
---@return {server: string?, database: string?, schema: string?, name: string}?
function ParserState:parse_qualified_identifier()
  return QualifiedName.parse(self)
end

---Try to parse an alias (AS alias or just alias)
---@return string?
function ParserState:parse_alias()
  return AliasParser.parse(self)
end

---Parse a table reference with optional alias
---@param known_ctes table<string, boolean>
---@return TableReference?
function ParserState:parse_table_reference(known_ctes)
  return TableReferenceParser.parse_legacy(self, known_ctes)
end

---Parse a subquery recursively
---This method delegates to SubqueryParser module
---@param known_ctes table<string, boolean>
---@return SubqueryInfo?
function ParserState:parse_subquery(known_ctes)
  return SubqueryParser.parse(self, known_ctes)
end

---Dispatch to appropriate statement handler based on keyword
---@param state ParserState Token navigation state
---@param scope ScopeContext Scope context with CTEs
---@param temp_tables table<string, TempTableInfo> Temp tables collection
---@return StatementChunk? chunk The parsed statement chunk
local function parse_statement_dispatch(state, scope, temp_tables)
  local token = state:current()
  if not token then
    return nil
  end

  local keyword = token.text:upper()

  -- Dispatch to appropriate handler
  if keyword == "SELECT" then
    return SelectStatement.parse(state, scope, temp_tables)
  elseif keyword == "INSERT" then
    local chunk, _ = InsertStatement.parse(state, scope, temp_tables)
    -- Update chunk end position from clause positions (same as SELECT does)
    for _, pos in pairs(chunk.clause_positions or {}) do
      if pos.end_line and pos.end_col then
        if pos.end_line > chunk.end_line or (pos.end_line == chunk.end_line and pos.end_col > chunk.end_col) then
          chunk.end_line = pos.end_line
          chunk.end_col = pos.end_col
        end
      end
    end
    return chunk
  elseif keyword == "UPDATE" then
    local chunk = UpdateStatement.parse(state, scope, temp_tables)
    -- After UPDATE, continue parsing for SET and FROM clauses
    parse_statement_remaining(state, chunk, scope, "UPDATE")
    return chunk
  elseif keyword == "DELETE" then
    local chunk = DeleteStatement.parse(state, scope, temp_tables)
    -- After DELETE, check for FROM clause (extended syntax)
    if state:is_keyword("FROM") and chunk.delete_target then
      DeleteStatement.parse_from(state, chunk, scope)
    end
    -- Parse WHERE clause for DELETE
    if state:is_keyword("WHERE") then
      WhereClauseParser.parse(state, chunk, scope, SubqueryParser)
    end
    -- Finalize chunk
    BaseStatement.finalize_chunk(chunk, scope, state)
    -- Update chunk end position from clause positions
    for _, pos in pairs(chunk.clause_positions or {}) do
      if pos.end_line and pos.end_col then
        if pos.end_line > chunk.end_line or (pos.end_line == chunk.end_line and pos.end_col > chunk.end_col) then
          chunk.end_line = pos.end_line
          chunk.end_col = pos.end_col
        end
      end
    end
    return chunk
  elseif keyword == "MERGE" then
    return MergeStatement.parse(state, scope, temp_tables)
  elseif keyword == "CREATE" then
    return DdlStatement.parse_create(state, scope, temp_tables)
  elseif keyword == "ALTER" then
    return DdlStatement.parse_alter(state, scope, temp_tables)
  elseif keyword == "DROP" then
    return DdlStatement.parse_drop(state, scope, temp_tables)
  elseif keyword == "DECLARE" then
    return DdlStatement.parse_declare(state, scope, temp_tables)
  elseif keyword == "TRUNCATE" then
    return DdlStatement.parse_truncate(state, scope, temp_tables)
  elseif keyword == "EXEC" or keyword == "EXECUTE" then
    return ExecStatement.parse(state, scope)
  elseif keyword == "SET" then
    return SetStatement.parse(state, scope, SubqueryParser)
  else
    -- Unknown statement type - skip to next statement
    state:consume_until_statement_end()
    return nil
  end
end

---Parse remaining clauses after UPDATE (SET, FROM for extended syntax, WHERE)
---@param state ParserState
---@param chunk StatementChunk
---@param scope ScopeContext
---@param statement_type string
function parse_statement_remaining(state, chunk, scope, statement_type)
  -- Parse SET clause (with subquery detection)
  if state:is_keyword("SET") then
    local set_token = state:current()
    state:advance()

    -- Track SET clause position
    chunk.clause_positions["set"] = {
      start_line = set_token.line,
      start_col = set_token.col,
      end_line = set_token.line,
      end_col = set_token.col + 2,
    }

    -- Build known_ctes for subquery parsing
    local known_ctes = scope and scope:get_known_ctes_table() or {}

    -- Parse SET expressions until FROM or WHERE or statement end, detecting subqueries
    local paren_depth = 0
    local last_token = set_token

    while state:current() do
      local token = state:current()

      if token.type == "paren_open" then
        paren_depth = paren_depth + 1
        last_token = token
        state:advance()
        -- Check for subquery: (SELECT ...
        if state:is_keyword("SELECT") then
          local subquery = state:parse_subquery(known_ctes)
          if subquery then
            -- After parse_subquery, parser is AT the closing ) - consume it
            if state:is_type("paren_close") then
              last_token = state:current()
              state:advance()
            end
            paren_depth = paren_depth - 1
            -- Add to scope so it gets copied to chunk in finalize
            if scope then
              scope:add_subquery(subquery)
            end
          end
        end
      elseif token.type == "paren_close" then
        paren_depth = paren_depth - 1
        last_token = token
        state:advance()
      elseif paren_depth == 0 then
        if state:is_keyword("FROM") or state:is_keyword("WHERE") then
          break
        end
        if is_statement_starter(token.text) then
          break
        end
        last_token = token
        state:advance()
      else
        last_token = token
        state:advance()
      end
    end

    -- Update SET clause end position
    chunk.clause_positions["set"].end_line = last_token.line
    chunk.clause_positions["set"].end_col = last_token.col + #last_token.text - 1
  end

  -- Parse FROM clause for extended UPDATE
  if state:is_keyword("FROM") then
    UpdateStatement.parse_from(state, chunk, scope)
  end

  -- Parse WHERE clause
  if state:is_keyword("WHERE") then
    WhereClauseParser.parse(state, chunk, scope, SubqueryParser)
  end

  -- Finalize UPDATE chunk
  UpdateStatement.finalize(chunk)

  -- Finalize chunk
  BaseStatement.finalize_chunk(chunk, scope, state)

  -- Update chunk end position from clause positions (same as SELECT does)
  for _, pos in pairs(chunk.clause_positions or {}) do
    if pos.end_line and pos.end_col then
      if pos.end_line > chunk.end_line or (pos.end_line == chunk.end_line and pos.end_col > chunk.end_col) then
        chunk.end_line = pos.end_line
        chunk.end_col = pos.end_col
      end
    end
  end
end

---Parse SQL text into statement chunks
---@param text string The SQL text to parse
---@return StatementChunk[] chunks The parsed chunks
---@return table<string, TempTableInfo> temp_tables Temp table info
---@return Token[] tokens The full token array (for caching)
function StatementParser.parse(text)
  local Tokenizer = require('nvim-ssns.completion.tokenizer')
  local tokens = Tokenizer.tokenize(text)

  local state = ParserState.new(tokens)
  local chunks = {}
  local temp_tables = {}

  while state:current() do
    local token = state:current()

    -- Handle GO batch separator
    if token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      state.go_batch_index = state.go_batch_index + 1
      state:advance()
      goto continue
    end

    -- Skip semicolons
    if token.type == "semicolon" then
      state:advance()
      goto continue
    end

    -- Check for statement starter
    if is_statement_starter(token.text) then
      -- Create fresh scope for each statement
      local scope = ScopeContext.new(nil)

      -- Save the start position (important for WITH...SELECT where WITH starts the statement)
      local stmt_start_line = token.line
      local stmt_start_col = token.col

      -- Handle WITH clause (CTEs) - capture the ordered array
      local parsed_ctes = nil
      if token.text:upper() == "WITH" then
        parsed_ctes = CteClauseParser.parse(state, scope)
        -- ctes are now in scope, continue to parse main statement
      end

      -- Now parse the main statement
      local chunk = parse_statement_dispatch(state, scope, temp_tables)
      if chunk then
        -- Copy CTEs to chunk - use parsed_ctes array to preserve declaration order
        -- (using pairs on scope.ctes would lose order since it's a dictionary)
        if parsed_ctes then
          for _, cte in ipairs(parsed_ctes) do
            if type(cte) == "table" and cte.name then
              table.insert(chunk.ctes, cte)
            end
          end
          -- Fix start position to be at WITH, not SELECT
          chunk.start_line = stmt_start_line
          chunk.start_col = stmt_start_col
        end

        -- Extract parameters from entire statement (done by handlers)
        table.insert(chunks, chunk)
      end
    else
      -- Unknown token at statement position, skip it
      state:advance()
    end

    ::continue::
  end

  return chunks, temp_tables, tokens
end

---Find which chunk contains the given position
---@param chunks StatementChunk[] The parsed chunks
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return StatementChunk? chunk The chunk at position, or nil
function StatementParser.get_chunk_at_position(chunks, line, col)
  local best_match = nil
  local best_end_line = -1

  for _, chunk in ipairs(chunks) do
    -- Quick line check: skip chunks that start after cursor line
    if line < chunk.start_line then
      if best_match then
        break
      end
      goto continue
    end

    -- Check if cursor is within chunk line boundaries
    if line >= chunk.start_line and line <= chunk.end_line then
      if line == chunk.start_line and col < chunk.start_col then
        goto continue
      end

      -- Allow cursor past end_col on last line (typing continuation)
      if line == chunk.end_line and col > chunk.end_col + 50 then
        goto continue
      end

      return chunk
    end

    -- Check continuation (cursor on lines after chunk.end_line within 5 lines)
    if line > chunk.end_line and line <= chunk.end_line + 5 then
      if chunk.end_line > best_end_line then
        best_end_line = chunk.end_line
        best_match = chunk
      end
    end

    ::continue::
  end

  return best_match
end

---Check if position is within bounds
---@param line number
---@param col number
---@param start_pos {line: number, col: number}
---@param end_pos {line: number, col: number}
---@return boolean
local function is_position_in_bounds(line, col, start_pos, end_pos)
  if line < start_pos.line or line > end_pos.line then
    return false
  end
  if line == start_pos.line and col < start_pos.col then
    return false
  end
  if line == end_pos.line and col > end_pos.col then
    return false
  end
  return true
end

---Recursively search for subquery containing position
---@param subquery SubqueryInfo
---@param line number
---@param col number
---@return SubqueryInfo?
local function find_subquery_recursive(subquery, line, col)
  -- Check nested subqueries first (innermost wins)
  for _, nested in ipairs(subquery.subqueries) do
    if is_position_in_bounds(line, col, nested.start_pos, nested.end_pos) then
      local result = find_subquery_recursive(nested, line, col)
      if result then
        return result
      end
      return nested
    end
  end

  -- Check if position is in this subquery
  if is_position_in_bounds(line, col, subquery.start_pos, subquery.end_pos) then
    return subquery
  end

  return nil
end

---Find if position is inside a subquery (recursive search)
---@param chunk StatementChunk The chunk to search
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return SubqueryInfo? subquery The innermost subquery containing position, or nil
function StatementParser.get_subquery_at_position(chunk, line, col)
  for _, subquery in ipairs(chunk.subqueries) do
    local result = find_subquery_recursive(subquery, line, col)
    if result then
      return result
    end
  end
  return nil
end

---Get which clause the cursor is in
---@param chunk StatementChunk
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? clause_name "select", "from", "where", "group_by", "having", "order_by", "set", "into", "join", "on", "values", "insert_columns", or nil
function StatementParser.get_clause_at_position(chunk, line, col)
  if not chunk or not chunk.clause_positions then
    return nil
  end

  -- Quick bounds check (skip if start_line/end_line not available, e.g., for subquery clause_positions)
  if chunk.start_line and chunk.end_line then
    if line < chunk.start_line or line > chunk.end_line then
      return nil
    end
    if line == chunk.start_line and col < chunk.start_col then
      return nil
    end
  end

  -- Find the last clause that started before (or at) the cursor position
  local best_match = nil
  local best_start_line = -1
  local best_start_col = -1

  for clause_name, pos in pairs(chunk.clause_positions) do
    -- Skip clauses that start AFTER the cursor
    if pos.start_line > line or (pos.start_line == line and pos.start_col > col) then
      goto continue
    end

    -- Check if this is the latest-starting clause
    local is_later = (pos.start_line > best_start_line) or
                     (pos.start_line == best_start_line and pos.start_col > best_start_col)

    if is_later then
      best_start_line = pos.start_line
      best_start_col = pos.start_col
      best_match = clause_name
    end

    ::continue::
  end

  if best_match then
    -- Normalize join_N and on_N to just "join" and "on"
    if best_match:match("^join_%d+$") then
      return "join"
    elseif best_match:match("^on_%d+$") then
      return "on"
    end
    return best_match
  end

  return nil
end

return StatementParser
