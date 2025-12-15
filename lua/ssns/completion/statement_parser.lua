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
require('ssns.completion.parser.types')

-- Import ParserState from parser module
local ParserState = require('ssns.completion.parser.state')

-- Import utility modules
local Keywords = require('ssns.completion.parser.utils.keywords')
local Helpers = require('ssns.completion.parser.utils.helpers')
local QualifiedName = require('ssns.completion.parser.utils.qualified_name')
local AliasParser = require('ssns.completion.parser.utils.alias')
local TableReferenceParser = require('ssns.completion.parser.utils.table_reference')
local ScopeContext = require('ssns.completion.parser.scope')

-- Import clause parser modules
local SelectListParser = require('ssns.completion.parser.clauses.select_list')
local FromClauseParser = require('ssns.completion.parser.clauses.from_clause')
local CteClauseParser = require('ssns.completion.parser.clauses.cte_clause')

-- Import statement handler modules
local BaseStatement = require('ssns.completion.parser.statements.base')
local SelectStatement = require('ssns.completion.parser.statements.select')
local InsertStatement = require('ssns.completion.parser.statements.insert')
local UpdateStatement = require('ssns.completion.parser.statements.update')
local DeleteStatement = require('ssns.completion.parser.statements.delete')
local MergeStatement = require('ssns.completion.parser.statements.merge')
local DdlStatement = require('ssns.completion.parser.statements.ddl')

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
---This method is called by clause parsers to parse nested subqueries
---@param known_ctes table<string, boolean>
---@return SubqueryInfo?
function ParserState:parse_subquery(known_ctes)
  local start_token = self:current()
  if not start_token then
    return nil
  end

  -- Track token range for parameter extraction
  local start_token_idx = self.pos

  local subquery = {
    alias = nil,
    columns = {},
    tables = {},
    subqueries = {},
    parameters = {},
    start_pos = { line = start_token.line, col = start_token.col },
    end_pos = { line = start_token.line, col = start_token.col },
    clause_positions = {},
  }

  -- Create a temporary scope for this subquery
  local scope = ScopeContext.new(nil)
  -- Populate scope.ctes from known_ctes
  for name, _ in pairs(known_ctes or {}) do
    scope:add_cte(name, { name = name, columns = {}, tables = {}, subqueries = {}, parameters = {} })
  end

  -- We're at SELECT keyword - save it for position tracking
  local select_token = self:current()
  self:advance()

  -- Parse SELECT list using the SelectListParser module
  local select_clause_pos
  subquery.columns, select_clause_pos = SelectListParser.parse(self, scope, select_token)
  if select_clause_pos then
    subquery.clause_positions["select"] = select_clause_pos
  end

  -- Parse FROM clause using the FromClauseParser module
  if self:is_keyword("FROM") then
    local from_token = self:current()
    local result = FromClauseParser.parse(self, scope, from_token)
    subquery.tables = result.tables
    if result.clause_position then
      subquery.clause_positions["from"] = result.clause_position
    end
    -- Add join and on positions
    if result.join_positions then
      for i, pos in ipairs(result.join_positions) do
        subquery.clause_positions["join_" .. i] = pos
      end
    end
    if result.on_positions then
      for i, pos in ipairs(result.on_positions) do
        subquery.clause_positions["on_" .. i] = pos
      end
    end
  end

  -- Copy subqueries from scope
  subquery.subqueries = scope.subqueries

  -- Handle set operations (UNION, INTERSECT, EXCEPT) to capture tables from all members
  local where_start = nil
  local last_token_before_end = nil

  while self:current() do
    -- Skip until we hit UNION/INTERSECT/EXCEPT or end of subquery
    local set_op_paren_depth = 0
    while self:current() do
      local token = self:current()

      -- Track WHERE clause start
      if set_op_paren_depth == 0 and self:is_keyword("WHERE") and not where_start then
        where_start = token
      end

      -- Track last token for WHERE clause end position
      last_token_before_end = token

      if token.type == "paren_open" then
        set_op_paren_depth = set_op_paren_depth + 1
        self:advance()
        -- Check for nested subquery: (SELECT ...
        if self:is_keyword("SELECT") then
          local nested = self:parse_subquery(known_ctes)
          if nested then
            table.insert(subquery.subqueries, nested)
          end
          -- After parse_subquery, parser is AT the closing ) - consume it
          if self:is_type("paren_close") then
            last_token_before_end = self:current()
            self:advance()
          end
          set_op_paren_depth = set_op_paren_depth - 1
        end
      elseif token.type == "paren_close" then
        if set_op_paren_depth == 0 then
          -- End of subquery - record WHERE clause position
          if where_start and last_token_before_end then
            subquery.clause_positions["where"] = {
              start_line = where_start.line,
              start_col = where_start.col,
              end_line = last_token_before_end.line,
              end_col = last_token_before_end.col + #last_token_before_end.text - 1,
            }
          end
          break
        end
        set_op_paren_depth = set_op_paren_depth - 1
        self:advance()
      elseif set_op_paren_depth == 0 and (self:is_keyword("UNION") or self:is_keyword("INTERSECT") or self:is_keyword("EXCEPT")) then
        -- Found set operation - record WHERE clause position
        if where_start and last_token_before_end then
          subquery.clause_positions["where"] = {
            start_line = where_start.line,
            start_col = where_start.col,
            end_line = last_token_before_end.line,
            end_col = last_token_before_end.col + #last_token_before_end.text - 1,
          }
        end
        break
      else
        self:advance()
      end
    end

    local is_set_op = self:is_keyword("UNION") or self:is_keyword("INTERSECT") or self:is_keyword("EXCEPT")
    if not is_set_op then
      break
    end

    self:advance()  -- consume UNION/INTERSECT/EXCEPT

    -- Handle ALL or DISTINCT modifier
    if self:is_keyword("ALL") or self:is_keyword("DISTINCT") then
      self:advance()
    end

    -- Expect SELECT
    if not self:is_keyword("SELECT") then
      break
    end
    self:advance()  -- consume SELECT

    -- Skip SELECT list until FROM
    local select_paren_depth = 0
    while self:current() do
      if self:is_type("paren_open") then
        select_paren_depth = select_paren_depth + 1
      elseif self:is_type("paren_close") then
        if select_paren_depth > 0 then
          select_paren_depth = select_paren_depth - 1
        else
          break  -- End of subquery
        end
      elseif select_paren_depth == 0 and self:is_keyword("FROM") then
        break  -- Found FROM clause
      end
      self:advance()
    end

    -- Parse FROM clause for UNION member
    if self:is_keyword("FROM") then
      local from_token = self:current()
      local union_scope = ScopeContext.new(nil)
      for name, _ in pairs(known_ctes or {}) do
        union_scope:add_cte(name, { name = name, columns = {}, tables = {}, subqueries = {}, parameters = {} })
      end
      local result = FromClauseParser.parse(self, union_scope, from_token)
      for _, tbl in ipairs(result.tables) do
        table.insert(subquery.tables, tbl)
      end
    end
  end

  -- Parse remaining nested subqueries
  local scan_depth = 0
  while self:current() do
    if self:is_type("paren_open") then
      scan_depth = scan_depth + 1
      self:advance()
      if self:is_keyword("SELECT") then
        local nested = self:parse_subquery(known_ctes)
        if nested then
          table.insert(subquery.subqueries, nested)
        end
        scan_depth = scan_depth - 1
      end
    elseif self:is_type("paren_close") then
      if scan_depth <= 0 then
        break  -- End of current subquery
      end
      scan_depth = scan_depth - 1
      self:advance()
    else
      self:advance()
    end
  end

  -- Record end position
  local end_token = self:current()
  if end_token then
    subquery.end_pos = { line = end_token.line, col = end_token.col }
  end

  -- Build alias mapping for this subquery
  local subquery_aliases = {}
  for _, table_ref in ipairs(subquery.tables) do
    if table_ref.alias then
      subquery_aliases[table_ref.alias:lower()] = table_ref
    end
  end

  -- Resolve parent_table for columns
  resolve_column_parents(subquery.columns, subquery_aliases, subquery.tables)

  -- Extract parameters from tokens
  local end_token_idx = self.pos - 1
  if end_token_idx >= start_token_idx then
    self:extract_all_parameters_from_tokens(start_token_idx, end_token_idx, subquery.parameters)
  end

  return subquery
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
      parse_where_clause(state, chunk, scope)
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
    return parse_exec_statement(state, scope)
  elseif keyword == "SET" then
    return parse_set_statement(state, scope)
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
    parse_where_clause(state, chunk, scope)
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

---Parse WHERE clause and track its position (shared by UPDATE/DELETE)
---@param state ParserState
---@param chunk StatementChunk
---@param scope ScopeContext
function parse_where_clause(state, chunk, scope)
  local where_token = state:current()
  state:advance()  -- consume WHERE

  local paren_depth = 0
  local last_token = where_token

  -- Build known_ctes for subquery parsing
  local known_ctes = scope and scope:get_known_ctes_table() or {}

  -- Parse until we hit ORDER BY, statement end, or next statement
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
      if paren_depth < 0 then
        break
      end
      last_token = token
      state:advance()
    elseif token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      break
    elseif token.type == "semicolon" then
      break
    elseif paren_depth == 0 and token.type == "keyword" then
      local upper_text = token.text:upper()
      if upper_text == "ORDER" or upper_text == "OPTION"
         or upper_text == "FOR" then
        break
      elseif is_statement_starter(upper_text) and upper_text ~= "WITH" then
        break
      else
        last_token = token
        state:advance()
      end
    else
      last_token = token
      state:advance()
    end
  end

  -- Track WHERE clause position
  chunk.clause_positions["where"] = {
    start_line = where_token.line,
    start_col = where_token.col,
    end_line = last_token.line,
    end_col = last_token.col + #last_token.text - 1,
  }
end

---Parse EXEC/EXECUTE statement
---@param state ParserState
---@param scope ScopeContext
---@return StatementChunk
function parse_exec_statement(state, scope)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("EXEC", start_token, state.go_batch_index, state)

  scope.statement_type = "EXEC"
  state:advance()  -- Must advance past EXEC before consume_until_statement_end
  state:consume_until_statement_end()

  -- Set token_end_idx manually since we don't call finalize_chunk
  if chunk.token_start_idx then
    chunk.token_end_idx = state.pos > 1 and state.pos - 1 or state.pos
  end

  -- Extract parameters from token range
  if chunk.token_start_idx and chunk.token_end_idx then
    state:extract_all_parameters_from_tokens(chunk.token_start_idx, chunk.token_end_idx, chunk.parameters)
  end

  return chunk
end

---Parse SET statement (variable assignment)
---@param state ParserState
---@param scope ScopeContext
---@return StatementChunk
function parse_set_statement(state, scope)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("SET", start_token, state.go_batch_index, state)

  scope.statement_type = "SET"
  state:advance()  -- Advance past SET

  -- Build known_ctes for subquery parsing
  local known_ctes = scope and scope:get_known_ctes_table() or {}

  -- Parse SET statement content, looking for subqueries
  local paren_depth = 0

  while state:current() do
    local token = state:current()

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      state:advance()
      -- Check for subquery: (SELECT ...
      if state:is_keyword("SELECT") then
        local subquery = state:parse_subquery(known_ctes)
        if subquery then
          -- After parse_subquery, parser is AT the closing ) - consume it
          if state:is_type("paren_close") then
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
      state:advance()
    elseif token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      -- Stop at GO batch separator
      break
    elseif token.type == "semicolon" then
      -- Stop at semicolon
      break
    elseif paren_depth == 0 and token.type == "keyword" then
      -- Check for new statement starter at top level
      if is_statement_starter(token.text:upper()) then
        break
      else
        state:advance()
      end
    else
      state:advance()
    end
  end

  -- Finalize chunk (copies subqueries from scope, sets token_end_idx)
  BaseStatement.finalize_chunk(chunk, scope, state)

  -- Extract parameters from token range
  if chunk.token_start_idx and chunk.token_end_idx then
    state:extract_all_parameters_from_tokens(chunk.token_start_idx, chunk.token_end_idx, chunk.parameters)
  end

  return chunk
end

---Parse SQL text into statement chunks
---@param text string The SQL text to parse
---@return StatementChunk[] chunks The parsed chunks
---@return table<string, TempTableInfo> temp_tables Temp table info
---@return Token[] tokens The full token array (for caching)
function StatementParser.parse(text)
  local Tokenizer = require('ssns.completion.tokenizer')
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
